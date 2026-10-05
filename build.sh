#!/bin/zsh
set -eu
cd "${0:A:h}"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
build_arguments=(--disable-sandbox -c release)
run=false
for argument in "$@"; do
  case "$argument" in
    --universal) build_arguments+=(--arch arm64 --arch x86_64) ;;
    --run) run=true ;;
    *) print -u2 "Unknown option: $argument"; exit 1 ;;
  esac
done
swift build "${build_arguments[@]}"
binary_directory=$(swift build "${build_arguments[@]}" --show-bin-path)
app="$PWD/build/Menyradio.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_directory/Menyradio" "$app/Contents/MacOS/Menyradio"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
# Finder displays the bundle directory timestamp, not its updated contents.
touch "$app"
print "Built $app"
if $run; then open "$app"; fi
