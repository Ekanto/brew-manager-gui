import Foundation

/// Bundle metadata for display in the UI.
///
/// The values come from the app bundle's `Info.plist`, with fallbacks so the
/// footer still renders sensibly when the binary is run directly (for example
/// via `swift run`), where no bundle metadata exists.
enum AppInfo {
    static let author = "Umar"

    static var version: String {
        bundleString("CFBundleShortVersionString") ?? "1.1"
    }

    static var build: String? {
        bundleString("CFBundleVersion")
    }

    /// "1.1 (1)" when a build number is available, otherwise just the version.
    static var displayVersion: String {
        guard let build, build != version else {
            return "Version \(version)"
        }
        return "Version \(version) (\(build))"
    }

    private static func bundleString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
