import AppKit
import AVKit

/// Keep the native route picker alive in a normal window, outside NSMenu's
/// tracking loop. Reopening the window does not recreate or rebind the picker.
@MainActor final class AirPlayWindow: NSWindowController {
    init(player: AVPlayer) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "AirPlay"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 80))
        let title = NSTextField(labelWithString: "Välj högtalare")
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.frame = NSRect(x: 20, y: 43, width: 190, height: 18)
        content.addSubview(title)
        let hint = NSTextField(labelWithString: "Klicka på AirPlay-symbolen")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 23, width: 190, height: 16)
        content.addSubview(hint)
        let picker = AVRoutePickerView(frame: NSRect(x: 224, y: 22, width: 36, height: 36))
        picker.player = player
        picker.isRoutePickerButtonBordered = false
        picker.setAccessibilityLabel("Välj AirPlay-högtalare")
        content.addSubview(picker)
        window.contentView = content
        super.init(window: window)
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Use init(player:)") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
