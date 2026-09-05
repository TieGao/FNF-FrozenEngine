package objects;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.FlxSprite;
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
    
    // 精灵和着色器 - 使用动态数组支持多K
    var playerSprites:Array<FlxSprite> = [];
    var opponentSprites:Array<FlxSprite> = [];
    var playerShaders:Array<RGBPalette> = [];
    var opponentShaders:Array<RGBPalette> = [];
    
    // 计时器
    var playerTimers:Map<Int, FlxTimer> = [];
    var opponentTimers:Map<Int, FlxTimer> = [];
    
    // 设置
    public var oppSplashEnabled:Bool = true;
    
    // 当前键数
    var currentKeyCount:Int = 4;

    public function new()
    {
        super(0, 0);
        
        // 初始化配置
        initializeConfig();
        
        // 加载皮肤
        loadSkin();
        
        // 根据键数创建精灵
        setupSpritesForKeys();
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
     * 加载皮肤配置
     */
    function loadSkin():Void
    {
        var isPixelStage:Bool = PlayState.isPixelStage;
        var skinName:String = ClientPrefs.data.holdCoverSkin;
        
        // 构建可能的JSON文件路径数组
        var possiblePaths:Array<String> = [];
        
        // 1. 首先尝试assets目录的自定义皮肤
        if (skinName != null && skinName.trim() != "" && skinName != "default")
        {
            var cleanSkinName = skinName.trim();
            var formattedName = cleanSkinName.charAt(0).toUpperCase() + cleanSkinName.substr(1).toLowerCase();
            
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
        
        // 3. mods目录
        if (skinName != null && skinName.trim() != "" && skinName != "default")
        {
            var cleanSkinName = skinName.trim();
            var formattedName = cleanSkinName.charAt(0).toUpperCase() + cleanSkinName.substr(1).toLowerCase();
            possiblePaths.push('mods/holdcovers/holdCover-${formattedName}.json');
        }
        
        possiblePaths.push('mods/holdcovers/holdCover.json');
        
        for (jsonPath in possiblePaths)
        {
            if (Paths.fileExists(jsonPath, TEXT))
            {
                if (loadConfigFromFile(jsonPath))
                {
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
        
        // 默认配置
        if (isPixelStage)
        {
            coverImagePath = "pixelUI/holdCover/holdCover";
            coverHoldAnim = "pixel hold";
            coverHoldOffset.set(-40, -20);
            coverEndAnim = "Splash";
            coverEndOffset.set(60, 97);
            coverScale.set(6, 6);
            coverFps = 24;
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
            
            return true;
        }
        catch (e:Dynamic)
        {
            return false;
        }
    }
    
    /**
     * 根据当前键数设置精灵
     */
    function setupSpritesForKeys():Void
    {
        var keys:Int = Note.getColumnsPerPlayer();
        currentKeyCount = keys;
        
        // 清理旧的精灵
        for (sprite in playerSprites)
        {
            remove(sprite);
            sprite.destroy();
        }
        for (sprite in opponentSprites)
        {
            remove(sprite);
            sprite.destroy();
        }
        playerSprites = [];
        opponentSprites = [];
        playerShaders = [];
        opponentShaders = [];
        playerTimers.clear();
        opponentTimers.clear();
        
        // 根据键数创建精灵
        for (i in 0...keys)
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
        
        // 应用键数缩放
        applyKeyCountScale();
    }
    
    /**
     * 根据键数应用等比例缩放
     */
    function applyKeyCountScale():Void
    {
        var keys:Int = Note.getColumnsPerPlayer();
        var scaleFactor:Float = PlayState.isPixelStage ? 
            Note.getPixelNoteScaleForKeys(keys) : 
            Note.getNoteScaleForKeys(keys);
        
        // 计算缩放比例 (相对于4K)
        var baseScale:Float = PlayState.isPixelStage ? 1.0 : 0.7;
        var ratio:Float = scaleFactor / baseScale;
        
        // 应用缩放到所有精灵
        for (sprite in playerSprites)
        {
            sprite.scale.set(coverScale.x * ratio, coverScale.y * ratio);
            sprite.updateHitbox();
        }
        for (sprite in opponentSprites)
        {
            sprite.scale.set(coverScale.x * ratio, coverScale.y * ratio);
            sprite.updateHitbox();
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
                
                sprite.animation.addByPrefix('Loop', coverHoldAnim, coverFps, true);
                sprite.animation.addByPrefix('End', coverEndAnim, coverFps, false);
                
                var keys:Int = Note.getColumnsPerPlayer();
                var scaleFactor:Float = PlayState.isPixelStage ? 
                    Note.getPixelNoteScaleForKeys(keys) : 
                    Note.getNoteScaleForKeys(keys);
                var baseScale:Float = PlayState.isPixelStage ? 1.0 : 0.7;
                var ratio:Float = scaleFactor / baseScale;
                
                sprite.scale.set(coverScale.x * ratio, coverScale.y * ratio);
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
        var colorSets:Array<Array<FlxColor>> = (!PlayState.isPixelStage) ? 
            ClientPrefs.data.arrowRGB : ClientPrefs.data.arrowRGBPixel;
        var colorIndex:Int = Std.int(Math.abs(noteData) % colorSets.length);
        var arr:Array<FlxColor> = colorSets[colorIndex];
        
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
        var index:Int = noteData % playerShaders.length;
        var shader = isPlayer ? playerShaders[index] : opponentShaders[index];
        
        if (note.rgbShader != null)
        {
            shader.r = note.rgbShader.r;
            shader.g = note.rgbShader.g;
            shader.b = note.rgbShader.b;
        }
        else
        {
            setDefaultColors(index);
        }
    }
    
    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        // 检查键数是否变化
        var keys:Int = Note.getColumnsPerPlayer();
        if (keys != currentKeyCount)
        {
            setupSpritesForKeys();
        }
        
        updatePositions();
    }
    
    function updatePositions():Void
    {
        var playState = PlayState.instance;
        if (playState == null) return;
        
        var keys:Int = Note.getColumnsPerPlayer();
        var spacing:Float = Note.getNoteSpacing(keys);
        
        for (i in 0...playerSprites.length)
        {
            if (i < playState.playerStrums.members.length && playState.playerStrums.members[i] != null)
            {
                var strum = playState.playerStrums.members[i];
                var sprite = playerSprites[i];
                
                sprite.x = strum.x + (strum.width / 2) - (sprite.width / 2);
                sprite.y = strum.y + (strum.height / 2) - (sprite.height / 2);
                sprite.alpha = strum.alpha * coverAlpha;
                
                if (!strum.visible) sprite.visible = false;
            }
            
            if (i < playState.opponentStrums.members.length && playState.opponentStrums.members[i] != null)
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
        var index:Int = noteData % playerSprites.length;
        if (index < 0 || index >= playerSprites.length) return;
        
        var sprite = playerSprites[index];
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
                playAnimWithOffset(sprite, 'Loop', false);
                
                if (playerTimers.exists(index))
                {
                    playerTimers.get(index).cancel();
                    playerTimers.remove(index);
                }
                
                var timer = new FlxTimer();
                timer.start(0.2, function(tmr:FlxTimer) {
                    sprite.visible = false;
                    playerTimers.remove(index);
                });
                playerTimers.set(index, timer);
            }
            else
            {
                var oppMode:Bool = PlayState.instance.opponentMode == 'opponent';
                if (!oppMode)
                {
                    playAnimWithOffset(sprite, 'End', true);
                }
                else
                {
                    sprite.visible = false;
                }
                
                if (playerTimers.exists(index))
                {
                    playerTimers.get(index).cancel();
                    playerTimers.remove(index);
                }
            }
        }
    }
    
    public function onOpponentNoteHit(noteData:Int, isSustain:Bool, note:Note):Void
    {
        var index:Int = noteData % opponentSprites.length;
        if (index < 0 || index >= opponentSprites.length) return;
        
        var sprite = opponentSprites[index];
        updateColorsFromNote(noteData, note, false);
        
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
                playAnimWithOffset(sprite, 'Loop', false);
                
                if (opponentTimers.exists(index))
                {
                    opponentTimers.get(index).cancel();
                    opponentTimers.remove(index);
                }
                
                var timer = new FlxTimer();
                timer.start(0.2, function(tmr:FlxTimer) {
                    sprite.visible = false;
                    opponentTimers.remove(index);
                });
                opponentTimers.set(index, timer);
            }
            else
            {
                if (oppSplashEnabled)
                {
                    var oppMode:Bool = PlayState.instance.opponentMode == 'opponent';
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
                
                if (opponentTimers.exists(index))
                {
                    opponentTimers.get(index).cancel();
                    opponentTimers.remove(index);
                }
            }
        }
    }
    
    public function clearAll():Void
    {
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
        
        for (sprite in playerSprites)
        {
            sprite.visible = false;
        }
        for (sprite in opponentSprites)
        {
            sprite.visible = false;
        }
    }
    
    public function triggerHold(noteData:Int, isPlayer:Bool = true):Void
    {
        var index:Int = noteData % playerSprites.length;
        if (index < 0 || index >= playerSprites.length) return;
        
        var sprite = isPlayer ? playerSprites[index] : opponentSprites[index];
        sprite.visible = true;
        playAnimWithOffset(sprite, 'Loop', false);
        
        if (isPlayer && playerTimers.exists(index))
        {
            playerTimers.get(index).cancel();
        }
        else if (!isPlayer && opponentTimers.exists(index))
        {
            opponentTimers.get(index).cancel();
        }
        
        var timer = new FlxTimer();
        timer.start(1.0, function(tmr:FlxTimer) {
            sprite.visible = false;
            if (isPlayer)
                playerTimers.remove(index);
            else
                opponentTimers.remove(index);
        });
        
        if (isPlayer)
            playerTimers.set(index, timer);
        else
            opponentTimers.set(index, timer);
    }
    
    public function endHold(noteData:Int, isPlayer:Bool = true):Void
    {
        var index:Int = noteData % playerSprites.length;
        if (index < 0 || index >= playerSprites.length) return;
        
        var sprite = isPlayer ? playerSprites[index] : opponentSprites[index];
        playAnimWithOffset(sprite, 'End', true);
        
        if (isPlayer && playerTimers.exists(index))
        {
            playerTimers.get(index).cancel();
            playerTimers.remove(index);
        }
        else if (!isPlayer && opponentTimers.exists(index))
        {
            opponentTimers.get(index).cancel();
            opponentTimers.remove(index);
        }
    }
    
    public function setOppSplashEnabled(enabled:Bool):Void
    {
        oppSplashEnabled = enabled;
    }
    
    /**
     * 重新加载皮肤（当皮肤设置改变时调用）
     */
    public function reloadSkin():Void
    {
        loadSkin();
        setupSpritesForKeys();
    }
    
    override public function destroy():Void
    {
        clearAll();
        super.destroy();
    }
}