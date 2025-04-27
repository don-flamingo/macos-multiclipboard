# ClipboardManager

A macOS multi-clipboard manager that runs in the background and provides access to your clipboard history.

## Features

- Runs as a background service with a menu bar icon
- Maintains a history of clipboard items
- Press Cmd+Shift+V to show a popup with clipboard history
- Click on an item to copy it back to the clipboard
- Double-click to copy and close the popup

## Requirements

- macOS 11.0 or later
- Swift 5.5 or later

## Building and Running

1. Clone this repository
2. Open Terminal and navigate to the repository directory
3. Run `swift build` to compile the application
4. Run `swift run` to launch the application

## Installation

1. Build the application with `swift build -c release`
2. Copy the built application from `.build/release/ClipboardManager` to your Applications folder
3. Add the application to your Login Items to have it start automatically at login

## Usage

- The application runs in the background with a clipboard icon in the menu bar
- Press Cmd+Shift+V to show the clipboard history popup
- Click on any item in the list to copy it to the clipboard
- The most recent clipboard item is automatically selected

## License

This project is available under the MIT license. 