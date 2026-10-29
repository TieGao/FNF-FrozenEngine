package nmv.backend;

/**
 * NMV `funkin.backend.DebugDisplay` 的桩：只做插件文本的收集。
 *
 * FE 的调试叠层是 `debug.FPSCounter`，没有插件接口，这里不渲染 —— 语料只用
 * `DebugDisplay.addPlugin(fn)` 往叠层加一行字（utils.hx），收下不显示即可。
 */
class DebugDisplay
{
	public static var instance:Null<DebugDisplay> = null;

	/** 已登记的插件，`getText()` 按顺序拼接。 */
	public static var plugins:Array<Void->Null<String>> = [];

	public static function init():Void
	{
		if (instance == null) instance = new DebugDisplay();
	}

	public function new() {}

	/** 登记一行调试文本，返回同一个函数（NMV 语义，可当注销句柄用）。 */
	public static function addPlugin(fun:Void->String):Void->Null<String>
	{
		if (fun == null) return null;
		if (plugins.indexOf(cast fun) == -1) plugins.push(cast fun);
		return cast fun;
	}

	public static function removePlugin(fun:Void->String):Void
	{
		plugins.remove(cast fun);
	}

	public static function getText():String
	{
		var out = '';
		for (fun in plugins)
		{
			var line:Dynamic = null;
			try line = fun() catch (e:Dynamic) {}
			if (line != null) out += line;
		}
		return out;
	}
}
