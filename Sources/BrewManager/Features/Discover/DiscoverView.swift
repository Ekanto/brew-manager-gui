import SwiftUI

struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: DiscoverViewModel(
                homebrewService: appState.homebrewService,
                appState: appState
            )
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search Homebrew catalog", text: searchTextBinding)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await viewModel.searchNow()
                        }
                    }

                Picker("Type", selection: selectedTypeBinding) {
                    Text("All").tag(PackageType?.none)
                    Text("Formulae").tag(PackageType?.some(.formula))
                    Text("Casks").tag(PackageType?.some(.cask))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)

                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task {
                        await viewModel.searchNow()
                    }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(isQueryEmpty || viewModel.isSearching)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
        .alert(
            viewModel.pendingInstall.map { "Install \($0.name)?" } ?? "",
            isPresented: pendingInstallBinding,
            presenting: viewModel.pendingInstall
        ) { package in
            Button("Install") {
                Task {
                    await viewModel.install(package)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingInstall = nil
            }
        } message: { package in
            Text("Homebrew will install \(package.name) as a \(package.type.displayName.lowercased()). Required dependencies may also be installed.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isQueryEmpty {
            EmptyStateView(
                title: "Search Homebrew",
                message: "Find formulae and casks in the Homebrew catalog, then install them from here.",
                systemImage: "magnifyingglass",
                tint: Theme.Palette.info
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isSearching && viewModel.results.isEmpty {
            ProgressView("Searching Homebrew…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.results.isEmpty {
            EmptyStateView(
                title: "No Matches",
                message: "No Homebrew packages match “\(trimmedQuery)”.",
                systemImage: "magnifyingglass",
                tint: Theme.Palette.warning
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                List(viewModel.results, selection: selectedPackageIDBinding) { package in
                    DiscoverResultRow(package: package)
                        .tag(package.id)
                }
                .frame(minWidth: 320, maxHeight: .infinity)

                if let selectedPackage = viewModel.selectedPackage {
                    DiscoverDetailPane(
                        package: selectedPackage,
                        detail: viewModel.detail,
                        isLoadingDetail: viewModel.isLoadingDetail,
                        onInstall: {
                            viewModel.requestInstall(selectedPackage)
                        }
                    )
                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyStateView(
                        title: "Select a Package",
                        message: "Choose a formula or cask to view details and install it.",
                        systemImage: "info.circle",
                        tint: Theme.Palette.info
                    )
                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { newValue in
                viewModel.searchText = newValue
                viewModel.searchDebounced()
            }
        )
    }

    private var selectedTypeBinding: Binding<PackageType?> {
        Binding(
            get: { viewModel.selectedType },
            set: { newValue in
                viewModel.selectedType = newValue
                viewModel.searchDebounced()
            }
        )
    }

    private var selectedPackageIDBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedPackage?.id },
            set: { selectedID in
                viewModel.selectedPackage = selectedID.flatMap { id in
                    viewModel.results.first(where: { $0.id == id })
                }
            }
        )
    }

    private var pendingInstallBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingInstall != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingInstall = nil
                }
            }
        )
    }

    private var trimmedQuery: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isQueryEmpty: Bool {
        trimmedQuery.isEmpty
    }
}

private struct DiscoverResultRow: View {
    let package: CatalogPackage

    var body: some View {
        HStack(spacing: 10) {
            IconTile(systemImage: package.systemImage, color: package.tint, size: 26)

            VStack(alignment: .leading, spacing: 5) {
                Text(package.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    Chip(text: package.type.displayName, color: package.tint)

                    if package.isInstalled {
                        Chip(
                            text: "Installed",
                            color: Theme.Palette.success,
                            systemImage: "checkmark.circle.fill"
                        )
                    }
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 5)
    }
}

private struct DiscoverDetailPane: View {
    let package: CatalogPackage
    let detail: BrewPackage?
    let isLoadingDetail: Bool
    let onInstall: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconTile(systemImage: package.systemImage, color: package.tint, size: 40)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(detail?.name ?? package.name)
                            .font(.title2.bold())

                        HStack(spacing: 6) {
                            Chip(text: package.type.displayName, color: package.tint)

                            if package.isInstalled {
                                Chip(
                                    text: "Installed",
                                    color: Theme.Palette.success,
                                    systemImage: "checkmark.circle.fill"
                                )
                            }
                        }
                    }

                    Spacer()

                    if isLoadingDetail {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Description", systemImage: "text.alignleft", color: Theme.Palette.amberDeep)

                    if let description = detail?.packageDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if isLoadingDetail {
                        Text("Loading package details…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No description available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.amberDeep)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Package", systemImage: "shippingbox", color: Theme.Palette.info)
                    packageField("Latest", detail?.latestVersion ?? "Unknown")

                    if let tap = detail?.tap, !tap.isEmpty {
                        packageField("Tap", tap)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tint: Theme.Palette.info)

                if let homepage = detail?.homepage {
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
                    .card(tint: Theme.Palette.cask)
                }

                HStack {
                    Spacer()

                    if package.isInstalled {
                        Button {
                        } label: {
                            Label("Already installed", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(true)
                    } else {
                        Button(action: onInstall) {
                            Label("Install", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(package.tint)
                    }
                }
                .controlSize(.large)
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

private extension CatalogPackage {
    var tint: Color {
        type == .cask ? Theme.Palette.cask : Theme.Palette.formula
    }

    var systemImage: String {
        type == .cask ? "macwindow" : "terminal"
    }
}
