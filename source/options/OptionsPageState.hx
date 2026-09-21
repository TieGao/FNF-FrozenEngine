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
    /** 右上角说明文字的淡入淡出时长：先淡出 DESC_FADE 秒 → 换字 → 再淡入 DESC_FADE 秒 */
    static inline var DESC_FADE:Float = 0.2;
    /**
     * 说明文字**当前的目标文本**。
     * 去重要拿它比，不能拿 hoverDesc.text —— 淡出期间 text 还是旧值，
     * 用 text 比会让每帧都重启一次动画。
     */
    var hoverDescTarget:String = '';
    var hoverDescTween:FlxTween = null;

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

    // ---------- 键盘导航 ----------
    // 焦点区域。界面分三类：搜索框 / 左侧导航 / 右侧选项列表。
    static inline var ZONE_SEARCH:Int = 0;
    static inline var ZONE_NAV:Int    = 1;
    static inline var ZONE_ROWS:Int   = 2;
    static inline var ZONE_COUNT:Int  = 3;
    /** 默认落在左侧导航（最上游），想默认进右侧列表就把这里改成 ZONE_ROWS */
    static inline var ZONE_DEFAULT:Int = ZONE_NAV;

    /**
     * 当前焦点区域。
     *
     * 这是**唯一真值源** —— 不要用 `PsychUIInputText.focusOn != null` 代替它：
     * 输入组件走的是 openfl 的 KeyboardEvent 监听（PsychUIInputText.onKeyDown），
     * 和 `controls.*`（FlxG.keys.anyJustPressed）互不消费，而且事件派发与 state 的
     * update() 谁先谁后不可靠。按 ESC 时输入组件会自己把 focusOn 清空，那时候要是
     * 去判 focusOn，就会把"退出搜索框"误判成"关闭整个页面"。
     */
    var focusZone:Int = ZONE_DEFAULT;
    /** 键盘聚焦的导航项下标 */
    var navIndex:Int = 0;
    /** 键盘选中的选项行下标（对应 rows 数组，不是 Option 列表） */
    var rowIndex:Int = 0;
    /**
     * 搜索框里按回车已经处理过的那一帧。
     *
     * ENTER 同时是搜索框的"跳到结果"和界面的 ACCEPT 键，而 KeyboardEvent 和
     * FlxG.keys 谁先触发不确定 → 用这个闩把同帧的 ACCEPT 吞掉，两种时序都安全。
     */
    var searchEnterHandled:Bool = false;

    /**
     * 是否处于「键盘导航模式」——决定要不要画键盘焦点 / 选中视觉。
     *
     * 默认 false：刚进页面**不画**任何键盘焦点，只有真按了方向键 / TAB / 回车才打开；
     * 鼠标一动（或点一下）就关掉 —— 鼠标操作时只剩控件自己的 hover 效果。
     *
     * ⚠️ 它只管**视觉**：navIndex / rowIndex 照旧由鼠标悬停同步。
     * ⚠️ 不要把它塞进 setFocusZone() —— 那个方法也被"输入框自己失焦"这条鼠标路径调用。
     */
    var keyboardNav:Bool = false;

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
        hoverDesc.alpha = 0;   // 初始不可见：第一段说明文字出现时由 setHoverDesc() 淡入
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
            rowIndex = 0;
            buildRows();
            updateScroll(0);
        };
        // 搜索框里按回车 = 跳到左侧导航（Win10 行为）。PsychUIInputText 的默认实现是
        // 直接取消焦点，那样用户还得再按一次下键才走得出去。
        searchComp.input.onPressEnter = function(e) {
            PsychUIInputText.focusOn = null;
            searchEnterHandled = true;
            setKeyboardNav(true);
            setFocusZone(ZONE_DEFAULT);
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
        // 先把旧导航项上的 hover / 聚焦色 tween 掐掉（`remove()` 不 destroy 成员，
        // 脱离了绘制树但 tween 还在跑，会一直往 bg 上写 color）
        for (item in navItems)
        {
            FlxTween.cancelTweensOf(item);
            if (item.bg != null) FlxTween.cancelTweensOf(item.bg);
            navContainer.remove(item, true);
        }
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

        // 导航项数量变了 → 键盘焦点夹回合法范围
        navIndex = Std.int(FlxMath.bound(navIndex, 0, Math.max(0, navItems.length - 1)));
        updateSelectionVisual();

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
        setHoverDesc('');

        if (previewLayer != null) previewLayer.showForCategory(cat.id);   // ← 改这里

        buildNav();

        var first = cat.subCategories.length > 0 ? cat.subCategories[0] : cat;
        selectSubCategory(first);
    }

    public function selectSubCategory(sub:OptionCategory):Void
    {
        currentSub = sub;
        // 换了子分类 → 右侧列表整体重建，键盘选中回到第一行
        rowIndex = 0;

        for (i in 0...navItems.length)
        {
            var item:Win10NaviItem = navItems[i];
            item.setActive(item.category == sub);
            // 键盘焦点跟着当前子分类走（鼠标点导航项 / 键盘切子分类都走这里）
            if (item.category == sub) navIndex = i;
        }

        hoveredOption = null;
        setHoverDesc('');

        if (previewLayer != null) previewLayer.showForCategory(sub.id);   // ← 改这里

        buildRows();   // 内部会按搜索状态刷新头部文案 + 刷新选中视觉

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

            // 键盘选中跟着滚过去，否则选中环会留在屏幕外的第一行上
            if (target > 0)
            {
                rowIndex = target;
                updateSelectionVisual();
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
            rowIndex = 0;
            updateSelectionVisual();
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
            // 选中时不给整行铺底色，只亮标题 + 控件（必须在第一次 setSelected() 之前设好）
            row.highlightWholeRow = false;

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

        // 行数变了（切子分类 / 搜索过滤 / 切主题重建）→ 键盘选中夹回合法范围并重画
        rowIndex = Std.int(FlxMath.bound(rowIndex, 0, Math.max(0, rows.length - 1)));
        updateSelectionVisual();

        updateHeaderText();
    }

    // =========================================================
    // 键盘导航
    // =========================================================

    /**
     * 把"键盘焦点在哪"同步到控件本体。
     *
     * 导航项用 setFocused，选项行用 setSelected —— 两者都只在
     * `keyboardNav && focusZone` 指向自己时才亮：
     * - `focusZone` 保证屏幕上同时只有一个焦点环；
     * - `keyboardNav` 保证"默认不显示键盘索引"，只有真的用过键盘才画。
     */
    function updateSelectionVisual():Void
    {
        for (i in 0...navItems.length)
            navItems[i].setFocused(keyboardNav && focusZone == ZONE_NAV && i == navIndex);

        for (i in 0...rows.length)
            rows[i].setSelected(keyboardNav && focusZone == ZONE_ROWS && i == rowIndex);

        updateHoverDescription();
    }

    /** 开关「键盘导航模式」（= 要不要画焦点 / 选中视觉），只在状态真的变了时重画 */
    function setKeyboardNav(v:Bool):Void
    {
        if (keyboardNav == v) return;
        keyboardNav = v;
        updateSelectionVisual();
    }

    /**
     * 本帧有没有按"导航类"按键。
     *
     * syncSelectionFromMouse() 跑在键盘分支**之后**，鼠标抖一下会把刚点亮的焦点收掉
     * —— 用它让位：同一帧里按了导航键就当作键盘接管，鼠标那一路不关灯。
     */
    inline function navKeyJustPressed():Bool
        return controls.UI_UP_P || controls.UI_DOWN_P || controls.UI_LEFT_P || controls.UI_RIGHT_P
            || FlxG.keys.justPressed.TAB || controls.ACCEPT;

    /** 切区域：进出搜索框时顺带管好输入焦点，避免和 focusOn 各说各话 */
    function setFocusZone(zone:Int):Void
    {
        if (focusZone == zone) return;
        focusZone = zone;

        if (focusZone == ZONE_SEARCH)
        {
            if (searchComp != null) searchComp.focus();
        }
        else if (PsychUIInputText.focusOn != null)
        {
            PsychUIInputText.focusOn = null;
        }

        updateSelectionVisual();
    }

    /** Tab / Shift+Tab 在三个区域之间循环 */
    function cycleZone(step:Int):Void
    {
        setFocusZone(FlxMath.wrap(focusZone + step, 0, ZONE_COUNT - 1));
    }

    /** 左侧导航：上下移动 = 直接切子分类（Win10 原生行为），没有"先移动再回车"这一步 */
    function changeNavSelection(delta:Int):Void
    {
        if (navItems.length == 0) return;

        var old:Int = navIndex;
        // 用 clamp 不用 wrap：到顶/到底就停住，跟 Win10 一致
        // （继续往上由调用方转成"回搜索框"，见 update() 里的 ZONE_NAV 分支）
        navIndex = Std.int(FlxMath.bound(navIndex + delta, 0, navItems.length - 1));
        if (navIndex == old) return;

        selectSubCategory(navItems[navIndex].category);   // 内部会重建列表并刷新视觉
        scrollNavIntoView(navIndex);
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    /** 右侧列表：上下移动选中行 */
    function changeRowSelection(delta:Int):Void
    {
        if (rows.length == 0) return;

        var old:Int = rowIndex;
        // 同上，clamp 不 wrap
        rowIndex = Std.int(FlxMath.bound(rowIndex + delta, 0, rows.length - 1));
        if (rowIndex == old) return;

        updateSelectionVisual();
        scrollRowIntoView(rowIndex);
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    /** 把某一行滚进可视区（和 Win8CharmSettings.scrollRowIntoView 同一套算法） */
    function scrollRowIntoView(index:Int):Void
    {
        if (index < 0 || index >= rows.length) return;

        var top:Float = rows[index].baseY - HEADER_H;
        var bottom:Float = top + ROW_H;
        // 视口：HEADER_H 到 FlxG.height - 60（与 applyContentScrollVisual 的可见判定一致）
        var viewH:Float = FlxG.height - 60 - HEADER_H;

        var target:Float = scroll;
        if (top < target) target = top;
        else if (bottom > target + viewH) target = bottom - viewH;

        target = FlxMath.bound(target, 0, maxScroll);

        if (contentScroller != null) contentScroller.tweenData = target;
        else updateScroll(target - scroll);
    }

    /** 把某个导航项滚进可视区 */
    function scrollNavIntoView(index:Int):Void
    {
        if (index < 0 || index >= navItems.length) return;

        var baseY:Float = navViewTop + index * (NAV_ITEM_H + NAV_ITEM_GAP);
        // 可视判定：item.y = baseY - navScroll，要落在 [navViewTop, navViewBottom - NAV_ITEM_H]
        var top:Float = baseY + NAV_ITEM_H - navViewBottom;   // 该行贴到视口底时 navScroll 的最小值
        var bottom:Float = baseY - navViewTop;                // 贴到视口顶时的最大值

        var target:Float = navScroll;
        if (target < top) target = top;
        else if (target > bottom) target = bottom;

        target = FlxMath.bound(target, 0, navMaxScroll);

        if (navScroller != null) navScroller.tweenData = target;
        else updateNavScroll(target - navScroll);
    }

    public function selectedRow():Win10OptionRow
    {
        if (rowIndex < 0 || rowIndex >= rows.length) return null;
        return rows[rowIndex];
    }

    function selectedOption():Option
    {
        var r:Win10OptionRow = selectedRow();
        return (r != null) ? r.option : null;
    }

    /** 当前行是不是数值条（只有它需要左右键调值，其余行左右键用来切区域） */
    function selectedRowIsNum():Bool
    {
        var r:Win10OptionRow = selectedRow();
        return (r != null && r.widget != null && Std.isOfType(r.widget, NumButton));
    }

    function rowLeft():Void
    {
        if (selectedRowIsNum()) adjustSelected(-1);
        else setFocusZone(ZONE_NAV);   // 非数值行：左键离开列表，回左侧导航
    }

    function rowRight():Void
    {
        // 非数值行的右侧没有别的区域，按右键不做事 —— 避免"想切区域却误改了值"
        if (selectedRowIsNum()) adjustSelected(1);
    }

    // 下面三个都委托给 OptionNav（和 Win8CharmSettings 共用同一套键盘语义）
    function adjustSelected(dir:Int):Void
    {
        var r:Win10OptionRow = selectedRow();
        if (r == null) return;
        OptionNav.adjust(r.option, dir, r.widget);
    }

    function activateSelected():Void
    {
        var r:Win10OptionRow = selectedRow();
        if (r == null) return;
        OptionNav.activate(r.option, r.widget);
    }

    function resetSelected():Void
    {
        var r:Win10OptionRow = selectedRow();
        if (r == null) return;
        OptionNav.reset(r.option, r.widget);
    }

    /** 有没有正在展开的下拉/调色板 —— 展开时方向键归弹层，界面不能抢 */
    function isAnyPopupOpen():Bool
    {
        for (r in rows)
        {
            var w:FlxSpriteGroup = r.widget;
            if (w == null) continue;

            if (Std.isOfType(w, options.objects.backend.StringSelect)
                && cast(w, options.objects.backend.StringSelect).isOpen) return true;
            if (Std.isOfType(w, options.objects.backend.ColorSelect)
                && cast(w, options.objects.backend.ColorSelect).isOpen) return true;
        }
        return false;
    }

    // =========================================================
    // 搜索框里的按键判定
    //
    // ClientPrefs.defaultKeys 里 `ui_down` = [S, DOWN]、`ui_right` = [D, RIGHT]、
    // `back` = [BACKSPACE, ESCAPE]，而搜索框是在"打字"，直接吃 controls.* 的话：
    //   - 打一个 "s" / "d" 就会把焦点踹出搜索框（键盘导航新引入的问题）
    //   - 按退格删字也会踹出去（这个是原来的老 bug，顺手一起修了）
    // 所以搜索框聚焦时把"字母别名"排掉，只认真正的方向键 / 功能键；手柄那一路照常。
    // =========================================================
    inline function searchDownPressed():Bool
        return controls.UI_DOWN_P && !FlxG.keys.justPressed.S;

    inline function searchRightPressed():Bool
        return controls.UI_RIGHT_P && !FlxG.keys.justPressed.D;

    inline function searchBackPressed():Bool
        return (controls.BACK && !FlxG.keys.justPressed.BACKSPACE) || FlxG.mouse.justPressedRight;

    /**
     * 鼠标移动时接管选中。
     *
     * 只认"鼠标真的动了"（deltaView != 0）或者"点了一下"：否则鼠标静静停在某一行上时，
     * 键盘按方向键会被悬停项每帧拽回去。正在打字 / 下拉展开时整段跳过。
     *
     * 左侧导航只同步"聚焦"视觉，**不切页** —— 鼠标只是划过不该把右侧列表换掉，
     * 切页仍然靠点击（Win10NaviItem.onClick）或回车。
     * 鼠标一接管还会 `setKeyboardNav(false)`：收掉键盘焦点环，只留控件自己的 hover 效果。
     */
    function syncSelectionFromMouse():Void
    {
        if (PsychUIInputText.focusOn != null) return;
        if (isAnyPopupOpen()) return;
        // "鼠标真的动了"或者"点了一下"都算鼠标接管
        if (FlxG.mouse.deltaViewX == 0 && FlxG.mouse.deltaViewY == 0 && !FlxG.mouse.justPressed) return;

        // 鼠标接管 → 收掉键盘焦点环（只留控件自己的 hover 效果）。
        // 同一帧里按了导航键就让位给键盘：鼠标抖一下不该把刚点亮的环收掉。
        if (!navKeyJustPressed()) setKeyboardNav(false);

        var mx:Float = FlxG.mouse.x;
        var my:Float = FlxG.mouse.y;

        if (mx <= NAV_W && my > HEADER_H)
        {
            for (i in 0...navItems.length)
            {
                var item:Win10NaviItem = navItems[i];
                if (!item.visible || !item.active) continue;
                if (my >= item.y && my <= item.y + NAV_ITEM_H)
                {
                    var zoneChanged:Bool = (focusZone != ZONE_NAV);
                    if (zoneChanged) focusZone = ZONE_NAV;
                    if (zoneChanged || navIndex != i)
                    {
                        navIndex = i;
                        updateSelectionVisual();
                    }
                    return;
                }
            }
            return;
        }

        for (i in 0...rows.length)
        {
            var row:Win10OptionRow = rows[i];
            if (!row.visible || !row.active) continue;
            if (mx >= row.x && mx <= row.x + ROW_W && my >= row.y && my <= row.y + ROW_H)
            {
                var zoneChanged:Bool = (focusZone != ZONE_ROWS);
                if (zoneChanged) focusZone = ZONE_ROWS;
                if (zoneChanged || rowIndex != i)
                {
                    rowIndex = i;
                    updateSelectionVisual();
                }
                return;
            }
        }
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

        hoveredOption = found;

        // 头部右侧的说明文字：鼠标悬停优先，没有悬停就显示键盘选中那一行
        // （对齐 Win8CharmSettings.updateFooterText 的口径，键盘操作时也有描述可看）
        var desc:Option = (hoveredOption != null) ? hoveredOption : selectedOption();
        setHoverDesc((desc != null && desc.description != null) ? desc.description : '');
    }

    /**
     * 换右上角的说明文字：先淡出 DESC_FADE → 换字 → 再淡入 DESC_FADE。
     *
     * 去重拿 hoverDescTarget 而不是 hoverDesc.text：淡出那 0.2s 里 text 还是旧值，
     * 用 text 比会让每帧调用都重启一次动画（这个方法是从 update() 每帧调的）。
     *
     * ⚠️ 不能用 FlxSpriteGroup 的 alpha 做整体淡入 —— 那是按倍率传播给子元素的，
     * 但 hoverDesc 是单个 FlxText，没有这个问题。
     */
    function setHoverDesc(text:String):Void
    {
        if (text == null) text = '';
        if (text == hoverDescTarget) return;
        hoverDescTarget = text;

        if (hoverDescTween != null)
        {
            hoverDescTween.cancel();
            hoverDescTween = null;
        }
        if (hoverDesc == null) return;

        if (hoverDesc.alpha > 0.01)
        {
            // 有东西在屏幕上 → 先淡出，淡完再换字淡入（空串就停在淡出，不再淡入）
            hoverDescTween = FlxTween.tween(hoverDesc, {alpha: 0.0}, DESC_FADE, {
                ease: FlxEase.quadOut,
                onComplete: function(_) {
                    if (hoverDesc == null) return;
                    hoverDesc.text = hoverDescTarget;
                    if (hoverDescTarget.length > 0)
                        hoverDescTween = FlxTween.tween(hoverDesc, {alpha: 1.0}, DESC_FADE, {ease: FlxEase.quadIn});
                }
            });
        }
        else
        {
            // 本来就不可见 → 直接换字淡入，省掉那 0.2s 的"对着空气淡出"
            hoverDesc.text = hoverDescTarget;
            if (hoverDescTarget.length > 0)
                hoverDescTween = FlxTween.tween(hoverDesc, {alpha: 1.0}, DESC_FADE, {ease: FlxEase.quadIn});
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

        if (scrollHolder.value != scroll)
            scrollHolder.value = scroll;
        if (navScrollHolder.value != navScroll)
            navScrollHolder.value = navScroll;

        // 下拉/调色板展开时滚轮归它们用，别再驱动列表
        if (contentScroller != null) contentScroller.inputAllow = !isAnyPopupOpen();

        // ---------- 返回 ----------
        // 判 focusZone 而不是 PsychUIInputText.focusOn：按 ESC 时输入组件会自己
        // 先把 focusOn 清掉，那一帧再判 focusOn 就会直接关掉整个页面。
        if (controls.BACK || FlxG.mouse.justPressedRight) {
            if (focusZone == ZONE_SEARCH) {
                // 搜索框里打字时，退格不能算"返回"（老 bug：按一次退格就丢焦点）
                if (!searchBackPressed())
                {
                    searchEnterHandled = false;
                    return;
                }
                PsychUIInputText.focusOn = null;
                setFocusZone(ZONE_DEFAULT);
                FlxG.sound.play(Paths.sound('cancelMenu'));
            } else {
                closePage();
            }
            searchEnterHandled = false;
            return;
        }

        // 焦点双向同步。必须放在上面 BACK 分支**之后**：ESC 那帧 focusZone 还停在
        // ZONE_SEARCH，先同步的话会被改成 ZONE_DEFAULT，BACK 分支就变成"关页面"了。
        if (focusZone != ZONE_SEARCH && searchComp != null && PsychUIInputText.focusOn == searchComp.input)
            setFocusZone(ZONE_SEARCH);
        else if (focusZone == ZONE_SEARCH && PsychUIInputText.focusOn == null)
            setFocusZone(ZONE_DEFAULT);

        // ---------- Tab：三区循环 ----------
        if (FlxG.keys.justPressed.TAB)
        {
            setKeyboardNav(true);
            cycleZone(FlxG.keys.pressed.SHIFT ? -1 : 1);
            searchEnterHandled = false;
            return;
        }

        // ---------- 键盘导航 ----------
        if (focusZone == ZONE_SEARCH)
        {
            // 搜索框聚焦时方向键归输入组件（左右移动光标），但 ↓ / → 是空的
            // —— PsychUIInputText 的 onKeyDown 只吃左右 / HOME / END / ESC / ENTER ——
            // 所以用它们离开搜索框（Win10 也是这个行为：↓ 进导航，→ 直接进列表）。
            if (searchDownPressed())
            {
                setKeyboardNav(true);
                setFocusZone(ZONE_NAV);
            }
            if (searchRightPressed())
            {
                setKeyboardNav(true);
                setFocusZone(ZONE_ROWS);
            }
            searchEnterHandled = false;
        }
        else if (searchEnterHandled)
        {
            // 搜索框里刚按过回车的那一帧：ENTER 是双语义（搜索框"跳到结果" + 界面 ACCEPT），
            // 把同帧的 ACCEPT 吞掉，免得顺手激活了导航项。
            searchEnterHandled = false;
        }
        else
        {
            // 键盘真的在操作了 → 点亮焦点环（默认状态是不画的）。
            // 放在 switch 之前：三区里的任何一次按键都算"用过键盘"。
            if (navKeyJustPressed()) setKeyboardNav(true);

            // 下拉/调色板展开时**不**拦方向键：它们是纯鼠标驱动的（不吃方向键），
            // 拦掉只会让键盘用户卡住。让位的是滚轮和鼠标接管，见上面的 inputAllow
            // 与 syncSelectionFromMouse()。
            switch (focusZone)
            {
                case ZONE_NAV:
                    // 首项再往上 / 按左键 → 回搜索框（搜索框在导航正上方）
                    if (controls.UI_UP_P)    { if (navIndex == 0) setFocusZone(ZONE_SEARCH); else changeNavSelection(-1); }
                    if (controls.UI_DOWN_P)  changeNavSelection(1);
                    if (controls.UI_LEFT_P)  setFocusZone(ZONE_SEARCH);
                    if (controls.UI_RIGHT_P) setFocusZone(ZONE_ROWS);
                    // 上下移动已经直接切了子分类，回车只是给个"确认"反馈
                    if (controls.ACCEPT)     FlxG.sound.play(Paths.sound('confirmMenu'));

                case ZONE_ROWS:
                    if (controls.UI_UP_P)   { if (rowIndex == 0) setFocusZone(ZONE_NAV); else changeRowSelection(-1); }
                    if (controls.UI_DOWN_P) changeRowSelection(1);
                    if (controls.UI_LEFT_P)  rowLeft();
                    if (controls.UI_RIGHT_P) rowRight();
                    if (controls.ACCEPT)     activateSelected();
                    if (controls.RESET)      resetSelected();

                default:
            }
        }

        updateHoverDescription();
        syncSelectionFromMouse();
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
            setHoverDesc(hoveredOption.description);
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

        if (hoverDescTween != null)
        {
            hoverDescTween.cancel();
            hoverDescTween = null;
        }

        // ← 新增：清理预览层
        if (previewLayer != null)
        {
            previewLayer.destroy();
            previewLayer = null;
        }

        super.destroy();
    }
}