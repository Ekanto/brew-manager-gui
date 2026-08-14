import Foundation
import OSLog

enum AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.umarekanto.BrewManager"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let brew = Logger(subsystem: subsystem, category: "homebrew")
    static let process = Logger(subsystem: subsystem, category: "process")
}
