package;

/** A logical touch target in the 1280x720 game viewport. */
typedef AndroidTouchRegion =
{
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
	var key:Int;
}

/** Tracks each finger independently and preserves taps shorter than one game update. */
class AndroidTouchInput
{
	var fingers:Map<Int, Int> = new Map();
	var blocked:Map<Int, Bool> = new Map();
	var pending:Map<Int, Array<Bool>> = new Map();
	var output:Map<Int, Bool> = new Map();
	var onKey:Int->Bool->Void;

	public function new(onKey:Int->Bool->Void)
	{
		this.onKey = onKey;
	}

	public function begin(finger:Int, key:Int):Void
	{
		blocked.remove(finger);
		if (fingers.exists(finger))
			end(finger);
		fingers.set(finger, -1);
		move(finger, key);
	}

	public function move(finger:Int, key:Int):Void
	{
		if (blocked.exists(finger) || !fingers.exists(finger))
			return;
		var previous = fingers.get(finger);
		if (previous == key)
			return;
		fingers.set(finger, -1);
		if (previous >= 0 && !isHeld(previous))
			queue(previous, false);
		if (key >= 0)
		{
			var alreadyHeld = isHeld(key);
			fingers.set(finger, key);
			if (!alreadyHeld)
				queue(key, true);
		}
	}

	public function end(finger:Int):Void
	{
		blocked.remove(finger);
		if (!fingers.exists(finger))
			return;
		var previous = fingers.get(finger);
		fingers.remove(finger);
		if (previous >= 0 && !isHeld(previous))
			queue(previous, false);
	}

	public function isHeld(key:Int):Bool
	{
		if (key < 0)
			return false;
		for (held in fingers)
			if (held == key)
				return true;
		return false;
	}

	function queue(key:Int, down:Bool):Void
	{
		if (!pending.exists(key))
			pending.set(key, []);
		pending.get(key).push(down);
	}

	/** Send at most one transition per key before each game update. */
	public function flush():Void
	{
		for (key => changes in pending)
			if (changes.length > 0)
			{
				var down = changes.shift();
				output.set(key, down);
				onKey(key, down);
			}
	}

	/** Held fingers cannot activate a new screen until they are lifted. */
	public function reset():Void
	{
		for (finger in fingers.keys())
			blocked.set(finger, true);
		fingers.clear();
		pending.clear();
		for (key => down in output)
			if (down)
				onKey(key, false);
		output.clear();
	}

	/** Later regions have priority, so the pause button never also plays a note. */
	public static function hitTest(x:Float, y:Float, regions:Array<AndroidTouchRegion>, width:Float = 1280, height:Float = 720):Int
	{
		if (x < 0 || y < 0 || x >= width || y >= height)
			return -1;
		var i = regions.length;
		while (i-- > 0)
		{
			var region = regions[i];
			if (region.key >= 0 && x >= region.x && y >= region.y && x < region.x + region.width && y < region.y + region.height)
				return region.key;
		}
		return -1;
	}
}
