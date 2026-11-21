package shapeEx;

import backend.Cache;

/**
 * 斜切四边形（平行四边形）精灵。
 *
 * 画法照 shapeEx.Rect 的范式：Shape.graphics 光栅化 → BitmapData → FlxGraphic → Cache 键缓存。
 * **纯白填充**，颜色交给 `color` —— 这样 hover 用 FlxTween.color 过渡不会被乘暗。
 * 顶点（整体右倾）：上边从 x=skew 到 x=w，下边从 x=0 到 x=w-skew。
 * 命中测试不要用包围盒：containsLocal() 按上下边随 y 线性插值算左右边界。
 *
 * 传 `outline` > 0 时改为**只画这么粗的描边**（内部透明）：
 * 半透明卡面叠在图上时不能用"白色大块垫在下面"的老办法 —— 底下那层白会透上来把卡面冲淡。
 * 描边图案压在卡面之上，alpha 独立控制。
 */
class SlantQuad extends FlxSprite
{
	public var skew(default, null):Float = 0;
	public var quadWidth(default, null):Float = 0;
	public var quadHeight(default, null):Float = 0;
	/** 描边粗细；0 = 实心块 */
	public var outline(default, null):Float = 0;

	public function new(X:Float = 0, Y:Float = 0, width:Float = 0, height:Float = 0, skew:Float = 20,
			Color:FlxColor = FlxColor.WHITE, ?Alpha:Float = 1, ?outline:Float = 0)
	{
		super(X, Y);

		this.skew = skew;
		this.quadWidth = width;
		this.quadHeight = height;
		this.outline = (outline == null || outline <= 0) ? 0 : outline;

		var key:String = cacheKey(width, height, skew, this.outline);
		if (!Cache.checkFrame(key)) addCache(width, height, skew, this.outline);
		frames = Cache.getFrame(key);

		antialiasing = ClientPrefs.data.antialiasing;
		color = Color;
		alpha = Alpha;
	}

	/** 缓存键必须拼上 skew（和描边粗细）—— 否则不同斜度 / 实心与空心会撞同一张图。 */
	public static function cacheKey(width:Float, height:Float, skew:Float, outline:Float = 0):String
	{
		var base:String = 'slant-w' + Std.int(width) + '-h' + Std.int(height) + '-s' + Std.int(skew);
		return (outline > 0) ? base + '-o' + Std.int(outline) : base;
	}

	function addCache(width:Float, height:Float, skew:Float, outline:Float):Void
	{
		var bitmap:BitmapData = (outline > 0)
			? drawOutlineQuad(width, height, skew, outline)
			: drawQuad(width, height, skew);
		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap);
		graphic.persist = true;
		graphic.destroyOnNoUse = true;
		Cache.setFrame(cacheKey(width, height, skew, outline), {graphic: graphic, frame: null});
	}

	static function drawQuad(width:Float, height:Float, skew:Float):BitmapData
	{
		var w:Int = Std.int(width);
		var h:Int = Std.int(height);
		if (w < 1) w = 1;
		if (h < 1) h = 1;

		var shape:Shape = new Shape();
		var g = shape.graphics;

		// 普通 fill 路径在 cairo 后端是 SUBPIXEL 抗锯齿；drawTriangles 那边是 NONE，别换。
		g.beginFill(0xFFFFFF);
		g.moveTo(skew, 0);
		g.lineTo(w, 0);
		g.lineTo(w - skew, h);
		g.lineTo(0, h);
		g.lineTo(skew, 0);
		g.endFill();

		var bitmap:BitmapData = new BitmapData(w, h, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}

	/**
	 * 空心描边：线宽中心压在四边形边界上（向内缩半个线宽），
	 * 外半圈正好落在图案边缘 → 图案尺寸与实心版本一致，两者可以同位置叠放。
	 */
	static function drawOutlineQuad(width:Float, height:Float, skew:Float, thickness:Float):BitmapData
	{
		var w:Int = Std.int(width);
		var h:Int = Std.int(height);
		if (w < 1) w = 1;
		if (h < 1) h = 1;

		var t:Float = Math.min(thickness, Math.min(w, h) * 0.5);
		var half:Float = t * 0.5;
		// 斜边按"垂直方向 t/2"折算成水平内缩；直接按 x 内缩会让斜边比上下边粗
		var innerH:Float = h - t;
		var insetX:Float = (innerH <= 0) ? 0 : half * (Math.sqrt(skew * skew + innerH * innerH) / innerH);

		var shape:Shape = new Shape();
		var g = shape.graphics;
		g.lineStyle(t, 0xFFFFFF, 1);
		g.moveTo(skew + insetX, half);
		g.lineTo(w - insetX, half);
		g.lineTo(w - skew - insetX, h - half);
		g.lineTo(insetX, h - half);
		g.lineTo(skew + insetX, half);

		var bitmap:BitmapData = new BitmapData(w, h, true, 0);
		bitmap.draw(shape);
		return bitmap;
	}

	/** 本地坐标命中（px/py 相对本精灵左上角，未计 offset/scale）。 */
	public function containsLocal(px:Float, py:Float):Bool
	{
		var w:Float = quadWidth;
		var h:Float = quadHeight;
		if (w <= 0 || h <= 0) return false;
		if (py < 0 || py > h) return false;

		// 左边界：y=0 时 x=skew，y=h 时 x=0
		var left:Float = skew * (1 - py / h);
		// 右边界：y=0 时 x=w，y=h 时 x=w-skew
		var right:Float = w - skew * (py / h);
		return px >= left && px <= right;
	}

	/** 屏幕坐标命中（用于直接喂 FlxG.mouse.x / FlxG.mouse.y）。 */
	public function containsScreen(px:Float, py:Float):Bool
	{
		var localX:Float = px - x;
		var localY:Float = py - y;
		if (scale.x != 0) localX /= scale.x;
		if (scale.y != 0) localY /= scale.y;
		return containsLocal(localX, localY);
	}
}
