import Foundation
import Observation

struct PendingBrewfileApply: Identifiable {
    let id = UUID()
    let pathDescription: String
}

@MainActor
@Observable
final class BrewfileViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var brewfilePath: String = "~/Brewfile"
    var pendingApply: PendingBrewfileApply?
    var isLoading = false
    var statusMessage: String?
    var errorMessage: String?

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    func exportCurrentMachine() async {
        isLoading = true
        defer { isLoading = false }

        let fileURL = resolvedBrewfileURL()

        let result = await runStreamingOperation(
            title: "Exporting Brewfile",
            arguments: brewfileArguments(base: ["bundle", "dump", "--force", "--describe"], fileURL: fileURL)
        ) { stream in
            try await self.homebrewService.exportBrewfile(fileURL: fileURL, stream: stream)
        }

        guard let result else { return }
        if result.exitCode == 0 {
            let location = fileURL?.path ?? "default location"
            statusMessage = "Brewfile exported to \(location)."
            errorMessage = nil
        }
    }

    func checkBrewfile() async {
        isLoading = true
        defer { isLoading = false }

        let fileURL = resolvedBrewfileURL()

        let result = await runStreamingOperation(
            title: "Checking Brewfile",
            arguments: brewfileArguments(base: ["bundle", "check"], fileURL: fileURL),
            treatNonZeroAsFailure: false
        ) { stream in
            try await self.homebrewService.checkBrewfile(fileURL: fileURL, stream: stream)
        }

        guard let result else { return }
        if result.exitCode == 0 {
            statusMessage = "Brewfile check passed."
            errorMessage = nil
        } else {
            statusMessage = "Brewfile check reported differences."
            errorMessage = nil
        }
    }

    func requestApply() {
        pendingApply = PendingBrewfileApply(pathDescription: resolvedBrewfileURL()?.path ?? "default Brewfile")
    }

    func applyRequestedBrewfile() async {
        pendingApply = nil
        isLoading = true
        defer { isLoading = false }

        let fileURL = resolvedBrewfileURL()

        let result = await runStreamingOperation(
            title: "Applying Brewfile",
            arguments: brewfileArguments(base: ["bundle"], fileURL: fileURL)
        ) { stream in
            try await self.homebrewService.applyBrewfile(fileURL: fileURL, stream: stream)
        }

        guard let result else { return }
        if result.exitCode == 0 {
            statusMessage = "Brewfile applied successfully."
            errorMessage = nil
        }
    }

    private func runStreamingOperation(
        title: String,
        arguments: [String],
        treatNonZeroAsFailure: Bool = true,
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

            if treatNonZeroAsFailure, result.exitCode != 0 {
                let classified = BrewError.classify(
                    command: command,
                    exitCode: result.exitCode,
                    stderr: result.stderr
                )
                errorMessage = classified.localizedDescription
                statusMessage = nil
            } else {
                errorMessage = nil
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

    private func resolvedBrewfileURL() -> URL? {
        let trimmed = brewfilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let expanded = trimmed.expandingTildePath
        return URL(fileURLWithPath: expanded)
    }

    private func brewfileArguments(base: [String], fileURL: URL?) -> [String] {
        guard let fileURL else {
            return base
        }
        return base + ["--file", fileURL.path]
    }
}
