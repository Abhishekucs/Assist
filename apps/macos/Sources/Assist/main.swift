import AppKit

if CommandLine.arguments.contains(CodexHookIPC.commandLineFlag) {
    exit(CodexHookCommand.run())
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
if AppIdentity.isDevelopmentBundle {
    app.setActivationPolicy(.regular)
} else {
    app.setActivationPolicy(.accessory)
}

if CommandLine.arguments.contains("--request-screen-access") {
    app.activate(ignoringOtherApps: true)
    _ = CGRequestScreenCaptureAccess()
    exit(0)
}

app.run()
