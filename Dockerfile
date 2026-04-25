FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js, ffmpeg, git
RUN apt-get update && apt-get install -y \
    ffmpeg curl nodejs npm git \
    && rm -rf /var/lib/apt/lists/*

# Install yt-dlp
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp

# Clone and build bgutil server (the PO token HTTP server)
# This generates PO tokens that bypass YouTube's bot detection
RUN git clone --depth 1 --branch 1.3.1 \
    https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git \
    /bgutil && \
    cd /bgutil/server && \
    npm ci && \
    npx tsc

# Install Python deps + yt-dlp PO token plugin
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install bgutil-ytdlp-pot-provider

WORKDIR /app
COPY main.py .
COPY start.sh .
RUN chmod +x start.sh

EXPOSE 8000

CMD ["/app/start.sh"]
