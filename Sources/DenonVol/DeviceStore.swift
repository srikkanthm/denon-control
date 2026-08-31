import Foundation
import Network
import Combine

struct DenonDevice: Identifiable, Hashable, Codable {
    var id: String { host }
    let name: String
    let host: String
}

@MainActor
final class DeviceStore: ObservableObject {
    @Published private(set) var candidates: [DenonDevice] = []
    @Published private(set) var paired: [DenonDevice] = []
    @Published private(set) var current: DenonDevice?

    private let telnet = DenonTelnet()
    private let mqueue = DispatchQueue(label: "denon.mdns")
    private var browsers: [NWBrowser] = []
    private var probes: [NWConnection] = []
    private var seen: Set<String> = []
    private var names: [String: String] = [:]
    private var probed: Set<String> = []
    private var ignored: Set<String> = []

    private enum Keys {
        static let paired = "pairedDevices"
        static let current = "currentDevice"
        static let ignored = "ignoredHosts"
    }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.paired),
           let list = try? JSONDecoder().decode([DenonDevice].self, from: data) {
            paired = list
        }
        if let data = defaults.data(forKey: Keys.current),
           let saved = try? JSONDecoder().decode(DenonDevice.self, from: data),
           paired.contains(where: { $0.host == saved.host }) {
            current = saved
        }
        ignored = Set(defaults.stringArray(forKey: Keys.ignored) ?? [])
        startDiscovery()
        verifySaved()
    }

    // MARK: - Actions

    func select(_ device: DenonDevice) {
        selectSafely(device)
    }

    func removeDevice(_ device: DenonDevice) {
        paired.removeAll { $0.host == device.host }
        if current?.host == device.host {
            current = nil
        }
        ignored.insert(device.host)
        savePaired()
        saveCurrent()
        saveIgnored()
    }

    func rescan() {
        ignored = []
        probed = []
        saveIgnored()
        for (host, name) in names {
            consider(DenonDevice(name: name, host: host))
        }
    }

    // MARK: - Pairing

    private func selectSafely(_ device: DenonDevice) {
        if !paired.contains(where: { $0.host == device.host }) {
            paired.append(device)
            savePaired()
        }
        current = device
        saveCurrent()
    }

    private func consider(_ device: DenonDevice) {
        guard !ignored.contains(device.host), current == nil else { return }
        if paired.contains(where: { $0.host == device.host }) {
            selectSafely(device)
            return
        }
        guard !probed.contains(device.host) else { return }
        probed.insert(device.host)
        telnet.query("MV?", host: device.host) { [weak self] response in
            Task { @MainActor [weak self] in
                guard let self, let response else { return }
                self.selectSafely(device)
            }
        }
    }

    private func verifySaved() {
        guard let current else { return }
        telnet.query("MV?", host: current.host) { [weak self] response in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if response == nil, self.current?.host == current.host {
                    self.current = nil
                    self.saveCurrent()
                    for (host, name) in self.names {
                        self.consider(DenonDevice(name: name, host: host))
                    }
                }
            }
        }
    }

    // MARK: - Persistence

    private func savePaired() {
        if let data = try? JSONEncoder().encode(paired) {
            UserDefaults.standard.set(data, forKey: Keys.paired)
        }
    }

    private func saveCurrent() {
        if let current, let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: Keys.current)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.current)
        }
    }

    private func saveIgnored() {
        UserDefaults.standard.set(Array(ignored), forKey: Keys.ignored)
    }

    // MARK: - mDNS discovery

    private func startDiscovery() {
        browse(type: "_airplay._tcp")
        browse(type: "_denonavr._tcp")
    }

    private func browse(type: String) {
        let browser = NWBrowser(for: .bonjour(type: type, domain: "local"), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleResults(results)
            }
        }
        browser.start(queue: mqueue)
        browsers.append(browser)
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            guard case .service(let name, let serviceType, _, _) = result.endpoint else { continue }
            let isDenon = name.localizedCaseInsensitiveContains("denon")
                || serviceType.hasPrefix("_denonavr")
            guard isDenon else { continue }
            resolveEndpoint(result, displayName: name)
        }
    }

    private func resolveEndpoint(_ result: NWBrowser.Result, displayName: String) {
        let params = NWParameters.tcp
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let probe = NWConnection(to: result.endpoint, using: params)
        probe.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let remote = probe.currentPath?.remoteEndpoint,
                   case .hostPort(let host, _) = remote {
                    var address = host.debugDescription
                    if let scope = address.firstIndex(of: "%") {
                        address = String(address[..<scope])
                    }
                    Task { @MainActor [weak self] in
                        self?.record(host: address, name: displayName)
                    }
                }
                probe.cancel()
            case .failed:
                probe.cancel()
            default:
                break
            }
        }
        probe.start(queue: mqueue)
        probes.append(probe)
    }

    private func record(host: String, name: String) {
        guard !seen.contains(host) else { return }
        seen.insert(host)
        names[host] = name
        let device = DenonDevice(name: name, host: host)
        candidates.append(device)
        consider(device)
    }
}