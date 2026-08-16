import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    var body: some View {
        @Bindable var appState = appState

        return NavigationSplitView {
            List(
                SidebarSection.allCases,
                selection: selectedSectionBinding
            ) { section in
                HStack(spacing: 10) {
                    IconTile(
                        systemImage: section.systemImage,
                        color: section.tint,
                        size: 26
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(section.title)
                            .font(.body.weight(.medium))
                        Text(section.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
                .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 232, ideal: 248)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    IconTile(systemImage: "mug.fill", color: Theme.Palette.amber, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Brew Manager")
                            .font(.headline)
                        Text(appState.brewExecutablePath == nil ? "Homebrew not found" : "Homebrew ready")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .chromeBackground()
            }
            .safeAreaInset(edge: .bottom) {
                AppFooter()
            }
        } detail: {
            VStack(spacing: 0) {
                if let startupError = appState.startupErrorMessage {
                    HStack(spacing: 10) {
                        IconTile(
                            systemImage: "exclamationmark.triangle.fill",
                            color: Theme.Palette.warning,
                            size: 24
                        )
                        Text(startupError)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Spacer()
                        Button("Retry") {
                            Task {
                                await appState.refreshBrewDiscovery()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(Theme.Palette.warning.opacity(0.12))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Theme.Palette.warning.opacity(0.3))
                            .frame(height: 1)
                    }
                }

                detailView(for: appState.selectedSection)
            }
            .background(Theme.canvas)
            .navigationTitle(appState.selectedSection.title)
        }
        .tint(Theme.Palette.amberDeep)
        .environment(\.reduceTransparencyEnabled, prefersOpaqueSurfaces)
        .sheet(item: $appState.activeOperation) { operation in
            OperationConsoleView(operation: operation) {
                appState.dismissOperation()
            }
        }
        .sheet(isPresented: $appState.isCommandPalettePresented) {
            CommandPaletteView()
                .environment(appState)
                .environment(\.reduceTransparencyEnabled, prefersOpaqueSurfaces)
        }
        .sheet(isPresented: $appState.isChangelogPresented) {
            ChangelogView {
                appState.dismissChangelog()
            }
            .environment(\.reduceTransparencyEnabled, prefersOpaqueSurfaces)
        }
    }

    /// Honour the app preference *or* the system accessibility setting; either
    /// one asking for solid surfaces is enough. The app also switches to solid,
    /// cheaper surfaces while inactive so Stage Manager/minimize snapshots do
    /// not have to animate a large stack of live materials.
    private var prefersOpaqueSurfaces: Bool {
        appState.preferences.reduceTransparency || systemReduceTransparency || !appState.isAppActive
    }

    private var selectedSectionBinding: Binding<SidebarSection?> {
        Binding<SidebarSection?>(
            get: { appState.selectedSection },
            set: { newValue in
                appState.selectedSection = newValue ?? .dashboard
            }
        )
    }

    @ViewBuilder
    private func detailView(for section: SidebarSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView(appState: appState)
        case .packages:
            PackagesView(appState: appState)
        case .discover:
            DiscoverView(appState: appState)
        case .updates:
            UpdatesView(appState: appState)
        case .services:
            ServicesView(appState: appState)
        case .taps:
            TapsView(appState: appState)
        case .brewfile:
            BrewfileView(appState: appState)
        case .issues:
            IssuesView(appState: appState)
        case .maintenance:
            MaintenanceView(appState: appState)
        case .history:
            HistoryView(appState: appState)
        case .settings:
            SettingsView(appState: appState)
        }
    }
}
