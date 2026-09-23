import assert from "node:assert/strict";

// Keep the allowlist explicit: compiler changes must not silently raise the
// minimum Windows version. In particular, display-mode switching is absent.
const allowed = new Map(Object.entries({
  "kernel32.dll": "ExitProcess GetModuleHandleW",
  "winmm.dll": "PlaySoundA",
  "user32.dll": `BeginPaint CallNextHookEx CreateWindowExW DefWindowProcW
    DestroyWindow DispatchMessageW DrawTextW EndPaint FillRect GetDC
    GetForegroundWindow GetClientRect GetSystemMetrics GetKeyState GetMessageW
    InvalidateRect IsIconic LoadIconW MessageBoxW PostQuitMessage PostMessageW
    RegisterClassW ReleaseDC SetCursor SetForegroundWindow SetWindowsHookExW
    SetWindowPos ShowWindow TranslateMessage UnhookWindowsHookEx UpdateWindow`,
  "gdi32.dll": `AddFontMemResourceEx BitBlt CreateCompatibleBitmap
    CreateCompatibleDC CreateFontW CreateSolidBrush DeleteDC DeleteObject
    GetTextExtentPoint32W GetTextFaceW RemoveFontMemResourceEx SelectObject
    SetBkMode SetTextColor`,
}).map(([dll, names]) => [dll, new Set(names.trim().split(/\s+/))]));

export function auditPE(data: Buffer, requireIcon = false) {
  const u16 = (at: number) => data.readUInt16LE(at);
  const u32 = (at: number) => data.readUInt32LE(at);
  assert.equal(data.toString("ascii", 0, 2), "MZ", "Missing DOS header");
  const pe = u32(0x3c);
  assert.equal(data.toString("ascii", pe, pe + 4), "PE\0\0", "Missing PE header");
  assert.equal(u16(pe + 4), 0x14c, "Must be x86");
  const optional = pe + 24;
  assert.equal(u16(optional), 0x10b, "Must be PE32");
  assert.deepEqual([u16(optional + 40), u16(optional + 42)], [5, 1], "Must target XP");
  assert.deepEqual([u16(optional + 48), u16(optional + 50)], [5, 1], "XP subsystem required");
  assert.equal(u16(optional + 68), 2, "Must be a GUI application");
  const table = optional + u16(pe + 20);
  const sections = Array.from({ length: u16(pe + 6) }, (_, i) => {
    const at = table + i * 40;
    return { size: Math.max(u32(at + 8), u32(at + 16)), rva: u32(at + 12), raw: u32(at + 20) };
  });
  function offset(rva: number) {
    const section = sections.find(s => rva >= s.rva && rva < s.rva + s.size);
    assert(section, `Invalid RVA: ${rva.toString(16)}`);
    return section.raw + rva - section.rva;
  }
  function string(rva: number) {
    const start = offset(rva);
    const end = data.indexOf(0, start);
    assert(end >= start, "Unterminated import name");
    return data.toString("ascii", start, end);
  }
  const imports = new Map<string, string[]>();
  for (let entry = offset(u32(optional + 104)); u32(entry + 12); entry += 20) {
    const dll = string(u32(entry + 12)).toLowerCase();
    const names = allowed.get(dll);
    assert(names, `Unexpected DLL dependency: ${dll}`);
    const functions: string[] = [];
    for (let cursor = offset(u32(entry) || u32(entry + 16)); u32(cursor); cursor += 4) {
      const symbol = u32(cursor);
      assert(!(symbol & 0x80000000), "Ordinal import requires review");
      const name = string(symbol + 2);
      assert(names.has(name), `Unreviewed API: ${dll}!${name}`);
      functions.push(name);
    }
    imports.set(dll, functions);
  }
  assert.deepEqual([...imports.keys()].sort(), [...allowed.keys()].sort(), "Unexpected DLL set");

  const iconSizes = new Set<number>();
  if (requireIcon) {
    const resourceRva = u32(optional + 112);
    assert(resourceRva, "Missing PE resources");
    const base = offset(resourceRva);
    function entries(relative: number) {
      const count = u16(base + relative + 12) + u16(base + relative + 14);
      return new Map(Array.from({ length: count }, (_, i) => {
        const at = base + relative + 16 + i * 8;
        return [u32(at), u32(at + 4)] as const;
      }));
    }
    function* blobs(node: number, depth = 0): Generator<Buffer> {
      assert(depth <= 3, "Invalid resource tree");
      if (node & 0x80000000) {
        for (const child of entries(node & 0x7fffffff).values()) yield* blobs(child, depth + 1);
      } else {
        const at = offset(u32(base + node));
        const size = u32(base + node + 4);
        assert(at + size <= data.length, "Truncated resource");
        yield data.subarray(at, at + size);
      }
    }
    const resources = entries(0);
    assert(resources.has(3) && resources.has(14), "Missing icon/group icon resources");
    assert(resources.has(16), "Missing application version information");
    const icons = new Map([...entries(resources.get(3)! & 0x7fffffff)]
      .map(([id, node]) => [id, [...blobs(node)][0]]));
    for (const group of blobs(resources.get(14)!)) {
      assert.equal(group.readUInt16LE(0), 0);
      assert.equal(group.readUInt16LE(2), 1);
      const count = group.readUInt16LE(4);
      assert(count > 0, "Empty icon group");
      for (let i = 0; i < count; i++) {
        const at = 6 + i * 14;
        const width = group[at];
        const height = group[at + 1];
        const icon = icons.get(group.readUInt16LE(at + 12));
        assert(icon, "Missing icon frame");
        assert.equal(icon.length, group.readUInt32LE(at + 8), "Icon length mismatch");
        assert.equal(icon.readUInt32LE(0), 40, "XP icons require a DIB header, not PNG");
        assert.equal(icon.readUInt32LE(16), 0, "XP icons must be uncompressed");
        assert.equal(icon.readInt32LE(4), width);
        assert.equal(icon.readInt32LE(8), height * 2);
        assert.equal(group.readUInt16LE(at + 4), 1);
        assert.equal(group.readUInt16LE(at + 6), 32);
        assert.equal(icon.readUInt16LE(12), 1);
        assert.equal(icon.readUInt16LE(14), 32);
        assert.equal(icon.length, 40 + width * height * 4 + Math.ceil(width / 32) * 4 * height);
        iconSizes.add(width);
      }
    }
    assert([16, 32, 48].every(size => iconSizes.has(size)), "Missing desktop/taskbar icon sizes");
  }
  return { bytes: data.length, imports, iconSizes: [...iconSizes].sort((a, b) => a - b) };
}

if (import.meta.main) {
  const file = process.argv[2];
  assert(file, "Usage: bun scripts/check-pe.bun.ts <exe> [--require-icon]");
  const report = auditPE(Buffer.from(await Bun.file(file).arrayBuffer()), process.argv.includes("--require-icon"));
  console.log(`PASS: x86 PE32 GUI, XP 5.1, ${report.bytes.toLocaleString("en-US")} bytes`);
  for (const [dll, names] of report.imports) console.log(`  ${dll}: ${names.length} XP-compatible imports`);
  if (report.iconSizes.length) console.log(`  PASS: XP icon resources at ${report.iconSizes.join(", ")} px and version metadata`);
}
