import AppKit

struct AnnotationTrailSample: Equatable {
    let point: CGPoint
    let timestamp: TimeInterval
}

struct AnnotationTrailState: Equatable {
    private(set) var samples: [AnnotationTrailSample] = []
    private(set) var sourcePointCount = 0

    mutating func begin(points: [CGPoint], at timestamp: TimeInterval) {
        samples = points.map { AnnotationTrailSample(point: $0, timestamp: timestamp) }
        sourcePointCount = points.count
    }

    mutating func update(points: [CGPoint], at timestamp: TimeInterval) {
        guard points.count >= sourcePointCount else {
            begin(points: points, at: timestamp)
            return
        }

        let newPoints = points.dropFirst(sourcePointCount)
        samples.append(contentsOf: newPoints.map {
            AnnotationTrailSample(point: $0, timestamp: timestamp)
        })
        sourcePointCount = points.count
    }

    mutating func removeExpired(at timestamp: TimeInterval, lifetime: TimeInterval) {
        samples.removeAll { timestamp - $0.timestamp >= lifetime }
    }

    func visibility(of sample: AnnotationTrailSample, at timestamp: TimeInterval, lifetime: TimeInterval) -> CGFloat {
        guard lifetime > 0 else { return 0 }
        let age = max(timestamp - sample.timestamp, 0)
        let remaining = max(1 - age / lifetime, 0)
        return CGFloat(remaining * remaining)
    }
}

final class AnnotationOverlayView: NSView {
    nonisolated static let trailLifetime: TimeInterval = 2

    private enum Palette {
        static let rose = NSColor(calibratedRed: 1, green: 0.24, blue: 0.46, alpha: 1)
        static let coral = NSColor(calibratedRed: 1, green: 0.36, blue: 0.27, alpha: 1)
        static let amber = NSColor(calibratedRed: 1, green: 0.68, blue: 0.25, alpha: 1)
    }

    private var trail = AnnotationTrailState()
    private var strokeWidth: CGFloat = 5
    private var displayTimer: Timer?
    private var currentTime: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func begin(stroke: Stroke) {
        strokeWidth = stroke.width
        trail.begin(points: stroke.points, at: currentTime)
        startDisplayTimer()
        needsDisplay = true
    }

    func update(stroke: Stroke) {
        strokeWidth = stroke.width
        trail.update(points: stroke.points, at: currentTime)
        needsDisplay = true
    }

    func clear() {
        displayTimer?.invalidate()
        displayTimer = nil
        trail = AnnotationTrailState()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let timestamp = currentTime
        let samples = trail.samples
        guard let latest = samples.last else { return }

        if samples.count > 1 {
            for index in 1..<samples.count {
                drawSegment(
                    from: samples[index - 1],
                    to: samples[index],
                    index: index,
                    count: samples.count,
                    at: timestamp
                )
            }
        }

        drawOrb(at: latest.point, timestamp: timestamp)
    }

    private func startDisplayTimer() {
        guard displayTimer == nil else { return }

        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(refreshTrail),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    @objc
    private func refreshTrail() {
        trail.removeExpired(at: currentTime, lifetime: Self.trailLifetime)
        needsDisplay = true
    }

    private func drawSegment(
        from start: AnnotationTrailSample,
        to end: AnnotationTrailSample,
        index: Int,
        count: Int,
        at timestamp: TimeInterval
    ) {
        let visibility = min(
            trail.visibility(of: start, at: timestamp, lifetime: Self.trailLifetime),
            trail.visibility(of: end, at: timestamp, lifetime: Self.trailLifetime)
        )
        guard visibility > 0 else { return }

        let position = CGFloat(index) / CGFloat(max(count - 1, 1))
        let color = gradientColor(at: position)
        let path = NSBezierPath()
        path.move(to: start.point)
        path.line(to: end.point)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        color.withAlphaComponent(0.08 * visibility).setStroke()
        path.lineWidth = strokeWidth + 15
        path.stroke()

        color.withAlphaComponent(0.18 * visibility).setStroke()
        path.lineWidth = strokeWidth + 8
        path.stroke()

        color.withAlphaComponent(0.78 * visibility).setStroke()
        path.lineWidth = max(strokeWidth - 1, 2.5)
        path.stroke()

        NSColor.white.withAlphaComponent(0.42 * visibility).setStroke()
        path.lineWidth = 1.1
        path.stroke()
    }

    private func drawOrb(at point: CGPoint, timestamp: TimeInterval) {
        let phase = timestamp.truncatingRemainder(dividingBy: 1.4) / 1.4
        let pulse = (sin(timestamp * .pi * 2 / 1.4) + 1) / 2
        let radius = CGFloat(8.5 + pulse * 1.5)

        Palette.coral.withAlphaComponent(0.1).setStroke()
        let glow = NSBezierPath(ovalIn: CGRect(
            x: point.x - radius - 4,
            y: point.y - radius - 4,
            width: (radius + 4) * 2,
            height: (radius + 4) * 2
        ))
        glow.lineWidth = 7
        glow.stroke()

        let segmentCount = 24
        for index in 0..<segmentCount {
            let fraction = CGFloat(index) / CGFloat(segmentCount)
            let startAngle = CGFloat(phase * 360) + fraction * 360
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: point,
                radius: radius,
                startAngle: startAngle,
                endAngle: startAngle + 360 / CGFloat(segmentCount) + 0.8,
                clockwise: false
            )
            arc.lineWidth = 2.4
            arc.lineCapStyle = .round
            gradientColor(at: fraction).withAlphaComponent(0.9).setStroke()
            arc.stroke()
        }

        NSColor.white.withAlphaComponent(0.84).setFill()
        NSBezierPath(ovalIn: CGRect(
            x: point.x - 2.2,
            y: point.y - 2.2,
            width: 4.4,
            height: 4.4
        )).fill()
    }

    private func gradientColor(at fraction: CGFloat) -> NSColor {
        let clamped = min(max(fraction, 0), 1)
        if clamped < 0.5 {
            return Palette.rose.blended(
                withFraction: clamped * 2,
                of: Palette.coral
            ) ?? Palette.coral
        }

        return Palette.coral.blended(
            withFraction: (clamped - 0.5) * 2,
            of: Palette.amber
        ) ?? Palette.amber
    }
}
