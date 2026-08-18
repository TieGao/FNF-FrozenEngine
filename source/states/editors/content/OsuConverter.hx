package states.editors.content;

import backend.Song;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import haxe.ds.StringMap;

using StringTools;

typedef BpmChange =
{
	var time:Float;
	var bpm:Float;
	var ?meter:Int;
}

typedef OsuNote =
{
	var time:Float;
	var lane:Int;
	var length:Float;
}

/**
 * 转换 Psych Engine 的 SwagSong 与 Osu! Mania (.osu) 文件。
 */
class OsuConverter
{
	// ============ Psych → OSU ============

	/**
	 * 将当前的 SwagSong 导出为 .osu 文件，返回是否成功。
	 * @param song 当前编辑的歌曲数据
	 * @param savePath 输出文件路径（含文件名）
	 */
	public static function convertPsychToOsu(song:SwagSong, savePath:String):Bool
	{
		if (song == null) return false;
		try
		{
			trace("========== Psych → OSU 转换开始 ==========");
			
			var lines:Array<String> = [];
			var bpmChanges:Array<BpmChange> = extractBpmChanges(song);
			var notes:Array<OsuNote> = extractNotes(song);

			// 调试输出：转换前的数据统计
			trace('【转换前】歌曲名称: ${song.song}');
			trace('【转换前】BPM: ${song.bpm}');
			trace('【转换前】小节数: ${song.notes.length}');
			
			// 统计原始音符总数
			var totalRawNotes:Int = 0;
			for (section in song.notes)
			{
				totalRawNotes += section.sectionNotes.length;
			}
			trace('【转换前】原始音符总数: $totalRawNotes');
			
			// 调试输出：提取后的音符
			trace('【提取后】提取到的 OsuNote 数量: ${notes.length}');
			
			// [General]
			lines.push("[General]");
			lines.push('AudioFilename: ${Paths.formatToSongPath(song.song)}.mp3');
			lines.push('AudioLeadIn: ${Std.int(song.offset ?? 0)}');
			lines.push('PreviewTime: -1');
			lines.push('Countdown: 1');
			lines.push('SampleSet: Normal');
			lines.push('StackLeniency: 0.7');
			lines.push('Mode: 3'); // Mania
			lines.push('LetterboxInBreaks: 0');
			lines.push('SpecialStyle: 0');
			lines.push('WidescreenStoryboard: 0');
			lines.push("");

			// [Metadata]
			lines.push("[Metadata]");
			lines.push('Title:${song.song}');
			lines.push('TitleUnicode:${song.song}');
			lines.push('Artist:Unknown');
			lines.push('ArtistUnicode:');
			lines.push('Creator:PsychChartEditor');
			lines.push('Version:Normal');
			lines.push('Source:');
			lines.push('BeatmapID:0');
			lines.push('BeatmapSetID:0');
			lines.push("");

			// [Difficulty]
			var keys:Int = getKeyCount(song);
			lines.push("[Difficulty]");
			lines.push('HPDrainRate:0');
			lines.push('CircleSize:$keys');
			lines.push('OverallDifficulty:0');
			lines.push('ApproachRate:0');
			// SliderMultiplier 用于控制滚动速度，此处映射 Psych 的 scrollSpeed
			var osuSpeed:Float = (song.speed ?? 1.0) * 0.45; // 经验系数
			lines.push('SliderMultiplier:$osuSpeed');
			lines.push('SliderTickRate:0');
			lines.push("");

			// [TimingPoints]
			lines.push("[TimingPoints]");
			for (bpm in bpmChanges)
			{
				var beatLength:Float = 60000.0 / bpm.bpm;
				var meter:Int = bpm.meter ?? 4;
				lines.push('${bpm.time}, $beatLength, $meter, 1, 0, 100, 1, 0');
			}
			lines.push("");

			// [HitObjects]
			lines.push("[HitObjects]");
			var circleSize:Int = keys;
			var writtenNotes:Int = 0;
			for (note in notes)
			{
				var x:Int = Std.int((note.lane / keys) * 512); // 0~511
				var time:Int = Std.int(note.time);
				var type:Int = (note.length > 0) ? 128 : 1; // 128 = hold, 1 = normal
				var hitsound:Int = 0;
				var objectParams:String = (type == 128) ? '${time + Std.int(note.length)}:0:0:0:0' : '0:0:0:0:0';
				lines.push('$x, 0, $time, $type, $hitsound, $objectParams');
				writtenNotes++;
			}
			trace('【写入】实际写入 HitObjects 数量: $writtenNotes');

			// 写入文件
			File.saveContent(savePath, lines.join("\n"));
			trace('【完成】文件已保存到: $savePath');
			trace("========== Psych → OSU 转换完成 ==========");
			return true;
		}
		catch (e:Dynamic)
		{
			trace('OSU export error: $e');
			return false;
		}
	}

	// ============ OSU → Psych ============

	/**
	 * 从 .osu 文件读取并转换为 SwagSong，返回解析后的歌曲数据。
	 * @param filePath .osu 文件路径
	 */
	// ============ OSU → Psych ============

    /**
     * 从 .osu 文件读取并转换为 SwagSong，返回解析后的歌曲数据。
     * @param filePath .osu 文件路径
     */
    public static function convertOsuToPsych(filePath:String):SwagSong
	{
		trace("========== OSU → Psych 转换开始 ==========");
		
		if (!FileSystem.exists(filePath))
		{
			trace('【错误】文件不存在: $filePath');
			return null;
		}

		var content:String;
		var tempDir:String = null;
		var audioPath:String = null;

		// 检测是否为 OSZ 压缩包
		if (filePath.toLowerCase().endsWith(".osz"))
		{
			trace('【检测】OSZ 压缩包，正在提取...');
			var result = OsuArchiveExtractor.extract(filePath);

			if (result == null)
			{
				trace('【错误】OSZ 提取失败');
				return null;
			}

			content = result.osuContent;
			audioPath = result.audioPath;
			tempDir = result.tempDir;
			trace('【提取】OSU 内容长度: ${content.length}');
		}
		else
		{
			content = File.getContent(filePath);
		}

		// 解析 OSU 文件
		var sections:Map<String, Array<String>> = parseOsuSections(content);
		var metadata:Map<String, String> = parseKeyValues(sections["Metadata"]);
		var difficulty:Map<String, String> = parseKeyValues(sections["Difficulty"]);
		var timingLines:Array<String> = sections["TimingPoints"] ?? [];
		var hitLines:Array<String> = sections["HitObjects"] ?? [];

		// 提取 BPM 变化
		var bpmChanges:Array<BpmChange> = [];
		for (line in timingLines)
		{
			var parts = line.split(",");
			if (parts.length < 8) continue;
			var time:Float = Std.parseFloat(parts[0]);
			var beatLength:Float = Std.parseFloat(parts[1]);
			var meter:Int = Std.parseInt(parts[2]);
			var uninherited:Int = Std.parseInt(parts[6]);
			if (uninherited == 1)
			{
				var bpm:Float = 60000.0 / beatLength;
				bpmChanges.push({ time: time, bpm: bpm, meter: meter });
			}
		}

		if (bpmChanges.length == 0)
			bpmChanges.push({ time: 0, bpm: 120, meter: 4 });

		bpmChanges.sort((a, b) -> Std.int(a.time - b.time));

		// 获取键数
		var keys:Int = Std.parseInt(difficulty.get("CircleSize"));
		if (keys < 1) keys = 4;

		// 提取音符
		var notes:Array<OsuNote> = [];
		for (line in hitLines)
		{
			var parts = line.split(",");
			if (parts.length < 6) continue;
			var x:Float = Std.parseFloat(parts[0]);
			var time:Float = Std.parseFloat(parts[2]);
			var type:Int = Std.parseInt(parts[3]);
			var params:String = parts[5];
			var lane:Int = Math.floor((x / 512) * keys);
			var length:Float = 0;

			if (type == 128) // hold note
			{
				var endTimeStr = params.split(":")[0];
				var endTime:Float = Std.parseFloat(endTimeStr);
				if (endTime > time) length = endTime - time;
			}
			notes.push({ time: time, lane: lane, length: length });
		}

		notes.sort((a, b) -> Std.int(a.time - b.time));

		// 获取歌曲名
		var songName:String = metadata.get("Title") ?? "Untitled";

		// 创建 SwagSong
		var song:SwagSong = {
			song: songName,
			notes: [],
			events: [],
			bpm: bpmChanges[0].bpm,
			needsVoices: true,
			speed: 1.0,
			offset: 0,
			player1: "bf",
			player2: "dad",
			gfVersion: "gf",
			stage: "stage",
			format: "psych_v1",
			mania: keys - 1,
			keyCount: keys,
			keycount: keys
		};

		// 生成小节
		var beatsPerSection:Float = 4.0;
		var totalSections:Int = 1;

		if (notes.length > 0)
		{
			var lastNoteTime:Float = notes[notes.length - 1].time;
			var totalBeats:Float = 0;
			var currentTime:Float = 0;
			var currentBpm:Float = bpmChanges[0].bpm;
			var bpmIndex:Int = 0;

			while (currentTime < lastNoteTime)
			{
				var nextBpmTime:Float = (bpmIndex + 1 < bpmChanges.length) ? bpmChanges[bpmIndex + 1].time : lastNoteTime + 1;
				var segmentDuration:Float = nextBpmTime - currentTime;

				if (segmentDuration <= 0)
				{
					bpmIndex++;
					if (bpmIndex >= bpmChanges.length) break;
					currentBpm = bpmChanges[bpmIndex].bpm;
					continue;
				}

				var beatsInSegment:Float = segmentDuration / (60000 / currentBpm);
				totalBeats += beatsInSegment;
				currentTime = nextBpmTime;
				bpmIndex++;
				if (bpmIndex < bpmChanges.length)
					currentBpm = bpmChanges[bpmIndex].bpm;
			}

			totalSections = Math.ceil(totalBeats / beatsPerSection) + 4;
			trace('【计算】总拍数: $totalBeats, 生成小节数: $totalSections');
		}

		var swagSections:Array<SwagSection> = [];
		var sectionTime:Float = 0;
		var bpmIndex:Int = 0;
		var currentBpm:Float = bpmChanges[0].bpm;

		for (i in 0...totalSections)
		{
			while (bpmIndex + 1 < bpmChanges.length && bpmChanges[bpmIndex + 1].time <= sectionTime + 0.1)
			{
				bpmIndex++;
				currentBpm = bpmChanges[bpmIndex].bpm;
			}

			var startTime:Float = sectionTime;
			var endTime:Float = sectionTime + beatsPerSection * (60000 / currentBpm);

			var sectionNotes:Array<Array<Dynamic>> = [];
			for (note in notes)
			{
				if (note.time >= startTime && note.time < endTime)
				{
					sectionNotes.push([note.time, note.lane, note.length, null]);
				}
			}

			swagSections.push({
				sectionNotes: sectionNotes,
				sectionBeats: beatsPerSection,
				mustHitSection: true,
				bpm: currentBpm,
				changeBPM: (i == 0 || bpmChanges[bpmIndex].time >= startTime),
				altAnim: false,
				gfSection: false
			});

			sectionTime = endTime;
		}

		song.notes = swagSections;

		// ========== 关键: 保存音频到歌曲目录 ==========
		if (audioPath != null)
		{
			var savedPath = OsuArchiveExtractor.saveAudioToSong(audioPath, songName);
			if (savedPath != null)
				trace('【完成】音频已保存到歌曲目录');
		}

		// 清理临时目录
		if (tempDir != null)
			OsuArchiveExtractor.cleanup(tempDir);

		trace("========== OSU → Psych 转换完成 ==========");
		return song;
	}

	// ============ 内部辅助函数 ============

	private static function getKeyCount(song:SwagSong):Int
	{
		// 优先从 mania 字段读取，否则使用 GRID_COLUMNS_PER_PLAYER（默认 4）
		if (Reflect.hasField(song, "mania")) return Reflect.field(song, "mania") + 1;
		if (Reflect.hasField(song, "keyCount")) return Reflect.field(song, "keyCount");
		if (Reflect.hasField(song, "keycount")) return Reflect.field(song, "keycount");
		return 4;
	}

	private static function extractBpmChanges(song:SwagSong):Array<BpmChange>
	{
		var changes:Array<BpmChange> = [];
		var time:Float = 0;
		var currentBpm:Float = song.bpm;
		var meter:Int = 4;
		changes.push({ time: 0, bpm: currentBpm, meter: meter });

		for (section in song.notes)
		{
			if (section.changeBPM)
			{
				currentBpm = section.bpm;
			}
			// 计算该小节时长（毫秒）
			var beats = section.sectionBeats ?? 4;
			var duration = beats * (60000 / currentBpm);
			time += duration;
		}
		// 更准确：遍历 section，在 changeBPM 为 true 的 section 起始时间记录变化
		time = 0;
		changes = [];
		currentBpm = song.bpm;
		changes.push({ time: 0, bpm: currentBpm, meter: 4 });
		for (section in song.notes)
		{
			var beats = section.sectionBeats ?? 4;
			var duration = beats * (60000 / currentBpm);
			if (section.changeBPM)
			{
				// 变化点在该 section 起始处（即 time 变量当前值）
				changes.push({ time: time, bpm: section.bpm, meter: 4 });
				currentBpm = section.bpm;
			}
			time += duration;
		}
		// 去重（时间相近的合并）
		var unique:Array<BpmChange> = [];
		for (c in changes)
		{
			if (unique.length == 0 || Math.abs(c.time - unique[unique.length - 1].time) > 0.1)
				unique.push(c);
			else
				unique[unique.length - 1] = c; // 保留最新的
		}
		return unique;
	}

	private static function extractNotes(song:SwagSong):Array<OsuNote>
	{
		var result:Array<OsuNote> = [];
		var keys = getKeyCount(song);
		for (section in song.notes)
		{
			// 仅提取 mustHitSection 为 true 的音符（玩家侧）
			if (!section.mustHitSection) continue;
			for (note in section.sectionNotes)
			{
				var time:Float = note[0];
				var data:Int = Std.int(note[1]); // 全局列
				var length:Float = note[2] ?? 0;
				if (data >= keys) continue;
				result.push({ time: time, lane: data, length: length });
			}
		}
		result.sort((a, b) -> Std.int(a.time - b.time));
		return result;
	}

	public static function parseOsuSections(content:String):Map<String, Array<String>>
	{
		var sections:Map<String, Array<String>> = new Map();
		var lines = content.split("\n");
		var currentSection:String = null;
		var currentLines:Array<String> = [];
		for (line in lines)
		{
			line = line.trim();
			if (line.startsWith("[") && line.endsWith("]"))
			{
				if (currentSection != null)
					sections.set(currentSection, currentLines);
				currentSection = line.substr(1, line.length - 2);
				currentLines = [];
			}
			else if (line.length > 0)
			{
				currentLines.push(line);
			}
		}
		if (currentSection != null)
			sections.set(currentSection, currentLines);
		return sections;
	}

	public static function parseKeyValues(lines:Array<String>):Map<String, String>
	{
		var map:Map<String, String> = new Map();
		if (lines == null) return map;
		for (line in lines)
		{
			var idx = line.indexOf(":");
			if (idx == -1) continue;
			var key = line.substr(0, idx).trim();
			var value = line.substr(idx + 1).trim();
			map.set(key, value);
		}
		return map;
	}
}