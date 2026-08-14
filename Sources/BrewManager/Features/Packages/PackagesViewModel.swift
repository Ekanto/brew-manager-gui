import Foundation
import Observation

enum PackageListFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case formulae = "Formulae"
    case casks = "Casks"

    var id: String { rawValue }
}

enum PackageActionType: String {
    case upgrade
    case reinstall
    case uninstall
    case pin
    case unpin
}

struct PendingPackageAction: Identifiable {
    let id = UUID()
    let action: PackageActionType
    let package: BrewPackage

    var title: String {
        switch action {
        case .upgrade:
            return "Upgrade \(package.name)?"
        case .reinstall:
            return "Reinstall \(package.name)?"
        case .uninstall:
            return "Uninstall \(package.name)?"
        case .pin:
            return "Pin \(package.name)?"
        case .unpin:
            return "Unpin \(package.name)?"
        }
    }

    var message: String {
        switch action {
        case .upgrade:
            return "Homebrew may also upgrade required dependencies."
        case .reinstall:
            return "This will reinstall the package using Homebrew."
        case .uninstall:
            return "This action removes the package from this machine."
        case .pin:
            return "Pinned packages will be skipped in general upgrades."
        case .unpin:
            return "The package will be eligible for normal upgrades again."
        }
    }

    var confirmTitle: String {
        switch action {
        case .upgrade:
            return "Run Upgrade"
        case .reinstall:
            return "Run Reinstall"
        case .uninstall:
            return "Run Uninstall"
        case .pin:
            return "Pin Package"
        case .unpin:
            return "Unpin Package"
        }
    }

    var isDestructive: Bool {
        action == .uninstall
    }
}

@MainActor
@Observable
final class PackagesViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var allPackages: [BrewPackage] = []
    var selectedFilter: PackageListFilter = .all
    var searchText: String = ""
    var installPackageName: String = ""
    var installPackageType: PackageType = .formula
    var selectedPackageID: String?
    var selectedPackageDetail: BrewPackage?
    var pendingAction: PendingPackageAction?

    /// Installed packages that depend on the one being uninstalled.
    var dependencyWarning: DependencyReport?
    var diskUsage: [String: Int64] = [:]
    var isLoadingDiskUsage = false
    var sortBySize = false

    private var dependencyLookupTask: Task<Void, Never>?

    var isLoading = false
    var isLoadingDetails = false
    var errorMessage: String?
    var statusMessage: String?

    private var hasLoaded = false

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    var filteredPackages: [BrewPackage] {
        let byFilter = allPackages.filter { package in
            switch selectedFilter {
            case .all:
                return true
            case .formulae:
                return package.type == .formula
            case .casks:
                return package.type == .cask
            }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = trimmedSearch.isEmpty
            ? byFilter
            : byFilter.filter { package in
                package.name.localizedCaseInsensitiveContains(trimmedSearch)
                    || (package.packageDescription?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            }

        guard sortBySize else { return matched }

        return matched.sorted { lhs, rhs in
            let left = diskUsage[lhs.name] ?? 0
            let right = diskUsage[rhs.name] ?? 0
            if left == right {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return left > right
        }
    }

    func formattedSize(for package: BrewPackage) -> String? {
        guard let bytes = diskUsage[package.name], bytes > 0 else { return nil }
        return DirectorySize.formatted(bytes: bytes)
    }

    var totalDiskUsage: Int64 {
        diskUsage.values.reduce(0, +)
    }

    /// Sizing every package walks a large directory tree, so it is opt-in
    /// rather than part of the normal refresh.
    func loadDiskUsage() async {
        guard !isLoadingDiskUsage else { return }
        isLoadingDiskUsage = true
        defer { isLoadingDiskUsage = false }

        do {
            let usage = try await homebrewService.diskUsage(for: allPackages)
            diskUsage = Dictionary(
                usage.map { ($0.name, $0.bytes) },
                uniquingKeysWith: { first, _ in first }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var selectedPackage: BrewPackage? {
        if let selectedPackageDetail, selectedPackageDetail.id == selectedPackageID {
            return selectedPackageDetail
        }
        guard let selectedPackageID else { return nil }
        return allPackages.first(where: { $0.id == selectedPackageID })
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let previousSelection = selectedPackageID

        do {
            async let formulae = homebrewService.listInstalledPackages(type: .formula)
            async let casks = homebrewService.listInstalledPackages(type: .cask)
            let combined = try await formulae + casks

            allPackages = combined.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            errorMessage = nil

            if let previousSelection, allPackages.contains(where: { $0.id == previousSelection }) {
                selectedPackageID = previousSelection
            } else {
                selectedPackageID = allPackages.first?.id
            }

            await loadDetailsForSelectedPackage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDetailsForSelectedPackage() async {
        guard let selected = selectedPackage else {
            selectedPackageDetail = nil
            return
        }

        isLoadingDetails = true
        defer { isLoadingDetails = false }

        do {
            let detailed = try await homebrewService.packageDetails(named: selected.name)
            selectedPackageDetail = detailed

            if let index = allPackages.firstIndex(where: { $0.id == selected.id }) {
                allPackages[index] = detailed
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAction(_ action: PackageActionType) {
        guard let selectedPackage else { return }
        pendingAction = PendingPackageAction(action: action, package: selectedPackage)

        // Uninstalling something other packages rely on will break them, so the
        // dependents are looked up while the confirmation is on screen.
        if action == .uninstall {
            loadDependents(for: selectedPackage)
        }
    }

    private func loadDependents(for package: BrewPackage) {
        dependencyWarning = nil
        dependencyLookupTask?.cancel()

        guard package.type == .formula else { return }

        dependencyLookupTask = Task { [homebrewService] in
            let report = try? await homebrewService.dependents(of: package.name)

            guard !Task.isCancelled,
                  let report,
                  report.hasDependents else {
                return
            }

            // Only apply if the confirmation is still for the same package.
            guard self.pendingAction?.package.name == package.name else { return }
            self.dependencyWarning = report
        }
    }

    func executePendingAction() async {
        guard let pendingAction else { return }
        await execute(pendingAction)
    }

    /// The alert's `isPresented` binding clears `pendingAction` as soon as the
    /// alert dismisses, which happens before the button's `Task` gets to run.
    /// The action must therefore be passed in explicitly rather than re-read.
    func execute(_ pendingAction: PendingPackageAction) async {
        self.pendingAction = nil
        dependencyLookupTask?.cancel()
        dependencyWarning = nil

        switch pendingAction.action {
        case .upgrade:
            await runStreamingOperation(
                title: "Upgrading \(pendingAction.package.name)",
                arguments: ["upgrade", pendingAction.package.name]
            ) { stream in
                try await self.homebrewService.upgrade(
                    packages: [pendingAction.package.name],
                    stream: stream
                )
            }
        case .reinstall:
            await runStreamingOperation(
                title: "Reinstalling \(pendingAction.package.name)",
                arguments: HomebrewService.packageArguments(
                    command: "reinstall",
                    package: pendingAction.package.name,
                    type: pendingAction.package.type
                )
            ) { stream in
                try await self.homebrewService.reinstall(
                    package: pendingAction.package.name,
                    type: pendingAction.package.type,
                    stream: stream
                )
            }
        case .uninstall:
            await runStreamingOperation(
                title: "Uninstalling \(pendingAction.package.name)",
                arguments: HomebrewService.packageArguments(
                    command: "uninstall",
                    package: pendingAction.package.name,
                    type: pendingAction.package.type
                )
            ) { stream in
                try await self.homebrewService.uninstall(
                    package: pendingAction.package.name,
                    type: pendingAction.package.type,
                    stream: stream
                )
            }
        case .pin:
            await runStreamingOperation(
                title: "Pinning \(pendingAction.package.name)",
                arguments: ["pin", pendingAction.package.name]
            ) { stream in
                try await self.homebrewService.pin(
                    package: pendingAction.package.name,
                    stream: stream
                )
            }
        case .unpin:
            await runStreamingOperation(
                title: "Unpinning \(pendingAction.package.name)",
                arguments: ["unpin", pendingAction.package.name]
            ) { stream in
                try await self.homebrewService.unpin(
                    package: pendingAction.package.name,
                    stream: stream
                )
            }
        }

        await refresh()
    }

    func installPackageFromInput() async {
        let trimmedName = installPackageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter a package name to install."
            return
        }

        await runStreamingOperation(
            title: "Installing \(trimmedName)",
            arguments: installPackageType == .cask
                ? ["install", "--cask", trimmedName]
                : ["install", trimmedName]
        ) { stream in
            try await self.homebrewService.install(
                package: trimmedName,
                type: self.installPackageType,
                stream: stream
            )
        }

        installPackageName = ""
        await refresh()
    }

    private func runStreamingOperation(
        title: String,
        arguments: [String],
        execution: @escaping (@escaping @Sendable (ProcessEvent) -> Void) async throws -> ProcessResult
    ) async {
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
            }
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
            if let activeOperation = appState.activeOperation {
                appState.failOperation(activeOperation, error: error)
            }
        }
    }
}
