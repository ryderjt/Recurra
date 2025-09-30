# Recurra

<div align="center">

# 🎯 Recurra

**A powerful macOS macro recorder and automation tool built with SwiftUI**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-lightgrey?style=for-the-badge&logo=apple)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge)](./LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen?style=for-the-badge)](https://github.com/ryderjt/Recurra)

*Capture, edit, and replay complex workflows with precision timing*

</div>

---

## 🚀 What is Recurra?

Recurra is a sophisticated macOS application that revolutionizes task automation by providing a beautiful, intuitive interface for recording and replaying keyboard and mouse sequences. Built entirely with SwiftUI, it combines the power of Core Graphics event handling with modern macOS design principles to deliver a seamless automation experience.

### ✨ Key Highlights

- **🎯 Precision Recording**: Captures keyboard and mouse events with millisecond accuracy
- **🎨 Modern Interface**: Beautiful SwiftUI design with gradient backgrounds and smooth animations
- **⚡ Global Hotkeys**: Instant access with customizable keyboard shortcuts
- **📊 Timeline Editor**: Visual timeline for fine-tuning macro timing and events
- **💾 Persistent Storage**: Reliable macro library with JSON-based persistence
- **🔒 Privacy-First**: Local storage only, no data leaves your Mac

## 🎬 Features

### Core Functionality
- **🎛️ Menu Bar Integration**: Quick access from your menu bar with status indicators
- **⌨️ High-Fidelity Recording**: Captures all keyboard events including modifiers and special keys
- **🖱️ Mouse Event Capture**: Records clicks, drags, scrolls, and precise cursor movements
- **▶️ Smart Playback**: Replays macros with original timing or customizable delays
- **⏹️ Safe Cancellation**: Stop recording or playback at any time without system issues

### Advanced Features
- **📁 Macro Library**: Organize, rename, and manage your recorded workflows
- **🎚️ Timeline Editor**: Visual editor for adjusting timing and modifying events
- **⚙️ Customizable Settings**: Adjustable timeline defaults and keyframe snapping
- **🔑 Hotkey Configuration**: Customizable global shortcuts for record/playback
- **♿ Accessibility Integration**: Seamless permission handling and system integration

### User Experience
- **🌙 Dark/Light Mode**: Automatic adaptation to your system appearance
- **📱 Responsive Design**: Optimized for different window sizes and screen configurations
- **🎨 Beautiful UI**: Gradient backgrounds, smooth animations, and modern macOS aesthetics
- **💡 Intuitive Workflow**: Simple record → edit → replay process

## 🛠️ Technical Architecture

### Built With
- **SwiftUI** - Modern declarative UI framework
- **Core Graphics** - Low-level event capture and replay
- **Combine** - Reactive programming and data flow
- **ApplicationServices** - Accessibility and system integration
- **Carbon** - Global hotkey registration

### System Requirements
- **macOS 13.0+** (Ventura or later)
- **Apple Silicon or Intel** Mac
- **Accessibility Permissions** (automatically requested)

## 🚀 Getting Started

### Quick Start
1. **Download** the latest release from the [Releases page](../../releases)
2. **Install** by dragging Recurra.app to your Applications folder
3. **Launch** and grant Accessibility permissions when prompted
4. **Record** your first macro using `⌘⌥R` or the Record button
5. **Replay** using `⌘⌥P` or the Replay button

### Building from Source
```bash
# Clone the repository
git clone https://github.com/ryderjt/Recurra.git
cd Recurra

# Open in Xcode
open Recurra.xcodeproj

# Build and run (⌘R)
```

### Development Setup
1. **Xcode 15.0+** required
2. **Configure signing** with your Apple Developer account
3. **Review entitlements** in `Recurra.entitlements`
4. **Build & run** to test functionality

## 📖 Usage Guide

### Recording Macros
1. **Name your macro** in the text field
2. **Press Record** or use `⌘⌥R` to start recording
3. **Perform your actions** (click, type, navigate)
4. **Press Stop** or use `⌘⌥R` again to finish

### Editing Macros
1. **Select a macro** from the library sidebar
2. **Use the timeline editor** to adjust timing
3. **Add/remove keyframes** as needed
4. **Save changes** to update the macro

### Global Hotkeys
- **`⌘⌥R`** - Toggle recording (default)
- **`⌘⌥P`** - Replay latest macro (default)
- **Customizable** in Settings

## 🎯 Use Cases

### Productivity
- **Form Automation**: Fill out repetitive forms quickly
- **Text Expansion**: Create complex text snippets with formatting
- **Navigation Shortcuts**: Automate common UI navigation patterns
- **Data Entry**: Streamline repetitive data input tasks

### Development
- **Testing Workflows**: Automate UI testing sequences
- **Code Generation**: Create templates and boilerplate
- **Debugging**: Reproduce specific user interactions
- **Demo Preparation**: Create consistent demo sequences

### Creative Work
- **Design Workflows**: Automate repetitive design tasks
- **Content Creation**: Streamline content production processes
- **File Organization**: Batch file operations and organization
- **Presentation Prep**: Automate slide creation and formatting

## 🔧 Configuration

### Settings Panel
Access via the gear icon in the main interface:

- **Timeline Defaults**: Set default duration for new macros
- **Keyframe Snapping**: Enable/disable timing snap intervals
- **Hotkey Configuration**: Customize global shortcuts
- **Accessibility**: Manage system permissions

### File Locations
- **Macros**: `~/Library/Application Support/Recurra/macros.json`
- **Settings**: Stored in UserDefaults
- **Logs**: Available in Console.app under "Recurra"

## ⚠️ Known Limitations

- **Secure Applications**: Some apps (banking, security) may block synthetic events
- **Permission Requirements**: Requires Accessibility permissions for full functionality
- **System Events**: Cannot record system-level events outside of user input
- **Timing Sensitivity**: Very fast actions may need manual timing adjustment

## 🛣️ Roadmap

### Completed ✅
- [x] Core recording and playback functionality
- [x] SwiftUI interface with modern design
- [x] Macro library with management features
- [x] Global hotkey support
- [x] Timeline editor for macro editing
- [x] Persistent storage system
- [x] Settings and configuration panel

### In Progress 🚧
- [ ] Macro sharing and export features
- [ ] Advanced timeline editing tools
- [ ] Macro templates and presets
- [ ] Performance optimizations

### Planned 📋
- [ ] Cloud sync capabilities
- [ ] Macro marketplace
- [ ] Advanced scripting support
- [ ] Multi-monitor support improvements

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Maintain consistent naming conventions
- Include documentation for public APIs

## 📄 License

Recurra is released under the [GNU General Public License v3.0](./LICENSE).

## 🙏 Acknowledgments

- **Apple** for SwiftUI and Core Graphics frameworks
- **macOS Community** for inspiration and feedback
- **Open Source Contributors** who make projects like this possible

---

<div align="center">

**Made with ❤️ for the macOS community**

[Report Bug](../../issues) · [Request Feature](../../issues) · [Join Discussion](../../discussions)

</div>
