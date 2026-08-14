import Foundation

extension Duration {
    var secondsValue: Double {
        let components = self.components
        return Double(components.seconds) + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
    }

    var conciseDisplay: String {
        String(format: "%.1fs", secondsValue)
    }
}
