import SwiftUI

struct ChangelogView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Changelog.entries) { entry in
                        ChangelogEntryCard(entry: entry)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Text("Made with love by \(AppInfo.author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Close") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(18)
        }
        .frame(minWidth: 620, idealWidth: 720, minHeight: 560, idealHeight: 680)
        .background(Theme.canvas)
    }

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: "sparkles", color: Theme.Palette.amber, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text("What’s New in Brew Manager")
                    .font(.title2.bold())

                Text(AppInfo.displayVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(18)
    }
}

private struct ChangelogEntryCard: View {
    let entry: ChangelogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.title)
                    .font(.headline)

                Chip(text: "v\(entry.version)", color: tint)

                Spacer()

                Text(entry.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.highlights, id: \.self) { highlight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(tint)
                            .padding(.top, 2)

                        Text(highlight)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(tint: tint)
    }

    private var tint: Color {
        entry.version == AppInfo.version ? Theme.Palette.amber : Theme.Palette.info
    }
}
