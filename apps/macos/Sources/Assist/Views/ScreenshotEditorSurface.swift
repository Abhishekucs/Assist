import SwiftUI

/// One continuous silhouette, from the island's top edge into the editor's rounded body.
/// The same geometry drives the reveal mask and native pointer hit testing.
struct ScreenshotEditorSurfaceShape: Shape {
    var collapsedSize: CGSize
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let progress = min(max(progress, 0), 1)
        let islandWidth = min(collapsedSize.width, rect.width)
        let islandHeight = min(collapsedSize.height, rect.height)
        let topRadius = min(PillChromeMetrics.collapsedTopCornerRadius, islandHeight / 2)
        let neckLeft = rect.midX - islandWidth / 2 + topRadius
        let neckRight = rect.midX + islandWidth / 2 - topRadius
        let left = neckLeft + (rect.minX - neckLeft) * progress
        let right = neckRight + (rect.maxX - neckRight) * progress
        let bottom = rect.minY + islandHeight + (rect.height - islandHeight) * progress
        let bodyTop = rect.minY + topRadius
            + (ScreenshotEditorMetrics.attachmentHeight(for: collapsedSize) - topRadius) * progress
        let bodyRadius = min(ScreenshotEditorMetrics.cornerRadius * progress, (bottom - bodyTop) / 2)
        let shoulderRadius = min(
            ScreenshotEditorMetrics.cornerRadius * progress,
            max(0, neckLeft - left - bodyRadius),
            max(0, bodyTop - rect.minY - topRadius)
        )
        let bottomRadius = min(
            PillChromeMetrics.collapsedBottomCornerRadius
                + (ScreenshotEditorMetrics.cornerRadius - PillChromeMetrics.collapsedBottomCornerRadius) * progress,
            max(0, bottom - bodyTop - bodyRadius),
            (right - left) / 2
        )

        var path = Path()
        path.move(to: CGPoint(x: neckLeft - topRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: neckLeft, y: rect.minY + topRadius),
            control: CGPoint(x: neckLeft, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: neckLeft, y: bodyTop - shoulderRadius))
        path.addQuadCurve(
            to: CGPoint(x: neckLeft - shoulderRadius, y: bodyTop),
            control: CGPoint(x: neckLeft, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: left + bodyRadius, y: bodyTop))
        path.addQuadCurve(
            to: CGPoint(x: left, y: bodyTop + bodyRadius),
            control: CGPoint(x: left, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: left, y: bottom - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: left + bottomRadius, y: bottom),
            control: CGPoint(x: left, y: bottom)
        )
        path.addLine(to: CGPoint(x: right - bottomRadius, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: right, y: bottom - bottomRadius),
            control: CGPoint(x: right, y: bottom)
        )
        path.addLine(to: CGPoint(x: right, y: bodyTop + bodyRadius))
        path.addQuadCurve(
            to: CGPoint(x: right - bodyRadius, y: bodyTop),
            control: CGPoint(x: right, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: neckRight + shoulderRadius, y: bodyTop))
        path.addQuadCurve(
            to: CGPoint(x: neckRight, y: bodyTop - shoulderRadius),
            control: CGPoint(x: neckRight, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: neckRight, y: rect.minY + topRadius))
        path.addQuadCurve(
            to: CGPoint(x: neckRight + topRadius, y: rect.minY),
            control: CGPoint(x: neckRight, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct ScreenshotEditorSurface: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    @ObservedObject var settings: PillSettings
    let onRevealCompleted: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        let collapsedSize = PillChromeMetrics.collapsedSize(settings: settings)
        let shape = ScreenshotEditorSurfaceShape(
            collapsedSize: collapsedSize,
            progress: isRevealed ? 1 : 0
        )

        GeometryReader { geometry in
            let attachmentHeight = ScreenshotEditorMetrics.attachmentHeight(for: collapsedSize)

            ZStack(alignment: .top) {
                Color.black

                ScreenshotQuickEditorView(viewModel: viewModel)
                    .frame(height: max(0, geometry.size.height - attachmentHeight))
                    .offset(y: attachmentHeight)
                    .opacity(isRevealed ? 1 : 0)
            }
        }
        .clipShape(shape)
        .contentShape(shape)
        .allowsHitTesting(isRevealed)
        .onAppear {
            // SwiftUI owns the reveal lifecycle. Completion, rather than a timer, enables
            // hover tracking once the visible surface has reached its final bounds.
            withAnimation(
                reduceMotion ? nil : AssistDesignTokens.ScreenshotEditor.Motion.presentation,
                completionCriteria: .removed
            ) {
                isRevealed = true
            } completion: {
                onRevealCompleted()
            }
        }
    }
}
