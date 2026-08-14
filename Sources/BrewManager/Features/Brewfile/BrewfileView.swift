import SwiftUI

struct BrewfileView: View {
    @State private var viewModel: BrewfileViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: BrewfileViewModel(
                homebrewService: appState.homebrewService,
                appState: appState
            )
        )
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconTile(systemImage: "doc.text", color: Theme.Palette.cask, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Brewfile")
                        .font(.title2.bold())
                    Text("Export, check, and apply Brewfiles with Homebrew Bundle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Brewfile path")
                    .font(.subheadline.weight(.semibold))
                TextField("~/Brewfile", text: $bindableViewModel.brewfilePath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.exportCurrentMachine() }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Palette.amberDeep)
                    .disabled(viewModel.isLoading)

                    Button {
                        Task { await viewModel.checkBrewfile() }
                    } label: {
                        Label("Check", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)

                    Button {
                        viewModel.requestApply()
                    } label: {
                        Label("Apply", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.Palette.info)
                    .disabled(viewModel.isLoading)

                    Spacer(minLength: 0)
                }
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(tint: Theme.Palette.cask)

            if let errorMessage = viewModel.errorMessage {
                MessageBanner(
                    severity: .failure,
                    headline: errorMessage,
                    onDismiss: { viewModel.errorMessage = nil }
                )
            } else if let statusMessage = viewModel.statusMessage {
                MessageBanner(
                    severity: .success,
                    headline: statusMessage,
                    onDismiss: { viewModel.statusMessage = nil }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
        .alert(
            "Apply Brewfile?",
            isPresented: pendingApplyBinding,
            presenting: bindableViewModel.pendingApply
        ) { pending in
            Button("Run Bundle") {
                Task {
                    await viewModel.applyRequestedBrewfile()
                }
            }
            Button("Cancel", role: .cancel) {
                bindableViewModel.pendingApply = nil
            }
        } message: { pending in
            Text("This will apply package changes from \(pending.pathDescription).")
        }
    }

    private var pendingApplyBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingApply != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingApply = nil
                }
            }
        )
    }
}
