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

    public var data:CategoryData;

    var mainWidth:Float;
    var mainHeight:Float;

    // Win10 深色模式配色
    var normalColor:FlxColor = 0xFF0A0A0A; // 接近纯黑
    var hoverColor:FlxColor  = 0xFF2E2E2E; // 浅灰
    var pressColor:FlxColor  = 0xFF454545; // 更亮

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
        iconBox = new Rect(iconX, height * 0.14, iconSize, iconSize, 0, 0, 0xFF4CC2FF, 1);
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
        title.setFormat(Paths.font("montserrat.ttf"), TITLE_SIZE, 0xFFFFFF, LEFT);
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
        tagText.setFormat(Paths.font("montserrat.ttf"), 10, 0xCCCCCC, LEFT);
        tagText.antialiasing = ClientPrefs.data.antialiasing;
        tagText.wordWrap = true;        // 标签也允许换行
        tagText.x = textX;
        tagText.y = height * 0.4;
        add(tagText);
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
}