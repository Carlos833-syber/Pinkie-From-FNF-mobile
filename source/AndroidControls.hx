package;

#if android
import flixel.FlxG;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.TouchEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

/** Stage-space controls stay fixed even when a modchart moves the game cameras. */
class AndroidControls extends Sprite
{
	var buttons:Array<Sprite> = [];
	var keys:Array<Int> = [37, 40, 38, 39, 27, 13, 32, 16];
	var fingers:Map<Int, Int> = new Map();
	var previousState:Dynamic;
	var previousSubState:Dynamic;

	public function new()
	{
		super();
		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
		var labels = ["<", "v", "^", ">", "BACK", "OK / PAUSE", "SKIP", "AUTO"];
		for (i in 0...keys.length)
		{
			var button = new Sprite();
			button.graphics.beginFill(0x202030, 0.5);
			button.graphics.lineStyle(2, 0xFFFFFF, 0.65);
			button.graphics.drawRoundRect(0, 0, 145, 95, 14);
			button.graphics.endFill();
			var label = new TextField();
			label.defaultTextFormat = new TextFormat("_sans", 20, 0xFFFFFF, true, null, null, null, null, "center");
			label.text = labels[i];
			label.width = 145;
			label.height = 45;
			label.y = 30;
			label.selectable = false;
			label.mouseEnabled = false;
			button.addChild(label);
			button.x = i < 4 ? 15 + i * 165 : 1280 - (8 - i) * 160;
			button.y = i < 4 ? 610 : 10;
			addChild(button);
			buttons.push(button);
		}
		addEventListener(Event.ADDED_TO_STAGE, attach);
	}

	function attach(_:Event):Void
	{
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, touch);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, touch);
		stage.addEventListener(TouchEvent.TOUCH_END, release);
		stage.addEventListener(Event.DEACTIVATE, reset);
		stage.addEventListener(Event.RESIZE, resize);
		addEventListener(Event.ENTER_FRAME, frame);
		resize(null);
	}

	function resize(_:Event):Void
	{
		scaleX = stage.stageWidth / 1280;
		scaleY = stage.stageHeight / 720;
	}

	function frame(_:Event):Void
	{
		var state = FlxG.state;
		var sub = state == null ? null : state.subState;
		if (state != previousState || sub != previousSubState)
			reset(null);
		previousState = state;
		previousSubState = sub;
	}

	function touch(event:TouchEvent):Void
	{
		var index = -1;
		for (i in 0...buttons.length)
			if (buttons[i].hitTestPoint(event.stageX, event.stageY))
			{
				index = i;
				break;
			}
		if (fingers.exists(event.touchPointID) && fingers.get(event.touchPointID) == index)
			return;
		release(event);
		if (index >= 0)
		{
			var held = isHeld(index);
			fingers.set(event.touchPointID, index);
			if (!held)
				emit(index, true);
		}
	}

	function release(event:TouchEvent):Void
	{
		if (!fingers.exists(event.touchPointID))
			return;
		var index = fingers.get(event.touchPointID);
		fingers.remove(event.touchPointID);
		if (!isHeld(index))
			emit(index, false);
	}

	function isHeld(index:Int):Bool
	{
		for (held in fingers)
			if (held == index)
				return true;
		return false;
	}

	function emit(index:Int, down:Bool):Void
	{
		buttons[index].alpha = down ? 1 : 0.65;
		stage.dispatchEvent(new KeyboardEvent(down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, 0, keys[index]));
	}

	function reset(_:Event):Void
	{
		for (i in 0...keys.length)
			if (isHeld(i))
				emit(i, false);
		fingers.clear();
	}
}
#end
