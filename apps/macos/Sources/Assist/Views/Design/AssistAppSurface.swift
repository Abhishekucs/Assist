import Combine
import SwiftUI

/// Launch and the library resolve the same persisted appearance preference.
/// System appearance notifications also reach windows that aren't key.
struct AssistAppSurface<Content: View>: View {
    @AppStorage("app.appearance") private var appearance: AppAppearance = .system
    @State private var systemScheme = SystemAppearanceResolver.currentColorScheme()
    private let content: (AssistTheme) -> Content

    init(@ViewBuilder content: @escaping (AssistTheme) -> Content) {
        self.content = content
    }

    private var scheme: ColorScheme {
        switch appearance {
        case .light: .light
        case .dark: .dark
        case .system: systemScheme
        }
    }

    var body: some View {
        let theme = AssistTheme(colorScheme: scheme)
        content(theme)
            .environment(\.assistTheme, theme)
            .foregroundStyle(theme.foreground)
            .font(AssistFont.body())
            .tint(theme.accent)
            .preferredColorScheme(scheme)
            .onReceive(DistributedNotificationCenter.default().publisher(for: SystemAppearanceResolver.changeNotification)) { _ in
                systemScheme = SystemAppearanceResolver.currentColorScheme()
            }
            .onAppear {
                systemScheme = SystemAppearanceResolver.currentColorScheme()
            }
    }
}
