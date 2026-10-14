package;

/** The overlay's input behavior has its own tests; this checks startup ordering. */
class AndroidControls extends openfl.display.Sprite
{
	public static var creates = 0;

	public function new()
	{
		super();
		if (flixel.FlxG.state == null || TitleState.creates != 1)
			throw "Controls initialized before the game state";
		creates++;
	}
}
