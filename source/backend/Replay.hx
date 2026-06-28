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
    public var timestamp:Date; // 保存为 Date，但 JSON 中实际为字符串
    public var songName:String;
    public var songDiff:Int;
    public var difficultyName:String;
    public var songNotes:Array<Dynamic>;
    public var songJudgements:Array<String>;
    public var noteSpeed:Float;
    public var chartPath:String;
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

class Replay
{
    public static var version:String = "1.5";

    public var path:String = "";
    public var replay:ReplayJSON;
    
    public var currentIndex:Int = 0;
    public var judgementIndex:Int = 0;
    
    public var noteRecording:Array<Array<Dynamic>> = [];
    public var judgementRecording:Array<String> = [];
    public var anaRecording:Analysis;
    
    public function new(path:String)
    {
        this.path = path;
        replay = {
            songName: "No Song Found", 
            songDiff: 1,
            difficultyName: "Normal",
            noteSpeed: 1.5,
            isDownscroll: false,
            songNotes: [],
            replayGameVer: version,
            chartPath: "",
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

    public static function LoadReplay(path:String):Replay
    {
        var rep:Replay = new Replay(path);
        rep.LoadFromJSON();
        return rep;
    }

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
        
        var chartPath:String = "";
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

        var replayDir = "assets/replays/";
        if (!FileSystem.exists(replayDir))
            FileSystem.createDirectory(replayDir);

        var songNameForFile:String = PlayState.SONG != null ? 
            StringTools.replace(StringTools.replace(PlayState.SONG.song, " ", "_"), ":", "_") : "Unknown";
        var diffName:String = Difficulty.getString().toLowerCase();
        
        var fileName:String = 'replay_${songNameForFile}_${diffName}_${time}.kadeReplay';
        File.saveContent(replayDir + fileName, data);
        
        path = fileName;
        trace('=== REPLAY SAVED ===');
        trace('File: $fileName');
        trace('Mod Directory: $modDirectory');
        trace('Difficulty ID: $songDiff');
        trace('Difficulty Name: $difficultyName');
        trace('Notes: ${notearray.length}');
        trace('Accuracy: ${accuracy}%');
        trace('Misses: ${missCount}');
        trace('====================');
        #end
    }

    public function LoadFromJSON()
    {
        #if sys
        try
        {
            var filePath:String = "assets/replays/" + path;
            trace('Loading replay from: $filePath');
            
            if (FileSystem.exists(filePath))
            {
                var fileContent:String = File.getContent(filePath);
                var repl:ReplayJSON = cast Json.parse(fileContent);
                replay = repl;
                
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
                
                // 修复 timestamp：JSON 解析后是字符串，尝试转为 Date
                var ts = replay.timestamp;
                if (ts != null)
                {
                    if (Std.isOfType(ts, String))
                    {
                        var str:String = cast ts;
                        // 尝试解析为 Date
                        try {
                            var parsed:Date = Date.fromString(str);
                            if (parsed != null) replay.timestamp = parsed;
                            else {
                                // 如果失败，尝试从数字解析（有些旧版本存为数字）
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
                // 如果仍然是 null 或无效，设置为当前时间
                if (replay.timestamp == null) {
                    replay.timestamp = Date.now();
                }
                
                // 初始化播放索引
                currentIndex = 0;
                judgementIndex = 0;
                
                trace('Successfully loaded replay:');
                trace('  Song: ${repl.songName}');
                trace('  Difficulty: ${repl.difficultyName}');
                trace('  Mod Directory: ${repl.modDirectory}');
                trace('  Accuracy: ${repl.accuracy}%');
                trace('  Notes: ${repl.songNotes.length}');
                trace('  Timestamp: ${replay.timestamp}');
            }
            else
            {
                trace('Replay file not found: $filePath');
            }
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