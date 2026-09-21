package options.objects.win8;

import backend.UIControlTheme;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * Win8 设置面板标题栏左上角的返回按钮（图标用 CharmIcons 现画）
 *
 * 视觉：默认只有浅色图标；悬停 / 按下时底色提亮、图标转强调色。
 * 点一下执行 onClick（宿主接 onBackAction()）。
 */
class Win8CharmIcon extends FlxSpriteGroup
{
	public var bg:Rect;
	public var icon:FlxSprite;

	public var onClick:Void->Void = null;

	var isHover:Bool = false;
	/**
	 * 是否接受鼠标输入。
	 * 面板滑入 / 滑出的过程中要关掉，否则还没停稳就能点到返回。
	 */
	public var inputEnabled:Bool = true;

	var mainW:Float;
	var iconSize:Int;
	var iconY:Float;

	var pressing:Bool = false;
	/** 上次画的图标颜色（-1 = 还没画过）。颜色没变就不重画 —— CharmIcons 没有缓存 */
	var lastIconColor:Int = -1;

	public function new(x:Float, y:Float, w:Float, h:Float, ?onClick:Void->Void)
	{
		super(x, y);
		UITheme.ensure();

		this.onClick = onClick;
		mainW = w;

		bg = new Rect(0, 0, w, h, 0, 0, UIControlTheme.railHover(), 0);
		add(bg);

		iconSize = Std.int(Math.min(w * 0.46, h * 0.44));
		icon = new FlxSprite();
		icon.antialiasing = ClientPrefs.data.antialiasing;
		iconY = h * 0.18;
		icon.x = (w - iconSize) * 0.5;
		icon.y = iconY;
		add(icon);
		redrawIcon(true);

		applyColors();
	}

	/**
	 * 只关鼠标输入，不改配色。
	 * 面板滑入/滑出时用它 —— 按钮还是正常颜色，只是点不到、也不会有 hover 高亮。
	 */
	public function setInputEnabled(v:Bool):Void
	{
		if (inputEnabled == v) return;
		inputEnabled = v;

		if (!v)
		{
			isHover = false;
			pressing = false;
		}

		applyColors();
	}

	function applyColors():Void
	{
		if (bg != null) bg.alpha = isHover ? 1 : 0;
		redrawIcon();
	}

	// ---------------------------------------------------------
	// 图标重绘（颜色变了才重画）
	// ---------------------------------------------------------
	function redrawIcon(?force:Bool = false):Void
	{
		if (icon == null) return;

		var c:FlxColor = isHover ? UIControlTheme.accent() : UIControlTheme.textSecondary();

		// 判活，而不是判 `icon.pixels != null` —— 那个 getter 就是 `graphic.bitmap`，
		// 图被 dispose 之后仍然非 null，拿它当"图还在"会让这个按钮永远不重画。
		if (!force && lastIconColor == c && icon.graphic != null && !icon.graphic.isDestroyed) return;
		lastIconColor = c;

		icon.pixels = CharmIcons.draw('back', iconSize, c);
		icon.offset.set(0, 0);
		icon.origin.set(0, 0);
		icon.scale.set(1, 1);
		icon.updateHitbox();
		// 注意：FlxSpriteGroup 的子元素坐标是"绝对"的（add() 时已经加过 group.x/y，
		// 之后 group 移动也是靠 set_x 把增量传播下来），所以这里必须带上 this.x/this.y，
		// 否则重绘（比如 hover 变色）会把图标弹回屏幕左上角。
		icon.x = this.x + (mainW - iconSize) * 0.5;
		icon.y = this.y + iconY;
	}

	/** 主题切换后重新套色（图标会被重画） */
	public function refreshTheme():Void
	{
		if (bg != null) bg.color = UIControlTheme.railHover();
		lastIconColor = -1;
		applyColors();
	}

	// ---------------------------------------------------------
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!visible || !active) return;
		if (!inputEnabled)
		{
			if (isHover)
			{
				isHover = false;
				pressing = false;
				applyColors();
			}
			return;
		}

		var mouse = FlxG.mouse;
		var wasHover:Bool = isHover;
		isHover = OptionInput.overlaps(bg);

		if (isHover != wasHover)
		{
			FlxTween.cancelTweensOf(bg);
			FlxTween.tween(bg, {alpha: isHover ? 1 : 0}, 0.12, {ease: FlxEase.quadOut});
			if (!isHover) pressing = false;
			applyColors();
		}

		if (isHover && mouse.justPressed)
		{
			pressing = true;
			FlxTween.cancelTweensOf(bg);
			FlxTween.tween(bg, {alpha: 1}, 0.05);
		}

		if (mouse.justReleased && pressing)
		{
			pressing = false;
			if (isHover && onClick != null) onClick();
		}
	}
}
