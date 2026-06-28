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
    public var background:FlxSprite;
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
    public var timeText:FlxText;
    public var progressBar:FlxSprite;
    public var progressFill:FlxSprite;
    public var volumeDownButton:FlxButton;
    public var volumeUpButton:FlxButton;
    public var volumeText:FlxText;
    
    // ========== 音频可视化控制 ==========
    public var vizToggleButton:FlxButton;
    public var vizPanel:FlxSpriteGroup;
    
    // 可视化控制组件
    public var barCountLabel:FlxText;
    public var barCountValue:FlxText;
    public var barCountDown:FlxButton;
    public var barCountUp:FlxButton;
    
    public var qualityLabel:FlxText;
    public var qualityValue:FlxText;
    public var qualityDown:FlxButton;
    public var qualityUp:FlxButton;
    
    public var updateRateLabel:FlxText;
    public var updateRateValue:FlxText;
    public var updateRateDown:FlxButton;
    public var updateRateUp:FlxButton;
    
    public var vizResetButton:FlxButton;
    
    // 可视化参数范围
    private static inline var MIN_BAR_COUNT:Int = 4;
    private static inline var MAX_BAR_COUNT:Int = 64;
    private static inline var DEFAULT_BAR_COUNT:Int = 16;
    
    private static inline var MIN_QUALITY:Int = 1;
    private static inline var MAX_QUALITY:Int = 8;
    private static inline var DEFAULT_QUALITY:Int = 4;
    
    private static inline var MIN_UPDATE_RATE:Float = 10;
    private static inline var MAX_UPDATE_RATE:Float = 100;
    private static inline var DEFAULT_UPDATE_RATE:Float = 33;
    
    // 当前可视化参数
    public var vizBarCount:Int = DEFAULT_BAR_COUNT;
    public var vizQuality:Int = DEFAULT_QUALITY;
    public var vizUpdateRate:Float = DEFAULT_UPDATE_RATE;
    public var vizPanelVisible:Bool = false;
    
    // ★★★ 可视化重建回调（内部使用）★★★
    public var onVizRebuild:(barCount:Int, quality:Int, updateRate:Float) -> Void = null;
    
    // 状态
    public var isMusicPlayerMode:Bool = false;
    public var currentSongName:String = "";
    
    // 引用
    private var freeplayState:FreeplayState;
    private var parentState:MusicBeatState;          // 用于添加/移除子对象
    
    // 播放器更新定时器
    private var updateTimer:Float = 0;
    
    // 面板高度
    private static inline var VIZ_PANEL_HEIGHT:Int = 180;
    
    // ★★★ 新增：音频可视化显示对象 ★★★
    public var audioDisplay:AudioDisplay;

    public function new(state:FreeplayState, width:Int, height:Int)
    {
        super();
        
        freeplayState = state;
        parentState = state;                    // 保存父状态用于添加/移除
        syncMusicPlayer();
        
        // 从配置读取可视化参数
        loadVizSettings();
        
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

        if (audioDisplay != null) {
    audioDisplay.gain = ClientPrefs.data.audioGain; // 从配置读取
    }
        
        // 创建按钮
        createButtons();
        
        // 创建播放器控件
        createPlayerControls();
        
        // 创建可视化控制面板
        createVizPanel();
        
        // ★★★ 设置内部回调：参数变化时重建可视化 ★★★
        onVizRebuild = function(barCount:Int, quality:Int, updateRate:Float) {
            rebuildAudioDisplay();
        };
        
        // 默认显示按钮模式
        setNormalMode();
    }
    
    // ========== 可视化控制面板 ==========
    
    private function createVizPanel():Void
    {
        var panelY:Float = background.y - VIZ_PANEL_HEIGHT;
        var panelWidth:Int = Std.int(background.width);
        
        vizPanel = new FlxSpriteGroup(0, panelY);
        vizPanel.scrollFactor.set();
        vizPanel.visible = false;
        
        // 面板背景
        var panelBg = new FlxSprite(0, 0).makeGraphic(panelWidth, VIZ_PANEL_HEIGHT, 0xCC000000);
        panelBg.alpha = 0.85;
        vizPanel.add(panelBg);
        
        // 标题
        var title = new FlxText(10, 6, panelWidth - 20, "🎵 音频可视化控制", 16);
        title.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
        vizPanel.add(title);
        
        // 分隔线
        var divider = new FlxSprite(10, 28).makeGraphic(panelWidth - 20, 1, 0xFF444444);
        vizPanel.add(divider);
        
        var currentY:Float = 36;
        var rowHeight:Float = 38;
        var labelWidth:Int = 80;
        var controlWidth:Int = 80;
        var btnSize:Int = 26;
        var halfPanel:Int = Std.int(panelWidth / 2);
        
        // ===== 左列：条形数量 =====
        barCountLabel = new FlxText(10, currentY + 4, labelWidth, "Bar Count", 13);
        barCountLabel.setFormat(Paths.font("vcr.ttf"), 13, 0xFFCCCCCC, LEFT);
        vizPanel.add(barCountLabel);
        
        barCountDown = new FlxButton(halfPanel - controlWidth - btnSize - 4, currentY, "-", decreaseBarCount);
        barCountDown.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        barCountDown.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        vizPanel.add(barCountDown);
        
        barCountValue = new FlxText(halfPanel - controlWidth, currentY + 2, controlWidth, Std.string(vizBarCount), 15);
        barCountValue.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, CENTER);
        vizPanel.add(barCountValue);
        
        barCountUp = new FlxButton(halfPanel - btnSize, currentY, "+", increaseBarCount);
        barCountUp.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        barCountUp.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        vizPanel.add(barCountUp);
        
        // ===== 右列：FFT质量 =====
        qualityLabel = new FlxText(halfPanel + 10, currentY + 4, labelWidth, "FFT Quality", 13);
        qualityLabel.setFormat(Paths.font("vcr.ttf"), 13, 0xFFCCCCCC, LEFT);
        vizPanel.add(qualityLabel);
        
        qualityDown = new FlxButton(panelWidth - controlWidth - btnSize - 4 - 10, currentY, "-", decreaseQuality);
        qualityDown.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        qualityDown.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        vizPanel.add(qualityDown);
        
        qualityValue = new FlxText(panelWidth - controlWidth - 10, currentY + 2, controlWidth, Std.string(vizQuality), 15);
        qualityValue.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, CENTER);
        vizPanel.add(qualityValue);
        
        qualityUp = new FlxButton(panelWidth - btnSize - 10, currentY, "+", increaseQuality);
        qualityUp.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        qualityUp.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        vizPanel.add(qualityUp);
        
        currentY += rowHeight;
        
        // ===== 第二行：更新频率 + 重置 =====
        updateRateLabel = new FlxText(10, currentY + 4, labelWidth, "Update Rate (ms)", 13);
        updateRateLabel.setFormat(Paths.font("vcr.ttf"), 13, 0xFFCCCCCC, LEFT);
        vizPanel.add(updateRateLabel);
        
        updateRateDown = new FlxButton(halfPanel - controlWidth - btnSize - 4, currentY, "-", decreaseUpdateRate);
        updateRateDown.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        updateRateDown.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        vizPanel.add(updateRateDown);
        
        updateRateValue = new FlxText(halfPanel - controlWidth, currentY + 2, controlWidth, Std.string(Std.int(vizUpdateRate)), 15);
        updateRateValue.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, CENTER);
        vizPanel.add(updateRateValue);
        
        updateRateUp = new FlxButton(halfPanel - btnSize, currentY, "+", increaseUpdateRate);
        updateRateUp.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        updateRateUp.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        vizPanel.add(updateRateUp);
        
        // 重置按钮（右侧）
        vizResetButton = new FlxButton(panelWidth - 110, currentY + 2, "Reset", resetVizToDefault);
        vizResetButton.loadGraphic(createButtonGraphic(90, 30, 0xFF335533));
        vizResetButton.label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER);
        vizPanel.add(vizResetButton);
        
        // 提示文字
        var tipText = new FlxText(10, VIZ_PANEL_HEIGHT - 20, panelWidth - 20, "Adjust visualization parameters for real-time effect", 11);
        tipText.setFormat(Paths.font("vcr.ttf"), 11, 0xFF666666, CENTER);
        vizPanel.add(tipText);
        
        add(vizPanel);
    }
    
    // ===== 可视化控制函数 =====
    
    private function loadVizSettings():Void
    {
        vizBarCount = ClientPrefs.data.relaxAudioNumber;
        vizQuality = ClientPrefs.data.relaxAudioDisplayQuality;
        vizUpdateRate = ClientPrefs.data.audioDisplayUpdate;
        
        // 确保在有效范围内
        if (vizBarCount < MIN_BAR_COUNT) vizBarCount = MIN_BAR_COUNT;
        if (vizBarCount > MAX_BAR_COUNT) vizBarCount = MAX_BAR_COUNT;
        if (vizQuality < MIN_QUALITY) vizQuality = MIN_QUALITY;
        if (vizQuality > MAX_QUALITY) vizQuality = MAX_QUALITY;
        if (vizUpdateRate < MIN_UPDATE_RATE) vizUpdateRate = MIN_UPDATE_RATE;
        if (vizUpdateRate > MAX_UPDATE_RATE) vizUpdateRate = MAX_UPDATE_RATE;
    }
    
    private function saveVizSettings():Void
    {
        ClientPrefs.data.relaxAudioNumber = vizBarCount;
        ClientPrefs.data.relaxAudioDisplayQuality = vizQuality;
        ClientPrefs.data.audioDisplayUpdate = vizUpdateRate;
    }
    
    private function updateVizDisplay():Void
    {
        if (barCountValue != null) barCountValue.text = Std.string(vizBarCount);
        if (qualityValue != null) qualityValue.text = Std.string(vizQuality);
        if (updateRateValue != null) updateRateValue.text = Std.string(Std.int(vizUpdateRate));
    }
    
    private function applyVizSettings():Void
    {
        saveVizSettings();
        // 调用重建回调（内部设置）
        if (onVizRebuild != null)
        {
            onVizRebuild(vizBarCount, vizQuality, vizUpdateRate);
        }
    }
    
    private function decreaseBarCount():Void
    {
        if (vizBarCount > MIN_BAR_COUNT)
        {
            vizBarCount--;
            updateVizDisplay();
            applyVizSettings();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
        }
    }
    
    private function increaseBarCount():Void
    {
        if (vizBarCount < MAX_BAR_COUNT)
        {
            vizBarCount++;
            updateVizDisplay();
            applyVizSettings();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
        }
    }
    
    private function decreaseQuality():Void
    {
        if (vizQuality > MIN_QUALITY)
        {
            vizQuality--;
            updateVizDisplay();
            applyVizSettings();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
        }
    }
    
    private function increaseQuality():Void
    {
        if (vizQuality < MAX_QUALITY)
        {
            vizQuality++;
            updateVizDisplay();
            applyVizSettings();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
        }
    }
    
    private function decreaseUpdateRate():Void
    {
        if (vizUpdateRate > MIN_UPDATE_RATE)
        {
            vizUpdateRate -= 5;
            if (vizUpdateRate < MIN_UPDATE_RATE) vizUpdateRate = MIN_UPDATE_RATE;
            updateVizDisplay();
            applyVizSettings();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
        }
    }
    
    private function increaseUpdateRate():Void
    {
        if (vizUpdateRate < MAX_UPDATE_RATE)
        {
            vizUpdateRate += 5;
            if (vizUpdateRate > MAX_UPDATE_RATE) vizUpdateRate = MAX_UPDATE_RATE;
            updateVizDisplay();
            applyVizSettings();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
        }
    }
    
    private function resetVizToDefault():Void
    {
        vizBarCount = DEFAULT_BAR_COUNT;
        vizQuality = DEFAULT_QUALITY;
        vizUpdateRate = DEFAULT_UPDATE_RATE;
        updateVizDisplay();
        applyVizSettings();
        FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
    }
    
    private function toggleVizPanel():Void
    {
        vizPanelVisible = !vizPanelVisible;
        
        var targetY:Float = vizPanelVisible ? (background.y - VIZ_PANEL_HEIGHT) : (background.y);
        
        if (vizPanelVisible)
        {
            vizPanel.visible = true;
            vizPanel.y = background.y;
            FlxTween.tween(vizPanel, {y: targetY}, 0.3, {
                ease: FlxEase.quadOut
            });
        }
        else
        {
            FlxTween.tween(vizPanel, {y: background.y}, 0.3, {
                ease: FlxEase.quadIn,
                onComplete: function(_) {
                    vizPanel.visible = false;
                }
            });
        }
        
        if (vizToggleButton != null)
        {
            vizToggleButton.label.text = vizPanelVisible ? "▼" : "🎵";
        }
        
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
    }
    
    // ========== ★★★ 音频可视化管理（新增） ★★★ ==========
    
    /**
     * 重建音频可视化（使用当前参数）
     */
    private function rebuildAudioDisplay():Void
    {
        // 如果未处于音乐播放模式或没有音乐播放，不创建
        if (!isMusicPlayerMode || FlxG.sound.music == null || !FlxG.sound.music.playing)
        {
            destroyAudioDisplay();
            return;
        }
        
        // 如果已存在则先销毁
        destroyAudioDisplay();
        
        // 创建新的 AudioDisplay
        // 参数：snd, X, Y, Width, Height, line(条形数), gap, Color, symmetry
        audioDisplay = new AudioDisplay(
            FlxG.sound.music,
            0,                          // X 位置（可根据需要调整）
            background.y,          // Y 位置（放在工具栏上方，留出空间）
            FlxG.width,            // 宽度
            300,                         // 高度
            vizBarCount,                 // 条形数量
            2,                           // 条形间距
            0xFF88FF88,                  // 颜色（绿色）
            false                        // 是否对称
        );
        audioDisplay.inRelax = true;     // 使用 Relax 参数
        audioDisplay.stopUpdate = false;
        
        // 添加到父状态（确保在正确的层级）
        if (parentState != null)
        {
            parentState.add(audioDisplay);
        }
        else
        {
            var state = FlxG.state;
            if (state != null) state.add(audioDisplay);
        }
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
    
    // ===== 原有函数 =====
    
    // ===== 修改后的 createButtons =====
    private function createButtons():Void
    {
        var buttonY:Float = background.y + (background.height - 40) / 2;
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
                36
            );
            btn.scrollFactor.set();
            btn.text.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
            btn.text.fieldWidth = buttonWidth;
            
            // 可选：调整样式
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
    
    private function createPlayerControls():Void
    {
        var centerY:Float = background.y + background.height / 2;
        var btnSize:Int = 32;
        
        // 可视化切换按钮（放在最左边）
        vizToggleButton = new FlxButton(5, centerY - btnSize/2, "🎵", toggleVizPanel);
        vizToggleButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        vizToggleButton.label.setFormat(null, 14, FlxColor.WHITE, CENTER);
        vizToggleButton.scrollFactor.set();
        vizToggleButton.label.systemFont = "";
        add(vizToggleButton);
        
        // 上一首
        prevButton = new FlxButton(0, centerY - btnSize/2, "◀◀", prevAction);
        prevButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333333));
        prevButton.label.setFormat(null, 14, FlxColor.WHITE, CENTER);
        prevButton.scrollFactor.set();
        prevButton.label.systemFont = "";
        add(prevButton);
        
        // 播放/暂停
        playPauseButton = new FlxButton(0, centerY - btnSize/2, "▶", playPauseAction);
        playPauseButton.loadGraphic(createButtonGraphic(btnSize, btnSize, 0xFF333366));
        playPauseButton.label.setFormat(null, 16, FlxColor.WHITE, CENTER);
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
        if (vizToggleButton != null) vizToggleButton.visible = visible;
        if (vizToggleButton != null) vizToggleButton.active = visible;
        
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
        
        // 隐藏可视化面板
        if (!visible && vizPanel != null)
        {
            vizPanel.visible = false;
            vizPanelVisible = false;
            if (vizToggleButton != null)
                vizToggleButton.label.text = "🎵";
        }
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
        
        // ★★★ 销毁可视化 ★★★
        destroyAudioDisplay();
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
        
        // ★★★ 创建可视化 ★★★
        rebuildAudioDisplay();
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
        var startX:Float = 45;
        
        if (vizToggleButton != null)
        {
            vizToggleButton.x = 5;
            vizToggleButton.y = centerY - vizToggleButton.height/2;
        }
        
        var currentX:Float = startX;
        var spacing:Float = 4;
        
        if (prevButton != null)
        {
            prevButton.x = currentX;
            prevButton.y = centerY - prevButton.height/2;
            currentX += prevButton.width + spacing;
        }
        
        if (playPauseButton != null)
        {
            playPauseButton.x = currentX;
            playPauseButton.y = centerY - playPauseButton.height/2;
            currentX += playPauseButton.width + spacing;
        }
        
        if (nextButton != null)
        {
            nextButton.x = currentX;
            nextButton.y = centerY - nextButton.height/2;
            currentX += nextButton.width + spacing;
        }
        
        if (stopButton != null)
        {
            stopButton.x = currentX;
            stopButton.y = centerY - stopButton.height/2;
            currentX += stopButton.width + spacing;
        }
        
        if (timeText != null)
        {
            timeText.x = currentX;
            timeText.y = centerY - timeText.height/2;
            currentX += timeText.width + spacing;
        }
        
        if (progressBar != null)
        {
            progressBar.x = currentX;
            progressBar.y = centerY + 12;
            currentX += progressBar.width + spacing;
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
            currentX += volumeDownButton.width + spacing;
        }
        
        if (volumeUpButton != null)
        {
            volumeUpButton.x = currentX;
            volumeUpButton.y = centerY - volumeUpButton.height/2;
            currentX += volumeUpButton.width + spacing;
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
            if (updateTimer >= 0.05)
            {
                updateTimer = 0;
                if (FlxG.sound.music != null)
                {
                    updateTimeDisplay(FlxG.sound.music.time, FlxG.sound.music.length);
                    updatePlayPauseButton(musicPlayer != null ? musicPlayer.playing : FlxG.sound.music.playing);
                }
            }
            
            // ★★★ 如果音乐意外停止，销毁可视化 ★★★
            if (FlxG.sound.music != null && !FlxG.sound.music.playing && audioDisplay != null)
            {
                destroyAudioDisplay();
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
        
        var buttonY:Float = background.y + (background.height - 40) / 2;  // 调整高度
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
        FlxTween.cancelTweensOf(this);
        FlxTween.cancelTweensOf(vizPanel);
        
        // ★★★ 销毁可视化 ★★★
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
        timeText = FlxDestroyUtil.destroy(timeText);
        progressBar = FlxDestroyUtil.destroy(progressBar);
        progressFill = FlxDestroyUtil.destroy(progressFill);
        volumeDownButton = FlxDestroyUtil.destroy(volumeDownButton);
        volumeUpButton = FlxDestroyUtil.destroy(volumeUpButton);
        volumeText = FlxDestroyUtil.destroy(volumeText);
        
        vizToggleButton = FlxDestroyUtil.destroy(vizToggleButton);
        vizPanel = FlxDestroyUtil.destroy(vizPanel);
        barCountLabel = FlxDestroyUtil.destroy(barCountLabel);
        barCountValue = FlxDestroyUtil.destroy(barCountValue);
        barCountDown = FlxDestroyUtil.destroy(barCountDown);
        barCountUp = FlxDestroyUtil.destroy(barCountUp);
        qualityLabel = FlxDestroyUtil.destroy(qualityLabel);
        qualityValue = FlxDestroyUtil.destroy(qualityValue);
        qualityDown = FlxDestroyUtil.destroy(qualityDown);
        qualityUp = FlxDestroyUtil.destroy(qualityUp);
        updateRateLabel = FlxDestroyUtil.destroy(updateRateLabel);
        updateRateValue = FlxDestroyUtil.destroy(updateRateValue);
        updateRateDown = FlxDestroyUtil.destroy(updateRateDown);
        updateRateUp = FlxDestroyUtil.destroy(updateRateUp);
        vizResetButton = FlxDestroyUtil.destroy(vizResetButton);
        
        freeplayState = null;
        parentState = null;
        onVizRebuild = null;
        
        super.destroy();
    }
}