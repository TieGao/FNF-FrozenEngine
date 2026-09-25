package objects;

import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.display.BitmapData;
import openfl.geom.Matrix;

/**
 * ToolBar 底部音乐播放器控件的图标绘制器。
 *
 * 全部用 Shape 现场画：任意尺寸、任意颜色、零素材。
 * 图标画在 size × size 的正方形里，坐标为 0~1 归一化后乘 size。
 *
 * 本类不做缓存 —— 每次调用都新造一张 BitmapData。
 * 这类自造的图会被 FlxG.bitmap 连带 dispose，所以调用方（ToolBar）负责判活重画。
 */
class ToolBarIcons
{
	// ---------------------------------------------------------
	// 播放器按钮配色
	// 固定深色，不跟随 UITheme —— 这条栏永远是深色模糊底，
	// 跟随主题会在浅色模式下把浅色图标画到黑底上。
	// ---------------------------------------------------------
	public static inline var BG_NORMAL:Int = 0xFF333333;
	public static inline var BG_HOVER:Int = 0xFF44445F;
	public static inline var BG_PRESS:Int = 0xFF5C5C88;
	public static inline var ICON_NORMAL:Int = 0xFFDCDCDC;
	public static inline var ICON_HOVER:Int = 0xFFFFFFFF;
	public static inline var ICON_PRESS:Int = 0xFFFFFFFF;
	/** 人声静音时的图标色 */
	public static inline var ICON_MUTED:Int = 0xFFFF6B6B;

	/** 图标占按钮边长的比例 */
	static inline var ICON_RATIO:Float = 0.52;

	/**
	 * 单画一个图标（透明底）。
	 * @param kind prev / next / play / pause / stop / mic / mic_off / volume_down / volume_up
	 */
	public static function draw(kind:String, size:Int, color:FlxColor):BitmapData
	{
		var s:Int = Std.int(Math.max(8, size));
		var shape:Shape = new Shape();
		drawIcon(shape.graphics, kind, s, color);

		var bmd:BitmapData = new BitmapData(s, s, true, 0x00000000);
		bmd.draw(shape);
		return bmd;
	}

	/**
	 * 画按钮用的 3 帧竖排图集（normal / hover / press，每帧 size × size）。
	 * 每帧 = 圆角底 + 居中图标，直接喂给
	 * FlxButton.loadGraphic(bmd, true, size, size)。
	 *
	 * @param iconNormal normal 帧的图标色。要换色就传目标色（如人声静音传 ICON_MUTED）——
	 *                   不要用 -1 之类的哨兵：颜色字面量带 0x80 位时在 Int32 里是负数，
	 *                   `iconNormal >= 0` 那类判断会把红色当成"没传"。
	 */
	public static function buttonStrip(kind:String, size:Int, ?iconNormal:Int = ICON_NORMAL):BitmapData
	{
		var s:Int = Std.int(Math.max(16, size));
		var iconSize:Int = Std.int(Math.max(8, s * ICON_RATIO));
		var inset:Float = (s - iconSize) * 0.5;
		var r:Float = s * 0.22;

		var bgColors:Array<Int> = [BG_NORMAL, BG_HOVER, BG_PRESS];
		var iconColors:Array<Int> = [iconNormal, ICON_HOVER, ICON_PRESS];

		var bmd:BitmapData = new BitmapData(s, s * 3, true, 0x00000000);

		// 三个状态的圆角底
		var bgShape:Shape = new Shape();
		var bg:Graphics = bgShape.graphics;
		for (i in 0...3)
		{
			bg.beginFill(bgColors[i]);
			bg.drawRoundRect(0, i * s, s, s, r, r);
			bg.endFill();
		}
		bmd.draw(bgShape);

		// 三个状态的图标（同一套几何，靠 Matrix 平移到各自那一帧）
		for (i in 0...3)
		{
			var iconShape:Shape = new Shape();
			drawIcon(iconShape.graphics, kind, iconSize, iconColors[i]);

			var m:Matrix = new Matrix();
			m.translate(inset, i * s + inset);
			bmd.draw(iconShape, m);
		}

		return bmd;
	}

	// =========================================================
	// 图标分发
	// =========================================================

	/**
	 * 把图标画进 g。坐标为 0~1 归一化后乘 s。
	 *
	 * 约定：**先画完所有 beginFill 的填充块，最后再 lineStyle 画描边**。
	 * 同一个 Graphics 上先设了 lineStyle 再去 beginFill，每个填充块会额外吃一圈
	 * 同色描边、把相邻块之间的缝隙吃掉。
	 */
	static function drawIcon(g:Graphics, kind:String, s:Int, color:FlxColor):Void
	{
		var t:Float = Math.max(1.6, s * 0.10);

		switch (kind)
		{
			case 'prev': drawPrev(g, s, color);
			case 'next': drawNext(g, s, color);
			case 'play': drawPlay(g, s, color);
			case 'pause': drawPause(g, s, color);
			case 'stop': drawStop(g, s, color);
			case 'mic': drawMic(g, s, color, t);
			case 'mic_off': drawMicOff(g, s, color, t);
			case 'volume_down': drawVolume(g, s, color, t, 1);
			case 'volume_up': drawVolume(g, s, color, t, 2);
			default: drawDot(g, s, color);
		}
	}

	// =========================================================
	// 各个图标
	// =========================================================

	static function drawPrev(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.beginFill(color);
		g.drawRect(s * 0.10, s * 0.20, s * 0.10, s * 0.60);
		g.endFill();

		g.beginFill(color);
		g.moveTo(s * 0.60, s * 0.20);
		g.lineTo(s * 0.60, s * 0.80);
		g.lineTo(s * 0.24, s * 0.50);
		g.lineTo(s * 0.60, s * 0.20);
		g.moveTo(s * 0.90, s * 0.20);
		g.lineTo(s * 0.90, s * 0.80);
		g.lineTo(s * 0.54, s * 0.50);
		g.lineTo(s * 0.90, s * 0.20);
		g.endFill();
	}

	static function drawNext(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.beginFill(color);
		g.drawRect(s * 0.80, s * 0.20, s * 0.10, s * 0.60);
		g.endFill();

		g.beginFill(color);
		g.moveTo(s * 0.40, s * 0.20);
		g.lineTo(s * 0.40, s * 0.80);
		g.lineTo(s * 0.76, s * 0.50);
		g.lineTo(s * 0.40, s * 0.20);
		g.moveTo(s * 0.10, s * 0.20);
		g.lineTo(s * 0.10, s * 0.80);
		g.lineTo(s * 0.46, s * 0.50);
		g.lineTo(s * 0.10, s * 0.20);
		g.endFill();
	}

	static function drawPlay(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.beginFill(color);
		g.moveTo(s * 0.30, s * 0.16);
		g.lineTo(s * 0.86, s * 0.50);
		g.lineTo(s * 0.30, s * 0.84);
		g.lineTo(s * 0.30, s * 0.16);
		g.endFill();
	}

	static function drawPause(g:Graphics, s:Int, color:FlxColor):Void
	{
		var r:Float = s * 0.06;
		g.beginFill(color);
		g.drawRoundRect(s * 0.28, s * 0.18, s * 0.16, s * 0.64, r, r);
		g.drawRoundRect(s * 0.56, s * 0.18, s * 0.16, s * 0.64, r, r);
		g.endFill();
	}

	static function drawStop(g:Graphics, s:Int, color:FlxColor):Void
	{
		var r:Float = s * 0.10;
		g.beginFill(color);
		g.drawRoundRect(s * 0.22, s * 0.22, s * 0.56, s * 0.56, r, r);
		g.endFill();
	}

	/** 麦克风：胶囊体 + 下方 U 形托 + 立柱 + 底座横线 */
	static function drawMic(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		var r:Float = s * 0.16;
		g.beginFill(color);
		g.drawRoundRect(s * 0.36, s * 0.10, s * 0.28, s * 0.46, r, r);
		g.endFill();

		g.lineStyle(t, color, 1);
		// U 形托
		g.moveTo(s * 0.24, s * 0.46);
		g.curveTo(s * 0.50, s * 0.84, s * 0.76, s * 0.46);
		// 立柱
		g.moveTo(s * 0.50, s * 0.66);
		g.lineTo(s * 0.50, s * 0.84);
		// 底座
		g.moveTo(s * 0.36, s * 0.86);
		g.lineTo(s * 0.64, s * 0.86);
		g.lineStyle(t, color, 0);
	}

	/** 麦克风 + 斜杠 */
	static function drawMicOff(g:Graphics, s:Int, color:FlxColor, t:Float):Void
	{
		drawMic(g, s, color, t);

		g.lineStyle(t, color, 1);
		g.moveTo(s * 0.16, s * 0.16);
		g.lineTo(s * 0.84, s * 0.84);
		g.lineStyle(t, color, 0);
	}

	/**
	 * 扬声器 + 声波弧线。
	 * @param waves 画几道弧（1 = 音量减，2 = 音量加）
	 */
	static function drawVolume(g:Graphics, s:Int, color:FlxColor, t:Float, waves:Int):Void
	{
		g.beginFill(color);
		g.moveTo(s * 0.10, s * 0.36);
		g.lineTo(s * 0.28, s * 0.36);
		g.lineTo(s * 0.48, s * 0.14);
		g.lineTo(s * 0.48, s * 0.86);
		g.lineTo(s * 0.28, s * 0.64);
		g.lineTo(s * 0.10, s * 0.64);
		g.lineTo(s * 0.10, s * 0.36);
		g.endFill();

		g.lineStyle(t, color, 1);
		if (waves >= 1)
		{
			g.moveTo(s * 0.58, s * 0.36);
			g.curveTo(s * 0.72, s * 0.50, s * 0.58, s * 0.64);
		}
		if (waves >= 2)
		{
			g.moveTo(s * 0.70, s * 0.22);
			g.curveTo(s * 0.92, s * 0.50, s * 0.70, s * 0.78);
		}
		g.lineStyle(t, color, 0);
	}

	static function drawDot(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.beginFill(color);
		g.drawCircle(s * 0.5, s * 0.5, s * 0.30);
		g.endFill();
	}
}
