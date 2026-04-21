#!/bin/bash
set -euo pipefail

echo "Setting up OpenClaw Voice Transcription System on Mac"

# Check if running as root (launchd plist needs root)
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Source environment variables
source .env

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install whisper.cpp
echo "Installing whisper.cpp..."
brew install whisper.cpp

# Download the model if not already present
MODEL_PATH="${WHISPER_MODEL_PATH:-/usr/local/share/whisper.cpp/ggml-medium.en.bin}"
MODEL_DIR=$(dirname "$MODEL_PATH")

if [ ! -f "$MODEL_PATH" ]; then
  echo "Downloading ggml-medium.en.bin model..."
  mkdir -p "$MODEL_DIR"
  curl -L -o "$MODEL_PATH" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin
  echo "Model downloaded to $MODEL_PATH"
else
  echo "Model already exists at $MODEL_PATH"
fi

# Install Tailscale if not present
if ! command -v tailscale &> /dev/null; then
  echo "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# Create log directory
LOG_DIR="/var/log/whisper-server"
mkdir -p "$LOG_DIR"
touch "$LOG_DIR/whisper-server.log"
chown "$(whoami):admin" "$LOG_DIR/whisper-server.log"

# Copy launchd service file
echo "Installing whisper-server launchd service..."
cp whisper-server.plist /Library/LaunchDaemons/
chown root:wheel /Library/LaunchDaemons/whisper-server.plist
chmod 644 /Library/LaunchDaemons/whisper-server.plist

# Load and start the service
echo "Loading whisper-server service..."
launchctl unload /Library/LaunchDaemons/whisper-server.plist 2>/dev/null || true
launchctl load /Library/LaunchDaemons/whisper-server.plist
launchctl start whisper-server

# Wait a moment for service to start
sleep 3

# Test the endpoint
echo "Testing whisper-server endpoint..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:${WHISPER_PORT:-8080}/inference | grep -q "200\|400"; then
  echo "✓ Whisper-server is responding on port ${WHISPER_PORT:-8080}"
else
  echo "✗ Whisper-server may not be responding correctly"
  echo "Check logs with: tail -f $LOG_DIR/whisper-server.log"
fi

echo ""
echo "Setup complete!"
echo "Whisper-server is now running as a service on port ${WHISPER_PORT:-8080}"
echo "To check status: sudo launchctl list | grep whisper"
echo "To view logs: sudo tail -f $LOG_DIR/whisper-server.log"
echo ""
echo "Remember to:"
echo "1. Install Tailscale and authenticate"
echo "2. Note your Mac's Tailscale IP (should be 100.67.79.42)"
echo "3. Set up the VM using the instructions in vm/setup.sh"