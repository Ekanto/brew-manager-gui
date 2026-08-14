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

                LiveOutputTextView(text: operation.output)
                    .frame(minHeight: 320)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08))
                    )
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

/// Read-only terminal output that remains scrollable while the command is
/// streaming. A disabled `TextEditor` looks right, but on macOS it also disables
/// wheel/trackpad scrolling; an `NSTextView` can be non-editable and still
/// selectable + scrollable.
private struct LiveOutputTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.allowsUndo = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.width]
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        guard textView.string != text else { return }

        let clipView = scrollView.contentView
        let previousOrigin = clipView.bounds.origin
        let wasPinnedToBottom = isPinnedToBottom(scrollView)

        textView.string = text

        if wasPinnedToBottom {
            textView.scrollToEndOfDocument(nil)
        } else {
            // The user is reading earlier output; keep that location stable
            // while new bytes arrive below it.
            clipView.scroll(to: previousOrigin)
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func isPinnedToBottom(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return true }

        let visible = scrollView.contentView.bounds
        let bottomEdge = visible.maxY
        let contentHeight = documentView.bounds.height

        return contentHeight - bottomEdge < 24
    }

    final class Coordinator {
        weak var textView: NSTextView?
    }
}
