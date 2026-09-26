<div align="center">

# Mute

A macOS menu bar app that automatically activates Do Not Disturb when your microphone or camera is in use.

![Screenshot](screenshot.jpg)

</div>

No configuration required. Works with Zoom, Teams, Meet, FaceTime, and any other app that accesses your mic or camera.

## Install

Requires macOS 14 Sonoma or later.

### Mac App Store

[**Download on the Mac App Store**](https://apps.apple.com/us/app/mute-silence-automated/id6790570476)

> Not available in the EU due to App Store trader-status requirements. EU users, install via Homebrew or the direct download below.

### Homebrew

```bash
brew install --cask kurama/tap/mute
```

### Direct download

Download the latest notarized `.dmg` from the [Releases page](https://github.com/kurama/mute/releases).

## Build from source

This repository is for contributors. To build locally:

```bash
git clone https://github.com/kurama/mute.git
cd mute
open mute.xcodeproj
```

Set your development team under **Signing & Capabilities**, then press `Cmd+R`.

On first launch, Mute will guide you through a short onboarding that installs two macOS Shortcuts used to toggle Focus mode.

## How it works

**Microphone detection** uses CoreAudio's `kAudioDevicePropertyDeviceIsRunningSomewhere` — the same signal that drives the orange mic indicator in the menu bar.

**Camera detection** uses `AVCaptureDevice.isInUseByAnotherApplication` via KVO, with a 2-second polling fallback.

**Do Not Disturb** is managed through bundled macOS Shortcuts, which call the native Focus actions. This approach avoids private APIs and works without special entitlements.

### Focus ownership

Mute first checks whether any Focus is already active. If you started a call
while using Do Not Disturb, Work, Sleep, or a custom Focus, Mute preserves it
and does not change it when the call ends. It turns Do Not Disturb off only
when Mute itself turned it on for that call.

The Focus automation uses the built-in Do Not Disturb identifier rather than the
translated name shown by macOS, so it works across system languages.

## Menu options

- Enable / Disable Mute
- Trigger on: Mic & Camera / Mic only / Camera only

## License

MIT
