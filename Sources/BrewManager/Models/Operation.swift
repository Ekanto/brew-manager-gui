import Foundation
import Observation

enum OperationSeverity: Sendable {
    case success
    case warning
    case failure
}

struct OperationRecord: Identifiable, Sendable {
    let id: UUID
    let title: String
    let command: String
    let output: String
    let exitCode: Int32
    let startedAt: Date
    let endedAt: Date
    let duration: Duration

    init(
        id: UUID = UUID(),
        title: String,
        command: String,
        output: String,
        exitCode: Int32,
        startedAt: Date,
        endedAt: Date,
        duration: Duration
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.output = output
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
    }

    var succeeded: Bool {
        exitCode == 0
    }
}

@MainActor
@Observable
final class OperationConsoleModel: Identifiable {
    let id: UUID
    let title: String
    let command: String
    let startedAt: Date

    /// Exit codes that mean "finished with advisories" rather than "failed".
    /// `brew doctor`, for example, exits 1 for purely informational warnings.
    let warningExitCodes: Set<Int32>

    var output: String
    var isRunning: Bool
    var exitCode: Int32?
    var duration: Duration?

    init(
        id: UUID = UUID(),
        title: String,
        command: String,
        startedAt: Date = Date(),
        warningExitCodes: Set<Int32> = []
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.startedAt = startedAt
        self.warningExitCodes = warningExitCodes
        self.output = ""
        self.isRunning = true
        self.exitCode = nil
        self.duration = nil
    }

    var severity: OperationSeverity {
        guard let exitCode else { return .success }
        if exitCode == 0 { return .success }
        return warningExitCodes.contains(exitCode) ? .warning : .failure
    }

    func append(event: ProcessEvent) {
        switch event.stream {
        case .stdout:
            output.append(event.text)
        case .stderr:
            output.append(event.text)
        }
    }

    func complete(with result: ProcessResult) {
        if output.isEmpty {
            output = result.stdout
            if !result.stderr.isEmpty {
                output += "\n" + result.stderr
            }
        }

        exitCode = result.exitCode
        duration = result.duration
        isRunning = false
    }

    func fail(with error: Error) {
        output += "\n\n" + (error.localizedDescription)
        exitCode = 1
        duration = .zero
        isRunning = false
    }
}
