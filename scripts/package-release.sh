#!/bin/zsh
set -eu
cd "${0:A:h:h}"
notarize=false
for argument in "$@"; do
  case "$argument" in
    --notarize) notarize=true ;;
    *) print -u2 "Unknown option: $argument"; exit 1 ;;
  esac
done
if $notarize; then
  : "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate name or SHA-1}"
  : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool Keychain profile name}"
  identities=$(security find-identity -v -p codesigning)
  if ! print -r -- "$identities" | /usr/bin/grep -F -- "$SIGNING_IDENTITY" | /usr/bin/grep -q 'Developer ID Application:'; then
    print -u2 "No matching valid Developer ID Application identity found in Keychain."
    exit 1
  fi
fi
./build.sh --universal
app="$PWD/build/Menyradio.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
if $notarize; then
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$app"
fi
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
if $notarize; then
  submission="$PWD/build/releases/Menyradio-$version-notarization.zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$submission"
  xcrun notarytool submit "$submission" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  codesign --verify --deep --strict "$app"
  spctl --assess --type execute --verbose=2 "$app"
  rm "$submission"
else
  archive="Menyradio-$version-macOS-unsigned.zip"
fi
ditto -c -k --sequesterRsrc --keepParent "$app" "build/releases/$archive"
cd build/releases
shasum -a 256 "$archive" > "$archive.sha256"
print "Packaged $PWD/$archive"
