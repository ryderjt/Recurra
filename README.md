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
- Macros are stored for the current session; persisting them between launches is on the roadmap.
- Background recording is paused if the system revokes the Accessibility permission.

## Roadmap

| Status | Item |
| ------ | ---- |
| ✅ | Menu bar controls and SwiftUI command menu |
| ✅ | In-app macro library with rename/delete |
| ✅ | Global hotkeys for record & replay |
| ⏳ | Persistent macro storage using on-disk serialization |
| ⏳ | Timeline editor to tweak delays |
| ⏳ | Sharing/export support |

## Automated Release Workflow

Tagged pushes trigger the **Build macOS Release** workflow (`.github/workflows/build.yml`) which:

1. Archives the `Recurra` scheme with `xcodebuild` into `build/Recurra.xcarchive`.
2. Exports a manually signed `.app` bundle using `exportOptions.plist` (Developer ID distribution).
3. Optionally notarizes the exported app with `notarytool` when Apple account secrets are available.
4. Packages the signed app into `build/Recurra.dmg` using [`create-dmg`](https://github.com/create-dmg/create-dmg).
5. Uploads the DMG as a build artifact for the release tag.

### Required GitHub Secrets

| Secret | Description |
| ------ | ----------- |
| `TEAM_ID` | Your Apple Developer Team ID (used for signing and notarization). |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded `.p12` Developer ID Application certificate. |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password protecting the exported `.p12` file. |
| `DEVELOPER_ID_IDENTITY` | Full signing identity string (e.g. `Developer ID Application: Example Corp (ABCDE12345)`). |
| `KEYCHAIN_PASSWORD` | Temporary password used to create the signing keychain on the runner. |
| `APPLE_ID` *(optional)* | Apple ID email for notarization with `notarytool`. |
| `APP_PASSWORD` *(optional)* | App-specific password associated with `APPLE_ID` for notarization. |

> ℹ️ The `exportOptions.plist` shipped in the repository contains a placeholder team identifier. The workflow automatically overwrites it with `TEAM_ID` before exporting the archive.

## License

Recurra is released under the [GNU General Public License v3.0](./LICENSE).
