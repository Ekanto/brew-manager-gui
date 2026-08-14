import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: DashboardViewModel(
                homebrewService: appState.homebrewService,
                preferences: appState.preferences
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let errorMessage = viewModel.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Palette.danger)
                        Text(errorMessage)
                            .font(.callout)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                    .card(tint: Theme.Palette.danger, padding: 12)
                }

                if viewModel.isLoading && viewModel.info == nil {
                    ProgressView("Loading Homebrew status…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if let info = viewModel.info {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 240), spacing: 14)
                    ], spacing: 14) {
                        statCard(
                            title: "Homebrew",
                            value: Self.shortVersion(info.brewVersion),
                            subtitle: info.prefix,
                            systemImage: "mug.fill",
                            color: Theme.Palette.amber
                        )

                        statCard(
                            title: "Installed",
                            value: "\(info.formulaCount + info.caskCount)",
                            subtitle: "packages in total",
                            systemImage: "shippingbox.fill",
                            color: Theme.Palette.formula,
                            chips: [
                                Chip(text: "\(info.formulaCount) formulae", color: Theme.Palette.formula),
                                Chip(text: "\(info.caskCount) casks", color: Theme.Palette.cask)
                            ]
                        )

                        statCard(
                            title: "Updates",
                            value: "\(info.outdatedFormulaCount + info.outdatedCaskCount)",
                            subtitle: outdatedSubtitle(info),
                            systemImage: outdatedTotal(info) == 0
                                ? "checkmark.seal.fill"
                                : "arrow.up.circle.fill",
                            color: outdatedTotal(info) == 0
                                ? Theme.Palette.success
                                : Theme.Palette.warning,
                            chips: outdatedTotal(info) == 0
                                ? []
                                : [
                                    Chip(text: "\(info.outdatedFormulaCount) formulae", color: Theme.Palette.warning),
                                    Chip(text: "\(info.outdatedCaskCount) casks", color: Theme.Palette.warning)
                                ]
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text("Last checked \(info.lastChecked.formatted(date: .omitted, time: .shortened))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    EmptyStateView(
                        title: "No Dashboard Data",
                        message: "Run refresh to query Homebrew health and package counts.",
                        systemImage: "rectangle.grid.2x2"
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onRefreshCommand {
            await viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            IconTile(systemImage: "rectangle.grid.2x2.fill", color: Theme.Palette.amber, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Overview")
                    .font(.title2.bold())
                Text("Your Homebrew installation at a glance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r")
            .disabled(viewModel.isLoading)
        }
    }

    private func outdatedTotal(_ info: DashboardInfo) -> Int {
        info.outdatedFormulaCount + info.outdatedCaskCount
    }

    private func outdatedSubtitle(_ info: DashboardInfo) -> String {
        outdatedTotal(info) == 0 ? "everything is up to date" : "packages can be upgraded"
    }

    /// `brew --version` returns a multi-word string; the card only has room
    /// for the number itself.
    static func shortVersion(_ raw: String) -> String {
        raw.replacingOccurrences(of: "Homebrew ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func statCard(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        chips: [Chip] = []
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconTile(systemImage: systemImage, color: color, size: 30)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.gradient(for: color))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !chips.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        chip
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .card(tint: color)
    }
}
