import Foundation
import Observation

/// Typed access to user preferences.
///
/// Views previously read `@AppStorage` directly, which meant non-view code
/// (the scheduler, the menu bar item) had no way to observe the same values.
@MainActor
@Observable
final class Preferences {
    enum Key {
        static let notifyOnFailedOperations = "notifyOnFailedOperations"
        static let notifyOnSuccessfulUpgrade = "notifyOnSuccessfulUpgrade"
        static let notifyWhenUpdatesAvailable = "notifyWhenUpdatesAvailable"
        static let automaticUpgradesEnabled = "automaticUpgradesEnabled"
        static let includeGreedyCasks = "includeGreedyCasks"
        static let backgroundCheckEnabled = "backgroundCheckEnabled"
        static let backgroundCheckHours = "backgroundCheckHours"
        static let showMenuBarExtra = "showMenuBarExtra"
        static let keepRunningInMenuBar = "keepRunningInMenuBar"
        static let reduceTransparency = "reduceTransparency"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Key.notifyOnFailedOperations: true,
            Key.notifyOnSuccessfulUpgrade: false,
            Key.notifyWhenUpdatesAvailable: true,
            Key.automaticUpgradesEnabled: false,
            Key.includeGreedyCasks: true,
            Key.backgroundCheckEnabled: true,
            Key.backgroundCheckHours: 6,
            Key.showMenuBarExtra: true,
            Key.keepRunningInMenuBar: false,
            Key.reduceTransparency: false
        ])

        notifyOnFailedOperations = defaults.bool(forKey: Key.notifyOnFailedOperations)
        notifyOnSuccessfulUpgrade = defaults.bool(forKey: Key.notifyOnSuccessfulUpgrade)
        notifyWhenUpdatesAvailable = defaults.bool(forKey: Key.notifyWhenUpdatesAvailable)
        automaticUpgradesEnabled = defaults.bool(forKey: Key.automaticUpgradesEnabled)
        includeGreedyCasks = defaults.bool(forKey: Key.includeGreedyCasks)
        backgroundCheckEnabled = defaults.bool(forKey: Key.backgroundCheckEnabled)
        backgroundCheckHours = defaults.integer(forKey: Key.backgroundCheckHours)
        showMenuBarExtra = defaults.bool(forKey: Key.showMenuBarExtra)
        keepRunningInMenuBar = defaults.bool(forKey: Key.keepRunningInMenuBar)
        reduceTransparency = defaults.bool(forKey: Key.reduceTransparency)
    }

    var notifyOnFailedOperations: Bool {
        didSet { defaults.set(notifyOnFailedOperations, forKey: Key.notifyOnFailedOperations) }
    }

    var notifyOnSuccessfulUpgrade: Bool {
        didSet { defaults.set(notifyOnSuccessfulUpgrade, forKey: Key.notifyOnSuccessfulUpgrade) }
    }

    var notifyWhenUpdatesAvailable: Bool {
        didSet { defaults.set(notifyWhenUpdatesAvailable, forKey: Key.notifyWhenUpdatesAvailable) }
    }

    var automaticUpgradesEnabled: Bool {
        didSet { defaults.set(automaticUpgradesEnabled, forKey: Key.automaticUpgradesEnabled) }
    }

    /// Include self-updating casks when checking for updates.
    var includeGreedyCasks: Bool {
        didSet { defaults.set(includeGreedyCasks, forKey: Key.includeGreedyCasks) }
    }

    var backgroundCheckEnabled: Bool {
        didSet { defaults.set(backgroundCheckEnabled, forKey: Key.backgroundCheckEnabled) }
    }

    var backgroundCheckHours: Int {
        didSet {
            let clamped = min(max(backgroundCheckHours, 1), 168)
            if clamped != backgroundCheckHours {
                backgroundCheckHours = clamped
                return
            }
            defaults.set(clamped, forKey: Key.backgroundCheckHours)
        }
    }

    var showMenuBarExtra: Bool {
        didSet { defaults.set(showMenuBarExtra, forKey: Key.showMenuBarExtra) }
    }

    var keepRunningInMenuBar: Bool {
        didSet { defaults.set(keepRunningInMenuBar, forKey: Key.keepRunningInMenuBar) }
    }

    /// Opt out of the translucent material backgrounds.
    var reduceTransparency: Bool {
        didSet { defaults.set(reduceTransparency, forKey: Key.reduceTransparency) }
    }

    var backgroundCheckInterval: TimeInterval {
        TimeInterval(backgroundCheckHours) * 3600
    }
}
