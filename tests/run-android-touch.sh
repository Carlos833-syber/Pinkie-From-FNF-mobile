#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT

# Keep the pure input checks independent of source/import.hx's engine imports.
cp "$repo_dir/source/AndroidTouchInput.hx" "$repo_dir/tests/AndroidTouchInputTest.hx" "$check_dir/"
haxe -cp "$check_dir" -main AndroidTouchInputTest --interp
