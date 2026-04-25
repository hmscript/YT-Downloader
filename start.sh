#!/bin/bash
set -e

echo "=== ClipAI Downloader Starting ==="

# Find the built bgutil server JS file
echo "Looking for bgutil server..."
find /bgutil -name "*.js" 2>/dev/null | grep -v node_modules | head -20

# Try known locations
BGUTIL_JS=""
for path in \
    "/bgutil/server/build/main.js" \
    "/bgutil/server/dist/main.js" \
    "/bgutil/server/out/main.js" \
    "/bgutil/server/index.js" \
    "/bgutil/server/main.js"; do
    if [ -f "$path" ]; then
        BGUTIL_JS="$path"
        echo "Found bgutil server at: $path"
        break
    fi
done

if [ -n "$BGUTIL_JS" ]; then
    echo "Starting bgutil PO token server..."
    node "$BGUTIL_JS" &
    BGUTIL_PID=$!
    sleep 3
    if kill -0 $BGUTIL_PID 2>/dev/null; then
        echo "✓ bgutil server running on port 4416"
    else
        echo "WARNING: bgutil server exited"
    fi
else
    echo "WARNING: bgutil server JS not found, listing /bgutil:"
    ls -la /bgutil/server/ 2>/dev/null || echo "  /bgutil/server not found"
    ls -la /bgutil/server/build/ 2>/dev/null || echo "  /bgutil/server/build not found"
fi

echo "Starting FastAPI on port 8000..."
cd /app
exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
