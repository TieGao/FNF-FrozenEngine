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
 * 读取 osu!mania (.osu) 谱面并转成 SwagSong。导出方向走 ChartConvertCore（moonchart）。
 */
class OsuConverter
{
	// ============ OSU → Psych ============

	/**
	 * 从 .osu 文件读取并转换为 SwagSong，返回解析后的歌曲数据。
	 * @param filePath .osu 文件路径
	 */
	public static function convertOsuToPsych(filePath:String, ?chartCategory:String, ?chartSongDir:String):SwagSong
    {
        //trace("========== OSU → Psych 转换开始 ==========");
        
        if (!FileSystem.exists(filePath))
        {
            trace('【错误】文件不存在: $filePath');
            return null;
        }
        
        var content:String = File.getContent(filePath);
        var sections:Map<String, Array<String>> = parseOsuSections(content);

        var general:Map<String, String> = parseKeyValues(sections["General"]);
        var metadata:Map<String, String> = parseKeyValues(sections["Metadata"]);
        var difficulty:Map<String, String> = parseKeyValues(sections["Difficulty"]);
        var timingLines:Array<String> = sections["TimingPoints"] ?? [];
        var hitLines:Array<String> = sections["HitObjects"] ?? [];

        //trace('【解析】HitObjects 行数: ${hitLines.length}');

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
            if (uninherited == 1) // BPM change
            {
                var bpm:Float = 60000.0 / beatLength;
                bpmChanges.push({ time: time, bpm: bpm, meter: meter });
            }
        }
        if (bpmChanges.length == 0)
        {
            bpmChanges.push({ time: 0, bpm: 120, meter: 4 });
            trace('【警告】未找到 TimingPoints，使用默认 BPM=120');
        }
        // 按时间排序
        bpmChanges.sort((a, b) -> Std.int(a.time - b.time));
        
        //trace('【提取】BPM变化点数: ${bpmChanges.length}');
        for (bpm in bpmChanges)
        {
//            trace('  time=${bpm.time}, bpm=${bpm.bpm}');
        }

        // 提取音符
        var keys:Int = Std.parseInt(difficulty.get("CircleSize"));
        if (keys < 1) keys = 4;
        
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
        // 按时间排序
        notes.sort((a, b) -> Std.int(a.time - b.time));
        
        //trace('【提取】OSU音符总数: ${notes.length}');
        if (notes.length > 0)
        {
           // trace('【提取】第一个音符时间: ${notes[0].time}ms, 最后一个音符时间: ${notes[notes.length - 1].time}ms');
        }

       		var sourceInfo:Array<String> = getChartSourceInfo(filePath);
		if (chartCategory == null) chartCategory = sourceInfo[0];
		if (chartSongDir == null) chartSongDir = sourceInfo[1];
		var songName:String = (chartSongDir != null && chartSongDir.length > 0)
			? chartSongDir
			: (metadata.get("Title") ?? "Untitled");
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
            // 添加 mania 相关字段
            mania: keys - 1,
            keyCount: keys,
            keycount: keys
        };

        Reflect.setField(song, 'mania', keys - 1);
        Reflect.setField(song, 'keyCount', keys);
        Reflect.setField(song, 'keycount', keys);

        // ========== 修复：精确计算总小节数 ==========
        var beatsPerSection:Float = 4.0;
        var totalSections:Int = 1;
        
        if (notes.length > 0)
        {
            var lastNoteTime:Float = notes[notes.length - 1].time;
            
            // 计算从0到最后一个音符的总拍数（考虑BPM变化）
            var totalBeats:Float = 0;
            var currentTime:Float = 0;
            var currentBpm:Float = bpmChanges[0].bpm;
            var bpmIndex:Int = 0;
            
            while (currentTime < lastNoteTime)
            {
                // 检查是否有BPM变化
                var nextBpmTime:Float = (bpmIndex + 1 < bpmChanges.length) ? bpmChanges[bpmIndex + 1].time : lastNoteTime + 1;
                var segmentDuration:Float = nextBpmTime - currentTime;
                if (segmentDuration <= 0)
                {
                    bpmIndex++;
                    if (bpmIndex >= bpmChanges.length) break;
                    currentBpm = bpmChanges[bpmIndex].bpm;
                    continue;
                }
                
                // 计算这段持续时间的拍数
                var beatsInSegment:Float = segmentDuration / (60000 / currentBpm);
                totalBeats += beatsInSegment;
                
                currentTime = nextBpmTime;
                bpmIndex++;
                if (bpmIndex < bpmChanges.length)
                {
                    currentBpm = bpmChanges[bpmIndex].bpm;
                }
            }
            
            // 额外加几个小节作为缓冲，确保所有音符都被包含
            totalSections = Math.ceil(totalBeats / beatsPerSection) + 4;
            //trace('【计算】总拍数: $totalBeats, 生成小节数: $totalSections (含4节缓冲)');
        }

        var swagSections:Array<SwagSection> = [];
        var sectionTime:Float = 0;
        var bpmIndex:Int = 0;
        var currentBpm:Float = bpmChanges[0].bpm;
        var totalSectionNotes:Int = 0;
        
        for (i in 0...totalSections)
        {
            // 检查当前小节是否应该改变BPM
            var nextBpm:Float = currentBpm;
            var changeBPM:Bool = false;
            
            // 如果下一个BPM变化在这个小节开始之前，更新BPM
            while (bpmIndex + 1 < bpmChanges.length && bpmChanges[bpmIndex + 1].time <= sectionTime + 0.1)
            {
                bpmIndex++;
                currentBpm = bpmChanges[bpmIndex].bpm;
                changeBPM = true;
            }
            nextBpm = currentBpm;

            var sec:SwagSection = {
                sectionNotes: [],
                sectionBeats: beatsPerSection,
                mustHitSection: true,
                bpm: nextBpm,
                changeBPM: changeBPM,
                altAnim: false,
                gfSection: false
            };

            // 将该小节时间范围内的音符加入
            var startTime:Float = sectionTime;
            var endTime:Float = sectionTime + beatsPerSection * (60000 / currentBpm);
            
            var sectionNotes:Array<Array<Dynamic>> = [];
            for (note in notes)
            {
                if (note.time >= startTime && note.time < endTime)
                {
                    var data:Int = note.lane;
                    var length:Float = note.length;
                    var noteType:String = null;
                    sectionNotes.push([note.time, data, length, noteType]);
                }
            }
            sec.sectionNotes = sectionNotes;
            swagSections.push(sec);
            totalSectionNotes += sectionNotes.length;
            
            if (i % 20 == 0 || i == totalSections - 1)
            {
//                trace('【小节 $i】时间范围: $startTime ~ $endTime ms, BPM: $currentBpm, 音符数: ${sectionNotes.length}');
            }

            sectionTime = endTime;
        }

        song.notes = swagSections;
        
       // trace('【完成】生成小节数: ${swagSections.length}');
        //trace('【完成】总音符数: $totalSectionNotes');
       // trace("========== OSU → Psych 转换完成 ==========");
        
        return song;
    }

	private static function getChartSourceInfo(filePath:String):Array<String>
	{
		var normalized:String = filePath.replace('\\', '/');
		var marker:String = '/customcharts/';
		var markerIndex:Int = normalized.toLowerCase().indexOf(marker);
		if (markerIndex == -1) return [null, null];

		var parts:Array<String> = normalized.substr(markerIndex + marker.length).split('/');
		if (parts.length < 3) return [null, null];
		return [parts[0], parts[1]];
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