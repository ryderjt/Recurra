import SwiftUI

// MARK: - Timeline Components

private struct KeyframeSnapConfiguration {
    var isEnabled: Bool
    var interval: TimeInterval

    func apply(to time: TimeInterval) -> TimeInterval {
        guard isEnabled else { return time }
        let spacing = max(interval, 0.01)
        return (time / spacing).rounded() * spacing
    }
}

private struct TimelineTrackView: View {
    @Binding var draft: MacroTimelineDraft
    @Binding var selection: UUID?
    let snapConfiguration: KeyframeSnapConfiguration

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let duration = max(draft.duration, 0.5)
            let ratio = width / duration
            let baseline = height * 0.65

            ZStack(alignment: .topLeading) {
                TimelineBackground(duration: duration)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baseline))
                    path.addLine(to: CGPoint(x: width, y: baseline))
                }
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)

                ForEach(draft.keyframes) { keyframe in
                    let xPosition = CGFloat(keyframe.time) * ratio
                    KeyframeMarker(keyframe: keyframe,
                                   isSelected: keyframe.id == selection)
                        .position(x: min(max(12, xPosition), width - 12),
                                  y: baseline)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 6)
                                .onChanged { value in
                                    guard width > 0 else { return }
                                    selection = keyframe.id
                                    let clampedX = min(max(0, value.location.x), width)
                                    let rawTime = Double(clampedX / width) * duration
                                    let snapped = snapConfiguration.apply(to: rawTime)
                                    let clamped = min(max(snapped, 0), draft.duration)
                                    draft.moveKeyframe(id: keyframe.id, to: clamped)
                                }
                                .onEnded { _ in
                                    draft.clampDurationToKeyframes()
                                }
                        )
                        .onTapGesture {
                            selection = keyframe.id
                        }
                }
            }
        }
    }
}

private struct TimelineBackground: View {
    let duration: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let baseline = height * 0.65
            let tickSpacing = timelineTickSpacing(for: duration)
            let totalTicks = Int((duration / tickSpacing).rounded(.up))
            let effectiveDuration = max(duration, 0.5)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.02))

                ForEach(0...totalTicks, id: \.self) { tick in
                    let time = Double(tick) * tickSpacing
                    let ratio = time / effectiveDuration
                    let xPosition = CGFloat(ratio) * width
                    Path { path in
                        path.move(to: CGPoint(x: xPosition, y: baseline - 40))
                        path.addLine(to: CGPoint(x: xPosition, y: baseline + 28))
                    }
                    .stroke(Color.secondary.opacity(tick % 5 == 0 ? 0.45 : 0.2), lineWidth: tick % 5 == 0 ? 1.5 : 1)

                    Text(timeLabel(for: time))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: xPosition, y: baseline - 48)
                }
            }
        }
    }

    private func timeLabel(for time: TimeInterval) -> String {
        if time < 0.01 {
            return "0s"
        }
        return String(format: "%.1fs", time)
    }

    private func timelineTickSpacing(for duration: TimeInterval) -> TimeInterval {
        switch duration {
        case ..<3:
            return 0.25
        case ..<10:
            return 0.5
        case ..<30:
            return 1
        default:
            return 5
        }
    }
}

private struct KeyframeMarker: View {
    let keyframe: MacroTimelineKeyframe
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(timeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(markerColor.opacity(isSelected ? 0.9 : 0.7))
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(markerColor, lineWidth: isSelected ? 2 : 1)
                )
                .overlay(
                    Image(systemName: symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                )
        }
    }

    private var markerColor: Color {
        switch keyframe.payload {
        case .keyboard:
            return Color.accentColor
        case .mouse:
            return Color.purple
        case .unsupported:
            return Color.gray
        }
    }

    private var symbolName: String {
        switch keyframe.payload {
        case .keyboard:
            return "keyboard"
        case .mouse:
            return "cursorarrow.click"
        case .unsupported:
            return "questionmark"
        }
    }

    private var timeLabel: String {
        String(format: "%.2fs", keyframe.time)
    }
}

private struct ModifierFlagsEditor: View {
    var flags: CGEventFlags
    var onChange: (CGEventFlags) -> Void

    private let options: [ModifierOption] = ModifierOption.allOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Modifiers")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(options) { option in
                    Toggle(isOn: Binding(get: {
                        flags.contains(option.flag)
                    }, set: { newValue in
                        var updated = flags
                        if newValue {
                            updated.insert(option.flag)
                        } else {
                            updated.remove(option.flag)
                        }
                        onChange(updated)
                    })) {
                        Text(option.label)
                    }
                    .toggleStyle(.button)
                }
            }
        }
    }
}

private struct ModifierOption: Identifiable {
    let id = UUID()
    let flag: CGEventFlags
    let label: String

    static let allOptions: [ModifierOption] = [
        ModifierOption(flag: .maskCommand, label: "⌘"),
        ModifierOption(flag: .maskShift, label: "⇧"),
        ModifierOption(flag: .maskControl, label: "⌃"),
        ModifierOption(flag: .maskAlternate, label: "⌥")
    ]
}

private struct MouseButtonOption: Identifiable {
    let id = UUID()
    let button: CGMouseButton
    let label: String

    static let all: [MouseButtonOption] = [
        MouseButtonOption(button: .left, label: "Left"),
        MouseButtonOption(button: .right, label: "Right"),
        MouseButtonOption(button: CGMouseButton(rawValue: 2) ?? .left, label: "Other")
    ]
}
