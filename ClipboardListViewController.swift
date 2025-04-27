import Cocoa

class ClipboardListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var clipboardItems: [ClipboardItem] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    private var tableView: NSTableView!
    private let scrollView = NSScrollView()
    
    init(clipboardItems: [ClipboardItem]) {
        self.clipboardItems = clipboardItems
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.wantsLayer = true
        
        setupTableView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.reloadData()
        
        // Auto-select the first (most recent) item
        if !clipboardItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
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
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.width, .height]
        
        view.addSubview(scrollView)
    }
    
    @objc private func tableViewDoubleClicked() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < clipboardItems.count {
            let item = clipboardItems[selectedRow]
            copyToClipboard(item.content)
            closePopover()
        }
    }
    
    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
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
            
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingTail
            textField.maximumNumberOfLines = 2
            
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
} 