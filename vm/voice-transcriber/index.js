require('dotenv').config();

const {
  Client,
  GatewayIntentBits,
  Partials,
  ChannelType,
} = require('discord.js');
const {
  joinVoiceChannel,
  createAudioPlayer,
  createAudioResource,
  VoiceReceiver,
  EndBehaviorType,
} = require('@discordjs/voice');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const WHISPER_API_URL = process.env.WHISPER_API_URL;
const DISCORD_TOKEN = process.env.DISCORD_TOKEN;

if (!WHISPER_API_URL) {
  process.stderr.write('ERROR: WHISPER_API_URL is not set in .env\n');
  process.exit(1);
}
if (!DISCORD_TOKEN) {
  process.stderr.write('ERROR: DISCORD_TOKEN is not set in .env\n');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Discord client
// ---------------------------------------------------------------------------
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
    GatewayIntentBits.GuildVoiceStates,
    GatewayIntentBits.GuildMembers,
  ],
  partials: [Partials.Channel],
});

// ---------------------------------------------------------------------------
// Temp directory for audio chunks
// ---------------------------------------------------------------------------
const TEMP_DIR = path.join(__dirname, 'temp_audio');
if (!fs.existsSync(TEMP_DIR)) fs.mkdirSync(TEMP_DIR, { recursive: true });

function cleanupTemp() {
  try {
    if (fs.existsSync(TEMP_DIR)) {
      fs.readdirSync(TEMP_DIR).forEach((f) =>
        fs.unlinkSync(path.join(TEMP_DIR, f))
      );
    }
  } catch (_) {}
}
process.on('exit', cleanupTemp);

// ---------------------------------------------------------------------------
// PCM → WAV helper
// ---------------------------------------------------------------------------
function pcmToWav(pcmBuffer, opts = {}) {
  const sampleRate = opts.sampleRate || 48000;
  const bits = opts.bits || 16;
  const channels = opts.channels || 2;
  const byteRate = (sampleRate * channels * bits) / 8;
  const blockAlign = (channels * bits) / 8;
  const headerLen = 44;
  const dataLen = pcmBuffer.length;
  const buf = Buffer.alloc(headerLen + dataLen);

  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + dataLen, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);           // fmt chunk size
  buf.writeUInt16LE(1, 20);            // PCM
  buf.writeUInt16LE(channels, 22);
  buf.writeUInt32LE(sampleRate, 24);
  buf.writeUInt32LE(byteRate, 28);
  buf.writeUInt16LE(blockAlign, 32);
  buf.writeUInt16LE(bits, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(dataLen, 40);
  pcmBuffer.copy(buf, headerLen);
  return buf;
}

// ---------------------------------------------------------------------------
// Resample 48 kHz stereo → 16 kHz mono WAV (whisper-server requirement)
// ---------------------------------------------------------------------------
async function resampleToWav(rawPcmBuffer) {
  const inFile = path.join(TEMP_DIR, `in_${process.pid}_${Date.now()}.raw`);
  const outFile = path.join(TEMP_DIR, `out_${process.pid}_${Date.now()}.wav`);
  fs.writeFileSync(inFile, rawPcmBuffer);
  try {
    execSync(
      `ffmpeg -y -f s16le -ar 48000 -ac 2 -i "${inFile}" -ar 16000 -ac 1 -f wav "${outFile}"`,
      { stdio: 'pipe' }
    );
    const wav = fs.readFileSync(outFile);
    return wav;
  } finally {
    try { fs.unlinkSync(inFile); } catch (_) {}
    try { fs.unlinkSync(outFile); } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Send audio to whisper-server, return transcribed text
// ---------------------------------------------------------------------------
async function transcribe(wavBuffer) {
  // Node 18+ has global fetch
  const res = await fetch(WHISPER_API_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'audio/wav' },
    body: wavBuffer,
  });
  if (!res.ok) {
    throw new Error(`whisper-server returned ${res.status}`);
  }
  const data = await res.json();
  return (data.text || '').trim();
}

// ---------------------------------------------------------------------------
// Ready
// ---------------------------------------------------------------------------
client.once('ready', () => {
  process.stdout.write(`[voice-transcriber] Logged in as ${client.user.tag}\n`);
  process.stdout.write(`[voice-transcriber] Whisper API: ${WHISPER_API_URL}\n`);
});

// ---------------------------------------------------------------------------
// Voice state monitoring – join when a human enters a voice channel
// ---------------------------------------------------------------------------
const activeConnections = new Map(); // guildId → { connection, receiver, speakingUsers }

client.on('voiceStateUpdate', async (oldState, newState) => {
  const guildId = newState.guild.id;

  // ── Someone joined a voice channel ──────────────────────────────────
  if (!oldState.channelId && newState.channelId) {
    // If we're already connected to this guild, nothing to do
    if (activeConnections.has(guildId)) return;

    const channel = newState.channel;
    const humanCount = channel.members.filter((m) => !m.user.bot).size;
    if (humanCount === 0) return;

    process.stdout.write(
      `[voice-transcriber] Joining "${channel.name}" in "${channel.guild.name}"\n`
    );

    try {
      const connection = joinVoiceChannel({
        channelId: channel.id,
        guildId: guildId,
        adapterCreator: channel.guild.voiceAdapterCreator,
        selfDeaf: true,
        selfMute: true,
      });

      const receiver = connection.receiver;

      // Track per-user PCM buffers per speaking session
      const userBuffers = {};

      receiver.speaking.on('start', (userId) => {
        process.stdout.write(`[voice-transcriber] User ${userId} started speaking\n`);
        const chunks = [];
        userBuffers[userId] = chunks;

        const sub = receiver.subscribe(userId, {
          end: { behavior: EndBehaviorType.AfterSilence, duration: 300 },
        });

        sub.on('data', (pcm) => chunks.push(Buffer.from(pcm)));

        sub.on('end', async () => {
          delete userBuffers[userId];
          if (chunks.length === 0) return;

          try {
            const raw = Buffer.concat(chunks);
            const wav = await resampleToWav(raw);
            const text = await transcribe(wav);

            if (text) {
              // Find a text channel we can write to
              const target = channel.guild.channels.cache.find(
                (c) =>
                  c.type === ChannelType.GuildText &&
                  c
                    .permissionsFor(channel.guild.members.me)
                    ?.has('SendMessages')
              );
              if (target) {
                await target.send(`🔊 <@${userId}>: ${text}`);
                process.stdout.write(`[voice-transcriber] → ${text}\n`);
              }
            }
          } catch (err) {
            process.stderr.write(
              `[voice-transcriber] Transcription error: ${err.message}\n`
            );
          }
        });
      });

      activeConnections.set(guildId, { connection });

      connection.on('disconnect', () => {
        activeConnections.delete(guildId);
        process.stdout.write(
          `[voice-transcriber] Disconnected from "${channel.name}"\n`
        );
      });
    } catch (err) {
      process.stderr.write(
        `[voice-transcriber] Failed to join: ${err.message}\n`
      );
      activeConnections.delete(guildId);
    }
  }

  // ── Someone left – leave if channel is empty of humans ─────────────
  if (oldState.channelId && !newState.channelId) {
    const channel = oldState.channel;
    const humans = channel?.members.filter((m) => !m.user.bot).size ?? 0;
    if (humans === 0) {
      const entry = activeConnections.get(guildId);
      if (entry) {
        entry.connection.destroy();
        activeConnections.delete(guildId);
        process.stdout.write(
          `[voice-transcriber] Left "${channel.name}" (empty)\n`
        );
      }
    }
  }
});

// ---------------------------------------------------------------------------
// Error handlers
// ---------------------------------------------------------------------------
client.on('error', (e) => process.stderr.write(`[discord] ${e}\n`));
client.on('warn', (w) => process.stderr.write(`[discord] warn: ${w}\n`));

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------
client.login(DISCORD_TOKEN).catch((e) => {
  process.stderr.write(`[voice-transcriber] Login failed: ${e.message}\n`);
  process.exit(1);
});