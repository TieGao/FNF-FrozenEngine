package options.objects.win8;

import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.display.BitmapData;

/**
 * Win8 Charm 边栏的图标绘制器
 *
 * 项目里没有 pausemenu 之类的图标素材，所以这里全部用 Shape 现场画，
 * 好处是任意尺寸/任意颜色（深浅色切换只要重画一次），也不依赖资源包。
 *
 * 所有图标都画在 size × size 的正方形里，坐标为 0~1 归一化后乘 size。
 */
class CharmIcons
{
	public static function draw(kind:String, size:Int, color:FlxColor, ?thickness:Float = 0):BitmapData
	{
		var s:Int = Std.int(Math.max(8, size));
		var t:Float = thickness > 0 ? thickness : Math.max(1.5, s * 0.078);

		var shape:Shape = new Shape();
		var g = shape.graphics;
		g.lineStyle(t, color, 1);

		switch (kind)
		{
			case 'search': drawSearch(g, s);
			case 'share': drawShare(g, s, color);
			case 'start': drawStart(g, s, color);
			case 'devices': drawDevices(g, s);
			case 'settings': drawSettings(g, s, color);
			case 'tool': drawTool(g, s);
			case 'resume': drawResume(g, s, color);
			case 'restart': drawRestart(g, s, color);
			case 'difficulty': drawDifficulty(g, s, color);
			case 'options': drawOptions(g, s, color);
			case 'exit': drawExit(g, s);
			case 'back': drawChevron(g, s);
			case 'close': drawClose(g, s);
			case 'check': drawCheck(g, s);
			default: drawDot(g, s, color);
		}

		var bmd:BitmapData = new BitmapData(s, s, true, 0x00000000);
		bmd.draw(shape);
		return bmd;
	}

	// =========================================================
	// 各个图标
	// =========================================================
	static function drawSearch(g:Graphics, s:Int):Void
	{
		g.drawCircle(s * 0.42, s * 0.42, s * 0.28);
		g.moveTo(s * 0.63, s * 0.63);
		g.lineTo(s * 0.87, s * 0.87);
	}

	static function drawShare(g:Graphics, s:Int, color:FlxColor):Void
	{
		// 连线先画（会被节点盖住，没关系）
		g.moveTo(s * 0.3, s * 0.5);
		g.lineTo(s * 0.72, s * 0.26);
		g.moveTo(s * 0.3, s * 0.5);
		g.lineTo(s * 0.72, s * 0.74);

		g.beginFill(color);
		g.drawCircle(s * 0.22, s * 0.5, s * 0.12);
		g.drawCircle(s * 0.78, s * 0.24, s * 0.12);
		g.drawCircle(s * 0.78, s * 0.76, s * 0.12);
		g.endFill();
	}

	static function drawStart(g:Graphics, s:Int, color:FlxColor):Void
	{
		// Windows 标志：2×2 方阵（略微错位模拟透视）
		var cell:Float = s * 0.34;
		var gap:Float = s * 0.1;
		var ox:Float = s * 0.09;
		var oy:Float = s * 0.09;

		g.beginFill(color);
		g.drawRect(ox, oy, cell, cell);
		g.drawRect(ox + cell + gap, oy + s * 0.02, cell, cell);
		g.drawRect(ox, oy + cell + gap, cell, cell);
		g.drawRect(ox + cell + gap, oy + cell + gap + s * 0.02, cell, cell);
		g.endFill();
	}

	static function drawDevices(g:Graphics, s:Int):Void
	{
		g.drawRect(s * 0.1, s * 0.16, s * 0.8, s * 0.5);
		g.moveTo(s * 0.5, s * 0.66);
		g.lineTo(s * 0.5, s * 0.84);
		g.moveTo(s * 0.28, s * 0.86);
		g.lineTo(s * 0.72, s * 0.86);
	}

	static function drawSettings(g:Graphics, s:Int, color:FlxColor):Void
	{
		var cx:Float = s * 0.5;
		var cy:Float = s * 0.5;
		var r:Float = s * 0.32;
		g.drawCircle(cx, cy, r);

		// 8 个齿
		g.beginFill(color);
		var tooth:Float = s * 0.12;
		for (i in 0...8)
		{
			var a:Float = i * Math.PI / 4;
			var tx:Float = cx + Math.cos(a) * (r + tooth * 0.35) - tooth * 0.5;
			var ty:Float = cy + Math.sin(a) * (r + tooth * 0.35) - tooth * 0.5;
			g.drawRect(tx, ty, tooth, tooth);
		}
		// 中心孔
		g.drawCircle(cx, cy, s * 0.11);
		g.endFill();
	}

	static function drawTool(g:Graphics, s:Int):Void
	{
		// 扳手：斜杆 + 头部圆环
		g.moveTo(s * 0.24, s * 0.78);
		g.lineTo(s * 0.66, s * 0.34);
		g.drawCircle(s * 0.72, s * 0.26, s * 0.16);
		g.moveTo(s * 0.18, s * 0.84);
		g.lineTo(s * 0.32, s * 0.7);
	}

	static function drawResume(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.beginFill(color);
		g.moveTo(s * 0.3, s * 0.2);
		g.lineTo(s * 0.82, s * 0.5);
		g.lineTo(s * 0.3, s * 0.8);
		g.lineTo(s * 0.3, s * 0.2);
		g.endFill();
	}

	static function drawRestart(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.drawCircle(s * 0.5, s * 0.5, s * 0.3);
		g.beginFill(color);
		g.moveTo(s * 0.42, s * 0.14);
		g.lineTo(s * 0.68, s * 0.26);
		g.lineTo(s * 0.4, s * 0.38);
		g.lineTo(s * 0.42, s * 0.14);
		g.endFill();
	}

	static function drawDifficulty(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.beginFill(color);
		g.drawRect(s * 0.16, s * 0.56, s * 0.16, s * 0.3);
		g.drawRect(s * 0.42, s * 0.34, s * 0.16, s * 0.52);
		g.drawRect(s * 0.68, s * 0.14, s * 0.16, s * 0.72);
		g.endFill();
	}

	static function drawOptions(g:Graphics, s:Int, color:FlxColor):Void
	{
		var rows:Array<Float> = [s * 0.26, s * 0.5, s * 0.74];
		var knobs:Array<Float> = [s * 0.66, s * 0.34, s * 0.58];
		for (i in 0...rows.length)
		{
			var y:Float = rows[i];
			g.moveTo(s * 0.14, y);
			g.lineTo(s * 0.86, y);
			g.beginFill(color);
			g.drawRect(knobs[i] - s * 0.07, y - s * 0.09, s * 0.14, s * 0.18);
			g.endFill();
		}
	}

	static function drawExit(g:Graphics, s:Int):Void
	{
		g.drawRect(s * 0.14, s * 0.14, s * 0.46, s * 0.72);
		g.moveTo(s * 0.46, s * 0.5);
		g.lineTo(s * 0.88, s * 0.5);
		g.moveTo(s * 0.72, s * 0.34);
		g.lineTo(s * 0.88, s * 0.5);
		g.moveTo(s * 0.72, s * 0.66);
		g.lineTo(s * 0.88, s * 0.5);
	}

	static function drawChevron(g:Graphics, s:Int):Void
	{
		g.moveTo(s * 0.62, s * 0.18);
		g.lineTo(s * 0.34, s * 0.5);
		g.lineTo(s * 0.62, s * 0.82);
	}

	static function drawClose(g:Graphics, s:Int):Void
	{
		g.moveTo(s * 0.22, s * 0.22);
		g.lineTo(s * 0.78, s * 0.78);
		g.moveTo(s * 0.78, s * 0.22);
		g.lineTo(s * 0.22, s * 0.78);
	}

	static function drawCheck(g:Graphics, s:Int):Void
	{
		g.moveTo(s * 0.2, s * 0.52);
		g.lineTo(s * 0.42, s * 0.74);
		g.lineTo(s * 0.82, s * 0.26);
	}

	static function drawDot(g:Graphics, s:Int, color:FlxColor):Void
	{
		g.beginFill(color);
		g.drawCircle(s * 0.5, s * 0.5, s * 0.32);
		g.endFill();
	}
}
