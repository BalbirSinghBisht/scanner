#!/bin/bash
set -e

echo "=========================================================="
echo "  Building Gallery Android App (.apk)                     "
echo "=========================================================="

# 1. Build release APK targeting physical Android devices (arm64 & armv7)
# Skipping x86_64 emulator ABI cuts compilation time by over 40%
if [ -n "$GITHUB_RUN_NUMBER" ]; then
  echo "Using CI build number: $GITHUB_RUN_NUMBER"
  flutter build apk --release --target-platform android-arm,android-arm64 --build-number="$GITHUB_RUN_NUMBER"
else
  flutter build apk --release --target-platform android-arm,android-arm64
fi

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
