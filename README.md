# XP32

Small native Windows XP applications written in Zig, sharing a minimal Win32
layer. Builds target 32-bit XP with a Pentium III baseline.

## Apps

- [Keytest](apps/keytest/README.md): a responsive fullscreen keyboard tester with
  white Noname Sans glyphs, input-dependent background colors, and a smiling
  keycap icon.

## Setup

Install [mise](https://mise.jdx.dev/), then run from the repository root:

```sh
mise trust
mise install
mise exec -- just setup
mise exec -- just check
```

`mise.toml` pins Zig 0.15.2, just 1.58.0, Nushell 0.115.1, and Bun 1.4.2.
With mise activated in your shell, omit `mise exec --` from these commands.
`just setup` installs the Bun dependencies using `bun.lock`. Development scripts
support macOS and Linux; XP needs only the resulting executable.

On macOS 27, Zig's native resource compiler needs an older SDK. With the macOS
12.1 SDK installed, run `just bootstrap-resinator` once before building. It
uses `/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk`; set
`XP32_MACOS_SDK` to override that location. Native Zig tests automatically use
that SDK when available. Other hosts use `zig rc` directly.

## Commands

Run `just` to list recipes. All commands below assume mise is activated.

| Command | Purpose |
| --- | --- |
| `just build` | Compile Keytest, audit XP compatibility, and package a ZIP |
| `just test` | Build, run input classification tests, and test the PE audit and ZIP |
| `just check` | Check Zig/justfile formatting, build, and run all tests |
| `just fmt` | Format Zig sources and the justfile |
| `just iso` | Build and create `dist/keytest.iso` for UTM on macOS |
| `just icon` | Regenerate the XP ICO from its PNG artwork |

Build output is `dist/keytest/keytest.exe` and `dist/keytest-xp32.zip`.
`just build keytest` and `just iso keytest` also accept the app name explicitly.

## Layout

```text
apps/
  keytest/             App source, resources, assets, and documentation
shared/
  win32.zig            Shared XP-compatible Win32 ABI declarations
scripts/
  *.nu                 Build, test, formatting, SDK bootstrap, and ISO orchestration
  *.bun.ts             PE audit, ZIP packaging, and ICO export
  *.test.ts            Build-audit regression tests
mise.toml              Pinned development tools
justfile               Thin entry points into scripts/
.github/workflows/     Build and test automation
dist/                  Generated executables, documentation, ZIPs, and ISOs (ignored)
```

Each app imports the shared bindings as `@import("win32")`; `scripts/build.nu`
supplies that module from `shared/win32.zig`. Keep app-specific assets and logic
under its own directory, and add future apps as siblings of `apps/keytest/`.
Register new apps in the build and packaging scripts as they are added.

## CI

GitHub Actions runs `just setup` and `just check` on Ubuntu for pushes to `main`,
pull requests, and manual dispatch. It cross-compiles the XP executable, checks
PE headers/imports/icon resources, runs two Zig tests and six Bun tests, and
uploads the portable ZIP as the `keytest-xp32` artifact. GUI behavior is verified
separately in XP through UTM; CI does not run the Windows application.
