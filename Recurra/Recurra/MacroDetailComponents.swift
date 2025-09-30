import SwiftUI

// MARK: - Macro Detail Components

private struct MacroDetailCard: View {
    let macro: RecordedMacro
    @Binding var renameText: String
    var isRenaming: FocusState<Bool>.Binding
    let renameAction: () -> Void
    let playAction: () -> Void
    let deleteAction: () -> Void
    let isReplaying: Bool
    let saveTimelineAction: (RecordedMacro) -> Void

    @State private var timelineDraft: MacroTimelineDraft
    @State private var selectedKeyframeID: UUID?
    @State private var hasTimelineChanges = false
    @State private var suppressTimelineChange = false
    @State private var timelineErrorMessage: String?
    @AppStorage(AppSettingsKey.defaultTimelineDuration) private var defaultTimelineDuration = 3.0

    init(macro: RecordedMacro,
         renameText: Binding<String>,
         isRenaming: FocusState<Bool>.Binding,
         renameAction: @escaping () -> Void,
         playAction: @escaping () -> Void,
         deleteAction: @escaping () -> Void,
         isReplaying: Bool,
         saveTimelineAction: @escaping (RecordedMacro) -> Void) {
        self.macro = macro
        self._renameText = renameText
        self.isRenaming = isRenaming
        self.renameAction = renameAction
        self.playAction = playAction
        self.deleteAction = deleteAction
        self.isReplaying = isReplaying
        self.saveTimelineAction = saveTimelineAction
        let baselineDuration = MacroDetailCard.resolveDefaultTimelineDuration()
        _timelineDraft = State(initialValue: MacroTimelineDraft(macro: macro,
                                                               minimumDuration: baselineDuration))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            renameSection

            summaryRow

            actionButtons

            Divider()

            MacroTimelineEditor(draft: $timelineDraft, selection: $selectedKeyframeID)
                .onChange(of: timelineDraft) { _ in
                    if suppressTimelineChange {
                        suppressTimelineChange = false
                    } else {
                        hasTimelineChanges = true
                    }
                }

            timelineFooter
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: 24)
        .onChange(of: macro.id) { _ in
            applyTimeline(from: macro)
        }
        .onChange(of: macro.events.count) { _ in
            if !hasTimelineChanges {
                applyTimeline(from: macro)
            }
        }
        .onChange(of: macro.duration) { _ in
            if !hasTimelineChanges {
                applyTimeline(from: macro)
            }
        }
        .alert("Timeline Update Failed", isPresented: Binding(get: {
            timelineErrorMessage != nil
        }, set: { isPresented in
            if !isPresented {
                timelineErrorMessage = nil
            }
        })) {
            Button("OK", role: .cancel) {
                timelineErrorMessage = nil
            }
        } message: {
            Text(timelineErrorMessage ?? "")
        }
        .onChange(of: defaultTimelineDuration) { newValue in
            guard timelineDraft.keyframes.isEmpty, !hasTimelineChanges else { return }
            let target = MacroDetailCard.resolveDefaultTimelineDuration(from: newValue)
            timelineDraft.duration = max(timelineDraft.duration, target)
        }
    }

    private var renameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macro name")
                .font(.headline)
            HStack(spacing: 10) {
                TextField("Macro name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .focused(isRenaming)
                    .onSubmit(renameAction)
                Button("Save", action: renameAction)
                    .buttonStyle(SubtleButtonStyle())
                    .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              renameText == macro.name)
            }
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(macro.name)
                    .font(.title2.weight(.semibold))
                Text(macro.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Label("\(macro.events.count)", systemImage: "square.stack.3d.down.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(durationString(for: macro), systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Replay Macro", action: playAction)
                .buttonStyle(GradientButtonStyle(isDestructive: false))
                .disabled(isReplaying)
            Button("Delete", role: .destructive, action: deleteAction)
                .buttonStyle(SubtleButtonStyle(isDestructive: true))
        }
    }

    private var timelineFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasTimelineChanges {
                HStack(spacing: 12) {
                    Label("Unsaved timeline changes", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Discard Changes", role: .destructive, action: resetTimeline)
                        .buttonStyle(.bordered)
                    Button("Save Timeline", action: saveTimeline)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Keyframes: \(timelineDraft.keyframes.count) • " +
                     "Duration: \(String(format: "%.2fs", timelineDraft.duration))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resetTimeline() {
        applyTimeline(from: macro)
    }

    private func saveTimeline() {
        do {
            let updatedMacro = try timelineDraft.buildMacro(from: macro)
            applyTimeline(from: updatedMacro)
            saveTimelineAction(updatedMacro)
        } catch {
            timelineErrorMessage = error.localizedDescription
        }
    }

    private func applyTimeline(from macro: RecordedMacro) {
        suppressTimelineChange = true
        let baselineDuration = MacroDetailCard.resolveDefaultTimelineDuration(from: defaultTimelineDuration)
        timelineDraft = MacroTimelineDraft(macro: macro, minimumDuration: baselineDuration)
        selectedKeyframeID = nil
        hasTimelineChanges = false
        DispatchQueue.main.async {
            suppressTimelineChange = false
        }
    }

    private func durationString(for macro: RecordedMacro) -> String {
        let seconds = max(0, macro.duration)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds > 60 ? [.minute, .second] : [.second]
        formatter.unitsStyle = .short
        return formatter.string(from: seconds) ?? "--"
    }
}

private extension MacroDetailCard {
    static func resolveDefaultTimelineDuration(from value: Double? = nil) -> TimeInterval {
        if let value {
            return clampTimelineDuration(value)
        }

        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: AppSettingsKey.defaultTimelineDuration) as? Double {
            return clampTimelineDuration(stored)
        }
        if defaults.object(forKey: AppSettingsKey.defaultTimelineDuration) != nil {
            return clampTimelineDuration(defaults.double(forKey: AppSettingsKey.defaultTimelineDuration))
        }
        return 3
    }

    static func clampTimelineDuration(_ value: Double) -> TimeInterval {
        guard value.isFinite, value > 0 else { return 3 }
        return min(max(value, 0.5), 120)
    }
}

private struct StatusBadge: View {
    let status: Recorder.Status

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(status.description)
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(colorScheme == .dark ? 0.22 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(colorScheme == .dark ? 0.5 : 0.35))
            )
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .idle:
            return Color.green
        case .recording:
            return Color.red
        case .replaying:
            return Color.blue
        case .permissionDenied:
            return Color.orange
        }
    }
}

private struct PermissionPrompt: View {
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Accessibility permission is required to record and replay events.")
                .font(.callout)
            Button("Grant Permission", action: primaryAction)
                .buttonStyle(SubtleButtonStyle())
        }
        .padding(16)
        .cardBackground(cornerRadius: 16)
    }
}

private struct PermissionRequestView: View {
    let onGrant: () -> Void
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(colorScheme: colorScheme)

        ZStack {
            palette.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    RecurraLogo()
                        .frame(width: 64, height: 64)

                    Image(systemName: "hand.raised")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.orange)
                }

                Text("Grant Accessibility Access")
                    .font(.title2.weight(.semibold))

                Text("Recurra needs Accessibility permission to capture and replay keyboard and mouse events. " +
                     "Grant access to continue using recording and playback features.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 360)

                VStack(spacing: 12) {
                    Button("Grant Permission") {
                        onGrant()
                    }
                    .buttonStyle(GradientButtonStyle(isDestructive: false))

                    Button("Not Now") {
                        dismiss()
                        onClose()
                    }
                    .buttonStyle(SubtleButtonStyle())
                }
            }
            .padding(36)
            .frame(maxWidth: 480)
            .cardBackground(cornerRadius: 28)
        }
    }
}
