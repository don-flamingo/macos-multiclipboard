# ClipboardManager

A macOS multi-clipboard manager that runs in the background and provides access to your clipboard history.

## Features

- Runs as a background service with a glassmorphic UI
- Maintains a history of clipboard items (up to 20 entries)
- Handles text content and website images only (not files)
- Press Cmd+Shift+V to show clipboard history anywhere
- Use arrow keys to navigate between items
- Press Enter to select an item and return to your previous app
- All selected items are automatically copied to clipboard

## Requirements

- macOS 11.0 or later
- Swift 5.5 or later
- Xcode Command Line Tools (for building from source)

## Building from Source

### Quick Build with Script

1. Clone this repository
2. Open Terminal and navigate to the repository directory
3. Run the build script: `./build_app.sh`
4. The app will be built and packaged as `ClipboardManager.app`

### Manual Build

1. Clone this repository
2. Open Terminal and navigate to the repository directory
3. Run `swift build -c release` to compile the application in release mode
4. Create the app structure:
   ```
   mkdir -p ClipboardManager.app/Contents/MacOS
   mkdir -p ClipboardManager.app/Contents/Resources
   cp .build/release/ClipboardManager ClipboardManager.app/Contents/MacOS/
   cp Info.plist ClipboardManager.app/Contents/
   ```

## Installation as a System Service

### Method 1: Login Items (Easiest)

1. Copy `ClipboardManager.app` to your Applications folder:
   ```
   cp -r ClipboardManager.app /Applications/
   ```
2. Open System Settings (or System Preferences on older macOS)
3. Go to "General" > "Login Items" (or "Users & Groups" > "Login Items" on older macOS)
4. Click "+" and add ClipboardManager.app
5. Make sure the checkbox next to it is enabled

### Method 2: Launch Agent (More Robust)

1. Copy `ClipboardManager.app` to your Applications folder:
   ```
   cp -r ClipboardManager.app /Applications/
   ```
2. Create a Launch Agent plist file:
   ```
   mkdir -p ~/Library/LaunchAgents
   ```
3. Create a file named `com.user.clipboardmanager.plist` in the LaunchAgents directory with this content:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>com.user.clipboardmanager</string>
       <key>ProgramArguments</key>
       <array>
           <string>/Applications/ClipboardManager.app/Contents/MacOS/ClipboardManager</string>
       </array>
       <key>RunAtLoad</key>
       <true/>
       <key>KeepAlive</key>
       <true/>
   </dict>
   </plist>
   ```
4. Load the Launch Agent:
   ```
   launchctl load ~/Library/LaunchAgents/com.user.clipboardmanager.plist
   ```

## Usage

- The application runs in the background
- Press Cmd+Shift+V to show the clipboard history window
- Use Up/Down arrow keys to navigate between items
- Press Enter to select an item and close the window
- Press Cmd+V to paste the selected item in your application
- Press Escape to close the window without selecting anything

## Troubleshooting

- If the app isn't starting on login, verify that it has been added to your Login Items
- If keyboard shortcuts aren't working, try restarting the application
- If the app doesn't appear in the menu bar, it's still running in the background - press Cmd+Shift+V to access it

## License

This project is available under the MIT license.














