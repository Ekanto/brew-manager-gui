import SwiftUI

struct PackageRowView: View {
    let package: BrewPackage
    var formattedSize: String?

    var body: some View {
        HStack(spacing: 10) {
            IconTile(
                systemImage: package.type == .cask ? "macwindow" : "terminal",
                color: package.type == .cask ? Theme.Palette.cask : Theme.Palette.formula,
                size: 26
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(package.name)
                    .font(.headline)

                if let description = package.packageDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Chip(
                        text: package.type.displayName,
                        color: package.type == .cask ? Theme.Palette.cask : Theme.Palette.formula
                    )

                    if let tap = package.tap, !tap.isEmpty {
                        Text(tap)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            if let formattedSize {
                Chip(text: formattedSize, color: Theme.Palette.info, systemImage: "internaldrive")
            }

            Text(package.displayedInstalledVersion)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.5), in: Capsule())
        }
        .padding(.vertical, 5)
    }
}
