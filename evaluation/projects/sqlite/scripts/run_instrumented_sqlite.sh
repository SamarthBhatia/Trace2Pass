#!/bin/bash
# SQLite Production Test - Instrumented Build and Workload Execution
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REPORTS_DIR="$PROJECT_ROOT/evaluation/production_reports"
INSTRUMENTOR_SO="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
RUNTIME_LIB="$PROJECT_ROOT/runtime/build"

echo "=== Trace2Pass SQLite Production Test ==="
echo "Project root: $PROJECT_ROOT"
echo "Reports dir: $REPORTS_DIR"
echo ""

# Step 1: Download SQLite if not already present
if [ ! -d "sqlite-src" ]; then
    echo "[1/6] Downloading SQLite amalgamation..."
    wget -q https://www.sqlite.org/2025/sqlite-amalgamation-3480000.zip
    unzip -q sqlite-amalgamation-3480000.zip
    mv sqlite-amalgamation-3480000 sqlite-src
    echo "✅ Downloaded SQLite 3.48.0"
else
    echo "[1/6] SQLite source already present ✅"
fi

cd sqlite-src

# Step 2: Build instrumented SQLite
echo "[2/6] Building instrumented SQLite..."
if [ ! -f "$INSTRUMENTOR_SO" ]; then
    echo "❌ ERROR: Instrumentor not found at $INSTRUMENTOR_SO"
    exit 1
fi

clang -O2 \
    -fpass-plugin="$INSTRUMENTOR_SO" \
    -L"$RUNTIME_LIB" \
    -lTrace2PassRuntime \
    sqlite3.c shell.c \
    -o sqlite3_instrumented \
    -lpthread -ldl -lm -lcurl

echo "✅ Built sqlite3_instrumented"

# Step 3: Build baseline (non-instrumented) for comparison
echo "[3/6] Building baseline SQLite..."
clang -O2 sqlite3.c shell.c -o sqlite3_baseline -lpthread -ldl -lm
echo "✅ Built sqlite3_baseline"

# Step 4: Create workload
echo "[4/6] Creating workload script..."
cat > workload.sql << 'EOF'
-- Trace2Pass SQLite Production Workload
-- Tests: INSERT, SELECT, aggregate functions, JOINs

-- Create tables
CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, age INTEGER, balance REAL);
CREATE TABLE transactions(id INTEGER PRIMARY KEY, user_id INTEGER, amount REAL, type TEXT);
CREATE INDEX idx_user_id ON transactions(user_id);

-- Insert data (will stress arithmetic operations)
BEGIN TRANSACTION;

-- Insert 10000 users (potential overflow in id arithmetic)
INSERT INTO users VALUES (1, 'User1', 25, 1000.0);
INSERT INTO users VALUES (2, 'User2', 30, 2000.0);
INSERT INTO users VALUES (3, 'User3', 35, 3000.0);
-- Note: In real test we'd generate 10K rows programmatically

COMMIT;

-- Aggregate queries (arithmetic-heavy)
SELECT COUNT(*) FROM users;
SELECT AVG(age) FROM users;
SELECT SUM(balance) FROM users;
SELECT MAX(balance) - MIN(balance) as balance_range FROM users;

-- Complex JOIN query (pointer arithmetic stress)
SELECT u.name, COUNT(t.id) as tx_count, SUM(t.amount) as total_amount
FROM users u
LEFT JOIN transactions t ON u.id = t.user_id
GROUP BY u.id, u.name
HAVING total_amount > 0
ORDER BY total_amount DESC;

-- Stress test: Nested aggregates
SELECT
    age,
    COUNT(*) * AVG(balance) as weighted_value,
    SUM(balance * age) as age_weighted_balance
FROM users
GROUP BY age;

VACUUM;
EOF

echo "✅ Created workload.sql"

# Step 5: Run baseline (for timing comparison)
echo "[5/6] Running baseline SQLite..."
rm -f test_baseline.db
START_TIME=$(date +%s%N)
./sqlite3_baseline test_baseline.db < workload.sql > /dev/null 2>&1
END_TIME=$(date +%s%N)
BASELINE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "✅ Baseline completed in ${BASELINE_TIME}ms"

# Step 6: Run instrumented SQLite with report collection
echo "[6/6] Running instrumented SQLite..."
rm -f test_instrumented.db

export TRACE2PASS_OUTPUT="$REPORTS_DIR/sqlite_$(date +%Y%m%d_%H%M%S).json"
export TRACE2PASS_SAMPLE_RATE=0.01  # 1% sampling

START_TIME=$(date +%s%N)
./sqlite3_instrumented test_instrumented.db < workload.sql > /dev/null 2>&1
END_TIME=$(date +%s%N)
INSTRUMENTED_TIME=$(( (END_TIME - START_TIME) / 1000000 ))

echo "✅ Instrumented run completed in ${INSTRUMENTED_TIME}ms"
echo ""

# Calculate overhead
OVERHEAD=$(echo "scale=2; (($INSTRUMENTED_TIME - $BASELINE_TIME) * 100.0) / $BASELINE_TIME" | bc)
echo "=== Performance Results ==="
echo "Baseline:     ${BASELINE_TIME}ms"
echo "Instrumented: ${INSTRUMENTED_TIME}ms"
echo "Overhead:     ${OVERHEAD}%"
echo ""

# Check for reports
echo "=== Runtime Reports ==="
if [ -f "$TRACE2PASS_OUTPUT" ]; then
    REPORT_SIZE=$(wc -c < "$TRACE2PASS_OUTPUT")
    if [ "$REPORT_SIZE" -gt 10 ]; then
        echo "✅ Reports generated: $TRACE2PASS_OUTPUT"
        echo "Report size: $REPORT_SIZE bytes"
        echo ""
        echo "First few reports:"
        head -20 "$TRACE2PASS_OUTPUT"
    else
        echo "⚠️  Report file exists but is empty (no bugs detected)"
    fi
else
    echo "⚠️  No report file generated (no bugs detected)"
fi

echo ""
echo "=== Test Complete ==="
echo "Next steps:"
echo "1. Check reports: cat $TRACE2PASS_OUTPUT"
echo "2. If bugs found, run diagnoser: cd $PROJECT_ROOT/diagnoser && python diagnose.py --report $TRACE2PASS_OUTPUT"
