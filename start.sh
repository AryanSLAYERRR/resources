
TS_KEY=""
DOCKER_PROXY_IP="aws-proxy-box" 
WALLET="85RcBrmqpB2TboWNtPUEzTLR5QVqZSiTPdq1fTiGdwvmC5E2rUzovKqArdYToBEZWz3qxthgoi2n41SJHJPN9amC9HCQbk8"
if [ ! -f "./tailscale" ]; then
    echo "Downloading Tailscale for ARM64..."
    wget -q https://pkgs.tailscale.com/stable/tailscale_latest_arm64.tgz
    tar xzf tailscale_latest_arm64.tgz --strip-components=1
    chmod +x tailscale tailscaled
fi


echo "Starting Tailscale in Userspace Mode..."
./tailscaled --tun=userspace-networking --socket=ts.sock --state=ts.state --socks5-server=localhost:1055 &
sleep 5

echo "Connecting to New Tailnet..."
./tailscale --socket=ts.sock up --authkey='tskey-auth-krr1zi8Ndc11CNTRL-j1o9tRQKxydZfgXZ62x2ydxncLSYuonXM' --hostname="aws-arm-3" --accept-dns=false
sleep 5

echo "Launching with your existing miner logic..."
