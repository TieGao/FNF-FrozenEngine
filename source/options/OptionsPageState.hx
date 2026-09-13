package options;

import options.psychoptions.PsychOption;

import backend.MusicBeatState;
import backend.MouseEvent;
import backend.MouseMove;
import backend.ui.PsychUIInputText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import shapeEx.Rect;

class OptionsPageState extends MusicBeatState
{
    public static var instance:OptionsPageState;

    // ---------- 布局参数 ----------
    static inline var NAV_W:Float       = 220;
    static inline var NAV_PAD:Float     = 12;
    static inline var NAV_ITEM_H:Float  = 44;
    static inline var NAV_ITEM_GAP:Float = 4;
    static inline var HEADER_H:Float    = 72;
    static inline var ROW_H:Float       = 92;
    static inline var ROW_GAP:Float     = 6;
    static inline var SEARCH_H:Float    = 36;

    var ROW_W:Float = 0;

    // ---------- 数据 ----------
    public var categories:Array<OptionCategory>;
    var selectedCat:OptionCategory;
    var currentSub:OptionCategory;

    // ---------- 兼容字段 ----------
    public var mouseEvent:MouseEvent;
    public var specBG:FlxSprite;
    public var downBG:FlxSprite;
    public var cataMove:Dynamic;

    // ---------- UI ----------
    var bg:FlxSprite;
    var header:Rect;

    var headerTitle:FlxText;
    var headerSubDesc:FlxText;
    var hoverDesc:FlxText;

    var searchComp:Win10SearchBar;
    var currentSearch:String = '';

    var navContainer:FlxSpriteGroup;
    var navItems:Array<Win10NaviItem> = [];
    var navScroll:Float = 0;
    var navMaxScroll:Float = 0;
    var navViewTop:Float = 0;
    var navViewBottom:Float = 0;
    var navBG:Rect;
    var navDivider:Rect;

    var contentContainer:FlxSpriteGroup;
    var overlayContainer:FlxSpriteGroup;
    var rows:Array<Win10OptionRow> = [];

    // ---------- 新增：预览层 ----------
    var previewLayer:OptionPreviewLayer = null;

    var scroll:Float = 0;
    var maxScroll:Float = 0;

    var onClose:Void->Void = null;
    var langReloadCb:Void->Void = null;

    var hoveredOption:PsychOption = null;

    var backButton:Win10BackButton;

    // ---------- MouseMove ----------
    var navScroller:MouseMove;
    var contentScroller:MouseMove;
    var navScrollHolder:{value:Float} = {value: 0};
    var scrollHolder:{value:Float} = {value: 0};

    public function new(categories:Array<OptionCategory>, initialCat:OptionCategory, ?onClose:Void->Void)
    {
        super();
        this.categories = categories;
        this.selectedCat = initialCat;
        this.onClose = onClose;
        this.cataMove = { velocity: 0.0, inputAllow: true };
    }

    override function create()
    {
        super.create();
        instance = this;
        FlxG.mouse.visible = true;

        langReloadCb = refreshLanguage;
        Language.addReloadCallback(langReloadCb);

        mouseEvent = new MouseEvent();
        add(mouseEvent);

        specBG = new FlxSprite();
        specBG.makeGraphic(1, 1, FlxColor.TRANSPARENT);
        specBG.visible = false;
        add(specBG);

        downBG = new FlxSprite();
        downBG.makeGraphic(1, 1, FlxColor.TRANSPARENT);
        downBG.visible = false;
        add(downBG);

        ROW_W = FlxG.width - NAV_W - NAV_PAD;

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
        bg.scrollFactor.set();
        add(bg);

        navBG = new Rect(0, HEADER_H, NAV_W, FlxG.height - HEADER_H,
                        0, 0, 0xFF2B2B2B, 1);
        navBG.scrollFactor.set();
        add(navBG);

        navDivider = new Rect(NAV_W, HEADER_H, 1, FlxG.height - HEADER_H,
                            0, 0, 0xFF3F3F3F, 1);
        navDivider.scrollFactor.set();
        add(navDivider);

        var headerLeft = new Rect(0, 0, NAV_W, HEADER_H, 0, 0, 0xFF2B2B2B, 1);
        headerLeft.scrollFactor.set();
        add(headerLeft);

        var headerRight = new Rect(NAV_W, 0, FlxG.width - NAV_W, HEADER_H,
                                0, 0, 0xFF000000, 1);
        headerRight.scrollFactor.set();
        add(headerRight);

        var leftX = NAV_W + NAV_PAD;
        var leftW = (FlxG.width - leftX - NAV_PAD) * 0.5;

        headerTitle = new FlxText(leftX, 6, leftW, selectedCat.displayName, 22);
        headerTitle.setFormat(Paths.font('montserrat.ttf'), 24,
            0xFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        headerTitle.borderStyle = NONE;
        headerTitle.antialiasing = ClientPrefs.data.antialiasing;
        add(headerTitle);

        headerSubDesc = new FlxText(leftX, 36, leftW, selectedCat.description, 14);
        headerSubDesc.setFormat(Paths.font('montserrat.ttf'), 16,
            0xAAAAAA, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        headerSubDesc.borderStyle = NONE;
        headerSubDesc.antialiasing = ClientPrefs.data.antialiasing;
        add(headerSubDesc);

        var rightX = leftX + leftW + NAV_PAD;
        var rightW = FlxG.width - rightX - NAV_PAD;

        hoverDesc = new FlxText(rightX, 0, rightW, '', 14);
        hoverDesc.setFormat(Paths.font('montserrat.ttf'), 14,
            0x4CC2FF, RIGHT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        hoverDesc.borderStyle = NONE;
        hoverDesc.antialiasing = ClientPrefs.data.antialiasing;
        hoverDesc.y = (HEADER_H - hoverDesc.height) * 0.5;
        add(hoverDesc);

        buildSearchBar();

        navContainer = new FlxSpriteGroup();
        add(navContainer);

        contentContainer = new FlxSpriteGroup();
        add(contentContainer);

        overlayContainer = new FlxSpriteGroup();
        add(overlayContainer);

        previewLayer = new OptionPreviewLayer(FlxG.width * 0.72, HEADER_H + 40);
        add(previewLayer);

        // 保存设置时通知预览
        PsychOption.onValueSaved = function(opt:PsychOption) {
            if (previewLayer != null)
                previewLayer.notifyValueSaved(opt);
        };

        buildScrollers();
        buildBackButton();

        selectCategory(selectedCat);
    }

    function buildSearchBar()
    {
        var searchX = NAV_PAD / 2;
        var searchY = HEADER_H + NAV_PAD;
        var searchW = NAV_W * 0.9;

        searchComp = new Win10SearchBar(searchX, searchY, searchW, SEARCH_H, 14);
        searchComp.setPlaceholder(Language.getPhrase('searchhint', 'Search settings'));
        searchComp.onChange = function(oldText:String, newText:String)
        {
            currentSearch = newText.trim();
            buildRows();
        };
        searchComp.scrollFactor.set();
        add(searchComp);
    }

    function buildScrollers()
    {
        navScroller = new MouseMove(
            navScrollHolder, 'value',
            [0, 0],
            [
                [0, NAV_W + 1],
                [HEADER_H + NAV_PAD, FlxG.height]
            ],
            function()
            {
                navScroll = navScrollHolder.value;
                applyNavScrollVisual();
            },
            true
        );
        navScroller.infScroll = false;
        navScroller.dragSensitivity = 1.0;
        navScroller.deceleration = 0.92;
        navScroller.mouseWheelSensitivity = -1000.0;
        navScroller.dragStartDelayMs = 100;
        navScroller.dragStartDistance = 10;
        add(navScroller);

        contentScroller = new MouseMove(
            scrollHolder, 'value',
            [0, 0],
            [
                [NAV_W, FlxG.width + 1],
                [HEADER_H, FlxG.height - 60]
            ],
            function()
            {
                scroll = scrollHolder.value;
                applyContentScrollVisual();
            },
            true
        );
        contentScroller.infScroll = false;
        contentScroller.dragSensitivity = 1.0;
        contentScroller.deceleration = 0.92;
        contentScroller.mouseWheelSensitivity = -1000.0;
        contentScroller.dragStartDelayMs = 100;
        contentScroller.dragStartDistance = 10;
        add(contentScroller);
    }

    function buildBackButton()
    {
        var btnW = NAV_W - NAV_PAD * 2;
        var btnH = 44;
        var btnX = NAV_PAD;
        var btnY = FlxG.height - btnH - NAV_PAD;

        backButton = new Win10BackButton(
            btnX, btnY, btnW, btnH,
            Language.getPhrase('options.back', 'back'),
            function() { closePage(); }
        );
        backButton.scrollFactor.set();
        add(backButton);
    }

    // =========================================================
    // 导航（同原版）
    // =========================================================
    function buildNav()
    {
        for (item in navItems) navContainer.remove(item, true);
        navItems = [];
        navScroll = 0;

        navViewTop = HEADER_H + NAV_PAD + SEARCH_H + NAV_PAD;
        navViewBottom = FlxG.height - NAV_PAD;

        var subs = selectedCat.subCategories;
        if (subs.length == 0) subs = [selectedCat];

        var startY = navViewTop;

        for (i in 0...subs.length)
        {
            var sub = subs[i];
            var item = new Win10NaviItem(0,
                startY + i * (NAV_ITEM_H + NAV_ITEM_GAP),
                NAV_W, NAV_ITEM_H,
                sub,
                function(c) { selectSubCategory(c); });
            navItems.push(item);
            navContainer.add(item);
        }

        var contentH = subs.length * (NAV_ITEM_H + NAV_ITEM_GAP) - NAV_ITEM_GAP;
        var viewH = navViewBottom - navViewTop;
        navMaxScroll = Math.max(0, contentH - viewH);

        if (navScroller != null)
        {
            navScroller.moveLimit = [0, navMaxScroll];
            navScroller.velocity = 0;
            navScrollHolder.value = FlxMath.bound(navScrollHolder.value, 0, navMaxScroll);
        }

        updateNavScroll(0);
    }

    function updateNavScroll(delta:Float)
    {
        navScroll = FlxMath.bound(navScroll + delta, 0, navMaxScroll);
        navScrollHolder.value = navScroll;
        applyNavScrollVisual();
    }

    function applyNavScrollVisual()
    {
        navScroll = FlxMath.bound(navScrollHolder.value, 0, navMaxScroll);
        navScrollHolder.value = navScroll;

        for (i in 0...navItems.length)
        {
            var baseY = navViewTop + i * (NAV_ITEM_H + NAV_ITEM_GAP);
            var item = navItems[i];
            item.y = baseY - navScroll;

            var visible = (item.y + NAV_ITEM_H > navViewTop)
                       && (item.y < navViewBottom);
            item.visible = visible;
            item.active = visible;
        }
    }

    public function selectCategory(cat:OptionCategory):Void
    {
        selectedCat = cat;
        headerTitle.text = cat.displayName;
        headerSubDesc.text = cat.description;
        hoveredOption = null;
        hoverDesc.text = '';

        if (previewLayer != null) previewLayer.showForCategory(cat.id);   // ← 改这里

        buildNav();

        var first = cat.subCategories.length > 0 ? cat.subCategories[0] : cat;
        selectSubCategory(first);
    }

    public function selectSubCategory(sub:OptionCategory):Void
    {
        currentSub = sub;

        for (item in navItems)
            item.setActive(item.category == sub);

        headerTitle.text = (sub == selectedCat)
            ? selectedCat.displayName
            : selectedCat.displayName + '  >  ' + sub.displayName;

        headerSubDesc.text = sub.description;

        hoveredOption = null;
        hoverDesc.text = '';

        if (previewLayer != null) previewLayer.showForCategory(sub.id);   // ← 改这里

        buildRows();

        scroll = 0;
        scrollHolder.value = 0;
        if (contentScroller != null) contentScroller.velocity = 0;
        updateScroll(0);
    }

    // =========================================================
    // 右侧列表
    // =========================================================
    function buildRows()
    {
        for (r in rows)
        {
            FlxTween.cancelTweensOf(r);
            contentContainer.remove(r, true);
        }
        rows = [];

        if (currentSub == null)
        {
            maxScroll = 0;
            if (contentScroller != null)
            {
                contentScroller.moveLimit = [0, 0];
                contentScroller.velocity = 0;
            }
            return;
        }

        var optionsToShow:Array<PsychOption> = [];
        if (currentSearch.length > 0)
        {
            var query = currentSearch.toLowerCase();
            var allOptions = (selectedCat != null) ? selectedCat.allOptions() : [];
            for (opt in allOptions)
            {
                if (optionMatchesSearch(opt, query))
                    optionsToShow.push(opt);
            }
        }
        else
        {
            optionsToShow = currentSub.options;
        }

        var startX = NAV_W + NAV_PAD * 2;
        var curY:Float = HEADER_H + NAV_PAD;

        for (i in 0...optionsToShow.length)
        {
            var opt = optionsToShow[i];
            var widget = createWidgetFor(opt);
            if (widget == null) continue;

            var row = new Win10OptionRow(startX, curY, ROW_W, ROW_H, opt, widget);
            row.setRowMeta(curY, ROW_H);

            rows.push(row);
            contentContainer.add(row);

            curY += ROW_H + ROW_GAP;
        }

        var contentH = curY - (HEADER_H + NAV_PAD) - ROW_GAP;
        var viewH = FlxG.height - HEADER_H - NAV_PAD - 60;
        maxScroll = Math.max(0, contentH - viewH);

        if (contentScroller != null)
        {
            contentScroller.moveLimit = [0, maxScroll];
            scrollHolder.value = FlxMath.bound(scrollHolder.value, 0, maxScroll);
        }
    }

    function optionMatchesSearch(opt:PsychOption, query:String):Bool
    {
        if (opt == null) return false;

        var owner = opt.ownerCategory;
        var ownerText = (owner != null) ? [owner.id, owner.displayName, owner.rawDisplayName].join(' ') : '';
        var haystack = [
            opt.name,
            opt.description,
            opt.variable,
            ownerText,
            opt.actionLabel
        ].join(' ').toLowerCase();

        return haystack.indexOf(query) >= 0;
    }

    function createWidgetFor(opt:PsychOption):FlxSpriteGroup
    {
        switch (opt.type)
        {
            case ACTION:
                var tag = opt.variable != null ? opt.variable.toLowerCase() : '';
                var isReset = (tag.indexOf('reset') >= 0
                    || (opt.actionLabel != null && opt.actionLabel.toLowerCase() == 'reset'));
                return new OptionButton(0, 0, 100, 35, opt, isReset);

            case BOOL:
                return new BoolButton(0, 0, 56, 24, opt);

            case INT, FLOAT, PERCENT:
                return new NumButton(0, 0, 240, 32, opt);

            case STRING:
                var sel = new StringSelect(0, 0, 240, 32, opt, overlayContainer);
                return sel;
            case COLOR:   // ← 新增
                var sel = new ColorSelect(0, 0, 240, 32, opt, overlayContainer);
                 return sel;
            case KEYBIND:
                return null;
        }
    }

    function updateScroll(delta:Float)
    {
        scroll = FlxMath.bound(scroll + delta, 0, maxScroll);
        scrollHolder.value = scroll;
        applyContentScrollVisual();
    }

    function applyContentScrollVisual()
    {
        scroll = FlxMath.bound(scrollHolder.value, 0, maxScroll);
        scrollHolder.value = scroll;

        for (i in 0...rows.length)
        {
            var row = rows[i];
            row.y = row.baseY - scroll;

            var visible = row.y + row.rowH > HEADER_H
                    && row.y < FlxG.height - 60;
            row.visible = visible;
            row.active = visible;
        }
    }

    // =========================================================
    // 悬浮检测 + 预览同步
    // =========================================================
    function updateHoverDescription()
    {
        var found:PsychOption = null;
        var mx = FlxG.mouse.x;
        var my = FlxG.mouse.y;

        if (mx > NAV_W && my > HEADER_H && my < FlxG.height - 60)
        {
            for (i in 0...rows.length)
            {
                var row = rows[i];
                if (!row.visible || !row.active) continue;

                if (mx >= row.x && mx <= row.x + ROW_W
                    && my >= row.y && my <= row.y + ROW_H)
                {
                    found = row.option;
                    break;
                }
            }
        }

        if (found != hoveredOption)
        {
            hoveredOption = found;
            hoverDesc.text = (hoveredOption != null) ? hoveredOption.description : '';

            // ← 删掉这三行：
            // if (previewLayer != null)
            //     previewLayer.showFor(hoveredOption);
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (controls.UI_DOWN_P) updateScroll(30);
        if (controls.UI_UP_P)   updateScroll(-30);

        if (scrollHolder.value != scroll)
            scrollHolder.value = scroll;
        if (navScrollHolder.value != navScroll)
            navScrollHolder.value = navScroll;

        updateHoverDescription();

        if (controls.BACK || FlxG.mouse.justPressedRight) {
            if (PsychUIInputText.focusOn != null) {
                PsychUIInputText.focusOn = null;
                FlxG.sound.play(Paths.sound('cancelMenu'));
            } else {
                closePage();
            }
        }
    }

    function closePage():Void
    {
        FlxG.sound.play(Paths.sound('cancelMenu'));
        if (onClose != null) onClose();
        MusicBeatState.switchState(new OptionsState());
    }

    function refreshLanguage():Void
    {
        if (selectedCat != null)
            selectedCat.refreshLanguage();

        buildNav();
        if (currentSub != null)
            selectSubCategory(currentSub);

        if (hoveredOption != null)
            hoverDesc.text = hoveredOption.description;
    }

    override function destroy()
    {
        if (langReloadCb != null)
            Language.removeReloadCallback(langReloadCb);
        instance = null;

        // ← 新增：清理预览层
        if (previewLayer != null)
        {
            previewLayer.destroy();
            previewLayer = null;
        }

        super.destroy();
    }
}