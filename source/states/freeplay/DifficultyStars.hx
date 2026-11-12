package states.freeplay;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;
import backend.Paths;

/**
 * Freeplay 右侧的官方星星难度显示（移植自官方 FunkIn 的 DifficultyStars）。
 *
 * 星星是一段纹理图集动画："diff stars" 每颗星占 100 帧 —— 0~99 转 1 颗、
 * 100~199 转 2 颗……900~999 转 10 颗（10 个槽位满排），1500 定格 0 星。
 * 超过 10 颗的部分由星星上方的火焰表达（flameCount = difficulty - 10，最多 5 个）。
 *
 * 摆位：整组锚在**专辑封面的顶边**——星星行左右居中压在封面上沿，火焰从星缝里往上冒。
 * 组自身恒定在 (0,0)，成员一律写绝对屏幕坐标：FlxSpriteGroup 的 preAdd 会把组坐标
 * 烘进成员、set_x 又按差值传播，两套语义叠加最容易算错，这里干脆绕开。
 * 位置由 alignToAlbum() 算一次，换封面 / 换分辨率再算一次。
 */
class DifficultyStars extends FlxSpriteGroup
{
	public static inline var FRAME_SEG:Int = 100; // 每颗星占的帧数
	public static inline var MAX_STARS:Int = 15;
	static inline var ZERO_STARS_FRAME:Int = 1500; // 官方 0 星定格帧

	// ==== 星星行的内容盒（相对 stars.x / stars.y，**已含 ROW_LEVEL_ANGLE 的摆正旋转**）====
	// 旋转后的内容位置 = origin + R(angle)·(rootMX + 层内平移)，rootMX = AN.STI.MX = (497.25, 320.95)。
	// 关键在 origin：`PsychFlxAnimate.loadAtlasEx` 里那句 `origin = symbol.transformationPoint`
	// 在 `origin(default, null)` 下其实没生效，draw 时用的是 resetHelpers → centerOrigin() 留下的
	// **帧尺寸一半** (55.5, 114)（spritemap 111×228）。按这个轴心算 10 星满排的包围盒才是下面这个，
	// 用 AN.STI.MX 当轴心会整体偏右上（实测过，别再用）。
	// 这些值只负责"第一帧看着就不离谱"，真正落地靠 measureContentOffset() 实测校正。
	static inline var CONTENT_LEFT:Float = 820;
	static inline var CONTENT_TOP:Float = 78;
	static inline var CONTENT_W:Float = 301;
	static inline var CONTENT_H:Float = 52;

	/**
	 * 把图集里右低左高的斜排转平，让星星行和（不歪的）封面平行。
	 * 8.543° = atan2(37.20, 247.65)：10 个星槽的 y 差比 x 差。
	 * 代价：单颗星也跟着转 8.5°，44px 的星看出不明显；真要连单颗都不歪只能拆图集。
	 */
	static inline var ROW_LEVEL_ANGLE:Float = -8.543;

	/** 星星行底边相对封面上沿再上抬多少；0 = 行底边正好压在封面上沿 */
	public static var albumTopGap:Float = 0;

	// 火焰 sparrow 的帧盒是 109 × 199。循环段（第 2 帧往后）火苗内容落在盒内 y ≈ 40~170、
	// x ≈ 31~85 —— 火根和火心都不在盒角上，所以下面三个量都是"内容"口径，不是盒子口径。
	static inline var FLAME_BOX_W:Float = 109;
	/** 火根（循环段内容底边）在帧盒里的 y */
	static inline var FLAME_BASE_Y:Float = 175;
	/** 火根相对星星行顶边的位置：压进行里，火苗从星星中间往上冒 */
	static inline var FLAME_BASE_AT_ROW:Float = 34;
	/** 火苗内容在帧盒里偏右（31~85），整簇要往左挪回来才和星行居中 */
	static inline var FLAME_SHIFT_X:Float = -13;

	/**
	 * 内部帧段游标：0~14 → 从 (游标 * 100) 起播；15 = 0 星定格段。
	 */
	var curDifficulty(default, set):Int = 0;

	/**
	 * 官方星数，0~15。0 = 无星（定格 0 星帧、隐藏火焰）。
	 */
	public var difficulty(default, set):Int = 1;

	public var stars:FlxAnimate;
	public var flames:FreeplayFlames;

	/** 图集是否加载成功；失败时 FreeplayState 直接隐藏整组。 */
	public var atlasOK(default, null):Bool = false;

	/** 当前对齐的封面矩形（世界坐标），null = 还没对齐过。 */
	var albumRect:FlxRect = null;

	/** 内容盒左上角要落到的屏幕坐标（layout 算出来的目标）。 */
	var targetLeft:Float = 0;
	var targetTop:Float = 0;

	/** 实测的内容盒左上角偏移（相对 stars.x/y）。NaN = 还没量到。 */
	var measuredLeft:Float = Math.NaN;
	var measuredTop:Float = Math.NaN;

	/** 下一次 update 里要不要取一次实测偏移。 */
	var measurePending:Bool = false;

	/** 还要等几帧才采信 relativeX/relativeY（draw 在本帧 update 之后才跑）。 */
	var measureCountdown:Int = 0;

	public function new()
	{
		super(0, 0);
		scrollFactor.set();

		// 火焰先 add，星星后 add —— 画序上星星压住火苗根部
		flames = new FreeplayFlames();
		flames.flameX = 0;
		flames.flameY = 0;

		// 这里 new FlxAnimate() 经 source/import.hx 的全局别名 = PsychFlxAnimate
		// （和 Character 的 atlas 同一条加载路径），别改成显式 import 库里的 FlxAnimate
		stars = new FlxAnimate();
		stars.showPivot = false;
		stars.scrollFactor.set();
		// 图集里这排星是右低左高的斜排（官方封面也是斜的，配套）。封面在这里是正的，
		// 所以把整排转平 —— 转轴是 origin（根符号变换点），内容盒随之变化，见 CONTENT_*。
		stars.angle = ROW_LEVEL_ANGLE;
		try
		{
			Paths.loadAnimateAtlas(stars, 'freeplay/freeplayStars');
			atlasOK = true;
			stars.anim.play('diff stars', true, false, 0);
		}
		catch (e:Dynamic)
		{
			trace('DifficultyStars: 星星图集加载失败: $e');
		}

		add(flames);
		add(stars);
		visible = false;
	}

	/**
	 * 锚到一块封面上：星星行左右居中、底边压在封面上沿（见 albumTopGap），火焰跟着行顶走。
	 * 传的必须是封面**可见**矩形（flixel 的 updateHitbox 把 offset 设成负值，
	 * sprite.x 并不是绘制左上角，别直接传 x/y）。
	 */
	public function alignToAlbum(rect:FlxRect):Void
	{
		if (rect == null) return;

		if (albumRect == null) albumRect = FlxRect.get(0, 0, 0, 0);
		albumRect.copyFrom(rect);

		layout();
	}

	/** 按 albumRect 重算所有成员坐标。 */
	function layout():Void
	{
		if (albumRect == null || !atlasOK) return;

		var centerX:Float = albumRect.x + albumRect.width * 0.5;
		var rowLeft:Float = centerX - CONTENT_W * 0.5;
		var rowBottom:Float = albumRect.y - albumTopGap;
		var rowTop:Float = rowBottom - CONTENT_H;

		targetLeft = rowLeft;
		targetTop = rowTop;

		placeStars();
		placeFlames(rowLeft, rowTop);

		// 位置变了就重新量一次（偏移是图集属性，量的结果每次都一样，幂等）
		measurePending = true;
		measureCountdown = 3;
	}

	/** 内容盒左上角顶到 (targetLeft, targetTop)：偏移优先用实测值，没量到就用估计值。 */
	function placeStars():Void
	{
		var offLeft:Float = Math.isNaN(measuredLeft) ? CONTENT_LEFT : measuredLeft;
		var offTop:Float = Math.isNaN(measuredTop) ? CONTENT_TOP : measuredTop;
		stars.x = targetLeft - offLeft;
		stars.y = targetTop - offTop;
	}

	/**
	 * 火焰：5 个槽沿整行铺满，火根压进星星行里，整簇左挪补掉火苗内容在帧盒里的右偏。
	 * 基准用的是**估计**的行顶（rowTop），不跟着实测偏移走 —— 火焰这一版用户已经确认过位置，
	 * 星星校正时不能把它一起带跑。
	 */
	function placeFlames(rowLeft:Float, rowTop:Float):Void
	{
		flames.flameX = rowLeft + FLAME_SHIFT_X;
		flames.flameY = rowTop + FLAME_BASE_AT_ROW - FLAME_BASE_Y;
		flames.flameSpreadX = (CONTENT_W - FLAME_BOX_W) / 4;
		flames.flameSpreadY = 0; // 星行已经转平，火焰不再跟着坡度走
	}

	/**
	 * 用 flxanimate 自己量出来的 relativeX/relativeY 校正内容盒偏移。
	 *
	 * `draw()` 里 `relativeX = 内容屏幕左缘 − sprite.x`，是唯一可信的真值 —— 旋转轴心到底在哪、
	 * 根平移有没有被抵消，全都不用再猜。
	 *
	 * 两个坑：
	 * - draw 在本帧 update 之后才跑，所以**不能**用 `stars.width` 判断"量到了没"：drawLimb 收尾时
	 *   会把 width/height 改写成**最后一块 limb** 的尺寸（几十像素），不是内容并集的宽度，
	 *   拿它跟 CONTENT_W 比对会永远判失败（上一版校正就是这么被静默跳过的）。
	 *   改用帧计数：layout 之后等 3 帧，期间 visible 的每一帧都必然走过一次 draw。
	 * - 内容整块在视口外时 `_flashRect` 是空的，relativeX 会退化成 −x，值离谱，丢掉重试。
	 */
	function measureContentOffset():Void
	{
		if (!measurePending || !visible || !atlasOK) return;
		if (FlxG.camera.zoom != 1) return; // 评级升级动画会拉 zoom

		if (measureCountdown > 0)
		{
			measureCountdown--;
			return;
		}

		if (Math.abs(stars.relativeX) > 3000 || Math.abs(stars.relativeY) > 3000) return;

		measuredLeft = stars.relativeX;
		measuredTop = stars.relativeY;
		measurePending = false;
		placeStars();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!atlasOK || stars.anim == null) return;

		measureContentOffset();

		// 官方的帧段循环：当前段播过头就从段首重来
		if (curDifficulty < 15 && stars.anim.curFrame >= (curDifficulty + 1) * FRAME_SEG)
		{
			stars.anim.play('diff stars', true, false, curDifficulty * FRAME_SEG);
		}
	}

	/**
	 * FlxSpriteGroup.set_visible 会把 visible 直接下发给**所有**成员，
	 * 把火焰"按 flameCount 逐个点燃"的状态一起冲成可见 —— 收尾时按 flameCount 再收一遍。
	 * 宿主每次刷新都会写 visible = atlasOK，所以这层补丁不能省。
	 */
	override function set_visible(Value:Bool):Bool
	{
		var changed:Bool = (visible != Value);
		var ret:Bool = super.set_visible(Value);
		if (changed && Value && flames != null) flameCheck();
		return ret;
	}

	function set_difficulty(value:Int):Int
	{
		if (value <= 0)
		{
			difficulty = 0;
			curDifficulty = 15; // 15 号段 = 官方的 0 星定格
		}
		else if (value <= MAX_STARS)
		{
			difficulty = value;
			curDifficulty = value - 1;
		}
		else
		{
			difficulty = MAX_STARS;
			curDifficulty = MAX_STARS - 1;
		}

		flameCheck();

		return difficulty;
	}

	public function flameCheck():Void
	{
		flames.flameCount = difficulty > 10 ? difficulty - 10 : 0;
	}

	function set_curDifficulty(value:Int):Int
	{
		curDifficulty = value;

		if (!atlasOK || stars.anim == null) return curDifficulty;

		if (curDifficulty == 15)
		{
			stars.anim.play('diff stars', true, false, ZERO_STARS_FRAME);
			stars.anim.pause();
		}
		else
		{
			stars.anim.curFrame = curDifficulty * FRAME_SEG;
			stars.anim.play('diff stars', true, false, curDifficulty * FRAME_SEG);
		}

		return curDifficulty;
	}

	override function destroy():Void
	{
		albumRect = null; // 成员由 super.destroy() 负责
		super.destroy();
	}
}
