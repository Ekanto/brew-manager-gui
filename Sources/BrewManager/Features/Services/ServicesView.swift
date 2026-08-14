import SwiftUI

struct ServicesView: View {
    @State private var viewModel: ServicesViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: ServicesViewModel(
                homebrewService: appState.homebrewService,
                appState: appState
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                IconTile(systemImage: "bolt.horizontal.fill", color: Theme.Palette.cask, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Services")
                        .font(.title2.bold())
                    Text("Homebrew-managed background daemons")
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
                .keyboardShortcut("r")
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            } else if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if viewModel.isLoading && viewModel.services.isEmpty {
                ProgressView("Loading services…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.services.isEmpty {
                EmptyStateView(
                    title: "No Services Found",
                    message: "No Homebrew services are currently registered.",
                    systemImage: "bolt.horizontal.circle",
                    tint: Theme.Palette.info
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.services) { service in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(color(for: service.status))
                            .frame(width: 8, height: 8)
                            .shadow(color: color(for: service.status).opacity(0.6), radius: 3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.name)
                                .font(.body.weight(.medium))

                            HStack(spacing: 6) {
                                Text(service.status.displayName)
                                    .foregroundStyle(color(for: service.status))
                                if service.launchesAtLogin {
                                    Text("• at login")
                                        .foregroundStyle(.secondary)
                                }
                                if let user = service.user {
                                    Text("• \(user)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                        .frame(minWidth: 200, alignment: .leading)

                        Spacer()

                        Button("Start") {
                            Task {
                                await viewModel.runAction(.start, serviceName: service.name)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.Palette.success)

                        Button("Stop") {
                            Task {
                                await viewModel.runAction(.stop, serviceName: service.name)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.Palette.danger)

                        Button("Restart") {
                            Task {
                                await viewModel.runAction(.restart, serviceName: service.name)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                    .font(.subheadline)
                }
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
    }

    private func color(for status: ServiceStatus) -> Color {
        switch status {
        case .running:
            return .green
        case .stopped:
            return .gray
        case .scheduled:
            return .blue
        case .error:
            return .red
        case .unknown:
            return .orange
        }
    }
}
