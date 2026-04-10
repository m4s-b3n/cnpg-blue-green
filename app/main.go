package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/lib/pq"
)

const createTableSQL = `CREATE TABLE IF NOT EXISTS demo_log (
	id SERIAL PRIMARY KEY,
	ts TIMESTAMPTZ DEFAULT now(),
	msg TEXT
)`

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	db := connectWithBackoff(ctx, dsn)
	if db == nil {
		return
	}
	defer db.Close()

	if err := ensureTable(ctx, db); err != nil {
		log.Fatalf("failed to create table: %v", err)
	}

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			fmt.Printf("[%s] Shutting down gracefully\n", ts())
			return
		case <-ticker.C:
			writeAndCount(ctx, db, dsn)
		}
	}
}

func connectWithBackoff(ctx context.Context, dsn string) *sql.DB {
	const retryInterval = time.Second

	for {
		select {
		case <-ctx.Done():
			return nil
		default:
		}

		db, err := sql.Open("postgres", dsn)
		if err != nil {
			fmt.Printf("[%s] CONNECT FAIL | error=%s\n", ts(), err)
			sleep(ctx, retryInterval)
			continue
		}

		db.SetMaxOpenConns(5)
		db.SetMaxIdleConns(2)
		db.SetConnMaxLifetime(30 * time.Second)
		db.SetConnMaxIdleTime(5 * time.Second)

		if err := db.PingContext(ctx); err != nil {
			fmt.Printf("[%s] CONNECT FAIL | error=%s\n", ts(), err)
			db.Close()
			sleep(ctx, retryInterval)
			continue
		}

		fmt.Printf("[%s] Connected to PostgreSQL\n", ts())
		return db
	}
}

func ensureTable(ctx context.Context, db *sql.DB) error {
	_, err := db.ExecContext(ctx, createTableSQL)
	return err
}

func writeAndCount(ctx context.Context, db *sql.DB, dsn string) {
	start := time.Now()

	msg := fmt.Sprintf("heartbeat from demo-logger at %s", ts())
	_, err := db.ExecContext(ctx, "INSERT INTO demo_log (msg) VALUES ($1)", msg)

	if err != nil {
		latency := time.Since(start)
		fmt.Printf("[%s] WRITE FAIL | error=%s | latency=%s\n", ts(), err, fmtLatency(latency))
		reconnect(ctx, db, dsn)
		return
	}

	var count int64
	err = db.QueryRowContext(ctx, "SELECT count(*) FROM demo_log").Scan(&count)
	latency := time.Since(start)

	if err != nil {
		fmt.Printf("[%s] READ FAIL | error=%s | latency=%s\n", ts(), err, fmtLatency(latency))
		return
	}

	fmt.Printf("[%s] WRITE ok | rows=%d | latency=%s\n", ts(), count, fmtLatency(latency))
}

func reconnect(ctx context.Context, db *sql.DB, dsn string) {
	const retryInterval = 500 * time.Millisecond

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		sleep(ctx, retryInterval)

		if err := db.PingContext(ctx); err != nil {
			fmt.Printf("[%s] RECONNECT FAIL | error=%s\n", ts(), err)
			continue
		}

		fmt.Printf("[%s] Reconnected to PostgreSQL\n", ts())
		return
	}
}

func ts() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func fmtLatency(d time.Duration) string {
	return fmt.Sprintf("%dms", d.Milliseconds())
}

func sleep(ctx context.Context, d time.Duration) {
	select {
	case <-ctx.Done():
	case <-time.After(d):
	}
}
