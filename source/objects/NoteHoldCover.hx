package objects;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import backend.Paths;
import backend.ClientPrefs;
import backend.animation.PsychAnimationController;

import states.PlayState;

import shaders.RGBPalette;

using StringTools;

typedef HoldCoverConfig = {
    var imagePath:String;
    var holdAnim:String;
    var holdOffset:Array<Float>;
    var endAnim:String;
    var endOffset:Array<Float>;
    var scale:Array<Float>;
    @:optional var fps:Null<Int>;
    @:optional var alphaVal:Null<Float>;
}

class NoteHoldCover extends FlxTypedSpriteGroup<FlxSprite>
{
    // 静态默认配置
    static var defaultImagePath:String = "holdCover/holdCover";
    static var defaultHoldAnim:String = "holdCoverLoop";
    static var defaultHoldOffset:FlxPoint = new FlxPoint(5, 10);
    static var defaultEndAnim:String = "holdCoverEnd";
    static var defaultEndOffset:FlxPoint = new FlxPoint(42, 35);
    static var defaultScaleVal:FlxPoint = new FlxPoint(0.9, 0.9);
    static var defaultFps:Int = 24;
    static var defaultAlphaVal:Float = 1.0;
    
    // 实例配置
    var coverImagePath:String;
    var coverHoldAnim:String;
    var coverHoldOffset:FlxPoint;
    var coverEndAnim:String;
    var coverEndOffset:FlxPoint;
    var coverScale:FlxPoint;
    var coverFps:Int;
    var coverAlpha:Float;
    
    // 精灵和着色器
    var playerSprites:Array<FlxSprite> = [];
    var opponentSprites:Array<FlxSprite> = [];
    var playerShaders:Array<RGBPalette> = [];
    var opponentShaders:Array<RGBPalette> = [];
    
    // 计时器 - 使用FlxTimer而不是Map
    var playerTimers:Map<Int, FlxTimer> = [];
    var opponentTimers:Map<Int, FlxTimer> = [];
    
    // 设置
    public var oppSplashEnabled:Bool = true;

    public function new()
    {
        super(0, 0);
        
        // 初始化配置
        initializeConfig();
        
        // 加载皮肤
        loadSkin();
        
        // 创建精灵
        setupSprites();
    }
    
    /**
     * 初始化配置为默认值
     */
    function initializeConfig():Void
    {
        coverImagePath = defaultImagePath;
        coverHoldAnim = defaultHoldAnim;
        coverHoldOffset = new FlxPoint(defaultHoldOffset.x, defaultHoldOffset.y);
        coverEndAnim = defaultEndAnim;
        coverEndOffset = new FlxPoint(defaultEndOffset.x, defaultEndOffset.y);
        coverScale = new FlxPoint(defaultScaleVal.x, defaultScaleVal.y);
        coverFps = defaultFps;
        coverAlpha = defaultAlphaVal;
    }
    
    /**
     * 加载皮肤配置
     */
    function loadSkin():Void
    {
        var isPixelStage:Bool = PlayState.isPixelStage;
        var skinPostfix:String = "";
        
        // 获取皮肤后缀
        if (ClientPrefs.data.holdCoverSkin != null && ClientPrefs.data.holdCoverSkin != "")
        {
            skinPostfix = '-' + ClientPrefs.data.holdCoverSkin.trim().toLowerCase().replace(' ', '-');
        }
        
        // 检查文件是否存在
        var jsonPath:String;
        if (isPixelStage)
        {
            jsonPath = 'images/pixelUI/holdCover/holdCover${skinPostfix}.json';
            if (!Paths.fileExists(jsonPath, TEXT))
            {
                // 尝试默认像素皮肤
                jsonPath = 'images/pixelUI/holdCover/holdCover.json';
            }
        }
        else
        {
            jsonPath = 'images/holdCover/holdCover${skinPostfix}.json';
            if (!Paths.fileExists(jsonPath, TEXT))
            {
                // 尝试默认皮肤
                jsonPath = 'images/holdCover/holdCover.json';
            }
        }
        
        // 加载JSON配置
        if (Paths.fileExists(jsonPath, TEXT))
        {
            try
            {
                var jsonData:String = Paths.getTextFromFile(jsonPath);
                var parsed:Dynamic = haxe.Json.parse(jsonData);
                
                coverImagePath = parsed.imagePath;
                coverHoldAnim = parsed.holdAnim;
                
                if (parsed.holdOffset != null && parsed.holdOffset.length >= 2)
                {
                    coverHoldOffset.set(parsed.holdOffset[0], parsed.holdOffset[1]);
                }
                
                coverEndAnim = parsed.endAnim;
                
                if (parsed.endOffset != null && parsed.endOffset.length >= 2)
                {
                    coverEndOffset.set(parsed.endOffset[0], parsed.endOffset[1]);
                }
                
                if (parsed.scale != null && parsed.scale.length >= 2)
                {
                    coverScale.set(parsed.scale[0], parsed.scale[1]);
                }
                
                if (parsed.fps != null) coverFps = parsed.fps;
                if (parsed.alphaVal != null) coverAlpha = parsed.alphaVal;
                else if (parsed.alpha != null) coverAlpha = parsed.alpha; // 向后兼容
                
                // 如果是像素舞台，确保路径正确
                if (isPixelStage && !coverImagePath.startsWith("pixelUI/"))
                {
                    coverImagePath = "pixelUI/" + coverImagePath;
                }
            }
            catch (e:Dynamic)
            {
                trace('Error loading holdCover config: $e');
            }
        }
        else if (isPixelStage)
        {
            // 像素舞台默认值
            coverImagePath = "pixelUI/holdCover/holdCover";
            coverHoldAnim = "pixel hold";
            coverHoldOffset.set(-40, -20);
            coverEndAnim = "Splash";
            coverEndOffset.set(60, 97);
            coverScale.set(6, 6);
        }
    }
    
    /**
     * 创建精灵
     */
    function setupSprites():Void
    {
        // 为4个方向创建精灵
        for (i in 0...4)
        {
            // 玩家精灵
            var playerSprite = createSprite(i, true);
            playerSprites.push(playerSprite);
            add(playerSprite);
            
            // 对手精灵
            var opponentSprite = createSprite(i, false);
            opponentSprites.push(opponentSprite);
            add(opponentSprite);
            
            // 着色器
            var playerShader = new RGBPalette();
            var opponentShader = new RGBPalette();
            
            playerShaders.push(playerShader);
            opponentShaders.push(opponentShader);
            
            playerSprite.shader = playerShader.shader;
            opponentSprite.shader = opponentShader.shader;
            
            // 设置颜色
            setDefaultColors(i);
            
            // 初始播放End动画并隐藏（像Lua一样）
            playAnimWithOffset(playerSprite, 'End', false);
            playAnimWithOffset(opponentSprite, 'End', false);
            playerSprite.visible = false;
            opponentSprite.visible = false;
        }
        
        // 设置抗锯齿
        if (PlayState.isPixelStage)
        {
            for (sprite in playerSprites)
            {
                sprite.antialiasing = false;
            }
            for (sprite in opponentSprites)
            {
                sprite.antialiasing = false;
            }
        }
    }
    
    /**
     * 创建单个精灵
     */
    function createSprite(index:Int, isPlayer:Bool):FlxSprite
    {
        var sprite = new FlxSprite();
        sprite.animation = new PsychAnimationController(sprite);
        
        try
        {
            var frames = Paths.getSparrowAtlas(coverImagePath);
            if (frames != null)
            {
                sprite.frames = frames;
                
                // 添加动画 - 使用正确的帧率
                sprite.animation.addByPrefix('Loop', coverHoldAnim, coverFps, true);  // 循环
                sprite.animation.addByPrefix('End', coverEndAnim, coverFps, false);   // 不循环
                
                // 设置缩放
                sprite.scale.set(coverScale.x, coverScale.y);
                sprite.updateHitbox();
                
                // 动画完成回调 - 像Lua一样
                sprite.animation.finishCallback = function(name:String) {
                    if (name == 'End')
                    {
                        // End动画完成后隐藏
                        sprite.visible = false;
                    }
                    // Loop动画会一直循环，不会触发完成回调
                };
            }
            else
            {
                trace('Failed to load holdCover frames: $coverImagePath');
                // 创建占位符
                sprite.makeGraphic(100, 100, isPlayer ? 0xFFFF0000 : 0xFF0000FF);
            }
        }
        catch (e:Dynamic)
        {
            trace('Failed to create holdCover sprite: $e');
            // 创建占位符
            sprite.makeGraphic(100, 100, isPlayer ? 0xFF00FF00 : 0xFFFFFF00);
        }
        
        return sprite;
    }
    
    /**
     * 设置默认颜色
     */
    function setDefaultColors(noteData:Int):Void
    {
        var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[noteData];
        if (PlayState.isPixelStage)
            arr = ClientPrefs.data.arrowRGBPixel[noteData];
        
        if (arr != null && arr.length >= 3)
        {
            playerShaders[noteData].r = arr[0];
            playerShaders[noteData].g = arr[1];
            playerShaders[noteData].b = arr[2];
            
            opponentShaders[noteData].r = arr[0];
            opponentShaders[noteData].g = arr[1];
            opponentShaders[noteData].b = arr[2];
        }
    }
    
    /**
     * 播放动画并设置偏移
     */
    function playAnimWithOffset(sprite:FlxSprite, animName:String, force:Bool = false):Void
    {
        if (sprite.animation.getByName(animName) != null)
        {
            sprite.animation.play(animName, force);
            
            // 设置偏移 - 像Lua版本一样
            if (animName == 'Loop')
            {
                sprite.offset.set(coverHoldOffset.x, coverHoldOffset.y);
            }
            else if (animName == 'End')
            {
                sprite.offset.set(coverEndOffset.x, coverEndOffset.y);
            }
        }
    }
    
    /**
 * 从音符更新颜色 - 完全按照音符的颜色
 */
function updateColorsFromNote(noteData:Int, note:Note, isPlayer:Bool):Void
{
    var shader = isPlayer ? playerShaders[noteData] : opponentShaders[noteData];
    
    // 总是使用音符的颜色（包括特殊音符类型的白色）
    if (note.rgbShader != null)
    {
        // 直接使用音符的 rgbShader 颜色
        shader.r = note.rgbShader.r;
        shader.g = note.rgbShader.g;
        shader.b = note.rgbShader.b;
    }
    else
    {
        // 如果音符没有 rgbShader，使用默认颜色
        setDefaultColors(noteData);
    }
}
    
    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        // 更新位置
        updatePositions();
    }
    
    /**
     * 更新位置
     */
    function updatePositions():Void
    {
        var playState = PlayState.instance;
        if (playState == null) return;
        
        for (i in 0...playerSprites.length)
        {
            // 玩家位置
            if (playState.playerStrums.members[i] != null)
            {
                var strum = playState.playerStrums.members[i];
                var sprite = playerSprites[i];
                
                // 像Lua一样计算位置
                sprite.x = strum.x + (strum.width / 2) - (sprite.width / 2);
                sprite.y = strum.y + (strum.height / 2) - (sprite.height / 2);
                sprite.alpha = strum.alpha * coverAlpha;
                
                // 同步可见性
                if (!strum.visible) sprite.visible = false;
            }
            
            // 对手位置
            if (playState.opponentStrums.members[i] != null)
            {
                var strum = playState.opponentStrums.members[i];
                var sprite = opponentSprites[i];
                
                sprite.x = strum.x + (strum.width / 2) - (sprite.width / 2);
                sprite.y = strum.y + (strum.height / 2) - (sprite.height / 2);
                sprite.alpha = strum.alpha * coverAlpha;
                
                // 同步可见性
                if (!strum.visible) sprite.visible = false;
            }
        }
    }
    
    /**
     * 玩家音符命中 - 像Lua版本一样
     */
    public function onPlayerNoteHit(noteData:Int, isSustain:Bool, note:Note):Void
    {
        if (noteData < 0 || noteData >= playerSprites.length) return;
        
        var sprite = playerSprites[noteData];
        updateColorsFromNote(noteData, note, true);
        
        if (isSustain)
        {
            // 检查是否是长按音符的结束部分
            var isEnd:Bool = false;
            if (note.animation != null && note.animation.curAnim != null)
            {
                var animName:String = note.animation.curAnim.name;
                if (animName != null && animName.endsWith("end"))
                    isEnd = true;
            }
            
            if (!isEnd)
            {
                // 开始长按 - 像Lua一样
                sprite.visible = true;
                playAnimWithOffset(sprite, 'Loop', false); // false = 不强制重置，保持自然
                
                // 取消现有计时器
                if (playerTimers.exists(noteData))
                {
                    playerTimers.get(noteData).cancel();
                    playerTimers.remove(noteData);
                }
                
                // 设置1秒后隐藏
                var timer = new FlxTimer();
                timer.start(1.0, function(tmr:FlxTimer) {
                    sprite.visible = false;
                    playerTimers.remove(noteData);
                });
                playerTimers.set(noteData, timer);
            }
            else
            {
                // 长按结束 - 播放End动画
                playAnimWithOffset(sprite, 'End', true);
                
                // 取消计时器
                if (playerTimers.exists(noteData))
                {
                    playerTimers.get(noteData).cancel();
                    playerTimers.remove(noteData);
                }
            }
        }
    }
    
    /**
     * 对手音符命中 - 像Lua版本一样
     */
    public function onOpponentNoteHit(noteData:Int, isSustain:Bool, note:Note):Void
    {
        if (noteData < 0 || noteData >= opponentSprites.length) return;
        
        var sprite = opponentSprites[noteData];
        updateColorsFromNote(noteData, note, false);
        
        if (isSustain)
        {
            // 检查是否是长按音符的结束部分
            var isEnd:Bool = false;
            if (note.animation != null && note.animation.curAnim != null)
            {
                var animName:String = note.animation.curAnim.name;
                if (animName != null && animName.endsWith("end"))
                    isEnd = true;
            }
            
            if (!isEnd)
            {
                // 开始长按
                sprite.visible = true;
                playAnimWithOffset(sprite, 'Loop', false);
                
                // 取消现有计时器
                if (opponentTimers.exists(noteData))
                {
                    opponentTimers.get(noteData).cancel();
                    opponentTimers.remove(noteData);
                }
                
                // 设置1秒后隐藏
                var timer = new FlxTimer();
                timer.start(1.0, function(tmr:FlxTimer) {
                    sprite.visible = false;
                    opponentTimers.remove(noteData);
                });
                opponentTimers.set(noteData, timer);
            }
            else
            {
                // 长按结束
                if (oppSplashEnabled)
                {
                    playAnimWithOffset(sprite, 'End', true);
                }
                else
                {
                    sprite.visible = false;
                }
                
                // 取消计时器
                if (opponentTimers.exists(noteData))
                {
                    opponentTimers.get(noteData).cancel();
                    opponentTimers.remove(noteData);
                }
            }
        }
    }
    
    /**
     * 清除所有
     */
    public function clearAll():Void
    {
        // 取消所有计时器
        for (timer in playerTimers)
        {
            timer.cancel();
        }
        for (timer in opponentTimers)
        {
            timer.cancel();
        }
        
        playerTimers.clear();
        opponentTimers.clear();
        
        // 隐藏所有精灵
        for (sprite in playerSprites)
        {
            sprite.visible = false;
        }
        for (sprite in opponentSprites)
        {
            sprite.visible = false;
        }
    }
    
    /**
     * 触发长按
     */
    public function triggerHold(noteData:Int, isPlayer:Bool = true):Void
    {
        if (noteData < 0 || noteData >= playerSprites.length) return;
        
        var sprite = isPlayer ? playerSprites[noteData] : opponentSprites[noteData];
        sprite.visible = true;
        playAnimWithOffset(sprite, 'Loop', false);
        
        // 取消现有计时器
        if (isPlayer && playerTimers.exists(noteData))
        {
            playerTimers.get(noteData).cancel();
        }
        else if (!isPlayer && opponentTimers.exists(noteData))
        {
            opponentTimers.get(noteData).cancel();
        }
        
        // 设置新计时器
        var timer = new FlxTimer();
        timer.start(1.0, function(tmr:FlxTimer) {
            sprite.visible = false;
            if (isPlayer)
                playerTimers.remove(noteData);
            else
                opponentTimers.remove(noteData);
        });
        
        if (isPlayer)
            playerTimers.set(noteData, timer);
        else
            opponentTimers.set(noteData, timer);
    }
    
    /**
     * 结束长按
     */
    public function endHold(noteData:Int, isPlayer:Bool = true):Void
    {
        if (noteData < 0 || noteData >= playerSprites.length) return;
        
        var sprite = isPlayer ? playerSprites[noteData] : opponentSprites[noteData];
        playAnimWithOffset(sprite, 'End', true);
        
        // 取消计时器
        if (isPlayer && playerTimers.exists(noteData))
        {
            playerTimers.get(noteData).cancel();
            playerTimers.remove(noteData);
        }
        else if (!isPlayer && opponentTimers.exists(noteData))
        {
            opponentTimers.get(noteData).cancel();
            opponentTimers.remove(noteData);
        }
    }
    
    /**
     * 设置对手splash是否启用
     */
    public function setOppSplashEnabled(enabled:Bool):Void
    {
        oppSplashEnabled = enabled;
    }
    
    override public function destroy():Void
    {
        // 清理计时器
        clearAll();
        
        super.destroy();
    }
}