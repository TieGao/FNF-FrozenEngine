package nmv.utils;

import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flxanimate.FlxAnimate;
import flxanimate.animate.FlxElement;
import flxanimate.animate.FlxKeyFrame;
import flxanimate.animate.FlxLayer;
import flxanimate.data.AnimationData.LayerType;
import flxanimate.animate.FlxSymbol;
import flxanimate.animate.SymbolParameters;

/**
 * NMV 内容包 Animate 图集的**逐动画定锚包围盒**。
 *
 * 两边的定锚原点不一样，这是角色整体偏移的唯一来源：
 * - NMV 用的 flixel-animate（MaybeMaru）在 drawAnimate 里先做
 *   `matrix.translate(-timeline._bounds.x, -timeline._bounds.y)`，而 `timeline` 会被控制器
 *   在每次播放时切成**当前动画自己的时间线**（FlxAnimateController.set_frameIndex），
 *   所以它按"该动画符号整条时间轴的包围盒左上角"钉位；
 * - 移植端用的 flxanimate（Dot-Stuff）不认包围盒，按 Animate 舞台原点钉位。
 * 差值就是 `_bounds`，本类负责把它算出来交给 Character 折进 offset。
 *
 * 计算是对 MaybeMaru `Timeline.getWholeBounds` 的逐行移植（不渲染、不运行时采样）：
 * 遍历符号时间线的每一帧 → 每层 → 每个元素，位图元素取"帧矩形 + 帧 offset"，
 * 嵌套符号按 `firstFrame + 相对帧` 递归。包围盒是符号坐标系里的常量，
 * 与角色 scale 无关（两边库的 translate 都是 openfl 的裸加，锚落在屏幕空间）。
 */
class NmvAtlasAnchor
{
	/** 包围盒缓存：键 = 图集路径|动画名。值可为 null（解析不出，别反复算）。 */
	static var cache:Map<String, Null<FlxRect>> = [];

	/** 递归深度护栏：Animate 时间轴理论可成环，防栈溢出。 */
	static inline var MAX_DEPTH:Int = 32;

	/**
	 * 动画实际播放符号的整条时间轴包围盒（符号坐标系）。
	 * 算不出（结构异常 / 空动画）返回 null。
	 *
	 * **按符号缓存，不按动画**：NMV 的三条注册路径（addBySymbol / addBySymbolIndices /
	 * addByFrameLabel）都把 `anim.timeline` 设成**被引用符号自己的时间线**，indices 与
	 * 帧标签只决定播哪几帧，不影响 `_bounds` —— 同一符号的所有动画共用一个包围盒。
	 */
	public static function getBounds(atlas:FlxAnimate, atlasKey:String, animName:String):Null<FlxRect>
	{
		if (atlas == null || atlas.anim == null || animName == null) return null;

		final symName:Null<String> = resolveSymbol(atlas, animName);
		if (symName == null)
		{
			backend.Bread.crumb('nmv bounds ' + atlasKey + '|' + animName + ' sym=<none>');
			return null;
		}

		final key:String = (atlasKey == null ? '' : atlasKey) + '|' + symName;
		if (cache.exists(key)) return cache.get(key);

		var result:Null<FlxRect> = null;
		final sym:FlxSymbol = atlas.anim.symbolDictionary.get(symName);
		if (sym != null && sym.timeline != null)
		{
			final memo:Map<String, Null<FlxRect>> = [];
			final total:Int = sym.timeline.totalFrames;
			var union:Null<FlxRect> = null;
			for (f in 0...total)
			{
				final fb:Null<FlxRect> = frameBounds(sym, f, memo, atlas, 0);
				if (fb == null || fb.isEmpty) continue;
				if (union == null) union = fb;
				else union = expand(union, fb);
			}
			if (union != null) result = union;
			backend.Bread.crumb('nmv bounds ' + key + ' via=' + animName + ' frames=' + total + ' x=' + Std.int(result == null ? 0 : result.x)
				+ ' y=' + Std.int(result == null ? 0 : result.y) + ' w=' + Std.int(result == null ? 0 : result.width) + ' h='
				+ Std.int(result == null ? 0 : result.height));
		}

		cache.set(key, result);
		return result;
	}

	/**
	 * 动画名 → 实际播放的**源符号**名。
	 *
	 * 四条注册路径（exact / prefix / indices / 帧标签包装）都会把结果写进 `animsMap`，
	 * 且 `animsMap[name].instance.symbol.name` 就是符号字典里的键，所以统一走这里。
	 * 注意不能对 animsMap 用 Reflect —— 它是 hxcpp 原生 StringMap，Reflect 取不到键。
	 *
	 * 移植端的 indices / 帧标签走"safe 包装符号"（键 = `<源符号>#<动画>`，时间线只含
	 * 选中的那几帧）。NMV 那边这两种情况的时间线仍是**整个源符号**，所以要拆回 `#` 前面那段。
	 */
	static function resolveSymbol(atlas:FlxAnimate, animName:String):Null<String>
	{
		final dict:Map<String, FlxSymbol> = atlas.anim.symbolDictionary;
		if (dict == null) return null;

		var name:Null<String> = null;
		@:privateAccess
		{
			final stuff = atlas.anim.animsMap.get(animName);
			if (stuff != null && stuff.instance != null && stuff.instance.symbol != null) name = stuff.instance.symbol.name;
		}
		if (name == null || name.length == 0) name = animName;

		// 包装符号（`@<源符号>@<动画>`）拆回源符号。
		final full:String = name;
		var base:String = full;
		if (name.charCodeAt(0) == '@'.code)
		{
			final second:Int = name.indexOf('@', 1);
			if (second > 1) base = name.substring(1, second);
		}

		// 【2026-11-01 二次修正 · 不要再加"只改锚点"的分支】
		// 曾在 `base` 同时是主符号帧标签时直接返回主符号，想让 `bf-fall` 的 `sing*-loop`
		// 与普通唱姿共用主符号包围盒。**这个思路是错的，实测无效**（09:38 日志里
		// `singRIGHT-loop` 仍 bw=466）：
		//  - 判据 `atlas.anim.getFrameLabel` 走的是 `curSymbol`，播放 `-loop` 时 curSymbol 是
		//    包装符号、没有帧标签 → 判定恒 false；
		//  - 就算判对，锚点与内容必须**同源**才能对齐：主符号上那条实例矩阵带
		//    (-211.6,-241.05) 的打包位移，只把锚点换成主符号的 (-683,-506) 而内容仍画子符号，
		//    会把画面额外推开 ~471/265 像素（比原来更偏）。
		// 正解在注册端：`Character.addFromFrameLabelIndices` 让"name 同时是帧标签"的
		// indices 动画走主符号时间线（= NMV `addAnimByFrameLabelIndices`），于是这里
		// `base` 天然就是主符号，无需任何特判。

		if (dict.exists(base)) return base;
		if (dict.exists(full)) return full;
		return dict.exists(animName) ? animName : null;
	}

	/**
	 * 符号的唯一键：`FlxSymbolDictionary.addSymbol` 会把 name 截成末段、目录存进 location，
	 * 记忆化必须带上 location，否则同名不同目录的符号会互相串。
	 */
	static inline function symbolKey(sym:FlxSymbol):String
	{
		final loc:String = sym.location;
		return (loc == null || loc.length == 0) ? sym.name : loc + '/' + sym.name;
	}

	/** 单层在某一帧的包围盒（不含遮罩处理，供遮罩层与被遮罩层共用）。 */
	static function layerBounds(layer:FlxLayer, frameIndex:Int, memo:Map<String, Null<FlxRect>>, atlas:FlxAnimate, depth:Int):Null<FlxRect>
	{
		final kf:FlxKeyFrame = layer.get(frameIndex);
		if (kf == null) return null;

		var out:Null<FlxRect> = null;
		for (el in kf.getList())
		{
			if (el == null || !el.visible) continue;

			final eb:Null<FlxRect> = elementBounds(el, frameIndex - kf.index, memo, atlas, depth);
			if (eb == null || eb.isEmpty) continue;
			out = (out == null) ? eb : expand(out, eb);
		}
		return out;
	}

	/** 按层名找遮罩层（Clipped 层的 Clpb 存的是层名）。 */
	static function findLayer(sym:FlxSymbol, name:String):Null<FlxLayer>
	{
		if (name == null || sym.timeline == null) return null;
		for (layer in sym.timeline.getList())
		{
			if (layer != null && layer.name == name) return layer;
		}
		return null;
	}

	/** 两矩形求交；无交集返回 null。 */
	static function intersect(a:FlxRect, b:FlxRect):Null<FlxRect>
	{
		if (a == null || b == null) return a;
		final x1:Float = Math.max(a.x, b.x);
		final y1:Float = Math.max(a.y, b.y);
		final x2:Float = Math.min(a.x + a.width, b.x + b.width);
		final y2:Float = Math.min(a.y + a.height, b.y + b.height);
		if (x2 <= x1 || y2 <= y1) return null;
		return new FlxRect(x1, y1, x2 - x1, y2 - y1);
	}

	/**
	 * 符号在某一帧的局部包围盒（符号自身坐标系）。按 符号键#帧号 记忆化，环上先占位。
	 */
	static function frameBounds(sym:FlxSymbol, frameIndex:Int, memo:Map<String, Null<FlxRect>>, atlas:FlxAnimate, depth:Int):Null<FlxRect>
	{
		if (sym == null || sym.timeline == null || depth > MAX_DEPTH) return null;

		final key:String = symbolKey(sym) + '#' + frameIndex;
		if (memo.exists(key)) return memo.get(key);
		memo.set(key, null);

		var out:Null<FlxRect> = null;
		for (layer in sym.timeline.getList())
		{
			if (layer == null || !layer.visible) continue;

			// 遮罩语义（MaybeMaru Timeline.getBounds + Frame.getBounds 同款）：
			// Clipper 层只当遮罩用、不参与包围盒（NMV 把它 visible=false）；
			// Clipped 层要与它的遮罩层求交。不做这一步，被遮罩的零件会按"整块未裁切"
			// 撑大包围盒，每个姿势撑得还不一样 → 角色逐姿势位移（white 的 mic hand 家族）。
			var clippedBy:String = null;
			switch (layer.type)
			{
				case Clipper:
					continue;
				case Clipped(n):
					clippedBy = n;
				case _:
			}

			var lr:Null<FlxRect> = layerBounds(layer, frameIndex, memo, atlas, depth);
			if (lr == null) continue;

			if (clippedBy != null)
			{
				final masker = findLayer(sym, clippedBy);
				if (masker != null)
				{
					lr = intersect(lr, layerBounds(masker, frameIndex, memo, atlas, depth));
					if (lr == null) continue;
				}
			}

			out = (out == null) ? lr : expand(out, lr);
		}

		if (out != null) memo.set(key, out);
		return out;
	}

	/** 单个元素在符号坐标系里的包围盒（相对帧只对嵌套符号有意义）。 */
	static function elementBounds(el:FlxElement, relFrame:Int, memo:Map<String, Null<FlxRect>>, atlas:FlxAnimate, depth:Int):Null<FlxRect>
	{
		final m:FlxMatrix = new FlxMatrix();
		m.copyFrom(el.matrix);
		m.translate(el.x, el.y);

		if (el.bitmap != null)
		{
			final fr:FlxFrame = atlas.frames.getByName(el.bitmap);
			if (fr == null || fr.frame == null) return null;

			// 帧矩形 + 帧 offset（等价 FlxFrame.prepareBlitMatrix(false)：只做 translate(offset)）
			final w:Float = fr.frame.width;
			final h:Float = fr.frame.height;
			if (w <= 0 || h <= 0) return null;

			return transformRect(m, new FlxRect(fr.offset.x, fr.offset.y, w, h));
		}

		if (el.symbol != null && el.symbol.name != null && el.symbol.name.length > 0)
		{
			// Dot-Stuff 的符号引用存在 SymbolParameters.name（instance 是 MovieClip 实例名）
			final nested:FlxSymbol = atlas.anim.symbolDictionary.get(el.symbol.name);
			if (nested == null) return null;

			final nb:Null<FlxRect> = frameBounds(nested, nestedFrame(el.symbol, relFrame, nested), memo, atlas, depth + 1);
			if (nb == null || nb.isEmpty) return null;
			return transformRect(m, nb);
		}

		return null;
	}

	/**
	 * 嵌套符号当帧解析：MaybeMaru 语义 = firstFrame + 相对帧，Loop 取模 / PlayOnce 截断 /
	 * SingleFrame 固定首帧。
	 */
	static function nestedFrame(params:SymbolParameters, relFrame:Int, nested:FlxSymbol):Int
	{
		final total:Int = (nested.timeline != null) ? nested.timeline.totalFrames : 0;
		if (total <= 0) return 0;

		final f:Int = params.firstFrame + relFrame;
		final loopName:String = params.loop.getName().toLowerCase();
		if (loopName.indexOf('single') != -1) return params.firstFrame;
		if (loopName.indexOf('playonce') != -1) return Std.int(FlxMath.bound(f, 0, total - 1));
		return ((f % total) + total) % total;
	}

	/** 矩形四角经矩阵变换后的包围盒。 */
	static function transformRect(m:FlxMatrix, r:FlxRect):FlxRect
	{
		final x2:Float = r.x + r.width;
		final y2:Float = r.y + r.height;

		var minX:Float = Math.POSITIVE_INFINITY;
		var minY:Float = Math.POSITIVE_INFINITY;
		var maxX:Float = Math.NEGATIVE_INFINITY;
		var maxY:Float = Math.NEGATIVE_INFINITY;

		for (cx in [r.x, x2])
		{
			for (cy in [r.y, y2])
			{
				final tx:Float = cx * m.a + cy * m.c + m.tx;
				final ty:Float = cx * m.b + cy * m.d + m.ty;
				if (tx < minX) minX = tx;
				if (ty < minY) minY = ty;
				if (tx > maxX) maxX = tx;
				if (ty > maxY) maxY = ty;
			}
		}
		return new FlxRect(minX, minY, maxX - minX, maxY - minY);
	}

	/** 两个矩形的并集（新对象）。 */
	static function expand(a:FlxRect, b:FlxRect):FlxRect
	{
		final minX:Float = Math.min(a.x, b.x);
		final minY:Float = Math.min(a.y, b.y);
		final maxX:Float = Math.max(a.x + a.width, b.x + b.width);
		final maxY:Float = Math.max(a.y + a.height, b.y + b.height);
		return new FlxRect(minX, minY, maxX - minX, maxY - minY);
	}
}
