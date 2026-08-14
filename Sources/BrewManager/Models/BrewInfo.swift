import Foundation

struct DashboardInfo: Sendable {
    let brewVersion: String
    let prefix: String
    let formulaCount: Int
    let caskCount: Int
    let outdatedFormulaCount: Int
    let outdatedCaskCount: Int
    let lastChecked: Date
}
