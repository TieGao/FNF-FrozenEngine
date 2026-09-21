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
    public var icon:FlxSprite;
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
    /**
     * 键盘选中态（方向键在卡片网格里移动时的那张）。
     * 和 onFocus（鼠标悬停）分开：鼠标静止时键盘选中要留在原地，不能被悬停覆盖。
     */
    public var selected:Bool = false;

    // 标题字号
    inline static var TITLE_SIZE:Int = 16;
    // 图标显示尺寸（比标题大，作为卡片的视觉锚点）
    inline static var ICON_SIZE:Int = 48;
    // 超采样倍数：按 2× 画、再缩到 0.5 显示，斜线/圆弧边缘才不锯齿
    inline static var ICON_SS:Int = 2;
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

        // ---------- 左侧分类图标（矢量现画，见 CategoryIcons） ----------
        var iconSize:Int = ICON_SIZE;
        var iconX = width * PAD_LEFT;

        icon = new FlxSprite();
        icon.frames = CategoryIcons.draw(data.icon, iconSize * ICON_SS, UITheme.accent).imageFrame;
        icon.antialiasing = ClientPrefs.data.antialiasing;
        // 关键：offset/origin 归零，并且**不要**调 updateHitbox()。
        // updateHitbox() 会写 offset = -0.5*(width-frameWidth) 并把 origin 挪到中心，
        // 缩放锚点跟着变，超采样图的左上角就不再落在 (x, y) 上。
        icon.offset.set(0, 0);
        icon.origin.set(0, 0);
        icon.scale.set(1 / ICON_SS, 1 / ICON_SS);
        // 判定盒必须手动设成"显示尺寸"：frames 的 setter 内部会 resetSizeFromFrame()
        // 把 width/height 设成帧尺寸（96）。而 FlxTypedSpriteGroup.get_width/get_height
        // 是遍历成员求 x+width / y+height 的包围盒 —— 不设的话图标会顶出卡片下边缘，
        // 把整张卡片的鼠标命中区往下撑大（悬停在卡片下方也会误触发 hover）。
        icon.width = iconSize;
        icon.height = iconSize;
        icon.x = iconX;
        icon.y = height * 0.14;
        add(icon);

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
            // 用 bg.color 当起点而不是写死 normalColor：selected / pressing 会改变目标色，
            // 写死起点会在状态叠加时跳变。
            FlxTween.color(bg, 0.12, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
            if (!onFocus) pressing = false;
        }

        if (onFocus && mouse.justPressed) {
            pressing = true;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, bg.color, computeTargetColor());
        }
        if (onFocus && mouse.justReleased && pressing) {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeTargetColor());
            if (onClick != null) onClick(data);
        }
    }

    /** 键盘选中/取消选中（方向键移动时由 OptionsState 调用） */
    public function setSelected(v:Bool):Void
    {
        if (selected == v) return;
        selected = v;

        FlxTween.cancelTweensOf(bg);
        FlxTween.color(bg, 0.12, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
        applySelectedColors();
    }

    /** pressing > selected > hover > normal */
    function computeTargetColor():FlxColor
    {
        if (pressing) return pressColor;
        if (selected) return UITheme.navItemActive;
        if (onFocus)  return hoverColor;
        return normalColor;
    }

    function applySelectedColors():Void
    {
        if (title != null) title.color = selected ? UITheme.accent : UITheme.textPrimary;
    }

    public function changeLanguage() {
        title.text = Language.getPhrase('options.category.' + data.id + '.title', data.getSubName());
        tagText.text = Language.getPhrase('options.category.' + data.id + '.tags', data.tags.join(' · '));
    }

    /** 主题切换后重新套用配色（卡片被重建时无需调用） */
    public function refreshTheme():Void
    {
        if (bg != null) bg.color = computeTargetColor();
        // FlxSprite 没有 .color，主题色变了只能重画（图标有静态缓存，同色不会重复绘制）
        if (icon != null) icon.frames = CategoryIcons.draw(data.icon, ICON_SIZE * ICON_SS, UITheme.accent).imageFrame;
        if (tagText != null) tagText.color = UITheme.textSecondary;
        if (dimOverlay != null) dimOverlay.color = UITheme.card;
        applySelectedColors();

        if (badgeBG != null && badgeBG.visible)
            badgeBG.color = (matchCount > 0) ? UITheme.accent : UITheme.control;
        if (badgeText != null && badgeText.visible)
            badgeText.color = (matchCount > 0) ? UITheme.textOnAccent : UITheme.textSecondary;
    }
}