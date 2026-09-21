package backend;

import openfl.display.Shape;
import openfl.display.BitmapData;

/**
 * 控件主题（"按键元素"的风格）
 *
 * 决定 options/objects/backend 下那批控件（BoolButton / NumButton / StringSelect /
 * ColorSelect / OptionButton）到底按 Win10 风格还是 Win8 风格绘制。
 *
 * 数据源：ClientPrefs.data.controlTheme —— 'auto' 跟随界面 / 'win10' / 'win8'。
 *
 * 界面在 create() 里调用 setSurface() 声明自己的风格，在 destroy() 里用返回的旧值
 * 调 restoreSurface() 还原。这样嵌套打开（Win8 边栏里再开 Win10 设置页）也不会串味。
 *
 * 配色不写死在这里：深浅色仍然跟随 UITheme.isLight，本类只负责"Win8 长什么样"。
 */
class UIControlTheme
{
	// ---------------------------------------------------------
	// 模式常量
	// ---------------------------------------------------------
	public static inline var AUTO:String = 'auto';
	public static inline var WIN10:String = 'win10';
	public static inline var WIN8:String = 'win8';

	/** 当前正在构建/显示的界面风格（由界面自己声明） */
	public static var surface(default, null):String = WIN10;

	// ---------------------------------------------------------
	// 偏好解析
	// ---------------------------------------------------------
	/** 读取并归一化 ClientPrefs.data.controlTheme */
	public static function pref():String
	{
		return normalizePref(ClientPrefs.data != null ? ClientPrefs.data.controlTheme : null);
	}

	public static function normalizePref(v:String):String
	{
		if (v == null) return AUTO;
		switch (v.trim().toLowerCase())
		{
			case WIN8, 'windows8', 'windows_8', '8': return WIN8;
			case WIN10, 'windows10', 'windows_10', '10': return WIN10;
			default: return AUTO;
		}
	}

	/** 当前真正生效的控件风格（'win10' 或 'win8'） */
	public static function current():String
	{
		var p:String = pref();
		if (p == AUTO) return surface;
		return p;
	}

	public static function isWin8():Bool
		return current() == WIN8;

	/** 当前是否"界面风格与控件风格一致"（自动模式） */
	public static function isAuto():Bool
		return pref() == AUTO;

	/**
	 * 声明当前界面风格，返回旧值（供 restoreSurface 还原）。
	 * @param s 'win10' 或 'win8'
	 */
	public static function setSurface(s:String):String
	{
		var old:String = surface;
		surface = (s == WIN8) ? WIN8 : WIN10;
		return old;
	}

	public static function restoreSurface(old:String):Void
	{
		surface = (old == WIN8) ? WIN8 : WIN10;
	}

	/** 界面风格的中文说明，给选项页做描述用 */
	public static function describe():String
	{
		return switch (pref())
		{
			case WIN10: 'Always use Windows 10 style buttons';
			case WIN8: 'Always use Windows 8 style buttons';
			default: 'Each interface uses its own style (Win10 UI -> Win10, Charm bar -> Win8)';
		}
	}

	// ---------------------------------------------------------
	// 几何
	// ---------------------------------------------------------
	/** Win8 一律方角 */
	public static function radius(win10Radius:Float):Float
		return isWin8() ? 0 : win10Radius;

	/** Win8 控件要画描边 */
	public static function hasBorder():Bool
		return isWin8();

	public static inline var BORDER_THICKNESS:Float = 2;

	// ---------------------------------------------------------
	// Win8 调色板（深浅色跟随 UITheme）
	// ---------------------------------------------------------
	public static function accent():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFF2672EC : 0xFF3B8EF0;
	}

	public static function accentHover():FlxColor
		return UITheme.hoverTint(accent());

	public static function accentPress():FlxColor
		return UITheme.pressTint(accent());

	public static function face():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFE8E8E8 : 0xFF2B2B2B;
	}

	public static function faceHover():FlxColor
		return UITheme.hoverTint(face());

	public static function facePress():FlxColor
		return UITheme.pressTint(face());

	public static function border():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFF3A3A3A : 0xFF9A9A9A;
	}

	public static function text():FlxColor
	{
		UITheme.ensure();
		return UITheme.textPrimary;
	}

	public static function textSecondary():FlxColor
	{
		UITheme.ensure();
		return UITheme.textSecondary;
	}

	public static function track():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFBDBDBD : 0xFF555555;
	}

	public static function knob():FlxColor
		return accent();

	public static function knobHover():FlxColor
		return accentHover();

	public static function knobPress():FlxColor
		return accentPress();

	public static function off():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFBDBDBD : 0xFF666666;
	}

	/** 强调色底上的文字色 */
	public static function onAccent():FlxColor
		return 0xFFFFFFFF;

	// ---------- Charm 边栏专用 ----------
	public static function railBG():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFF2F2F2 : 0xFF1A1A1A;
	}

	public static function railHover():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFE0E0E0 : 0xFF333333;
	}

	public static function panelBG():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFFFFFFF : 0xFF1F1F1F;
	}

	public static function panelHeader():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFEDEDED : 0xFF2B2B2B;
	}

	public static function divider():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFDCDCDC : 0xFF3F3F3F;
	}

	/** 键盘选中行的底色 */
	public static function rowSelected():FlxColor
	{
		return FlxColor.interpolate(panelBG(), accent(), 0.22);
	}

	public static function overlay():FlxColor
	{
		UITheme.ensure();
		return UITheme.isLight ? 0xFFFFFFFF : 0xFF000000;
	}

	public static function overlayAlpha():Float
	{
		UITheme.ensure();
		return UITheme.isLight ? 0.4 : 0.62;
	}

	// ---------------------------------------------------------
	// 绘制辅助
	// ---------------------------------------------------------
	/**
	 * 生成一个"空心方框"精灵（白色填充，靠 color 染色）。
	 * 用于给 Win8 控件描边——注意 shapeEx.Rect 的 lineStyle 有共享缓存的坑，
	 * 所以这里自己画 BitmapData。
	 */
	public static function makeFrameSprite(w:Float, h:Float, ?thickness:Float = BORDER_THICKNESS):FlxSprite
	{
		var iw:Int = Std.int(w);
		var ih:Int = Std.int(h);
		var t:Int = Std.int(Math.max(1, thickness));

		var spr:FlxSprite = new FlxSprite();
		if (iw <= 0 || ih <= 0 || iw <= t * 2 || ih <= t * 2) return spr;

		var shape:Shape = new Shape();
		shape.graphics.beginFill(0xFFFFFFFF);
		shape.graphics.drawRect(0, 0, iw, t);
		shape.graphics.drawRect(0, ih - t, iw, t);
		shape.graphics.drawRect(0, t, t, ih - t * 2);
		shape.graphics.drawRect(iw - t, t, t, ih - t * 2);
		shape.graphics.endFill();

		var bmd:BitmapData = new BitmapData(iw, ih, true, 0x00000000);
		bmd.draw(shape);

		spr.pixels = bmd;
		spr.antialiasing = ClientPrefs.data.antialiasing;
		return spr;
	}
}
