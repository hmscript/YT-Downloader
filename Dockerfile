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

# Install Python deps
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# Install yt-dlp PO token plugins
RUN pip install yt-dlp-get-pot bgutil-ytdlp-pot-provider

# Install and set up bgutil server (generates PO tokens)
RUN pip show bgutil-ytdlp-pot-provider | grep Location | awk '{print $2}' | \
    xargs -I{} find {} -name "*.py" -path "*/bgutil*" | head -5 || true

WORKDIR /app
COPY main.py .
COPY start.sh .
RUN chmod +x start.sh

EXPOSE 8000

CMD ["/app/start.sh"]
