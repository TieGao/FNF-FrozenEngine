package nmv.scripting;

import flixel.util.FlxDestroyUtil;
import nmv.scripts.FunkinScript;
import nmv.scripts.ScriptGroup;
import nmv.states.FallbackState;
import states.MainMenuState;
import sys.FileSystem;

/**
 * 自带脚本组的 State 壳：加载 `scripts/states/<scriptName>` 下的脚本并转发 onLoad/onCreate。
 */
@:nullSafety
class ScriptedState extends MusicBeatState
{
	public var scripted:Bool = false;
	public var scriptName:String = '';
	public var scriptGroup:ScriptGroup = new ScriptGroup();

	public function new(scriptName:String)
	{
		super();

		initStateScript(scriptName, false);
		scriptGroup.parent = this;
		scriptGroup.call('onLoad');
	}

	/** 加载状态脚本；callOnLoad 为 false 时由构造函数手动决定调用时机。 */
	public function initStateScript(?scriptName:String, callOnLoad:Bool = true):Bool
	{
		if (scriptName == null)
		{
			final stateName = Type.getClassName(Type.getClass(this)).split('.').pop();
			scriptName = stateName ?? '???';
		}

		final scriptFile = FunkinScript.getPath('scripts/states/$scriptName');
		if (scriptGroup.exists(scriptFile)) return true;

		this.scriptName = scriptName;

		if (FileSystem.exists(scriptFile))
		{
			var newScript = FunkinScript.fromFile(scriptFile, scriptName);
			if (newScript.parsingFailed())
			{
				newScript = FlxDestroyUtil.destroy(newScript);
				return false;
			}

			scriptGroup.parent = this;
			scriptGroup.addScript(newScript);
			scripted = true;
		}

		if (callOnLoad) scriptGroup.call('onLoad', []);

		return scripted;
	}

	override function create()
	{
		super.create();

		if (!scripted)
		{
			FlxG.switchState(() -> new FallbackState('failed to load ($scriptName)!\nDoes it exist?', () -> FlxG.switchState(MainMenuState.new)));
			return;
		}

		scriptGroup.call('onCreate');
	}
}
