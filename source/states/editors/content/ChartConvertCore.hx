package states.editors.content;

import haxe.ds.Map;
import moonchart.formats.BasicFormat;
import moonchart.formats.StepMania;
import moonchart.formats.StepManiaShark;
import moonchart.formats.OsuMania;
import moonchart.formats.Quaver;
import moonchart.formats.Midi;
import moonchart.backend.Timing;
import moonchart.parsers.QuaverParser.QuaverHitObject;
import moonchart.parsers._internal.ZipFile;

using StringTools;

/**
 * 统一谱面转换核心（其他游戏 ⇄ FE），只依赖 moonchart，不依赖引擎代码，便于独立测试。
 *
 * 支持导入：.sm / .ssc / .osu / .osz / .qua / .qp / .mid / .mc
 * 支持导出：.sm / .ssc / .osu / .qua（moonchart 的 Midi 只有解析没有 stringify，导不出）
 *
 * 与直接用 moonchart FNFPsych 中转的差异（都是实测踩过的坑）：
 *  - section 构建自己写：FNFLegacy 的 8 轨取模 lane 编码会把 >7K 谱面 lane 卷绕撞车，
 *    而 FE 的多键布局是连续 player-major（0..K-1 玩家侧 / K..2K-1 对手侧），与各源格式
 *    的单轨 lane 天然同构，直接透传即可；
 *  - hold 长度透传：FNFLegacy 的 offsetHolds 会按 legacy FNF 0.2.x 的习惯砍掉一个
 *    stepCrochet，对 Psych 系存储值（存多少放多少）会引入一步误差；
 *  - note 类型映射：SM 的 mine / moonchart 的 "mine" → FE "Hurt Note"。
 */
class ChartConvertCore
{
	/** Malody 音乐条目偏移在 extraData 里的传递键（ms） */
	public static inline var MALODY_MUSIC_OFFSET:String = 'FE_MALODY_MUSIC_OFFSET';

	public static var FILE_FILTER:String = '*.sm;*.ssc;*.osu;*.osz;*.qua;*.qp;*.mid;*.midi;*.mc';

	/** 可导出的格式（FE → 外部），顺序即导出对话框的展示顺序 */
	public static var EXPORT_FORMATS:Array<String> = ['sm', 'ssc', 'osu', 'qua'];

	public static var FORMAT_LABELS:Map<String, String> = [
		'sm' => 'StepMania (.sm)', 'ssc' => 'StepMania (.ssc)',
		'osu' => 'osu!mania (.osu)', 'osz' => 'osu!mania beatmap pack (.osz)',
		'qua' => 'Quaver (.qua)', 'qp' => 'Quaver mapset (.qp)',
		'mid' => 'MIDI (.mid)', 'mc' => 'Malody (.mc)'
	];

	// ====================================================
	//  对外 API
	// ====================================================

	/**
	 * 识别文件格式，返回格式 tag（sm/ssc/osu/osz/qua/qp/mid/mc），不认识返回 null
	 */
	public static function detectFormat(path:String):Null<String>
	{
		var ext:String = path.substr(path.lastIndexOf('.') + 1).toLowerCase();
		return switch(ext)
		{
			case 'sm': 'sm';
			case 'ssc': 'ssc';
			case 'osu': 'osu';
			case 'osz': 'osz';
			case 'qua': 'qua';
			case 'qp': 'qp';
			case 'mid', 'midi': 'mid';
			case 'mc': 'mc';
			default: null;
		}
	}

	/**
	 * 探测文件信息（键数/难度列表/标题），供导入对话框使用。解析失败抛异常。
	 */
	public static function probe(path:String):ChartImportInfo
	{
		var format:String = detectFormat(path);
		if(format == null)
			throw 'Unsupported chart file: $path';
		var loaded = loadBasic(path, null, 4);
		return loaded.info;
	}

	/** 外部格式的字段值会带前导空格（'Title: xxx' 的冒号后），落地前统一裁掉 */
	static function cleanName(value:Null<String>, fallback:String):String
	{
		if(value == null) return fallback;
		var name:String = value.trim();
		return (name.length > 0) ? name : fallback;
	}

	/**
	 * 导入为 FE 谱面（SwagSong 结构的 Dynamic）。解析失败抛异常。
	 * @param diff 源难度名（null = 第一个难度）
	 * @param targetKeys 目标键数；与源键数不同时按比例重排列（MIDI 直接以目标键数做 pitch 取模）
	 */
	public static function importToSong(path:String, ?diff:String, targetKeys:Int = 4):Dynamic
	{
		var format:String = detectFormat(path);
		if(format == null)
			throw 'Unsupported chart file: $path';

		var isMidi:Bool = (format == 'mid');
		var loaded = loadBasic(path, diff, isMidi ? targetKeys : null);
		var info:ChartImportInfo = loaded.info;

		var keys:Int = isMidi ? targetKeys : info.keys;
		if(keys < 1) keys = 4;
		if(targetKeys < 1) targetKeys = keys;

		var notes:Array<BasicNote> = firstDiffNotes(loaded.basic);
		if(notes == null)
			throw 'Chart has no difficulty data';

		if(!isMidi && keys != targetKeys)
			scaleLanes(notes, keys, targetKeys);

		return buildSong(loaded.basic.meta, notes, targetKeys);
	}

	/**
	 * 导出 FE 谱面为外部格式文本（.sm / .ssc / .osu / .qua）。不支持的格式抛异常。
	 * @param diffName 写入文件的难度名（SM 的 #NOTES 名 / osu 的 Version / Quaver 的 DifficultyName）
	 */
	public static function exportFromSong(song:Dynamic, format:String, diffName:String = 'Challenge'):String
	{
		return switch(format)
		{
			case 'sm', 'ssc': stepManiaFromSong(song, format, diffName);
			case 'osu': osuFromSong(song, diffName);
			case 'qua': quaverFromSong(song, diffName);
			default: throw 'Unsupported export format: $format';
		}
	}

	/**
	 * 导出 FE 谱面为 StepMania 文本（.sm / .ssc）。
	 * @param diffName 写入文件的难度名（如 Challenge）
	 */
	public static function stepManiaFromSong(song:Dynamic, format:String = 'sm', diffName:String = 'Challenge'):String
	{
		var keys:Int = songKeys(song);
		var basic:BasicChart = songToBasic(song, keys);

		if(format == 'ssc')
		{
			var fmt = new StepManiaShark();
			fmt.fromBasicFormat(basic);
			renameSmDiff(fmt.data, diffName, true);
			return fmt.stringify().data;
		}
		else
		{
			var fmt = new StepMania();
			fmt.fromBasicFormat(basic);
			renameSmDiff(fmt.data, diffName, false);
			return fmt.stringify().data;
		}
	}

	/** 导出 FE 谱面为 osu!mania 文本（.osu） */
	static function osuFromSong(song:Dynamic, diffName:String):String
	{
		var keys:Int = songKeys(song);
		var basic:BasicChart = songToBasic(song, keys, true);
		var notes:Array<BasicNote> = firstDiffNotes(basic);

		// moonchart 的 osu 导出只认 type 里的 osu 原始类型串（'__OSU-<type>-<hitsound>-<sampleset>'），不看 length：
		// hold 必须标成 128，否则会被写成单点；mine 在 osu!mania 无对应，直接丢弃
		if(notes != null)
		{
			var kept:Array<BasicNote> = [];
			for(note in notes)
			{
				if(note.type == BasicNoteType.MINE) continue;
				if(note.length > 0) note.type = '__OSU-128-0-0';
				kept.push(note);
			}
			for(diffKey in [for(k in basic.data.diffs.keys()) k])
				basic.data.diffs.set(diffKey, kept);
			notes = kept;
		}

		var fmt:OsuMania = new OsuMania().fromBasicFormat(basic);

		// moonchart 用 lane * 512 / keys 算列位置，非 4/8K 时整除误差会把相邻列并到同一列；改写成列中心
		var hits:Array<Array<Int>> = fmt.data.HitObjects;
		if(notes != null && hits.length == notes.length)
		{
			for(i in 0...hits.length)
				hits[i][0] = Std.int((notes[i].lane + 0.5) * 512 / keys);
		}

		// fromBasicFormat 的 Version 取的是内部难度 key（恒为 default），这里换成用户选的名字
		fmt.data.Metadata.Version = diffName;
		return fmt.stringify().data;
	}

	/** 导出 FE 谱面为 Quaver 文本（.qua） */
	static function quaverFromSong(song:Dynamic, diffName:String):String
	{
		var basic:BasicChart = songToBasic(song, songKeys(song), true);
		var fmt:Quaver = new Quaver().fromBasicFormat(basic);

		// moonchart 的 Quaver 导出把 EndTime 写成了 hold 时长（应为绝对结束时间），按源音符改回来
		var notes:Array<BasicNote> = firstDiffNotes(basic);
		var hits:Array<QuaverHitObject> = fmt.data.HitObjects;
		if(notes != null && hits.length == notes.length)
		{
			for(i in 0...hits.length)
				if(notes[i].length > 0) hits[i].EndTime = Std.int(notes[i].time + notes[i].length);
		}

		fmt.data.DifficultyName = diffName;
		return fmt.stringify().data;
	}

	// moonchart 会把难度 key 规范化（小写/去空格），导出前改回用户选择的名字
	static function renameSmDiff(data:Dynamic, diffName:String, isSSC:Bool):Void
	{
		var notesMap:Map<String, Dynamic> = data.NOTES;
		var renamed:Map<String, Dynamic> = new Map();
		for(k => v in notesMap)
		{
			v.diff = diffName;
			if(isSSC) v.desc = diffName; // SSC 的难度显示名走 #DESCRIPTION
			renamed.set(diffName, v);
		}
		data.NOTES = renamed;
	}

	// ====================================================
	//  各格式加载 → BasicChart
	// ====================================================

	static function loadBasic(path:String, ?diff:String, ?midiLanes:Int):{info:ChartImportInfo, basic:BasicChart}
	{
		var format:String = detectFormat(path);
		return switch(format)
		{
			case 'sm': loadStepMania(path, false, diff);
			case 'ssc': loadStepMania(path, true, diff);
			case 'osu': loadOsu(path, diff);
			case 'osz': loadOszPack(path, diff);
			case 'qua': loadQuaver(path, diff);
			case 'qp': loadQuaverPack(path, diff);
			case 'mid': loadMidi(path, midiLanes ?? 4);
			case 'mc': loadMalody(path);
			default: throw 'Unsupported chart file: $path';
		}
	}

	static function loadStepMania(path:String, isSSC:Bool, ?diff:String):{info:ChartImportInfo, basic:BasicChart}
	{
		var fmt:Dynamic = isSSC ? new StepManiaShark().fromFile(path, null, diff) : new StepMania().fromFile(path, null, diff);
		if(fmt == null || fmt.data == null)
			throw 'Unable to parse StepMania file';

		var diffs:Array<String> = [];
		var keys:Int = 4;
		var first:Dynamic = null;
		var notesMap:Map<String, Dynamic> = fmt.data.NOTES;
		for(k => v in notesMap)
		{
			diffs.push(k);
			if(first == null) first = v;
		}
		if(diffs.length <= 0)
			throw 'StepMania file has no charts (#NOTES)';

		// dance-single=4 / dance-double=8，其余冷门舞种按首小节行宽推断
		var dance:String = Std.string(Reflect.field(first, 'dance'));
		if(dance == 'dance-single') keys = 4;
		else if(dance == 'dance-double') keys = 8;
		else
		{
			var measures:Array<Array<String>> = Reflect.field(first, 'notes');
			if(measures != null && measures.length > 0)
				for(row in measures[0])
					if(row.length > keys) keys = row.length;
			if(keys < 1) keys = 4;
		}

		return {
			info: {
				format: isSSC ? 'ssc' : 'sm',
				formatLabel: FORMAT_LABELS.get(isSSC ? 'ssc' : 'sm'),
				keys: keys,
				diffs: diffs,
				title: cleanName(Reflect.field(fmt.data, 'TITLE'), 'Unknown')
			},
			basic: fmt.toBasicFormat()
		};
	}

	static function loadOsu(path:String, ?diff:String):{info:ChartImportInfo, basic:BasicChart}
	{
		var fmt:OsuMania = new OsuMania().fromFile(path, null, diff);
		return finishOsu(fmt, 'osu', [Std.string(fmt.data.Metadata.Version).trim()]);
	}

	static function finishOsu(fmt:OsuMania, format:String, diffs:Array<String>):{info:ChartImportInfo, basic:BasicChart}
	{
		if(fmt == null || fmt.data == null)
			throw 'Not a valid osu!mania beatmap (Mode != mania)';
		var keys:Int = Std.int(fmt.data.Difficulty.CircleSize);
		if(keys < 1) keys = 4;
		if(keys > 16) keys = 16;
		return {
			info: {
				format: format,
				formatLabel: FORMAT_LABELS.get(format),
				keys: keys,
				diffs: diffs,
				title: cleanName(fmt.data.Metadata.Title, 'Unknown')
			},
			basic: fmt.toBasicFormat()
		};
	}

	static function loadOszPack(path:String, ?diff:String):{info:ChartImportInfo, basic:BasicChart}
	{
		var zip:ZipFile = new ZipFile().openFile(path);
		var entries = zip.filterEntries((entry) -> entry.fileName.toLowerCase().endsWith('.osu'));
		if(entries.length <= 0)
			throw 'No .osu beatmaps found inside the .osz';

		var parsed:Array<OsuMania> = [];
		for(entry in entries)
		{
			try
			{
				// 同包里可能混有 osu!/taiko/catch 难度（fromOsu 对非 mania 模式直接抛错），跳过
				var fmt:OsuMania = new OsuMania().fromOsu(zip.unzipString(entry));
				if(fmt != null && fmt.data != null)
					parsed.push(fmt);
			}
			catch(e:Dynamic) {}
		}
		if(parsed.length <= 0)
			throw 'No osu!mania (Mode 3) charts inside the .osz';

		var diffs:Array<String> = [for(fmt in parsed) Std.string(fmt.data.Metadata.Version).trim()];
		var selected:OsuMania = null;
		if(diff != null)
		{
			for(fmt in parsed)
			{
				if(Std.string(fmt.data.Metadata.Version).trim() == diff)
				{
					selected = fmt;
					break;
				}
			}
		}
		if(selected == null) selected = parsed[0];

		return finishOsu(selected, 'osz', diffs);
	}

	static function loadQuaver(path:String, ?diff:String):{info:ChartImportInfo, basic:BasicChart}
	{
		var fmt:Quaver = new Quaver().fromFile(path, null, diff);
		var diffName:String = Std.string(fmt.data.DifficultyName ?? 'Normal');
		return finishQuaver(fmt, 'qua', [diffName]);
	}

	static function finishQuaver(fmt:Quaver, format:String, diffs:Array<String>):{info:ChartImportInfo, basic:BasicChart}
	{
		if(fmt == null || fmt.data == null)
			throw 'Unable to parse Quaver file';

		var basic:BasicChart = fmt.toBasicFormat();
		// moonchart 的 Quaver 解析按 1 起算读 Lane（写入时却是 0 起），这里统一补回 0 起，
		// 否则真实 .qua 的每一列都会左移一列、最左列还会变成 -1
		for(k => notes in basic.data.diffs)
			for(note in notes)
				note.lane += 1;

		return {
			info: {
				format: format,
				formatLabel: FORMAT_LABELS.get(format),
				keys: Std.string(fmt.data.Mode) == 'Keys4' ? 4 : 7,
				diffs: diffs,
				title: cleanName(fmt.data.Title, 'Unknown')
			},
			basic: basic
		};
	}

	static function loadQuaverPack(path:String, ?diff:String):{info:ChartImportInfo, basic:BasicChart}
	{
		var zip:ZipFile = new ZipFile().openFile(path);
		var entries = zip.filterEntries((entry) -> entry.fileName.toLowerCase().endsWith('.qua'));
		if(entries.length <= 0)
			throw 'No .qua charts found inside the .qp';

		var parsed:Array<Quaver> = [];
		for(entry in entries)
		{
			var fmt:Quaver = new Quaver().fromQuaver(zip.unzipString(entry));
			if(fmt != null && fmt.data != null)
				parsed.push(fmt);
		}
		if(parsed.length <= 0)
			throw 'Unable to parse any .qua charts inside the .qp';

		var diffs:Array<String> = [for(fmt in parsed) Std.string(fmt.data.DifficultyName ?? 'Normal')];
		var selected:Quaver = null;
		if(diff != null)
		{
			for(fmt in parsed)
			{
				if(Std.string(fmt.data.DifficultyName) == diff)
				{
					selected = fmt;
					break;
				}
			}
		}
		if(selected == null) selected = parsed[0];

		return finishQuaver(selected, 'qp', diffs);
	}

	static function loadMidi(path:String, lanes:Int):{info:ChartImportInfo, basic:BasicChart}
	{
		var midi:Midi = new Midi().fromFile(path);
		// MIDI 没有轨道概念，note 的 pitch 直接对目标键数取模铺轨
		midi.strumlinesLength = 1;
		midi.lanesLength = lanes;
		var name:String = path.substr(path.lastIndexOf('/') + 1);
		name = name.substr(0, name.lastIndexOf('.'));
		return {
			info: {
				format: 'mid',
				formatLabel: FORMAT_LABELS.get('mid'),
				keys: 4,
				diffs: ['MIDI'],
				title: name
			},
			basic: midi.toBasicFormat()
		};
	}

	static function loadMalody(path:String):{info:ChartImportInfo, basic:BasicChart}
	{
		// MalodyResult 是 MalodyChart 的模块子类型，这里用推断避免跨模块限定
		var result = MalodyChart.fromFile(path);
		return {
			info: {
				format: 'mc',
				formatLabel: FORMAT_LABELS.get('mc'),
				keys: result.keys,
				diffs: [result.diff],
				title: result.title
			},
			basic: result.chart
		};
	}

	static function firstDiffNotes(chart:BasicChart):Array<BasicNote>
	{
		for(k => notes in chart.data.diffs)
			return notes;
		return null;
	}

	// ====================================================
	//  BasicChart → FE 谱面（核心 section 构建）
	// ====================================================

	static function buildSong(meta:BasicMetaData, notes:Array<BasicNote>, keys:Int):Dynamic
	{
		var bpmChanges:Array<BasicBPMChange> = meta.bpmChanges.copy();
		if(bpmChanges.length <= 0)
			bpmChanges.push({time: 0, bpm: 120, beatsPerMeasure: 4, stepsPerBeat: 4});
		Timing.sortBPMChanges(bpmChanges);
		bpmChanges = Timing.cleanBPMChanges(bpmChanges);

		// 同一时间点的多条变速取最后一条（osu 解析会固定在 0 点补一条，拆小节会切出 0 拍 section）
		var merged:Array<BasicBPMChange> = [bpmChanges[0]];
		for(i in 1...bpmChanges.length)
		{
			var change = bpmChanges[i];
			var prev = merged[merged.length - 1];
			if(Math.abs(change.time - prev.time) < 0.01)
				merged[merged.length - 1] = change;
			else
				merged.push(change);
		}
		bpmChanges = merged;

		// SM 的 #OFFSET 按 moonchart 惯例烘焙进音符时间（time -= offset），引擎侧 offset 保持 0
		var bakeOffset:Float = meta.offset ?? 0;

		var measures:Array<BasicMeasure> = Timing.divideNotesToMeasures(notes, [], bpmChanges);
		if(measures.length <= 0)
		{
			// 只有一个 t=0 音符的谱（endTime=0）切不出小节，手工补一个
			measures = [{
				notes: notes.copy(),
				events: [],
				bpmChanges: [bpmChanges[0]],
				bpm: bpmChanges[0].bpm,
				beatsPerMeasure: bpmChanges[0].beatsPerMeasure,
				stepsPerBeat: 4,
				startTime: 0,
				endTime: 1600,
				length: 1600,
				snap: 4
			}];
		}
		var sections:Array<Dynamic> = [];
		var lastBpm:Float = bpmChanges[0].bpm;

		for(measure in measures)
		{
			if(measure.bpmChanges.length > 1)
			{
				// 小节内多次变速：在变速点把小节拆成多个子 section，
				// FE 的 Conductor 以 section 粒度重建 BPM 时间轴，不拆会整体错位
				var last:BasicBPMChange = measure.bpmChanges[0];
				var pushedBeats:Float = 0;
				var rest:Array<BasicNote> = measure.notes.copy();

				for(i in 1...measure.bpmChanges.length)
				{
					var next:BasicBPMChange = measure.bpmChanges[i];
					var elapsedBeats:Float = Timing.roundFloat((next.time - last.time) / Timing.crochet(last.bpm));
					var subNotes:Array<BasicNote> = [];
					while(rest.length > 0 && rest[0].time < next.time)
						subNotes.push(rest.shift());

					sections.push(makeSection(subNotes, elapsedBeats, last.bpm, keys, bakeOffset));
					pushedBeats += elapsedBeats;
					last = next;
				}

				var tailBeats:Float = Timing.roundFloat(measure.beatsPerMeasure - pushedBeats);
				if(tailBeats <= 0) tailBeats = 1;
				sections.push(makeSection(rest, tailBeats, last.bpm, keys, bakeOffset));
				lastBpm = last.bpm;
			}
			else
			{
				var change:Bool = measure.bpm != lastBpm;
				sections.push(makeSection(measure.notes, measure.beatsPerMeasure, change ? measure.bpm : null, keys, bakeOffset));
				lastBpm = measure.bpm;
			}
		}

		// divideNotesToMeasures 的小节区间是左闭右开：正好卡在最后一个 measure 结束点上的音符会掉出去，
		// 这里按拍把漏掉的尾部音符补成追加 section
		var tailStart:Float = measures[measures.length - 1].endTime;
		var tail:Array<BasicNote> = [];
		for(note in notes)
			if(note.time >= tailStart) tail.push(note);

		var tailBpm:Float = measures[measures.length - 1].bpm;
		while(tail.length > 0)
		{
			var sectionEnd:Float = tailStart + 4 * Timing.crochet(tailBpm);
			var chunk:Array<BasicNote> = [];
			while(tail.length > 0 && tail[0].time < sectionEnd)
				chunk.push(tail.shift());
			sections.push(makeSection(chunk, 4, null, keys, bakeOffset));
			tailStart = sectionEnd;
		}

		var speed:Float = 1.0;
		for(k => v in meta.scrollSpeeds)
		{
			speed = v;
			break;
		}
		if(speed == 0 || Math.isNaN(speed)) speed = 1.0;

		// Malody 音乐条目的偏移走引擎 offset（Conductor.offset = 谱面时间轴相对音乐前移），不烘焙
		var malodyOffset:Float = meta.extraData.get(MALODY_MUSIC_OFFSET) ?? 0;

		var song:Dynamic = {
			song: cleanName(meta.title, 'Unknown'),
			notes: sections,
			events: [],
			bpm: bpmChanges[0].bpm,
			needsVoices: false,
			speed: speed,
			offset: malodyOffset,
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			format: 'psych_v1_convert',
			mania: keys - 1,
			keyCount: keys,
			keycount: keys
		};

		var artist:String = meta.extraData.get(BasicMetaValues.SONG_ARTIST);
		if(artist != null && artist.length > 0) Reflect.setField(song, 'artist', artist);
		var charter:String = meta.extraData.get(BasicMetaValues.SONG_CHARTER);
		if(charter != null && charter.length > 0) Reflect.setField(song, 'charter', charter);

		return song;
	}

	static function makeSection(notes:Array<BasicNote>, beats:Float, bpm:Null<Float>, keys:Int, bakeOffset:Float):Dynamic
	{
		var sectionNotes:Array<Dynamic> = [];
		for(note in notes)
		{
			var lane:Int = note.lane;
			if(lane < 0) lane = 0;
			if(lane >= keys) lane = keys - 1;

			var time:Float = note.time - bakeOffset;
			var type:String = resolveNoteType(note.type);
			sectionNotes.push(type != null ? [time, lane, note.length, type] : [time, lane, note.length]);
		}

		var section:Dynamic = {
			sectionNotes: sectionNotes,
			sectionBeats: beats,
			mustHitSection: true
		};
		if(bpm != null)
		{
			section.changeBPM = true;
			section.bpm = bpm;
		}
		return section;
	}

	static function resolveNoteType(type:String):Null<String>
	{
		if(type == null) return null;
		// moonchart BasicNoteType.MINE = "mine"（SM 的 M / osu 等转换而来）
		if(type == BasicNoteType.MINE) return 'Hurt Note';
		return null;
	}

	/**
	 * 键数重映射（与 FE ChartingState.remapSongKeys 同一套数学）：
	 * 列按比例缩放，玩家块整体平移
	 */
	public static function scaleLanes(notes:Array<BasicNote>, from:Int, to:Int):Void
	{
		if(from == to || from <= 1 || to <= 1) return;
		var scale:Float = (to - 1) / (from - 1);
		for(note in notes)
		{
			var player:Int = Math.floor(note.lane / from);
			var col:Int = note.lane % from;
			var newCol:Int = Math.round(col * scale);
			if(newCol < 0) newCol = 0;
			if(newCol > to - 1) newCol = to - 1;
			note.lane = player * to + newCol;
		}
	}

	// ====================================================
	//  FE 谱面 → BasicChart（导出用）
	// ====================================================

	static function songKeys(song:Dynamic):Int
	{
		var value:Dynamic = Reflect.field(song, 'mania');
		if(Std.isOfType(value, Int)) return Std.int(value) + 1;
		value = Reflect.field(song, 'keyCount');
		if(Std.isOfType(value, Int)) return Std.int(value);
		value = Reflect.field(song, 'keycount');
		if(Std.isOfType(value, Int)) return Std.int(value);
		return 4;
	}

	/**
	 * @param singleSide osu / Quaver 是单人不分侧：只导玩家侧（lane < keys），对手侧丢弃
	 */
	static function songToBasic(song:Dynamic, keys:Int, singleSide:Bool = false):BasicChart
	{
		// BPM 时间线：与 Conductor.mapBPMChanges 同一套累计逻辑
		var bpmChanges:Array<BasicBPMChange> = [];
		var currentBpm:Float = Reflect.field(song, 'bpm') ?? 120;
		var cumulativeTime:Float = 0;
		bpmChanges.push({time: 0, bpm: currentBpm, beatsPerMeasure: 4, stepsPerBeat: 4});

		for(section in (Reflect.field(song, 'notes'):Array<Dynamic>))
		{
			var beats:Float = Reflect.field(section, 'sectionBeats') ?? 4;
			if(beats <= 0) beats = 4;
			if(Reflect.field(section, 'changeBPM') == true)
			{
				var sectionBpm:Null<Float> = Reflect.field(section, 'bpm');
				if(sectionBpm != null && sectionBpm > 0 && sectionBpm != currentBpm)
				{
					currentBpm = sectionBpm;
					bpmChanges.push({time: cumulativeTime, bpm: currentBpm, beatsPerMeasure: 4, stepsPerBeat: 4});
				}
			}
			cumulativeTime += beats * (60000 / currentBpm);
		}

		// SM 单谱面最多 8 轨（dance-double），>4K 时把两侧各压回 4 轨
		var compress:Bool = !singleSide && keys > 4;
		var colScale:Float = compress ? 3 / (keys - 1) : 1;

		var notes:Array<BasicNote> = [];
		for(section in (Reflect.field(song, 'notes'):Array<Dynamic>))
		{
			for(noteData in (Reflect.field(section, 'sectionNotes'):Array<Array<Dynamic>>))
			{
				if(noteData == null || noteData.length < 2) continue;
				var lane:Int = Std.int(noteData[1]);
				if(singleSide && lane >= keys) continue;
				var type:Dynamic = (noteData.length >= 4) ? noteData[3] : null;
				var basicType:String = "";
				if(Std.isOfType(type, String))
				{
					if(type.toLowerCase() == 'hurt note') basicType = BasicNoteType.MINE;
				}
				else if(Std.isOfType(type, Int) && Std.int(type) == 3)
				{
					// 旧式类型索引 3 = Hurt Note（Note.defaultNoteTypes）
					basicType = BasicNoteType.MINE;
				}

				if(compress)
				{
					var player:Int = Math.floor(lane / keys);
					var col:Int = Math.round((lane % keys) * colScale);
					if(col < 0) col = 0;
					if(col > 3) col = 3;
					lane = player * 4 + col;
				}
				if(lane < 0) lane = 0;

				notes.push({
					time: noteData[0],
					lane: lane,
					length: noteData[2] ?? 0,
					type: basicType
				});
			}
		}
		Timing.sortNotes(notes);

		var title:String = Std.string(Reflect.field(song, 'song') ?? 'Unknown');
		var diffs:Map<String, Array<BasicNote>> = new Map();
		diffs.set('default', notes);

		var extra:Map<String, Dynamic> = new Map();
		var artist:String = Reflect.field(song, 'artist');
		if(artist != null) extra.set(BasicMetaValues.SONG_ARTIST, artist);
		var charter:String = Reflect.field(song, 'charter');
		if(charter != null) extra.set(BasicMetaValues.SONG_CHARTER, charter);
		// osu / Quaver 的键数取 LANES_LENGTH，音频名取 AUDIO_FILE（引擎的歌曲目录惯例是 inst.ogg）
		extra.set(BasicMetaValues.LANES_LENGTH, keys);
		extra.set(BasicMetaValues.STRUMLINE_LANES, 1);
		extra.set(BasicMetaValues.STRUMLINE_KEYS, keys);
		extra.set(BasicMetaValues.AUDIO_FILE, 'inst.ogg');

		return {
			data: {diffs: diffs, events: []},
			meta: {
				title: title,
				bpmChanges: bpmChanges,
				scrollSpeeds: ['default' => (Reflect.field(song, 'speed') ?? 1.0)],
				offset: Reflect.field(song, 'offset') ?? 0,
				extraData: extra
			}
		};
	}
}

typedef ChartImportInfo =
{
	format:String,
	formatLabel:String,
	keys:Int,
	diffs:Array<String>,
	title:String
}
