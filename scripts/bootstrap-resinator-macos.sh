#!/bin/sh
# Work around Zig 0.15.2's native tool linking on this macOS 27 host by
# compiling its bundled resource compiler against an older installed SDK.
set -eu
cd "$(dirname "$0")/.."
ZIG=${ZIG:-.tools/zig-aarch64-macos-0.15.2/zig}
SDK=${SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk}
zig_lib_dir=$("$ZIG" env | sed -n 's/^ *\.lib_dir = "\(.*\)",$/\1/p')
mkdir -p .tools/cache .zig-cache
"$ZIG" build-exe -target aarch64-macos.12.1 --sysroot "$SDK" \
    -O ReleaseFast -lc --dep aro \
    -Mroot="$zig_lib_dir/compiler/resinator/main.zig" \
    -Maro="$zig_lib_dir/compiler/aro/aro.zig" \
    -femit-bin=.tools/resinator --cache-dir .zig-cache --global-cache-dir .tools/cache
