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
    static var defaultHoldOffset:FlxPoint = new FlxPoint(-3, 7);
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
    var coverAlpha:Float = ClientPrefs.data.holdcoverAlpha;
    
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
    }
    
   /**
 * 加载皮肤配置 - 精简版：只保留带连字符和大写格式
 */
function loadSkin():Void
{
    var isPixelStage:Bool = PlayState.isPixelStage;
    var skinName:String = ClientPrefs.data.holdCoverSkin;
    
    trace('Loading holdCover skin: "$skinName", pixelStage: $isPixelStage');
    
    // 构建可能的JSON文件路径数组，按优先级排序
    var possiblePaths:Array<String> = [];
    
    // 1. 首先尝试assets目录的自定义皮肤（最高优先级）
    if (skinName != null && skinName.trim() != "" && skinName != "default")
    {
        var cleanSkinName = skinName.trim();
        // 确保首字母大写
        var formattedName = cleanSkinName.charAt(0).toUpperCase() + cleanSkinName.substr(1).toLowerCase();
        
        // assets目录的自定义皮肤 - 只保留带连字符格式
        if (isPixelStage)
        {
            possiblePaths.push('images/pixelUI/holdCover/holdCover-${formattedName}.json');
        }
        else
        {
            possiblePaths.push('images/holdCover/holdCover-${formattedName}.json');
        }
    }
    
    // 2. assets目录的默认配置
    if (isPixelStage)
    {
        possiblePaths.push('images/pixelUI/holdCover/holdCover.json');
    }
    else
    {
        possiblePaths.push('images/holdCover/holdCover.json');
    }
    
    // 3. 最后才检查mods目录（最低优先级）
    if (skinName != null && skinName.trim() != "" && skinName != "default")
    {
        var cleanSkinName = skinName.trim();
        var formattedName = cleanSkinName.charAt(0).toUpperCase() + cleanSkinName.substr(1).toLowerCase();
        possiblePaths.push('mods/holdcovers/holdCover-${formattedName}.json');
    }
    

    possiblePaths.push('mods/holdcovers/holdCover.json');
    
    for (i in 0...possiblePaths.length)
    {

    }
    

    for (jsonPath in possiblePaths)
    {
        if (Paths.fileExists(jsonPath, TEXT))
        {
            if (loadConfigFromFile(jsonPath))
            {
                trace('Loaded holdCover config from: $jsonPath');

                if (isPixelStage && !coverImagePath.startsWith("pixelUI/"))
                {
                    if (!coverImagePath.startsWith("pixelUI/") && !coverImagePath.contains("pixelUI/"))
                    {
                        coverImagePath = "pixelUI/" + coverImagePath;
                    }
                }
                return;
            }
        }
    }
    

    if (isPixelStage)
    {
        coverImagePath = "pixelUI/holdCover/holdCover";
        coverHoldAnim = "pixel hold";
        coverHoldOffset.set(-40, -20);
        coverEndAnim = "Splash";
        coverEndOffset.set(60, 97);
        coverScale.set(6, 6);
        coverFps = 24;
        
        trace('Using default pixel holdCover config');
    }
}
    

    function loadConfigFromFile(jsonPath:String):Bool
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
            
            // 仅保留读取到的文件信息
            //trace('Loaded holdCover config from: $jsonPath');
            return true;
        }
        catch (e:Dynamic)
        {
            return false;
        }
    }
    

    function setupSprites():Void
    {

        for (i in 0...4)
        {

            var playerSprite = createSprite(i, true);
            playerSprites.push(playerSprite);
            add(playerSprite);
            

            var opponentSprite = createSprite(i, false);
            opponentSprites.push(opponentSprite);
            add(opponentSprite);
            
            var playerShader = new RGBPalette();
            var opponentShader = new RGBPalette();
            
            playerShaders.push(playerShader);
            opponentShaders.push(opponentShader);
            
            playerSprite.shader = playerShader.shader;
            opponentSprite.shader = opponentShader.shader;
            
            setDefaultColors(i);
            
            playerSprite.visible = false;
            opponentSprite.visible = false;
        }
        
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
            

            sprite.animation.addByPrefix('Loop', coverHoldAnim, coverFps, true);  // 循环
            sprite.animation.addByPrefix('End', coverEndAnim, coverFps, false);   // 不循环

            sprite.scale.set(coverScale.x, coverScale.y);
            sprite.updateHitbox();
            

            if (PlayState.isPixelStage)
            {
                sprite.antialiasing = false;
            }
            

            sprite.animation.finishCallback = function(name:String) {
                if (name == 'End')
                {
                    sprite.visible = false;
                }
            };
            
            sprite.visible = false;
        }
        else
        {
            trace('Failed to load holdCover frames: $coverImagePath');

        }
    }
    catch (e:Dynamic)
    {
        trace('Failed to create holdCover sprite: $e');

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
    

    function playAnimWithOffset(sprite:FlxSprite, animName:String, force:Bool = false):Void
    {
        if (sprite.animation.getByName(animName) != null)
        {
            sprite.animation.play(animName, force);
            
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

    function updateColorsFromNote(noteData:Int, note:Note, isPlayer:Bool):Void
    {
        var shader = isPlayer ? playerShaders[noteData] : opponentShaders[noteData];

        if (note.rgbShader != null)
        {

            shader.r = note.rgbShader.r;
            shader.g = note.rgbShader.g;
            shader.b = note.rgbShader.b;
        }
        else
        {
            setDefaultColors(noteData);
        }
    }
    
    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        updatePositions();
    }
    
    function updatePositions():Void
    {
        var playState = PlayState.instance;
        if (playState == null) return;
        
        for (i in 0...playerSprites.length)
        {
            if (playState.playerStrums.members[i] != null)
            {
                var strum = playState.playerStrums.members[i];
                var sprite = playerSprites[i];
                
                sprite.x = strum.x + (strum.width / 2) - (sprite.width / 2);
                sprite.y = strum.y + (strum.height / 2) - (sprite.height / 2);
                sprite.alpha = strum.alpha * coverAlpha;
                
                if (!strum.visible) sprite.visible = false;
            }

            if (playState.opponentStrums.members[i] != null)
            {
                var strum = playState.opponentStrums.members[i];
                var sprite = opponentSprites[i];
                
                sprite.x = strum.x + (strum.width / 2) - (sprite.width / 2);
                sprite.y = strum.y + (strum.height / 2) - (sprite.height / 2);
                sprite.alpha = strum.alpha * coverAlpha;
                
                if (!strum.visible) sprite.visible = false;
            }
        }
    }
    
    public function onPlayerNoteHit(noteData:Int, isSustain:Bool, note:Note):Void
    {
        if (noteData < 0 || noteData >= playerSprites.length) return;
        
        var sprite = playerSprites[noteData];
        updateColorsFromNote(noteData, note, true);
        
        if (isSustain)
        {
            var isEnd:Bool = false;
            if (note.animation != null && note.animation.curAnim != null)
            {
                var animName:String = note.animation.curAnim.name;
                if (animName != null && animName.endsWith("end"))
                    isEnd = true;
            }
            
            if (!isEnd)
            {
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
                timer.start(0.2, function(tmr:FlxTimer) {
                    sprite.visible = false;
                    playerTimers.remove(noteData);
                });
                playerTimers.set(noteData, timer);
            }
            else
            {
                var oppMode = PlayState.instance.opponentMode;
                if (!oppMode)
                {
                playAnimWithOffset(sprite, 'End', true);
                }
                else
                {
                sprite.visible = false; 
                }
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
                timer.start(0.2, function(tmr:FlxTimer) {
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
                 var oppMode = PlayState.instance.opponentMode;
                    if (oppMode)
                    {
                    playAnimWithOffset(sprite, 'End', true);
                    }
                    else
                    {
                    sprite.visible = false; 
                    }
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