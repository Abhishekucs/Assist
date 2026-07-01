import AppKit
import CoreGraphics

@MainActor
protocol ControlGestureMonitorDelegate: AnyObject {
    func controlGestureDidBegin(at globalPoint: CGPoint)
    func controlGestureDidMove(to globalPoint: CGPoint)
    func controlGestureDidEnd(at globalPoint: CGPoint)
    func controlOptionScreenshotRequested(at globalPoint: CGPoint)
}

@MainActor
final class ControlGestureMonitor: @unchecked Sendable {
    private enum Timing {
        static let controlHoldDelay: TimeInterval = 0.10
        static let pointerPollInterval: TimeInterval = 1.0 / 60.0
    }

    weak var delegate: ControlGestureMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var isControlDown = false
    private var isControlOptionDown = false
    private var suppressControlGestureUntilRelease = false
    private var pendingControlBeginPoint: CGPoint?
    private var pendingControlBeginWorkItem: DispatchWorkItem?
    private var pointerPollTimer: Timer?

    func start() throws {
        guard eventTap == nil else { return }
        DebugLogger.log("monitor.start.request", [
            "accessibility": "\(AXIsProcessTrusted())"
        ])

        let mask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<ControlGestureMonitor>.fromOpaque(refcon).takeUnretainedValue()
            let controlIsDown = event.flags.contains(.maskControl)
            let optionIsDown = event.flags.contains(.maskAlternate)
            monitor.handle(type: type, controlIsDown: controlIsDown, optionIsDown: optionIsDown)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DebugLogger.log("monitor.start.error", ["reason": "eventTapUnavailable"])
            throw AppError.eventTapUnavailable
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        startCocoaFlagsFallback()
        DebugLogger.log("monitor.start.ready")
    }

    func stop() {
        DebugLogger.log("monitor.stop")
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
        }

        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
        }

        cancelPendingControlBegin()
        stopPointerPolling()
        eventTap = nil
        runLoopSource = nil
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        isControlDown = false
        isControlOptionDown = false
        suppressControlGestureUntilRelease = false
    }

    nonisolated private func handle(type: CGEventType, controlIsDown: Bool, optionIsDown: Bool) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { [weak self] in
                guard let self, let eventTap = self.eventTap else { return }
                DebugLogger.log("monitor.event-tap.disabled", ["type": "\(type.rawValue)"])
                CGEvent.tapEnable(tap: eventTap, enable: true)
                DebugLogger.log("monitor.event-tap.reenabled")
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let point = NSEvent.mouseLocation

            switch type {
            case .flagsChanged:
                self.handleFlagsChanged(controlIsDown: controlIsDown, optionIsDown: optionIsDown, point: point)
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                self.handleMouseMoved(to: point)
            default:
                break
            }
        }
    }

    private func startCocoaFlagsFallback() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async { [weak self] in
                self?.handle(event: event)
            }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async { [weak self] in
                self?.handle(event: event)
            }

            return event
        }
        DebugLogger.log("monitor.cocoa-fallback.ready")
    }

    private func handle(event: NSEvent) {
        let flags = event.modifierFlags
        handleFlagsChanged(
            controlIsDown: flags.contains(.control),
            optionIsDown: flags.contains(.option),
            point: NSEvent.mouseLocation
        )
    }

    private func handleFlagsChanged(controlIsDown: Bool, optionIsDown: Bool, point: CGPoint) {
        let chordIsDown = controlIsDown && optionIsDown

        if chordIsDown && !isControlOptionDown {
            isControlOptionDown = true
            isControlDown = false
            suppressControlGestureUntilRelease = true
            cancelPendingControlBegin()
            stopPointerPolling()
            DebugLogger.log("monitor.control-option.down", ["point": DebugLogger.describe(point)])
            delegate?.controlOptionScreenshotRequested(at: point)
            return
        }

        if !chordIsDown {
            isControlOptionDown = false
        }

        if !controlIsDown {
            cancelPendingControlBegin()
            if isControlDown {
                isControlDown = false
                stopPointerPolling()
                DebugLogger.log("monitor.control.up", ["point": DebugLogger.describe(point)])
                delegate?.controlGestureDidEnd(at: point)
            }
            suppressControlGestureUntilRelease = false
            return
        }

        guard !optionIsDown, !suppressControlGestureUntilRelease else {
            return
        }

        if !isControlDown, pendingControlBeginWorkItem == nil {
            DebugLogger.log("monitor.control.pending", ["point": DebugLogger.describe(point)])
            scheduleControlBegin(at: point)
        }
    }

    private func handleMouseMoved(to point: CGPoint) {
        if isControlDown {
            delegate?.controlGestureDidMove(to: point)
            return
        }

        if pendingControlBeginWorkItem != nil, !suppressControlGestureUntilRelease {
            firePendingControlBegin()
            delegate?.controlGestureDidMove(to: point)
        }
    }

    private func scheduleControlBegin(at point: CGPoint) {
        pendingControlBeginPoint = point

        let workItem = DispatchWorkItem { [weak self] in
            self?.firePendingControlBegin()
        }

        pendingControlBeginWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.controlHoldDelay, execute: workItem)
    }

    private func firePendingControlBegin() {
        guard let point = pendingControlBeginPoint else { return }

        cancelPendingControlBegin()
        guard !isControlDown, !suppressControlGestureUntilRelease else { return }

        isControlDown = true
        DebugLogger.log("monitor.control.down", ["point": DebugLogger.describe(point)])
        delegate?.controlGestureDidBegin(at: point)
        startPointerPolling()
    }

    private func cancelPendingControlBegin() {
        pendingControlBeginWorkItem?.cancel()
        pendingControlBeginWorkItem = nil
        pendingControlBeginPoint = nil
    }

    private func startPointerPolling() {
        pointerPollTimer?.invalidate()
        DebugLogger.log("monitor.pointer-poll.start")

        let timer = Timer(timeInterval: Timing.pointerPollInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isControlDown else { return }
                self.delegate?.controlGestureDidMove(to: NSEvent.mouseLocation)
            }
        }

        pointerPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPointerPolling() {
        pointerPollTimer?.invalidate()
        pointerPollTimer = nil
        DebugLogger.log("monitor.pointer-poll.stop")
    }
}
