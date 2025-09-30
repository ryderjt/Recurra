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

private struct Palette {
    let colorScheme: ColorScheme

    var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                Color(red: 0.07, green: 0.08, blue: 0.11),
                Color(red: 0.03, green: 0.04, blue: 0.07)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.88, green: 0.93, blue: 1.0)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var sidebarGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [
                Color(red: 0.08, green: 0.09, blue: 0.13),
                Color(red: 0.05, green: 0.06, blue: 0.09)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [
                Color(red: 0.94, green: 0.97, blue: 1.0),
                Color(red: 0.87, green: 0.92, blue: 1.0)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var sidebarDivider: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.95)
    }

    var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    var rowBaseFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
    }

    var rowBaseStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    var rowSelectionFill: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.18)
    }

    var rowSelectionStroke: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.5 : 0.38)
    }

    var primaryGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.35, green: 0.68, blue: 1.0),
                Color(red: 0.18, green: 0.42, blue: 0.96)
            ]
        }
        return [
            Color(red: 0.2, green: 0.55, blue: 0.98),
            Color(red: 0.05, green: 0.37, blue: 0.9)
        ]
    }

    var destructiveGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.95, green: 0.34, blue: 0.36),
                Color(red: 0.74, green: 0.16, blue: 0.24)
            ]
        }
        return [
            Color(red: 0.94, green: 0.27, blue: 0.32),
            Color(red: 0.78, green: 0.12, blue: 0.18)
        ]
    }

    func buttonStroke(isDestructive: Bool) -> Color {
        if isDestructive {
            return colorScheme == .dark ? Color.red.opacity(0.45) : Color.red.opacity(0.3)
        }
        return colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.12)
    }

    func buttonShadow(isDestructive: Bool, hovering: Bool) -> Color {
        let base = isDestructive ? Color.red : Color.accentColor
        if colorScheme == .dark {
            return base.opacity(hovering ? 0.42 : 0.28)
        }
        return base.opacity(hovering ? 0.24 : 0.14)
    }

    func subtleFill(hovering: Bool) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(hovering ? 0.18 : 0.12)
        }
        return Color.black.opacity(hovering ? 0.08 : 0.05)
    }

    var subtleStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    func subtleShadow(hovering: Bool) -> Color {
        if colorScheme == .dark {
            return Color.black.opacity(hovering ? 0.32 : 0.2)
        }
        return Color.black.opacity(hovering ? 0.18 : 0.1)
    }

    func rowButtonFill(isPressed: Bool) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(isPressed ? 0.22 : 0.12)
        }
        return Color.black.opacity(isPressed ? 0.12 : 0.06)
    }

    var rowButtonStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08)
    }
}

private struct RecurraLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Image(colorScheme == .dark ? "BasicIconWhite" : "BasicIconBlack")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
    }
}
