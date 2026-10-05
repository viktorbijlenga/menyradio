import SwiftUI
import AppKit

@main @MainActor enum MenyradioApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(library: RadioLibrary(), player: RadioPlayer())
    }
    func applicationWillTerminate(_ notification: Notification) {
        statusBar?.player.stop()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
