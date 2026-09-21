package options.objects;

import options.Option;
import options.objects.backend.BoolButton;
import options.objects.backend.NumButton;
import options.objects.backend.StringSelect;
import options.objects.backend.ColorSelect;
import options.objects.backend.OptionButton;
import options.objects.backend.KeybindButton;

/**
 * 按 Option 类型创建控件（"按键元素"工厂），Win10 设置页与 Win8 Charm 边栏共用，
 * 保证两边的控件行为 / 风格完全一致。
 *
 * 控件风格（Win10 / Win8）由 backend.UIControlTheme 决定，控件自己在构造时读取，
 * 这里不需要传参。
 */
class OptionWidgetFactory
{
	/**
	 * @param opt        要绑定的选项
	 * @param overlay    下拉/调色板弹层的挂载层（不传则挂在控件自己身上）
	 * @param widgetW    数值条/下拉条的宽度
	 */
	public static function create(opt:Option, ?overlay:FlxSpriteGroup, widgetW:Float = 240):FlxSpriteGroup
	{
		if (opt == null) return null;

		switch (opt.type)
		{
			case ACTION:
				return createActionButton(opt, 100, 35);

			case BOOL:
				return new BoolButton(0, 0, 56, 24, opt);

			case INT, FLOAT, PERCENT:
				return new NumButton(0, 0, widgetW, 32, opt);

			case STRING:
				return new StringSelect(0, 0, widgetW, 32, opt, overlay);

			case COLOR:
				return new ColorSelect(0, 0, widgetW, 32, opt, overlay);

			case KEYBIND:
				// 只有 mod 设置会用到键位选项（见 options.ModSettingsSubState）。
				// 注意捕获期间要挂起宿主界面的键鼠处理，见 KeybindButton 的类注释。
				return new KeybindButton(0, 0, widgetW, 32, opt);
		}
	}

	/**
	 * 造 ACTION 按钮。宽高由调用方给 —— Win10 设置页用工厂默认的小按钮（100×35），
	 * Charm 面板想要更大的按钮就直接调这个。
	 *
	 * isReset 的判定收在这里，免得调用方各写一份。
	 */
	public static function createActionButton(opt:Option, w:Float, h:Float):OptionButton
	{
		var tag:String = opt.variable != null ? opt.variable.toLowerCase() : '';
		var isReset:Bool = (tag.indexOf('reset') >= 0
			|| (opt.actionLabel != null && opt.actionLabel.toLowerCase() == 'reset'));
		return new OptionButton(0, 0, w, h, opt, isReset);
	}

	/**
	 * 让控件重新读取 follow.getValue() 并刷新显示。
	 * 键盘操作（上下左右）直接改了 Option 的值之后必须调一次，否则界面还是旧值。
	 */
	public static function refreshValue(widget:FlxSpriteGroup):Void
	{
		if (widget == null) return;

		if (Std.isOfType(widget, BoolButton))
			cast(widget, BoolButton).updateDisplay();
		else if (Std.isOfType(widget, NumButton))
			cast(widget, NumButton).refreshValue();
		else if (Std.isOfType(widget, StringSelect))
			cast(widget, StringSelect).refreshValue();
		else if (Std.isOfType(widget, ColorSelect))
			cast(widget, ColorSelect).refreshValue();
		else if (Std.isOfType(widget, KeybindButton))
			cast(widget, KeybindButton).refreshValue();
	}

	/**
	 * 键盘选中某一行时，让控件进入/退出"悬停态"高亮。
	 *
	 * Win10 设置页的行不铺整行选中底色，选中时只把标题转强调色 + 让控件亮起来，
	 * 宿主行用它把"你被键盘指着"告诉控件。
	 *
	 * 这里用 Std.isOfType 逐个分发，而不是给控件加公共接口 —— 跟上面的 refreshValue()
	 * 同一套路，是本仓库已经在 cpp 上验证过的写法；接口 + Std.isOfType 的组合本项目没试过。
	 *
	 * ⚠️ 控件内部只会拿它去算**颜色**，绝不能并进 `hover`：`hover` 同时是
	 * OptionButton / StringSelect 的点击门控，并进去就变成"鼠标点哪都触发"。
	 */
	public static function setKeyboardHighlight(widget:FlxSpriteGroup, v:Bool):Void
	{
		if (widget == null) return;

		if (Std.isOfType(widget, OptionButton))
			cast(widget, OptionButton).setKeyboardHighlight(v);
		else if (Std.isOfType(widget, BoolButton))
			cast(widget, BoolButton).setKeyboardHighlight(v);
		else if (Std.isOfType(widget, NumButton))
			cast(widget, NumButton).setKeyboardHighlight(v);
		else if (Std.isOfType(widget, StringSelect))
			cast(widget, StringSelect).setKeyboardHighlight(v);
		else if (Std.isOfType(widget, ColorSelect))
			cast(widget, ColorSelect).setKeyboardHighlight(v);
	}
}
