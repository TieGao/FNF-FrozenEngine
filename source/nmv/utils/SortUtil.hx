package nmv.utils;

import flixel.FlxBasic;
import flixel.util.FlxSort;

/**
 * NMV funkin.utils.SortUtil 移植。
 * svSort 未移植：参数是 modchart.SpeedEvent，modchart 系统整体未移植（见 52 号清单四档）。
 */
class SortUtil
{
	/** Sorts by floats */
	public static inline function laserSort(a:Float, b:Float):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, a, b);
	}

	/**
	 * Sorts by FlxBasic's z values。pin 的 flixel fork 连 FlxBasic 都没有 zIndex 字段，
	 * 脚本写入被 InterpEx 记进旁表（zIndexStore）——这里必须读旁表，否则
	 * `group.sort(SortUtil.sortByZ)` 全按 0 比较、等于不排序：finale 血条的
	 * bg(z=0) 是最后 add 的，不排序就盖住 leftBar/rightBar(z=1)，整条血条只剩底图。
	 */
	public static inline function sortByZ(order:Int, a:FlxBasic, b:FlxBasic):Int
	{
		if (a == null || b == null) return 0;

		return FlxSort.byValues(order, effectiveZ(a), effectiveZ(b));
	}

	static function effectiveZ(o:FlxBasic):Float
	{
		final z:Dynamic = Reflect.field(o, 'zIndex');
		if (z != null) return z;
		return nmv.scripts.InterpEx.getZ(o);
	}
}
