import Foundation

/// `brew doctor` exits non-zero whenever it emits any advisory warning, even
/// when nothing is actually broken. Its output is a boilerplate preamble
/// followed by `Warning:` blocks, so it is parsed rather than shown raw.
struct DoctorReport: Sendable {
    struct Warning: Identifiable, Sendable {
        let id = UUID()
        let title: String
        let detail: String

        var hasDetail: Bool {
            !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// A remediation command that Homebrew itself printed, e.g.
    /// `brew install fzf python@3.13`. Only allowlisted subcommands are
    /// surfaced so the app never offers to run arbitrary parsed text.
    struct SuggestedFix: Identifiable, Sendable, Equatable {
        let id: String
        let arguments: [String]

        var displayCommand: String {
            "brew " + arguments.joined(separator: " ")
        }

        var isDestructive: Bool {
            guard let subcommand = arguments.first else { return true }
            return ["uninstall", "untap", "cleanup"].contains(subcommand)
        }

        var confirmTitle: String {
            guard let subcommand = arguments.first else { return "Run" }
            switch subcommand {
            case "install":
                return "Install"
            case "reinstall":
                return "Reinstall"
            case "link", "unlink":
                return subcommand.capitalized
            case "upgrade":
                return "Upgrade"
            default:
                return "Run"
            }
        }
    }

    private static let allowedSubcommands: Set<String> = [
        "install",
        "reinstall",
        "link",
        "unlink",
        "upgrade",
        "update",
        "tap",
        "untap"
    ]

    let warnings: [Warning]
    let suggestedFixes: [SuggestedFix]

    var isHealthy: Bool {
        warnings.isEmpty
    }

    var headline: String {
        switch warnings.count {
        case 0:
            return "No problems found. Your Homebrew installation looks healthy."
        case 1:
            return "Homebrew reported 1 warning."
        default:
            return "Homebrew reported \(warnings.count) warnings."
        }
    }

    static func parse(_ output: String) -> DoctorReport {
        let normalized = output.replacingOccurrences(of: "\r\n", with: "\n")

        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var warnings: [Warning] = []
        var currentTitle: String?
        var currentDetail: [String] = []

        func flush() {
            guard let title = currentTitle else { return }
            warnings.append(
                Warning(
                    title: title,
                    detail: currentDetail.joined(separator: "\n\n")
                )
            )
            currentTitle = nil
            currentDetail = []
        }

        for paragraph in paragraphs {
            if paragraph.hasPrefix("Warning:") {
                flush()

                var lines = paragraph.components(separatedBy: "\n")
                let firstLine = lines.removeFirst()
                currentTitle = String(firstLine.dropFirst("Warning:".count))
                    .trimmingCharacters(in: .whitespaces)

                let remainder = lines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !remainder.isEmpty {
                    currentDetail.append(remainder)
                }
            } else if currentTitle != nil {
                // Continuation of the warning that is currently being built.
                currentDetail.append(paragraph)
            }
            // Paragraphs before the first `Warning:` are the boilerplate
            // preamble telling the user these warnings are safe to ignore.
        }

        flush()

        return DoctorReport(
            warnings: warnings,
            suggestedFixes: parseSuggestedFixes(normalized)
        )
    }

    /// Homebrew prints remediation as its own indented line starting with
    /// `brew `. Backticked mentions inside prose (``Run `brew missing` ``) are
    /// ignored because they never begin the line.
    static func parseSuggestedFixes(_ output: String) -> [SuggestedFix] {
        var fixes: [SuggestedFix] = []
        var seen: Set<String> = []

        for rawLine in output.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("brew ") else { continue }

            let tokens = line
                .split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)
                .dropFirst()

            let arguments = Array(tokens)
            guard
                let subcommand = arguments.first,
                allowedSubcommands.contains(subcommand),
                arguments.count > 1 || subcommand == "update",
                arguments.dropFirst().allSatisfy(isSafeArgument)
            else {
                continue
            }

            let key = arguments.joined(separator: " ")
            guard seen.insert(key).inserted else { continue }

            fixes.append(SuggestedFix(id: key, arguments: arguments))
        }

        return fixes
    }

    private static func isSafeArgument(_ argument: String) -> Bool {
        if argument.hasPrefix("-") {
            return argument.range(of: #"^--?[A-Za-z0-9][A-Za-z0-9\-]*$"#, options: .regularExpression) != nil
        }

        // Tap-qualified names legitimately contain "/", so the charset alone
        // cannot reject path traversal. Absolute and relative paths are never
        // valid package names, so exclude them explicitly.
        guard
            !argument.contains(".."),
            !argument.hasPrefix("/"),
            !argument.hasPrefix(".")
        else {
            return false
        }

        return argument.isValidBrewPackageName
    }
}
