defaults delete com.local.DenonControl
#!/bin/sh
set -e
cd "$(dirname "$0")"

swift build -c release

rm -rf DenonControl.app
mkdir -p DenonControl.app/Contents/MacOS DenonControl.app/Contents/Resources
cp .build/release/DenonControl DenonControl.app/Contents/MacOS/DenonControl
cp Resources/Info.plist DenonControl.app/Contents/Info.plist
cp Resources/AppIcon.icns DenonControl.app/Contents/Resources/AppIcon.icns
cp Resources/DenonGlyphTemplate.png DenonControl.app/Contents/Resources/DenonGlyphTemplate.png

codesign --force --deep --sign - DenonControl.app 2>/dev/null
echo "Built DenonControl.app"
