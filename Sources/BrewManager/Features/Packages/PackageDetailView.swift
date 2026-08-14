import SwiftUI

struct PackageDetailView: View {
    let package: BrewPackage
    let isLoadingDetails: Bool
    let onRefreshDetails: () -> Void
    let onUpgrade: () -> Void
    let onReinstall: () -> Void
    let onUninstall: () -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconTile(
                        systemImage: package.type == .cask ? "macwindow" : "terminal",
                        color: package.type == .cask ? Theme.Palette.cask : Theme.Palette.formula,
                        size: 40
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(package.name)
                            .font(.title2.bold())
                        HStack(spacing: 6) {
                            Chip(
                                text: package.type.displayName,
                                color: package.type == .cask ? Theme.Palette.cask : Theme.Palette.formula
                            )
                            if package.isPinned {
                                Chip(text: "Pinned", color: Theme.Palette.warning, systemImage: "pin.fill")
                            }
                        }
                    }

                    Spacer()

                    if isLoadingDetails {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        onRefreshDetails()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                    .help("Refresh details")
                }

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Versions", systemImage: "number", color: Theme.Palette.info)
                    packageField("Installed", package.displayedInstalledVersion)
                    packageField("Latest", package.latestVersion ?? "Unknown")
                    if let tap = package.tap, !tap.isEmpty {
                        packageField("Tap", tap)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.info)

                if let description = package.packageDescription, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Description", systemImage: "text.alignleft", color: Theme.Palette.amberDeep)
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                if let homepage = package.homepage {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Homepage", systemImage: "globe", color: Theme.Palette.cask)
                        Link(destination: homepage) {
                            HStack(spacing: 5) {
                                Text(homepage.absoluteString)
                                    .font(.subheadline)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                if !package.dependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(
                            "Dependencies (\(package.dependencies.count))",
                            systemImage: "shippingbox",
                            color: Theme.Palette.formula
                        )
                        FlowChips(items: package.dependencies, color: Theme.Palette.formula)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                HStack(spacing: 8) {
                    Button(action: onUpgrade) {
                        Label("Upgrade", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Palette.amberDeep)

                    Button(action: onReinstall) {
                        Label("Reinstall", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)

                    if package.isPinned {
                        Button(action: onUnpin) {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: onPin) {
                            Label("Pin", systemImage: "pin")
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(role: .destructive, action: onUninstall) {
                        Label("Uninstall", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.Palette.danger)
                }
                .controlSize(.large)
                .padding(.top, 2)
            }
            .padding(16)
        }
    }

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func packageField(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .textSelection(.enabled)
        }
    }
}

/// Wraps chips onto multiple lines so long dependency lists stay readable.
struct FlowChips: View {
    let items: [String]
    var color: Color = .secondary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { Chip(text: $0, color: color) }
            }
            rows
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(chunked.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { Chip(text: $0, color: color) }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var chunked: [[String]] {
        stride(from: 0, to: items.count, by: 4).map {
            Array(items[$0..<min($0 + 4, items.count)])
        }
    }
}
