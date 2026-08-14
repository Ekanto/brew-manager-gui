import AppKit
import SwiftUI

@main
struct BrewManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: MainWindow.identifier) {
            RootView()
                .environment(appState)
                .task {
                    await appState.bootstrapIfNeeded()
                }
        }
        .defaultSize(width: 1240, height: 820)
        .commands {
            BrewManagerCommands(appState: appState)
        }

        MenuBarExtra(isInserted: menuBarVisibility) {
            MenuBarContent()
                .environment(appState)
        } label: {
            MenuBarLabel(outdatedCount: appState.outdatedCount)
        }
    }

    /// `MenuBarExtra` requires a binding; the preference stays the source of truth.
    private var menuBarVisibility: Binding<Bool> {
        Binding(
            get: { appState.preferences.showMenuBarExtra },
            set: { appState.preferences.showMenuBarExtra = $0 }
        )
    }
}

/// Keyboard-first navigation. Anything reachable by mouse should also have a
/// menu command, which is a baseline expectation for a Mac app.
struct BrewManagerCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Command Palette…") {
                appState.isCommandPalettePresented = true
            }
            .keyboardShortcut("k", modifiers: .command)
        }

        CommandMenu("Homebrew") {
            Button("Refresh Current Section") {
                NotificationCenter.default.post(name: .brewManagerRefresh, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Check for Updates") {
                Task { await appState.performBackgroundUpdateCheck() }
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])

            Divider()

            ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element.id) { index, section in
                Button(section.title) {
                    appState.selectedSection = section
                }
                .keyboardShortcut(shortcutKey(for: index), modifiers: .command)
            }
        }
    }

    /// ⌘1…⌘9 for the first nine sections; any beyond that stay menu-only.
    private func shortcutKey(for index: Int) -> KeyEquivalent {
        guard index < 9 else { return KeyEquivalent(" ") }
        return KeyEquivalent(Character("\(index + 1)"))
    }
}

extension Notification.Name {
    /// Broadcast so whichever section is visible can reload itself.
    static let brewManagerRefresh = Notification.Name("BrewManagerRefresh")
}
