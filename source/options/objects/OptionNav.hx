package options.objects;

import options.Option;
import options.Option.OptionType;

/**
 * 键盘操作 Option 的共用逻辑（上下移动选中行之后的"改值 / 激活 / 复位"），
 * Win10 设置页与 Win8 Charm 边栏共用。
 *
 * 约定：
 *   - 三个入口都会自己播交互音效：改值 = scrollMenu 0.4，复位 = cancelMenu 0.4，
 *     ACTION 执行不发声。
 *   - `widget` 传当前行对应的控件，用于改完之后刷新显示。传 null 也不会崩。
 *   - 控件本体是鼠标驱动的，键盘直接改了 `Option` 的值之后**必须**调
 *     `OptionWidgetFactory.refreshValue()`，否则界面还显示旧值。
 *
 * ⚠️ `Win8CharmSettings` 仍是自己那份实现（没有改成委托，避免动正在工作的 Win8 路径），
 *   两处逻辑必须保持一致，改这里时记得同步那边。
 */
class OptionNav
{
	/** 交互音效音量，和 Win8CharmSettings 一致 */
	inline static var MOVE_VOLUME:Float = 0.4;
	inline static var RESET_VOLUME:Float = 0.4;

	/**
	 * 按方向调整值。
	 * @param dir -1 往左 / +1 往右
	 * @return 是否真的动了值（ACTION / KEYBIND 返回 false）
	 */
	public static function adjust(opt:Option, dir:Int, ?widget:FlxSpriteGroup):Bool
	{
		if (opt == null) return false;

		switch (opt.type)
		{
			case BOOL:
				opt.setValue(!(opt.getValue() == true));

			case INT, FLOAT, PERCENT:
				var step:Float = Std.parseFloat(Std.string(opt.changeValue));
				if (Math.isNaN(step) || step == 0) step = 1;

				var v:Float = cast opt.getValue();
				v += dir * step;

				var lo:Dynamic = opt.minValue;
				var hi:Dynamic = opt.maxValue;
				if (lo != null && v < lo) v = lo;
				if (hi != null && v > hi) v = hi;

				opt.setValue(opt.type == INT ? Math.round(v) : FlxMath.roundDecimal(v, opt.decimals));

			case STRING:
				cycleString(opt, dir);

			case COLOR:
				cycleColor(opt, dir);

			case ACTION, KEYBIND:
				return false;
		}

		opt.change();
		opt.saveCurrentValue();
		OptionWidgetFactory.refreshValue(widget);
		FlxG.sound.play(Paths.sound('scrollMenu'), MOVE_VOLUME);
		return true;
	}

	/**
	 * 回车激活：ACTION 直接执行、BOOL 切换、其它类型等同往右调整一次。
	 * @return 是否真的改了值（ACTION 返回 false，但它已经执行了动作）
	 */
	public static function activate(opt:Option, ?widget:FlxSpriteGroup):Bool
	{
		if (opt == null) return false;

		switch (opt.type)
		{
			case ACTION:
				if (opt.action != null) opt.action();
				return false;

			case BOOL:
				opt.setValue(!(opt.getValue() == true));

			case INT, FLOAT, PERCENT, STRING, COLOR:
				return adjust(opt, 1, widget);

			case KEYBIND:
				return false;
		}

		opt.change();
		opt.saveCurrentValue();
		OptionWidgetFactory.refreshValue(widget);
		FlxG.sound.play(Paths.sound('scrollMenu'), MOVE_VOLUME);
		return true;
	}

	/** 复位成默认值（对应 ClientPrefs 的 defaultData） */
	public static function reset(opt:Option, ?widget:FlxSpriteGroup):Bool
	{
		if (opt == null) return false;

		opt.setValue(opt.defaultValue);
		if (opt.type == STRING && opt.options != null)
		{
			var idx:Int = opt.options.indexOf(Std.string(opt.getValue()));
			opt.curOption = idx < 0 ? 0 : idx;
		}

		opt.change();
		opt.saveCurrentValue();
		OptionWidgetFactory.refreshValue(widget);
		FlxG.sound.play(Paths.sound('cancelMenu'), RESET_VOLUME);
		return true;
	}

	/** STRING：在 options 里循环 */
	public static function cycleString(opt:Option, dir:Int):Void
	{
		if (opt.options == null || opt.options.length == 0) return;

		var idx:Int = opt.options.indexOf(Std.string(opt.getValue()));
		if (idx < 0) idx = opt.curOption;
		idx = FlxMath.wrap(idx + dir, 0, opt.options.length - 1);

		opt.curOption = idx;
		opt.setValue(opt.options[idx]);
	}

	/** COLOR：在 COLOR_PALETTE 里循环 */
	public static function cycleColor(opt:Option, dir:Int):Void
	{
		var pal:Array<Int> = Option.COLOR_PALETTE;
		var idx:Int = pal.indexOf(cast opt.getValue());
		if (idx < 0) idx = opt.curOption;
		idx = FlxMath.wrap(idx + dir, 0, pal.length - 1);

		opt.curOption = idx;
		opt.setValue(pal[idx]);
	}
}
