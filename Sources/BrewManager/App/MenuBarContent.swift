import SwiftUI

/// Menu bar item showing outdated package count at a glance.
///
/// A Homebrew tool is checked far more often than it is acted on, so the
/// common question — "am I up to date?" — should not require opening a window.
struct MenuBarContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if let error = appState.startupErrorMessage {
                Text(error)
                Divider()
            } else {
                Text(statusText)
                if let checked = appState.lastUpdateCheck {
                    Text("Checked \(checked.formatted(date: .omitted, time: .shortened))")
                }
                Divider()
            }

            Button("Open Brew Manager") {
                activate(section: .dashboard)
            }
            .keyboardShortcut("o")

            Button("Show Updates") {
                activate(section: .updates)
            }

            Button("Check for Updates Now") {
                Task { await appState.performBackgroundUpdateCheck() }
            }

            Divider()

            Button("Quit Brew Manager") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var statusText: String {
        switch appState.outdatedCount {
        case 0:
            return "Everything is up to date"
        case 1:
            return "1 update available"
        default:
            return "\(appState.outdatedCount) updates available"
        }
    }

    private func activate(section: SidebarSection) {
        appState.selectedSection = section
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Re-open the main window if the user closed it.
        if NSApplication.shared.windows.contains(where: { $0.canBecomeMain }) {
            NSApplication.shared.windows
                .first { $0.canBecomeMain }?
                .makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: MainWindow.identifier)
        }
    }
}

enum MainWindow {
    static let identifier = "brew-manager-main"
}

/// Label for the menu bar item: the mug, badged with a count when work is due.
struct MenuBarLabel: View {
    let outdatedCount: Int

    var body: some View {
        if outdatedCount > 0 {
            Label("\(outdatedCount)", systemImage: "mug.fill")
        } else {
            Image(systemName: "mug.fill")
        }
    }
}
