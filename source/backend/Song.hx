package backend;

import haxe.Json;
import lime.utils.Assets;

import objects.Note;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var mirrorNotes:Bool;

	@:optional var mania:Int;        // 键数-1 (3 = 4K, 15 = 16K)
    @:optional var keyCount:Int;     // 实际键数 (4-16)
    @:optional var keycount:Int;     // 兼容旧版
    // 以"值域"而非"玩家/对手侧"编码轨道、且自行处理 noteData 的谱面（如自制多轨谱），
    // 置 true 让 convert 原样保留 noteData。convert 的归一化公式本质假设
    // noteData 用 mustHitSection 的 XOR 编码两侧；这类谱没有这层编码，硬套会毁数据。
    @:optional var noConvert:Bool;

    // 专辑 id（对应 assets/shared/albums/<id>.json）。原版挂在每个变体上，
    // 本引擎只读当前难度那一份，缺失时显示层回退到默认难度档。
    @:optional var album:String;

    // 歌曲署名。原版谱面 JSON 自带这两个字段；V-Slice 转换时也会写入。
    // 统一取数见 backend.SongCredits（暂停界面 / Freeplay 共用）。
    @:optional var artist:String;
    @:optional var charter:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';
	public var mirrorNotes:Bool = false;

	public static function getKeyCount(songJson:Dynamic):Int
	{
		if(songJson == null) return 4;

		var columns:Int = 4;
		var value:Dynamic = Reflect.field(songJson, 'mania');
		if(Std.isOfType(value, Int))
			columns = Std.int(value) + 1;
		else
		{
			value = Reflect.field(songJson, 'keyCount');
			if(Std.isOfType(value, Int))
				columns = Std.int(value);
			else
			{
				value = Reflect.field(songJson, 'keycount');
				if(Std.isOfType(value, Int))
					columns = Std.int(value);
				else
				{
					// NMV 格式用 keys 表示每侧列数（NMV Chart.correctFormat: keys ??= 4）
					value = Reflect.field(songJson, 'keys');
					if(Std.isOfType(value, Int))
						columns = Std.int(value);
				}
			}
		}
		return Std.int(Math.max(4, columns));
	}

	public static inline function shouldSplitCustomTracks(songJson:Dynamic, enabled:Bool):Bool
	{
		if(!enabled || songJson == null || Reflect.field(songJson, 'noConvert') != true)
			return false;

		var columns:Int = getKeyCount(songJson);
		return columns >= 8 && columns % 2 == 0;
	}

	public static function getPlayableColumnCount(songJson:Dynamic, ?splitCustomTracks:Bool = false):Int
	{
		var columns:Int = getKeyCount(songJson);
		return shouldSplitCustomTracks(songJson, splitCustomTracks) ? Std.int(columns / 2) : columns;
	}

	public static function isOpponentLane(rawLane:Int, songJson:Dynamic, ?splitCustomTracks:Bool = false):Bool
	{
		var boundary:Int = shouldSplitCustomTracks(songJson, splitCustomTracks)
			? Std.int(getKeyCount(songJson) / 2)
			: getKeyCount(songJson);
		return rawLane >= boundary;
	}

	public static function convert(songJson:Dynamic, ?sourceFormat:String) // Convert old charts to psych_v1 format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		// 自管 noteData 的谱面：convert 的归一化公式假设 noteData 用 mustHitSection 的 XOR
		// 编码"玩家/对手侧"，但这类谱往往用"值域区间"直接编码轨道，且自己在脚本里处理 noteData。
		// 硬套公式会把值域区间打乱（实测会把多条轨合并），故原样返回。
		if(songJson.noConvert == true) return;

		// 归一化要按"每侧列数"来算，而不是写死 4。原实现 %4 / +4 只对 4K 成立，
		// 任何多 k 谱（8K 等）都会被压扁、丢掉轨道身份。
		// 读取优先级刻意与 Note.getColumnsPerPlayer 一致（mania -> keyCount -> keycount -> keys），
		// 保证对真实多 k 谱两者结果相同。
		var columns:Int = getKeyCount(songJson);

		// nmv2（NMV 引擎原生格式）的车道本来就是绝对值：0..keys-1 = 玩家侧，
		// keys..2keys-1 = 对手侧，与 FE psych_v1 运行时同构；时间/延音同为毫秒。
		// 硬套旧格式的 mustHitSection XOR 翻转会把对手 note 全翻到玩家侧
		// （2026-10-28 实测：整首谱 note 全归 player）。只跳过车道翻转，
		// 保留 sectionBeats 修正与事件提取。
		final skipLaneFlip:Bool = (sourceFormat == 'nmv2');

		// NMV 的 arrowSkin/splashSkin 是它自家 JSON noteskin 系统（data/noteskins/<id>.json
		// 映射出 noteTexture）的皮肤 ID（'default'/'top'/'pixel'），不是 FE 图集名；
		// 原样透传会让 Paths.getSparrowAtlas('default') 落空 → Note frames=null →
		// findByPrefix 崩（2026-10-31 实测：double-trouble 是唯一 arrowSkin='default' 的
		// nmv2 图，note 生成即崩）。NMV noteskin 未移植，一律剥掉回退 FE 默认
		// （NOTE_assets / ClientPrefs 的 noteSplashes）。
		if (skipLaneFlip)
		{
			Reflect.deleteField(songJson, 'arrowSkin');
			Reflect.deleteField(songJson, 'splashSkin');
		}

		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			if (skipLaneFlip) continue;

			for (note in section.sectionNotes)
			{
				var gottaHitNote:Bool = (note[1] < columns) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % columns) + (gottaHitNote ? 0 : columns);

				if(!Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
			}
		}
	}

	/**
	 * convert() 的逆运算：把 psych_v1 的绝对 lane 语义（lane<cols = 玩家侧）
	 * 转回 Legacy（0.7.x）的"相对 lane + mustHitSection"语义。
	 * 供编辑器导出降级谱面用，保证按 mustHitSection 解释的老引擎读出来归属不变。
	 *
	 * 与 convert() 保持同一套跳过条件：noConvert 谱自管 noteData，转回去只会毁数据。
	 */
	public static function convertNoteLanesToLegacy(songJson:Dynamic, ?columns:Int):Void
	{
		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;
		if(songJson.noConvert == true) return;

		if(columns == null || columns < 1) columns = getKeyCount(songJson);

		for (section in sectionsData)
		{
			var mustHit:Bool = (section.mustHitSection == true);
			for (note in section.sectionNotes)
			{
				if(note[1] < 0) continue; // 事件 note 用负数 lane，不参与
				var isPlayerSide:Bool = (note[1] < columns);
				var sameSide:Bool = (isPlayerSide == mustHit);
				note[1] = (note[1] % columns) + (sameSide ? 0 : columns);
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath;
		#if windows
		// prevent any saving errors by fixing the path on Windows (being the only OS to ever use backslashes instead of forward slashes for paths)
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawData:String = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if sys
		// NMV 内容包的谱面是 songs/<歌>/data/<难度>.json，与 FE 的 data/<歌>/<歌>-<难度>.json 不同。
		// 必须在 Assets.getText 之前判存在：那条路找不到会抛异常，回退就再也走不到了。
		if (!FileSystem.exists(_lastPath))
		{
			var nmvPath:String = findNmvChart(formattedFolder, formattedSong);
			if (nmvPath != null)
			{
				_lastPath = nmvPath;
				return parseJSON(File.getContent(nmvPath), jsonInput);
			}
		}
		#end

		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else
		#end
			rawData = Assets.getText(_lastPath);

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	#if sys
	/** NMV 内容包谱面回退：songs/<歌>/data/<难度>.json；难度文件缺失时回退 normal。 */
	static function findNmvChart(folder:String, song:String):Null<String>
	{
		var mod:String = NMVContentData.currentMod;
		if (mod == null || mod.length == 0) return null;

		var difficulty:String = 'normal';
		var dash:Int = song.lastIndexOf('-');
		if (dash >= 0 && dash < song.length - 1) difficulty = song.substr(dash + 1);

		var root:String = '${NMVContentData.ROOT}/$mod';

		// 事件图表特判：NMV 的事件在 songs/<歌>/data/events.json（vanilla 旧事件格式）。
		// 不特判的话 'events' 会被当难度名、difficulty 落回 'normal'，
		// 第一候选直接命中 normal.json —— 事件图表加载成 note 谱，全部事件丢失
		// （2026-10-30 实测：日志 "converting chart events with format nmv2" 即此假命中）。
		// 变体（events-erect 等）优先探变体文件，探不到再落基础 events.json。
		var candidates:Array<String>;
		if (song == 'events' || StringTools.startsWith(song, 'events-'))
		{
			candidates = [];
			if (difficulty != 'normal' && dash >= 0 && song.substr(0, dash) == 'events')
				candidates.push('$root/songs/$folder/data/events-$difficulty.json');
			candidates.push('$root/songs/$folder/data/events.json');
			candidates.push('$root/songs/$folder/events.json');
		}
		else
		{
			candidates = [
				'$root/songs/$folder/data/$difficulty.json',
				'$root/songs/$folder/$difficulty.json',
				'$root/songs/$folder/data/normal.json',
				'$root/songs/$folder/song.json'
			];
		}

		for (candidate in candidates)
		{
			if (FileSystem.exists(candidate)) return candidate;
		}

		return null;
	}
	#end

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1')) //Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						var sourceFormat = fmt;
						songJson.format = 'psych_v1_convert';
						convert(songJson, sourceFormat);
					}
			}
		}
		return songJson;
	}
}
