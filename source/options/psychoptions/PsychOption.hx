package options.psychoptions;

import options.objects.OptionCategory;

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
	ACTION;   // ← 新增：纯动作按钮，不读写 ClientPrefs
}

class PsychOption
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

	public var displayFormat:String = '%v';
	public var description:String = '';
	public var name:String = 'Unknown';

	public var defaultKeys:Keybind = null;
	public var keys:Keybind = null;

	// =========================================================
	// Win10 风格 UI 组件补充属性
	// =========================================================
	/** 是否允许响应输入 */
	public var allowUpdate:Bool = true;

	/** 选项在父容器中的 X 基准位置 */
	public var followX:Float = 0;

	/** 选项内部的 X 偏移量 */
	public var innerX:Float = 0;

	/** 值变化时刷新显示文本的回调 */
	public var updateDisText:Void->Void = null;

	/** 动作回调：FunctionButton / ResetButton 点击时执行 */
	public var action:Void->Void = null;

	/** 按钮上显示的文字（为空则用默认 "Open" / "Reset"） */
	public var actionLabel:String = '';

	/** 该 option 所属的 section（由 OptionSection.add 自动赋值） */
	public var ownerCategory:OptionCategory = null;

	// =========================================================

	public function new(name:String, description:String = '', variable:String, type:OptionType = BOOL, ?options:Array<String> = null, ?translation:String = null)
	{
		_name = name;
		_description = description;
		_translationKey = translation != null ? translation : _name;
		this.name = Language.getPhrase('setting_$_translationKey', name);
		this.description = Language.getPhrase('description_$_translationKey', description);
		this.variable = variable;
		this.type = type;
		this.options = options;

		if(this.type != KEYBIND) this.defaultValue = Reflect.getProperty(ClientPrefs.defaultData, variable);
		switch(type)
		{
			case BOOL:
				if(defaultValue == null) defaultValue = false;
			case INT, FLOAT:
				if(defaultValue == null) defaultValue = 0;
			case PERCENT:
				if(defaultValue == null) defaultValue = 1;
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
			case STRING:
				if(options.length > 0)
					defaultValue = options[0];
				if(defaultValue == null)
					defaultValue = '';

			case KEYBIND:
				defaultValue = '';
				defaultKeys = {gamepad: 'NONE', keyboard: 'NONE'};
				keys = {gamepad: 'NONE', keyboard: 'NONE'};
			    case ACTION:
        		defaultValue = null;
		}

		try
		{
			if(getValue() == null)
				setValue(defaultValue);
	
			switch(type)
			{
				case STRING:
					var num:Int = options.indexOf(getValue());
					if(num > -1) curOption = num;

				default:
			}
		}
		catch(e) {}
	}

	public function change()
	{
		if(onChange != null)
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
		if(type == KEYBIND) return !Controls.instance.controllerMode ? value.keyboard : value.gamepad;
		return value;
	}

	dynamic public function setValue(value:Dynamic)
	{
		if(type == KEYBIND)
		{
			var keys = Reflect.getProperty(ClientPrefs.data, variable);
			if(!Controls.instance.controllerMode) keys.keyboard = value;
			else keys.gamepad = value;
			return value;
		}
		return Reflect.setProperty(ClientPrefs.data, variable, value);
	}

	public function saveCurrentValue():Void
	{
		ClientPrefs.saveSettings();
		applyImmediateChanges();
	}

	private function applyImmediateChanges():Void
	{
		switch(variable)
		{
			case 'framerate':
				if(ClientPrefs.data.framerate > FlxG.drawFramerate)
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
				if(Main.fpsVar != null)
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
		if(child != null)
		{
			_text = newValue;
			child.text = Language.getPhrase('setting_$_translationKey-${getValue()}', _text);
			return _text;
		}
		return null;
	}
}