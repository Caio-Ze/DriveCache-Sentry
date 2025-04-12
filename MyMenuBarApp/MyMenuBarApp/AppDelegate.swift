import Cocoa
import UserNotifications

// Remove @main attribute for command-line builds
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    private var statusItem: NSStatusItem!
    private let defaults = UserDefaults.standard
    private let lastNotificationKey = "lastNotificationDate"
    private let foldersKey = "monitoredFolders"
    private let folderThresholdsKey = "folderThresholds"
    private let folderExceededStatusKey = "folderExceededStatus"
    
    // Default values
    private let defaultFolderPath = "~/Library/Application Support/Google/DriveFS/Metadata"
    private let defaultThresholdMB = 1000 // 1 GB
    
    // To prevent multiple concurrent scans
    private var isScanning = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("App launching...")
        
        // Initialize default values if not set
        if defaults.array(forKey: foldersKey) == nil {
            defaults.set([defaultFolderPath], forKey: foldersKey)
            print("Initialized default folders")
        }
        
        // Migrate from old threshold system to new per-folder system if needed
        if defaults.dictionary(forKey: folderThresholdsKey) == nil {
            // Create a new dictionary with thresholds for each folder
            let oldThreshold = defaults.integer(forKey: "thresholdSizeMB")
            let threshold = oldThreshold > 0 ? oldThreshold : defaultThresholdMB
            
            var thresholds = [String: Int]()
            for folder in getMonitoredFolders() {
                thresholds[folder] = threshold
            }
            
            defaults.set(thresholds, forKey: folderThresholdsKey)
            print("Initialized folder thresholds")
        }
        
        // Initialize exceeded status dictionary if needed
        if defaults.dictionary(forKey: folderExceededStatusKey) == nil {
            defaults.set([String: Bool](), forKey: folderExceededStatusKey)
            print("Initialized folder exceeded status")
        }
        
        // Setup menu bar item with simple emoji
        setupSimpleMenuBar()
        
        // Check if menu is working properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkMenuStatus()
        }
        
        // Safely request notification permissions and schedule check
        do {
            // Try to get notification center - this can fail in non-bundle environments
            guard let center = try? UNUserNotificationCenter.current() else {
                print("Warning: Unable to access notification center. Running in limited mode.")
                return
            }
            
            center.requestAuthorization(options: [.alert, .sound]) { success, error in
                print("Notification authorization: \(success), error: \(String(describing: error))")
                // Schedule only after we have permission
                DispatchQueue.main.async {
                    self.scheduleNextCheck()
                }
            }
        } catch {
            print("Error setting up notifications: \(error). Running in limited mode.")
        }
        
        print("App launch setup complete")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up resources if needed
    }
    
    // MARK: - Menu Bar Setup
    
    func setupSimpleMenuBar() {
        // Create status item with fixed length for better visibility
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Configure the button with an emoji icon
        if let button = statusItem?.button {
            button.title = "💾"
            
            // Make the emoji more visible - fix the optional binding error
            let font = NSFont.systemFont(ofSize: 14, weight: .regular)
            button.font = font
            
            // Add hover effects
            button.wantsLayer = true
            button.layer?.cornerRadius = 4
            
            // Ensure visibility and accessibility
            button.isHidden = false
            button.isEnabled = true
            button.setAccessibilityTitle("Folder Monitor")
            
            // Debug info
            print("Status button created with title: \(button.title)")
        } else {
            print("ERROR: Failed to create status button")
        }
        
        // Update menu immediately
        updateMenu()
        print("Menu bar setup complete")
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // Status section
        let headerItem = NSMenuItem(title: "Folder Monitor Status:", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        let folders = getMonitoredFolders()
        let thresholds = getFolderThresholds()
        
        if folders.isEmpty {
            // No folders configured
            let noFoldersItem = NSMenuItem(title: "   No folders configured", action: nil, keyEquivalent: "")
            noFoldersItem.isEnabled = false
            menu.addItem(noFoldersItem)
            
            let instructionItem = NSMenuItem(title: "   Click 'Add Folder...' below", action: nil, keyEquivalent: "")
            instructionItem.isEnabled = false
            menu.addItem(instructionItem)
        } else {
            // List all monitored folders with their threshold
            for folder in folders {
                let folderName = (folder as NSString).lastPathComponent
                let threshold = thresholds[folder] ?? defaultThresholdMB
                
                // Get the last known exceeded status
                let exceededStatus = getFolderExceededStatus()
                let didExceed = exceededStatus[folder] ?? false // Default to false if no status saved
                
                let prefix = didExceed ? "🔴 " : "   "
                let fullTitleString = "\(prefix)📁 \(folderName) (\(threshold)MB)"
                
                // Create attributed string for potential size/style adjustments
                let attributedTitle = NSMutableAttributedString(string: fullTitleString)
                
                // Get default menu font if possible, otherwise use system font
                let defaultFont = NSFont.menuFont(ofSize: 0) // Size 0 gets the default menu font size
                let baseFontSize = defaultFont.pointSize
                attributedTitle.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: attributedTitle.length))
                
                // If the dot is present, make it smaller and adjust baseline
                if didExceed {
                    let dotRange = NSRange(location: 0, length: 1) // Range of the first character "🔴"
                    let smallerFontSize = baseFontSize * 0.7 // Adjust this multiplier for desired size (70%)
                    let smallerFont = NSFont.systemFont(ofSize: smallerFontSize)
                    attributedTitle.addAttribute(.font, value: smallerFont, range: dotRange)
                    
                    // Adjust baseline to keep the smaller dot vertically centered (might need tweaking)
                    let baselineOffset = (baseFontSize - smallerFontSize) / 3 // Experiment with this offset
                    attributedTitle.addAttribute(.baselineOffset, value: baselineOffset, range: dotRange)
                }

                // Create the menu item and set its attributed title
                let folderItem = NSMenuItem()
                folderItem.attributedTitle = attributedTitle
                folderItem.action = nil // Ensure it's not clickable itself
                folderItem.keyEquivalent = ""
                
                // Create a submenu for each folder
                let submenu = NSMenu()
                
                // Check Size option
                let checkSizeItem = NSMenuItem(title: "Check Size", action: #selector(checkFolderSize(_:)), keyEquivalent: "")
                checkSizeItem.representedObject = folder
                checkSizeItem.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: nil)
                submenu.addItem(checkSizeItem)
                
                // Set Threshold option
                let setThresholdItem = NSMenuItem(title: "Set Threshold...", action: #selector(setThresholdForFolder(_:)), keyEquivalent: "")
                setThresholdItem.representedObject = folder
                setThresholdItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
                submenu.addItem(setThresholdItem)
                
                // Remove option
                let removeItem = NSMenuItem(title: "Remove", action: #selector(removeFolder(_:)), keyEquivalent: "")
                removeItem.representedObject = folder
                removeItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
                submenu.addItem(removeItem)
                
                folderItem.submenu = submenu
                menu.addItem(folderItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Basic commands with icons
        let checkAllItem = NSMenuItem(title: "Check All Folders", action: #selector(checkAllFolders), keyEquivalent: "c")
        checkAllItem.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        menu.addItem(checkAllItem)
        
        let addFolderItem = NSMenuItem(title: "Add Folder...", action: #selector(addFolder), keyEquivalent: "a")
        addFolderItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        menu.addItem(addFolderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About section
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
        
        // Set the menu on the status item
        self.statusItem.menu = menu
        print("Menu updated with \(menu.items.count) items")
    }
    
    // MARK: - Folder and Threshold Management
    
    private func getMonitoredFolders() -> [String] {
        return defaults.array(forKey: foldersKey) as? [String] ?? []
    }
    
    private func getFolderThresholds() -> [String: Int] {
        return defaults.dictionary(forKey: folderThresholdsKey) as? [String: Int] ?? [:]
    }
    
    private func getFolderExceededStatus() -> [String: Bool] {
        return defaults.dictionary(forKey: folderExceededStatusKey) as? [String: Bool] ?? [:]
    }
    
    private func setFolderExceededStatus(_ folder: String, exceeded: Bool) {
        var status = getFolderExceededStatus()
        status[folder] = exceeded
        defaults.set(status, forKey: folderExceededStatusKey)
    }
    
    private func setThresholdForFolder(_ folder: String, threshold: Int) {
        var thresholds = getFolderThresholds()
        thresholds[folder] = threshold
        defaults.set(thresholds, forKey: folderThresholdsKey)
    }
    
    @objc private func addFolder() {
        // Use a standard NSOpenPanel - more reliable than custom configuration
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Folder to Monitor"
        openPanel.message = "Choose a folder to monitor its size"
        openPanel.prompt = "Monitor This Folder"
        
        // Ensure panel is visible by making it key window and ordering front
        if let window = NSApplication.shared.mainWindow {
            openPanel.beginSheetModal(for: window) { [weak self] response in
                guard let self = self else { return }
                if response == .OK, let url = openPanel.url {
                    self.processFolderSelection(url)
                }
            }
        } else {
            // No main window, use regular modal
            NSApp.activate(ignoringOtherApps: true)
            let response = openPanel.runModal()
            
            if response == .OK, let url = openPanel.url {
                processFolderSelection(url)
            }
        }
    }
    
    private func processFolderSelection(_ url: URL) {
        var folders = getMonitoredFolders()
        
        // Don't add duplicates
        if !folders.contains(url.path) {
            folders.append(url.path)
            defaults.set(folders, forKey: foldersKey)
            
            // Set default threshold for the new folder
            setThresholdForFolder(url.path, threshold: defaultThresholdMB)
            // Also initialize its exceeded status to false
            setFolderExceededStatus(url.path, exceeded: false)
            
            updateMenu()
            
            // Provide feedback with a notification
            let folderName = url.lastPathComponent
            
            let content = UNMutableNotificationContent()
            content.title = "Folder Added ✅"
            content.body = "Now monitoring: \(folderName)"
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "folder-added-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request)
            
            // Show alert first, then prompt for threshold
            let alert = NSAlert()
            alert.messageText = "Folder Added Successfully"
            alert.informativeText = "The folder '\(folderName)' has been added for monitoring."
            alert.addButton(withTitle: "Set Threshold")
            alert.addButton(withTitle: "Use Default")
            
            NSApp.activate(ignoringOtherApps: true)
            let buttonClicked = alert.runModal()
            
            if buttonClicked == .alertFirstButtonReturn {
                showThresholdDialog(for: url.path, folderName: folderName)
            }
        } else {
            // Show alert for duplicate folder
            let alert = NSAlert()
            alert.messageText = "Folder Already Monitored"
            alert.informativeText = "The selected folder is already being monitored."
            alert.addButton(withTitle: "OK")
            
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    
    @objc private func removeFolder(_ sender: NSMenuItem) {
        // Get the folder directly from representedObject instead of using index
        if let folder = sender.representedObject as? String {
            let folderPath = (folder as NSString).expandingTildeInPath
            let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
            
            // Ask for confirmation before removing
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Remove Folder?"
            confirmAlert.informativeText = "Are you sure you want to stop monitoring '\(folderName)'?"
            confirmAlert.addButton(withTitle: "Remove")
            confirmAlert.addButton(withTitle: "Cancel")
            
            // Set the first button (Remove) as destructive
            if let button = confirmAlert.buttons.first {
                button.hasDestructiveAction = true
            }
            
            NSApp.activate(ignoringOtherApps: true)
            let result = confirmAlert.runModal()
            
            if result == .alertFirstButtonReturn {
                // User confirmed, remove the folder
                var folders = getMonitoredFolders()
                if let index = folders.firstIndex(of: folder) {
                    folders.remove(at: index)
                    defaults.set(folders, forKey: foldersKey)
                    
                    // Remove threshold for this folder
                    var thresholds = getFolderThresholds()
                    thresholds.removeValue(forKey: folder)
                    defaults.set(thresholds, forKey: folderThresholdsKey)
                    
                    // Also remove its exceeded status
                    var status = getFolderExceededStatus()
                    status.removeValue(forKey: folder)
                    defaults.set(status, forKey: folderExceededStatusKey)
                    
                    updateMenu()
                    
                    // Provide feedback with a notification
                    let content = UNMutableNotificationContent()
                    content.title = "Folder Removed"
                    content.body = "'\(folderName)' is no longer being monitored."
                    content.sound = UNNotificationSound.default
                    
                    let request = UNNotificationRequest(
                        identifier: "folder-removed-\(Date().timeIntervalSince1970)",
                        content: content,
                        trigger: nil
                    )
                    
                    UNUserNotificationCenter.current().add(request)
                }
            }
        } else {
            print("Error: No folder specified in menu item")
        }
    }
    
    @objc private func setThresholdForFolder(_ sender: NSMenuItem) {
        // Get the folder directly from representedObject instead of using index
        if let folder = sender.representedObject as? String {
            let folderPath = (folder as NSString).expandingTildeInPath
            let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
            
            showThresholdDialog(for: folder, folderName: folderName)
        } else {
            print("Error: No folder specified in menu item")
        }
    }
    
    private func showThresholdDialog(for folder: String, folderName: String) {
        let alert = NSAlert()
        alert.messageText = "Set Size Threshold for \(folderName)"
        alert.informativeText = "Enter the size threshold in MB (e.g., 1000 for 1GB):"
        
        let currentThreshold = getFolderThresholds()[folder] ?? defaultThresholdMB
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = "\(currentThreshold)"
        textField.placeholderString = "Enter size in MB"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        // Make sure the alert is visible to the user
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == .alertFirstButtonReturn {
            let intValue = Int(textField.stringValue) ?? defaultThresholdMB
            let newThreshold = max(1, intValue)
            
            setThresholdForFolder(folder, threshold: newThreshold)
            updateMenu()
            
            // Show feedback notification
            let content = UNMutableNotificationContent()
            content.title = "Threshold Updated ✅"
            
            let formattedSize = formatFileSize(Int64(newThreshold) * 1024 * 1024)
            content.body = "Threshold for \(folderName) set to \(formattedSize)"
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "threshold-updated-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request)
            
            // Also show visual feedback
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Threshold Saved"
            confirmAlert.informativeText = "The threshold for '\(folderName)' has been set to \(formattedSize)."
            confirmAlert.addButton(withTitle: "OK")
            
            NSApp.activate(ignoringOtherApps: true)
            confirmAlert.runModal()
        }
    }
    
    // MARK: - Recursive Size Calculation with Depth Limit
    
    private func calculateFolderSize(at path: String, maxDepth: Int) -> Int64 {
        print("📁 Calculating size of folder: \(path) with max depth \(maxDepth)")
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        // Start the recursive calculation from depth 0
        return calculateSizeRecursive(at: url, currentDepth: 0, maxDepth: maxDepth, fileManager: fileManager)
    }

    private func calculateSizeRecursive(at url: URL, currentDepth: Int, maxDepth: Int, fileManager: FileManager) -> Int64 {
        // Base case: Depth limit reached
        if currentDepth > maxDepth {
            // print("   -> Depth limit (\(maxDepth)) reached at \(url.lastPathComponent), stopping recursion.")
            return 0
        }

        var totalSize: Int64 = 0
        var isDirectory: ObjCBool = false
        
        // Check if the current URL exists and is a directory
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            print("⚠️ Item does not exist or cannot be accessed: \(url.path)")
            return 0
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let size = attributes[FileAttributeKey.size] as? NSNumber {
                // Add the size of the directory entry itself (often small, but technically part of it)
                // Comment this out if you only want the sum of *contained* items.
                // totalSize += size.int64Value
            }

            // If it's not a directory, just return its size (this handles files passed directly)
            if !isDirectory.boolValue {
                 if let size = attributes[FileAttributeKey.size] as? NSNumber {
                    // print("   -> File found: \(url.lastPathComponent) size: \(formatFileSize(size.int64Value)) at depth \(currentDepth)")
                    return size.int64Value
                 } else {
                     print("⚠️ Could not get size attribute for file: \(url.path)")
                     return 0
                 }
            }

            // It's a directory, and we are within the depth limit, so proceed to read contents
            // print("   -> Directory found: \(url.lastPathComponent) at depth \(currentDepth). Reading contents...")
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .totalFileSizeKey, .fileSizeKey], options: [.skipsHiddenFiles])
           
            // print("   -> Found \(contents.count) items in \(url.lastPathComponent)")
            for itemURL in contents {
                // Recursively call for each item inside
                totalSize += calculateSizeRecursive(at: itemURL, currentDepth: currentDepth + 1, maxDepth: maxDepth, fileManager: fileManager)
            }

        } catch {
            print("❌ Error processing item \(url.path): \(error.localizedDescription)")
            // Silently fail for this item/subtree if errors occur
        }
        
        // print("   -> Total size for \(url.lastPathComponent) at depth \(currentDepth): \(formatFileSize(totalSize))")
        return totalSize
    }
    
    // MARK: - Ultra-Lightweight Size Calculation (REPLACED)
    /*
    private func quicklyCalculateFolderSize(at path: String) -> Int64 {
        print("📁 Calculating size of folder: \(path)")
        // The lightest possible size calculation - don't recurse, just top level
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        var totalSize: Int64 = 0
        
        do {
            // Only get contents at top level - much faster
            print("📑 Reading directory contents")
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            print("📊 Found \(contents.count) items in directory")
            
            for fileURL in contents {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    if let size = attributes[FileAttributeKey.size] as? NSNumber {
                        totalSize += size.int64Value
                    }
                } catch {
                    print("⚠️ Could not get attributes for: \(fileURL.path), error: \(error.localizedDescription)")
                    // Silently skip problem files
                }
            }
        } catch {
            print("❌ Error reading directory: \(error.localizedDescription)")
            // Silently fail if folder doesn't exist or isn't accessible
        }
        
        print("📊 Total folder size calculated: \(formatFileSize(totalSize))")
        return totalSize
    }
    */

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // MARK: - Notification Helpers
    
    private func safelySendNotification(title: String, body: String, identifier: String) {
        guard let center = try? UNUserNotificationCenter.current() else {
            print("Warning: Unable to access notification center. Showing alert instead.")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = body
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error posting notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Check and Notification Functions
    
    @objc private func checkFolderSize(_ sender: NSMenuItem) {
        print("⭐️ checkFolderSize called")
        
        if isScanning {
            print("❌ Already scanning - showing alert and returning")
            // Already scanning, show notification
            let alert = NSAlert()
            alert.messageText = "Scan in Progress"
            alert.informativeText = "Please wait for the current scan to complete."
            alert.runModal()
            return
        }
        
        // Get the folder directly from representedObject instead of using index
        if let folder = sender.representedObject as? String {
            print("✅ Got folder from representedObject: \(folder)")
            isScanning = true
            let folderPath = (folder as NSString).expandingTildeInPath
            print("📂 Expanded folder path: \(folderPath)")
            
            // Verify folder exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: folderPath) {
                print("❌ ERROR: Folder does not exist at path: \(folderPath)")
                isScanning = false
                
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Folder Not Found"
                    alert.informativeText = "The folder at \(folderPath) does not exist or cannot be accessed."
                    alert.runModal()
                }
                return
            }
            
            // Show scanning indicator in menu bar
            if let button = statusItem.button {
                button.title = "⏳"
                print("⏳ Changed menu bar icon to scanning indicator")
            } else {
                print("❌ Status button is nil")
            }
            
            print("🔍 Starting size calculation for: \(folderPath)")
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { 
                    print("❌ Self is nil in async block")
                    return 
                }
                
                print("🧮 Calculating folder size (depth limited)...")
                // Call the new depth-limited function with maxDepth = 5
                let folderSize = self.calculateFolderSize(at: folderPath, maxDepth: 5)
                let formattedSize = self.formatFileSize(folderSize)
                let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
                let threshold = self.getFolderThresholds()[folder] ?? self.defaultThresholdMB
                let formattedThreshold = self.formatFileSize(Int64(threshold) * 1024 * 1024)
                
                print("📊 Size calculation complete: \(folderName) is \(formattedSize)")
                
                DispatchQueue.main.async {
                    // Update the exceeded status in UserDefaults
                    let exceededStatus = self.getFolderExceededStatus()
                    let exceedsThreshold = folderSize > (Int64(threshold) * 1024 * 1024)
                    self.setFolderExceededStatus(folder, exceeded: exceedsThreshold)

                    // Restore icon (always use default icon now)
                    if let button = self.statusItem.button {
                        button.title = "💾" // Always set back to the default icon
                        print("💾 Restored menu bar icon")
                    } else {
                        print("❌ Status button is nil when restoring icon")
                    }
                    
                    print("📱 Creating notification with folder size result")
                    let notificationBody = "\(folderName) is currently \(formattedSize)\nThreshold: \(formattedThreshold)"
                    self.safelySendNotification(
                        title: "Folder Size",
                        body: notificationBody,
                        identifier: "size-\(folderPath.hash)"
                    )
                    
                    // Also show an alert with the result
                    print("🪟 Showing alert with size result")
                    let alert = NSAlert()
                    alert.messageText = "Folder Size"
                    alert.informativeText = "\(folderName) is currently \(formattedSize)\nThreshold: \(formattedThreshold)"
                    alert.addButton(withTitle: "OK")
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                    
                    self.isScanning = false
                    print("✅ Folder size check complete")
                }
            }
        } else {
            print("❌ ERROR: No folder specified in menu item representedObject")
        }
    }
    
    @objc private func checkAllFolders() {
        if isScanning {
            // Already scanning, show notification
            let alert = NSAlert()
            alert.messageText = "Scan in Progress"
            alert.informativeText = "Please wait for the current scan to complete."
            alert.runModal()
            return
        }
        
        isScanning = true
        let folders = getMonitoredFolders()
        
        // Show scanning indicator in menu bar
        if let button = statusItem.button {
            button.title = "⏳"
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var results = [(name: String, size: Int64, threshold: Int64, exceeded: Bool)]()
            var anyExceedsThreshold = false
            
            for folder in folders {
                let folderPath = (folder as NSString).expandingTildeInPath
                // Call the new depth-limited function with maxDepth = 5
                let folderSize = self.calculateFolderSize(at: folderPath, maxDepth: 5)
                let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
                let thresholdMB = self.getFolderThresholds()[folder] ?? self.defaultThresholdMB
                let thresholdBytes = Int64(thresholdMB) * 1024 * 1024
                let exceeds = folderSize > thresholdBytes
                
                // Update status for this specific folder immediately after check
                self.setFolderExceededStatus(folder, exceeded: exceeds)

                results.append((folderName, folderSize, thresholdBytes, exceeds))
                
                if exceeds {
                    anyExceedsThreshold = true
                }
            }
            
            DispatchQueue.main.async {
                // Restore icon
                if let button = self.statusItem.button {
                    button.title = "💾"
                }
                
                if results.isEmpty {
                    // No folders to check
                    return
                }
                
                let title: String
                var body = ""
                
                if anyExceedsThreshold {
                    title = "Size Threshold Exceeded"
                    
                    for (name, size, threshold, exceeded) in results {
                        let formattedSize = self.formatFileSize(size)
                        let formattedThreshold = self.formatFileSize(threshold)
                        let status = exceeded ? "⚠️ EXCEEDS" : "✓ OK"
                        body += "\(name): \(formattedSize) [\(status)]\n"
                    }
                    
                    // Mark as notified today
                    self.defaults.set(Date(), forKey: self.lastNotificationKey)
                } else {
                    title = "All Folders Under Threshold"
                    
                    for (name, size, threshold, _) in results {
                        let formattedSize = self.formatFileSize(size)
                        let formattedThreshold = self.formatFileSize(threshold)
                        body += "\(name): \(formattedSize) / \(formattedThreshold)\n"
                    }
                }
                
                body = body.trimmingCharacters(in: .newlines)
                self.safelySendNotification(
                    title: title,
                    body: body,
                    identifier: "size-check-all"
                )
                
                self.isScanning = false
            }
        }
    }
    
    private func checkFolderSizesAndNotifyIfNeeded() {
        // Don't scan if already scanning
        if isScanning {
            return
        }
        
        // Check if already notified today
        if let lastDate = defaults.object(forKey: lastNotificationKey) as? Date,
           Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            return // Already notified today
        }
        
        isScanning = true
        let folders = getMonitoredFolders()
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            var anyExceedsThreshold = false
            var exceededFolders = [(name: String, size: Int64, threshold: Int64)]()
            
            for folder in folders {
                let folderPath = (folder as NSString).expandingTildeInPath
                // Call the new depth-limited function with maxDepth = 5
                let folderSize = self.calculateFolderSize(at: folderPath, maxDepth: 5)
                let thresholdMB = self.getFolderThresholds()[folder] ?? self.defaultThresholdMB
                let thresholdBytes = Int64(thresholdMB) * 1024 * 1024
                
                if folderSize > thresholdBytes {
                    // Update status for this folder
                    self.setFolderExceededStatus(folder, exceeded: true)
                    let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
                    exceededFolders.append((folderName, folderSize, thresholdBytes))
                    anyExceedsThreshold = true
                } else {
                    // Update status for this folder
                    self.setFolderExceededStatus(folder, exceeded: false)
                }
            }
            
            DispatchQueue.main.async {
                if anyExceedsThreshold {
                    var body = "The following folders exceed their thresholds:\n\n"
                    for (name, size, threshold) in exceededFolders {
                        let formattedSize = self.formatFileSize(size)
                        let formattedThreshold = self.formatFileSize(threshold)
                        body += "\(name): \(formattedSize) exceeds \(formattedThreshold)\n"
                    }
                    
                    body = body.trimmingCharacters(in: .newlines)
                    self.safelySendNotification(
                        title: "Folder Size Alert",
                        body: body,
                        identifier: "threshold-exceeded"
                    )
                    
                    self.defaults.set(Date(), forKey: self.lastNotificationKey)
                }
                
                self.isScanning = false
            }
        }
    }
    
    // MARK: - Scheduling
    
    private func scheduleNextCheck() {
        // Calculate time until 16:20 today or tomorrow
        let now = Date()
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        
        dateComponents.hour = 16
        dateComponents.minute = 20
        dateComponents.second = 0
        
        guard var targetDate = calendar.date(from: dateComponents) else { return }
        
        // If it's already past 16:20, schedule for tomorrow
        if now >= targetDate {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }
        
        // Calculate delay interval
        let delay = targetDate.timeIntervalSince(now)
        
        // Schedule using a single dispatch
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.checkFolderSizesAndNotifyIfNeeded()
            self?.scheduleNextCheck() // Schedule next check
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📣 Will present notification: \(notification.request.identifier)")
        
        // Use modern API when available
        if #available(macOS 11.0, *) {
            print("📱 Using modern notification presentation (banner + sound)")
            completionHandler([.banner, .sound])
        } else {
            print("📱 Using legacy notification presentation (alert + sound)")
            completionHandler([.alert, .sound])
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Folder Monitor"
        alert.informativeText = """
        A lightweight app that monitors folder sizes.
        
        • Monitors multiple folders
        • Custom thresholds for each folder
        • Ultra-fast, non-recursive scanning
        • Daily checks at 16:20
        
        Version 1.0
        """
        alert.addButton(withTitle: "OK")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    // Diagnose menu issues
    private func checkMenuStatus() {
        print("Menu status check:")
        print(" - Status item exists: \(statusItem != nil)")
        print(" - Button exists: \(statusItem?.button != nil)")
        print(" - Menu exists: \(statusItem?.menu != nil)")
        print(" - Menu item count: \(statusItem?.menu?.items.count ?? 0)")
        
        if statusItem?.menu == nil {
            print("Menu is nil - attempting to fix")
            updateMenu()
            
            // Force update visibility
            if let button = statusItem?.button {
                button.isHidden = false
                button.isEnabled = true
            }
        }
    }
} 