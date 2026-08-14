import Foundation

actor HomebrewService {
    private let processRunner: ProcessRunning
    private let brewLocator: BrewLocating
    private var brewExecutable: URL?

    /// Mutating commands run one at a time; see `OperationGate`.
    private let gate = OperationGate()
    private let readCache = TTLCache<[String]>(lifetime: 90)

    init(
        processRunner: ProcessRunning = ProcessRunner(),
        brewLocator: BrewLocating = BrewLocator()
    ) {
        self.processRunner = processRunner
        self.brewLocator = brewLocator
    }

    /// True while a mutating command holds the exclusive gate.
    func isMutating() async -> Bool {
        await gate.isRunning
    }

    func discoveredExecutable() throws -> URL {
        if let brewExecutable {
            return brewExecutable
        }

        let located = try brewLocator.locate()
        brewExecutable = located
        AppLogger.brew.info("Resolved brew executable: \(located.path, privacy: .public)")
        return located
    }

    func commandString(arguments: [String]) throws -> String {
        let executable = try discoveredExecutable()
        return ([executable.path] + arguments).joined(separator: " ")
    }

    func brewVersion() async throws -> String {
        let result = try await runCommand(arguments: ["--version"])
        try requireSuccess(result: result, arguments: ["--version"])

        return result.stdout
            .split(separator: "\n")
            .first
            .map(String.init) ?? "Unknown"
    }

    func brewPrefix() async throws -> String {
        let result = try await runCommand(arguments: ["--prefix"])
        try requireSuccess(result: result, arguments: ["--prefix"])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func brewConfig() async throws -> String {
        let result = try await runCommand(arguments: ["config"])
        try requireSuccess(result: result, arguments: ["config"])
        return result.stdout
    }

    func listInstalledPackages(type: PackageType) async throws -> [BrewPackage] {
        let arguments: [String]
        switch type {
        case .formula:
            arguments = ["list", "--formula", "--versions"]
        case .cask:
            arguments = ["list", "--cask", "--versions"]
        }

        let result = try await runCommand(arguments: arguments)
        try requireSuccess(result: result, arguments: arguments)

        return parseInstalledPackageList(result.stdout, type: type)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func outdatedPackages() async throws -> [OutdatedPackage] {
        try await outdatedPackages(greedy: false)
    }

    func packageDetails(named name: String) async throws -> BrewPackage {
        try InputValidation.validatePackageNames([name])

        let arguments = ["info", "--json=v2", name]
        let result = try await runCommand(arguments: arguments)
        try requireSuccess(result: result, arguments: arguments)

        return try BrewJSONDecoder.decodePackageInfo(
            from: Data(result.stdout.utf8),
            fallbackName: name
        )
    }

    func servicesList() async throws -> [BrewServiceInfo] {
        let arguments = ["services", "list", "--json"]
        let result = try await runCommand(arguments: arguments)
        try requireSuccess(result: result, arguments: arguments)

        return try BrewJSONDecoder.decodeServices(from: Data(result.stdout.utf8))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func dashboardInfo(greedy: Bool = false) async throws -> DashboardInfo {
        async let version = brewVersion()
        async let prefix = brewPrefix()
        async let formulae = listInstalledPackages(type: .formula)
        async let casks = listInstalledPackages(type: .cask)
        async let outdated = outdatedPackages(greedy: greedy)

        let (resolvedVersion, resolvedPrefix, resolvedFormulae, resolvedCasks, resolvedOutdated) = try await (
            version,
            prefix,
            formulae,
            casks,
            outdated
        )

        let outdatedFormulaCount = resolvedOutdated.filter { $0.type == .formula }.count
        let outdatedCaskCount = resolvedOutdated.filter { $0.type == .cask }.count

        return DashboardInfo(
            brewVersion: resolvedVersion,
            prefix: resolvedPrefix,
            formulaCount: resolvedFormulae.count,
            caskCount: resolvedCasks.count,
            outdatedFormulaCount: outdatedFormulaCount,
            outdatedCaskCount: outdatedCaskCount,
            lastChecked: Date()
        )
    }

    func updateMetadata(
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try await runCommand(arguments: ["update"], stream: stream)
    }

    func install(
        package: String,
        type: PackageType,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([package])

        var arguments = ["install"]
        if type == .cask {
            arguments.append("--cask")
        }
        arguments.append(package)

        return try await runCommand(arguments: arguments, stream: stream)
    }

    func upgrade(
        packages: [String],
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames(packages)
        return try await runCommand(arguments: ["upgrade"] + packages, stream: stream)
    }

    func reinstall(
        package: String,
        type: PackageType = .formula,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([package])
        return try await runCommand(
            arguments: Self.packageArguments(command: "reinstall", package: package, type: type),
            stream: stream
        )
    }

    func uninstall(
        package: String,
        type: PackageType = .formula,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([package])
        return try await runCommand(
            arguments: Self.packageArguments(command: "uninstall", package: package, type: type),
            stream: stream
        )
    }

    /// Casks must be addressed explicitly; otherwise Homebrew resolves the name
    /// against formulae first and fails or acts on the wrong package.
    static func packageArguments(
        command: String,
        package: String,
        type: PackageType
    ) -> [String] {
        var arguments = [command]
        if type == .cask {
            arguments.append("--cask")
        }
        arguments.append(package)
        return arguments
    }

    func pin(
        package: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([package])
        return try await runCommand(arguments: ["pin", package], stream: stream)
    }

    func unpin(
        package: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([package])
        return try await runCommand(arguments: ["unpin", package], stream: stream)
    }

    func startService(
        named service: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([service])
        return try await runCommand(arguments: ["services", "start", service], stream: stream)
    }

    func stopService(
        named service: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([service])
        return try await runCommand(arguments: ["services", "stop", service], stream: stream)
    }

    func restartService(
        named service: String,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames([service])
        return try await runCommand(arguments: ["services", "restart", service], stream: stream)
    }

    func exportBrewfile(
        fileURL: URL?,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        var arguments = ["bundle", "dump", "--force", "--describe"]
        if let fileURL {
            arguments.append(contentsOf: ["--file", fileURL.path])
        }
        return try await runCommand(arguments: arguments, stream: stream)
    }

    func checkBrewfile(
        fileURL: URL?,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        var arguments = ["bundle", "check"]
        if let fileURL {
            arguments.append(contentsOf: ["--file", fileURL.path])
        }
        return try await runCommand(arguments: arguments, stream: stream)
    }

    func applyBrewfile(
        fileURL: URL?,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        var arguments = ["bundle"]
        if let fileURL {
            arguments.append(contentsOf: ["--file", fileURL.path])
        }
        return try await runCommand(arguments: arguments, stream: stream)
    }

    func cleanup(
        dryRun: Bool,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        var arguments = ["cleanup"]
        if dryRun {
            arguments.append("--dry-run")
        }
        return try await runCommand(arguments: arguments, stream: stream)
    }

    static func cleanupArguments(scrub: Bool, dryRun: Bool) -> [String] {
        var arguments = ["cleanup", "--prune=all"]
        if scrub {
            arguments.append("--scrub")
        }
        if dryRun {
            arguments.append("--dry-run")
        }
        return arguments
    }

    /// `--prune=all` discards every cached download regardless of age;
    /// `--scrub` additionally removes caches for still-installed packages.
    func purgeCache(
        scrub: Bool,
        dryRun: Bool,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try await runCommand(
            arguments: Self.cleanupArguments(scrub: scrub, dryRun: dryRun),
            stream: stream
        )
    }

    static func autoremoveArguments(dryRun: Bool) -> [String] {
        dryRun ? ["autoremove", "--dry-run"] : ["autoremove"]
    }

    /// Removes formulae that were installed only as dependencies and are no
    /// longer required by anything.
    func autoremove(
        dryRun: Bool,
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try await runCommand(
            arguments: Self.autoremoveArguments(dryRun: dryRun),
            stream: stream
        )
    }

    func cacheDirectory() async throws -> URL {
        let arguments = ["--cache"]
        let result = try await runCommand(arguments: arguments)
        try requireSuccess(result: result, arguments: arguments)

        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw BrewError.commandFailed(
                command: try commandString(arguments: arguments),
                exitCode: result.exitCode,
                stderr: "brew --cache returned no path."
            )
        }
        return URL(fileURLWithPath: path)
    }

    /// Runs a remediation command that `brew doctor` itself printed. The
    /// arguments are re-validated here so a parsed suggestion can never widen
    /// into an arbitrary command.
    func runSuggestedFix(
        arguments: [String],
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try InputValidation.validatePackageNames(
            arguments.filter { !$0.hasPrefix("-") }
        )
        return try await runCommand(arguments: arguments, stream: stream)
    }

    func doctor(
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        try await runCommand(arguments: ["doctor"], stream: stream)
    }

    /// Subcommands that change state on disk. These are serialised; concurrent
    /// mutating brew processes fight over Homebrew's own locks.
    private static let mutatingSubcommands: Set<String> = [
        "install", "uninstall", "reinstall", "upgrade", "update",
        "pin", "unpin", "tap", "untap", "cleanup", "autoremove",
        "link", "unlink", "bundle", "services"
    ]

    /// Read-only invocations of otherwise-mutating subcommands.
    private static func isReadOnlyInvocation(_ arguments: [String]) -> Bool {
        guard let first = arguments.first else { return true }

        switch first {
        case "services":
            return arguments.dropFirst().first == "list"
        case "bundle":
            return arguments.dropFirst().first == "check"
        default:
            return arguments.contains("--dry-run")
        }
    }

    static func isMutating(arguments: [String]) -> Bool {
        guard let first = arguments.first else { return false }
        guard mutatingSubcommands.contains(first) else { return false }
        return !isReadOnlyInvocation(arguments)
    }

    /// Single choke point for every brew invocation. Mutating commands acquire
    /// the exclusive gate here rather than at each call site, so a new command
    /// cannot accidentally skip serialisation.
    func runCommand(
        arguments: [String],
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        guard Self.isMutating(arguments: arguments) else {
            return try await executeCommand(arguments: arguments, stream: stream)
        }

        return try await gate.withExclusiveAccess { [self] in
            let result = try await executeCommand(arguments: arguments, stream: stream)
            await readCache.removeAll()
            return result
        }
    }

    private func executeCommand(
        arguments: [String],
        stream: (@Sendable (ProcessEvent) -> Void)? = nil
    ) async throws -> ProcessResult {
        let executable = try discoveredExecutable()
        AppLogger.brew.info("Running brew command: \(arguments.joined(separator: " "), privacy: .public)")

        if let stream {
            return try await processRunner.runStreaming(
                executable: executable,
                arguments: arguments,
                onEvent: stream
            )
        }

        return try await processRunner.run(
            executable: executable,
            arguments: arguments
        )
    }

    private func parseInstalledPackageList(_ text: String, type: PackageType) -> [BrewPackage] {
        text.split(separator: "\n")
            .compactMap { line in
                let components = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard let name = components.first else {
                    return nil
                }

                let versions = Array(components.dropFirst())
                return BrewPackage(
                    name: name,
                    type: type,
                    installedVersions: versions,
                    currentVersion: versions.last,
                    latestVersion: nil,
                    packageDescription: nil,
                    homepage: nil,
                    tap: nil,
                    isPinned: false
                )
            }
    }

    private func requireSuccess(
        result: ProcessResult,
        arguments: [String]
    ) throws {
        guard result.exitCode == 0 else {
            let command = try commandString(arguments: arguments)
            throw BrewError.classify(
                command: command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }
}
