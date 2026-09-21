package options.objects.backend;

import options.Option;
import backend.UIControlTheme;
import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * 动作按钮（ACTION 类型，比如 Open / Reset）
 *
 * Win10 风格：平铺方角、无描边（原来的样子）
 * Win8  风格：2px 描边 + 按下填充强调色（Metro 按钮）
 */
class OptionButton extends FlxSpriteGroup
{
    var follow:Option;
    var bg:Rect;
    var border:FlxSprite;
    var label:FlxText;
    var actionText:FlxText;

    var isReset:Bool;

    /** 本次构建时解析出的风格 */
    var win8:Bool = false;

    var hover:Bool = false;
    var pressing:Bool = false;

    /**
     * 键盘选中宿主行时由 Win10OptionRow 置位：让按钮看起来和鼠标悬停一样。
     * ⚠️ 只参与**配色**计算，绝不能并进 `hover` —— 下面 `hover && mouse.justPressed`
     * 是点击门控，并进去就变成"鼠标点哪都触发"。
     */
    public var keyboardHighlight:Bool = false;

    var confirmPending:Bool = false;
    var confirmTimer:Float = 0;

    public function new(X:Float, Y:Float, width:Float, height:Float,
                        follow:Option, isReset:Bool = false, fontSize:Int = 16)
    {
        super(X, Y);
        UITheme.ensure();

        this.follow = follow;
        this.isReset = isReset;
        win8 = UIControlTheme.isWin8();

        bg = new Rect(0, 0, width, height, 0, 0, baseColor(), 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        if (win8)
        {
            border = UIControlTheme.makeFrameSprite(width, height);
            border.color = borderColor();
            add(border);
        }

        actionText = new FlxText(0, 0, width - 20, getActionText(), fontSize);
        actionText.setFormat(Paths.font('montserrat.ttf'), fontSize,
            win8 ? UIControlTheme.text() : UITheme.textPrimary, CENTER);
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

    inline function baseColor():Int
        return isReset ? UITheme.dangerBase : (win8 ? UIControlTheme.face() : UITheme.control);

    function borderColor():FlxColor
    {
        if (isReset) return UITheme.danger;
        return (hover || pressing || keyboardHighlight) ? UIControlTheme.accent() : UIControlTheme.border();
    }

    // 根据状态计算目标背景色（颜色全部来自主题）
    function computeTargetColor():Int
    {
        if (isReset)
            return pressing ? UITheme.dangerPress : ((hover || keyboardHighlight) ? UITheme.dangerHover : UITheme.dangerBase);

        if (win8)
            return pressing ? UIControlTheme.accent() : ((hover || keyboardHighlight) ? UIControlTheme.faceHover() : UIControlTheme.face());

        return pressing ? UITheme.controlPress : ((hover || keyboardHighlight) ? UITheme.controlHover : UITheme.control);
    }

    /** 文字颜色（Win8 按下时底色是强调色，文字转白） */
    function computeTextColor():FlxColor
    {
        if (isReset) return confirmPending ? UITheme.danger : UITheme.textPrimary;
        if (win8) return pressing ? UIControlTheme.onAccent() : ((hover || keyboardHighlight) ? UIControlTheme.accent() : UIControlTheme.text());
        return (hover || keyboardHighlight) ? UITheme.accent : UITheme.textPrimary;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        if (!follow.allowUpdate) return;

        var mouse = FlxG.mouse;
        var wasHover = hover;
        hover = OptionInput.overlaps(bg);

        // 悬浮状态变化 → tween 渐变（和 CategoryCard 一致）
        if (hover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
            if (border != null) border.color = borderColor();
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
            actionText.color = computeTextColor();
        }

        if (hover && mouse.justPressed)
        {
            pressing = true;

            // 按下：快速渐到按下色
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, bg.color, computeTargetColor());
            if (border != null) border.color = borderColor();

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
            FlxTween.color(bg, 0.1, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
            if (border != null) border.color = borderColor();

            if (hover)
            {
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
                if (follow.action != null) follow.action();
            }
        }

        if (!hover && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
            if (border != null) border.color = borderColor();
        }
    }

    /** 动态改按钮文字（比如深浅色切换按钮） */
    public function setActionText(text:String):Void
    {
        if (actionText != null) actionText.text = text;
    }

    /**
     * 键盘选中宿主行时由 Win10OptionRow 调用（见 OptionWidgetFactory.setKeyboardHighlight）。
     * 走和 hover 变化完全同一条渐变路径，只是把来源从鼠标换成键盘。
     * 文字色不用管：update() 里非 reset 按钮每帧都会刷 computeTextColor()。
     */
    public function setKeyboardHighlight(v:Bool):Void
    {
        if (keyboardHighlight == v) return;
        keyboardHighlight = v;

        if (bg != null)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeTargetColor(), {ease: FlxEase.quadOut});
        }
        if (border != null) border.color = borderColor();
    }

    /** 主题切换后重新套用配色（行被重建时无需调用） */
    public function refreshTheme():Void
    {
        if (bg != null) bg.color = computeTargetColor();
        if (border != null) border.color = borderColor();
        if (actionText != null && !isReset)
            actionText.color = computeTextColor();
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
