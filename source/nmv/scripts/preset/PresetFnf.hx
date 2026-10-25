package nmv.scripts.preset;

import crowplexus.iris.Iris;

import nmv.objects.FunkinSprite;
import nmv.scripting.ScriptConstants;
import nmv.scripting.ScriptedState;
import nmv.scripting.ScriptedSubstate;
import nmv.scripts.FunkinScript;

/**
 * NMV preset 的 FNF 段：引擎类引用 + 歌内上下文变量。
 *
 * 同名异义的 WeekData/StageData 故意不注册（脚本一用到就会得到 hscript 的
 * Unknown variable 报错，带文件名行号），详见 docs/nmv-port-plan/30 小节。
 */
class PresetFnf
{
	public static function register(script:FunkinScript):Void
	{
		script.set("Paths", backend.Paths);
		script.set("Conductor", backend.Conductor);
		script.set("ClientPrefs", ClientPrefs);
		script.set("CoolUtil", CoolUtil);
		script.set('Controls', backend.Controls);

		script.set("MusicBeatState", backend.MusicBeatState);
		script.set("PlayState", PlayState);
		script.set('Highscore', backend.Highscore);

		// script compat 名（NMV 也注册了 HScript* 两份别名）
		script.set("FunkinScript", FunkinScript);
		script.set('ScriptConstants', ScriptConstants);
		script.set('HScriptState', ScriptedState);
		script.set('HScriptSubstate', ScriptedSubstate);
		script.set('ScriptedState', ScriptedState);
		script.set('ScriptedSubstate', ScriptedSubstate);
		script.set("GameOverSubstate", substates.GameOverSubstate);
		script.set('CustomSubstate', psychlua.CustomSubstate);

		// objects
		script.set("Note", objects.Note);
		script.set("Bar", objects.Bar);
		script.set("Character", objects.Character);
		script.set("NoteSplash", objects.NoteSplash);
		script.set("BGSprite", objects.BGSprite);
		script.set("StrumNote", objects.StrumNote);
		script.set("Alphabet", objects.Alphabet);
		script.set("HealthIcon", objects.HealthIcon);
		script.set("FunkinSprite", FunkinSprite);
		script.set('DialogueBox', cutscenes.DialogueBox);
		script.set("CutsceneHandler", cutscenes.CutsceneHandler);

		// 通用工具（Psych 系 preset 也有，脚本常直接调）
		script.set('buildTarget', psychlua.LuaUtils.getBuildTarget());
		script.set('Function_Stop', psychlua.LuaUtils.Function_Stop);
		script.set('Function_Continue', psychlua.LuaUtils.Function_Continue);
		script.set('Function_StopLua', psychlua.LuaUtils.Function_StopLua);
		script.set('Function_StopHScript', psychlua.LuaUtils.Function_StopHScript);
		script.set('Function_StopAll', psychlua.LuaUtils.Function_StopAll);

		// 变量读写走 MusicBeatState 的共享表，与 psychlua.HScript 同一口径
		script.set('setVar', function(name:String, value:Dynamic) {
			backend.MusicBeatState.getVariables().set(name, value);
			return value;
		});
		script.set('getVar', function(name:String) {
			var result:Dynamic = null;
			if (backend.MusicBeatState.getVariables().exists(name)) result = backend.MusicBeatState.getVariables().get(name);
			return result;
		});
		script.set('removeVar', function(name:String) {
			if (backend.MusicBeatState.getVariables().exists(name))
			{
				backend.MusicBeatState.getVariables().remove(name);
				return true;
			}
			return false;
		});

		script.set('getModSetting', function(saveTag:String, ?modName:String = null) {
			return psychlua.LuaUtils.getModSetting(saveTag, modName);
		});

		script.set('game', FlxG.state);
		script.set('controls', backend.Controls.instance);
		script.set('modFolder', script.modFolder);

		registerPlayStateContext(script);

		PresetStubs.register(script);
	}

	/** PlayState 内的歌上下文变量（NMV 同名段；字段取不到的一律不注册）。 */
	static function registerPlayStateContext(script:FunkinScript):Void
	{
		if (!(FlxG.state is PlayState)) return;

		script.set("inPlaystate", true);
		script.set('bpm', PlayState.SONG.bpm);
		script.set('scrollSpeed', PlayState.SONG.speed);
		script.set('songName', PlayState.SONG.song);
		script.set('isStoryMode', PlayState.isStoryMode);
		script.set('difficulty', PlayState.storyDifficulty);
		script.set('weekRaw', backend.WeekData.getWeekFileName());
		script.set('seenCutscene', PlayState.seenCutscene);
		if (PlayState.storyDifficulty >= 0 && PlayState.storyDifficulty < backend.Difficulty.list.length)
			script.set('difficultyName', backend.Difficulty.list[PlayState.storyDifficulty]);
		if (FlxG.sound.music != null) script.set('songLength', FlxG.sound.music.length);

		final instance = PlayState.instance;
		if (instance != null)
		{
			script.set('healthGainMult', instance.healthGain);
			script.set('healthLossMult', instance.healthLoss);
			script.set('instakillOnMiss', instance.instakillOnMiss);
			script.set('botPlay', instance.cpuControlled);
			script.set('practice', instance.practiceMode);
		}

		script.set("global", backend.MusicBeatState.getVariables());

		script.set('setVar', (varName:String, val:Dynamic) -> backend.MusicBeatState.getVariables().set(varName, val));
		script.set('getVar', (varName:String) -> backend.MusicBeatState.getVariables().get(varName));
	}
}
