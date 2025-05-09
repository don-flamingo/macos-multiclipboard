import Cocoa

class ClipboardListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var clipboardItems: [ClipboardItem] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    private var tableView: NSTableView!
    private let scrollView = NSScrollView()
    private var clearButton: NSButton!
    private let footerView = NSView()
    
    // Reference to storage manager
    private let storageManager = ClipboardStorageManager.shared
    
    init(clipboardItems: [ClipboardItem]) {
        self.clipboardItems = clipboardItems
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 340))
        view.wantsLayer = true
        
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.reloadData()
        
        // Auto-select the first (most recent) item
        if !clipboardItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    private func setupUI() {
        // Setup table view
        setupTableView()
        
        // Setup footer with clear button
        setupFooter()
        
        // Layout constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        footerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor),
            
            // Footer constraints
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 40),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupFooter() {
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.addSubview(footerView)
        
        // Add a separator line
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        footerView.addSubview(separator)
        
        // Add Clear History button
        clearButton = NSButton(title: "Clear History", target: self, action: #selector(clearHistory))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .regular
        footerView.addSubview(clearButton)
        
        NSLayoutConstraint.activate([
            // Separator constraints
            separator.topAnchor.constraint(equalTo: footerView.topAnchor),
            separator.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            // Clear button constraints
            clearButton.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
    }
    
    @objc private func clearHistory() {
        // Clear the array
        clipboardItems.removeAll()
        
        // Update the UI
        tableView.reloadData()
        
        // Use the enhanced method to clear storage including image files
        storageManager.clearAllItems()
    }
    
    private func setupTableView() {
        // Create table view
        tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        tableView.doubleAction = #selector(tableViewDoubleClicked)
        
        // Create column for content
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ContentColumn"))
        column.width = 400
        tableView.addTableColumn(column)
        
        // Set up scroll view
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = []
        
        view.addSubview(scrollView)
    }
    
    @objc private func tableViewDoubleClicked() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < clipboardItems.count {
            let item = clipboardItems[selectedRow]
            copyToClipboard(item)
            closePopover()
        }
    }
    
    private func copyToClipboard(_ item: ClipboardItem) {
        item.copyToPasteboard()
    }
    
    private func closePopover() {
        if let popover = view.window?.parent?.windowController as? NSPopover {
            popover.close()
        }
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardItems.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < clipboardItems.count else { return nil }
        
        let item = clipboardItems[row]
        
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
            
            // Add remove button
            let removeButton = NSButton(title: "", target: self, action: #selector(removeClipboardItem(_:)))
            removeButton.translatesAutoresizingMaskIntoConstraints = false
            removeButton.bezelStyle = .inline
            removeButton.controlSize = .small
            removeButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
            removeButton.isBordered = false
            removeButton.contentTintColor = NSColor.secondaryLabelColor
            removeButton.tag = 400 // Tag for later retrieval
            removeButton.toolTip = "Remove this item"
            cellView?.addSubview(removeButton)
            
            // Create text field
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingTail
            textField.maximumNumberOfLines = 2
            
            cellView?.textField = textField
            cellView?.addSubview(textField)
            
            // Add image preview for image items
            let imagePreview = NSImageView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            imagePreview.imageScaling = .scaleProportionallyDown
            imagePreview.tag = 200 // Tag for later retrieval
            imagePreview.isHidden = true
            cellView?.addSubview(imagePreview)
            
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
                timestampLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
                
                // Day name label constraints
                dayNameLabel.trailingAnchor.constraint(equalTo: timestampLabel.trailingAnchor),
                dayNameLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 2),
                dayNameLabel.widthAnchor.constraint(equalTo: timestampLabel.widthAnchor),
                
                // Remove button constraints
                removeButton.trailingAnchor.constraint(equalTo: timestampLabel.leadingAnchor, constant: -8),
                removeButton.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                removeButton.widthAnchor.constraint(equalToConstant: 22),
                removeButton.heightAnchor.constraint(equalToConstant: 22),
                
                // Text field constraints
                textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
                textField.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -10),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                
                // Image preview constraints
                imagePreview.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 5),
                imagePreview.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
                imagePreview.trailingAnchor.constraint(lessThanOrEqualTo: cellView!.trailingAnchor, constant: -10),
                imagePreview.heightAnchor.constraint(equalToConstant: 50),
                imagePreview.bottomAnchor.constraint(lessThanOrEqualTo: cellView!.bottomAnchor, constant: -5)
            ])
        }
        
        // Get components by tag
        let iconView = cellView?.viewWithTag(100) as? NSImageView
        let imagePreview = cellView?.viewWithTag(200) as? NSImageView
        let timestampLabel = cellView?.viewWithTag(300) as? NSTextField
        let dayNameLabel = cellView?.viewWithTag(301) as? NSTextField
        let removeButton = cellView?.viewWithTag(400) as? NSButton
        
        // Store the row as the button's tag for later retrieval
        removeButton?.tag = row
        
        // Update timestamp
        timestampLabel?.stringValue = item.relativeTimeString + " (" + item.timeWithSecondsString + ")"
        
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
        if selectedRow >= 0 && selectedRow < clipboardItems.count {
            let item = clipboardItems[selectedRow]
            copyToClipboard(item)
        }
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // Return taller rows for image items with preview
        guard row < clipboardItems.count else { return 60 }
        
        let item = clipboardItems[row]
        switch item.type {
        case .text:
            return 60
        case .image, .webImage:
            return 100 // Taller row for image preview
        }
    }
    
    // MARK: - Item Removal
    
    @objc func removeClipboardItem(_ sender: NSButton) {
        // Get the parent cell view
        guard let cellView = sender.superview as? NSTableCellView else {
            return
        }
        
        // Find the row for this cell
        let row = tableView.row(for: cellView)
        if row == -1 {
            return
        }
        
        guard row >= 0 && row < clipboardItems.count else {
            return
        }
        
        // Check if this is the selected row (currently in clipboard)
        let isSelectedRow = (row == tableView.selectedRow)
        
        // If this is the selected row, deselect it first
        if isSelectedRow {
            tableView.deselectRow(row)
            
            // Clear the system clipboard if removing the currently selected item
            NSPasteboard.general.clearContents()
        }
        
        // Remove from clipboardItems array
        clipboardItems.remove(at: row)
        
        // Update the UI
        tableView.reloadData()
        
        // If we have items and the removed item was selected, select a new item
        if isSelectedRow && clipboardItems.count > 0 {
            // Select the same row (now containing the next item) or the last item if that's not possible
            let newSelectionRow = min(row, clipboardItems.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: newSelectionRow), byExtendingSelection: false)
        }
        
        // Save changes to disk
        storageManager.saveItems(clipboardItems)
    }
} 