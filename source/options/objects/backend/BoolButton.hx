package options.objects.backend;

import options.Option;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class BoolButton extends FlxSpriteGroup
{
    var bg:Rect;
    var dis:Rect;

    var follow:Option;

    var innerX:Float;
    var innerY:Float;
    var moveForward:Bool = true;

    var hover:Bool = false;
    var pressing:Bool = false;

    // 颜色统一走主题（深浅色切换由 UITheme 提供）
    inline function getOffColor():Int return UITheme.switchOff;
    inline function getOnColor():Int return UITheme.switchOn;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:Option)
    {
        super(X, Y);

        UITheme.ensure();

        this.follow = follow;
        innerX = X;
        innerY = Y;

        // 胶囊轨道：圆角 = 高度一半
        var r:Float = height;
        bg = new Rect(0, 0, width, height, r, r, getOffColor(), 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        // 圆形圆点：直径 = height - 6，圆角 = 半径
        var d:Float = height / 1.5;
        var kr:Float = d;
        dis = new Rect(2, 4, d, d, kr, kr, UITheme.knob, 1);
        dis.antialiasing = ClientPrefs.data.antialiasing;
        add(dis);

        // 初始化位置（不播放动画）
        dis.x = follow.getValue() ? bg.width / 2 + 10 : 0;
        bg.color = follow.getValue() ? getOnColor() : getOffColor();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        if (!follow.allowUpdate) return;

        var mouse = FlxG.mouse;

        // ---------- 悬停 / 按下状态（只做视觉反馈，不影响点击判定） ----------
        var wasHover = hover;
        hover = mouse.overlaps(bg);

        if (hover != wasHover)
        {
            // 不直接改 bg.color（updateBgColor 每帧在插值），
            // 而是触发一次"目标色重算"：用 tween 快速逼近
            refreshBgTween();
        }

        if (hover && mouse.justPressed)
        {
            pressing = true;
            refreshBgTween(true);
        }

        // ---------- 点击判定：保持原逻辑 ----------
        if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(bg))
        {
            var nextValue:Bool = !(follow.getValue() == true);
            follow.setValue(nextValue);
            follow.change();
            follow.saveCurrentValue();
            updateDisplay();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        }

        if (mouse.justReleased && pressing)
        {
            pressing = false;
            refreshBgTween();
        }

        // 每帧平滑逼近目标色（原逻辑保留，作为兜底）
        updateBgColor(elapsed);
    }

    // 计算当前状态的目标背景色
    function computeTargetColor():Int
    {
        var base:FlxColor = follow.getValue() ? getOnColor() : getOffColor();

        if (pressing) return UITheme.pressTint(base);
        else if (hover) return UITheme.hoverTint(base);

        return base;
    }

    // 用 tween 让 bg.color 快速趋近目标（短期渐变），
    // 每帧 updateBgColor 仍会继续做细微收敛。
    function refreshBgTween(isPress:Bool = false)
    {
        FlxTween.cancelTweensOf(bg);
        var target = computeTargetColor();
        var dur = isPress ? 0.05 : 0.12;
        FlxTween.color(bg, dur, bg.color, target, {ease: FlxEase.quadOut});
    }

    var moveTween:FlxTween;
    public function updateDisplay()
    {
        if (moveTween != null) moveTween.cancel();

        // 保留原来的相对位移设计：
        // 关 -> 开：+（bg.width/2 + 1）
        // 开 -> 关：-（bg.width/2 + 1）
        var targetX = follow.getValue() ?  bg.width / 2 + 10: -(bg.width / 2 + 10);

        moveTween = FlxTween.tween(dis, { x: dis.x + targetX }, 0.2, { ease: FlxEase.quadOut });
    }

    function updateBgColor(elapsed:Float = 0)
    {
        var targetColor = computeTargetColor();
        bg.color = FlxColor.interpolate(bg.color, targetColor, 0.2);
    }
}