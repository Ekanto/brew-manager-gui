import Foundation
import Observation

struct PendingIssueFix: Identifiable {
    let id = UUID()
    let fix: DoctorReport.SuggestedFix

    var title: String { "Apply Homebrew's suggested fix?" }
    var confirmTitle: String { fix.confirmTitle }
    var isDestructive: Bool { fix.isDestructive }

    var message: String {
        """
        Homebrew suggested:

        \(fix.displayCommand)

        Brew Manager will run exactly that command and show the output.
        """
    }
}

struct PendingCaskIssueRepair: Identifiable {
    let id = UUID()
    let cask: StaleCask
    let action: CaskRecoveryAction

    var title: String {
        action == .forget ? "Forget \(cask.name)?" : "Reinstall \(cask.name)?"
    }

    var message: String {
        action.explanation(for: [cask.name])
    }
}

@MainActor
@Observable
final class IssuesViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var staleCasks: [StaleCask] = []
    var permissionIssues: [CaskPermissionIssue] = []
    var doctorReport: DoctorReport?
    var feedback: MaintenanceFeedback?
    var isScanning = false
    var isRunningFix = false
    var pendingFix: PendingIssueFix?
    var pendingCaskRepair: PendingCaskIssueRepair?

    private var hasLoaded = false

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    var issueCount: Int {
        staleCasks.count + permissionIssues.count + (doctorReport?.warnings.count ?? 0)
    }

    var hasIssues: Bool {
        issueCount > 0
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await scan()
    }

    func scan() async {
        isScanning = true
        feedback = nil
        defer { isScanning = false }

        do {
            async let stale = homebrewService.staleCasks()
            async let permissions = homebrewService.rootOwnedCaskApps()
            async let doctor = homebrewService.doctor()

            let (resolvedStale, resolvedPermissions, doctorResult) = try await (
                stale,
                permissions,
                doctor
            )

            staleCasks = resolvedStale
            permissionIssues = resolvedPermissions
            doctorReport = Self.parseDoctorResult(doctorResult)
        } catch {
            feedback = MaintenanceFeedback(
                severity: .failure,
                headline: "Could not scan Homebrew issues.",
                details: [MessageBanner.DetailItem(title: error.localizedDescription)]
            )
        }
    }

    func requestFix(_ fix: DoctorReport.SuggestedFix) {
        guard !isRunningFix else { return }
        pendingFix = PendingIssueFix(fix: fix)
    }

    func requestCaskRepair(_ cask: StaleCask, action: CaskRecoveryAction) {
        guard !isRunningFix else { return }
        pendingCaskRepair = PendingCaskIssueRepair(cask: cask, action: action)
    }

    func confirmFix(_ pending: PendingIssueFix) async {
        pendingFix = nil
        await runFix(pending.fix)
    }

    func confirmCaskRepair(_ pending: PendingCaskIssueRepair) async {
        pendingCaskRepair = nil
        await runCaskRepair(pending)
    }

    func showOutput(for operation: OperationConsoleModel) {
        appState.presentOperation(operation)
    }

    private func runFix(_ fix: DoctorReport.SuggestedFix) async {
        await runStreamingOperation(
            title: "Applying suggested fix",
            arguments: fix.arguments
        ) { stream in
            try await self.homebrewService.runSuggestedFix(
                arguments: fix.arguments,
                stream: stream
            )
        }
    }

    private func runCaskRepair(_ pending: PendingCaskIssueRepair) async {
        let arguments = HomebrewService.recoveryArguments(
            action: pending.action,
            cask: pending.cask.name
        )

        await runStreamingOperation(
            title: "\(pending.action.title) \(pending.cask.name)",
            arguments: arguments
        ) { stream in
            switch pending.action {
            case .forget:
                return try await self.homebrewService.forgetCask(
                    pending.cask.name,
                    stream: stream
                )
            case .reinstall:
                return try await self.homebrewService.reinstallMissingCask(
                    pending.cask.name,
                    stream: stream
                )
            }
        }
    }

    private func runStreamingOperation(
        title: String,
        arguments: [String],
        execution: @escaping (@escaping @Sendable (ProcessEvent) -> Void) async throws -> ProcessResult
    ) async {
        guard !isRunningFix else { return }
        isRunningFix = true
        feedback = nil
        defer { isRunningFix = false }

        do {
            let command = try await homebrewService.commandString(arguments: arguments)
            let operation = appState.beginOperation(title: title, command: command)

            let result = try await execution { event in
                Task { @MainActor in
                    operation.append(event: event)
                }
            }

            appState.finishOperation(operation, result: result)

            if result.exitCode == 0 {
                feedback = MaintenanceFeedback(
                    severity: .success,
                    headline: "\(title) completed.",
                    footnote: "Scan again to confirm the issue is resolved.",
                    operation: operation
                )
                await scan()
            } else {
                let classified = BrewError.classify(
                    command: command,
                    exitCode: result.exitCode,
                    stderr: result.stderr
                )
                feedback = MaintenanceFeedback(
                    severity: .failure,
                    headline: "\(title) failed.",
                    details: [MessageBanner.DetailItem(title: classified.localizedDescription)],
                    operation: operation
                )
            }
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
        }
    }

    private static func parseDoctorResult(_ result: ProcessResult) -> DoctorReport {
        let combinedOutput = [result.stdout, result.stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        return DoctorReport.parse(combinedOutput)
    }
}
