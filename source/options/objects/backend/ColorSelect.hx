package options.objects.backend;

import options.Option;
import backend.UIControlTheme;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

/**
 * 颜色选项（色块 + 名称/HEX + 展开调色板）
 *
 * Win10 风格：4px 圆角、无描边
 * Win8  风格：方角 + 2px 描边
 */
class ColorSelect extends FlxSpriteGroup
{
    var follow:Option;

    var bg:Rect;          // 当前颜色的条
    var border:FlxSprite; // Win8 描边
    var swatch:FlxSprite; // 左侧颜色块
    var dis:FlxText;

    var popup:FlxSpriteGroup;   // 展开的调色板
    var popupBg:Rect;
    var popupBorder:FlxSprite;
    var popupItems:Array<Rect> = [];
    var popupTexts:Array<FlxText> = [];
    var popupSwatches:Array<Rect> = [];

    var topLayer:FlxSpriteGroup;

    public var isOpen:Bool = false;
    var mainW:Float;
    var mainH:Float;

    /** 本次构建时解析出的风格 */
    var win8:Bool = false;

    var hover:Bool = false;
    var pressing:Bool = false;

    // 调色板每行列数
    static inline var COLS:Int = 4;
    static inline var CELL:Float = 40.0;
    static inline var CELL_PAD:Float = 6.0;

    var arrowGfx:FlxSprite;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:Option, ?topLayer:FlxSpriteGroup)
    {
        super(X, Y);
        UITheme.ensure();

        this.follow = follow;
        this.topLayer = topLayer;
        mainW = width; mainH = height;
        win8 = UIControlTheme.isWin8();

        bg = new Rect(0, 0, width, height, UIControlTheme.radius(4), UIControlTheme.radius(4),
            win8 ? UIControlTheme.face() : UITheme.control, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        if (win8)
        {
            border = UIControlTheme.makeFrameSprite(width, height);
            border.color = borderColor();
            add(border);
        }

        // 左侧色块（Win8 用方角）
        swatch = new FlxSprite(6, (height - (height - 12)) * 0.5);
        swatch.makeGraphic(Std.int(height - 12), Std.int(height - 12), 0xFFFFFFFF);
        swatch.antialiasing = ClientPrefs.data.antialiasing;
        add(swatch);

        dis = new FlxText(Std.int(height) + 4, 0, width - Std.int(height) - 30, '', 16);
        dis.setFormat(Paths.font('montserrat.ttf'), 16, mainTextColor(), LEFT);
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

        refreshValue();

        popup = new FlxSpriteGroup();
        popup.visible = false;
        popup.x = this.x;
        popup.y = this.y + height + 4;

        if (topLayer != null)
            topLayer.add(popup);
        else
            add(popup);
    }

    // ---------------------------------------------------------
    // 配色
    // ---------------------------------------------------------
    inline function accentColor():FlxColor
        return win8 ? UIControlTheme.accent() : UITheme.accent;

    inline function mainTextColor():FlxColor
        return win8 ? UIControlTheme.text() : UITheme.textPrimary;

    inline function popupBGColor():FlxColor
        return win8 ? UIControlTheme.panelBG() : UITheme.popup;

    inline function iconColor():FlxColor
        return win8 ? UIControlTheme.textSecondary() : UITheme.icon;

    function borderColor():FlxColor
        return (hover || isOpen || keyboardHighlight) ? UIControlTheme.accent() : UIControlTheme.border();

    public function refreshValue()
    {
        var v:Int = cast follow.getValue();
        swatch.color = v;
        var name = Option.colorName(v);
        var hex = Option.intToHex(v);
        dis.text = name + '   ' + hex;
        dis.color = (hover || isOpen || keyboardHighlight) ? accentColor() : mainTextColor();
        if (border != null) border.color = borderColor();
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

        var col = (hover || isOpen || keyboardHighlight) ? accentColor() : iconColor();
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
        popupSwatches = [];

        var pal = Option.COLOR_PALETTE;
        var rows = Math.ceil(pal.length / COLS);
        var gridW = COLS * CELL + (COLS - 1) * CELL_PAD;
        var gridH = rows * CELL + (rows - 1) * CELL_PAD;
        var popupW = gridW + CELL_PAD * 2;
        var popupH = gridH + CELL_PAD * 2;
        var r:Float = UIControlTheme.radius(4);

        popupBg = new Rect(0, 0, popupW, popupH, r, r, popupBGColor(), 1);
        popupBg.antialiasing = ClientPrefs.data.antialiasing;
        popup.add(popupBg);

        popupBorder = null;
        if (win8)
        {
            popupBorder = UIControlTheme.makeFrameSprite(popupW, popupH);
            popupBorder.color = UIControlTheme.border();
            popup.add(popupBorder);
        }

        for (i in 0...pal.length)
        {
            var col = i % COLS;
            var row = Std.int(i / COLS);
            var cx = CELL_PAD + col * (CELL + CELL_PAD);
            var cy = CELL_PAD + row * (CELL + CELL_PAD);

            // 色块
            var cell = new Rect(cx, cy, CELL, CELL, UIControlTheme.radius(3), UIControlTheme.radius(3), pal[i], 1);
            cell.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(cell);
            popupItems.push(cell);

            // 选中/悬浮高亮描边
            var outline = new Rect(cx - 2, cy - 2, CELL + 4, CELL + 4, UIControlTheme.radius(4), UIControlTheme.radius(4),
                accentColor(), 0);
            outline.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(outline);
            popupSwatches.push(outline);

            // 名称（画在色块中心，用对比色）
            var t = new FlxText(cx, cy, CELL, Option.COLOR_NAMES[i], 10);
            t.setFormat(Paths.font('montserrat.ttf'), 10,
                Option.contrastText(pal[i]), CENTER);
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
        if (win8)
            return pressing ? UIControlTheme.facePress() : ((hover || keyboardHighlight) ? UIControlTheme.faceHover() : UIControlTheme.face());
        return pressing ? UITheme.controlPress : ((hover || keyboardHighlight) ? UITheme.controlHover : UITheme.control);
    }

    /**
     * 键盘选中宿主行时由 Win10OptionRow 置位：让颜色条看起来和鼠标悬停一样。
     * ⚠️ 只参与**配色**计算，绝不能并进 `hover` —— update() 里 `hover && mouse.justPressed` /
     * `mouse.justReleased && pressing && hover` 都是点击门控，并进去就变成"鼠标点哪都触发"。
     */
    public var keyboardHighlight:Bool = false;

    /**
     * 键盘选中宿主行时由 Win10OptionRow 调用（见 OptionWidgetFactory.setKeyboardHighlight）。
     * 走和 hover 变化同一条路径：底色 tween + 箭头重画 + 文字/边框配色。
     */
    public function setKeyboardHighlight(v:Bool):Void
    {
        if (keyboardHighlight == v) return;
        keyboardHighlight = v;

        if (bg != null)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
        }
        redrawArrow();
        refreshValue();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        syncPopupPosition();
        var mouse = FlxG.mouse;

        var wasHover = hover;
        hover = OptionInput.overlaps(bg);

        if (hover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
            redrawArrow();
            refreshValue();
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
            refreshValue();
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
            var itHover = OptionInput.overlaps(it);

            // 高亮描边
            popupSwatches[i].alpha = itHover ? 1.0 : 0.0;

            if (itHover && mouse.justReleased)
            {
                var newColor:Int = Option.COLOR_PALETTE[i];
                follow.setValue(newColor);
                follow.curOption = i;
                follow.change();
                follow.saveCurrentValue();
                refreshValue();
                isOpen = false;
                popup.visible = false;
                redrawArrow();
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
                return;
            }
        }

        // 点外面关闭
        if (mouse.justPressed && !OptionInput.overlaps(bg))
        {
            var inPopup = false;
            for (it in popupItems)
            {
                if (OptionInput.overlaps(it)) { inPopup = true; break; }
            }
            if (!inPopup) { isOpen = false; popup.visible = false; redrawArrow(); refreshValue(); }
        }
    }

    /** 关闭调色板（键盘切换到别的行时用） */
    public function closePopup():Void
    {
        if (!isOpen) return;
        isOpen = false;
        if (popup != null) popup.visible = false;
        redrawArrow();
        refreshValue();
    }

    /** 主题切换后重新套用配色（行被重建时无需调用） */
    public function refreshTheme():Void
    {
        if (bg != null) bg.color = computeMainColor();
        if (border != null) border.color = borderColor();
        if (popupBg != null) popupBg.color = popupBGColor();
        if (popupBorder != null) popupBorder.color = UIControlTheme.border();
        for (o in popupSwatches) o.color = accentColor();
        redrawArrow();
        refreshValue();
    }

    /**
     * 调色板弹层挂在 topLayer（overlayContainer）上，
     * 销毁时手动清掉，避免残留在外层容器里继续渲染。
     */
    override function destroy():Void
    {
        if (popup != null && topLayer != null)
        {
            topLayer.remove(popup, true);
            popup.destroy();
        }
        popup = null;
        super.destroy();
    }
}
