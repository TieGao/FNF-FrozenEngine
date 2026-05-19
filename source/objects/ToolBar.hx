package objects;

import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.util.FlxDestroyUtil;
import flixel.ui.FlxButton;
import flixel.util.FlxStringUtil;
import backend.Paths;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import states.FreeplayState;
import objects.MusicPlayerLegacy;
import options.KEOptionsMenu;

class ToolBar extends FlxSpriteGroup
{
    public var background:FlxSprite;
    public var textDisplay:FlxText;
    public var musicPlayer:MusicPlayerLegacy;
    
    // 按钮相关
    public var buttons:Array<FlxButton> = [];
    public var buttonTexts:Array<String> = [];
    public var buttonWidth:Int = 150;
    public var buttonSpacing:Int = 5;
    
    // 播放器控制相关
    public var playPauseButton:FlxButton;
    public var stopButton:FlxButton;
    public var prevButton:FlxButton;
    public var nextButton:FlxButton;
    public var timeText:FlxText;
    public var progressBar:FlxSprite;
    public var progressFill:FlxSprite;
    public var volumeDownButton:FlxButton;
    public var volumeUpButton:FlxButton;
    public var volumeText:FlxText;
    
    // 状态
    public var isMusicPlayerMode:Bool = false;
    public var currentSongName:String = "";
    
    // 引用
    private var freeplayState:FreeplayState;
    
    // 播放器更新定时器
    private var updateTimer:Float = 0;
    
    public function new(state:FreeplayState, width:Int, height:Int)
    {
        super();
        
        freeplayState = state;
        syncMusicPlayer();
        
        background = new FlxSprite(0, FlxG.height - height).makeGraphic(width, height, 0xFF000000);
        background.alpha = 0.6;
        background.scrollFactor.set();
        add(background);
        
        // 创建文本显示（作为备用）
        textDisplay = new FlxText(0, background.y + 4, width, "", 16);
        textDisplay.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
        textDisplay.scrollFactor.set();
        textDisplay.visible = false;
        add(textDisplay);
        
        // 创建按钮
        createButtons();
        
        // 创建播放器控件
        createPlayerControls();
        
        // 默认显示按钮模式
        setNormalMode();
    }
    
    private function createButtons():Void
    {
        var buttonY:Float = background.y + (background.height - 30) / 2;
        var startX:Float = (FlxG.width - (buttonWidth * 4 + buttonSpacing * 3)) / 2;
        
        var buttonNames:Array<String> = [Language.getPhrase("options", "OPTIONS"), Language.getPhrase("gameplay", "GAMEPLAY"), Language.getPhrase("reset", "RESET"), Language.getPhrase("listen", "LISTEN")];
        var buttonActions:Array<Void->Void> = [
            openOptions,
            openGameplayChangers,
            resetScore,
            toggleListenMode
        ];
        
        for (i in 0...buttonNames.length)
        {
            var btn = new FlxButton(startX + i * (buttonWidth + buttonSpacing), buttonY, buttonNames[i], buttonActions[i]);
            btn.loadGraphic(createButtonGraphic(buttonWidth, 50, 0xFF333333));
            btn.label.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
            btn.label.fieldWidth = buttonWidth;
            btn.scrollFactor.set();
            add(btn);
            buttons.push(btn);
        }
    }
    
    private function createButtonGraphic(width:Int, height:Int, color:Int):FlxGraphic
    {
        // 使用 FlxGraphic.fromBitmapData 来创建图形
        var bitmapData:openfl.display.BitmapData = new openfl.display.BitmapData(width, height, true, color);
        return FlxGraphic.fromBitmapData(bitmapData, false, null);
    }
    
    private function createPlayerControls():Void
    {
        var centerY:Float = background.y + background.height / 2;
        var btnSize:Int = 32;
        
        // 播放/暂停按钮
        playPauseButton = new FlxButton(0, centerY - btnSize/2, "▶", playPauseAction);
        playPauseButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        playPauseButton.label.setFormat(Paths.font("HarmonyOS_Sans_SC_Medium.ttf"), 16, FlxColor.WHITE, CENTER);
        playPauseButton.scrollFactor.set();
        add(playPauseButton);
        
        // 停止按钮
        stopButton = new FlxButton(0, centerY - btnSize/2, "■", stopAction);
        stopButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        stopButton.label.setFormat(Paths.font("HarmonyOS_Sans_SC_Medium.ttf"), 16, FlxColor.WHITE, CENTER);
        stopButton.scrollFactor.set();
        add(stopButton);
        
        // 上一首
        prevButton = new FlxButton(0, centerY - btnSize/2, "◀◀", prevAction);
        prevButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        prevButton.label.setFormat(Paths.font("HarmonyOS_Sans_SC_Medium.ttf"), 14, FlxColor.WHITE, CENTER);
        prevButton.scrollFactor.set();
        add(prevButton);
        
        // 下一首
        nextButton = new FlxButton(0, centerY - btnSize/2, "▶▶", nextAction);
        nextButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        nextButton.label.setFormat(Paths.font("HarmonyOS_Sans_SC_Medium.ttf"), 14, FlxColor.WHITE, CENTER);
        nextButton.scrollFactor.set();
        add(nextButton);
        
        // 时间文本
        timeText = new FlxText(0, centerY - 10, 140, "0:00 / 0:00", 14);
        timeText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER);
        timeText.scrollFactor.set();
        add(timeText);
        
        // 进度条背景
        progressBar = new FlxSprite(0, centerY + 30).makeGraphic(300, 20, 0xFF444444);
        progressBar.scrollFactor.set();
        add(progressBar);
        
        // 进度条填充
        progressFill = new FlxSprite(0, centerY + 30).makeGraphic(300, 20, 0xFF88FF88);
        progressFill.scrollFactor.set();
        add(progressFill);
        
        // 音量减
        volumeDownButton = new FlxButton(0, centerY - btnSize/2, "−", volumeDownAction);
        volumeDownButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        volumeDownButton.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        volumeDownButton.scrollFactor.set();
        add(volumeDownButton);
        
        // 音量加
        volumeUpButton = new FlxButton(0, centerY - btnSize/2, "+", volumeUpAction);
        volumeUpButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        volumeUpButton.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        volumeUpButton.scrollFactor.set();
        add(volumeUpButton);
        
        // 音量文本
        volumeText = new FlxText(0, centerY - 10, 60, "100%", 16);
        volumeText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
        volumeText.scrollFactor.set();
        add(volumeText);
        
        // 默认隐藏播放器控件
        setPlayerControlsVisible(false);
    }
    
    // 按钮动作函数
    private function playPauseAction():Void
    {
        syncMusicPlayer();
        if (musicPlayer != null && musicPlayer.playingMusic)
        {
            musicPlayer.pauseOrResume(!musicPlayer.playing);
            updatePlayPauseButton(musicPlayer.playing);
            return;
        }

        if (freeplayState != null)
        {
            freeplayState.togglePlaySong();
        }
    }
    
    private function stopAction():Void
    {
        if (freeplayState != null)
        {
            freeplayState.stopMusicAndReset();
        }
    }
    
    private function prevAction():Void
    {
        if (freeplayState != null)
        {
            freeplayState.prevSong();
            syncMusicPlayer();
        }
    }
    
    private function nextAction():Void
    {
        if (freeplayState != null)
        {
            freeplayState.nextSong();
            syncMusicPlayer();
        }
    }
    
    private function volumeDownAction():Void
    {
        if (FlxG.sound.music != null)
        {
            var newVol:Float = FlxG.sound.music.volume - 0.1;
            if (newVol < 0) newVol = 0;
            FlxG.sound.music.volume = newVol;
            updateVolumeText();
        }
    }
    
    private function volumeUpAction():Void
    {
        if (FlxG.sound.music != null)
        {
            var newVol:Float = FlxG.sound.music.volume + 0.1;
            if (newVol > 1) newVol = 1;
            FlxG.sound.music.volume = newVol;
            updateVolumeText();
        }
    }
    
    private function updateVolumeText():Void
    {
        if (FlxG.sound.music != null && volumeText != null)
        {
            var volPercent:Int = Math.round(FlxG.sound.music.volume * 100);
            volumeText.text = volPercent + "%";
        }
    }
    
    private function setPlayerControlsVisible(visible:Bool):Void
    {
        if (playPauseButton != null) playPauseButton.visible = visible;
        if (stopButton != null) stopButton.visible = visible;
        if (prevButton != null) prevButton.visible = visible;
        if (nextButton != null) nextButton.visible = visible;
        if (timeText != null) timeText.visible = visible;
        if (progressBar != null) progressBar.visible = visible;
        if (progressFill != null) progressFill.visible = visible;
        if (volumeDownButton != null) volumeDownButton.visible = visible;
        if (volumeUpButton != null) volumeUpButton.visible = visible;
        if (volumeText != null) volumeText.visible = visible;
        
        if (playPauseButton != null) playPauseButton.active = visible;
        if (stopButton != null) stopButton.active = visible;
        if (prevButton != null) prevButton.active = visible;
        if (nextButton != null) nextButton.active = visible;
        if (volumeDownButton != null) volumeDownButton.active = visible;
        if (volumeUpButton != null) volumeUpButton.active = visible;
    }
    
    public function setNormalMode():Void
    {
        isMusicPlayerMode = false;
        if (textDisplay != null) textDisplay.visible = false;
        
        for (btn in buttons)
        {
            if (btn != null)
            {
                btn.visible = true;
                btn.active = true;
            }
        }
        
        setPlayerControlsVisible(false);
    }
    
    public function setMusicPlayerMode(songName:String):Void
    {
        isMusicPlayerMode = true;
        currentSongName = songName;
        if (textDisplay != null) textDisplay.visible = false;
        
        for (btn in buttons)
        {
            if (btn != null)
            {
                btn.visible = false;
                btn.active = false;
            }
        }
        
        setPlayerControlsVisible(true);
        updatePlayerPositions();
        syncMusicPlayer();
        updatePlayPauseButton(musicPlayer != null ? musicPlayer.playing : true);
        updateVolumeText();
    }
    
    private function syncMusicPlayer():Void
    {
        if (musicPlayer == null && freeplayState != null)
            musicPlayer = freeplayState.musicPlayer;
    }
    
    public function updatePlayPauseButton(isPlaying:Bool):Void
    {
        if (playPauseButton != null)
        {
            playPauseButton.label.text = isPlaying ? "❚❚" : "▶";
        }
    }
    
    public function updateTimeDisplay(current:Float, total:Float):Void
    {
        if (timeText != null)
        {
            var currentStr:String = FlxStringUtil.formatTime(current / 1000, false);
            var totalStr:String = FlxStringUtil.formatTime(total / 1000, false);
            timeText.text = currentStr + " / " + totalStr;
        }
        
        if (progressBar != null && progressFill != null && total > 0)
        {
            var percent:Float = current / total;
            var fillWidth:Int = Std.int(progressBar.width * percent);
            if (fillWidth < 0) fillWidth = 0;
            if (fillWidth > progressBar.width) fillWidth = Std.int(progressBar.width);
            progressFill.setGraphicSize(fillWidth, Std.int(progressFill.height));
            progressFill.updateHitbox();
        }
    }
    
    private function updatePlayerPositions():Void
    {
        var centerY:Float = background.y + background.height / 2;
        var totalWidth:Float = 0;
        var startX:Float;
        
        // 计算所需总宽度
        var controlsWidth:Array<Float> = [36, 36, 36, 36, 140, 300, 36, 36, 60];
        for (w in controlsWidth) totalWidth += w;
        totalWidth += 8 * 5; // spacing
        
        startX = (FlxG.width - totalWidth) / 2;
        var currentX:Float = startX;
        
        // 布局所有控件
        if (playPauseButton != null)
        {
            playPauseButton.x = currentX;
            playPauseButton.y = centerY - playPauseButton.height/2;
            currentX += playPauseButton.width + 5;
        }
        
        if (stopButton != null)
        {
            stopButton.x = currentX;
            stopButton.y = centerY - stopButton.height/2;
            currentX += stopButton.width + 5;
        }
        
        if (prevButton != null)
        {
            prevButton.x = currentX;
            prevButton.y = centerY - prevButton.height/2;
            currentX += prevButton.width + 5;
        }
        
        if (nextButton != null)
        {
            nextButton.x = currentX;
            nextButton.y = centerY - nextButton.height/2;
            currentX += nextButton.width + 5;
        }
        
        if (timeText != null)
        {
            timeText.x = currentX;
            timeText.y = centerY - timeText.height/2;
            currentX += timeText.width + 5;
        }
        
        if (progressBar != null)
        {
            progressBar.x = currentX;
            progressBar.y = centerY + 12;
            currentX += progressBar.width + 5;
        }
        
        if (progressFill != null && progressBar != null)
        {
            progressFill.x = progressBar.x;
            progressFill.y = progressBar.y;
        }
        
        if (volumeDownButton != null)
        {
            volumeDownButton.x = currentX;
            volumeDownButton.y = centerY - volumeDownButton.height/2;
            currentX += volumeDownButton.width + 5;
        }
        
        if (volumeUpButton != null)
        {
            volumeUpButton.x = currentX;
            volumeUpButton.y = centerY - volumeUpButton.height/2;
            currentX += volumeUpButton.width + 5;
        }
        
        if (volumeText != null)
        {
            volumeText.x = currentX;
            volumeText.y = centerY - volumeText.height/2;
        }
    }
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        if (isMusicPlayerMode)
        {
            syncMusicPlayer();
            updateTimer += elapsed;
            if (updateTimer >= 0.05) // 每秒更新20次
            {
                updateTimer = 0;
                if (FlxG.sound.music != null)
                {
                    updateTimeDisplay(FlxG.sound.music.time, FlxG.sound.music.length);
                    updatePlayPauseButton(musicPlayer != null ? musicPlayer.playing : FlxG.sound.music.playing);
                }
            }
        }
    }
    
    // 按钮回调函数
    private function openOptions():Void
    {
        if (freeplayState != null)
        {
            MusicBeatState.switchState(new KEOptionsMenu());
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }
    }
    
    private function openGameplayChangers():Void
    {
        if (freeplayState != null && freeplayState.persistentUpdate)
        {
            freeplayState.persistentUpdate = false;
            freeplayState.openSubState(new GameplayChangersSubstate());
        }
    }
    
    private function resetScore():Void
    {
        if (freeplayState != null && FreeplayState.curSelected >= 0 && FreeplayState.curSelected < freeplayState.songs.length)
        {
            freeplayState.persistentUpdate = false;
            var song = freeplayState.songs[FreeplayState.curSelected];
            freeplayState.openSubState(new ResetScoreSubState(song.songName, freeplayState.curDifficulty, song.songCharacter, -1, song.folder));
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }
    }
    
    private function toggleListenMode():Void
    {
        if (freeplayState != null)
        {
            freeplayState.togglePlaySong();
        }
    }
    
    public function setText(message:String):Void
    {
        if (textDisplay != null && !isMusicPlayerMode)
        {
            textDisplay.text = message;
        }
    }
    
    public function setXY(x:Float, y:Float):Void
    {
        if (background != null)
        {
            background.x = x;
            background.y = y;
        }
        if (textDisplay != null)
        {
            textDisplay.x = x;
            textDisplay.y = y + 4;
        }
        
        // 重新计算按钮位置
        var buttonY:Float = background.y + (background.height - 30) / 2;
        var startX:Float = (FlxG.width - (buttonWidth * 4 + buttonSpacing * 3)) / 2;
        
        for (i in 0...buttons.length)
        {
            if (buttons[i] != null)
            {
                buttons[i].x = startX + i * (buttonWidth + buttonSpacing);
                buttons[i].y = buttonY;
            }
        }
        
        updatePlayerPositions();
    }
    
    override public function destroy():Void
    {
        background = FlxDestroyUtil.destroy(background);
        textDisplay = FlxDestroyUtil.destroy(textDisplay);
        
        for (btn in buttons)
            FlxDestroyUtil.destroy(btn);
        buttons = null;
        
        playPauseButton = FlxDestroyUtil.destroy(playPauseButton);
        stopButton = FlxDestroyUtil.destroy(stopButton);
        prevButton = FlxDestroyUtil.destroy(prevButton);
        nextButton = FlxDestroyUtil.destroy(nextButton);
        timeText = FlxDestroyUtil.destroy(timeText);
        progressBar = FlxDestroyUtil.destroy(progressBar);
        progressFill = FlxDestroyUtil.destroy(progressFill);
        volumeDownButton = FlxDestroyUtil.destroy(volumeDownButton);
        volumeUpButton = FlxDestroyUtil.destroy(volumeUpButton);
        volumeText = FlxDestroyUtil.destroy(volumeText);
        
        freeplayState = null;
        
        super.destroy();
    }
}