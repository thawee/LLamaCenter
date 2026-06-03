#!/bin/bash

# Configuration
APP_NAME="LlamaCenter"
APP_VERSION="0.0.1"
BUNDLE_ID="com.user.LlamaCenter"
EXECUTABLE_NAME="StatusDashboard"

echo "🔨 Building $APP_NAME v$APP_VERSION..."

# 1. Build the binary
swift build -c release

# 2. Create the Bundle Structure
APP_BUNDLE="$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy assets
cp ".build/release/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# 4. Create Info.plist
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Thawee.p. All rights reserved.</string>
</dict>
</plist>
EOF

echo "✅ Success! $APP_BUNDLE created."
echo "🚀 You can now run it with: open $APP_BUNDLE"
