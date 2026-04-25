#!/bin/bash
set -e

echo "=== ClipAI Downloader Starting ==="

# Find bgutil JS server file installed by pip package
BGUTIL_JS=$(find /usr/local/lib/python3.11/site-packages -name "*.js" 2>/dev/null | grep -i bgutil | head -1)

if [ -n "$BGUTIL_JS" ]; then
    echo "Starting bgutil PO token server: $BGUTIL_JS"
    node "$BGUTIL_JS" &
    sleep 3
    echo "✓ bgutil server started on port 4416"
else
    echo "WARNING: bgutil JS not found, trying npm install..."
    npm install -g @ybd-project/bgutil-ytdlp-pot-provider 2>/dev/null || true
    BGUTIL_JS=$(find /usr/local/lib -name "*.js" 2>/dev/null | grep -i bgutil | head -1)
    if [ -n "$BGUTIL_JS" ]; then
        node "$BGUTIL_JS" &
        sleep 3
        echo "✓ bgutil server started"
    else
        echo "WARNING: Could not start bgutil server, continuing without PO tokens"
    fi
fi

echo "Starting FastAPI on port 8000..."
exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
