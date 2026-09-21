package options.objects.backend;

import options.Option;
import backend.UIControlTheme;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * 开关控件
 *
 * Win10 风格：胶囊轨道 + 圆形滑块（原来的样子）
 * Win8  风格：直角方框轨道 + 方形滑块 —— 状态表达方式和 Win10 一样（滑块停靠位置 + 轨道配色），
 *              只是全部走 Metro 的方角语言，并且**不再使用对勾**
 *
 * 具体走哪一套由 backend.UIControlTheme 决定（跟随"控件主题"设置）。
 */
class BoolButton extends FlxSpriteGroup
{
    var bg:Rect;
    var dis:Rect;
    var border:FlxSprite;
    var hitArea:Rect;

    var follow:Option;

    var innerX:Float;
    var innerY:Float;
    var moveForward:Bool = true;

    var hover:Bool = false;
    var pressing:Bool = false;

    /**
     * 键盘选中宿主行时由 Win10OptionRow 置位：让开关看起来和鼠标悬停一样。
     * ⚠️ 只参与**配色**计算，不能并进 `hover`。
     */
    public var keyboardHighlight:Bool = false;

    /** 本次构建时解析出的风格 */
    var win8:Bool = false;

    /**
     * Win8 方形滑块的两个停靠点（相对本组左上角的局部坐标）。
     * 用"绝对目标"而不是"相对位移"，updateDisplay() 被重复调用时才不会累积漂移
     * （键盘改值 + OptionWidgetFactory.refreshValue 会反复触发它）。
     */
    var knobOffX:Float = 0;
    var knobOnX:Float = 0;

    // 颜色统一走主题（深浅色切换由 UITheme 提供），Win8 再套一层 UIControlTheme
    inline function getOffColor():Int return win8 ? UIControlTheme.face() : UITheme.switchOff;
    inline function getOnColor():Int return win8 ? UIControlTheme.accent() : UITheme.switchOn;

    /** Win8 滑块配色：关 = 和描边同色（压在浅色轨道上看得清），开 = 强调色底上的白块 */
    inline function getKnobColor(on:Bool):Int
        return win8 ? (on ? UIControlTheme.onAccent() : UIControlTheme.border()) : UITheme.knob;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:Option)
    {
        super(X, Y);

        UITheme.ensure();

        this.follow = follow;
        innerX = X;
        innerY = Y;
        win8 = UIControlTheme.isWin8();

        var on:Bool = (follow.getValue() == true);

        // 整块区域的透明命中区：两种风格都铺满整个控件尺寸
        hitArea = new Rect(0, 0, width, height, 0, 0, 0x00000000, 0);
        add(hitArea);

        // 滑块边长：两种风格共用同一尺寸，切换"控件主题"时视觉重量保持一致
        var d:Float = height / 1.5;

        if (win8)
        {
            // 直角轨道（"方框"）：Metro 不给圆角
            bg = new Rect(0, 0, width, height, 0, 0, on ? getOnColor() : getOffColor(), 1);
            bg.antialiasing = ClientPrefs.data.antialiasing;
            add(bg);

            // Win8 控件一律带描边。注意不能用 shapeEx.Rect 的 lineStyle（静态缓存会串色），
            // 统一走 UIControlTheme.makeFrameSprite 自绘
            border = UIControlTheme.makeFrameSprite(width, height);
            border.x = bg.x;
            border.y = bg.y;
            border.color = UIControlTheme.border();
            add(border);

            // 方形滑块：左右留 pad，垂直居中
            var pad:Float = (height - d) * 0.5;
            knobOffX = pad;
            knobOnX = width - d - pad;

            // 位置在 add() 之前写进构造函数：add() 的 preAdd 会把本组的 x/y 加进来，
            // 之后再写局部坐标会把滑块弹到屏幕左上角（见 FlxSpriteGroup 坐标语义）
            dis = new Rect(on ? knobOnX : knobOffX, pad, d, d, 0, 0, getKnobColor(on), 1);
            dis.antialiasing = ClientPrefs.data.antialiasing;
            add(dis);
        }
        else
        {
            // 胶囊轨道：圆角 = 高度一半
            var r:Float = height;
            bg = new Rect(0, 0, width, height, r, r, getOffColor(), 1);
            bg.antialiasing = ClientPrefs.data.antialiasing;
            add(bg);

            // 圆形圆点：直径 = height / 1.5，圆角 = 半径
            dis = new Rect(2, 4, d, d, d, d, UITheme.knob, 1);
            dis.antialiasing = ClientPrefs.data.antialiasing;
            add(dis);

            // 初始化位置（不播放动画）
            dis.x = on ? bg.width / 2 + 10 : 0;
            bg.color = on ? getOnColor() : getOffColor();
        }
    }

    /**
     * Win8 模式下同步方形滑块的配色。
     * 轨道底色不在这里直接赋值 —— 交给每帧的 updateBgColor() 平滑过渡，
     * 否则状态一变就硬切，没有滑动动画的观感。
     */
    function refreshWin8():Void
    {
        if (dis != null) dis.color = getKnobColor(follow.getValue() == true);
    }

    /**
     * 键盘选中宿主行时由 Win10OptionRow 调用（见 OptionWidgetFactory.setKeyboardHighlight）。
     * 底色本来就会被每帧的 updateBgColor() 插值收敛，这里顺手把 tween 也切过去，反应更跟手。
     */
    public function setKeyboardHighlight(v:Bool):Void
    {
        if (keyboardHighlight == v) return;
        keyboardHighlight = v;
        refreshBgTween();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        if (!follow.allowUpdate) return;

        var mouse = FlxG.mouse;

        // ---------- 悬停 / 按下状态（只做视觉反馈，不影响点击判定） ----------
        var wasHover = hover;
        hover = OptionInput.overlaps(hitArea);

        if (hover != wasHover)
        {
            refreshBgTween();
        }

        if (hover && mouse.justPressed)
        {
            pressing = true;
            refreshBgTween(true);
        }

        // ---------- 点击判定：保持原逻辑 ----------
        if (FlxG.mouse.justPressed && OptionInput.overlaps(hitArea))
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
        else if (hover || keyboardHighlight) return UITheme.hoverTint(base);

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

        var on:Bool = (follow.getValue() == true);
        var targetX:Float;

        if (win8)
        {
            // 方形滑块滑到两个停靠点之一。这里要写"本组 x + 局部停靠点"：
            // 子元素坐标是绝对的（preAdd 已经把本组 x/y 烘焙进去了）
            targetX = this.x + (on ? knobOnX : knobOffX);
            refreshWin8();
        }
        else
        {
            // 保留原来的相对位移设计：
            // 关 -> 开：+（bg.width/2 + 1）
            // 开 -> 关：-（bg.width/2 + 1）
            targetX = dis.x + (on ? bg.width / 2 + 10 : -(bg.width / 2 + 10));
        }

        moveTween = FlxTween.tween(dis, { x: targetX }, 0.2, { ease: FlxEase.quadOut });
    }

    function updateBgColor(elapsed:Float = 0)
    {
        var targetColor = computeTargetColor();
        bg.color = FlxColor.interpolate(bg.color, targetColor, 0.2);
    }

    /** 主题/控件风格切换后重新套用配色 */
    public function refreshTheme():Void
    {
        if (border != null) border.color = UIControlTheme.border();

        if (win8) refreshWin8();
        else if (dis != null) dis.color = UITheme.knob;
    }
}
