#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# VM setup script for OpenClaw Voice Transcription System
# Installs dependencies, Tailscale, voice-transcriber bot, and OpenClaw agent.
# ──────────────────────────────────────────────────────────────────────────────

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root:  sudo ./setup.sh"
  exit 1
fi

echo "=== OpenClaw Voice – VM Setup ==="
echo ""

# ── 1. System update ────────────────────────────────────────────────────────
echo "[1/8] Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq

# ── 2. Dependencies ─────────────────────────────────────────────────────────
echo "[2/8] Installing dependencies (Node.js, ffmpeg, curl, git)..."

# Node.js 18+ (required for global fetch)
if ! command -v node &>/dev/null || [ "$(node -e 'process.exit(process.version.startsWith("v18")||process.version.startsWith("v20")||process.version.startsWith("v22")?0:1)')" -ne 0 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
fi
apt-get install -y -qq nodejs ffmpeg curl git build-essential

# ── 3. Tailscale ─────────────────────────────────────────────────────────────
if ! command -v tailscale &>/dev/null; then
  echo "[3/8] Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "[3/8] Tailscale already installed."
fi
echo ""
echo "  ⚠  IMPORTANT: Authenticate Tailscale:"
echo "     sudo tailscale up"
echo ""

# ── 4. Service user ──────────────────────────────────────────────────────────
echo "[4/8] Creating openclaw service user..."
if ! id -u openclaw &>/dev/null; then
  useradd --system --home-dir /opt/openclaw --shell /usr/sbin/nologin openclaw
fi

# ── 5. Voice transcriber bot ─────────────────────────────────────────────────
echo "[5/8] Setting up voice-transcriber bot..."

mkdir -p /opt/voice-transcriber
cp -r "$SCRIPTDIR/voice-transcriber/"* /opt/voice-transcriber/
chown -R openclaw:openclaw /opt/voice-transcriber

cd /opt/voice-transcriber
npm install --production

# ── 6. OpenClaw agent ────────────────────────────────────────────────────────
echo "[6/8] Setting up OpenClaw agent (Lucy)..."

mkdir -p /opt/openclaw/logs

# Copy config template if user hasn't provided one
if [ ! -f /opt/openclaw/openclaw.json ]; then
  cp "$SCRIPTDIR/openclaw-config/openclaw.json.example" /opt/openclaw/openclaw.json
  echo "  → Created /opt/openclaw/openclaw.json from template."
  echo "    ⚠  You MUST edit this file with your Discord bot token."
fi

# Check if OpenClaw is already installed (user may have cloned it)
if [ ! -f /opt/openclaw/index.js ]; then
  echo ""
  echo "  ⚠  OpenClaw is not installed yet."
  echo "     Install OpenClaw by following the official guide:"
  echo "     https://docs.openclaw.ai/installation  (or your OpenClaw source)"
  echo ""
  echo "     Quick install (if OpenClaw is on npm):"
  echo "       cd /opt/openclaw && npm init -y && npm install openclaw"
  echo ""
  echo "     Or clone from your OpenClaw repository:"
  echo "       git clone <your-openclaw-repo-url> /opt/openclaw"
  echo "       cd /opt/openclaw && npm install"
  echo ""
fi

chown -R openclaw:openclaw /opt/openclaw

# ── 7. Systemd services ──────────────────────────────────────────────────────
echo "[7/8] Installing systemd services..."

cp "$SCRIPTDIR/services/voice-transcriber.service" /etc/systemd/system/
cp "$SCRIPTDIR/services/openclaw-gateway.service" /etc/systemd/system/

systemctl daemon-reload

# Enable services (will fail to start until configured, that's OK)
systemctl enable voice-transcriber
systemctl enable openclaw-gateway

# ── 8. Summary ───────────────────────────────────────────────────────────────
echo ""
echo "[8/8] Setup complete!"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  BEFORE STARTING SERVICES, YOU MUST:"
echo ""
echo "  1. Authenticate Tailscale:"
echo "       sudo tailscale up"
echo ""
echo "  2. Edit the voice-transcriber config:"
echo "       nano /opt/voice-transcriber/.env"
echo "     → Set DISCORD_TOKEN to your Discord bot token"
echo "     → Set WHISPER_API_URL to http://<MAC_TAILSCALE_IP>:8080/inference"
echo ""
echo "  3. Edit the OpenClaw config:"
echo "       nano /opt/openclaw/openclaw.json"
echo "     → Set discordToken to the SAME Discord bot token"
echo ""
echo "  4. Install OpenClaw if you haven't already (see step 6 above)"
echo ""
echo "  5. Start services:"
echo "       sudo systemctl start voice-transcriber"
echo "       sudo systemctl start openclaw-gateway"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Useful commands:"
echo "  Status:   systemctl status voice-transcriber"
echo "            systemctl status openclaw-gateway"
echo "  Logs:     journalctl -u voice-transcriber -f"
echo "            journalctl -u openclaw-gateway -f"
echo "  Restart:  sudo systemctl restart voice-transcriber"
echo "            sudo systemctl restart openclaw-gateway"