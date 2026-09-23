# Verification status

## Repository tooling

- `mise.toml` pins Zig, just, Nushell, and Bun; `bun.lock` locks script dependencies.
- `just check` builds and audits the XP executable, checks Zig/justfile formatting,
  and passes four Zig input/speech tests plus nine Bun build-audit, packaging, and audio tests.
- Bun regression tests reject newer Windows subsystem requirements, unreviewed
  imports, missing resources, and malformed icon mask data. The ZIP test verifies
  its executable and documentation match the current build and sources.
- GitHub Actions passed the original build and packaging checks on Ubuntu and uploaded the portable ZIP
  for commit `4161ed8` ([run](https://github.com/jeremybanka/xp32/actions/runs/35838905159)).
- GUI validation below describes the app revision; the separate font update is described below.

## Keytest packaging revision

- Renamed the executable, window class, window/error titles and version metadata
  to Keytest. Moved app code and assets to apps/keytest, with Win32 in shared.
- XP PE/import audit passes: 57,344 bytes, 47 XP-compatible imports.
- Linked icon resource audit passes: 16/24/32/48 px uncompressed 32-bit DIBs,
  matching group entries, full mask data and application version metadata.
- Computer/UTM live verification passed: Explorer displays the keycap icon,
  keytest.exe filename and Keytest description. The taskbar displays Keytest
  with its icon, and the task switcher uses the same icon.
- Renamed executable launched fullscreen and rendered k on blue. Alt-Tab left
  the desktop usable. The new media is mounted as KEYTEST (D:) from
  /private/tmp/keytest.iso. Input capture is off.
- Input tests, Zig formatting, and whitespace checks pass after relocation.

## Responsive prototype validation (before rename)

- Cross-compiled with official Zig 0.15.2 for `x86-windows.xp-gnu`, Pentium III.
- PE audit passes: PE32 GUI, Windows/subsystem 5.1, 37,888 bytes; 46 reviewed
  imports from kernel32, user32 and gdi32 only.
- No display-mode-changing API is allowed by the import audit.
- Fullscreen placement uses the current primary display dimensions.
- Font size is one quarter of client height; long labels shrink to fit 90% width.
- Activation queues placement until after the Windows restore operation and
  retains default keyboard-focus handling. Canvas allocation follows client size.
- Computer/UTM validation: the revised GLYPH3 build launched at 1024 × 768,
  filled the entire guest display, and rendered the responsive font.
- Verified b/blue, a/cyan, 7/red and Backspace/green. Backspace fits the screen.
- Verified two defocus/restore cycles with working keyboard input and complete
  fullscreen coverage after returning. No resolution switch on Alt-Tab.
- Exercised external 800 × 600 display changes while minimized; XP reverted
  both changes before the confirmation was accepted. Restoration at 1024 × 768
  passed, but rendering/font size at a second resolution is not yet verified.
- Input classification tests and Zig formatting check pass.
- The new build is mounted as GLYPH3 (D:) from /private/tmp/xp32-glyph3.iso.
  XP is left at its original 1024 × 768, High (24 bit), with capture released.

## Updated font

The original font rendered NO GLYPH for ampersand. The embedded asset now uses
the user's modified NonameSans-Web.otf export, which adds an ampersand.

- Windows Unicode cmap maps U+0026 to glyph 149; a FreeType preview renders the
  ampersand correctly. The family remains Noname Sans Web.
- Updated executable passes the XP audit: 46,080 bytes and 47 reviewed imports.
  All two Zig tests and six Bun tests pass.
- Live XP verification passed on September 23, 2026 using the updated ISO in UTM:
  Keytest launched fullscreen at 1024 × 768, rendered Enter in white on green,
  then Shift+7 rendered the custom ampersand in white on orange. The OTF loaded
  successfully without a font substitution error. Input capture remains off.

## Spoken key feedback

- Replaced the rejected letter-name/cropped-syllable experiments with 145 whole
  Kokoro utterances: NATO words, numbers, punctuation, and control-key names.
- Every clip is embedded in the standalone executable. Current PE audit passes
  with 48 imports; the only additional DLL/API is the XP-era
  `winmm.dll!PlaySoundA`. The package requires no external audio files.
- Four Zig tests cover visual categories and speech routing, including every
  printable ASCII character and every supported control label, shifted symbols,
  repeat suppression, and no duplicate Space announcement.
- Nine Bun tests cover PE auditing, packaging, PCM validity, dictionary/hash
  consistency, generated-index freshness, and all embedded audio bytes.
- Playback is asynchronous, replaces earlier speech, and stops on deactivation
  and exit. Hook-only Windows/Print Screen keys post audio work to the window.
- Live Computer/UTM check on September 23, 2026: mounted the new 10.8 MB ISO,
  closed two older Keytest instances, and launched a single fresh `D:\keytest.exe`.
  Confirmed fullscreen at 1024 × 768, b/blue, a/cyan, 7/red, ampersand/orange,
  Control/green, and Space/green. Alt-Tab restored the desktop and returning
  restored full display coverage. Input capture is released; the app is open.
- Audible output, repeat suppression, and interruption timing still need a
  listening check. The Computer tool returns screenshots and input state, not
  audio; no audible-pass claim is made from the visual check. Speech routing
  and PCM embedding are covered by the automated tests above.

- Naming update: both Windows-key positions now display and say "Super".
  The regenerated clip, embedded index, XP build, and all 13 tests pass.

## Regression checklist

1. Launch at 1024 × 768: borderless full coverage, no desktop/taskbar visible,
   192 px nominal font size. Repeat at 1280 × 1024 for 256 px type.
2. Press B, A, 7, Shift+1 and Shift+7. Expect white b/a/7/!/& on
   blue/cyan/red/orange/orange, with literal ampersand rendering.
3. Check Shift, Ctrl, Alt, Enter, Esc, Space, arrows and Backspace labels on green.
4. Alt-Tab out and return repeatedly, including quick switches. Confirm full
   coverage, centered text and working input after every return.
5. Change the XP resolution while the app is minimized, then return. Confirm
   window, canvas and font adopt the new dimensions.
6. Check spoken Alfa, Bravo, Delta, Papa, Seven, Ampersand, Shift, Control, Enter,
   Space, Left arrow, and F12. Confirm Windows/Print Screen speech when received.
7. Hold a letter and a modifier: speech should play once per physical press.
   Quickly press two different keys: the latest should replace the first.
8. Alt-Tab during speech: audio should stop. Return and verify speech resumes
   on the next press. Quit with Alt+F4; confirm audio stops and XP's resolution
   and color depth stay unchanged.

## Earlier build

The user verified rendering in XP but reported a 1024 × 768 window remaining
inside a 1280 × 1024 desktop after defocus/refocus. The current revision removes
exclusive display-mode switching entirely, per the user's revised request.
UTM temporarily has Return and G Send Key shortcuts from the initial test session.
