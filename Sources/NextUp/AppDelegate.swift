import AppKit
import NextUpCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let selfCheck: Bool
    private var statusItem: NSStatusItem!
    /// The one store for the app's life; `nil` in the self-check, which calls no EventKit.
    private var source: CalendarSource?
    /// `nil` in the self-check, which calls no UserNotifications (meeting-alerts R23).
    private var alerts: MeetingAlerts?
    private var timer: Timer?
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
        // The delegate before any `await`, so a click that launches NextUp reaches it (meeting-alerts R18).
        let alerts = MeetingAlerts()
        self.alerts = alerts
        let source = CalendarSource()
        self.source = source
        refresh()
        observe()
        Task {
            if CalendarSource.accessNotDetermined {
                await source.requestAccess()
                refresh()
            }
            await alerts.requestAuthorization()
            // Reads the new status now, not at the next tick, and reschedules if it changed (R16).
            refresh()
        }
    }

    /// Pending alerts go before the process does (meeting-alerts R14).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let alerts else { return .terminateNow }
        Task {
            await alerts.removeAll()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func refresh() {
        if let source {
            events = source.events(in: Agenda.window(now: now, calendar: calendar))
        } else {
            events = SelfCheck.events
        }
        drawBar()
        alerts?.update(AlertPlan.alerts(for: events ?? [], now: now, calendar: calendar, locale: locale), now: now)
    }

    // MARK: Triggers

    /// Every trigger calls the same `refresh()` (menubar-app R15–R17).
    private func observe() {
        let center = NotificationCenter.default
        for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.alerts?.forget()
                    self?.realign()
                }
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.realign() }
        }
        scheduleTimer()
    }

    /// After a wake or a clock change: the timer moves to the next minute boundary, then a refresh.
    private func realign() {
        scheduleTimer()
        refresh()
    }

    /// A repeating timer from the next minute boundary, at most 1 s late.
    private func scheduleTimer() {
        timer?.invalidate()
        let nextMinute = Date(timeIntervalSinceReferenceDate: (Date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60)
        let timer = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: Bar

    private func drawBar() {
        guard let button = statusItem.button else { return }
        if let events, let bar = Agenda.bar(for: events, now: now, calendar: calendar) {
            button.image = Self.colorBar(bar.color, striped: bar.declinedByGuest)
            button.imagePosition = .imageLeading
            button.title = bar.text
        } else {
            // Today's date, as Notion Calendar shows it; `N.calendar` ships with macOS 26 (menubar-app R22).
            let (symbol, description) = events == nil
                ? ("calendar.badge.exclamationmark", "NextUp: no calendar access")
                : ("\(calendar.component(.day, from: now)).calendar", "NextUp: nothing more today")
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
                ?? NSImage(systemSymbolName: "calendar", accessibilityDescription: description)
            image?.isTemplate = true
            button.image = image
            button.title = ""
        }
    }

    /// 4 × 16 pt, corner radius 2 pt, in the event's colour (menubar-app R21); `striped`: 45° stripes,
    /// 2 pt of colour then 2 pt clear, for an event a guest declined (R44).
    private static func colorBar(_ color: RGB, striped: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 16), flipped: false) { rect in
            NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1).setFill()
            let shape = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            guard striped else {
                shape.fill()
                return true
            }
            shape.addClip()
            // A 45° band 2 pt tall every 4 pt, from below the bottom edge to above the top one.
            for y in stride(from: -rect.width, to: rect.height, by: 4) {
                let band = NSBezierPath()
                band.move(to: NSPoint(x: 0, y: y))
                band.line(to: NSPoint(x: rect.width, y: y + rect.width))
                band.line(to: NSPoint(x: rect.width, y: y + rect.width + 2))
                band.line(to: NSPoint(x: 0, y: y + 2))
                band.close()
                band.fill()
            }
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
                // The menu's first row gets its Join right under it (menubar-app R26).
                if section == sections.first, let url = section.rows.first?.meetURL {
                    menu.insertItem(joinItem(url), at: 2)
                }
            }
        } else {
            menu.addItem(.sectionHeader(title: "No calendar access"))
            let settings = NSMenuItem(title: "Open Privacy Settings…", action: #selector(openPrivacySettings), keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
        }
        menu.addItem(.separator())
        if alerts?.isOff == true {
            let alertsOff = NSMenuItem(title: "Turn on meeting alerts…", action: #selector(openNotificationSettings), keyEquivalent: "")
            alertsOff.target = self
            menu.addItem(alertsOff)
        }
        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        // The self-check reads no ServiceManagement and draws it unchecked (menubar-app R33).
        login.state = !selfCheck && SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NextUp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// A row with no action of its own; a meeting gets a `Join Google Meet` submenu (menubar-app R24–R26).
    private func rowItem(_ row: MenuRow) -> NSMenuItem {
        let item = NSMenuItem(title: row.text, action: nil, keyEquivalent: "")
        item.image = Self.colorBar(row.color, striped: row.declinedByGuest)
        if let url = row.meetURL {
            item.submenu = NSMenu()
            item.submenu?.addItem(joinItem(url))
        }
        return item
    }

    private func joinItem(_ url: URL) -> NSMenuItem {
        let join = NSMenuItem(title: "Join Google Meet", action: #selector(join(_:)), keyEquivalent: "")
        join.target = self
        join.representedObject = url
        join.image = Self.meetLogo
        return join
    }

    /// `Contents/Resources/meet.png`, drawn at 16 × 16 pt; `nil` (no icon) if the bundle lacks it.
    private static let meetLogo: NSImage? = {
        let image = Bundle.main.image(forResource: "meet")
        image?.size = NSSize(width: 16, height: 16)
        return image
    }()

    /// The only place that calls `register()` (menubar-app R31).
    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            NSLog("NextUp: Launch at login failed: %@", String(describing: error))
        }
    }

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars")!
        NSWorkspace.shared.open(url)
    }

    @objc private func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }

    @objc private func join(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }
}
