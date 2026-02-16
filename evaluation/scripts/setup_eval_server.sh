#!/bin/bash
# Trace2Pass Evaluation Server Setup
# Installs dependencies, builds Docker images, and pre-downloads project sources.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_DIR="/data/project-sources"
DOCKER_DIR="$PROJECT_ROOT/evaluation/docker-images"

echo "=== Trace2Pass Evaluation Server Setup ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# --- Step 1: System dependencies ---
echo "[1/4] Checking system dependencies..."

if ! command -v docker &>/dev/null; then
    echo "Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker
    echo "Docker installed."
else
    echo "Docker already installed: $(docker --version)"
fi

if ! command -v python3 &>/dev/null; then
    echo "Installing Python 3..."
    apt-get update
    apt-get install -y python3 python3-pip python3-venv
else
    echo "Python3 already installed: $(python3 --version)"
fi

echo "Installing Python dependencies..."
pip3 install --quiet flask flask-cors marshmallow requests tabulate

echo "Done."

# --- Step 2: Build trace2pass-eval Docker images ---
echo ""
echo "[2/4] Building trace2pass-eval Docker images..."

LLVM_VERSIONS=(14 16 17 18 19)

for ver in "${LLVM_VERSIONS[@]}"; do
    IMAGE="trace2pass-eval:${ver}"
    if docker image inspect "$IMAGE" &>/dev/null; then
        echo "  Image $IMAGE already exists, skipping."
    else
        echo "  Building $IMAGE ..."
        docker build \
            --build-arg LLVM_VERSION="$ver" \
            -f "$DOCKER_DIR/Dockerfile.trace2pass-eval" \
            -t "$IMAGE" \
            "$PROJECT_ROOT" 2>&1 | tail -1
        echo "  Built $IMAGE"
    fi
done

echo "Done. Available images:"
docker images --filter "reference=trace2pass-eval" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}"

# --- Step 3: Pre-download project sources ---
echo ""
echo "[3/4] Pre-downloading project source tarballs..."

mkdir -p "$DATA_DIR"

declare -A SOURCES=(
    [libjpeg-turbo]="https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.0/libjpeg-turbo-3.1.0.tar.gz"
    [mbedtls]="https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.2/mbedtls-3.6.2.tar.bz2"
    [libpng]="https://downloads.sourceforge.net/libpng/libpng-1.6.44.tar.gz"
    [jemalloc]="https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2"
    [musl]="https://musl.libc.org/releases/musl-1.2.5.tar.gz"
    [libxml2]="https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz"
    [brotli]="https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz"
    [harfbuzz]="https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz"
    [re2]="https://github.com/google/re2/releases/download/2024-07-02/re2-2024-07-02.tar.gz"
    [tcc]="https://download.savannah.gnu.org/releases/tinycc/tcc-0.9.27.tar.bz2"
    [chibicc]="https://github.com/rui314/chibicc/archive/refs/heads/main.tar.gz"
    [8cc]="https://github.com/rui314/8cc/archive/refs/heads/master.tar.gz"
)

for name in "${!SOURCES[@]}"; do
    url="${SOURCES[$name]}"
    dest="$DATA_DIR/$name.tar.gz"
    if [ -f "$dest" ] || [ -f "$DATA_DIR/$name.tar.bz2" ] || [ -f "$DATA_DIR/$name.tar.xz" ]; then
        echo "  $name: already downloaded."
    else
        echo "  $name: downloading..."
        # Determine extension from URL
        ext="${url##*.}"
        case "$ext" in
            bz2) dest="$DATA_DIR/$name.tar.bz2" ;;
            xz)  dest="$DATA_DIR/$name.tar.xz" ;;
            *)   dest="$DATA_DIR/$name.tar.gz" ;;
        esac
        curl -fSL -o "$dest" "$url" 2>/dev/null || echo "    WARNING: Failed to download $name from $url"
    fi
done

echo "Done. Downloaded sources:"
ls -lh "$DATA_DIR/" 2>/dev/null || echo "  (no files yet)"

# --- Step 4: Verify Collector API can start ---
echo ""
echo "[4/4] Verifying Collector API..."

cd "$PROJECT_ROOT"
python3 -c "
import sys
sys.path.insert(0, 'collector/src')
from collector import app
print('Collector Flask app loaded successfully.')
print('Endpoints:')
for rule in app.url_map.iter_rules():
    if rule.endpoint != 'static':
        print(f'  {rule.methods - {\"OPTIONS\", \"HEAD\"}} {rule.rule}')
"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Start Collector: cd $PROJECT_ROOT && python3 collector/src/collector.py &"
echo "  2. Run all benchmarks: $SCRIPT_DIR/evaluate_all_projects.sh"
echo "  3. Aggregate results: python3 $SCRIPT_DIR/aggregate_results.py"
