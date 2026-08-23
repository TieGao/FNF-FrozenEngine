package objects;

import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.util.FlxDestroyUtil;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.ui.FlxButton;
import flixel.math.FlxRect;
import flixel.util.FlxStringUtil;
import backend.Paths;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import states.FreeplayState;
import objects.MusicPlayerLegacy;
import options.KEOptionsMenu;
import backend.ui.PsychUIButton; 


class ToolBar extends FlxSpriteGroup
{
    public var background:FlxFilteredSprite;
    public var textDisplay:FlxText;
    public var musicPlayer:MusicPlayerLegacy;
    
    // 按钮相关
    public var buttons:Array<PsychUIButton> = [];
    public var buttonTexts:Array<String> = [];
    public var buttonWidth:Int = 200;
    public var buttonSpacing:Int = 5;
    
    // 播放器控制相关
    public var playPauseButton:FlxButton;
    public var stopButton:FlxButton;
    public var prevButton:FlxButton;
    public var nextButton:FlxButton;
    public var volumeDownButton:FlxButton;
    public var volumeUpButton:FlxButton;
    public var volumeText:FlxText;
    
    // ★★★ 人声切换按钮 ★★★
    public var voiceToggleButton:FlxButton;
    public var voiceText:FlxText;
    public var voicesMuted:Bool = false;
    
    // ★★★ 音频可视化对象 ★★★
    public var audioDisplay:AudioDisplay;
    
    // 可视化参数
    public var vizBarCount:Int = 16;
    public var vizQuality:Int = 4;
    public var vizUpdateRate:Float = 33;
    
    // 状态
    public var isMusicPlayerMode:Bool = false;
    public var currentSongName:String = "";
    
    // 引用
    private var freeplayState:FreeplayState;
    private var parentState:MusicBeatState;
    
    // 播放器更新定时器
    private var updateTimer:Float = 0;
    
    // ★★★ 音频谱重建标记 ★★★
    private var needsAudioDisplayRebuild:Bool = false;

    public var blurFilter:BlurFilter;  // 模糊滤镜
    public var blurAmount:Float = 40;   // 模糊强度

    public function new(state:FreeplayState, width:Int, height:Int)
    {
        super();
        
        freeplayState = state;
        parentState = state;
        syncMusicPlayer();
        
        // 从配置读取可视化参数
        loadVizSettings();
        
        background = new FlxFilteredSprite(-100, FlxG.height - height);
        background.makeGraphic(width, height + 50, 0xFF000000);
        background.alpha = 0.6;
        background.scrollFactor.set();
        background.filters = [new BlurFilter(blurAmount, blurAmount, BitmapFilterQuality.HIGH)];
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
    
    // ===== 可视化参数加载 =====
    
    private function loadVizSettings():Void
    {
        vizBarCount = ClientPrefs.data.relaxAudioNumber;
        vizQuality = ClientPrefs.data.relaxAudioDisplayQuality;
        vizUpdateRate = ClientPrefs.data.audioDisplayUpdate;
    }
    
    // ===== ★★★ 音频可视化管理 ★★★ =====
    
    /**
     * 创建音频可视化（放在屏幕下方）
     */
    private function createAudioDisplay():Void
    {
        // 如果已存在则先销毁
        destroyAudioDisplay();
        
        // 如果没有音乐播放，不创建
        if (FlxG.sound.music == null || !FlxG.sound.music.playing)
        {
            return;
        }
        
        // 创建新的 AudioDisplay（放在屏幕下方）
        audioDisplay = new AudioDisplay(
            FlxG.sound.music,
            0,                          // X 位置（居中）
            FlxG.height - 50,          // Y 位置（放在工具栏上方，留出空间）
            FlxG.width,                // 宽度
            300,                       // 高度
            vizBarCount,               // 条形数量
            2,                         // 条形间距
            0xFF88FF88,                // 颜色（绿色）
            false                      // 是否对称
        );
        audioDisplay.inRelax = true;
        audioDisplay.stopUpdate = false;
        
        // 添加到父状态
        if (parentState != null)
        {
            parentState.add(audioDisplay);
        }
        else
        {
            var state = FlxG.state;
            if (state != null) state.add(audioDisplay);
        }
        
        needsAudioDisplayRebuild = false;
    }
    
    /**
     * 销毁音频可视化
     */
    private function destroyAudioDisplay():Void
    {
        if (audioDisplay != null)
        {
            audioDisplay.destroy();
            if (parentState != null)
            {
                parentState.remove(audioDisplay);
            }
            else
            {
                var state = FlxG.state;
                if (state != null) state.remove(audioDisplay);
            }
            audioDisplay = null;
        }
    }
    
    /**
     * 重建音频可视化（参数变化时调用）
     */
    private function rebuildAudioDisplay():Void
    {
        destroyAudioDisplay();
        createAudioDisplay();
    }
    
    // ===== 创建按钮 =====
    
    private function createButtons():Void
    {
        var buttonY:Float = background.y + (background.height - 40) / 2 - 20;
        var startX:Float = (FlxG.width - (buttonWidth * 4 + buttonSpacing * 3)) / 2;
        
        var buttonData:Array<{label:String, action:Void->Void}> = [
            {label: Language.getPhrase("options", "OPTIONS"), action: openOptions},
            {label: Language.getPhrase("gameplay", "GAMEPLAY"), action: openGameplayChangers},
            {label: Language.getPhrase("reset", "RESET"), action: resetScore},
            {label: Language.getPhrase("listen", "LISTEN"), action: toggleListenMode}
        ];
        
        for (i in 0...buttonData.length)
        {
            var btn = new PsychUIButton(
                startX + i * (buttonWidth + buttonSpacing),
                buttonY,
                buttonData[i].label,
                buttonData[i].action,
                buttonWidth,
                32
            );
            btn.scrollFactor.set();
            btn.text.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
            btn.text.fieldWidth = buttonWidth;
            
            btn.normalStyle = {bgColor: 0xFF333333, textColor: FlxColor.WHITE, bgAlpha: 0.9};
            btn.hoverStyle = {bgColor: 0xFF555577, textColor: FlxColor.WHITE, bgAlpha: 1};
            btn.clickStyle = {bgColor: 0xFF8888AA, textColor: FlxColor.WHITE, bgAlpha: 1};
            
            add(btn);
            buttons.push(btn);
        }
    }
    
    private function createButtonGraphic(width:Int, height:Int, color:Int):FlxGraphic
    {
        var bitmapData:openfl.display.BitmapData = new openfl.display.BitmapData(width, height, true, color);
        return FlxGraphic.fromBitmapData(bitmapData, false, null);
    }
    
    // ===== 创建播放器控件（移除了时间显示） =====
    
    private function createPlayerControls():Void
    {
        var centerY:Float = background.y + background.height / 2 - 20;
        var btnSize:Int = 32;
        var spacing:Int = 8;
        
        // 上一首
        prevButton = new FlxButton(0, centerY - btnSize/2, "◀◀", prevAction);
        prevButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        prevButton.label.setFormat(null, 14, FlxColor.WHITE, CENTER);
        prevButton.scrollFactor.set();
        prevButton.label.systemFont = "";
        add(prevButton);
        
        // ★★★ 播放/暂停（移到中心）★★★
        playPauseButton = new FlxButton(0, centerY - btnSize/2, "▶", playPauseAction);
        playPauseButton.loadGraphic(createButtonGraphic(btnSize + 10, btnSize + 10, 0xFF333366));
        playPauseButton.label.setFormat(null, 18, FlxColor.WHITE, CENTER);
        playPauseButton.scrollFactor.set();
        playPauseButton.label.systemFont = "";
        add(playPauseButton);
        
        // 下一首
        nextButton = new FlxButton(0, centerY - btnSize/2, "▶▶", nextAction);
        nextButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        nextButton.label.setFormat(null, 14, FlxColor.WHITE, CENTER);
        nextButton.scrollFactor.set();
        nextButton.label.systemFont = "";
        add(nextButton);
        
        // 停止
        stopButton = new FlxButton(0, centerY - btnSize/2, "■", stopAction);
        stopButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        stopButton.label.setFormat(null, 16, FlxColor.WHITE, CENTER);
        stopButton.scrollFactor.set();
        stopButton.label.systemFont = "";
        add(stopButton);
        
        // ★★★ 人声切换按钮 ★★★
        voiceToggleButton = new FlxButton(0, centerY - btnSize/2, "🎤", voiceToggleAction);
        voiceToggleButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        voiceToggleButton.label.setFormat(null, 14, FlxColor.WHITE, CENTER);
        voiceToggleButton.scrollFactor.set();
        voiceToggleButton.label.systemFont = "";
        add(voiceToggleButton);
        
        // 人声状态文字（显示在按钮旁边）
        voiceText = new FlxText(0, centerY - 10, 40, "ON", 12);
        voiceText.antialiasing = ClientPrefs.data.antialiasing;
        voiceText.setFormat(Paths.font("vcr.ttf"), 12, 0xFF88FF88, CENTER);
        voiceText.scrollFactor.set();
        add(voiceText);
        
        // 音量减
        volumeDownButton = new FlxButton(0, centerY - btnSize/2, "-", volumeDownAction);
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
        volumeText = new FlxText(0, centerY - 10, 50, "100%", 14);
        volumeText.antialiasing = ClientPrefs.data.antialiasing;
        volumeText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER);
        volumeText.scrollFactor.set();
        add(volumeText);
        
        // 默认隐藏播放器控件
        setPlayerControlsVisible(false);
    }
    
    // ===== 按钮动作函数 =====
    
    private function playPauseAction():Void
    {
        syncMusicPlayer();
        if (musicPlayer != null && musicPlayer.playingMusic)
        {
            // ★★★ 切换播放/暂停 ★★★
            var wasPlaying = musicPlayer.playing;
            musicPlayer.pauseOrResume(!wasPlaying);
            
            // ★★★ 重建音频谱（从暂停恢复时） ★★★
            if (!wasPlaying && FlxG.sound.music != null && FlxG.sound.music.playing)
            {
                // 如果从暂停恢复，需要重建音频谱
                needsAudioDisplayRebuild = true;
            }
            else if (wasPlaying && !musicPlayer.playing)
            {
                // 暂停时音频谱保留但停止更新，不需要销毁
                if (audioDisplay != null)
                {
                    audioDisplay.stopUpdate = true;
                }
            }
            
            updatePlayPauseButton(musicPlayer.playing);
            
            // 如果正在播放，恢复音频谱更新
            if (musicPlayer.playing && audioDisplay != null)
            {
                audioDisplay.stopUpdate = false;
            }
            return;
        }

        if (freeplayState != null)
        {
            freeplayState.togglePlaySong();
            // 延迟重建音频谱（等待音乐加载完成）
            needsAudioDisplayRebuild = true;
        }
    }
    
    private function stopAction():Void
    {
        if (freeplayState != null)
        {
            freeplayState.stopMusicAndReset();
            // 停止时销毁音频谱
            destroyAudioDisplay();
            voicesMuted = false;
            updateVoiceButton();
        }
    }
    
    private function prevAction():Void
    {
        if (freeplayState != null)
        {
            freeplayState.prevSong();
            syncMusicPlayer();
            // 切换歌曲后重建音频谱
            needsAudioDisplayRebuild = true;
            // 重置人声状态
            voicesMuted = false;
            updateVoiceButton();
        }
    }
    
    private function nextAction():Void
    {
        if (freeplayState != null)
        {
            freeplayState.nextSong();
            syncMusicPlayer();
            // 切换歌曲后重建音频谱
            needsAudioDisplayRebuild = true;
            // 重置人声状态
            voicesMuted = false;
            updateVoiceButton();
        }
    }
    
    private function voiceToggleAction():Void
    {
        voicesMuted = !voicesMuted;
        updateVoiceVolume();
        updateVoiceButton();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    private function updateVoiceVolume():Void
    {
        var volume:Float = voicesMuted ? 0 : 0.8;
        
        // 只改变音量，不暂停/恢复
        if (FreeplayState.vocals != null)
        {
            FreeplayState.vocals.volume = volume;
        }
        
        if (FreeplayState.opponentVocals != null)
        {
            FreeplayState.opponentVocals.volume = volume;
        }
    }
    
    private function updateVoiceButton():Void
    {
        if (voiceToggleButton != null)
        {
            voiceToggleButton.label.text = voicesMuted ? "🔇" : "🎤";
            voiceToggleButton.color = voicesMuted ? 0xFFFF6666 : 0xFFFFFFFF;
        }
        if (voiceText != null)
        {
            voiceText.text = voicesMuted ? "OFF" : "ON";
            voiceText.color = voicesMuted ? 0xFFFF6666 : 0xFF88FF88;
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
    
    // ===== 显示控制 =====
    
    private function setPlayerControlsVisible(visible:Bool):Void
    {
        if (playPauseButton != null) { playPauseButton.visible = visible; playPauseButton.active = visible; }
        if (stopButton != null) { stopButton.visible = visible; stopButton.active = visible; }
        if (prevButton != null) { prevButton.visible = visible; prevButton.active = visible; }
        if (nextButton != null) { nextButton.visible = visible; nextButton.active = visible; }
        if (volumeDownButton != null) { volumeDownButton.visible = visible; volumeDownButton.active = visible; }
        if (volumeUpButton != null) { volumeUpButton.visible = visible; volumeUpButton.active = visible; }
        if (volumeText != null) volumeText.visible = visible;
        if (voiceToggleButton != null) { voiceToggleButton.visible = visible; voiceToggleButton.active = visible; }
        if (voiceText != null) voiceText.visible = visible;
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
        
        // 销毁可视化
        destroyAudioDisplay();
    }
    
    public function setMusicPlayerMode(songName:String, ?songColor:FlxColor):Void
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
        updateVoiceButton();
        
        // 创建可视化
        createAudioDisplay();
        
        // 设置颜色
        if (songColor != null)
        {
            updateAudioDisplayColor(songColor);
        }
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
    
    private function updatePlayerPositions():Void
    {
        var centerY:Float = background.y + background.height / 2 - 20;
        var btnSize:Int = 32;
        var spacing:Int = 8;
        
        // ★★★ 计算所有按钮的总宽度，居中排列 ★★★
        var totalWidth:Float = 0;
        var buttonsList:Array<FlxButton> = [prevButton, playPauseButton, nextButton, stopButton, voiceToggleButton, volumeDownButton, volumeUpButton];
        var visibleButtons:Array<FlxButton> = [];
        
        for (btn in buttonsList)
        {
            if (btn != null && btn.visible)
            {
                visibleButtons.push(btn);
                totalWidth += btn.width;
            }
        }
        
        // 计算音量文本宽度（作为整体的一部分）
        var hasVolumeText:Bool = volumeText != null && volumeText.visible;
        if (hasVolumeText)
        {
            totalWidth += volumeText.width + spacing;
        }
        
        // 计算人声文本宽度
        var hasVoiceText:Bool = voiceText != null && voiceText.visible;
        if (hasVoiceText)
        {
            totalWidth += voiceText.width + spacing;
        }
        
        // 添加间距
        var buttonCount:Int = visibleButtons.length;
        if (buttonCount > 0)
        {
            totalWidth += (buttonCount - 1) * spacing;
        }
        
        // 起始 X 位置（居中）
        var startX:Float = (FlxG.width - totalWidth) / 2;
        var currentX:Float = startX;
        
        for (btn in visibleButtons)
        {
            btn.x = currentX;
            btn.y = centerY - btn.height/2;
            currentX += btn.width + spacing;
        }
        
        // 放置音量文本
        if (volumeText != null && volumeText.visible)
        {
            volumeText.x = currentX;
            volumeText.y = centerY - volumeText.height/2;
            currentX += volumeText.width + spacing;
        }
        
        // 放置人声文本
        if (voiceText != null && voiceText.visible)
        {
            voiceText.x = currentX;
            voiceText.y = centerY - voiceText.height/2;
        }
    }
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        if (isMusicPlayerMode)
        {
            syncMusicPlayer();
            updateTimer += elapsed;
            if (updateTimer >= 0.05)
            {
                updateTimer = 0;
                if (FlxG.sound.music != null)
                {
                    updatePlayPauseButton(musicPlayer != null ? musicPlayer.playing : FlxG.sound.music.playing);
                }
            }
            
            // ★★★ 检查是否需要重建音频谱（解决暂停/跳过导致的消失问题）★★★
            if (needsAudioDisplayRebuild)
            {
                if (FlxG.sound.music != null && FlxG.sound.music.playing)
                {
                    rebuildAudioDisplay();
                }
                needsAudioDisplayRebuild = false;
            }
            
            // ★★★ 监控音乐状态，如果音乐正在播放但音频谱不存在，则重建 ★★★
            if (FlxG.sound.music != null && FlxG.sound.music.playing && audioDisplay == null)
            {
                createAudioDisplay();
            }
            
            // ★★★ 监控音频谱状态，如果音乐停止但音频谱存在，则销毁 ★★★
            if (FlxG.sound.music != null && !FlxG.sound.music.playing && audioDisplay != null)
            {
                destroyAudioDisplay();
            }
            
            // ★★★ 保持人声状态与UI同步 ★★★
            if (voicesMuted)
            {
                if (FreeplayState.vocals != null && FreeplayState.vocals.volume > 0)
                    updateVoiceVolume();
                if (FreeplayState.opponentVocals != null && FreeplayState.opponentVocals.volume > 0)
                    updateVoiceVolume();
            }
        }
    }
    
    // ===== 按钮回调函数 =====
    
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
            // 延迟重建音频谱
            needsAudioDisplayRebuild = true;
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
        
        var buttonY:Float = background.y + (background.height - 40) / 2;
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
    
    public function updateAudioDisplayColor(color:FlxColor):Void
    {
        if (audioDisplay != null && audioDisplay.members != null)
        {
            for (member in audioDisplay.members)
            {
                if (member != null)
                {
                    member.color = color;
                }
            }
        }
    }

    override public function destroy():Void
    {
        FlxTween.cancelTweensOf(this);
        
        // 销毁可视化
        destroyAudioDisplay();
        
        background = FlxDestroyUtil.destroy(background);
        textDisplay = FlxDestroyUtil.destroy(textDisplay);
        
        for (btn in buttons)
            FlxDestroyUtil.destroy(btn);
        buttons = null;
        
        playPauseButton = FlxDestroyUtil.destroy(playPauseButton);
        stopButton = FlxDestroyUtil.destroy(stopButton);
        prevButton = FlxDestroyUtil.destroy(prevButton);
        nextButton = FlxDestroyUtil.destroy(nextButton);
        volumeDownButton = FlxDestroyUtil.destroy(volumeDownButton);
        volumeUpButton = FlxDestroyUtil.destroy(volumeUpButton);
        volumeText = FlxDestroyUtil.destroy(volumeText);
        voiceToggleButton = FlxDestroyUtil.destroy(voiceToggleButton);
        voiceText = FlxDestroyUtil.destroy(voiceText);
        
        freeplayState = null;
        parentState = null;
        
        super.destroy();
    }
}