"""
ClipAI Downloader Service
FastAPI app that downloads YouTube videos using bgutil PO token provider
"""

import os
import tempfile
import subprocess
import socket
from pathlib import Path
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from pydantic import BaseModel

app = FastAPI(title="ClipAI Downloader", version="2.0.0")

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


def is_bgutil_running() -> bool:
    """Check if bgutil server is running on port 4416 (IPv4 or IPv6)."""
    for host in ["127.0.0.1", "::1", "0.0.0.0"]:
        try:
            family = socket.AF_INET6 if ":" in host else socket.AF_INET
            sock = socket.socket(family, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex((host, 4416))
            sock.close()
            if result == 0:
                return True
        except Exception:
            pass
    return False


@app.get("/health")
def health():
    try:
        result = subprocess.run(["yt-dlp", "--version"],
                                capture_output=True, text=True, timeout=5)
        ytdlp_version = result.stdout.strip()
    except Exception:
        ytdlp_version = "unknown"

    bgutil = is_bgutil_running()

    return {
        "status": "ok",
        "yt_dlp_version": ytdlp_version,
        "pot_provider": bgutil,
    }


@app.post("/download")
async def download_video(req: DownloadRequest, background_tasks: BackgroundTasks):
    if req.api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    if not req.url.startswith("http"):
        raise HTTPException(status_code=400, detail="Invalid URL")

    with tempfile.TemporaryDirectory(dir=DOWNLOAD_DIR) as tmp:
        cmd = [
            "yt-dlp",
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
            "--http-chunk-size", "10M",
            "--concurrent-fragments", "4",
            "--extractor-args", "youtube:player_client=web,android",
            "--output", os.path.join(tmp, "%(title).60s.%(ext)s"),
            req.url
        ]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=1200
            )
        except subprocess.TimeoutExpired:
            raise HTTPException(status_code=504, detail="Download timed out")

        if result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=f"Download failed: {result.stderr[-500:]}"
            )

        mp4s = list(Path(tmp).glob("*.mp4"))
        if not mp4s:
            raise HTTPException(status_code=500, detail="No file downloaded")

        video_path = str(sorted(mp4s, key=os.path.getmtime)[-1])
        filename = os.path.basename(video_path)
        out_path = os.path.join(DOWNLOAD_DIR, filename)
        os.rename(video_path, out_path)
        background_tasks.add_task(cleanup_file, out_path)

        return FileResponse(out_path, media_type="video/mp4", filename=filename)
