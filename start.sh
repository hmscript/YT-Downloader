#!/bin/bash
set -e

echo "=== ClipAI Downloader Starting ==="

mkdir -p /config
cd /config

# Step 1: Register WARP account (ignore 500 errors from Cloudflare - file still gets created)
if [ ! -f /config/wgcf-account.toml ]; then
    echo "Registering WARP account..."
    wgcf register --accept-tos || true
    echo "Registration done (errors above are expected from Cloudflare API)"
fi

# Step 2: Generate WireGuard profile
if [ ! -f /config/wgcf-profile.conf ]; then
    echo "Generating WireGuard profile..."
    wgcf generate || true
fi

# Step 3: Bring up WireGuard
if [ -f /config/wgcf-profile.conf ]; then
    echo "Bringing up WireGuard (WARP)..."
    cp /config/wgcf-profile.conf /etc/wireguard/wg0.conf

    # Remove DNS lines — causes issues in containers
    sed -i '/^DNS/d' /etc/wireguard/wg0.conf

    # Only route internet traffic through WARP, not local
    sed -i 's|AllowedIPs = 0.0.0.0/0, ::/0|AllowedIPs = 0.0.0.0/1, 128.0.0.0/1|' /etc/wireguard/wg0.conf

    wg-quick up wg0 || echo "WireGuard warning — may still work"

    # Wait and check
    echo "Waiting for WARP..."
    for i in $(seq 1 20); do
        if curl -s --max-time 5 https://cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -q "warp=on"; then
            echo "✓ WARP connected!"
            break
        fi
        sleep 2
    done
else
    echo "WARNING: No WireGuard profile found — running without WARP"
fi

# Step 4: Start Squid
echo "Starting Squid proxy..."
squid -f /etc/squid/squid.conf || true
sleep 2

# Step 5: Start FastAPI
echo "Starting FastAPI on port 8000..."
exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
