use common.nu *

def main [] {
    init
    # Audit tests mutate copies of the actual freshly linked executable.
    checked nu --no-config-file scripts/build.nu keytest
    checked zig test apps/keytest/speech.zig ...(native-args)
    checked bun test scripts
}
