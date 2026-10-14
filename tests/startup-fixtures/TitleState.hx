package;

import flixel.FlxState;

/** Asset-free state used by production Main in the startup lifecycle test. */
class TitleState extends FlxState
{
	public static var creates = 0;
	public static var resizes = 0;

	override public function create():Void
	{
		super.create();
		creates++;
	}

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		resizes++;
	}
}
