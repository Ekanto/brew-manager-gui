import SwiftUI

struct HistoryView: View {
    let appState: AppState

    var body: some View {
        Group {
            if appState.history.isEmpty {
                EmptyStateView(
                    title: "No Operations Yet",
                    message: "Executed Homebrew commands will appear here.",
                    systemImage: "clock.arrow.circlepath",
                    tint: Theme.Palette.info
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.history) { entry in
                            historyRow(entry)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
    }

    private func historyRow(_ entry: OperationRecord) -> some View {
        let tint = entry.succeeded ? Theme.Palette.success : Theme.Palette.danger

        return HStack(alignment: .top, spacing: 12) {
            IconTile(
                systemImage: entry.succeeded ? "checkmark" : "xmark",
                color: tint,
                size: 30
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(.headline)
                    Spacer(minLength: 8)
                    Chip(text: entry.succeeded ? "Success" : "Failed", color: tint)
                }

                Text("$ \(entry.command)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Chip(
                        text: entry.endedAt.formatted(date: .abbreviated, time: .shortened),
                        color: .secondary,
                        systemImage: "calendar"
                    )
                    Chip(text: "Exit \(entry.exitCode)", color: .secondary)
                    Chip(text: entry.duration.conciseDisplay, color: .secondary, systemImage: "timer")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(tint: tint)
    }
}
