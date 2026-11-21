package options;

import options.objects.OptionCategory;
import options.objects.backend.IStringValueSource;
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

class Option implements options.objects.backend.IStringValueSource
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

	/** 运行时注入的取值/写值钩子（ModSettingsSubState 用 save 映射替代 ClientPrefs 直读）。
	 *  之前靠 dynamic 函数重赋值实现；IStringValueSource 接口化后 getValue/setValue 必须是普通方法，改走钩子。 */
	public var getValueOverride:Void->Dynamic = null;
	public var setValueOverride:Dynamic->Void = null;

	public var displayFormat:String = '%v';
	public var description:String = '';
	public var name:String = 'Unknown';

	/**
	 * 未翻译的原始名（构造时传进来的那个）。
	 * `name` 是译文（中文下 'Scroll Speed' 会变成 '音符流速'），所以按英文名查找的入口
	 * （getOptionByName 这类，HScript / mod 也会调）必须用这个，否则非英语语言下全部落空。
	 */
	public var rawName(get, never):String;
	inline function get_rawName():String return _name;

	/**
	 * 自定义数值文本（可选）。设了之后 NumButton 会用它格式化当前值，
	 * 比如 Skip Time 用它把毫秒显示成 "1:23 / 3:45"。
	 */
	public var valueFormatter:Float->String = null;

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

	/**
	 * COLOR 类型专用的色板。为 null 时回落到全局 COLOR_PALETTE。
	 * 强调色这类"只该从固定几色里挑"的选项用它收窄选择范围。
	 */
	public var palette:Array<Int> = null;
	public var paletteNames:Array<String> = null;

	/**
	 * 本页总开关（只有 BOOL 能用）。
	 *
	 * 置 true 的选项放在该页第一项；它为关时，同页其余选项整体隐藏，
	 * 关 / 开即时生效。判定与列表重建见 `OptionCategory.visibleOptions()` 与
	 * `OptionsPageState.buildRows()`。
	 */
	public var pageGate:Bool = false;

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

	/**
	 * UI 强调色专用色板：全部取中明度，浅色底上作文字色也能读。
	 * 首项是默认蓝，刻意保留现有暗色观感（比其余色亮一档）。
	 */
	public static var ACCENT_PALETTE:Array<Int> = [
		0xFF4CC2FF, // Default Blue
		0xFF0891B2, // Cyan
		0xFF0D9488, // Teal
		0xFF16A34A, // Green
		0xFF65A30D, // Lime
		0xFFCA8A04, // Amber
		0xFFEA580C, // Orange
		0xFFDC2626, // Red
		0xFFDB2777, // Pink
		0xFF7C3AED, // Purple
		0xFF4F46E5, // Indigo
		0xFF64748B  // Slate
	];

	public static var ACCENT_NAMES:Array<String> = [
		"Default Blue", "Cyan", "Teal", "Green", "Lime", "Amber",
		"Orange", "Red", "Pink", "Purple", "Indigo", "Slate"
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
		return backend.UITheme.contrastText(c, 150);
	}

	// ---------------------------------------------------------
	// 色板
	// ---------------------------------------------------------
	public function paletteOf():Array<Int>
		return palette != null ? palette : COLOR_PALETTE;

	public function paletteNamesOf():Array<String>
		return paletteNames != null ? paletteNames : COLOR_NAMES;

	/** 按本选项的色板查色名，查不到回落 #RRGGBB */
	public function colorNameOf(c:Int):String
	{
		var pal:Array<Int> = paletteOf();
		var names:Array<String> = paletteNamesOf();
		for (i in 0...pal.length)
			if (pal[i] == c && i < names.length) return names[i];
		return intToHex(c);
	}

	/**
	 * 设置专用色板，并按当前值重新对齐 curOption。
	 * 不重算的话键盘左右循环会从错误的下标起步。
	 */
	public function setPalette(pal:Array<Int>, names:Array<String>):Void
	{
		palette = pal;
		paletteNames = names;
		if (type != COLOR || pal == null) return;

		var v:Dynamic = getValue();
		if (v == null) v = defaultValue;
		curOption = 0;
		if (v == null) return;

		var iv:Int = v;
		for (i in 0...pal.length)
			if (pal[i] == iv) { curOption = i; break; }
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

	public function getValue():Dynamic
	{
		if (getValueOverride != null) return getValueOverride();
		var value = Reflect.getProperty(ClientPrefs.data, variable);
		if (type == KEYBIND) return !Controls.instance.controllerMode ? value.keyboard : value.gamepad;
		return value;
	}

	public function setValue(value:Dynamic):Void
	{
		if (setValueOverride != null)
		{
			setValueOverride(value);
			return;
		}
		if (type == KEYBIND)
		{
			var keys = Reflect.getProperty(ClientPrefs.data, variable);
			if (!Controls.instance.controllerMode) keys.keyboard = value;
			else keys.gamepad = value;
			return;
		}
		Reflect.setProperty(ClientPrefs.data, variable, value);
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
		case 'framerate', 'updaterate', 'unlimitedFPS', 'fpsRework', 'devideDrawAndUpdate':
			// 所有帧率相关开关统一走 lime 帧调度入口（unlimitedFPS = FrameProfile.UNCAPPED）
			ClientPrefs.applyFrameTiming();
		case 'showFPS':
				if (Main.fpsVar != null)
					Main.fpsVar.visible = ClientPrefs.data.showFPS;
			case 'autoPause':
				FlxG.autoPause = ClientPrefs.data.autoPause;
			case 'language':
				backend.Language.reloadPhrases();
			case 'sessionLogMax':
				// 保留上限改动立即清理旧日志档案
				debug.LogFile.trimArchives();
			case 'colorMode':
				// 深浅色切换：刷新调色板，界面会收到通知后重建
				backend.UITheme.refresh();
			case 'controlTheme':
				// 控件风格（Win10 / Win8 按钮）切换：同样刷新一次，
				// 界面发现 UITheme.version 变了就会按新风格重建控件
				backend.UITheme.refresh();
			case 'uiAccent', 'uiAccentHover':
				// 强调色改动：UITheme 重新派生整套色，界面按 version 重建
				backend.UITheme.refresh();
			case 'keyboardBGColor', 'keyboardEdgeColor', 'keyboardRainColor', 'keyboardTextColor':
				// 颜色语义已经按目标拆开（主体 / 边缘 / 键雨 / 文字），不能再对 members 无脑
				// `color = col` —— 那会把 KeyButtonAlpha（按压高亮）和按键文字一起染掉。
				objects.KeyboardViewer.refreshAll();
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