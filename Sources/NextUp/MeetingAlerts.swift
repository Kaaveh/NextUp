import AppKit
import NextUpCore

/// Keeps the panel timers equal to the alert plan and owns the open panels; normal mode only, never in the self-check
/// (meeting-alerts R8, R11–R13, R20, R23, R25, R29–R35). NextUp posts no macOS notification.
final class MeetingAlerts {
    /// The last plan given to `update`.
    private var plan: [Alert] = []
    /// `false` until the first update and after `forget()`: the next update starts from scratch (R11).
    private var scheduled = false
    /// One one-shot timer per alert, at its fire date, by id (R29).
    private var timers: [String: Timer] = [:]
    /// The open panels, top to bottom (R32).
    private var panels: [MeetingPanel] = []

    /// The next update starts from scratch: a timer may not follow a clock change (R12).
    func forget() {
        scheduled = false
    }

    /// Applies the plan's changes against the last one to the panel timers; the first time, replaces them all
    /// (R8, R11, R29). Open panels redraw or close (R33).
    func update(_ new: [Alert], now: Date) {
        for panel in panels { panel.update(now: now) }
        // A timer past its date hasn't fired: a Timer runs late by a sleep, and a start from scratch would drop it.
        for timer in timers.values where timer.fireDate <= now { timer.fire() }
        let fromScratch = !scheduled
        let changes = AlertPlan.changes(from: fromScratch ? [] : plan, to: new, now: now)
        plan = new
        scheduled = true
        let stale = fromScratch ? Array(timers.keys) : changes.remove
        for id in stale { timers.removeValue(forKey: id)?.invalidate() }
        for alert in changes.add { schedulePanel(alert) }
    }

    // MARK: Panel (R25, R29–R35)

    /// A one-shot timer at the fire date that opens the panel, replacing an older timer of that id (R29).
    private func schedulePanel(_ alert: Alert) {
        timers[alert.id]?.invalidate()
        let timer = Timer(fire: alert.fireDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.openPanel(alert) }
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[alert.id] = timer
    }

    /// Opens the alert's panel below the open ones, unless one with its id is open (R30, R32); after a sleep past
    /// the meeting's end, none.
    private func openPanel(_ alert: Alert) {
        timers[alert.id] = nil
        let now = Date()
        guard !panels.contains(where: { $0.alert.id == alert.id }), AlertPlan.panelStatus(for: alert, now: now) != nil else { return }
        let panel = MeetingPanel(alert, now: now) { [weak self] closed in
            self?.panels.removeAll { $0 === closed }
            self?.stackPanels()
        }
        panels.append(panel)
        stackPanels()
        panel.orderFrontRegardless()
    }

    /// Top right of the menu bar's screen, 8 pt in from the top and right of its visible frame, 8 pt apart (R32).
    private func stackPanels() {
        guard let visible = NSScreen.screens.first?.visibleFrame else { return }
        var top = visible.maxY - 8
        for panel in panels {
            panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - 8 - panel.frame.width, y: top))
            top -= panel.frame.height + 8
        }
    }

    /// Opens an https link on meet.google.com and nothing else (R20, R34).
    static func open(_ url: URL) {
        guard url.scheme == "https", url.host() == "meet.google.com" else { return }
        NSWorkspace.shared.open(url)
    }
}
