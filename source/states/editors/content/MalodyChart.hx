package states.editors.content;

import haxe.Json;
import moonchart.formats.BasicFormat;
import sys.io.File;

using StringTools;

/**
 * Malody .mc（Key 模式）解析器，输出 moonchart BasicChart 走统一转换管线。
 * 格式参考：B站专栏 cv36572680《Malody Key模式谱面文件解析》（非官方文档，社区逆向）。
 *
 * .mc 为纯 JSON，五个部分：meta / time / effect / note / extra
 *  - meta.mode == 0 为 Key 模式（下落式），其余模式不支持
 *  - 键数在 meta.mode_ext.column（常规 4~9，改键谱可到 10）
 *  - beat 三元组 [小节, 分子, 分母]：拍数 = (小节 + 分子/分母) * 4（Key 模式固定 4/4）
 *  - time[] 为 BPM 变化表，每项 {beat, bpm}
 *  - note[] 每项 {beat, column, endbeat?}，有 endbeat 即 hold；column 从 0 起从左到右
 *  - 最后一个 note（type==1）是音乐条目，带 offset（音乐播放位置向后偏移，毫秒），不是音符
 *  - effect 的 scroll（变速/倒流）/jump/sign 与逐 note key 音在 FNF 无对应，导入时丢弃
 */
class MalodyChart
{
	public static inline var MODE_KEY:Int = 0;

	public static function fromFile(path:String):MalodyResult
	{
		return parse(File.getContent(path));
	}

	public static function parse(content:String):MalodyResult
	{
		var raw:Dynamic = Json.parse(content);
		var meta:Dynamic = Reflect.field(raw, 'meta');
		if(meta == null)
			throw 'Malody: missing "meta" section';

		var mode:Int = Std.int(Reflect.field(meta, 'mode') ?? MODE_KEY);
		if(mode != MODE_KEY)
			throw 'Malody: only Key mode charts are supported (file mode = $mode)';

		var modeExt:Dynamic = Reflect.field(meta, 'mode_ext') ?? {};
		var keys:Int = Std.int(Reflect.field(modeExt, 'column') ?? 4);
		if(keys < 1) keys = 4;

		var bpmChanges:Array<BasicBPMChange> = parseTiming(Reflect.field(raw, 'time'));

		// 音乐条目（type==1）的 offset：正值 = 音乐延后 X 毫秒。
		// FNF 音乐恒从 0 开始，等价于所有音符后移 X，由统一管线以 meta.offset = -X 烘焙。
		var musicOffset:Float = 0;
		var noteEntries:Array<Dynamic> = cast Reflect.field(raw, 'note') ?? [];
		for(entry in noteEntries)
		{
			if(Std.int(Reflect.field(entry, 'type') ?? 0) == 1)
			{
				musicOffset = Std.parseFloat(Std.string(Reflect.field(entry, 'offset') ?? 0));
				if(Math.isNaN(musicOffset)) musicOffset = 0;
				break;
			}
		}

		var notes:Array<BasicNote> = [];
		for(entry in noteEntries)
		{
			if(Std.int(Reflect.field(entry, 'type') ?? 0) == 1)
				continue;

			var startBeat:Float = beatsOf(Reflect.field(entry, 'beat'));
			var note:BasicNote = {
				time: timeAtBeat(startBeat, bpmChanges),
				lane: Std.int(Reflect.field(entry, 'column') ?? 0),
				length: 0,
				type: ""
			};

			var endBeatTuple:Dynamic = Reflect.field(entry, 'endbeat');
			if(endBeatTuple != null)
			{
				var endMs:Float = timeAtBeat(beatsOf(endBeatTuple), bpmChanges);
				if(endMs > note.time) note.length = endMs - note.time;
			}
			notes.push(note);
		}
		notes.sort((a, b) -> a.time < b.time ? -1 : 1);

		var songMeta:Dynamic = Reflect.field(meta, 'song') ?? {};
		var diff:String = Std.string(Reflect.field(meta, 'version') ?? "Malody");
		var title:String = Std.string(Reflect.field(songMeta, 'title') ?? "Unknown");

		var chart:BasicChart = {
			data: {diffs: [diff => notes], events: []},
			meta: {
				title: title,
				bpmChanges: bpmChanges,
				scrollSpeeds: [diff => 1.0],
				offset: 0,
				extraData: [
					BasicMetaValues.LANES_LENGTH => keys,
					BasicMetaValues.STRUMLINE_LANES => 1,
					BasicMetaValues.STRUMLINE_KEYS => keys,
					BasicMetaValues.SONG_ARTIST => Std.string(Reflect.field(songMeta, 'artist') ?? ""),
					BasicMetaValues.SONG_CHARTER => Std.string(Reflect.field(meta, 'creator') ?? ""),
					// 音乐条目的 offset 交给引擎 song.offset 处理（Conductor 语义 = 谱面时间轴相对音乐前移），
					// 不烘焙进音符时间，避免 BPM 时间轴与音符错位
					ChartConvertCore.MALODY_MUSIC_OFFSET => musicOffset
				]
			}
		};

		return {
			chart: chart,
			keys: keys,
			diff: diff,
			title: title
		};
	}

	static function parseTiming(timeEntries:Array<Dynamic>):Array<BasicBPMChange>
	{
		var changes:Array<BasicBPMChange> = [];
		if(timeEntries == null || timeEntries.length == 0)
		{
			changes.push({time: 0, bpm: 120, beatsPerMeasure: 4, stepsPerBeat: 4});
			return changes;
		}

		var entries:Array<{beat:Float, bpm:Float}> = [];
		for(entry in timeEntries)
		{
			var bpm:Float = Std.parseFloat(Std.string(Reflect.field(entry, 'bpm') ?? 120));
			if(bpm <= 0) bpm = 120;
			entries.push({beat: beatsOf(Reflect.field(entry, 'beat')), bpm: bpm});
		}
		entries.sort((a, b) -> a.beat < b.beat ? -1 : 1);

		var time:Float = 0;
		var lastBeat:Float = entries[0].beat;
		var lastBpm:Float = entries[0].bpm;

		// 首个变速点之前的时间轴从 0 拍起算
		changes.push({time: 0, bpm: lastBpm, beatsPerMeasure: 4, stepsPerBeat: 4});
		for(i in 1...entries.length)
		{
			var e = entries[i];
			time += ((e.beat - lastBeat) / lastBpm) * 60000;
			lastBeat = e.beat;
			lastBpm = e.bpm;
			changes.push({time: time, bpm: lastBpm, beatsPerMeasure: 4, stepsPerBeat: 4});
		}
		return changes;
	}

	static inline function beatsOf(beatTuple:Dynamic):Float
	{
		if(beatTuple == null) return 0;
		var bar:Float = Std.parseFloat(Std.string(beatTuple[0] ?? 0));
		var num:Float = Std.parseFloat(Std.string(beatTuple[1] ?? 0));
		var den:Float = Std.parseFloat(Std.string(beatTuple[2] ?? 1));
		if(den <= 0) den = 1;
		return (bar + num / den) * 4;
	}

	static function timeAtBeat(beat:Float, bpmChanges:Array<BasicBPMChange>):Float
	{
		var lastTime:Float = 0;
		var lastBeat:Float = 0;
		var bpm:Float = bpmChanges[0].bpm;

		for(i in 1...bpmChanges.length)
		{
			var change = bpmChanges[i];
			var segBeats:Float = (change.time - lastTime) / (60000 / bpm);
			if(beat <= lastBeat + segBeats)
				break;
			lastBeat += segBeats;
			lastTime = change.time;
			bpm = change.bpm;
		}
		return lastTime + (beat - lastBeat) * (60000 / bpm);
	}
}

typedef MalodyResult =
{
	chart:BasicChart,
	keys:Int,
	diff:String,
	title:String
}
