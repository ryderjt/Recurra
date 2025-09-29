# MacroRecorder

*A sleek macOS app that records and replays your exact keystrokes and mouse actions, making automation seamless for writing, gaming, and everyday tasks.*

<p align="center">
  <img src="https://img.shields.io/badge/build-passing-brightgreen" alt="Build Status" />
  <img src="https://img.shields.io/badge/license-GPLv3-blue" alt="License" />
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift Version" />
  <img src="https://img.shields.io/badge/platform-macOS%2013+-lightgrey" alt="Platform" />
</p>

<p align="center">
  <img src="https://via.placeholder.com/960x540.png?text=Macro+Recorder+Gradient+UI" alt="Gradient macro recorder UI preview" width="640" />
</p>

## Overview

MacroRecorder lays the groundwork for a modern SwiftUI desktop application that can capture low-level keyboard and mouse events using `CGEventTap`, then replay them with precision. This repository provides a clean starting point for further development, packaging, and distribution as a DMG installer.

## Project Structure

```
MacroRecorder/
├─ MacroRecorder.xcodeproj/        # Xcode project configuration
├─ MacroRecorder/
│  ├─ App.swift                    # SwiftUI entry point
│  ├─ ContentView.swift            # Gradient SwiftUI interface & navigation
│  ├─ Recorder.swift               # CGEventTap recorder & macro library
│  ├─ Replayer.swift               # Timed playback engine and hotkeys
│  └─ Info.plist                   # Accessibility permission descriptions
├─ LICENSE                         # GPLv3 license
└─ README.md
```

## Features

- ✨ Minimalist gradient UI with a split sidebar and responsive controls.
- ⌨️ Captures keyboard and mouse activity via `CGEventTap` with precise timing.
- 📚 Macro library with timestamps, inline actions to replay or delete, and detail cards.
- ⏱️ Playback engine that replays events at the recorded cadence.
- ⌘ Global hotkeys (`⌘⌥R` to toggle recording, `⌘⌥P` to replay the latest macro).
- ♿ Guided Accessibility permission flow that deep-links to System Settings when needed.

## Getting Started

### Prerequisites
- Xcode 15 or newer
- macOS 13 Ventura or newer

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/your-organization/MacroRecorder.git
   cd MacroRecorder
   ```
2. Open the project in Xcode:
   ```bash
   open MacroRecorder.xcodeproj
   ```
3. Update the signing team and bundle identifier in **Signing & Capabilities**.
4. Build and run the app on your Mac. On first launch, macOS will prompt for Accessibility permissions so the app can monitor and control input events.

## Usage
- Launch the app and grant Accessibility permissions when prompted so macOS allows input monitoring.
- Use the **Record** button (or `⌘⌥R`) to start capturing mouse and keyboard events.
- Stop the recording to save it in the sidebar, optionally renaming the macro beforehand.
- Select any saved macro to view details and press **Replay** (or `⌘⌥P`) to play it back at the captured speed.
- Delete macros from the list when they are no longer needed.

## Contributing
We welcome community contributions! To propose a change:
1. Fork the repository and create a feature branch.
2. Implement your changes, including tests or documentation where appropriate.
3. Submit a pull request describing your improvements.
4. Participate in the review process to get your contribution merged.

Please follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and include descriptive commit messages.

## Upcoming Features
- Conditional macros and branching logic for smarter automation.
- Inline timeline editor with drag-to-adjust timings.
- Lightweight scripting hooks for custom actions between recorded steps.
- Persistent storage and syncing of the macro library.
- Export/import functionality for sharing macros.

## License
MacroRecorder is released under the [GNU General Public License v3.0](./LICENSE).
