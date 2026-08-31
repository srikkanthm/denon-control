import SwiftUI
import AppKit

@main
struct DenonVolApp: App {
    private let denon = DenonTelnet(host: "192.168.0.25")

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                Button {
                    denon.send("MVUP")
                } label: {
                    Label("Volume Up", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(8)

                Divider()

                Button {
                    denon.send("MVDOWN")
                } label: {
                    Label("Volume Down", systemImage: "minus")
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
            .frame(width: 200, height: 92)
        } label: {
            Image(nsImage: DenonIcon.menuBarImage)
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
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