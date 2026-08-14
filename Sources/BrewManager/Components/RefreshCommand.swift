import SwiftUI

/// Lets any section view respond to the global "Refresh Current Section"
/// command (⌘R) without the menu needing to know which section is on screen.
///
/// Only the visible section reacts in practice: off-screen detail views are
/// torn down by `NavigationSplitView`, so their subscriptions go with them.
extension View {
    func onRefreshCommand(_ action: @escaping () async -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .brewManagerRefresh)) { _ in
            Task { await action() }
        }
    }
}
