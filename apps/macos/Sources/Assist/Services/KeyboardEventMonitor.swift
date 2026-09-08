import AppKit
import Carbon
import CoreGraphics

@MainActor
protocol KeyboardEventMonitoring: AnyObject {
    var onEvent: ((KeyboardSoundEvent) -> Void)? { get set }
    var onInterruption: (() -> Void)? { get set }
    var hasPermission: Bool { get }
    func requestPermission()
    func start() throws
    func stop()
    func resetPressedKeys()
}

@MainActor
final class KeyboardEventMonitor: KeyboardEventMonitoring {
    var onEvent: ((KeyboardSoundEvent) -> Void)?
    var onInterruption: (() -> Void)?
    var hasPermission: Bool { CGPreflightListenEventAccess() }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var state = KeyboardPressState()

    func requestPermission() { _ = CGRequestListenEventAccess() }

    func resetPressedKeys() { state.reset() }

    func start() throws {
        guard tap == nil else { return }
        guard hasPermission else { throw KeyboardSoundError.inputPermission }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) {
            $0 | (1 << $1.rawValue)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                // This source is installed only on the main run loop.
                MainActor.assumeIsolated {
                    Unmanaged<KeyboardEventMonitor>.fromOpaque(context).takeUnretainedValue()
                        .receive(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { throw KeyboardSoundError.eventTap }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw KeyboardSoundError.eventTap
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        state.reset()
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.reset()
            onInterruption?()
            if hasPermission, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard hasPermission, !IsSecureEventInputEnabled() else {
            state.reset()
            onInterruption?()
            return
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let down: Bool
        switch type {
        case .keyDown: down = true
        case .keyUp: down = false
        case .flagsChanged:
            // Device-dependent modifier bits distinguish left/right keys when
            // both are held. Caps Lock and Fn use their aggregate state.
            let flags = event.flags.rawValue
            switch code {
            case 56: down = flags & UInt64(NX_DEVICELSHIFTKEYMASK) != 0
            case 60: down = flags & UInt64(NX_DEVICERSHIFTKEYMASK) != 0
            case 59: down = flags & UInt64(NX_DEVICELCTLKEYMASK) != 0
            case 62: down = flags & UInt64(NX_DEVICERCTLKEYMASK) != 0
            case 58: down = flags & UInt64(NX_DEVICELALTKEYMASK) != 0
            case 61: down = flags & UInt64(NX_DEVICERALTKEYMASK) != 0
            case 55: down = flags & UInt64(NX_DEVICELCMDKEYMASK) != 0
            case 54: down = flags & UInt64(NX_DEVICERCMDKEYMASK) != 0
            case 57: down = event.flags.contains(.maskAlphaShift)
            case 63: down = event.flags.contains(.maskSecondaryFn)
            default: return
            }
        default: return
        }
        if let hit = state.event(keyCode: code, isDown: down,
                                 isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0 && type == .keyDown) {
            onEvent?(hit)
        }
    }
}

enum KeyboardSoundError: LocalizedError {
    case inputPermission, eventTap, missingSamples, rendererUnavailable
    var errorDescription: String? {
        switch self {
        case .inputPermission: "Allow Assist in Privacy & Security → Input Monitoring for keyboard sounds and the visualizer."
        case .eventTap: "Keyboard listening could not start. Check Input Monitoring for this copy of Assist, then retry."
        case .missingSamples: "The bundled keyboard sounds are missing or invalid. Reinstall Assist to restore them."
        case .rendererUnavailable: "The keyboard audio renderer could not be created."
        }
    }
}
