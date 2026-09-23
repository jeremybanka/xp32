set shell := ["nu", "--no-config-file", "-c"]

default:
    @just --list

# Install the locked Bun script dependencies.
setup:
    bun install --frozen-lockfile

# Build, audit, and package an XP app.
build app="keytest":
    nu --no-config-file scripts/build.nu {{ quote(app) }}

# Build and run Zig tests plus executable-audit regression tests.
test:
    nu --no-config-file scripts/test.nu

fmt:
    nu --no-config-file scripts/fmt.nu

fmt-check:
    nu --no-config-file scripts/fmt.nu --check

check: fmt-check test

# One-time workaround for Zig's native resource compiler on macOS 27.
bootstrap-resinator:
    nu --no-config-file scripts/bootstrap-resinator.nu

# macOS: create CD media for transfer into UTM.
iso app="keytest": (build app)
    nu --no-config-file scripts/iso.nu {{ quote(app) }}

# Regenerate the XP ICO from the existing PNG artwork.
icon:
    bun scripts/export-icon.bun.ts

# Generate complete NATO words and names for numbers, symbols, and controls.
voice *ids:
    bun scripts/generate-speech.bun.ts {{ quote(ids) }}

# Validate assets, rebuild the embedded index, and refresh audition reels (no TTS).
voice-index:
    bun scripts/speech-index.bun.ts
