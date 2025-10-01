# Recurra

**A lightweight macOS macro recorder and automation tool built with SwiftUI**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-lightgrey?style=for-the-badge&logo=apple)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey?style=for-the-badge)](./LICENSE)

Capture, edit, and replay complex workflows with precision timing.

## What is Recurra?

Recurra is a macOS application that provides an intuitive interface for recording and replaying keyboard and mouse sequences. Built with SwiftUI, it combines Core Graphics event handling with modern macOS design to deliver seamless automation.

### Key Features

- **Precision Recording**: Captures keyboard and mouse events with millisecond accuracy
- **Modern Interface**: Beautiful SwiftUI design with smooth animations
- **Global Hotkeys**: Instant access with customizable keyboard shortcuts
- **Timeline Editor**: Visual timeline for fine-tuning macro timing
- **Persistent Storage**: Reliable macro library with JSON-based persistence
- **Privacy-First**: Local storage only, no data leaves your Mac

## Features

- **Menu Bar Integration**: Quick access from your menu bar with status indicators
- **High-Fidelity Recording**: Captures all keyboard events including modifiers and special keys
- **Mouse Event Capture**: Records clicks, drags, scrolls, and precise cursor movements
- **Smart Playback**: Replays macros with original timing or customizable delays
- **Macro Library**: Organize, rename, and manage your recorded workflows
- **Timeline Editor**: Visual editor for adjusting timing and modifying events
- **Customizable Settings**: Adjustable timeline defaults and keyframe snapping
- **Hotkey Configuration**: Customizable global shortcuts for record/playback
- **Dark Mode**: Beautiful dark interface optimized for productivity

## Technical Details

**Built With**: SwiftUI, Core Graphics, Combine, ApplicationServices, Carbon

**System Requirements**: macOS 13.0+ (Ventura or later), Apple Silicon or Intel Mac, Accessibility Permissions

## Getting Started

### Installation & Setup

**Note**: This app is currently unsigned due to cost constraints. Follow these steps to open it:

1. **Download** the latest release from the [Releases page](../../releases)
2. **Install** by dragging Recurra.app to your Applications folder
3. **Open System Settings** → **Privacy & Security**
4. **Scroll down** to find "Recurra" in the blocked apps section
5. **Click "Allow Anyway"** next to Recurra
6. **Try opening Recurra again** - you may need to repeat step 5 once more
7. **Grant Accessibility permissions** when prompted
8. **Start recording** your first macro using `⌘⌥R` or the Record button

### Building from Source
```bash
git clone https://github.com/ryderjt/Recurra.git
cd Recurra
open Recurra.xcodeproj
# Build and run (⌘R)
```

## How to Use

### Recording Macros
1. Name your macro in the text field
2. Press Record or use `⌘⌥R` to start recording
3. Perform your actions (click, type, navigate)
4. Press Stop or use `⌘⌥R` again to finish

### Playing Macros
1. Select a macro from the library sidebar
2. Play selected macro using `⌘⌥S` or the "Play Selected" button
3. Play latest macro using `⌘⌥P` or the "Play Latest" button
4. Stop any playing macro using `⌘⌥Esc`

### Editing Macros
1. Select a macro from the library sidebar
2. Use the timeline editor to adjust timing
3. Add/remove keyframes as needed
4. Save changes to update the macro

### Global Hotkeys
- `⌘⌥R` - Toggle recording (default)
- `⌘⌥P` - Play latest macro (default)
- `⌘⌥S` - Play selected macro (default)
- `⌘⌥Esc` - Stop any playing macro (default)
- Customizable in Settings

## Configuration

**Settings Panel**: Access via the gear icon in the main interface
- Timeline Defaults, Keyframe Snapping, Hotkey Configuration, Accessibility

**File Locations**:
- Macros: `~/Library/Application Support/Recurra/macros.json`
- Settings: Stored in UserDefaults
- Logs: Available in Console.app under "Recurra"

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

**Development Setup**:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

**Code Style**: Follow Swift API Design Guidelines and SwiftUI best practices

## License

Recurra is released under the [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](./LICENSE).

---

**Made with ❤️ by ryderjt**

[Report Bug](../../issues) · [Request Feature](../../issues) · [Join Discussion](../../discussions)
