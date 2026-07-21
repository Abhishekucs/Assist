import AppKit

if let provider = CodingAgentHookCommand.provider(in: CommandLine.arguments) {
    exit(CodingAgentHookCommand.run(provider: provider, arguments: CommandLine.arguments))
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
