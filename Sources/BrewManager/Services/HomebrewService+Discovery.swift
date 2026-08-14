import Foundation

// MARK: - Discovery, dependencies, taps and disk usage

extension HomebrewService {

    // MARK: Catalog search

    /// Searches the full Homebrew catalog, not just installed packages.
    ///
    /// `brew search` exits 1 when nothing matches, which is a normal empty
    /// result rather than a failure, so the exit code is deliberately not
    /// treated as an error here.
    func searchCatalog(query: String, type: PackageType?) async throws -> [CatalogPackage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        try InputValidation.validateSearchQuery(trimmed)

        var results: [CatalogPackage] = []

        for candidate in type.map({ [$0] }) ?? [PackageType.formula, .cask] {
            let flag = candidate == .cask ? "--cask" : "--formula"
            let arguments = ["search", flag, trimmed]
            let result = try await runCommand(arguments: arguments)

            // Exit 1 with "no ... found" is an empty result set.
            if result.exitCode != 0 {
                let combined = result.stdout + result.stderr
                if combined.localizedCaseInsensitiveContains("no formulae or casks found")
                    || combined.localizedCaseInsensitiveContains("no formula or cask found") {
                    continue
                }
                throw BrewError.classify(
                    command: try commandString(arguments: arguments),
                    exitCode: result.exitCode,
                    stderr: result.stderr
                )
            }

            results.append(contentsOf: Self.parseSearchOutput(result.stdout, type: candidate))
        }

        return results
    }

    /// `brew search` prints one name per line, but may include `==>` section
    /// headers and informational lines that must be discarded.
    static func parseSearchOutput(_ text: String, type: PackageType) -> [CatalogPackage] {
        text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty else { return false }
                guard !line.hasPrefix("==>") else { return false }
                guard !line.hasPrefix("If you meant") else { return false }
                guard !line.hasPrefix("Error") && !line.hasPrefix("Warning") else { return false }
                // Real package names never contain spaces.
                return !line.contains(" ")
            }
            .map { CatalogPackage(name: $0, type: type) }
    }

    // MARK: Dependencies

    /// Installed packages that depend on `package`. Used to warn before an
    /// uninstall that would break something else.
    func dependents(of package: String) async throws -> DependencyReport {
        try InputValidation.validatePackageNames([package])

        let arguments = ["uses", "--installed", package]
        let result = try await runCommand(arguments: arguments)

        // A package nothing uses exits non-zero on some Homebrew versions.
        guard result.exitCode == 0 || result.stdout.isEmpty else {
            throw BrewError.classify(
                command: try commandString(arguments: arguments),
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        let names = result.stdout
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("==>") && !$0.contains(" ") }

        return DependencyReport(package: package, dependents: names)
    }

    func dependencyTree(for package: String) async throws -> String {
        try InputValidation.validatePackageNames([package])

        let arguments = ["deps", "--tree", "--installed", package]
        let result = try await runCommand(arguments: arguments)
        guard result.exitCode == 0 else {
            throw BrewError.classify(
                command: try commandString(arguments: arguments),
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return result.stdout
    }

    // MARK: Taps

    func listTaps() async throws -> [TapInfo] {
        let arguments = ["tap"]
        let result = try await runCommand(arguments: arguments)
        guard result.exitCode == 0 else {
            throw BrewError.classify(
                command: try commandString(arguments: arguments),
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return result.stdout
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { TapInfo(name: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addTap(
        name: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validateTapName(name)
        return try await runCommand(arguments: ["tap", name], stream: stream)
    }

    func removeTap(
        name: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validateTapName(name)
        return try await runCommand(arguments: ["untap", name], stream: stream)
    }

    // MARK: Greedy upgrades

    /// Casks that update themselves are invisible to a plain `brew outdated`,
    /// so the Updates count silently under-reports without `--greedy`.
    func outdatedPackages(greedy: Bool) async throws -> [OutdatedPackage] {
        var arguments = ["outdated", "--json=v2"]
        if greedy {
            arguments.append("--greedy")
        }

        let result = try await runCommand(arguments: arguments)
        guard result.exitCode == 0 else {
            throw BrewError.classify(
                command: try commandString(arguments: arguments),
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        // `--greedy` triggers an API download banner before the JSON body.
        let json = Self.extractJSONObject(from: result.stdout)

        return try BrewJSONDecoder.decodeOutdated(from: Data(json.utf8))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Homebrew may print progress lines before the JSON payload; take the
    /// document starting at the first brace.
    static func extractJSONObject(from output: String) -> String {
        guard let start = output.firstIndex(of: "{") else { return output }
        return String(output[start...])
    }

    func upgradeAll(
        greedy: Bool,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        var arguments = ["upgrade"]
        if greedy {
            arguments.append("--greedy")
        }
        return try await runCommand(arguments: arguments, stream: stream)
    }

    // MARK: Disk usage

    func cellarDirectory() async throws -> URL {
        try await singlePathCommand(["--cellar"])
    }

    func caskroomDirectory() async throws -> URL {
        try await singlePathCommand(["--caskroom"])
    }

    private func singlePathCommand(_ arguments: [String]) async throws -> URL {
        let result = try await runCommand(arguments: arguments)
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        guard result.exitCode == 0, !path.isEmpty else {
            throw BrewError.classify(
                command: try commandString(arguments: arguments),
                exitCode: result.exitCode,
                stderr: result.stderr.isEmpty ? "No path returned." : result.stderr
            )
        }

        return URL(fileURLWithPath: path)
    }

    /// Measures each installed package's footprint by sizing its directory in
    /// the Cellar or Caskroom. `brew info` does not report this for casks, and
    /// summing it per package is far faster than one `brew info` call each.
    func diskUsage(for packages: [BrewPackage]) async throws -> [PackageDiskUsage] {
        guard !packages.isEmpty else { return [] }

        let needsCellar = packages.contains { $0.type == .formula }
        let needsCaskroom = packages.contains { $0.type == .cask }

        let cellar = needsCellar ? try? await cellarDirectory() : nil
        let caskroom = needsCaskroom ? try? await caskroomDirectory() : nil

        let inputs: [(String, PackageType, URL?)] = packages.map { package in
            let root = package.type == .cask ? caskroom : cellar
            return (package.name, package.type, root)
        }

        // Sizing thousands of files must not block the actor or the main thread.
        return await withTaskGroup(of: PackageDiskUsage?.self) { group in
            for (name, type, root) in inputs {
                group.addTask {
                    guard let root else { return nil }
                    let directory = root.appendingPathComponent(name, isDirectory: true)
                    guard FileManager.default.fileExists(atPath: directory.path) else {
                        return PackageDiskUsage(name: name, type: type, bytes: 0)
                    }
                    return PackageDiskUsage(
                        name: name,
                        type: type,
                        bytes: DirectorySize.bytes(at: directory)
                    )
                }
            }

            var results: [PackageDiskUsage] = []
            for await usage in group {
                if let usage {
                    results.append(usage)
                }
            }
            return results
        }
    }
}

// MARK: - Cask recovery

extension HomebrewService {
    /// Arguments for repairing a cask whose application was deleted outside
    /// Homebrew. `--force` is what makes both paths work in that state: it tells
    /// Homebrew to ignore errors while removing files that are already gone.
    static func recoveryArguments(action: CaskRecoveryAction, cask: String) -> [String] {
        switch action {
        case .forget:
            return ["uninstall", "--cask", "--force", cask]
        case .reinstall:
            return ["reinstall", "--cask", "--force", cask]
        }
    }

    /// Drops Homebrew's record of a cask without needing its files to exist.
    func forgetCask(
        _ cask: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([cask])
        return try await runCommand(
            arguments: Self.recoveryArguments(action: .forget, cask: cask),
            stream: stream
        )
    }

    /// Downloads the cask again and puts the application back in place.
    func reinstallMissingCask(
        _ cask: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([cask])
        return try await runCommand(
            arguments: Self.recoveryArguments(action: .reinstall, cask: cask),
            stream: stream
        )
    }

    /// Cross-checks every installed cask against the artifacts Homebrew staged
    /// for it, so stale records can be surfaced before an upgrade trips over
    /// them. An empty version directory means the application it was tracking
    /// is gone.
    func staleCasks() async throws -> [StaleCask] {
        let casks = try await listInstalledPackages(type: .cask)
        guard !casks.isEmpty else { return [] }

        let caskroom = try await caskroomDirectory()
        let fileManager = FileManager.default

        return casks.compactMap { cask in
            let caskDirectory = caskroom.appendingPathComponent(cask.name, isDirectory: true)

            let versions = cask.installedVersions.isEmpty
                ? (try? fileManager.contentsOfDirectory(atPath: caskDirectory.path)) ?? []
                : cask.installedVersions

            guard !versions.isEmpty else { return nil }

            // Stale only when *every* staged version directory is empty: a cask
            // with any artifact left is still usable.
            let allEmpty = versions.allSatisfy { version in
                let path = caskDirectory.appendingPathComponent(version, isDirectory: true).path
                guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
                    return false
                }
                return contents.allSatisfy { $0 == ".metadata" }
            }

            return allEmpty ? StaleCask(name: cask.name, missingPath: nil) : nil
        }
    }
}
