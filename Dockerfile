FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps including Node.js for PO token generation
RUN apt-get update && apt-get install -y \
    ffmpeg curl nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Verify Node.js
RUN node --version && npm --version

# Install yt-dlp (latest)
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp

# Install Python deps + PO token plugins
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install yt-dlp-get-pot bgutil-ytdlp-pot-provider

WORKDIR /app
COPY main.py .

# Start bgutil PO token server then FastAPI
CMD bash -c "\
    echo 'Starting bgutil PO token server...' && \
    python3 -c \"\
import subprocess, sys, os, importlib.util; \
spec = importlib.util.find_spec('bgutil_ytdlp_pot_provider'); \
pkg_dir = os.path.dirname(spec.origin) if spec else None; \
js = next((os.path.join(r,f) for r,d,files in os.walk(pkg_dir or '') for f in files if f.endswith('.js')), None) if pkg_dir else None; \
subprocess.Popen(['node', js]) if js else print('bgutil JS not found, continuing without PO token server'); \
\" && \
    sleep 3 && \
    echo 'Starting FastAPI...' && \
    python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 \
"
