package nmv.test;

#if NMV_SMOKE
import nmv.scripts.FunkinScript;

/**
 * preset 冒烟：验证一二档符号全部注册、三档 throw 桩真的抛。
 *
 * 正式构建不含本文件（NMV_SMOKE 未定义时整体被条件编译排除）。
 */
class NmvPresetSmoke
{
	static final PRESET_NAMES:Array<String> = [
		// 核心
		'Type', 'StringTools', 'Math', 'Std', 'script', 'Dynamic', 'StringMap', 'IntMap', 'ObjectMap',
		'Assets', 'File', 'FileSystem', 'Function_Halt', 'Function_Stop', 'Function_Continue',
		'keyToString', 'keyFromString', 'version',
		// flixel
		'FlxG', 'FlxSprite', 'FlxCamera', 'PsychCamera', 'FlxMath', 'FlxTimer', 'FlxTween', 'FlxEase',
		'FlxSound', 'FlxText', 'FlxRuntimeShader', 'FlxFlicker', 'FlxSpriteUtil', 'FlxBackdrop', 'FlxPoint',
		'FlxTypedGroup', 'FlxSpriteGroup', 'FlxEmitter', 'FlxCameraFollowStyle', 'FlxTextBorderStyle',
		'FlxBarFillDirection', 'FlxAnimate', 'FlxAnimateFrames', 'FlxColor',
		// FNF
		'Paths', 'Conductor', 'ClientPrefs', 'CoolUtil', 'Controls', 'MusicBeatState', 'PlayState',
		'Highscore', 'FunkinScript', 'ScriptConstants', 'HScriptState', 'HScriptSubstate', 'ScriptedState',
		'ScriptedSubstate', 'GameOverSubstate', 'CustomSubstate', 'Note', 'Bar', 'Character', 'NoteSplash',
		'BGSprite', 'StrumNote', 'Alphabet', 'HealthIcon', 'FunkinSprite', 'buildTarget', 'Function_StopLua',
		'Function_StopHScript', 'Function_StopAll', 'getModSetting', 'setVar', 'getVar', 'removeVar',
		'game', 'controls',
		// 补桩（注册了但调用必抛）
		'newShader', 'ModManager', 'SubModifier', 'NoteModifier', 'ScriptedModifier', 'EventTimeline',
		'Modifier', 'StepCallbackEvent', 'CallbackEvent', 'ModEvent', 'EaseEvent', 'SetEvent',
		'WeekData', 'StageData', 'FunkinCamera', 'BackgroundDancer', 'BackgroundGirls', 'FunkinSound',
		'initScript', 'getInstance', 'newOption', 'getOption'
	];

	static final MUST_THROW:Array<String> = ['ModManager', 'SubModifier', 'WeekData', 'StageData', 'initScript', 'newOption'];

	static function main()
	{
		final script = FunkinScript.fromString('', 'smoke');

		for (name in PRESET_NAMES)
		{
			if (script.get(name) == null) throw 'preset missing: $name';
		}

		for (name in MUST_THROW)
		{
			final fn:Dynamic = script.get(name);
			var threw = false;
			try
			{
				fn('smoke-arg');
			}
			catch (e:Dynamic)
			{
				threw = true;
			}
			if (!threw) throw 'stub did not throw: $name';
		}

		Sys.println('NMV PRESET SMOKE OK (${PRESET_NAMES.length} symbols, ${MUST_THROW.length} throw stubs)');
	}
}
#end
