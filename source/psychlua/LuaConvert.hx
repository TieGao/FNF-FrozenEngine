#if LUA_ALLOWED
package psychlua;

/**
 * 把 Haxe 值压进 Lua 栈的封装，替掉直接调 `llua.Convert.toLua`。
 *
 * 为什么不能直接用：`Convert.toLua` 遇到不认识的类型（引擎对象、FlxSprite、FlxText 之类）
 * 会先 `Sys.println` 一行再压 nil。cpp 上 `Sys.println` 是 `PRINTF` + `fflush(stdout)`
 * （Windows 带控制台时还要额外 WriteConsoleAllW + 一次 fflush，见 hxcpp StdLibs.cpp）。
 * 脚本只要在 onUpdate 里每帧返回一次这种对象，就是每帧十几次 fflush —— 这是掉帧的直接来源。
 *
 * 这里先判一次"能不能转"：转不了就直接压 nil（栈行为和原来完全一致），
 * 并且同一种类型只在第一次报一次，之后静默。
 */
class LuaConvert
{
	static var warned:Map<String, Bool> = new Map<String, Bool>();

	public static function toLua(l:State, val:Dynamic):Void
	{
		if (isConvertible(val))
		{
			Convert.toLua(l, val);
			return;
		}

		// 必须压一个 nil 保持栈平衡：调用方按「已压入 1 个返回值」计数，
		// 表构造里也紧接着 settable(-3)。不压栈会让 Lua 栈错位、回调取到脏值。
		warnOnce(Type.typeof(val));
		Lua.pushnil(l);
	}

	static function isConvertible(val:Dynamic):Bool
	{
		return switch (Type.typeof(val))
		{
			// 与 Convert.toLua 能处理的分支逐条对齐
			case TNull | TInt | TFloat | TBool | TObject: true;
			case TClass(Array) | TClass(String) | TClass(haxe.ds.ObjectMap) | TClass(haxe.ds.StringMap): true;
			default: false;
		}
	}

	static function warnOnce(type:Dynamic):Void
	{
		var key:String = Std.string(type);
		if (warned.exists(key)) return;
		warned.set(key, true);
		Sys.println('Couldn\'t convert "$key" to Lua. (further messages for this type are suppressed)');
	}
}
#end
