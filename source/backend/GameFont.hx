package backend;

/**
 * 游戏内字体解析入口。
 * 与 Paths.font 的区别：默认绕开语言字体替换表，只在设置开启时才跟随语言。
 * mod 覆盖仍然生效（mods/<mod>/fonts/<key> 优先）。
 */
class GameFont
{
	/**
	 * 设置项：游戏内 HUD 与 Lua/HScript 文本是否跟随语言字体（默认关闭）。
	 * ⚠️ 只影响之后新建的文本，已存在的 FlxText 不会重建 —— 与语言切换的现有行为一致。
	 */
	public static function followsLanguage():Bool
	{
		var d = ClientPrefs.data;
		return d != null && d.gameFontFollowLanguage;
	}

	/** key 不带 `fonts/` 前缀，与 Paths.font 一致。 */
	public static function resolve(key:String):String
	{
		return Paths.font(key, !followsLanguage());
	}
}
