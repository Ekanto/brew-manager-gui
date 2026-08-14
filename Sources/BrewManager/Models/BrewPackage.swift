import Foundation

enum PackageType: String, CaseIterable, Codable, Sendable {
    case formula
    case cask

    var displayName: String {
        switch self {
        case .formula:
            return "Formula"
        case .cask:
            return "Cask"
        }
    }
}

struct BrewPackage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let type: PackageType
    let installedVersions: [String]
    let currentVersion: String?
    let latestVersion: String?
    let packageDescription: String?
    let homepage: URL?
    let tap: String?
    let isPinned: Bool
    let dependencies: [String]
    let dependents: [String]

    init(
        id: String? = nil,
        name: String,
        type: PackageType,
        installedVersions: [String] = [],
        currentVersion: String? = nil,
        latestVersion: String? = nil,
        packageDescription: String? = nil,
        homepage: URL? = nil,
        tap: String? = nil,
        isPinned: Bool = false,
        dependencies: [String] = [],
        dependents: [String] = []
    ) {
        self.id = id ?? "\(type.rawValue):\(name)"
        self.name = name
        self.type = type
        self.installedVersions = installedVersions
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.packageDescription = packageDescription
        self.homepage = homepage
        self.tap = tap
        self.isPinned = isPinned
        self.dependencies = dependencies
        self.dependents = dependents
    }

    var displayedInstalledVersion: String {
        currentVersion ?? installedVersions.first ?? "Unknown"
    }
}

struct OutdatedPackage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let type: PackageType
    let installedVersion: String
    let latestVersion: String
    let isPinned: Bool

    init(
        name: String,
        type: PackageType,
        installedVersion: String,
        latestVersion: String,
        isPinned: Bool = false
    ) {
        self.id = "\(type.rawValue):\(name)"
        self.name = name
        self.type = type
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.isPinned = isPinned
    }
}
