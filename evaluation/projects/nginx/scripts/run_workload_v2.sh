#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_BIN="$SCRIPT_DIR/../nginx-instrumented-binary"
# Use /tmp for runtime files to avoid space issues
NGINX_CONF="/tmp/nginx_test.conf"
REPORTS_DIR="$SCRIPT_DIR/../reports"
HTML_DIR="/tmp/nginx_html"
LOG_DIR="/tmp/nginx_logs"

echo "========================================="
echo "Running nginx workload with Trace2Pass"
echo "========================================="
echo ""

# Verify binary exists
if [ ! -f "$NGINX_BIN" ]; then
    echo "ERROR: nginx binary not found: $NGINX_BIN"
    exit 1
fi

# Create directories
mkdir -p "$REPORTS_DIR"
mkdir -p "$HTML_DIR"
mkdir -p "$LOG_DIR"

# Create simple HTML file
cat > "$HTML_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Trace2Pass nginx Test</title></head>
<body>
<h1>nginx Instrumented Test Page</h1>
<p>This page is served by an instrumented nginx binary.</p>
</body>
</html>
EOF

# Create nginx config (using /tmp paths - no spaces!)
cat > "$NGINX_CONF" <<EOF
worker_processes  1;
daemon off;
error_log  $LOG_DIR/error.log  info;
pid        $LOG_DIR/nginx.pid;

events {
    worker_connections  1024;
}

http {
    access_log  $LOG_DIR/access.log;

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

# Set environment variables
export TRACE2PASS_OUTPUT="$REPORTS_DIR/nginx_$(date +%Y%m%d_%H%M%S).json"
export TRACE2PASS_SAMPLE_RATE="0.01"

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
    echo "Error log:"
    cat "$LOG_DIR/error.log" 2>/dev/null || echo "(no error log)"
    exit 1
fi

echo "nginx started (PID: $NGINX_PID)"
echo ""

# Run workload
echo "Running HTTP workload (1,000 requests)..."
for i in {1..1000}; do
    curl -s http://localhost:8080/ >/dev/null &
    if [ $((i % 10)) -eq 0 ]; then
        wait
    fi
    if [ $((i % 100)) -eq 0 ]; then
        printf "."
    fi
done
wait
echo " done!"

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
    echo "✅ Report contains $REPORT_SIZE anomaly reports"
    echo ""
    if [ "$REPORT_SIZE" -gt 0 ]; then
        echo "Sample reports:"
        head -10 "$TRACE2PASS_OUTPUT"
    fi
else
    echo "ℹ️  No anomaly reports generated"
    echo "(This is expected if no arithmetic overflows occurred)"
fi

echo ""
echo "Logs:"
echo "  Error log: $LOG_DIR/error.log"
echo "  Access log: $LOG_DIR/access.log"
echo ""
echo "Next steps:"
echo "  1. Analyze reports (if any)"
echo "  2. Run UB detection on suspicious cases"
echo "  3. Create reproducers if needed"
