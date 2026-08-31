# Denon Control

A macOS menu bar app for controlling a Denon AVR over telnet. Shows the current volume and power state, lets you adjust the volume with a custom slider, and turns the receiver on/off — all from a small panel in the menu bar.

## Features

- **Menu bar panel** — click the Denon icon in the menu bar (SwiftUI `MenuBarExtra`, window style).
- **Auto-discovery & pairing** — finds Denon AVRs on the local network via mDNS (`_airplay._tcp` and `_denonavr._tcp`), probes them over telnet (`MV?`), and auto-pairs. Devices persist across launches.
- **Volume control** — custom slider (drag, or arrow keys when focused) that sends `MV` commands over telnet. Volume reads back the receiver's current value and max.
- **Global volume shortcuts** — press **⌘⌥↑** or **⌘⌥↓** anywhere on the Mac to nudge the receiver volume up or down by 0.5 (works without opening the panel, no permissions needed).
- **Power control** — custom power button that reflects ON/OFF state, with an inline confirmation before turning the device off.
- **Launch at login** — a checkbox in the panel registers the app as a macOS login item (`SMAppService`, with a LaunchAgent fallback); state refreshes each time the panel opens.
- **Unpair** — remove a device (it stays hidden until you scan and re-select it).

## Requirements

- macOS 14 (Sonoma) or later
- Xcode command line tools (`swift` in `PATH`)

## Build & run

```sh
sh build.sh
open DenonControl.app
```

`build.sh` compiles a release build and assembles `DenonControl.app` with codesigning in place. The app is an LSUIElement (menu bar only, no Dock icon).

## How it works

- **Control protocol**: the app talks to the AVR over plain-text telnet on port 23 (the Denon HTTP API on newer receivers is unusable for this — HTTPS redirects then 403). Commands are `PW?`/`PWON`/`PWSTANDBY` for power and `MV?`/`MV<n>`/`MV<n*10>` for volume.
- **Discovery**: `NWBrowser` with an IPv4-only probe connection to resolve the advertised host name. Discovery state (paired devices, current device, ignored hosts) is persisted in `UserDefaults`.

## Project layout

```
Sources/DenonControl/
  DenonControlApp.swift   # MenuBarExtra scene, panel UI, focus handling
  VolumeSliderView.swift  # custom volume slider (drag + arrow keys)
  DeviceStore.swift       # mDNS discovery, pairing, UserDefaults persistence
  DenonTelnet.swift       # tiny telnet client (single shared queue)
  GlobalVolumeShortcuts.swift  # Carbon global hotkeys (volume up/down)
  LoginItemController.swift    # launch-at-login (SMAppService + LaunchAgent fallback)
Resources/
  Info.plist
  AppIcon.icns
build.sh                  # release build -> DenonControl.app
```

## Notes

- Receivers may be found under multiple service types (AirPlay vs. native `_denonavr`), so the app dedupes by resolved host.
- Volume values with fractional steps (0.5) are sent as `MV<value*10>` (e.g. 56.5 → `MV565`).
- Global shortcuts are registered with Carbon `RegisterEventHotKey`; the current device (from `UserDefaults`) is the target. Key repeats nudge repeatedly.
- Launch at login uses `SMAppService.mainApp` (works for non-sandboxed apps from any location; BTM status `.requiresApproval` prompts the user to approve in System Settings). If registration throws, it falls back to a `~/Library/LaunchAgents` plist.