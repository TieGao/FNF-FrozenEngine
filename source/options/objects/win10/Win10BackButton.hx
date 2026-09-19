package options.objects.win10;

import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * Win10 风格返回按钮
 * 方角背景 + 左箭头图标 + "返回" 文本
 * 带悬浮/按下反馈
 */
class Win10BackButton extends FlxSpriteGroup
{
    public var bg:Rect;
    public var arrow:FlxSprite;   // 左箭头（用 graphic 画一个三角）
    public var label:FlxText;

    var mainW:Float;
    var mainH:Float;

    // 配色统一走主题（深浅色切换由 UITheme 提供），改成 getter 后每帧都会取到最新值
    var normalColor(get, never):FlxColor;
    inline function get_normalColor():FlxColor return UITheme.control;
    var hoverColor(get, never):FlxColor;
    inline function get_hoverColor():FlxColor return UITheme.controlHover;
    var pressColor(get, never):FlxColor;
    inline function get_pressColor():FlxColor return UITheme.controlPress;
    var accentColor(get, never):FlxColor;
    inline function get_accentColor():FlxColor return UITheme.accent;

    // 箭头尺寸（主题切换重绘时要用）
    var arrowSize:Float = 0;

    public var onClick:Void->Void = null;
    public var onFocus:Bool = false;
    var pressing:Bool = false;

    // 反馈动画
    var _scaleTween:FlxTween = null;

    public function new(X:Float, Y:Float, width:Float, height:Float, ?text:String = '返回', onClick:Void->Void = null)
    {
        super(X, Y);
        UITheme.ensure();

        this.onClick = onClick;
        mainW = width;
        mainH = height;

        // ---------- 背景 ----------
        bg = new Rect(0, 0, width, height, 0, 0, normalColor, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        // ---------- 左箭头图标 ----------
        arrowSize = height * 0.42;
        arrow = new FlxSprite();
        arrow.makeGraphic(Std.int(arrowSize), Std.int(arrowSize), 0x00000000, true);
        drawArrow(arrow, Std.int(arrowSize), accentColor);
        arrow.antialiasing = ClientPrefs.data.antialiasing;
        arrow.x = width * 0.1;
        arrow.y = (height - arrowSize) * 0.5;
        add(arrow);

        // ---------- 文本 ----------
        var textX = arrow.x + arrowSize + width * 0.06;
        var textW = width - textX - width * 0.08;

        label = new FlxText(textX, 0, Std.int(textW), text, 14);
        label.setFormat(Paths.font('montserrat.ttf'), 14, UITheme.textPrimary, LEFT);
        label.antialiasing = ClientPrefs.data.antialiasing;
        label.y = (height - label.height) * 0.5;
        add(label);
    }

    /**
     * 在 Sprite 上绘制一个指向左的实心三角形
     */
    function drawArrow(spr:FlxSprite, size:Int, color:FlxColor)
    {
        var bmd = new openfl.display.BitmapData(size, size, true, 0x00000000);
        // 简单三角形光栅化：每行从左到右填充
        for (y in 0...size)
        {
            // 计算该行三角形的宽度（上下对称）
            var half = size * 0.5;
            var dist = Math.abs(y - half);
            var w = Std.int((half - dist) * 1.1);
            if (w <= 0) continue;
            // 左对齐
            for (x in 0...w)
                bmd.setPixel32(x, y, color);
        }
        spr.pixels = bmd;
        spr.dirty = true;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var mouse = FlxG.mouse;
        var wasFocus = onFocus;
        onFocus = mouse.overlaps(this);

        // ---------- 悬浮/离开反馈 ----------
        if (onFocus != wasFocus)
        {
            FlxTween.cancelTweensOf(bg);
            if (onFocus) {
                FlxTween.color(bg, 0.12, normalColor, hoverColor, {ease: FlxEase.quadOut});
                // 箭头变亮一点（用 alpha 做反馈）
                FlxTween.tween(arrow, {alpha: 1.0}, 0.12, {ease: FlxEase.quadOut});
            } else {
                FlxTween.color(bg, 0.12, hoverColor, normalColor, {ease: FlxEase.quadOut});
                FlxTween.tween(arrow, {alpha: 0.75}, 0.12, {ease: FlxEase.quadOut});
                pressing = false;
            }
        }

        // ---------- 按下反馈 ----------
        if (onFocus && mouse.justPressed)
        {
            pressing = true;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, hoverColor, pressColor);

            // 轻微缩放，增加手感
            if (_scaleTween != null) _scaleTween.cancel();
            _scaleTween = FlxTween.tween(this.scale, {x: 0.97, y: 0.97}, 0.06, {ease: FlxEase.quadOut});
        }

        // ---------- 释放反馈 ----------
        if (onFocus && mouse.justReleased && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, pressColor, hoverColor);

            if (_scaleTween != null) _scaleTween.cancel();
            _scaleTween = FlxTween.tween(this.scale, {x: 1.0, y: 1.0}, 0.12, {ease: FlxEase.backOut});

            if (onClick != null) onClick();
        }

        // 释放时鼠标已经离开按钮，也恢复缩放
        if (!onFocus && pressing)
        {
            pressing = false;
            if (_scaleTween != null) _scaleTween.cancel();
            _scaleTween = FlxTween.tween(this.scale, {x: 1.0, y: 1.0}, 0.12, {ease: FlxEase.backOut});
        }
    }

    public function setLabel(text:String)
    {
        if (label != null) label.text = text;
    }

    /** 主题切换后重新套用配色（含箭头重绘） */
    public function refreshTheme():Void
    {
        if (label != null) label.color = UITheme.textPrimary;
        if (arrow != null) drawArrow(arrow, Std.int(arrowSize), accentColor);
        if (bg != null) bg.color = onFocus ? hoverColor : normalColor;
    }
}