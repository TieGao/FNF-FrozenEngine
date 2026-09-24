package options.psychoptions;

import options.Option;
import options.Option.OptionType;
import options.Win8CharmSettings;
import options.Win8CharmSettings.CharmEntry;

/**
 * Gameplay Changers —— Win8 风格设置面板
 *
 * 继承 options.Win8CharmSettings 的单页设置页：
 *   - Gameplay Changers 分组：选项走 options/objects 下那套控件
 *     （NumButton / StringSelect / BoolButton / OptionButton）
 *   - Reset 分组：一个 Reset 动作按钮
 *
 * 对外接口：类名、无参构造、getOptionByName()、同模块的 GameplayOption。
 */
class GameplayChangersSubstate extends Win8CharmSettings
{
	var optionsArray:Array<GameplayOption> = [];

	public function new()
	{
		optionsArray = [];
		super();
	}

	// =========================================================
	// Charm 声明
	// =========================================================
	override public function buildCharms():Array<CharmEntry>
	{
		buildOptions();

		var opts:Array<Option> = [];
		for (o in optionsArray) opts.push(o);

		var resetOpt:Option = new Option('Reset Gameplay Changers',
			'Restore every gameplay changer to its default value',
			'reset_gameplay', ACTION);
		resetOpt.actionLabel = Language.getPhrase('options.action.reset', 'Reset');
		resetOpt.action = resetAll;

		return [
			{
				id: 'gameplay',
				title: 'Gameplay Changers',
				description: 'Scroll speed, health multipliers, instakill, botplay and more',
				options: opts
			},
			{
				id: 'reset',
				title: 'Reset',
				description: 'Put every gameplay changer back to its default value',
				options: [resetOpt]
			}
		];
	}

	// =========================================================
	// 单页模式的总标题
	// =========================================================
	override public function getPageTitle():String
		return Language.getPhrase('charm_gameplay', 'Gameplay Changers');

	override public function getPageDescription():String
		return 'Scroll speed, health multipliers, instakill, botplay and more';

	// =========================================================
	// 选项表（与原版一致）
	// =========================================================
	function buildOptions():Void
	{
		optionsArray = [];

		var scrollType:GameplayOption = new GameplayOption('Scroll Type', 'scrolltype', STRING, 'multiplicative',
			["multiplicative", "constant"],
			'How the scroll speed is interpreted');
		scrollType.onChange = function() {
			applyScrollType();
			requestPanelRebuild();
		};
		optionsArray.push(scrollType);

		var speed:GameplayOption = new GameplayOption('Scroll Speed', 'scrollspeed', FLOAT, 1, null,
			'How fast the notes scroll');
		speed.scrollSpeed = 2.0;
		speed.minValue = 0.35;
		// maxValue / displayFormat 会被 applyScrollType() 按 Scroll Type 覆盖，这里先给死值兜底：
		// 它没跑到的话 maxValue 会是 null，而 NumButton 对 null 的兜底是 1，滑块直接废掉。
		speed.maxValue = 3;
		speed.displayFormat = '%vX';
		speed.changeValue = 0.05;
		speed.decimals = 2;
		optionsArray.push(speed);

		#if FLX_PITCH
		var rate:GameplayOption = new GameplayOption('Playback Rate', 'songspeed', FLOAT, 1, null,
			'Speed multiplier of the whole song');
		rate.scrollSpeed = 1;
		rate.minValue = 0.5;
		rate.maxValue = 3.0;
		rate.changeValue = 0.05;
		rate.displayFormat = '%vX';
		rate.decimals = 2;
		optionsArray.push(rate);
		#end

		var healthGain:GameplayOption = new GameplayOption('Health Gain Multiplier', 'healthgain', FLOAT, 1, null,
			'How much health you gain when hitting a note');
		healthGain.scrollSpeed = 2.5;
		healthGain.minValue = 0;
		healthGain.maxValue = 5;
		healthGain.changeValue = 0.1;
		healthGain.displayFormat = '%vX';
		optionsArray.push(healthGain);

		var healthLoss:GameplayOption = new GameplayOption('Health Loss Multiplier', 'healthloss', FLOAT, 1, null,
			'How much health you lose when missing a note');
		healthLoss.scrollSpeed = 2.5;
		healthLoss.minValue = 0.5;
		healthLoss.maxValue = 5;
		healthLoss.changeValue = 0.1;
		healthLoss.displayFormat = '%vX';
		optionsArray.push(healthLoss);

		optionsArray.push(new GameplayOption('Instakill on Miss', 'instakill', BOOL, false, null,
			'Missing a single note kills you'));
		optionsArray.push(new GameplayOption('Practice Mode', 'practice', BOOL, false, null,
			'Practice mode: no death, you can retry sections'));
		optionsArray.push(new GameplayOption('Botplay', 'botplay', BOOL, false, null,
			'Let the engine play the chart for you'));
		optionsArray.push(new GameplayOption('Player Mode', 'opponentplay', STRING, 'player',
			['player', 'opponent', 'coop', 'coop_split'],
			'Which side the player controls'));
		optionsArray.push(new GameplayOption('Mirror Notes', 'mirrornotes', BOOL, false, null,
			'Flip the chart horizontally'));

		// Scroll Type 会影响 Scroll Speed 的取值范围/显示格式
		applyScrollType();
	}

	public function getOptionByName(name:String):GameplayOption
	{
		for (i in optionsArray)
		{
			var opt:GameplayOption = i;
			// name 是译文（中文下 'Scroll Speed' 会变成 '音符流速'），必须连原始名一起比，
			// 否则按英文名查找在非英语语言下全部落空。
			if (opt.name == name || opt.rawName == name)
				return opt;
		}
		return null;
	}

	/**
	 * 按 Scroll Type 调整 Scroll Speed：
	 * constant（cmod）最大 6，multiplicative（amod）最大 3 且带 X 后缀。
	 */
	function applyScrollType():Void
	{
		var st:GameplayOption = getOptionByName('Scroll Type');
		var sp:GameplayOption = getOptionByName('Scroll Speed');
		if (sp == null) return;

		var constant:Bool = (st != null && st.getValue() == 'constant');

		sp.displayFormat = constant ? '%v' : '%vX';
		sp.maxValue = constant ? 6 : 3;
		sp.valueFormatter = makeFormatter(sp);

		if (!constant && cast(sp.getValue(), Float) > 3)
			sp.setValue(3);
	}

	/** 用 displayFormat 生成数值文本（NumButton 支持 valueFormatter） */
	function makeFormatter(opt:Option):Float->String
	{
		return function(v:Float):String
		{
			var decimals:Int = opt.decimals;
			var s:String;

			if (decimals <= 0)
			{
				s = Std.string(Std.int(v));
			}
			else
			{
				s = Std.string(FlxMath.roundDecimal(v, decimals));
				if (s.indexOf('.') < 0) s += '.';
				var parts:Array<String> = s.split('.');
				while (parts[1].length < decimals) parts[1] += '0';
				s = parts[0] + '.' + parts[1].substr(0, decimals);
			}

			return opt.displayFormat.replace('%v', s);
		};
	}

	/** 把全部 gameplay changer 恢复默认值 */
	function resetAll():Void
	{
		for (opt in optionsArray)
		{
			opt.setValue(opt.defaultValue);
			if (opt.type == STRING && opt.options != null)
			{
				var idx:Int = opt.options.indexOf(Std.string(opt.getValue()));
				opt.curOption = idx < 0 ? 0 : idx;
			}
			opt.change();
		}

		applyScrollType();
		ClientPrefs.saveSettings();

		// 值变了，控件要按新值重建（顺便刷掉正在显示的下拉）
		requestPanelRebuild();
	}

	override public function closeCharmBar():Void
	{
		ClientPrefs.saveSettings();
		close();
	}
}

/**
 * 写进 ClientPrefs.data.gameplaySettings 的选项（不是普通存档字段）。
 * 现在继承 options.Option，这样就能直接喂给 objects 下的那套控件。
 */
class GameplayOption extends Option
{
	public function new(name:String, variable:String, type:OptionType, defaultValue:Dynamic = 'null variable value',
		?options:Array<String> = null, ?description:String = null)
	{
		super(name, description != null ? description : '', variable, type, options);

		if (defaultValue == 'null variable value')
		{
			switch (type)
			{
				case BOOL:
					defaultValue = false;
				case INT, FLOAT:
					defaultValue = 0;
				case PERCENT:
					defaultValue = 1;
				case STRING:
					defaultValue = '';
					if (options != null && options.length > 0)
						defaultValue = options[0];
				default:
			}
		}

		this.defaultValue = defaultValue;
		if (getValue() == null) setValue(defaultValue);

		switch (type)
		{
			case STRING:
				if (options != null)
				{
					var num:Int = options.indexOf(Std.string(getValue()));
					if (num > -1) curOption = num;
				}
			case PERCENT:
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
			default:
		}
	}

	override public function getValue():Dynamic
		return ClientPrefs.data.gameplaySettings.get(variable);

	override public function setValue(value:Dynamic):Void
	{
		ClientPrefs.data.gameplaySettings.set(variable, value);
	}
}
