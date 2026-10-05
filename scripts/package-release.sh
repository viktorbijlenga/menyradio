#!/bin/zsh
set -eu
cd "${0:A:h:h}"
./build.sh --universal
app="$PWD/build/Menyradio.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
codesign --verify --deep --strict "$app"
architectures=$(lipo -archs "$app/Contents/MacOS/Menyradio")
for architecture in arm64 x86_64; do
  if [[ " $architectures " != *" $architecture "* ]]; then
    print -u2 "Missing release architecture: $architecture"
    exit 1
  fi
done
mkdir -p build/releases
archive="Menyradio-$version-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "build/releases/$archive"
cd build/releases
shasum -a 256 "$archive" > "$archive.sha256"
print "Packaged $PWD/$archive"
