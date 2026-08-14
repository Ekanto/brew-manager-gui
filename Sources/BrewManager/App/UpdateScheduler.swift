import Foundation

/// Periodically triggers a background check for outdated packages.
///
/// macOS has no `BGTaskScheduler` for this kind of work, so this is a plain
/// repeating task. It also fires shortly after launch, because an app that is
/// opened rarely would otherwise never report anything.
@MainActor
final class UpdateScheduler {
    private var task: Task<Void, Never>?
    private let initialDelay: Duration
    private let performCheck: @MainActor () async -> Void

    /// Never poll more often than this, regardless of the stored preference.
    static let minimumInterval: TimeInterval = 300

    init(
        initialDelay: Duration = .seconds(20),
        performCheck: @escaping @MainActor () async -> Void
    ) {
        self.initialDelay = initialDelay
        self.performCheck = performCheck
    }

    func start(interval: TimeInterval) {
        stop()

        let seconds = max(interval, Self.minimumInterval)

        task = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: self.initialDelay)
            } catch {
                return
            }

            while !Task.isCancelled {
                await self.performCheck()

                do {
                    try await Task.sleep(for: .seconds(seconds))
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    var isRunning: Bool { task != nil }

    deinit {
        task?.cancel()
    }
}
