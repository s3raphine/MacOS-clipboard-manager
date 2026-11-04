import SwiftUI
import AppKit
import Carbon.HIToolbox

@main
enum ClipboardManagerApp {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: ClipboardMonitor!
    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor = makeMonitor()
        monitor.startMonitoring()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        panelController = PanelController(monitor: monitor, statusItem: statusItem)
        registerGlobalHotKey()

        #if DEBUG
        if CommandLine.arguments.contains("--show-panel") { panelController.show() }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.flushPendingSaves()
    }

    private func makeMonitor() -> ClipboardMonitor {
        #if DEBUG
        if let dir = ProcessInfo.processInfo.environment["CLIPBOARD_MANAGER_DATA_DIR"] {
            return ClipboardMonitor(directory: URL(fileURLWithPath: dir, isDirectory: true))
        }
        #endif
        return ClipboardMonitor()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            panelController.toggle()
        }
    }

    private func showStatusMenu() {
        panelController.hide()
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Clipboard", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clipboard Manager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanel() {
        panelController.show()
    }

    private func registerGlobalHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1)
        let modifiers = UInt32(cmdKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_V)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue().panelController.toggle()
            return noErr
        }, 1, &eventType, selfPointer, nil)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Clipboard Manager: could not register ⌘⇧V (error \(status))")
        }
    }
}
