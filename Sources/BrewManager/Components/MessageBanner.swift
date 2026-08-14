import SwiftUI

/// Presents command feedback with a severity-appropriate colour, a short
/// headline, and optional detail that stays collapsed until asked for, so a
/// long advisory dump never floods the screen.
struct MessageBanner: View {
    let severity: OperationSeverity
    let headline: String
    var detailItems: [DetailItem] = []
    var footnote: String?
    var onShowOutput: (() -> Void)?
    var onDismiss: (() -> Void)?

    struct DetailItem: Identifiable {
        let id: UUID
        let title: String
        let detail: String

        init(id: UUID = UUID(), title: String, detail: String = "") {
            self.id = id
            self.title = title
            self.detail = detail
        }

        var hasDetail: Bool {
            !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)

                Text(headline)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if !detailItems.isEmpty {
                    Button(isExpanded ? "Hide Details" : "Show Details") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    }
                    .buttonStyle(.link)
                }

                if let onShowOutput {
                    Button("View Output", action: onShowOutput)
                        .buttonStyle(.link)
                }

                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
            }

            if isExpanded, !detailItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(detailItems) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)

                            if item.hasDetail {
                                Text(item.detail)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, 24)
            }

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 24)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.35))
        )
    }

    private var tint: Color {
        switch severity {
        case .success:
            return Theme.Palette.success
        case .warning:
            return Theme.Palette.warning
        case .failure:
            return Theme.Palette.danger
        }
    }

    private var symbol: String {
        switch severity {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }
}
