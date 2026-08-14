import Foundation

enum BrewJSONDecoder {
    private static let decoder = JSONDecoder()

    static func decodeOutdated(from data: Data) throws -> [OutdatedPackage] {
        do {
            let root = try decoder.decode(OutdatedRoot.self, from: data)

            let formulae = root.formulae.map {
                OutdatedPackage(
                    name: $0.name,
                    type: .formula,
                    installedVersion: $0.installedVersions.values.first ?? "Unknown",
                    latestVersion: $0.currentVersion ?? "Unknown",
                    isPinned: $0.pinned ?? false
                )
            }

            let casks = root.casks.map {
                OutdatedPackage(
                    name: $0.name,
                    type: .cask,
                    installedVersion: $0.installedVersions.values.first ?? $0.installedVersion ?? "Unknown",
                    latestVersion: $0.currentVersion ?? "Unknown",
                    isPinned: $0.pinned ?? false
                )
            }

            return formulae + casks
        } catch {
            throw BrewError.invalidJSON(details: error.localizedDescription)
        }
    }

    static func decodePackageInfo(from data: Data, fallbackName: String) throws -> BrewPackage {
        do {
            let root = try decoder.decode(PackageInfoRoot.self, from: data)

            if let formula = root.formulae.first {
                let installedVersions = formula.installed.map(\.version)
                let currentVersion = installedVersions.last
                let latestVersion = formula.versions?.stable

                return BrewPackage(
                    name: formula.name,
                    type: .formula,
                    installedVersions: installedVersions,
                    currentVersion: currentVersion,
                    latestVersion: latestVersion,
                    packageDescription: formula.desc,
                    homepage: formula.homepage.flatMap(URL.init(string:)),
                    tap: formula.tappedFrom,
                    isPinned: formula.pinned ?? false,
                    dependencies: formula.dependencies ?? [],
                    dependents: formula.installedOnRequest == true ? [] : []
                )
            }

            if let cask = root.casks.first {
                let installedVersions = cask.installed.values
                let caskName = cask.token ?? cask.fullToken ?? fallbackName

                return BrewPackage(
                    name: caskName,
                    type: .cask,
                    installedVersions: installedVersions,
                    currentVersion: installedVersions.last,
                    latestVersion: cask.version,
                    packageDescription: cask.desc ?? cask.name?.first,
                    homepage: cask.homepage.flatMap(URL.init(string:)),
                    tap: cask.tap,
                    isPinned: false,
                    dependencies: [],
                    dependents: []
                )
            }

            throw BrewError.invalidJSON(details: "No formula or cask entries in brew info output.")
        } catch let error as BrewError {
            throw error
        } catch {
            throw BrewError.invalidJSON(details: error.localizedDescription)
        }
    }

    static func decodeServices(from data: Data) throws -> [BrewServiceInfo] {
        do {
            let services = try decoder.decode([RawService].self, from: data)
            return services.map {
                BrewServiceInfo(
                    name: $0.name,
                    status: ServiceStatus(rawStatus: $0.status),
                    user: $0.user,
                    file: $0.file,
                    plist: $0.plist,
                    exitCode: $0.exitCode
                )
            }
        } catch {
            throw BrewError.invalidJSON(details: error.localizedDescription)
        }
    }
}

private struct OutdatedRoot: Decodable {
    let formulae: [RawOutdatedFormula]
    let casks: [RawOutdatedCask]
}

private struct RawOutdatedFormula: Decodable {
    let name: String
    let installedVersions: StringList
    let currentVersion: String?
    let pinned: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
        case pinned
    }
}

private struct RawOutdatedCask: Decodable {
    let name: String
    let installedVersions: StringList
    let installedVersion: String?
    let currentVersion: String?
    let pinned: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case installedVersion = "installed_version"
        case currentVersion = "current_version"
        case pinned
    }
}

private struct PackageInfoRoot: Decodable {
    let formulae: [RawFormula]
    let casks: [RawCask]
}

private struct RawFormula: Decodable {
    let name: String
    let desc: String?
    let homepage: String?
    let tappedFrom: String?
    let pinned: Bool?
    let dependencies: [String]?
    let installedOnRequest: Bool?
    let versions: RawVersions?
    let installed: [RawInstalledVersion]

    enum CodingKeys: String, CodingKey {
        case name
        case desc
        case homepage
        case tappedFrom = "tap"
        case pinned
        case dependencies
        case installedOnRequest = "installed_on_request"
        case versions
        case installed
    }
}

private struct RawVersions: Decodable {
    let stable: String?
}

private struct RawInstalledVersion: Decodable {
    let version: String
}

private struct RawCask: Decodable {
    let token: String?
    let fullToken: String?
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?
    let installed: StringList
    let tap: String?

    enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case name
        case desc
        case homepage
        case version
        case installed
        case tap
    }
}

private struct RawService: Decodable {
    let name: String
    let status: String
    let user: String?
    let file: String?
    let plist: String?
    let exitCode: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case user
        case file
        case plist
        case exitCode = "exit_code"
    }
}

private struct StringList: Decodable {
    let values: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let values = try? container.decode([String].self) {
            self.values = values
            return
        }

        if let value = try? container.decode(String.self) {
            self.values = [value]
            return
        }

        self.values = []
    }
}
