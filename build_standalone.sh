#!/usr/bin/env bash
# Builds AgoraRecorder.dylib directly with clang, without Theos' make
# machinery. Useful if you just want the raw Substrate dylib for a quick
# scp-and-install onto a jailbroken device.
#
# Requires:
#   - Xcode command line tools with an iOS SDK (for iphoneos sysroot)
#   - CydiaSubstrate headers/stub library (substrate.h + libsubstrate.dylib),
#     normally pulled from $THEOS/vendor or your jailbreak toolchain
#   - ldid (for ad-hoc signing the resulting dylib)
#
# Usage:
#   SYSROOT=/path/to/iPhoneOS.sdk SUBSTRATE_DIR=/path/to/substrate ./build_standalone.sh

set -euo pipefail

: "${SYSROOT:?Set SYSROOT to your iPhoneOS SDK path}"
: "${SUBSTRATE_DIR:?Set SUBSTRATE_DIR to the dir containing substrate.h and libsubstrate.dylib}"

ARCH=arm64
OUT=AgoraRecorder.dylib

clang -arch "$ARCH" \
  -isysroot "$SYSROOT" \
  -miphoneos-version-min=14.0 \
  -fobjc-arc \
  -dynamiclib \
  -I "$SUBSTRATE_DIR" \
  -L "$SUBSTRATE_DIR" \
  -lsubstrate \
  -framework Foundation \
  -framework UIKit \
  -framework AVFoundation \
  Tweak.m AgoraRecorder.m RecordingsListController.m \
  -o "$OUT"

# Ad-hoc sign so the dylib can be loaded by the host process.
if command -v ldid >/dev/null 2>&1; then
  ldid -S "$OUT"
else
  echo "Warning: ldid not found; sign $OUT manually before copying to device." >&2
fi

echo "Built $OUT"
echo "Copy it to, e.g., /Library/MobileSubstrate/DynamicLibraries/ on the device,"
echo "alongside a matching AgoraRecorder.plist Filter restricting it to your app's bundle ID."
