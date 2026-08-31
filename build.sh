#!/bin/sh
set -e
cd "$(dirname "$0")"

swift build -c release

rm -rf DenonVol.app
mkdir -p DenonVol.app/Contents/MacOS DenonVol.app/Contents/Resources
cp .build/release/DenonVol DenonVol.app/Contents/MacOS/DenonVol
cp Resources/Info.plist DenonVol.app/Contents/Info.plist
cp Resources/AppIcon.icns DenonVol.app/Contents/Resources/AppIcon.icns

codesign --force --deep --sign - DenonVol.app 2>/dev/null
echo "Built DenonVol.app"