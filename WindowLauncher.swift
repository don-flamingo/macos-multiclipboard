import Cocoa

@main
class WindowApplication: NSObject, NSApplicationDelegate {
    private var windowController: ClipboardManagerWindow?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = WindowApplication()
        app.delegate = delegate
        
        // Ensure we're running as a foreground application
        NSApp.setActivationPolicy(.regular)
        
        // Start the app
        NSApp.activate(ignoringOtherApps: true)
        print("Starting application run loop")
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Creating window controller")
        windowController = ClipboardManagerWindow()
        
        // Ensure window is visible
        windowController?.window?.makeKeyAndOrderFront(nil)
        windowController?.showWindow(nil)
        
        // Force activation
        NSApp.activate(ignoringOtherApps: true)
        
        print("Window should now be visible")
        
        // Add a delay and try again to ensure visibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            print("Forcing window to front again")
            self?.windowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Application will terminate")
    }
} 