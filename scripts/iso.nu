use common.nu *

def main [app: string = 'keytest'] {
    init
    app-dir $app | ignore
    if $nu.os-info.name != 'macos' { error make {msg: 'ISO creation requires macOS hdiutil.'} }
    (checked hdiutil makehybrid -iso -joliet -ov
        -default-volume-name ($app | str uppercase)
        -o $'dist/($app).iso' $'dist/($app)')
}
