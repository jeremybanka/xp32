#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${ZIG:-}" ]; then
    if [ -x .tools/zig-aarch64-macos-0.15.2/zig ]; then
        ZIG=.tools/zig-aarch64-macos-0.15.2/zig
    else
        ZIG=zig
    fi
fi
if [ "$("$ZIG" version)" != 0.15.2 ]; then
    echo 'This project requires Zig 0.15.2 (set ZIG to its executable).' >&2
    exit 1
fi
mkdir -p dist .tools/cache
# Compile directly: no native build-runner dependency on the host macOS SDK.
"$ZIG" build-exe main.zig \
    -target x86-windows.xp-gnu -mcpu pentium3 \
    -O ReleaseSmall -fno-stack-protector -fsingle-threaded -fstrip \
    -fentry=WinMainCRTStartup --subsystem windows \
    -lkernel32 -luser32 -lgdi32 \
    -femit-bin=dist/glyph.exe \
    --cache-dir .zig-cache --global-cache-dir .tools/cache
python3 scripts/check_pe.py dist/glyph.exe

