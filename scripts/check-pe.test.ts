import { expect, test } from "bun:test";
import { resolve } from "node:path";
import { unzipSync } from "fflate";
import { auditPE } from "./check-pe.bun";

// `just test` builds first, so these exercise the output and never a stale fixture.
const root = resolve(import.meta.dir, "..");
const executable = Buffer.from(await Bun.file(resolve(root, "dist/keytest/keytest.exe")).arrayBuffer());
const optional = executable.readUInt32LE(0x3c) + 24;

test("fresh executable has XP headers, reviewed imports, and usable icon frames", () => {
  expect(auditPE(executable, true).iconSizes).toEqual([16, 24, 32, 48]);
});

test("audit rejects a compiler raising the Windows version", () => {
  const changed = Buffer.from(executable);
  changed.writeUInt16LE(6, optional + 48);
  expect(() => auditPE(changed, true)).toThrow("XP subsystem required");
});

test("audit rejects an unreviewed imported API", () => {
  const changed = Buffer.from(executable);
  const at = changed.indexOf(Buffer.from("GetModuleHandleW\0"));
  expect(at).toBeGreaterThan(0);
  changed[at] = "X".charCodeAt(0);
  expect(() => auditPE(changed, true)).toThrow("Unreviewed API");
});

test("audit rejects missing resources", () => {
  const changed = Buffer.from(executable);
  changed.writeUInt32LE(0, optional + 112);
  expect(() => auditPE(changed, true)).toThrow("Missing PE resources");
});

test("audit rejects missing XP transparency mask data", () => {
  const changed = Buffer.from(executable);
  // Locate a 48x48 32-bit icon DIB and corrupt its height without changing its size.
  const dib = Buffer.from([40, 0, 0, 0, 48, 0, 0, 0, 96, 0, 0, 0, 1, 0, 32, 0]);
  const at = changed.indexOf(dib);
  expect(at).toBeGreaterThan(0);
  changed.writeInt32LE(48, at + 8);
  expect(() => auditPE(changed, true)).toThrow();
});

test("portable ZIP contains the exact executable and current documentation", async () => {
  const files = unzipSync(await Bun.file(resolve(root, "dist/keytest-xp32.zip")).bytes());
  expect(Object.keys(files).sort()).toEqual(["README.md", "TESTING.md", "keytest.exe"]);
  expect(Buffer.from(files["keytest.exe"])).toEqual(executable);
  for (const name of ["README.md", "TESTING.md"]) {
    expect(Buffer.from(files[name]).toString()).toBe(await Bun.file(resolve(root, "apps/keytest", name)).text());
  }
});
