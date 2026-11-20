import AppKit

let selfCheck = CommandLine.arguments.contains("--self-check")

// Outside the bundle macOS has no usage text to show for a permission (menubar-app R5).
if Bundle.main.bundleIdentifier == nil && !selfCheck {
    FileHandle.standardError.write(Data("NextUp: run build/NextUp.app (scripts/build-app.sh), or pass --self-check\n".utf8))
    exit(64)
}

let app = NSApplication.shared
let delegate = AppDelegate(selfCheck: selfCheck)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
