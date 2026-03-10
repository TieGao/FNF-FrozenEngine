package objects;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.ui.FlxBar;
import flixel.util.FlxStringUtil;
import flixel.util.FlxColor;
import flixel.math.FlxMath;

import states.FreeplayState;

/**
 * New Music player used for Freeplay with slide animation and dual mode support
 */
@:access(states.FreeplayState)
class NewMusicPlayer extends FlxGroup 
{
    public var instance:FreeplayState;
    
    public var playing(get, never):Bool;

    public var playingMusic:Bool = false;
    public var curTime:Float;

    var songBG:FlxSprite;
    var songTxt:FlxText;      // Now Playing: xxx (基准元素)
    var timeTxt:FlxText;      // 时间显示
    var progressBar:FlxBar;   // 进度条
    var modeBG:FlxSprite;     // 模式背景
    var modeTxt:FlxText;      // 模式文本
    var modeIcon:FlxSprite;   // 模式图标
    var playbackBG:FlxSprite; // 播放控制背景
    var playbackTxt:FlxText;  // 播放速度
    
    // 动画相关
    var isSliding:Bool = false;
    var targetY:Float = 60; // 距离屏幕上方60像素
    var startY:Float = -300;
    var slideDuration:Float = 0.5;

    var wasPlaying:Bool;

    var holdPitchTime:Float = 0;
    var playbackRate(default, set):Float = 1;
    
    // 播放模式
    public var playMode:Int = 1; // 默认使用 Inst+Vocals 模式
    
    // 音频引用
    var vocals:FlxSound;
    var opponentVocals:FlxSound;
    
    // 基准坐标
    var baseX:Float = 0;
    var baseY:Float = 0;

    public function new(instance:FreeplayState)
    {
        super();

        this.instance = instance;

        // 计算居中位置
        baseX = FlxG.width * 0.5 - 300; // 500像素宽度，居中
        baseY = startY + 15; // Now Playing 的Y坐标

        // 主背景 - 500像素宽度
        songBG = new FlxSprite(baseX - 10, startY).makeGraphic(600, 160, 0xFF000000);
        songBG.alpha = 0.3;
        add(songBG);

        // Now Playing 文本 - 基准元素 (字号20)
        songTxt = new FlxText(baseX, baseY, 500, "", 20);
        songTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        add(songTxt);

        // 播放模式背景
        modeBG = new FlxSprite(baseX + 420, baseY - 8).makeGraphic(160, 35, 0xFF000000);
        modeBG.alpha = 0.4;
        add(modeBG);

        // 播放模式文本 - 右侧 (字号16)
        modeTxt = new FlxText(baseX + 425, baseY - 3, 150, "INST+VOX", 16);
        modeTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
        add(modeTxt);
        
        // 播放模式图标
        modeIcon = new FlxSprite(baseX + 570, baseY - 1).makeGraphic(14, 14, FlxColor.CYAN);
        add(modeIcon);

        // 时间显示 - 在Now Playing下面 (字号16)
        timeTxt = new FlxText(baseX +50 , baseY + 30, 480, "0:00 / 0:00", 16);
        timeTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
        add(timeTxt);

        // 进度条背景
        playbackBG = new FlxSprite(baseX, baseY + 60).makeGraphic(580, 50, 0xFF000000);
        playbackBG.alpha = 0.8;
        add(playbackBG);

        // 进度条
        progressBar = new FlxBar(baseX + 10, baseY + 70, LEFT_TO_RIGHT, 560, 10, null, "", 0, Math.POSITIVE_INFINITY);
        progressBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
        add(progressBar);

        // 播放速度文本 - 在进度条下面 (字号16)
        playbackTxt = new FlxText(baseX + 250, baseY + 85, 100, "1.00x", 16);
        playbackTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
        add(playbackTxt);

        // 初始化时隐藏所有元素
        forEach(function(spr) {
            spr.visible = false;
        });
        
        // 初始化音频引用
        vocals = null;
        opponentVocals = null;
    }

    // 设置音频引用
    public function setVocals(vocals:FlxSound, opponentVocals:FlxSound):Void
    {
        this.vocals = vocals;
        this.opponentVocals = opponentVocals;
        updateAudioVolume();
    }

    // 更新音频音量
    function updateAudioVolume():Void
    {
        if (playMode == 0) // Inst 模式
        {
            // 静音人声
            if (vocals != null)
                vocals.volume = 0;
            if (opponentVocals != null)
                opponentVocals.volume = 0;
        }
        else // Inst+Vocals 模式
        {
            // 恢复人声音量
            if (vocals != null)
                vocals.volume = 0.7;
            if (opponentVocals != null)
                opponentVocals.volume = 0.7;
        }
    }

    // 根据基准元素更新所有元素位置
    function updateAllPositions():Void
    {
        // 更新背景位置
        songBG.x = baseX - 10;
        songBG.y = baseY - 15;
        
        // 更新模式背景和文本位置
        modeBG.x = baseX + 420;
        modeBG.y = baseY - 8;
        
        modeTxt.x = baseX + 425;
        modeTxt.y = baseY - 3;
        
        modeIcon.x = baseX + 570;
        modeIcon.y = baseY - 1;
        
        // 更新时间显示位置
        timeTxt.x = baseX + 50;
        timeTxt.y = baseY + 30;
        
        // 更新进度条背景位置
        playbackBG.x = baseX;
        playbackBG.y = baseY + 60;
        
        // 更新进度条位置
        progressBar.x = baseX + 10;
        progressBar.y = baseY + 70;
        
        // 更新播放速度文本位置
        playbackTxt.x = baseX + 250;
        playbackTxt.y = baseY + 85;
    }

    public function slideIn():Void
    {
        if (isSliding) return;
        
        isSliding = true;
        visible = true;
        
        // 计算目标基准位置
        var targetBaseY:Float = targetY + 15; // Now Playing的目标Y坐标
        
        // 要动画的元素列表
        var elements:Array<FlxSprite> = [
            songBG, songTxt, modeBG, modeTxt, modeIcon, 
            timeTxt, playbackBG, progressBar, playbackTxt
        ];
        
        // 为每个元素创建滑动动画
        var completedCount:Int = 0;
        var totalElements:Int = elements.length;
        
        for (element in elements)
        {
            FlxTween.cancelTweensOf(element);
            
            // 计算相对于基准的偏移
            var offsetY:Float = 0;
            if (element == songTxt) offsetY = 0;
            else if (element == songBG) offsetY = -15;
            else if (element == modeBG || element == modeTxt || element == modeIcon) offsetY = 0;
            else if (element == timeTxt) offsetY = 30;
            else if (element == playbackBG) offsetY = 60;
            else if (element == progressBar) offsetY = 70;
            else if (element == playbackTxt) offsetY = 85;
            
            // 先设置到开始位置并显示
            element.y = startY + offsetY;
            element.visible = true;
            element.alpha = 0;
            
            FlxTween.tween(element, {
                y: targetBaseY + offsetY,
                alpha: getElementAlpha(element)
            }, slideDuration, {
                ease: FlxEase.backOut,
                onComplete: function(twn:FlxTween) {
                    completedCount++;
                    if (completedCount >= totalElements)
                    {
                        isSliding = false;
                        // 更新基准坐标
                        baseY = targetBaseY;
                        updateAllPositions();
                    }
                }
            });
        }
    }

    function getElementAlpha(element:FlxSprite):Float
    {
        if (element == songBG) return 0.85;
        if (element == modeBG || element == playbackBG) return 0.6;
        return 1.0;
    }

    public function slideOut(onComplete:Void->Void = null):Void
    {
        if (isSliding) return;
        
        isSliding = true;
        
        var elements:Array<FlxSprite> = [
            songBG, songTxt, modeBG, modeTxt, modeIcon, 
            timeTxt, playbackBG, progressBar, playbackTxt
        ];
        
        var completedCount:Int = 0;
        var totalElements:Int = elements.length;
        
        for (element in elements)
        {
            FlxTween.cancelTweensOf(element);
            
            // 计算相对于基准的偏移
            var offsetY:Float = 0;
            if (element == songTxt) offsetY = 0;
            else if (element == songBG) offsetY = -15;
            else if (element == modeBG || element == modeTxt || element == modeIcon) offsetY = 0;
            else if (element == timeTxt) offsetY = 30;
            else if (element == playbackBG) offsetY = 60;
            else if (element == progressBar) offsetY = 70;
            else if (element == playbackTxt) offsetY = 85;
            
            FlxTween.tween(element, {
                y: startY + offsetY,
                alpha: 0
            }, slideDuration, {
                ease: FlxEase.backIn,
                onComplete: function(twn:FlxTween) {
                    completedCount++;
                    if (completedCount >= totalElements)
                    {
                        isSliding = false;
                        visible = false;
                        if (onComplete != null) onComplete();
                    }
                }
            });
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (!playingMusic || isSliding)
        {
            return;
        }

        // 获取当前选中的歌曲
        var curSelected = getCurSelected();
        if (curSelected >= 0 && curSelected < instance.songs.length)
        {
            var songName:String = instance.songs[curSelected].songName;
            songTxt.text = 'Now Playing: $songName';
        }

        // SHIFT 切换播放模式
        if (FlxG.keys.justPressed.SHIFT)
        {
            switchPlayMode();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        // SPACE 重置播放
        if (FlxG.keys.justPressed.SPACE)
        {
            resetPlayback();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        // 上下键控制播放速度
        if (FlxG.keys.justPressed.UP)
        {
            holdPitchTime = 0;
            playbackRate += 0.05;
            setPlaybackRate();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }
        else if (FlxG.keys.justPressed.DOWN)
        {
            holdPitchTime = 0;
            playbackRate -= 0.05;
            setPlaybackRate();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        // 长按持续调整速度
        if (FlxG.keys.pressed.UP || FlxG.keys.pressed.DOWN)
        {
            holdPitchTime += elapsed;
            if (holdPitchTime > 0.6)
            {
                playbackRate += 0.05 * elapsed * (FlxG.keys.pressed.UP ? 1 : -1);
                setPlaybackRate();
            }
        }

        // 左右控制播放进度
        if (FlxG.keys.justPressed.LEFT)
        {
            if (playing)
                wasPlaying = true;

            pauseOrResume();

            curTime = FlxG.sound.music.time - 5000;
            instance.holdTime = 0;

            if (curTime < 0)
                curTime = 0;

            FlxG.sound.music.time = curTime;
            syncVocals();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }
        
        if (FlxG.keys.justPressed.RIGHT)
        {
            if (playing)
                wasPlaying = true;

            pauseOrResume();

            curTime = FlxG.sound.music.time + 5000;
            instance.holdTime = 0;

            if (curTime > FlxG.sound.music.length)
                curTime = FlxG.sound.music.length;

            FlxG.sound.music.time = curTime;
            syncVocals();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        // 长按快速前进/后退
        if(FlxG.keys.pressed.LEFT || FlxG.keys.pressed.RIGHT)
        {
            instance.holdTime += elapsed;
            if(instance.holdTime > 0.5)
            {
                var direction = FlxG.keys.pressed.LEFT ? -1 : 1;
                curTime += 20000 * elapsed * direction;
                
                if(curTime > FlxG.sound.music.length) 
                    curTime = FlxG.sound.music.length;
                else if(curTime < 0) 
                    curTime = 0;

                FlxG.sound.music.time = curTime;
                syncVocals();
            }
        }

        if(FlxG.keys.justReleased.LEFT || FlxG.keys.justReleased.RIGHT)
        {
            if (wasPlaying)
            {
                pauseOrResume(true);
                wasPlaying = false;
            }
        }

        // R 重置播放速率
        if (FlxG.keys.justPressed.R)
        {
            playbackRate = 1;
            setPlaybackRate();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        // 更新播放器显示
        updateTimeTxt();
        updatePlaybackTxt();
    }

    // 同步人声
    function syncVocals():Void
    {
        if (vocals != null)
            vocals.time = FlxG.sound.music.time;
        if (opponentVocals != null)
            opponentVocals.time = FlxG.sound.music.time;
    }

    // 切换播放模式
    function switchPlayMode():Void
    {
        playMode = (playMode + 1) % 2;
        updateModeDisplay();
        updateAudioVolume();
    }

    // 重置播放
    function resetPlayback():Void
    {
        // 重置到开头
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.time = 0;
            syncVocals();
        }
        
        // 确保音乐在播放
        if (!playing)
        {
            pauseOrResume(true);
        }
        
        // 重置播放速率
        playbackRate = 1;
        setPlaybackRate();
    }

    function updateModeDisplay():Void
    {
        switch(playMode)
        {
            case 0:
                modeTxt.text = "INST";
                modeIcon.makeGraphic(14, 14, FlxColor.WHITE);
            case 1:
                modeTxt.text = "INST+VOX";
                modeIcon.makeGraphic(14, 14, FlxColor.CYAN);
        }
    }

    public function pauseOrResume(resume:Bool = false):Void
    {
        if (FlxG.sound.music == null) return;
        
        if (resume)
        {
            if (!FlxG.sound.music.playing)
                FlxG.sound.music.resume();
            
            if (vocals != null && !vocals.playing)
                vocals.resume();
            if (opponentVocals != null && !opponentVocals.playing)
                opponentVocals.resume();
        }
        else 
        {
            FlxG.sound.music.pause();
            
            if (vocals != null)
                vocals.pause();
            if (opponentVocals != null)
                opponentVocals.pause();
        }
    }

    // 停止音乐播放
    public function stopMusic():Void
    {
        if (!playingMusic) return;
        
        playingMusic = false;
        
        // 停止音乐
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.stop();
            FlxG.sound.music.onComplete = null;
        }
        
        if (vocals != null)
            vocals.stop();
        if (opponentVocals != null)
            opponentVocals.stop();
        
        // 滑出动画
        slideOut(function() {
            // 恢复菜单音乐
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
            
            // 更新界面状态
            switchPlayMusic();
            
            // 清理音频引用
            vocals = null;
            opponentVocals = null;
        });
    }

    public function switchPlayMusic():Void
    {
        FlxG.autoPause = (!playingMusic && ClientPrefs.data.autoPause);
        active = playingMusic;
        
        if (playingMusic)
        {
            // 显示并滑入
            slideIn();
            
            // 隐藏分数显示
            if (instance.scoreBG != null) instance.scoreBG.visible = false;
            if (instance.diffText != null) instance.diffText.visible = false;
            if (instance.scoreText != null) instance.scoreText.visible = false;
            
            // 初始化显示
            updateModeDisplay();
            updateTimeTxt();
            updateAudioVolume();
            
            if (FlxG.sound.music != null)
            {
                progressBar.setRange(0, FlxG.sound.music.length);
                progressBar.setParent(FlxG.sound.music, "time");
                progressBar.numDivisions = 1600;
            }
        }
        else
        {
            // 恢复分数显示
            if (instance.scoreBG != null) instance.scoreBG.visible = true;
            if (instance.diffText != null) instance.diffText.visible = true;
            if (instance.scoreText != null) instance.scoreText.visible = true;
            
            progressBar.setRange(0, Math.POSITIVE_INFINITY);
            progressBar.setParent(null, "");
            progressBar.numDivisions = 0;
        }
        progressBar.updateBar();
    }

    function updatePlaybackTxt():Void
    {
        var rateText = Std.string(FlxMath.roundDecimal(playbackRate, 2));
        if (rateText.indexOf(".") == -1)
            rateText += ".00";
        else if (rateText.split(".")[1].length == 1)
            rateText += "0";
            
        playbackTxt.text = rateText + "x";
    }

    function updateTimeTxt():Void
    {
        if (FlxG.sound.music != null)
        {
            var currentTime = FlxStringUtil.formatTime(FlxG.sound.music.time / 1000, false);
            var totalTime = FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, false);
            timeTxt.text = '$currentTime / $totalTime';
        }
    }

    function setPlaybackRate():Void
    {
        // 限制播放速率范围
        playbackRate = FlxMath.roundDecimal(playbackRate, 2);
        if (playbackRate > 3) playbackRate = 3;
        else if (playbackRate <= 0.25) playbackRate = 0.25;
        
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.pitch = playbackRate;
        }
        
        if (vocals != null)
            vocals.pitch = playbackRate;
        if (opponentVocals != null)
            opponentVocals.pitch = playbackRate;
            
        updatePlaybackTxt();
    }

    function get_playing():Bool
    {
        return FlxG.sound.music != null && FlxG.sound.music.playing;
    }

    // 获取当前选中的索引
    function getCurSelected():Int
    {
        var clazz = Type.getClass(instance);
        var field = Reflect.field(clazz, "curSelected");
        if (field != null)
            return field;
        return 0;
    }

    // 播放速率 setter
    function set_playbackRate(value:Float):Float
    {
        var value = FlxMath.roundDecimal(value, 2);
        if (value > 3) value = 3;
        else if (value <= 0.25) value = 0.25;
        return playbackRate = value;
    }
}