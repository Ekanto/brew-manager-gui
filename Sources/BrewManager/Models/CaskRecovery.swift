import Foundation

/// A cask Homebrew still records as installed even though its application is
/// no longer on disk — the state you land in after dragging an app to the
/// Trash instead of uninstalling it through Homebrew.
///
/// Homebrew reports this during an upgrade as:
///
///     Error: Problems with multiple casks:
///     raycast: It seems the App source '/Applications/Raycast.app' is not there.
///
/// The upgrade cannot proceed because Homebrew backs up the existing app before
/// replacing it, and there is nothing to back up.
struct StaleCask: Identifiable, Hashable, Sendable {
    let name: String
    /// The artifact Homebrew expected to find, e.g. `/Applications/Raycast.app`.
    let missingPath: String?

    var id: String { name }

    var missingItemName: String? {
        missingPath.map { ($0 as NSString).lastPathComponent }
    }

}

/// A Homebrew cask whose app exists in /Applications but is owned by root.
/// Homebrew can still repair it, but a GUI subprocess cannot answer the sudo
/// password prompt, so users need to run the exact command in Terminal.
struct CaskPermissionIssue: Identifiable, Hashable, Sendable {
    let name: String
    let appPath: String
    let owner: String

    var id: String { "\(name):\(appPath)" }

    var terminalCommand: String {
        "brew reinstall --cask \(name)"
    }
}

/// How the user chose to resolve a stale cask record.
enum CaskRecoveryAction: String, Identifiable, CaseIterable, Sendable {
    /// Drop Homebrew's record and keep the app uninstalled.
    case forget
    /// Download the cask again and restore the application.
    case reinstall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forget:
            return "Forget"
        case .reinstall:
            return "Reinstall"
        }
    }

    var systemImage: String {
        switch self {
        case .forget:
            return "eraser"
        case .reinstall:
            return "arrow.down.app"
        }
    }

    var isDestructive: Bool { self == .forget }

    func explanation(for casks: [String]) -> String {
        let names = casks.joined(separator: ", ")
        switch self {
        case .forget:
            return "Homebrew will stop tracking \(names). The application stays uninstalled and will no longer appear in Updates."
        case .reinstall:
            return "Homebrew will download \(names) again and put the application back in /Applications."
        }
    }
}

enum CaskRecovery {    /// Matches both the per-cask form (`name: It seems the App source ...`) and
    /// the bare single-cask form, which omits the name.
    static let pattern = #"^(?:([^\s:]+):\s*)?It seems the \w+ source '([^']+)' is not there\.?$"#

    /// Extracts the casks Homebrew complained about.
    ///
    /// - Parameter candidates: names Homebrew currently considers installed.
    ///   A parsed name is only accepted if it appears here, so a malformed or
    ///   unexpected message can never produce a command against an arbitrary
    ///   string.
    static func staleCasks(in output: String, candidates: [String]) -> [StaleCask] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }

        let candidateSet = Set(candidates)
        var results: [StaleCask] = []
        var seen: Set<String> = []

        let range = NSRange(output.startIndex..<output.endIndex, in: output)

        for match in regex.matches(in: output, range: range) {
            guard let pathRange = Range(match.range(at: 2), in: output) else { continue }
            let path = String(output[pathRange])

            var name: String?
            if let nameRange = Range(match.range(at: 1), in: output) {
                let labelled = String(output[nameRange])
                // The label is only trusted when Homebrew is really naming a
                // cask. In the single-cask form the line begins "Error: ", and
                // that prefix would otherwise be read as the name.
                if candidateSet.contains(labelled) {
                    name = labelled
                }
            }

            if name == nil {
                // Recover the name from the artifact instead:
                // "Only Switch.app" -> "only-switch".
                name = inferredName(fromArtifactPath: path, candidates: candidateSet)
            }

            guard
                let resolved = name,
                candidateSet.contains(resolved),
                seen.insert(resolved).inserted
            else {
                continue
            }

            results.append(StaleCask(name: resolved, missingPath: path))
        }

        return results
    }

    /// True when Homebrew failed because an artifact it expected on disk was
    /// gone. Used to classify the error; the specific casks are resolved
    /// separately against the installed list.
    static func indicatesStaleArtifacts(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("it seems the") && normalized.contains("is not there")
    }

    /// Names Homebrew labelled explicitly, which it does whenever more than one
    /// cask failed. Safe to display without cross-checking.
    static func labelledNames(in output: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)

        return regex.matches(in: output, range: range).compactMap { match -> String? in
            guard let nameRange = Range(match.range(at: 1), in: output) else { return nil }
            let name = String(output[nameRange])

            // Cask tokens are always lowercase, so this rejects the "Error: "
            // prefix that begins the single-cask form of the message.
            guard
                name == name.lowercased(),
                name.isValidBrewPackageName
            else {
                return nil
            }

            return name
        }
    }

    /// Only ever returns a name that is already known to be installed, so the
    /// guess cannot introduce an unknown package name.
    private static func inferredName(fromArtifactPath path: String, candidates: Set<String>) -> String? {
        let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let slug = base
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        if candidates.contains(slug) { return slug }

        let compact = slug.replacingOccurrences(of: "-", with: "")
        return candidates.first { $0.replacingOccurrences(of: "-", with: "") == compact }
    }
}
