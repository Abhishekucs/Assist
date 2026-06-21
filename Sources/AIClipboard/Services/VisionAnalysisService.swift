import Foundation
@preconcurrency import Vision

struct VisionAnalysisService: Sendable {
    func analyze(imageURL: URL) async -> ScreenshotContext {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let visibleText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let warnings = Self.sensitiveDataWarnings(in: visibleText)
                let context = ScreenshotContext(
                    summary: Self.summary(for: visibleText),
                    visibleText: Array(visibleText.prefix(30)),
                    appsDetected: [],
                    uiElements: Self.inferUIElements(from: visibleText),
                    entities: Self.extractEntities(from: visibleText),
                    possibleUserIntent: "Use the annotated area and detected text as context for the next agent task.",
                    agentInstructions: [
                        "Inspect the annotated region first.",
                        "Use visible text as source context.",
                        "Ask before acting on sensitive data."
                    ],
                    sensitiveDataWarnings: warnings
                )

                continuation.resume(returning: context)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(url: imageURL)

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: ScreenshotContext(
                        summary: "Screenshot saved. Text analysis was unavailable.",
                        visibleText: [],
                        appsDetected: [],
                        uiElements: [],
                        entities: [],
                        possibleUserIntent: "Use the screenshot image as visual context.",
                        agentInstructions: ["Review the screenshot manually."],
                        sensitiveDataWarnings: []
                    ))
                }
            }
        }
    }

    private static func summary(for text: [String]) -> String {
        if text.isEmpty {
            return "Screenshot captured with annotation. No readable text was detected."
        }

        return "Screenshot captured with annotation. Detected \(text.count) text snippet\(text.count == 1 ? "" : "s")."
    }

    private static func inferUIElements(from text: [String]) -> [String] {
        let joined = text.joined(separator: " ").lowercased()
        var elements: [String] = []

        if joined.contains("error") { elements.append("error message") }
        if joined.contains("button") || joined.contains("submit") || joined.contains("save") { elements.append("action control") }
        if joined.contains("http://") || joined.contains("https://") { elements.append("link") }
        if joined.contains("table") || joined.contains("row") || joined.contains("column") { elements.append("table") }

        return elements
    }

    private static func extractEntities(from text: [String]) -> [String] {
        let tokenPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|https?://\S+|[/~][^\s]+"#
        let joined = text.joined(separator: " ")
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return [] }

        let range = NSRange(joined.startIndex..<joined.endIndex, in: joined)
        return regex.matches(in: joined, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: joined) else { return nil }
            return String(joined[swiftRange])
        }
    }

    private static func sensitiveDataWarnings(in text: [String]) -> [String] {
        let joined = text.joined(separator: " ").lowercased()
        var warnings: [String] = []

        if joined.contains("password") || joined.contains("secret") || joined.contains("token") {
            warnings.append("Possible credential-like text detected.")
        }

        if joined.range(of: #"\b\d{12,19}\b"#, options: .regularExpression) != nil {
            warnings.append("Possible long numeric identifier detected.")
        }

        return warnings
    }
}
