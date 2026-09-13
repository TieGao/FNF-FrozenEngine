package options.objects.win10;

import options.objects.OptionCategory;
import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class Win10NaviItem extends FlxSpriteGroup
{
    public static inline var NORMAL:FlxColor = 0xFF2B2B2B; // 和导航背景一致
    public static inline var HOVER:FlxColor  = 0xFF3A3A3A; // 悬浮略亮
    public static inline var ACTIVE:FlxColor = 0xFF3A3A3A; // 选中
    public static inline var PRESS:FlxColor  = 0xFF222222; // 按下略暗
    public static inline var ACCENT:FlxColor = 0xFF4CC2FF; // Win10 蓝

    public var bg:Rect;
    public var accent:Rect;
    public var label:FlxText;

    public var category:OptionCategory;
    public var onClick:OptionCategory->Void;

    public var isActive:Bool = false;
    public var isHover:Bool = false;

    var mainW:Float;
    var mainH:Float;

    // 渐变用：记录当前目标基础色（active 时也要保留悬停反馈）
    var baseColor:FlxColor = NORMAL;
    var pressing:Bool = false;

    public function new(x:Float, y:Float, w:Float, h:Float,
                        cat:OptionCategory, onClick:OptionCategory->Void)
    {
        super(x, y);
        this.category = cat;
        this.onClick = onClick;
        mainW = w; mainH = h;

        // 方角
        bg = new Rect(0, 0, w, h, 0, 0, NORMAL, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        accent = new Rect(0, 0, 3, h, 0, 0, ACCENT, 1);
        accent.scale.y = 0;
        accent.antialiasing = ClientPrefs.data.antialiasing;
        add(accent);

        label = new FlxText(16, 0, w - 24, cat.displayName, Std.int(h * 0.34));
        label.setFormat(Paths.font('montserrat.ttf'), Std.int(h * 0.34),
            0xFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        label.borderStyle = NONE;
        label.antialiasing = ClientPrefs.data.antialiasing;
        label.y = (h - label.height) * 0.5;
        add(label);
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
            FlxTween.color(bg, 0.05, bg.color, PRESS);
        }

        if (mouse.justReleased && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            if (isHover)
            {
                FlxTween.color(bg, 0.1, PRESS, computeTargetColor(), {ease: FlxEase.quadOut});
                onClick(category);
                FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
            }
            else
            {
                FlxTween.color(bg, 0.1, PRESS, computeTargetColor(), {ease: FlxEase.quadOut});
            }
        }

        // 选中项的高亮（accent 条 + 文字颜色），保留原有即时插值
        var targetScale = isActive ? 1.0 : 0.0;
        accent.scale.y += (targetScale - accent.scale.y) * 0.25;
        accent.y = (mainH - accent.height * accent.scale.y) * 0.5;

        label.color = isActive ? ACCENT : (isHover ? 0xFFFFFF : 0xE0E0E0);
    }

    // 根据 active / hover / press 决定 bg 的目标颜色
    function computeTargetColor():FlxColor
    {
        if (pressing) return PRESS;
        if (isHover)  return isActive ? ACTIVE : HOVER;
        return isActive ? ACTIVE : NORMAL;
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