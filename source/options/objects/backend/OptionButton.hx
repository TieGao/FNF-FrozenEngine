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

    var confirmPending:Bool = false;
    var confirmTimer:Float = 0;

    public function new(X:Float, Y:Float, width:Float, height:Float,
                        follow:Option, isReset:Bool = false, fontSize:Int = 16)
    {
        super(X, Y);
        UITheme.ensure();

        this.follow = follow;
        this.isReset = isReset;

        // 方角
        bg = new Rect(0, 0, width, height, 0, 0, isReset ? UITheme.dangerBase : UITheme.control, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        actionText = new FlxText(0, 0, width - 20, getActionText(), fontSize);
        actionText.setFormat(Paths.font('montserrat.ttf'), fontSize,
            UITheme.textPrimary, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
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

    // 根据状态计算目标背景色（颜色全部来自主题）
    function computeTargetColor():Int
    {
        if (isReset)
            return pressing ? UITheme.dangerPress : (hover ? UITheme.dangerHover : UITheme.dangerBase);
        return pressing ? UITheme.controlPress : (hover ? UITheme.controlHover : UITheme.control);
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
                actionText.color = UITheme.textPrimary;
            }
            else
            {
                actionText.color = UITheme.danger;
            }
        }

        if (!isReset)
        {
            actionText.color = hover ? UITheme.accent : UITheme.textPrimary;
        }

        if (hover && mouse.justPressed)
        {
            pressing = true;

            // 按下：快速渐到按下色
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, bg.color, computeTargetColor());

            if (isReset)
            {
                if (!confirmPending)
                {
                    confirmPending = true;
                    confirmTimer = 1.5;
                    actionText.text = Language.getPhrase('options.action.confirm', 'Confirm?');
                    actionText.color = UITheme.danger;
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

    /** 动态改按钮文字（比如深浅色切换按钮） */
    public function setActionText(text:String):Void
    {
        if (actionText != null) actionText.text = text;
    }

    /** 主题切换后重新套用配色（行被重建时无需调用） */
    public function refreshTheme():Void
    {
        if (bg != null) bg.color = computeTargetColor();
        if (actionText != null && !isReset)
            actionText.color = hover ? UITheme.accent : UITheme.textPrimary;
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