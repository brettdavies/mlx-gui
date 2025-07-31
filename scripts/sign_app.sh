#!/bin/bash

# MLX-GUI App Signing and Notarization Script
# This script will zip the app, submit for notarization, and staple the result

set -e  # Exit on any error

echo "🍎 MLX-GUI App Signing and Notarization"
echo "======================================="

# Configuration
APP_PATH="dist/MLX-GUI.app"
ZIP_PATH="dist/MLX-GUI.zip"
APPLE_ID="matt@rogers.uno"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: $APP_PATH not found!"
    echo "Please run the build script first to create the app bundle."
    exit 1
fi

# Get credentials interactively
echo ""
echo "📝 Please enter your Apple Developer credentials:"
read -p "Team ID: " TEAM_ID

if [ -z "$TEAM_ID" ]; then
    echo "❌ Error: Team ID is required"
    exit 1
fi

echo -n "App-specific password for $APPLE_ID: "
read -s APP_PASSWORD
echo ""

if [ -z "$APP_PASSWORD" ]; then
    echo "❌ Error: Password is required"
    exit 1
fi

echo ""
echo "🗂️  Creating zip archive..."
# Remove existing zip if it exists
if [ -f "$ZIP_PATH" ]; then
    rm "$ZIP_PATH"
fi

# Create zip using ditto (preserves macOS metadata)
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "✅ Created $ZIP_PATH"

echo ""
echo "📤 Submitting to Apple for notarization..."
echo "This may take several minutes..."

# Submit for notarization
SUBMIT_RESULT=$(xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait)

echo "$SUBMIT_RESULT"

# Check if submission was successful
if echo "$SUBMIT_RESULT" | grep -q "status: Accepted"; then
    echo "✅ Notarization successful!"

    echo ""
    echo "📎 Stapling notarization to app..."
    xcrun stapler staple "$APP_PATH"
    echo "✅ App successfully stapled!"

    echo ""
    echo "🎉 MLX-GUI.app is now signed and notarized!"
    echo "📁 Location: $APP_PATH"
    echo "📦 Zip archive: $ZIP_PATH"

else
    echo "❌ Notarization failed!"
    echo "Please check the output above for details."
    exit 1
fi

echo ""
echo "🔍 Verifying notarization..."
xcrun stapler validate "$APP_PATH"
echo "✅ Notarization verification complete!"
