import AppKit
import NextUpCore

/// NextUp's own Notion-style panel, its only meeting alert: the title, the status, `Join Google Meet` and a close button
/// on hover (meeting-alerts R31–R34).
/// `MeetingAlerts` opens, stacks and closes it; normal mode only (R35).
final class MeetingPanel: NSPanel {
    let alert: Alert
    /// Called once when the panel closes, so the ones below move up (R32).
    private let onClose: (MeetingPanel) -> Void
    private let status = NSTextField(labelWithString: "")
    /// The close button, shown while the pointer is over the panel (R31, R34).
    private let close = NSButton()

    init(_ alert: Alert, now: Date, onClose: @escaping (MeetingPanel) -> Void) {
        self.alert = alert
        self.onClose = onClose
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 72),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // R32: above other windows, on every Space and over full-screen apps, never taking focus.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        // R31: dark in light and dark mode, the shape drawn by the content view's layer.
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        contentView = layout()
        contentView?.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                                    owner: self))
        update(now: now)
    }

    /// The status from `panelStatus`; `nil` closes the panel (R27, R33).
    func update(now: Date) {
        guard let text = AlertPlan.panelStatus(for: alert, now: now) else { return dismiss() }
        let line = NSMutableAttributedString(string: text, attributes: [.foregroundColor: NSColor.systemRed])
        line.append(NSAttributedString(string: " · " + alert.timeRange, attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
        line.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: line.length))
        status.attributedStringValue = line
    }

    override func mouseEntered(with event: NSEvent) { close.isHidden = false }
    override func mouseExited(with event: NSEvent) { close.isHidden = true }

    @objc func dismiss() {
        guard isVisible else { return }
        orderOut(nil)
        onClose(self)
    }

    // MARK: Layout (R31)

    private func layout() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Self.rgb(0x2C).cgColor
        view.layer?.cornerRadius = 12
        view.layer?.borderWidth = 1
        view.layer?.borderColor = Self.rgb(0x3B).cgColor

        let title = NSTextField(labelWithString: alert.title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = .labelColor
        title.lineBreakMode = .byTruncatingTail
        title.maximumNumberOfLines = 1
        status.lineBreakMode = .byTruncatingTail
        for label in [title, status] { label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) }
        let text = NSStackView(views: [title, status])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let join = NSButton(title: "Join Google Meet", target: self, action: #selector(joinMeeting))
        join.image = AppDelegate.meetLogo
        join.imagePosition = .imageLeading
        join.font = .systemFont(ofSize: 13)
        let chevron = NSButton(image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "More")!,
                               target: self, action: #selector(showMore(_:)))
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = Self.rgb(0x2C).cgColor
        for button in [join, chevron] {
            button.isBordered = false
            button.contentTintColor = .labelColor
        }
        let group = NSStackView(views: [join, divider, chevron])
        group.spacing = 0
        group.setCustomSpacing(10, after: join)
        group.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        group.wantsLayer = true
        group.layer?.backgroundColor = Self.rgb(0x37).cgColor
        group.layer?.cornerRadius = 6
        join.setContentHuggingPriority(.required, for: .horizontal)
        group.setContentCompressionResistancePriority(.required, for: .horizontal)

        close.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Dismiss")
        close.imageScaling = .scaleProportionallyUpOrDown
        close.isBordered = false
        close.contentTintColor = .secondaryLabelColor
        close.target = self
        close.action = #selector(dismiss)
        close.isHidden = true

        for subview in [text, group, close] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            text.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: group.leadingAnchor, constant: -12),
            group.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            group.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            group.heightAnchor.constraint(equalToConstant: 28),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalTo: group.heightAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 28),
            chevron.heightAnchor.constraint(equalToConstant: 28),
            close.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            close.widthAnchor.constraint(equalToConstant: 16),
            close.heightAnchor.constraint(equalToConstant: 16),
        ])
        return view
    }

    private static func rgb(_ gray: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(gray) / 255, green: CGFloat(gray) / 255, blue: CGFloat(gray) / 255, alpha: 1)
    }

    // MARK: Actions (R34)

    @objc private func joinMeeting() {
        MeetingAlerts.open(alert.url)
        dismiss()
    }

    @objc private func showMore(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Dismiss", action: #selector(dismiss), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Copy link", action: #selector(copyLink), keyEquivalent: "").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.isFlipped ? sender.bounds.maxY + 4 : -4), in: sender)
    }

    @objc private func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(alert.url.absoluteString, forType: .string)
    }
}
