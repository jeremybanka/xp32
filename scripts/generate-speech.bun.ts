import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { createHash } from "node:crypto";
import { KokoroTTS, TextSplitterStream } from "kokoro-js";
import { env, StyleTextToSpeech2Model, AutoTokenizer } from "@huggingface/transformers";
import dictionary from "../apps/keytest/assets/voice/speech.json";
import config from "../apps/keytest/assets/voice/kokoro.json";
import { pcm16Wav } from "./voice-wav";

const root = resolve(import.meta.dir, "..");
const output = resolve(root, "apps/keytest/assets/voice/clips");
const selected = process.argv.slice(2).flatMap(ids => ids.split(/\s+/).filter(Boolean));
if (selected.some(id => !dictionary.some(entry => entry.id === id))) throw new Error("Unknown speech ID");
const manifestPath = resolve(output, "manifest.json");
const previous = selected.length ? await Bun.file(manifestPath).json() : null;
if (previous && Object.entries(config).some(([key, value]) => previous[key] !== value)) {
  throw new Error("Voice settings changed; regenerate all speech");
}
await mkdir(output, { recursive: true });
env.cacheDir = resolve(root, ".tools/kokoro");
if (config.dtype !== "fp32") throw new Error("Expected fp32 model");
const [model, tokenizer] = await Promise.all([
  StyleTextToSpeech2Model.from_pretrained(config.model, { revision: config.revision, dtype: config.dtype, device: "cpu" }),
  AutoTokenizer.from_pretrained(config.model, { revision: config.revision }),
]);
const tts = new KokoroTTS(model, tokenizer);
const clips = new Map<string, any>((previous?.clips ?? []).map((clip: any) => [clip.id, clip]));
try {
  for (const entry of dictionary) {
    if (selected.length && !selected.includes(entry.id)) continue;
    const prompt = `${entry.pronunciation ?? entry.spoken}.`;
    const text = new TextSplitterStream();
    text.push(prompt);
    text.close();
    const chunks = [];
    for await (const chunk of tts.stream(text, { voice: config.voice as keyof KokoroTTS["voices"], speed: config.speed })) chunks.push(chunk);
    if (chunks.length !== 1) throw new Error(`Expected one utterance for ${entry.id}`);
    const { audio, phonemes } = chunks[0];
    if (audio.sampling_rate !== 24000) throw new Error("Unexpected sample rate");
    const wav = pcm16Wav(audio.audio, audio.sampling_rate);
    await Bun.write(resolve(output, `${entry.id}.wav`), wav);
    clips.set(entry.id, { id: entry.id, spoken: entry.spoken, prompt, phonemes,
      seconds: audio.audio.length / audio.sampling_rate,
      sha256: createHash("sha256").update(wav).digest("hex") });
    console.log(`${entry.id}: ${entry.spoken} [${phonemes}]`);
  }
  await Bun.write(manifestPath, JSON.stringify({ ...config, sampleRate: 24000, bits: 16, channels: 1,
    trimmed: false, clips: dictionary.map(entry => clips.get(entry.id)) }, null, 2) + "\n");
} finally {
  await model.dispose();
}
await import("./speech-index.bun").then(module => module.writeSpeechIndex());
