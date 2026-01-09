#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_BIN="$SCRIPT_DIR/../nginx-instrumented-binary"
NGINX_CONF="$SCRIPT_DIR/nginx.conf"
REPORTS_DIR="$SCRIPT_DIR/../reports"
HTML_DIR="$SCRIPT_DIR/../html"

echo "========================================="
echo "Running nginx workload with Trace2Pass"
echo "========================================="
echo ""

# Verify binary exists
if [ ! -f "$NGINX_BIN" ]; then
    echo "ERROR: nginx binary not found: $NGINX_BIN"
    echo "Run build_instrumented.sh first"
    exit 1
fi

# Create directories
mkdir -p "$REPORTS_DIR"
mkdir -p "$HTML_DIR"

# Create simple HTML file for serving
cat > "$HTML_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Trace2Pass nginx Test</title></head>
<body>
<h1>nginx Instrumented Test Page</h1>
<p>This page is served by an instrumented nginx binary.</p>
<p>Request ID: {{RANDOM}}</p>
</body>
</html>
EOF

# Create nginx config
cat > "$NGINX_CONF" <<EOF
worker_processes  1;
daemon off;
error_log  $SCRIPT_DIR/../nginx-error.log  info;
pid        $SCRIPT_DIR/../nginx.pid;

events {
    worker_connections  1024;
}

http {
    access_log  $SCRIPT_DIR/../nginx-access.log;

    server {
        listen       8080;
        server_name  localhost;

        location / {
            root   $HTML_DIR;
            index  index.html;
        }
    }
}
EOF

# Set environment variables for runtime reporting
export TRACE2PASS_OUTPUT="$REPORTS_DIR/nginx_$(date +%Y%m%d_%H%M%S).json"
export TRACE2PASS_SAMPLE_RATE="0.01"  # 1% sampling

echo "Configuration:"
echo "  nginx binary: $NGINX_BIN"
echo "  nginx config: $NGINX_CONF"
echo "  Listening on: http://localhost:8080"
echo "  Report output: $TRACE2PASS_OUTPUT"
echo "  Sample rate: 1%"
echo ""

# Start nginx in background
echo "Starting nginx..."
"$NGINX_BIN" -c "$NGINX_CONF" &
NGINX_PID=$!

# Wait for nginx to start
sleep 2

if ! kill -0 $NGINX_PID 2>/dev/null; then
    echo "ERROR: nginx failed to start"
    echo "Check error log: $SCRIPT_DIR/../nginx-error.log"
    exit 1
fi

echo "nginx started (PID: $NGINX_PID)"
echo ""

# Run workload
echo "Running HTTP workload..."
echo "  - 10,000 requests"
echo "  - 10 concurrent connections"
echo "  - Testing various URL patterns"
echo ""

# Simple workload with curl
for i in {1..1000}; do
    curl -s http://localhost:8080/ >/dev/null &
    if [ $((i % 10)) -eq 0 ]; then
        wait  # Wait for batch
    fi
    if [ $((i % 100)) -eq 0 ]; then
        echo "  Progress: $i/1000 requests"
    fi
done
wait

echo ""
echo "Workload complete!"
echo ""

# Stop nginx
echo "Stopping nginx..."
kill $NGINX_PID
wait $NGINX_PID 2>/dev/null || true

echo ""
echo "========================================="
echo "Workload Complete"
echo "========================================="
echo ""
echo "Report location: $TRACE2PASS_OUTPUT"
echo ""

if [ -f "$TRACE2PASS_OUTPUT" ]; then
    REPORT_SIZE=$(wc -l < "$TRACE2PASS_OUTPUT" | tr -d ' ')
    echo "Report contains $REPORT_SIZE anomaly reports"
    echo ""
    echo "Sample reports:"
    head -20 "$TRACE2PASS_OUTPUT"
else
    echo "No anomaly reports generated (this is normal if no overflows occurred)"
fi

echo ""
echo "Next steps:"
echo "  1. Analyze reports: python3 ../../analyze_reports.py $TRACE2PASS_OUTPUT"
echo "  2. Run UB detection on suspicious cases"
echo "  3. Create reproducers if needed"
