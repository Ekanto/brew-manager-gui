import AppKit
import SwiftUI

struct OperationConsoleView: View {
    @Bindable var operation: OperationConsoleModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                IconTile(
                    systemImage: "terminal.fill",
                    color: operation.isRunning ? Theme.Palette.info : statusColor,
                    size: 32
                )
                Text(operation.title)
                    .font(.title3.bold())
                Spacer()
                statusLabel
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("COMMAND")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("$ \(operation.command)")
                    .font(.system(.callout, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("OUTPUT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $operation.output)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 320)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08))
                    )
                    .disabled(true)
            }

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(operation.output, forType: .string)
                } label: {
                    Label("Copy Output", systemImage: "doc.on.doc")
                }
                Spacer()
                Button(operation.isRunning ? "Close" : "Done") {
                    onDone()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 520)
        .background(Theme.canvas)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if operation.isRunning {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            let code = operation.exitCode ?? -1

            HStack(spacing: 8) {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)
                Text(statusText(exitCode: code))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                if let duration = operation.duration {
                    Text("• \(duration.conciseDisplay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.14), in: Capsule())
        }
    }

    private var statusColor: Color {
        switch operation.severity {
        case .success:
            return Theme.Palette.success
        case .warning:
            return Theme.Palette.warning
        case .failure:
            return Theme.Palette.danger
        }
    }

    private var statusSymbol: String {
        switch operation.severity {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

    private func statusText(exitCode: Int32) -> String {
        switch operation.severity {
        case .success:
            return "Exit 0"
        case .warning:
            return "Finished with warnings"
        case .failure:
            return "Exit \(exitCode)"
        }
    }
}
