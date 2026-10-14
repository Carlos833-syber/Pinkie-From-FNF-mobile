#!/usr/bin/env python3
"""Reduce oversized Sparrow sheets in an Android build checkout only.

XML frame coordinates stay in original pixels. AndroidAtlasFrames reads the
androidScale marker and restores the original geometry at runtime. Never run
this on source assets you intend to commit; CI runs it after checkout.
"""

import argparse
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image


def prepare_atlas(image_path: Path, max_size: int) -> tuple[int, int]:
    xml_path = image_path.with_suffix(".xml")
    if not xml_path.is_file():
        return 0, 0
    tree = ET.parse(xml_path)
    root = tree.getroot()
    if root.tag != "TextureAtlas" or not root.findall("SubTexture"):
        return 0, 0
    if root.get("androidScale"):
        return 0, 0  # Idempotent when rerunning a prepared build checkout.
    with Image.open(image_path) as image:
        width, height = image.size
        if max(width, height) <= max_size:
            return 0, 0
        scale = 1
        while math.ceil(max(width, height) / scale) > max_size:
            scale *= 2
        # Preserve one exact scale on both axes, including sheets of odd size.
        padded_width = math.ceil(width / scale) * scale
        padded_height = math.ceil(height / scale) * scale
        for frame in root.findall("SubTexture"):
            if not frame.get("name"):
                raise ValueError(f"Unnamed frame in {xml_path}")
            x, y, w, h = (float(frame.attrib[key]) for key in ("x", "y", "width", "height"))
            if not all(math.isfinite(value) for value in (x, y, w, h)):
                raise ValueError(f"Invalid frame coordinates in {xml_path}")
            if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > width or y + h > height:
                raise ValueError(f"Frame outside PNG bounds in {xml_path}: {frame.get('name')}")
            if "frameX" in frame.attrib:
                for key in ("frameX", "frameY", "frameWidth", "frameHeight"):
                    if not math.isfinite(float(frame.attrib[key])):
                        raise ValueError(f"Invalid trim geometry in {xml_path}")
        image = image.convert("RGBA")
        if (padded_width, padded_height) != image.size:
            padded = Image.new("RGBA", (padded_width, padded_height))
            padded.paste(image, (0, 0))
            image = padded
        reduced = image.resize((padded_width // scale, padded_height // scale), Image.Resampling.LANCZOS)
        reduced.save(image_path)
    root.set("androidScale", str(scale))
    tree.write(xml_path, encoding="utf-8", xml_declaration=True)
    return width * height * 4, reduced.width * reduced.height * 4


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("asset_root", type=Path, nargs="?", default=Path("assets"))
    parser.add_argument("--max-size", type=int, default=4096)
    args = parser.parse_args()
    if args.max_size <= 0:
        parser.error("--max-size must be positive")
    before = after = count = 0
    for image_path in sorted(args.asset_root.rglob("*.png")):
        try:
            old_size, new_size = prepare_atlas(image_path, args.max_size)
        except ET.ParseError:
            continue  # An unrelated XML file is not a Sparrow atlas.
        if old_size:
            before += old_size
            after += new_size
            count += 1
            print(f"Reduced {image_path}: decoded RGBA {old_size // 1048576} -> {new_size // 1048576} MiB")
    print(f"Prepared {count} Sparrow atlases; decoded RGBA total {before // 1048576} -> {after // 1048576} MiB")


if __name__ == "__main__":
    main()
