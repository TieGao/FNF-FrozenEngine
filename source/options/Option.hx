package options;

import options.objects.OptionCategory;
import flixel.util.FlxColor;

typedef Keybind = {
	keyboard:String,
	gamepad:String
}

enum OptionType {
	BOOL;
	INT;
	FLOAT;
	PERCENT;
	STRING;
	KEYBIND;
	ACTION;
	COLOR;   // ← 新增
}

class Option
{
	public var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Void->Void = null;
	public var type:OptionType = BOOL;

	public var scrollSpeed:Float = 50;
	private var _description:String = '';
	public var variable(default, null):String = null;
	public var defaultValue:Dynamic = null;

	public var curOption:Int = 0;
	public var options:Array<String> = null;
	public var changeValue:Dynamic = 1;
	public var minValue:Dynamic = null;
	public var maxValue:Dynamic = null;
	public var decimals:Int = 1;

	public static var onValueSaved:Option->Void = null;

	public var displayFormat:String = '%v';
	public var description:String = '';
	public var name:String = 'Unknown';

	public var defaultKeys:Keybind = null;
	public var keys:Keybind = null;

	// =========================================================
	// Win10 风格 UI 组件补充属性
	// =========================================================
	public var allowUpdate:Bool = true;
	public var followX:Float = 0;
	public var innerX:Float = 0;
	public var updateDisText:Void->Void = null;
	public var action:Void->Void = null;
	public var actionLabel:String = '';
	public var ownerCategory:OptionCategory = null;

	// =========================================================
	// 调色板（COLOR 类型）
	// =========================================================
	public static var COLOR_PALETTE:Array<Int> = [
		FlxColor.WHITE,
		FlxColor.GRAY,
		FlxColor.BLACK,
		FlxColor.GREEN,
		FlxColor.LIME,
		FlxColor.YELLOW,
		FlxColor.ORANGE,
		FlxColor.RED,
		FlxColor.PURPLE,
		FlxColor.BLUE,
		FlxColor.BROWN,
		FlxColor.PINK,
		FlxColor.MAGENTA,
		FlxColor.CYAN
	];

	public static var COLOR_NAMES:Array<String> = [
		"WHITE", "GRAY", "BLACK", "GREEN", "LIME", "YELLOW", "ORANGE", "RED",
		"PURPLE", "BLUE", "BROWN", "PINK", "MAGENTA", "CYAN"
	];

	private static var HEX_CHARS:Array<String> = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"];

	public static function byteToHex(b:Int):String {
		return HEX_CHARS[(b >> 4) & 0xF] + HEX_CHARS[b & 0xF];
	}

	public static function intToHex(c:Int):String {
		var rgb = c & 0xFFFFFF;
		return "#" + byteToHex((rgb >> 16) & 0xFF) + byteToHex((rgb >> 8) & 0xFF) + byteToHex(rgb & 0xFF);
	}

	public static function colorName(c:Int):String {
		for (i in 0...COLOR_PALETTE.length)
			if (COLOR_PALETTE[i] == c) return COLOR_NAMES[i];
		return FlxColor.fromInt(c).toWebString().toUpperCase();
	}

	/** 根据亮度选前景色（黑/白），用于在色块上画字 */
	public static function contrastText(c:Int):Int {
		var r = (c >> 16) & 0xFF;
		var g = (c >> 8) & 0xFF;
		var b = c & 0xFF;
		var lum = 0.299 * r + 0.587 * g + 0.114 * b;
		return lum > 150 ? 0xFF000000 : 0xFFFFFFFF;
	}

	// =========================================================

	public function new(name:String, description:String = '', variable:String,
                    type:OptionType = BOOL, ?options:Array<String> = null,
                    ?translation:String = null,
                    ?minValue:Dynamic = null, ?maxValue:Dynamic = null,
                    ?changeValue:Dynamic = null)
	{
		_name = name;
		_description = description;
		_translationKey = translation != null ? translation : _name;
		this.name = Language.getPhrase('setting_$_translationKey', name);
		this.description = Language.getPhrase('description_$_translationKey', description);
		this.variable = variable;
		this.type = type;
		this.options = options;

		if (this.type != KEYBIND) this.defaultValue = Reflect.getProperty(ClientPrefs.defaultData, variable);

		switch(type)
		{
			case BOOL:
				if (defaultValue == null) defaultValue = false;
			case INT, FLOAT:
				if (defaultValue == null) defaultValue = 0;
			case PERCENT:
				if (defaultValue == null) defaultValue = 1;
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
			case STRING:
				if (options != null && options.length > 0)
					defaultValue = options[0];
				if (defaultValue == null)
					defaultValue = '';
			case KEYBIND:
				defaultValue = '';
				defaultKeys = {gamepad: 'NONE', keyboard: 'NONE'};
				keys = {gamepad: 'NONE', keyboard: 'NONE'};
			case ACTION:
				defaultValue = null;
			case COLOR:
				if (defaultValue == null) defaultValue = FlxColor.WHITE;
				changeValue = 1;
				curOption = 0;
				for (i in 0...COLOR_PALETTE.length)
					if (COLOR_PALETTE[i] == defaultValue) { curOption = i; break; }
		}

		try
		{
			if (getValue() == null)
				setValue(defaultValue);

			switch(type)
			{
				case STRING:
					if (options != null) {
						var num:Int = options.indexOf(getValue());
						if (num > -1) curOption = num;
					}
				case COLOR:
					var v = getValue();
					if (v == null) { setValue(defaultValue); v = defaultValue; }
					for (i in 0...COLOR_PALETTE.length)
						if (COLOR_PALETTE[i] == v) { curOption = i; break; }
				default:
			}
		}
		catch(e) {}

		    if (minValue    != null) this.minValue    = minValue;
			if (maxValue    != null) this.maxValue    = maxValue;
			if (changeValue != null) this.changeValue = changeValue;
	}

	public function change()
	{
		//trace('[Option.change] variable=$variable, onChange=${onChange != null}');
		if (onChange != null)
			onChange();
	}

	public function refreshLanguage():Void
	{
		this.name = Language.getPhrase('setting_$_translationKey', _name);
		this.description = Language.getPhrase('description_$_translationKey', _description);
		if (child != null)
			child.text = Language.getPhrase('setting_$_translationKey-${getValue()}', _text);
	}

	public function getOptionText(value:Dynamic):String
	{
		if (value == null) return '';
		var raw:String = Std.string(value);
		return Language.getPhrase('setting_$_translationKey-${raw}', raw);
	}

	dynamic public function getValue():Dynamic
	{
		var value = Reflect.getProperty(ClientPrefs.data, variable);
		if (type == KEYBIND) return !Controls.instance.controllerMode ? value.keyboard : value.gamepad;
		return value;
	}

	dynamic public function setValue(value:Dynamic)
	{
		if (type == KEYBIND)
		{
			var keys = Reflect.getProperty(ClientPrefs.data, variable);
			if (!Controls.instance.controllerMode) keys.keyboard = value;
			else keys.gamepad = value;
			return value;
		}
		return Reflect.setProperty(ClientPrefs.data, variable, value);
	}

	public function saveCurrentValue():Void
	{
		ClientPrefs.saveSettings();
		applyImmediateChanges();

		if (onValueSaved != null) onValueSaved(this);
	}

	private function applyImmediateChanges():Void
	{
		switch(variable)
		{
			case 'framerate':
				if (ClientPrefs.data.framerate > FlxG.drawFramerate)
				{
					FlxG.updateFramerate = ClientPrefs.data.framerate;
					FlxG.drawFramerate = ClientPrefs.data.framerate;
				}
				else
				{
					FlxG.drawFramerate = ClientPrefs.data.framerate;
					FlxG.updateFramerate = ClientPrefs.data.framerate;
				}
			case 'showFPS':
				if (Main.fpsVar != null)
					Main.fpsVar.visible = ClientPrefs.data.showFPS;
			case 'autoPause':
				FlxG.autoPause = ClientPrefs.data.autoPause;
			case 'language':
				backend.Language.reloadPhrases();
			case 'keyboardBGColor', 'keyboardTextColor':
				try
				{
					var col = Reflect.getProperty(ClientPrefs.data, variable);
					if (objects.KeyboardViewer.instance != null)
					{
						var kv = objects.KeyboardViewer.instance;
						for (m in kv.members)
						{
							try Reflect.setProperty(m, 'color', col) catch(_) {}
						}
						for (t in kv.keyTexts) t.color = ClientPrefs.data.keyboardTextColor;
						if (kv.kpsText != null) kv.kpsText.color = ClientPrefs.data.keyboardTextColor;
						if (kv.totalText != null) kv.totalText.color = ClientPrefs.data.keyboardTextColor;
					}
				}
				catch(e:Dynamic) {}
		}
	}

	var _name:String = null;
	var _text:String = null;
	var _translationKey:String = null;
	private function get_text()
		return _text;

	private function set_text(newValue:String = '')
	{
		if (child != null)
		{
			_text = newValue;
			child.text = Language.getPhrase('setting_$_translationKey-${getValue()}', _text);
			return _text;
		}
		return null;
	}
}