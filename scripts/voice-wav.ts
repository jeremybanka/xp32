// Our generated assets use a canonical 44-byte mono PCM header. Reject other
// formats rather than silently treating metadata or stereo samples as audio.
export function readVoiceWav(wav: Buffer): { samples: Float32Array; rate: number } {
  if (wav.length < 46 || wav.toString("ascii", 0, 4) !== "RIFF" ||
      wav.toString("ascii", 8, 16) !== "WAVEfmt " || wav.readUInt32LE(16) !== 16 ||
      wav.readUInt16LE(20) !== 1 || wav.readUInt16LE(22) !== 1 ||
      wav.readUInt32LE(24) !== 24000 || wav.readUInt32LE(28) !== 48000 ||
      wav.readUInt16LE(32) !== 2 || wav.readUInt16LE(34) !== 16 ||
      wav.toString("ascii", 36, 40) !== "data" || wav.readUInt32LE(4) !== wav.length - 8 ||
      wav.readUInt32LE(40) !== wav.length - 44 || (wav.length - 44) % 2 !== 0) {
    throw new Error("Expected canonical mono 24 kHz 16-bit PCM WAV");
  }
  const samples = new Float32Array((wav.length - 44) / 2);
  for (let i = 0; i < samples.length; i++) samples[i] = wav.readInt16LE(44 + i * 2) / 32768;
  return { samples, rate: 24000 };
}

// Integer PCM keeps these assets usable by XP's native audio APIs.
export function pcm16Wav(samples: Float32Array, rate: number): Buffer {
  if (!Number.isInteger(rate) || rate <= 0 || samples.length === 0) throw new Error("Invalid audio");
  let peak = 0;
  for (const sample of samples) {
    if (!Number.isFinite(sample)) throw new Error("Non-finite audio sample");
    peak = Math.max(peak, Math.abs(sample));
  }
  if (peak < 0.0001) throw new Error("Silent audio");
  // Keep quiet consonants; normalize the whole utterance to -1 dBFS.
  const gain = 10 ** (-1 / 20) / peak;
  const wav = Buffer.alloc(44 + samples.length * 2);
  wav.write("RIFF", 0);
  wav.writeUInt32LE(wav.length - 8, 4);
  wav.write("WAVEfmt ", 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20); // PCM
  wav.writeUInt16LE(1, 22); // mono
  wav.writeUInt32LE(rate, 24);
  wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write("data", 36);
  wav.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) wav.writeInt16LE(Math.round(samples[i] * gain * 32767), 44 + i * 2);
  return wav;
}
