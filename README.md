# XP32

Small native Windows XP applications written in Zig, sharing a minimal Win32
layer. Builds use Zig 0.15.2 and target 32-bit XP with a Pentium III baseline.

## Apps

- [Keytest](apps/keytest/README.md): a responsive fullscreen keyboard tester with
  white Noname Sans glyphs, input-dependent background colors, and a smiling
  keycap icon.

## Layout

```text
apps/
  keytest/             App source, assets, documentation and build recipe
shared/
  win32.zig            Shared XP-compatible Win32 ABI declarations
scripts/
  build.sh             App build entry point (defaults to keytest)
  check_pe.py          Shared XP executable/import/resource audit
dist/
  keytest/             Generated executable and documentation (ignored)
  keytest-xp32.zip      Generated portable package (ignored)
```

Each app imports the shared bindings as `@import("win32")`; its build recipe
supplies that module from `shared/win32.zig`. Keep app-specific assets and logic
under its own directory, and add future apps as siblings of `apps/keytest/`.

## Build

```sh
sh scripts/build.sh keytest
# Or explicitly choose the compiler:
ZIG=/path/to/zig sh scripts/build.sh keytest
```

Python 3.8+ performs the PE audit and creates the ZIP. The downloaded local
compiler in `.tools/` is used when available. See [Keytest's README](apps/keytest/README.md)
for input behavior, testing commands, and CD image transfer into UTM.
