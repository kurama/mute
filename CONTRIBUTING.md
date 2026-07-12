# Contributing

## Setup

```bash
git clone https://github.com/doriangrasset/mute.git
cd mute
open mute.xcodeproj
```

Set your development team in **Signing & Capabilities** before building.

To reset the onboarding during development, use the **Reset Onboarding** item in the menu bar (visible in Debug builds only).

## Project structure

| File | Responsibility |
|------|----------------|
| `muteApp.swift` | App entry point. Routes to onboarding or straight to the menu bar agent based on UserDefaults. |
| `MediaMonitor.swift` | Detects mic and camera activity system-wide. Exposes `onStateChange` callback and a `triggerMode` setting. |
| `FocusController.swift` | Installs and runs the bundled Shortcuts on first launch. Toggled by `MediaMonitor`. |
| `StatusBarController.swift` | Owns the menu bar icon and contextual menu. |
| `OnboardingView.swift` | SwiftUI 3-step onboarding. Handles shortcut installation and launch-at-login. |
| `OnboardingWindowController.swift` | Wraps the SwiftUI onboarding in an `NSWindow`. Fires a completion callback on finish or window close. |
| `NSImage+Tint.swift` | Extension to fill an SVG image with a solid color, used to tint the status bar icon green when active. |

## Guidelines

- Keep all logic in the relevant file above. Avoid cross-cutting concerns.
- No third-party dependencies. The project intentionally has none.
- All code runs on `@MainActor` by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- Do not use private or undocumented APIs. The Shortcuts-based DND approach exists precisely to avoid this.
- `#if DEBUG` blocks are the only acceptable place for dev-only code.

## Submitting changes

1. Fork the repository and create a branch from `main`.
2. Make your changes. Build and test locally.
3. Open a pull request with a clear description of what changed and why.

## Reporting issues

Open a GitHub issue with your macOS version, a description of the problem, and steps to reproduce.
