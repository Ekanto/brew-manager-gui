import SwiftUI

struct SettingsView: View {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        @Bindable var preferences = appState.preferences

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        "Notifications",
                        subtitle: "Choose when Brew Manager should tell you something happened.",
                        systemImage: "bell.badge",
                        color: Theme.Palette.info
                    )
                    Divider()
                    Toggle("Notify on failed operations", isOn: $preferences.notifyOnFailedOperations)
                    Toggle("Notify on successful upgrades", isOn: $preferences.notifyOnSuccessfulUpgrade)
                    Toggle("Notify when updates are available", isOn: $preferences.notifyWhenUpdatesAvailable)

                    Label(
                        "macOS will ask for permission the first time a notification is sent.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.info)

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        "Update Checks",
                        subtitle: "Brew Manager can look for outdated packages in the background.",
                        systemImage: "arrow.triangle.2.circlepath",
                        color: Theme.Palette.formula
                    )
                    Divider()

                    Toggle("Check for updates in the background", isOn: $preferences.backgroundCheckEnabled)
                        .onChange(of: preferences.backgroundCheckEnabled) { _, _ in
                            appState.configureScheduler()
                        }

                    Stepper(
                        "Check every \(preferences.backgroundCheckHours) hour\(preferences.backgroundCheckHours == 1 ? "" : "s")",
                        value: $preferences.backgroundCheckHours,
                        in: 1...168
                    )
                    .disabled(!preferences.backgroundCheckEnabled)
                    .onChange(of: preferences.backgroundCheckHours) { _, _ in
                        appState.configureScheduler()
                    }

                    Toggle("Include self-updating casks (--greedy)", isOn: $preferences.includeGreedyCasks)

                    Label(
                        "Some casks update themselves and are invisible to a plain update check. Including them gives an accurate count but makes checks slower.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    if let lastCheck = appState.lastUpdateCheck {
                        Text("Last checked \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.formula)

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        "Appearance",
                        subtitle: "Adjust how Brew Manager looks.",
                        systemImage: "paintpalette",
                        color: Theme.Palette.cask
                    )
                    Divider()
                    Toggle("Show menu bar item", isOn: $preferences.showMenuBarExtra)
                    Toggle("Reduce transparency", isOn: $preferences.reduceTransparency)

                    Label(
                        "Reduce transparency replaces the translucent panels with solid surfaces.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.cask)

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        "Safety",
                        subtitle: "Brew Manager never changes your system without an explicit confirmation.",
                        systemImage: "lock.shield",
                        color: Theme.Palette.warning
                    )
                    Divider()
                    Toggle("Automatic upgrades", isOn: $preferences.automaticUpgradesEnabled)
                        .disabled(true)
                    Label(
                        "Automatic upgrades are intentionally disabled in this release.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.warning)

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        "History",
                        subtitle: "Past operations are stored on this Mac so they survive quitting.",
                        systemImage: "clock.arrow.circlepath",
                        color: Color(red: 0.60, green: 0.62, blue: 0.70)
                    )
                    Divider()
                    HStack {
                        Text("\(appState.history.count) stored operation\(appState.history.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear History", role: .destructive) {
                            appState.clearHistory()
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.Palette.danger)
                        .disabled(appState.history.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader(
                        "About",
                        subtitle: "A native front end for the Homebrew you already have installed.",
                        systemImage: "info.circle",
                        color: Theme.Palette.amber
                    )
                    Divider()
                    LabeledContent("Version", value: AppInfo.displayVersion)
                    if let path = appState.brewExecutablePath {
                        LabeledContent("Homebrew", value: path)
                    }
                    LabeledContent("Author", value: AppInfo.author)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.amber)
            }
            .toggleStyle(.switch)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
    }

    private func sectionHeader(
        _ title: String,
        subtitle: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            IconTile(systemImage: systemImage, color: color, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
