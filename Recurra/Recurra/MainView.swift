import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var replayer: Replayer
    @EnvironmentObject private var macroManager: MacroManager

    @State private var selectedMacroID: RecordedMacro.ID?
    @State private var renameText: String = ""
    @FocusState private var isRenaming: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.12, blue: 0.15),
                                    Color(red: 0.08, green: 0.08, blue: 0.12)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            NavigationSplitView(sidebar: {
                sidebar
                    .frame(minWidth: 260)
            }, detail: {
                detail
            })
            .navigationSplitViewStyle(.prominentDetail)
        }
        .frame(minWidth: 920, minHeight: 560)
        .onAppear {
            if selectedMacroID == nil {
                selectedMacroID = macroManager.mostRecentMacro?.id
            }
            renameText = selectedMacro?.name ?? ""
        }
        .onChange(of: macroManager.macros) { macros in
            guard !macros.isEmpty else {
                selectedMacroID = nil
                renameText = ""
                return
            }
            if let selectedMacroID, macros.contains(where: { $0.id == selectedMacroID }) {
                return
            }
            selectedMacroID = macros.first?.id
        }
        .onChange(of: selectedMacroID) { _ in
            renameText = selectedMacro?.name ?? ""
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved Macros")
                .font(.title2.weight(.semibold))
                .padding(.top, 32)
                .padding(.horizontal, 20)

            List(selection: $selectedMacroID) {
                if macroManager.macros.isEmpty {
                    EmptyMacroPlaceholder()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(macroManager.macros) { macro in
                        MacroRow(macro: macro,
                                 isSelected: macro.id == selectedMacroID,
                                 replayAction: { replayer.replay(macro) },
                                 renameAction: { startRenaming(macro) },
                                 deleteAction: { macroManager.remove(macro) })
                            .tag(macro.id)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { offsets in
                        macroManager.remove(at: offsets)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            VStack(alignment: .leading, spacing: 12) {
                Text("Next macro name")
                    .font(.headline)
                TextField("Macro name", text: $recorder.nextMacroName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.trailing, 200)
                    .onSubmit {
                        recorder.nextMacroName = recorder.nextMacroName.trimmingCharacters(in: .whitespaces)
                    }
            }

            HStack(spacing: 18) {
                Button(action: recorder.toggleRecording) {
                    Label(recorder.isRecording ? "Stop" : "Record", systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.headline)
                }
                .buttonStyle(GradientButtonStyle(isDestructive: recorder.isRecording))
                .disabled(recorder.isReplaying)
                .keyboardShortcut(.r, modifiers: [.command, .option])

                Button(action: replaySelected) {
                    Label("Replay Selected", systemImage: "play.circle")
                        .font(.headline)
                }
                .buttonStyle(SubtleButtonStyle())
                .disabled(selectedMacro == nil || recorder.isRecording || recorder.isReplaying)

                Button(action: replayer.togglePlayback) {
                    Label(replayer.isReplaying ? "Stop Playback" : "Replay Latest",
                          systemImage: replayer.isReplaying ? "stop.circle" : "gobackward")
                }
                .buttonStyle(SubtleButtonStyle(isDestructive: replayer.isReplaying))
                .disabled((macroManager.mostRecentMacro == nil && !replayer.isReplaying) || recorder.isRecording)
                .keyboardShortcut(.p, modifiers: [.command, .option])
            }

            Divider()
                .padding(.vertical, 4)

            if let selectedMacro {
                MacroDetailCard(macro: selectedMacro,
                                renameText: $renameText,
                                isRenaming: $isRenaming,
                                renameAction: commitRename,
                                playAction: { replayer.replay(selectedMacro) },
                                deleteAction: { macroManager.remove(selectedMacro) },
                                isReplaying: replayer.isReplaying)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No macro selected")
                        .font(.headline)
                    Text("Pick a macro from the sidebar to see its timeline and quick actions.")
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.15)))
            }

            Spacer()

            footer
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Macro Recorder")
                        .font(.largeTitle.bold())
                    Text("Capture and replay keyboard and mouse flows with a minimalist workspace.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: recorder.status)
            }

            if recorder.status == .permissionDenied {
                PermissionPrompt()
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shortcuts")
                .font(.headline)
            HStack(spacing: 16) {
                ShortcutBadge(icon: "record.circle", title: "Toggle recording", shortcut: "⌘⌥R")
                ShortcutBadge(icon: "play.circle", title: "Replay latest", shortcut: "⌘⌥P")
            }
            Text("Grant Accessibility permissions when prompted so the app can monitor and replay events.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var selectedMacro: RecordedMacro? {
        macroManager.macro(with: selectedMacroID) ?? macroManager.mostRecentMacro
    }

    private func replaySelected() {
        guard let macro = selectedMacro else { return }
        replayer.replay(macro)
    }

    private func commitRename() {
        guard let macro = selectedMacro else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameText = macro.name
            return
        }
        macroManager.rename(macro, to: trimmed)
        renameText = trimmed
        isRenaming = false
    }

    private func startRenaming(_ macro: RecordedMacro) {
        selectedMacroID = macro.id
        renameText = macro.name
        DispatchQueue.main.async {
            isRenaming = true
        }
    }
}

// MARK: - Subviews

private struct EmptyMacroPlaceholder: View {
    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                ContentUnavailableView("No recordings yet",
                                       systemImage: "square.and.pencil",
                                       description: Text("Record a macro to see it listed here."))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("No recordings yet")
                        .font(.title3.weight(.semibold))
                    Text("Record a macro to see it listed here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 36)
            }
        }
    }
}

private struct MacroRow: View {
    let macro: RecordedMacro
    let isSelected: Bool
    let replayAction: () -> Void
    let renameAction: () -> Void
    let deleteAction: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(macro.name)
                    .font(.headline)
                Text(Self.relativeFormatter.localizedString(for: macro.createdAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: replayAction) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(RowIconButtonStyle())

                Button(action: renameAction) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(RowIconButtonStyle())

                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(RowIconButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.3 : 0.1))
        )
        .listRowBackground(Color.clear)
        .contextMenu {
            Button("Replay", action: replayAction)
            Button("Rename", action: renameAction)
            Button("Delete", role: .destructive, action: deleteAction)
        }
    }
}

private struct MacroDetailCard: View {
    let macro: RecordedMacro
    @Binding var renameText: String
    var isRenaming: FocusState<Bool>.Binding
    let renameAction: () -> Void
    let playAction: () -> Void
    let deleteAction: () -> Void
    let isReplaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || renameText == macro.name)
                }
            }

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

            HStack(spacing: 12) {
                Button("Replay Macro", action: playAction)
                    .buttonStyle(GradientButtonStyle(isDestructive: false))
                    .disabled(isReplaying)
                Button("Delete", role: .destructive, action: deleteAction)
                    .buttonStyle(SubtleButtonStyle(isDestructive: true))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.15)))
    }

    private func durationString(for macro: RecordedMacro) -> String {
        let seconds = max(0, macro.duration)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds > 60 ? [.minute, .second] : [.second]
        formatter.unitsStyle = .short
        return formatter.string(from: seconds) ?? "--"
    }
}

private struct StatusBadge: View {
    let status: Recorder.Status

    var body: some View {
        Text(status.description)
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color.opacity(0.2)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.5)))
            .foregroundColor(color)
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
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Accessibility permission is required to record and replay events.")
                .font(.callout)
            Button("Open Settings", action: openAccessibilityPreferences)
                .buttonStyle(SubtleButtonStyle())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.15)))
    }
}

private struct ShortcutBadge: View {
    let icon: String
    let title: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
            Spacer(minLength: 8)
            Text(shortcut)
                .font(.subheadline.monospaced())
        }
        .padding(12)
        .frame(maxWidth: 240)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.15)))
    }
}

private struct GradientButtonStyle: ButtonStyle {
    var isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        GradientButton(configuration: configuration, isDestructive: isDestructive)
    }

    private struct GradientButton: View {
        let configuration: Configuration
        let isDestructive: Bool
        @State private var hovering = false

        var body: some View {
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
                        .stroke(Color.white.opacity(0.2))
                )
                .shadow(color: Color.black.opacity(hovering ? 0.18 : 0.12), radius: hovering ? 12 : 8, x: 0, y: hovering ? 6 : 4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.18), value: hovering)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { hovering in
                    self.hovering = hovering
                }
        }

        private var gradientColors: [Color] {
            if isDestructive {
                return [Color(red: 0.8, green: 0.3, blue: 0.3), Color(red: 0.6, green: 0.1, blue: 0.2)]
            }
            return [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.3, blue: 0.8)]
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

        var body: some View {
            configuration.label
                .padding(.vertical, 10)
                .padding(.horizontal, 22)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(hovering ? 0.15 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.2))
                )
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .shadow(color: Color.black.opacity(hovering ? 0.15 : 0.08), radius: hovering ? 10 : 4, x: 0, y: hovering ? 4 : 2)
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
        configuration.label
            .padding(8)
            .background(
                Circle().fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.2))
            )
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .contentShape(Circle())
    }
}

private func openAccessibilityPreferences() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
    NSWorkspace.shared.open(url)
}

#Preview {
    let manager = MacroManager()
    let recorder = Recorder(macroManager: manager)
    let replayer = Replayer(recorder: recorder, macroManager: manager)
    return MainView()
        .environmentObject(manager)
        .environmentObject(recorder)
        .environmentObject(replayer)
}
