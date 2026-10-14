#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT

# Isolate the helper from source/import.hx while using the project's real libraries.
cp "$repo_dir/source/AndroidAtlasFrames.hx" "$repo_dir/tests/AndroidAtlasFramesTest.hx" "$check_dir/"
haxe -lib flixel -lib openfl -lib lime -cp "$check_dir" \
  -D android -D FLX_NO_DEBUG -D FLX_NO_SOUND_SYSTEM --remap flash:openfl \
  --macro 'flixel.system.macros.FlxDefines.run()' \
  -main AndroidAtlasFramesTest --interp
