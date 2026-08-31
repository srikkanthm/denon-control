# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## Build & verify

- Build: `sh build.sh` (release SwiftPM build → assembles `DenonControl.app`, ad-hoc codesigned). End message `Built DenonControl.app` = success.
- There is **no test suite and no linter**. "Verification" = a clean `sh build.sh` + (when possible) launching the app and driving the live AVR.
- Launch/relaunch: `pkill -f DenonControl; open DenonControl.app` (or run the binary directly). Without a menu-bar click/open, the panel stays closed.
- Never power-cycle the physical receiver to verify a change. To test power-off flows, only verify the confirmation/Cancel paths (toggle must not send `PWSTANDBY` until confirmed).

## Architecture

- SwiftUI `MenuBarExtra` (`.window` style) app, macOS 14 deployment target. Bundle id `com.local.DenonControl`. Package: `Package.swift`, single executable target.
- `Sources/DenonControl/`:
  - `DenonControlApp.swift` — scene + `ContentView` (panel UI, power/slider state, confirm bars, focus handling).
  - `VolumeSliderView.swift` — custom slider (gradient track, ticks, drag gesture, 0.5-snap).
  - `DeviceStore.swift` — `@MainActor ObservableObject`: mDNS discovery/pairing/remove/rescan + `UserDefaults` persistence.
  - `DenonTelnet.swift` — telnet client (connect/send/read per call), one shared serial `DispatchQueue`.
  - `GlobalVolumeShortcuts.swift` — `@MainActor` Carbon global hotkeys (⌘⌥↑/⌘⌥↓ → `MVUP`/`MVDOWN`), started/stopped from `AppDelegate`.
- AVR control is plain-text telnet on port **23**: `PW?`/`PWON`/`PWSTANDBY`, `MV?`/`MV<n>`/`MV<n*10>`. Responses are CR-terminated (`MV<v>\rMVMAX <max>\r`).

## Hard-won pitfalls (don't regress)

- **Focus cycle**: Tab must traverse Power → volume slider → buttons. The custom views keep working because each exposes a real AX role via `.accessibilityRepresentation` (slider → `Slider`, power → relies on its Button role). Do NOT remove this.
- **Never hide a focusable/subtree with `if` removal** — it broke Tab focus. Hide with `opacity` + `allowsHitTesting(false)` + `accessibilityHidden(true)` + `.focusable(cond)` so the focus graph stays stable. Keep `.focused`/`defaultFocus` attached to always-present views; guard defaults with `Bool` args (e.g. `.defaultFocus($f, cond)`).
- **Do not add `.focusable()` to a control that is already focusable** (Buttons) and do not also give it `.accessibilityRepresentation` — those double the Tab stops (control gets focused twice).
- **`scenePhase` does NOT change when the MenuBarExtra panel opens/closes** — do not gate per-open work on `scenePhase`. Instead, `onAppear` re-fires for each panel open; use it (and `NSWindow.didBecomeKeyNotification` via `.onReceive`) to reset `@FocusState` and re-sync state, so panel reopen starts with nothing focused.
- **Power-off requires confirmation**: the Power button sets `pendingPowerOff` (inline bar) and only sends `PWSTANDBY` after "Turn Off". Keep this flow.
- **Slider visibility**: slider row is gated on `showSlider = powerOn && !pendingPowerOff` (see pitfall above) and collapses via `.frame(height: 0)` when hidden, not `if`-removal.
- **Global hotkeys**: register with Carbon `RegisterEventHotKey` (code + modifiers), not `EventHotKeySpec` — that struct is stripped from the 64-bit headers (compiler can't find it). `InstallEventHandler` returns `OSStatus`; use an out-param for the `EventHandlerRef`. Handler must be a non-capturing `EventHandlerUPP` that hops to `@MainActor` via `Task`.
- **Synthetic input cannot verify hotkeys**: hotkey matching ignores injected CGEvents/System Events on macOS 26 — you must get a real physical key press to verify. Registration returning `noErr` is a necessary but not sufficient check.
- **⌘⌥↑/⌘⌥↓ are taken**: don't reuse these combos for anything else (panel slider uses left/right arrows, so no clash). Key-repeat behavior is desirable here (hold to ramp).

## Style

- No code comments. Follow existing SwiftUI conventions (computed view builders as `private var`, `@State`/`@Published`, etc.).
- Commits: single line, imperative, matching repo history (e.g. `Fix Tab focus cycle: ...`). Push only when asked.