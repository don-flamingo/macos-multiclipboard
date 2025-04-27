import Cocoa
import HotKey

@main
class ClipboardManagerApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var clipboardItems: [ClipboardItem] = []
    private var popover: NSPopover?
    private var hotKey: HotKey?
    private var statusMenu: NSMenu?
    
    // This is the main entry point for the application
    static func main() {
        let app = NSApplication.shared
        let delegate = ClipboardManagerApp()
        app.delegate = delegate
        
        // Ensure we're running as a proper UI application
        NSApp.setActivationPolicy(.accessory)
        
        // Start the app and enter the run loop
        app.activate(ignoringOtherApps: true)
        print("ClipboardManager application started")
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        setupStatusBar()
        setupClipboardMonitoring()
        setupHotKey()
        
        // Show a notification to confirm we're running
        displayNotification(title: "ClipboardManager Running", 
                           message: "Press Cmd+Shift+V to access clipboard history")
    }
    
    private func setupStatusBar() {
        print("Setting up status bar item")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            print("Creating menu bar icon")
            // Make it more noticeable by using text + emoji
            button.title = "📋 Clip"
            
            // Create a menu
            setupMenu()
            
            print("Status bar setup complete")
        } else {
            print("Failed to access status item button")
        }
    }
    
    private func setupMenu() {
        statusMenu = NSMenu()
        
        let showItem = NSMenuItem(title: "Show Clipboard History", action: #selector(showPopover), keyEquivalent: "v")
        showItem.keyEquivalentModifierMask = [.command, .shift]
        statusMenu?.addItem(showItem)
        
        statusMenu?.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusMenu?.addItem(quitItem)
        
        statusItem?.menu = statusMenu
    }
    
    private func setupClipboardMonitoring() {
        print("Setting up clipboard monitoring")
        NSPasteboard.general.clearContents()
        let _ = NSPasteboard.general.writeObjects([NSString(string: "")])
        
        // Start monitoring timer
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForPasteboardChanges()
        }
    }
    
    private func setupHotKey() {
        print("Setting up hotkey")
        // Command+Shift+V
        hotKey = HotKey(key: .v, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            print("Hotkey triggered")
            self?.showPopover()
        }
    }
    
    private func checkForPasteboardChanges() {
        guard let items = NSPasteboard.general.pasteboardItems else { return }
        
        for item in items {
            if let string = item.string(forType: .string) {
                if !clipboardItems.contains(where: { $0.content == string }) {
                    let newItem = ClipboardItem(content: string, timestamp: Date())
                    clipboardItems.insert(newItem, at: 0)
                    print("New clipboard item added: \(string.prefix(20))...")
                    
                    // Limit history size
                    if clipboardItems.count > 20 {
                        clipboardItems.removeLast()
                    }
                }
            }
        }
    }
    
    @objc private func togglePopover(_ sender: Any?) {
        if let popover = popover, popover.isShown {
            hidePopover()
        } else {
            showPopover()
        }
    }
    
    @objc private func showPopover() {
        print("Showing clipboard history popup")
        if popover == nil {
            popover = NSPopover()
            popover?.contentViewController = ClipboardListViewController(clipboardItems: clipboardItems)
            popover?.behavior = .transient
        }
        
        if let button = statusItem?.button {
            (popover?.contentViewController as? ClipboardListViewController)?.clipboardItems = clipboardItems
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        } else {
            // Create a window as fallback if button isn't available
            showInWindow()
        }
    }
    
    private func showInWindow() {
        let windowController = NSWindowController(window: NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        ))
        
        windowController.window?.contentViewController = ClipboardListViewController(clipboardItems: clipboardItems)
        windowController.window?.center()
        windowController.window?.makeKeyAndOrderFront(nil)
    }
    
    private func hidePopover() {
        popover?.close()
    }
    
    private func displayNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
        
        print("Notification sent: \(title) - \(message)")
    }
}

struct ClipboardItem: Equatable {
    let id = UUID()
    let content: String
    let timestamp: Date
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }
} 