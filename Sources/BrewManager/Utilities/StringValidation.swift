import Foundation

enum InputValidation {
    static func validatePackageNames(_ names: [String]) throws {
        for name in names where !name.isValidBrewPackageName {
            throw BrewError.invalidPackageName(name)
        }
    }

    /// Search text is free-form, and is passed to `Process` as a discrete
    /// argument rather than through a shell, so quoting is not a concern.
    /// A leading dash would still be read by brew as a flag, and control
    /// characters have no business in a query.
    static func validateSearchQuery(_ query: String) throws {
        guard !query.hasPrefix("-") else {
            throw BrewError.invalidPackageName(query)
        }

        guard query.count <= 128 else {
            throw BrewError.invalidPackageName(query)
        }

        let hasControlCharacters = query.unicodeScalars.contains { scalar in
            CharacterSet.controlCharacters.contains(scalar) || scalar == "\n" || scalar == "\r"
        }

        guard !hasControlCharacters else {
            throw BrewError.invalidPackageName(query)
        }
    }

    /// Taps are always `owner/repository`. Anything else — especially a path
    /// fragment — is rejected outright.
    static func validateTapName(_ name: String) throws {
        guard name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil,
              !name.contains("..") else {
            throw BrewError.invalidPackageName(name)
        }
    }
}

extension String {
    var isValidBrewPackageName: Bool {
        range(of: #"^[A-Za-z0-9@._+\-/]+$"#, options: .regularExpression) != nil
    }

    var expandingTildePath: String {
        (self as NSString).expandingTildeInPath
    }
}
