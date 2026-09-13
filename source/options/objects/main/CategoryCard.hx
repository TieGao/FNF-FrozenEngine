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

    // Win10 配色
    var normalColor:FlxColor = 0xFF2B2B2B;
    var hoverColor:FlxColor  = 0xFF3A3A3A;
    var pressColor:FlxColor  = 0xFF252525;

    public var onClick:CategoryData->Void = null;
    public var onFocus:Bool = false;
    var pressing:Bool = false;

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

        // ---------- 左上角图标占位 ----------
        var iconSize = height * 0.24;
        iconBox = new Rect(width * 0.08, height * 0.14, iconSize, iconSize, 0, 0, 0xFF4CC2FF, 1);
        iconBox.antialiasing = ClientPrefs.data.antialiasing;
        add(iconBox);

        // ---------- 文本区域（图标右侧） ----------
        var textX = width * 0.08 + iconSize + width * 0.05;
        var textW = width * 0.92 - textX;

        // 主标题
        title = new FlxText(0, 0, Std.int(textW),
            Language.getPhrase('options.category.' + data.id + '.title', data.getSubName()));
        title.setFormat(Paths.font("montserrat.ttf"), 16, 0xFFFFFF, LEFT);
        title.antialiasing = ClientPrefs.data.antialiasing;
        title.x = textX;
        title.y = height * 0.14;
        add(title);

        // ---------- 标签行 ----------
        var tagKey = 'options.category.' + data.id + '.tags';
        var tagDefault = data.tags.join(' · ');
        tagText = new FlxText(0, 0, Std.int(width * 0.84),
            Language.getPhrase(tagKey, tagDefault));
        tagText.setFormat(Paths.font("montserrat.ttf"), 10, 0xCCCCCC, LEFT);
        tagText.antialiasing = ClientPrefs.data.antialiasing;
        tagText.x = textX;
        tagText.y = height * 0.4;
        tagText.wordWrap = false;
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