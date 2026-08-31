import Carbon
import Foundation

@MainActor
final class GlobalVolumeShortcuts {
    static let shared = GlobalVolumeShortcuts()

    private var upRef: EventHotKeyRef?
    private var downRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let telnet = DenonTelnet()

    private static let hotKeySignature = OSType(0x444E564B)
    private static let upID: UInt32 = 1
    private static let downID: UInt32 = 2

    func start() {
        guard upRef == nil, handlerRef == nil else { return }
        installHandler()

        let target = GetApplicationEventTarget()
        var up: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(kVK_UpArrow), UInt32(cmdKey | optionKey),
                               EventHotKeyID(signature: Self.hotKeySignature, id: Self.upID),
                               target, 0, &up) == noErr {
            upRef = up
        }

        var down: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(kVK_DownArrow), UInt32(cmdKey | optionKey),
                               EventHotKeyID(signature: Self.hotKeySignature, id: Self.downID),
                               target, 0, &down) == noErr {
            downRef = down
        } else if let upRef {
            UnregisterEventHotKey(upRef)
            self.upRef = nil
        }
    }

    func stop() {
        if let upRef {
            UnregisterEventHotKey(upRef)
            self.upRef = nil
        }
        if let downRef {
            UnregisterEventHotKey(downRef)
            self.downRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var out: EventHandlerRef?
        let status = withUnsafePointer(to: &spec) { pointer in
            InstallEventHandler(GetApplicationEventTarget(), Self.handler, 1, pointer, nil, &out)
        }
        if status == noErr {
            handlerRef = out
        }
    }

    private nonisolated static let handler: EventHandlerUPP = { _, event, _ in
        guard let event, let hotKeyID = extractHotKeyID(from: event) else {
            return OSStatus(eventNotHandledErr)
        }
        let id = hotKeyID.id
        Task { @MainActor in
            switch id {
            case GlobalVolumeShortcuts.upID:
                GlobalVolumeShortcuts.shared.adjust(command: "MVUP")
            case GlobalVolumeShortcuts.downID:
                GlobalVolumeShortcuts.shared.adjust(command: "MVDOWN")
            default:
                break
            }
        }
        return noErr
    }

    private func adjust(command: String) {
        guard let host = currentHost() else { return }
        telnet.send(command, host: host)
    }

    private func currentHost() -> String? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "currentDevice"),
              let device = try? JSONDecoder().decode(DenonDevice.self, from: data) else {
            return nil
        }
        return device.host
    }
}

private func extractHotKeyID(from event: EventRef) -> EventHotKeyID? {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                   EventParamName(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return nil }
    return hotKeyID
}