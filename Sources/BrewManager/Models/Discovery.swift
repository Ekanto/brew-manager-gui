import Foundation

/// A package returned by `brew search`, which may or may not be installed.
struct CatalogPackage: Identifiable, Hashable, Sendable {
    let name: String
    let type: PackageType
    var isInstalled: Bool = false

    var id: String { "\(type.rawValue):\(name)" }
}

/// A third-party repository added with `brew tap`.
struct TapInfo: Identifiable, Hashable, Sendable {
    let name: String

    var id: String { name }

    /// Homebrew's own taps should not be offered for removal.
    var isOfficial: Bool {
        name.hasPrefix("homebrew/")
    }

    var owner: String {
        name.split(separator: "/").first.map(String.init) ?? name
    }

    var repository: String {
        let components = name.split(separator: "/")
        return components.count > 1 ? String(components[1]) : name
    }
}

/// Packages that depend on a given package. Uninstalling a package with
/// dependents will break them, so this drives a warning in the confirmation.
struct DependencyReport: Sendable {
    let package: String
    let dependents: [String]

    var hasDependents: Bool { !dependents.isEmpty }

    var summary: String {
        guard hasDependents else {
            return "Nothing else depends on \(package)."
        }

        let list = dependents.prefix(5).joined(separator: ", ")
        if dependents.count > 5 {
            return "\(dependents.count) installed packages depend on \(package), including \(list)."
        }
        return dependents.count == 1
            ? "\(list) depends on \(package)."
            : "\(list) depend on \(package)."
    }
}

/// On-disk size of an installed package.
struct PackageDiskUsage: Sendable, Hashable {
    let name: String
    let type: PackageType
    let bytes: Int64

    var formatted: String {
        DirectorySize.formatted(bytes: bytes)
    }
}
