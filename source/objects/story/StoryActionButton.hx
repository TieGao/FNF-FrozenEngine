package objects.story;

import shapeEx.SlantQuad;

/**
 * StoryMode 右下角的斜切功能块（纯文字版）。
 *
 * 构成：白色描边（可选）+ 斜切四边形底（纯白 + color 染色）+ 居中文字，无图标。
 * 交互：**松手才触发**，中途松开或移出一律取消。
 *
 * 接缝：三块是边对边拼的，每块往四周各胀 SEAM_OVERLAP(1px)，两块之间就是 2px 重叠。
 * 描边垫在底色**后面**并再外扩 borderWidth，所以接缝处只看得见一条白线，
 * 不会出现"两块各自 2px → 4px 双线"，也不会因为抗锯齿露缝。
 *
 * ⚠ 命中坐标坑：FlxSpriteGroup.preAdd() 会把组的 x/y **加进成员坐标**
 * （`sprite.x += x`），所以 bg.x / bg.y 已经是绝对值，不是相对组的局部坐标。
 * 这里必须用 `px - bg.x`，不能再减一次组 x（之前就是这么错的，命中区整体左移，
 * 按钮永远点不到）。
 */
class StoryActionButton extends FlxSpriteGroup
{
	public static inline var COLOR_NORMAL:FlxColor = 0xE6141414;
	public static inline var COLOR_HOVER:FlxColor = 0xE63C3C3C;
	public static inline var COLOR_PRESS:FlxColor = 0xFFF9CF51;
	public static inline var COLOR_LABEL:FlxColor = 0xFFF2F2F2;
	public static inline var COLOR_LABEL_PRESS:FlxColor = 0xFF101010;
	public static inline var COLOR_BORDER:FlxColor = 0xFFFFFFFF;

	/** 每块往四周外胀这么多，两块拼起来正好 2px 重叠 */
	public static inline var SEAM_OVERLAP:Float = 1;

	public var bg:SlantQuad;
	public var outline:SlantQuad;
	public var label:FlxText;
	public var onClick:Void->Void = null;

	public var hovered(default, null):Bool = false;
	public var pressing(default, null):Bool = false;

	public var enabled(default, set):Bool = true;

	public function new(X:Float, Y:Float, width:Float, height:Float, skew:Float, text:String, ?fontSize:Int = 20,
			?onClick:Void->Void, ?borderWidth:Float = 0, ?borderColor:FlxColor = COLOR_BORDER)
	{
		super(X, Y);

		this.onClick = onClick;

		var grow:Float = SEAM_OVERLAP;

		if (borderWidth > 0)
		{
			// 斜边要按"垂直方向 2px"折算成水平外扩：水平量 = b / cosθ，cosθ = height / 斜边长度。
			// 直接按 x 外扩 b 的话，斜边会变成 b 的 1/cosθ 倍（约 1.06 倍），上下边和斜边粗细不一致。
			var slant:Float = Math.sqrt(skew * skew + height * height);
			var ox:Float = grow + borderWidth * (slant / height);
			outline = new SlantQuad(-ox, -grow - borderWidth, width + ox * 2, height + (grow + borderWidth) * 2,
				skew, borderColor, 1);
			add(outline);
		}

		bg = new SlantQuad(-grow, -grow, width + grow * 2, height + grow * 2, skew, COLOR_NORMAL, 1);
		add(bg);

		label = new FlxText(0, 0, width, text, fontSize);
		label.setFormat(Paths.font('vcr.ttf'), fontSize, COLOR_LABEL, CENTER);
		label.antialiasing = ClientPrefs.data.antialiasing;
		label.y = (height - label.height) * 0.5;
		add(label);
	}

	function set_enabled(value:Bool):Bool
	{
		enabled = value;
		if (!value)
		{
			hovered = false;
			pressing = false;
			FlxTween.cancelTweensOf(bg);
			bg.color = COLOR_NORMAL;
			label.color = COLOR_LABEL;
		}
		alpha = value ? 1 : 0.4;
		return enabled;
	}

	/** 屏幕坐标命中（平行四边形，不是包围盒） */
	public function containsPoint(px:Float, py:Float):Bool
	{
		if (!enabled) return false;
		// bg.x / bg.y 已经被 preAdd 变成绝对值，别再减组的 x
		return bg.containsLocal(px - bg.x, py - bg.y);
	}

	/**
	 * @param isHover 由 StoryMenuState 统一裁决（多个块重叠时只有画在最上层的那块算 hover）
	 */
	public function updateButton(isHover:Bool, acceptInput:Bool):Void
	{
		if (!enabled || !acceptInput)
		{
			if (hovered || pressing)
			{
				hovered = false;
				pressing = false;
				refreshVisual();
			}
			return;
		}

		var mouse = FlxG.mouse;

		if (isHover != hovered)
		{
			hovered = isHover;
			if (!pressing) refreshVisual();
		}

		if (hovered && mouse.justPressed)
		{
			pressing = true;
			refreshVisual();
		}

		if (pressing)
		{
			if (mouse.justReleased)
			{
				var fire:Bool = hovered;
				pressing = false;
				refreshVisual();
				if (fire && onClick != null) onClick();
			}
			else if (!mouse.pressed)
			{
				pressing = false;
				refreshVisual();
			}
		}
	}

	public function refreshVisual():Void
	{
		FlxTween.cancelTweensOf(bg);

		if (pressing)
		{
			bg.color = COLOR_PRESS;
			label.color = COLOR_LABEL_PRESS;
		}
		else
		{
			var target:FlxColor = hovered ? COLOR_HOVER : COLOR_NORMAL;
			FlxTween.color(bg, 0.1, bg.color, target, {ease: FlxEase.quadOut});
			label.color = COLOR_LABEL;
		}
	}
}
