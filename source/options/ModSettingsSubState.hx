package options;

import options.Option.OptionType;
import options.Win8CharmSettings.CharmEntry;
import options.objects.backend.KeybindButton;

/**
 * Mod Settings —— Win8 风格设置面板
 *
 * 继承 options.Win8CharmSettings，内容来自 mod 的 data/settings.json：
 *   { name, description, save, type, options, translation_key,
 *     value, min, max, step, scroll, decimals, format, keyboard, gamepad }
 * 值存进 FlxG.save.data.modSettings[folder]，关闭时写回存档。
 *
 * 对外接口：构造签名 (options, folder, name)、类名、HScript 注册名
 * 'options.ModSettingsSubState'。
 *
 * ⚠️ 选项必须在**构造函数**里解析，不能拖到 create()：Win8CharmSettings.create() 会立刻
 *   调 buildCharms()，而 create() 要到下一帧（FlxState.resetSubState）才跑 —— 拖过去
 *   等于每次多一次重建。副作用是解析失败能在构造阶段就报出来（见 _crashed）。
 */
class ModSettingsSubState extends Win8CharmSettings
{
	/** 本 mod 的设置存档，写回 FlxG.save.data.modSettings[folder] */
	var save:Map<String, Dynamic> = new Map<String, Dynamic>();
	var folder:String = '';
	var modName:String = '';

	/** 构造阶段解析好的选项，buildCharms() 直接把它交给面板 */
	var builtOptions:Array<Option> = [];

	/** settings.json 解析失败 → create() 里不建面板，直接退出 */
	var _crashed:Bool = false;
	/** 已经写回过存档（close / destroy 只写一次） */
	var _persisted:Bool = false;

	public function new(options:Array<Dynamic>, folder:String, name:String)
	{
		super();

		this.folder = folder;
		this.modName = (name != null && name != '') ? name : folder;

		save = new Map<String, Dynamic>();
		builtOptions = [];

		if (FlxG.save.data.modSettings == null)
			FlxG.save.data.modSettings = new Map<String, Dynamic>();
		else
		{
			var saveMap:Map<String, Dynamic> = FlxG.save.data.modSettings;
			if (saveMap[folder] != null) save = saveMap[folder];
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Mod Settings ($modName)', null);
		#end

		try
		{
			buildOptions(options);
		}
		catch (e:Dynamic)
		{
			var errorTitle = 'Mod name: ' + folder;
			var errorMsg = 'An error occurred: $e';
			#if windows
			lime.app.Application.current.window.alert(errorMsg, errorTitle);
			#end
			trace('$errorTitle - $errorMsg');

			// 注意：这里**不能**直接 close() —— 构造阶段 _parentState 还没挂上，
			// FlxSubState.close() 是空操作。真正的退出在 create() 里做。
			_crashed = true;
		}
	}

	// =========================================================
	// 生命周期
	// =========================================================
	override function create():Void
	{
		if (_crashed)
		{
			// settings.json 没解析成功：别建面板（否则会先闪一下空面板再关）。
			// 这里 _parentState 已经挂好了（resetSubState 里先赋值再调 create），
			// 所以 close() 这次是真的生效。
			close();
			return;
		}

		super.create();
	}

	override function update(elapsed:Float)
	{
		// 键位控件正在等按键 → 面板自己的键鼠操作全部挂起，
		// 否则按方向键会同时滚动列表、按回车会顺手触发别的选项、按 ESC 会把整个界面关掉
		inputModal = (KeybindButton.capturing != null);

		super.update(elapsed);
	}

	override public function close():Void
	{
		persist();
		super.close();
	}

	override function destroy():Void
	{
		// 兜底：万一不是走 close() 退出（比如宿主界面被直接切走），也别把改动丢了
		persist();
		super.destroy();
	}

	/** 把设置写回存档，只写一次 */
	function persist():Void
	{
		if (_persisted || _crashed) return;
		_persisted = true;

		FlxG.save.data.modSettings.set(folder, save);
		FlxG.save.flush();
	}

	// =========================================================
	// Charm 声明
	// =========================================================
	override public function buildCharms():Array<CharmEntry>
	{
		// settings.json 里没有分组信息，所以整页就一组
		if (builtOptions.length == 0) return [];

		return [
			{
				id: 'mod_settings',
				title: 'Settings',
				description: getPageDescription(),
				options: builtOptions
			}
		];
	}

	/** 面板顶部的标题 = mod 名字 */
	override public function getPageTitle():String
		return modName;

	override public function getPageDescription():String
	{
		if (builtOptions.length == 0)
			return Language.getPhrase('mod_settings_none', 'This mod has no settings to show');

		return Language.getPhrase('mod_settings_desc', 'Settings provided by this mod');
	}

	// =========================================================
	// 键盘：键位选项要特殊处理
	// =========================================================
	/** 回车：选中键位选项时 = 开始等按键 */
	override public function activateSelected():Void
	{
		var opt:Option = selectedOption();

		if (opt != null && opt.type == KEYBIND)
		{
			var w:FlxSpriteGroup = rows[selectedRow].widget;
			if (Std.isOfType(w, KeybindButton))
			{
				cast(w, KeybindButton).startCapture();
				return;
			}
		}

		super.activateSelected();
	}

	/**
	 * RESET：键位选项不能走基类那条路。
	 * Option 给 KEYBIND 的 defaultValue 是空串（它没有"ClientPrefs 默认值"可言），
	 * 真正该恢复的是 settings.json 里写的 keyboard / gamepad。
	 */
	override public function resetSelected():Void
	{
		var opt:Option = selectedOption();

		if (opt != null && opt.type == KEYBIND)
		{
			var d:String = null;
			if (opt.defaultKeys != null)
				d = Controls.instance.controllerMode ? opt.defaultKeys.gamepad : opt.defaultKeys.keyboard;

			opt.setValue((d != null && d.length > 0) ? d : 'NONE');
			opt.change();
			refreshSelectedWidget();
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		super.resetSelected();
	}

	// =========================================================
	// 解析 settings.json
	// =========================================================
	function buildOptions(defs:Array<Dynamic>):Void
	{
		if (defs == null) return;

		for (def in defs)
		{
			// save 是唯一的键，没有它这条设置没法存也没法读
			if (def == null || def.save == null) continue;

			var newOption:Option = new Option(
				def.name != null ? def.name : def.save,
				def.description != null ? def.description : 'No description provided.',
				def.save,
				convertType(def.type),
				def.options,
				def.translation_key
			);

			switch (newOption.type)
			{
				case KEYBIND:
					// 键位存的是 {keyboard: 'A', gamepad: 'NONE'} 这种结构，
					// 不是单一值，所以 get/set 都得自己接管
					var keyboardStr:String = (def.keyboard != null) ? def.keyboard : 'NONE';
					var gamepadStr:String = (def.gamepad != null) ? def.gamepad : 'NONE';

					newOption.defaultKeys.keyboard = keyboardStr;
					newOption.defaultKeys.gamepad = gamepadStr;

					if (save.get(def.save) == null)
					{
						newOption.keys.keyboard = keyboardStr;
						newOption.keys.gamepad = gamepadStr;
						save.set(def.save, newOption.keys);
					}

					@:privateAccess
					{
						newOption.getValue = function()
						{
							var data:Dynamic = save.get(newOption.variable);
							if (data == null) return 'NONE';
							return !Controls.instance.controllerMode ? data.keyboard : data.gamepad;
						};
						newOption.setValue = function(value:Dynamic)
						{
							var data:Dynamic = save.get(newOption.variable);
							if (data == null) data = {keyboard: 'NONE', gamepad: 'NONE'};

							if (!Controls.instance.controllerMode) data.keyboard = value;
							else data.gamepad = value;
							save.set(newOption.variable, data);
						};
					}

				default:
					if (def.value != null) newOption.defaultValue = def.value;

					@:privateAccess
					{
						newOption.getValue = function() return save.get(newOption.variable);
						newOption.setValue = function(value:Dynamic) save.set(newOption.variable, value);
					}
			}

			if (newOption.type != KEYBIND)
			{
				if (def.format != null) newOption.displayFormat = def.format;
				if (def.min != null) newOption.minValue = def.min;
				if (def.max != null) newOption.maxValue = def.max;
				if (def.step != null) newOption.changeValue = def.step;
				if (def.scroll != null) newOption.scrollSpeed = def.scroll;
				if (def.decimals != null) newOption.decimals = def.decimals;

				var myValue:Dynamic = null;
				if (save.get(def.save) != null)
				{
					myValue = save.get(def.save);
					newOption.setValue(myValue);
				}
				else
				{
					myValue = newOption.getValue();
					if (myValue == null) myValue = newOption.defaultValue;
				}

				if (newOption.type == STRING && newOption.options != null)
				{
					var num:Int = newOption.options.indexOf(Std.string(myValue));
					if (num > -1) newOption.curOption = num;
				}

				save.set(def.save, myValue);
			}

			builtOptions.push(newOption);
		}
	}

	private function convertType(str:String):OptionType
	{
		// 没写 type 就当开关处理（原来会在这里抛异常，把整页设置一起带崩）
		if (str == null) return BOOL;

		switch (str.toLowerCase().trim())
		{
			case 'bool':
				return BOOL;
			case 'int', 'integer':
				return INT;
			case 'float', 'fl':
				return FLOAT;
			case 'percent':
				return PERCENT;
			case 'string', 'str':
				return STRING;
			case 'keybind', 'key':
				return KEYBIND;
		}

		FlxG.log.error("Could not find option type: " + str);
		return BOOL;
	}
}
