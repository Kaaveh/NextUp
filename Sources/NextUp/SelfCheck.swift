import AppKit

enum SelfCheck {
    static func run(_ statusItem: NSStatusItem) {
        let menu = statusItem.menu!
        menu.delegate?.menuNeedsUpdate?(menu)
        print("bar: " + (statusItem.button?.title ?? ""))
        for item in menu.items { print("menu: " + item.title) }
        exit(0)
    }
}
