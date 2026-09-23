export const root = path self ..

export def --env init [] {
    cd $root
    $env.ZIG_GLOBAL_CACHE_DIR = ($root | path join '.tools' 'cache')
    $env.ZIG_LOCAL_CACHE_DIR = ($root | path join '.zig-cache')
    mkdir $env.ZIG_GLOBAL_CACHE_DIR $env.ZIG_LOCAL_CACHE_DIR
    if ((^zig version | str trim) != '0.15.2') {
        error make {msg: 'Zig 0.15.2 is required. Run mise install.'}
    }
}

export def --wrapped checked [command: string, ...args: string] {
    ^$command ...$args
    if $env.LAST_EXIT_CODE != 0 { exit $env.LAST_EXIT_CODE }
}

export def app-dir [app: string] {
    if $app != 'keytest' { error make {msg: $'Unknown app: ($app). Available: keytest'} }
    $root | path join 'apps' $app
}

export def zig-lib [] {
    ^zig env | parse --regex '\.lib_dir = "(?<lib>[^"]+)"' | get lib.0 | path expand
}

# Zig 0.15.2 native tools cannot link against this host's macOS 27 SDK.
# Explicit overrides are also useful on hosts with a different SDK location.
export def native-args [] {
    let sdk = ($env.XP32_MACOS_SDK? | default '/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk')
    if $nu.os-info.name == 'macos' and ($sdk | path exists) {
        let arch = if $nu.os-info.arch == 'aarch64' { 'aarch64' } else { 'x86_64' }
        ['-target' $'($arch)-macos.12.1' '--sysroot' $sdk]
    } else { [] }
}
