import SwiftUI

struct TapsView: View {
    @State private var viewModel: TapsViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: TapsViewModel(
                homebrewService: appState.homebrewService,
                appState: appState
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                addTapCard

                if let errorMessage = viewModel.errorMessage {
                    MessageBanner(
                        severity: .failure,
                        headline: errorMessage,
                        onDismiss: { viewModel.errorMessage = nil }
                    )
                }

                if viewModel.isLoading && viewModel.taps.isEmpty {
                    ProgressView("Loading taps…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if viewModel.taps.isEmpty {
                    EmptyStateView(
                        title: "No Taps",
                        message: "Add a third-party Homebrew repository to make its formulae and casks available.",
                        systemImage: "arrow.triangle.branch",
                        tint: Theme.Palette.info
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.taps) { tap in
                            tapCard(for: tap)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
        .task {
            await viewModel.refresh()
        }
        .onRefreshCommand {
            await viewModel.refresh()
        }
        .alert(
            viewModel.pendingRemoval.map { "Remove \($0.name)?" } ?? "",
            isPresented: pendingRemovalBinding,
            presenting: viewModel.pendingRemoval
        ) { tap in
            Button("Remove Tap", role: .destructive) {
                Task {
                    await viewModel.remove(tap)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingRemoval = nil
            }
        } message: { tap in
            Text("Packages installed from \(tap.name) may no longer be updatable.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: "arrow.triangle.branch", color: Theme.Palette.info, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("Taps")
                    .font(.title2.bold())
                Text("Manage extra Homebrew package repositories for third-party formulae and casks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var addTapCard: some View {
        @Bindable var viewModel = viewModel

        return HStack(spacing: 10) {
            IconTile(systemImage: "plus", color: Theme.Palette.formula, size: 32)

            TextField("owner/repository", text: $viewModel.newTapName)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .disabled(viewModel.isLoading)
                .onSubmit {
                    Task {
                        await viewModel.addTap()
                    }
                }

            Button {
                Task {
                    await viewModel.addTap()
                }
            } label: {
                Label("Add Tap", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.formula)
            .disabled(
                viewModel.newTapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isLoading
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(tint: Theme.Palette.formula)
    }

    private func tapCard(for tap: TapInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            IconTile(
                systemImage: tap.isOfficial ? "checkmark.seal.fill" : "shippingbox.fill",
                color: tap.isOfficial ? Theme.Palette.amberDeep : Theme.Palette.cask,
                size: 34
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(tap.owner)
                        .font(.headline)
                    Text("/")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(tap.repository)
                        .font(.headline.weight(.semibold))

                    if tap.isOfficial {
                        Chip(
                            text: "Official",
                            color: Theme.Palette.amberDeep,
                            systemImage: "checkmark.seal.fill"
                        )
                    }
                }

                Text(tap.name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            if !tap.isOfficial {
                Button("Remove", role: .destructive) {
                    viewModel.requestRemoval(tap)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Palette.danger)
                .disabled(viewModel.isLoading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(tint: tap.isOfficial ? Theme.Palette.amberDeep : Theme.Palette.cask)
    }

    private var pendingRemovalBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingRemoval = nil
                }
            }
        )
    }
}
