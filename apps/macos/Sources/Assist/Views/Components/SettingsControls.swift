import SwiftUI

private typealias Tokens = AssistDesignTokens

/// A scrolling settings page. It draws no background of its own; the settings
/// dialog paints the surface behind it.
struct SettingsDetailPage<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    @Environment(\.assistTheme) private var theme

    init(title: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxLarge) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
                    Text(title)
                        .font(AssistFont.pageTitle())
                        .foregroundStyle(theme.foreground)
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle {
                        Text(subtitle)
                            .font(AssistFont.caption())
                            .foregroundStyle(theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, Tokens.Settings.headerTopInset)

                content
            }
            .padding(.trailing, Tokens.Spacing.medium)
            .padding(.bottom, Tokens.Spacing.xxxLarge)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

/// A labeled, outlined settings group. Rows are leading-aligned; a row that
/// should be centered, such as a preview, sets its own full-width frame.
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.assistTheme) private var theme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.large)
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            Text(title)
                .font(AssistFont.section())
                .foregroundStyle(theme.muted)
                .padding(.horizontal, Tokens.Settings.rowInset)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Tokens.Spacing.xxSmall)
            .background(theme.card, in: shape)
            .overlay {
                shape.strokeBorder(theme.border, lineWidth: Tokens.Control.borderWidth)
            }
        }
    }
}

struct SettingToggleRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool
    @Environment(\.assistTheme) private var theme

    init(title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: Tokens.Settings.rowInset) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxSmall) {
                Text(title)
                    .font(AssistFont.label())
                    .foregroundStyle(theme.foreground)

                if let detail {
                    Text(detail)
                        .font(AssistFont.caption())
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Tokens.Settings.rowInset)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .accessibilityLabel(title)
                .toggleStyle(.switch)
                .tint(theme.accent)
                .controlSize(.small)
                .pointingHandCursor()
        }
        .padding(.horizontal, Tokens.Settings.rowInset)
        .frame(minHeight: detail == nil ? Tokens.Settings.rowHeight : Tokens.Settings.detailedRowHeight)
    }
}
