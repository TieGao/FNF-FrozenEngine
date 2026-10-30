package nmv.utils;

import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.graphics.frames.FlxFrame;
import flxanimate.FlxAnimate;
import flxanimate.animate.FlxSymbol;
import flxanimate.animate.SymbolParameters;
import flxanimate.data.AnimationData.Loop;
import flixel.math.FlxMath;

/**
 * NMV 内容包 Animate 图集的锚点确定性计算。
 *
 * 背景：NMV 用的 flixel-animate 以「整条时间轴包围盒左上角」定锚
 * （Timeline.getWholeBounds：逐根帧、逐可见层、递归嵌套符号求并集），
 * FE pin 的 flxanimate 4.0.0 以舞台原点定锚，两边差一个 (-bounds.x, -bounds.y)。
 *
 * 此前 Character 靠「首帧绘制实测」补偿，三个不稳定源（2026-10-30 面包屑实测）：
 * - 换角色实例（Change Character）重新首帧采样，首绘动画不同量出不同值
 *   （danger 76,343 → -5,-190，角色瞬移）；
 * - 首帧内容不碰包围盒角的角色（parasite 类）量出全错的值（blackparasite -2074）；
 * - 实测值混入相机屏幕空间/裁剪（limbOnScreen 只统计上屏部件，zoom≠1 时畸变）。
 *
 * 这里从已解析的图集对象树按 NMV 同一数学直接算（不含滤镜扩张），不渲染。
 * 返回图集原始坐标系的包围盒 min(x,y)（未乘角色 scale，调用方应用时乘）。
 */
class NmvAtlasAnchor
{
	/** 锚点缓存：键 = 角色 json 的 image 路径（同图集跨实例复用）。值未乘 scale。 */
	public static var cache:Map<String, FlxPoint> = [];

	/** 递归深度护栏：Animate 时间轴理论可成环，防栈溢出。 */
	static inline var MAX_DEPTH:Int = 48;

	/**
	 * 计算根时间轴的全帧包围盒 min。算不出（结构异常/空）返回 null，调用方退回首帧实测。
	 */
	public static function computeAnchor(atlas:FlxAnimate):Null<FlxPoint>
	{
		var anim = atlas.anim;
		if (anim == null || anim.curInstance == null || anim.curInstance.symbol == null) return null;

		var rootName:String = anim.curInstance.symbol.name;
		if (rootName == null || !anim.symbolDictionary.exists(rootName)) return null;
		var root:FlxSymbol = anim.symbolDictionary.get(rootName);
		if (root == null || root.timeline == null) return null;

		var boundsCache:Map<String, FlxRect> = [];
		var result:FlxRect = FlxRect.get();

		var rootFrames:Int = root.timeline.length;
		if (rootFrames <= 0) return null;

		for (f in 0...rootFrames)
		{
			var frameBounds:FlxRect = symbolBoundsAt(root, f, boundsCache, atlas, 0);
			if (frameBounds == null || frameBounds.isEmpty) continue;

			if (result.isEmpty) result.copyFrom(frameBounds);
			else
			{
				var u:FlxRect = result.union(frameBounds);
				result.copyFrom(u);
				u.put();
			}
		}

		if (result.isEmpty) return null;
		return FlxPoint.get(result.x, result.y);
	}

	/**
	 * 符号 timeline 在 frameIndex 帧的局部包围盒（符号自身坐标系，未含父矩阵）。
	 * 按 (符号名#帧号) 记忆化 —— 同一符号帧在多个父帧下重复出现时不重算。
	 */
	static function symbolBoundsAt(sym:FlxSymbol, frameIndex:Int, boundsCache:Map<String, FlxRect>, atlas:FlxAnimate, depth:Int):Null<FlxRect>
	{
		if (sym == null || sym.timeline == null || depth > MAX_DEPTH) return null;

		var key:String = sym.name + '#' + frameIndex;
		if (boundsCache.exists(key))
		{
			var cached:FlxRect = boundsCache.get(key);
			return cached == null ? null : cached.clone();
		}

		// 先占位防环：环上再次遇到本帧直接跳过（返回空）
		boundsCache.set(key, null);

		var rect:FlxRect = FlxRect.get();
		var m:FlxMatrix = new FlxMatrix();

		@:privateAccess
		for (layer in sym.timeline.getList())
		{
			if (!layer.visible) continue;

			var kf = layer.get(frameIndex);
			if (kf == null) continue;

			for (el in kf._elements)
			{
				if (el == null || !el.visible) continue;

				m.copyFrom(el.matrix);
				m.translate(el.x, el.y);

				if (el.bitmap != null)
				{
					var fr = atlas.frames.getByName(el.bitmap);
					if (fr == null || fr.frame == null) continue;
					var w:Float = fr.frame.width;
					var h:Float = fr.frame.height;
					if (fr.angle != FlxFrameAngle.ANGLE_0) // fork 无 rotation 字段，用 FlxFrameAngle 判旋转（宽高互换）
					{
						var t:Float = w; w = h; h = t;
					}
					if (w <= 0 || h <= 0) continue;
					var b:FlxRect = transformedRect(m, FlxRect.get(0, 0, w, h));
					if (rect.isEmpty) rect.copyFrom(b); else rect = unionInto(rect, b);
					b.put();
				}
				else if (el.symbol != null && el.symbol.name != null)
				{
					var nested:FlxSymbol = atlas.anim.symbolDictionary.get(el.symbol.name);
					if (nested == null) continue; // parseElement 同款守卫：符号缺失就跳过

					var nf:Int = resolveNestedFrame(el.symbol, frameIndex, nested);
					var nb:FlxRect = symbolBoundsAt(nested, nf, boundsCache, atlas, depth + 1);
					if (nb == null || nb.isEmpty) continue;

					// 嵌套符号的局部包围盒四角经元素矩阵变换进本层坐标系
					var b:FlxRect = transformedRect(m, nb);
					if (rect.isEmpty) rect.copyFrom(b); else rect = unionInto(rect, b);
					b.put();
				}
			}
		}

		boundsCache.set(key, rect.clone());
		return rect.isEmpty ? null : rect.clone();
	}

	/** union 的就地版（flixel 的 FlxRect.union 返回新对象、不改 this）。 */
	static function unionInto(target:FlxRect, other:FlxRect):FlxRect
	{
		var minX:Float = Math.min(target.x, other.x);
		var minY:Float = Math.min(target.y, other.y);
		var maxX:Float = Math.max(target.x + target.width, other.x + other.width);
		var maxY:Float = Math.max(target.y + target.height, other.y + other.height);
		target.set(minX, minY, maxX - minX, maxY - minY);
		return target;
	}

	/**
	 * 嵌套符号当帧解析：与 flxanimate 4.0.0 FlxElement.updateRender 同一语义
	 * （Loop 取模、PlayOnce 截断、SingleFrame 固定首帧）。
	 */
	static function resolveNestedFrame(params:SymbolParameters, frameIndex:Int, nested:FlxSymbol):Int
	{
		var len:Int = nested.timeline != null ? nested.timeline.length : 0;
		var curFF:Int = frameIndex + params.firstFrame;

		if (len <= 0) return params.firstFrame;

		// Loop 枚举的类型名与构造器同名，pattern 匹配在部分 Haxe 版本下有解析歧义，改按名匹配
		final loopName:String = params.loop.getName();
		if (loopName == 'Loop') return curFF % len;
		if (loopName == 'PlayOnce') return Std.int(FlxMath.bound(curFF, 0, len - 1));
		return params.firstFrame;
	}

	/** 矩形四角经矩阵变换后的包围盒。 */
	static function transformedRect(m:FlxMatrix, r:FlxRect):FlxRect
	{
		var minX:Float = Math.POSITIVE_INFINITY, minY:Float = Math.POSITIVE_INFINITY;
		var maxX:Float = Math.NEGATIVE_INFINITY, maxY:Float = Math.NEGATIVE_INFINITY;
		var x2:Float = r.x + r.width;
		var y2:Float = r.y + r.height;
		for (cx in [r.x, x2])
		{
			for (cy in [r.y, y2])
			{
				var tx:Float = cx * m.a + cy * m.c + m.tx;
				var ty:Float = cx * m.b + cy * m.d + m.ty;
				if (tx < minX) minX = tx;
				if (ty < minY) minY = ty;
				if (tx > maxX) maxX = tx;
				if (ty > maxY) maxY = ty;
			}
		}
		return FlxRect.get(minX, minY, maxX - minX, maxY - minY);
	}
}
