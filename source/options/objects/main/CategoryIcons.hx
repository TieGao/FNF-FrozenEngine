package options.objects.main;

import flixel.graphics.FlxGraphic;

import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.display.BitmapData;

/**
 * OptionsState 分类卡片的图标绘制器
 *
 * 和 options.objects.win8.CharmIcons 同一套路：没有素材，全部用 Shape 现场画，
 * 任意尺寸 / 任意颜色（深浅色切换只要重画一次），不依赖资源包。
 * 所有图标都画在 size × size 的正方形里，坐标为 0~1 归一化后乘 size。
 *
 * ⚠️ 线宽用 5%，不是 CharmIcons 的 7.8%：那边图标在 rail 里显示 33px，7.8% ≈ 2.6px 正好；
 *   本卡片要显示到 48px，沿用会得到 3.7px 的粗线，明显过重。
 * ⚠️ 填充小块之前必须把描边关掉（lineStyle 的 alpha 设 0，见 fillBegin / fillEnd）：
 *   48px 下键盘键帽只有 0.10 高、行间距 0.06，描边 0.05 会上下各撑 0.025，把两排键帽糊成一片。
 * ⚠️ 有静态缓存，返回的 FlxGraphic 是**共享对象**，调用方只能读、不能改。
 */
class CategoryIcons
{
	/**
	 * 静态缓存：kind|size|color -> 已画好的图。
	 *
	 * 为什么必须有：OptionsState.buildCards() 在**搜索框每敲一个键**都会重建全部卡片，
	 * 一次 8 张图标。不缓存的话每敲一键就产生 8 个新 BitmapData 塞进 FlxG.bitmap，
	 * 一路累积；缓存后同一 kind/size/color 只画一次。
	 * （shapeEx/Rect.hx 里也有一份同样的静态 Cache，不是新花样。）
	 *
	 * ⚠️ 缓存里的图会被 FlxG.bitmap 清理连带销毁，命中时必须判活（见 draw 的说明）。
	 */
	static var cache:Map<String, FlxGraphic> = new Map();

	/** 默认线宽占 size 的比例 */
	inline static var STROKE_RATIO:Float = 0.05;

	/**
	 * 画一个图标。
	 *
	 * 缓存命中也要**判活**再返回。这份图的 BitmapData 是经 `sprite.frames` 交给
	 * FlxG.bitmap 托管的（key 形如 `pixels3`），而 `Paths.clearStoredMemory()` 是按
	 * "key 不在 currentTrackedAssets 里"整片销毁 —— 不看 useCount、也不看 persist
	 * —— 所以每次进设置界面（`OptionsState.create()`）它都会被
	 * `FlxGraphic.destroy()` → `bitmap.dispose()` 干掉一次，而静态缓存还留着这个 key。
	 * 直接返回就是一张死图：openfl 的 `get_image()` 见 `__isValid == false` 返回 null，
	 * 图标一个像素都画不出来。死了就重画并覆盖缓存条目
	 * —— 和 shapeEx.Rect + backend.Cache.checkFrame 同一个路子。
	 *
	 * @param kind      图标种类，见下方 switch；未知种类落到 drawGeneric
	 * @param size      画布边长（像素）
	 * @param color     线条 / 填充色
	 * @param thickness 线宽，<= 0 时按 size * 5% 自动取（下限 1.5px）
	 */
	public static function draw(kind:String, size:Int, color:FlxColor, ?thickness:Float = 0):FlxGraphic
	{
		var s:Int = Std.int(Math.max(8, size));
		var key:String = kind + '|' + s + '|' + Std.string(color);

		// isDestroyed 是 flixel 自己的判据（= shader == null，FlxImageFrame.fromGraphic 也这么判），
		// 别自己拼 imageFrame.frames.length —— 那个 getter 会惰性重建 frames 集合。
		var cached:FlxGraphic = cache.get(key);
		if (cached != null && !cached.isDestroyed) return cached;

		var t:Float = thickness > 0 ? thickness : Math.max(1.5, s * STROKE_RATIO);

		var shape:Shape = new Shape();
		var g = shape.graphics;
		g.lineStyle(t, color, 1);

		switch (kind)
		{
			case 'keyboard': drawKeyboard(g, s, color, t);
			case 'arrow': drawArrow(g, s, color, t);
			case 'palette': drawPalette(g, s, color, t);
			case 'hiterror': drawHitError(g, s, color, t);
			case 'hud': drawHud(g, s, color, t);
			case 'menu': drawMenu(g, s, color, t);
			case 'gpu': drawGpu(g, s, color, t);
			case 'debug': drawDebug(g, s, color, t);
			default: drawGeneric(g, s, color, t);
		}

		var bmd:BitmapData = new BitmapData(s, s, true, 0x00000000);
		bmd.draw(shape);

		// 照 shapeEx.Rect.addCache 的写法建图（Unique=false / Key=null / Cache=true）：
		// 让它进 FlxG.bitmap 的缓存，被清掉时下一帧重建就行。
		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bmd);
		cache.set(key, graphic);
		return graphic;
	}

	// =========================================================
	// 填充辅助
	//
	// 填充前把描边 alpha 设成 0 —— 不然每个填充路径都会被再加一圈同色描边，
	// 块与块之间的缝隙就被吃掉（见文件头注释第 2 条）。
	// 注意用 alpha=0 而不是 thickness=0：后者会生成退化几何，语义也不明确。
	// =========================================================
	inline static function fillBegin(g:Graphics, color:FlxColor, t:Float):Void
	{
		g.lineStyle(t, color, 0);
		g.beginFill(color);
	}

	inline static function fillEnd(g:Graphics, color:FlxColor, t:Float):Void
	{
		g.endFill();
		g.lineStyle(t, color, 1);
	}

	// =========================================================
	// 各个图标
	// =========================================================

	/** Basics：键盘（键帽方阵 + 空格条） */
	static function drawKeyboard(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		g.drawRect(s * 0.06, s * 0.24, s * 0.88, s * 0.52);

		fillBegin(g, color, t);
		var kw:Float = s * 0.16;
		var kh:Float = s * 0.10;
		for (i in 0...3)
		{
			var kx:Float = s * 0.12 + i * s * 0.30;
			g.drawRect(kx, s * 0.33, kw, kh);
			g.drawRect(kx, s * 0.49, kw, kh);
		}
		g.drawRect(s * 0.28, s * 0.63, s * 0.44, s * 0.08);
		fillEnd(g, color, t);
	}

	/** Gameplay：音符方向箭头（→），和游戏里的 note 箭头同形 */
	static function drawArrow(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		fillBegin(g, color, t);
		// 杆
		g.drawRect(s * 0.10, s * 0.415, s * 0.44, s * 0.17);
		// 箭头
		g.moveTo(s * 0.48, s * 0.22);
		g.lineTo(s * 0.90, s * 0.50);
		g.lineTo(s * 0.48, s * 0.78);
		g.lineTo(s * 0.48, s * 0.22);
		fillEnd(g, color, t);
	}

	/** Skin：调色板（主体 + 颜料点 + 拇指孔） */
	static function drawPalette(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		g.drawCircle(s * 0.5, s * 0.5, s * 0.42);

		fillBegin(g, color, t);
		g.drawCircle(s * 0.30, s * 0.36, s * 0.085);
		g.drawCircle(s * 0.52, s * 0.30, s * 0.085);
		g.drawCircle(s * 0.70, s * 0.44, s * 0.085);
		g.drawCircle(s * 0.34, s * 0.62, s * 0.085);
		fillEnd(g, color, t);

		g.drawCircle(s * 0.70, s * 0.70, s * 0.115);
	}

	/** Components：mini 判定误差条（基准线 + 中央刻线 + 两侧偏差刻度） */
	static function drawHitError(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		g.moveTo(s * 0.06, s * 0.50);
		g.lineTo(s * 0.94, s * 0.50);

		fillBegin(g, color, t);
		// 中央基准刻线（更宽更高，和两侧刻度拉开区别）
		g.drawRect(s * 0.47, s * 0.16, s * 0.06, s * 0.68);
		// 两侧偏差刻度，高低错落 → 读起来像一次判定的分布
		g.drawRect(s * 0.16, s * 0.40, s * 0.05, s * 0.20);
		g.drawRect(s * 0.26, s * 0.34, s * 0.05, s * 0.32);
		g.drawRect(s * 0.36, s * 0.42, s * 0.05, s * 0.16);
		g.drawRect(s * 0.59, s * 0.38, s * 0.05, s * 0.24);
		g.drawRect(s * 0.69, s * 0.33, s * 0.05, s * 0.34);
		g.drawRect(s * 0.79, s * 0.41, s * 0.05, s * 0.18);
		fillEnd(g, color, t);
	}

	/** GameUI：HUD 进度条（两条轨道 + 各自已填充段） */
	static function drawHud(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		g.drawRoundRect(s * 0.12, s * 0.24, s * 0.76, s * 0.20, s * 0.10, s * 0.10);
		g.drawRoundRect(s * 0.12, s * 0.56, s * 0.76, s * 0.20, s * 0.10, s * 0.10);

		fillBegin(g, color, t);
		g.drawRoundRect(s * 0.145, s * 0.265, s * 0.435, s * 0.15, s * 0.075, s * 0.075);
		g.drawRoundRect(s * 0.145, s * 0.585, s * 0.235, s * 0.15, s * 0.075, s * 0.075);
		fillEnd(g, color, t);
	}

	/** OuterUI：菜单列表（窗口 + 3 行菜单项） */
	static function drawMenu(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		g.drawRoundRect(s * 0.10, s * 0.16, s * 0.80, s * 0.68, s * 0.12, s * 0.12);

		fillBegin(g, color, t);
		for (i in 0...3)
		{
			var ry:Float = s * 0.28 + i * s * 0.18;
			g.drawRect(s * 0.20, ry, s * 0.12, s * 0.12);
			g.drawRect(s * 0.38, ry + s * 0.03, s * 0.34, s * 0.06);
		}
		fillEnd(g, color, t);
	}

	/** Graphics：显卡（挡板 + PCB + 双风扇 + 金手指） */
	static function drawGpu(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		// 左侧挡板
		fillBegin(g, color, t);
		g.drawRect(s * 0.02, s * 0.24, s * 0.06, s * 0.54);
		fillEnd(g, color, t);

		// PCB
		g.drawRoundRect(s * 0.08, s * 0.28, s * 0.84, s * 0.44, s * 0.05, s * 0.05);

		// 两个风扇
		g.drawCircle(s * 0.33, s * 0.50, s * 0.15);
		g.drawCircle(s * 0.67, s * 0.50, s * 0.15);

		fillBegin(g, color, t);
		g.drawCircle(s * 0.33, s * 0.50, s * 0.05);
		g.drawCircle(s * 0.67, s * 0.50, s * 0.05);
		// 金手指
		for (i in 0...4)
			g.drawRect(s * 0.21 + i * s * 0.16, s * 0.72, s * 0.10, s * 0.07);
		fillEnd(g, color, t);
	}

	/** Advanced：调试（控制台窗口 + 斜放的扳手） */
	static function drawDebug(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		// 窗口 + 标题栏分隔线
		g.drawRoundRect(s * 0.05, s * 0.12, s * 0.60, s * 0.54, s * 0.08, s * 0.08);
		g.moveTo(s * 0.05, s * 0.28);
		g.lineTo(s * 0.65, s * 0.28);

		// 窗口里的两行输出
		fillBegin(g, color, t);
		g.drawRect(s * 0.14, s * 0.37, s * 0.40, s * 0.055);
		g.drawRect(s * 0.14, s * 0.48, s * 0.24, s * 0.055);
		fillEnd(g, color, t);

		// 扳手：斜杆 + 头部圆环
		g.moveTo(s * 0.52, s * 0.90);
		g.lineTo(s * 0.78, s * 0.66);
		g.drawCircle(s * 0.83, s * 0.64, s * 0.11);
	}

	/** 兜底：未知 kind 画一个"带点的方框"，别退化成一个小圆点 */
	static function drawGeneric(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		g.drawRoundRect(s * 0.14, s * 0.14, s * 0.72, s * 0.72, s * 0.16, s * 0.16);

		fillBegin(g, color, t);
		g.drawCircle(s * 0.5, s * 0.5, s * 0.14);
		fillEnd(g, color, t);
	}
}
