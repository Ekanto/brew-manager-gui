import Foundation
import Observation

@MainActor
@Observable
final class TapsViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var taps: [TapInfo] = []
    var isLoading = false
    var errorMessage: String?
    var newTapName: String = ""
    var pendingRemoval: TapInfo?

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            taps = try await homebrewService.listTaps()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTap() async {
        let trimmedName = newTapName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter a tap in owner/repository form, for example homebrew/cask."
            return
        }

        do {
            try InputValidation.validateTapName(trimmedName)
        } catch {
            errorMessage = "Taps must be in owner/repository form, for example homebrew/cask."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let succeeded = await runStreamingOperation(
            title: "Adding \(trimmedName)",
            arguments: ["tap", trimmedName]
        ) { stream in
            try await self.homebrewService.addTap(name: trimmedName, stream: stream)
        }

        guard succeeded else { return }

        newTapName = ""
        await refresh()
    }

    func requestRemoval(_ tap: TapInfo) {
        guard !tap.isOfficial else {
            errorMessage = "Official Homebrew taps cannot be removed."
            return
        }

        pendingRemoval = tap
    }

    func remove(_ tap: TapInfo) async {
        pendingRemoval = nil

        guard !tap.isOfficial else {
            errorMessage = "Official Homebrew taps cannot be removed."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let succeeded = await runStreamingOperation(
            title: "Removing \(tap.name)",
            arguments: ["untap", tap.name]
        ) { stream in
            try await self.homebrewService.removeTap(name: tap.name, stream: stream)
        }

        if succeeded {
            await refresh()
        }
    }

    private func runStreamingOperation(
        title: String,
        arguments: [String],
        execution: @escaping (@escaping @Sendable (ProcessEvent) -> Void) async throws -> ProcessResult
    ) async -> Bool {
        var operation: OperationConsoleModel?

        do {
            let command = try await homebrewService.commandString(arguments: arguments)
            let activeOperation = appState.beginOperation(title: title, command: command)
            operation = activeOperation

            let result = try await execution { event in
                Task { @MainActor in
                    activeOperation.append(event: event)
                }
            }

            appState.finishOperation(activeOperation, result: result)

            if result.exitCode == 0 {
                errorMessage = nil
                return true
            }

            errorMessage = BrewError.classify(
                command: command,
                exitCode: result.exitCode,
                stderr: result.stderr
            ).localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            if let operation {
                appState.failOperation(operation, error: error)
            }
            return false
        }
    }
}
