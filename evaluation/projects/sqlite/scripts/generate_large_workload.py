#!/usr/bin/env python3
"""Generate a realistic SQLite workload for production testing"""

print("""-- Trace2Pass SQLite Large Production Workload
-- Realistic database operations with arithmetic stress

-- Create tables
CREATE TABLE users(
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    age INTEGER,
    balance REAL,
    signup_timestamp INTEGER
);

CREATE TABLE transactions(
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    amount REAL,
    type TEXT,
    timestamp INTEGER,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE products(
    id INTEGER PRIMARY KEY,
    name TEXT,
    price REAL,
    stock INTEGER,
    category TEXT
);

CREATE INDEX idx_user_id ON transactions(user_id);
CREATE INDEX idx_timestamp ON transactions(timestamp);
CREATE INDEX idx_category ON products(category);

-- Begin bulk insert
BEGIN TRANSACTION;
""")

# Generate 10,000 users (stress arithmetic operations)
import random
import time

for i in range(1, 10001):
    name = f"User{i}"
    email = f"user{i}@example.com"
    age = random.randint(18, 80)
    balance = round(random.uniform(100, 100000), 2)
    timestamp = int(time.time()) - random.randint(0, 31536000)  # Last year

    print(f"INSERT INTO users VALUES ({i}, '{name}', '{email}', {age}, {balance}, {timestamp});")

print("\nCOMMIT;\n")

# Generate 50,000 transactions
print("BEGIN TRANSACTION;")
for i in range(1, 50001):
    user_id = random.randint(1, 10000)
    amount = round(random.uniform(-500, 5000), 2)
    tx_type = random.choice(['deposit', 'withdrawal', 'transfer', 'payment'])
    timestamp = int(time.time()) - random.randint(0, 31536000)

    print(f"INSERT INTO transactions VALUES ({i}, {user_id}, {amount}, '{tx_type}', {timestamp});")

print("\nCOMMIT;\n")

# Generate 1,000 products
print("BEGIN TRANSACTION;")
categories = ['electronics', 'books', 'clothing', 'food', 'toys']
for i in range(1, 1001):
    name = f"Product{i}"
    price = round(random.uniform(5, 1000), 2)
    stock = random.randint(0, 1000)
    category = random.choice(categories)

    print(f"INSERT INTO products VALUES ({i}, '{name}', {price}, {stock}, '{category}');")

print("\nCOMMIT;\n")

# Complex queries that stress arithmetic
print("""
-- Aggregate queries (arithmetic-heavy)
SELECT COUNT(*) as total_users FROM users;
SELECT AVG(age) as avg_age FROM users;
SELECT SUM(balance) as total_balance FROM users;
SELECT MAX(balance) - MIN(balance) as balance_range FROM users;

-- Transaction analysis (multiplication, division)
SELECT
    type,
    COUNT(*) as count,
    AVG(amount) as avg_amount,
    SUM(amount) as total_amount,
    SUM(amount) / COUNT(*) as weighted_avg
FROM transactions
GROUP BY type
HAVING total_amount > 1000;

-- Complex JOIN with aggregates
SELECT
    u.id,
    u.name,
    u.balance,
    COUNT(t.id) as tx_count,
    SUM(t.amount) as total_spent,
    AVG(t.amount) as avg_transaction,
    u.balance - SUM(t.amount) as remaining_balance
FROM users u
LEFT JOIN transactions t ON u.id = t.user_id
GROUP BY u.id, u.name, u.balance
HAVING tx_count > 5
ORDER BY total_spent DESC
LIMIT 100;

-- Product statistics (overflow-prone with stock * price)
SELECT
    category,
    COUNT(*) as product_count,
    AVG(price) as avg_price,
    SUM(stock) as total_stock,
    SUM(stock * price) as inventory_value,
    MAX(stock * price) as max_item_value
FROM products
GROUP BY category
ORDER BY inventory_value DESC;

-- Time-based aggregation (timestamp arithmetic)
SELECT
    strftime('%Y-%m', datetime(timestamp, 'unixepoch')) as month,
    COUNT(*) as tx_count,
    SUM(amount) as monthly_volume,
    AVG(amount) as avg_amount,
    SUM(amount * amount) as sum_of_squares
FROM transactions
GROUP BY month
ORDER BY month DESC;

-- Nested subquery with arithmetic
SELECT
    u.name,
    u.balance,
    (SELECT COUNT(*) FROM transactions t WHERE t.user_id = u.id) as tx_count,
    (SELECT SUM(amount) FROM transactions t WHERE t.user_id = u.id) as total_tx,
    u.balance + (SELECT COALESCE(SUM(amount), 0) FROM transactions t WHERE t.user_id = u.id) as final_balance
FROM users u
WHERE u.balance > 10000
ORDER BY final_balance DESC
LIMIT 50;

-- Window functions (advanced arithmetic)
SELECT
    id,
    user_id,
    amount,
    type,
    SUM(amount) OVER (PARTITION BY user_id ORDER BY timestamp) as running_total,
    AVG(amount) OVER (PARTITION BY user_id ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) as moving_avg
FROM transactions
ORDER BY user_id, timestamp
LIMIT 1000;

-- Stress test: Self-join with multiplication
SELECT
    t1.user_id,
    COUNT(*) as interaction_count,
    SUM(t1.amount * t2.amount) as interaction_score
FROM transactions t1
JOIN transactions t2 ON t1.user_id = t2.user_id AND t1.id != t2.id
GROUP BY t1.user_id
HAVING interaction_count > 10
ORDER BY interaction_score DESC
LIMIT 20;

VACUUM;
ANALYZE;
""")
