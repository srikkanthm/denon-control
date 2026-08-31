import Foundation
import ServiceManagement

@MainActor
final class LoginItemController {
    static let shared = LoginItemController()

    private static let agentLabel = "com.local.DenonControl"

    private var agentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private var agentURL: URL {
        agentsDir.appendingPathComponent(Self.agentLabel + ".plist")
    }

    var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return launchAgentInstalled
        }
    }

    var statusNote: String? {
        if SMAppService.mainApp.status == .requiresApproval {
            return "Approve it in System Settings → General → Login Items"
        }
        return nil
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            return enableViaServiceManagement() || installLaunchAgent()
        } else {
            try? SMAppService.mainApp.unregister()
            removeLaunchAgent()
            return !isEnabled
        }
    }

    private func enableViaServiceManagement() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            return false
        }
    }

    private func installLaunchAgent() -> Bool {
        removeLaunchAgent()
        do {
            try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(Self.agentLabel)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(Bundle.main.executableURL!.path)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>LimitLoadToSessionType</key>
                <string>Aqua</string>
            </dict>
            </plist>
            """
            guard let data = plist.data(using: .utf8) else { return false }
            try data.write(to: agentURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: agentURL.path)
            return runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", agentURL.path])
                || runLaunchctl(arguments: ["load", "-w", agentURL.path])
        } catch {
            return false
        }
    }

    private func removeLaunchAgent() {
        runLaunchctl(arguments: ["bootout", "gui/\(getuid())/\(Self.agentLabel)"])
        try? FileManager.default.removeItem(at: agentURL)
    }

    private var launchAgentInstalled: Bool {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return false }
        return runLaunchctl(arguments: ["print", "gui/\(getuid())/\(Self.agentLabel)"])
    }

    private func runLaunchctl(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}