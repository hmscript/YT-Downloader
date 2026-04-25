FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system deps
RUN apt-get update && apt-get install -y \
    curl wget git python3 python3-pip \
    ffmpeg wireguard-tools iproute2 \
    squid iptables net-tools \
    ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install wgcf (latest v2.2.29)
RUN curl -fsSL https://github.com/ViRb3/wgcf/releases/download/v2.2.29/wgcf_2.2.29_linux_amd64 \
    -o /usr/local/bin/wgcf && chmod +x /usr/local/bin/wgcf

# Install yt-dlp (latest)
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp

# Install Python deps
RUN pip3 install fastapi uvicorn httpx

# Configure Squid
COPY squid.conf /etc/squid/squid.conf

# Copy app files
COPY start.sh /start.sh
RUN chmod +x /start.sh
COPY main.py /app/main.py

WORKDIR /app

EXPOSE 8000

CMD ["/start.sh"]
