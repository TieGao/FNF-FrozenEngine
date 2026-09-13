package options.objects.backend;

import options.psychoptions.PsychOption;

class StringSelect extends FlxSpriteGroup
{
    var follow:PsychOption;

    var bg:Rect;          // 当前值的条
    var dis:FlxText;
    var arrow:FlxSprite;

    var popup:FlxSpriteGroup;   // 展开的下拉
    var popupBg:Rect;
    var popupItems:Array<Rect> = [];
    var popupTexts:Array<FlxText> = [];

    var topLayer:FlxSpriteGroup;

    public var isOpen:Bool = false;
    var mainW:Float;
    var mainH:Float;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:PsychOption, ?topLayer:FlxSpriteGroup)
    {
        super(X, Y);
        this.follow = follow;
        this.topLayer = topLayer;
        mainW = width; mainH = height;

        bg = new Rect(0, 0, width, height, 4, 4, 0xFF3A3A3A, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        dis = new FlxText(10, 0, width - 30, '', 16);
        dis.setFormat(Paths.font('montserrat.ttf'), 16,
            0xFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        dis.borderStyle = NONE;
        dis.antialiasing = ClientPrefs.data.antialiasing;
        dis.y = (height - dis.height) * 0.5;
        add(dis);

        arrow = new FlxSprite().loadGraphic(Paths.image('menuExtend/OptionsState/icons/dropdown'));
        arrow.setGraphicSize(Std.int(height * 0.4));
        arrow.updateHitbox();
        arrow.color = 0xCCCCCC;
        arrow.x = width - arrow.width - 8;
        arrow.y = (height - arrow.height) * 0.5;
        arrow.antialiasing = ClientPrefs.data.antialiasing;
        add(arrow);

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
            var item = new Rect(4, 4 + i * itemH, mainW - 8, itemH, 3, 3, 0xFF3A3A3A, 0);
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

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        syncPopupPosition();
        var mouse = FlxG.mouse;

        // 点击主条
        if (mouse.overlaps(bg) && mouse.justPressed)
        {
            isOpen = !isOpen;
            if (isOpen) { buildPopup(); popup.visible = true; }
            else popup.visible = false;
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
        }

        if (!isOpen) return;

        // 悬停
        for (i in 0...popupItems.length)
        {
            var it = popupItems[i];
            var hover = mouse.overlaps(it);

            it.alpha = hover ? 1.0 : 0.0;

            if (hover && mouse.justReleased)
            {
                follow.setValue(follow.options[i]);
                follow.change();
                follow.saveCurrentValue();
                refreshText();
                isOpen = false;
                popup.visible = false;
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
            if (!inPopup) { isOpen = false; popup.visible = false; }
        }
    }
}