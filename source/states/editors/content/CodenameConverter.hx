package states.editors.content;

import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import haxe.io.Path;
import backend.Song;
import moonchart.formats.fnf.FNFCodename;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.formats.BasicFormat;
import moonchart.backend.Timing;

class CodenameConverter
{
    /**
     * 将 Codename Engine 谱面（.json）转换为 Psych Engine 的 SwagSong
     * @param jsonPath CNE 谱面文件路径，例如 "songName/chart/hard.json"
     * @param metaPath 可选的 meta.json 路径，若为 null 则自动查找
     * @return Psych 引擎的 SwagSong 对象
     */
    public static function convertCodenameToPsych(jsonPath:String, ?metaPath:String):SwagSong
    {
        if (!FileSystem.exists(jsonPath)) {
            throw 'Codename Engine file does not exist: $jsonPath';
        }

        try {
            trace('=== Starting Codename Engine to Psych conversion (MoonChart) ===');
            trace('Codename file: $jsonPath');

            // 如果未提供 metaPath，则自动查找
            if (metaPath == null || !FileSystem.exists(metaPath)) {
                metaPath = findMetaFile(jsonPath);
                if (metaPath != null) {
                    trace('✓ Meta file found automatically: $metaPath');
                } else {
                    trace('⚠️ No meta.json found, proceeding without meta (may cause issues)');
                }
            } else {
                trace('✓ Using provided meta file: $metaPath');
            }

            // 使用 Moonchart 加载 CNE 谱面
            var codenameChart = new FNFCodename().fromFile(jsonPath, metaPath);
            if (codenameChart == null) {
                throw 'Failed to load Codename Engine file';
            }

            trace('✓ Codename Engine file loaded successfully');

            // 利用 Moonchart 自动转换为 Psych 格式
            var psychChart = new FNFPsych();
            psychChart.fromFormat(codenameChart);

            trace('✓ MoonChart conversion successful');

            // 将 Psych 数据转换为 Psych 引擎的 SwagSong
            var swagSong = convertPsychDataToSwagSong(psychChart.data, jsonPath);

            trace('=== Conversion Complete ===');
            trace('Song: ${swagSong.song}');
            trace('BPM: ${swagSong.bpm}');
            trace('Sections: ${swagSong.notes.length}');

            return swagSong;

        } catch (e:Dynamic) {
            trace('Codename to Psych conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            throw 'Codename conversion error: $e';
        }
    }

    /**
     * 将 Psych Engine 的 SwagSong 转换回 Codename Engine 格式并保存
     * @param psychSong Psych 引擎的歌曲数据
     * @param outputPath 输出 CNE 谱面文件路径（例如 "songName/chart/hard.json"）
     * @return 是否成功
     */
    public static function convertPsychToCodename(psychSong:SwagSong, outputPath:String):Bool
    {
        try {
            trace('=== Starting Psych to Codename Engine conversion ===');
            trace('Output path: $outputPath');

            // 将 SwagSong 转为 Moonchart 的 BasicChart
            var basicChart = convertSwagSongToBasicChart(psychSong);

            // 从 BasicChart 生成 CNE 谱面
            var codenameChart = new FNFCodename().fromBasicFormat(basicChart);
            if (codenameChart == null) {
                throw 'Failed to create Codename Engine chart from Psych data';
            }

            trace('✓ Codename Engine chart created successfully');

            // 序列化并保存
            var codenameOutput = codenameChart.stringify();
            if (codenameOutput == null || codenameOutput.data == null) {
                throw 'Failed to stringify Codename Engine chart';
            }

            var dir = Path.directory(outputPath);
            if (dir.length > 0 && !FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }

            File.saveContent(outputPath, codenameOutput.data);

            // 如果有元数据，一并保存到上级目录
            if (codenameOutput.meta != null) {
                var metaDir = Path.directory(Path.directory(outputPath)); // 歌曲根目录
                if (!FileSystem.exists(metaDir)) {
                    FileSystem.createDirectory(metaDir);
                }
                var metaPath = Path.join([metaDir, "meta.json"]);
                File.saveContent(metaPath, codenameOutput.meta);
                trace('✓ Metadata file saved to: $metaPath');
            }

            trace('✓ Codename Engine files saved to: $outputPath');
            return true;

        } catch (e:Dynamic) {
            trace('Psych to Codename conversion failed: $e');
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            return false;
        }
    }

    // ------------------------ 辅助函数 ------------------------

    /**
     * 根据谱面路径向上查找 meta.json
     * 遵循结构：歌曲根目录/meta.json
     */
    static function findMetaFile(jsonPath:String):Null<String>
    {
        var dir = Path.directory(jsonPath);          // 例如 chart/
        var parent = Path.directory(dir);            // 歌曲根目录
        var metaPath = Path.join([parent, "meta.json"]);
        if (FileSystem.exists(metaPath)) {
            return metaPath;
        }
        // 备选：如果当前目录也有（兼容性）
        var localMeta = Path.join([dir, "meta.json"]);
        if (FileSystem.exists(localMeta)) {
            return localMeta;
        }
        return null;
    }

    /**
     * 将 Moonchart 的 Psych 数据（即 FNFPsych.data）转换为 Psych 引擎的 SwagSong
     */
    static function convertPsychDataToSwagSong(psychData:Dynamic, sourcePath:String):SwagSong
    {
        trace('--- Converting Psych data to SwagSong ---');

        var songData:Dynamic = psychData.song;
        if (songData == null) {
            throw 'Psych data missing "song" field';
        }

        var songName = extractSongName(sourcePath);
        var bpm:Float = songData.bpm != null ? songData.bpm : 120.0;
        var speed:Float = songData.speed != null ? songData.speed : 1.0;
        var offset:Float = songData.offset != null ? songData.offset : 0.0;

        var sections:Array<SwagSection> = [];
        var notesData:Dynamic = songData.notes;
        if (notesData != null && Std.isOfType(notesData, Array)) {
            var notesArray:Array<Dynamic> = cast notesData;
            for (sectionData in notesArray) {
                var sectionNotes:Array<Dynamic> = [];
                if (sectionData.sectionNotes != null && Std.isOfType(sectionData.sectionNotes, Array)) {
                    sectionNotes = cast sectionData.sectionNotes;
                }
                var section:SwagSection = {
                    sectionNotes: sectionNotes,
                    sectionBeats: sectionData.sectionBeats != null ? sectionData.sectionBeats : 4,
                    mustHitSection: sectionData.mustHitSection != null ? sectionData.mustHitSection : true,
                    altAnim: sectionData.altAnim != null ? sectionData.altAnim : false,
                    gfSection: sectionData.gfSection != null ? sectionData.gfSection : false,
                    bpm: sectionData.bpm != null ? sectionData.bpm : bpm,
                    changeBPM: sectionData.changeBPM != null ? sectionData.changeBPM : false
                };
                sections.push(section);
            }
        } else {
            trace('⚠️ No notes array found, creating an empty section');
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

        var events:Array<Array<Dynamic>> = [];
        var eventsData:Dynamic = songData.events;
        if (eventsData != null && Std.isOfType(eventsData, Array)) {
            events = cast eventsData;
        }

        return {
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
            arrowSkin: songData.arrowSkin != null ? songData.arrowSkin : "NOTE_assets",
            splashSkin: songData.splashSkin != null ? songData.splashSkin : "noteSplashes",
            gameOverChar: songData.gameOverChar != null ? songData.gameOverChar : "bf-dead",
            gameOverSound: songData.gameOverSound != null ? songData.gameOverSound : "fnf_loss_sfx",
            gameOverLoop: songData.gameOverLoop != null ? songData.gameOverLoop : "gameOver",
            gameOverEnd: songData.gameOverEnd != null ? songData.gameOverEnd : "gameOverEnd",
            disableNoteRGB: songData.disableNoteRGB != null ? songData.disableNoteRGB : false
        };
    }

    /**
     * 将 Psych 引擎的 SwagSong 转换为 Moonchart 的 BasicChart
     */
    static function convertSwagSongToBasicChart(psychSong:SwagSong):BasicChart
    {
        trace('--- Converting SwagSong to BasicChart ---');

        // 构建 BPM 变化表
        var bpmChanges:Array<BasicBPMChange> = [{
            time: 0,
            bpm: psychSong.bpm,
            beatsPerMeasure: 4,
            stepsPerBeat: 4
        }];

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

        // 提取所有音符
        var basicNotes:Array<BasicNote> = [];
        var currentTime:Float = 0;
        for (section in psychSong.notes) {
            var sectionLength = (60000 / section.bpm) * section.sectionBeats;
            for (noteData in section.sectionNotes) {
                var noteTime = currentTime + noteData[0];
                var lane = noteData[1];
                var length = noteData[2];
                var type = noteData.length > 3 ? noteData[3] : "";
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

        // 单难度（默认名称）
        var diffName = "default";
        var diffs = new Map<String, Array<BasicNote>>();
        diffs.set(diffName, basicNotes);

        // 事件（排除 BPM Change，因为已单独处理）
        var basicEvents:Array<BasicEvent> = [];
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
                                    value1: subEvent[1],
                                    value2: subEvent[2]
                                }
                            });
                        }
                    }
                }
            }
        }

        // 额外数据（CNE 需要的信息）
        var extraData = new Map<String, Dynamic>();
        extraData.set("lanesLength", 8);   // CNE 使用 4 个 strumline × 2 玩家，总 lanes 8
        extraData.set("audioFile", "audio.mp3");
        extraData.set("songArtist", "Unknown");
        extraData.set("songCharter", "Unknown");

        var scrollSpeeds = new Map<String, Float>();
        scrollSpeeds.set(diffName, psychSong.speed);

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

    /**
     * 从文件路径中提取歌曲名（去除扩展名并整理格式）
     */
    static function extractSongName(path:String):String
    {
        var fileName = path.split('/').pop().split('\\').pop();
        var name = fileName.substring(0, fileName.lastIndexOf('.'));
        name = ~/[\[\]\(\)\-_]/g.replace(name, ' ');
        name = ~/\s+/g.replace(name, ' ').trim();
        var words = name.split(' ');
        for (i in 0...words.length) {
            if (words[i].length > 0) {
                words[i] = words[i].charAt(0).toUpperCase() + words[i].substr(1).toLowerCase();
            }
        }
        return words.join(' ');
    }
}