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
            version: "4.0",
            title: "GitHub Release Publishing",
            date: "August 2026",
            highlights: [
                "Added a tag-triggered GitHub Actions workflow that builds, tests and packages Brew Manager when a version tag is pushed.",
                "The workflow verifies the tag matches the app bundle version before publishing, so a mistagged release fails safely.",
                "Release artifacts are uploaded directly to GitHub Releases as downloadable DMG files."
            ]
        ),
        ChangelogEntry(
            version: "3.0",
            title: "History Log Viewer",
            date: "August 2026",
            highlights: [
                "Added a View Error Log action to failed history entries so you can inspect the exact terminal output that explains what went wrong.",
                "Successful history entries can also open their stored output, making History a complete command log instead of only a summary.",
                "The log opens in the same scrollable terminal-style console used by live operations, with copy support and the original command shown at the top."
            ]
        ),
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
