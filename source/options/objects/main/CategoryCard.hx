package options.objects.main;

import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * Win10 风格的大类卡片
 * 方角背景 + 图标 + 标题 + 标签行
 */
class CategoryCard extends FlxSpriteGroup
{
    public var bg:Rect;
    public var iconBox:Rect;
    public var title:FlxText;
    public var tagText:FlxText;

    /** 搜索命中数徽标（只在搜索时显示） */
    public var badgeBG:Rect;
    public var badgeText:FlxText;

    public var data:CategoryData;

    var mainWidth:Float;
    var mainHeight:Float;

    /** 搜索命中数 / 是否处于搜索状态 */
    var matchCount:Int = 0;
    var searching:Bool = false;
    /** 命中 0 项时盖在卡片上的淡化层（不能直接改 alpha，bg 的颜色 tween 会覆盖 alpha） */
    var dimOverlay:Rect;

    // 配色统一走主题（深浅色切换由 UITheme 提供），getter 保证每帧取到最新值
    var normalColor(get, never):FlxColor;
    inline function get_normalColor():FlxColor return UITheme.card;
    var hoverColor(get, never):FlxColor;
    inline function get_hoverColor():FlxColor return UITheme.cardHover;
    var pressColor(get, never):FlxColor;
    inline function get_pressColor():FlxColor return UITheme.cardPress;

    public var onClick:CategoryData->Void = null;
    public var onFocus:Bool = false;
    var pressing:Bool = false;

    // 标题字号（图标大小与它保持一致）
    inline static var TITLE_SIZE:Int = 16;
    // 图标/标题左侧起始位置
    inline static var PAD_LEFT:Float = 0.08;
    // 图标与文字之间的间距
    inline static var ICON_GAP:Float = 0.05;
    // 右侧留白，避免文字贴边 / 溢出
    inline static var PAD_RIGHT:Float = 0.06;

    public function new(X:Float, Y:Float, width:Float, height:Float, data:CategoryData, onClick:CategoryData->Void = null)
    {
        super(X, Y);
        UITheme.ensure();

        this.data = data;
        this.onClick = onClick;

        mainWidth = width;
        mainHeight = height;

        // ---------- 方角背景 ----------
        bg = new Rect(0, 0, width, height, 0, 0, normalColor, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        // ---------- 左上角图标占位（大小 = 标题字号） ----------
        var iconSize = TITLE_SIZE;
        var iconX = width * PAD_LEFT;
        iconBox = new Rect(iconX, height * 0.14, iconSize, iconSize, 0, 0, UITheme.accent, 1);
        iconBox.antialiasing = ClientPrefs.data.antialiasing;
        add(iconBox);

        // ---------- 文本区域（图标右侧） ----------
        var textX = iconX + iconSize + width * ICON_GAP;
        // 关键：文本宽度 = 卡片宽度 - 左边距 - 图标 - 间距 - 右边距
        var textW = width - textX - width * PAD_RIGHT;
        if (textW < 10) textW = 10; // 防御：极端窄卡片时不至于为负

        // 主标题
        title = new FlxText(0, 0, Std.int(textW),
            Language.getPhrase('options.category.' + data.id + '.title', data.getSubName()));
        title.setFormat(Paths.font("montserrat.ttf"), TITLE_SIZE, UITheme.textPrimary, LEFT);
        title.antialiasing = ClientPrefs.data.antialiasing;
        title.wordWrap = true;          // 超长自动换行
        title.x = textX;
        title.y = height * 0.14;
        add(title);

        // ---------- 标签行 ----------
        var tagKey = 'options.category.' + data.id + '.tags';
        var tagDefault = data.tags.join(' · ');
        tagText = new FlxText(0, 0, Std.int(textW),
            Language.getPhrase(tagKey, tagDefault));
        tagText.setFormat(Paths.font("montserrat.ttf"), 10, UITheme.textSecondary, LEFT);
        tagText.antialiasing = ClientPrefs.data.antialiasing;
        tagText.wordWrap = true;        // 标签也允许换行
        tagText.x = textX;
        tagText.y = height * 0.4;
        add(tagText);

        // ---------- 命中 0 项时的淡化层（盖住卡片内容，不影响右上角徽标） ----------
        dimOverlay = new Rect(0, 0, width, height, 0, 0, UITheme.card, 0.65);
        dimOverlay.antialiasing = ClientPrefs.data.antialiasing;
        dimOverlay.visible = false;
        add(dimOverlay);

        // ---------- 搜索命中数徽标（右上角小药丸，只在搜索时显示） ----------
        var badgeW = 40.0;
        var badgeH = 18.0;
        var badgeX = width - badgeW - width * PAD_RIGHT * 0.5;
        var badgeY = height * 0.14;

        badgeBG = new Rect(badgeX, badgeY, badgeW, badgeH, 9, 9, UITheme.accent, 1);
        badgeBG.antialiasing = ClientPrefs.data.antialiasing;
        badgeBG.visible = false;
        add(badgeBG);

        badgeText = new FlxText(badgeX, badgeY, badgeW, '0', 12);
        badgeText.setFormat(Paths.font("montserrat.ttf"), 12, UITheme.textOnAccent, CENTER);
        badgeText.antialiasing = ClientPrefs.data.antialiasing;
        badgeText.y = badgeY + (badgeH - badgeText.height) * 0.5;
        badgeText.visible = false;
        add(badgeText);
    }

    /**
     * 更新搜索状态下的命中数徽标。
     * @param count     该大类里命中的选项数量
     * @param searching 是否处于搜索状态；false 时恢复普通外观
     */
    public function setSearchState(count:Int, searching:Bool):Void
    {
        this.matchCount = count;
        this.searching = searching;

        badgeBG.visible = searching;
        badgeText.visible = searching;
        dimOverlay.visible = searching && count <= 0;

        if (!searching) return;

        var hit = count > 0;
        badgeBG.color = hit ? UITheme.accent : UITheme.control;
        badgeText.color = hit ? UITheme.textOnAccent : UITheme.textSecondary;
        badgeText.text = Std.string(count);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var mouse = FlxG.mouse;
        var wasFocus = onFocus;
        onFocus = mouse.overlaps(this);

        if (onFocus != wasFocus) {
            FlxTween.cancelTweensOf(bg);
            if (onFocus) {
                FlxTween.color(bg, 0.12, normalColor, hoverColor, {ease: FlxEase.quadOut});
            } else {
                FlxTween.color(bg, 0.12, hoverColor, normalColor, {ease: FlxEase.quadOut});
                pressing = false;
            }
        }

        if (onFocus && mouse.justPressed) {
            pressing = true;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, hoverColor, pressColor);
        }
        if (onFocus && mouse.justReleased && pressing) {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, pressColor, hoverColor);
            if (onClick != null) onClick(data);
        }
    }

    public function changeLanguage() {
        title.text = Language.getPhrase('options.category.' + data.id + '.title', data.getSubName());
        tagText.text = Language.getPhrase('options.category.' + data.id + '.tags', data.tags.join(' · '));
    }

    /** 主题切换后重新套用配色（卡片被重建时无需调用） */
    public function refreshTheme():Void
    {
        if (bg != null) bg.color = onFocus ? hoverColor : normalColor;
        if (iconBox != null) iconBox.color = UITheme.accent;
        if (title != null) title.color = UITheme.textPrimary;
        if (tagText != null) tagText.color = UITheme.textSecondary;
        if (dimOverlay != null) dimOverlay.color = UITheme.card;

        if (badgeBG != null && badgeBG.visible)
            badgeBG.color = (matchCount > 0) ? UITheme.accent : UITheme.control;
        if (badgeText != null && badgeText.visible)
            badgeText.color = (matchCount > 0) ? UITheme.textOnAccent : UITheme.textSecondary;
    }
}