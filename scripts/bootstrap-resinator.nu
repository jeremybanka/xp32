use common.nu *

def main [] {
    init
    if $nu.os-info.name != 'macos' { error make {msg: 'This workaround is only needed on macOS.'} }
    let native = (native-args)
    if ($native | is-empty) {
        error make {msg: 'Set XP32_MACOS_SDK to an installed macOS 12.1 SDK.'}
    }
    let lib = (zig-lib)
    (checked zig build-exe ...$native -O ReleaseFast -lc --dep aro
        $'-Mroot=($lib)/compiler/resinator/main.zig'
        $'-Maro=($lib)/compiler/aro/aro.zig'
        -femit-bin=.tools/resinator)
}
