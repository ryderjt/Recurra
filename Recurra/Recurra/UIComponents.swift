import SwiftUI

// MARK: - UI Components

private struct GradientButtonStyle: ButtonStyle {
    var isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        GradientButton(configuration: configuration, isDestructive: isDestructive)
    }

    private struct GradientButton: View {
        let configuration: Configuration
        let isDestructive: Bool
        @State private var hovering = false
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let palette = Palette(colorScheme: colorScheme)
            let gradientColors = isDestructive ? palette.destructiveGradientColors : palette.primaryGradientColors
            let stroke = palette.buttonStroke(isDestructive: isDestructive)
            let shadow = palette.buttonShadow(isDestructive: isDestructive, hovering: hovering)

            configuration.label
                .padding(.vertical, 12)
                .padding(.horizontal, 26)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: gradientColors,
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(stroke)
                )
                .shadow(color: shadow, radius: hovering ? 12 : 8, x: 0, y: hovering ? 6 : 4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.18), value: hovering)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { hovering in
                    self.hovering = hovering
                }
        }
    }
}

private struct SubtleButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        SubtleButton(configuration: configuration, isDestructive: isDestructive)
    }

    private struct SubtleButton: View {
        let configuration: Configuration
        let isDestructive: Bool
        @State private var hovering = false
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let palette = Palette(colorScheme: colorScheme)
            let fill = palette.subtleFill(hovering: hovering)
            let stroke = palette.subtleStroke
            let shadow = palette.subtleShadow(hovering: hovering)

            configuration.label
                .padding(.vertical, 10)
                .padding(.horizontal, 22)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(stroke)
                )
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .shadow(color: shadow, radius: hovering ? 10 : 4, x: 0, y: hovering ? 4 : 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.18), value: hovering)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { hovering in
                    self.hovering = hovering
                }
        }
    }
}

private struct RowIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowIconButton(configuration: configuration)
    }

    private struct RowIconButton: View {
        let configuration: Configuration
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let palette = Palette(colorScheme: colorScheme)

            configuration.label
                .padding(8)
                .background(
                    Circle().fill(palette.rowButtonFill(isPressed: configuration.isPressed))
                )
                .overlay(
                    Circle().stroke(palette.rowButtonStroke)
                )
                .foregroundStyle(.primary)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .contentShape(Circle())
        }
    }
}

private extension View {
    func cardBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}

private struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let palette = Palette(colorScheme: colorScheme)

        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.cardStroke)
            )
    }
}

public struct Palette {
    public let colorScheme: ColorScheme
    
    public init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }

    public var backgroundGradient: LinearGradient {
        return LinearGradient(colors: [
            Color(red: 0.07, green: 0.08, blue: 0.11),
            Color(red: 0.03, green: 0.04, blue: 0.07)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var sidebarGradient: LinearGradient {
        return LinearGradient(colors: [
            Color(red: 0.08, green: 0.09, blue: 0.13),
            Color(red: 0.05, green: 0.06, blue: 0.09)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var sidebarDivider: Color {
        Color.white.opacity(0.1)
    }

    public var cardFill: Color {
        Color.white.opacity(0.08)
    }

    public var cardStroke: Color {
        Color.white.opacity(0.16)
    }

    public var rowBaseFill: Color {
        Color.white.opacity(0.05)
    }

    public var rowBaseStroke: Color {
        Color.white.opacity(0.1)
    }

    public var rowSelectionFill: Color {
        Color.accentColor.opacity(0.32)
    }

    public var rowSelectionStroke: Color {
        Color.accentColor.opacity(0.5)
    }

    public var primaryGradientColors: [Color] {
        return [
            Color(red: 0.35, green: 0.68, blue: 1.0),
            Color(red: 0.18, green: 0.42, blue: 0.96)
        ]
    }

    public var destructiveGradientColors: [Color] {
        return [
            Color(red: 0.95, green: 0.34, blue: 0.36),
            Color(red: 0.74, green: 0.16, blue: 0.24)
        ]
    }

    public func buttonStroke(isDestructive: Bool) -> Color {
        if isDestructive {
            return Color.red.opacity(0.45)
        }
        return Color.white.opacity(0.25)
    }

    public func buttonShadow(isDestructive: Bool, hovering: Bool) -> Color {
        let base = isDestructive ? Color.red : Color.accentColor
        return base.opacity(hovering ? 0.42 : 0.28)
    }

    public func subtleFill(hovering: Bool) -> Color {
        return Color.white.opacity(hovering ? 0.18 : 0.12)
    }

    public var subtleStroke: Color {
        Color.white.opacity(0.16)
    }

    public func subtleShadow(hovering: Bool) -> Color {
        return Color.black.opacity(hovering ? 0.32 : 0.2)
    }

    public func rowButtonFill(isPressed: Bool) -> Color {
        return Color.white.opacity(isPressed ? 0.22 : 0.12)
    }

    public var rowButtonStroke: Color {
        Color.white.opacity(0.2)
    }
}

private struct RecurraLogo: View {
    var body: some View {
        Image("BasicIconWhite")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
    }
}
