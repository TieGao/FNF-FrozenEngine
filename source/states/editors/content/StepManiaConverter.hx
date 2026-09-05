package states.editors.content;

import backend.Song;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import moonchart.formats.StepMania;
import moonchart.formats.StepManiaShark;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.formats.BasicFormat;
import moonchart.backend.Timing;

using StringTools;

/**
 * 精确的 StepMania 转换器
 * 手动构建 BasicChart 并精准计算 BPM 变化时间，修复变速谱面尾部错乱问题
 */
class StepManiaConverter
{
    // ====================================================
    //  1. Psych → StepMania (.sm / .ssc)
    // ====================================================

    /**
     * 将 SwagSong 转换为 StepMania 格式文本
     * @param song Psych SwagSong
     * @param format "sm" 或 "ssc"
     * @return StepMania 格式的字符串
     */
    public static function convertPsychToStepMania(song:SwagSong, format:String = "sm"):String
    {
        try
        {
            // 1. 手动构建 BasicChart（内部已精准计算时间线）
            var basicChart = psychToBasicChart(song);
            
            // 2. 创建对应的 StepMania 格式实例
            var smFormat:Dynamic = (format == "ssc") ? new StepManiaShark() : new StepMania();
            
            // 3. 从 BasicChart 转换
            smFormat.fromBasicFormat(basicChart);
            
            // 4. 序列化为字符串
            return smFormat.stringify().data;
        }
        catch (e:Dynamic)
        {
            trace('StepMania export error: $e');
            trace(e.stack);
            return null;
        }
    }

    /**
     * 将 SwagSong 保存为 .sm 或 .ssc 文件
     */
    public static function savePsychToStepMania(song:SwagSong, path:String, format:String = "sm"):Bool
    {
        try
        {
            var content = convertPsychToStepMania(song, format);
            if (content == null) return false;
            
            if (!path.endsWith('.' + format)) path += '.' + format;
            File.saveContent(path, content);
            return true;
        }
        catch (e:Dynamic)
        {
            trace('Save StepMania error: $e');
            return false;
        }
    }

    // ====================================================
    //  2. StepMania → Psych (.sm / .ssc)
    // ====================================================

    /**
     * 从 StepMania 文件解析为 SwagSong
     * @param filePath .sm 或 .ssc 文件路径
     * @return SwagSong 或 null
     */
    public static function convertStepManiaToPsych(filePath:String):SwagSong
    {
        try
        {
            if (!FileSystem.exists(filePath))
            {
                trace('File not found: $filePath');
                return null;
            }

            var isSSC = filePath.toLowerCase().endsWith('.ssc');
            
            // 1. 加载 StepMania 文件
            var smFormat:Dynamic = isSSC ? new StepManiaShark() : new StepMania();
            smFormat.fromFile(filePath);

            // 2. 转换为 BasicChart
            var basicChart = smFormat.toBasicFormat();

            // 3. 将 BasicChart 转换为 SwagSong（使用 FNFPsych 简化转换）
            return basicChartToPsych(basicChart);
        }
        catch (e:Dynamic)
        {
            trace('StepMania import error: $e');
            trace(e.stack);
            return null;
        }
    }

    /**
     * 从 StepMania 文件加载，并指定目标键数（重新映射）
     */
    public static function convertStepManiaToPsychWithKeys(filePath:String, targetKeys:Int):SwagSong
    {
        var song = convertStepManiaToPsych(filePath);
        if (song == null) return null;
        
        var sourceKeys = getKeyCount(song);
        if (sourceKeys != targetKeys)
        {
            remapSongKeys(song, sourceKeys, targetKeys);
            Reflect.setField(song, 'mania', targetKeys - 1);
            Reflect.setField(song, 'keyCount', targetKeys);
            Reflect.setField(song, 'keycount', targetKeys);
        }
        
        return song;
    }

    // ====================================================
    //  3. 核心转换逻辑 (精准计算 BPM 时间线)
    // ====================================================

    /**
     * 将 SwagSong 转换为 BasicChart
     * 关键：完全按照 FNF ChartingState 的 _cacheSections 逻辑计算 BPM 变化时间
     */
    private static function psychToBasicChart(song:SwagSong):BasicChart
    {
        // -------- 1. 构建精准的 BPM 时间线 --------
        var bpmChanges:Array<BasicBPMChange> = [];
        var currentBpm:Float = song.bpm;
        var cumulativeTime:Float = 0;
        
        // 初始 BPM
        bpmChanges.push({
            time: 0,
            bpm: currentBpm,
            beatsPerMeasure: 4,
            stepsPerBeat: 4
        });

        // 遍历每个小节，计算精确的起始时间
        for (section in song.notes)
        {
            var beats = (section.sectionBeats > 0) ? section.sectionBeats : 4;
            
            // 如果该小节标记了 BPM 变化，更新当前 BPM（FNF 中 BPM 变化发生在小节开头）
            if (section.changeBPM && section.bpm != null && section.bpm > 0 && section.bpm != currentBpm)
            {
                currentBpm = section.bpm;
                bpmChanges.push({
                    time: cumulativeTime,  // 这个小节的开始时间
                    bpm: currentBpm,
                    beatsPerMeasure: 4,
                    stepsPerBeat: 4
                });
            }
            
            // 累加时间： beat(ms) = 60000 / bpm，总时间 = beat * beats
            cumulativeTime += beats * (60000 / currentBpm);
        }

        // 去重（防止连续 BPM 变化产生相同时间的记录）
        var uniqueChanges:Array<BasicBPMChange> = [];
        for (change in bpmChanges)
        {
            if (uniqueChanges.length == 0 || Math.abs(change.time - uniqueChanges[uniqueChanges.length - 1].time) > 0.01)
                uniqueChanges.push(change);
        }
        bpmChanges = uniqueChanges;

        // -------- 2. 提取所有音符 (直接使用绝对时间) --------
        var allNotes:Array<BasicNote> = [];
        for (section in song.notes)
        {
            for (noteData in section.sectionNotes)
            {
                if (noteData == null) continue;
                
                allNotes.push({
                    time: noteData[0],          // FNF 引擎计算的绝对毫秒时间
                    lane: Std.int(noteData[1]),
                    length: noteData[2] ?? 0,
                    type: noteData[3] ?? ""
                });
            }
        }
        allNotes.sort((a, b) -> Std.int(a.time - b.time));

        // -------- 3. 构建 BasicChart 数据结构 --------
        var diffs:Map<String, Array<BasicNote>> = new Map<String, Array<BasicNote>>();
        diffs.set("default", allNotes);

        var meta:BasicMetaData = {
            title: song.song,
            bpmChanges: bpmChanges,
            scrollSpeeds: new Map<String, Float>(),
            offset: song.offset ?? 0,
            extraData: new Map<String, Dynamic>()
        };
        meta.scrollSpeeds.set("default", song.speed ?? 1.0);
        
        // 传递额外信息
        meta.extraData.set("player1", song.player1 ?? "bf");
        meta.extraData.set("player2", song.player2 ?? "dad");
        meta.extraData.set("gfVersion", song.gfVersion ?? "gf");
        meta.extraData.set("stage", song.stage ?? "stage");

        return {
            data: { diffs: diffs, events: [] },
            meta: meta
        };
    }

    /**
     * 将 BasicChart 转换为 SwagSong（利用 FNFPsych 简化工作）
     */
    private static function basicChartToPsych(chart:BasicChart):SwagSong
    {
        // 使用 FNFPsych 将 BasicChart 序列化为标准 Psych JSON
        var fnf = new FNFPsych().fromBasicFormat(chart);
        var json:String = fnf.stringify().data;
        var obj:Dynamic = Json.parse(json);
        
        // 兼容 JSON 外层套 "song" 的情况
        if (Reflect.hasField(obj, 'song') && Reflect.field(obj, 'song') != null)
            obj = Reflect.field(obj, 'song');
            
        return cast obj;
    }

    // ====================================================
    //  4. 辅助函数
    // ====================================================

    /**
     * 从 SwagSong 中获取键数
     */
    public static function getKeyCount(song:SwagSong):Int
    {
        if (Reflect.hasField(song, "mania"))
        {
            var mania = Reflect.field(song, "mania");
            if (mania != null) return Std.int(mania) + 1;
        }
        if (Reflect.hasField(song, "keyCount"))
        {
            var keyCount = Reflect.field(song, "keyCount");
            if (keyCount != null) return Std.int(keyCount);
        }
        if (Reflect.hasField(song, "keycount"))
        {
            var keycount = Reflect.field(song, "keycount");
            if (keycount != null) return Std.int(keycount);
        }
        return 4;
    }

    /**
     * 重新映射歌曲的键数（列映射）
     */
    public static function remapSongKeys(song:SwagSong, sourceKeys:Int, targetKeys:Int):Void
    {
        if (sourceKeys == targetKeys) return;
        if (sourceKeys <= 0 || targetKeys <= 0) return;
        
        var scale:Float = (targetKeys - 1) / (sourceKeys - 1);
        
        for (section in song.notes)
        {
            for (note in section.sectionNotes)
            {
                if (note == null || note[1] == null) continue;
                
                var data:Int = Std.int(note[1]);
                var player = Math.floor(data / sourceKeys);
                var col = data % sourceKeys;
                
                var newCol:Int = Math.round(col * scale);
                newCol = Std.int(Math.max(0, Math.min(newCol, targetKeys - 1)));
                
                note[1] = player * targetKeys + newCol;
            }
        }
    }

    /**
     * 检测 StepMania 文件中的键数
     */
    public static function detectStepManiaKeys(filePath:String):Int
    {
        try
        {
            if (!FileSystem.exists(filePath)) return 4;
            
            var content:String = File.getContent(filePath);
            var lines = content.split("\n");
            
            var inNotes:Bool = false;
            var danceType:String = "single";
            var foundDance:Bool = false;
            var dataLines:Array<String> = [];
            
            for (line in lines)
            {
                var trimmed = line.trim();
                
                if (trimmed.startsWith("#NOTES:"))
                {
                    inNotes = true;
                    continue;
                }
                
                if (inNotes)
                {
                    if (trimmed == ";" || trimmed == ";")
                    {
                        if (dataLines.length > 0) break;
                        inNotes = false;
                        continue;
                    }
                    
                    if (!foundDance && trimmed.startsWith("dance:"))
                    {
                        danceType = trimmed.replace("dance:", "").trim();
                        foundDance = true;
                        continue;
                    }
                    
                    if (foundDance && dataLines.length == 0 && trimmed.length > 0 && trimmed != "//")
                    {
                        continue;
                    }
                    
                    if (trimmed.length > 0 && !trimmed.startsWith("//") && trimmed != ";")
                    {
                        dataLines.push(trimmed);
                    }
                }
            }
            
            if (dataLines.length > 0)
            {
                var firstRow = dataLines[0];
                if (danceType == "single")
                    return 4;
                else if (danceType == "double")
                    return 8;
                else
                    return firstRow.length;
            }
            
            return 4;
        }
        catch (e:Dynamic)
        {
            trace('Detect keys error: $e');
            return 4;
        }
    }
}