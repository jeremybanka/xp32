use common.nu *

def main [--check] {
    init
    let files = (glob '{apps,shared}/**/*.zig')
    let zig_flags = if $check { ['--check'] } else { [] }
    let just_flags = if $check { ['--check'] } else { [] }
    checked zig fmt ...$zig_flags ...$files
    checked just --fmt ...$just_flags
}
