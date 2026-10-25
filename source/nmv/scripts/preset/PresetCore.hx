package nmv.scripts.preset;

import crowplexus.iris.Iris;

import nmv.scripting.ScriptConstants;

/**
 * NMV preset 的核心部分：标准库、集合、资源入口、脚本自身引用。
 *
 * 对应 NMV funkin.scripts.FunkinScript.preset() 的非 flixel、非 FNF 段。
 */
class PresetCore
{
	public static function register(script:FunkinScript):Void
	{
		script.set("StringTools", StringTools);
		script.set("Type", Type);
		script.set("Math", Math);
		script.set("Std", Std);

		script.set("script", script);
		script.set("Dynamic", Dynamic);
		script.set("this", script);

		script.set('StringMap', haxe.ds.StringMap);
		script.set('IntMap', haxe.ds.IntMap);
		script.set('ObjectMap', haxe.ds.ObjectMap);

		script.set("Assets", lime.utils.Assets);
		script.set("OpenFlAssets", openfl.utils.Assets);

		#if sys
		script.set('File', sys.io.File);
		script.set('FileSystem', sys.FileSystem);
		#end

		script.set('Function_Halt', ScriptConstants.HALT_FUNC);
		script.set('Function_Stop', ScriptConstants.STOP_FUNC);
		script.set('Function_Continue', ScriptConstants.CONTINUE_FUNC);

		script.set("keyToString", (key:Int) -> flixel.input.keyboard.FlxKey.toStringMap.get(key));
		script.set("keyFromString", (str:String) -> flixel.input.keyboard.FlxKey.fromStringMap.get(str));

		// 引擎版本号；FE 没有 NMV 的 Main.NMV_VERSION，用 AboutSubState 同一口径
		script.set('version', backend.VersionInfo.lib('hscript-iris-nmv'));
	}
}
