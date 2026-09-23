import { resolve } from "node:path";
import sharp from "sharp";

const assets = resolve(import.meta.dir, "../apps/keytest/assets");
const output = process.argv[2] ?? resolve(assets, "keytest.ico");
const sizes = [16, 24, 32, 48];
const frames: Buffer[] = [];
for (const size of sizes) {
  const rgba = await sharp(resolve(assets, "keytest.png"))
    .resize(size, size, { kernel: "lanczos3" }).ensureAlpha().raw().toBuffer();
  const stride = Math.ceil(size / 32) * 4;
  const bgra = Buffer.alloc(size * size * 4);
  const mask = Buffer.alloc(stride * size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const from = ((size - 1 - y) * size + x) * 4;
      const to = (y * size + x) * 4;
      bgra.set([rgba[from + 2], rgba[from + 1], rgba[from], rgba[from + 3]], to);
      if (rgba[from + 3] === 0) mask[y * stride + (x >> 3)] |= 0x80 >> (x % 8);
    }
  }
  const header = Buffer.alloc(40);
  header.writeUInt32LE(40, 0);
  header.writeInt32LE(size, 4);
  header.writeInt32LE(size * 2, 8);
  header.writeUInt16LE(1, 12);
  header.writeUInt16LE(32, 14);
  header.writeUInt32LE(bgra.length + mask.length, 20);
  frames.push(Buffer.concat([header, bgra, mask]));
}
const directory = Buffer.alloc(6 + 16 * sizes.length);
directory.writeUInt16LE(1, 2);
directory.writeUInt16LE(sizes.length, 4);
let offset = directory.length;
for (const [i, size] of sizes.entries()) {
  const at = 6 + 16 * i;
  directory[at] = directory[at + 1] = size;
  directory.writeUInt16LE(1, at + 4);
  directory.writeUInt16LE(32, at + 6);
  directory.writeUInt32LE(frames[i].length, at + 8);
  directory.writeUInt32LE(offset, at + 12);
  offset += frames[i].length;
}
await Bun.write(output, Buffer.concat([directory, ...frames]));
console.log(`Exported XP icon to ${output}`);
