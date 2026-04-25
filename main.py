"""
ClipAI Downloader Service
FastAPI app that downloads YouTube videos via Cloudflare WARP proxy
"""

import os
import tempfile
import subprocess
import asyncio
from pathlib import Path
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="ClipAI Downloader", version="1.0.0")

WARP_PROXY = "http://127.0.0.1:8080"
DOWNLOAD_DIR = "/tmp/downloads"
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

API_KEY = os.environ.get("DOWNLOADER_API_KEY", "clipai-secret-key")


class DownloadRequest(BaseModel):
    url: str
    api_key: str


def cleanup_file(path: str):
    try:
        if os.path.exists(path):
            os.remove(path)
    except Exception:
        pass


def is_warp_connected() -> bool:
    try:
        result = subprocess.run(
            ["curl", "-s", "-x", WARP_PROXY,
             "https://cloudflare.com/cdn-cgi/trace", "--max-time", "10"],
            capture_output=True, text=True, timeout=15
        )
        return "warp=on" in result.stdout
    except Exception:
        return False


@app.get("/health")
def health():
    warp = is_warp_connected()
    return {
        "status": "ok",
        "warp_connected": warp,
    }


@app.post("/download")
async def download_video(req: DownloadRequest, background_tasks: BackgroundTasks):
    # Auth check
    if req.api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    if not req.url.startswith("http"):
        raise HTTPException(status_code=400, detail="Invalid URL")

    # Check WARP
    if not is_warp_connected():
        raise HTTPException(status_code=503, detail="WARP proxy not connected")

    with tempfile.TemporaryDirectory(dir=DOWNLOAD_DIR) as tmp:
        opts = [
            "yt-dlp",
            "--proxy", WARP_PROXY,
            "--format", (
                "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/"
                "bestvideo[height<=720]+bestaudio/"
                "best[height<=720]/"
                "best"
            ),
            "--merge-output-format", "mp4",
            "--no-playlist",
            "--no-check-certificate",
            "--retries", "10",
            "--fragment-retries", "20",
            "--continue",
            "--http-chunk-size", "10M",
            "--extractor-args", "youtube:player_client=android",
            "--output", os.path.join(tmp, "%(title).60s.%(ext)s"),
            req.url
        ]

        try:
            result = subprocess.run(
                opts,
                capture_output=True,
                text=True,
                timeout=1200  # 20 min max
            )
        except subprocess.TimeoutExpired:
            raise HTTPException(status_code=504, detail="Download timed out")

        if result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=f"Download failed: {result.stderr[-500:]}"
            )

        # Find the downloaded file
        mp4s = list(Path(tmp).glob("*.mp4"))
        if not mp4s:
            raise HTTPException(status_code=500, detail="No file downloaded")

        video_path = str(sorted(mp4s, key=os.path.getmtime)[-1])
        filename = os.path.basename(video_path)

        # Move to persistent location before tmp is cleaned up
        out_path = os.path.join(DOWNLOAD_DIR, filename)
        os.rename(video_path, out_path)

        # Schedule cleanup after response
        background_tasks.add_task(cleanup_file, out_path)

        return FileResponse(
            out_path,
            media_type="video/mp4",
            filename=filename,
            background=background_tasks
        )


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
