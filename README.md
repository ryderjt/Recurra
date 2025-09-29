# MacroRecorder

*A sleek macOS app that records and replays your exact keystrokes and mouse actions, making automation seamless for writing, gaming, and everyday tasks.*

<p align="center">
  <img src="https://img.shields.io/badge/build-passing-brightgreen" alt="Build Status" />
  <img src="https://img.shields.io/badge/license-GPLv3-blue" alt="License" />
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift Version" />
  <img src="https://img.shields.io/badge/platform-macOS%2013+-lightgrey" alt="Platform" />
</p>

## Overview

MacroRecorder lays the groundwork for a modern SwiftUI desktop application that can capture low-level keyboard and mouse events using `CGEventTap`, then replay them with precision. This repository provides a clean starting point for further development, packaging, and distribution as a DMG installer.

## Project Structure

```
MacroRecorder/
├─ MacroRecorder.xcodeproj/        # Xcode project configuration
├─ MacroRecorder/
│  ├─ App.swift                    # SwiftUI entry point
│  ├─ ContentView.swift            # Minimal UI with Record/Replay controls
│  ├─ RecordManager.swift          # Placeholder CGEventTap recorder
│  ├─ ReplayManager.swift          # Placeholder event playback manager
│  └─ Info.plist                   # Accessibility permission descriptions
├─ LICENSE                         # GPLv3 license
└─ README.md
```

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
- Click **Record** to begin capturing keyboard and mouse events. The current implementation stores the events in memory for future use.
- Click **Stop Recording** to end the capture session.
- Click **Replay** to trigger the playback placeholder and verify accessibility permissions.

## Contributing
We welcome community contributions! To propose a change:
1. Fork the repository and create a feature branch.
2. Implement your changes, including tests or documentation where appropriate.
3. Submit a pull request describing your improvements.
4. Participate in the review process to get your contribution merged.

Please follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and include descriptive commit messages.

## Roadmap
- Persistent storage of recorded macros.
- Timeline editor to visualize and adjust events.
- Playback speed controls and looping support.
- Global keyboard shortcuts to trigger recording and playback.
- Export/import functionality for sharing macros.
- Notarized DMG packaging for streamlined distribution.

## License
MacroRecorder is released under the [GNU General Public License v3.0](./LICENSE).
