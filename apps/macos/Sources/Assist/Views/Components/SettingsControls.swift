import SwiftUI

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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(theme.foreground)

                    if let subtitle {
                        Text(subtitle)
                            .font(AssistFont.caption())
                            .foregroundStyle(theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 7)

                content
            }
            .padding(.trailing, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(theme.background)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.assistTheme) private var theme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.muted)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(theme.border.opacity(0.8), lineWidth: 1)
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.foreground)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .accessibilityLabel(title)
                .toggleStyle(.switch)
                .tint(theme.accent)
                .controlSize(.small)
                .pointingHandCursor()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: detail == nil ? 46 : 60)
    }
}
