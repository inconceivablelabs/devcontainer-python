#!/usr/bin/env bash
# Start a shared Dolt SQL server for Beads task tracking.
# Called by devcontainer postStartCommand on every container start.
#
# Architecture:
#   - Server root: /home/vscode/.dolt-server/ (Docker volume, persistent)
#   - All project databases live here (created by bd init)
#   - One server on port 3307 serves all projects
set -euo pipefail

DOLT_ROOT="/home/vscode/.dolt-server"
DOLT_PORT=3307
DOLT_LOG="$DOLT_ROOT/sql-server.log"
DOLT_PID_FILE="$DOLT_ROOT/sql-server.pid"

# --- Prerequisites ---

if ! command -v dolt &>/dev/null; then
    echo "[start-dolt] dolt not found, skipping server startup"
    exit 0
fi

# --- Initialize server root (idempotent) ---

if [ ! -d "$DOLT_ROOT/.dolt" ]; then
    mkdir -p "$DOLT_ROOT"

    # Configure Dolt identity from git config (or defaults)
    DOLT_USER_NAME=$(git config --global user.name 2>/dev/null || echo "devcontainer")
    DOLT_USER_EMAIL=$(git config --global user.email 2>/dev/null || echo "dev@localhost")
    dolt config --global --add user.name "$DOLT_USER_NAME" 2>/dev/null || true
    dolt config --global --add user.email "$DOLT_USER_EMAIL" 2>/dev/null || true

    cd "$DOLT_ROOT" && dolt init --name "$DOLT_USER_NAME" --email "$DOLT_USER_EMAIL"
    echo "[start-dolt] Initialized server root at $DOLT_ROOT"
fi

# --- Check if server is already running ---

if [ -f "$DOLT_PID_FILE" ]; then
    OLD_PID=$(cat "$DOLT_PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[start-dolt] Dolt server already running (PID $OLD_PID)"
        exit 0
    fi
    rm -f "$DOLT_PID_FILE"
fi

# Also check if something else is on the port
if ss -tlnp 2>/dev/null | grep -q ":${DOLT_PORT} "; then
    echo "[start-dolt] Port $DOLT_PORT already in use, skipping"
    exit 0
fi

# --- Start server ---

cd "$DOLT_ROOT"
nohup dolt sql-server --host 127.0.0.1 --port "$DOLT_PORT" \
    >>"$DOLT_LOG" 2>&1 &
echo $! > "$DOLT_PID_FILE"

# Wait for server to be ready (up to 10 seconds)
for i in $(seq 1 20); do
    if ss -tlnp 2>/dev/null | grep -q ":${DOLT_PORT} "; then
        echo "[start-dolt] Dolt server started (PID $(cat $DOLT_PID_FILE), port $DOLT_PORT)"
        exit 0
    fi
    sleep 0.5
done

echo "[start-dolt] WARNING: Dolt server may not have started. Check $DOLT_LOG"
exit 1
