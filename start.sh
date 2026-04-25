#!/bin/bash
set -e

echo "=== ClipAI Downloader Starting ==="

# Step 1: Generate WARP credentials if not already present
if [ ! -f /config/wgcf-account.toml ]; then
    echo "Generating WARP credentials..."
    mkdir -p /config
    cd /config
    wgcf register --accept-tos
    wgcf generate
    echo "WARP credentials generated."
else
    echo "Using existing WARP credentials."
    cd /config
fi

# Step 2: Bring up WireGuard tunnel using WARP config
echo "Bringing up WireGuard (WARP)..."
cp /config/wgcf-profile.conf /etc/wireguard/wg0.conf

# Remove DNS lines that can cause issues in containers
sed -i '/^DNS/d' /etc/wireguard/wg0.conf

# Add routing rule to only route non-local traffic through WARP
# This prevents the container's management traffic from breaking
sed -i 's|AllowedIPs = 0.0.0.0/0, ::/0|AllowedIPs = 0.0.0.0/1, 128.0.0.0/1|' /etc/wireguard/wg0.conf

wg-quick up wg0 || echo "WireGuard warning (may still work)"

# Step 3: Wait for WARP to connect
echo "Waiting for WARP connection..."
for i in $(seq 1 30); do
    if curl -s --max-time 5 https://cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -q "warp=on"; then
        echo "✓ WARP connected!"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 2
done

# Step 4: Start Squid proxy
echo "Starting Squid proxy on port 8080..."
squid -f /etc/squid/squid.conf
sleep 2

# Verify Squid is running
if ! pgrep squid > /dev/null; then
    echo "WARNING: Squid failed to start, trying alternative..."
    squid -f /etc/squid/squid.conf -N &
fi

# Step 5: Test the proxy
echo "Testing proxy..."
if curl -s -x http://127.0.0.1:8080 --max-time 10 https://cloudflare.com/cdn-cgi/trace | grep -q "warp=on"; then
    echo "✓ Proxy working with WARP!"
else
    echo "WARNING: Proxy test failed, but continuing..."
fi

# Step 6: Start FastAPI app
echo "Starting FastAPI downloader on port 8000..."
exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
