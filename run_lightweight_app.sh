#!/bin/bash

# === Configuration ===
APP_NAME="LightMenuBarApp"
APP_BUNDLE_NAME="${APP_NAME}.app"
VERSION="1.0.1" # Match version in About dialog
BUILD_DIR="build"
RESOURCES_DIR="Resources"
ICON_NAME="AppIcon.icns"
FINAL_ZIP_NAME="DriveCache-Sentry-v${VERSION}.zip"

# macOS Deployment Target (Monterey)
DEPLOYMENT_TARGET="12.0"

# Paths
INTEL_BUILD_PATH="${BUILD_DIR}/intel/${APP_NAME}"
ARM_BUILD_PATH="${BUILD_DIR}/arm/${APP_NAME}"
UNIVERSAL_EXEC_PATH="${BUILD_DIR}/universal/${APP_NAME}"
APP_BUNDLE_PATH="${BUILD_DIR}/${APP_BUNDLE_NAME}"
FINAL_ZIP_PATH="${BUILD_DIR}/${FINAL_ZIP_NAME}"

SOURCE_FILES=("main.swift" "MyMenuBarApp/MyMenuBarApp/AppDelegate.swift")
FRAMEWORKS=("-framework" "Cocoa" "-framework" "UserNotifications")

# Check for --no-run flag (used in CI or just for building)
NO_RUN=false
for arg in "$@"; do
  if [ "$arg" = "--no-run" ]; then
    NO_RUN=true
  fi
done

echo "=== Building DriveCache Sentry v${VERSION} ==="

# Clean previous build
echo "Cleaning previous build..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/intel"
mkdir -p "${BUILD_DIR}/arm"
mkdir -p "${BUILD_DIR}/universal"

# --- Compile for Intel (x86_64) ---
echo "Compiling for Intel (x86_64)..."
xcrun swiftc -target "x86_64-apple-macos${DEPLOYMENT_TARGET}" \
  -o "${INTEL_BUILD_PATH}" "${SOURCE_FILES[@]}" "${FRAMEWORKS[@]}"

if [ $? -ne 0 ]; then
  echo "Intel build failed. Please check for errors."
  exit 1
fi

# --- Compile for Apple Silicon (arm64) ---
echo "Compiling for Apple Silicon (arm64)..."
xcrun swiftc -target "arm64-apple-macos${DEPLOYMENT_TARGET}" \
  -o "${ARM_BUILD_PATH}" "${SOURCE_FILES[@]}" "${FRAMEWORKS[@]}"

if [ $? -ne 0 ]; then
  echo "Apple Silicon build failed. Please check for errors."
  exit 1
fi

# --- Create Universal Binary with lipo ---
echo "Creating Universal Binary..."
lipo -create -output "${UNIVERSAL_EXEC_PATH}" "${INTEL_BUILD_PATH}" "${ARM_BUILD_PATH}"

if [ $? -ne 0 ]; then
  echo "lipo failed. Could not create universal binary."
  exit 1
fi

# Make executable
chmod +x "${UNIVERSAL_EXEC_PATH}"

# --- Create .app Bundle Structure ---
echo "Creating application bundle structure..."
mkdir -p "${APP_BUNDLE_PATH}/Contents/MacOS"
mkdir -p "${APP_BUNDLE_PATH}/Contents/Resources"

# Copy Universal Binary to .app
echo "Copying universal binary..."
cp "${UNIVERSAL_EXEC_PATH}" "${APP_BUNDLE_PATH}/Contents/MacOS/${APP_NAME}"

# Copy Icon to .app
if [ -f "${RESOURCES_DIR}/${ICON_NAME}" ]; then
  echo "Copying icon..."
  cp "${RESOURCES_DIR}/${ICON_NAME}" "${APP_BUNDLE_PATH}/Contents/Resources/"
else
  echo "Warning: ${RESOURCES_DIR}/${ICON_NAME} not found. App will use default icon."
fi

# --- Create Info.plist ---
echo "Creating Info.plist..."
cat > "${APP_BUNDLE_PATH}/Contents/Info.plist" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>${ICON_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.drivcachesentry.app</string>
    <key>CFBundleName</key>
    <string>DriveCache Sentry</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>${DEPLOYMENT_TARGET}</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOL

echo "Application bundle created at: ${APP_BUNDLE_PATH}"

# --- Code Signing and Notarization Placeholder ---
# If you have an Apple Developer ID, uncomment and configure these steps:
echo "Skipping Code Signing & Notarization (Requires Apple Developer ID)"
# DEVELOPER_ID_APPLICATION="Your Developer ID Application Certificate Name"
# echo "Signing application bundle..."
# codesign --force --deep --options=runtime --sign "${DEVELOPER_ID_APPLICATION}" "${APP_BUNDLE_PATH}"
# if [ $? -ne 0 ]; then
#   echo "Code signing failed."
#   # Decide if you want to exit or continue without signing
# fi
# echo "Code signing complete."
# Add notarization steps here using notarytool if desired

# --- Package into .zip --- 
echo "Packaging into .zip archive..."
( # Run zip in a subshell to avoid changing directory of the main script
  # First, ensure INSTALL.md exists in the root to be copied
  if [ ! -f "../INSTALL.md" ]; then 
    echo "Error: INSTALL.md not found in project root. Cannot include in zip." >&2
    exit 1 # Exit subshell with error
  fi
  
  cd "${BUILD_DIR}" || exit 1
  
  # Clean potential old artifacts inside build before zipping
  # Be careful with rm -rf
  # rm -rf ./* # Maybe too aggressive? Let's just zip what we need.

  # Copy INSTALL.md into the build dir temporarily for zipping
  cp ../INSTALL.md .
  
  # Create zip with the App bundle AND the install instructions
  zip -r -q "${FINAL_ZIP_NAME}" "${APP_BUNDLE_NAME}" "INSTALL.md"
  
  # Remove the temporary copy of INSTALL.md
  rm INSTALL.md 
)
if [ $? -ne 0 ]; then
  echo "Failed to create .zip archive."
  exit 1
fi
echo "Successfully packaged application into: ${FINAL_ZIP_PATH}"

# --- Clean up temporary files ---
echo "Cleaning up temporary build files..."
rm -rf "${BUILD_DIR}/intel"
rm -rf "${BUILD_DIR}/arm"
rm -rf "${BUILD_DIR}/universal"

echo "Build process complete!"

# --- Run or Output Info ---
if [ "$NO_RUN" = false ]; then
  echo "Killing existing instances (if any)..."
  killall "${APP_NAME}" &>/dev/null
  echo "Running app..."
  open "${APP_BUNDLE_PATH}"
  echo "App running in the background. Look for the 💾 icon in your menu bar."
else
  echo "App built successfully but not running (--no-run flag detected)"
  echo "Distribution package created at: $(pwd)/${FINAL_ZIP_PATH}"
fi 

exit 0 