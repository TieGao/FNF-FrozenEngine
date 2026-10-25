package nmv.scripts.preset;

import flixel.util.FlxColor;

/**
 * preset 里注册的 FlxColor：Int 值封装。
 *
 * abstract 的常量/静态方法在 hscript 反射路径下不稳（NMV 原版同样用
 * ScriptedFlxColor 的 Int 封装，FE 的 psychlua.HScript 也有 CustomFlxColor），
 * 这里保持常量名与 flixel.FlxColor 一致，值用 Int。
 */
class ScriptFlxColor
{
	public static inline function fromInt(value:Int):Int
		return cast FlxColor.fromInt(value);

	public static inline function fromRGB(red:Int, green:Int, blue:Int, alpha:Int = 255):Int
		return cast FlxColor.fromRGB(red, green, blue, alpha);

	public static inline function fromRGBFloat(red:Float, green:Float, blue:Float, alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(red, green, blue, alpha);

	public static inline function fromCMYK(c:Float, m:Float, y:Float, k:Float, alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(c, m, y, k, alpha);

	public static inline function fromHSB(hue:Float, sat:Float, brt:Float, alpha:Float = 1):Int
		return cast FlxColor.fromHSB(hue, sat, brt, alpha);

	public static inline function fromHSL(hue:Float, sat:Float, light:Float, alpha:Float = 1):Int
		return cast FlxColor.fromHSL(hue, sat, light, alpha);

	public static inline function fromString(str:String):Int
		return cast FlxColor.fromString(str);

	public static inline function getRed(color:Int):Int
		return cast FlxColor.fromInt(color).red;

	public static inline function getGreen(color:Int):Int
		return cast FlxColor.fromInt(color).green;

	public static inline function getBlue(color:Int):Int
		return cast FlxColor.fromInt(color).blue;

	public static inline function interpolate(a:Int, b:Int, factor:Float = 1):Int
	{
		var ca:FlxColor = FlxColor.fromInt(a);
		var cb:FlxColor = FlxColor.fromInt(b);

		return cast FlxColor.fromRGBFloat(
			ca.redFloat + (cb.redFloat - ca.redFloat) * factor,
			ca.greenFloat + (cb.greenFloat - ca.greenFloat) * factor,
			ca.blueFloat + (cb.blueFloat - ca.blueFloat) * factor,
			ca.alphaFloat + (cb.alphaFloat - ca.alphaFloat) * factor);
	}

	// 常量与 flixel.FlxColor 同名同值，仅供脚本读取
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;
}
