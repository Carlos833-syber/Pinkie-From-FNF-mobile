# Android build

The `Android APK` GitHub Actions workflow builds a **debug APK for ARM64 phones**
(Android 6.0 / API 23 or later). It runs for pull requests and pushes that change
build inputs, and can also be started from **Actions → Android APK → Run workflow**.
The workflow must exist on the repository's default branch for the manual button
to appear.

After a successful run, download `Pinkie-Android-arm64-debug` from **Artifacts**,
extract the ZIP, and install the APK on a compatible phone. Android may ask you
to allow installation from that file manager/browser. This is a sideload build,
not a Play Store release. It uses a temporary CI debug signing key; builds from
separate runs may require uninstalling the old APK, which removes its saved data.

## Toolchain

| Tool | Version |
| --- | --- |
| Haxe | 4.2.5 |
| Java for compilation | 11 |
| Android SDK / build tools | 33 / 33.0.2 |
| Android NDK | 21.4.7075529 |
| Gradle / Android Gradle plugin | 7.5.1 / 7.4.2 |
| Lime / OpenFL | 8.1.3 / 9.2.2 |
| HaxeFlixel / addons / UI | 4.11.0 / 2.11.0 / 2.5.0 |
| hxcpp / hscript | 4.2.1 / 2.5.0 |
| newgrounds / polymod | 1.1.5 / 1.3.1 |

The setup script pins both Lua Haxe bindings and the LuaJIT source to commit
hashes. LuaJIT is compiled as a position-independent ARM64 static library using
the NDK, then linked into the game. Song Lua modcharts remain enabled on Android.
The bundled Windows libraries are not used by the Android build.

## Local Linux build

Install Haxe 4.2.5, Neko, Java 11, Git, Python 3, GNU Make, and a C compiler.
Install the SDK packages listed above using Android's `sdkmanager` (current SDK
command-line tools require Java 17; switch back to Java 11 before building).
Initialize a fresh Haxelib repository with `haxelib setup`, then run from this
repository's root:

```bash
export ANDROID_SDK_ROOT=/path/to/android-sdk
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/21.4.7075529"
export JAVA_HOME=/path/to/jdk-11
export PATH="$JAVA_HOME/bin:$PATH"
bash scripts/setup-android.sh
python3 -m pip install -r scripts/requirements-android-assets.txt
python3 scripts/prepare-android-assets.py assets
haxelib run lime build android -debug -arm64
```

The APK is under `export/debug/android/bin/app/build/outputs/apk/debug/`.
The setup script is intended for a fresh dependency installation, as used in CI.
Do not share its patched `linc_luajit` checkout with unrelated builds.
Texture preparation changes PNG/XML pairs in place: run it in a disposable build
checkout and do not commit the resulting assets. A desktop build should use the
original source assets.

## Android behavior and validation

Packaged charts, atlases, portraits, audio, and other assets are loaded through
OpenFL asset IDs instead of assuming files exist beside the executable. Desktop
filesystem overrides remain available. Atlas metadata uses the same asset library
as its PNG, including the GF sprites in `shared`; previously the XML lookup passed
the library as an asset type and failed when entering songs.

The Android canvas stays at **1280×720 (16:9)**, centered with black bars as needed.
It does not stretch to the phone's aspect ratio, and Android fullscreen is disabled.
The touch overlay follows the same viewport; taps in the black bars are ignored.

- Menus and pause/game-over screens: Psych mobile directional pad, **A** to accept,
  **B** to go back.
- Gameplay: four full-height hitboxes, left/down/up/right, with colored feedback.
  Multiple fingers and sustains are supported. The separate top-right pause button
  takes priority over the right lane.
- Dialogue: **A** advances, **B** skips, **C** reveals the current line.

Touch presses are released on state changes and when the app loses focus. Lift a
finger before using it on the next screen. The imported Psych mobile button assets
include their Apache 2.0 license and source notice under `assets/preload/images/mobile/`.

Android also skips the unused Discord atlas pre-rendering at startup. Song teardown
releases Lua, pending notes and vocals; it does not dump textures still in use.
Modchart callbacks restore the Lua stack after each call, including absent
callbacks, instead of accumulating a result/nil on every frame.

The Android build reduces Sparrow sheets larger than 4096 pixels on either axis.
The atlas loader restores their original logical frame sizes and offsets, so
characters and animations keep their positions. An 8192×8192 RGBA sheet drops from
256 MiB to 64 MiB of decoded pixels. This trades some texture detail for lower memory
use; Adobe animation atlases and smaller textures keep their original data.

Regression checks run with `bash tests/run-android-touch.sh`,
`python3 scripts/test-asset-paths.py`, and
`python3 -m unittest discover -s tests -p 'test_android_assets.py'`.
After installing the pinned Haxe libraries, `bash tests/run-android-atlas.sh` checks
frame geometry, rotations, flips, clipping, sprite reuse and thumbnail transforms
against the real Flixel/OpenFL classes. It does not render on a GPU. The packaged
path/Lua test also requires those libraries; it exercises the real resolvers and
pinned LuaVM with controlled asset/Lua API test doubles.

Desktop MP4 playback is unavailable on Android in this engine. The Android path
continues into the existing dialogue/gameplay flow instead of calling the
unsupported desktop player. MP4 playback itself has not been ported.

An APK compilation is not a device playtest. Before distributing a build, test
startup, menu navigation, each song, simultaneous notes, pause/resume, audio,
portraits/dialogue, Lua-driven song events, and save persistence on a real ARM64
phone. Check transitions that ordinarily show a video. Runtime stability and
memory usage still need device validation.
