#!/bin/bash
set -e

echo "=========================================================="
echo "  Building Scanner iOS App for TrollStore (Unsigned IPA)  "
echo "=========================================================="

# 1. Clean old intermediate packaging if any
OUTPUT_IPA="build/scanner-trollstore.ipa"
rm -f "$OUTPUT_IPA"

# 2. Build iOS release without codesigning
flutter build ios --release --no-codesign

# 3. Package Runner.app into standard IPA Payload structure
BUILD_DIR="build/ios/iphoneos"
PAYLOAD_DIR="$BUILD_DIR/Payload"

rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"

cp -R "$BUILD_DIR/Runner.app" "$PAYLOAD_DIR/"

# 4. Zip Payload folder into .ipa
pushd "$BUILD_DIR" > /dev/null
zip -r -q "../../../$OUTPUT_IPA" Payload
popd > /dev/null

rm -rf "$PAYLOAD_DIR"

echo "=========================================================="
echo " SUCCESS! TrollStore IPA ready: $OUTPUT_IPA"
echo " File size: $(ls -lh "$OUTPUT_IPA" | awk '{print $5}')"
echo ""
echo " How to use with TrollStore:"
echo " 1. Send '$OUTPUT_IPA' to your friend via WhatsApp Document."
echo " 2. Your friend taps the file in WhatsApp -> Share -> Open in TrollStore."
echo " 3. Tap 'Install'. The app installs permanently with full permissions!"
echo "=========================================================="
