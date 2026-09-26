#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

xcodebuild build -project BluetoothStatus.xcodeproj -scheme BluetoothStatus \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO -quiet

source_app="$PWD/DerivedData/Build/Products/Release/BluetoothStatus.app"
version=$(plutil -extract CFBundleShortVersionString raw -o - "$source_app/Contents/Info.plist")
mkdir -p dist
package_dir=$(mktemp -d "$PWD/dist/BluetoothStatus-${version}-XXXXXX")
app="$package_dir/BluetoothStatus.app"
archive="BluetoothStatus-${version}-macOS-arm64"

ditto "$source_app" "$app"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
test "$(lipo -archs "$app/Contents/MacOS/BluetoothStatus")" = arm64
test "$(plutil -extract LSUIElement raw -o - "$app/Contents/Info.plist")" = true
test -s "$app/Contents/Resources/AppIcon.icns"
test -s "$app/Contents/Resources/Assets.car"

ditto -c -k --sequesterRsrc --keepParent "$app" "$package_dir/$archive.zip"
hdiutil create -volname 'Bluetooth Status' -srcfolder "$app" \
  -format UDZO "$package_dir/$archive.dmg"
unzip -tq "$package_dir/$archive.zip"
hdiutil verify "$package_dir/$archive.dmg"

(
  cd "$package_dir"
  shasum -a 256 "$archive.zip" "$archive.dmg" > SHA256SUMS
)
printf 'Packages: %s\n' "$package_dir"
