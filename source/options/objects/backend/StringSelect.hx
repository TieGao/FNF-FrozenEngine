package options.objects.backend;

import options.Option;
import backend.UIControlTheme;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

/**
 * 字符串选项下拉条
 *
 * Win10 风格：4px 圆角、无描边
 * Win8  风格：方角 + 2px 描边（Metro 下拉）
 *
 * 列表超过 MAX_VISIBLE_ROWS 行时弹层高度封顶，靠滚轮（鼠标悬停弹层上）或上下键翻动，
 * 右侧画一条滑块。键盘回车是「打开列表 → 上下选 → 回车确认」，不再直接循环改值。
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
    /** 列表放不下时右侧的滚动条滑块；放得下时为 null */
    var popupThumb:Rect;

    var topLayer:FlxSpriteGroup;

    public var isOpen:Bool = false;
    var mainW:Float;
    var mainH:Float;

    /** 本次构建时解析出的风格 */
    var win8:Bool = false;

    // 状态
    var hover:Bool = false;
    var pressing:Bool = false;

    /** 下拉里第一个可见项的下标（列表超长时才有意义） */
    var scrollIndex:Int = 0;
    /** 键盘在下拉里高亮的那一项（-1 = 还没用键盘操作过） */
    var keyIndex:Int = -1;

    // 下拉项尺寸 / 边缘留白
    static inline var ITEM_H:Float = 32.0;
    static inline var EDGE_MARGIN:Float = 4.0;

    /**
     * 下拉最多显示多少行，超出的部分靠滚轮 / 上下键翻。
     * 弹层高度因此有上限，长列表（语言、音效之类）不会顶穿屏幕。
     */
    static inline var MAX_VISIBLE_ROWS:Int = 8;
    /** 右侧滚动条的宽度 / 滑块绘制基准高度 */
    static inline var THUMB_W:Float = 3.0;
    static inline var THUMB_BASE_H:Float = 32.0;

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

    /** 下拉可视行数：最多 MAX_VISIBLE_ROWS 行 */
    function visibleRows():Int
    {
        var opts = follow.options;
        if (opts == null) return 0;
        return opts.length > MAX_VISIBLE_ROWS ? MAX_VISIBLE_ROWS : opts.length;
    }

    /** 还能往下滚多少项（0 = 列表放得下，不用滚） */
    function maxScrollIndex():Int
    {
        var opts = follow.options;
        if (opts == null) return 0;
        var m:Int = opts.length - visibleRows();
        return m > 0 ? m : 0;
    }

    /** 当前值在 options 里的下标 */
    function currentOptionIndex():Int
    {
        var opts = follow.options;
        if (opts == null || opts.length == 0) return 0;

        var i:Int = opts.indexOf(Std.string(follow.getValue()));
        if (i < 0) i = follow.curOption;
        return Std.int(FlxMath.bound(i, 0, opts.length - 1));
    }

    /** 把下标 idx 的项滚进可视窗口 */
    function scrollToShow(idx:Int):Void
    {
        var rows:Int = visibleRows();
        if (rows <= 0) return;

        if (scrollIndex > idx) scrollIndex = idx;
        else if (idx >= scrollIndex + rows) scrollIndex = idx - rows + 1;

        scrollIndex = Std.int(FlxMath.bound(scrollIndex, 0, maxScrollIndex()));
    }

    function getPopupHeight():Float
    {
        var n:Int = visibleRows();
        if (n <= 0) return 0;
        return n * ITEM_H + 8;
    }

    /**
     * 按 scrollIndex 重新摆放下拉项（滚出窗口的项直接隐藏）。
     *
     * ⚠️ FlxSpriteGroup 的成员坐标是**绝对**的：`popup.add(x)` 时 preAdd 已经把
     * popup 自己的 x/y 加进了成员的 x/y，而 FlxSpriteGroup.draw() 只是逐个
     * `member.draw()`，绘制时**不会**再叠加父级偏移。
     * 所以这里必须写 `popup.y + 局部Y`；直接写局部 Y 会让整列文字/高亮跑到屏幕顶部
     * （背景块位置正确、内容却飞到最上面，就是这个原因）。
     * 同理，弹层位置一变（syncPopupPosition）就得重跑一遍，否则内容会和背景错位。
     */
    function applyPopupScroll():Void
    {
        var oy:Float = (popup != null) ? popup.y : 0;
        var rows:Int = visibleRows();

        for (i in 0...popupItems.length)
        {
            var slot:Int = i - scrollIndex;
            var inView:Bool = slot >= 0 && slot < rows;
            var y:Float = oy + 4 + slot * ITEM_H;

            popupItems[i].y = y;
            if (i < popupTexts.length)
                popupTexts[i].y = y + (ITEM_H - popupTexts[i].height) * 0.5;

            popupItems[i].visible = inView;
            if (i < popupTexts.length) popupTexts[i].visible = inView;

            popupItems[i].alpha = (inView && i == keyIndex) ? 1.0 : 0.0;
        }

        updateThumb();
    }

    /** 列表放不下时，右侧滑块标出当前滚到哪一段 */
    function updateThumb():Void
    {
        if (popupThumb == null) return;

        var total:Int = popupItems.length;
        var rows:Int = visibleRows();
        if (rows <= 0 || total <= rows)
        {
            popupThumb.visible = false;
            return;
        }

        var trackH:Float = rows * ITEM_H;
        var h:Float = Math.max(18, trackH * rows / total);
        var maxIdx:Int = maxScrollIndex();

        popupThumb.visible = true;
        popupThumb.setGraphicSize(Std.int(THUMB_W), Std.int(h));
        popupThumb.updateHitbox();
        popupThumb.x = popup.x + mainW - THUMB_W - 3;
        popupThumb.y = popup.y + 4 + (trackH - h) * (maxIdx > 0 ? scrollIndex / maxIdx : 0);
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

        // 成员坐标是绝对的，弹层一移动就得重新摆一遍，否则内容会和背景错位
        applyPopupScroll();
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
        popupThumb = null;
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

        // 滑块最后加，保证画在列表项上面
        popupThumb = null;
        if (maxScrollIndex() > 0)
        {
            popupThumb = new Rect(0, 0, THUMB_W, THUMB_BASE_H, 2, 2, iconColor(), 1);
            popupThumb.antialiasing = false;
            popup.add(popupThumb);
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

        // ---- 列表放不下时：滚轮在弹层上滚动 ----
        // 宿主界面的列表滚动在弹层展开时已经被让出来（scroller.inputAllow），
        // 所以这里读到的滚轮不会和页面滚动打架。
        if (isOpen && overPopup && mouse.wheel != 0 && maxScrollIndex() > 0)
        {
            scrollIndex = Std.int(FlxMath.bound(scrollIndex - mouse.wheel, 0, maxScrollIndex()));
            applyPopupScroll();
        }

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

            if (isOpen)
            {
                closePopup();
            }
            else
            {
                openPopup(false);
                openedThisFrame = true;
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
            if (!it.visible) continue;   // 滚出窗口的项不参与悬停 / 点击

            var itHover = OptionInput.overlaps(it);
            // 键盘高亮和鼠标悬停共用同一条底色
            it.alpha = (itHover || i == keyIndex) ? 1.0 : 0.0;

            if (itHover && mouse.justReleased)
            {
                follow.setValue(follow.options[i]);
                follow.curOption = i;
                follow.change();
                follow.saveCurrentValue();
                refreshValue();
                closePopup();
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
                return;
            }
        }

        // 点外面关闭（主条和弹窗都不算外面）；右键也算
        if ((mouse.justPressed || mouse.justPressedRight) && !OptionInput.overlaps(bg) && !overPopup)
        {
            closePopup();
        }
    }

    /** 打开下拉；byKeyboard = true 时把高亮定在当前值上（键盘回车走这条） */
    public function openPopup(byKeyboard:Bool = false):Void
    {
        if (isOpen) return;

        scrollIndex = 0;
        keyIndex = byKeyboard ? currentOptionIndex() : -1;
        if (byKeyboard) scrollToShow(keyIndex);

        buildPopup();
        syncPopupPosition();
        if (popup != null) popup.visible = true;

        isOpen = true;
        redrawArrow();
        refreshValue();
    }

    /** 关闭下拉（键盘切换到别的行时用） */
    public function closePopup():Void
    {
        keyIndex = -1;
        if (!isOpen) return;
        isOpen = false;
        if (popup != null) popup.visible = false;
        redrawArrow();
        refreshValue();
    }

    /**
     * 下拉展开时接管键盘：上下选、回车确认、ESC 关闭、R 复位。
     *
     * 宿主界面在键鼠处理之前调用；返回 true 表示这次按键已经被下拉吃掉，
     * 宿主不要再拿它去动行选中 / 关界面。
     */
    public function handleKeyNav():Bool
    {
        if (!isOpen) return false;

        var c:Controls = Controls.instance;
        if (c == null) return false;

        // TAB 让给宿主：先收起下拉，再让它去切区域
        if (FlxG.keys.justPressed.TAB)
        {
            closePopup();
            return false;
        }

        if (c.UI_UP_P)   moveKey(-1);
        if (c.UI_DOWN_P) moveKey(1);

        if (c.ACCEPT)
        {
            confirmKeySelection();
            return true;
        }

        if (c.BACK)
        {
            closePopup();
            FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
            return true;
        }

        if (c.RESET)
        {
            OptionNav.reset(follow, this);
            keyIndex = currentOptionIndex();
            scrollToShow(keyIndex);
            applyPopupScroll();
            return true;
        }

        return true;
    }

    /** 键盘在下拉里上下移动高亮项 */
    function moveKey(dir:Int):Void
    {
        var opts = follow.options;
        if (opts == null || opts.length == 0) return;

        var idx:Int = (keyIndex < 0) ? currentOptionIndex() : keyIndex;
        var next:Int = Std.int(FlxMath.bound(idx + dir, 0, opts.length - 1));
        if (next == keyIndex) return;

        keyIndex = next;
        scrollToShow(keyIndex);
        applyPopupScroll();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    /** 回车：把高亮项写成当前值并收起下拉 */
    function confirmKeySelection():Void
    {
        var opts = follow.options;
        var idx:Int = keyIndex;
        if (opts == null || idx < 0 || idx >= opts.length) return;

        follow.setValue(opts[idx]);
        follow.curOption = idx;
        follow.change();
        follow.saveCurrentValue();
        refreshValue();
        closePopup();
        FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
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
        if (popupThumb != null) popupThumb.color = iconColor();
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