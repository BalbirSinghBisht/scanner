#!/bin/bash
set -e

echo "=========================================================="
echo "  Building Gallery iOS App for Scarlet & Sideloading      "
echo "=========================================================="

# 1. Clean old intermediate packaging if any
OUTPUT_IPA="build/Gallery.ipa"
SCARLET_IPA="build/gallery-scarlet.ipa"
rm -f "$OUTPUT_IPA" "$SCARLET_IPA" build/*.ipa

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
cp "../../../$OUTPUT_IPA" "../../../$SCARLET_IPA"
popd > /dev/null

rm -rf "$PAYLOAD_DIR"

echo "=========================================================="
echo " SUCCESS! Gallery IPA ready: $SCARLET_IPA"
echo " File size: $(ls -lh "$SCARLET_IPA" | awk '{print $5}')"
echo "=========================================================="
