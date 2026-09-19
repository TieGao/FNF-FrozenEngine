package options.objects.backend;

import options.Option;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

class StringSelect extends FlxSpriteGroup
{
    var follow:Option;

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

    // 下拉项尺寸 / 边缘留白
    static inline var ITEM_H:Float = 32.0;
    static inline var EDGE_MARGIN:Float = 4.0;

    // 手动绘制的箭头
    var arrowGfx:FlxSprite;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:Option, ?topLayer:FlxSpriteGroup)
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

        arrowGfx = new FlxSprite();
        arrowGfx.antialiasing = ClientPrefs.data.antialiasing;
        arrowGfx.x = width - arrowGfx.width - 16;
        arrowGfx.y = height * 0.4;
        add(arrowGfx);
        redrawArrow();

        refreshText();

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

    function getPopupHeight():Float
    {
        var opts = follow.options;
        if (opts == null || opts.length == 0) return 0;
        return opts.length * ITEM_H + 8;
    }

    function syncPopupPosition()
    {
        if (popup == null) return;

        var popupH = getPopupHeight();
        if (popupH <= 0) return;

        var viewX = this.x;
        var viewY:Float;

        var belowY = this.y + mainH + 4;
        var aboveY = this.y - popupH - 4;
        var maxBottom = FlxG.height - EDGE_MARGIN;

        if (belowY + popupH <= maxBottom)
        {
            // 1. 下方放得下
            viewY = belowY;
        }
        else if (aboveY >= EDGE_MARGIN)
        {
            // 2. 上方放得下
            viewY = aboveY;
        }
        else
        {
            // 3. 上下都放不下 → 直接覆盖在组件上，居中并夹取到屏幕内
            viewY = this.y + mainH * 0.5 - popupH * 0.5;
            if (viewY + popupH > maxBottom)
                viewY = maxBottom - popupH;
            if (viewY < EDGE_MARGIN)
                viewY = EDGE_MARGIN;
        }

        // 水平方向夹取
        if (viewX + mainW > FlxG.width - EDGE_MARGIN)
            viewX = FlxG.width - mainW - EDGE_MARGIN;
        if (viewX < EDGE_MARGIN)
            viewX = EDGE_MARGIN;

        if (topLayer != null)
        {
            popup.x = viewX;
            popup.y = viewY;
        }
        else
        {
            popup.x = viewX - this.x;
            popup.y = viewY - this.y;
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

        var steps = Std.int(len);
        for (i in 0...steps + 1)
        {
            var t = i / steps;
            var px = x1 + dx * t;
            var py = y1 + dy * t;
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
        for (m in popup.members) popup.remove(m, true);
        popupItems = [];
        popupTexts = [];

        var opts = follow.options;
        if (opts == null) return;

        popupBg = new Rect(0, 0, mainW, opts.length * ITEM_H + 8, 4, 4, 0xFF2B2B2B, 1);
        popupBg.antialiasing = ClientPrefs.data.antialiasing;
        popup.add(popupBg);

        for (i in 0...opts.length)
        {
            var item = new Rect(4, 4 + i * ITEM_H, mainW - 8, ITEM_H, 3, 3, ITEM_NORMAL, 0);
            item.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(item);
            popupItems.push(item);

            var t = new FlxText(12, 4 + i * ITEM_H, mainW - 24, follow.getOptionText(opts[i]), 15);
            t.setFormat(Paths.font('montserrat.ttf'), 15,
                0xFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
            t.borderStyle = NONE;
            t.antialiasing = ClientPrefs.data.antialiasing;
            t.y += (ITEM_H - t.height) * 0.5;
            popup.add(t);
            popupTexts.push(t);
        }
    }

    function computeMainColor():Int
    {
        return pressing ? PRESS : (hover ? HOVER : NORMAL);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        syncPopupPosition();
        var mouse = FlxG.mouse;

        // 如果鼠标在下拉菜单上，主条不再抢悬停（避免覆盖时误判）
        var overPopup = isOpen && popup.visible && popupBg != null && mouse.overlaps(popupBg);

        // ---- 主条悬浮/按下反馈 ----
        var wasHover = hover;
        hover = mouse.overlaps(bg) && !overPopup;

        if (hover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
            redrawArrow();
        }

        dis.color = (hover || isOpen) ? ACCENT : 0xFFFFFF;

        // 点击主条
        if (hover && mouse.justPressed)
        {
            pressing = true;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.05, bg.color, computeMainColor());
        }

        // 本帧刚打开下拉时，消费这次释放事件，防止同一次点击被下拉项再次处理
        var openedThisFrame:Bool = false;

        if (mouse.justReleased && pressing && hover)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeMainColor(), {ease: FlxEase.quadOut});

            isOpen = !isOpen;
            if (isOpen)
            {
                buildPopup();
                syncPopupPosition();
                popup.visible = true;
                openedThisFrame = true;
            }
            else
            {
                popup.visible = false;
            }
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);

            redrawArrow();
        }

        if (!hover && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
        }

        // ---- 下拉项反馈 ----
        if (!isOpen) return;
        if (openedThisFrame) return; // 打开那一帧不处理，避免误触

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

        // 点外面关闭（主条和弹窗都不算外面）
        if (mouse.justPressed && !mouse.overlaps(bg) && !overPopup)
        {
            isOpen = false;
            popup.visible = false;
            redrawArrow();
        }
    }
}