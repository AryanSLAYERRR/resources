# 1. Capture the key from the command line or environment
TS_KEY="${TS_KEY:-$1}"

# Optional: Stop if no key is found (prevents wasted downloads)
if [ -z "$TS_KEY" ]; then
    echo "Error: No TS_KEY provided."
    exit 1
fi

wget https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-aarch64-static && \
chmod +x xmrig-aarch64-static && \
chmod +x ./start.sh && \

TS_KEY="$TS_KEY" ./start.sh
