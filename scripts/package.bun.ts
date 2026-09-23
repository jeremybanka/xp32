import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { zipSync, type Zippable } from "fflate";

const app = process.argv[2] ?? "keytest";
if (app !== "keytest") throw new Error(`Unknown app: ${app}`);
const root = resolve(import.meta.dir, "..");
const output = resolve(root, "dist", app);
await mkdir(output, { recursive: true });
const files: Zippable = {};
for (const name of [`${app}.exe`, "README.md", "TESTING.md"]) {
  const path = resolve(output, name);
  if (!name.endsWith(".exe")) {
    await Bun.write(path, Bun.file(resolve(root, "apps", app, name)));
  }
  // Fixed timestamps keep ZIP metadata reproducible across hosts/time zones.
  files[name] = [await Bun.file(path).bytes(), { mtime: new Date(2000, 0, 1) }];
}
await Bun.write(resolve(root, "dist", `${app}-xp32.zip`), zipSync(files, { level: 9 }));
console.log(`Packaged dist/${app}-xp32.zip`);
