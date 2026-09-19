package options;

import options.Option;

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
    var contentMaskTop:FlxFilteredSprite;
    var contentMaskBottom:FlxFilteredSprite;
    var header:Rect;

    // 头部左右两块底色（切主题时要改色，所以提成字段）
    var headerLeft:Rect;
    var headerRight:Rect;

    /** 已套用的主题版本号：和 UITheme.version 不一致时说明要重建 */
    var themeVersion:Int = -1;

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

    var hoveredOption:Option = null;

    var backButton:Win10BackButton;

    // ---------- MouseMove ----------
    var navScroller:MouseMove;
    var contentScroller:MouseMove;
    var navScrollHolder:{value:Float} = {value: 0};
    var scrollHolder:{value:Float} = {value: 0};

    public function new(categories:Array<OptionCategory>, initialCat:OptionCategory, ?onClose:Void->Void, ?initialSearch:String)
    {
        super();
        this.categories = categories;
        this.selectedCat = initialCat;
        this.onClose = onClose;
        this.cataMove = { velocity: 0.0, inputAllow: true };
        // 从大类页带过来的搜索词：进来直接就是过滤结果
        this.currentSearch = OptionSearch.normalize(initialSearch);
    }

    override function create()
    {
        super.create();
        instance = this;
        FlxG.mouse.visible = true;

        // ---------- 主题 ----------
        UITheme.ensure();
        themeVersion = UITheme.version;

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

        // 用白色图形 + color 着色，切主题时只要改 color
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
        bg.color = UITheme.windowBG;
        bg.scrollFactor.set();
        add(bg);

        navBG = new Rect(0, HEADER_H, NAV_W, FlxG.height - HEADER_H,
                        0, 0, UITheme.sidebar, 1);
        navBG.scrollFactor.set();
        add(navBG);

        navDivider = new Rect(NAV_W, HEADER_H, 1, FlxG.height - HEADER_H,
                            0, 0, UITheme.divider, 1);
        navDivider.scrollFactor.set();
        add(navDivider);

        headerLeft = new Rect(0, 0, NAV_W, HEADER_H, 0, 0, UITheme.sidebar, 1);
        headerLeft.scrollFactor.set();
        add(headerLeft);

        headerRight = new Rect(NAV_W, 0, FlxG.width - NAV_W, HEADER_H,
                                0, 0, UITheme.windowBG, 1);
        headerRight.scrollFactor.set();
        add(headerRight);

        var leftX = NAV_W + NAV_PAD;
        var leftW = (FlxG.width - leftX - NAV_PAD) * 0.5;

        buildSearchBar();

        navContainer = new FlxSpriteGroup();
        add(navContainer);

        contentContainer = new FlxSpriteGroup();
        add(contentContainer);

        var maskX = NAV_W;
        var maskW = Std.int(FlxG.width - NAV_W);

        // 顶部遮罩：从 HEADER_H 往下 24px（可调）
        var topMaskH = 150;
        contentMaskTop = new FlxFilteredSprite(maskX, -75);
        contentMaskTop.makeGraphic(maskW, topMaskH, UITheme.mask);
        contentMaskTop.filters = [new openfl.filters.BlurFilter(0, 20, 1)];
        contentMaskTop.scrollFactor.set();
        add(contentMaskTop);

        // 底部遮罩：从 FlxG.height - 60 往上 24px（可调）
        var bottomMaskH = 200;
        contentMaskBottom = new FlxFilteredSprite(maskX, FlxG.height - 50);
        contentMaskBottom.makeGraphic(maskW, bottomMaskH, UITheme.mask);
        contentMaskBottom.filters = [new openfl.filters.BlurFilter(0, 20, 1)];
        contentMaskBottom.scrollFactor.set();
        add(contentMaskBottom);

        overlayContainer = new FlxSpriteGroup();
        add(overlayContainer);

        previewLayer = new OptionPreviewLayer(FlxG.width * 0.72, HEADER_H + 40);
        add(previewLayer);

        headerTitle = new FlxText(leftX, 6, leftW, selectedCat.displayName, 22);
        headerTitle.setFormat(Paths.font('vcr.ttf'), 24,
            UITheme.textPrimary, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        headerTitle.borderStyle = NONE;
        headerTitle.antialiasing = ClientPrefs.data.antialiasing;
        add(headerTitle);

        headerSubDesc = new FlxText(leftX, 36, leftW, selectedCat.description, 14);
        headerSubDesc.setFormat(Paths.font('vcr.ttf'), 16,
            UITheme.textSecondary, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        headerSubDesc.borderStyle = NONE;
        headerSubDesc.antialiasing = ClientPrefs.data.antialiasing;
        add(headerSubDesc);

        var rightX = leftX + leftW + NAV_PAD;
        var rightW = FlxG.width - rightX - NAV_PAD;

        hoverDesc = new FlxText(rightX, 0, rightW, '', 14);
        hoverDesc.setFormat(Paths.font('vcr.ttf'), 14,
            UITheme.accent, RIGHT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        hoverDesc.borderStyle = NONE;
        hoverDesc.antialiasing = ClientPrefs.data.antialiasing;
        hoverDesc.y = (HEADER_H - hoverDesc.height) * 0.5;
        add(hoverDesc);

        // 保存设置时通知预览
        Option.onValueSaved = function(opt:Option) {
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
            currentSearch = OptionSearch.normalize(newText);

            // 结果集变了：回到顶部，刷新导航命中数和右侧列表
            scroll = 0;
            scrollHolder.value = 0;
            if (contentScroller != null) contentScroller.velocity = 0;

            refreshNavCounts();
            buildRows();
            updateScroll(0);
        };
        searchComp.scrollFactor.set();
        add(searchComp);

        // 带着搜索词进来时预填输入框（setText 不会触发 onChange）
        if (currentSearch.length > 0)
            searchComp.setText(currentSearch);
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

        refreshNavCounts();
        updateNavScroll(0);
    }

    /** 按当前搜索词刷新每个子分类的命中数徽标（搜索时才显示） */
    function refreshNavCounts():Void
    {
        var searching = currentSearch.length > 0;

        if (!searching)
        {
            for (item in navItems) item.setMatchCount(0, false);
            return;
        }

        var counts = OptionSearch.countsPerSub(selectedCat, currentSearch.toLowerCase());
        for (i in 0...navItems.length)
            navItems[i].setMatchCount(i < counts.length ? counts[i] : 0, true);
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

        hoveredOption = null;
        hoverDesc.text = '';

        if (previewLayer != null) previewLayer.showForCategory(sub.id);   // ← 改这里

        buildRows();   // 内部会按搜索状态刷新头部文案

        if (contentScroller != null) contentScroller.velocity = 0;

        if (currentSearch.length > 0)
        {
            // 搜索时右侧列表是整棵分类树的结果：
            // 点导航项 = 滚到该子分类的第一条命中，让导航徽标"可点、有意义"
            scroll = 0;
            scrollHolder.value = 0;

            var target = -1;
            for (i in 0...rows.length)
            {
                if (rows[i].option != null && rows[i].option.ownerCategory == sub)
                {
                    target = i;
                    break;
                }
            }

            updateScroll(target > 0 ? target * (ROW_H + ROW_GAP) : 0);
            return;
        }

        scroll = 0;
        scrollHolder.value = 0;
        updateScroll(0);
    }

    /**
     * 头部文案：
     * - 搜索中 → 显示当前大类的命中总数（此时右侧列表是整棵分类树的结果，不再是单个子分类）；
     * - 未搜索 → 保持原来的「大类 > 子分类 + 描述」。
     */
    function updateHeaderText():Void
    {
        if (selectedCat == null) return;

        if (currentSearch.length > 0)
        {
            var total = OptionSearch.countInCategory(selectedCat, currentSearch.toLowerCase());
            headerTitle.text = selectedCat.displayName;
            headerSubDesc.text = Language.getPhrase('options.search.results',
                '{1} settings match "{2}"',
                [Std.string(total), currentSearch]);
            return;
        }

        headerTitle.text = (currentSub == null || currentSub == selectedCat)
            ? selectedCat.displayName
            : selectedCat.displayName + '  >  ' + currentSub.displayName;

        headerSubDesc.text = (currentSub != null) ? currentSub.description : selectedCat.description;
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

        var searching = currentSearch.length > 0;

        var optionsToShow:Array<Option> = [];
        if (searching)
        {
            // 搜索时展示整个大类（含所有子分类）的命中结果，与导航徽标统计口径一致
            optionsToShow = OptionSearch.filterCategory(selectedCat, currentSearch.toLowerCase());
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

            // 搜索时在行右侧标注这条结果来自哪个子分类
            if (searching && opt.ownerCategory != null)
                row.setSubLabel(opt.ownerCategory.displayName);

            rows.push(row);
            contentContainer.add(row);

            curY += ROW_H + ROW_GAP;
        }

        var contentH = curY - (HEADER_H + NAV_PAD) - ROW_GAP;
        var viewH = FlxG.height - HEADER_H - NAV_PAD - 60;
        maxScroll = Math.max(0, contentH - viewH);

        scroll = FlxMath.bound(scroll, 0, maxScroll);
        scrollHolder.value = scroll;

        if (contentScroller != null)
        {
            contentScroller.moveLimit = [0, maxScroll];
            scrollHolder.value = FlxMath.bound(scrollHolder.value, 0, maxScroll);
        }

        updateHeaderText();
    }

    function createWidgetFor(opt:Option):FlxSpriteGroup
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
        var found:Option = null;
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
        // 主题切换：在成员 update 之前重建，避免销毁正在 update 的控件
        if (themeVersion != UITheme.version)
        {
            themeVersion = UITheme.version;
            applyTheme();
        }

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

    // =========================================================
    // 深浅色主题
    // =========================================================
    /** 按当前主题重新套用配色：静态面板直接改色，列表按新配色重建 */
    function applyTheme()
    {
        if (bg != null) bg.color = UITheme.windowBG;
        if (navBG != null) navBG.color = UITheme.sidebar;
        if (navDivider != null) navDivider.color = UITheme.divider;
        if (headerLeft != null) headerLeft.color = UITheme.sidebar;
        if (headerRight != null) headerRight.color = UITheme.windowBG;

        if (contentMaskTop != null) contentMaskTop.color = UITheme.mask;
        if (contentMaskBottom != null) contentMaskBottom.color = UITheme.mask;

        if (headerTitle != null) headerTitle.color = UITheme.textPrimary;
        if (headerSubDesc != null) headerSubDesc.color = UITheme.textSecondary;
        if (hoverDesc != null) hoverDesc.color = UITheme.accent;

        // 旧行彻底销毁：下拉弹层挂在 overlayContainer 上，不销毁会残留
        for (r in rows)
        {
            FlxTween.cancelTweensOf(r);
            contentContainer.remove(r, true);
            r.destroy();
        }
        rows = [];

        buildNav();
        if (currentSub != null)
            for (item in navItems) item.setActive(item.category == currentSub);

        buildRows();

        if (searchComp != null) searchComp.refreshTheme();
        if (backButton != null) backButton.refreshTheme();
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