#!/usr/bin/env bash
# Run from the repository root on Linux after installing Haxe, Neko and the NDK.
set -euo pipefail

: "${ANDROID_NDK_ROOT:?Set ANDROID_NDK_ROOT to NDK 21.4.7075529}"
: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT to the Android SDK}"
: "${JAVA_HOME:?Set JAVA_HOME to a Java 11 JDK}"

haxelib install hxcpp 4.2.1 --quiet --skip-dependencies
haxelib install lime 8.0.2 --quiet --skip-dependencies
haxelib install openfl 9.2.2 --quiet --skip-dependencies
haxelib install flixel 4.11.0 --quiet --skip-dependencies
haxelib install flixel-addons 2.11.0 --quiet --skip-dependencies
haxelib install flixel-ui 2.5.0 --quiet --skip-dependencies
haxelib install hscript 2.5.0 --quiet --skip-dependencies
haxelib install newgrounds 1.1.5 --quiet --skip-dependencies
haxelib install polymod 1.3.1 --quiet --skip-dependencies
haxelib git linc_luajit https://github.com/nebulazorua/linc_luajit 58429d4b5c934d50b3895ca99b3ac37d0c8dd93d --quiet
haxelib git hxvm-luajit https://github.com/nebulazorua/hxvm-luajit 5d59ea1172be619bcda2668e27b828fdb10d78d7 --quiet

# Build a static ARM64 LuaJIT instead of shipping the upstream desktop libraries
# or Android shared objects whose SONAME does not match their packaged filename.
android_deps_dir="$(haxelib config)/pinkie-android"
luajit_checkout="$android_deps_dir/LuaJIT"
mkdir -p "$android_deps_dir"
if [[ ! -d "$luajit_checkout/.git" ]]; then
  git clone https://github.com/LuaJIT/LuaJIT.git "$luajit_checkout"
fi
git -C "$luajit_checkout" checkout --detach 2a8e017ef1ece6a95b983ffca073d30609dce7c4
ndk_bin="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
ndk_cc="$ndk_bin/aarch64-linux-android23-clang"
make -C "$luajit_checkout" clean
make -C "$luajit_checkout" -j2 \
  CROSS="$ndk_bin/aarch64-linux-android-" \
  STATIC_CC="$ndk_cc -fPIC" DYNAMIC_CC="$ndk_cc -fPIC" \
  TARGET_LD="$ndk_cc" TARGET_AR="$ndk_bin/llvm-ar rcus" \
  TARGET_STRIP="$ndk_bin/llvm-strip" BUILDMODE=static TARGET_SYS=Linux
for header in lua.h lauxlib.h lualib.h luaconf.h lua.hpp luajit.h; do
  cp "$luajit_checkout/src/$header" "$(haxelib config)/linc_luajit/git/lib/lua/src/$header"
done
python3 scripts/patch-luajit.py "$(haxelib config)/linc_luajit/git" "$luajit_checkout/src/libluajit.a"

haxelib run lime config ANDROID_SETUP true
haxelib run lime config ANDROID_SDK "$ANDROID_SDK_ROOT"
haxelib run lime config ANDROID_NDK_ROOT "$ANDROID_NDK_ROOT"
haxelib run lime config JAVA_HOME "$JAVA_HOME"
