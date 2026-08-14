import Foundation

/// Serialises mutating Homebrew commands.
///
/// `HomebrewService` is an actor, but Swift actors are *re-entrant*: when a
/// method suspends at an `await` (which every `Process` invocation does), other
/// calls are free to interleave. That means two `brew install` runs could
/// execute simultaneously, which Homebrew rejects with lock errors and which
/// can leave the Cellar in a half-written state.
///
/// This gate provides genuine FIFO mutual exclusion on top of the actor.
actor OperationGate {
    private var isBusy = false
    private var pending: [(id: UUID, continuation: CheckedContinuation<Void, Never>)] = []

    /// Number of callers currently waiting for the gate, for UI display.
    var queueDepth: Int { pending.count }

    var isRunning: Bool { isBusy }

    private func acquire() async {
        guard isBusy else {
            isBusy = true
            return
        }

        let id = UUID()
        await withCheckedContinuation { continuation in
            pending.append((id, continuation))
        }
        // Ownership was handed to us directly by `release`, so `isBusy`
        // is already true and must not be set again here.
    }

    private func release() {
        guard !pending.isEmpty else {
            isBusy = false
            return
        }

        // Hand ownership straight to the next waiter without clearing
        // `isBusy`, so a newly arriving caller cannot jump the queue.
        let next = pending.removeFirst()
        next.continuation.resume()
    }

    /// Runs `body` with exclusive access. Access is always released, including
    /// when `body` throws or is cancelled.
    func withExclusiveAccess<T: Sendable>(
        _ body: @Sendable () async throws -> T
    ) async rethrows -> T {
        await acquire()

        do {
            let value = try await body()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }
}
