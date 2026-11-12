package states.freeplay;

import shapeEx.SlantQuad;

/**
 * Freeplay 底部工具条的斜切按钮（平行四边形）。
 *
 * 形状复刻 StoryMode 右下角的 StoryActionButton / 难度方块：白色描边的斜切四边形 +
 * 居中文字，**纯白底 + `color` 染色**，所以 hover / press 只改颜色，不会把图形乘暗。
 *
 * 和 PsychUIButton 的区别（也就是"防误触"做在哪）：
 *  1. 按下必须**从本按钮上开始**——从别处按下再拖进来松手不算；
 *  2. 松手时指针必须**仍在本按钮上**才算数，中途拖出去只取消视觉，拖回来仍可生效；
 *  3. 触发后由 ToolBar 上 `inputLock` 锁一小段输入：同一次松手不会被第二块再消费一次，
 *     连点也不会把同一块点两下；
 *  4. 松手事件如果被状态切换吃掉（比如开了子状态），`!mouse.pressed` 那条兜底会把
 *     按下态解掉，不会卡在按下色。
 *
 * ⚠ 命中坐标坑（StoryActionButton 踩过）：FlxSpriteGroup 的 preAdd 会把组的 x/y 加进
 * 成员坐标，所以 bg.x / bg.y 已经是绝对值，`containsPoint` 里**不能再减一次组的 x**。
 */
class ToolBarButton extends FlxSpriteGroup
{
	public static inline var COLOR_NORMAL:FlxColor = 0xFF33333C;
	public static inline var COLOR_HOVER:FlxColor = 0xFF4E4E70;
	public static inline var COLOR_PRESS:FlxColor = 0xFFF9CF51;

	public static inline var COLOR_LABEL:FlxColor = 0xFFDDDDE4;
	public static inline var COLOR_LABEL_HOVER:FlxColor = 0xFFFFFFFF;
	public static inline var COLOR_LABEL_PRESS:FlxColor = 0xFF141414;

	/** 描边是**不透明**的：FlxSprite.color 里的 alpha 不参与渲染，只能整块上色 */
	public static inline var COLOR_OUTLINE:FlxColor = 0xFF5C5C70;
	public static inline var COLOR_OUTLINE_HOVER:FlxColor = 0xFFB4B4D2;

	/** 每块往四周各胀 1px，两块拼起来正好 2px 重叠（同 StoryActionButton.SEAM_OVERLAP） */
	public static inline var SEAM_OVERLAP:Float = 1;

	/** 悬停 / 按下配色的渐变时长，越小越"脆" */
	static inline var FADE_TIME:Float = 0.1;

	public var bg:SlantQuad;
	public var outline:SlantQuad;
	public var label:FlxText;

	public var onClick:Void->Void;

	public var hovered(default, null):Bool = false;
	public var pressing(default, null):Bool = false;

	/** false = 置灰 + 完全不接输入（没有歌的时候 RESET / EDITOR 就是这样） */
	public var enabled(default, set):Bool = true;

	public function new(X:Float, Y:Float, width:Float, height:Float, skew:Float, text:String, ?fontSize:Int = 20,
			?onClick:Void->Void, ?borderWidth:Float = 2)
	{
		super(X, Y);
		scrollFactor.set();

		this.onClick = onClick;

		var grow:Float = SEAM_OVERLAP;

		if (borderWidth > 0 && height > 0)
		{
			// 斜边要按"垂直方向 borderWidth"折算成水平外扩：水平量 = b / cosθ = b * 斜边长度 / 高度。
			// 直接按 x 外扩 b 的话，斜边会比上下边粗 1/cosθ 倍，看着像描边不匀。
			var slant:Float = Math.sqrt(skew * skew + height * height);
			var ox:Float = grow + borderWidth * (slant / height);
			outline = new SlantQuad(-ox, -grow - borderWidth, width + ox * 2, height + (grow + borderWidth) * 2,
				skew, COLOR_OUTLINE, 1);
			add(outline);
		}

		bg = new SlantQuad(-grow, -grow, width + grow * 2, height + grow * 2, skew, COLOR_NORMAL, 1);
		add(bg);

		label = new FlxText(0, 0, width, text, fontSize);
		label.setFormat(Paths.font('vcr.ttf'), fontSize, COLOR_LABEL, CENTER);
		label.antialiasing = ClientPrefs.data.antialiasing;
		// ⚠ 只在构造时摆一次。add() 之后 label.y 已被 preAdd 加成本组的绝对 y，
		// 之后再往里写"相对基准值"会让文字直接飞到屏幕顶部（悬停时就现原形）。
		label.y = (height - label.height) * 0.5;
		add(label);
	}

	/** 屏幕坐标命中：走平行四边形自身判定，不用包围盒（斜角区域不该算命中） */
	public function containsPoint(px:Float, py:Float):Bool
	{
		if (!enabled || bg == null) return false;
		return bg.containsLocal(px - bg.x, py - bg.y);
	}

	/**
	 * 每帧由 ToolBar 统一驱动（只有一处能拿到鼠标状态，避免两个 update 各判一次）。
	 *
	 * @param isHover     由 ToolBar 裁决：接缝那 2px 归画在上层的右块
	 * @param acceptInput 输入锁没到期时为 false —— 只更新悬停视觉，不许进入按下态
	 */
	public function updateButton(isHover:Bool, acceptInput:Bool):Void
	{
		if (!enabled || !exists)
		{
			if (hovered || pressing) cancelInput();
			return;
		}

		var mouse = FlxG.mouse;

		// 锁输入期间悬停照样亮：按钮不能看起来"死了"，只是点不动
		if (isHover != hovered)
		{
			hovered = isHover;
			if (!pressing) refreshVisual();
		}

		// 防误触①：锁定期间强制松开，拖出拖回也不会在解锁后补一次点击
		if (pressing && !acceptInput)
		{
			pressing = false;
			refreshVisual();
		}

		// 防误触②：按下必须从本按钮上开始（从别处按下再拖进来松手不算）
		if (acceptInput && hovered && mouse.justPressed && !pressing)
		{
			pressing = true;
			refreshVisual();
		}

		if (!pressing) return;

		if (mouse.justReleased)
		{
			// 防误触③：松手时指针还得在本按钮上
			var fire:Bool = hovered;
			pressing = false;
			if (fire) fireClick() else refreshVisual();
		}
		else if (!mouse.pressed)
		{
			// 防误触④：松手事件被状态切换吃掉时也要解锁，否则按钮卡在按下色
			pressing = false;
			refreshVisual();
		}
	}

	/** 外部强制清掉交互态（隐藏按钮 / 进出播放器模式时用）。已经是干净状态就别白起 tween */
	public function cancelInput():Void
	{
		if (!hovered && !pressing) return;
		hovered = false;
		pressing = false;
		refreshVisual();
	}

	public function refreshVisual():Void
	{
		if (bg == null) return;

		FlxTween.cancelTweensOf(bg);
		FlxTween.cancelTweensOf(label);

		if (pressing)
		{
			// 按下瞬间就到位，不走渐变 —— 按住期间还在渐变会显得发闷。
			// 位移反馈一律不给：斜切块不能缩放（会错开接缝），文字也不能动（组坐标是绝对值）
			bg.color = COLOR_PRESS;
			label.color = COLOR_LABEL_PRESS;
			setOutlineColor(COLOR_PRESS, 0);
			return;
		}

		var wantBg:FlxColor = COLOR_NORMAL;
		var wantLabel:FlxColor = COLOR_LABEL;
		var wantOutline:FlxColor = COLOR_OUTLINE;

		if (hovered)
		{
			wantBg = COLOR_HOVER;
			wantLabel = COLOR_LABEL_HOVER;
			wantOutline = COLOR_OUTLINE_HOVER;
		}

		FlxTween.color(bg, FADE_TIME, bg.color, wantBg, {ease: FlxEase.quadOut});
		FlxTween.color(label, FADE_TIME, label.color, wantLabel, {ease: FlxEase.quadOut});
		setOutlineColor(wantOutline, FADE_TIME);
	}

	function fireClick():Void
	{
		// 先把按下色"顶住"，再交给 refreshVisual 渐变回 hover/常态 ——
		// 松手生效这一下要看得见落点，不能瞬间跳色
		bg.color = COLOR_PRESS;
		label.color = COLOR_LABEL_PRESS;
		refreshVisual();
		if (onClick != null) onClick();
	}

	function setOutlineColor(color:FlxColor, duration:Float):Void
	{
		if (outline == null) return;
		FlxTween.cancelTweensOf(outline);
		if (duration <= 0) outline.color = color
		else FlxTween.color(outline, duration, outline.color, color, {ease: FlxEase.quadOut});
	}

	function set_enabled(value:Bool):Bool
	{
		// 外面（updateNormalButtons）每帧都会刷成同一个值，没变就别重复清态起 tween
		if (enabled == value) return value;

		enabled = value;
		if (!value)
		{
			hovered = false;
			pressing = false;
			refreshVisual();
		}
		alpha = value ? 1 : 0.4;
		return value;
	}

	override public function destroy():Void
	{
		// 颜色 tween 是按对象引用挂着的，成员销毁了它还活着 —— 先掐掉再交给 super
		if (bg != null) FlxTween.cancelTweensOf(bg);
		if (label != null) FlxTween.cancelTweensOf(label);
		if (outline != null) FlxTween.cancelTweensOf(outline);

		bg = null;
		outline = null;
		label = null;
		onClick = null;

		super.destroy();
	}
}
