import SwiftUI

extension SidebarSection {
    var tint: Color {
        switch self {
        case .dashboard:
            return Theme.Palette.amber
        case .packages:
            return Theme.Palette.formula
        case .discover:
            return Color(red: 0.94, green: 0.45, blue: 0.62)
        case .updates:
            return Theme.Palette.info
        case .services:
            return Theme.Palette.cask
        case .taps:
            return Color(red: 0.36, green: 0.72, blue: 0.78)
        case .brewfile:
            return Color(red: 0.36, green: 0.72, blue: 0.78)
        case .maintenance:
            return Theme.Palette.amberDeep
        case .history:
            return Color(red: 0.60, green: 0.62, blue: 0.70)
        case .settings:
            return Color(red: 0.50, green: 0.55, blue: 0.62)
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return "Health and counts"
        case .packages:
            return "Installed software"
        case .discover:
            return "Search the catalog"
        case .updates:
            return "Outdated packages"
        case .services:
            return "Background daemons"
        case .taps:
            return "Extra repositories"
        case .brewfile:
            return "Export and apply"
        case .maintenance:
            return "Clean and diagnose"
        case .history:
            return "Past operations"
        case .settings:
            return "Preferences"
        }
    }
}
