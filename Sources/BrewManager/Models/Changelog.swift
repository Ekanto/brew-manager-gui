import Foundation

struct ChangelogEntry: Identifiable, Sendable {
    let version: String
    let title: String
    let date: String
    let highlights: [String]

    var id: String { version }
}

enum Changelog {
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "2.0",
            title: "What’s New",
            date: "August 2026",
            highlights: [
                "Added this scrollable changelog window so app updates explain what changed the first time you open them.",
                "Styled the update notes with the same Homebrew-inspired cards, icon tiles and status chips used across the app.",
                "The changelog can be closed immediately, and Brew Manager remembers that you already saw it for the current version."
            ]
        ),
        ChangelogEntry(
            version: "1.2",
            title: "Discover Layout Fix",
            date: "August 2026",
            highlights: [
                "Fixed Discover so the search field and package-type picker stay visible at the top of the screen.",
                "Moved Discover into the same header and card layout pattern as the other stable sections.",
                "Kept empty/searching/no-match states from expanding upward and clipping the controls."
            ]
        ),
        ChangelogEntry(
            version: "1.1",
            title: "Performance and Responsiveness",
            date: "August 2026",
            highlights: [
                "Reduced Stage Manager and minimize/reopen lag by using cheaper solid surfaces while the app is inactive.",
                "Cached read-only Homebrew commands to avoid duplicate dashboard and background checks.",
                "Delayed and throttled automatic background update polling so the app is quieter after launch.",
                "Fixed the live command output console so it remains scrollable while upgrades are running."
            ]
        ),
        ChangelogEntry(
            version: "1.0",
            title: "Initial Release",
            date: "August 2026",
            highlights: [
                "Built a native SwiftUI Homebrew manager for packages, updates, services, taps, Brewfiles, maintenance and history.",
                "Added a standalone macOS app bundle, generated app icon and drag-to-install DMG workflow.",
                "Every operation shows the real brew command and real output instead of hiding Homebrew behind custom logic.",
                "Added safety prompts, dry-run maintenance previews, persistent history, notifications, menu bar status and a command palette.",
                "Added stale cask repair for apps deleted outside Homebrew, with one-click Reinstall or Forget actions."
            ]
        )
    ]
}
