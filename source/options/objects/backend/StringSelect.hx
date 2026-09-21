package options.objects.backend;

import options.Option;
import backend.UIControlTheme;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

/**
 * 字符串选项下拉条
 *
 * Win10 风格：4px 圆角、无描边（原来的样子）
 * Win8  风格：方角 + 2px 描边（Metro 下拉）
 */
class StringSelect extends FlxSpriteGroup
{
    var follow:Option;

    var bg:Rect;          // 当前值的条
    var border:FlxSprite; // Win8 描边
    var dis:FlxText;

    var popup:FlxSpriteGroup;   // 展开的下拉
    var popupBg:Rect;
    var popupBorder:FlxSprite;
    var popupItems:Array<Rect> = [];
    var popupTexts:Array<FlxText> = [];

    var topLayer:FlxSpriteGroup;

    public var isOpen:Bool = false;
    var mainW:Float;
    var mainH:Float;

    /** 本次构建时解析出的风格 */
    var win8:Bool = false;

    // 状态
    var hover:Bool = false;
    var pressing:Bool = false;

    // 下拉项尺寸 / 边缘留白
    static inline var ITEM_H:Float = 32.0;
    static inline var EDGE_MARGIN:Float = 4.0;

    // 手动绘制的箭头
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

        dis = new FlxText(10, 0, width - 30, '', 16);
        dis.setFormat(Paths.font('montserrat.ttf'), 16, textColor(), LEFT);
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

    inline function accentColor():FlxColor
        return win8 ? UIControlTheme.accent() : UITheme.accent;

    inline function mainTextColor():FlxColor
        return win8 ? UIControlTheme.text() : UITheme.textPrimary;

    inline function popupBGColor():FlxColor
        return win8 ? UIControlTheme.panelBG() : UITheme.popup;

    inline function popupItemColor():FlxColor
        return win8 ? UIControlTheme.railHover() : UITheme.popupItem;

    inline function iconColor():FlxColor
        return win8 ? UIControlTheme.textSecondary() : UITheme.icon;

    inline function textColor():FlxColor
        return (hover || isOpen || keyboardHighlight) ? accentColor() : mainTextColor();

    function borderColor():FlxColor
        return (hover || isOpen || keyboardHighlight) ? UIControlTheme.accent() : UIControlTheme.border();

    public function refreshValue()
    {
        var v = follow.getValue();
        dis.text = follow.getOptionText(v);
        dis.color = textColor();
        if (border != null) border.color = borderColor();
    }

    /** 下拉可视行数：还原为显示全部选项 */
    function visibleRows():Int
    {
        var opts = follow.options;
        if (opts == null) return 0;
        return opts.length;
    }

    function getPopupHeight():Float
    {
        var n:Int = visibleRows();
        if (n <= 0) return 0;
        return n * ITEM_H + 8;
    }

    /**
     * 还原：不再有滚动偏移，所有项全部可见。
     *
     * ⚠️ FlxSpriteGroup 的成员坐标是**绝对**的：`popup.add(x)` 时 preAdd 已经把
     * popup 自己的 x/y 加进了成员的 x/y，而 FlxSpriteGroup.draw() 只是逐个
     * `member.draw()`，绘制时**不会**再叠加父级偏移。
     * 所以这里必须写 `popup.y + 局部Y`；直接写局部 Y 会让整列文字/高亮跑到屏幕顶部
     * （背景块位置正确、内容却飞到最上面，就是这个原因）。
     */
    function applyPopupScroll():Void
    {
        var oy:Float = (popup != null) ? popup.y : 0;

        for (i in 0...popupItems.length)
        {
            var y:Float = oy + 4 + i * ITEM_H;

            popupItems[i].y = y;
            if (i < popupTexts.length)
                popupTexts[i].y = y + (ITEM_H - popupTexts[i].height) * 0.5;

            popupItems[i].visible = true;
            if (i < popupTexts.length) popupTexts[i].visible = true;
        }
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

        // popup 的子元素坐标是绝对的（preAdd 已把 popup 自身的 x/y 加进去，绘制时不再叠加父级），
        // 所以不管挂在 topLayer 还是挂在 this 上，这里统一写**世界坐标**即可，
        // 不能再减一次 this.x / this.y（会少偏移一次）。
        popup.x = viewX;
        popup.y = viewY;
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

    /**
     * 清空下拉弹层里的旧成员。
     *
     * 注意：不能在遍历 `popup.members` 的同时 `remove`（splice 会就地删元素，
     * 结果隔一个漏一个，旧项会残留在弹层里变成幽灵行）。
     * 另外必须把 popupBg / popupBorder 置空——它们已经被 destroy，
     * 留着非 null 引用会被 update() 里的 `OptionInput.overlaps(popupBg)` 拿去用，
     * 触发 Null Object Reference。
     */
    function clearPopup():Void
    {
        if (popup == null) return;

        var old = popup.members.copy();
        for (m in old)
        {
            if (m == null) continue;
            popup.remove(m, true);
            m.destroy();
        }

        popupItems = [];
        popupTexts = [];
        popupBg = null;
        popupBorder = null;
    }

    function buildPopup()
    {
        clearPopup();

        var opts = follow.options;
        if (opts == null) return;

        var popupW = mainW;
        var popupH = getPopupHeight();
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

        for (i in 0...opts.length)
        {
            var item = new Rect(4, 4 + i * ITEM_H, popupW - 8, ITEM_H, UIControlTheme.radius(3), UIControlTheme.radius(3),
                popupItemColor(), 0);
            item.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(item);
            popupItems.push(item);

            var t = new FlxText(12, 4 + i * ITEM_H, popupW - 24, follow.getOptionText(opts[i]), 15);
            t.setFormat(Paths.font('montserrat.ttf'), 15, mainTextColor(), LEFT);
            t.borderStyle = NONE;
            t.antialiasing = ClientPrefs.data.antialiasing;
            popup.add(t);
            popupTexts.push(t);
        }

        applyPopupScroll();
    }

    function computeMainColor():Int
    {
        if (win8)
            return pressing ? UIControlTheme.facePress() : ((hover || keyboardHighlight) ? UIControlTheme.faceHover() : UIControlTheme.face());
        return pressing ? UITheme.controlPress : ((hover || keyboardHighlight) ? UITheme.controlHover : UITheme.control);
    }

    /**
     * 键盘选中宿主行时由 Win10OptionRow 置位：让下拉条看起来和鼠标悬停一样。
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

        // 如果鼠标在下拉菜单上，主条不再抢悬停（避免覆盖时误判）
        var overPopup = isOpen && popup.visible && popupBg != null && OptionInput.overlaps(popupBg);

        // ---- 主条悬浮/按下反馈 ----
        var wasHover = hover;
        hover = OptionInput.overlaps(bg) && !overPopup;

        if (hover != wasHover)
        {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.12, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
            redrawArrow();
            refreshValue();
        }

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
            refreshValue();
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
            var itHover = OptionInput.overlaps(it);

            it.alpha = itHover ? 1.0 : 0.0;

            if (itHover && mouse.justReleased)
            {
                follow.setValue(follow.options[i]);
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

        // 点外面关闭（主条和弹窗都不算外面）
        if (mouse.justPressed && !OptionInput.overlaps(bg) && !overPopup)
        {
            isOpen = false;
            popup.visible = false;
            redrawArrow();
            refreshValue();
        }
    }

    /** 关闭下拉（键盘切换到别的行时用） */
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
        for (it in popupItems) it.color = popupItemColor();
        for (t in popupTexts) t.color = mainTextColor();
        redrawArrow();
        refreshValue();
    }

    /**
     * 下拉弹层是挂在 topLayer（overlayContainer）上的，
     * 销毁时如果不手动清掉，会残留在外层容器里继续渲染。
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