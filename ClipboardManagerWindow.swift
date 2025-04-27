import Cocoa
import HotKey
import Carbon.HIToolbox

class ClipboardManagerWindow: NSWindowController {
    private var clipboardItems: [ClipboardItem] = []
    private var tableView: NSTableView!
    private var hotKey: HotKey?
    private var clipboardMonitorTimer: Timer?
    private var previousFrontmostApp: NSRunningApplication?
    
    init() {
        // Create a borderless panel instead of a standard window
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Center in screen
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            panel.setFrameOrigin(NSPoint(
                x: screenRect.midX - panel.frame.width / 2,
                y: screenRect.midY - panel.frame.height / 2
            ))
        }
        
        // Make it glassmorphic
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        
        super.init(window: panel)
        
        setupUI()
        setupClipboardMonitoring()
        setupHotKey()
        
        // Setup key responder chain for the window
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Handle various key presses
            switch Int(event.keyCode) {
            case kVK_Return, kVK_ANSI_KeypadEnter: // Enter key
                self.handleEnterKey()
                return nil // Consume event
                
            case kVK_UpArrow: // Up Arrow
                self.moveSelection(delta: -1)
                return nil // Consume event
                
            case kVK_DownArrow: // Down Arrow
                self.moveSelection(delta: 1)
                return nil // Consume event
                
            case kVK_Escape: // Escape key
                self.closeWindow()
                return nil // Consume event
                
            default:
                return event
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        // Store currently active application before showing our window
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        
        // Show our window
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure table view becomes first responder
        window?.makeFirstResponder(tableView)
        
        // Select the first row if available
        if tableView.numberOfRows > 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    private func moveSelection(delta: Int) {
        let currentRow = tableView.selectedRow
        let newRow = max(0, min(tableView.numberOfRows - 1, currentRow + delta))
        
        if newRow != currentRow && newRow >= 0 && newRow < clipboardItems.count {
            tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(newRow)
        }
    }
    
    private func handleEnterKey() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < clipboardItems.count {
            let item = clipboardItems[selectedRow]
            copyToClipboard(item.content)
            
            // Store a local reference to previous app
            let targetApp = previousFrontmostApp
            
            // Close our window first
            closeWindow()
            
            // Return to the original app
            if let app = targetApp {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
    }
    
    @objc private func closeWindow() {
        window?.orderOut(nil)
    }
    
    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }
        
        // Create a visual effect view for the glassmorphic effect
        let visualEffectView = NSVisualEffectView(frame: contentView.bounds)
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .hudWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20
        visualEffectView.autoresizingMask = [.width, .height]
        contentView.addSubview(visualEffectView)
        
        // Add a close button
        let closeButton = NSButton(frame: NSRect(x: contentView.bounds.width - 40, y: contentView.bounds.height - 30, width: 20, height: 20))
        closeButton.bezelStyle = .circular
        closeButton.title = "✕"
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.autoresizingMask = [.minXMargin, .minYMargin]
        contentView.addSubview(closeButton)
        
        // Create a simple heading
        let label = NSTextField(labelWithString: "Clipboard History")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = NSColor.labelColor
        label.alignment = .center
        contentView.addSubview(label)
        
        // Create instructions label
        let instructionsLabel = NSTextField(labelWithString: "Select an item and press ⌘V in your app to paste")
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionsLabel.font = NSFont.systemFont(ofSize: 12)
        instructionsLabel.textColor = NSColor.secondaryLabelColor
        instructionsLabel.alignment = .center
        contentView.addSubview(instructionsLabel)
        
        // Create table view with proper key handling
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        tableView = KeyHandlingTableView()
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 60
        tableView.selectionHighlightStyle = .regular
        tableView.usesAlternatingRowBackgroundColors = false
        
        // Make arrow keys work
        tableView.allowsEmptySelection = false
        tableView.focusRingType = .none
        
        // Create column for content
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ContentColumn"))
        column.width = 480
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Set delegates
        tableView.dataSource = self
        tableView.delegate = self
        
        // Add constraints
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            instructionsLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            instructionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            instructionsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }
    
    private func setupClipboardMonitoring() {
        NSPasteboard.general.clearContents()
        let _ = NSPasteboard.general.writeObjects([NSString(string: "")])
        
        // Start monitoring timer
        clipboardMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForPasteboardChanges()
        }
    }
    
    private func setupHotKey() {
        // Command+Shift+V
        hotKey = HotKey(key: .v, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            self?.showWindow(nil)
        }
    }
    
    private func checkForPasteboardChanges() {
        guard let items = NSPasteboard.general.pasteboardItems else { return }
        
        for item in items {
            if let string = item.string(forType: .string) {
                if !clipboardItems.contains(where: { $0.content == string }) {
                    let newItem = ClipboardItem(content: string, timestamp: Date())
                    clipboardItems.insert(newItem, at: 0)
                    
                    // Limit history size
                    if clipboardItems.count > 20 {
                        clipboardItems.removeLast()
                    }
                    
                    tableView.reloadData()
                    
                    // Auto-select the first (most recent) item
                    if !clipboardItems.isEmpty {
                        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    }
                }
            }
        }
    }
    
    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
    
    deinit {
        clipboardMonitorTimer?.invalidate()
    }
}

// Custom table view class that handles key events better
class KeyHandlingTableView: NSTableView {
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // Let the window handler deal with it
        NSApp.sendEvent(event)
    }
}

extension ClipboardManagerWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < clipboardItems.count else { return nil }
        
        let item = clipboardItems[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("ClipboardCell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier
            
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingTail
            textField.maximumNumberOfLines = 2
            textField.textColor = NSColor.labelColor
            
            cellView?.textField = textField
            cellView?.addSubview(textField)
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 10),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -10),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }
        
        // Configure cell
        cellView?.textField?.stringValue = item.content
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < clipboardItems.count {
            let item = clipboardItems[selectedRow]
            copyToClipboard(item.content)
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableView(_ tableView: NSTableView, didDoubleClickRow row: Int) {
        if row >= 0 && row < clipboardItems.count {
            let item = clipboardItems[row]
            copyToClipboard(item.content)
            
            // Store a local reference to previous app
            let targetApp = previousFrontmostApp
            
            // Close our window
            closeWindow()
            
            // Return to the original app
            if let app = targetApp {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
    }
} 