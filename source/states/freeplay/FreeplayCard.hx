package states.freeplay;

import shaders.ColorSwap;
import openfl.display.BlendMode;
import shapeEx.SlantQuad;

/**
 * Freeplay 列表里的单张歌曲卡。
 *
 * 造型：**平行四边形**卡身 + 右侧同斜度的色块 + 压在卡面上的白色描边（全部是 SlantQuad 现画的，
 * 不再用 makeGraphic 的矩形贴图）。卡身是半透明的，所以描边必须"压在卡面上"而不是垫在卡底下 ——
 * 垫在底下的话那层白会从半透明卡面里透上来，整张卡发灰。
 *
 * 配色：**卡面本体固定中性黑**，只有右侧色块跟歌曲的 HealthIcon 主色走（getDominantColor），
 * 不读 week.json 的 color；icon 取不到颜色时色块退回中性灰。
 */
class FreeplayCard extends FlxTypedGroup<FlxSprite>
{
    // ===================== 卡片几何 =====================
    /** 卡身总宽（含右侧色块）。和旧版「450 卡身 + 60 菱形」的总宽一致，整卡不会变宽 */
    public static inline var CARD_W:Float = 480;
    public static inline var CARD_H:Float = 75;
    /** 斜度 20 / 75 ≈ 15.3°，和难度方块（18 / 66）同一个倾角 */
    public static inline var CARD_SKEW:Float = 20;
    /** 右侧色块宽度（原始 100 的 3/5）；右边缘与卡身右斜边完全重合 */
    static inline var ACCENT_W:Float = 60;
    /** 白色描边粗细 */
    static inline var BORDER:Float = 2;
    /** 卡身底色：固定中性黑，**不跟 icon 染色**（icon 色只上右侧色块） */
    static inline var CARD_BODY:Int = 0xFF141414;
    /** 选中 / 悬停时的卡身（只提一点点，保持"黑卡"观感） */
    static inline var CARD_BODY_LIT:Int = 0xFF2A2A2A;
    /** HealthIcon.getDominantColor() 的"没取到"返回值 */
    static inline var UNKNOWN_ICON_COLOR:Int = 0xFF808080;
    static inline var DEFAULT_TINT:Int = 0xFF8A8A8A;

    // 卡内文字基准（相对卡身左上角）
    static inline var TITLE_X:Float = 108;
    static inline var TITLE_Y:Float = 9;
    static inline var TITLE_W:Float = 292;
    static inline var INFO_Y:Float = 39;
    static inline var LENGTH_X:Float = 108;
    static inline var KEYS_X:Float = 260;
    /** icon 相对卡身左上角的偏移（旧版：targetX-80 / targetY-45，卡身左上 = targetX-50） */
    static inline var ICON_X:Float = -30;
    static inline var ICON_Y:Float = -45;

    public var targetY:Float = 0;
    public var songName:String;
    /** 卡片上的标题文本。默认等于 songName，变体歌会带上标签（'Bopeebo (Pico Mix)'）；
     *  songName 仍保持原始歌名 —— 评级 / 存档查找都按它算。 */
    public var displayName:String;
    /** 卡片主色（= icon 主色）。**只用于右侧色块**，卡身始终是 CARD_BODY 的中性黑。 */
    public var coloring:Int;
    public var folder:String;
    /** 本卡所属内容包变体（Pico…）；base 歌为 null。徽章查成绩必须用它，不能吃全局 Paths.currentContentVariant。 */
    public var variant:String = null;
    /** 这首歌**真实拥有**的难度名（来自谱面信息）；为空时退回全局 Difficulty.list。
     *  混排列表（base + Erect + PicoMix）里全局列表只可能对应其中一种。 */
    public var diffNames:Array<String> = null;
    
    /** 卡身（平行四边形，半透明） */
    public var bgSprite:SlantQuad;
    /** 白色描边（空心，压在卡面之上） */
    public var cardOutline:SlantQuad;
    /** 右侧色块（原来那张 rhombus 菱形贴图的位置，现在同斜度的平行四边形） */
    public var accentBg:SlantQuad;
    public var textSprite:FlxText;
    public var icon:HealthIcon;
    
    public var ratingSprite:FlxSprite;
    
    // ---- 动态评级徽章（官方 rankbadges 图集） ----
    /** 徽章相对色块中心再左移多少（视觉重心偏左一点，别贴着右斜边） */
    static inline var BADGE_SHIFT_X:Float = -60;
    /** 徽章缩放（原 0.7 偏小，1.5x ≈ 1.05；后续自调只改这里） */
    public static inline var BADGE_SCALE:Float = 1.09;
    public var hasBadgeAtlas:Bool = false;
    public var currentRank:FreeplayRank = FreeplayRank.NONE;
    public var hueShader:ColorSwap;   // 仅 RAINBOW 挂载
    public var hueTime:Float = 0;
    /** 评级应用动画期间为 true，updatePosition 跳过逐帧摆位 */
    public var animLock:Bool = false;
    
    public var lengthText:FlxText;
    public var keysText:FlxText;
    private var ratingText:FlxText;

    /** 鼠标悬停态。由宿主维护 —— updatePosition 每帧重算 alpha，直接 setAlpha 会被覆盖。 */
    public var isHovered:Bool = false;

    /** 卡身左上角（未旋转）；所有成员位置都由 applyLayout() 从这里推 */
    private var cardX:Float = 0;
    private var cardY:Float = 0;
    /** 整卡角度（评级动画的歪头）；非 0 时成员绕卡身中心一起转 */
    private var cardAngle:Float = 0;

    public function new(x:Float, y:Float, songName:String, songCharacter:String, ?displayName:String,
                        ?variant:String = null, ?diffNames:Array<String> = null)
    {
        super();
        
        this.songName = songName;
        this.displayName = (displayName != null && displayName.length > 0) ? displayName : songName;
        this.coloring = DEFAULT_TINT;
        this.variant = (variant != null && variant.length > 0) ? variant : null;
        this.diffNames = (diffNames != null && diffNames.length > 0) ? diffNames : null;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
        
        // 画序（自下而上）：卡身 → 右侧色块 → 白色描边 → 文字/icon/徽章
        bgSprite = new SlantQuad(x, y, CARD_W, CARD_H, CARD_SKEW, CARD_BODY, 0.6);
        bgSprite.scrollFactor.set();
        add(bgSprite);

        accentBg = new SlantQuad(x + CARD_W - ACCENT_W, y, ACCENT_W, CARD_H, CARD_SKEW, DEFAULT_TINT, 0.75);
        accentBg.scrollFactor.set();
        add(accentBg);

        cardOutline = new SlantQuad(x, y, CARD_W, CARD_H, CARD_SKEW, FlxColor.WHITE, 0.5, BORDER);
        cardOutline.scrollFactor.set();
        add(cardOutline);
        
        textSprite = new FlxText(x + TITLE_X, y + TITLE_Y, TITLE_W, this.displayName, 20);
        textSprite.antialiasing = ClientPrefs.data.antialiasing;
        textSprite.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        textSprite.borderSize = 2;
        textSprite.borderColor = FlxColor.BLACK;
        textSprite.scrollFactor.set();
        // 长标题降字号，不要折行 —— 折出来的第二行会压到下面的 LENGTH/KEYS
        textSprite.wordWrap = false;
        var measuredTitle:Float = (textSprite.textField != null) ? textSprite.textField.textWidth : 0;
        if (measuredTitle > TITLE_W)
        {
            var fittedSize:Int = Std.int(20 * TITLE_W / measuredTitle);
            if (fittedSize < 13) fittedSize = 13;
            textSprite.setFormat(Paths.font("vcr.ttf"), fittedSize, FlxColor.WHITE, LEFT);
        }
        add(textSprite);

        lengthText = new FlxText(x + LENGTH_X, y + INFO_Y, 140, 'LENGTH: 0:00', 14);
        lengthText.antialiasing = ClientPrefs.data.antialiasing;
        lengthText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        lengthText.borderSize = 1;
        lengthText.borderColor = FlxColor.BLACK;
        lengthText.scrollFactor.set();
        add(lengthText);

        keysText = new FlxText(x + KEYS_X, y + INFO_Y, 90, 'KEYS: --', 14);
        keysText.antialiasing = ClientPrefs.data.antialiasing;
        keysText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        keysText.borderSize = 1;
        keysText.borderColor = FlxColor.BLACK;
        keysText.scrollFactor.set();
        add(keysText);
        
        Mods.currentModDirectory = this.folder;

        icon = new HealthIcon(songCharacter, false, true, this.folder);
        icon.setPosition(x + ICON_X, y + ICON_Y);
        icon.scale.set(0.6, 0.6);
        icon.updateHitbox();
        icon.scrollFactor.set();
        add(icon);

        // 卡片配色只跟 icon 主色走（不读 week.json）；icon 整个取不到时用中性灰兜底。
        // icon 色**只用在右侧色块**上，卡身保持中性黑。
        var iconColor:Int = icon.getDominantColor();
        this.coloring = (iconColor == UNKNOWN_ICON_COLOR) ? DEFAULT_TINT : iconColor;
        bgSprite.color = CARD_BODY;
        accentBg.color = accentColor();

        ratingSprite = new FlxSprite(x, y);
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
        cardX = x;
        cardY = y;
        updateRatingSprite();
        applyLayout();
    }

    // ===================== 配色 =====================
    /** 右侧色块：icon 主色压暗一点，白徽章 / 白字压在上面才读得清。卡身不参与染色。 */
    public function accentColor():Int
    {
        var c:Int = (coloring == 0) ? DEFAULT_TINT : coloring;
        return FlxColor.interpolate(c, CARD_BODY, 0.18);
    }
    
    /** 宿主维护悬停态；alpha 由 updatePosition 统一算，别在外部直接改成员 alpha。 */
    public function setHovered(value:Bool):Void
    {
        isHovered = value;
    }

    /** 卡片信息行（BPM 已挪到右上信息区，卡上只留时长和键数）。 */
    public function updateDifficultyInfo(formattedLength:String, ?keyCount:Int = 0)
    {
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
            applyLayout(); // 徽章居中在右侧色块里（尺寸变了要重摆）
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
            applyLayout();
        }
        catch (e:Dynamic)
        {
            trace('Failed to load rating image: $ratingImage');
            ratingSprite.makeGraphic(40, 40, FlxColor.TRANSPARENT);
            
            if (ratingText == null)
            {
                ratingText = new FlxText(cardX, cardY, 40, ratingImage, 20);
                ratingText.antialiasing = ClientPrefs.data.antialiasing;
                ratingText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
                ratingText.borderSize = 2;
                ratingText.borderColor = FlxColor.BLACK;
                add(ratingText);
            }
            else
            {
                ratingText.text = ratingImage;
            }
            ratingText.visible = true;
            applyLayout();
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
        cardX += dx;
        cardY += dy;
        applyLayout();
    }
    
    /** 动画用：整卡设置角度（绕卡身中心整体旋转，各成员接缝不会裂开） */
    public function setCardAngle(a:Float):Void
    {
        cardAngle = a;
        applyLayout();
    }
    
    public function updatePosition(curSelected:Float, selectedIndex:Int)
    {
        if (animLock) return; // 评级应用动画期间由动画代码接管
        var distance = targetY - curSelected;
        
        if (Math.abs(distance) > 5) 
        {
            setCardVisible(false);
            return;
        }
        
        setCardVisible(true);
        // 未游玩（NONE）不显示徽章；帧序号默认 0，不藏住会画出图集第一帧（E）
        ratingSprite.visible = ratingSprite.active = (currentRank != FreeplayRank.NONE);
        
        var middleY = FlxG.height * 0.5;
        var spacing = 80;
        
        var offsetY = distance * spacing;
        var offsetX = Math.abs(distance) * -60;
        
        var targetX = FlxG.width * 0.175 + offsetX;
        var targetYPos = middleY + offsetY - 30;

        cardX = targetX - 50;
        cardY = targetYPos;
        cardAngle = 0;
        applyLayout();

        var isSelected:Bool = (targetY == selectedIndex);
        
        var alpha:Float = 0.6;
        if (isSelected) alpha = 0.8;
        else if (isHovered) alpha = 0.7;

        // 卡身固定中性黑：选中 / 悬停只提一档灰，不再拿 icon 色染卡面
        bgSprite.color = (isSelected || isHovered) ? CARD_BODY_LIT : CARD_BODY;
        accentBg.color = accentColor();
        
        bgSprite.alpha = alpha;
        textSprite.alpha = alpha;
        icon.alpha = alpha;
        lengthText.alpha = alpha;
        keysText.alpha = alpha;
        // 色块是整张卡唯一的彩色区域，比卡身更实一点（白徽章压得住）
        accentBg.alpha = Math.min(1, alpha * 1.25);

        // 白描边：选中最亮，越远越淡（描边本身独立于卡面 alpha）
        cardOutline.alpha = isSelected ? 0.95 : (isHovered ? 0.8 : 0.5);

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
    }

    private function setCardVisible(value:Bool):Void
    {
        bgSprite.visible = bgSprite.active = value;
        accentBg.visible = accentBg.active = value;
        cardOutline.visible = cardOutline.active = value;
        textSprite.visible = textSprite.active = value;
        icon.visible = icon.active = value;
        lengthText.visible = lengthText.active = value;
        keysText.visible = keysText.active = value;
        if (!value)
        {
            ratingSprite.visible = ratingSprite.active = false;
        }
    }

    /** 按 cardX / cardY / cardAngle 摆全部成员。位置只在这里算，别在别处直接写 x/y。 */
    private function applyLayout():Void
    {
        var pivotX:Float = cardX + CARD_W * 0.5;
        var pivotY:Float = cardY + CARD_H * 0.5;

        placeBg(cardOutline, cardX, cardY, pivotX, pivotY);
        placeBg(bgSprite, cardX, cardY, pivotX, pivotY);
        placeBg(accentBg, cardX + CARD_W - ACCENT_W, cardY, pivotX, pivotY);
        placeBg(textSprite, cardX + TITLE_X, cardY + TITLE_Y, pivotX, pivotY);
        placeBg(lengthText, cardX + LENGTH_X, cardY + INFO_Y, pivotX, pivotY);
        placeBg(keysText, cardX + KEYS_X, cardY + INFO_Y, pivotX, pivotY);
        placeBg(icon, cardX + ICON_X, cardY + ICON_Y, pivotX, pivotY);

        // 徽章居中在右侧色块里，再整体左移一点（BADGE_SHIFT_X）；
        // 右下角还要按斜边夹一下，别让它越出卡片轮廓
        var badgeW:Float = ratingSprite.width;
        var badgeH:Float = ratingSprite.height;
        var badgeY:Float = cardY + (CARD_H - badgeH) * 0.5;
        var midY:Float = (CARD_H - badgeH) * 0.5 + badgeH * 0.5;
        var centerX:Float = (accentEdge(midY, false) + accentEdge(midY, true)) * 0.5;
        var badgeX:Float = centerX - badgeW * 0.5 + BADGE_SHIFT_X;
        var maxX:Float = accentEdge((badgeY - cardY) + badgeH, true) - 2 - badgeW;
        if (badgeX > maxX) badgeX = maxX;
        placeBg(ratingSprite, badgeX, badgeY, pivotX, pivotY);

        // 图集缺失时的纯文字兜底，跟着徽章的位置走
        if (ratingText != null && ratingText.visible)
            placeBg(ratingText, centerX - ratingText.width * 0.5 + BADGE_SHIFT_X,
                cardY + (CARD_H - ratingText.height) * 0.5, pivotX, pivotY);
    }

    /** 色块在卡内高度 y 处的左 / 右边界（屏幕坐标）。 */
    private function accentEdge(y:Float, right:Bool):Float
    {
        var t:Float = Math.max(0, Math.min(1, y / CARD_H));
        var x:Float = cardX + CARD_W - ACCENT_W;
        return right ? (x + ACCENT_W - CARD_SKEW * t) : (x + CARD_SKEW * (1 - t));
    }

    /**
     * 摆一个成员。cardAngle 非 0（评级动画歪头）时把成员的**中心**绕卡身中心旋转，
     * 而不是让每个成员各自原地转 —— 各自转的话卡身和右侧色块会错开一条缝。
     */
    private function placeBg(spr:FlxSprite, x:Float, y:Float, pivotX:Float, pivotY:Float):Void
    {
        if (spr == null) return;

        spr.angle = cardAngle;
        if (cardAngle == 0)
        {
            spr.x = x;
            spr.y = y;
            return;
        }

        var rad:Float = cardAngle * Math.PI / 180;
        var cos:Float = Math.cos(rad);
        var sin:Float = Math.sin(rad);
        var halfW:Float = spr.width * 0.5;
        var halfH:Float = spr.height * 0.5;
        var dx:Float = x + halfW - pivotX;
        var dy:Float = y + halfH - pivotY;
        spr.x = pivotX + dx * cos - dy * sin - halfW;
        spr.y = pivotY + dx * sin + dy * cos - halfH;
    }
    
    public function checkMouseOver():Bool
    {
        // 平行四边形按斜边命中，别用包围盒（卡片右半截是斜的，用盒子会误触相邻卡）
        if (bgSprite != null && bgSprite.containsScreen(FlxG.mouse.x, FlxG.mouse.y)) return true;
        if (ratingSprite != null && ratingSprite.visible && FlxG.mouse.overlaps(ratingSprite)) return true;
        return false;
    }
}
