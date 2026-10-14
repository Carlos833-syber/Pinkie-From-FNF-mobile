package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.system.scaleModes.RatioScaleMode;
import lime.graphics.RenderContext;
import lime.graphics.RenderContextType;
import openfl.Lib;
import openfl.display.Application;
import openfl.events.Event;

/** Exercises the real engine lifecycle and production Main; never renders a frame. */
@:access(flixel.FlxGame)
@:access(lime.ui.Window)
@:access(lime.graphics.RenderContext)
@:access(openfl.display.Stage)
class AndroidStartupTest
{
	static var assertions = 0;

	static function check(condition:Bool, message:String):Void
	{
		assertions++;
		if (!condition)
			throw message;
	}

	static function main():Void
	{
		var app = new Application();
		var window = app.createWindow({width: 2400, height: 1080, context: {}});
		// The interpreter has no native graphics context. Provide only its type;
		// OpenFL/Flixel constructors, event dispatch and resizing remain unchanged.
		window.context = new RenderContext();
		window.context.type = RenderContextType.CAIRO;
		window.resize(2400, 1080);
		window.stage.__resize();
		check(Lib.current.stage.stageWidth == 2400, "Headless stage width must be initialized");
		check(Lib.current.stage.stageHeight == 1080, "Headless stage height must be initialized");

		var scenario = Sys.args()[0];
		if (scenario == "engine")
		{
			var game = new FlxGame(1280, 720, TitleState, 1, 60, 60, true, false);
			check(game._state == null, "FlxGame must have no state before ADDED_TO_STAGE");
			var earlyResizeFailed = false;
			try
			{
				FlxG.scaleMode = new RatioScaleMode(false);
			}
			catch (error:Dynamic)
			{
				earlyResizeFailed = Std.string(error).indexOf("Null Access") != -1;
			}
			check(earlyResizeFailed, "The regression fixture must reproduce the early resize null access");
			check(TitleState.creates == 0, "An early scale-mode setter must not initialize the state");
			Lib.current.addChild(game);
			check(game._state != null && TitleState.creates == 1, "Stage attachment must initialize FlxGame");
			var resizes = TitleState.resizes;
			FlxG.scaleMode = new RatioScaleMode(false);
			check(TitleState.resizes == resizes + 1, "A post-attachment scale-mode setter must resize the live state");
		}
		else if (scenario == "application")
		{
			// This compiles the actual Main.hx copied by the runner, so restoring
			// its old setter-before-addChild ordering makes this scenario fail.
			Main.main();
			check(TitleState.creates == 1, "Production Main must initialize its Android initial state");
			check(FlxG.state != null, "Production Main must leave a live state");
			check(AndroidControls.creates == 1, "The controls must be attached after game initialization");
			check(FlxG.android.preventDefaultKeys.length == 1, "Main must configure the Android back key");
		}
		else
		{
			throw 'Unknown startup scenario: $scenario';
		}

		check(FlxG.width == 1280 && FlxG.height == 720, "Startup must retain the logical 1280x720 canvas");
		check(FlxG.scaleMode.gameSize.x == 1920 && FlxG.scaleMode.gameSize.y == 1080, "Ultrawide startup must retain 16:9");
		check(FlxG.game.x == 240 && FlxG.game.y == 0, "Ultrawide startup must center the letterboxed viewport");
		var resizes = TitleState.resizes;
		window.resize(1280, 720);
		window.stage.__resize();
		window.stage.dispatchEvent(new Event(Event.RESIZE));
		check(TitleState.resizes > resizes, "Subsequent stage resizing must reach the initialized state");
		check(FlxG.game.x == 0 && FlxG.game.y == 0, "16:9 resizing must remove the side bars");
		trace('Android startup $scenario passed ($assertions assertions; real Flixel/OpenFL lifecycle, no GPU/device execution).');
		// Flixel's timer plugins remain registered; no event loop is needed here.
		Sys.exit(0);
	}
}
