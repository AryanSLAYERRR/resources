#!/bin/bash
set -Eeuo pipefail

# --- PATHS ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TAILSCALE="$SCRIPT_DIR/tailscale"
TAILSCALED="$SCRIPT_DIR/tailscaled"
XMRIG="$SCRIPT_DIR/xmrig-x86_64-static"
TS_SOCKET="$SCRIPT_DIR/ts.sock"
TS_ARCHIVE="$SCRIPT_DIR/tailscale_latest_amd64.tgz"

# --- CONFIGURATION ---
DOCKER_PROXY_IP="mainproxy"
WALLET="85RcBrmqpB2TboWNtPUEzTLR5QVqZSiTPdq1fTiGdwvmC5E2rUzovKqArdYToBEZWz3qxthgoi2n41SJHJPN9amC9HCQbk8"

TS_KEY="${TS_KEY:-${1:-}}"

if [ -z "$TS_KEY" ]; then
    echo "ERROR: No TS_KEY provided."
    echo "Use: TS_KEY='your-key' ./script86.sh"
    exit 1
fi

TAILSCALED_PID=""

# --- CLEANUP ---
cleanup() {
    echo "Stopping miner and removing node from Tailnet..."

    if [ -S "$TS_SOCKET" ] && [ -x "$TAILSCALE" ]; then
        "$TAILSCALE" --socket="$TS_SOCKET" logout >/dev/null 2>&1 || true
    fi

    if [ -n "$TAILSCALED_PID" ] && kill -0 "$TAILSCALED_PID" 2>/dev/null; then
        kill "$TAILSCALED_PID" 2>/dev/null || true
        wait "$TAILSCALED_PID" 2>/dev/null || true
    fi

    rm -f "$TS_SOCKET"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- 1. HUGE PAGES ---
echo "Configuring huge pages..."

if sysctl -w vm.nr_hugepages=1280; then
    echo "1280 x 2MB huge pages requested."
else
    echo "WARNING: Could not reserve huge pages."
fi

# Try to persist the setting for future runs.
mkdir -p /etc/sysctl.d
echo "vm.nr_hugepages=1280" > /etc/sysctl.d/99-xmrig-hugepages.conf 2>/dev/null || true

# --- 2. MSR ---
echo "Checking MSR support..."

if modprobe msr 2>/dev/null; then
    echo "MSR kernel module loaded."
else
    echo "MSR kernel module unavailable."
fi

if ls /dev/cpu/*/msr >/dev/null 2>&1; then
    echo "MSR devices exist, but this VM may restrict individual MSRs."
else
    echo "No MSR devices exposed."
fi

# This VM is known not to expose usable MSRs.
# XMRig will therefore be explicitly told not to modify MSRs.

# --- 3. DOWNLOAD TAILSCALE ---
if [ ! -x "$TAILSCALE" ] || [ ! -x "$TAILSCALED" ]; then
    echo "Downloading Tailscale for x86_64..."

    rm -f "$TAILS_ARCHIVE" "$TAILSCALE" "$TAILSCALED"

    curl -fL \
        --retry 5 \
        --retry-all-errors \
        --connect-timeout 15 \
        --max-time 180 \
        "https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz" \
        -o "$TAILS_ARCHIVE"

    echo "Validating Tailscale archive..."
    tar -tzf "$TAILS_ARCHIVE" >/dev/null

    echo "Extracting Tailscale..."
    tar -xzf "$TAILS_ARCHIVE" \
        --strip-components=1 \
        -C "$SCRIPT_DIR"

    chmod +x "$TAILSCALE" "$TAILSCALED"

    rm -f "$TAILS_ARCHIVE"
else
    echo "Tailscale already present; skipping download."
fi

# --- 4. DOWNLOAD XMRIG ---
if [ ! -x "$XMRIG" ]; then
    echo "Downloading XMRig for x86_64..."

    curl -fL \
        --retry 5 \
        --retry-all-errors \
        --connect-timeout 15 \
        --max-time 180 \
        "https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static" \
        -o "$XMRIG"

    chmod +x "$XMRIG"
else
    echo "XMRig already present; skipping download."
fi

# --- 5. REMOVE STALE SOCKET ---
rm -f "$TS_SOCKET"

# --- 6. START TAILSCALE ---
echo "Starting Tailscale..."

"$TAILSCALED" \
    --tun=userspace-networking \
    --socket="$TS_SOCKET" \
    --state=mem: \
    --socks5-server=localhost:1055 &

TAILSCALED_PID=$!

# Give daemon a moment to start.
sleep 2

if ! kill -0 "$TAILSCALED_PID" 2>/dev/null; then
    echo "ERROR: tailscaled failed to start."
    exit 1
fi

# --- 7. CONNECT TO TAILNET ---
echo "Connecting to Tailnet..."

"$TAILSCALE" \
    --socket="$TS_SOCKET" \
    up \
    --authkey="$TS_KEY" \
    --hostname="pazi-x86-$RANDOM" \
    --accept-dns=false

echo "Waiting for Tailscale..."

"$TAILSCALE" \
    --socket="$TS_SOCKET" \
    wait \
    --timeout=30s

echo "Tailscale is running."

# --- 8. SHOW NETWORK STATUS ---
"$TAILSCALE" \
    --socket="$TS_SOCKET" \
    status

echo "Launching XMRig..."

# --- 9. START XMRIG ---
"$XMRIG" \
    -c "$SCRIPT_DIR/Config86.json" \
    -o "$DOCKER_PROXY_IP:9999" \
    -u "$WALLET" \
    --proxy "127.0.0.1:1055" \
    --no-tls \
    --rig-id "pazi-aws" \
    --randomx-wrmsr=-1
