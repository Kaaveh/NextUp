import AppKit
import NextUpCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let selfCheck: Bool
    private var statusItem: NSStatusItem!
    /// The one store for the app's life; `nil` in the self-check, which calls no EventKit.
    private var source: CalendarSource?
    /// The events of the last refresh; `nil` without calendar access.
    private var events: [Event]? = []

    // The only place the two modes differ (menubar-app R18, R32).
    private var now: Date { selfCheck ? SelfCheck.now : Date() }
    private var calendar: Calendar { selfCheck ? SelfCheck.calendar : .autoupdatingCurrent }
    private var locale: Locale { selfCheck ? SelfCheck.locale : .autoupdatingCurrent }

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
        if selfCheck {
            refresh()
            SelfCheck.run(statusItem)
            return
        }
        let source = CalendarSource()
        self.source = source
        refresh()
        if CalendarSource.accessNotDetermined {
            Task {
                await source.requestAccess()
                refresh()
            }
        }
    }

    func refresh() {
        if let source {
            events = source.events(in: Agenda.window(now: now, calendar: calendar))
        } else {
            events = SelfCheck.events
        }
        drawBar()
    }

    // MARK: Bar

    private func drawBar() {
        guard let button = statusItem.button else { return }
        if let events, let bar = Agenda.bar(for: events, now: now) {
            button.image = Self.colorBar(bar.color)
            button.imagePosition = .imageLeading
            button.title = bar.text
        } else {
            let (symbol, description) = events == nil
                ? ("calendar.badge.exclamationmark", "NextUp: no calendar access")
                : ("calendar", "NextUp: no upcoming events")
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
            image?.isTemplate = true
            button.image = image
            button.title = ""
        }
    }

    /// 3 × 14 pt, corner radius 1.5 pt, in the event's colour (menubar-app R21).
    private static func colorBar(_ color: RGB) -> NSImage {
        let image = NSImage(size: NSSize(width: 3, height: 14), flipped: false) { rect in
            NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let events {
            let sections = Agenda.sections(for: events, now: now, calendar: calendar, locale: locale)
            if sections.isEmpty {
                let empty = NSMenuItem(title: "No upcoming events", action: nil, keyEquivalent: "")
                empty.isEnabled = false
                menu.addItem(empty)
            }
            for section in sections {
                menu.addItem(.sectionHeader(title: section.header))
                for row in section.rows { menu.addItem(rowItem(row)) }
            }
        } else {
            menu.addItem(.sectionHeader(title: "No calendar access"))
            let settings = NSMenuItem(title: "Open Privacy Settings…", action: #selector(openPrivacySettings), keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Launch at login", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NextUp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// A row with no action of its own; a meeting gets a `Join Google Meet` submenu (menubar-app R24–R26).
    private func rowItem(_ row: MenuRow) -> NSMenuItem {
        let item = NSMenuItem(title: row.text, action: nil, keyEquivalent: "")
        item.image = Self.colorBar(row.color)
        if let url = row.meetURL {
            let join = NSMenuItem(title: "Join Google Meet", action: #selector(join(_:)), keyEquivalent: "")
            join.target = self
            join.representedObject = url
            item.submenu = NSMenu()
            item.submenu?.addItem(join)
        }
        return item
    }

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars")!
        NSWorkspace.shared.open(url)
    }

    @objc private func join(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }
}
