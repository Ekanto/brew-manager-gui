import SwiftUI

struct UpdatesView: View {
    @State private var viewModel: UpdatesViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: UpdatesViewModel(
                homebrewService: appState.homebrewService,
                appState: appState
            )
        )
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                IconTile(
                    systemImage: viewModel.outdatedPackages.isEmpty
                        ? "checkmark.seal.fill"
                        : "arrow.up.circle.fill",
                    color: viewModel.outdatedPackages.isEmpty
                        ? Theme.Palette.success
                        : Theme.Palette.info,
                    size: 38
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.outdatedPackages.isEmpty
                        ? "Everything is up to date"
                        : "\(viewModel.outdatedPackages.count) updates available")
                        .font(.title2.bold())

                    if let lastMetadataUpdate = viewModel.lastMetadataUpdate {
                        Text("Metadata refreshed \(lastMetadataUpdate.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Fetch the latest Homebrew metadata to check for new versions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.updateMetadataAndRefresh()
                    }
                } label: {
                    Label("Update Metadata", systemImage: "arrow.down.circle")
                }

                Button {
                    Task {
                        await viewModel.refreshOutdated()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            HStack(spacing: 8) {
                Button("Select All", action: viewModel.selectAll)
                    .disabled(viewModel.outdatedPackages.isEmpty)
                Button("Clear", action: viewModel.clearSelection)
                    .disabled(viewModel.selectedPackageIDs.isEmpty)

                Spacer()

                Button {
                    viewModel.requestUpgradeSelected()
                } label: {
                    Label("Upgrade Selected", systemImage: "arrow.up.square")
                }
                .disabled(viewModel.selectedPackageIDs.isEmpty)

                Button {
                    viewModel.requestUpgradeAll()
                } label: {
                    Label("Upgrade All", systemImage: "arrow.up.square.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.outdatedPackages.isEmpty)
            }

            if !viewModel.staleCasks.isEmpty {
                StaleCaskCard(
                    casks: viewModel.staleCasks,
                    isBusy: viewModel.isRecovering
                ) { action in
                    viewModel.requestRecovery(action)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            } else if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if viewModel.isLoading && viewModel.outdatedPackages.isEmpty {
                ProgressView("Checking for updates…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.outdatedPackages.isEmpty {
                EmptyStateView(
                    title: "No Updates Available",
                    message: "Your installed Homebrew packages are up to date.",
                    systemImage: "checkmark.seal",
                    tint: Theme.Palette.success
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !viewModel.outdatedFormulae.isEmpty {
                        Section("Formulae (\(viewModel.outdatedFormulae.count))") {
                            ForEach(viewModel.outdatedFormulae) { package in
                                updateRow(for: package)
                            }
                        }
                    }

                    if !viewModel.outdatedCasks.isEmpty {
                        Section("Casks (\(viewModel.outdatedCasks.count))") {
                            ForEach(viewModel.outdatedCasks) { package in
                                updateRow(for: package)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onRefreshCommand {
            await viewModel.refreshOutdated()
        }
        .alert(
            bindableViewModel.pendingUpgrade?.title ?? "",
            isPresented: pendingUpgradeBinding,
            presenting: bindableViewModel.pendingUpgrade
        ) { pending in
            Button("Run Upgrade") {
                Task {
                    await viewModel.execute(pending)
                }
            }
            Button("Cancel", role: .cancel) {
                bindableViewModel.pendingUpgrade = nil
            }
        } message: { pending in
            Text(pending.message)
        }
        .alert(
            bindableViewModel.pendingRecovery?.title ?? "",
            isPresented: pendingRecoveryBinding,
            presenting: bindableViewModel.pendingRecovery
        ) { pending in
            Button(
                pending.action.title,
                role: pending.action.isDestructive ? .destructive : nil
            ) {
                Task {
                    await viewModel.performRecovery(pending)
                }
            }
            Button("Cancel", role: .cancel) {
                bindableViewModel.pendingRecovery = nil
            }
        } message: { pending in
            Text(pending.message)
        }
    }

    private func updateRow(for package: OutdatedPackage) -> some View {
        let isSelectedBinding = Binding(
            get: { viewModel.selectedPackageIDs.contains(package.id) },
            set: { selected in
                viewModel.toggleSelection(for: package, selected: selected)
            }
        )

        return Toggle(isOn: isSelectedBinding) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(package.name)
                        .font(.body.weight(.medium))
                    Chip(
                        text: package.type.displayName,
                        color: package.type == .cask ? Theme.Palette.cask : Theme.Palette.formula
                    )
                }

                Spacer()

                HStack(spacing: 6) {
                    Text(package.installedVersion)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.5), in: Capsule())

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(package.latestVersion)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.Palette.success)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.Palette.success.opacity(0.15), in: Capsule())
                }
            }
            .padding(.vertical, 3)
        }
        .toggleStyle(.checkbox)
    }

    private var pendingRecoveryBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingRecovery != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingRecovery = nil
                }
            }
        )
    }

    private var pendingUpgradeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingUpgrade != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingUpgrade = nil
                }
            }
        )
    }
}
