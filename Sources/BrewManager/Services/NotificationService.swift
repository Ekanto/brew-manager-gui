import Foundation
import UserNotifications

/// Delivers user notifications for long-running or background events.
///
/// The Settings toggles previously persisted preferences that nothing read;
/// this is the piece that makes them real. Authorisation is requested lazily,
/// the first time a notification is actually wanted, so launching the app does
/// not immediately prompt.
actor NotificationService {
    enum Kind: Sendable {
        case operationFailed(title: String, detail: String)
        case upgradeSucceeded(title: String)
        case updatesAvailable(count: Int)

        var identifierPrefix: String {
            switch self {
            case .operationFailed: return "operation-failed"
            case .upgradeSucceeded: return "upgrade-succeeded"
            case .updatesAvailable: return "updates-available"
            }
        }

        var title: String {
            switch self {
            case .operationFailed:
                return "Homebrew operation failed"
            case .upgradeSucceeded:
                return "Upgrade complete"
            case .updatesAvailable(let count):
                return count == 1 ? "1 update available" : "\(count) updates available"
            }
        }

        var body: String {
            switch self {
            case .operationFailed(let title, let detail):
                return detail.isEmpty ? title : "\(title): \(detail)"
            case .upgradeSucceeded(let title):
                return title
            case .updatesAvailable(let count):
                return count == 1
                    ? "One installed package has a newer version."
                    : "\(count) installed packages have newer versions."
            }
        }
    }

    private var authorisationState: Bool?

    /// Notifications require a bundled, signed app; when running the bare
    /// executable the framework throws, which must not crash the app.
    private var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func ensureAuthorised() async -> Bool {
        if let authorisationState {
            return authorisationState
        }

        guard isAvailable else {
            authorisationState = false
            return false
        }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            authorisationState = granted
            return granted
        } catch {
            AppLogger.app.error(
                "Notification authorisation failed: \(error.localizedDescription, privacy: .public)"
            )
            authorisationState = false
            return false
        }
    }

    func post(_ kind: Kind) async {
        guard await ensureAuthorised() else { return }

        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(kind.identifierPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.app.error(
                "Could not post notification: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
