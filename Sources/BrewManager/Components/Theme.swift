import SwiftUI

/// Central visual language for the app. Colours are derived from Homebrew's
/// own amber branding so the UI reads as a Homebrew tool rather than a generic
/// list app.
enum Theme {
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 14

    enum Palette {
        static let amber = Color(red: 0.98, green: 0.68, blue: 0.18)
        static let amberDeep = Color(red: 0.93, green: 0.47, blue: 0.10)
        static let formula = Color(red: 0.25, green: 0.72, blue: 0.51)
        static let cask = Color(red: 0.55, green: 0.45, blue: 0.94)
        static let info = Color(red: 0.29, green: 0.60, blue: 0.96)
        static let danger = Color(red: 0.94, green: 0.35, blue: 0.36)
        static let warning = Color(red: 0.98, green: 0.63, blue: 0.20)
        static let success = Color(red: 0.24, green: 0.74, blue: 0.45)
    }

    /// Solid card fill used when transparency is reduced. Tracks the window
    /// background so it stays correct in both light and dark appearance.
    static var opaqueSurface: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.amber, Palette.amberDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func gradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.95), color.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Subtle warm wash behind the detail pane so large empty areas do not
    /// read as flat grey.
    static var canvas: some View {
        CanvasBackground()
    }
}

private struct CanvasBackground: View {
    @Environment(\.reduceTransparencyEnabled) private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                LinearGradient(
                    colors: [
                        Theme.Palette.amber.opacity(0.06),
                        Color.clear,
                        Theme.Palette.cask.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// A rounded, subtly bordered surface used for every grouped block so the app
/// has one consistent container instead of mixed `GroupBox` styling.
struct CardModifier: ViewModifier {
    @Environment(\.reduceTransparencyEnabled) private var reduceTransparency

    var tint: Color = .clear
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .fill(tint.opacity(tint == .clear ? 0 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .strokeBorder(
                        tint == .clear
                            ? AnyShapeStyle(Color.primary.opacity(reduceTransparency ? 0.16 : 0.08))
                            : AnyShapeStyle(tint.opacity(0.25))
                    )
            )
    }

    private var surface: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Theme.opaqueSurface)
            : AnyShapeStyle(.ultraThinMaterial)
    }
}

/// True when either the system accessibility setting or the app preference asks
/// for solid surfaces instead of blurred materials.
private struct ReduceTransparencyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var reduceTransparencyEnabled: Bool {
        get { self[ReduceTransparencyKey.self] }
        set { self[ReduceTransparencyKey.self] = newValue }
    }
}

extension View {
    func card(tint: Color = .clear, padding: CGFloat = 14) -> some View {
        modifier(CardModifier(tint: tint, padding: padding))
    }

    /// Background for window chrome (sidebar header, footer, palette). Falls
    /// back to a solid fill when the user has reduced transparency.
    func chromeBackground(prominent: Bool = false) -> some View {
        modifier(ChromeBackgroundModifier(prominent: prominent))
    }
}

struct ChromeBackgroundModifier: ViewModifier {
    @Environment(\.reduceTransparencyEnabled) private var reduceTransparency

    var prominent: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Theme.opaqueSurface)
        } else if prominent {
            content.background(.regularMaterial)
        } else {
            content.background(.ultraThinMaterial)
        }
    }
}

/// Gradient-filled symbol tile. Gives each section and card a strong, colourful
/// focal point.
struct IconTile: View {
    @Environment(\.reduceTransparencyEnabled) private var reduceTransparency

    let systemImage: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Theme.gradient(for: color))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(
                color: color.opacity(reduceTransparency ? 0 : 0.35),
                radius: reduceTransparency ? 0 : 4,
                x: 0,
                y: reduceTransparency ? 0 : 2
            )
    }
}

/// Small pill used for package types, counts and states.
struct Chip: View {
    let text: String
    var color: Color = .secondary
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.25)))
    }
}
