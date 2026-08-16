import AppKit
import SwiftUI

struct IssuesView: View {
    @State private var viewModel: IssuesViewModel

    init(appState: AppState) {
        _viewModel = State(
            initialValue: IssuesViewModel(
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

                if let feedback = viewModel.feedback {
                    MessageBanner(
                        severity: feedback.severity,
                        headline: feedback.headline,
                        detailItems: feedback.details,
                        footnote: feedback.footnote,
                        onShowOutput: feedback.operation.map { operation in
                            { viewModel.showOutput(for: operation) }
                        },
                        onDismiss: { viewModel.feedback = nil }
                    )
                }

                if viewModel.isScanning {
                    scanningCard
                } else if !viewModel.hasIssues {
                    healthyCard
                } else {
                    issueSections
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
            await viewModel.scan()
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
        .alert(
            viewModel.pendingCaskRepair?.title ?? "",
            isPresented: pendingCaskRepairBinding,
            presenting: viewModel.pendingCaskRepair
        ) { pending in
            Button(pending.action.title, role: pending.action.isDestructive ? .destructive : nil) {
                Task {
                    await viewModel.confirmCaskRepair(pending)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingCaskRepair = nil
            }
        } message: { pending in
            Text(pending.message)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemImage: "exclamationmark.triangle.fill", color: Theme.Palette.warning, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Problem Resolver Center")
                    .font(.title2.weight(.bold))

                Text("Scan for stale casks, permission problems and `brew doctor` warnings. Safe fixes show the exact Homebrew command before running.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                Task {
                    await viewModel.scan()
                }
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.warning)
            .disabled(viewModel.isScanning || viewModel.isRunningFix)
        }
        .card(tint: Theme.Palette.warning)
    }

    @ViewBuilder
    private var issueSections: some View {
        if !viewModel.staleCasks.isEmpty {
            staleCasksSection
        }

        if !viewModel.permissionIssues.isEmpty {
            permissionSection
        }

        if let report = viewModel.doctorReport, !report.warnings.isEmpty {
            doctorSection(report)
        }
    }

    private var staleCasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Stale casks",
                count: viewModel.staleCasks.count,
                color: Theme.Palette.warning
            )

            ForEach(viewModel.staleCasks) { cask in
                issueCard(
                    icon: "questionmark.app.dashed",
                    color: Theme.Palette.warning,
                    title: "\(cask.name) is missing from disk",
                    summary: "Homebrew still tracks this cask, but its application is missing. Upgrades can fail until you reinstall it or make Homebrew forget it."
                ) {
                    HStack(spacing: 8) {
                        Spacer()
                        Button {
                            viewModel.requestCaskRepair(cask, action: .reinstall)
                        } label: {
                            Label("Reinstall", systemImage: CaskRecoveryAction.reinstall.systemImage)
                        }
                        .disabled(viewModel.isRunningFix)

                        Button {
                            viewModel.requestCaskRepair(cask, action: .forget)
                        } label: {
                            Label("Forget", systemImage: CaskRecoveryAction.forget.systemImage)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Palette.warning)
                        .disabled(viewModel.isRunningFix)
                    }
                }
            }
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Permission problems",
                count: viewModel.permissionIssues.count,
                color: Theme.Palette.danger
            )

            ForEach(viewModel.permissionIssues) { issue in
                issueCard(
                    icon: "lock.trianglebadge.exclamationmark.fill",
                    color: Theme.Palette.danger,
                    title: "\(issue.name) needs Terminal repair",
                    summary: "\(issue.appPath) is owned by \(issue.owner). Brew Manager will not ask for your password inside the GUI; run the copied command in Terminal so macOS can prompt safely."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(issue.terminalCommand)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))

                        HStack {
                            Spacer()
                            Button {
                                copy(issue.terminalCommand)
                            } label: {
                                Label("Copy Terminal Command", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
        }
    }

    private func doctorSection(_ report: DoctorReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "brew doctor warnings",
                count: report.warnings.count,
                color: Theme.Palette.info
            )

            ForEach(report.warnings) { warning in
                issueCard(
                    icon: "stethoscope",
                    color: Theme.Palette.info,
                    title: warning.title,
                    summary: warning.detail.isEmpty ? "Homebrew reported this warning without extra details." : warning.detail
                ) {
                    EmptyView()
                }
            }

            if !report.suggestedFixes.isEmpty {
                suggestedFixes(report.suggestedFixes)
            }
        }
    }

    private func suggestedFixes(_ fixes: [DoctorReport.SuggestedFix]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safe suggested fixes")
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
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Palette.info)
                    .disabled(viewModel.isRunningFix)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .card(tint: Theme.Palette.info)
    }

    private func issueCard<Actions: View>(
        icon: String,
        color: Color,
        title: String,
        summary: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(systemImage: icon, color: color, size: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            actions()
        }
        .card(tint: color)
    }

    private func sectionTitle(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Chip(text: "\(count)", color: color)
        }
    }

    private var scanningCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Scanning Homebrew issues…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .card(tint: Theme.Palette.info)
    }

    private var healthyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemImage: "checkmark.seal.fill", color: Theme.Palette.success, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text("No problems found")
                    .font(.headline)
                Text("Brew Manager did not find stale casks, root-owned cask apps or `brew doctor` warnings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card(tint: Theme.Palette.success)
    }

    private func copy(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        viewModel.feedback = MaintenanceFeedback(
            severity: .success,
            headline: "Terminal command copied.",
            footnote: "Paste it into Terminal to let macOS ask for your password safely."
        )
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

    private var pendingCaskRepairBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingCaskRepair != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.pendingCaskRepair = nil
                }
            }
        )
    }
}
