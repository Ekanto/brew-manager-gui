import Foundation
import Observation

/// A confirmation for repairing stale cask records, held separately from the
/// upgrade confirmation so the two alerts cannot interfere.
struct PendingCaskRecovery: Identifiable {
    let id = UUID()
    let casks: [StaleCask]
    let action: CaskRecoveryAction

    var names: [String] { casks.map(\.name) }

    var title: String {
        let subject = casks.count == 1 ? casks[0].name : "\(casks.count) casks"
        return action == .forget ? "Forget \(subject)?" : "Reinstall \(subject)?"
    }

    var message: String { action.explanation(for: names) }
}

struct PendingUpgradeRequest: Identifiable {
    let id = UUID()
    let packages: [OutdatedPackage]

    var title: String {
        if packages.isEmpty {
            return "Upgrade all packages?"
        }
        return "Upgrade \(packages.count) package\(packages.count == 1 ? "" : "s")?"
    }

    var message: String {
        if packages.isEmpty {
            return "Homebrew may also upgrade required dependencies."
        }

        let preview = packages
            .prefix(8)
            .map { "\($0.name) \($0.installedVersion) → \($0.latestVersion)" }
            .joined(separator: "\n")

        if packages.count > 8 {
            return preview + "\n…"
        }
        return preview
    }
}

@MainActor
@Observable
final class UpdatesViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var outdatedPackages: [OutdatedPackage] = []
    var selectedPackageIDs: Set<String> = []
    var pendingUpgrade: PendingUpgradeRequest?

    var isLoading = false
    var errorMessage: String?
    var statusMessage: String?
    var lastMetadataUpdate: Date?

    /// Casks Homebrew still tracks whose application is missing from disk.
    /// These block `brew upgrade`, so they are surfaced with a one-click fix.
    var staleCasks: [StaleCask] = []
    var pendingRecovery: PendingCaskRecovery?
    var isRecovering = false

    private var hasLoaded = false

    /// Casks Homebrew explicitly blamed in a failure, kept across refreshes
    /// until they are repaired.
    private var reportedStale: [String: StaleCask] = [:]

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    var outdatedFormulae: [OutdatedPackage] {
        outdatedPackages.filter { $0.type == .formula }
    }

    var outdatedCasks: [OutdatedPackage] {
        outdatedPackages.filter { $0.type == .cask }
    }

    var selectedPackages: [OutdatedPackage] {
        outdatedPackages.filter { selectedPackageIDs.contains($0.id) }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refreshOutdated()
    }

    func refreshOutdated() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let outdated = try await homebrewService.outdatedPackages(
                greedy: appState.preferences.includeGreedyCasks
            )
            outdatedPackages = outdated

            let validIDs = Set(outdated.map(\.id))
            selectedPackageIDs = selectedPackageIDs.intersection(validIDs)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        await detectStaleCasks()
    }

    // MARK: - Stale cask recovery

    /// Checked proactively on every refresh so the problem is visible before an
    /// upgrade fails, not only afterwards.
    ///
    /// Two sources are combined. The disk scan catches the problem in advance,
    /// while Homebrew's own failure output is authoritative about what actually
    /// blocked an upgrade — so a cask it named is kept even if the scan cannot
    /// see anything wrong with it.
    func detectStaleCasks() async {
        let installed = (try? await homebrewService.listInstalledPackages(type: .cask)) ?? []
        let installedNames = Set(installed.map(\.name))

        // A repaired cask is no longer installed, which is what clears it.
        reportedStale = reportedStale.filter { installedNames.contains($0.key) }

        var byName: [String: StaleCask] = reportedStale

        for cask in (try? await homebrewService.staleCasks()) ?? [] {
            byName[cask.name] = byName[cask.name] ?? cask
        }

        // Only surface casks that are actually in the way of an upgrade.
        let outdatedNames = Set(outdatedPackages.map(\.name))
        staleCasks = byName.values
            .filter { outdatedNames.contains($0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Homebrew names the offending casks in its failure output, which is more
    /// precise than the disk scan because it reflects what actually blocked
    /// this run. Both sources are merged so neither can miss a cask.
    private func noteStaleCasks(in output: String) async {
        guard CaskRecovery.indicatesStaleArtifacts(output) else { return }

        let installedCasks = (try? await homebrewService.listInstalledPackages(type: .cask)) ?? []
        let reported = CaskRecovery.staleCasks(
            in: output,
            candidates: installedCasks.map(\.name)
        )

        for cask in reported {
            reportedStale[cask.name] = cask
        }

        for cask in reported where !staleCasks.contains(where: { $0.name == cask.name }) {
            staleCasks.append(cask)
        }
    }

    func requestRecovery(_ action: CaskRecoveryAction, casks: [StaleCask]? = nil) {
        let targets = casks ?? staleCasks
        guard !targets.isEmpty else { return }
        pendingRecovery = PendingCaskRecovery(casks: targets, action: action)
    }

    func performRecovery(_ pending: PendingCaskRecovery) async {
        pendingRecovery = nil
        isRecovering = true
        defer { isRecovering = false }

        var repaired: [String] = []
        var failed: [String] = []

        for cask in pending.casks {
            let arguments = HomebrewService.recoveryArguments(
                action: pending.action,
                cask: cask.name
            )

            let result = await runStreamingOperation(
                title: "\(pending.action.title) \(cask.name)",
                arguments: arguments
            ) { stream in
                switch pending.action {
                case .forget:
                    return try await self.homebrewService.forgetCask(cask.name, stream: stream)
                case .reinstall:
                    return try await self.homebrewService.reinstallMissingCask(cask.name, stream: stream)
                }
            }

            if result?.exitCode == 0 {
                repaired.append(cask.name)
            } else {
                failed.append(cask.name)
            }
        }

        if failed.isEmpty {
            let verb = pending.action == .forget ? "no longer tracked by Homebrew" : "reinstalled"
            statusMessage = "\(repaired.joined(separator: ", ")) \(repaired.count == 1 ? "is" : "are") \(verb)."
            errorMessage = nil
        } else {
            errorMessage = "Could not repair: \(failed.joined(separator: ", ")). Open the output above for Homebrew's reason."
        }

        await refreshOutdated()
    }

    func updateMetadataAndRefresh() async {
        let result = await runStreamingOperation(
            title: "Updating Homebrew metadata",
            arguments: ["update"]
        ) { stream in
            try await self.homebrewService.updateMetadata(stream: stream)
        }

        if result?.exitCode == 0 {
            lastMetadataUpdate = Date()
        }

        await refreshOutdated()
    }

    func selectAll() {
        selectedPackageIDs = Set(outdatedPackages.map(\.id))
    }

    func clearSelection() {
        selectedPackageIDs.removeAll()
    }

    func toggleSelection(for package: OutdatedPackage, selected: Bool) {
        if selected {
            selectedPackageIDs.insert(package.id)
        } else {
            selectedPackageIDs.remove(package.id)
        }
    }

    func requestUpgradeSelected() {
        let selected = selectedPackages
        guard !selected.isEmpty else { return }
        pendingUpgrade = PendingUpgradeRequest(packages: selected)
    }

    func requestUpgradeAll() {
        pendingUpgrade = PendingUpgradeRequest(packages: [])
    }

    func executePendingUpgrade() async {
        guard let pendingUpgrade else { return }
        await execute(pendingUpgrade)
    }

    /// The alert's `isPresented` binding clears `pendingUpgrade` as soon as the
    /// alert dismisses, which happens before the button's `Task` gets to run.
    /// The request must therefore be passed in explicitly rather than re-read.
    func execute(_ pendingUpgrade: PendingUpgradeRequest) async {
        self.pendingUpgrade = nil

        if pendingUpgrade.packages.isEmpty {
            let greedy = appState.preferences.includeGreedyCasks
            _ = await runStreamingOperation(
                title: "Upgrading all packages",
                arguments: greedy ? ["upgrade", "--greedy"] : ["upgrade"]
            ) { stream in
                try await self.homebrewService.upgradeAll(greedy: greedy, stream: stream)
            }
        } else {
            let packageNames = pendingUpgrade.packages.map(\.name)
            _ = await runStreamingOperation(
                title: "Upgrading selected packages",
                arguments: ["upgrade"] + packageNames
            ) { stream in
                try await self.homebrewService.upgrade(
                    packages: packageNames,
                    stream: stream
                )
            }
        }

        await refreshOutdated()
    }

    private func runStreamingOperation(
        title: String,
        arguments: [String],
        execution: @escaping (@escaping @Sendable (ProcessEvent) -> Void) async throws -> ProcessResult
    ) async -> ProcessResult? {
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
                statusMessage = "\(title) completed."
                errorMessage = nil
            } else {
                let classified = BrewError.classify(
                    command: command,
                    exitCode: result.exitCode,
                    stderr: result.stderr
                )
                errorMessage = classified.localizedDescription
                statusMessage = nil

                await noteStaleCasks(in: result.stdout + "\n" + result.stderr)
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            if let activeOperation = appState.activeOperation {
                appState.failOperation(activeOperation, error: error)
            }
            return nil
        }
    }
}
