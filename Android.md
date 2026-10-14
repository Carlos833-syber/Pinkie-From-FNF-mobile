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
haxelib run lime build android -debug -arm64
```

The APK is under `export/debug/android/bin/app/build/outputs/apk/debug/`.
The setup script is intended for a fresh dependency installation, as used in CI.
Do not share its patched `linc_luajit` checkout with unrelated builds.

## Android behavior and validation

Packaged charts, atlases, portraits, audio, and other assets are loaded through
OpenFL asset IDs instead of assuming files exist beside the executable. Desktop
filesystem overrides remain available. Touch controls provide menu navigation
and the four gameplay directions.

Desktop MP4 playback is unavailable on Android in this engine. The Android path
continues into the existing dialogue/gameplay flow instead of calling the
unsupported desktop player. MP4 playback itself has not been ported.

An APK compilation is not a device playtest. Before distributing a build, test
startup, menu navigation, each song, simultaneous notes, pause/resume, audio,
portraits/dialogue, Lua-driven song events, and save persistence on a real ARM64
phone. Check transitions that ordinarily show a video. Runtime stability and
memory usage still need device validation.
