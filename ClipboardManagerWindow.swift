import Cocoa
import HotKey
import Carbon.HIToolbox
import ObjectiveC

// Extension to add associated object property to NSButton
private var AssociatedRowIndexKey: UInt8 = 0

extension NSButton {
    var rowIndex: Int {
        get {
            return objc_getAssociatedObject(self, &AssociatedRowIndexKey) as? Int ?? -1
        }
        set {
            objc_setAssociatedObject(self, &AssociatedRowIndexKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// Custom window that handles keyboard events for arrow navigation
class KeyHandlingWindow: NSPanel {
    var dayForwardAction: (() -> Void)?
    var dayBackwardAction: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        let cmdPressed = event.modifierFlags.contains(.command)
        
        if cmdPressed {
            switch event.keyCode {
            case 123: // Left arrow key with command
                dayForwardAction?()
                return
            case 124: // Right arrow key with command
                dayBackwardAction?()
                return
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
}

class ClipboardManagerWindow: NSWindowController {
    private var clipboardItems: [ClipboardItem] = []
    private var filteredItems: [ClipboardItem] = []
    private var tableView: NSTableView!
    private var hotKey: HotKey?
    private var clipboardMonitorTimer: Timer?
    private var keyEventMonitor: Any?
    private var previousFrontmostApp: NSRunningApplication?
    private var statusLabel: NSTextField!
    private var dateFilterButtons: [NSButton] = []
    private var currentFilter: Date?
    private let storageManager = ClipboardStorageManager.shared
    
    init() {
        // Create a custom borderless panel instead of a standard window
        let panel = KeyHandlingWindow(
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
        
        // Set up keyboard handlers for the custom window
        if let customWindow = window as? KeyHandlingWindow {
            customWindow.dayForwardAction = { [weak self] in
                self?.navigateDayForward(NSButton())
            }
            customWindow.dayBackwardAction = { [weak self] in
                self?.navigateDayBackward(NSButton())
            }
        }
        
        // Setup main menu with keyboard shortcuts
        setupMainMenu()
        
        // Load saved items
        loadSavedClipboardItems()
        
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
    
    private func setupMainMenu() {
        // Create a main menu if one doesn't exist
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = NSMenu(title: "MainMenu")
        }
        
        // Create Navigation Menu 
        let navMenu = NSMenu(title: "Navigation")
        let navMenuItem = NSMenuItem(title: "Navigation", action: nil, keyEquivalent: "")
        navMenuItem.submenu = navMenu
        
        // Previous Day (⌘S)
        let prevDayItem = NSMenuItem(title: "Previous Day", action: #selector(navigateDayBackward(_:)), keyEquivalent: "s")
        prevDayItem.keyEquivalentModifierMask = .command
        prevDayItem.target = self
        navMenu.addItem(prevDayItem)
        
        // Next Day (⌘A)
        let nextDayItem = NSMenuItem(title: "Next Day", action: #selector(navigateDayForward(_:)), keyEquivalent: "a")
        nextDayItem.keyEquivalentModifierMask = .command
        nextDayItem.target = self
        navMenu.addItem(nextDayItem)
        
        // Add separator
        navMenu.addItem(NSMenuItem.separator())
        
        // Today (⌘T)
        let todayItem = NSMenuItem(title: "Today", action: #selector(filterToday(_:)), keyEquivalent: "t")
        todayItem.keyEquivalentModifierMask = .command
        todayItem.target = self
        navMenu.addItem(todayItem)
        
        // All Items (⌘0)
        let allItem = NSMenuItem(title: "All Items", action: #selector(showAllItems(_:)), keyEquivalent: "0")
        allItem.keyEquivalentModifierMask = .command
        allItem.target = self
        navMenu.addItem(allItem)
        
        // Add Navigation menu to main menu
        NSApp.mainMenu?.addItem(navMenuItem)
    }
    
    private func loadSavedClipboardItems() {
        self.clipboardItems = storageManager.loadItems()
        self.filteredItems = clipboardItems
        print("Loaded \(clipboardItems.count) items from storage")
    }
    
    private func saveClipboardItems() {
        storageManager.saveItems(clipboardItems)
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
            updateStatusLabel("Item copied to clipboard")
        }
    }
    
    override func keyDown(with event: NSEvent) {
        let cmdPressed = event.modifierFlags.contains(.command)
        
        if cmdPressed {
            switch event.keyCode {
            case 123: // Left arrow key
                navigateDayForward(NSButton())
                return
            case 124: // Right arrow key
                navigateDayBackward(NSButton())
                return
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
    
    private func moveSelection(delta: Int) {
        let currentRow = tableView.selectedRow
        let newRow = max(0, min(tableView.numberOfRows - 1, currentRow + delta))
        
        if newRow != currentRow && newRow >= 0 && newRow < filteredItems.count {
            tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(newRow)
            updateStatusLabel("Item copied to clipboard")
        }
    }
    
    private func updateStatusLabel(_ message: String) {
        statusLabel.stringValue = message
        
        // Flash the status label briefly
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            statusLabel.animator().textColor = NSColor.systemGreen
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    self.statusLabel.animator().textColor = NSColor.secondaryLabelColor
                })
            }
        })
    }
    
    private func handleEnterKey() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < filteredItems.count {
            let item = filteredItems[selectedRow]
            copyToClipboard(item)
            updateStatusLabel("Item copied! Press ⌘V to paste in your app")
            
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
        let instructionsLabel = NSTextField(labelWithString: "Use ↑/↓ keys to navigate, Enter to select")
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionsLabel.font = NSFont.systemFont(ofSize: 12)
        instructionsLabel.textColor = NSColor.secondaryLabelColor
        instructionsLabel.alignment = .center
        contentView.addSubview(instructionsLabel)
        
        // Create status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)
        
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
        
        // Create a footer area
        let footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.wantsLayer = true
        contentView.addSubview(footerView)
        
        // Setup the footer with day filtering tabs
        setupFooter(in: footerView)
        
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
            
            statusLabel.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // Footer view constraints
            footerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 80), // Increased to fit date tabs
            
            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor, constant: -10)
        ])
    }
    
    private func setupFooter(in footerView: NSView) {
        // Add a separator line above the footer
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        footerView.addSubview(separator)
        
        // Create days filter tab bar
        let daysFilterView = NSView()
        daysFilterView.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(daysFilterView)
        
        // Add navigation arrows for days - SWAP DIRECTIONS
        let leftArrowButton = NSButton(title: "← (⌘A)", target: self, action: #selector(navigateDayForward(_:)))
        leftArrowButton.translatesAutoresizingMaskIntoConstraints = false
        leftArrowButton.bezelStyle = .recessed
        leftArrowButton.isBordered = false
        leftArrowButton.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .bold)
        leftArrowButton.contentTintColor = NSColor.secondaryLabelColor
        daysFilterView.addSubview(leftArrowButton)
        
        // Create a container view for the tab buttons to center them
        let tabButtonsContainer = NSView()
        tabButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        daysFilterView.addSubview(tabButtonsContainer)
        
        // Add buttons for days
        let allButton = createFilterButton(title: "All (⌘0)", action: #selector(showAllItems(_:)))
        let todayButton = createFilterButton(title: "Today (⌘T)", action: #selector(filterToday(_:)))
        let yesterdayButton = createFilterButton(title: "Yesterday", action: #selector(filterYesterday(_:)))
        
        // Create day name buttons for the past week
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE" // Short weekday name
        
        let calendar = Calendar.current
        var weekdayButtons: [NSButton] = []
        
        // Add buttons for the past 5 days (excluding today and yesterday)
        for i in 2...6 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let dayName = dateFormatter.string(from: date)
            let button = createFilterButton(title: dayName, action: #selector(filterByWeekday(_:)))
            button.tag = i // Store the day offset in the tag
            weekdayButtons.append(button)
        }
        
        // Add "More" button
        let moreButton = createFilterButton(title: "More...", action: #selector(showMoreDates(_:)))
        
        // Add right arrow button - SWAP DIRECTIONS
        let rightArrowButton = NSButton(title: "(⌘S) →", target: self, action: #selector(navigateDayBackward(_:)))
        rightArrowButton.translatesAutoresizingMaskIntoConstraints = false
        rightArrowButton.bezelStyle = .recessed
        rightArrowButton.isBordered = false
        rightArrowButton.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .bold)
        rightArrowButton.contentTintColor = NSColor.secondaryLabelColor
        daysFilterView.addSubview(rightArrowButton)
        
        // Store all filter buttons for later reference
        dateFilterButtons = [allButton, todayButton, yesterdayButton] + weekdayButtons + [moreButton]
        
        // Highlight "All" button by default
        highlightSelectedFilterButton(allButton)
        
        // Add buttons to the filter container
        tabButtonsContainer.addSubview(allButton)
        tabButtonsContainer.addSubview(todayButton)
        tabButtonsContainer.addSubview(yesterdayButton)
        for button in weekdayButtons {
            tabButtonsContainer.addSubview(button)
        }
        tabButtonsContainer.addSubview(moreButton)
        
        // Add clear history button to the footer
        let clearButton = NSButton(title: "Clear History", target: self, action: #selector(clearHistory))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        footerView.addSubview(clearButton)
        
        // Add constraints for the filter section
        NSLayoutConstraint.activate([
            // Separator constraints
            separator.topAnchor.constraint(equalTo: footerView.topAnchor),
            separator.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            // Days filter view
            daysFilterView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            daysFilterView.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 10),
            daysFilterView.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -10),
            daysFilterView.heightAnchor.constraint(equalToConstant: 25),
            
            // Left arrow constraints
            leftArrowButton.leadingAnchor.constraint(equalTo: daysFilterView.leadingAnchor, constant: 5),
            leftArrowButton.centerYAnchor.constraint(equalTo: daysFilterView.centerYAnchor),
            
            // Tab buttons container centered in filter view
            tabButtonsContainer.centerXAnchor.constraint(equalTo: daysFilterView.centerXAnchor),
            tabButtonsContainer.centerYAnchor.constraint(equalTo: daysFilterView.centerYAnchor),
            tabButtonsContainer.heightAnchor.constraint(equalTo: daysFilterView.heightAnchor),
            tabButtonsContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leftArrowButton.trailingAnchor, constant: 10),
            tabButtonsContainer.trailingAnchor.constraint(lessThanOrEqualTo: rightArrowButton.leadingAnchor, constant: -10),
            
            // Right arrow constraints
            rightArrowButton.trailingAnchor.constraint(equalTo: daysFilterView.trailingAnchor, constant: -5),
            rightArrowButton.centerYAnchor.constraint(equalTo: daysFilterView.centerYAnchor),
            
            // Clear button constraints
            clearButton.topAnchor.constraint(equalTo: daysFilterView.bottomAnchor, constant: 8),
            clearButton.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            clearButton.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -10)
        ])
        
        // Set up horizontal layout for filter buttons
        if let firstButton = dateFilterButtons.first {
            NSLayoutConstraint.activate([
                firstButton.leadingAnchor.constraint(equalTo: tabButtonsContainer.leadingAnchor)
            ])
            
            // Chain buttons horizontally with spacing
            for i in 1..<dateFilterButtons.count {
                NSLayoutConstraint.activate([
                    dateFilterButtons[i].leadingAnchor.constraint(equalTo: dateFilterButtons[i-1].trailingAnchor, constant: 12)
                ])
            }
            
            if let lastButton = dateFilterButtons.last {
                NSLayoutConstraint.activate([
                    lastButton.trailingAnchor.constraint(equalTo: tabButtonsContainer.trailingAnchor)
                ])
            }
            
            // Center buttons vertically
            for button in dateFilterButtons {
                NSLayoutConstraint.activate([
                    button.centerYAnchor.constraint(equalTo: tabButtonsContainer.centerYAnchor)
                ])
            }
        }
    }
    
    private func createFilterButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .recessed
        button.isBordered = false
        button.contentTintColor = NSColor.secondaryLabelColor
        return button
    }
    
    @objc private func clearHistory() {
        // Clear the arrays
        clipboardItems.removeAll()
        filteredItems.removeAll()
        
        // Update the UI
        tableView.reloadData()
        
        // Use the enhanced method to clear storage including image files
        storageManager.clearAllItems()
        
        // Update status
        updateStatusLabel("Clipboard history cleared")
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
                
                // Update filtered items based on current filter
                filterItemsByDate(currentFilter)
                
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
                
                // Save to storage
                saveClipboardItems()
                
                tableView.reloadData()
                
                // Auto-select the first (most recent) item
                if !clipboardItems.isEmpty {
                    tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
            }
        }
    }
    
    private func copyToClipboard(_ item: ClipboardItem) {
        item.copyToPasteboard()
    }
    
    deinit {
        clipboardMonitorTimer?.invalidate()
        
        // Remove event monitor when window is deallocated
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // Method to filter items by date
    private func filterItemsByDate(_ date: Date?) {
        if let filterDate = date {
            let calendar = Calendar.current
            filteredItems = clipboardItems.filter { item in
                calendar.isDate(item.timestamp, inSameDayAs: filterDate)
            }
        } else {
            // No filter = show all items
            filteredItems = clipboardItems
        }
        
        tableView.reloadData()
        
        // Select the first row if available
        if tableView.numberOfRows > 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    // MARK: - Day filter actions
    
    @objc private func filterToday(_ sender: NSButton) {
        highlightSelectedFilterButton(sender)
        currentFilter = Date()
        filterItemsByDate(currentFilter)
    }
    
    @objc private func filterYesterday(_ sender: NSButton) {
        highlightSelectedFilterButton(sender)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        currentFilter = yesterday
        filterItemsByDate(currentFilter)
    }
    
    @objc private func filterByWeekday(_ sender: NSButton) {
        highlightSelectedFilterButton(sender)
        // Get the tag which is the offset of days (-2 = 2 days ago, etc.)
        let daysOffset = -(sender.tag)
        let targetDate = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())
        currentFilter = targetDate
        filterItemsByDate(currentFilter)
    }
    
    @objc private func showMoreDates(_ sender: NSButton) {
        let menu = NSMenu()
        
        // Add options for previous weeks
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"
        
        let calendar = Calendar.current
        let today = Date()
        
        // Start from 8 days ago (past week is already in buttons)
        for i in 8...21 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let menuItem = NSMenuItem(title: dateFormatter.string(from: date), action: #selector(selectDateFromMenu(_:)), keyEquivalent: "")
            // Store the date in the representedObject
            menuItem.representedObject = date
            menu.addItem(menuItem)
        }
        
        menu.popUp(positioning: nil, at: NSPoint(x: sender.frame.midX, y: sender.frame.minY), in: sender.superview!)
    }
    
    @objc private func selectDateFromMenu(_ sender: NSMenuItem) {
        if let date = sender.representedObject as? Date {
            currentFilter = date
            // Reset button highlight since this is coming from menu
            resetFilterButtonHighlights()
            filterItemsByDate(date)
        }
    }
    
    @objc private func showAllItems(_ sender: NSButton) {
        highlightSelectedFilterButton(sender)
        currentFilter = nil
        filterItemsByDate(nil)
    }
    
    private func highlightSelectedFilterButton(_ selectedButton: NSButton) {
        // Reset all buttons to normal state
        resetFilterButtonHighlights()
        
        // Highlight the selected button
        selectedButton.contentTintColor = NSColor.controlAccentColor
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .bold)
        selectedButton.font = font
    }
    
    private func resetFilterButtonHighlights() {
        for button in dateFilterButtons {
            button.contentTintColor = NSColor.secondaryLabelColor
            let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.font = font
        }
    }
    
    // Navigation methods for day arrows
    @objc private func navigateDayBackward(_ sender: NSButton) {
        // If we're showing all items, start from today
        if currentFilter == nil {
            currentFilter = Date()
        }
        
        if let currentDate = currentFilter {
            let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            currentFilter = previousDay
            filterItemsByDate(currentFilter)
            
            // Try to find and highlight a button for this date if it exists
            updateButtonHighlightForDate(previousDay)
        }
    }
    
    @objc private func navigateDayForward(_ sender: NSButton) {
        // If we're showing all items, we can't go forward
        if currentFilter == nil {
            return
        }
        
        if let currentDate = currentFilter {
            // Don't navigate past today
            if Calendar.current.isDateInToday(currentDate) {
                // Already at today, show all items
                showAllItems(dateFilterButtons[0]) // All button
                return
            }
            
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            currentFilter = nextDay
            filterItemsByDate(currentFilter)
            
            // Try to find and highlight a button for this date if it exists
            updateButtonHighlightForDate(nextDay)
        }
    }
    
    private func updateButtonHighlightForDate(_ date: Date) {
        let calendar = Calendar.current
        
        // First reset all button highlights
        resetFilterButtonHighlights()
        
        // Find the appropriate button to highlight
        if calendar.isDateInToday(date) {
            // Today button (index 1)
            if dateFilterButtons.count > 1 {
                highlightSelectedFilterButton(dateFilterButtons[1])
            }
        } else if calendar.isDate(date, equalTo: calendar.date(byAdding: .day, value: -1, to: Date())!, toGranularity: .day) {
            // Yesterday button (index 2)
            if dateFilterButtons.count > 2 {
                highlightSelectedFilterButton(dateFilterButtons[2])
            }
        } else {
            // Check for weekday buttons (indices 3-7)
            for i in 3..<min(8, dateFilterButtons.count) {
                let button = dateFilterButtons[i]
                let daysOffset = -(button.tag)
                let buttonDate = calendar.date(byAdding: .day, value: daysOffset, to: Date())!
                
                if calendar.isDate(date, equalTo: buttonDate, toGranularity: .day) {
                    highlightSelectedFilterButton(button)
                    return
                }
            }
            
            // No button found for this date - just update the status label
            if let statusLabel = statusLabel {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                let dateString = formatter.string(from: date)
                statusLabel.stringValue = "Showing items from \(dateString)"
            }
        }
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
        return filteredItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredItems.count else { return nil }
        
        let item = filteredItems[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("ClipboardCell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier
            
            // Create icon view
            let iconView = NSImageView(frame: NSRect(x: 10, y: 20, width: 20, height: 20))
            iconView.imageScaling = .scaleProportionallyDown
            iconView.tag = 100 // Tag for later retrieval
            cellView?.addSubview(iconView)
            
            // Create timestamp label
            let timestampLabel = NSTextField(labelWithString: "")
            timestampLabel.translatesAutoresizingMaskIntoConstraints = false
            timestampLabel.font = NSFont.systemFont(ofSize: 10, weight: .light)
            timestampLabel.textColor = NSColor.secondaryLabelColor
            timestampLabel.alignment = .right
            timestampLabel.tag = 300 // Tag for later retrieval
            cellView?.addSubview(timestampLabel)
            
            // Create day name label (below timestamp)
            let dayNameLabel = NSTextField(labelWithString: "")
            dayNameLabel.translatesAutoresizingMaskIntoConstraints = false
            dayNameLabel.font = NSFont.systemFont(ofSize: 9, weight: .light)
            dayNameLabel.textColor = NSColor.tertiaryLabelColor
            dayNameLabel.alignment = .right
            dayNameLabel.tag = 301 // Tag for later retrieval
            cellView?.addSubview(dayNameLabel)
            
            // Create text field
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingTail
            textField.maximumNumberOfLines = 2
            textField.textColor = NSColor.labelColor
            
            cellView?.textField = textField
            cellView?.addSubview(textField)
            
            // Add image preview for image items
            let imagePreview = NSImageView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            imagePreview.imageScaling = .scaleProportionallyDown
            imagePreview.tag = 200 // Tag for later retrieval
            imagePreview.isHidden = true
            cellView?.addSubview(imagePreview)
            
            // Add remove button
            let removeButton = NSButton(title: "Delete", target: self, action: #selector(removeClipboardItem(_:)))
            removeButton.translatesAutoresizingMaskIntoConstraints = false
            removeButton.bezelStyle = .rounded
            removeButton.controlSize = .small
            removeButton.wantsLayer = true
            removeButton.layer?.backgroundColor = NSColor.systemRed.cgColor
            removeButton.layer?.cornerRadius = 4
            removeButton.tag = 400 // Tag for later retrieval
            removeButton.toolTip = "Remove this item"
            removeButton.contentTintColor = NSColor.white
            cellView?.addSubview(removeButton)
            
            // Layout constraints
            textField.translatesAutoresizingMaskIntoConstraints = false
            iconView.translatesAutoresizingMaskIntoConstraints = false
            imagePreview.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                // Icon constraints
                iconView.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 10),
                iconView.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20),
                
                // Timestamp constraints
                timestampLabel.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -20),
                timestampLabel.topAnchor.constraint(equalTo: cellView!.centerYAnchor, constant: -12),
                timestampLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
                
                // Day name label constraints
                dayNameLabel.trailingAnchor.constraint(equalTo: timestampLabel.trailingAnchor),
                dayNameLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 2),
                dayNameLabel.widthAnchor.constraint(equalTo: timestampLabel.widthAnchor),
                
                // Remove button constraints
                removeButton.trailingAnchor.constraint(equalTo: timestampLabel.leadingAnchor, constant: -8),
                removeButton.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                removeButton.widthAnchor.constraint(equalToConstant: 55),
                removeButton.heightAnchor.constraint(equalToConstant: 20),
                
                // Text field constraints
                textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
                textField.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -10),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                
                // Image preview constraints
                imagePreview.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 5),
                imagePreview.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
                imagePreview.trailingAnchor.constraint(lessThanOrEqualTo: cellView!.trailingAnchor, constant: -10),
                imagePreview.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
        
        // Get components by tag
        let iconView = cellView?.viewWithTag(100) as? NSImageView
        let imagePreview = cellView?.viewWithTag(200) as? NSImageView
        let timestampLabel = cellView?.viewWithTag(300) as? NSTextField
        let dayNameLabel = cellView?.viewWithTag(301) as? NSTextField
        let removeButton = cellView?.viewWithTag(400) as? NSButton
        
        // Store the row in the button's tag for later retrieval
        removeButton?.rowIndex = row
        
        // Update timestamp
        timestampLabel?.stringValue = item.timeWithSecondsString
        
        // Update day name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE" // Full day name
        let dayName = dateFormatter.string(from: item.timestamp)
        dayNameLabel?.stringValue = dayName
        
        // Configure cell based on item type
        switch item.type {
        case .text:
            iconView?.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Text")
            cellView?.textField?.stringValue = item.textContent ?? ""
            imagePreview?.isHidden = true
            
        case .image:
            iconView?.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
            cellView?.textField?.stringValue = "Image from clipboard"
            
            // Show small preview of the image
            if let image = item.imageContent {
                imagePreview?.image = image
                imagePreview?.isHidden = false
            } else {
                imagePreview?.isHidden = true
            }
            
        case .webImage:
            iconView?.image = NSImage(systemSymbolName: "globe.americas", accessibilityDescription: "Web Image")
            
            let displayText = item.sourceURL?.absoluteString ?? "Web Image"
            cellView?.textField?.stringValue = displayText
            
            // Show small preview of the image
            if let image = item.imageContent {
                imagePreview?.image = image
                imagePreview?.isHidden = false
            } else {
                imagePreview?.isHidden = true
            }
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < filteredItems.count {
            let item = filteredItems[selectedRow]
            copyToClipboard(item)
            updateStatusLabel("Item copied to clipboard")
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableView(_ tableView: NSTableView, didDoubleClickRow row: Int) {
        if row >= 0 && row < filteredItems.count {
            let item = filteredItems[row]
            copyToClipboard(item)
            updateStatusLabel("Item copied! Press ⌘V to paste in your app")
            
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
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // Return taller rows for image items with preview
        guard row < filteredItems.count else { return 60 }
        
        let item = filteredItems[row]
        switch item.type {
        case .text:
            return 60
        case .image, .webImage:
            return 100 // Taller row for image preview
        }
    }
    
    // MARK: - Item Removal
    
    @objc func removeClipboardItem(_ sender: NSButton) {
        let row = sender.rowIndex
        guard row >= 0 && row < filteredItems.count else {
            return
        }
        
        let itemToRemove = filteredItems[row]
        
        // Remove from filtered items
        filteredItems.remove(at: row)
        
        // Find and remove from main clipboardItems array
        if let mainIndex = clipboardItems.firstIndex(where: { $0.id == itemToRemove.id }) {
            clipboardItems.remove(at: mainIndex)
        }
        
        // Update the UI
        tableView.removeRows(at: IndexSet(integer: row), withAnimation: .slideUp)
        
        // Save changes to disk
        saveClipboardItems()
        
        // Update status
        updateStatusLabel("Item removed")
    }
} 