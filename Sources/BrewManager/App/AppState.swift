import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var selectedSection: SidebarSection = .dashboard
    var brewExecutablePath: String?
    var startupErrorMessage: String?
    var activeOperation: OperationConsoleModel?
    var history: [OperationRecord] = []

    /// Outdated count kept current by the scheduler, for the menu bar item.
    var outdatedCount: Int = 0
    var lastUpdateCheck: Date?
    var isCommandPalettePresented = false

    let homebrewService: HomebrewService
    let preferences: Preferences

    private let historyStore = HistoryStore()
    private let notificationService = NotificationService()
    private var scheduler: UpdateScheduler?
    private var bootstrapped = false

    /// Outdated packages the user has already been told about, so repeated
    /// polls of an unchanged system stay silent.
    private var notifiedOutdatedIDs: Set<String> = []

    init(
        homebrewService: HomebrewService = HomebrewService(),
        preferences: Preferences = Preferences()
    ) {
        self.homebrewService = homebrewService
        self.preferences = preferences
    }

    func bootstrapIfNeeded() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        history = await historyStore.load()

        await refreshBrewDiscovery()
        configureScheduler()
    }

    // MARK: - Background update checks

    func configureScheduler() {
        scheduler?.stop()

        guard preferences.backgroundCheckEnabled else {
            scheduler = nil
            return
        }

        let scheduler = UpdateScheduler { [weak self] in
            await self?.performBackgroundUpdateCheck()
        }

        self.scheduler = scheduler
        scheduler.start(interval: preferences.backgroundCheckInterval)
    }

    /// Refreshes the outdated count without disturbing any visible screen.
    func performBackgroundUpdateCheck() async {
        guard brewExecutablePath != nil else { return }

        do {
            let outdated = try await homebrewService.outdatedPackages(
                greedy: preferences.includeGreedyCasks
            )

            outdatedCount = outdated.count
            lastUpdateCheck = Date()

            // Notify on the *identities* that are newly outdated rather than on
            // a change in count: upgrading one package while another becomes
            // outdated leaves the count identical but is still news.
            let current = Set(outdated.map(\.id))
            let unseen = current.subtracting(notifiedOutdatedIDs)
            notifiedOutdatedIDs = current

            if preferences.notifyWhenUpdatesAvailable, !unseen.isEmpty {
                await notificationService.post(.updatesAvailable(count: outdated.count))
            }
        } catch {
            AppLogger.app.error(
                "Background update check failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func refreshOutdatedCount() async {
        guard brewExecutablePath != nil else { return }

        if let outdated = try? await homebrewService.outdatedPackages(
            greedy: preferences.includeGreedyCasks
        ) {
            outdatedCount = outdated.count
            lastUpdateCheck = Date()
        }
    }

    func refreshBrewDiscovery() async {
        do {
            let brewPath = try await homebrewService.discoveredExecutable()
            brewExecutablePath = brewPath.path
            startupErrorMessage = nil
        } catch {
            brewExecutablePath = nil
            startupErrorMessage = error.localizedDescription
        }
    }

    func beginOperation(
        title: String,
        command: String,
        warningExitCodes: Set<Int32> = []
    ) -> OperationConsoleModel {
        let operation = OperationConsoleModel(
            title: title,
            command: command,
            warningExitCodes: warningExitCodes
        )
        activeOperation = operation
        return operation
    }

    func finishOperation(_ operation: OperationConsoleModel, result: ProcessResult) {
        operation.complete(with: result)

        let endedAt = Date()
        let duration = result.duration

        record(
            OperationRecord(
                title: operation.title,
                command: operation.command,
                output: operation.output,
                exitCode: result.exitCode,
                startedAt: operation.startedAt,
                endedAt: endedAt,
                duration: duration
            ),
            severity: operation.severity
        )
    }

    func failOperation(_ operation: OperationConsoleModel, error: Error) {
        operation.fail(with: error)

        record(
            OperationRecord(
                title: operation.title,
                command: operation.command,
                output: operation.output,
                exitCode: operation.exitCode ?? 1,
                startedAt: operation.startedAt,
                endedAt: Date(),
                duration: operation.duration ?? .zero
            ),
            severity: .failure
        )
    }

    /// Stores a finished operation, persists the log and raises any
    /// notification the user asked for.
    private func record(_ entry: OperationRecord, severity: OperationSeverity) {
        history.insert(entry, at: 0)

        if history.count > HistoryStore.maximumEntries {
            history.removeLast(history.count - HistoryStore.maximumEntries)
        }

        let snapshot = history
        Task { await historyStore.save(snapshot) }

        notify(for: entry, severity: severity)

        // Any mutation may have changed what is outdated.
        Task { await refreshOutdatedCount() }
    }

    private func notify(for entry: OperationRecord, severity: OperationSeverity) {
        switch severity {
        case .failure:
            guard preferences.notifyOnFailedOperations else { return }
            Task { [notificationService] in
                await notificationService.post(
                    .operationFailed(title: entry.title, detail: "Exit code \(entry.exitCode)")
                )
            }
        case .success:
            guard preferences.notifyOnSuccessfulUpgrade,
                  entry.title.localizedCaseInsensitiveContains("upgrad") else { return }
            Task { [notificationService] in
                await notificationService.post(.upgradeSucceeded(title: entry.title))
            }
        case .warning:
            break
        }
    }

    func clearHistory() {
        history.removeAll()
        Task { await historyStore.clear() }
    }

    func presentOperation(_ operation: OperationConsoleModel) {
        activeOperation = operation
    }

    func dismissOperation() {
        activeOperation = nil
    }
}
