# DriveCache Sentry

An ultra-lightweight macOS menu bar app that monitors Google Drive cache and other folder sizes, sending notifications when they exceed custom thresholds.

## Features

- Lives in your macOS menu bar with a minimal 💾 icon
- Specializes in Google Drive cache monitoring (default folder: DriveFS/Metadata)
- Monitors multiple folders simultaneously with customizable thresholds
- **Independent size thresholds** for each monitored folder
- Ultra-fast, non-recursive size scanning for maximum performance
- Daily checks at 16:10 (4:10 PM) that notify only when folders exceed threshold
- Minimal interface with no dock icon
- Anti-freeze protection - prevents app from hanging during file operations

## Requirements

- macOS 12.0 (Monterey) or later
- Xcode 13.0 or later

## Building the App

### Using Xcode
1. Open Xcode and create a new macOS project
2. Replace the generated files with the files from this repository
3. Build and run the app

### Using the Script
For quick testing, you can use the provided shell script:
```bash
./run_lightweight_app.sh
```

## How to Use

1. After launching, look for the 💾 icon in your menu bar
2. Click the icon to access the app's menu with your monitored folders
3. Click on any folder to check its current size or access its options:
   - **Check Size** - Show the current folder size
   - **Set Threshold...** - Set a custom threshold for this specific folder
   - **Remove** - Remove this folder from monitoring
4. Use these options to manage folders:
   - "Check All Folders" - Shows the current size of all folders at once
   - "Add Folder..." - Add a new folder to monitor (prompts for threshold)
5. The app automatically checks all folders daily at 16:10 (4:10 PM)
6. You will receive a notification ONLY if any folder size exceeds its specific threshold

## Default Settings

- Default monitored folder: `~/Library/Application Support/Google/DriveFS/Metadata` (Google Drive cache)
- Default threshold: 1000 MB (1 GB) per folder
- Daily check time: 16:10 (4:10 PM)

## Why DriveCache Sentry Is Better

DriveCache Sentry offers several advantages over typical folder monitoring tools:

1. **Specialized Google Drive focus**: Optimized for monitoring Google Drive cache, which can grow unexpectedly
2. **Minimal resource usage**: Uses ultra-lightweight scanning that only checks top-level files
3. **No recursive scanning**: Avoids the performance hit of deep directory traversal
4. **Individual thresholds**: Each folder can have its own custom size threshold
5. **Intelligent notifications**: Only notifies once per day when thresholds are exceeded
6. **Visual feedback**: Shows scanning progress with menu bar icon changes
7. **All native Swift**: Built with native macOS APIs for maximum efficiency

## Performance Optimizations

This app has been extremely optimized for performance and low resource usage:

- **Ultra-fast scanning**: Only top-level scanning without recursion for maximum speed
- **Memory efficient**: Minimizes memory allocation during scans
- **Anti-freeze protection**: Prevents app from hanging during scans
- **Visual indicators**: Shows when scanning is in progress (⏳ icon)
- **Notification efficiency**: Only sends one notification per day when folders exceed threshold

## Setting Up Launch at Login

To have the app launch automatically when you log in:

1. Go to **System Settings > General > Login Items** (macOS Ventura or later)
2. Click the "+" button to add an app
3. Locate and select the built DriveCacheSentry.app
4. The app will now launch automatically when you log in

## Project Structure

```
DriveCache-Sentry/
├── docs/
│   └── Instructions.md
├── MyMenuBarApp/
│   ├── AppDelegate.swift       # Contains the app delegate and monitoring logic
│   ├── Info.plist              # Contains LSUIElement = YES to hide the Dock icon
│   ├── Assets.xcassets         # Contains app icons and other resources
│   └── Other Swift files       # Additional files and resources for the app
├── main.swift                  # Initializes the application for command-line builds
├── Info.plist                  # Application property list for command-line builds
├── run_lightweight_app.sh      # Shell script for quick building and testing
└── README.md                   # This file
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 