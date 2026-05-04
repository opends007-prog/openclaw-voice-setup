# OpenClaw Voice Transcription Setup

**Repository:** https://github.com/opends007-prog/openclaw-voice-setup

Complete, reproducible setup for a voice-enabled Discord AI agent. A Mac M1 runs whisper.cpp for speech-to-text, and an Ubuntu VM (via Orbstack) runs both the OpenClaw agent "Lucy" and a voice transcriber bot. Tailscale connects the two machines.

## Architecture

```
┌─────────────────────────┐         Tailscale          ┌──────────────────────────────┐
│        Mac M1           │◄──────────────────────────►│       Ubuntu VM              │
│                         │      100.x.y.z             │                              │
│  whisper-server :8080   │  HTTP POST /inference      │  ┌────────────────────────┐  │
│  (ggml-medium.en.bin)   │◄──────────────────────────  │  │  Voice Transcriber Bot │  │
│                         │     audio WAV data          │  │  (captures voice,      │  │
│                         │                             │  │   sends to whisper,    │  │
│                         │                             │  │   posts text to Discord│  │
│                         │                             │  └────────────────────────┘  │
│                         │                             │                              │
│                         │                             │  ┌────────────────────────┐  │
│                         │                             │  │  OpenClaw Agent "Lucy" │  │
│                         │                             │  │  (reads all messages,  │  │
│                         │                             │  │   responds with AI)    │  │
│                         │                             │  └────────────────────────┘  │
└─────────────────────────┘                             └──────────────────────────────┘
                                                                  │
                                                                  ▼
                                                         ┌─────────────────┐
                                                         │  Discord Server  │
                                                         │  (one bot token) │
                                                         └─────────────────┘
```

**Key concept:** Lucy and the voice transcriber are the **same Discord bot**. One bot token handles both text commands (Lucy/AI responses) and voice channel transcription. When someone speaks in a voice channel, the transcriber converts it to text and posts it in a text channel — then Lucy can read and respond to it like any other message.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **Mac M1** | With Homebrew installed (`brew`) |
| **Orbstack** | Installed on Mac — https://orbstack.dev |
| **Tailscale** | Free account — https://tailscale.com |
| **Discord** | A server you admin + a bot token (guide below) |
| **OpenClaw** | Access to OpenClaw installation (npm or git) |
| **Git** | To clone this repository |

---

## Setup Overview

There are **5 phases**. Do them in order:

| Phase | What | Where |
|---|---|---|
| 1. Discord Bot | Create bot, get token, set permissions | Discord Developer Portal |
| 2. Mac Setup | Install whisper-server, Tailscale | Your Mac |
| 3. VM Setup | Create Ubuntu VM via Orbstack | Orbstack on Mac |
| 4. Tailscale | Connect both machines | Both Mac and VM |
| 5. VM Software | Install voice transcriber + OpenClaw | Ubuntu VM |

---

## Phase 1: Create Your Discord Bot

**→ Follow the complete guide in [`discord-bot-setup.md`](discord-bot-setup.md)**

This will walk you through:
1. Creating a Discord application
2. Adding a bot and copying the token
3. Enabling privileged intents (Message Content, Server Members, Presence)
4. Setting bot permissions (Connect, Speak, Send Messages, etc.)
5. Inviting the bot to your server

**Save your bot token.** You'll enter it during VM setup.

---

## Phase 2: Mac Setup

### 2a. Clone the repository

```bash
git clone https://github.com/opends007-prog/openclaw-voice-setup.git
cd openclaw-voice-setup/mac
```

### 2b. Configure environment

```bash
cp .env.example .env
nano .env
```

Edit `.env`:
```bash
WHISPER_MODEL_PATH=/usr/local/share/whisper.cpp/ggml-medium.en.bin
WHISPER_PORT=8080
TAILSCALE_MAC_IP=YOUR_MAC_TAILSCALE_IP    # Fill in after Tailscale setup
```

### 2c. Run the install script

```bash
chmod +x install.sh
./install.sh
```

This will:
- Install Homebrew (if needed)
- Install whisper.cpp
- Download the `ggml-medium.en.bin` model (~1.4 GB)
- Install Tailscale (if needed)
- Register whisper-server as a launchd service (auto-starts on boot)

### 2d. Verify

```bash
# Check service is running
sudo launchctl list | grep whisper

# Check logs
tail -f /var/log/whisper-server/whisper-server.log
```

---

## Phase 3: Create the Ubuntu VM

**→ Follow [`orbstack/setup-instructions.md`](orbstack/setup-instructions.md)**

Summary:
1. Open Orbstack
2. Create a new VM: Ubuntu 22.04 LTS, 2+ CPUs, 4 GB RAM, 10 GB disk
3. Start the VM and note its IP

### Copy the repository to the VM

From your Mac:
```bash
scp -r /Users/admin/openclaw-voice-setup ubuntu@<VM_IP>:~/
```

Or clone directly on the VM:
```bash
git clone https://github.com/opends007-prog/openclaw-voice-setup.git
```

---

## Phase 4: Tailscale Setup

**→ Follow [`tailscale/setup-instructions.md`](tailscale/setup-instructions.md)**

On **both** your Mac and the VM:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

After authenticating, get each machine's Tailscale IP:
```bash
tailscale ip
```

**Note your Mac's Tailscale IP** — you'll need it for the voice-transcriber config.

---

## Phase 5: VM Software Setup

### 5a. Configure the voice transcriber

```bash
cd ~/openclaw-voice-setup/vm
cp voice-transcriber/.env.example /opt/voice-transcriber/.env 2>/dev/null || true
```

Edit the `.env` file:
```bash
nano ~/openclaw-voice-setup/vm/voice-transcriber/.env
```

Set:
```bash
DISCORD_TOKEN=your_discord_bot_token_here
WHISPER_API_URL=http://<YOUR_MAC_TAILSCALE_IP>:8080/inference
```

### 5b. Configure OpenClaw

```bash
cp openclaw-config/openclaw.json.example /opt/openclaw/openclaw.json 2>/dev/null || true
nano ~/openclaw-voice-setup/vm/openclaw-config/openclaw.json
```

Set the `discordToken` to the **same** bot token.

### 5c. Run the VM setup script

```bash
cd ~/openclaw-voice-setup/vm
chmod +x setup.sh
sudo ./setup.sh
```

This will:
- Update system packages
- Install Node.js 20, ffmpeg, curl, git
- Install Tailscale (if not present)
- Create the `openclaw` service user
- Copy and install the voice-transcriber bot (`npm install`)
- Copy OpenClaw config
- Install and enable systemd services

### 5d. Install OpenClaw (if not done already)

The setup script will warn you if OpenClaw isn't installed. Install it:

```bash
cd /opt/openclaw
# Option A: if OpenClaw is on npm
npm init -y && npm install openclaw

# Option B: if OpenClaw is a git repo
git clone <your-openclaw-repo-url> .
npm install
```

### 5e. Start services

```bash
sudo systemctl start voice-transcriber
sudo systemctl start openclaw-gateway
```

### 5f. Verify

```bash
systemctl status voice-transcriber
systemctl status openclaw-gateway
```

---

## Testing

### Test whisper-server from the VM

```bash
# Create a test WAV file (or use any short audio clip)
# Then send it to your Mac's whisper-server:
curl -X POST http://<MAC_TAILSCALE_IP>:8080/inference \
  -H "Content-Type: audio/wav" \
  --data-binary @test.wav
```

### Test in Discord

1. Join a voice channel in your Discord server
2. Speak — the bot should transcribe your speech and post it in a text channel
3. Lucy should be able to read and respond to the transcription

---

## Troubleshooting

### Check service status

**On Mac:**
```bash
sudo launchctl list | grep whisper
tail -f /var/log/whisper-server/whisper-server.log
```

**On VM:**
```bash
systemctl status voice-transcriber
systemctl status openclaw-gateway
journalctl -u voice-transcriber -f
journalctl -u openclaw-gateway -f
```

### Common issues

| Problem | Solution |
|---|---|
| Bot shows offline | Start services: `sudo systemctl start voice-transcriber openclaw-gateway` |
| Bot doesn't join voice | Check bot has `Connect` + `Speak` permissions in Discord |
| Bot doesn't respond to messages | Enable `Message Content Intent` in Discord Developer Portal |
| Transcription fails | Test whisper-server: `curl -X POST http://<MAC_IP>:8080/inference -H "Content-Type: audio/wav" --data-binary @test.wav` |
| Tailscale can't connect | Run `tailscale status` on both machines; re-authenticate if needed |
| whisper-server not running on Mac | `sudo launchctl kickstart -k system/com.openclaw.whisper-server` |

### Restart services after config changes

```bash
sudo systemctl restart voice-transcriber
sudo systemctl restart openclaw-gateway
```

---

## Updating

```bash
cd ~/openclaw-voice-setup
git pull
sudo ./vm/setup.sh   # On VM
./mac/install.sh     # On Mac
```

---

## File Reference

| File | Purpose |
|---|---|
| `discord-bot-setup.md` | Complete Discord bot creation guide |
| `mac/install.sh` | Mac setup: whisper.cpp, model, launchd service |
| `mac/.env.example` | Mac environment variables template |
| `mac/whisper-server.plist` | launchd service definition |
| `vm/setup.sh` | VM setup: Node.js, ffmpeg, Tailscale, services |
| `vm/voice-transcriber/index.js` | Voice transcriber bot source |
| `vm/voice-transcriber/.env.example` | VM environment variables template |
| `vm/openclaw-config/openclaw.json.example` | OpenClaw config template |
| `vm/services/voice-transcriber.service` | systemd service for voice transcriber |
| `vm/services/openclaw-gateway.service` | systemd service for OpenClaw |
| `orbstack/setup-instructions.md` | Orbstack VM creation guide |
| `tailscale/setup-instructions.md` | Tailscale installation guide |