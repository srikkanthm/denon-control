# TODO

## Later

- [ ] Reduce memory footprint: rewrite the SwiftUI `MenuBarExtra` panel as a minimal AppKit `NSStatusItem` app. Drops the SwiftUI runtime + render server, saving roughly 5-10MB of the ~30MB footprint. Must preserve current behavior: custom volume slider + arrow-key focus like the native slider, power-aware slider visibility, device discovery/pairing UI, inline removal confirmation.