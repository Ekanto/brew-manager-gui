import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private let homebrewService: HomebrewService
    private let preferences: Preferences

    var info: DashboardInfo?
    var isLoading = false
    var errorMessage: String?

    private var hasLoaded = false

    init(homebrewService: HomebrewService, preferences: Preferences) {
        self.homebrewService = homebrewService
        self.preferences = preferences
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            info = try await homebrewService.dashboardInfo(
                greedy: preferences.includeGreedyCasks
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
