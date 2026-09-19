package options.objects.win10;

import options.objects.OptionCategory;
import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class Win10NaviItem extends FlxSpriteGroup
{
    public var bg:Rect;
    public var accent:Rect;
    public var label:FlxText;

    /** 搜索命中数徽标（只在搜索时显示） */
    public var countBG:Rect;
    public var countText:FlxText;

    public var category:OptionCategory;
    public var onClick:OptionCategory->Void;

    public var isActive:Bool = false;
    public var isHover:Bool = false;

    var mainW:Float;
    var mainH:Float;

    // 渐变用：记录当前目标基础色（active 时也要保留悬停反馈）
    var baseColor:FlxColor = 0;
    var pressing:Bool = false;

    /** 搜索命中数 / 是否处于搜索状态 */
    var matchCount:Int = 0;
    var searching:Bool = false;
    /** 命中 0 项时盖在导航项上的淡化层（不能直接改 alpha，bg 的颜色 tween 会覆盖 alpha） */
    var dimOverlay:Rect;

    public function new(x:Float, y:Float, w:Float, h:Float,
                        cat:OptionCategory, onClick:OptionCategory->Void)
    {
        super(x, y);
        UITheme.ensure();

        this.category = cat;
        this.onClick = onClick;
        mainW = w; mainH = h;
        baseColor = UITheme.navItem;

        // 方角
        bg = new Rect(0, 0, w, h, 0, 0, UITheme.navItem, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        accent = new Rect(0, 0, 3, h, 0, 0, UITheme.accent, 1);
        accent.scale.y = 0;
        accent.antialiasing = ClientPrefs.data.antialiasing;
        add(accent);

        label = new FlxText(16, 0, w - 24, cat.displayName, Std.int(h * 0.34));
        label.setFormat(Paths.font('montserrat.ttf'), Std.int(h * 0.34),
            UITheme.textPrimary, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        label.borderStyle = NONE;
        label.antialiasing = ClientPrefs.data.antialiasing;
        label.y = (h - label.height) * 0.5;
        add(label);

        // ---------- 命中 0 项时的淡化层（盖住底色 / 强调条 / 文字） ----------
        dimOverlay = new Rect(0, 0, w, h, 0, 0, UITheme.navItem, 0.7);
        dimOverlay.antialiasing = ClientPrefs.data.antialiasing;
        dimOverlay.visible = false;
        add(dimOverlay);

        // ---------- 搜索命中数徽标（右侧小药丸，只在搜索时显示） ----------
        var bw = 28.0;
        var bh = 18.0;
        var bx = w - bw - 6;
        var by = (h - bh) * 0.5;

        countBG = new Rect(bx, by, bw, bh, 9, 9, UITheme.accent, 1);
        countBG.antialiasing = ClientPrefs.data.antialiasing;
        countBG.visible = false;
        add(countBG);

        countText = new FlxText(bx, by, bw, '0', 12);
        countText.setFormat(Paths.font('montserrat.ttf'), 12, UITheme.textOnAccent, CENTER);
        countText.antialiasing = ClientPrefs.data.antialiasing;
        countText.y = by + (bh - countText.height) * 0.5;
        countText.visible = false;
        add(countText);
    }

    /**
     * 更新搜索状态下的命中数徽标。
     * @param count     该子分类里命中的选项数量
     * @param searching 是否处于搜索状态；false 时恢复普通外观
     */
    public function setMatchCount(count:Int, searching:Bool):Void
    {
        this.matchCount = count;
        this.searching = searching;

        countBG.visible = searching;
        countText.visible = searching;
        dimOverlay.visible = searching && count <= 0;

        if (!searching) return;

        var hit = count > 0;
        countBG.color = hit ? UITheme.accent : UITheme.control;
        countText.color = hit ? UITheme.textOnAccent : UITheme.textSecondary;
        countText.text = Std.string(count);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (!visible || !active)
        {
            isHover = false;
            pressing = false;
            return;
        }

        var mouse = FlxG.mouse;
        var wasHover = isHover;
        isHover = mouse.overlaps(bg);

        // 悬浮状态切换 → 用 tween 做颜色渐变（和 CategoryCard 一样）
        if (isHover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            var from = bg.color;
            var to = computeTargetColor();
            FlxTween.color(bg, 0.12, from, to, {ease: FlxEase.quadOut});

            if (!isHover) pressing = false;
        }

        // 按下效果
        if (isHover && mouse.justPressed)
        {
            pressing = true;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, bg.color, UITheme.navItemPress);
        }

        if (mouse.justReleased && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            if (isHover)
            {
                FlxTween.color(bg, 0.1, UITheme.navItemPress, computeTargetColor(), {ease: FlxEase.quadOut});
                onClick(category);
                FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
            }
            else
            {
                FlxTween.color(bg, 0.1, UITheme.navItemPress, computeTargetColor(), {ease: FlxEase.quadOut});
            }
        }

        // 选中项的高亮（accent 条 + 文字颜色），保留原有即时插值
        var targetScale = isActive ? 1.0 : 0.0;
        accent.scale.y += (targetScale - accent.scale.y) * 0.25;
        accent.y = (mainH - accent.height * accent.scale.y) * 0.5;

        label.color = isActive ? UITheme.accent : (isHover ? UITheme.textPrimary : UITheme.textMuted);
    }

    // 根据 active / hover / press 决定 bg 的目标颜色
    function computeTargetColor():FlxColor
    {
        if (pressing) return UITheme.navItemPress;
        if (isHover)  return isActive ? UITheme.navItemActive : UITheme.navItemHover;
        return isActive ? UITheme.navItemActive : UITheme.navItem;
    }

    /** 主题切换后重新套用配色（导航被重建时无需调用） */
    public function refreshTheme():Void
    {
        baseColor = UITheme.navItem;
        if (accent != null) accent.color = UITheme.accent;
        if (bg != null) bg.color = computeTargetColor();
        if (label != null) label.color = isActive ? UITheme.accent : (isHover ? UITheme.textPrimary : UITheme.textMuted);
        if (dimOverlay != null) dimOverlay.color = UITheme.navItem;

        if (countBG != null && countBG.visible)
            countBG.color = (matchCount > 0) ? UITheme.accent : UITheme.control;
        if (countText != null && countText.visible)
            countText.color = (matchCount > 0) ? UITheme.textOnAccent : UITheme.textSecondary;
    }

    public function setActive(v:Bool):Void
    {
        if (isActive == v) return;
        isActive = v;

        // 选中状态切换时也做渐变，避免生硬跳变
        FlxTween.cancelTweensOf(bg);
        FlxTween.color(bg, 0.12, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
    }
}