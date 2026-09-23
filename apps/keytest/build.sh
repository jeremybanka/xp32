#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
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
mkdir -p dist/keytest .tools/cache .zig-cache
export ZIG_GLOBAL_CACHE_DIR="$PWD/.tools/cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-cache"
# This host's macOS SDK needs the separately bootstrapped resource compiler.
# Other hosts can use the same compiler through Zig's normal `rc` command.
if [ -x .tools/resinator ]; then
    zig_lib_dir=$("$ZIG" env | sed -n 's/^ *\.lib_dir = "\(.*\)",$/\1/p')
    .tools/resinator "$zig_lib_dir" /fo .zig-cache/keytest.res apps/keytest/keytest.rc
else
    "$ZIG" rc /fo .zig-cache/keytest.res apps/keytest/keytest.rc
fi
# Compile directly: no native build-runner dependency on the host macOS SDK.
"$ZIG" build-exe .zig-cache/keytest.res \
    -target x86-windows.xp-gnu -mcpu pentium3 \
    -O ReleaseSmall -fno-stack-protector -fsingle-threaded -fstrip \
    --dep win32 -Mroot=apps/keytest/main.zig -Mwin32=shared/win32.zig \
    -fentry=WinMainCRTStartup --subsystem windows \
    -lkernel32 -luser32 -lgdi32 \
    -femit-bin=dist/keytest/keytest.exe \
    --cache-dir .zig-cache --global-cache-dir .tools/cache
python3 scripts/check_pe.py dist/keytest/keytest.exe --require-icon

cp apps/keytest/README.md apps/keytest/TESTING.md dist/keytest/
python3 - <<'PYZIP'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
with ZipFile('dist/keytest-xp32.zip', 'w', ZIP_DEFLATED) as archive:
    for name in ('keytest.exe', 'README.md', 'TESTING.md'):
        archive.write(Path('dist/keytest') / name, name)
PYZIP
