import Foundation
import Observation

@MainActor
@Observable
final class DiscoverViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var searchText: String = ""
    var selectedType: PackageType?
    var results: [CatalogPackage] = []
    var isSearching = false
    var errorMessage: String?
    var statusMessage: String?
    var selectedPackage: CatalogPackage? {
        didSet {
            guard selectedPackage?.id != oldValue?.id else { return }
            detail = nil

            guard selectedPackage != nil else {
                isLoadingDetail = false
                return
            }

            Task {
                await loadDetailForSelectedPackage()
            }
        }
    }
    var detail: BrewPackage?
    var isLoadingDetail = false
    var pendingInstall: CatalogPackage?

    private var searchTask: Task<Void, Never>?

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    func searchDebounced() {
        searchTask?.cancel()
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            selectedPackage = nil
            detail = nil
            isSearching = false
            errorMessage = nil
            return
        }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self?.searchNow()
        }
    }

    func searchNow() async {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            selectedPackage = nil
            detail = nil
            isSearching = false
            errorMessage = nil
            return
        }

        let query = trimmedQuery
        let type = selectedType
        let previousSelectionID = selectedPackage?.id

        isSearching = true

        do {
            async let catalogResults = homebrewService.searchCatalog(query: query, type: type)
            async let installedFormulae = homebrewService.listInstalledPackages(type: .formula)
            async let installedCasks = homebrewService.listInstalledPackages(type: .cask)

            let (catalog, formulae, casks) = try await (catalogResults, installedFormulae, installedCasks)

            guard !Task.isCancelled else { return }
            guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                  selectedType == type else { return }

            let installedIDs = Set((formulae + casks).map(\.id))
            results = catalog
                .map { package in
                    var markedPackage = package
                    markedPackage.isInstalled = installedIDs.contains(package.id)
                    return markedPackage
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            if let previousSelectionID,
               let selected = results.first(where: { $0.id == previousSelectionID }) {
                selectedPackage = selected
            } else {
                selectedPackage = results.first
            }

            errorMessage = nil
            isSearching = false
        } catch is CancellationError {
            guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                  selectedType == type else { return }
            isSearching = false
        } catch {
            guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                  selectedType == type else { return }
            results = []
            selectedPackage = nil
            errorMessage = error.localizedDescription
            isSearching = false
        }
    }

    func loadDetailForSelectedPackage() async {
        guard let selectedPackage else {
            detail = nil
            isLoadingDetail = false
            return
        }

        isLoadingDetail = true

        do {
            let packageDetail = try await homebrewService.packageDetails(named: selectedPackage.name)
            guard self.selectedPackage?.id == selectedPackage.id else { return }
            detail = packageDetail
            errorMessage = nil
            isLoadingDetail = false
        } catch {
            guard self.selectedPackage?.id == selectedPackage.id else { return }
            detail = nil
            errorMessage = error.localizedDescription
            isLoadingDetail = false
        }
    }

    func requestInstall(_ package: CatalogPackage) {
        guard !package.isInstalled else { return }
        pendingInstall = package
    }

    func install(_ package: CatalogPackage) async {
        pendingInstall = nil

        await runStreamingOperation(
            title: "Installing \(package.name)",
            arguments: HomebrewService.packageArguments(
                command: "install",
                package: package.name,
                type: package.type
            )
        ) { stream in
            try await self.homebrewService.install(
                package: package.name,
                type: package.type,
                stream: stream
            )
        }

        await searchNow()
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
