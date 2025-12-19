package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;
import backend.Replay;
import sys.FileSystem;
import sys.io.File;

class LoadReplayState extends MusicBeatState
{
    var grpReplays:FlxTypedGroup<Alphabet>;
    var replays:Array<String> = [];
    var curSelected:Int = 0;
    
    override function create()
    {
        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFFea71fd;
        bg.setGraphicSize(Std.int(bg.width * 1.1));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);
        
        #if sys
        // 读取回放文件
        var replayDir = "assets/replays/";
        if (FileSystem.exists(replayDir)) {
            for (file in FileSystem.readDirectory(replayDir)) {
                if (file.endsWith(".kadeReplay")) {
                    replays.push(file);
                }
            }
        }
        #end
        
        if (replays.length == 0) {
            replays.push("No Replays Found");
        }
        
        grpReplays = new FlxTypedGroup<Alphabet>();
        add(grpReplays);
        
        for (i in 0...replays.length) {
            var replayText:Alphabet = new Alphabet(0, (70 * i) + 30, replays[i], true, false);
            replayText.isMenuItem = true;
            replayText.targetY = i;
            grpReplays.add(replayText);
        }
        
        var infoText = new FlxText(5, FlxG.height - 64, FlxG.width - 10, 
            "SELECT - Load Replay | BACK - Return | F - Delete Replay", 16);
        infoText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        infoText.borderSize = 2;
        add(infoText);
        
        changeSelection();
        
        super.create();
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (controls.BACK) {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new MainMenuState());
        }
        
        if (controls.UI_UP_P) {
            changeSelection(-1);
        }
        
        if (controls.UI_DOWN_P) {
            changeSelection(1);
        }
        
        if (controls.ACCEPT) {
            if (replays[curSelected] != "No Replays Found") {
                loadReplay(replays[curSelected]);
            }
        }
        
        if (FlxG.keys.justPressed.F) {
            if (replays[curSelected] != "No Replays Found") {
                deleteReplay(replays[curSelected]);
            }
        }
    }
    
    function changeSelection(change:Int = 0)
    {
        curSelected += change;
        
        if (curSelected < 0)
            curSelected = replays.length - 1;
        if (curSelected >= replays.length)
            curSelected = 0;
            
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        
        var bullShit:Int = 0;
        for (item in grpReplays.members)
        {
            item.targetY = bullShit - curSelected;
            bullShit++;
            
            item.alpha = 0.6;
            if (item.targetY == 0)
            {
                item.alpha = 1;
            }
        }
    }
    
    function loadReplay(filename:String):Void
    {
        trace('Loading replay: $filename');
        
        PlayState.rep = Replay.LoadReplay(filename);
        PlayState.loadRep = true;
        PlayState.rep.startPlayback();
        
        // 切换到对应歌曲的PlayState
        // 这里需要根据回放文件中的歌曲信息加载对应的歌曲
        LoadingState.loadAndSwitchState(new PlayState());
    }
    
    function deleteReplay(filename:String):Void
    {
        #if sys
        var replayPath = "assets/replays/" + filename;
        if (FileSystem.exists(replayPath)) {
            FileSystem.deleteFile(replayPath);
            trace('Deleted replay: $filename');
            
            // 刷新列表
            create();
        }
        #end
    }
}