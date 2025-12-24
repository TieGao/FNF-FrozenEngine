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
    public var timestamp:Date;
    public var songName:String;
    public var songDiff:Int;
    public var songNotes:Array<Dynamic>; // [strumTime, sustainLength, noteData, diff]
    public var songJudgements:Array<String>;
    public var noteSpeed:Float;
    public var chartPath:String;
    public var isDownscroll:Bool;
    public var sf:Int;
    public var sm:Bool;
    public var ana:Analysis;
    public var playerName:String;
    public var accuracy:Float;
    public var score:Int;
    public var misses:Int;
    public var rating:String;
    public var ratingFC:String;
}

class Replay
{
    public static var version:String = "1.3";

    public var path:String = "";
    public var replay:ReplayJSON;
    
    // 回放播放相关
    public var currentIndex:Int = 0;
    public var judgementIndex:Int = 0;
    
    // 回放录制相关
    public var noteRecording:Array<Array<Dynamic>> = []; // [strumTime, sustainLength, noteData, diff]
    public var judgementRecording:Array<String> = [];
    public var anaRecording:Analysis;
    
    public function new(path:String)
    {
        this.path = path;
        replay = {
            songName: "No Song Found", 
            songDiff: 1,
            noteSpeed: 1.5,
            isDownscroll: false,
            songNotes: [],
            replayGameVer: version,
            chartPath: "",
            sm: false,
            timestamp: Date.now(),
            sf: 10,
            ana: new Analysis(),
            songJudgements: [],
            playerName: "Player",
            accuracy: 0.0,
            score: 0,
            misses: 0,
            rating: "N/A",
            ratingFC: "N/A"
        };
        
        anaRecording = new Analysis();
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
        // 获取当前模组目录
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
        
        var chartPath:String = currentMod;
        
        // 计算数据
        var missCount:Int = 0;
        for (j in judge) {
            if (j == "miss") missCount++;
        }
        
        var totalNotes:Int = notearray.length;
        var totalHits:Int = totalNotes - missCount;
        var accuracy:Float = totalNotes > 0 ? (totalHits / totalNotes) * 100 : 0;
        
        // 生成评分
        var rating:String = "N/A";
        var ratingFC:String = "N/A";
        
        if (PlayState.instance != null)
        {
            rating = PlayState.instance.ratingName;
            ratingFC = PlayState.instance.ratingFC;
        }
        
        // 获取玩家名称
        var playerName:String = "Player";
        #if (sys && windows)
        try {
            playerName = Sys.environment()["USERNAME"];
        } catch(e:Dynamic) {}
        #end
        
        var json = {
            "songName": PlayState.SONG != null ? PlayState.SONG.song : "Unknown",
            "songDiff": PlayState.storyDifficulty,
            "chartPath": chartPath,
            "sm": false,
            "timestamp": Date.now(),
            "replayGameVer": version,
            "sf": 10,
            "noteSpeed": PlayState.SONG != null ? PlayState.SONG.speed : 1.5,
            "isDownscroll": ClientPrefs.data.downScroll,
            "songNotes": notearray,
            "songJudgements": judge,
            "ana": ana,
            "playerName": playerName,
            "accuracy": accuracy,
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
                
                // 初始化播放索引
                currentIndex = 0;
                judgementIndex = 0;
                
                trace('Successfully loaded replay:');
                trace('  Song: ${repl.songName}');
                trace('  Difficulty: ${repl.songDiff}');
                trace('  Player: ${repl.playerName}');
                trace('  Accuracy: ${repl.accuracy}%');
                trace('  Notes: ${repl.songNotes.length}');
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
    
    // ========== 回放录制方法 - 参考Kade Engine的方式 ==========
    
    public function startRecording():Void
    {
        noteRecording = [];
        judgementRecording = [];
        anaRecording = new Analysis();
        trace('Started recording replay');
    }
    
    // 参考Kade Engine的记录方式
    public function recordNote(strumTime:Float, noteData:Int, sustainLength:Float, diff:Float):Void
    {
        // Kade Engine的方式：直接记录原始diff值
        // 如果diff太大，可能是miss，但我们不应该在这里修正
        // 让图表处理显示逻辑
        noteRecording.push([strumTime, sustainLength, noteData, diff]);
    }
    
    // 记录miss - 使用Kade Engine的约定：diff = -10000 表示miss
    public function recordMiss(noteData:Int, strumTime:Float):Void
    {
        // 使用-10000作为miss标记（Kade Engine约定）
        noteRecording.push([strumTime, 0, noteData, -10000]);
        judgementRecording.push("miss");
        
        // 分析数据
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
    
    // 记录判定
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
            replay.noteSpeed = PlayState.SONG.speed;
            replay.isDownscroll = ClientPrefs.data.downScroll;
            replay.accuracy = PlayState.instance.ratingPercent * 100;
            replay.score = PlayState.instance.songScore;
            replay.misses = PlayState.instance.songMisses;
            replay.rating = PlayState.instance.ratingName;
            replay.ratingFC = PlayState.instance.ratingFC;
        }
    }
    
    // ========== 回放播放方法 ==========
    
    public function startPlayback():Void
    {
        trace('Starting replay playback for: ' + replay.songName);
        trace('Total notes in replay: ' + replay.songNotes.length);
        currentIndex = 0;
        judgementIndex = 0;
    }
    
    public function getNextNote(strumTime:Float):Array<Dynamic>
    {
        while (currentIndex < replay.songNotes.length)
        {
            var note:Array<Dynamic> = replay.songNotes[currentIndex];
            if (note[0] <= strumTime + 50) // 50ms容差
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
               replay.songNotes.length > 0;
    }
    
    public function getReplay():ReplayJSON
    {
        return replay;
    }

    public function getReplayInfo():String
    {
        if (!isValid()) return "Invalid Replay";
        
        var info:String = 'Song: ${replay.songName}\n';
        info += 'Difficulty: ${Difficulty.getString(replay.songDiff)}\n';
        info += 'Player: ${replay.playerName}\n';
        info += 'Accuracy: ${Math.round(replay.accuracy * 100) / 100}%\n';
        info += 'Score: ${replay.score}\n';
        info += 'Misses: ${replay.misses}\n';
        info += 'Rating: ${replay.rating} (${replay.ratingFC})\n';
        info += 'Notes: ${replay.songNotes.length}\n';
        info += 'Date: ${replay.timestamp}';
        
        return info;
    }
}