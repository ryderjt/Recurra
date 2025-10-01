import SwiftUI
import AppKit
import Carbon.HIToolbox

extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
}

enum AppSettingsKey {
    static let defaultTimelineDuration = "settings.defaultTimelineDuration"
    static let keyframeSnapEnabled = "settings.keyframeSnapEnabled"
    static let keyframeSnapInterval = "settings.keyframeSnapInterval"
    static let recordingHotkeyKeyCode = "settings.recordingHotkeyKeyCode"
    static let recordingHotkeyModifiers = "settings.recordingHotkeyModifiers"
    static let recordingHotkeyKeyEquivalent = "settings.recordingHotkeyKeyEquivalent"
    static let playbackHotkeyKeyCode = "settings.playbackHotkeyKeyCode"
    static let playbackHotkeyModifiers = "settings.playbackHotkeyModifiers"
    static let playbackHotkeyKeyEquivalent = "settings.playbackHotkeyKeyEquivalent"
    static let playSelectedHotkeyKeyCode = "settings.playSelectedHotkeyKeyCode"
    static let playSelectedHotkeyModifiers = "settings.playSelectedHotkeyModifiers"
    static let playSelectedHotkeyKeyEquivalent = "settings.playSelectedHotkeyKeyEquivalent"
    static let stopMacroHotkeyKeyCode = "settings.stopMacroHotkeyKeyCode"
    static let stopMacroHotkeyModifiers = "settings.stopMacroHotkeyModifiers"
    static let stopMacroHotkeyKeyEquivalent = "settings.stopMacroHotkeyKeyEquivalent"
}

struct MainView: View {
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var replayer: Replayer
    @EnvironmentObject private var macroManager: MacroManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedMacroID: RecordedMacro.ID?
    @State private var renameText: String = ""
    @FocusState private var isRenaming: Bool
    @State private var isShowingPermissionSheet = false
    @State private var isShowingSettings = false
    @State private var permissionMonitor: Timer?
    @State private var sidebarWidth: CGFloat = 320

    private var palette: Palette { Palette(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            palette.backgroundGradient
                .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)
                    .background(palette.sidebarGradient)
                
                // Draggable divider
                ResizableDivider(
                    width: $sidebarWidth,
                    minWidth: 200,
                    maxWidth: 500,
                    palette: palette
                )

                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 920, minHeight: 560)
        .onAppear {
            if selectedMacroID == nil {
                selectedMacroID = macroManager.mostRecentMacro?.id
            }
            renameText = selectedMacro?.name ?? ""
            presentPermissionIfNeeded()
        }
        .onChange(of: macroManager.macros) { macros in
            guard !macros.isEmpty else {
                selectedMacroID = nil
                renameText = ""
                return
            }
            // Only auto-select if no macro is currently selected
            if selectedMacroID == nil {
                selectedMacroID = macros.first?.id
            }
        }
        .onChange(of: selectedMacroID) { _ in
            renameText = selectedMacro?.name ?? ""
        }
        .onChange(of: recorder.status) { status in
            if status == .permissionDenied {
                isShowingPermissionSheet = true
            }
        }
        .onChange(of: isShowingPermissionSheet) { isPresented in
            if isPresented {
                startMonitoringAccessibilityPermission()
            } else {
                stopMonitoringAccessibilityPermission()
            }
        }
        .sheet(isPresented: $isShowingPermissionSheet, onDismiss: handlePermissionSheetDismissal) {
            PermissionRequestView(onGrant: handleGrantPermission,
                                   onClose: handlePermissionSheetDismissal)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .background(
            // Hidden button for stop macro keyboard shortcut
            Button("Stop Macro", action: stopMacro)
                .keyboardShortcut(stopMacroKeyboardShortcut)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 8) {
                Text("Library")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Organize, rename, and play your recorded flows.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 34)

            Button(action: createCustomMacro) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Blank Macro")
                }
            }
            .buttonStyle(SubtleButtonStyle())
            .help("Create an empty macro that you can manually build with the timeline editor")
            .frame(maxWidth: .infinity, alignment: .center)

            List {
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
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                selectedMacroID = macro.id
                            }
                    }
                    .onDelete { offsets in
                        macroManager.remove(at: offsets)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                controlsCard

                if let selectedMacro {
                    MacroDetailCard(macro: selectedMacro,
                                    renameText: $renameText,
                                    isRenaming: $isRenaming,
                                    renameAction: commitRename,
                                    playAction: { replayer.replay(selectedMacro) },
                                    deleteAction: { macroManager.remove(selectedMacro) },
                                    isReplaying: replayer.isReplaying,
                                    saveTimelineAction: { updated in
                                        macroManager.update(updated)
                                        // Ensure the updated macro remains selected
                                        selectedMacroID = updated.id
                                    },
                                    macroManager: macroManager)
                } else {
                    emptySelectionCard
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    RecurraLogo()
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recurra")
                            .font(.largeTitle.bold())
                        Text("Capture and replay keyboard and mouse flows with a minimalist workspace.")
                            .foregroundStyle(.secondary)
                        Text("by ryderjt")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }

                Spacer()
                Button {
                    isShowingSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)

                StatusBadge(status: recorder.status)
            }

            if recorder.status == .permissionDenied {
                PermissionPrompt(primaryAction: {
                    isShowingPermissionSheet = true
                })
            }
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header section with clear title and description
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    Text("Create New Macro")
                        .font(.title3.weight(.semibold))
                }
                
                Text("Record keyboard and mouse actions to create reusable macros.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Macro creation section with improved layout
            VStack(alignment: .leading, spacing: 16) {
                // Step 1: Name your macro
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name your macro")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        TextField("Enter macro name...", text: $recorder.nextMacroName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)
                            .onSubmit {
                                recorder.nextMacroName = recorder.nextMacroName.trimmingCharacters(in: .whitespaces)
                            }
                        
                        if !recorder.nextMacroName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        }
                    }
                }
                
                // Step 2: Record your macro
                VStack(alignment: .leading, spacing: 8) {
                    Text(recorder.isRecording ? "Recording in progress..." : "Record your actions")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(action: recorder.toggleRecording) {
                            HStack(spacing: 8) {
                                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                                    .font(.title3)
                                Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(GradientButtonStyle(isDestructive: recorder.isRecording))
                        .disabled(recorder.isReplaying)
                        .keyboardShortcut("r", modifiers: [.command, .option])
                        .help(recorder.isRecording ? "Stop recording your macro" : "Start recording keyboard and mouse actions")
                        
                        if recorder.isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(recorder.isRecording ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recorder.isRecording)
                                Text("Recording...")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            
            // Quick actions section
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)
                
                Text("Quick Actions")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Button(action: replaySelected) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle")
                            Text("Play Selected")
                        }
                    }
                    .buttonStyle(SubtleButtonStyle())
                    .disabled(selectedMacro == nil || recorder.isRecording || recorder.isReplaying)
                    .keyboardShortcut(playSelectedKeyboardShortcut)
                    .help("Play the currently selected macro from the library")
                    
                    Button(action: replayer.togglePlayback) {
                        HStack(spacing: 6) {
                            Image(systemName: replayer.isReplaying ? "stop.circle" : "gobackward")
                            Text(replayer.isReplaying ? "Stop Latest" : "Play Latest")
                        }
                    }
                    .buttonStyle(SubtleButtonStyle(isDestructive: replayer.isReplaying))
                    .disabled((macroManager.mostRecentMacro == nil && !replayer.isReplaying) || recorder.isRecording)
                    .keyboardShortcut("p", modifiers: [.command, .option])
                    .help(replayer.isReplaying ? "Stop the currently playing macro" : "Play the most recently created macro")
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .cardBackground()
    }
    
    private var statusColor: Color {
        if recorder.isRecording {
            return .red
        }
        if replayer.isReplaying {
            return .blue
        }
        if selectedMacro != nil {
            return .green
        }
        return .secondary
    }

    private var emptySelectionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if macroManager.macros.isEmpty {
                // First-time user guidance
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                            .font(.title2)
                        Text("Welcome to Recurra!")
                            .font(.title2.weight(.semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Get started by creating your first macro:")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("1.")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 16)
                                Text("Enter a name for your macro above")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("2.")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 16)
                                Text("Click 'Start Recording' and perform your actions")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("3.")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 16)
                                Text("Click 'Stop Recording' when finished")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                        
                        Text("Your macro will appear in the library and can be replayed anytime!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            } else {
                // User has macros but none selected
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "sidebar.left")
                            .foregroundStyle(.blue)
                            .font(.title2)
                        Text("No macro selected")
                            .font(.title2.weight(.semibold))
                    }
                    
                    Text("Choose a macro from the library to view its details, timeline, and playback options.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let mostRecentMacro = macroManager.mostRecentMacro {
                        Button(action: { selectedMacroID = mostRecentMacro.id }) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Select most recent: \(mostRecentMacro.name)")
                            }
                        }
                        .buttonStyle(SubtleButtonStyle())
                    }
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: 24)
    }

    private var statusMessage: String {
        if recorder.isRecording {
            return "Recording in progress"
        }
        if replayer.isReplaying {
            return "Playing latest macro"
        }
        if let selectedMacro {
            return "Selected: \(selectedMacro.name)"
        }
        return "Select a macro to play"
    }

    private var statusIcon: String {
        if recorder.isRecording {
            return "record.circle"
        }
        if replayer.isReplaying {
            return "play.circle"
        }
        if selectedMacro != nil {
            return "checkmark.circle"
        }
        return "sidebar.left"
    }

    private var selectedMacro: RecordedMacro? {
        macroManager.macro(with: selectedMacroID) ?? macroManager.mostRecentMacro
    }

    private var playSelectedKeyboardShortcut: KeyboardShortcut {
        let defaults = UserDefaults.standard
        let keyEquivalent = defaults.string(forKey: AppSettingsKey.playSelectedHotkeyKeyEquivalent) ?? "s"
        let modifiers = UInt32(defaults.integer(forKey: AppSettingsKey.playSelectedHotkeyModifiers))

        var eventModifiers: SwiftUI.EventModifiers = []
        if modifiers & UInt32(controlKey) != 0 { eventModifiers.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { eventModifiers.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { eventModifiers.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { eventModifiers.insert(.command) }

        guard let character = keyEquivalent.first else {
            return KeyboardShortcut("s", modifiers: [.command, .option])
        }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }

    private var stopMacroKeyboardShortcut: KeyboardShortcut {
        let defaults = UserDefaults.standard
        let keyEquivalent = defaults.string(forKey: AppSettingsKey.stopMacroHotkeyKeyEquivalent) ?? "escape"
        let modifiers = UInt32(defaults.integer(forKey: AppSettingsKey.stopMacroHotkeyModifiers))

        var eventModifiers: SwiftUI.EventModifiers = []
        if modifiers & UInt32(controlKey) != 0 { eventModifiers.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { eventModifiers.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { eventModifiers.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { eventModifiers.insert(.command) }

        guard let character = keyEquivalent.first else {
            return KeyboardShortcut(.escape, modifiers: [.command, .option])
        }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }

    private func createCustomMacro() {
        let macro = macroManager.createCustomMacro()
        selectedMacroID = macro.id
        renameText = macro.name
    }

    private func replaySelected() {
        guard let macro = selectedMacro else { return }
        replayer.replay(macro)
    }

    private func stopMacro() {
        if replayer.isReplaying {
            replayer.stop()
        }
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

    private func presentPermissionIfNeeded() {
        if !AccessibilityPermission.isTrusted() {
            recorder.markPermissionDenied()
            isShowingPermissionSheet = true
        }
    }

    private func handleGrantPermission() {
        AccessibilityPermission.requestPermission()
        _ = AccessibilityPermission.openSystemSettings()
        if AccessibilityPermission.isTrusted() {
            recorder.markIdle()
            isShowingPermissionSheet = false
        }
    }

    private func handlePermissionSheetDismissal() {
        if AccessibilityPermission.isTrusted() {
            recorder.markIdle()
            isShowingPermissionSheet = false
        } else {
            recorder.markPermissionDenied()
        }
    }

    private func startMonitoringAccessibilityPermission() {
        stopMonitoringAccessibilityPermission()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if AccessibilityPermission.isTrusted() {
                timer.invalidate()
                permissionMonitor = nil
                recorder.markIdle()
                isShowingPermissionSheet = false
            }
        }
        timer.tolerance = 0.1
        permissionMonitor = timer
    }

    private func stopMonitoringAccessibilityPermission() {
        permissionMonitor?.invalidate()
        permissionMonitor = nil
    }
}

// MARK: - Subviews

private struct ResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let palette: Palette
    
    @State private var isDragging = false
    @State private var isHovering = false
    
    var body: some View {
        Rectangle()
            .fill(palette.sidebarDivider)
            .frame(width: 1)
            .background(
                // Invisible wider area for easier dragging
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
                    .contentShape(Rectangle())
            )
            .overlay(
                // Visual indicator when dragging
                Rectangle()
                    .fill(Color.accentColor.opacity(isDragging ? 0.6 : 0.3))
                    .frame(width: 2)
                    .opacity(isDragging ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        
                        let newWidth = width + value.translation.width
                        let clampedWidth = max(minWidth, min(maxWidth, newWidth))
                        width = clampedWidth
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .ignoresSafeArea(edges: .vertical)
    }
}

private struct EmptyMacroPlaceholder: View {
    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                ContentUnavailableView(
                    "No macros yet",
                    systemImage: "plus.circle",
                    description: Text("Create your first macro using the controls on the right.")
                )
                .symbolEffect(.pulse, isActive: true)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.blue.opacity(0.6))

                    VStack(spacing: 8) {
                        Text("No macros yet")
                            .font(.title3.weight(.semibold))
                        Text("Create your first macro using the controls on the right.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 220)
                        
                        Text("💡 Tip: Give your macro a descriptive name first!")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                            .padding(.top, 4)
                    }
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

    @Environment(\.colorScheme) private var colorScheme

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        let palette = Palette(colorScheme: colorScheme)

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
                .fill(isSelected ? palette.rowSelectionFill : palette.rowBaseFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? palette.rowSelectionStroke : palette.rowBaseStroke)
        )
        .listRowBackground(Color.clear)
        .contextMenu {
            Button("Play", action: replayAction)
            Button("Rename", action: renameAction)
            Button("Delete", role: .destructive, action: deleteAction)
        }
    }
}


private struct HotkeyPicker: View {
    let title: String
    let description: String
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @Binding var keyEquivalent: String
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var displayString: String {
        var result = ""
        let modFlags = UInt32(modifiers)
        if modFlags & UInt32(controlKey) != 0 { result += "⌃" }
        if modFlags & UInt32(optionKey) != 0 { result += "⌥" }
        if modFlags & UInt32(shiftKey) != 0 { result += "⇧" }
        if modFlags & UInt32(cmdKey) != 0 { result += "⌘" }
        result += keyEquivalent.uppercased()
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button(action: startRecording) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "keyboard")
                        Text(isRecording ? "Press keys..." : displayString)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(isRecording)

                if !isRecording {
                    Button("Reset") {
                        keyCode = Int(kVK_ANSI_R)
                        modifiers = Int(cmdKey | optionKey)
                        keyEquivalent = "r"
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let deviceIndependent = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let modifierSubset = deviceIndependent.intersection([.command, .option, .control, .shift])
            let primaryModifiers = modifierSubset.intersection([.command, .option, .control])
            guard !primaryModifiers.isEmpty else { return nil }

            guard let characters = event.charactersIgnoringModifiers, let first = characters.first else {
                return nil
            }

            let uppercase = String(first).uppercased()
            guard let scalar = uppercase.unicodeScalars.first,
                  CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) else {
                return nil
            }

            var carbonModifiers: UInt32 = 0
            if modifierSubset.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
            if modifierSubset.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if modifierSubset.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            if modifierSubset.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

            keyCode = Int(event.keyCode)
            modifiers = Int(carbonModifiers)
            keyEquivalent = uppercase.lowercased()

            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppSettingsKey.defaultTimelineDuration) private var defaultTimelineDuration = 3.0
    @AppStorage(AppSettingsKey.keyframeSnapEnabled) private var isKeyframeSnappingEnabled = true
    @AppStorage(AppSettingsKey.keyframeSnapInterval) private var keyframeSnapInterval = 0.05

    // Hotkey settings
    @AppStorage(AppSettingsKey.recordingHotkeyKeyCode) private var recordingKeyCode = Int(kVK_ANSI_R)
    @AppStorage(AppSettingsKey.recordingHotkeyModifiers) private var recordingModifiers = Int(cmdKey | optionKey)
    @AppStorage(AppSettingsKey.recordingHotkeyKeyEquivalent) private var recordingKeyEquivalent = "r"
    @AppStorage(AppSettingsKey.playbackHotkeyKeyCode) private var playbackKeyCode = Int(kVK_ANSI_P)
    @AppStorage(AppSettingsKey.playbackHotkeyModifiers) private var playbackModifiers = Int(cmdKey | optionKey)
    @AppStorage(AppSettingsKey.playbackHotkeyKeyEquivalent) private var playbackKeyEquivalent = "p"

    var body: some View {
        let palette = Palette(colorScheme: colorScheme)

        ZStack {
            palette.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    RecurraLogo()
                        .frame(width: 64, height: 64)
                }

                Text("Settings")
                    .font(.title2.weight(.semibold))

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Timeline Defaults")
                            .font(.headline)
                        Text("Set the starting length used when editing a macro without keyframes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            TextField("Seconds",
                                      value: $defaultTimelineDuration,
                                      format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Stepper(value: $defaultTimelineDuration, in: 0.5...120, step: 0.25) {
                                Text("\(defaultTimelineDuration, format: .number.precision(.fractionLength(2))) s")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Keyframe Editing")
                            .font(.headline)
                        Toggle("Snap keyframes to interval", isOn: $isKeyframeSnappingEnabled)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Snap interval: \(keyframeSnapInterval, format: .number.precision(.fractionLength(2))) s")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Slider(value: $keyframeSnapInterval, in: 0.01...1.0, step: 0.01)
                                .disabled(!isKeyframeSnappingEnabled)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Keyboard Shortcuts")
                            .font(.headline)

                        HotkeyPicker(
                            title: "Recording",
                            description: "Start or stop recording a macro",
                            keyCode: $recordingKeyCode,
                            modifiers: $recordingModifiers,
                            keyEquivalent: $recordingKeyEquivalent
                        )
                        .onChange(of: recordingKeyCode) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: recordingModifiers) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: recordingKeyEquivalent) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }

                        HotkeyPicker(
                            title: "Playback",
                            description: "Replay the most recent macro",
                            keyCode: $playbackKeyCode,
                            modifiers: $playbackModifiers,
                            keyEquivalent: $playbackKeyEquivalent
                        )
                        .onChange(of: playbackKeyCode) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: playbackModifiers) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: playbackKeyEquivalent) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                    }
                }

                VStack(spacing: 12) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(GradientButtonStyle(isDestructive: false))
                    
                    Text("Made with ❤️ by ryderjt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(36)
            .frame(maxWidth: 480)
            .cardBackground(cornerRadius: 28)
        }
        .onChange(of: defaultTimelineDuration) { newValue in
            let clamped = Self.clampDuration(newValue)
            if clamped != newValue {
                defaultTimelineDuration = clamped
            }
        }
        .onChange(of: keyframeSnapInterval) { newValue in
            let clamped = Self.clampSnapInterval(newValue)
            if clamped != newValue {
                keyframeSnapInterval = clamped
            }
        }
    }

    private static func clampDuration(_ value: Double) -> Double {
        guard value.isFinite else { return 3 }
        return min(max(value, 0.5), 120)
    }

    private static func clampSnapInterval(_ value: Double) -> Double {
        guard value.isFinite else { return 0.05 }
        return min(max(value, 0.01), 1.0)
    }
}

// MARK: - Macro Detail Components

struct MacroDetailCard: View {
    let macro: RecordedMacro
    @Binding var renameText: String
    var isRenaming: FocusState<Bool>.Binding
    let renameAction: () -> Void
    let playAction: () -> Void
    let deleteAction: () -> Void
    let isReplaying: Bool
    let saveTimelineAction: (RecordedMacro) -> Void
    let macroManager: MacroManager

    @State private var timelineDraft: MacroTimelineDraft
    @State private var selectedKeyframeID: UUID?
    @State private var isAutoSaving = false
    @State private var suppressTimelineChange = false
    @State private var suppressTimelineReset = false
    @State private var timelineErrorMessage: String?
    @State private var lastAutoSaveTime: Date?
    @State private var autoSaveTask: Task<Void, Never>?
    @AppStorage(AppSettingsKey.defaultTimelineDuration) private var defaultTimelineDuration = 3.0

    init(macro: RecordedMacro,
         renameText: Binding<String>,
         isRenaming: FocusState<Bool>.Binding,
         renameAction: @escaping () -> Void,
         playAction: @escaping () -> Void,
         deleteAction: @escaping () -> Void,
         isReplaying: Bool,
         saveTimelineAction: @escaping (RecordedMacro) -> Void,
         macroManager: MacroManager) {
        self.macro = macro
        self._renameText = renameText
        self.isRenaming = isRenaming
        self.renameAction = renameAction
        self.playAction = playAction
        self.deleteAction = deleteAction
        self.isReplaying = isReplaying
        self.saveTimelineAction = saveTimelineAction
        self.macroManager = macroManager
        let baselineDuration = MacroDetailCard.resolveDefaultTimelineDuration()
        _timelineDraft = State(initialValue: MacroTimelineDraft(macro: macro,
                                                               minimumDuration: baselineDuration))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            renameSection

            summaryRow

            actionButtons

            loopSettings

            Divider()

            MacroTimelineEditor(draft: $timelineDraft, selection: $selectedKeyframeID)
                .onChange(of: timelineDraft) { newDraft in
                    guard !suppressTimelineChange else {
                        suppressTimelineChange = false
                        return
                    }
                    
                    // Auto-save changes after a brief delay
                    autoSaveTimeline()
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
            guard !suppressTimelineReset else { return }
            applyTimeline(from: macro)
        }
        .onChange(of: macro.duration) { _ in
            guard !suppressTimelineReset else { return }
            applyTimeline(from: macro)
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
            guard timelineDraft.keyframes.isEmpty else { return }
            let target = MacroDetailCard.resolveDefaultTimelineDuration(from: newValue)
            timelineDraft.duration = max(timelineDraft.duration, target)
        }
        .onDisappear {
            // Cancel any pending auto-save when view disappears
            autoSaveTask?.cancel()
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
            Button("Play Macro", action: playAction)
                .buttonStyle(GradientButtonStyle(isDestructive: false))
                .disabled(isReplaying)
            Button("Delete", role: .destructive, action: deleteAction)
                .buttonStyle(SubtleButtonStyle(isDestructive: true))
        }
    }

    private var loopSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Loop Settings")
                .font(.headline)
            HStack(spacing: 10) {
                TextField("Loop count", value: Binding(
                    get: { macro.loopCount },
                    set: { newValue in
                        macroManager.updateLoopCount(macro, to: newValue)
                    }
                ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("times")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text("Set to 0 for infinite loops")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timelineFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if isAutoSaving {
                    Label("Saving...", systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.blue)
                } else if let lastSave = lastAutoSaveTime {
                    Label("Saved \(lastSave.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                } else {
                    Text("Keyframes: \(timelineDraft.keyframes.count) • " +
                         "Duration: \(String(format: "%.2fs", timelineDraft.duration))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func autoSaveTimeline() {
        // Cancel any existing auto-save task
        autoSaveTask?.cancel()
        
        // Create a new debounced auto-save task
        autoSaveTask = Task {
            // Wait for 1 second before auto-saving
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await performAutoSave()
        }
    }
    
    @MainActor
    private func performAutoSave() async {
        guard !isAutoSaving else { return }
        
        do {
            let updatedMacro = try timelineDraft.buildMacro(from: macro)
            isAutoSaving = true
            suppressTimelineReset = true
            
            saveTimelineAction(updatedMacro)
            lastAutoSaveTime = Date()
            
            // Reset the saving state after a brief delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            isAutoSaving = false
            
            // Reset the suppress flag after auto-save completes
            suppressTimelineReset = false
        } catch {
            timelineErrorMessage = error.localizedDescription
            isAutoSaving = false
            suppressTimelineReset = false
        }
    }

    private func applyTimeline(from macro: RecordedMacro) {
        suppressTimelineChange = true
        let baselineDuration = MacroDetailCard.resolveDefaultTimelineDuration(from: defaultTimelineDuration)
        timelineDraft = MacroTimelineDraft(macro: macro, minimumDuration: baselineDuration)
        selectedKeyframeID = nil
        isAutoSaving = false
        lastAutoSaveTime = Date()
        suppressTimelineReset = false
        
        // Reset the suppress flag after a brief delay to ensure all updates are processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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

extension MacroDetailCard {
    static func resolveDefaultTimelineDuration(from value: Double? = nil) -> TimeInterval {
        if let value {
            return max(0.5, min(value, 120))
        }
        let stored = UserDefaults.standard.double(forKey: AppSettingsKey.defaultTimelineDuration)
        return stored > 0 ? max(0.5, min(stored, 120)) : 3.0
    }
}

// MARK: - UI Components

struct GradientButtonStyle: ButtonStyle {
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

struct SubtleButtonStyle: ButtonStyle {
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

struct RowIconButtonStyle: ButtonStyle {
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

extension View {
    func cardBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}

struct CardBackground: ViewModifier {
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

struct RecurraLogo: View {
    var body: some View {
        Image("BasicIconWhite")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
    }
}

struct StatusBadge: View {
    let status: Recorder.Status

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(status.description)
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.5))
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

struct PermissionPrompt: View {
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

struct PermissionRequestView: View {
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

// MARK: - Palette

struct Palette {
    let colorScheme: ColorScheme
    
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }

    var backgroundGradient: LinearGradient {
        return LinearGradient(colors: [
            Color(red: 0.07, green: 0.08, blue: 0.11),
            Color(red: 0.03, green: 0.04, blue: 0.07)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var sidebarGradient: LinearGradient {
        return LinearGradient(colors: [
            Color(red: 0.08, green: 0.09, blue: 0.13),
            Color(red: 0.05, green: 0.06, blue: 0.09)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var sidebarDivider: Color {
        Color.white.opacity(0.1)
    }

    var cardFill: Color {
        Color.white.opacity(0.08)
    }

    var cardStroke: Color {
        Color.white.opacity(0.16)
    }

    var rowBaseFill: Color {
        Color.white.opacity(0.05)
    }

    var rowBaseStroke: Color {
        Color.white.opacity(0.1)
    }

    var rowSelectionFill: Color {
        Color.accentColor.opacity(0.32)
    }

    var rowSelectionStroke: Color {
        Color.accentColor.opacity(0.5)
    }

    var primaryGradientColors: [Color] {
        return [
            Color(red: 0.35, green: 0.68, blue: 1.0),
            Color(red: 0.18, green: 0.42, blue: 0.96)
        ]
    }

    var destructiveGradientColors: [Color] {
        return [
            Color(red: 0.95, green: 0.34, blue: 0.36),
            Color(red: 0.74, green: 0.16, blue: 0.24)
        ]
    }

    func buttonStroke(isDestructive: Bool) -> Color {
        if isDestructive {
            return Color.red.opacity(0.45)
        }
        return Color.white.opacity(0.25)
    }

    func buttonShadow(isDestructive: Bool, hovering: Bool) -> Color {
        let base = isDestructive ? Color.red : Color.accentColor
        return base.opacity(hovering ? 0.42 : 0.28)
    }

    func subtleFill(hovering: Bool) -> Color {
        return Color.white.opacity(hovering ? 0.18 : 0.12)
    }

    var subtleStroke: Color {
        Color.white.opacity(0.16)
    }

    func subtleShadow(hovering: Bool) -> Color {
        return Color.black.opacity(hovering ? 0.32 : 0.2)
    }

    func rowButtonFill(isPressed: Bool) -> Color {
        return Color.white.opacity(isPressed ? 0.22 : 0.12)
    }

    var rowButtonStroke: Color {
        Color.white.opacity(0.2)
    }
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





