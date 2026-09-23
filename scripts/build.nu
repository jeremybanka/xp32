use common.nu *

def main [app: string = 'keytest'] {
    init
    let source = (app-dir $app)
    let output = ($root | path join 'dist' $app)
    let resource = ($env.ZIG_LOCAL_CACHE_DIR | path join $'($app).res')
    let executable = ($output | path join $'($app).exe')
    let resinator = ($root | path join '.tools' 'resinator')
    mkdir $output
    if $nu.os-info.name == 'macos' and ($resinator | path exists) {
        checked $resinator (zig-lib) '/fo' $resource ($source | path join $'($app).rc')
    } else {
        checked zig rc '/fo' $resource ($source | path join $'($app).rc')
    }
    (checked zig build-exe $resource
        -target x86-windows.xp-gnu -mcpu pentium3
        -O ReleaseSmall -fno-stack-protector -fsingle-threaded -fstrip
        --dep win32 $'-Mroot=($source)/main.zig' $'-Mwin32=($root)/shared/win32.zig'
        -fentry=WinMainCRTStartup --subsystem windows
        -lkernel32 -luser32 -lgdi32 -lwinmm $'-femit-bin=($executable)')
    checked bun scripts/check-pe.bun.ts $executable --require-icon
    checked bun scripts/package.bun.ts $app
}
