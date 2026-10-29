package nmv.utils;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;

/**
 * NMV funkin.utils.MathUtil 原样移植（语料 fpsLerp 等）。
 */
class MathUtil
{
	/**
	 * Get the logarithm of a value with a given base.
	 * @return `log_base(value)`
	 */
	public static function logBase(base:Float, value:Float):Float
	{
		return Math.log(value) / Math.log(base);
	}

	/**
	 * Remaps a value from a range to a new range (akin to `FlxMath.remapToRange`).
	 */
	public static inline function scale(x:Float, l1:Float, h1:Float, l2:Float, h2:Float):Float
	{
		return ((x - l1) * (h2 - l2) / (h1 - l1) + l2);
	}

	/**
	 * Clamps/Bounds a value between a range (akin to `FlxMath.bound`).
	 */
	public static inline function clamp(n:Float, l:Float, h:Float)
	{
		if (n > h) n = h;
		if (n < l) n = l;
		return n;
	}

	/**
	 * Creates or uses a provided point and rotates it around a given `x` and `y` by radians.
	 * @return A rotated FlxPoint
	 */
	public static function rotate(x:Float, y:Float, angle:Float, ?point:FlxPoint):FlxPoint
	{
		final p = point ?? FlxPoint.weak();
		p.set((x * Math.cos(angle)) - (y * Math.sin(angle)), (x * Math.sin(angle)) + (y * Math.cos(angle)));
		return p;
	}

	public static inline function quantizeAlpha(f:Float, interval:Float)
	{
		return Std.int((f + interval / 2) / interval) * interval;
	}

	public static inline function quantize(f:Float, interval:Float)
	{
		return Std.int((f + interval / 2) / interval) * interval;
	}

	/** FlxMath.lerp but accounts for FPS. */
	public static inline function fpsLerp(v1:Float, v2:Float, ratio:Float)
	{
		return FlxMath.lerp(v1, v2, FlxMath.getElapsedLerp(ratio, FlxG.elapsed));
	}

	/**
	 * A frame independent lerp (primary purpose is for the camera); decay should be around 1 - 25.
	 */
	public static function decayLerp(a:Float, b:Float, decay:Float, elapsed:Float)
	{
		return b + (a - b) * Math.exp(-decay * elapsed);
	}

	/**
	 * Similar to FlxMath.wrap, but also supports floats.
	 */
	public static inline function wrap(n:Float, min:Float, max:Float):Float
	{
		return (euclideanMod(n - min, max - min + 1) + min);
	}

	/**
	 * Euclidean division based modulo (result never negative, unlike Haxe's `%`).
	 */
	public static inline function euclideanMod(n:Float, div:Float):Float
	{
		var mod:Float = (n % div);
		return (mod < 0 ? mod + Math.abs(div) : mod);
	}

	/**
	 * Alternative to `FlxMath.roundDecimal` but floors the value rather than rounding it.
	 */
	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.floor(value);

		var tempMult:Float = 1;
		for (i in 0...decimals)
			tempMult *= 10;

		return Math.floor(value * tempMult) / tempMult;
	}

	/**
	 * Makes a number array (`min` default 0, exclusive `max`).
	 */
	public static inline function numberArray(?min:Int, max:Int):Array<Int>
	{
		if (min == null) min = 0;
		return [for (i in min...max) i];
	}
}
