import Foundation

enum CaptureContextMarkdown {
    static func render(item: CaptureItem) -> String {
        """
        # Assist Capture Context

        ## What I want to do
        \(instruction(for: item.context.dictation))

        ## Visual context
        Use the attached screenshot as the source of truth.
        If an annotation or marked region is visible, prioritize it.
        Read relevant UI text, code, and error logs directly from the image.
        If something is not legible, say so instead of inferring it.

        ## Screenshot
        `\(item.imagePath)`
        """
    }

    static func preview(from markdown: String) -> String {
        let heading = "## What I want to do"
        if let headingRange = markdown.range(of: heading) {
            let sectionStart = headingRange.upperBound
            let remaining = markdown[sectionStart...]
            let sectionEnd = remaining.range(of: "\n## ")?.lowerBound ?? remaining.endIndex
            let section = remaining[..<sectionEnd]
            let collapsed = collapseWhitespace(String(section))
            if !collapsed.isEmpty {
                return collapsed
            }
        }

        return collapseWhitespace(markdown)
    }

    private static func instruction(for dictation: DictationContext?) -> String {
        guard let dictation else {
            return "No voice instruction was recorded for this capture."
        }

        switch dictation.status {
        case .transcribing:
            return "Transcription is still in progress."
        case .ready:
            return dictation.transcript
        case .noSpeech:
            return "No speech was detected for this capture."
        case .failed:
            if let errorDetails = dictation.errorDetails, !errorDetails.isEmpty {
                return "Transcription failed:\n\(errorDetails)"
            }
            return "Transcription failed without error details."
        }
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
