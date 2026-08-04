package states.editors.content;

import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import haxe.Json;
import EReg;
import backend.Song;
import backend.Difficulty;
import backend.Paths;

// MoonChart 依赖
import moonchart.formats.fnf.FNFCodename;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.backend.FormatData;

class CodenameConverter
{
    /**
     * Codename Engine → Psych Engine（使用 MoonChart 标准转换）
     */
    public static function convertCodenameToPsych(jsonPath:String, ?metaPath:String):SwagSong
    {
        if (!FileSystem.exists(jsonPath)) {
            throw 'Codename chart file not found: $jsonPath';
        }

        // 自动查找 meta.json（位于 charts 的上一级目录）
        if (metaPath == null || !FileSystem.exists(metaPath)) {
            var dir = Path.directory(jsonPath);
            var parentDir = Path.directory(dir);
            var defaultMeta = '$parentDir/meta.json';
            if (FileSystem.exists(defaultMeta)) {
                metaPath = defaultMeta;
            } else {
                metaPath = null;
            }
        }

        try {
            trace('=== Codename → Psych (MoonChart) ===');
            trace('Chart: $jsonPath');
            if (metaPath != null) trace('Meta: $metaPath');

            // 1. 使用 MoonChart 直接加载 Codename 格式
            var chartContent:String = File.getContent(jsonPath);
            var metaContent:String = (metaPath != null) ? File.getContent(metaPath) : null;
            var codenameChart:FNFCodename = new FNFCodename().fromJson(chartContent, metaContent);
            if (codenameChart == null || codenameChart.data == null) {
                throw 'Failed to parse Codename chart with MoonChart';
            }
            trace('✓ Codename chart loaded');

            // 2. 转换为 BasicChart（中间格式）
            var basicChart = codenameChart.toBasicFormat();
            if (basicChart == null) {
                throw 'Failed to convert to BasicChart';
            }

            // 3. 从 BasicChart 生成 Psych 格式
            var psychChart:FNFPsych = new FNFPsych();
            psychChart.fromBasicFormat(basicChart);
            if (psychChart == null || psychChart.data == null) {
                throw 'Failed to convert to Psych format';
            }
            trace('✓ Converted to Psych format');

            // 4. 将 Psych 数据转换为 SwagSong
            var swagSong:SwagSong = convertPsychDataToSwagSong(psychChart.data, jsonPath);

            trace('=== Conversion Complete ===');
            trace('Song: ${swagSong.song}');
            trace('BPM: ${swagSong.bpm}');
            trace('Sections: ${swagSong.notes.length}');

            return swagSong;

        } catch (e:Dynamic) {
            trace('Conversion error: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            throw 'Codename conversion error: $e';
        }
    }

    /**
     * Psych Engine → Codename Engine（生成完整的 CNE 文件夹结构）
     */
    public static function convertPsychToCodename(psychSong:SwagSong, outputPath:String):Bool
    {
        try {
            trace('=== Psych → Codename (MoonChart) ===');
            trace('Output path: $outputPath');

            // 1. 将 SwagSong 转为 BasicChart
            var basicChart = convertSwagSongToBasicChart(psychSong);
            if (basicChart == null) {
                throw 'Failed to create BasicChart from SwagSong';
            }

            // 2. 从 BasicChart 生成 Codename 格式
            var codenameChart:FNFCodename = new FNFCodename().fromBasicFormat(basicChart);
            if (codenameChart == null || codenameChart.data == null) {
                throw 'Failed to convert to Codename format';
            }
            trace('✓ Codename chart created');

            // 3. 构建输出目录
            var outputFolder:String = resolveOutputFolder(outputPath);
            var songName:String = Paths.formatToSongPath(psychSong.song);
            var songFolder:String = '$outputFolder/$songName';
            var chartFolder:String = '$songFolder/charts';
            var songAudioFolder:String = '$songFolder/song';

            if (!FileSystem.exists(songFolder)) FileSystem.createDirectory(songFolder);
            if (!FileSystem.exists(chartFolder)) FileSystem.createDirectory(chartFolder);
            if (!FileSystem.exists(songAudioFolder)) FileSystem.createDirectory(songAudioFolder);

            // 4. 保存 chart JSON（包含 strumLines 等）
            var chartJson:String = Json.stringify(codenameChart.data, "  ");
            var diffName:String = "normal";
            File.saveContent('$chartFolder/$diffName.json', chartJson);

            // 5. 保存 meta JSON（元数据）
            var metaObj:Dynamic = buildCodenameMeta(psychSong, songName);
            var metaJson:String = Json.stringify(metaObj, "  ");
            File.saveContent('$songFolder/meta.json', metaJson);

            trace('✓ Files saved to: $songFolder');
            return true;

        } catch (e:Dynamic) {
            trace('Psych to Codename conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            return false;
        }
    }

    // ---------- 辅助：Psych Data → SwagSong ----------
    static function convertPsychDataToSwagSong(psychData:Dynamic, sourcePath:String):SwagSong
    {
        var songData:Dynamic = psychData.song;
        if (songData == null) {
            throw 'Psych data missing "song" field';
        }

        var songName = extractSongNameFromPath(sourcePath);
        if (songData.song != null && songData.song.length > 0) {
            songName = songData.song;
        }

        var bpm:Float = songData.bpm != null ? songData.bpm : 120.0;
        var speed:Float = songData.speed != null ? songData.speed : 1.0;
        var offset:Float = songData.offset != null ? songData.offset : 0.0;

        // 转换 sections
        var sections:Array<SwagSection> = [];
        var notesData:Dynamic = songData.notes;
        if (notesData != null && Std.isOfType(notesData, Array)) {
            var notesArray:Array<Dynamic> = cast notesData;
            for (sectionData in notesArray) {
                var sectionNotes:Array<Dynamic> = [];
                if (sectionData.sectionNotes != null && Std.isOfType(sectionData.sectionNotes, Array)) {
                    sectionNotes = cast sectionData.sectionNotes;
                }
                var sec:SwagSection = {
                    sectionNotes: sectionNotes,
                    sectionBeats: sectionData.sectionBeats != null ? sectionData.sectionBeats : 4,
                    mustHitSection: sectionData.mustHitSection != null ? sectionData.mustHitSection : true,
                    altAnim: sectionData.altAnim != null ? sectionData.altAnim : false,
                    gfSection: sectionData.gfSection != null ? sectionData.gfSection : false,
                    bpm: sectionData.bpm != null ? sectionData.bpm : bpm,
                    changeBPM: sectionData.changeBPM != null ? sectionData.changeBPM : false
                };
                sections.push(sec);
            }
        } else {
            trace('Warning: No notes array in psych data, creating empty section');
            sections.push({
                sectionNotes: [],
                sectionBeats: 4,
                mustHitSection: true,
                altAnim: false,
                gfSection: false,
                bpm: bpm,
                changeBPM: false
            });
        }

        // 转换 events
        var events:Array<Array<Dynamic>> = [];
        var eventsData:Dynamic = songData.events;
        if (eventsData != null && Std.isOfType(eventsData, Array)) {
            events = cast eventsData;
        }

        // 构建 SwagSong
        var swagSong:SwagSong = {
            song: songName,
            notes: sections,
            events: events,
            bpm: bpm,
            needsVoices: songData.needsVoices != null ? songData.needsVoices : true,
            speed: speed,
            offset: offset,
            player1: songData.player1 != null ? songData.player1 : "bf",
            player2: songData.player2 != null ? songData.player2 : "dad",
            gfVersion: songData.gfVersion != null ? songData.gfVersion : "gf",
            stage: songData.stage != null ? songData.stage : "stage",
            format: "psych_v1",
            arrowSkin: songData.arrowSkin != null ? songData.arrowSkin : "",
            splashSkin: songData.splashSkin != null ? songData.splashSkin : "",
            gameOverChar: songData.gameOverChar != null ? songData.gameOverChar : "bf-dead",
            gameOverSound: songData.gameOverSound != null ? songData.gameOverSound : "fnf_loss_sfx",
            gameOverLoop: songData.gameOverLoop != null ? songData.gameOverLoop : "gameOver",
            gameOverEnd: songData.gameOverEnd != null ? songData.gameOverEnd : "gameOverEnd",
            disableNoteRGB: songData.disableNoteRGB != null ? songData.disableNoteRGB : false
        };
        return swagSong;
    }

    // ---------- 辅助：SwagSong → BasicChart ----------
    static function convertSwagSongToBasicChart(psychSong:SwagSong):Dynamic
    {
        // 构建 BPM 变化列表（含初始 BPM）
        var bpmChanges:Array<Dynamic> = [{
            time: 0,
            bpm: psychSong.bpm,
            beatsPerMeasure: 4,
            stepsPerBeat: 4
        }];

        // 从事件中提取 BPM Change
        if (psychSong.events != null) {
            for (event in psychSong.events) {
                var eventTime:Float = event[0];
                var eventPack:Array<Dynamic> = event[1];
                if (eventPack != null) {
                    for (subEvent in eventPack) {
                        if (subEvent[0] == "BPM Change") {
                            var bpm = Std.parseFloat(subEvent[1]);
                            if (!Math.isNaN(bpm)) {
                                bpmChanges.push({
                                    time: eventTime,
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
        bpmChanges.sort((a, b) -> Std.int(a.time - b.time));

        // 构建音符列表（BasicNote）
        var basicNotes:Array<Dynamic> = [];
        var currentTime:Float = 0;
        for (section in psychSong.notes) {
            var sectionLength = (60000 / section.bpm) * section.sectionBeats;
            for (noteData in section.sectionNotes) {
                var noteTime = currentTime + noteData[0];
                var lane = Std.int(noteData[1]);
                var length = noteData[2] != null ? noteData[2] : 0.0;
                var type = noteData.length > 3 ? Std.string(noteData[3]) : "";
                basicNotes.push({
                    time: noteTime,
                    lane: lane,
                    length: length,
                    type: type
                });
            }
            currentTime += sectionLength;
        }
        basicNotes.sort((a, b) -> Std.int(a.time - b.time));

        // 构建 diffs 映射（仅一个难度）
        var diffs = new Map<String, Array<Dynamic>>();
        diffs.set("normal", basicNotes);

        // 构建事件列表（BasicEvent），忽略 BPM Change
        var basicEvents:Array<Dynamic> = [];
        if (psychSong.events != null) {
            for (event in psychSong.events) {
                var eventTime:Float = event[0];
                var eventPack:Array<Dynamic> = event[1];
                if (eventPack != null) {
                    for (subEvent in eventPack) {
                        if (subEvent[0] != "BPM Change") {
                            basicEvents.push({
                                time: eventTime,
                                name: subEvent[0],
                                data: {
                                    value1: subEvent[1] != null ? subEvent[1] : "",
                                    value2: subEvent[2] != null ? subEvent[2] : ""
                                }
                            });
                        }
                    }
                }
            }
        }

        // 计算键位数（最大列数）
        var keyCount = 4;
        for (note in basicNotes) {
            var lane = note.lane;
            if (lane >= 4 && lane < 8) lane -= 4;
            if (lane >= keyCount) keyCount = lane + 1;
        }

        // extraData
        var extraData = new Map<String, Dynamic>();
        extraData.set("LANES_LENGTH", keyCount);
        extraData.set("AUDIO_FILE", "audio.mp3");
        extraData.set("SONG_ARTIST", "Unknown");
        extraData.set("SONG_CHARTER", "Unknown");

        // scrollSpeeds
        var scrollSpeeds = new Map<String, Float>();
        scrollSpeeds.set("normal", psychSong.speed);

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

    // ---------- 辅助：构建 Codename Meta 对象 ----------
    static function buildCodenameMeta(psychSong:SwagSong, songName:String):Dynamic
    {
        return {
            name: songName,
            displayName: psychSong.song,
            bpm: psychSong.bpm,
            needsVoices: psychSong.needsVoices,
            icon: "bf",
            color: "",
            difficulties: ["normal"],
            customValues: {
                composers: "Unknown",
                charters: "Unknown"
            }
        };
    }

    static function resolveOutputFolder(outputPath:String):String
    {
        if (outputPath == null) return ".";
        var normalized:String = outputPath.replace('\\', '/');
        if (normalized.endsWith('/')) return normalized.substring(0, normalized.length - 1);
        if (FileSystem.exists(normalized) && FileSystem.isDirectory(normalized)) return normalized;

        var dir:String = Path.directory(normalized);
        if (dir != null && dir.length > 0) return dir;
        return ".";
    }

    // ---------- 辅助：从路径提取歌名 ----------
    static function extractSongNameFromPath(path:String):String
    {
        var fileName = path.split('/').pop().split('\\').pop();
        var lastDot = fileName.lastIndexOf('.');
        var name = if (lastDot > 0) fileName.substring(0, lastDot) else fileName;

        // 移除常见后缀
        var suffixes = ["-easy", "-normal", "-hard", "-erect", "-nightmare"];
        for (suffix in suffixes) {
            if (name.toLowerCase().endsWith(suffix)) {
                name = name.substr(0, name.length - suffix.length);
                break;
            }
        }

        name = name.replace("_", " ").replace("-", " ");
        name = new EReg("\\s+", "g").replace(name, " ").trim();

        var words = name.split(' ');
        for (i in 0...words.length) {
            if (words[i].length > 0)
                words[i] = words[i].charAt(0).toUpperCase() + words[i].substr(1).toLowerCase();
        }
        return words.join(' ');
    }
}