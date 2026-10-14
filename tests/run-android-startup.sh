#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT

# Run the production Main without pulling in content, Lua or source/import.hx.
# FlxGame, FlxG, the stage and their event/resize lifecycle are the real libraries.
cp "$repo_dir/source/Main.hx" "$repo_dir/tests/AndroidStartupTest.hx" "$check_dir/"
cp "$repo_dir"/tests/startup-fixtures/*.hx "$check_dir/"
for scenario in engine application; do
  haxe -lib flixel -lib openfl -lib lime -cp "$check_dir" \
    -D android -D mobile -D FLX_NO_DEBUG -D FLX_NO_SOUND_SYSTEM --remap flash:openfl \
    --macro 'flixel.system.macros.FlxDefines.run()' \
    --run AndroidStartupTest "$scenario"
done
