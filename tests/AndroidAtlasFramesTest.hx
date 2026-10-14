package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.IBitmapDrawable;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

@:access(flixel.FlxG)
@:access(flixel.FlxSprite)
class AndroidAtlasFramesTest
{
	static var assertions = 0;

	static function near(actual:Float, expected:Float, message:String):Void
	{
		assertions++;
		if (Math.abs(actual - expected) > 0.00001)
			throw '$message: expected $expected, got $actual';
	}

	static function sameGeometry(original:FlxFrame, reduced:FlxFrame):Void
	{
		near(reduced.sourceSize.x, original.sourceSize.x, "logical width");
		near(reduced.sourceSize.y, original.sourceSize.y, "logical height");
		near(reduced.offset.x, original.offset.x, "trim offset X");
		near(reduced.offset.y, original.offset.y, "trim offset Y");
		if (reduced.name != original.name)
			throw "Animation frame name changed";
		for (rotation in [FlxFrameAngle.ANGLE_0, FlxFrameAngle.ANGLE_90, FlxFrameAngle.ANGLE_NEG_90])
			for (flipX in [false, true])
				for (flipY in [false, true])
				{
					var a = original.prepareMatrix(new FlxMatrix(), rotation, flipX, flipY);
					var b = reduced.prepareMatrix(new FlxMatrix(), rotation, flipX, flipY);
					// Equivalent texture corners must land on identical screen pixels.
					for (x in [0.0, original.frame.width])
						for (y in [0.0, original.frame.height])
						{
							near(b.a * x / 2 + b.c * y / 2 + b.tx, a.a * x + a.c * y + a.tx, "screen X");
							near(b.b * x / 2 + b.d * y / 2 + b.ty, a.b * x + a.d * y + a.ty, "screen Y");
						}
				}
	}

	static function main():Void
	{
		FlxG.renderTile = true;
		FlxG.renderBlit = false;
		var originalBitmap = new BitmapData(64, 64, true, 0xFFFF0000);
		var reducedBitmap = new BitmapData(32, 32, true, 0xFFFF0000);
		var originalGraphic = FlxGraphic.fromBitmapData(originalBitmap, false, "original", false);
		var reducedGraphic = FlxGraphic.fromBitmapData(reducedBitmap, false, "reduced", false);
		originalGraphic.persist = reducedGraphic.persist = true;
		var body = '<SubTexture name="idle0000" x="4" y="6" width="20" height="24" frameX="-2" frameY="-3" frameWidth="30" frameHeight="40"/>'
			+
			'<SubTexture name="turn0000" x="24" y="6" width="18" height="24" frameX="-4" frameY="-5" frameWidth="40" frameHeight="50" rotated="true" flipX="true" flipY="true"/>'
			+ '<SubTexture name="plain0000" x="0" y="32" width="20" height="24"/>'
			+ '<SubTexture name="plainTurn0000" x="24" y="32" width="20" height="24" rotated="true"/>'
			+ '<SubTexture name="negativeOffset0000" x="0" y="0" width="20" height="24" frameX="2" frameY="3" frameWidth="30" frameHeight="40"/>';
		var original = AndroidAtlasFrames.fromSparrow(originalGraphic, '<TextureAtlas>$body</TextureAtlas>');
		var reduced = AndroidAtlasFrames.fromSparrow(reducedGraphic, '<TextureAtlas androidScale="2">$body</TextureAtlas>');
		near(reduced.frames.length, original.frames.length, "frame count");
		for (i in 0...original.frames.length)
		{
			var a = original.frames[i];
			var b = reduced.frames[i];
			sameGeometry(a, b);
			sameGeometry(a, b.copyTo());
			if (reduced.getByName(a.name) != b)
				throw "Frame lookup lost its name";
			var region = FlxRect.get(6, 8, 8, 10);
			sameGeometry(a.clipTo(region), b.clipTo(region));
			sameGeometry(a.subFrameTo(region), b.subFrameTo(region));
			sameGeometry(a.clipTo(region, a.copyTo()), b.clipTo(region, b.copyTo()));
			sameGeometry(a.subFrameTo(region, a.copyTo()), b.subFrameTo(region, b.copyTo()));
			region.put();
			var thumbnail = new RecordingBitmapData(Std.int(b.sourceSize.x), Std.int(b.sourceSize.y));
			b.paint(thumbnail);
			near(thumbnail.drawCalls, 1, "thumbnail uses scaled draw rather than copyPixels");
			near(Math.abs(thumbnail.transform.a) + Math.abs(thumbnail.transform.b), 2, "thumbnail scale X");
			near(Math.abs(thumbnail.transform.c) + Math.abs(thumbnail.transform.d), 2, "thumbnail scale Y");
			near(thumbnail.drawRect.width, a.angle == FlxFrameAngle.ANGLE_0 ? a.frame.width : a.frame.height, "thumbnail trim width");
			near(thumbnail.drawRect.height, a.angle == FlxFrameAngle.ANGLE_0 ? a.frame.height : a.frame.width, "thumbnail trim height");
		}
		// Exercise the actual FlxSprite copy/reuse path across optimized and normal graphics.
		var sprite = new FlxSprite();
		sprite.frames = reduced;
		sameGeometry(original.frames[0], sprite._frame);
		var baselineSprite = new FlxSprite();
		baselineSprite.frames = original;
		baselineSprite.frame = original.frames[1];
		sprite.frame = reduced.frames[1];
		baselineSprite.clipRect = FlxRect.get(6, 8, 8, 10);
		sprite.clipRect = FlxRect.get(6, 8, 8, 10);
		sameGeometry(baselineSprite._frame, sprite._frame);
		sprite.clipRect = null;
		sprite.frames = original;
		var reused = sprite._frame.prepareMatrix(new FlxMatrix());
		near(reused.a, 1, "replacing scaled graphic resets matrix scale");
		near(reused.d, 1, "replacing scaled graphic resets matrix scale Y");
		sprite.frames = reduced;
		sameGeometry(original.frames[0], sprite._frame);
		// Empty clips previously recursed between paint and paintRotatedAndFlipped.
		var empty = reduced.frames[0].clipTo(FlxRect.get(100, 100, 1, 1));
		if (empty.type != FlxFrameType.EMPTY)
			throw "Outside clip must be empty";
		var emptyBitmap = empty.paint();
		near(emptyBitmap.width, 30, "empty thumbnail width");
		near(emptyBitmap.height, 40, "empty thumbnail height");
		trace('Android atlas geometry/paint-call regressions passed ($assertions assertions; real Flixel/OpenFL, no GPU rendering).');
	}
}

/** Captures the real FlxFrame.paint transform without requiring a GPU/Cairo backend. */
private class RecordingBitmapData extends BitmapData
{
	public var transform:Matrix;
	public var drawRect:Rectangle;
	public var drawCalls = 0;

	public function new(width:Int, height:Int)
	{
		super(width, height, true, 0);
	}

	override public function draw(source:IBitmapDrawable, matrix:Matrix = null, colorTransform:ColorTransform = null, blendMode:BlendMode = null,
			clipRect:Rectangle = null, smoothing:Bool = false):Void
	{
		drawCalls++;
		transform = matrix.clone();
		drawRect = clipRect.clone();
	}
}
