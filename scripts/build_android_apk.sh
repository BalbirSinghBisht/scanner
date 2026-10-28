#!/bin/bash
set -e

echo "=========================================================="
echo "  Building Gallery Android App (.apk)                     "
echo "=========================================================="

# 1. Build release APK
flutter build apk --release

# 2. Package and copy with standard names
OUTPUT_DIR="build"
APK_SOURCE="build/app/outputs/flutter-apk/app-release.apk"

mkdir -p "$OUTPUT_DIR"
cp "$APK_SOURCE" "$OUTPUT_DIR/Gallery.apk"
cp "$APK_SOURCE" "$OUTPUT_DIR/gallery.apk"
cp "$APK_SOURCE" "$OUTPUT_DIR/app-release.apk"

echo "=========================================================="
echo " SUCCESS! Gallery APK ready: $OUTPUT_DIR/Gallery.apk"
echo " File size: $(ls -lh "$OUTPUT_DIR/Gallery.apk" | awk '{print $5}')"
echo "=========================================================="
