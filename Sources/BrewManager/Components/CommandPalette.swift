import SwiftUI

/// A single actionable entry in the command palette.
struct PaletteCommand: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let keywords: [String]

    /// Erased so commands can navigate, run work, or both.
    let action: @MainActor () -> Void

    static func == (lhs: PaletteCommand, rhs: PaletteCommand) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let haystack = ([title, subtitle] + keywords).joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(query)
    }
}

/// Spotlight-style launcher. Every section and common action is reachable
/// without leaving the keyboard.
struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var selectionIndex = 0
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Jump to a section or run a command…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFieldFocused)
                    .onSubmit(runSelection)
                    .onChange(of: query) { _, _ in selectionIndex = 0 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if filteredCommands.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No matching commands")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                                commandRow(command, isSelected: index == selectionIndex)
                                    .id(index)
                                    .onTapGesture {
                                        selectionIndex = index
                                        runSelection()
                                    }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selectionIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 560)
        .chromeBackground(prominent: true)
        .onAppear { isFieldFocused = true }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private func commandRow(_ command: PaletteCommand, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            IconTile(systemImage: command.systemImage, color: command.tint, size: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(.body.weight(.medium))
                Text(command.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "return")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? command.tint.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var filteredCommands: [PaletteCommand] {
        commands.filter { $0.matches(query) }
    }

    private func moveSelection(by offset: Int) {
        let count = filteredCommands.count
        guard count > 0 else { return }
        selectionIndex = (selectionIndex + offset + count) % count
    }

    private func runSelection() {
        guard filteredCommands.indices.contains(selectionIndex) else { return }
        let command = filteredCommands[selectionIndex]
        dismiss()
        command.action()
    }

    private var commands: [PaletteCommand] {
        var result: [PaletteCommand] = SidebarSection.allCases.map { section in
            PaletteCommand(
                id: "section-\(section.rawValue)",
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                tint: section.tint,
                keywords: ["go", "open", "navigate", section.rawValue]
            ) {
                appState.selectedSection = section
            }
        }

        result.append(
            PaletteCommand(
                id: "action-check-updates",
                title: "Check for Updates",
                subtitle: "Query Homebrew for outdated packages",
                systemImage: "arrow.clockwise",
                tint: Theme.Palette.info,
                keywords: ["outdated", "refresh", "upgrade"]
            ) {
                appState.selectedSection = .updates
                Task { await appState.performBackgroundUpdateCheck() }
            }
        )

        result.append(
            PaletteCommand(
                id: "action-show-last-output",
                title: "Show Last Command Output",
                subtitle: "Reopen the console for the most recent operation",
                systemImage: "terminal",
                tint: Theme.Palette.amberDeep,
                keywords: ["console", "log", "output"]
            ) {
                appState.selectedSection = .history
            }
        )

        return result
    }
}
