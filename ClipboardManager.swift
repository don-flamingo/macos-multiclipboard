import Cocoa
import HotKey

@main
class ClipboardManagerApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var clipboardItems: [ClipboardItem] = []
    private var popover: NSPopover?
    private var hotKey: HotKey?
    private var statusMenu: NSMenu?
    private let storageManager = ClipboardStorageManager.shared
    
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
        
        // Load saved clipboard items
        loadSavedClipboardItems()
        
        setupStatusBar()
        setupClipboardMonitoring()
        setupHotKey()
        
        // Show a notification to confirm we're running
        displayNotification(title: "ClipboardManager Running", 
                           message: "Press Cmd+Shift+V to access clipboard history")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Save clipboard items when app terminates
        saveClipboardItems()
    }
    
    private func loadSavedClipboardItems() {
        self.clipboardItems = storageManager.loadItems()
        print("Loaded \(clipboardItems.count) items from storage")
    }
    
    private func saveClipboardItems() {
        storageManager.saveItems(clipboardItems)
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
        
        // Show Clipboard History at the top
        let showItem = NSMenuItem(title: "Show Clipboard History", action: #selector(showPopover), keyEquivalent: "v")
        showItem.keyEquivalentModifierMask = [.command, .shift]
        statusMenu?.addItem(showItem)
        
        statusMenu?.addItem(NSMenuItem.separator())
        
        // Only keep the Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q")
        statusMenu?.addItem(quitItem)
        
        statusItem?.menu = statusMenu
    }
    
    @objc private func clearClipboardHistory() {
        clipboardItems.removeAll()
        saveClipboardItems()
        
        // Update UI if visible
        if let controller = popover?.contentViewController as? ClipboardListViewController,
           popover?.isShown == true {
            controller.clipboardItems = clipboardItems
        }
    }
    
    // Ensure items are saved when quitting
    @objc private func quitApplication() {
        print("Quitting application - saving clipboard items...")
        saveClipboardItems()
        NSApplication.shared.terminate(nil)
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
        if let newItem = ClipboardItem.fromPasteboard(NSPasteboard.general) {
            // Check if we already have this item
            let isAlreadyPresent: Bool
            
            switch newItem.type {
            case .text:
                // For text, compare the actual text content
                isAlreadyPresent = clipboardItems.contains { 
                    $0.type == .text && $0.textContent == newItem.textContent 
                }
                
            case .image, .webImage:
                // For images, compare by size/dimensions for a quick check
                isAlreadyPresent = clipboardItems.contains { 
                    if $0.type == .image || $0.type == .webImage, 
                       let existingImage = $0.imageContent,
                       let newImage = newItem.imageContent {
                        return existingImage.size == newImage.size
                    }
                    return false
                }
            }
            
            if !isAlreadyPresent {
                // Add the new item
                clipboardItems.insert(newItem, at: 0)
                
                // Log what was added
                switch newItem.type {
                case .text:
                    if let text = newItem.textContent {
                        print("New text item added at \(newItem.dateTimeString): \(text.prefix(20))...")
                    }
                case .image:
                    print("New image item added at \(newItem.dateTimeString)")
                case .webImage:
                    print("New web image added at \(newItem.dateTimeString) from \(newItem.sourceURL?.absoluteString ?? "unknown source")")
                }
                
                // Limit history size
                if clipboardItems.count > 20 {
                    clipboardItems.removeLast()
                }
                
                // Save to persistent storage
                saveClipboardItems()
                
                // Update the UI if the popover is visible
                if let controller = popover?.contentViewController as? ClipboardListViewController,
                   popover?.isShown == true {
                    controller.clipboardItems = clipboardItems
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