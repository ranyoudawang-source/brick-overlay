#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build/BrickOverlay.app/Contents/MacOS
swiftc -parse-as-library -target arm64-apple-macosx26.0 Appearance.swift Overlay.swift -o build/BrickOverlay.app/Contents/MacOS/BrickOverlay
cp Info.plist build/BrickOverlay.app/Contents/Info.plist
codesign --force --sign - build/BrickOverlay.app
