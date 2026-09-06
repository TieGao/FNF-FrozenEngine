package backend;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.FlxG;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.FileReference;
import lime.utils.Assets;
import haxe.Json;
import flixel.input.keyboard.FlxKey;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxTimer;
import flixel.util.FlxStringUtil;
import objects.Note;
import objects.StrumNote;
import openfl.utils.Dictionary;
import states.PlayState;

class Ana
{
    public var hitTime:Float;
    public var nearestNote:Array<Dynamic>;
    public var hit:Bool;
    public var hitJudge:String;
    public var key:Int;
    
    public function new(_hitTime:Float, _nearestNote:Array<Dynamic>, _hit:Bool, _hitJudge:String, _key:Int) {
        hitTime = _hitTime;
        nearestNote = _nearestNote;
        hit = _hit;
        hitJudge = _hitJudge;
        key = _key;
    }
}

class Analysis
{
    public var anaArray:Array<Ana>;

    public function new() {
        anaArray = [];
    }
}

typedef ReplayJSON =
{
    public var replayGameVer:String;
    public var timestamp:Date;
    public var songName:String;
    public var songDiff:Int;
    public var difficultyName:String;
    public var songNotes:Array<Dynamic>;
    public var songJudgements:Array<String>;
    public var noteSpeed:Float;
    public var chartPath:String;
    public var chartCategory:String;
    public var chartDirectory:String;
    public var chartHasVSliceMetadata:Bool;
    public var chartAudioSuffix:String;
    public var modDirectory:String;
    public var isDownscroll:Bool;
    public var sf:Int;
    public var sm:Bool;
    public var ana:Analysis;
    public var opponentMode:String;
    public var accuracy:Float;
    public var score:Int;
    public var misses:Int;
    public var rating:String;
    public var ratingFC:String;
}

class LegacyReplay
{
    public static var version:String = "1.5";

    public var path:String = "";
    public var replay:ReplayJSON;
    
    public var currentIndex:Int = 0;
    public var judgementIndex:Int = 0;
    
    public var noteRecording:Array<Array<Dynamic>> = [];
    public var judgementRecording:Array<String> = [];
    public var anaRecording:Analysis;
    public var replayNoteQueue:Array<Array<Dynamic>> = [];
    public var repNoteIndex:Int = 0;
    public var lastReplayTime:Float = 0;
    public var legacyReplayTxt:FlxText;
    
    // 新增：存储Replay的完整路径（包含mod子文件夹）
    public var fullPath:String = "";
    
    public function new(path:String)
    {
        this.path = path;
        this.fullPath = path;
        replay = {
            songName: "No Song Found", 
            songDiff: 1,
            difficultyName: "Normal",
            noteSpeed: 1.5,
            isDownscroll: false,
            songNotes: [],
            replayGameVer: version,
            chartPath: "",
            chartCategory: "",
            chartDirectory: "",
            chartHasVSliceMetadata: false,
            chartAudioSuffix: "",
            modDirectory: "",
            sm: false,
            timestamp: Date.now(),
            sf: 10,
            ana: new Analysis(),
            songJudgements: [],
            opponentMode: "player",
            accuracy: 0.0,
            score: 0,
            misses: 0,
            rating: "N/A",
            ratingFC: "N/A"
        };
        
        anaRecording = new Analysis();
    }

    private function roundFloat(value:Dynamic, decimals:Int):Float
    {
        if (value == null) return 0.0;
        var num:Float = Std.parseFloat(Std.string(value));
        var factor:Float = Math.pow(10, decimals);
        return Math.round(num * factor) / factor;
    }

    private function roundReplayNotes(notes:Array<Dynamic>, decimals:Int):Array<Dynamic>
    {
        var rounded:Array<Dynamic> = [];
        for (note in notes)
        {
            if (note != null && note.length >= 4)
            {
                rounded.push([
                    roundFloat(note[0], decimals),
                    roundFloat(note[1], decimals),
                    note[2],
                    roundFloat(note[3], decimals)
                ]);
            }
            else
            {
                rounded.push(note);
            }
        }
        return rounded;
    }

    private function roundAnalysisData(ana:Analysis, decimals:Int):Analysis
    {
        var rounded:Analysis = new Analysis();
        for (hit in ana.anaArray)
        {
            var roundedHit:Ana = new Ana(
                roundFloat(hit.hitTime, decimals),
                hit.nearestNote,
                hit.hit,
                hit.hitJudge,
                hit.key
            );
            rounded.anaArray.push(roundedHit);
        }
        return rounded;
    }

    // ========== 新增：获取Replay目录路径 ==========
    
    /**
     * 获取Replay的根目录路径
     */
    public static function getReplayRootDir():String
    {
        return "assets/replays/";
    }
    
    /**
    * 获取当前Mod对应的Replay子目录路径
    * 如果没有Mod，则返回 "base" 子目录
    */
    public static function getReplayModDir(?modName:String = null):String
    {
        var rootDir:String = getReplayRootDir();
        
        #if MODS_ALLOWED
        if (modName == null) {
            modName = Mods.currentModDirectory;
        }
        
        // 如果 modName 为空或者是 "base"，都保存到 base 子目录
        if (modName != null && modName.length > 0 && modName != "base") {
            // 直接返回原始 modName，不做任何字符替换
            return rootDir + modName + "/";
        }
        #end
        
        // 默认保存到 base 子目录（包括原版 FNF 曲目）
        return rootDir + "base/";
    }
    
    /**
     * 确保Replay目录存在（递归创建）
     */
    public static function ensureReplayDirExists(?modName:String = null):String
    {
        #if sys
        var dir:String = getReplayModDir(modName);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
            trace('Created replay directory: $dir');
        }
        return dir;
        #else
        return getReplayModDir(modName);
        #end
    }
    
    /**
     * 获取所有Replay文件（从所有子目录）
     */
    public static function getAllReplayFiles():Array<String>
    {
        #if sys
        var allFiles:Array<String> = [];
        var rootDir:String = getReplayRootDir();
        
        if (!FileSystem.exists(rootDir)) {
            return allFiles;
        }
        
        // 遍历根目录下的所有文件和文件夹
        for (entry in FileSystem.readDirectory(rootDir)) {
            var fullPath:String = rootDir + entry;
            
            if (FileSystem.isDirectory(fullPath)) {
                // 遍历子文件夹中的.replay文件
                for (file in FileSystem.readDirectory(fullPath)) {
                    if (file.endsWith(".kadeReplay")) {
                        allFiles.push(entry + "/" + file);
                    }
                }
            } else if (entry.endsWith(".kadeReplay")) {
                // 根目录下的.replay文件（兼容旧版本）
                allFiles.push(entry);
            }
        }
        
        return allFiles;
        #else
        return [];
        #end
    }
    
    /**
     * 获取指定Mod目录下的Replay文件
     */
    public static function getReplayFilesForMod(?modName:String = null):Array<String>
    {
        #if sys
        var files:Array<String> = [];
        var dir:String = getReplayModDir(modName);
        
        if (!FileSystem.exists(dir)) {
            return files;
        }
        
        for (file in FileSystem.readDirectory(dir)) {
            if (file.endsWith(".kadeReplay")) {
                // 返回相对于根目录的路径
                var modDirName:String = (modName != null && modName.length > 0) ? modName : "";
                if (modDirName.length > 0) {
                    files.push(modDirName + "/" + file);
                } else {
                    files.push(file);
                }
            }
        }
        
        return files;
        #else
        return [];
        #end
    }

    // ========== 修改：LoadReplay 支持子文件夹路径 ==========
    
    public static function LoadReplay(path:String):LegacyReplay
    {
        var rep:LegacyReplay = new LegacyReplay(path);
        rep.LoadFromJSON();
        return rep;
    }

    // ========== 修改：SaveReplay 按Mod分类保存 ==========
    
    public function SaveReplay(notearray:Array<Dynamic>, judge:Array<String>, ana:Analysis)
    {
        #if sys
        var currentMod:String = "";
        
        #if MODS_ALLOWED
        if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
        {
            currentMod = Mods.currentModDirectory;
            trace('Saving replay with mod directory: $currentMod');
        }
        else
        {
            trace('Saving replay without mod (base game)');
        }
        #end
        
        var chartPath:String = Paths.currentChartDirectory != null ? Paths.currentChartDirectory : "";
        var modDirectory:String = currentMod;
        
        var missCount:Int = 0;
        for (j in judge) {
            if (j == "miss") missCount++;
        }

        var totalNotes:Int = notearray.length;
        var totalHits:Int = totalNotes - missCount;
        var computedAccuracy:Float = totalNotes > 0 ? (totalHits / totalNotes) * 100 : 0;

        var accuracy:Float = (PlayState.instance != null) ? (PlayState.instance.ratingPercent * 100) : computedAccuracy;
        
        var difficultyName:String = Difficulty.getString();
        var songDiff:Int = PlayState.storyDifficulty;
        
        var rating:String = "N/A";
        var ratingFC:String = "N/A";
        
        if (PlayState.instance != null)
        {
            rating = PlayState.instance.ratingName;
            ratingFC = PlayState.instance.ratingFC;
        }
        
        var roundedNotes:Array<Dynamic> = roundReplayNotes(notearray, 2);
        var roundedAccuracy:Float = roundFloat(accuracy, 2);
        var roundedNoteSpeed:Float = roundFloat(PlayState.SONG != null ? PlayState.SONG.speed : 1.5, 2);
        var roundedAna:Analysis = roundAnalysisData(ana, 2);

        var json = {
            "songName": PlayState.SONG != null ? PlayState.SONG.song : "Unknown",
            "songDiff": songDiff,
            "difficultyName": difficultyName,
            "chartPath": chartPath,
            "chartCategory": Paths.currentChartCategory != null ? Paths.currentChartCategory : "",
            "chartDirectory": chartPath,
            "chartHasVSliceMetadata": Paths.currentChartHasVSliceMetadata,
            "chartAudioSuffix": Paths.currentChartAudioSuffix != null ? Paths.currentChartAudioSuffix : "",
            "modDirectory": modDirectory,
            "sm": false,
            "timestamp": Date.now(),
            "replayGameVer": version,
            "sf": 10,
            "noteSpeed": roundedNoteSpeed,
            "isDownscroll": ClientPrefs.data.downScroll,
            "songNotes": roundedNotes,
            "songJudgements": judge,
            "ana": roundedAna,
            "accuracy": roundedAccuracy,
            "score": PlayState.instance != null ? PlayState.instance.songScore : 0,
            "misses": missCount,
            "rating": rating,
            "ratingFC": ratingFC
        };

        var data:String = Json.stringify(json, null, "\t");
        var time = Date.now().getTime();

        // ========== 使用Mod子目录 ==========
        var replayDir:String = ensureReplayDirExists(currentMod);

        var songNameForFile:String = PlayState.SONG != null ? 
            StringTools.replace(StringTools.replace(PlayState.SONG.song, " ", "_"), ":", "_") : "Unknown";
        var diffName:String = Difficulty.getString().toLowerCase();
        
        var fileName:String = 'replay_${songNameForFile}_${diffName}_${time}.kadeReplay';
        var fullFilePath:String = replayDir + fileName;
        File.saveContent(fullFilePath, data);
        
        // 存储完整路径和相对路径
        this.fullPath = fullFilePath;
        if (currentMod != null && currentMod.length > 0) {
            this.path = currentMod + "/" + fileName;
        } else {
            this.path = fileName;
        }
        
        trace('=== REPLAY SAVED ===');
        trace('File: $fileName');
        trace('Full Path: $fullFilePath');
        trace('Mod Directory: $modDirectory');
        trace('Difficulty ID: $songDiff');
        trace('Difficulty Name: $difficultyName');
        trace('Notes: ${notearray.length}');
        trace('Accuracy: ${accuracy}%');
        trace('Misses: ${missCount}');
        trace('====================');
        #end
    }

    // ========== 修改：LoadFromJSON 支持子文件夹路径 ==========
    
    public function LoadFromJSON()
    {
        #if sys
        try
        {
            // 尝试多种可能的路径
            var possiblePaths:Array<String> = [];
            var rootDir:String = getReplayRootDir();
            
            // 1. 原始路径（可能包含子文件夹）
            if (path != null && path.length > 0) {
                possiblePaths.push(rootDir + path);
            }
            
            // 2. 如果路径不包含 "/"，尝试在所有Mod子目录中查找
            if (path != null && path.length > 0 && path.indexOf("/") == -1) {
                // 遍历所有子目录
                if (FileSystem.exists(rootDir)) {
                    for (entry in FileSystem.readDirectory(rootDir)) {
                        var fullPath:String = rootDir + entry;
                        if (FileSystem.isDirectory(fullPath)) {
                            var filePath:String = fullPath + "/" + path;
                            if (FileSystem.exists(filePath)) {
                                possiblePaths.push(filePath);
                            }
                        }
                    }
                }
            }
            
            // 3. 尝试将路径拆分为 Mod名/文件名 格式
            if (path != null && path.length > 0 && path.indexOf("/") > 0) {
                var parts:Array<String> = path.split("/");
                if (parts.length == 2) {
                    var modName:String = parts[0];
                    var fileName:String = parts[1];
                    var modPath:String = rootDir + modName + "/" + fileName;
                    if (!possiblePaths.contains(modPath)) {
                        possiblePaths.push(modPath);
                    }
                }
            }
            
            // 4. 如果路径为空或者是旧格式，尝试用文件名在所有子目录中查找
            if (path != null && path.length > 0) {
                var fileNameOnly:String = path.split("/").pop();
                if (fileNameOnly != null && fileNameOnly.length > 0) {
                    // 遍历所有子目录查找同名文件
                    if (FileSystem.exists(rootDir)) {
                        for (entry in FileSystem.readDirectory(rootDir)) {
                            var fullPath:String = rootDir + entry;
                            if (FileSystem.isDirectory(fullPath)) {
                                var filePath:String = fullPath + "/" + fileNameOnly;
                                if (FileSystem.exists(filePath) && !possiblePaths.contains(filePath)) {
                                    possiblePaths.push(filePath);
                                }
                            }
                        }
                    }
                }
            }
            
            // 查找存在的文件
            var filePath:String = null;
            for (p in possiblePaths) {
                if (FileSystem.exists(p)) {
                    filePath = p;
                    break;
                }
            }
            
            // 如果还是找不到，尝试直接使用根目录+路径
            if (filePath == null && path != null && path.length > 0) {
                var testPath:String = rootDir + path;
                if (FileSystem.exists(testPath)) {
                    filePath = testPath;
                }
            }
            
            if (filePath == null) {
                trace('Replay file not found. Tried paths: $possiblePaths');
                return;
            }
            
            trace('Loading replay from: $filePath');
            
            var fileContent:String = File.getContent(filePath);
            var repl:ReplayJSON = cast Json.parse(fileContent);
            replay = repl;
            
            // 存储完整路径
            this.fullPath = filePath;
            
            if (repl.replayGameVer != version)
            {
                trace('Warning: Replay version mismatch. Replay: ${repl.replayGameVer}, Current: $version');
            }
            
            // 补齐可能缺失的字段
            if (replay.songNotes == null) replay.songNotes = [];
            if (replay.songJudgements == null) replay.songJudgements = [];
            if (replay.ana == null) replay.ana = new Analysis();
            if (replay.modDirectory == null) replay.modDirectory = "";
            if (replay.songName == null) replay.songName = "Unknown";
            if (replay.difficultyName == null) replay.difficultyName = "Normal";
            if (replay.rating == null) replay.rating = "N/A";
            if (replay.ratingFC == null) replay.ratingFC = "N/A";
            
            // 修复 timestamp
            var ts = replay.timestamp;
            if (ts != null)
            {
                if (Std.isOfType(ts, String))
                {
                    var str:String = cast ts;
                    try {
                        var parsed:Date = Date.fromString(str);
                        if (parsed != null) replay.timestamp = parsed;
                        else {
                            var num:Float = Std.parseFloat(str);
                            if (!Math.isNaN(num)) {
                                replay.timestamp = Date.fromTime(num);
                            }
                        }
                    } catch(e:Dynamic) {
                        trace('Failed to parse timestamp string: $str');
                    }
                }
                else if (Std.isOfType(ts, Float) || Std.isOfType(ts, Int))
                {
                    var num:Float = Std.parseFloat(Std.string(ts));
                    if (!Math.isNaN(num)) {
                        replay.timestamp = Date.fromTime(num);
                    }
                }
            }
            if (replay.timestamp == null) {
                replay.timestamp = Date.now();
            }
            
            currentIndex = 0;
            judgementIndex = 0;
            
            trace('Successfully loaded replay:');
            trace('  Song: ${repl.songName}');
            trace('  Difficulty: ${repl.difficultyName}');
            trace('  Mod Directory: ${repl.modDirectory}');
            trace('  Accuracy: ${repl.accuracy}%');
            trace('  Notes: ${repl.songNotes.length}');
            trace('  Timestamp: ${replay.timestamp}');
            trace('  File: $filePath');
        }
        catch(e:Dynamic)
        {
            trace('Failed to load replay: ' + e);
        }
        #end
    }
    
    // ========== 回放录制方法 ==========
    
    public function startRecording():Void
    {
        noteRecording = [];
        judgementRecording = [];
        anaRecording = new Analysis();
        trace('Started recording replay');
    }
    
    public function recordNote(strumTime:Float, noteData:Int, sustainLength:Float, diff:Float):Void
    {
        noteRecording.push([strumTime, sustainLength, noteData, diff]);
    }
    
    public function recordMiss(noteData:Int, strumTime:Float):Void
    {
        noteRecording.push([strumTime, 0, noteData, -10000]);
        judgementRecording.push("miss");
        
        var ana:Ana = new Ana(
            strumTime,
            [],
            false,
            "miss",
            noteData
        );
        anaRecording.anaArray.push(ana);
        
        trace('Recorded miss at $strumTime, key: $noteData');
    }
    
    public function recordJudgement(judge:String):Void
    {
        judgementRecording.push(judge);
    }

    public function recordHit(strumTime:Float, noteData:Int, sustainLength:Float, diff:Float, judge:String):Void
    {
        recordJudgement(judge);
        recordNote(strumTime, noteData, sustainLength, diff);
    }
    
    public function finishRecording():Void
    {
        replay.songNotes = noteRecording;
        replay.songJudgements = judgementRecording;
        replay.ana = anaRecording;
        
        if (PlayState.instance != null)
        {
            replay.songName = PlayState.SONG.song;
            replay.songDiff = PlayState.storyDifficulty;
            replay.difficultyName = Difficulty.getString();
            replay.noteSpeed = PlayState.SONG.speed;
            replay.isDownscroll = ClientPrefs.data.downScroll;
            replay.accuracy = PlayState.instance.ratingPercent * 100;
            replay.score = PlayState.instance.songScore;
            replay.misses = PlayState.instance.songMisses;
            replay.rating = PlayState.instance.ratingName;
            replay.ratingFC = PlayState.instance.ratingFC;
            
            #if MODS_ALLOWED
            replay.modDirectory = Mods.currentModDirectory;
            #else
            replay.modDirectory = "";
            #end
        }
    }
    
    // ========== 回放播放方法 ==========
    
    public function startPlayback():Void
    {
        trace('Starting replay playback for: ' + replay.songName);
        trace('Difficulty: ' + replay.difficultyName);
        trace('Mod Directory: ' + replay.modDirectory);
        trace('Total notes in replay: ' + replay.songNotes.length);
        currentIndex = 0;
        judgementIndex = 0;
    }

    public function initReplayData():Void
    {
        if (replay == null || replay.songNotes == null)
        {
            trace('ERROR: Replay data is null or invalid!');
            PlayState.inReplay = false;
            return;
        }

        replayNoteQueue = [];
        repNoteIndex = 0;
        lastReplayTime = 0;

        for (noteData in replay.songNotes)
        {
            if (noteData == null || noteData.length < 4) continue;
            replayNoteQueue.push([
                noteData[0], noteData[1], Std.int(noteData[2] % 4), noteData[3], noteData[3] <= -9999, false
            ]);
        }

        replayNoteQueue.sort(function(a:Array<Dynamic>, b:Array<Dynamic>):Int
        {
            return Std.int(a[0] - b[0]);
        });
    }

    public function createReplayUI(state:PlayState):Void
    {
        if (!PlayState.inReplay || state.healthBar == null || !ClientPrefs.data.legacyReplay) return;

        legacyReplayTxt = new FlxText(400, state.healthBar.y + (ClientPrefs.data.downScroll ? 100 : -150), FlxG.width - 800, "REPLAY MODE", 32);
        legacyReplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        legacyReplayTxt.scrollFactor.set();
        legacyReplayTxt.borderSize = 1.25;
        legacyReplayTxt.color = FlxColor.YELLOW;
        legacyReplayTxt.alpha = 0.8;
        legacyReplayTxt.visible = true;
        state.uiGroup.add(legacyReplayTxt);
    }

    public function processReplayNotes(state:PlayState):Void
    {
        if (!PlayState.inReplay || replayNoteQueue.length == 0 || repNoteIndex >= replayNoteQueue.length) return;

        var currentTime:Float = Conductor.songPosition;
        var realCurrentTime:Float = currentTime + Conductor.offset;
        updateReplayUI(currentTime);

        #if debug
        if (Math.floor(currentTime / 2000) > Math.floor(lastReplayTime / 2000))
            trace('Replay status at ${currentTime}ms: ${repNoteIndex}/${replayNoteQueue.length} notes processed');
        #end
        lastReplayTime = currentTime;

        var processedCount:Int = 0;
        while (repNoteIndex < replayNoteQueue.length && processedCount < 100)
        {
            var replayNote:Array<Dynamic> = replayNoteQueue[repNoteIndex];
            if (replayNote == null || replayNote.length < 6) { repNoteIndex++; continue; }

            var noteStrTime:Float = replayNote[0];
            var diff:Float = replayNote[3];
            var actualHitTime:Float = noteStrTime - diff;
            if (replayNote[5]) { repNoteIndex++; continue; }
            if (actualHitTime > realCurrentTime + 2) break;
            if (realCurrentTime - actualHitTime > Conductor.safeZoneOffset)
            {
                replayNote[5] = true;
                repNoteIndex++;
                continue;
            }

            if (!replayNote[4]) processReplayHit(state, replayNote, realCurrentTime);
            replayNote[5] = true;
            repNoteIndex++;
            processedCount++;
        }

        if (repNoteIndex >= replayNoteQueue.length && PlayState.inReplay)
            completeReplay();
    }

    private function processReplayHit(state:PlayState, replayNote:Array<Dynamic>, currentTime:Float):Void
    {
        var noteStrTime:Float = replayNote[0];
        var sustainLength:Float = replayNote[1];
        var column:Int = replayNote[2];
        var diff:Float = replayNote[3];
        var strum:StrumNote = state.playerStrums.members[column];
        if (strum != null)
        {
            strum.playAnim('confirm', true);
            strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / state.playbackRate;
        }

        var targetNote:Note = findNoteAtOriginalTime(state, noteStrTime, column);
        if (targetNote != null)
        {
            state.goodNoteHit(targetNote, diff);
            if (sustainLength > 0) processSustainNotes(state, targetNote, replayNote);
        }
        else
        {
            var animations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
            var animName:String = animations[Std.int(Math.abs(column) % animations.length)];
            if (state.boyfriend != null && state.boyfriend.hasAnimation(animName))
            {
                state.boyfriend.playAnim(animName, true);
                state.boyfriend.holdTimer = 0;
            }
        }
    }

    private function findNoteAtOriginalTime(state:PlayState, targetTime:Float, column:Int):Note
    {
        var bestNote:Note = null;
        var minTimeDiff:Float = 9999;
        state.notes.forEachAlive(function(note:Note)
        {
            if (!note.mustPress || note.wasGoodHit || note.tooLate || !note.canBeHit || note.noteData != column) return;
            var timeDiff:Float = Math.abs(note.strumTime - targetTime);
            if (timeDiff < minTimeDiff) { minTimeDiff = timeDiff; bestNote = note; }
        });

        if (bestNote == null)
        {
            var fallbackDiff:Float = Conductor.safeZoneOffset;
            state.notes.forEachAlive(function(note:Note)
            {
                if (!note.mustPress || note.wasGoodHit || note.tooLate || note.noteData != column) return;
                var timeDiff:Float = Math.abs(note.strumTime - targetTime);
                if (timeDiff < fallbackDiff) { fallbackDiff = timeDiff; bestNote = note; }
            });
        }
        return bestNote;
    }

    private function processSustainNotes(state:PlayState, parentNote:Note, replayNote:Array<Dynamic>):Void
    {
        if (parentNote == null || replayNote[1] <= 0) return;
        var strum:StrumNote = state.playerStrums.members[replayNote[2]];
        if (strum != null)
        {
            strum.playAnim('confirm', true);
            strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / state.playbackRate;
        }
    }

    private function updateReplayUI(currentTime:Float):Void
    {
        if (legacyReplayTxt == null || !PlayState.inReplay) return;
        var totalNotes:Int = replayNoteQueue.length;
        var progress:Float = totalNotes > 0 ? (repNoteIndex / totalNotes) * 100 : 100;
        var timeStr:String = FlxStringUtil.formatTime(Math.floor(currentTime / 1000), false);
        legacyReplayTxt.text = 'REPLAY MODE\n${Math.round(progress)}% (${repNoteIndex}/${totalNotes})\n${timeStr}';
        legacyReplayTxt.visible = true;
    }

    private function completeReplay():Void
    {
        trace('Completing replay...');
        if (legacyReplayTxt != null)
        {
            legacyReplayTxt.text = 'REPLAY COMPLETE!';
            legacyReplayTxt.color = FlxColor.GREEN;
            new FlxTimer().start(3, function(_) {
                if (legacyReplayTxt != null) legacyReplayTxt.visible = false;
            });
        }
        PlayState.inReplay = false;
    }

    public function clearPlayback():Void
    {
        replayNoteQueue = [];
        repNoteIndex = 0;
        lastReplayTime = 0;
        if (legacyReplayTxt != null) legacyReplayTxt.visible = false;
    }
    
    public function getNextNote(strumTime:Float):Array<Dynamic>
    {
        while (currentIndex < replay.songNotes.length)
        {
            var note:Array<Dynamic> = replay.songNotes[currentIndex];
            if (note[0] <= strumTime + 10)
            {
                currentIndex++;
                return note;
            }
            break;
        }
        return null;
    }
    
    public function getNextJudgement():String
    {
        if (judgementIndex < replay.songJudgements.length)
        {
            return replay.songJudgements[judgementIndex++];
        }
        return null;
    }
    
    // ========== 辅助方法 ==========
    
    public function isValid():Bool
    {
         return replay != null && 
             replay.songName != null && 
             replay.songName != "No Song Found" &&
             replay.songNotes != null && replay.songNotes.length > 0;
    }
    
    public function getReplay():ReplayJSON
    {
        return replay;
    }

    public function getReplayInfo():String
    {
        if (!isValid()) return "Invalid Replay";
        
        var info:String = 'Song: ${replay.songName}\n';
        info += 'Difficulty: ${replay.difficultyName}\n';
        if (replay.modDirectory != null && replay.modDirectory.length > 0) {
            info += 'Mod: ${replay.modDirectory}\n';
        }
        info += 'Accuracy: ${Math.round(replay.accuracy * 100) / 100}%\n';
        info += 'Score: ${replay.score}\n';
        info += 'Misses: ${replay.misses}\n';
        info += 'Rating: ${replay.rating} (${replay.ratingFC})\n';
        info += 'Notes: ${replay.songNotes.length}\n';
        info += 'Date: ${replay.timestamp}';
        
        return info;
    }
}