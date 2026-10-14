"""Build preprocessing regression tests; fixtures are generated in temp dirs."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from PIL import Image


spec = importlib.util.spec_from_file_location(
    "prepare_android_assets", Path(__file__).resolve().parents[1] / "scripts/prepare-android-assets.py"
)
prepare_android_assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare_android_assets)


class AndroidAssetsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.image = Path(self.temp.name) / "sheet.png"
        self.xml = self.image.with_suffix(".xml")

    def make_atlas(self, size=(16, 16)):
        image = Image.new("RGBA", size, (0, 0, 0, 0))
        # Color blocks detect a missing resize or an unexpected atlas rearrange.
        image.paste((255, 0, 0, 255), (0, 0, 8, 8))
        image.paste((0, 255, 0, 255), (8, 0, 16, 8))
        image.save(self.image)
        self.xml.write_text(
            '<TextureAtlas imagePath="sheet.png"><SubTexture name="idle0000" '
            'x="0" y="0" width="8" height="8" frameX="-3" frameY="-5" '
            'frameWidth="13" frameHeight="17" flipX="true"/>'
            '<SubTexture name="turn0001" x="8" y="0" width="8" height="6" '
            'rotated="true" flipY="true"/></TextureAtlas>'
        )

    def test_reduces_memory_and_preserves_every_frame_attribute(self):
        self.make_atlas()
        original = [dict(frame.attrib) for frame in ET.parse(self.xml).getroot()]
        self.assertEqual(prepare_android_assets.prepare_atlas(self.image, 8), (1024, 256))
        root = ET.parse(self.xml).getroot()
        self.assertEqual(root.attrib, {"imagePath": "sheet.png", "androidScale": "2"})
        self.assertEqual([dict(frame.attrib) for frame in root], original)
        with Image.open(self.image) as image:
            self.assertEqual(image.size, (8, 8))
            red = image.getpixel((1, 1))
            green = image.getpixel((6, 1))
            self.assertGreater(red[0], 245)
            self.assertLess(red[1], 10)
            self.assertGreater(green[1], 245)
            self.assertLess(green[0], 10)

    def test_rerun_is_idempotent_and_small_sheet_is_byte_identical(self):
        self.make_atlas()
        before = self.image.read_bytes(), self.xml.read_bytes()
        self.assertEqual(prepare_android_assets.prepare_atlas(self.image, 16), (0, 0))
        self.assertEqual(before, (self.image.read_bytes(), self.xml.read_bytes()))
        prepare_android_assets.prepare_atlas(self.image, 8)
        prepared = self.image.read_bytes(), self.xml.read_bytes()
        self.assertEqual(prepare_android_assets.prepare_atlas(self.image, 8), (0, 0))
        self.assertEqual(prepared, (self.image.read_bytes(), self.xml.read_bytes()))

    def test_odd_dimensions_are_padded_to_keep_one_exact_scale(self):
        self.make_atlas((17, 19))
        prepare_android_assets.prepare_atlas(self.image, 8)
        self.assertEqual(ET.parse(self.xml).getroot().get("androidScale"), "4")
        with Image.open(self.image) as image:
            self.assertEqual(image.size, (5, 5))

    def test_missing_or_non_sparrow_xml_does_not_touch_png(self):
        self.make_atlas()
        original = self.image.read_bytes()
        self.xml.unlink()
        self.assertEqual(prepare_android_assets.prepare_atlas(self.image, 8), (0, 0))
        self.xml.write_text('<Animation><Frame x="0"/></Animation>')
        self.assertEqual(prepare_android_assets.prepare_atlas(self.image, 8), (0, 0))
        self.assertEqual(self.image.read_bytes(), original)

    def test_invalid_frame_fails_before_image_changes(self):
        self.make_atlas()
        original = self.image.read_bytes()
        self.xml.write_text('<TextureAtlas><SubTexture name="bad" x="15" y="0" width="8" height="8"/></TextureAtlas>')
        with self.assertRaisesRegex(ValueError, "outside PNG bounds"):
            prepare_android_assets.prepare_atlas(self.image, 8)
        self.assertEqual(self.image.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
