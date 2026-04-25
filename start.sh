#!/bin/bash
set -e

echo "=== ClipAI Downloader Starting ==="

# Start bgutil PO token HTTP server (port 4416)
echo "Starting bgutil PO token server..."
cd /bgutil/server
node build/main.js &
BGUTIL_PID=$!
sleep 3

# Verify it's running
if kill -0 $BGUTIL_PID 2>/dev/null; then
    echo "✓ bgutil server running on port 4416 (PID: $BGUTIL_PID)"
else
    echo "WARNING: bgutil server failed to start"
fi

# Start FastAPI
echo "Starting FastAPI on port 8000..."
cd /app
exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
