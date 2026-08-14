import Foundation

enum ServiceStatus: String, Codable, Sendable {
    case running
    case stopped
    case scheduled
    case error
    case unknown

    init(rawStatus: String) {
        let normalized = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("started") || normalized.contains("running") {
            self = .running
        } else if normalized.contains("scheduled") {
            self = .scheduled
        } else if normalized.contains("error") {
            self = .error
        } else if normalized.contains("stopped") || normalized.contains("none") {
            self = .stopped
        } else {
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .stopped:
            return "Stopped"
        case .scheduled:
            return "Scheduled"
        case .error:
            return "Error"
        case .unknown:
            return "Unknown"
        }
    }
}

struct BrewServiceInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let status: ServiceStatus
    let user: String?
    let file: String?
    let plist: String?
    let exitCode: Int?

    init(
        id: String? = nil,
        name: String,
        status: ServiceStatus,
        user: String? = nil,
        file: String? = nil,
        plist: String? = nil,
        exitCode: Int? = nil
    ) {
        self.id = id ?? name
        self.name = name
        self.status = status
        self.user = user
        self.file = file
        self.plist = plist
        self.exitCode = exitCode
    }

    var launchesAtLogin: Bool {
        guard let plist, !plist.isEmpty else {
            return false
        }
        return true
    }
}
