import SwiftUI

struct MaintenanceView: View {
    @State private var viewModel: MaintenanceViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: MaintenanceViewModel(
                homebrewService: appState.homebrewService,
                appState: appState
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cacheSummary

                if let feedback = viewModel.feedback {
                    VStack(alignment: .leading, spacing: 8) {
                        MessageBanner(
                            severity: feedback.severity,
                            headline: feedback.headline,
                            detailItems: feedback.details,
                            footnote: feedback.footnote,
                            onShowOutput: feedback.operation.map { operation in
                                { viewModel.showOutput(for: operation) }
                            },
                            onDismiss: { viewModel.dismissFeedback() }
                        )

                        if !feedback.suggestedFixes.isEmpty {
                            suggestedFixes(feedback.suggestedFixes)
                        }
                    }
                }

                ForEach(MaintenanceTask.allCases) { task in
                    taskCard(for: task)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onRefreshCommand {
            await viewModel.refreshCacheSize()
        }
        .alert(
            viewModel.pendingTask?.title ?? "",
            isPresented: pendingTaskBinding,
            presenting: viewModel.pendingTask
        ) { pending in
            Button(pending.confirmTitle, role: pending.isDestructive ? .destructive : nil) {
                Task {
                    await viewModel.confirm(pending)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingTask = nil
            }
        } message: { pending in
            Text(pending.message)
        }
        .alert(
            viewModel.pendingFix?.title ?? "",
            isPresented: pendingFixBinding,
            presenting: viewModel.pendingFix
        ) { pending in
            Button(pending.confirmTitle, role: pending.isDestructive ? .destructive : nil) {
                Task {
                    await viewModel.confirmFix(pending)
                }
            }
            Button("Not Now", role: .cancel) {
                viewModel.pendingFix = nil
            }
        } message: { pending in
            Text(pending.message)
        }
    }

    private func suggestedFixes(_ fixes: [DoctorReport.SuggestedFix]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Suggested fixes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(fixes) { fix in
                HStack(spacing: 10) {
                    Text(fix.displayCommand)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Button(fix.confirmTitle) {
                        viewModel.requestFix(fix)
                    }
                    .disabled(viewModel.isBusy)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var cacheSummary: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemImage: "internaldrive.fill", color: Theme.Palette.info, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("Download Cache")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if viewModel.isLoadingCacheSize {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Measuring cache…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(viewModel.cacheSizeDescription ?? "Unknown size")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gradient(for: Theme.Palette.info))
                }

                Text(viewModel.cachePath ?? "Cache location unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button {
                Task {
                    await viewModel.refreshCacheSize()
                }
            } label: {
                Label("Recalculate", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoadingCacheSize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(tint: Theme.Palette.info)
    }

    private func taskCard(for task: MaintenanceTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(systemImage: task.systemImage, color: task.tint, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(task.title)
                            .font(.headline)

                        if task.isDestructive {
                            Chip(
                                text: "Destructive",
                                color: Theme.Palette.warning,
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }
                    }

                    Text(task.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if viewModel.runningTask == task {
                    ProgressView()
                        .controlSize(.small)
                    Text("Running…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if task.supportsPreview {
                    Button("Preview") {
                        Task {
                            await viewModel.preview(task)
                        }
                    }
                    .disabled(viewModel.isBusy)
                }

                Button(task.runTitle) {
                    viewModel.requestRun(task)
                }
                .buttonStyle(.borderedProminent)
                .tint(task.tint)
                .disabled(viewModel.isBusy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(tint: task.tint)
    }

    private var pendingFixBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingFix != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingFix = nil
                }
            }
        )
    }

    private var pendingTaskBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingTask != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingTask = nil
                }
            }
        )
    }
}
