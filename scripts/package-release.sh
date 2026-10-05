#!/bin/zsh
set -eu
cd "${0:A:h:h}"
project_directory="$PWD"
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
  framework="$app/Contents/Frameworks/Sparkle.framework"
  for service in "$framework"/Versions/B/XPCServices/*.xpc(N); do
    codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$service"
  done
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$framework/Versions/B/Autoupdate"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$framework/Versions/B/Updater.app"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$framework"
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

if $notarize; then
  tools="$project_directory/.build/artifacts/sparkle/Sparkle/bin"
  : "${SPARKLE_TOOLS:=$tools}"
  update_directory="$project_directory/build/sparkle-updates/$version"
  mkdir -p "$update_directory"
  cp "$archive" "$update_directory/"
  if [[ -f "$project_directory/appcast.xml" ]]; then
    cp "$project_directory/appcast.xml" "$update_directory/appcast.xml"
  fi
  "$SPARKLE_TOOLS/generate_appcast" --account Menyradio --maximum-deltas 0 \
    --download-url-prefix "https://github.com/viktorbijlenga/menyradio/releases/download/v$version/" \
    --link "https://github.com/viktorbijlenga/menyradio" "$update_directory"
  cp "$update_directory/appcast.xml" "$project_directory/appcast.xml"
fi
