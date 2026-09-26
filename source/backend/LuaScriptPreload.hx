package backend;

#if (LUA_ALLOWED && sys)
import sys.FileSystem;
import sys.io.File;
import backend.Song; // SwagSong / SwagSection
import cutscenes.DialogueBoxPsych;
import flixel.FlxG;
import states.LoadingState;
import states.PlayState;
import luahscript.LuaParser;
import luahscript.exprs.LuaExpr;
#end

/**
 * LoadingState 预载阶段的 lua 脚本静态分析：
 * 解析本歌将要运行的全部 .lua，抽取其中的资源路径提前预热，并顺带做语法校验。
 *
 * 行为由 ClientPrefs.data.luaScriptParser 控制：
 *   'native'  —— 完全不解析。语法错误交给运行期真实 Lua VM 在 dofile/dostring 时报
 *                （即 Psych 1.0.4 的原生行为，见 FunkinLua 构造函数）
 *   'check'   —— 只解析做语法校验，不往预载队列塞东西
 *   'preload' —— 解析 + 抽资源交给 LoadingState.prepare 预载（语法校验同样生效）
 *
 * 任何情况下都不抛异常、不中断预载：单个坏脚本只记一条错误。
 */
class LuaScriptPreload
{
	/** 入口，由 LoadingState.prepareToSong 调用 */
	public static function scanSong():Void
	{
		#if (LUA_ALLOWED && sys)
		run();
		#end
	}

	#if (LUA_ALLOWED && sys)
	/** 已扫过的路径。addLuaScript 可能成环，靠它兜底，否则会无限递归 */
	static var visited:Map<String, Bool> = [];
	static var errors:Array<String> = [];
	static var imgs:Array<String> = [];
	static var snds:Array<String> = [];
	static var mscs:Array<String> = [];

	static function run():Void
	{
		var mode:String = ClientPrefs.data.luaScriptParser;
		if (mode != 'check' && mode != 'preload') return;

		var song:SwagSong = PlayState.SONG;
		if (song == null) return;

		var extract:Bool = (mode == 'preload');
		visited = [];
		errors = [];
		imgs = [];
		snds = [];
		mscs = [];

		try
		{
			var folder:String = Paths.formatToSongPath(Song.loadedSongName);
			var stage:String = (song.stage == null || song.stage.length < 1) ? StageData.vanillaSongStage(folder) : song.stage;

			// 以下六类逐条对齐 PlayState 真正加载脚本的位置
			for (dir in ['scripts/', 'data/${song.song}/'])
				for (scriptsFolder in Mods.directoriesWithFile(Paths.getSharedPath(), dir))
					for (file in FileSystem.readDirectory(scriptsFolder))
						if (file.toLowerCase().endsWith('.lua'))
							scanNamed(scriptsFolder + file, extract);

			scanNamed('stages/$stage.lua', extract);

			for (character in [song.player1, song.player2, song.gfVersion])
				if (character != null && character.length > 0)
					scanNamed('characters/$character.lua', extract);

			for (noteType in collectNoteTypes(song))
				scanNamed('custom_notetypes/$noteType.lua', extract);

			for (eventName in collectEventNames(song, folder))
				scanNamed('custom_events/$eventName.lua', extract);
		}
		catch (e:Dynamic)
		{
			trace('[LuaScriptPreload] 枚举脚本失败: $e');
		}

		if (extract && (imgs.length > 0 || snds.length > 0 || mscs.length > 0))
			LoadingState.prepare(imgs, snds, mscs);

		reportErrors();
	}

	/** 谱面用到的 noteType：取自 sectionNotes[3]，去重。对齐 PlayState 的 noteTypes 收集方式 */
	static function collectNoteTypes(song:SwagSong):Array<String>
	{
		var out:Array<String> = [];
		if (song.notes == null) return out;

		for (section in song.notes)
		{
			if (section == null || section.sectionNotes == null) continue;
			for (note in section.sectionNotes)
			{
				if (note == null || !Std.isOfType(note, Array)) continue;
				var noteData:Array<Dynamic> = cast note;
				if (noteData.length < 4 || noteData[3] == null) continue;

				var name:String = Std.string(noteData[3]);
				if (name.length > 0 && !out.contains(name)) out.push(name);
			}
		}
		return out;
	}

	/** 谱面事件名。每项形如 [strumTime, [[事件名, v1, v2], ...]] */
	static function collectEventNames(song:SwagSong, folder:String):Array<String>
	{
		var out:Array<String> = [];
		addEventNames(song.events, out);

		// 事件也可能单独放在 data/<歌>/events.json 里，PlayState 会一并读
		try
		{
			var eventsChart:SwagSong = Song.getChart('events', folder);
			if (eventsChart != null) addEventNames(eventsChart.events, out);
		}
		catch (e:Dynamic) {}

		return out;
	}

	static function addEventNames(events:Array<Dynamic>, out:Array<String>):Void
	{
		if (events == null) return;

		for (event in events)
		{
			if (event == null || !Std.isOfType(event, Array)) continue;
			var entry:Array<Dynamic> = cast event;
			if (entry.length < 2 || !Std.isOfType(entry[1], Array)) continue;

			for (sub in (cast entry[1]:Array<Dynamic>))
			{
				if (sub == null || !Std.isOfType(sub, Array)) continue;
				var subData:Array<Dynamic> = cast sub;
				if (subData.length < 1 || subData[0] == null) continue;

				var name:String = Std.string(subData[0]);
				if (name.length > 0 && !out.contains(name)) out.push(name);
			}
		}
	}

	/** 按 mods 优先、再 shared 的顺序定位脚本；命中且没扫过才解析。对齐 PlayState 的 startLuasNamed */
	static function scanNamed(filePath:String, extract:Bool):Void
	{
		if (filePath == null || filePath.length < 1) return;

		#if MODS_ALLOWED
		var path:String = Paths.modFolders(filePath);
		#else
		var path:String = Paths.getSharedPath(filePath);
		#end

		if (!FileSystem.exists(path)) path = Paths.getSharedPath(filePath);
		if (!FileSystem.exists(path)) return;
		if (visited.exists(path)) return;

		visited.set(path, true);
		scanFile(path, extract);
	}

	/** 解析单个脚本。解析失败只记错、不抛 */
	static function scanFile(path:String, extract:Bool):Void
	{
		var input:String = null;
		try input = File.getContent(path)
		catch (e:Dynamic)
		{
			errors.push('$path: 读取失败 ($e)');
			return;
		}
		if (input == null) return;

		// 去掉 UTF-8 BOM
		if (StringTools.fastCodeAt(input, 0) == 0xFEFF) input = input.substr(1);

		var expr:LuaExpr = null;
		try expr = new LuaParser().parseFromString(input)
		catch (e:Dynamic)
		{
			errors.push('$path: $e');
			return;
		}
		if (expr == null) return;

		LuaScriptTools.searchCallback(expr, function(callee:LuaExpr, params:Array<LuaExpr>) {
			switch (callee.expr)
			{
				case EIdent('makeLuaSprite') | EIdent('makeAnimatedLuaSprite'):
					addImage(LuaScriptTools.getValue(paramAt(params, 1)), extract);
				case EIdent('precacheImage'):
					addImage(LuaScriptTools.getValue(paramAt(params, 0)), extract);
				case EIdent('precacheSound') | EIdent('playSound'):
					addSound(LuaScriptTools.getValue(paramAt(params, 0)), extract);
				case EIdent('precacheMusic') | EIdent('playMusic'):
					addMusic(LuaScriptTools.getValue(paramAt(params, 0)), extract);
				case EIdent('addLuaScript'):
					var nested:Dynamic = LuaScriptTools.getValue(paramAt(params, 0));
					if (nested != null) scanNamed(Std.string(nested), extract);
				case EIdent('startDialogue'):
					collectDialogue(params, extract);
				case _:
			}
		});
	}

	/** 越界取参返回 null —— 脚本少传参数时不该炸 */
	static function paramAt(params:Array<LuaExpr>, index:Int):LuaExpr
	{
		if (params == null || index < 0 || index >= params.length) return null;
		return params[index];
	}

	static function addImage(value:Dynamic, extract:Bool):Void
	{
		if (!extract || value == null) return;
		var s:String = Std.string(value);
		if (s.length > 0 && !imgs.contains(s)) imgs.push(s);
	}

	static function addSound(value:Dynamic, extract:Bool):Void
	{
		if (!extract || value == null) return;
		var s:String = Std.string(value);
		if (s.length > 0 && !snds.contains(s)) snds.push(s);
	}

	static function addMusic(value:Dynamic, extract:Bool):Void
	{
		if (!extract || value == null) return;
		var s:String = Std.string(value);
		if (s.length > 0 && !mscs.contains(s)) mscs.push(s);
	}

	/** startDialogue('对话文件', '音乐')：读对话 json 把 portrait / sound 一并预载。只有剧情模式会用到 */
	static function collectDialogue(params:Array<LuaExpr>, extract:Bool):Void
	{
		if (!extract || !PlayState.isStoryMode) return;

		var dialogueFile:Dynamic = LuaScriptTools.getValue(paramAt(params, 0));
		if (dialogueFile != null)
		{
			try
			{
				var folder:String = Paths.formatToSongPath(PlayState.SONG.song);
				var name:String = Std.string(dialogueFile);

				var path:String = null;
				#if MODS_ALLOWED
				path = Paths.modsJson('$folder/$name');
				if (!FileSystem.exists(path)) path = Paths.json('$folder/$name');
				#else
				path = Paths.json('$folder/$name');
				#end

				if (FileSystem.exists(path))
				{
					var dialogueList:DialogueFile = DialogueBoxPsych.parseDialogue(path);
					for (line in dialogueList.dialogue)
					{
						if (line == null) continue;
						if (line.portrait != null) addImage('dialogue/${line.portrait}', true);
						if (line.sound != null) addSound(line.sound, true);
					}
				}
			}
			catch (e:Dynamic) {}
		}

		var music:Dynamic = LuaScriptTools.getValue(paramAt(params, 1));
		if (music != null) addMusic(Std.string(music), true);
	}

	/**
	 * 语法错误汇总：逐条进日志，再弹一次原生提示框（和 FunkinLua 报 lua 错误同一条通道）。
	 * 只弹一次 —— window.alert 是阻塞式模态框，逐条弹会变成"关不掉"。
	 * 扫描通常跑在 lime.app.Future 的后台线程上（prepareToSong 传的 useThreads），
	 * SDL_ShowSimpleMessageBox 允许从任意线程调用，弹窗只会卡住这一条预载链，不会卡住主线程。
	 */
	static function reportErrors():Void
	{
		if (errors.length < 1) return;

		var summary:String = '';
		for (err in errors)
		{
			trace('[LuaScriptPreload] $err');
			try FlxG.log.error('[LuaScriptPreload] $err') catch (e:Dynamic) {}
			summary += err + '\n';
		}

		#if windows
		try lime.app.Application.current.window.alert(summary, 'Lua Script Syntax Error') catch (e:Dynamic) {}
		#end
	}
	#end
}
