package options.objects.backend;

import options.Option;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

class ColorSelect extends FlxSpriteGroup
{
    var follow:Option;

    var bg:Rect;          // 当前颜色的条
    var swatch:FlxSprite; // 左侧颜色块
    var dis:FlxText;

    var popup:FlxSpriteGroup;   // 展开的调色板
    var popupBg:Rect;
    var popupItems:Array<Rect> = [];
    var popupTexts:Array<FlxText> = [];
    var popupSwatches:Array<FlxSprite> = [];

    var topLayer:FlxSpriteGroup;

    public var isOpen:Bool = false;
    var mainW:Float;
    var mainH:Float;

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

    // 调色板每行列数
    static inline var COLS:Int = 4;
    static inline var CELL:Float = 40.0;
    static inline var CELL_PAD:Float = 6.0;

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

        // 左侧色块
        swatch = new FlxSprite(6, (height - (height - 12)) * 0.5);
        swatch.makeGraphic(Std.int(height - 12), Std.int(height - 12), 0xFFFFFFFF);
        swatch.antialiasing = ClientPrefs.data.antialiasing;
        add(swatch);

        dis = new FlxText(Std.int(height) + 4, 0, width - Std.int(height) - 30, '', 16);
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
        var v:Int = cast follow.getValue();
        swatch.color = v;
        var name = Option.colorName(v);
        var hex = Option.intToHex(v);
        dis.text = name + '   ' + hex;
        dis.color = (hover || isOpen) ? ACCENT : 0xFFFFFF;
    }

    function syncPopupPosition()
    {
        if (popup == null) return;

        // popup 的尺寸（buildPopup 后会更新）
        var pw = popup.width;
        var ph = popup.height;

        // 世界坐标下主条的位置
        var worldX = this.x;
        var worldY = this.y;
        if (topLayer != null)
        {
            // topLayer 自身可能带有偏移，这里取其在父级中的位置
            worldX += topLayer.x;
            worldY += topLayer.y;
        }

        // ---- 垂直：默认在下方，放不下就放到上方 ----
        var belowY = worldY + mainH + 4;
        var aboveY = worldY - ph - 4;

        var finalWorldY:Float;
        if (belowY + ph <= FlxG.height)
            finalWorldY = belowY;                    // 下方放得下
        else if (aboveY >= 0)
            finalWorldY = aboveY;                    // 下方放不下，改放上方
        else
            finalWorldY = Math.max(0, FlxG.height - ph); // 上下都放不下，贴底

        // ---- 水平：默认对齐左边，右边超出就左移 ----
        var finalWorldX = worldX;
        if (finalWorldX + pw > FlxG.width)
            finalWorldX = FlxG.width - pw;
        if (finalWorldX < 0)
            finalWorldX = 0;

        // ---- 换算回 popup 所属容器的局部坐标 ----
        if (topLayer != null)
        {
            popup.x = finalWorldX - topLayer.x;
            popup.y = finalWorldY - topLayer.y;
        }
        else
        {
            // 挂在 this 上时，popup 坐标是相对 this 的
            popup.x = finalWorldX - this.x;
            popup.y = finalWorldY - this.y;
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

        arrowGfx.x = mainW - arrowGfx.width - 16;
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
        popupSwatches = [];

        var pal = Option.COLOR_PALETTE;
        var rows = Math.ceil(pal.length / COLS);
        var gridW = COLS * CELL + (COLS - 1) * CELL_PAD;
        var gridH = rows * CELL + (rows - 1) * CELL_PAD;
        var popupW = gridW + CELL_PAD * 2;
        var popupH = gridH + CELL_PAD * 2;

        popupBg = new Rect(0, 0, popupW, popupH, 4, 4, 0xFF2B2B2B, 1);
        popupBg.antialiasing = ClientPrefs.data.antialiasing;
        popup.add(popupBg);

        for (i in 0...pal.length)
        {
            var col = i % COLS;
            var row = Std.int(i / COLS);
            var cx = CELL_PAD + col * (CELL + CELL_PAD);
            var cy = CELL_PAD + row * (CELL + CELL_PAD);

            // 色块
            var cell = new Rect(cx, cy, CELL, CELL, 3, 3, pal[i], 1);
            cell.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(cell);
            popupItems.push(cell);

            // 选中/悬浮高亮描边
            var outline = new Rect(cx - 2, cy - 2, CELL + 4, CELL + 4, 4, 4, ACCENT, 0);
            outline.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(outline);
            popupSwatches.push(outline);

            // 名称（画在色块中心，用对比色）
            var t = new FlxText(cx, cy, CELL, Option.COLOR_NAMES[i], 10);
            t.setFormat(Paths.font('montserrat.ttf'), 10,
                Option.contrastText(pal[i]), CENTER, FlxTextBorderStyle.OUTLINE, 0xFF000000);
            t.borderStyle = NONE;
            t.antialiasing = ClientPrefs.data.antialiasing;
            t.x = cx + (CELL - t.width) * 0.5;
            t.y = cy + (CELL - t.height) * 0.5;
            popup.add(t);
            popupTexts.push(t);
        }
        syncPopupPosition();
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

        var wasHover = hover;
        hover = mouse.overlaps(bg);

        if (hover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
            redrawArrow();
            refreshText();
        }

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

            redrawArrow();
            refreshText();
        }

        if (!hover && pressing)
        {
            pressing = false;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.1, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
        }

        if (!isOpen) return;

        // 下拉项反馈
        for (i in 0...popupItems.length)
        {
            var it = popupItems[i];
            var itHover = mouse.overlaps(it);

            // 高亮描边
            popupSwatches[i].alpha = itHover ? 1.0 : 0.0;

            if (itHover && mouse.justReleased)
            {
                var newColor:Int = Option.COLOR_PALETTE[i];
                follow.setValue(newColor);
                follow.curOption = i;
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
            if (!inPopup) { isOpen = false; popup.visible = false; redrawArrow(); refreshText(); }
        }
    }
}