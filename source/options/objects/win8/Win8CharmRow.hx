package options.objects.win8;

import options.Option;
import options.objects.win10.Win10OptionRow;

/**
 * Charm 面板里的一行。
 *
 * 排版与视觉直接沿用 Win10 的 Win10OptionRow —— 也就是设置页里那套两段式：
 * 标题在上（18px，左对齐），控件在下，行本身不带描述文字。区别只有两点：
 *
 *   1. **收窄**：内边距从 20 收到 14，控件从 y=56 提到 y=46，行高交给调用方
 *      （Win8CharmSettings 用 ROW_H = 88，比 Win10 的 92 紧一点），
 *      好塞进 Charm 的 flyout 面板。
 *   2. 搜索用的右侧子分类标注用不到，直接隐藏。
 *
 * 选中态（整行铺 UITheme.navItemActive 底色 + 标题转强调色）**已经上提到基类**
 * Win10OptionRow，因为它现在也是 Win10 设置页的键盘选中视觉，两边共用一份。
 *
 * 注意：FlxSpriteGroup 的子元素坐标是**绝对**的（add() 时已经加过 group.x/y，
 * 之后 group 移动靠 set_x 把增量传播下来），所以这里调整子元素位置必须带上
 * this.x / this.y，否则会把元素弹回屏幕左上角。
 */
class Win8CharmRow extends Win10OptionRow
{
	/** 收窄后的左右内边距（Win10 是 20） */
	public static inline var PAD_X:Float = 14;
	/** 标题的 y（Win10 是 10） */
	public static inline var TITLE_Y:Float = 9;
	/** 控件的 y（Win10 是 56） */
	public static inline var WIDGET_Y:Float = 46;

	public function new(x:Float, y:Float, w:Float, h:Float, opt:Option, widget:FlxSpriteGroup)
	{
		super(x, y, w, h, opt, widget);

		// 把 Win10 的排版收窄到面板宽度内（记住要带上 group 的偏移）
		if (title != null)
		{
			title.x = this.x + PAD_X;
			title.y = this.y + TITLE_Y;
			title.fieldWidth = w - PAD_X * 2;
		}

		if (widget != null)
		{
			widget.x = this.x + PAD_X;
			widget.y = this.y + WIDGET_Y;
		}

		// 搜索用的右侧子分类标注在 Charm 面板里用不到
		if (subLabel != null) subLabel.visible = false;

		if (bg != null) bg.alpha = 0;
	}
}
