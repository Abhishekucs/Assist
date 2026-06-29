import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var settings: PillSettings
    @ObservedObject var viewModel: PillViewModel
    @State private var selectedPage: SettingsPage = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPage) {
                ForEach(SettingsPage.allCases) { page in
                    NavigationLink(value: page) {
                        Label(page.title, systemImage: page.systemImage)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selectedPage {
                case .general:
                    GeneralSettingsPane(settings: settings)
                case .appearance:
                    AppearanceSettingsPane(settings: settings)
                case .capture:
                    CaptureSettingsPane(viewModel: viewModel)
                case .advanced:
                    AdvancedSettingsPane(settings: settings, viewModel: viewModel)
                case .about:
                    AboutSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .formStyle(.grouped)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 720, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case appearance
    case capture
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            "General"
        case .appearance:
            "Appearance"
        case .capture:
            "Capture"
        case .advanced:
            "Advanced"
        case .about:
            "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gear"
        case .appearance:
            "eye"
        case .capture:
            "camera.viewfinder"
        case .advanced:
            "gearshape.2"
        case .about:
            "info.circle"
        }
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var settings: PillSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                Toggle("Follow pointer display", isOn: $settings.followPointerDisplay)
            } header: {
                Text("App")
            }

            Section {
                Toggle("Open notch on hover", isOn: $settings.openOnHover)
                Toggle("Show loading border", isOn: $settings.showLoadingBorder)
            } header: {
                Text("Island")
            } footer: {
                Text("The island stays pinned to the top center of the active display.")
            }
        }
        .navigationTitle("General")
    }
}

private struct AppearanceSettingsPane: View {
    @ObservedObject var settings: PillSettings
    @State private var previewExpanded = true

    var body: some View {
        Form {
            Section {
                IslandControlPreview(settings: settings, isExpanded: previewExpanded)
                    .frame(height: 154)

                Picker("Preview", selection: $previewExpanded) {
                    Text("Pill").tag(false)
                    Text("Expanded").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Preview")
            }

            Section {
                MetricSlider(
                    title: "Pill width",
                    value: binding(for: \.collapsedWidth),
                    range: PillSettings.Defaults.collapsedWidthRange
                )
                MetricSlider(
                    title: "Pill height",
                    value: binding(for: \.collapsedHeight),
                    range: PillSettings.Defaults.collapsedHeightRange
                )
                MetricSlider(
                    title: "Expanded width",
                    value: binding(for: \.expandedWidth),
                    range: PillSettings.Defaults.expandedWidthRange
                )
                MetricSlider(
                    title: "Expanded height",
                    value: binding(for: \.expandedHeight),
                    range: PillSettings.Defaults.expandedHeightRange
                )
            } header: {
                Text("Sizing")
            }

            Section {
                Button("Reset appearance") {
                    settings.resetIslandShape()
                }
            }
        }
        .navigationTitle("Appearance")
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<PillSettings, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(settings[keyPath: keyPath]) },
            set: { settings[keyPath: keyPath] = CGFloat($0.rounded()) }
        )
    }
}

private struct CaptureSettingsPane: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        Form {
            Section {
                SettingValueRow(title: "Annotate screenshot", value: "Hold Control")
                SettingValueRow(title: "Clean screenshot", value: "Control + Option")
                SettingValueRow(title: "Copied text", value: "Automatic")
            } header: {
                Text("Capture")
            }

            Section {
                Button("Test screenshot") {
                    viewModel.testScreenshot()
                }

                Button("Test annotation overlay") {
                    viewModel.testOverlay()
                }
            } header: {
                Text("Diagnostics")
            }

            if let diagnosticMessage = viewModel.diagnosticMessage {
                Section {
                    Text(diagnosticMessage)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Status")
                }
            }
        }
        .navigationTitle("Capture")
    }
}

private struct AdvancedSettingsPane: View {
    @ObservedObject var settings: PillSettings
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        Form {
            Section {
                Button("Open debug log") {
                    viewModel.openDebugLog()
                }

                Button("Reset island size") {
                    settings.resetIslandShape()
                }
            } header: {
                Text("Debug")
            }

            Section {
                SettingValueRow(
                    title: "Captures",
                    value: "~/Library/Application Support/\(AppIdentity.supportDirectoryName)/Captures"
                )
                SettingValueRow(
                    title: "Database",
                    value: "~/Library/Application Support/\(AppIdentity.supportDirectoryName)/captures.sqlite"
                )
            } header: {
                Text("Storage")
            }
        }
        .navigationTitle("Advanced")
    }
}

private struct AboutSettingsPane: View {
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Bundle")
                        Spacer()
                        Text(Bundle.main.bundleIdentifier ?? AppIdentity.bundleIdentifier)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Version info")
                }

                Section {
                    Button {
                        openProjectRepository()
                    } label: {
                        Label("GitHub", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("Project")
                }
            }

            VStack(spacing: 3) {
                Divider()
                Text(AppIdentity.name)
                    .font(.system(size: 13, weight: .medium))
                Text("Native screenshots, annotation, and AI context.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .navigationTitle("About")
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func openProjectRepository() {
        guard let url = URL(string: "https://github.com/Thinking-Sound-Lab/Assist") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 18)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct IslandControlPreview: View {
    @ObservedObject var settings: PillSettings
    let isExpanded: Bool

    private var previewSize: CGSize {
        isExpanded ? settings.expandedSize : settings.collapsedSize
    }

    private var scale: CGFloat {
        min(420 / previewSize.width, 116 / previewSize.height)
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 22)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.09))
                        .frame(height: 1)
                }

            BoringNotchShape(
                topCornerRadius: PillChromeMetrics.topCornerRadius(forExpandedState: isExpanded) * scale,
                bottomCornerRadius: PillChromeMetrics.bottomCornerRadius(forExpandedState: isExpanded) * scale
            )
            .fill(.black)
            .frame(width: previewSize.width * scale, height: previewSize.height * scale)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.black)
                    .frame(height: 1)
                    .padding(.horizontal, PillChromeMetrics.topCornerRadius(forExpandedState: isExpanded) * scale)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MetricSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<CGFloat>

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value)) px")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }

            Slider(value: $value, in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        }
    }
}
