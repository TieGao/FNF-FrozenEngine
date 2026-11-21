package states.freeplay;

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
import backend.UITheme;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import states.FreeplayState;
import options.keoptions.KEOptionsMenu;
import options.psychoptions.PsychOptionsState;
import options.OptionsState;
import options.keoptions.KEExtraSettingsSubState;
import objects.AudioDisplay;


class ToolBar extends FlxSpriteGroup
{
    /** 正常模式（导航按钮）的栏高 */
    public static inline var BAR_HEIGHT_NORMAL:Int = 50;
    /** 音乐播放器模式的栏高 */
    public static inline var BAR_HEIGHT_PLAYER:Int = 64;
    /** 播放器控件的边长 */
    public static inline var PLAYER_BTN_SIZE:Int = 44;
    /** 播放/暂停按钮的边长 */
    public static inline var PLAYER_BTN_SIZE_MAIN:Int = 56;

    public var background:FlxFilteredSprite;
    public var textDisplay:FlxText;
    public var musicPlayer:MusicPlayerLegacy;
    
    // 按钮相关（自造的斜切按钮，见 ToolBarButton —— 不再依赖 PsychUIButton）
    public var buttons:Array<ToolBarButton> = [];
    public var buttonWidth:Int = 200;
    public var buttonHeight:Int = 32;
    /** 斜度：和 StoryMode 的 BTN_SKEW/BTN_H（28/70）同量级的角度，平行四边形才看得出来 */
    public var buttonSkew:Int = 12;
    /** 整排按钮离屏幕左右边的最小留白，块数多时按这个反推单块最大宽度 */
    static inline var BUTTON_STRIP_MARGIN:Float = 40;
    /**
     * 实际烘进贴图的按钮宽度。宽度是画进图里的（SlantQuad 缓存键也带它），
     * 只能在造按钮之前定死，所以 createButtons 里算一次，layoutButtons 直接用。
     */
    private var layoutWidth:Float = 200;

    /** 需要"当前有选中歌"才有意义的几块（RESET / LISTEN / EDITOR）：没歌时置灰禁用 */
    private var songButtons:Array<ToolBarButton> = [];

    /**
     * 触发后锁输入的剩余时长。
     * 防误触：按钮一触发就上锁，同一次松手不会被第二块再消费一次，连点也不会重复触发。
     */
    public var inputLock:Float = 0;
    static inline var INPUT_LOCK_TIME:Float = 0.18;
    
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
    public var voicesMuted:Bool = false;

    // ★★★ 循环模式（单曲 / 列表 / 随机 / 只放一次）★★★
    public var loopModeButton:FlxButton;
    public var loopModeText:FlxText;
    /** 循环按钮当前画的是哪种图标（变了才重画） */
    private var loopIconKind:String = '';
    /** 循环模式文字标签的固定宽度（居中显示，宽度写死摆位才不跳） */
    static inline var LOOP_TEXT_WIDTH:Int = 120;
    
    /** 当前栏高：正常模式 50，音乐播放器模式 64 */
    public var barHeight:Int = BAR_HEIGHT_NORMAL;
    
    /** 播放/暂停按钮当前画的是哪种图标（变了才重画） */
    private var playIconKind:String = '';
    /** 人声按钮当前画的是哪种图标（变了才重画） */
    private var voiceIconKind:String = '';
    /** 已套用的强调色版本号，和 UITheme.version 不一致时重画图集 */
    private var accentVersion:Int = -1;
    
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
    private var hasExtraButton:Bool = false;

    public var blurAmount:Float = 40;   // 模糊强度

    public function new(state:FreeplayState, width:Int, height:Int)
    {
        super();
        
        freeplayState = state;
        parentState = state;
        barHeight = height;
        syncMusicPlayer();
        
        // 从配置读取可视化参数
        loadVizSettings();
        
        // 一次按最大栏高造图，切模式只改 y —— 重造贴图会生成新的 BitmapData，
        // 被 Paths.clearStoredMemory() 清掉后整条栏会变白
        background = new FlxFilteredSprite(-100, FlxG.height - height);
        background.makeGraphic(width, BAR_HEIGHT_PLAYER + 50, 0xFF000000);
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
        
        // 默认显示按钮模式。force 必须带上：此刻 isMusicPlayerMode 和栏高都已是"常态"，
        // 不带的话 setNormalMode 会判定成"没变化"直接返回，播放器控件就留在屏幕上
        setNormalMode(true);
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
            FlxG.height - barHeight,   // Y 位置（贴在工具栏上沿）
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
        for (button in buttons)
        {
            if (button == null) continue;
            remove(button, true);
            button.destroy();
        }
        buttons = [];
        songButtons = [];

        // action 返回"这次点击有没有真的做事"：false 就走取消音，点了没反应也能听见。
        // needsSong = true 的那几块在没有歌时会置灰禁用，连"点了没反应"都不会发生。
        var buttonData:Array<{label:String, needsSong:Bool, action:Void->Bool}> = [
            {label: Language.getPhrase("options", "OPTIONS"), needsSong: false, action: openOptions},
            {label: Language.getPhrase("gameplay", "GAMEPLAY"), needsSong: false, action: openGameplayChangers},
            {label: Language.getPhrase("reset", "RESET"), needsSong: true, action: resetScore},
            {label: Language.getPhrase("random", "RANDOM"), needsSong: true, action: randomSong},
            {label: Language.getPhrase("listen", "LISTEN"), needsSong: true, action: toggleListenMode},
            {label: Language.getPhrase("editor", "EDITOR"), needsSong: true, action: openChartEditor}
        ];
        hasExtraButton = Paths.isCustomChartCategory();
        if (hasExtraButton)
            buttonData.insert(1, {label: "EXTRA", needsSong: false, action: openExtraSettings});

        // 斜切块整条宽 = n*W - (n-1)*skew。内容包分类会多一块 EXTRA（7 块），
        // 按原宽 200 算出来 1328 > 1280 会顶出屏幕两侧，所以块数多时把宽度压到刚好放下。
        var count:Int = buttonData.length;
        var avail:Float = FlxG.width - BUTTON_STRIP_MARGIN * 2;
        var maxW:Float = (avail + (count - 1) * buttonSkew) / count;
        layoutWidth = Math.min(buttonWidth, Math.floor(maxW));

        for (i in 0...buttonData.length)
        {
            var data = buttonData[i];
            // 先按 (0,0) 造，位置统一由 layoutButtons() 摆 —— 位置只会有一处算，
            // 不会出现"创建时算一次、setXY 再算一次"两套公式打架
            var btn = new ToolBarButton(0, 0, layoutWidth, buttonHeight, buttonSkew, data.label, 20,
                makeButtonAction(data.action));
            add(btn);
            buttons.push(btn);
            if (data.needsSong) songButtons.push(btn);
        }

        layoutButtons();
    }

    /**
     * 把这一排斜切块摆成一条：相邻两块的水平步长 = 宽 - skew，两条斜边正好重合。
     * 整条宽度 = n*W - (n-1)*skew，比"n*W + 间距"窄，6 块也不会顶到屏幕边。
     */
    private function layoutButtons():Void
    {
        var count:Int = buttons.length;
        if (count < 1) return;

        var step:Float = layoutWidth - buttonSkew;
        var stripW:Float = layoutWidth + (count - 1) * step;
        var left:Float = (FlxG.width - stripW) * 0.5;
        // 只按"可见栏高"垂直居中：不要用 background.height，那是按最大栏高造的，多 50px 模糊出血
        var top:Float = FlxG.height - barHeight * 0.5 - buttonHeight * 0.5;

        for (i in 0...count)
        {
            var btn = buttons[i];
            if (btn == null) continue;
            btn.x = left + i * step;
            btn.y = top;
        }
    }

    /** 把按钮动作包一层：上锁 + 成功/失败音 */
    private function makeButtonAction(action:Void->Bool):Void->Void
    {
        return function()
        {
            // 一触发就上锁：同一次松手不会再喂给别的块，连点也不会把同一块点两下。
            // 触发块自己在 fireClick 里已经把 pressing 解掉了，这里不用再清别的块。
            inputLock = INPUT_LOCK_TIME;

            var ok:Bool = (action != null) && action();
            FlxG.sound.play(Paths.sound(ok ? 'confirmMenu' : 'cancelMenu'), ok ? 0.5 : 0.35);
        };
    }

    /** 常态栏的悬停 / 按下裁决。多个斜切块共用接缝：命中取"最后一个命中的"，接缝那 2px 归右块。 */
    private function updateNormalButtons():Void
    {
        if (buttons.length < 1) return;

        // 没有歌的时候 RESET / LISTEN / EDITOR 点了也不可能做事：直接置灰不接输入，
        // 比"点了没反应"清楚得多。OPTIONS / GAMEPLAY 跟选歌无关，永远可用。
        var hasSong:Bool = freeplayState != null && freeplayState.songs != null && freeplayState.songs.length > 0;
        for (btn in songButtons)
            if (btn != null) btn.enabled = hasSong;

        var hoverIdx:Int = -1;
        for (i in 0...buttons.length)
        {
            var btn = buttons[i];
            if (btn != null && btn.visible && btn.enabled && btn.containsPoint(FlxG.mouse.x, FlxG.mouse.y))
                hoverIdx = i;
        }

        var canInput:Bool = (inputLock <= 0);
        for (i in 0...buttons.length)
        {
            var btn = buttons[i];
            if (btn != null && btn.visible) btn.updateButton(i == hoverIdx, canInput);
        }
    }

    public function refreshChartModeButtons():Void
    {
        var shouldShowExtra:Bool = Paths.isCustomChartCategory();
        if (shouldShowExtra != hasExtraButton)
            createButtons();
    }
    
    // ===== 创建播放器控件 =====
    
    private function createPlayerControls():Void
    {
        prevButton = makePlayerButton('prev', PLAYER_BTN_SIZE, prevAction);
        playPauseButton = makePlayerButton('play', PLAYER_BTN_SIZE_MAIN, playPauseAction);
        nextButton = makePlayerButton('next', PLAYER_BTN_SIZE, nextAction);
        stopButton = makePlayerButton('stop', PLAYER_BTN_SIZE, stopAction);
        loopModeButton = makePlayerButton(loopIconFor(MusicPlayerLegacy.loopMode), PLAYER_BTN_SIZE, cycleLoopMode);
        voiceToggleButton = makePlayerButton('mic', PLAYER_BTN_SIZE, voiceToggleAction);
        volumeDownButton = makePlayerButton('volume_down', PLAYER_BTN_SIZE, volumeDownAction);
        volumeUpButton = makePlayerButton('volume_up', PLAYER_BTN_SIZE, volumeUpAction);
        playIconKind = 'play';
        voiceIconKind = 'mic';
        // 循环图标不在这里记 kind：交给下面的 updateLoopModeButton 第一次画，
        // 否则「进来时模式已经是列表循环」的情况下描边色会停在默认灰
        
        // 音量文本（夹在两个音量键中间）
        volumeText = new FlxText(0, 0, 60, "100%", 18);
        volumeText.antialiasing = ClientPrefs.data.antialiasing;
        volumeText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        volumeText.scrollFactor.set();
        add(volumeText);

        // 循环模式文字（贴在循环按钮右边，图标看不懂时靠它）
        loopModeText = new FlxText(0, 0, LOOP_TEXT_WIDTH, "", 18);
        loopModeText.antialiasing = ClientPrefs.data.antialiasing;
        loopModeText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        loopModeText.scrollFactor.set();
        add(loopModeText);
        updateLoopModeButton();
        
        // 默认隐藏播放器控件
        setPlayerControlsVisible(false);
    }
    
    /**
     * 造一个播放器图标按钮。
     *
     * 图标用 ToolBarIcons 现画的 3 帧图集（normal / hover / press）——
     * FlxButton 会按 status 自动切帧，所以悬停 / 按下天然有视觉反馈；
     * 单帧图会被 FlxTypedButton 把 highlight / pressed 的帧号夹回第 0 帧，等于没有反馈。
     */
    private function makePlayerButton(kind:String, size:Int, action:Void->Void):FlxButton
    {
        var btn:FlxButton = new FlxButton(0, 0, null, action);
        btn.loadGraphic(ToolBarIcons.buttonStrip(kind, size), true, size, size);
        btn.antialiasing = ClientPrefs.data.antialiasing;
        btn.scrollFactor.set();
        add(btn);
        return btn;
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
        if (voiceToggleButton == null) return;
        
        var kind:String = voicesMuted ? 'mic_off' : 'mic';
        if (voiceIconKind == kind && !isGraphicDead(voiceToggleButton)) return;
        voiceIconKind = kind;
        
        var tint:Int = voicesMuted ? ToolBarIcons.ICON_MUTED : ToolBarIcons.ICON_NORMAL;
        voiceToggleButton.loadGraphic(ToolBarIcons.buttonStrip(kind, PLAYER_BTN_SIZE, tint), true, PLAYER_BTN_SIZE, PLAYER_BTN_SIZE);
        voiceToggleButton.antialiasing = ClientPrefs.data.antialiasing;
    }

    // ===== 循环模式 =====

    /** 循环切换：只放一次 → 列表循环 → 单曲循环 → 随机 → 只放一次 */
    private function cycleLoopMode():Void
    {
        MusicPlayerLegacy.loopMode = (MusicPlayerLegacy.loopMode + 1) % MusicPlayerLegacy.LOOP_MODE_COUNT;
        updateLoopModeButton();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    /** 图标 + 文字一起刷。图标没变就别重画贴图（自造图会被 clearStoredMemory 连带 dispose，掉了靠 isGraphicDead 判活） */
    private function updateLoopModeButton():Void
    {
        if (loopModeButton == null) return;

        var mode:Int = MusicPlayerLegacy.loopMode;
        var kind:String = loopIconFor(mode);
        if (loopIconKind != kind || isGraphicDead(loopModeButton))
        {
            loopIconKind = kind;
            // 只放一次用灰的，开着循环 / 随机用黄色 —— 不用点开也知道现在是不是在循环
            var tint:Int = (mode == MusicPlayerLegacy.LOOP_ONCE) ? ToolBarIcons.ICON_NORMAL : ToolBarIcons.iconActive();
            loopModeButton.loadGraphic(ToolBarIcons.buttonStrip(kind, PLAYER_BTN_SIZE, tint), true, PLAYER_BTN_SIZE, PLAYER_BTN_SIZE);
            loopModeButton.antialiasing = ClientPrefs.data.antialiasing;
        }

        if (loopModeText != null)
            loopModeText.text = loopModeLabel(mode);
    }

    private inline function loopIconFor(mode:Int):String
    {
        switch (mode)
        {
            case MusicPlayerLegacy.LOOP_ALL: return 'repeat';
            case MusicPlayerLegacy.LOOP_ONE: return 'repeat_one';
            case MusicPlayerLegacy.LOOP_SHUFFLE: return 'shuffle';
            default: return 'play_once';
        }
    }

    private inline function loopModeLabel(mode:Int):String
    {
        switch (mode)
        {
            case MusicPlayerLegacy.LOOP_ALL: return Language.getPhrase('musicplayer_mode_all', 'LOOP ALL');
            case MusicPlayerLegacy.LOOP_ONE: return Language.getPhrase('musicplayer_mode_one', 'LOOP ONE');
            case MusicPlayerLegacy.LOOP_SHUFFLE: return Language.getPhrase('musicplayer_mode_shuffle', 'SHUFFLE');
            default: return Language.getPhrase('musicplayer_mode_once', 'ONCE');
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
    
    // ===== 栏高 =====
    
    /**
     * 切换工具栏高度。只改 background 的 y，不重造贴图
     * （重造会生成新的 BitmapData，被 clearStoredMemory 清掉后整条栏变白）。
     */
    private function applyBarHeight(h:Int):Void
    {
        if (barHeight == h) return;
        barHeight = h;
        
        if (background != null)
        {
            FlxTween.cancelTweensOf(background);
            FlxTween.tween(background, {y: FlxG.height - h}, 0.15, {ease: FlxEase.quadOut});
        }
        if (audioDisplay != null)
            audioDisplay.y = FlxG.height - h;
    }
    
    /** 自造的图标图是否已被销毁（不要用 pixels != null 判活，那个 getter 就是 graphic.bitmap） */
    private inline function isGraphicDead(spr:FlxSprite):Bool
    {
        return spr == null || spr.graphic == null || spr.graphic.isDestroyed;
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
        if (loopModeButton != null) { loopModeButton.visible = visible; loopModeButton.active = visible; }
        if (loopModeText != null) loopModeText.visible = visible;
    }
    
    public function setNormalMode(force:Bool = false):Void
    {
        // FreeplayState 在不放歌时每帧都会调一次；状态没变就别重摆 / 重清（每次重摆都要
        // 跟着 transformChildren 走一遍成员，白烧）
        var changed:Bool = force || isMusicPlayerMode || barHeight != BAR_HEIGHT_NORMAL;

        isMusicPlayerMode = false;
        applyBarHeight(BAR_HEIGHT_NORMAL);
        if (textDisplay != null) textDisplay.visible = false;

        if (!changed) return;

        layoutButtons();

        for (btn in buttons)
        {
            if (btn != null)
            {
                btn.cancelInput();
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
        applyBarHeight(BAR_HEIGHT_PLAYER);
        if (textDisplay != null) textDisplay.visible = false;
        
        for (btn in buttons)
        {
            if (btn != null)
            {
                btn.cancelInput();
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
        updateLoopModeButton();
        
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
        if (playPauseButton == null) return;
        
        var kind:String = isPlaying ? 'pause' : 'play';
        if (playIconKind == kind && !isGraphicDead(playPauseButton)) return;
        playIconKind = kind;
        
        playPauseButton.loadGraphic(ToolBarIcons.buttonStrip(kind, PLAYER_BTN_SIZE_MAIN), true, PLAYER_BTN_SIZE_MAIN, PLAYER_BTN_SIZE_MAIN);
        playPauseButton.antialiasing = ClientPrefs.data.antialiasing;
    }
    
    /**
     * 强调色变了：重画播放器按钮的图集，并刷新斜切按钮的交互态。
     * 图集是现画的 BitmapData，颜色烘在像素里，只能整块重建。
     */
    private function refreshAccentColors():Void
    {
        if (playPauseButton != null)
        {
            var kind:String = (playIconKind.length > 0) ? playIconKind : 'play';
            reloadButtonGraphic(playPauseButton, ToolBarIcons.buttonStrip(kind, PLAYER_BTN_SIZE_MAIN), PLAYER_BTN_SIZE_MAIN);
        }

        if (voiceToggleButton != null)
        {
            var kind:String = voicesMuted ? 'mic_off' : 'mic';
            var tint:Int = voicesMuted ? ToolBarIcons.ICON_MUTED : ToolBarIcons.ICON_NORMAL;
            reloadButtonGraphic(voiceToggleButton, ToolBarIcons.buttonStrip(kind, PLAYER_BTN_SIZE, tint), PLAYER_BTN_SIZE);
        }

        if (loopModeButton != null)
        {
            var kind:String = (loopIconKind.length > 0) ? loopIconKind : 'play_once';
            var tint:Int = (MusicPlayerLegacy.loopMode == MusicPlayerLegacy.LOOP_ONCE)
                ? ToolBarIcons.ICON_NORMAL : ToolBarIcons.iconActive();
            reloadButtonGraphic(loopModeButton, ToolBarIcons.buttonStrip(kind, PLAYER_BTN_SIZE, tint), PLAYER_BTN_SIZE);
        }

        for (b in buttons)
            if (b != null) b.refreshVisual();
    }

    /** 换图集：先摘掉旧 frames 再销毁 graphic，避免 FlxG.bitmap 缓存里堆积废图 */
    private function reloadButtonGraphic(btn:FlxButton, bmd:openfl.display.BitmapData, size:Int):Void
    {
        btn.frames = null;
        if (btn.graphic != null) btn.graphic.destroy();
        btn.loadGraphic(bmd, true, size, size);
        btn.antialiasing = ClientPrefs.data.antialiasing;
    }

    private function updatePlayerPositions():Void
    {
        var centerY:Float = FlxG.height - barHeight / 2;
        var spacing:Int = 10;
        
        // 一行里从左到右的控件：音量百分比夹在两个音量键中间
        var row:Array<FlxSprite> = [prevButton, playPauseButton, nextButton, stopButton,
            loopModeButton, loopModeText, voiceToggleButton, volumeDownButton, volumeText, volumeUpButton];
        
        var visibleItems:Array<FlxSprite> = [];
        var totalWidth:Float = 0;
        for (item in row)
        {
            if (item != null && item.visible)
            {
                visibleItems.push(item);
                totalWidth += item.width;
            }
        }
        if (visibleItems.length > 1)
            totalWidth += (visibleItems.length - 1) * spacing;
        
        var currentX:Float = (FlxG.width - totalWidth) / 2;
        for (item in visibleItems)
        {
            item.x = currentX;
            item.y = centerY - item.height / 2;
            currentX += item.width + spacing;
        }
    }
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        // 设置页改完强调色回到 Freeplay 时，按钮图集还烘着旧色，靠版本号补刷
        if (accentVersion != UITheme.version)
        {
            accentVersion = UITheme.version;
            refreshAccentColors();
        }

        if (inputLock > 0) inputLock -= elapsed;

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
            
            // 自造的图标图会被 Paths.clearStoredMemory() 连带 dispose，掉了就重画
            if (FlxG.sound.music != null && isGraphicDead(playPauseButton))
            {
                playIconKind = '';
                updatePlayPauseButton(musicPlayer != null ? musicPlayer.playing : FlxG.sound.music.playing);
            }
            if (isGraphicDead(voiceToggleButton))
            {
                voiceIconKind = '';
                updateVoiceButton();
            }
            if (isGraphicDead(loopModeButton))
            {
                loopIconKind = '';
                updateLoopModeButton();
            }
            
            // ★★★ 保持人声状态与UI同步 ★★★
            if (voicesMuted)
            {
                if (FreeplayState.vocals != null && FreeplayState.vocals.volume > 0)
                    updateVoiceVolume();
                if (FreeplayState.opponentVocals != null && FreeplayState.opponentVocals.volume > 0)
                    updateVoiceVolume();
            }
            return;
        }

        // 常态栏：导航按钮的悬停 / 按下全在这里裁决（按钮自己不碰鼠标状态）
        updateNormalButtons();
    }
    
    // ===== 按钮回调函数 =====
    // 统一返回 Bool："这次点击有没有真的做事" —— false 由 makeButtonAction 换成取消音，
    // 点了没反应也能听见，不会像以前那样按钮响一声、后台什么都不发生。

    private function openOptions():Bool
    {
        if (freeplayState == null) return false;

        if (ClientPrefs.data.optionstype == 'new')
        {
            MusicBeatState.switchState(new OptionsState());
            OptionsState.stateType = 1;
        }
        else if (ClientPrefs.data.optionstype == 'ke')
            MusicBeatState.switchState(new KEOptionsMenu());
        else
            MusicBeatState.switchState(new PsychOptionsState());

        return true;
    }
    
    private function openGameplayChangers():Bool
    {
        if (freeplayState == null || !freeplayState.persistentUpdate) return false;

        freeplayState.persistentUpdate = false;
        freeplayState.openSubState(new GameplayChangersSubstate());
        return true;
    }

    private function openExtraSettings():Bool
    {
        if (freeplayState == null || !freeplayState.persistentUpdate) return false;

        freeplayState.persistentUpdate = false;
        freeplayState.openSubState(new KEExtraSettingsSubState());
        return true;
    }
    
    private function resetScore():Bool
    {
        if (freeplayState == null || FreeplayState.curSelected < 0
            || FreeplayState.curSelected >= freeplayState.songs.length) return false;

        freeplayState.persistentUpdate = false;
        var song = freeplayState.songs[FreeplayState.curSelected];
        freeplayState.openSubState(new ResetScoreSubState(song.songName, freeplayState.curDifficulty, song.songCharacter, -1, song.folder));
        return true;
    }
    
    private function toggleListenMode():Bool
    {
        if (freeplayState == null) return false;

        freeplayState.togglePlaySong();
        // 延迟重建音频谱
        needsAudioDisplayRebuild = true;
        return true;
    }

    /** 随机选曲：只在普通模式下换选中项（试听中按钮本来就是隐藏的） */
    private function randomSong():Bool
    {
        if (freeplayState == null) return false;
        return freeplayState.randomSelectSong();
    }

    /**
     * 直接用当前选中的歌曲打开谱面编辑器。
     * ChartingState 读的是 PlayState.SONG，加载由 FreeplayState.openChartEditor() 负责。
     */
    private function openChartEditor():Bool
    {
        if (freeplayState == null) return false;
        if (FreeplayState.curSelected < 0 || FreeplayState.curSelected >= freeplayState.songs.length) return false;

        freeplayState.openChartEditor();
        return true;
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
        
        // 摆位公式只有 layoutButtons() 一份，这里不要另算一套
        layoutButtons();
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
        FlxTween.cancelTweensOf(background);
        
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
        loopModeButton = FlxDestroyUtil.destroy(loopModeButton);
        loopModeText = FlxDestroyUtil.destroy(loopModeText);
        
        freeplayState = null;
        parentState = null;
        
        super.destroy();
    }
}