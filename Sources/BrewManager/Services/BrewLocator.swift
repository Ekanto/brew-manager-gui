import Foundation

protocol BrewLocating: Sendable {
    func locate() throws -> URL
}

struct BrewLocator: BrewLocating {
    let preferredPaths: [String]
    let controlledPathDirectories: [String]
    let environmentPath: String?

    init(
        preferredPaths: [String] = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ],
        controlledPathDirectories: [String] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ],
        environmentPath: String? = ProcessInfo.processInfo.environment["PATH"],
    ) {
        self.preferredPaths = preferredPaths
        self.controlledPathDirectories = controlledPathDirectories
        self.environmentPath = environmentPath
    }

    func locate() throws -> URL {
        var seen = Set<String>()

        for path in candidatePaths where seen.insert(path).inserted {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        throw BrewError.homebrewNotFound
    }

    private var candidatePaths: [String] {
        var candidates = preferredPaths
        candidates.append(contentsOf: controlledPathDirectories.map { "\($0)/brew" })

        if let environmentPath {
            let pathDirectories = environmentPath
                .split(separator: ":")
                .map(String.init)
                .filter { !$0.isEmpty }
            candidates.append(contentsOf: pathDirectories.map { "\($0)/brew" })
        }

        return candidates
    }
}
