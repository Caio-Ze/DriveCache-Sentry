#!/bin/bash

# Check for --no-run flag (used in CI)
NO_RUN=false
for arg in "$@"; do
  if [ "$arg" = "--no-run" ]; then
    NO_RUN=true
  fi
done

echo "=== Building DriveCache Sentry ==="
echo "Building app (this may take a moment)..."

# Create build directory if it doesn't exist
mkdir -p build

# Compile the main.swift file
xcrun swiftc -o build/LightMenuBarApp main.swift MyMenuBarApp/MyMenuBarApp/AppDelegate.swift \
  -framework Cocoa -framework UserNotifications

# Check if compilation was successful
if [ $? -ne 0 ]; then
  echo "Build failed. Please check for errors."
  exit 1
fi

# Kill any existing instances if we're going to run
if [ "$NO_RUN" = false ]; then
  killall LightMenuBarApp &>/dev/null
fi

# Make it executable just in case
chmod +x build/LightMenuBarApp

# Create the .app bundle structure if it doesn't exist
mkdir -p build/LightMenuBarApp.app/Contents/MacOS

# Copy the executable to the app bundle
cp build/LightMenuBarApp build/LightMenuBarApp.app/Contents/MacOS/

# Create an Info.plist for the app bundle
cat > build/LightMenuBarApp.app/Contents/Info.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LightMenuBarApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.drivcachesentry.app</string>
    <key>CFBundleName</key>
    <string>DriveCache Sentry</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOL

echo "Build successful!"

# Only run the app if not in CI mode
if [ "$NO_RUN" = false ]; then
  echo "Running app..."
  
  # Start the app
  open build/LightMenuBarApp.app
  
  echo "App running in the background. Look for the 💾 icon in your menu bar."
  echo "Features:"
  echo "- Monitor multiple folders simultaneously"
  echo "- Ultra-fast, non-recursive folder scanning"
  echo "- Anti-freeze protection with visual indicators"
  echo "- Daily checks at 16:20 with threshold-based notifications"
  echo ""
  echo "To configure folders and settings, click the 💾 icon in the menu bar."
else
  echo "App built successfully but not running (--no-run flag detected)"
  echo "App bundle created at: $(pwd)/build/LightMenuBarApp.app"
fi 