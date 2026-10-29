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
	 * Sorts by FlxBasic's z values。pin 的 flixel fork 连 FlxBasic 都没有 zIndex 字段
	 * （写入已被 InterpEx 吸收为 no-op），这里 Reflect 容错读取：缺失按 0，
	 * 排序退化为"稳定不重排"，与 zIndex 无渲染语义的现状一致。
	 */
	public static inline function sortByZ(order:Int, a:FlxBasic, b:FlxBasic):Int
	{
		if (a == null || b == null) return 0;

		return FlxSort.byValues(order, reflectZ(a), reflectZ(b));
	}

	static function reflectZ(o:FlxBasic):Float
	{
		final z:Dynamic = Reflect.field(o, 'zIndex');
		return (z == null) ? 0 : z;
	}
}
