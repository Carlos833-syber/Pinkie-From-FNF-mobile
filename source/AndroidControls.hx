package;

#if android
import AndroidTouchInput.AndroidTouchRegion;
import flixel.FlxG;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.TouchEvent;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

private typedef AndroidTouchButton =
{
	var sprite:Sprite;
	var region:AndroidTouchRegion;
	var bitmap:Bitmap;
	var frameWidth:Int;
	var hitbox:Bool;
}

/** Psych mobile controls, fixed to the game's letterboxed viewport instead of modchart cameras. */
@:access(PlayState)
class AndroidControls extends Sprite
{
	static inline var MENU:Int = 1;
	static inline var DIALOGUE:Int = 2;
	static inline var HITBOX:Int = 3;

	var menu:Sprite = new Sprite();
	var dialogue:Sprite = new Sprite();
	var hitbox:Sprite = new Sprite();
	var menuRegions:Array<AndroidTouchRegion> = [];
	var dialogueRegions:Array<AndroidTouchRegion> = [];
	var hitboxRegions:Array<AndroidTouchRegion> = [];
	var buttons:Array<AndroidTouchButton> = [];
	var pause:AndroidTouchButton;
	var input:AndroidTouchInput;
	var attachedStage:Stage;
	var previousState:Dynamic;
	var previousSubState:Dynamic;
	var mode:Int = -1;
	var pauseEnabled:Bool = false;

	public function new()
	{
		super();
		mouseEnabled = false;
		mouseChildren = false;
		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
		input = new AndroidTouchInput(emit);
		addChild(hitbox);
		addChild(menu);
		addChild(dialogue);

		// Positions, colors and sprites match Psych Engine Mobile's LEFT_FULL + A_B pad.
		addPadButton(menu, menuRegions, 0, 477, "left", 0xFF00FF, 37);
		addPadButton(menu, menuRegions, 105, 585, "down", 0x00FFFF, 40);
		addPadButton(menu, menuRegions, 105, 375, "up", 0x00FF00, 38);
		addPadButton(menu, menuRegions, 207, 477, "right", 0xFF0000, 39);
		addPadButton(menu, menuRegions, 1022, 585, "b", 0xFFCB00, 27);
		addPadButton(menu, menuRegions, 1148, 585, "a", 0xFF0000, 13);

		addPadButton(dialogue, dialogueRegions, 896, 585, "c", 0x44FF00, 16);
		addPadButton(dialogue, dialogueRegions, 1022, 585, "b", 0xFFCB00, 32);
		addPadButton(dialogue, dialogueRegions, 1148, 585, "a", 0xFF0000, 13);
		addLabel(896, "REVELAR");
		addLabel(1022, "PULAR");
		addLabel(1148, "AVANÇAR");

		var colors = [0xFF00FF, 0x00FFFF, 0x00FF00, 0xFF0000];
		var keys = [37, 40, 38, 39];
		for (i in 0...4)
		{
			var lane = new Sprite();
			lane.graphics.beginFill(colors[i], 0.5333);
			lane.graphics.drawRect(0, 0, 320, 720);
			lane.graphics.endFill();
			lane.x = i * 320;
			lane.alpha = 0.00001;
			hitbox.addChild(lane);
			var region:AndroidTouchRegion = {
				x: lane.x,
				y: 0,
				width: 320,
				height: 720,
				key: keys[i]
			};
			hitboxRegions.push(region);
			buttons.push({
				sprite: lane,
				region: region,
				bitmap: null,
				frameWidth: 0,
				hitbox: true
			});
		}

		var pauseSprite = new Sprite();
		var pauseBitmap = new Bitmap(Assets.getBitmapData("assets/images/mobile/pauseButton.png"));
		pauseBitmap.smoothing = true;
		pauseSprite.addChild(pauseBitmap);
		pauseSprite.scaleX = pauseSprite.scaleY = 0.8;
		pauseSprite.x = 1150;
		pauseSprite.y = 25;
		pauseSprite.alpha = 0.7;
		hitbox.addChild(pauseSprite);
		pause = {
			sprite: pauseSprite,
			region: {
				x: 1150,
				y: 25,
				width: pauseBitmap.width * 0.8,
				height: pauseBitmap.height * 0.8,
				key: 13
			},
			bitmap: null,
			frameWidth: 0,
			hitbox: false
		};
		hitboxRegions.push(pause.region);
		buttons.push(pause);

		addEventListener(Event.ADDED_TO_STAGE, attach);
		addEventListener(Event.REMOVED_FROM_STAGE, detach);
	}

	function addPadButton(group:Sprite, regions:Array<AndroidTouchRegion>, x:Float, y:Float, graphic:String, color:Int, key:Int):Void
	{
		var data = Assets.getBitmapData('assets/images/mobile/virtualpad/$graphic.png');
		var frameWidth = Std.int(data.width / 3);
		var bitmap = new Bitmap(data);
		bitmap.smoothing = true;
		var button = new Sprite();
		button.addChild(bitmap);
		button.scrollRect = new Rectangle(0, 0, frameWidth, data.height);
		button.transform.colorTransform = new ColorTransform(((color >> 16) & 255) / 255, ((color >> 8) & 255) / 255, (color & 255) / 255);
		button.x = x;
		button.y = y;
		button.alpha = 0.5;
		group.addChild(button);
		var region:AndroidTouchRegion = {
			x: x,
			y: y,
			width: frameWidth,
			height: data.height,
			key: key
		};
		regions.push(region);
		buttons.push({
			sprite: button,
			region: region,
			bitmap: bitmap,
			frameWidth: frameWidth,
			hitbox: false
		});
	}

	function addLabel(x:Float, text:String):Void
	{
		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 17, 0xFFFFFF, true, null, null, null, null, "center");
		label.text = text;
		label.width = 132;
		label.height = 25;
		label.x = x;
		label.y = 558;
		label.selectable = false;
		label.mouseEnabled = false;
		dialogue.addChild(label);
	}

	function attach(_:Event):Void
	{
		attachedStage = stage;
		attachedStage.addEventListener(TouchEvent.TOUCH_BEGIN, begin);
		attachedStage.addEventListener(TouchEvent.TOUCH_MOVE, move);
		attachedStage.addEventListener(TouchEvent.TOUCH_END, end);
		attachedStage.addEventListener(Event.DEACTIVATE, reset);
		attachedStage.addEventListener(Event.RESIZE, resize);
		FlxG.signals.preUpdate.add(beforeUpdate);
		FlxG.signals.postUpdate.add(afterUpdate);
		resize(null);
		updateContext();
	}

	function detach(_:Event):Void
	{
		input.reset();
		attachedStage.removeEventListener(TouchEvent.TOUCH_BEGIN, begin);
		attachedStage.removeEventListener(TouchEvent.TOUCH_MOVE, move);
		attachedStage.removeEventListener(TouchEvent.TOUCH_END, end);
		attachedStage.removeEventListener(Event.DEACTIVATE, reset);
		attachedStage.removeEventListener(Event.RESIZE, resize);
		FlxG.signals.preUpdate.remove(beforeUpdate);
		FlxG.signals.postUpdate.remove(afterUpdate);
		attachedStage = null;
	}

	function resize(_:Event):Void
	{
		// Use Flixel's exact rounded viewport so controls also exclude the black bars.
		x = FlxG.scaleMode.offset.x;
		y = FlxG.scaleMode.offset.y;
		scaleX = FlxG.scaleMode.scale.x * FlxG.initialZoom;
		scaleY = FlxG.scaleMode.scale.y * FlxG.initialZoom;
	}

	function beforeUpdate():Void
	{
		resize(null);
		updateContext();
		input.flush();
	}

	function afterUpdate():Void
	{
		updateContext();
		for (button in buttons)
		{
			var held = input.isHeld(button.region.key);
			if (button.hitbox)
			{
				var target = held ? 0.2 : 0.00001;
				var speed = held ? 0.075 : 0.15;
				button.sprite.alpha += (target - button.sprite.alpha) * Math.min(1, FlxG.elapsed / speed);
			}
			else if (button.bitmap != null)
				button.bitmap.x = held ? -button.frameWidth * 2 : 0;
		}
	}

	function updateContext():Void
	{
		var state = FlxG.state;
		var sub = state == null ? null : state.subState;
		var nextMode = state == null ? 0 : MENU;
		pauseEnabled = false;
		if (Std.isOfType(state, PlayState) && sub == null)
		{
			var play:PlayState = cast state;
			if (play.inCutscene)
				nextMode = DIALOGUE;
			else if (!play.paused)
			{
				nextMode = HITBOX;
				pauseEnabled = play.startedCountdown && play.canPause;
			}
			else
				nextMode = 0;
		}
		if (state != previousState || sub != previousSubState || mode != nextMode)
			input.reset();
		previousState = state;
		previousSubState = sub;
		mode = nextMode;
		menu.visible = mode == MENU;
		dialogue.visible = mode == DIALOGUE;
		hitbox.visible = mode == HITBOX;
		pause.sprite.visible = pauseEnabled;
		pause.region.key = pauseEnabled ? 13 : -1;
	}

	function keyAt(event:TouchEvent):Int
	{
		var point = globalToLocal(new Point(event.stageX, event.stageY));
		var regions = switch (mode)
		{
			case MENU: menuRegions;
			case DIALOGUE: dialogueRegions;
			case HITBOX: hitboxRegions;
			default: [];
		};
		return AndroidTouchInput.hitTest(point.x, point.y, regions);
	}

	function begin(event:TouchEvent):Void
	{
		updateContext();
		input.begin(event.touchPointID, keyAt(event));
	}

	function move(event:TouchEvent):Void
	{
		input.move(event.touchPointID, keyAt(event));
	}

	function end(event:TouchEvent):Void
	{
		input.end(event.touchPointID);
	}

	function emit(key:Int, down:Bool):Void
	{
		if (attachedStage != null)
			attachedStage.dispatchEvent(new KeyboardEvent(down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, 0, key));
	}

	function reset(_:Event):Void
	{
		input.reset();
	}
}
#end
