import SwiftUI
import ApplicationServices

struct MacroTimelineEditor: View {
    @Binding var draft: MacroTimelineDraft
    @Binding var selection: UUID?
    @State private var durationInput: String = ""
    @AppStorage(AppSettingsKey.keyframeSnapEnabled) private var isKeyframeSnappingEnabled = true
    @AppStorage(AppSettingsKey.keyframeSnapInterval) private var keyframeSnapInterval = 0.05

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Timeline")
                    .font(.headline)
                Spacer()
                if draft.keyframes.isEmpty {
                    Text("No keyframes yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            TimelineTrackView(draft: $draft,
                              selection: $selection,
                              snapConfiguration: snapConfiguration)
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2))
                )

            timelineLengthControl

            HStack(spacing: 12) {
                Button(action: addKeyboardKeyframe) {
                    Label("Add Key Keyframe", systemImage: "keyboard")
                }
                .buttonStyle(.bordered)

                Button(action: addMouseKeyframe) {
                    Label("Add Mouse Keyframe", systemImage: "cursorarrow.click")
                }
                .buttonStyle(.bordered)

                Spacer()

                if let selection, draft.keyframes.first(where: { $0.id == selection }) != nil {
                    Button(role: .destructive, action: deleteSelection) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            if let selection, let keyframe = draft.keyframes.first(where: { $0.id == selection }) {
                KeyframeInspector(keyframe: keyframe,
                                  draft: $draft,
                                  snapConfiguration: snapConfiguration)
            } else {
                Text("Select a keyframe to edit its details.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: draft.keyframes) { _ in
            guard let selection else { return }
            if !draft.keyframes.contains(where: { $0.id == selection }) {
                self.selection = draft.keyframes.last?.id
            }
        }
        .onAppear(perform: syncDurationInput)
        .onChange(of: draft.duration) { _ in
            syncDurationInput()
        }
    }

    private var nextInsertionTime: TimeInterval {
        let currentMax = draft.maximumKeyframeTime
        if currentMax == 0 {
            return min(0.25, draft.duration)
        }
        let proposed = currentMax + 0.25
        return min(proposed, draft.duration)
    }

    private func addKeyboardKeyframe() {
        let id = draft.addKeyboardKeyframe(at: nextInsertionTime)
        selection = id
    }

    private func addMouseKeyframe() {
        let id = draft.addMouseKeyframe(at: nextInsertionTime)
        selection = id
    }

    private func deleteSelection() {
        guard let selection else { return }
        draft.removeKeyframe(id: selection)
        let remaining = draft.keyframes
        self.selection = remaining.last?.id
    }

    private func syncDurationInput() {
        durationInput = formattedDuration(draft.duration)
    }

    private func applyDurationInput() {
        guard let value = Double(durationInput) else {
            syncDurationInput()
            return
        }
        updateDuration(to: value)
    }

    private func updateDuration(to value: TimeInterval) {
        // Ensure the value is finite and within reasonable bounds
        guard value.isFinite && !value.isNaN else {
            syncDurationInput()
            return
        }

        let clamped = max(0.5, min(value, 120))
        draft.duration = clamped
        draft.clampDurationToKeyframes()
        durationInput = formattedDuration(clamped)
    }

    private func formattedDuration(_ value: TimeInterval) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded.rounded() == rounded {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.2f", rounded)
    }

    private var timelineLengthControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timeline Length")
                Spacer()
                Text("\(draft.duration, format: .number.precision(.fractionLength(2))) s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Seconds", text: Binding(get: {
                durationInput
            }, set: { newValue in
                durationInput = newValue
                if let value = Double(newValue) {
                    updateDuration(to: value)
                }
            }))
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            .onSubmit(applyDurationInput)
        }
    }

    private var snapConfiguration: KeyframeSnapConfiguration {
        let sanitizedInterval = max(0.01, keyframeSnapInterval)
        return KeyframeSnapConfiguration(isEnabled: isKeyframeSnappingEnabled,
                                         interval: sanitizedInterval)
    }
}

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

private struct KeyframeInspector: View {
    let keyframe: MacroTimelineKeyframe
    @Binding var draft: MacroTimelineDraft
    let snapConfiguration: KeyframeSnapConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("Time: \(keyframe.time, format: .number.precision(.fractionLength(2))) s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            timeControls

            switch keyframe.payload {
            case .keyboard(let action):
                keyboardInspector(action: action)
            case .mouse(let action):
                mouseInspector(action: action)
            case .unsupported(let unsupported):
                unsupportedInspector(info: unsupported)
            }
        }
    }

    private var title: String {
        switch keyframe.payload {
        case .keyboard:
            return "Keyboard Keyframe"
        case .mouse:
            return "Mouse Keyframe"
        case .unsupported:
            return "Unsupported Event"
        }
    }

    private var timeControls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Time (s)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Time", value: timeBinding, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            Stepper(value: timeBinding, in: 0...draft.duration, step: 0.05) {
                Text("Nudge")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeBinding: Binding<Double> {
        Binding(
            get: { keyframe.time },
            set: { newValue in
                // Ensure the value is finite and within reasonable bounds
                guard newValue.isFinite && !newValue.isNaN else { return }

                let snapped = snapConfiguration.apply(to: newValue)
                let clamped = max(0, min(snapped, draft.duration))
                draft.moveKeyframe(id: keyframe.id, to: clamped)
            }
        )
    }

    private func keyboardInspector(action: KeyboardAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Phase", selection: Binding(get: {
                action.phase
            }, set: { newValue in
                draft.updateKeyboardAction(id: keyframe.id) { action in
                    action.phase = newValue
                }
            })) {
                ForEach(KeyboardAction.Phase.allCases) { phase in
                    Text(phase.rawValue)
                        .tag(phase)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Key Code")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Key code", value: Binding(get: {
                    Double(action.keyCode)
                }, set: { newValue in
                    let normalized = max(0, min(255, Int(newValue)))
                    draft.updateKeyboardAction(id: keyframe.id) { action in
                        action.keyCode = CGKeyCode(UInt16(normalized))
                    }
                }), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
            }

            ModifierFlagsEditor(flags: action.flags) { newFlags in
                draft.updateKeyboardAction(id: keyframe.id) { action in
                    action.flags = newFlags
                }
            }
        }
    }

    private func mouseInspector(action: MouseAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            phasePicker(for: action)
            buttonPicker(for: action)
            coordinateFields(for: action)
            modifierFlagsEditor(for: action)
        }
    }

    private func phasePicker(for action: MouseAction) -> some View {
        Picker("Phase", selection: Binding(get: {
            action.phase
        }, set: { newValue in
            draft.updateMouseAction(id: keyframe.id) { action in
                action.phase = newValue
            }
        })) {
            ForEach(MouseAction.Phase.allCases) { phase in
                Text(phase.rawValue)
                    .tag(phase)
            }
        }
        .pickerStyle(.segmented)
    }

    private func buttonPicker(for action: MouseAction) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Button")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker("Button", selection: Binding(get: {
                    action.button
                }, set: { newValue in
                    draft.updateMouseAction(id: keyframe.id) { action in
                        action.button = newValue
                    }
                })) {
                    ForEach(MouseButtonOption.all) { option in
                        Text(option.label)
                            .tag(option.button)
                    }
                }
                .pickerStyle(.segmented)
            }
            Spacer()
        }
    }

    private func coordinateFields(for action: MouseAction) -> some View {
        HStack(spacing: 14) {
            coordinateField(title: "X", value: action.location.x) { newValue in
                draft.updateMouseAction(id: keyframe.id) { action in
                    action.location.x = newValue
                }
            }

            coordinateField(title: "Y", value: action.location.y) { newValue in
                draft.updateMouseAction(id: keyframe.id) { action in
                    action.location.y = newValue
                }
            }
        }
    }

    private func modifierFlagsEditor(for action: MouseAction) -> some View {
        ModifierFlagsEditor(flags: action.flags) { newFlags in
            draft.updateMouseAction(id: keyframe.id) { action in
                action.flags = newFlags
            }
        }
    }

    private func coordinateField(title: String, value: CGFloat, onChange: @escaping (CGFloat) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField(title, value: Binding(get: {
                Double(value)
            }, set: { newValue in
                onChange(CGFloat(newValue))
            }), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 120)
        }
    }

    private func unsupportedInspector(info: UnsupportedAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event type: \(info.description)")
                .font(.subheadline)
            Text("This event type cannot yet be edited. It will be preserved when you save the macro.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
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
}#if DEBUG
#Preview {
    struct PreviewHost: View {
        @State private var draft = MacroTimelineDraft()
        @State private var selection: UUID?

        var body: some View {
            MacroTimelineEditor(draft: $draft, selection: $selection)
                .padding()
        }
    }

    return PreviewHost()
}
#endif


