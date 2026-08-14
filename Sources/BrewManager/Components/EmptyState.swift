import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var tint: Color = Theme.Palette.amberDeep

    var body: some View {
        VStack(spacing: 14) {
            IconTile(systemImage: systemImage, color: tint, size: 56)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
        .frame(maxWidth: 380)
        .card(tint: tint, padding: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
