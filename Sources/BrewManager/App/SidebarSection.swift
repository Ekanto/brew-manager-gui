import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard
    case packages
    case discover
    case updates
    case services
    case taps
    case brewfile
    case issues
    case maintenance
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .packages:
            return "Packages"
        case .discover:
            return "Discover"
        case .updates:
            return "Updates"
        case .services:
            return "Services"
        case .taps:
            return "Taps"
        case .brewfile:
            return "Brewfile"
        case .issues:
            return "Issues"
        case .maintenance:
            return "Maintenance"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "rectangle.grid.2x2"
        case .packages:
            return "shippingbox"
        case .discover:
            return "sparkle.magnifyingglass"
        case .updates:
            return "arrow.triangle.2.circlepath"
        case .services:
            return "bolt.horizontal.circle"
        case .taps:
            return "arrow.triangle.branch"
        case .brewfile:
            return "doc.text"
        case .issues:
            return "exclamationmark.triangle"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .history:
            return "clock.arrow.circlepath"
        case .settings:
            return "gear"
        }
    }
}
