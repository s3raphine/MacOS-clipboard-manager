import AppKit
import SwiftUI
import Carbon.HIToolbox

final class FloatingPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !isComposingText, keyHandler?(event) == true {
            return
        }
        super.sendEvent(event)
    }

    private var isComposingText: Bool {
        (firstResponder as? NSTextView)?.hasMarkedText() ?? false
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let action: Selector?
        switch (flags, event.charactersIgnoringModifiers?.lowercased()) {
        case (.command, "x"): action = #selector(NSText.cut(_:))
        case (.command, "c"): action = #selector(NSText.copy(_:))
        case (.command, "v"): action = #selector(NSText.paste(_:))
        case (.command, "a"): action = #selector(NSText.selectAll(_:))
        case (.command, "z"): action = Selector(("undo:"))
        case ([.command, .shift], "z"): action = Selector(("redo:"))
        default: action = nil
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class PanelController: NSObject, NSWindowDelegate {
    private static let panelSize = NSSize(width: 400, height: 520)

    private let monitor: ClipboardMonitor
    private let statusItem: NSStatusItem
    private let panel = FloatingPanel(size: PanelController.panelSize)
    private var clickOutsideMonitor: Any?

    init(monitor: ClipboardMonitor, statusItem: NSStatusItem) {
        self.monitor = monitor
        self.statusItem = statusItem
        super.init()
        panel.delegate = self
        panel.keyHandler = { [weak self] event in self?.handleKey(event) ?? false }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        monitor.resetForOpening()
        panel.contentView = NSHostingView(rootView:
            ContentView(onClose: { [weak self] in self?.hide() })
                .environmentObject(monitor)
        )
        panel.setFrameOrigin(panelOrigin())
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, !self.isMouseOverStatusItem else { return }
            self.hide()
        }
    }

    private var isMouseOverStatusItem: Bool {
        guard let button = statusItem.button, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(NSEvent.mouseLocation)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.contentView = nil
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
            self.clickOutsideMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if isMouseOverStatusItem { return }
        hide()
    }

    private func panelOrigin() -> NSPoint {
        let size = Self.panelSize
        var screen = NSScreen.main ?? NSScreen.screens[0]
        var anchor: NSRect?

        if let button = statusItem.button, let window = button.window, let buttonScreen = window.screen {
            screen = buttonScreen
            let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
            if screen.frame.maxY - frame.minY < 100 { anchor = frame }
        }

        let visible = screen.visibleFrame
        let centerX = anchor?.midX ?? visible.maxX
        let x = min(max(centerX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        return NSPoint(x: x, y: visible.maxY - size.height - 6)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])

        switch (Int(event.keyCode), flags) {
        case (kVK_DownArrow, []):
            monitor.moveSelection(by: 1)
        case (kVK_UpArrow, []):
            monitor.moveSelection(by: -1)
        case (kVK_Return, []), (kVK_ANSI_KeypadEnter, []):
            guard let item = monitor.selectedItem else { return true }
            monitor.copyToClipboard(item)
            hide()
        case (kVK_Escape, _):
            if monitor.searchQuery.isEmpty {
                hide()
            } else {
                monitor.searchQuery = ""
            }
        case (kVK_ANSI_P, .command):
            if let item = monitor.selectedItem { monitor.togglePin(item) }
        case (kVK_Delete, .command):
            if let item = monitor.selectedItem { monitor.delete(item) }
        default:
            return false
        }
        return true
    }
}
