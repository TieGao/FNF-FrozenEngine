package backend;

import flixel.input.FlxInput;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

class Controls
{
	//Keeping same use cases on stuff for it to be easier to understand/use
	//I'd have removed it but this makes it a lot less annoying to use in my opinion

	//You do NOT have to create these variables/getters for adding new keys,
	//but you will instead have to use:
	//   controls.justPressed("ui_up")   instead of   controls.UI_UP

	//5K+ 谱面的多键输入不用在这里加 getter,直接用动态键名:
	//   controls.pressedKeyIndex('note_${totalKeys}k_$i', 0)

	// Pressed buttons (directions)
	public var UI_UP_P(get, never):Bool;
	public var UI_DOWN_P(get, never):Bool;
	public var UI_LEFT_P(get, never):Bool;
	public var UI_RIGHT_P(get, never):Bool;
	public var NOTE_UP_P(get, never):Bool;
	public var NOTE_DOWN_P(get, never):Bool;
	public var NOTE_LEFT_P(get, never):Bool;
	public var NOTE_RIGHT_P(get, never):Bool;

	private function get_UI_UP_P() return justPressed('ui_up');
	private function get_UI_DOWN_P() return justPressed('ui_down');
	private function get_UI_LEFT_P() return justPressed('ui_left');
	private function get_UI_RIGHT_P() return justPressed('ui_right');
	private function get_NOTE_UP_P() return justPressed('note_up');
	private function get_NOTE_DOWN_P() return justPressed('note_down');
	private function get_NOTE_LEFT_P() return justPressed('note_left');
	private function get_NOTE_RIGHT_P() return justPressed('note_right');

	// Held buttons (directions)
	public var UI_UP(get, never):Bool;
	public var UI_DOWN(get, never):Bool;
	public var UI_LEFT(get, never):Bool;
	public var UI_RIGHT(get, never):Bool;
	public var NOTE_UP(get, never):Bool;
	public var NOTE_DOWN(get, never):Bool;
	public var NOTE_LEFT(get, never):Bool;
	public var NOTE_RIGHT(get, never):Bool;

	private function get_UI_UP() return pressed('ui_up');
	private function get_UI_DOWN() return pressed('ui_down');
	private function get_UI_LEFT() return pressed('ui_left');
	private function get_UI_RIGHT() return pressed('ui_right');
	private function get_NOTE_UP() return pressed('note_up');
	private function get_NOTE_DOWN() return pressed('note_down');
	private function get_NOTE_LEFT() return pressed('note_left');
	private function get_NOTE_RIGHT() return pressed('note_right');

	// Released buttons (directions)
	public var UI_UP_R(get, never):Bool;
	public var UI_DOWN_R(get, never):Bool;
	public var UI_LEFT_R(get, never):Bool;
	public var UI_RIGHT_R(get, never):Bool;
	public var NOTE_UP_R(get, never):Bool;
	public var NOTE_DOWN_R(get, never):Bool;
	public var NOTE_LEFT_R(get, never):Bool;
	public var NOTE_RIGHT_R(get, never):Bool;

	private function get_UI_UP_R() return justReleased('ui_up');
	private function get_UI_DOWN_R() return justReleased('ui_down');
	private function get_UI_LEFT_R() return justReleased('ui_left');
	private function get_UI_RIGHT_R() return justReleased('ui_right');
	private function get_NOTE_UP_R() return justReleased('note_up');
	private function get_NOTE_DOWN_R() return justReleased('note_down');
	private function get_NOTE_LEFT_R() return justReleased('note_left');
	private function get_NOTE_RIGHT_R() return justReleased('note_right');

	// Pressed buttons (others)
	public var ACCEPT(get, never):Bool;
	public var BACK(get, never):Bool;
	public var PAUSE(get, never):Bool;
	public var RESET(get, never):Bool;
	private function get_ACCEPT() return justPressed('accept');
	private function get_BACK() return justPressed('back');
	private function get_PAUSE() return justPressed('pause');
	private function get_RESET() return justPressed('reset');

	//Gamepad & Keyboard stuff
	public var keyboardBinds:Map<String, Array<FlxKey>>;
	public var gamepadBinds:Map<String, Array<FlxGamepadInputID>>;

	public function justPressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadCheck(gamepadBinds[key], -1, JUST_PRESSED) == true;
	}

	public function pressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadCheck(gamepadBinds[key], -1, PRESSED) == true;
	}

	public function justReleased(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustReleased(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadCheck(gamepadBinds[key], -1, JUST_RELEASED) == true;
	}

	// 按索引读单个键位(主键位 index 0 / 备用 index 1),多键谱面用动态键名走这里
	public function justPressedKeyIndex(key:String, index:Int):Bool
	{
		var keys:Array<FlxKey> = keyboardBinds[key];
		if(keys == null || index < 0 || index >= keys.length) return false;
		var result:Bool = (FlxG.keys.checkStatus(keys[index], JUST_PRESSED) == true);
		if(result) controllerMode = false;

		return result || _myGamepadCheck(gamepadBinds[key], index, JUST_PRESSED) == true;
	}

	public function pressedKeyIndex(key:String, index:Int):Bool
	{
		var keys:Array<FlxKey> = keyboardBinds[key];
		if(keys == null || index < 0 || index >= keys.length) return false;
		var result:Bool = (FlxG.keys.checkStatus(keys[index], PRESSED) == true);
		if(result) controllerMode = false;

		return result || _myGamepadCheck(gamepadBinds[key], index, PRESSED) == true;
	}

	public function justReleasedKeyIndex(key:String, index:Int):Bool
	{
		var keys:Array<FlxKey> = keyboardBinds[key];
		if(keys == null || index < 0 || index >= keys.length) return false;
		var result:Bool = (FlxG.keys.checkStatus(keys[index], JUST_RELEASED) == true);
		if(result) controllerMode = false;

		return result || _myGamepadCheck(gamepadBinds[key], index, JUST_RELEASED) == true;
	}

	public var controllerMode:Bool = false;

	// 手柄轮询:全组(index = -1)或单个键位(index >= 0),state 决定按下/刚按下/刚松开
	private function _myGamepadCheck(keys:Array<FlxGamepadInputID>, index:Int, state:FlxInputState):Bool
	{
		if(keys == null) return false;

		if(index >= 0)
		{
			if(index < keys.length && _padHasState(keys[index], state))
			{
				controllerMode = true;
				return true;
			}
			return false;
		}

		for (key in keys)
		{
			if(_padHasState(key, state))
			{
				controllerMode = true;
				return true;
			}
		}
		return false;
	}

	private inline function _padHasState(id:FlxGamepadInputID, state:FlxInputState):Bool
	{
		return switch(state)
		{
			case JUST_PRESSED:  FlxG.gamepads.anyJustPressed(id);
			case PRESSED:       FlxG.gamepads.anyPressed(id);
			case JUST_RELEASED: FlxG.gamepads.anyJustReleased(id);
			default: false;
		}
	}

	// IGNORE THESE
	public static var instance:Controls;
	public function new()
	{
		keyboardBinds = ClientPrefs.keyBinds;
		gamepadBinds = ClientPrefs.gamepadBinds;
	}
}
