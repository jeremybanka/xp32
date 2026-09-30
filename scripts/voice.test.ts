import { expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import dictionary from "../apps/keytest/assets/voice/speech.json";
import config from "../apps/keytest/assets/voice/kokoro.json";
import { readVoiceWav, pcm16Wav } from "./voice-wav";
import { writeSpeechIndex } from "./speech-index.bun";

const root = resolve(import.meta.dir, "..");
const dir = resolve(root, "apps/keytest/assets/voice/clips");

test("WAV export and decoding reject invalid audio and unsupported formats", () => {
  const wav = pcm16Wav(new Float32Array([-0.5, 0, 0.5]), 24000);
  expect(wav.readUInt32LE(4)).toBe(wav.length - 8);
  expect(wav.readInt16LE(44)).toBeLessThan(-29000);
  expect(wav.readInt16LE(46)).toBe(0);
  expect(wav.readInt16LE(48)).toBeGreaterThan(29000);
  expect(readVoiceWav(wav).samples.length).toBe(3);
  const invalid = Buffer.from(wav);
  invalid.writeUInt16LE(2, 22);
  expect(() => readVoiceWav(invalid)).toThrow();
  expect(() => readVoiceWav(wav.subarray(0, 40))).toThrow();
  expect(() => readVoiceWav(wav.subarray(0, wav.length - 1))).toThrow();
  expect(() => pcm16Wav(new Float32Array([NaN]), 24000)).toThrow();
  expect(() => pcm16Wav(new Float32Array(10), 24000)).toThrow();
});

test("speech uses complete NATO words and valid, reproducible PCM assets", async () => {
  const manifest = await Bun.file(resolve(dir, "manifest.json")).json();
  for (const [key, value] of Object.entries(config)) expect(manifest[key]).toEqual(value);
  expect(manifest.trimmed).toBe(false);
  expect(manifest.clips.map((c: any) => c.id)).toEqual(dictionary.map(entry => entry.id));
  expect(dictionary.filter(entry => entry.group === "alphabet").map(entry => entry.spoken)).toEqual(
    "Alfa Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliett Kilo Lima Mike November Oscar Papa Quebec Romeo Sierra Tango Uniform Victor Whiskey X-ray Yankee Zulu".split(" "),
  );
  for (const entry of dictionary) {
    const clip = manifest.clips.find((clip: any) => clip.id === entry.id);
    expect(clip.spoken).toBe(entry.spoken);
    expect(clip.prompt).toBe(`${entry.pronunciation ?? entry.spoken}.`);
    expect(clip.crop).toBeUndefined();
    expect(clip.phonemes.length).toBeGreaterThan(1);
    const wav = Buffer.from(await Bun.file(resolve(dir, `${entry.id}.wav`)).arrayBuffer());
    expect(createHash("sha256").update(wav).digest("hex")).toBe(clip.sha256);
    const { samples, rate } = readVoiceWav(wav);
    expect(samples.length / rate).toBe(clip.seconds);
    expect(clip.seconds).toBeGreaterThan(0.2);
    expect(clip.seconds).toBeLessThan(8);
    let peak = 0;
    for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
    expect(peak).toBeGreaterThan(0.88);
    expect(peak).toBeLessThan(0.90);
  }
  await writeSpeechIndex(true);
});

test("the portable executable embeds every speech clip byte-for-byte", async () => {
  const executable = Buffer.from(await Bun.file(resolve(root, "dist/keytest/keytest.exe")).arrayBuffer());
  for (const entry of dictionary) {
    const wav = Buffer.from(await Bun.file(resolve(dir, `${entry.id}.wav`)).arrayBuffer());
    expect(executable.indexOf(wav), entry.id).toBeGreaterThan(0);
  }
});
