import Foundation
import Observation
import SwiftUI

enum MaintenanceTask: String, CaseIterable, Identifiable {
    case cleanup
    case purgeCache
    case autoremove
    case doctor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleanup:
            return "Clean Up Old Versions"
        case .purgeCache:
            return "Purge Download Cache"
        case .autoremove:
            return "Remove Orphan Packages"
        case .doctor:
            return "Run Diagnostics"
        }
    }

    var summary: String {
        switch self {
        case .cleanup:
            return "Removes outdated versions of installed formulae and casks, plus stale lock files."
        case .purgeCache:
            return "Deletes every cached download, including archives for packages you still have installed."
        case .autoremove:
            return "Uninstalls formulae that were pulled in as dependencies and are no longer needed by anything."
        case .doctor:
            return "Checks your Homebrew installation for common problems. Read-only — nothing is changed."
        }
    }

    var systemImage: String {
        switch self {
        case .cleanup:
            return "sparkles"
        case .purgeCache:
            return "trash.fill"
        case .autoremove:
            return "leaf.fill"
        case .doctor:
            return "stethoscope"
        }
    }

    var tint: Color {
        switch self {
        case .cleanup:
            return Theme.Palette.info
        case .purgeCache:
            return Theme.Palette.danger
        case .autoremove:
            return Theme.Palette.formula
        case .doctor:
            return Theme.Palette.cask
        }
    }

    /// Diagnostics only reads state, so it needs neither a preview nor a confirmation.
    var supportsPreview: Bool {
        self != .doctor
    }

    var requiresConfirmation: Bool {
        self != .doctor
    }

    var isDestructive: Bool {
        self == .purgeCache || self == .autoremove
    }

    /// `brew doctor` exits 1 whenever it prints any advisory, so a non-zero
    /// exit there means "warnings", not "failed".
    var warningExitCodes: Set<Int32> {
        self == .doctor ? [1] : []
    }

    var runTitle: String {
        switch self {
        case .cleanup:
            return "Clean Up"
        case .purgeCache:
            return "Purge Cache"
        case .autoremove:
            return "Remove Orphans"
        case .doctor:
            return "Run Diagnostics"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .cleanup:
            return "Old downloads and superseded versions will be deleted. Installed packages stay at their current version."
        case .purgeCache:
            return "All cached downloads will be deleted. Reinstalling or upgrading a package will re-download it."
        case .autoremove:
            return "Homebrew will uninstall unused dependencies. Run Preview first to see exactly what would be removed."
        case .doctor:
            return ""
        }
    }
}

struct PendingMaintenanceTask: Identifiable {
    let id = UUID()
    let task: MaintenanceTask

    var title: String { "\(task.title)?" }
    var message: String { task.confirmationMessage }
    var confirmTitle: String { task.runTitle }
    var isDestructive: Bool { task.isDestructive }
}

struct MaintenanceFeedback {
    let severity: OperationSeverity
    let headline: String
    var details: [MessageBanner.DetailItem] = []
    var footnote: String?
    var operation: OperationConsoleModel?
    var suggestedFixes: [DoctorReport.SuggestedFix] = []
}

struct PendingSuggestedFix: Identifiable {
    let id = UUID()
    let fix: DoctorReport.SuggestedFix

    var title: String { "Apply Homebrew's suggested fix?" }

    var message: String {
        """
        Homebrew suggests running:

        \(fix.displayCommand)

        This runs exactly the command shown above. Nothing else will be changed.
        """
    }

    var confirmTitle: String { fix.confirmTitle }
    var isDestructive: Bool { fix.isDestructive }
}

@MainActor
@Observable
final class MaintenanceViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var cachePath: String?
    var cacheSizeDescription: String?
    var isLoadingCacheSize = false
    var runningTask: MaintenanceTask?
    var feedback: MaintenanceFeedback?
    var pendingTask: PendingMaintenanceTask?
    var pendingFix: PendingSuggestedFix?

    private var hasLoaded = false

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    var isBusy: Bool {
        runningTask != nil
    }

    func dismissFeedback() {
        feedback = nil
    }

    func showOutput(for operation: OperationConsoleModel) {
        appState.presentOperation(operation)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refreshCacheSize()
    }

    func refreshCacheSize() async {
        isLoadingCacheSize = true
        defer { isLoadingCacheSize = false }

        do {
            let cacheURL = try await homebrewService.cacheDirectory()
            cachePath = cacheURL.path

            let bytes = await Task.detached(priority: .utility) {
                DirectorySize.bytes(at: cacheURL)
            }.value

            cacheSizeDescription = DirectorySize.formatted(bytes: bytes)
        } catch {
            cachePath = nil
            cacheSizeDescription = nil
            feedback = MaintenanceFeedback(
                severity: .failure,
                headline: "Could not read the Homebrew cache location.",
                details: [MessageBanner.DetailItem(title: error.localizedDescription)]
            )
        }
    }

    func requestRun(_ task: MaintenanceTask) {
        guard !isBusy else { return }

        if task.requiresConfirmation {
            pendingTask = PendingMaintenanceTask(task: task)
        } else {
            Task { await run(task, dryRun: false) }
        }
    }

    /// The alert clears `pendingTask` on dismissal before the button's `Task`
    /// runs, so the confirmed task must be passed in rather than re-read.
    func confirm(_ pending: PendingMaintenanceTask) async {
        pendingTask = nil
        await run(pending.task, dryRun: false)
    }

    func preview(_ task: MaintenanceTask) async {
        guard task.supportsPreview else { return }
        await run(task, dryRun: true)
    }

    func run(_ task: MaintenanceTask, dryRun: Bool) async {
        guard !isBusy else { return }

        runningTask = task
        defer { runningTask = nil }

        feedback = nil

        let title = dryRun ? "\(task.title) (Preview)" : task.title
        let arguments = Self.arguments(for: task, dryRun: dryRun)

        let outcome = await runStreamingOperation(
            title: title,
            arguments: arguments,
            warningExitCodes: task.warningExitCodes
        ) { stream in
            switch task {
            case .cleanup:
                return try await self.homebrewService.cleanup(dryRun: dryRun, stream: stream)
            case .purgeCache:
                return try await self.homebrewService.purgeCache(
                    scrub: true,
                    dryRun: dryRun,
                    stream: stream
                )
            case .autoremove:
                return try await self.homebrewService.autoremove(dryRun: dryRun, stream: stream)
            case .doctor:
                return try await self.homebrewService.doctor(stream: stream)
            }
        }

        guard let outcome else { return }

        let newFeedback = makeFeedback(
            task: task,
            dryRun: dryRun,
            outcome: outcome
        )
        feedback = newFeedback

        // Homebrew printed an actionable remediation, so offer to run it
        // instead of leaving the user to retype it in a terminal.
        if let firstFix = newFeedback.suggestedFixes.first {
            pendingFix = PendingSuggestedFix(fix: firstFix)
        }

        // Cleanup and cache purges both change on-disk cache size.
        if !dryRun,
           outcome.severity != .failure,
           task == .cleanup || task == .purgeCache {
            await refreshCacheSize()
        }
    }

    func requestFix(_ fix: DoctorReport.SuggestedFix) {
        guard !isBusy else { return }
        pendingFix = PendingSuggestedFix(fix: fix)
    }

    /// The alert clears `pendingFix` on dismissal before the button's `Task`
    /// runs, so the confirmed fix must be passed in rather than re-read.
    func confirmFix(_ pending: PendingSuggestedFix) async {
        pendingFix = nil
        await runFix(pending.fix)
    }

    func runFix(_ fix: DoctorReport.SuggestedFix) async {
        guard !isBusy else { return }

        runningTask = .doctor
        defer { runningTask = nil }

        feedback = nil

        let outcome = await runStreamingOperation(
            title: "Applying suggested fix",
            arguments: fix.arguments,
            warningExitCodes: []
        ) { stream in
            try await self.homebrewService.runSuggestedFix(
                arguments: fix.arguments,
                stream: stream
            )
        }

        guard let outcome else { return }

        switch outcome.severity {
        case .failure:
            feedback = MaintenanceFeedback(
                severity: .failure,
                headline: "`\(fix.displayCommand)` failed.",
                details: [MessageBanner.DetailItem(title: outcome.failureDescription)],
                operation: outcome.operation
            )
        case .success, .warning:
            feedback = MaintenanceFeedback(
                severity: .success,
                headline: "`\(fix.displayCommand)` completed.",
                footnote: "Run diagnostics again to confirm the warning is resolved.",
                operation: outcome.operation
            )
        }
    }

    private func makeFeedback(
        task: MaintenanceTask,
        dryRun: Bool,
        outcome: MaintenanceOutcome
    ) -> MaintenanceFeedback {
        let result = outcome.result
        let combinedOutput = [result.stdout, result.stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        // `brew doctor` exits non-zero for advisories that are safe to ignore,
        // so its output is parsed into warnings instead of shown as a failure.
        if task == .doctor, outcome.severity != .failure {
            let report = DoctorReport.parse(combinedOutput)
            return MaintenanceFeedback(
                severity: report.isHealthy ? .success : .warning,
                headline: report.headline,
                details: report.warnings.map {
                    MessageBanner.DetailItem(title: $0.title, detail: $0.detail)
                },
                footnote: report.isHealthy
                    ? nil
                    : "These are diagnostic hints, not failures. If Homebrew works fine for you, they are safe to ignore.",
                operation: outcome.operation,
                suggestedFixes: report.suggestedFixes
            )
        }

        switch outcome.severity {
        case .failure:
            return MaintenanceFeedback(
                severity: .failure,
                headline: "\(task.title) failed.",
                details: [MessageBanner.DetailItem(title: outcome.failureDescription)],
                operation: outcome.operation
            )
        case .warning, .success:
            return MaintenanceFeedback(
                severity: .success,
                headline: dryRun
                    ? "\(task.title) preview finished. Nothing was changed."
                    : "\(task.title) completed.",
                footnote: Self.reclaimSummary(from: combinedOutput),
                operation: outcome.operation
            )
        }
    }

    /// Homebrew reports reclaimable space on its final line; surfacing it saves
    /// the user from opening the console just to read one number.
    static func reclaimSummary(from output: String) -> String? {
        output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { $0.contains("disk space") }?
            .replacingOccurrences(of: "==> ", with: "")
    }

    static func arguments(for task: MaintenanceTask, dryRun: Bool) -> [String] {
        switch task {
        case .cleanup:
            return dryRun ? ["cleanup", "--dry-run"] : ["cleanup"]
        case .purgeCache:
            return HomebrewService.cleanupArguments(scrub: true, dryRun: dryRun)
        case .autoremove:
            return HomebrewService.autoremoveArguments(dryRun: dryRun)
        case .doctor:
            return ["doctor"]
        }
    }

    private func runStreamingOperation(
        title: String,
        arguments: [String],
        warningExitCodes: Set<Int32>,
        execution: @escaping (@escaping @Sendable (ProcessEvent) -> Void) async throws -> ProcessResult
    ) async -> MaintenanceOutcome? {
        do {
            let command = try await homebrewService.commandString(arguments: arguments)
            let operation = appState.beginOperation(
                title: title,
                command: command,
                warningExitCodes: warningExitCodes
            )

            let result = try await execution { event in
                Task { @MainActor in
                    operation.append(event: event)
                }
            }

            appState.finishOperation(operation, result: result)

            let severity: OperationSeverity
            if result.exitCode == 0 {
                severity = .success
            } else if warningExitCodes.contains(result.exitCode) {
                severity = .warning
            } else {
                severity = .failure
            }

            let failureDescription = severity == .failure
                ? BrewError.classify(
                    command: command,
                    exitCode: result.exitCode,
                    stderr: result.stderr
                ).localizedDescription
                : ""

            return MaintenanceOutcome(
                result: result,
                severity: severity,
                failureDescription: failureDescription,
                operation: operation
            )
        } catch {
            feedback = MaintenanceFeedback(
                severity: .failure,
                headline: "\(title) could not be run.",
                details: [MessageBanner.DetailItem(title: error.localizedDescription)],
                operation: appState.activeOperation
            )
            if let activeOperation = appState.activeOperation {
                appState.failOperation(activeOperation, error: error)
            }
            return nil
        }
    }
}

struct MaintenanceOutcome {
    let result: ProcessResult
    let severity: OperationSeverity
    let failureDescription: String
    let operation: OperationConsoleModel?
}
