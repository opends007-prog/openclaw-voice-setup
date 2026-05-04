#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Mac setup script for OpenClaw Voice Transcription System
# Installs whisper.cpp, downloads the model, configures Tailscale,
# and registers whisper-server as a launchd service.
# ──────────────────────────────────────────────────────────────────────────────

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/.env" 2>/dev/null || true

MODEL_PATH="${WHISPER_MODEL_PATH:-/usr/local/share/whisper.cpp/ggml-medium.en.bin}"
WHISPER_PORT="${WHISPER_PORT:-8080}"
MODEL_DIR="$(dirname "$MODEL_PATH")"
LOG_DIR="/var/log/whisper-server"

echo "=== OpenClaw Voice – Mac Setup ==="
echo ""

# ── 1. Homebrew ──────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "[1/6] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "[1/6] Homebrew already installed."
fi

# ── 2. whisper.cpp ───────────────────────────────────────────────────────────
echo "[2/6] Installing whisper.cpp..."
brew install whisper.cpp 2>/dev/null || brew upgrade whisper.cpp 2>/dev/null || true

# Detect correct binary path (Apple Silicon vs Intel)
if [ -f "/opt/homebrew/bin/whisper-server" ]; then
  WHISPER_BIN="/opt/homebrew/bin/whisper-server"
elif [ -f "/usr/local/bin/whisper-server" ]; then
  WHISPER_BIN="/usr/local/bin/whisper-server"
else
  echo "ERROR: whisper-server binary not found after install."
  exit 1
fi
echo "  → whisper-server at $WHISPER_BIN"

# ── 3. Model ─────────────────────────────────────────────────────────────────
if [ -f "$MODEL_PATH" ]; then
  echo "[3/6] Model already exists at $MODEL_PATH"
else
  echo "[3/6] Downloading ggml-medium.en.bin (≈ 1.4 GB)..."
  mkdir -p "$MODEL_DIR"
  curl -L --progress-bar -o "$MODEL_PATH" \
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin
  echo "  → Model saved to $MODEL_PATH"
fi

# ── 4. Tailscale ─────────────────────────────────────────────────────────────
if ! command -v tailscale &>/dev/null; then
  echo "[4/6] Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "[4/6] Tailscale already installed."
fi
echo ""
echo "  ⚠  IMPORTANT: Authenticate Tailscale if you haven't already:"
echo "     sudo tailscale up"
echo "     Then note your Tailscale IP:  tailscale ip"
echo "     You will need it when configuring the VM."
echo ""

# ── 5. launchd service ───────────────────────────────────────────────────────
echo "[5/6] Installing whisper-server launchd service..."

# Generate the plist dynamically so paths are correct
PLIST_PATH="/Library/LaunchDaemons/com.openclaw.whisper-server.plist"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.openclaw.whisper-server</string>
  <key>ProgramArguments</key>
  <array>
    <string>${WHISPER_BIN}</string>
    <string>-m</string>
    <string>${MODEL_PATH}</string>
    <string>--port</string>
    <string>${WHISPER_PORT}</string>
    <string>--host</string>
    <string>0.0.0.0</string>
    <string>-t</string>
    <string>8</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/whisper-server.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/whisper-server.log</string>
  <key>WorkingDirectory</key>
  <string>${MODEL_DIR}</string>
</dict>
</plist>
PLIST

# Create log directory
mkdir -p "$LOG_DIR"

# Unload old version if present, then load new
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
launchctl start com.openclaw.whisper-server

echo "  → Service loaded."

# ── 6. Verify ────────────────────────────────────────────────────────────────
echo "[6/6] Verifying..."
sleep 3

if launchctl list | grep -q "com.openclaw.whisper-server"; then
  echo "  ✓ whisper-server service is running."
else
  echo "  ✗ whisper-server service did NOT start. Check logs:"
  echo "    tail -f ${LOG_DIR}/whisper-server.log"
fi

echo ""
echo "=== Mac setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Make sure Tailscale is authenticated:  sudo tailscale up"
echo "  2. Note your Tailscale IP:                tailscale ip"
echo "  3. Set up the VM (see vm/setup.sh)"
echo ""
echo "Commands:"
echo "  Check status:  sudo launchctl list | grep whisper"
echo "  View logs:     tail -f ${LOG_DIR}/whisper-server.log"
echo "  Restart:       sudo launchctl kickstart -k system/com.openclaw.whisper-server"