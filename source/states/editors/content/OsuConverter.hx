package states.editors.content;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import backend.Song;
import objects.Note;
import moonchart.formats.OsuMania;
import moonchart.formats.BasicFormat;
import moonchart.formats.BasicFormat.*;
import moonchart.backend.Util;

typedef PsychEventArray = Array<Array<String>>;
typedef PsychEventPack = Array<Dynamic>;

class OsuConverter
{
    // 简化的 OSU 转换函数 - 专门为 ChartingState 设计
    public static function convertOsuToPsych(osuPath:String):SwagSong
    {
        if (!FileSystem.exists(osuPath)) {
            throw 'OSU file does not exist: $osuPath';
        }
        
        try {
            trace('=== Converting OSU to Psych ===');
            trace('OSU file: $osuPath');
            
            // 1. 使用 MoonChart 加载 OSU 文件
            var osuChart = new OsuMania().fromFile(osuPath);
            if (osuChart == null) {
                throw 'Failed to load OSU file with MoonChart';
            }
            
            trace('✓ OSU file loaded');
            
            // 2. 转换为 MoonChart 中间格式
            var basicChart = osuChart.toBasicFormat();
            
            // 3. 转换为 Psych 格式
            var psychSong = convertBasicChartToPsych(basicChart, osuPath);
            
            trace('=== Conversion Complete ===');
            trace('Song: ${psychSong.song}');
            trace('BPM: ${psychSong.bpm}');
            trace('Sections: ${psychSong.notes.length}');
            
            var totalNotes = 0;
            for (section in psychSong.notes) {
                totalNotes += section.sectionNotes.length;
            }
            trace('Total notes: $totalNotes');
            
            return psychSong;
            
        } catch (e:Dynamic) {
            trace(' Conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            throw e;
        }
    }
    
   static function convertBasicChartToPsych(basicChart:BasicChart, osuPath:String):SwagSong
{
    try {
        var meta = basicChart.meta;
        var data = basicChart.data;
        
        trace('--- Converting Basic Chart to Psych ---');
        trace('Chart title: ${meta.title}');
        
        // 获取基本数据
        var bpm:Float = 120.0;
        if (meta.bpmChanges != null && meta.bpmChanges.length > 0) {
            bpm = meta.bpmChanges[0].bpm;
            trace('Initial BPM: $bpm, BPM changes: ${meta.bpmChanges.length}');
        }
        
        // 获取键位数
        var keyCount:Int = 4;
        if (meta.extraData.exists(LANES_LENGTH)) {
            keyCount = meta.extraData.get(LANES_LENGTH);
            trace('Key count: $keyCount');
        }
        
        trace('Offset: ${meta.offset}ms');
        
        // 获取音符数据
        var notes:Array<BasicNote> = [];
        for (diff in data.diffs.keys()) {
            notes = data.diffs.get(diff);
            trace('Converting difficulty: $diff');
            trace('Number of notes: ${notes.length}');
            
            // 查看前几个音符的数据
            if (notes.length > 0) {
                trace('Sample note 1: time=${notes[0].time}, lane=${notes[0].lane}, length=${notes[0].length}, type=${notes[0].type}');
                if (notes.length > 1) {
                    trace('Sample note 2: time=${notes[1].time}, lane=${notes[1].lane}');
                }
            }
            break;
        }
        
        // 事件数据
        trace('Event count: ${data.events != null ? data.events.length : 0}');
        
        // 转换音符
        trace('--- Starting note conversion ---');
        var psychNotes = convertBasicNotesToPsych(notes, keyCount, bpm, meta.bpmChanges);
        trace('Created ${psychNotes.length} sections');

         // 确保psychNotes不为null
        if (psychNotes == null) {
            psychNotes = [];
        }
        
        
        // 转换事件
        trace('--- Starting event conversion ---');
        var psychEvents = convertBasicEventsToPsych(data.events);
        trace('Created ${psychEvents.length} event groups');
        
        // 计算速度
        var speed = calculateOptimalSpeed(bpm, keyCount);
        trace('Optimal speed: $speed');
        
        // 创建 Psych 谱面
        trace('--- Creating Psych song ---');
        var songName = extractSongName(osuPath);
        trace('Song name: $songName');
        
        var psychSong:SwagSong = {
            song: songName,
            notes: psychNotes,
            events: psychEvents,
            bpm: bpm,
            needsVoices: true,
            speed: speed,
            offset: meta.offset,
            
            player1: "boyfriend",
            player2: "dad",
            gfVersion: "gf",
            stage: "stage",
            format: "psych_v1",
            
            arrowSkin: "NOTE_assets",
            splashSkin: "noteSplashes",
            
            gameOverChar: "bf-dead",
            gameOverSound: "fnf_loss_sfx",
            gameOverLoop: "gameOver",
            gameOverEnd: "gameOverEnd",
            
            disableNoteRGB: false
        };
        
        // 添加 BPM 变化事件
        if (meta.bpmChanges != null && meta.bpmChanges.length > 1) {
            trace('--- Adding BPM change events ---');
            addBPMChangeEvents(psychSong, meta.bpmChanges);
        }
        
        // 验证结果
        trace('=== Conversion Results ===');
        var totalNotes = 0;
        for (section in psychSong.notes) {
            totalNotes += section.sectionNotes.length;
        }
        trace('Total notes in Psych song: $totalNotes');
        trace('Total sections: ${psychSong.notes.length}');
        trace('Total event groups: ${psychSong.events != null ? psychSong.events.length : 0}');
        
        return psychSong;
        
    } catch (e:Dynamic) {
        trace(' ERROR in convertBasicChartToPsych: $e');
        trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
        throw e;
    }
}

static function convertBasicNotesToPsych(
    notes:Array<BasicNote>,
    keyCount:Int,
    baseBPM:Float,
    bpmChanges:Array<BasicBPMChange>
):Array<SwagSection>
{
    try {
        trace('convertBasicNotesToPsych called with ${notes.length} notes');

        if (notes == null || notes.length == 0) {
            trace('No notes to convert');
            return [];
        }

        // 使用毫秒为单位（与项目中现有 Psych chart 一致）
        var allNoteData:Array<{time:Float, lane:Int, length:Float, type:String}> = [];

        // 检测 MoonChart 的时间单位（如果数值很小则可能是秒），将其标准化为毫秒
        var timeIsMs:Bool = false;
        for (n in notes) {
            if (n != null && n.time > 10000) { timeIsMs = true; break; }
        }

        for (note in notes) {
            var t:Float = note.time;
            var l:Float = note.length;
            if (!timeIsMs) {
                // 如果 MoonChart 返回的是秒，则转换为毫秒
                t = note.time * 1000.0;
                l = note.length * 1000.0;
            }
            var lane = Std.int(note.lane) % keyCount;
            var type = convertBasicNoteTypeToPsych(note.type);
            allNoteData.push({ time: t, lane: lane, length: l, type: type });
        }

        // 按时间（毫秒）排序
        allNoteData.sort((a, b) -> Reflect.compare(a.time, b.time));

        var maxTimeMs:Float = allNoteData.length > 0 ? allNoteData[allNoteData.length - 1].time : 0;

        // 小节长度（毫秒）
        var secondsPerBeat = 60.0 / baseBPM;
        var msPerSection = secondsPerBeat * 4.0 * 1000.0;
        var totalSections = Math.ceil(maxTimeMs / msPerSection);
        trace('Total sections needed: $totalSections, maxTimeMs: ${maxTimeMs}ms, msPerSection: ${msPerSection}ms');

        // 预建小节
        var sections:Array<SwagSection> = [];
        for (i in 0...Std.int(totalSections) + 1) {
            var mustHit = (i % 2 == 0);
            sections.push({
                sectionNotes: [],
                sectionBeats: 4,
                mustHitSection: mustHit,
                altAnim: false,
                gfSection: false,
                bpm: baseBPM,
                changeBPM: false
            });
        }

        // 先按小节收集原始 lane 分布（用于 8K 决定左右）
        var laneCounts:Array<{left:Int,right:Int}> = [];
        for (i in 0...sections.length) laneCounts.push({ left: 0, right: 0 });

        for (noteData in allNoteData) {
            var sectionIndex = Math.floor(noteData.time / msPerSection);
            if (sectionIndex < 0) sectionIndex = 0;
            while (sectionIndex >= sections.length) {
                var newIdx = sections.length;
                var m = (newIdx % 2 == 0);
                sections.push({ sectionNotes: [], sectionBeats: 4, mustHitSection: m, altAnim: false, gfSection: false, bpm: baseBPM, changeBPM: false });
                laneCounts.push({ left:0, right:0 });
            }
            if (keyCount == 8) {
                if (noteData.lane < (keyCount / 2)) laneCounts[sectionIndex].left++;
                else laneCounts[sectionIndex].right++;
            } else if (keyCount == 4) {
                laneCounts[sectionIndex].right++;
            } else {
                if (noteData.lane < (keyCount / 2)) laneCounts[sectionIndex].left++;
                else laneCounts[sectionIndex].right++;
            }
        }

        // 根据 laneCounts 决定 mustHitSection（8K 用左右多数决定；4K 默认玩家）
        for (i in 0...sections.length) {
            if (keyCount == 8) sections[i].mustHitSection = laneCounts[i].right >= laneCounts[i].left;
            else if (keyCount == 4) sections[i].mustHitSection = true;
            else sections[i].mustHitSection = laneCounts[i].right >= laneCounts[i].left;
        }

        // 最后将音符推入对应小节，使用秒为单位（与 Psych 格式一致）
        for (noteData in allNoteData) {
            var sectionIndex = Math.floor(noteData.time / msPerSection);
            if (sectionIndex < 0) sectionIndex = 0;
            while (sectionIndex >= sections.length) {
                var newIdx2 = sections.length;
                var m2 = (newIdx2 % 2 == 0);
                sections.push({ sectionNotes: [], sectionBeats: 4, mustHitSection: m2, altAnim: false, gfSection: false, bpm: baseBPM, changeBPM: false });
            }

            var section = sections[sectionIndex];
            var timeInSection = noteData.time - (sectionIndex * msPerSection);

            // Lane 映射：压缩到 0..3，然后根据 4K/8K 规则分配侧
            var compressedLane = Math.floor(noteData.lane * 4 / keyCount);
            var psychLane:Int;
            if (keyCount == 4) psychLane = compressedLane; // 全部玩家侧
            else if (keyCount == 8) {
                if (noteData.lane < (keyCount / 2)) psychLane = compressedLane + 4; // 前半 -> 对手
                else psychLane = compressedLane; // 后半 -> 玩家
            } else psychLane = section.mustHitSection ? compressedLane : compressedLane + 4;

            psychLane = psychLane % 8;

            var noteArray:Array<Dynamic> = [timeInSection, psychLane, noteData.length];
            if (noteData.type != "Normal") noteArray.push(noteData.type);

            section.sectionNotes.push(noteArray);
        }

        // 移除空小节并排序（保持时间为毫秒）
        var finalSections:Array<SwagSection> = [];
        for (i in 0...sections.length) {
            var s = sections[i];
            if (s.sectionNotes != null && s.sectionNotes.length > 0) {
                s.sectionNotes.sort(function(a:Array<Dynamic>, b:Array<Dynamic>):Int { return Reflect.compare(a[0], b[0]); });
                finalSections.push(s);
                if (i < 3) {
                    trace('Section $i: ${s.sectionNotes.length} notes, mustHit=${s.mustHitSection}');
                    var fn = s.sectionNotes[0];
                    trace('  First note: time=${fn[0]}ms, lane=${fn[1]}, length=${fn[2]}ms');
                }
            }
        }

        if (finalSections.length == 0) finalSections.push({ sectionNotes: [], sectionBeats: 4, mustHitSection: true, altAnim: false, gfSection: false, bpm: baseBPM, changeBPM: false });

        trace('Final sections: ${finalSections.length}');
        return finalSections;
        
    } catch (e:Dynamic) {
        trace('Error in convertBasicNotesToPsych: $e');
        trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
        return [{
            sectionNotes: [],
            sectionBeats: 4,
            mustHitSection: true,
            altAnim: false,
            gfSection: false,
            bpm: baseBPM,
            changeBPM: false
        }];
    }
}

// 基于 MoonChart 逻辑的时间转换
static function convertTimeToBeat(timeMs:Float, bpmTimeline:Array<{time:Float, bpm:Float}>):Float
{
    if (bpmTimeline.length == 0) return 0;
    
    var totalBeats:Float = 0;
    var lastTime:Float = 0;
    
    for (i in 0...bpmTimeline.length) {
        var segment = bpmTimeline[i];
        var segmentStart = segment.time;
        var segmentBPM = segment.bpm;
        
        // 确定段结束时间
        var segmentEnd:Float = if (i < bpmTimeline.length - 1) {
            bpmTimeline[i + 1].time;
        } else {
            timeMs;
        };
        
        if (timeMs <= segmentEnd) {
            // 音符在当前段内
            var timeInSegment = timeMs - Math.max(segmentStart, lastTime);
            var beatsInSegment = (timeInSegment * segmentBPM) / 60000;
            totalBeats += beatsInSegment;
            break;
        } else {
            // 音符在当前段之后，累加整个段
            var segmentDuration = segmentEnd - Math.max(segmentStart, lastTime);
            var beatsInSegment = (segmentDuration * segmentBPM) / 60000;
            totalBeats += beatsInSegment;
            lastTime = segmentEnd;
        }
    }
    
    return totalBeats;
}

static function convertBeatToTime(totalBeats:Float, bpmTimeline:Array<{time:Float, bpm:Float}>):Float
{
    if (bpmTimeline.length == 0) return 0;
    
    var remainingBeats:Float = totalBeats;
    var totalTime:Float = 0;
    var lastTime:Float = 0;
    
    for (i in 0...bpmTimeline.length) {
        var segment = bpmTimeline[i];
        var segmentStart = segment.time;
        var segmentBPM = segment.bpm;
        
        // 确定段结束时间
        var segmentEnd:Float = if (i < bpmTimeline.length - 1) {
            bpmTimeline[i + 1].time;
        } else {
            10000000; // 很大的值
        };
        
        var segmentDuration = segmentEnd - Math.max(segmentStart, lastTime);
        var segmentBeats = (segmentDuration * segmentBPM) / 60000;
        
        if (remainingBeats <= segmentBeats) {
            // beats在当前段内
            var timeInSegment = (remainingBeats * 60000) / segmentBPM;
            totalTime += timeInSegment;
            break;
        } else {
            // 消耗整个段
            totalTime += segmentDuration;
            remainingBeats -= segmentBeats;
            lastTime = segmentEnd;
        }
    }
    
    return totalTime;
}

// 轨道映射函数（参考 OSU_MANIA 的轨道计算）
static function convertLaneToPsych(lane:Int, mustHitSection:Bool, keyCount:Int):Int
{
    // 确保lane在有效范围内
    lane = lane % keyCount;
    
    // 参考 OsuMania 的轨道计算：lane * OSU_CIRCLE_SIZE / circleSize
    // 这里我们反向映射：OSU轨道 -> Psych轨道
    
    if (keyCount == 4) {
        // 4K: 所有轨道给玩家 (4-7)
        return lane + 4;
    }
    else if (keyCount == 8) {
        // 8K: 根据mustHitSection分配
        if (mustHitSection) {
            // Player 2 小节: 对手在 0-3
            // OSU的左边4轨和右边4轨都映射到对手轨道
            return lane < 4 ? lane : lane - 4;
        } else {
            // Player 1 小节: 玩家在 4-7
            // OSU的左边4轨和右边4轨都映射到玩家轨道
            return lane < 4 ? lane + 4 : lane;
        }
    }
    else {
        // 其他键数：压缩到4轨，然后根据mustHitSection分配
        var compressedLane = Math.floor(lane * 4 / keyCount);
        if (mustHitSection) {
            return compressedLane; // 对手: 0-3
        } else {
            return compressedLane + 4; // 玩家: 4-7
        }
    }
}

// 音符类型转换（参考 OsuMania 的类型转换）
static function convertBasicNoteTypeToPsych(type:String):String
{
    if (type == null || type == "") return "Normal";
    
    // 参考 OsuMania 的 encodeOsuType/decodeOsuType
    switch(type) {
        case "Mine": return "Hurt Note";
        case "Alt Animation": return "Alt Animation";
        case "Roll": return "Roll Note"; // Psych 可能不支持，但先留着
        default: return "Normal";
    }
}
    static function convertBasicEventsToPsych(basicEvents:Array<BasicEvent>):Array<Array<Dynamic>>
{
    var psychEvents:Array<Array<Dynamic>> = [];
    
    if (basicEvents == null) return psychEvents;
    
    // 使用时间（毫秒）作为整数键，避免浮点精度问题
    var eventsByTime = new Map<Int, PsychEventArray>();
    
    for (event in basicEvents) {
        if (event == null) continue;
        
        // 将时间转换为毫秒整数
        var timeMs = Std.int(event.time);
        
        if (!eventsByTime.exists(timeMs)) {
            eventsByTime.set(timeMs, []);
        }
        
        var value1 = "";
        var value2 = "";
        
        if (event.data != null) {
            if (Reflect.hasField(event.data, "value1")) {
                value1 = Std.string(Reflect.field(event.data, "value1"));
            }
            if (Reflect.hasField(event.data, "value2")) {
                value2 = Std.string(Reflect.field(event.data, "value2"));
            }
        }
        
        eventsByTime.get(timeMs).push([event.name, value1, value2]);
    }
    
    // 转换为 Psych 格式
    var times = [for (key in eventsByTime.keys()) key];
    times.sort((a, b) -> a - b);
    
    for (timeMs in times) {
        // 保持为毫秒（与项目其他 chart 格式一致）
        psychEvents.push([timeMs, eventsByTime.get(timeMs)]);
    }
    
    return psychEvents;
}
    
    
    static function addBPMChangeEvents(psychSong:SwagSong, bpmChanges:Array<BasicBPMChange>):Void
    {
        if (bpmChanges == null || bpmChanges.length < 2) return;
        
        var lastBPM = psychSong.bpm;
        
        for (i in 1...bpmChanges.length) {
            var change = bpmChanges[i];
            if (Math.abs(change.bpm - lastBPM) > 0.1) {
                var timeSec = change.time / 1000;
                
                // 检查是否已存在事件
                var exists = false;
                if (psychSong.events != null) {
                    for (event in psychSong.events) {
                        if (Math.abs(event[0] - timeSec) < 0.001) {
                            var eventPack:PsychEventPack = event[1];
                            if (eventPack != null) {
                                for (subEvent in eventPack) {
                                    var subEventArray:Array<Dynamic> = cast subEvent;
                                    if (subEventArray[0] == "BPM Change") {
                                        exists = true;
                                        break;
                                    }
                                }
                            }
                            if (exists) break;
                        }
                    }
                }
                
                if (!exists) {
                    if (psychSong.events == null) psychSong.events = [];
                    psychSong.events.push([
                        timeSec,
                        [["BPM Change", Std.string(Math.round(change.bpm * 10) / 10), ""]]
                    ]);
                }
                
                lastBPM = change.bpm;
            }
        }
    }
    
    static function getBPMAtTime(bpmChanges:Array<BasicBPMChange>, timeMs:Float, defaultBPM:Float):Float
    {
        var currentBPM = defaultBPM;
        
        if (bpmChanges != null) {
            for (change in bpmChanges) {
                if (change.time <= timeMs) {
                    currentBPM = change.bpm;
                } else {
                    break;
                }
            }
        }
        
        return currentBPM;
    }
    
    static function calculateOptimalSpeed(bpm:Float, keyCount:Int):Float
    {
        var speed = 1.0;
        
        if (bpm > 200) speed = 0.7;
        else if (bpm > 180) speed = 0.8;
        else if (bpm > 160) speed = 0.9;
        else if (bpm > 140) speed = 1.0;
        else if (bpm > 120) speed = 1.1;
        else speed = 1.2;
        
        if (keyCount > 6) speed *= 0.8;
        else if (keyCount > 4) speed *= 0.9;
        
        return Math.round(speed * 10) / 10;
    }
    
    static function extractSongName(path:String):String
    {
        var fileName = path.split('/').pop().split('\\').pop();
        var name = fileName.substring(0, fileName.lastIndexOf('.'));
        
        // 清理文件名
        name = ~/[\[\]\(\)\-_]/g.replace(name, ' ');
        name = ~/\s+/g.replace(name, ' ').trim();
        
        // 首字母大写
        var words = name.split(' ');
        for (i in 0...words.length) {
            if (words[i].length > 0) {
                words[i] = words[i].charAt(0).toUpperCase() + words[i].substr(1).toLowerCase();
            }
        }
        
        return words.join(' ');
    }
    
    // Psych 转换为 OSU（简化版）
    public static function convertPsychToOsu(psychSong:SwagSong, outputPath:String):Bool
    {
        try {
            trace('=== Converting Psych to OSU ===');
            
            // 1. 转换为 MoonChart 中间格式
            var basicChart = convertPsychToBasicChart(psychSong);
            
            // 2. 使用 MoonChart 创建 OSU 图表
            var osuChart = new OsuMania().fromBasicFormat(basicChart);
            if (osuChart == null) {
                throw 'Failed to create OSU chart from Psych data';
            }
            
            // 3. 使用 MoonChart 的 stringify 方法获取 OSU 内容
            var osuOutput = osuChart.stringify();
            if (osuOutput == null || osuOutput.data == null) {
                throw 'Failed to stringify OSU chart';
            }
            
            // 4. 保存文件
            var dir = haxe.io.Path.directory(outputPath);
            if (dir.length > 0 && !FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }
            
            File.saveContent(outputPath, osuOutput.data);
            
            trace('✓ OSU file saved to: $outputPath');
            return true;
            
        } catch (e:Dynamic) {
            trace(' Conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            return false;
        }
    }
    
    static function convertPsychToBasicChart(psychSong:SwagSong):BasicChart
    {
        // 创建 BPM 变化数组（时间单位：毫秒）
        var bpmChanges:Array<BasicBPMChange> = [{
            time: 0,
            bpm: psychSong.bpm,
            beatsPerMeasure: 4,
            stepsPerBeat: 4
        }];
        
        // 从事件中提取 BPM 变化
        if (psychSong.events != null) {
            for (event in psychSong.events) {
                var eventPack:PsychEventPack = event[1];
                if (eventPack != null) {
                    for (subEvent in eventPack) {
                        var subEventArray:Array<Dynamic> = cast subEvent;
                        if (subEventArray[0] == "BPM Change") {
                            var bpm = Std.parseFloat(subEventArray[1]);
                            if (!Math.isNaN(bpm)) {
                                bpmChanges.push({
                                    time: event[0],
                                    bpm: bpm,
                                    beatsPerMeasure: 4,
                                    stepsPerBeat: 4
                                });
                            }
                        }
                    }
                }
            }
        }
        
        // 创建音符数据
        var diffs = new Map<String, Array<BasicNote>>();
        var basicNotes:Array<BasicNote> = [];
        
        var currentTime:Float = 0;
        for (section in psychSong.notes) {
            var sectionLength = (60 / section.bpm) * section.sectionBeats * 1000;
            
            for (noteData in section.sectionNotes) {
                // section note times are in milliseconds
                var noteTime = currentTime + noteData[0];
                var lane = convertPsychLaneToBasic(noteData[1], section.mustHitSection);
                var length = noteData[2];
                var type = (noteData.length > 3) ? convertPsychNoteTypeToBasic(noteData[3]) : "";

                basicNotes.push({
                    time: noteTime,
                    lane: lane,
                    length: length,
                    type: type
                });
            }
            
            currentTime += sectionLength;
        }
        
        // 按时间排序
        basicNotes.sort((a, b) -> Reflect.compare(a.time, b.time));
        diffs.set("Converted", basicNotes);
        
        // 创建事件数据
        var basicEvents:Array<BasicEvent> = [];
        if (psychSong.events != null) {
            for (event in psychSong.events) {
                var time = event[0];
                var eventPack:PsychEventPack = event[1];
                
                if (eventPack != null) {
                    for (subEvent in eventPack) {
                        var subEventArray:Array<Dynamic> = cast subEvent;
                        basicEvents.push({
                            time: time,
                            name: subEventArray[0],
                            data: {
                                value1: subEventArray[1],
                                value2: subEventArray[2]
                            }
                        });
                    }
                }
            }
        }
        
        // 计算最大键位数
        var maxKeyCount = 4;
        if (psychSong.notes != null) {
            for (section in psychSong.notes) {
                if (section.sectionNotes != null) {
                    for (note in section.sectionNotes) {
                        var lane:Int = cast note[1];
                        if (lane >= maxKeyCount) maxKeyCount = lane < 4 ? 4 : (lane < 6 ? 6 : 8);
                    }
                }
            }
        }
        
        // 使用正确的 Map 初始化语法
        var extraData = new Map<String, Dynamic>();
        extraData.set(LANES_LENGTH, maxKeyCount);
        extraData.set(AUDIO_FILE, "audio.mp3");
        extraData.set(SONG_ARTIST, "Unknown");
        extraData.set(SONG_CHARTER, "Unknown");
        
        var scrollSpeeds = new Map<String, Float>();
        scrollSpeeds.set(psychSong.song, psychSong.speed);
        
        return {
            data: {
                diffs: diffs,
                events: basicEvents
            },
            meta: {
                title: psychSong.song,
                bpmChanges: bpmChanges,
                scrollSpeeds: scrollSpeeds,
                offset: psychSong.offset,
                extraData: extraData
            }
        };
    }
    
    static function convertPsychLaneToBasic(lane:Int, mustHitSection:Bool):Int
    {
        // 简化映射：总是返回0-3的轨道
        return lane % 4;
    }
    
    static function convertPsychNoteTypeToBasic(type:String):String
    {
        return switch(type) {
            case "Hurt Note": "Mine";
            case "Alt Animation": "Alt Animation";
            default: "";
        };
    }
}