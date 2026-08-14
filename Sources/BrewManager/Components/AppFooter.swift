import SwiftUI

/// Version and authorship credit pinned to the bottom of the sidebar.
struct AppFooter: View {
    var body: some View {
        VStack(spacing: 3) {
            Text(AppInfo.displayVersion)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                Text("Made with")
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.Palette.danger)
                Text("by \(AppInfo.author)")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .chromeBackground()
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppInfo.displayVersion). Made with love by \(AppInfo.author).")
    }
}
