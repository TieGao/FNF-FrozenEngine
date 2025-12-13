package backend;

#if sys
import sys.io.File;
#end
// 移除 Controls.Control 导入，因为可能不存在
import flixel.FlxG;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.FileReference;
import lime.utils.Assets;
import haxe.Json;
import flixel.input.keyboard.FlxKey;
import openfl.utils.Dictionary;

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
    public var songNotes:Array<Dynamic>;
    public var songJudgements:Array<String>;
    public var noteSpeed:Float;
    public var chartPath:String;
    public var isDownscroll:Bool;
    public var sf:Int;
    public var sm:Bool;
    public var ana:Analysis;
}

class Replay
{
    public static var version:String = "1.2";

    public var path:String = "";
    public var replay:ReplayJSON;
    
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
            sf: 10, // 默认safe frames
            ana: new Analysis(),
            songJudgements: []
        };
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
        var json = {
            "songName": PlayState.SONG.song,
            "songDiff": PlayState.storyDifficulty,
            "chartPath": "",
            "sm": false,
            "timestamp": Date.now(),
            "replayGameVer": version,
            "sf": 10,
            "noteSpeed": PlayState.SONG.speed,
            "isDownscroll": false,
            "songNotes": notearray,
            "songJudgements": judge,
            "ana": ana
        };

        var data:String = Json.stringify(json, null, "");
        var time = Date.now().getTime();

        File.saveContent("assets/replays/replay-" + PlayState.SONG.song + "-time" + time + ".kadeReplay", data);
        path = "replay-" + PlayState.SONG.song + "-time" + time + ".kadeReplay";
        #end
    }

    public function LoadFromJSON()
    {
        #if sys
        try
        {
            var repl:ReplayJSON = cast Json.parse(File.getContent("assets/replays/" + path));
            replay = repl;
        }
        catch(e)
        {
            trace('Failed to load replay: ' + e.message);
        }
        #end
    }
}