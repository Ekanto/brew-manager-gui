import Foundation

enum BrewError: Error, LocalizedError, Equatable, Sendable {
    case homebrewNotFound
    case invalidPackageName(String)
    case processLaunchFailed(String)
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case permissionDenied(details: String)
    case networkFailure(details: String)
    case packageNotFound(name: String)
    case packageConflict(details: String)
    case staleCaskArtifacts(casks: [String])
    case invalidJSON(details: String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .homebrewNotFound:
            return "Homebrew was not found. Install Homebrew or configure its executable path."
        case .invalidPackageName(let package):
            return "Invalid package name: \(package)"
        case .processLaunchFailed(let details):
            return "Failed to launch Homebrew: \(details)"
        case .commandFailed(let command, let exitCode, let stderr):
            if stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Command failed (\(exitCode)): \(command)"
            }
            return "Homebrew command failed (\(exitCode)): \(stderr)"
        case .permissionDenied(let details):
            return "Permission denied: \(details)"
        case .networkFailure(let details):
            return "Network failure while running Homebrew: \(details)"
        case .packageNotFound(let name):
            return "Package not found: \(name)"
        case .packageConflict(let details):
            return "Package conflict: \(details)"
        case .staleCaskArtifacts(let casks):
            let names = casks.joined(separator: ", ")
            if casks.count == 1 {
                return "\(names) is recorded as installed but its application is missing from disk, so Homebrew cannot upgrade it."
            }
            return "\(casks.count) casks are recorded as installed but their applications are missing from disk, so Homebrew cannot upgrade them: \(names)."
        case .invalidJSON(let details):
            return "Unable to decode Homebrew output: \(details)"
        case .userCancelled:
            return "Operation cancelled."
        }
    }

    static func classify(command: String, exitCode: Int32, stderr: String) -> BrewError {
        let normalized = stderr.lowercased()

        // Checked before the generic matches below: this message contains
        // "not there", and its remedy is specific enough to warrant its own case.
        if CaskRecovery.indicatesStaleArtifacts(stderr) {
            let names = CaskRecovery.labelledNames(in: stderr)
            if !names.isEmpty {
                return .staleCaskArtifacts(casks: names)
            }
        }

        if normalized.contains("permission denied")
            || normalized.contains("operation not permitted")
            || normalized.contains("not writable")
        {
            return .permissionDenied(details: stderr)
        }

        if normalized.contains("could not resolve")
            || normalized.contains("timed out")
            || normalized.contains("network")
            || normalized.contains("failed to fetch")
        {
            return .networkFailure(details: stderr)
        }

        if normalized.contains("no available formula")
            || normalized.contains("no available cask")
            || normalized.contains("not found")
        {
            let name = extractLikelyPackageName(from: command) ?? "unknown"
            return .packageNotFound(name: name)
        }

        if normalized.contains("conflict")
            || normalized.contains("already installed")
            || normalized.contains("keg-only")
        {
            return .packageConflict(details: stderr)
        }

        return .commandFailed(command: command, exitCode: exitCode, stderr: stderr)
    }

    private static func extractLikelyPackageName(from command: String) -> String? {
        let components = command.split(separator: " ")
        return components.last.map(String.init)
    }
}
