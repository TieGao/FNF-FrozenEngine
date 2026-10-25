package states.freeplay;

import shaders.ColorSwap;
import openfl.display.BlendMode;

class FreeplayCard extends FlxTypedGroup<FlxSprite>
{
    public var targetY:Float = 0;
    public var songName:String;
    /** 卡片上的标题文本。默认等于 songName，变体歌会带上标签（'Bopeebo (Pico Mix)'）；
     *  songName 仍保持原始歌名 —— 评级 / 存档查找都按它算。 */
    public var displayName:String;
    public var coloring:Int;
    public var folder:String;
    /** 本卡所属内容包变体（Pico…）；base 歌为 null。徽章查成绩必须用它，不能吃全局 Paths.currentContentVariant。 */
    public var variant:String = null;
    /** 这首歌**真实拥有**的难度名（来自谱面信息）；为空时退回全局 Difficulty.list。
     *  混排列表（base + Erect + PicoMix）里全局列表只可能对应其中一种。 */
    public var diffNames:Array<String> = null;
    
    public var bgSprite:FlxSprite;
    public var textSprite:FlxText;
    public var icon:HealthIcon;
    
    public var rhombusBg:FlxSprite;
    public var ratingSprite:FlxSprite;
    
    // ---- 动态评级徽章（官方 rankbadges 图集） ----
    /** 徽章缩放（原 0.7 偏小，1.5x ≈ 1.05；后续自调只改这里） */
    public static inline var BADGE_SCALE:Float = 1.05;
    public var hasBadgeAtlas:Bool = false;
    public var currentRank:FreeplayRank = FreeplayRank.NONE;
    public var hueShader:ColorSwap;   // 仅 RAINBOW 挂载
    public var hueTime:Float = 0;
    /** 评级应用动画期间为 true，updatePosition 跳过逐帧摆位 */
    public var animLock:Bool = false;
    
    public var bpmText:FlxText;
    public var lengthText:FlxText;
    public var keysText:FlxText;
    private var ratingText:FlxText;

    /** 鼠标悬停态。由宿主维护 —— updatePosition 每帧重算 alpha，直接 setAlpha 会被覆盖。 */
    public var isHovered:Bool = false;

    public function new(x:Float, y:Float, songName:String, songCharacter:String, coloring:Int, ?displayName:String,
                        ?variant:String = null, ?diffNames:Array<String> = null)
    {
        super();
        
        this.songName = songName;
        this.displayName = (displayName != null && displayName.length > 0) ? displayName : songName;
        this.coloring = coloring;
        this.variant = (variant != null && variant.length > 0) ? variant : null;
        this.diffNames = (diffNames != null && diffNames.length > 0) ? diffNames : null;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
        
        bgSprite = new FlxSprite(x, y);
        bgSprite.makeGraphic(450, 75, 0xFF4A4A4A);
        bgSprite.alpha = 0.67;
        bgSprite.scrollFactor.set();
        
        add(bgSprite);
        
        textSprite = new FlxText(x + 60, y + 10, 380, this.displayName, 20);
        textSprite.antialiasing = ClientPrefs.data.antialiasing;
        textSprite.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        textSprite.borderSize = 2;
        textSprite.borderColor = FlxColor.BLACK;
        textSprite.scrollFactor.set();
        add(textSprite);

        bpmText = new FlxText(x + 60, y + 35, 110, 'BPM: --', 14);
        bpmText.antialiasing = ClientPrefs.data.antialiasing;
        bpmText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        bpmText.borderSize = 1;
        bpmText.borderColor = FlxColor.BLACK;
        bpmText.scrollFactor.set();
        add(bpmText);
        
        lengthText = new FlxText(x + 180, y + 35, 130, 'LENGTH: 0:00', 14);
        lengthText.antialiasing = ClientPrefs.data.antialiasing;
        lengthText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        lengthText.borderSize = 1;
        lengthText.borderColor = FlxColor.BLACK;
        lengthText.scrollFactor.set();
        add(lengthText);

        keysText = new FlxText(x + 320, y + 35, 80, 'KEYS: --', 14);
        keysText.antialiasing = ClientPrefs.data.antialiasing;
        keysText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        keysText.borderSize = 1;
        keysText.borderColor = FlxColor.BLACK;
        keysText.scrollFactor.set();
        add(keysText);
        
        Mods.currentModDirectory = this.folder;
        
        icon = new HealthIcon(songCharacter, false, true, this.folder);
        icon.setPosition(x + 30, y + 5);
        icon.scale.set(0.6, 0.6);
        icon.updateHitbox();
        icon.scrollFactor.set();
        add(icon);
        
        rhombusBg = new FlxSprite(x + 400, y);

        try {
            rhombusBg.loadGraphic(Paths.image('freeplay/rhombus'));
        } catch (e:Dynamic) {
            rhombusBg.makeGraphic(60, 75, 0xFF333333);
        }
        
        rhombusBg.color = coloring;
        rhombusBg.alpha = 0.6;
        rhombusBg.scrollFactor.set();
        add(rhombusBg);
        
        ratingSprite = new FlxSprite(x + 490, y + 20);
        ratingSprite.antialiasing = true;
        ratingSprite.scrollFactor.set();
        
        // 官方 rankbadges 图集（sparrowsheet，24fps 非循环，ADD 叠加发光）
        try
        {
            ratingSprite.frames = Paths.getSparrowAtlas('freeplay/rankbadges');
            for (anim in ['PERFECT rank', 'PERFECT rank GOLD', 'EXCELLENT rank', 'GREAT rank', 'GOOD rank', 'LOSS rank'])
                ratingSprite.animation.addByPrefix(anim, anim, 24, false);
            ratingSprite.blend = BlendMode.ADD;
            hasBadgeAtlas = true;
        }
        catch (e:Dynamic)
        {
            hasBadgeAtlas = false;
        }
        
        add(ratingSprite);
        updateRatingSprite();
    }
    
    /** 宿主维护悬停态；alpha 由 updatePosition 统一算，别在外部直接改成员 alpha。 */
    public function setHovered(value:Bool):Void
    {
        isHovered = value;
    }
    
    public function updateDifficultyInfo(bpm:Float, formattedLength:String, ?noteCount:Int = 0, ?difficultyRating:Float = 0.0, ?keyCount:Int = 0)
    {
        if (bpm > 0)
        {
            var bpmValue:String = Math.round(bpm) == bpm ? Std.string(Math.round(bpm)) : Std.string(FlxMath.roundDecimal(bpm, 1));
            bpmText.text = 'BPM: $bpmValue';
        }
        else
            bpmText.text = 'BPM: --';
            
        lengthText.text = 'LENGTH: $formattedLength';

        if (keysText != null)
            keysText.text = (keyCount > 0) ? 'KEYS: $keyCount' : 'KEYS: --';
    }
    
    public function updateRatingSprite(?mode:String = null)
    {
        if (mode == null) mode = ClientPrefs.getGameplaySetting('opponentplay');
        var songLowercase:String = songName.toLowerCase();
        songLowercase = songLowercase.replace(" ", "-");
        
        var bestRating:Float = 0;
        // 难度名优先用这首歌自己的（混排列表里全局 Difficulty.list 未必对得上）；
        // 变体显式传入 —— 切来源后全局 Paths.currentContentVariant 可能还是上一个包的，
        // 吃全局会让 PicoMix 的卡读到 base 同名歌的成绩。
        var ratingDiffs:Array<String> = (diffNames != null && diffNames.length > 0) ? diffNames : Difficulty.list;
        for (diffName in ratingDiffs)
        {
            // 只读版：这里每张卡都会遍历全部难度，getRating 会给缺失键写回存档 + flush
            var rating:Float = Highscore.peekRatingByName(songLowercase, diffName, folder, mode, variant);
            if (rating > bestRating)
            {
                bestRating = rating;
            }
        }
        
        var percent:Float = bestRating * 100;
        var newRank:FreeplayRank = FreeplayRank.fromAccuracy(percent);
        
        if (hasBadgeAtlas)
        {
            // 档位没变就不重放动画（此函数会被 create/refresh/preload 回调多处调用）
            if (newRank == currentRank && ratingSprite.animation.curAnim != null) return;
            currentRank = newRank;
            
            if (newRank == FreeplayRank.NONE)
            {
                ratingSprite.visible = false;
                ratingSprite.animation.stop();
                return;
            }
            
            ratingSprite.visible = true;
            
            // 彩色P：粉P素材 + 色相循环
            if (newRank == FreeplayRank.RAINBOW)
            {
                if (hueShader == null)
                {
                    hueShader = new ColorSwap();
                    hueShader.saturation = 0.1;
                }
                ratingSprite.shader = hueShader.shader;
            }
            else
            {
                ratingSprite.shader = null;
            }
            
            ratingSprite.animation.play(newRank.animName, true, false, 0);
            ratingSprite.scale.set(BADGE_SCALE, BADGE_SCALE);
            ratingSprite.updateHitbox();
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 205;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
            return;
        }
        
        // ---- 回退：官方图集缺失时用旧静态 PNG ----
        var ratingImage:String = "air";
        
        if (percent >= 98) {
            ratingImage = "P";
        } else if (percent >= 90) {
            ratingImage = "GP";
        } else if (percent >= 80) {
            ratingImage = "E";
        } else if (percent >= 70) {
            ratingImage = "SG";
        } else if (percent >= 60) {
            ratingImage = "G";
        } else if (percent > 0) {
            ratingImage = "L";
        }
        
        try
        {
            ratingSprite.loadGraphic(Paths.image('freeplay/ratings/$ratingImage'));
            if (ratingText != null) ratingText.visible = false;
            ratingSprite.scale.set(0.7, 0.7);
            ratingSprite.updateHitbox();
            
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 205;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }
        catch (e:Dynamic)
        {
            trace('Failed to load rating image: $ratingImage');
            ratingSprite.makeGraphic(40, 40, FlxColor.TRANSPARENT);
            
            if (ratingText == null)
            {
                ratingText = new FlxText(ratingSprite.x, ratingSprite.y, 40, ratingImage, 20);
                ratingText.antialiasing = ClientPrefs.data.antialiasing;
                ratingText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
                ratingText.borderSize = 2;
                ratingText.borderColor = FlxColor.BLACK;
                add(ratingText);
            }
            else
            {
                ratingText.text = ratingImage;
                ratingText.x = ratingSprite.x;
                ratingText.y = ratingSprite.y;
            }
            ratingText.visible = true;
        }
    }
    
    /** RAINBOW 彩P 色相循环（卡片无自身 update，由 State 每帧驱动） */
    public function updateRankHue(elapsed:Float):Void
    {
        if (currentRank != FreeplayRank.RAINBOW || hueShader == null) return;
        hueTime += elapsed;
        hueShader.hue = (hueTime * 0.6) % 1.0;
    }
    
    /** 动画用：整卡（含徽章）平移 */
    public function shiftCard(dx:Float, dy:Float):Void
    {
        for (member in members)
        {
            if (member == null) continue;
            member.x += dx;
            member.y += dy;
        }
    }
    
    /** 动画用：整卡设置角度 */
    public function setCardAngle(a:Float):Void
    {
        for (member in members)
            if (member != null) member.angle = a;
    }
    
    public function updatePosition(curSelected:Float, selectedIndex:Int)
    {
        if (animLock) return; // 评级应用动画期间由动画代码接管
        var distance = targetY - curSelected;
        
        if (Math.abs(distance) > 5) 
        {
            bgSprite.visible = bgSprite.active = false;
            textSprite.visible = textSprite.active = false;
            icon.visible = icon.active = false;
            rhombusBg.visible = rhombusBg.active = false;
            ratingSprite.visible = ratingSprite.active = false;
            bpmText.visible = bpmText.active = false;
            lengthText.visible = lengthText.active = false;
            keysText.visible = keysText.active = false;
            return;
        }
        
        bgSprite.visible = bgSprite.active = true;
        textSprite.visible = textSprite.active = true;
        icon.visible = icon.active = true;
        rhombusBg.visible = rhombusBg.active = true;
        // 未游玩（NONE）不显示徽章；帧序号默认 0，不藏住会画出图集第一帧（E）
        ratingSprite.visible = ratingSprite.active = (currentRank != FreeplayRank.NONE);
        bpmText.visible = bpmText.active = true;
        lengthText.visible = lengthText.active = true;
        keysText.visible = keysText.active = true;
        
        var middleY = FlxG.height * 0.5;
        var spacing = 80;
        
        var offsetY = distance * spacing;
        var offsetX = Math.abs(distance) * -60;
        
        var targetX = FlxG.width * 0.175 + offsetX;
        var targetYPos = middleY + offsetY - 30;
        
        bgSprite.x = targetX - 50;
        bgSprite.y = targetYPos;
        
        textSprite.x = targetX + 60;
        textSprite.y = targetYPos + 10;

        bpmText.x = targetX + 60;
        bpmText.y = targetYPos + 35;
        
        lengthText.x = targetX + 180;
        lengthText.y = targetYPos + 35;

        keysText.x = targetX + 320;
        keysText.y = targetYPos + 35;
        
        icon.x = targetX - 80;
        icon.y = targetYPos - 45;
        
        rhombusBg.x = targetX + 400;
        rhombusBg.y = targetYPos;
        
        if (ratingSprite.graphic != null)
        {
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 100;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }

        var isSelected:Bool = (targetY == selectedIndex);
        
        var alpha:Float = 0.6;
        if (isSelected) alpha = 0.8;
        else if (isHovered) alpha = 0.7;
        bgSprite.color = (isSelected || isHovered) ? 0xFF5A5A5A : 0xFF4A4A4A;
        
        rhombusBg.color = coloring;
        
        bgSprite.alpha = alpha;
        textSprite.alpha = alpha;
        icon.alpha = alpha;
        rhombusBg.alpha = alpha;
        // 徽章明暗与卡片 alpha 解耦（官方风格：选中全亮，未选中压暗）
        if (isSelected)
        {
            ratingSprite.color = 0xFFFFFFFF;
            ratingSprite.alpha = 1.0;
        }
        else
        {
            ratingSprite.color = 0xFFAAAAAA;
            ratingSprite.alpha = 0.7 * alpha;
        }
        bpmText.alpha = alpha;
        lengthText.alpha = alpha;
        keysText.alpha = alpha;
    }
    
    public function checkMouseOver():Bool
    {
        return FlxG.mouse.overlaps(bgSprite) || FlxG.mouse.overlaps(rhombusBg) || FlxG.mouse.overlaps(ratingSprite);
    }
}