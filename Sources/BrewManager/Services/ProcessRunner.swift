import Foundation

struct BrewCommand: Sendable {
    let arguments: [String]
}

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: Duration
}

struct ProcessEvent: Sendable {
    enum Stream: Sendable {
        case stdout
        case stderr
    }

    let stream: Stream
    let text: String
}

protocol ProcessRunning: Sendable {
    func run(
        executable: URL,
        arguments: [String]
    ) async throws -> ProcessResult

    func runStreaming(
        executable: URL,
        arguments: [String],
        onEvent: @escaping @Sendable (ProcessEvent) -> Void
    ) async throws -> ProcessResult

    func stream(
        executable: URL,
        arguments: [String]
    ) -> AsyncThrowingStream<ProcessEvent, Error>
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "BrewManager.ProcessOutputBuffer")
    private var stdoutData = Data()
    private var stderrData = Data()

    func append(_ data: Data, stream: ProcessEvent.Stream) {
        queue.sync {
            switch stream {
            case .stdout:
                stdoutData.append(data)
            case .stderr:
                stderrData.append(data)
            }
        }
    }

    func outputStrings() -> (stdout: String, stderr: String) {
        queue.sync {
            (
                String(decoding: stdoutData, as: UTF8.self),
                String(decoding: stderrData, as: UTF8.self)
            )
        }
    }
}

final class ProcessRunner: ProcessRunning, @unchecked Sendable {
    /// Homebrew prints "hint" paragraphs to stderr that are noise inside a GUI
    /// console, and a Finder-launched app inherits a minimal PATH. Both are
    /// corrected here so every command sees the same predictable environment.
    static func childEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment

        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        environment["HOMEBREW_NO_EMOJI"] = "1"
        environment["HOMEBREW_COLOR"] = nil

        let requiredPathEntries = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existing = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let merged = existing + requiredPathEntries.filter { !existing.contains($0) }
        environment["PATH"] = merged.joined(separator: ":")

        return environment
    }

    func run(
        executable: URL,
        arguments: [String]
    ) async throws -> ProcessResult {
        try await execute(
            executable: executable,
            arguments: arguments,
            onEvent: nil
        )
    }

    func runStreaming(
        executable: URL,
        arguments: [String],
        onEvent: @escaping @Sendable (ProcessEvent) -> Void
    ) async throws -> ProcessResult {
        try await execute(
            executable: executable,
            arguments: arguments,
            onEvent: onEvent
        )
    }

    func stream(
        executable: URL,
        arguments: [String]
    ) -> AsyncThrowingStream<ProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    _ = try await execute(
                        executable: executable,
                        arguments: arguments,
                        onEvent: { event in
                            continuation.yield(event)
                        }
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func execute(
        executable: URL,
        arguments: [String],
        onEvent: (@Sendable (ProcessEvent) -> Void)?
    ) async throws -> ProcessResult {
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = Self.childEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let outputBuffer = ProcessOutputBuffer()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            outputBuffer.append(data, stream: .stdout)

            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                onEvent?(ProcessEvent(stream: .stdout, text: text))
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            outputBuffer.append(data, stream: .stderr)

            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                onEvent?(ProcessEvent(stream: .stderr, text: text))
            }
        }

        let clock = ContinuousClock()
        let start = clock.now

        let exitCode: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { finishedProcess in
                    continuation.resume(returning: finishedProcess.terminationStatus)
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(
                        throwing: BrewError.processLaunchFailed(error.localizedDescription)
                    )
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingStdout.isEmpty {
            outputBuffer.append(remainingStdout, stream: .stdout)

            if let text = String(data: remainingStdout, encoding: .utf8), !text.isEmpty {
                onEvent?(ProcessEvent(stream: .stdout, text: text))
            }
        }

        let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingStderr.isEmpty {
            outputBuffer.append(remainingStderr, stream: .stderr)

            if let text = String(data: remainingStderr, encoding: .utf8), !text.isEmpty {
                onEvent?(ProcessEvent(stream: .stderr, text: text))
            }
        }

        let output = outputBuffer.outputStrings()

        let duration = start.duration(to: clock.now)

        AppLogger.process.debug(
            "Executed process: \(executable.path, privacy: .public) \(arguments.joined(separator: " "), privacy: .public) [exit=\(exitCode)]"
        )

        return ProcessResult(
            exitCode: exitCode,
            stdout: output.stdout,
            stderr: output.stderr,
            duration: duration
        )
    }
}
