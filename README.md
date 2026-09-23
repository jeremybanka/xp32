# Glyph for Windows XP

A Zig 0.15.2 / Win32 keyboard canvas. Fills the primary display at its **current resolution**;
the last key stays on screen in white **Noname Sans at ¼ of the screen height**
(192 px at 1024 × 768, 256 px at 1280 × 1024).

| Input | Background |
| --- | --- |
| Consonants (including Y) | Blue `#174ED9` |
| Vowels (A E I O U) | Cyan `#00A0B5` |
| Digits | Red `#D9323B` |
| Punctuation and symbols | Orange `#E67800` |
| Modifiers, Space, navigation, function and control keys | Green `#199843` |

The font is embedded in the EXE, registered privately, and removed on exit.
No font installation, SDL, .NET, C runtime, or additional DLLs are needed.
The initial screen is blank green until a key is pressed. The supplied font
has incomplete symbol coverage (for example, `&` renders its NO GLYPH placeholder).

## Run

Copy `dist/glyph.exe` to XP and double-click it. The borderless window covers
the primary display, including the taskbar, without changing the resolution or
color depth. The canvas and font adapt when the display resolution changes.
The app reports an error if it cannot use the embedded font.

- **Alt+F4** or **Ctrl+Shift+F12** quits. The desktop display mode is never changed.
- **Esc** displays “Esc”; **Space** displays “Space”. Other controls use readable
  names so missing symbol glyphs never appear as boxes.
- Printable characters follow the active keyboard layout, Shift and Caps Lock.
  Thus `1` is red, while `!` is orange. Latin-1 accented vowels are recognized.
- Long control names shrink proportionally only when needed to fit within 90%
  of the screen width.
- Alt-Tab minimizes the app. Returning to it reapplies fullscreen placement after
  Windows finishes restoring the window, with keyboard focus restored too.
- Windows keys are captured only while Glyph is foreground, to display “Win”.
  Secure OS sequences such as Ctrl+Alt+Delete remain owned by Windows. Host/VM
  shortcuts can intercept keys before the guest application receives them.

## Build

Install [Zig 0.15.2](https://ziglang.org/download/0.15.2/) on the development host
(XP only runs the compiled output). Python 3.8+ is used for the PE audit.

```sh
ZIG=/path/to/zig sh scripts/build.sh
```

On this workspace, `sh scripts/build.sh` finds the downloaded compiler in
`.tools/zig-aarch64-macos-0.15.2/zig`. The build uses a Pentium III CPU baseline,
Windows XP 5.1 PE headers, and an explicit startup function. The audit rejects
DLLs or imported APIs outside the reviewed XP-compatible list.

The direct `build-exe` script avoids compiling Zig's native build runner, which
has a linking problem with this host's macOS 27 SDK. It still cross-compiles the
game normally; the Windows executable does not depend on that SDK.

Run input classification tests on a typical host with:

```sh
zig test src/keys.zig
```

On this Apple Silicon host, the verified test command is:

```sh
.tools/zig-aarch64-macos-0.15.2/zig test src/keys.zig \
  -target aarch64-macos.12.1 \
  --sysroot /Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk \
  --cache-dir .zig-cache --global-cache-dir .tools/cache
```

To make a CD image for transfer into UTM on macOS:

```sh
hdiutil makehybrid -iso -joliet -default-volume-name GLYPH \
  -o /tmp/xp32-glyph.iso dist
```

## Implementation

`main.zig` owns fullscreen placement, the responsive font, and buffered GDI drawing.
`src/win32.zig` declares the minimal 32-bit Windows ABI. `src/keys.zig` keeps input
classification separate from the platform layer. The event-driven message loop
does not continuously repaint an unchanged screen.

The font was copied from the user's installed `nonamesans-web-webfont.ttf`.
Its internal family name is **Noname Sans Web**, with a Regular face. The app
requests weight 600, matching the user's WezTerm window-frame configuration.
