#!/bin/bash
set -euo pipefail

echo "Setting up OpenClaw Voice Transcription System on Ubuntu VM"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Source VM directory to find .env files
VM_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$VM_DIR/voice-transcriber/.env" 2>/dev/null || true
source "$VM_DIR/openclaw-config/openclaw.json" 2>/dev/null || true || true

# Update system
echo "Updating system packages..."
apt-get update && apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt-get install -y nodejs npm ffmpeg curl git

# Install Tailscale if not present
if ! command -v tailscale &> /dev/null; then
  echo "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# Create directories
mkdir -p /opt/voice-transcriber
mkdir -p /opt/openclaw

# Copy voice transcriber bot
echo "Setting up voice transcriber bot..."
cp -r "$VM_DIR/voice-transcriber/"* /opt/voice-transcriber/
cd /opt/voice-transcriber
npm install

# Copy OpenClaw config (example - user needs to customize)
echo "Setting up OpenClaw configuration..."
cp "$VM_DIR/openclaw-config/openclaw.json.example" /opt/openclaw/openclaw.json 2>/dev/null || true
cp "$VM_DIR/openclaw-config/openclaw.json" /opt/openclaw/openclaw.json 2>/dev/null || true || true

# Install systemd services
echo "Installing systemd services..."
cp "$VM_DIR/services/voice-transcriber.service" /etc/systemd/system/
cp "$VM_DIR/services/openclaw-gateway.service" /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable and start services
echo "Starting services..."
systemctl enable voice-transcriber
systemctl start voice-transcriber
systemctl enable openclaw-gateway
systemctl start openclaw-gateway

# Wait for services to start
sleep 5

# Check service status
echo "Checking service status..."
systemctl status voice-transcriber --no-pager || true
systemctl status openclaw-gateway --no-pager || true

echo ""
echo "Setup complete!"
echo ""
echo "Important next steps:"
echo "1. Install and authenticate Tailscale on this VM:"
echo "   sudo tailscale up"
echo "2. Edit /opt/voice-transcriber/.env with your actual values:"
echo "   - WHISPER_API_URL: http://[YOUR_MAC_TAILSCALE_IP]:8080/inference"
echo "   - VOICE_BOT_TOKEN: [Your Discord bot token]"
echo "3. Edit /opt/openclaw/openclaw.json with your Discord bot token"
echo "4. Restart services after configuration changes:"
echo "   sudo systemctl restart voice-transcriber"
echo "   sudo systemctl restart openclaw-gateway"
echo ""
echo "To check logs:"
echo "  journalctl -u voice-transcriber -f"
echo "  journalctl -u openclaw-gateway -f"
echo ""
echo "To test transcription from this VM:"
echo "  curl -X POST http://[YOUR_MAC_TAILSCALE_IP]:8080/inference -H \"Content-Type: audio/wav\" --data-binary @test.wav"