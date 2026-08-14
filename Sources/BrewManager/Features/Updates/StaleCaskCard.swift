import SwiftUI

/// Explains the one Homebrew failure users cannot act on from raw output:
/// a cask whose application was deleted outside Homebrew, which blocks every
/// later upgrade until the record is repaired.
struct StaleCaskCard: View {
    let casks: [StaleCask]
    var isBusy: Bool
    var onRecover: (CaskRecoveryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                IconTile(
                    systemImage: "questionmark.app.dashed",
                    color: Theme.Palette.warning,
                    size: 30
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.callout.weight(.semibold))

                    Text("Homebrew still tracks \(casks.count == 1 ? "it" : "them"), but the \(casks.count == 1 ? "application is" : "applications are") missing from disk — usually because \(casks.count == 1 ? "it was" : "they were") dragged to the Trash instead of being uninstalled here. Upgrades cannot run until this is resolved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            FlowChips(items: casks.map(\.name), color: Theme.Palette.warning)

            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button {
                    onRecover(.reinstall)
                } label: {
                    Label("Reinstall", systemImage: CaskRecoveryAction.reinstall.systemImage)
                }
                .disabled(isBusy)
                .help("Download again and put the application back in /Applications")

                Button {
                    onRecover(.forget)
                } label: {
                    Label("Forget", systemImage: CaskRecoveryAction.forget.systemImage)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.warning)
                .disabled(isBusy)
                .help("Stop tracking the cask and keep the application uninstalled")
            }
        }
        .card(tint: Theme.Palette.warning)
    }

    private var headline: String {
        casks.count == 1
            ? "\(casks[0].name) is missing from disk"
            : "\(casks.count) casks are missing from disk"
    }
}
