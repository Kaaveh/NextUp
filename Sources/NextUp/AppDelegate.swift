import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let selfCheck: Bool
    private var statusItem: NSStatusItem!

    init(selfCheck: Bool) {
        self.selfCheck = selfCheck
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        drawBar()
        if selfCheck { SelfCheck.run(statusItem) }
    }

    private func drawBar() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "NextUp: no upcoming events")
        image?.isTemplate = true
        button.image = image
        button.title = ""
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(title: "Quit NextUp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}
