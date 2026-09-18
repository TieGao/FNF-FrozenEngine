package options.objects.backend;

import options.Option;
import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class OptionButton extends FlxSpriteGroup
{
    var follow:Option;
    var bg:Rect;
    var label:FlxText;
    var actionText:FlxText;

    var isReset:Bool;

    var hover:Bool = false;
    var pressing:Bool = false;

    static inline var NORMAL:Int = 0xFF3A3A3A;
    static inline var HOVER:Int  = 0xFF4A4A4A;
    static inline var PRESS:Int  = 0xFF2B2B2B;
    static inline var ACCENT:Int = 0xFF4CC2FF;

    static inline var R_NORMAL:Int = 0xFF5A2B2B;
    static inline var R_HOVER:Int  = 0xFF7A3A3A;
    static inline var R_PRESS:Int  = 0xFF3A1F1F;
    static inline var R_WARN:Int   = 0xFFFF6363;

    var confirmPending:Bool = false;
    var confirmTimer:Float = 0;

    public function new(X:Float, Y:Float, width:Float, height:Float,
                        follow:Option, isReset:Bool = false, fontSize:Int = 16)
    {
        super(X, Y);
        this.follow = follow;
        this.isReset = isReset;

        // 方角
        bg = new Rect(0, 0, width, height, 0, 0, isReset ? R_NORMAL : NORMAL, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        actionText = new FlxText(0, 0, width - 20, getActionText(), fontSize);
        actionText.setFormat(Paths.font('montserrat.ttf'), fontSize,
            0xFFFFFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        actionText.borderStyle = NONE;
        actionText.antialiasing = ClientPrefs.data.antialiasing;
        actionText.y = bg.y + (height - actionText.height) * 0.5;
        add(actionText);
    }

    function getTitleText():String
    {
        if (follow.name != null && follow.name != '')
            return follow.name;

        if (isReset)
            return Language.getPhrase('options.action.reset', 'Reset');

        return Language.getPhrase('options.action.open', 'Open');
    }

    function getActionText():String
    {
        if (follow.actionLabel != null && follow.actionLabel != '')
            return follow.actionLabel;

        if (isReset)
            return Language.getPhrase('options.action.reset', 'Reset');

        return Language.getPhrase('options.action.open', 'Open');
    }

    // 根据状态计算目标背景色
    function computeTargetColor():Int
    {
        if (isReset)
            return pressing ? R_PRESS : (hover ? R_HOVER : R_NORMAL);
        return pressing ? PRESS : (hover ? HOVER : NORMAL);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        if (!follow.allowUpdate) return;

        var mouse = FlxG.mouse;
        var wasHover = hover;
        hover = mouse.overlaps(bg);

        // 悬浮状态变化 → tween 渐变（和 CategoryCard 一致）
        if (hover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
        }

        // 确认计时器
        if (isReset && confirmPending)
        {
            confirmTimer -= elapsed;
            if (confirmTimer <= 0)
            {
                confirmPending = false;
                actionText.text = getActionText();
                actionText.color = 0xFFFFFF;
            }
            else
            {
                actionText.color = R_WARN;
            }
        }

        if (!isReset)
        {
            actionText.color = hover ? ACCENT : 0xFFFFFF;
        }

        if (hover && mouse.justPressed)
        {
            pressing = true;

            // 按下：快速渐到 PRESS
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, bg.color, computeTargetColor());

            if (isReset)
            {
                if (!confirmPending)
                {
                    confirmPending = true;
                    confirmTimer = 1.5;
                    actionText.text = Language.getPhrase('options.action.confirm', 'Confirm?');
                    actionText.color = R_WARN;
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
                }
                else
                {
                    confirmPending = false;
                    doReset();
                }
            }
        }

        if (mouse.justReleased && pressing && !isReset)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            if (hover)
            {
                FlxTween.color(bg, 0.1, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
                if (follow.action != null) follow.action();
            }
            else
            {
                FlxTween.color(bg, 0.1, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
            }
        }

        if (!hover && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
        }
    }

    function doReset()
    {
        FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);

        if (follow.action != null)
        {
            follow.action();
            return;
        }

        var cat = follow.ownerCategory;
        if (cat != null)
        {
            for (o in cat.options)
            {
                o.setValue(o.defaultValue);
                o.change();
                o.saveCurrentValue();
                if (o.updateDisText != null) o.updateDisText();
            }
        }
        else
        {
            follow.setValue(follow.defaultValue);
            follow.change();
            follow.saveCurrentValue();
        }
    }
}