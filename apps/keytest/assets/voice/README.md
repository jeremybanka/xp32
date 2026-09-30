# Keytest speech

`speech.json` is the source dictionary for the app's spoken feedback:

- 26 NATO alphabet words, with official spellings **Alfa** and **Juliett**.
- Ordinary names for 0–9, ASCII punctuation, and additional common symbols.
- Names for all controls recognized by `keys.zig`, including F1–F24 and media keys.
- "Unknown character" for a printable character without a recording.

The NATO word list follows [NATO's published alphabet](https://www.nato.int/en/about-us/nato-history/history-by-theme/symbols-of-nato/nato-phonetic-alphabet).
The visual glyph and background remain based on the actual key/character.

## Generate

```sh
mise exec -- just voice
mise exec -- just voice letter-a control-shift
```

Generation runs locally in Bun using `kokoro-js` and ONNX Runtime CPU. The
`af_heart` voice, normal speed, fp32 model, and model revision are pinned in
`kokoro.json`; dependencies are locked in `bun.lock`. The first run downloads
about 311 MiB into `.tools/kokoro/`. No Python or separate Node process is needed.

Each prompt is the complete spoken name followed by a period. An optional
`pronunciation` spelling overrides the TTS input without changing the key name:
Alt uses `ault`. Every generated
sample is retained; there is no syllable extraction, fade, or speed adjustment.
Export normalizes peaks to -1 dBFS and writes mono 24 kHz, 16-bit PCM WAVs into
`clips/`. `clips/manifest.json` records prompts, phonemes, durations, and hashes.
The script then rebuilds `../../speech-data.zig` and the listening reels.

## Replace recordings

To use a personal recording, replace `clips/<id>.wav` with the same canonical
44-byte-header PCM format, update that entry's duration and SHA-256 in
`clips/manifest.json`, and record its new provenance there. No TTS is needed:

```sh
mise exec -- just voice-index
mise exec -- just check
```

`voice-index` validates the dictionary, headers, hashes, and durations, then
regenerates the embedded Zig index. `just check` checks the saved index and
verifies every clip is embedded byte-for-byte in the executable. CI never
runs TTS or downloads the model. Run `just voice` only when intentionally
replacing recordings with synthesized speech.

Listening reels are in `artifacts/speech/`: `alphabet.wav`, `numbers.wav`,
`punctuation.wav`, and `controls.wav`. The recordings are assembled unchanged,
with half-second gaps between clips.

## Playback

`PlaySoundA` uses asynchronous in-memory playback. Embedded WAV buffers live
for the entire process, satisfying the API's lifetime requirement. A new press
interrupts the preceding clip; repeat keydowns/characters don't restart it.
Space speaks once on keydown. Windows and Print Screen events are posted from
the keyboard hook to the window, keeping audio work out of the hook callback.
Deactivation and exit stop audio. Missing sound hardware leaves the visual
keyboard tester usable without playing a default Windows alert.

API reference: [Microsoft PlaySound documentation](https://learn.microsoft.com/en-us/previous-versions/dd743680(v=vs.85)).

## Earlier experiments

Letter-name synthesis and syllable extraction were abandoned after listening
review. Their local source takes and scripts are retained under the ignored
`artifacts/voice-letter-experiments/` directory for reference. They are not
part of the build or the current voice workflow.

Generated with [Kokoro](https://github.com/hexgrad/kokoro/tree/main/kokoro.js)
and its [ONNX model](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX).
The library and model use Apache-2.0. These are synthetic voice clips.
