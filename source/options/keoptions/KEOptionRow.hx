package options.keoptions;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.UITheme;
import backend.UIControlTheme;
import shapeEx.Rect;
import options.objects.backend.StringSelect;

/**
 * KEOptionsMenu 的一行：选项名在左（同款框）、值/控件在右。
 *
 * 刻意不继承 FlxSpriteGroup —— flixel 6.2.0 组级 clipToWorldBounds 必崩（animation=null），
 * 裁剪要逐叶子做。成员通过 attachTo 挂进宿主绘制组（顺序即 z 序），行只持有引用与几何。
 *
 * 布局（BIOS 式统一）：
 * - 名字：左侧统一标签列框（与 StringSelect 主条同款配色），文本限宽截断
 * - 值：string/color/bool → StringSelect 下拉；int/float → 数值框（键入缓冲显示在内）；
 *   分组 → 值框内居中 ">"；action/confirm/back 无值；title → 居中标题、无框、不可选
 */
class KEOptionRow
{
	public var option:KEOption;
	public var index:Int = 0;

	public var nameText:FlxText;
	public var valueText:FlxText;      // 非 widget 行的右侧文本；widget 行为 null
	public var nameBox:Rect;           // 名字标签框（与下拉框同款样式）；title 行为 null
	public var valueBox:Rect;          // 数值输入框 / 分组 ">" 框（同款样式）；其余为 null
	public var widget:StringSelect;    // string/color/bool 行的下拉条；其余为 null
	public var indicator:Rect;         // 左侧选中指示条
	public var hitbox:FlxObject;       // 整行命中区（滚出视口时不响应）

	/** 参与裁剪/显隐的叶子（widget 自己裁自己的叶子） */
	var leaves:Array<FlxSprite> = [];

	public var rowVisible:Bool = true;
	public var selected:Bool = false;

	/** string/color/bool 行的下拉条宽度（构造参数存一份，对齐用） */
	var widgetW:Float;

	public function new(option:KEOption, index:Int, widgetW:Float, accent:FlxColor, overlay:FlxSpriteGroup)
	{
		this.option = option;
		this.index = index;
		this.widgetW = widgetW;

		var rowH:Float = KEOptionsMenu.ROW_H;
		var boxColor:FlxColor = UIControlTheme.isWin8() ? UIControlTheme.face() : UITheme.control;

		// 选中指示条：竖条从中心纵向展开（scaleY 0→1）
		indicator = new Rect(KEOptionsMenu.OPTION_LEFT_MARGIN - 16, 0, 4, 28, 2, 2, accent, 0);
		indicator.antialiasing = ClientPrefs.data.antialiasing;
		indicator.scrollFactor.set();
		indicator.origin.set(2, 14);
		indicator.scale.y = 0;
		leaves.push(indicator);

		nameText = new FlxText(KEOptionsMenu.OPTION_LEFT_MARGIN, 0, 0, "", 28);
		nameText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		nameText.borderSize = 2;
		nameText.borderQuality = 1;
		nameText.scrollFactor.set();

		if (option.type == "title")
		{
			// 子视图顶部标题行：居中、限宽、无框（不可选中，由菜单的导航守卫保证）
			nameText.fieldWidth = KEOptionsMenu.SCREEN_WIDTH - KEOptionsMenu.OPTION_LEFT_MARGIN * 2;
			nameText.alignment = CENTER;
		}
		else
		{
			// 名字标签框：统一标签列（与下拉条同款配色），文本框内左对齐、超长截断
			var boxW:Float = valueColLeftX() - KEOptionsMenu.OPTION_LEFT_MARGIN - 8;
			nameBox = new Rect(KEOptionsMenu.OPTION_LEFT_MARGIN, 0, boxW, 36,
				UIControlTheme.radius(4), UIControlTheme.radius(4), boxColor, 1);
			nameBox.antialiasing = ClientPrefs.data.antialiasing;
			nameBox.scrollFactor.set();
			leaves.push(nameBox);

			nameText.x = KEOptionsMenu.OPTION_LEFT_MARGIN + 12;
			nameText.fieldWidth = Std.int(boxW) - 24;
			nameText.wordWrap = false;
		}
		leaves.push(nameText);

		if (isWidgetRow(option))
		{
			// win10 下拉条：BIOS 式统一值列——右缘 0.85×宽，宽 0.2×宽
			widget = new StringSelect(valueColLeftX(), 0, widgetW, 32, option, overlay);
			widget.scrollFactor.set();
		}
		else
		{
			var isNumeric:Bool = (option.type == "int" || option.type == "float");
			var isGroup:Bool = option.hasSubMenu;

			// 数值行 = 输入框（键入缓冲显示在内）；分组行 = 值框内居中 ">"
			if (isNumeric || isGroup)
			{
				valueBox = new Rect(valueColLeftX(), 0, widgetW, 32,
					UIControlTheme.radius(4), UIControlTheme.radius(4), boxColor, 1);
				valueBox.antialiasing = ClientPrefs.data.antialiasing;
				valueBox.scrollFactor.set();
				leaves.push(valueBox);
			}

			valueText = new FlxText(0, 0, 0, "", (isNumeric || isGroup) ? 20 : 32);
			valueText.setFormat(Paths.font("vcr.ttf"), (isNumeric || isGroup) ? 20 : 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			valueText.borderSize = 2;
			valueText.borderQuality = 1;
			valueText.scrollFactor.set();
			leaves.push(valueText);
		}

		hitbox = new FlxObject(KEOptionsMenu.OPTION_LEFT_MARGIN - 10, 0,
			KEOptionsMenu.SCREEN_WIDTH - (KEOptionsMenu.OPTION_LEFT_MARGIN - 10) * 2, rowH);
		hitbox.scrollFactor.set();
	}

	/** 按 z 序挂进宿主绘制组（指示条 → 名字框 → 名字 → 值框 → 值文本 → 下拉条 → 命中区） */
	public function attachTo(group:FlxTypedGroup<FlxBasic>):Void
	{
		for (leaf in leaves)
			group.add(leaf);
		if (widget != null)
			group.add(widget);
		group.add(hitbox);
	}

	/** 该行右侧是否挂 StringSelect 下拉条（string/color/bool 全部下拉化） */
	public static function isWidgetRow(option:KEOption):Bool
	{
		return (option.type == "string" && option.options.length > 0)
			|| option.type == "color"
			|| option.type == "bool";
	}

	/** 值列右缘 = 0.85×宽（右侧留白 0.15×宽） */
	static function valueColRightX():Float
	{
		return KEOptionsMenu.SCREEN_WIDTH * 0.85;
	}

	/** 值列左缘 = 右缘 - 0.2×宽（下拉/输入框统一 0.2×宽） */
	static function valueColLeftX():Float
	{
		return valueColRightX() - KEOptionsMenu.SCREEN_WIDTH * 0.20;
	}

	/** 行顶部 y（内容坐标）：所有叶子按各自高度垂直居中 */
	public function setY(rowY:Float):Void
	{
		var rowH:Float = KEOptionsMenu.ROW_H;
		hitbox.y = rowY;
		for (leaf in leaves)
			leaf.y = rowY + (rowH - leaf.height) * 0.5;
		if (widget != null)
			widget.y = rowY + (rowH - 32) * 0.5;
	}

	/** 值文本位置：数值=框内左对齐（留 10px 内距）；分组 ">"=框内居中；无框则右对齐到值列右缘 */
	function alignValueText():Void
	{
		if (valueText == null) return;
		if (valueBox != null)
		{
			if (option.hasSubMenu)
				valueText.x = valueBox.x + (valueBox.width - valueText.width) * 0.5;
			else
				valueText.x = valueBox.x + 10;
		}
		else
			valueText.x = valueColRightX() - valueText.width;
	}

	public function refreshTexts(valueProvider:KEOption->String):Void
	{
		nameText.text = option.getDisplayName();
		if (widget != null)
		{
			widget.refreshValue();
		}
		else if (valueText != null)
		{
			valueText.text = valueProvider(option);
			alignValueText();
		}
	}

	/** 数值直接输入的预览文本（不落盘，仅改显示） */
	public function setPreviewValue(text:String):Void
	{
		if (valueText == null) return;
		valueText.text = text;
		alignValueText();
	}

	public function setSelected(v:Bool):Void
	{
		selected = v;
		// 指示条纵向展开动画：从中心 scaleY 0→1（原点在 ctor 里设为中心）
		if (indicator != null)
		{
			FlxTween.cancelTweensOf(indicator.scale);
			FlxTween.cancelTweensOf(indicator);
			FlxTween.tween(indicator.scale, {y: v ? 1.0 : 0.0}, 0.16, {ease: FlxEase.quadOut});
			FlxTween.tween(indicator, {alpha: v ? 1.0 : 0.0}, 0.16, {ease: FlxEase.quadOut});
		}
		nameText.alpha = v ? 1.0 : KEOptionsMenu.OPTION_ALPHA;
		if (valueText != null)
			valueText.alpha = v ? 1.0 : KEOptionsMenu.OPTION_ALPHA;
	}

	/** 三态裁剪之一：整行完全在视口内，清掉全部裁剪 */
	public function clearClip():Void
	{
		for (leaf in leaves)
			leaf.clipRect = null;
		if (widget != null) widget.clearClipRect();
	}

	/** 三态裁剪之二：露出一截，逐叶子按视图坐标裁（widget 的弹层不受影响） */
	public function applyClip(l:Float, t:Float, r:Float, b:Float, cam:flixel.FlxCamera):Void
	{
		for (leaf in leaves)
			leaf.clipToViewBounds(l, t, r, b, cam);
		if (widget != null) widget.applyClipRect(l, t, r, b, cam);
	}

	/** 三态裁剪之三：整行滚出视口，隐藏（含命中区失效） */
	public function setVisible(v:Bool):Void
	{
		rowVisible = v;
		for (leaf in leaves)
			leaf.visible = v;
		if (widget != null) widget.visible = v;
		hitbox.visible = v;
	}

	public function destroyAll():Void
	{
		for (leaf in leaves)
			leaf.destroy();
		leaves = [];
		if (widget != null)
		{
			widget.destroy();
			widget = null;
		}
		if (hitbox != null)
		{
			hitbox.destroy();
			hitbox = null;
		}
	}
}
