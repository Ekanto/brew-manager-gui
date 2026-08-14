import SwiftUI

struct PackagesView: View {
    @State private var viewModel: PackagesViewModel
    @State private var searchQuery: String = ""

    init(appState: AppState) {
        _viewModel = State(
            initialValue: PackagesViewModel(
                homebrewService: appState.homebrewService,
                appState: appState
            )
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search packages", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08))
                )

                Picker("Type", selection: selectedFilterBinding) {
                    ForEach(PackageListFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut("r")
                .help("Refresh installed packages")

                Button {
                    Task {
                        viewModel.sortBySize.toggle()
                        if viewModel.sortBySize, viewModel.diskUsage.isEmpty {
                            await viewModel.loadDiskUsage()
                        }
                    }
                } label: {
                    if viewModel.isLoadingDiskUsage {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Sort by size", systemImage: "internaldrive")
                            .labelStyle(.iconOnly)
                    }
                }
                .help(viewModel.sortBySize ? "Sorting by size — click to sort by name" : "Measure and sort by disk usage")
                .tint(viewModel.sortBySize ? Theme.Palette.amberDeep : nil)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Theme.Palette.formula)

                Picker("Install Type", selection: installPackageTypeBinding) {
                    Text("Formula").tag(PackageType.formula)
                    Text("Cask").tag(PackageType.cask)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)

                TextField("Package to install", text: installPackageNameBinding)
                    .textFieldStyle(.roundedBorder)

                Button("Install") {
                    Task {
                        await viewModel.installPackageFromInput()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.formula)
                .disabled(viewModel.installPackageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))

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

            if viewModel.isLoading && viewModel.allPackages.isEmpty {
                ProgressView("Loading packages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedPackages.isEmpty {
                EmptyStateView(
                    title: hasActiveSearch ? "No Matches" : "No Packages",
                    message: hasActiveSearch
                        ? "No installed packages match “\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))”."
                        : "No installed packages match the current filter.",
                    systemImage: hasActiveSearch ? "magnifyingglass" : "shippingbox"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    List(
                        displayedPackages,
                        selection: selectedPackageIDBinding
                    ) { package in
                        PackageRowView(
                            package: package,
                            formattedSize: viewModel.formattedSize(for: package)
                        )
                            .tag(package.id)
                    }
                    .frame(minWidth: 320, maxHeight: .infinity)

                    if let selectedPackage = selectedDisplayedPackage {
                        PackageDetailView(
                            package: selectedPackage,
                            isLoadingDetails: viewModel.isLoadingDetails,
                            onRefreshDetails: {
                                Task {
                                    await viewModel.loadDetailsForSelectedPackage()
                                }
                            },
                            onUpgrade: { viewModel.requestAction(.upgrade) },
                            onReinstall: { viewModel.requestAction(.reinstall) },
                            onUninstall: { viewModel.requestAction(.uninstall) },
                            onPin: { viewModel.requestAction(.pin) },
                            onUnpin: { viewModel.requestAction(.unpin) }
                        )
                        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyStateView(
                            title: "Select a Package",
                            message: "Choose a formula or cask to view details and actions.",
                            systemImage: "info.circle"
                        )
                        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onRefreshCommand {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedPackageID) { _, _ in
            Task {
                await viewModel.loadDetailsForSelectedPackage()
            }
        }
        .alert(
            viewModel.pendingAction?.title ?? "",
            isPresented: pendingActionBinding,
            presenting: viewModel.pendingAction
        ) { action in
            Button(action.confirmTitle, role: action.isDestructive ? .destructive : nil) {
                Task {
                    await viewModel.execute(action)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingAction = nil
            }
        } message: { action in
            if action.action == .uninstall, let warning = viewModel.dependencyWarning {
                Text("\(action.message)\n\n⚠️ \(warning.summary)")
            } else {
                Text(action.message)
            }
        }
    }

    private var selectedFilterBinding: Binding<PackageListFilter> {
        Binding(
            get: { viewModel.selectedFilter },
            set: { viewModel.selectedFilter = $0 }
        )
    }

    private var installPackageTypeBinding: Binding<PackageType> {
        Binding(
            get: { viewModel.installPackageType },
            set: { viewModel.installPackageType = $0 }
        )
    }

    private var installPackageNameBinding: Binding<String> {
        Binding(
            get: { viewModel.installPackageName },
            set: { viewModel.installPackageName = $0 }
        )
    }

    private var selectedPackageIDBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedPackageID },
            set: { viewModel.selectedPackageID = $0 }
        )
    }

    private var displayedPackages: [BrewPackage] {
        let packagesByFilter = viewModel.allPackages.filter { package in
            switch viewModel.selectedFilter {
            case .all:
                return true
            case .formulae:
                return package.type == .formula
            case .casks:
                return package.type == .cask
            }
        }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return packagesByFilter
        }

        return packagesByFilter.filter { package in
            package.name.localizedCaseInsensitiveContains(trimmedQuery)
                || (package.packageDescription?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }
    }

    private var hasActiveSearch: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedDisplayedPackage: BrewPackage? {
        guard let selectedID = viewModel.selectedPackageID else {
            return nil
        }
        return displayedPackages.first(where: { $0.id == selectedID })
    }

    private var pendingActionBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAction != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingAction = nil
                }
            }
        )
    }
}
