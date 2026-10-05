# Development notes

Menyradio uses Swift, AppKit, SwiftUI and AVPlayer, with no third-party dependencies. It targets macOS 14 or later and uses a Swift 6 toolchain.

Open `Package.swift` in Xcode to edit the source. Use `./build.sh` to package the executable as a menu-only app with its Info.plist and icon. The script signs the local build ad hoc and updates the bundle timestamp for Finder. Developer ID signing and notarization are not configured.

Preferences use UserDefaults. Channel responses are cached under Application Support/Menyradio for 24 hours; failed refreshes retain the previous cache. The first launch needs a successful channel request.

## Release packaging

Run `./scripts/package-release.sh` to build a universal app for Apple Silicon and Intel, verify its ad hoc signature and both architectures, and create a ZIP plus SHA-256 checksum under `build/releases`. The release version comes from `Resources/Info.plist`. GitHub releases contain these two files. Developer ID signing and notarization are still required for distribution without the unidentified-developer prompt; current releases document the macOS Open Anyway procedure.

## Small architecture

- `MenyradioApp`: accessory-app lifecycle.
- `StatusBarController`: native NSStatusItem and NSMenu list, dynamic AppKit tooltip, AirPlay window and SwiftUI Settings window.
- `RadioLibrary`: channel cache, ordered favourites and cached programme titles for the menu.
- `SverigesRadioAPI`: injectable URLSession and Codable response models, independent of playback.
- `RadioPlayer`: one AVPlayer, connection status, bounded reconnect and independent metadata polling.
- `PlaybackSupport`: retry recovery and timestamp-validated metadata caching, tested without audio or network access.
- `NowPlayingService`: native live-stream metadata and play/pause/stop media commands.
- `SettingsView`: channel selection, ordering and login launch.

Inspired by [RÚV Noise](https://github.com/jokull/ruv-noise): menu bar UX, app-owned player and explicit playback state. This implementation is original and omits its custom stream decoder, AVAudioEngine DSP, simulated FM effects, news scheduling and updater.

## Verified Sveriges Radio API

Inspected official documentation and live responses on 2026-10-05. [SR warns that the public API is no longer maintained](https://www.sverigesradio.se/artikel/dokumentation-for-api-version-2), though these endpoints responded during development:

| Endpoint (HTTPS base `https://api.sr.se/api/v2/`) | Usage |
| --- | --- |
| `channels?format=json&pagination=false` | IDs, names and `liveaudio.url`; filter P1/P2/P3 and names beginning `P4 ` |
| `scheduledepisodes/rightnow?channelid=ID&format=json` | `channel.currentscheduledepisode`, title and UTC validity interval |
| `playlists/rightnow?channelid=ID&format=json` | `playlist.song`, artist/title and UTC validity interval |

Official documentation: [channels](https://api.sr.se/api/documentation/v2/metoder/kanaler.html), [schedule](https://api.sr.se/api/documentation/v2/metoder/tabla.html), [music](https://api.sr.se/api/documentation/v2/metoder/musik.html).

The channels response currently supplies HTTPS MP3 redirect URLs such as `https://www.sverigesradio.se/topsy/direkt/srapi/132.mp3`; use the supplied value rather than constructing URLs. The documented legacy `liveaudiotemplateid=1&audioquality=hi` combination returned HTTP 404 and is deliberately omitted. Channel images are available but unused to keep the menu compact.

Playback metadata polls for the selected channel every 30 seconds while playback is requested; requests and the playback monitor stop during pause or terminal failure. The open menu separately fetches programme titles for favourites, with a 60-second cache. Song data is shown only within its start/stop interval, then falls back to a valid programme or just the channel. Temporary metadata failures retain the last valid information until its timestamp expires. A scheduled expiry updates the display even while paused or offline. Missing, stale, malformed or failed metadata does not interrupt playback. Now Playing is published when its content or playback state changes. Broadcast metadata may lead buffered audio by a few seconds. The player waits for buffering and retries failures or stalls over 20 seconds up to three times with increasing delays. Thirty seconds of uninterrupted playback restores the retry budget; brief recoveries do not. Stop/channel switching cancels old tasks. Pause via media controls resumes at the live edge.

## Tests

```sh
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift test --disable-sandbox
```

Three fixture tests check national and regional channel response shapes, programme/song parsing, stale song rejection, missing metadata, malformed responses and HTTPS stream validation. Four additional tests cover retry exhaustion, stable versus brief recovery, cached metadata expiry and invalid metadata. A preferences test covers migration from the original app name. Fixtures are test resources and are not bundled with the app.

Manual checks: play each national channel, close/reopen the menu, switch channels rapidly, stop during buffering, reconnect after a network interruption, select/reorder a P4 favourite, restart, and check Control Center/media keys and login launch. AirPlay needs testing with a physical receiver; compilation and passing API tests do not verify speaker routing.

## Native menu and tooltip

NSStatusItem hosts a standard NSMenu. Channel rows are built on menu open, with programme names in smaller secondary text. Playback rows remain in place and update through Observation even while the menu is open; footer actions remain in place. `NSStatusBarButton.toolTip` is updated through Observation, including while the menu is closed. Unicode symbols identify the channel, programme or song. SwiftUI `.help` on the original MenuBarExtra label did not display reliably.

## AirPlay

The AirPlay menu action closes menu tracking and opens a small reusable window containing AVRoutePickerView. The picker is created once and bound to the same AVPlayer used for radio. This keeps it outside NSMenu's event tracking loop. No private APIs, custom discovery or system-wide output changes are used by this action. Before an app-specific route is selected, AVPlayer follows the Mac's default audio output.

## App icon

The app bundle includes original radio artwork in `Resources/AppIcon.icns`; `Resources/AppIcon.png` is the 1024-pixel preview. It is drawn from vector shapes, not an SR logo or an SF Symbol. The menu bar continues to use the system's monochrome radio symbol.

To regenerate all standard macOS icon sizes:

```sh
swift scripts/generate-icon.swift
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
./build.sh
```

## README image

`docs/images/menu-preview.html` is the source for the README image. `scripts/export-menu-symbols.swift` exports the actual macOS system symbols used in its menu bar. The image is rendered at 2× resolution with the system font and the app's original icon.

## Upgrade from the original development name

Menyradio uses the bundle identifier `se.imwithfriends.Menyradio`. On first launch it copies ordered favourites from the previous `se.publicradio.SRMenu` preferences if no new favourites have been saved, and imports the previous channel cache. The old data is left intact. Quit the old app before opening `build/Menyradio.app`. If launch at login was enabled for the old app, disable its old login entry and enable the option in Menyradio.

To refresh the README image on macOS with Chrome installed:

```sh
swift scripts/export-menu-symbols.swift
python3 scripts/render-readme.py
```

The renderer uses a temporary browser profile. These tools are for documentation only and are not bundled with Menyradio.
