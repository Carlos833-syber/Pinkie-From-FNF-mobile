package;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxGraphicAsset;
import haxe.xml.Access;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.geom.Point;

/** Reads build-time reduced Sparrow sheets without changing gameplay coordinates. */
class AndroidAtlasFrames
{
	public static function fromSparrow(source:FlxGraphicAsset, description:String):FlxAtlasFrames
	{
		if (description == null)
			return null;
		if (Assets.exists(description))
			description = Assets.getText(description);
		var data = new Access(Xml.parse(description).firstElement());
		var scale = data.has.androidScale ? Std.parseFloat(data.att.androidScale) : 1.0;
		if (Math.isNaN(scale) || scale < 1)
			throw "Invalid Android atlas scale";
		if (scale == 1)
			return FlxAtlasFrames.fromSparrow(source, description);

		var graphic = FlxG.bitmap.add(source);
		if (graphic == null)
			return null;
		var frames = FlxAtlasFrames.findFrame(graphic);
		if (frames != null)
			return frames;
		frames = new FlxAtlasFrames(graphic);
		for (texture in data.nodes.SubTexture)
		{
			var width = Std.parseFloat(texture.att.width);
			var height = Std.parseFloat(texture.att.height);
			var trimmed = texture.has.frameX;
			var rotated = texture.has.rotated && texture.att.rotated == "true";
			var frame = new AndroidAtlasFrame(graphic, scale, rotated ? FlxFrameAngle.ANGLE_NEG_90 : FlxFrameAngle.ANGLE_0);
			frame.name = texture.att.name;
			frame.flipX = texture.has.flipX && texture.att.flipX == "true";
			frame.flipY = texture.has.flipY && texture.att.flipY == "true";
			frame.sourceSize.set(trimmed ? Std.parseFloat(texture.att.frameWidth) : (rotated ? height : width),
				trimmed ? Std.parseFloat(texture.att.frameHeight) : (rotated ? width : height));
			frame.offset.set(trimmed ? -Std.parseFloat(texture.att.frameX) : 0, trimmed ? -Std.parseFloat(texture.att.frameY) : 0);
			frame.frame = FlxRect.get(Std.parseFloat(texture.att.x) / scale, Std.parseFloat(texture.att.y) / scale, width / scale, height / scale);
			frames.pushFrame(frame);
		}
		return frames;
	}
}

/** Texture rectangles use reduced pixels; offsets, sizes and transforms use original pixels. */
@:access(flixel.graphics.frames.FlxFrame)
private class AndroidAtlasFrame extends FlxFrame
{
	var atlasScale:Float;
	var scaledParent:FlxGraphic;

	public function new(parent:FlxGraphic, scale:Float, angle:FlxFrameAngle = FlxFrameAngle.ANGLE_0)
	{
		super(parent, angle);
		atlasScale = scale;
		scaledParent = parent;
	}

	override function cacheFrameMatrix():Void
	{
		super.cacheFrameMatrix();
		// FlxSprite can reuse its private frame when replacing its graphic.
		var scale = parent == scaledParent ? atlasScale : 1.0;
		if (scale == 1)
			return;
		for (i in 0...4)
			blitMatrix[i] *= scale;
		blitMatrix[4] = offset.x - frame.x * blitMatrix[0] - frame.y * blitMatrix[2];
		blitMatrix[5] = offset.y - frame.x * blitMatrix[1] - frame.y * blitMatrix[3];
		if (angle == FlxFrameAngle.ANGLE_90)
			blitMatrix[4] += frame.height * scale;
		else if (angle == FlxFrameAngle.ANGLE_NEG_90)
			blitMatrix[5] += frame.width * scale;
		if (FlxG.renderTile)
		{
			for (i in 0...4)
				tileMatrix[i] = blitMatrix[i];
			tileMatrix[4] = blitMatrix[4] + frame.x * blitMatrix[0] + frame.y * blitMatrix[2];
			tileMatrix[5] = blitMatrix[5] + frame.x * blitMatrix[1] + frame.y * blitMatrix[3];
		}
	}

	override public function paint(?bmd:BitmapData, ?point:Point, mergeAlpha:Bool = false, disposeIfNotEqual:Bool = false):BitmapData
	{
		if (type == FlxFrameType.EMPTY)
			return super.paint(bmd, point, mergeAlpha, disposeIfNotEqual);
		// FlxFrame.paint's unrotated fast path uses copyPixels and cannot upscale.
		return paintRotatedAndFlipped(bmd, point, FlxFrameAngle.ANGLE_0, flipX, flipY, mergeAlpha, disposeIfNotEqual);
	}

	override public function copyTo(?clone:FlxFrame):FlxFrame
	{
		var target:AndroidAtlasFrame;
		if (Std.isOfType(clone, AndroidAtlasFrame))
			target = cast clone;
		else
		{
			if (clone != null)
				clone.destroy();
			target = new AndroidAtlasFrame(parent, atlasScale, angle);
		}
		target.atlasScale = atlasScale;
		target.scaledParent = scaledParent;
		return super.copyTo(target);
	}

	override public function clipTo(clip:FlxRect, ?clippedFrame:FlxFrame):FlxFrame
	{
		return clippedTo(clip, clippedFrame, false);
	}

	override public function subFrameTo(region:FlxRect, ?frameToFill:FlxFrame):FlxFrame
	{
		return clippedTo(region, frameToFill, true);
	}

	function clippedTo(region:FlxRect, target:FlxFrame, rebase:Bool):FlxFrame
	{
		var previousFlipX = target != null && target.flipX;
		var previousFlipY = target != null && target.flipY;
		var previousName = target == null ? null : target.name;
		var result = copyTo(target);
		// FlxFrame leaves an existing destination's orientation unchanged.
		result.flipX = previousFlipX;
		result.flipY = previousFlipY;
		var scale = parent == scaledParent ? atlasScale : 1.0;
		var width = (angle == FlxFrameAngle.ANGLE_0 ? frame.width : frame.height) * scale;
		var height = (angle == FlxFrameAngle.ANGLE_0 ? frame.height : frame.width) * scale;
		var originX = rebase ? Math.max(offset.x, 0) : offset.x;
		var originY = rebase ? Math.max(offset.y, 0) : offset.y;
		var left = Math.max(0, region.x - originX);
		var top = Math.max(0, region.y - originY);
		var right = Math.min(width, region.right - originX);
		var bottom = Math.min(height, region.bottom - originY);
		if (rebase)
		{
			result.sourceSize.set(region.width, region.height);
			result.name = previousName;
		}
		result.offset.set(offset.x + left - (rebase ? region.x : 0), offset.y + top - (rebase ? region.y : 0));
		if (right <= left || bottom <= top || type == FlxFrameType.EMPTY)
		{
			result.type = FlxFrameType.EMPTY;
			result.frame.set(0, 0, 0, 0);
			result.frame = result.frame;
			result.offset.set(0, 0);
		}
		else
		{
			var rect = result.frame;
			if (angle == FlxFrameAngle.ANGLE_NEG_90)
				rect.set(frame.x + frame.width - bottom / scale, frame.y + left / scale, (bottom - top) / scale, (right - left) / scale);
			else if (angle == FlxFrameAngle.ANGLE_90)
				rect.set(frame.x + top / scale, frame.y + frame.height - right / scale, (bottom - top) / scale, (right - left) / scale);
			else
				rect.set(frame.x + left / scale, frame.y + top / scale, (right - left) / scale, (bottom - top) / scale);
			result.frame = rect;
		}
		result.cacheFrameMatrix();
		return result;
	}
}
