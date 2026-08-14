import Foundation

/// Small time-to-live cache for read-only Homebrew queries.
///
/// `brew info` and `brew list` are slow enough to be noticeable when a view
/// re-queries them on every appearance, and their results change only when the
/// app itself mutates something. Cached entries are therefore explicitly
/// invalidated after any mutating command.
actor TTLCache<Value: Sendable> {
    private struct Entry {
        let value: Value
        let storedAt: Date
    }

    private var storage: [String: Entry] = [:]
    private let lifetime: TimeInterval
    private let clock: @Sendable () -> Date

    init(lifetime: TimeInterval = 60, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.lifetime = lifetime
        self.clock = clock
    }

    func value(forKey key: String) -> Value? {
        guard let entry = storage[key] else { return nil }

        guard clock().timeIntervalSince(entry.storedAt) < lifetime else {
            storage.removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    func store(_ value: Value, forKey key: String) {
        storage[key] = Entry(value: value, storedAt: clock())
    }

    /// Returns the cached value, or computes, stores and returns a new one.
    func value(
        forKey key: String,
        computedBy compute: @Sendable () async throws -> Value
    ) async rethrows -> Value {
        if let cached = value(forKey: key) {
            return cached
        }

        let computed = try await compute()
        store(computed, forKey: key)
        return computed
    }

    func removeAll() {
        storage.removeAll()
    }

    func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}
