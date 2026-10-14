#!/usr/bin/env python3
"""Link pinned linc_luajit against a static LuaJIT built with the Android NDK."""

import argparse
from pathlib import Path
from xml.sax.saxutils import escape

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("checkout", type=Path)
parser.add_argument("archive", type=Path)
args = parser.parse_args()
archive = args.archive.resolve(strict=True)
with archive.open("rb") as handle:
    if handle.read(8) != b"!<arch>\n":
        raise SystemExit("Expected a static archive, not a shared library")
xml = args.checkout / "linc/linc_lua.xml"
source = xml.read_text()
start = '        <section if="android">'
end = "        </section>"
if source.count(start) != 1:
    raise SystemExit("Unexpected linc_luajit XML: expected one Android section")
first = source.index(start)
last = source.index(end, first) + len(end)
old = source[first:last]
replacement = (
    start
    + '\n            <lib name="'
    + escape(str(archive), {'"': "&quot;"})
    + '" />\n'
    + end
)
if old == replacement:
    raise SystemExit(0)
expected = ["libluajit-v7.so", "libluajit-x86.so", "libluajit-64.so"]
if not all(old.count(name) == 1 for name in expected):
    raise SystemExit("Unexpected Android libraries; verify the pinned revision")
xml.write_text(source[:first] + replacement + source[last:])
