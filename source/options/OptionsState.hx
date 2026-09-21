package options;

import options.objects.main.CategoryCard;

import states.MainMenuState;
import states.FreeplayState;
import states.PlayState;

import backend.MusicBeatState;
import backend.StageData;
import backend.MouseEvent;
import backend.ui.PsychUIInputText;

import openfl.Lib;
import shapeEx.Rect;

class OptionsState extends MusicBeatState
{
    public static var instance:OptionsState;

    // Win10 配色
    public var baseColor:FlxColor = 0xFF1F1F1F;
    public var mainColor:FlxColor = 0xFF2B2B2B;

    // 背景
    var background:FlxSprite;
    var overlay:Rect;

    // 鼠标事件
    public var mouseEvent:MouseEvent;
    public var specBG:FlxSprite;
    public var downBG:FlxSprite;
    public var cataMove:Dynamic;

    var searchComp:Win10SearchBar;
    /** 搜索框下方的结果统计（"共 N 项，分布在 M 个分类" / "没有找到"） */
    var resultText:FlxText;
    /** 当前搜索词（归一化后），点击卡片时带给分类页 */
    var searchQuery:String = '';

    // 卡片网格
    var cardGroup:Array<CategoryCard> = [];
    var cardContainer:FlxSpriteGroup;
    /** 网格列数（buildCards 和键盘上下移动共用，别让两处各写一个 4） */
    var cardCols:Int = 4;

    // ---------- 键盘导航 ----------
    // 焦点区域。界面分两类：搜索框 / 卡片网格。
    static inline var ZONE_SEARCH:Int = 0;
    static inline var ZONE_CARDS:Int  = 1;
    static inline var ZONE_COUNT:Int  = 2;
    /** 默认落在卡片上，进界面就能用方向键 */
    static inline var ZONE_DEFAULT:Int = ZONE_CARDS;

    /**
     * 当前焦点区域。
     *
     * 这是**唯一真值源** —— 不要用 `PsychUIInputText.focusOn != null` 代替它：
     * 输入组件走的是 openfl 的 KeyboardEvent 监听（PsychUIInputText.onKeyDown），
     * 和 `controls.*`（FlxG.keys.anyJustPressed）互不消费，而且事件派发与 state 的
     * update() 谁先谁后不可靠。按 ESC 时输入组件会自己把 focusOn 清空，那时候要是
     * 去判 focusOn，就会把"退出搜索框"误判成"退出整个界面"。
     */
    var focusZone:Int = ZONE_DEFAULT;
    /** 键盘选中的卡片下标 */
    var selectedIndex:Int = 0;
    /**
     * 搜索框里按回车已经处理过的那一帧。
     *
     * ENTER 同时是搜索框的"跳到结果"和界面的 ACCEPT 键，而 KeyboardEvent 和
     * FlxG.keys 谁先触发不确定 → 用这个闩把同帧的 ACCEPT 吞掉，两种时序都安全。
     */
    var searchEnterHandled:Bool = false;

    /**
     * 是否处于「键盘导航模式」——决定要不要画键盘选中环。
     *
     * 默认 false：刚进界面**不画**任何键盘选中视觉，只有真按了方向键 / TAB / 回车才打开；
     * 鼠标一动（或点一下）就关掉 —— 鼠标操作时只剩卡片自己的 hover 色，鼠标离开就没了。
     *
     * ⚠️ 它只管**视觉**：selectedIndex 照旧由鼠标悬停同步，所以鼠标离开后再按方向键
     * 是从鼠标最后悬停的那张卡继续。
     */
    var keyboardNav:Bool = false;

    // 分类数据
    var categoryData:Array<CategoryData> = [];

    // 分类选项树缓存：搜索统计 + 进入分类页共用同一份构建结果，避免重复构建
    var optionCache:Map<String, OptionCategory> = [];
    /** 预构建队列：每帧只构建一个，避免第一次搜索时卡顿 */
    var prewarmQueue:Array<String> = [];

    // 底部返回按钮
    var backButton:Win10BackButton;

    // 右下角：深浅色切换
    var themeButton:OptionButton;
    var themeOption:Option;
    /** 已套用的主题版本号：和 UITheme.version 不一致时说明要重建 */
    var themeVersion:Int = -1;

    // 返回状态
    public static var stateType:Int = 0;
    var backCheck:Bool = false;

    override function create()
    {
		FlxG.mouse.visible = true;
        if (stateType != 2) {
            Paths.clearStoredMemory();
            Paths.clearUnusedMemory();
        }

        persistentUpdate = persistentDraw = true;
        instance = this;

        // ---------- 主题 ----------
        UITheme.ensure();
        themeVersion = UITheme.version;
        // 原有的两个配色字段也跟着主题走，方便外部直接取用
        baseColor = UITheme.base;
        mainColor = UITheme.sidebar;

        // ---------- 分类数据 ----------
        buildCategoryData();
        // 分类选项树延后到 update 里逐个构建（每帧一个），保证打开界面不卡
        prewarmQueue = [for (d in categoryData) d.id];

        // ---------- 鼠标事件 ----------
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

        cataMove = { velocity: 0.0, inputAllow: true };

        // ---------- 背景 ----------
        // 用白色图形 + color 着色，切主题时只要改 color 就行
        background = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
        background.color = UITheme.windowBG;
        background.scrollFactor.set();
        add(background);

        // 半透明遮罩
        overlay = new Rect(0, 0, FlxG.width, FlxG.height, 0, 0, UITheme.overlay, UITheme.overlayAlpha);
        overlay.scrollFactor.set();
        add(overlay);

        var searchW = FlxG.width * 0.2;
        var searchH = FlxG.height * 0.04;
        var searchX = (FlxG.width - searchW) / 2;
        var searchY = FlxG.height * 0.06;

        searchComp = new Win10SearchBar(searchX, searchY, searchW, searchH, 16);
        searchComp.setPlaceholder(Language.getPhrase('options.search.hint', 'Search settings'));
        searchComp.onChange = function(oldText:String, newText:String) {
            buildCards(newText);
        };
        // 搜索框里按回车 = 跳到卡片网格（Win10 行为）。PsychUIInputText 的默认实现是
        // 直接取消焦点，那样用户还得再按一次下键才进得去。
        searchComp.input.onPressEnter = function(e) {
            PsychUIInputText.focusOn = null;
            searchEnterHandled = true;
            setKeyboardNav(true);
            setFocusZone(ZONE_DEFAULT);
        };
        searchComp.scrollFactor.set();
        add(searchComp);

        // 搜索框下方的结果统计行
        resultText = new FlxText(0, searchY + searchH + 8, FlxG.width, '', 13);
        resultText.setFormat(Paths.font('montserrat.ttf'), 13, UITheme.textSecondary, CENTER);
        resultText.antialiasing = ClientPrefs.data.antialiasing;
        resultText.visible = false;
        resultText.scrollFactor.set();
        add(resultText);

        // ---------- 卡片网格 ----------
        cardContainer = new FlxSpriteGroup();
        cardContainer.scrollFactor.set();
        add(cardContainer);
        buildCards();

        buildBackButton();

        // ---------- 右下角：深浅色切换 ----------
        buildThemeButton();

        super.create();
    }

    // =========================================================
    // 分类数据：8 大类，默认英文
    // 第 5 个参数是卡片左侧的图标种类名，见 options.objects.main.CategoryIcons
    // =========================================================
    function buildCategoryData()
    {
        categoryData = [
            new CategoryData(
                'Basics',
                ['Basic Settings', 'Basics'],
                ['Language', 'Keybinds', 'Note Colors'],
                '',
                'keyboard'
            ),
            new CategoryData(
                'Gameplay',
                ['Gameplay', 'Gameplay'],
                ['Downscroll', 'Ghost Tapping', 'Timing'],
                '',
                'arrow'
            ),
            new CategoryData(
                'Skin',
                ['Skin', 'Skin'],
                ['Note Skins', 'Splashes', 'Judgements'],
                '',
                'palette'
            ),
            new CategoryData(
                'Components',
                ['Components', 'Components'],
                ['Hit Error Bar', 'Keyboard', 'Counter'],
                '',
                'hiterror'
            ),
            new CategoryData(
                'GameUI',
                ['In-Game UI', 'Game UI'],
                ['HUD', 'Time Bar', 'Score Screen'],
                '',
                'hud'
            ),
            new CategoryData(
                'OuterUI',
                ['Outer UI', 'Outer UI'],
                ['Freeplay', 'Main Menu', 'Transition'],
                '',
                'menu'
            ),
            new CategoryData(
                'Graphics',
                ['Graphics', 'Graphics'],
                ['Resolution', 'Framerate', 'Shaders'],
                '',
                'gpu'
            ),
            new CategoryData(
                'Advanced',
                ['Engine', 'Advanced'],
                ['Updates', 'Discord RPC', 'Reset'],
                '',
                'debug'
            ),
        ];
    }

    // =========================================================
    // 构建卡片网格（Win10 风格）
    //
    // 搜索时：
    //   - 统计每个大类里有多少个选项命中（含子分类），显示在卡片右上角徽标上；
    //   - 命中数从多到少排序，命中最多的排最前面；
    //   - 命中 0 项但名字/标签本身命中的大类仍然保留，只是淡显并显示 0。
    // =========================================================
    function buildCards(filterText:String = '')
    {
        // 先把旧卡片上的 hover / 选中色 tween 掐掉，免得它们继续往即将脱离绘制树的 bg 上写 color。
        // 注意 `FlxSpriteGroup.clear()` **不 destroy** 成员（flixel 源码注释明说 "does not destroy()"），
        // 这里也**故意不补 destroy**：卡片的 icon 指向 CategoryIcons 静态缓存里的**共享 FlxGraphic**，
        // 而 `FlxGraphic.destroyOnNoUse` 默认 true —— destroy 掉一个 sprite 就会把这份共享图的
        // useCount 减到 0、触发 `FlxG.bitmap.remove()` 把它 dispose 掉，屏幕上其它卡片立刻变白。
        // （CategoryIcons 现在会判活重画，但没必要每重建一次就把图拆一遍。）
        for (card in cardGroup)
        {
            FlxTween.cancelTweensOf(card);
            if (card.bg != null) FlxTween.cancelTweensOf(card.bg);
        }

        cardContainer.clear();
        cardGroup = [];

        var query = OptionSearch.normalize(filterText);
        searchQuery = query;
        var searching = query.length > 0;

        var entries:Array<CategoryEntry> = [];
        var totalMatches = 0;
        var hitCategories = 0;

        for (data in categoryData)
        {
            var count = 0;
            if (searching)
            {
                var built = getCategoryOptions(data.id);
                count = (built != null) ? OptionSearch.countInCategory(built, query) : 0;
            }

            if (!searching || count > 0 || categoryMatchesQuery(data, query))
            {
                entries.push({data: data, count: count, order: entries.length});

                if (searching)
                {
                    totalMatches += count;
                    if (count > 0) hitCategories++;
                }
            }
        }

        if (searching)
        {
            entries.sort(function(a, b) {
                var diff = b.count - a.count;
                return (diff != 0) ? diff : (a.order - b.order);
            });
        }

        var cols = cardCols;
        var cardW = FlxG.width * 0.20;   // 稍宽
        var cardH = FlxG.height * 0.11;  // 更矮 → 长方形
        var gapX = FlxG.width * 0.012;
        var gapY = FlxG.height * 0.012;

        var totalW = cols * cardW + (cols - 1) * gapX;
        var startX = (FlxG.width - totalW) / 2;
        var startY = FlxG.height * 0.2;

        for (i in 0...entries.length) {
            var col = i % cols;
            var row = Math.floor(i / cols);
            var cx = startX + col * (cardW + gapX);
            var cy = startY + row * (cardH + gapY);

            var card = new CategoryCard(cx, cy, cardW, cardH, entries[i].data, onCardClick);
            card.setSearchState(entries[i].count, searching);
            cardGroup.push(card);
            cardContainer.add(card);
        }

        updateSearchSummary(searching, totalMatches, hitCategories);

        // 卡片数量变了（搜索过滤 / 切主题重建）→ 把键盘选中夹回合法范围并重画
        selectedIndex = Std.int(FlxMath.bound(selectedIndex, 0, Math.max(0, cardGroup.length - 1)));
        updateCardSelection();
    }

    // =========================================================
    // 键盘导航
    // =========================================================

    /** 把"哪张卡片被键盘选中"同步到卡片本体 */
    function updateCardSelection():Void
    {
        // keyboardNav 把关：没真的用过键盘就一个环都不画（鼠标悬停的高亮由卡片自己管）
        var show:Bool = keyboardNav && focusZone == ZONE_CARDS;
        for (i in 0...cardGroup.length)
            cardGroup[i].setSelected(show && i == selectedIndex);
    }

    /** 开关「键盘导航模式」（= 要不要画选中环），只在状态真的变了时重画 */
    function setKeyboardNav(v:Bool):Void
    {
        if (keyboardNav == v) return;
        keyboardNav = v;
        updateCardSelection();
    }

    /**
     * 本帧有没有按"导航类"按键。
     *
     * syncSelectionFromMouse() 跑在键盘分支**之后**，鼠标抖一下会把刚点亮的选中环收掉
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

        updateCardSelection();
    }

    /** Tab / Shift+Tab 在两个区域之间循环 */
    function cycleZone(step:Int):Void
    {
        setFocusZone(FlxMath.wrap(focusZone + step, 0, ZONE_COUNT - 1));
    }

    /**
     * 卡片网格里移动选中。
     * 左右 ±1、上下 ±cardCols；上边界继续按上 → 焦点回搜索框（下边界只 clamp，不穿越）。
     */
    function moveCardSelection(dx:Int, dy:Int):Void
    {
        if (cardGroup.length == 0)
        {
            if (dy < 0) setFocusZone(ZONE_SEARCH);
            return;
        }

        var next:Int = selectedIndex;
        if (dx != 0) next += dx;
        if (dy != 0) next += dy * cardCols;

        if (dy < 0 && next < 0)
        {
            setFocusZone(ZONE_SEARCH);
            return;
        }

        next = Std.int(FlxMath.bound(next, 0, cardGroup.length - 1));
        if (next == selectedIndex) return;

        selectedIndex = next;
        updateCardSelection();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    /** 回车打开当前选中的分类（音效由 onCardClick 播） */
    function openSelectedCard():Void
    {
        if (selectedIndex < 0 || selectedIndex >= cardGroup.length) return;
        onCardClick(cardGroup[selectedIndex].data);
    }

    // =========================================================
    // 搜索框里的按键判定
    //
    // ClientPrefs.defaultKeys 里 `ui_down` = [S, DOWN]、`back` = [BACKSPACE, ESCAPE]，
    // 而搜索框是在"打字"，直接吃 controls.UI_DOWN_P / controls.BACK 的话：
    //   - 打一个 "s" 就会把焦点踹出搜索框（键盘导航新引入的问题）
    //   - 按退格删字也会踹出去（这个是原来的老 bug，顺手一起修了）
    // 所以搜索框聚焦时把"字母别名"排掉，只认真正的方向键 / 功能键；手柄那一路照常。
    // =========================================================
    inline function searchDownPressed():Bool
        return controls.UI_DOWN_P && !FlxG.keys.justPressed.S;

    inline function searchBackPressed():Bool
        return (controls.BACK && !FlxG.keys.justPressed.BACKSPACE) || FlxG.mouse.justPressedRight;

    /**
     * 鼠标移动时接管选中。
     *
     * 只认"鼠标真的动了"（deltaView != 0）或者"点了一下"：否则鼠标静静停在某张卡上时，
     * 键盘按方向键会被悬停项每帧拽回去。正在打字时整段跳过 —— 鼠标搁在卡片上轻微一抖
     * 就抢走焦点会让搜索没法用。
     *
     * 鼠标一接管就 `setKeyboardNav(false)`：收掉键盘选中环，只留卡片自己的 hover 色，
     * 鼠标离开卡片后屏幕上干干净净，不会留一张永远高亮的卡。
     * 但同一帧里按了导航键就让位给键盘（键盘分支跑在这之前，否则会被这一句立刻关掉）。
     */
    function syncSelectionFromMouse():Void
    {
        if (PsychUIInputText.focusOn != null) return;
        if (FlxG.mouse.deltaViewX == 0 && FlxG.mouse.deltaViewY == 0 && !FlxG.mouse.justPressed) return;

        if (!navKeyJustPressed()) setKeyboardNav(false);

        for (i in 0...cardGroup.length)
        {
            if (!cardGroup[i].onFocus) continue;

            var zoneChanged:Bool = (focusZone != ZONE_CARDS);
            if (zoneChanged) focusZone = ZONE_CARDS;

            if (zoneChanged || selectedIndex != i)
            {
                selectedIndex = i;
                updateCardSelection();
            }
            return;
        }
    }

    /** 刷新搜索框下方的统计文案 */
    function updateSearchSummary(searching:Bool, total:Int, categories:Int)
    {
        if (resultText == null) return;

        if (!searching)
        {
            resultText.visible = false;
            resultText.text = '';
            return;
        }

        resultText.visible = true;

        if (total <= 0)
        {
            resultText.color = UITheme.textSecondary;
            resultText.text = Language.getPhrase('options.search.noResults',
                'No settings found for "{1}"', [searchQuery]);
            return;
        }

        resultText.color = UITheme.accent;
        resultText.text = Language.getPhrase('options.search.summary',
            '{1} settings found in {2} categories',
            [Std.string(total), Std.string(categories)]);
    }

    // =========================================================
    // 分类选项树（带缓存）
    // =========================================================
    function buildCategoryOptions(id:String):OptionCategory
    {
        return switch (id)
        {
            case 'Basics':     BasicsData.build();
            case 'Gameplay':   GameplayData.build();
            case 'Skin':       SkinData.build();
            case 'Components': ComponentsData.build();
            case 'GameUI':     GameUIData.build();
            case 'OuterUI':    OuterUIData.build();
            case 'Graphics':   GraphicsData.build();
            case 'Advanced':   AdvancedData.build();
            default:           null;
        }
    }

    /**
     * 取某个大类的选项树（首次访问时构建并缓存）。
     * 搜索统计和进入分类页共用同一份实例，避免同一分类被构建两次。
     */
    public function getCategoryOptions(id:String):OptionCategory
    {
        if (id == null) return null;

        var cached = optionCache.get(id);
        if (cached != null) return cached;

        var built = buildCategoryOptions(id);
        if (built != null) optionCache.set(id, built);

        return built;
    }

    function buildBackButton()
    {
        var btnW = 220;
        var btnH = 44;
        var btnX = 0;
        var btnY = FlxG.height - btnH - 20;

        backButton = new Win10BackButton(
            btnX, btnY, btnW, btnH,
            Language.getPhrase('options.back', 'back'),
            function() { backMenu(); }
        );
        backButton.scrollFactor.set();
        add(backButton);
    }

    // =========================================================
    // 右下角：深浅色切换按钮（复用 OptionButton，配色跟随主题）
    // =========================================================
    function buildThemeButton()
    {
        var btnW = 220;
        var btnH = 44;
        var btnX = FlxG.width - btnW - 20;
        var btnY = FlxG.height - btnH - 20;

        // 复用已有的 colorMode 字段，只把它当成一个"动作"来用
        themeOption = new Option('Theme', 'Switch between dark and light mode',
            'colorMode', Option.OptionType.ACTION);
        themeOption.actionLabel = themeButtonLabel();
        themeOption.action = function() { UITheme.toggle(); };

        themeButton = new OptionButton(btnX, btnY, btnW, btnH, themeOption, false, 14);
        themeButton.scrollFactor.set();
        add(themeButton);
    }

    inline function themeButtonLabel():String
    {
        return UITheme.isLight
            ? Language.getPhrase('options.theme.dark', 'Dark Mode')
            : Language.getPhrase('options.theme.light', 'Light Mode');
    }

    function categoryMatchesQuery(data:CategoryData, query:String):Bool
    {
        var title = Language.getPhrase('options.category.' + data.id + '.title', data.getDisplayName());
        var tagText = Language.getPhrase('options.category.' + data.id + '.tags', data.tags.join(' · '));
        var haystack = [data.id, title, data.getSubName(), tagText, data.desc].join(' ').toLowerCase();
        return haystack.indexOf(query) >= 0;
    }

    // =========================================================
    // 卡片点击
    // =========================================================
	function onCardClick(data:CategoryData)
	{
		FlxG.sound.play(Paths.sound('confirmMenu'));

		var cat = getCategoryOptions(data.id);
		if (cat == null)
		{
			trace('Category not wired yet: ' + data.id);
			return;
		}

		// 带着当前搜索词进入分类页，进去后直接就是过滤结果 + 各子分类命中数
		MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}, searchQuery));
	}

    // =========================================================
    // 返回
    // =========================================================
    function backMenu()
    {
        if (!backCheck) {
            backCheck = true;
            FlxG.sound.play(Paths.sound('cancelMenu'));
            ClientPrefs.saveSettings();

            switch (stateType) {
                case 0: MusicBeatState.switchState(new MainMenuState());
                case 1: MusicBeatState.switchState(new FreeplayState());
                case 2:
                    MusicBeatState.switchState(new PlayState());
                    FlxG.mouse.visible = false;
            }
            stateType = 0;
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

        // 分类选项树预构建：每帧只建一个，避免第一次搜索时一次性卡顿
        if (prewarmQueue.length > 0)
        {
            var nextId = prewarmQueue.shift();
            if (nextId != null) getCategoryOptions(nextId);
        }

        if (controls.BACK || FlxG.mouse.justPressedRight) {
            // 判 focusZone 而不是 PsychUIInputText.focusOn：按 ESC 时输入组件会自己
            // 先把 focusOn 清掉，那一帧再判 focusOn 就会直接退出整个界面。
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
                backMenu();
            }
            searchEnterHandled = false;
            return;
        }

        // 焦点双向同步。必须放在上面 BACK 分支**之后**：ESC 那帧 focusZone 还停在
        // ZONE_SEARCH，先同步的话会被改成 ZONE_DEFAULT，BACK 分支就变成"关界面"了。
        if (focusZone != ZONE_SEARCH && searchComp != null && PsychUIInputText.focusOn == searchComp.input)
            setFocusZone(ZONE_SEARCH);
        else if (focusZone == ZONE_SEARCH && PsychUIInputText.focusOn == null)
            setFocusZone(ZONE_DEFAULT);

        // ---------- Tab：区域循环 ----------
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
            // 搜索框聚焦时方向键归输入组件（左右移动光标），但 ↓ 是空的
            // —— PsychUIInputText 的 onKeyDown 只吃左右 / ESC / ENTER ——
            // 所以 ↓ 用来"跳到卡片网格"（Win10 也是这个行为）。
            if (searchDownPressed())
            {
                setKeyboardNav(true);
                setFocusZone(ZONE_DEFAULT);
            }
            searchEnterHandled = false;
        }
        else if (searchEnterHandled)
        {
            // 搜索框里按回车已经处理过的那一帧，ACCEPT 要吞掉，
            // 否则会顺手把第一张卡片也打开。
            searchEnterHandled = false;
        }
        else
        {
            // 键盘真的在操作了 → 点亮选中环（默认状态是不画的）
            if (controls.UI_LEFT_P || controls.UI_RIGHT_P || controls.UI_UP_P || controls.UI_DOWN_P || controls.ACCEPT)
                setKeyboardNav(true);

            if (controls.UI_LEFT_P)  moveCardSelection(-1, 0);
            if (controls.UI_RIGHT_P) moveCardSelection(1, 0);
            if (controls.UI_UP_P)    moveCardSelection(0, -1);
            if (controls.UI_DOWN_P)  moveCardSelection(0, 1);
            if (controls.ACCEPT)     openSelectedCard();
        }

        syncSelectionFromMouse();
    }

    // =========================================================
    // 预留接口，供 Level 1 / Level 2 调用
    // =========================================================
    public function changeLanguage() {
        for (card in cardGroup) card.changeLanguage();
    }

    // =========================================================
    // 深浅色主题
    // =========================================================
    /** 按当前主题重新套用配色（卡片 / 按钮按新配色重建） */
    function applyTheme()
    {
        if (background != null) background.color = UITheme.windowBG;

        if (overlay != null)
        {
            overlay.color = UITheme.overlay;
            overlay.alpha = UITheme.overlayAlpha;
        }

        // 卡片：重建以套用新配色，同时保留当前搜索过滤
        var query:String = (searchComp != null && searchComp.input != null) ? searchComp.input.text : '';
        buildCards(query != null ? query : '');

        if (searchComp != null) searchComp.refreshTheme();
        if (backButton != null) backButton.refreshTheme();

        if (themeOption != null) themeOption.actionLabel = themeButtonLabel();
        if (themeButton != null) themeButton.setActionText(themeOption.actionLabel);
    }

    /**
     * 销毁时一定要把 instance 清掉。
     *
     * 之前这里没清，离开设置页之后 `OptionsState.instance` 仍然指着这个已经销毁的
     * state。控件（NumButton）在别的界面里还会去读它的 mouseEvent / specBG / downBG，
     * 而这些成员早已被 destroy（scrollFactor 被置 null），一调 overlaps 就崩。
     */
    override function destroy()
    {
        if (instance == this) instance = null;
        mouseEvent = null;
        specBG = null;
        downBG = null;
        super.destroy();
    }
}

// =========================================================
// 搜索时的卡片条目：分类数据 + 命中数（order 用于同分时保持原顺序）
// =========================================================
typedef CategoryEntry = {
    var data:CategoryData;
    var count:Int;
    var order:Int;
}

// =========================================================
// 分类数据
// =========================================================
class CategoryData
{
    public var id:String;           // 英文标识，用于 switch
    public var names:Array<String>; // [主名称, 副名称]
    public var tags:Array<String>;  // 卡片上显示的 3 个小标签
    public var desc:String;         // 描述（当前卡片未使用，保留供分类页使用）
    public var icon:String;         // 卡片左侧图标种类名，见 options.objects.main.CategoryIcons

    public function new(id:String, names:Array<String>, tags:Array<String>, desc:String, ?icon:String)
    {
        this.id = id;
        this.names = names;
        this.tags = tags;
        this.desc = desc;
        this.icon = (icon != null) ? icon : 'generic';
    }

    public function getDisplayName():String
    {
        return names[0];
    }

    public function getSubName():String
    {
        return names.length > 1 ? names[1] : '';
    }
}