# Recurra

![Build](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-GPLv3-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey)

A lightweight SwiftUI macro recorder for macOS that captures keyboard and mouse input with millisecond timing, then replays it on demand.

## Features

- 🎛️ Menu bar controller with quick record/play toggles, window activation, and quit shortcut.
- ⌨️ High-fidelity recording of keyboard and mouse events backed by Accessibility permissions.
- ▶️ Smooth, cancellable playback with safe timing across the entire macro.
- 📁 Macro library with rename, delete, and replay actions plus customizable default names.
- 💾 Persistent macro storage backed by Application Support serialization.
- 🔑 Global hotkeys for record (`⌘⌥R`) and replay (`⌘⌥P`).
- ♿ Text-based onboarding to request Accessibility permissions when required.

## Project Structure

```
Recurra/
├─ Recurra.xcodeproj/
├─ Recurra/
│  ├─ App.swift                 # SwiftUI entry point + command/menu integration
│  ├─ Info.plist                # Usage descriptions for Accessibility prompts
│  ├─ MacroManager.swift        # Macro library storage and rename/delete helpers
│  ├─ Recurra.entitlements      # Sandbox and Accessibility entitlements
│  ├─ MainView.swift            # Gradient SwiftUI interface
│  ├─ MenuBar.swift             # NSStatusItem-backed menu bar controller
│  ├─ Recorder.swift            # CGEventTap recorder with timing metadata
│  └─ Replayer.swift            # Playback engine with cancellation + hotkeys
├─ LICENSE                      # GPLv3
└─ README.md
```

## Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-organization/Recurra.git
   cd Recurra/Recurra
   ```
2. **Open the project**
   ```bash
   open Recurra.xcodeproj
   ```
3. **Configure signing** – set your development team and bundle identifier.
4. **Review entitlements** – confirm `Recurra.entitlements` is attached to the target so macOS can prompt for Accessibility and input monitoring.
5. **Build & run** – launch the app, approve the Accessibility prompt, and try recording a quick macro.

## Known Limitations

- Some games and secure apps block synthetic events, so playback may be ignored.
- Background recording is paused if the system revokes the Accessibility permission.

## Roadmap

| Status | Item |
| ------ | ---- |
| ✅ | Menu bar controls and SwiftUI command menu |
| ✅ | In-app macro library with rename/delete |
| ✅ | Global hotkeys for record & replay |
| ✅ | Persistent macro storage using on-disk serialization |
| ⏳ | Timeline editor to tweak delays |
| ⏳ | Sharing/export support |

## Packaging & Notarization Notes

1. Archive the app in Xcode (`Product > Archive`) with a Developer ID signing certificate.
2. Export the signed `.app` bundle and wrap it in a `.dmg` using `create-dmg` or `hdiutil`.
3. Run `xcrun notarytool submit <dmg> --keychain-profile <profile> --wait` to notarize.
4. Staple the ticket (`xcrun stapler staple <dmg>`) before distribution so Gatekeeper validates offline.

## License

Recurra is released under the [GNU General Public License v3.0](./LICENSE).
