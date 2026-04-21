require('dotenv').config();
const { Client, GatewayIntentBits, Partials } = require('discord.js');
const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');

// Configuration
const WHISPER_API_URL = process.env.WHISPER_API_URL || 'http://100.67.79.42:8080/inference';
const VOICE_BOT_TOKEN = process.env.VOICE_BOT_TOKEN;

// Create Discord client
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
    GatewayIntentBits.GuildVoiceStates,
  ],
  partials: [Partials.Channel],
});

// Temporary directory for audio files
const TEMP_DIR = path.join(__dirname, 'temp');
if (!fs.existsSync(TEMP_DIR)) {
  fs.mkdirSync(TEMP_DIR);
}

// Clean up temp files on exit
process.on('exit', () => {
  if (fs.existsSync(TEMP_DIR)) {
    fs.readdirSync(TEMP_DIR).forEach(file => {
      fs.unlinkSync(path.join(TEMP_DIR, file));
    });
  }
});

client.once('ready', () => {
  console.log(`Logged in as ${client.user.tag}!`);
  console.log(`Whisper API URL: ${WHISPER_API_URL}`);
});

client.on('voiceStateUpdate', async (oldState, newState) => {
  // Join voice channel when user joins
  if (oldState.channelId === null && newState.channelId !== null) {
    try {
      const connection = await newState.channel.join();
      console.log(`Joined voice channel: ${newState.channel.name}`);

      // Create audio receiver
      const receiver = connection.receiver.subscribe({
        end: {
          behavior: Discord.VoiceReceiveBehavior.AfterInactivity,
          duration: 300,
        },
      });

      // Handle incoming audio
      receiver.on('speech', (userId) => {
        console.log(`User ${userId} started speaking`);
      });

      receiver.on('pcm', async (userId, pcm) => {
        try {
          console.log(`Receiving audio from user ${userId}`);

          // Convert PCM to WAV format
          const wavBuffer = convertPcmToWav(pcm, {
            sampleRate: 48000,
            bitDepth: 16,
            channels: 2,
          });

          // Save to temporary file
          const tempFilePath = path.join(TEMP_DIR, `${userId}-${Date.now()}.wav`);
          fs.writeFileSync(tempFilePath, wavBuffer);

          // Send to whisper-server for transcription
          const response = await fetch(WHISPER_API_URL, {
            method: 'POST',
            headers: {
              'Content-Type': 'audio/wav',
            },
            body: wavBuffer,
          });

          if (!response.ok) {
            throw new Error(`Whisper server error: ${response.status}`);
          }

          const result = await response.json();
          const transcription = result.text || '';

          if (transcription.trim()) {
            // Send transcription back to the text channel
            const textChannel = newState.channel.guild.channels.cache.find(
              ch => ch.type === ChannelType.GuildText && ch.permissionsFor(newState.guild.members.me).has('SendMessages')
            );

            if (textChannel) {
              await textChannel.send(`<@${userId}>: ${transcription}`);
              console.log(`Transcribed and sent: ${transcription}`);
            }
          }

          // Clean up temp file
          fs.unlinkSync(tempFilePath);
        } catch (error) {
          console.error('Error processing audio:', error);
        }
      });

      receiver.on('end', () => {
        console.log('Voice connection ended');
        connection.destroy();
      });
    } catch (error) {
      console.error('Error joining voice channel:', error);
    }
  }

  // Leave voice channel when last user leaves
  if (oldState.channelId !== null && newState.channelId === null) {
    const members = oldState.channel.members.filter(m => !m.user.bot);
    if (members.size === 0) {
      try {
        const connection = oldState.channel.guild.voiceAdapterCreator.voiceConnections.get(oldState.guildId);
        if (connection) {
          connection.destroy();
          console.log(`Left voice channel: ${oldState.channel.name}`);
        }
      } catch (error) {
        console.error('Error leaving voice channel:', error);
      }
    }
  }
});

// Simple PCM to WAV converter (simplified version)
function convertPcmToWav(pcmData, opts = {}) {
  const sampleRate = opts.sampleRate || 48000;
  const bitDepth = opts.bitDepth || 16;
  const channels = opts.channels || 2;

  const buffer = Buffer.alloc(44 + pcmData.length);

  // WAV header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + pcmData.length, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20); // PCM format
  buffer.writeUInt16LE(channels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * channels * bitDepth / 8, 28);
  buffer.writeUInt16LE(channels * bitDepth / 8, 32);
  buffer.writeUInt16LE(bitDepth, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(pcmData.length, 40);

  // PCM data
  pcmData.copy(buffer, 44);

  return buffer;
}

// Error handling
client.on('error', console.error);
client.on('warn', console.warn);
client.on('debug', console.log);

// Login to Discord
client.login(VOICE_BOT_TOKEN).catch(console.error);