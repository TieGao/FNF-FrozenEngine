package options.objects.backend;

import options.psychoptions.PsychOption;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

class StringSelect extends FlxSpriteGroup
{
    var follow:PsychOption;

    var bg:Rect;          // 当前值的条
    var dis:FlxText;

    var popup:FlxSpriteGroup;   // 展开的下拉
    var popupBg:Rect;
    var popupItems:Array<Rect> = [];
    var popupTexts:Array<FlxText> = [];

    var topLayer:FlxSpriteGroup;

    public var isOpen:Bool = false;
    var mainW:Float;
    var mainH:Float;

    // 状态
    var hover:Bool = false;
    var pressing:Bool = false;

    // 主条颜色
    static inline var NORMAL:Int = 0xFF3A3A3A;
    static inline var HOVER:Int  = 0xFF4A4A4A;
    static inline var PRESS:Int  = 0xFF2B2B2B;
    static inline var ACCENT:Int = 0xFF4CC2FF;

    // 下拉项颜色
    static inline var ITEM_NORMAL:Int = 0xFF3A3A3A;
    static inline var ITEM_HOVER:Int  = 0xFF4A4A4A;

    // 手动绘制的箭头
    var arrowGfx:FlxSprite;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:PsychOption, ?topLayer:FlxSpriteGroup)
    {
        super(X, Y);
        this.follow = follow;
        this.topLayer = topLayer;
        mainW = width; mainH = height;

        bg = new Rect(0, 0, width, height, 4, 4, NORMAL, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        dis = new FlxText(10, 0, width - 30, '', 16);
        dis.setFormat(Paths.font('montserrat.ttf'), 16,
            0xFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        dis.borderStyle = NONE;
        dis.antialiasing = ClientPrefs.data.antialiasing;
        dis.y = (height - dis.height) * 0.5;
        add(dis);

        // 手动绘制箭头：位置在这里固定一次
        arrowGfx = new FlxSprite();
        arrowGfx.antialiasing = ClientPrefs.data.antialiasing;
        arrowGfx.x = width - arrowGfx.width - 16;   // 先占位，redraw 会重设尺寸
        arrowGfx.y = height * 0.4;
        add(arrowGfx);
        redrawArrow();

        refreshText();

        // popup 默认隐藏
        popup = new FlxSpriteGroup();
        popup.visible = false;
        popup.x = this.x;
        popup.y = this.y + height + 4;

        if (topLayer != null)
            topLayer.add(popup);
        else
            add(popup);
    }

    function refreshText()
    {
        var v = follow.getValue();
        dis.text = follow.getOptionText(v);
    }

    function syncPopupPosition()
    {
        if (popup == null) return;

        if (topLayer != null)
        {
            popup.x = this.x;
            popup.y = this.y + mainH + 4;
        }
        else
        {
            popup.x = 0;
            popup.y = mainH + 4;
        }
    }

    function redrawArrow()
    {
        var size = mainH * 0.18;
        var thickness = Math.max(1.5, mainH * 0.05);
        var w = Std.int(size * 2 + thickness + 2);
        var h = Std.int(size + thickness + 2);

        var bmd = new openfl.display.BitmapData(w, h, true, 0x00000000);

        var cx = w * 0.5;
        var cy = h * 0.5;
        var dir = isOpen ? -1.0 : 1.0;

        var col = (hover || isOpen) ? ACCENT : 0xCCCCCC;
        var c:FlxColor = col;

        drawThickLine(bmd,
            cx - size, cy - size * 0.4 * dir,
            cx,        cy + size * 0.4 * dir,
            thickness, c);

        drawThickLine(bmd,
            cx,        cy + size * 0.4 * dir,
            cx + size, cy - size * 0.4 * dir,
            thickness, c);

        arrowGfx.pixels = bmd;
        arrowGfx.offset.set(0, 0);
        arrowGfx.origin.set(0, 0);
        arrowGfx.scale.set(1, 1);
        arrowGfx.updateHitbox();
    }

    function drawThickLine(bmd:openfl.display.BitmapData,
                           x1:Float, y1:Float, x2:Float, y2:Float,
                           thickness:Float, color:FlxColor)
    {
        var dx = x2 - x1;
        var dy = y2 - y1;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len == 0) return;
        var nx = dx / len;
        var ny = dy / len;
        var half = thickness * 0.5;

        // 用矩形填充近似粗线
        var steps = Std.int(len);
        for (i in 0...steps + 1)
        {
            var t = i / steps;
            var px = x1 + dx * t;
            var py = y1 + dy * t;
            // 沿线垂直方向填充厚度
            var perpX = -ny;
            var perpY = nx;
            for (j in 0...Std.int(thickness) + 1)
            {
                var off = -half + j;
                var fx = Std.int(px + perpX * off);
                var fy = Std.int(py + perpY * off);
                if (fx >= 0 && fy >= 0 && fx < bmd.width && fy < bmd.height)
                    bmd.setPixel32(fx, fy, color);
            }
        }
    }

    function buildPopup()
    {
        // 清空
        for (m in popup.members) popup.remove(m, true);
        popupItems = [];
        popupTexts = [];

        var opts = follow.options;
        if (opts == null) return;

        var itemH = 32.0;
        popupBg = new Rect(0, 0, mainW, opts.length * itemH + 8, 4, 4, 0xFF2B2B2B, 1);
        popupBg.antialiasing = ClientPrefs.data.antialiasing;
        popup.add(popupBg);

        for (i in 0...opts.length)
        {
            var item = new Rect(4, 4 + i * itemH, mainW - 8, itemH, 3, 3, ITEM_NORMAL, 0);
            item.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(item);
            popupItems.push(item);

            var t = new FlxText(12, 4 + i * itemH, mainW - 24, follow.getOptionText(opts[i]), 15);
            t.setFormat(Paths.font('montserrat.ttf'), 15,
                0xFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
            t.borderStyle = NONE;
            t.antialiasing = ClientPrefs.data.antialiasing;
            t.y += (itemH - t.height) * 0.5;
            popup.add(t);
            popupTexts.push(t);
        }
    }

    // 主条目标颜色
    function computeMainColor():Int
    {
        return pressing ? PRESS : (hover ? HOVER : NORMAL);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        syncPopupPosition();
        var mouse = FlxG.mouse;

        // ---- 主条悬浮/按下反馈 ----
        var wasHover = hover;
        hover = mouse.overlaps(bg);

        if (hover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
            redrawArrow(); // 箭头颜色/方向跟随状态
        }

        // 文字颜色随悬浮变化
        dis.color = (hover || isOpen) ? ACCENT : 0xFFFFFF;

        // 点击主条
        if (hover && mouse.justPressed)
        {
            pressing = true;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, bg.color, computeMainColor());
        }

        if (mouse.justReleased && pressing && hover)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeMainColor(), {ease: FlxEase.quadOut});

            isOpen = !isOpen;
            if (isOpen) { buildPopup(); popup.visible = true; }
            else popup.visible = false;
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);

            redrawArrow(); // 翻转箭头
        }

        if (!hover && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
        }

        // ---- 下拉项反馈 ----
        if (!isOpen) return;

        for (i in 0...popupItems.length)
        {
            var it = popupItems[i];
            var itHover = mouse.overlaps(it);

            it.alpha = itHover ? 1.0 : 0.0;

            if (itHover && mouse.justReleased)
            {
                follow.setValue(follow.options[i]);
                follow.change();
                follow.saveCurrentValue();
                refreshText();
                isOpen = false;
                popup.visible = false;
                redrawArrow();
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
                return;
            }
        }

        // 点外面关闭
        if (mouse.justPressed && !mouse.overlaps(bg))
        {
            var inPopup = false;
            for (it in popupItems)
            {
                if (mouse.overlaps(it)) { inPopup = true; break; }
            }
            if (!inPopup) { isOpen = false; popup.visible = false; redrawArrow(); }
        }
    }
}