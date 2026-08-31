import SwiftUI
import AppKit

@main
struct DenonVolApp: App {
    @StateObject private var store = DeviceStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            Image(nsImage: DenonIcon.menuBarImage)
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @ObservedObject var store: DeviceStore
    private let denon = DenonTelnet()
    @Environment(\.scenePhase) private var scenePhase
    @State private var powerOn = false
    @State private var volume: Double = 0
    @State private var volumeMax: Double = 98
    @State private var volumeSet: DispatchWorkItem?
    @FocusState private var volumeFocused: Bool
    @State private var pendingRemoval: DenonDevice?

    private var host: String? { store.current?.host }

    var body: some View {
        VStack(spacing: 0) {
            header

            if store.current != nil {
                Divider()

                Toggle(isOn: Binding(
                    get: { powerOn },
                    set: { newValue in
                        powerOn = newValue
                        guard let host else { return }
                        denon.send(newValue ? "PWON" : "PWSTANDBY", host: host)
                    }
                )) {
                    Label("Power", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .padding(8)

                Divider()

                HStack(spacing: 10) {
                    Slider(value: Binding(
                        get: { volume },
                        set: { newValue in
                            volume = newValue
                            scheduleVolumeSend()
                        }
                    ), in: 0...volumeMax, step: 0.5)
                    .focused($volumeFocused)
                    .focusable()
                    .onKeyPress(.leftArrow) {
                        adjustVolume(by: -0.5)
                        return .handled
                    }
                    .onKeyPress(.rightArrow) {
                        adjustVolume(by: 0.5)
                        return .handled
                    }

                    Text(String(format: "%.1f", volume))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(width: 30, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
                .defaultFocus($volumeFocused, true)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            devicesSection

            if pendingRemoval != nil {
                confirmationBar
            }

            Divider()

            Button {
                store.rescan()
            } label: {
                Label("Scan for Devices", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(8)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(width: 260)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            syncState()
        }
        .onChange(of: store.current?.host) { _ in
            NSApp.activate(ignoringOtherApps: true)
            syncState()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                NSApp.activate(ignoringOtherApps: true)
                syncState()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.current != nil ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(store.current?.name
                ?? (store.candidates.isEmpty
                    ? (store.hiddenCount > 0 ? "No devices — tap Scan below" : "Searching…")
                    : "Select a device"))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var devicesSection: some View {
        VStack(spacing: 0) {
            Text("DEVICES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if store.candidates.isEmpty {
                Text("No Denon receiver found on the network")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                ForEach(sortedCandidates) { device in
                    HStack(spacing: 6) {
                        Image(systemName: store.current?.host == device.host
                            ? "checkmark.circle.fill"
                            : "circle")
                            .font(.system(size: 11))
                            .foregroundStyle(store.current?.host == device.host
                                ? Color.green
                                : Color.secondary)

                        Text(device.name)
                            .font(.system(size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text(device.host)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if store.paired.contains(where: { $0.host == device.host }) {
                            Button {
                                pendingRemoval = device
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("Remove this device")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.select(device)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var confirmationBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remove \(pendingRemoval?.name ?? "this device")?")
                .font(.system(size: 12, weight: .semibold))
            Text("It will stay hidden until you scan and select it again.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Remove") {
                    if let device = pendingRemoval {
                        store.removeDevice(device)
                    }
                    pendingRemoval = nil
                }
                Button("Cancel") {
                    pendingRemoval = nil
                }
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding([.horizontal, .bottom], 6)
    }

    private var sortedCandidates: [DenonDevice] {
        store.candidates.sorted { left, right in
            if store.current?.host == left.host { return true }
            if store.current?.host == right.host { return false }
            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
    }

    private func scheduleVolumeSend() {
        volumeSet?.cancel()
        guard let host else { return }
        let work = DispatchWorkItem { denon.send(volumeCommand, host: host) }
        volumeSet = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func adjustVolume(by delta: Double) {
        volume = min(max(volume + delta, 0), volumeMax)
        scheduleVolumeSend()
    }

    private var volumeCommand: String {
        let value = volume
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "MV\(Int(value))"
        }
        return "MV\(Int(value * 10))"
    }

    private func syncState() {
        guard let host else {
            powerOn = false
            return
        }

        denon.query("PW?", host: host) { response in
            guard let response else { return }
            powerOn = response.contains("PWON")
        }

        denon.query("MV?", host: host) { response in
            guard let response else { return }
            var value: Double?
            var maxValue: Double = 98
            let parts = response.split(whereSeparator: { $0 == "\r" || $0 == "\n" })
            for part in parts {
                let chunk = part.trimmingCharacters(in: .whitespaces)
                if chunk.hasPrefix("MVMAX") {
                    let num = chunk.dropFirst("MVMAX".count)
                        .trimmingCharacters(in: .whitespaces)
                    if let m = Double(num) {
                        maxValue = m
                    }
                } else if chunk.hasPrefix("MV") {
                    let num = chunk.dropFirst(2)
                    if let n = Double(num) {
                        value = num.count >= 3 ? n / 10 : n
                    }
                }
            }
            guard let value else { return }
            volumeMax = max(maxValue, 1)
            volume = min(max(value, 0), volumeMax)
        }
    }
}

enum DenonIcon {
    static let glyph = "\u{1014AC}"

    static var menuBarImage: NSImage {
        let fontSize: CGFloat = 16
        let font = NSFont.systemFont(ofSize: fontSize)
        let glyphSize = (glyph as NSString).size(withAttributes: [.font: font])
        let canvas = NSSize(
            width: max(glyphSize.width, fontSize),
            height: max(glyphSize.height, fontSize)
        )
        let image = NSImage(size: canvas)
        image.lockFocus()
        let origin = NSPoint(
            x: (canvas.width - glyphSize.width) / 2,
            y: (canvas.height - glyphSize.height) / 2
        )
        (glyph as NSString).draw(at: origin, withAttributes: [.font: font])
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}