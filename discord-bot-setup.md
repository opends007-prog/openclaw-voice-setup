# Discord Bot Setup Guide

This guide walks you through creating the Discord bot that both **Lucy** (OpenClaw agent) and the **voice transcriber** will use.

> **Key point:** Lucy and the voice transcriber are **the same bot**. One bot does both text commands (Lucy) and voice-to-text transcription. You only need to create **one** Discord application.

---

## Step 1: Create a Discord Application

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **"New Application"** (top-right)
3. Give it a name (e.g., "Lucy") and click **Create**

## Step 2: Create the Bot

1. In the left sidebar, click **"Bot"**
2. Click **"Add Bot"** → **"Yes, do it!"**
3. Under the bot's username, click **"Reset Token"** and copy the token
   > ⚠️ **Save this token securely. You will need it for both the OpenClaw config and the voice-transcriber .env file.**

## Step 3: Enable Privileged Intents

Still on the **Bot** page, scroll down to **"Privileged Gateway Intents"** and enable ALL THREE:

| Intent | Why |
|---|---|
| **Presence Intent** | Required for OpenClaw to track user status |
| **Server Members Intent** | Required for OpenClaw to access member list |
| **Message Content Intent** | Required for OpenClaw to read message content |

Click **"Save Changes"** at the bottom.

## Step 4: Set Bot Permissions

1. In the left sidebar, click **"OAuth2"** → **"URL Generator"**
2. Under **"Scopes"**, check:
   - `bot`
   - `applications.commands`
3. Under **"Bot Permissions"**, check:

| Permission | Why |
|---|---|
| View Channels | See channels in the server |
| Send Messages | Reply in text channels |
| Read Message History | Context for conversations |
| Connect | Join voice channels |
| Speak | Voice functionality |
| Use Voice Activity | Voice activity detection |

4. Copy the generated URL at the bottom of the page

## Step 5: Invite the Bot to Your Server

1. Paste the URL from Step 4 into your browser
2. Select your server from the dropdown
3. Click **"Authorize"**
4. Complete the CAPTCHA if prompted

The bot should now appear in your server (it will show as offline until you start it).

## Step 6: Get Your Bot Token

If you didn't save the token in Step 2:

1. Go back to [Discord Developer Portal](https://discord.com/developers/applications)
2. Select your application
3. Go to **"Bot"** in the left sidebar
4. Click **"Reset Token"** and copy it

---

## What to Do with the Token

Use this **same token** in two places:

1. **Voice transcriber** – `/opt/voice-transcriber/.env`:
   ```
   DISCORD_TOKEN=your_token_here
   ```

2. **OpenClaw agent** – `/opt/openclaw/openclaw.json`:
   ```json
   {
     "discordToken": "your_token_here"
   }
   ```

---

## Architecture Overview

```
Discord Server
  └── Your Bot Token ("Lucy")
        ├── Text Channels → OpenClaw agent (Lucy) reads messages, responds with AI
        └── Voice Channels → Voice transcriber joins, converts speech → text → sends to text channel
```

Both functions connect to Discord using the **same bot identity**. When a user speaks in a voice channel:
1. The voice transcriber bot joins the voice channel
2. It captures audio and sends it to your Mac's whisper-server
3. The transcribed text is posted in the text channel (mentioning who spoke)
4. Lucy (OpenClaw) can then read and respond to the transcription like any other message

---

## Troubleshooting

### Bot shows as offline
- Make sure you've started both services:
  ```bash
  sudo systemctl start voice-transcriber
  sudo systemctl start openclaw-gateway
  ```

### Bot doesn't join voice channels
- Check the bot has `Connect` and `Speak` permissions in the server
- Regenerate the invite URL with correct permissions and re-invite

### Bot doesn't respond to messages
- Verify `Message Content Intent` is enabled in the Developer Portal
- Check the bot has `Send Messages` permission in the channel

### "Privileged Intents" error
- If your bot is in 100+ servers, privileged intents require verification
- For personal/small servers, they work immediately
