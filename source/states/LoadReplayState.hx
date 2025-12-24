package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import backend.Replay;
import sys.FileSystem;
import backend.Song;
import backend.Difficulty;
import backend.ClientPrefs;

class LoadReplayState extends MusicBeatState
{
    var grpReplays:FlxTypedGroup<Alphabet>;
    var replays:Array<String> = [];
    var curSelected:Int = 0;
    
    var infoText:FlxText;
    var noReplaysText:FlxText;
    
    override function create()
    {
        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFFea71fd;
        bg.setGraphicSize(Std.int(bg.width * 1.1));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);
        
        // 读取回放文件
        loadReplays();
        
        grpReplays = new FlxTypedGroup<Alphabet>();
        add(grpReplays);
        
        createReplayList();
        
        // 信息文本
        infoText = new FlxText(5, FlxG.height - 44, FlxG.width - 10, 
            "ENTER - Load | BACK - Return | F - Delete", 16);
        infoText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        infoText.borderSize = 2;
        add(infoText);
        
        // 无回放文本
        noReplaysText = new FlxText(0, FlxG.height / 2 - 20, FlxG.width, 
            "No Replays Found\nPress BACK to return", 24);
        noReplaysText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        noReplaysText.borderSize = 2;
        noReplaysText.visible = (replays.length == 0);
        add(noReplaysText);
        
        changeSelection();
        
        super.create();
    }
    
    function loadReplays()
    {
        #if sys
        replays = [];
        
        var replayDir = "assets/replays/";
        if (FileSystem.exists(replayDir)) {
            var files = FileSystem.readDirectory(replayDir);
            files.sort(function(a:String, b:String):Int {
                var aTime = getFileTime(a);
                var bTime = getFileTime(b);
                return Std.int(bTime - aTime);
            });
            
            for (file in files) {
                if (file.endsWith(".kadeReplay")) {
                    replays.push(file);
                }
            }
        }
        #end
    }
    
    function getFileTime(filename:String):Float
    {
        var timeMatch = ~/time(\d+)\.kadeReplay$/;
        if (timeMatch.match(filename)) {
            return Std.parseFloat(timeMatch.matched(1));
        }
        return 0;
    }
    
    function createReplayList()
    {
        grpReplays.clear();
        
        for (i in 0...replays.length)
        {
            var displayName:String = replays[i];
            displayName = displayName.replace("replay-", "").replace(".kadeReplay", "");
            displayName = displayName.replace("_", " ");
            
            var replayText:Alphabet = new Alphabet(0, (70 * i) + 30, displayName, true);
            replayText.isMenuItem = true;
            replayText.targetY = i;
            grpReplays.add(replayText);
        }
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
            if (replays.length > 0) {
                loadReplay(replays[curSelected]);
            }
        }
        
        if (FlxG.keys.justPressed.F) {
            if (replays.length > 0) {
                deleteReplay(replays[curSelected]);
            }
        }
    }
    
    function changeSelection(change:Int = 0)
    {
        if (replays.length == 0) return;
        
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
        
        // 加载回放
        var rep:Replay = Replay.LoadReplay(filename);
        
        if (rep != null && rep.isValid())
        {
            trace('Successfully loaded replay: ${rep.replay.songName}');
            
            // 设置模组目录
            var modPath:String = rep.replay.chartPath;
            #if MODS_ALLOWED
            if (modPath != null && modPath.length > 0 && modPath != "null")
            {
                Mods.currentModDirectory = modPath;
            }
            else
            {
                Mods.currentModDirectory = "";
            }
            #end
            
            // 设置到 PlayState
            PlayState.rep = rep;
            PlayState.loadRep = true;
            
            // 加载歌曲
            try
            {
                var songName:String = rep.replay.songName;
                var songDiff:Int = rep.replay.songDiff;
                var difficulty:String = Difficulty.getFilePath(songDiff);
                
                var loadedSong:SwagSong = Song.loadFromJson(songName + difficulty, songName);
                
                if (loadedSong != null)
                {
                    PlayState.storyDifficulty = songDiff;
                    PlayState.isStoryMode = false;
                    
                    // 切换到PlayState
                    FlxG.sound.music.stop();
                    LoadingState.loadAndSwitchState(new PlayState());
                    return;
                }
            }
            catch(e:Dynamic)
            {
                trace('Error loading song: $e');
            }
            
            // 显示错误
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Failed to load replay song!");
        }
        else
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Invalid replay file!");
        }
    }
    
    function showError(message:String):Void
    {
        var errorMsg:FlxText = new FlxText(0, FlxG.height / 2 - 30, FlxG.width, 
            message, 20);
        errorMsg.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
        errorMsg.borderSize = 2;
        errorMsg.screenCenter(X);
        add(errorMsg);
        
        new FlxTimer().start(3, function(tmr:FlxTimer) {
            remove(errorMsg);
            errorMsg.destroy();
        });
    }
    
    function deleteReplay(filename:String):Void
    {
        #if sys
        var replayPath = "assets/replays/" + filename;
        if (FileSystem.exists(replayPath)) {
            FileSystem.deleteFile(replayPath);
            trace('Deleted replay: $filename');
            
            // 刷新列表
            loadReplays();
            createReplayList();
            
            // 重置选择
            if (replays.length > 0)
            {
                curSelected = 0;
                changeSelection(0);
            }
            else
            {
                noReplaysText.visible = true;
            }
        }
        #end
    }
}