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
		registerImportAliases();

		script.set("Paths", backend.Paths);
		// NMV 的 Paths.getPath 第三个参数是查找范围枚举，FE 不区分 —— 给个纯值对象即可
		script.set('PathsTestMode', {NORMAL: 'NORMAL', STRICT: 'STRICT', LOOSE: 'LOOSE', NONE: 'NONE'});
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
		script.set('FunkinCaption', nmv.objects.FunkinCaption);
		script.set('FunkinCaptionGroup', nmv.objects.FunkinCaptionGroup);
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

		// NMV 移植的对象类（Phase 5 按语料实测补）
		script.set('SnowEmitter', nmv.objects.SnowEmitter);
		script.set('CustomEmitter', nmv.objects.CustomEmitter);
		script.set('AmongWalker', nmv.objects.AmongWalker);
		script.set('Lang', nmv.data.Lang);
		script.set('GameFlags', nmv.data.GameFlags);
		script.set('ProgressionUtil', nmv.data.ProgressionUtil);
		script.set('FunkinAssets', nmv.FunkinAssets);
		script.set('DebugDisplay', nmv.backend.DebugDisplay);
		script.set('Vector3', nmv.backend.math.Vector3);
		script.set('CosmicubeData', nmv.data.CosmicubeData);
		// 1.1.2 批：工具类 + 演出 shader（注册点见类注释）
		script.set('MathUtil', nmv.utils.MathUtil);
		script.set('SortUtil', nmv.utils.SortUtil);
		script.set('CameraUtil', nmv.utils.CameraUtil);
		script.set('ExtraDropShadowShader', nmv.shaders.ExtraDropShadowShader);
		script.set('FunkinRuntimeShader', nmv.shaders.FunkinRuntimeShader);
		script.set('HSLColorSwap', nmv.shaders.HSLColorSwap);
		// NMV 的 flxanimate fork 内部元素类（charles.hx 置子件 active 用），壳见类注释
		script.set('animate.internal.elements.FlxSpriteElement', nmv.objects.AnimateElementShim);
		#if VIDEOS_ALLOWED
		// NMV 视频播放器薄适配（legacy 全部开场演出：videoCutscene/meltdown，hxvlc 直包）
		script.set('FunkinVideoSprite', nmv.objects.FunkinVideoSprite);
		#end
		// flixel.text.FlxText.FlxTextAlign 是 enum abstract，注册名字→值映射
		script.set('FlxTextAlign', {
			LEFT: flixel.text.FlxText.FlxTextAlign.LEFT,
			CENTER: flixel.text.FlxText.FlxTextAlign.CENTER,
			RIGHT: flixel.text.FlxText.FlxTextAlign.RIGHT,
			JUSTIFY: flixel.text.FlxText.FlxTextAlign.JUSTIFY
		});

		// NMV 的宠物光标（Pet 继承 Bopper，未随路线 C 移植）：舞台/歌曲脚本普遍引用
		// pet.curPet / pet.loadPet / pet.origin 等面，缺了会让脚本 onLoad 中断、后续
		// 定时器闭包裸抛崩游戏。行为桩：FlxSprite 实例（不显示），逻辑放行。
		script.set('pet', new nmv.objects.PetStub());

		// 'stage'（NMV Stage 对象）：语料只用 stage.add / stage.insert / stage.members，
		// 与 PlayState 的 flixel 容器面一致，直接映射到宿主 state
		script.set('stage', FlxG.state);

		// NMV 的 playHUD（BaseHUD/PsychHUD）：映射到 PlayState 自带的 HUD 元素（getter 逐次取）
		script.set('playHUD', new nmv.objects.PlayHUDShim());

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
	static var aliasesRegistered:Bool = false;

	/**
	 * NMV 的脚本按自己的包名 import（`funkin.xxx`），FE 没有这个命名空间，
	 * 不接上的话 import 全部报 "could not be added"、后续变量解析成 null。
	 * 这里只映射有对应物（或已补桩）的类。
	 */
	static function registerImportAliases():Void
	{
		if (aliasesRegistered) return;
		aliasesRegistered = true;

		Iris.addProxyImport('funkin.utils.CoolUtil', backend.CoolUtil);
		Iris.addProxyImport('funkin.data.ClientPrefs', backend.ClientPrefs);
		Iris.addProxyImport('funkin.data.GameFlags', nmv.data.GameFlags);
		Iris.addProxyImport('funkin.utils.ProgressionUtil', nmv.data.ProgressionUtil);

		// 引擎侧同名/同义类
		Iris.addProxyImport('funkin.states.substates.PauseSubState', substates.PauseSubState);
		Iris.addProxyImport('funkin.states.substates.GameOverSubstate', substates.GameOverSubstate);
		Iris.addProxyImport('funkin.states.TitleState', states.TitleState);
		Iris.addProxyImport('funkin.data.WeekData', backend.WeekData);
		Iris.addProxyImport('funkin.Mods', backend.Mods);

		// 已移植的 nmv/ 类
		Iris.addProxyImport('funkin.objects.SnowEmitter', nmv.objects.SnowEmitter);
		Iris.addProxyImport('funkin.objects.FunkinCaption', nmv.objects.FunkinCaption);
		Iris.addProxyImport('funkin.objects.FunkinCaptionGroup', nmv.objects.FunkinCaptionGroup);
		Iris.addProxyImport('funkin.objects.stageobjects.AmongWalker', nmv.objects.AmongWalker);
		Iris.addProxyImport('funkin.game.huds.PsychHUD', nmv.objects.PlayHUDShim);
		Iris.addProxyImport('funkin.game.shaders.DropShadowShader', nmv.shaders.DropShadowShader);
		Iris.addProxyImport('funkin.game.shaders.ColorSwap', nmv.shaders.ColorSwap);
		Iris.addProxyImport('funkin.game.shaders.ChromaticAbberation', nmv.shaders.ChromaticAbberation);
		Iris.addProxyImport('funkin.game.shaders.HeatwaveShader', nmv.shaders.HeatwaveShader);
		Iris.addProxyImport('funkin.game.shaders.RGBPalette', nmv.shaders.RGBPalette);

		// 1.1.2 脚本新增的 funkin.* 依赖（工具类 / 数据桩）
		Iris.addProxyImport('funkin.FunkinAssets', nmv.FunkinAssets);
		Iris.addProxyImport('funkin.backend.DebugDisplay', nmv.backend.DebugDisplay);
		Iris.addProxyImport('funkin.backend.math.Vector3', nmv.backend.math.Vector3);
		Iris.addProxyImport('funkin.data.CosmicubeData', nmv.data.CosmicubeData);
		Iris.addProxyImport('funkin.utils.MathUtil', nmv.utils.MathUtil);
		Iris.addProxyImport('funkin.utils.SortUtil', nmv.utils.SortUtil);
		Iris.addProxyImport('funkin.utils.CameraUtil', nmv.utils.CameraUtil);
		Iris.addProxyImport('funkin.game.shaders.ExtraDropShadowShader', nmv.shaders.ExtraDropShadowShader);
		Iris.addProxyImport('funkin.game.shaders.HSLColorSwap', nmv.shaders.HSLColorSwap);
		Iris.addProxyImport('funkin.game.shaders.ColorMatrixShader', nmv.shaders.ColorMatrixShader);
		Iris.addProxyImport('funkin.game.shaders.OverlayShader', nmv.shaders.OverlayShader);
		Iris.addProxyImport('funkin.backend.FunkinShader.FunkinRuntimeShader', nmv.shaders.FunkinRuntimeShader);
		// 保险：脚本直接 `import flixel.addons.display.FlxRuntimeShader`（rgbPetColors.hx）
		Iris.addProxyImport('flixel.addons.display.FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);

		// FQ 名映射：`new funkin.objects.Pet()` 等全限定 new 不走 import 语句，
		// 走 InterpEx.cnew 的 proxyImports 查找。未移植类给"调用即抛"桩，
		// 撞上 cnew 的 TFunction 守卫 → 带原因的异常（而不是 Unknown variable）。
		Iris.addProxyImport('funkin.objects.Pet', nmv.objects.PetStub);
		missingProxyImport('funkin.data.FinaleState', 'finale 周剧情收尾，未移植。');
		missingProxyImport('funkin.states.substates.CreditsRollSubState', '制作人员滚动（剧情系统），未移植。');
		missingProxyImport('funkin.states.HenryState', '剧情状态机，未移植。');
		missingProxyImport('funkin.states.substates.MissCounterSubstate', 'NMV 特有 substate，未移植。');
		missingProxyImport('funkin.objects.RGBSprite', '依赖 NMV RGBGraphics 渲染管线，未移植。');
		missingProxyImport('funkin.game.modchart.ModManager', 'NMV modchart 未移植（FE 无 modchart 体系）。');
	}

	/** FQ 类名 → "调用即抛"桩：全限定 new/静态访问撞桩时给带原因的异常。 */
	static function missingProxyImport(name:String, reason:String):Void
	{
		Iris.addProxyImport(name, Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
			throw 'NMV API "$name" is not implemented in this port. $reason';
		}));
	}

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
