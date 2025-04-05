# DriveCache Sentry

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![macOS](https://img.shields.io/badge/macOS-12.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)

A macOS menu bar application that monitors folder sizes and sends notifications when specified thresholds are exceeded.

## Functionality

A simple menu bar application that monitors folder sizes on your Mac. Because in our ever-advancing technological landscape, knowing when Google Drive's cache folder silently grows to fuck you is apparently something we need to worry about now.

It sits in your menu bar as a disk icon, doing what modern operating systems somehow still can't do on their own - tell you when FOLDERS CACHE get too big.

Set custom thresholds for any folder you want to keep an eye on. Particularly useful for that Google Drive cache that mysteriously expands when you're not looking.

It performs a daily check at 16:20. Like it or not. 🏳️‍🌈

## Installation

### Pre-built Application

1. Download from [Releases](https://github.com/Caio-Ze/DriveCache-Sentry/releases)
2. Extract the ZIP file
3. Move the application to your preferred location
4. Launch the application

### Building from Source

Requirements:
- macOS 12.0 or later
- Xcode 13.0 or later

Using Terminal:
```bash
git clone https://github.com/Caio-Ze/DriveCache-Sentry.git
cd DriveCache-Sentry
chmod +x run_lightweight_app.sh
./run_lightweight_app.sh
```

## Usage Instructions

1. The application appears as a disk icon in the menu bar
2. Click the icon to view the application menu
3. The menu displays all monitored folders
4. For each folder, the following actions are available:
   - Check Size: Display current folder size
   - Set Threshold: Configure size threshold
   - Remove: Stop monitoring the folder
5. Additional menu options:
   - Check All Folders: Display sizes of all monitored folders
   - Add Folder: Select a new folder to monitor
   
## Adding Folders to Monitor

The application can monitor any folder on your system:
1. Click on the menu bar icon
2. Select "Add Folder..."
3. Use the file browser to select any folder on your disk
4. Set a threshold size for the selected folder
5. The folder will now be monitored for size changes

## Configuration

Default settings:
- Initial monitored folder: `~/Library/Application Support/Google/DriveFS/Metadata`
- Default threshold: 1000 MB (1 GB) per folder
- Scheduled check: Daily at 16:20 (4:20 PM)

## Technical Details

Implementation features:
- Non-recursive folder size calculation
- Memory usage optimization
- Status indicator during scanning operations
- Notification system triggered by threshold conditions
- No limitations on folder types or locations that can be monitored

## Auto-start Configuration

To configure the application to start automatically:

1. Open System Settings
2. Navigate to General > Login Items
3. Add the application to the list
4. The application will start when you log in

## Repository Structure

```
DriveCache-Sentry/
├── Screenshots/            # Application screenshots
├── Source/                 # Source code files
│   ├── AppDelegate.swift   # Application delegate and core logic
│   ├── Info.plist          # Application configuration
│   └── Assets.xcassets     # Application resources
├── main.swift              # Application entry point
├── run_lightweight_app.sh  # Build script
└── README.md               # Documentation
```

## Contributing

To contribute to this project:

1. Fork the repository
2. Create a branch for your changes
3. Implement and test your changes
4. Submit a pull request
5. Follow the project code style and documentation standards

## License

This project uses the MIT License. See the [LICENSE](LICENSE) file for details. 