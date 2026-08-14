import Foundation
import Observation

enum ServiceActionType: String {
    case start
    case stop
    case restart
}

@MainActor
@Observable
final class ServicesViewModel {
    private let homebrewService: HomebrewService
    private let appState: AppState

    var services: [BrewServiceInfo] = []
    var isLoading = false
    var errorMessage: String?
    var statusMessage: String?

    private var hasLoaded = false

    init(homebrewService: HomebrewService, appState: AppState) {
        self.homebrewService = homebrewService
        self.appState = appState
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            services = try await homebrewService.servicesList()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runAction(_ action: ServiceActionType, serviceName: String) async {
        let arguments: [String]
        let title: String

        switch action {
        case .start:
            arguments = ["services", "start", serviceName]
            title = "Starting \(serviceName)"
        case .stop:
            arguments = ["services", "stop", serviceName]
            title = "Stopping \(serviceName)"
        case .restart:
            arguments = ["services", "restart", serviceName]
            title = "Restarting \(serviceName)"
        }

        await runStreamingOperation(title: title, arguments: arguments) { stream in
            switch action {
            case .start:
                return try await self.homebrewService.startService(named: serviceName, stream: stream)
            case .stop:
                return try await self.homebrewService.stopService(named: serviceName, stream: stream)
            case .restart:
                return try await self.homebrewService.restartService(named: serviceName, stream: stream)
            }
        }

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
