# OpenClaw Voice Transcription Setup

Complete setup for voice transcription system with OpenClaw agent "Lucy" on Discord, using Whisper transcription service on macOS and voice transcriber bot in Ubuntu VM.

**GitHub Repository**: https://github.com/opends007-prog/openclaw-voice-setup

## Overview

This setup includes:
- **Mac M1** running whisper-server
- **Ubuntu VM** (via Orbstack) running:
  - OpenClaw agent "Lucy" connected to Discord
  - Voice transcriber bot that sends audio to Mac's whisper-server
- **Tailscale** networking between Mac and VM

## Prerequisites

1. Mac M1 with Homebrew installed
2. Orbstack installed on Mac (for Ubuntu VM)
3. Tailscale account
4. Discord bot token for OpenClaw
5. Ubuntu 22.04 LTS (recommended for Orbstack VM)
6. Git (for cloning this repository)

## Repository Structure

```
├── README.md                   # This file
├── mac/                        # Mac setup files
│   ├── install.sh              # Install whisper-server and dependencies
│   ├── whisper-server.plist    # launchd service file
│   └── .env.example            # Example environment variables
├── vm/                         # VM setup files
│   ├── setup.sh                # Complete VM setup script
│   ├── voice-transcriber/      # Bot source code
│   │   ├── index.js            # Voice transcriber bot
│   │   ├── package.json
│   │   └── .env.example
│   ├── openclaw-config/        # OpenClaw configuration
│   │   └── openclaw.json.example
│   └── services/               # Service configuration files
│       ├── voice-transcriber.service
│       └── openclaw-gateway.service
├── orbstack/
│   └── setup-instructions.md   # Orbstack VM creation steps
└── tailscale/
    └── setup-instructions.md   # Tailscale installation and auth
```

## Setup Instructions

### 1. Get the Repository

On any computer (your Mac or another device):

```bash
# Clone the repository
git clone https://github.com/opends007-prog/openclaw-voice-setup.git
cd openclaw-voice-setup
```

### 2. Mac Setup

1. Navigate to the `mac/` directory:
   ```bash
   cd mac
   ```

2. Copy the example environment file and edit it:
   ```bash
   cp .env.example .env
   # Edit .env to set your preferences (optional - defaults work)
   ```

3. Run the install script:
   ```bash
   ./install.sh
   ```

4. Verify whisper-server is running:
   ```bash
   sudo launchctl list | grep whisper
   curl http://localhost:8080/inference -X POST -H "Content-Type: audio/wav" --data-binary @test.wav
   ```

### 3. Orbstack VM Setup

1. Follow instructions in `orbstack/setup-instructions.md` to create Ubuntu VM

2. Copy this repository to the VM:
   ```bash
   # From your Mac, assuming VM IP is 192.168.64.2
   scp -r . ubuntu@192.168.64.2:~/
   # Or if you're already on the VM, you cloned it directly
   ```

### 4. Tailscale Setup

1. Follow instructions in `tailscale/setup-instructions.md` to:
   - Install Tailscale on both Mac and VM
   - Authenticate with your Tailscale account
   - Note the Tailscale IP of your Mac (should be 100.67.79.42)

### 5. VM Setup

1. Navigate to the `vm/` directory in the VM:
   ```bash
   cd ~/openclaw-voice-setup/vm
   ```

2. Copy the example environment files and edit them:
   ```bash
   cp voice-transcriber/.env.example voice-transcriber/.env
   cp openclaw-config/openclaw.json.example openclaw-config/openclaw.json
   # Edit .env files to set your tokens and Tailscale IP
   # IMPORTANT: Set WHISPER_API_URL to http://[YOUR_MAC_TAILSCALE_IP]:8080/inference
   ```

3. Run the setup script:
   ```bash
   chmod +x setup.sh
   sudo ./setup.sh
   ```

## Configuration Details

### Environment Files to Customize:

**Mac (.env)**:
```
WHISPER_MODEL_PATH=/usr/local/share/whisper.cpp/ggml-medium.en.bin
WHISPER_PORT=8080
TAILSCALE_MAC_IP=100.67.79.42
```

**VM Voice Transcriber (.env)**:
```
VOICE_BOT_TOKEN=your_discord_bot_token_here
WHISPER_API_URL=http://100.67.79.42:8080/inference  # UPDATE WITH YOUR MAC'S TAILSCALE IP
```

**VM OpenClaw Config (openclaw.json)**:
```json
{
  "agentName": "Lucy",
  "discordToken": "your_discord_bot_token_here",
  // ... other settings
}
```

## Troubleshooting

### Check Service Status

On Mac:
```bash
sudo launchctl list | grep whisper
```

On VM:
```bash
systemctl status voice-transcriber
systemctl status openclaw-gateway
```

### Check Logs

On Mac:
```bash
sudo tail -f /var/log/whisper-server.log
```

On VM:
```bash
sudo journalctl -u voice-transcriber -f
sudo journalctl -u openclaw-gateway -f
```

### Testing Connection

Test transcription from VM to Mac:
```bash
# Replace 100.67.79.42 with your Mac's Tailscale IP
curl http://100.67.79.42:8080/inference -X POST -H "Content-Type: audio/wav" --data-binary @test.wav
```

## Updating

To update the system, pull the latest changes and re-run the setup scripts:
```bash
git pull
cd mac && ./install.sh  # On Mac
cd vm && sudo ./setup.sh  # On VM
```