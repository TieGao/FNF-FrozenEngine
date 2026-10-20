package backend;

/**
 * Metro / Win8 动效曲线。
 *
 * 对应 Win8 设计规范里的两条 cubic-bezier：
 *  - `ENTRANCE`：入场用，先快后慢 —— 元素迅速进入，再缓慢落定。
 *  - `EXIT`：出场用，先慢后快 —— 先停顿一下再迅速离场，不抢注意力。
 *
 * 用法：`FlxTween.tween(..., {ease: MetroEase.ENTRANCE})`。
 */
class MetroEase
{
	/** Win8 entrance：cubic-bezier(0.1, 0.9, 0.2, 1.0) */
	public static var ENTRANCE:Float->Float = bezier(0.1, 0.9, 0.2, 1.0);

	/** Win8 exit：cubic-bezier(0.7, 0.0, 1.0, 0.5) */
	public static var EXIT:Float->Float = bezier(0.7, 0.0, 1.0, 0.5);

	/**
	 * 通用 cubic-bezier(x1, y1, x2, y2) 缓动，与 CSS 的曲线定义一致。
	 * 先按 x 反解贝塞尔参数 t（牛顿迭代，跑飞时二分兜底），再求 y。
	 */
	public static function bezier(x1:Float, y1:Float, x2:Float, y2:Float):Float->Float
	{
		var cx = 3 * x1;
		var bx = 3 * (x2 - x1) - cx;
		var ax = 1 - cx - bx;
		var cy = 3 * y1;
		var by = 3 * (y2 - y1) - cy;
		var ay = 1 - cy - by;

		return function(x:Float):Float {
			if (x <= 0) return 0;
			if (x >= 1) return 1;

			var t = x;
			var solved = false;
			for (_ in 0...8)
			{
				var fx = ((ax * t + bx) * t + cx) * t - x;
				if (Math.abs(fx) < 1e-5)
				{
					solved = true;
					break;
				}
				var dfx = (3 * ax * t + 2 * bx) * t + cx;
				if (Math.abs(dfx) < 1e-6) break;
				t -= fx / dfx;
				if (t < 0 || t > 1) break;
			}

			if (!solved)
			{
				var lo = 0.0;
				var hi = 1.0;
				t = x;
				for (_ in 0...20)
				{
					var fx = ((ax * t + bx) * t + cx) * t - x;
					if (Math.abs(fx) < 1e-5) break;
					if (fx > 0) hi = t;
					else lo = t;
					t = (lo + hi) * 0.5;
				}
			}

			return ((ay * t + by) * t + cy) * t;
		};
	}
}
