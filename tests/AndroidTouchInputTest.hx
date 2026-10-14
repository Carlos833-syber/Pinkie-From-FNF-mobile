package;

import AndroidTouchInput.AndroidTouchRegion;

class AndroidTouchInputTest
{
	static function expect(actual:Dynamic, expected:Dynamic, message:String):Void
	{
		if (actual != expected)
			throw '$message: expected $expected, got $actual';
	}

	static function main():Void
	{
		var events:Array<String> = [];
		var input = new AndroidTouchInput(function(key:Int, down:Bool):Void
		{
			events.push('$key:$down');
		});

		// Independent fingers can sustain chords, including two fingers in one lane.
		input.begin(1, 37);
		input.begin(2, 39);
		input.begin(3, 37);
		input.flush();
		expect(events.length, 2, "one press per held lane");
		input.end(1);
		input.flush();
		expect(events.length, 2, "second finger keeps a sustain held");
		input.end(3);
		input.flush();
		expect(events[2], "37:false", "last finger releases the lane");
		expect(input.isHeld(39), true, "other chord note remains held");
		input.reset();
		expect(events[3], "39:false", "screen changes release all held keys");

		// The finger that accepted a menu item must not become a hitbox or pause press.
		input.move(2, 13);
		input.flush();
		expect(events.length, 4, "screen changes suppress carried fingers");
		input.end(2);
		input.begin(2, 13);
		input.flush();
		expect(events[4], "13:true", "lifted fingers can press on the new screen");
		input.reset();
		events = [];

		// A complete tap between game ticks must still be sampled as down, then up.
		input.begin(4, 38);
		input.end(4);
		input.flush();
		expect(events.join(","), "38:true", "short taps survive until the next update");
		input.flush();
		expect(events.join(","), "38:true,38:false", "short taps release on the following update");
		events = [];

		input.begin(5, 37);
		input.flush();
		input.move(5, 40);
		input.flush();
		expect(input.isHeld(37), false, "sliding leaves the previous lane");
		expect(input.isHeld(40), true, "sliding enters the new lane");
		expect(events.indexOf("37:false") >= 0, true, "sliding releases the old key");
		expect(events.indexOf("40:true") >= 0, true, "sliding presses the new key");
		input.reset();

		var regions:Array<AndroidTouchRegion> = [];
		var keys = [37, 40, 38, 39];
		for (i in 0...4)
			regions.push({
				x: i * 320,
				y: 0,
				width: 320,
				height: 720,
				key: keys[i]
			});
		regions.push({
			x: 1150,
			y: 25,
			width: 81.6,
			height: 75.2,
			key: 13
		});
		for (i in 0...4)
		{
			expect(AndroidTouchInput.hitTest(i * 320, 0, regions), keys[i], "lane starts at the top edge");
			expect(AndroidTouchInput.hitTest(i * 320 + 319, 719, regions), keys[i], "lane reaches the bottom edge");
		}
		expect(AndroidTouchInput.hitTest(1160, 30, regions), 13, "pause takes priority over the right lane");
		regions[4].key = -1;
		expect(AndroidTouchInput.hitTest(1160, 30, regions), 39, "hidden pause does not block notes");
		expect(AndroidTouchInput.hitTest(-1, 100, regions), -1, "left letterbox never plays a note");
		expect(AndroidTouchInput.hitTest(1280, 100, regions), -1, "right letterbox never plays a note");
		expect(AndroidTouchInput.hitTest(100, 720, regions), -1, "bottom letterbox never plays a note");
		Sys.println("Android touch input checks passed");
	}
}
