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
    // =========================================================
    function buildCategoryData()
    {
        categoryData = [
            new CategoryData(
                'Basics',
                ['Basic Settings', 'Basics'],
                ['Language', 'Keybinds', 'Note Colors'],
                ''
            ),
            new CategoryData(
                'Gameplay',
                ['Gameplay', 'Gameplay'],
                ['Downscroll', 'Ghost Tapping', 'Timing'],
                ''
            ),
            new CategoryData(
                'Skin',
                ['Skin', 'Skin'],
                ['Note Skins', 'Splashes', 'Judgements'],
                ''
            ),
            new CategoryData(
                'Components',
                ['Components', 'Components'],
                ['Hit Error Bar', 'Keyboard', 'Counter'],
                ''
            ),
            new CategoryData(
                'GameUI',
                ['In-Game UI', 'Game UI'],
                ['HUD', 'Time Bar', 'Score Screen'],
                ''
            ),
            new CategoryData(
                'OuterUI',
                ['Outer UI', 'Outer UI'],
                ['Freeplay', 'Main Menu', 'Transition'],
                ''
            ),
            new CategoryData(
                'Graphics',
                ['Graphics', 'Graphics'],
                ['Resolution', 'Framerate', 'Shaders'],
                ''
            ),
            new CategoryData(
                'Advanced',
                ['Engine', 'Advanced'],
                ['Updates', 'Discord RPC', 'Reset'],
                ''
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

        var cols = 4;
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
            if (PsychUIInputText.focusOn != null) {
                 PsychUIInputText.focusOn = null;
                FlxG.sound.play(Paths.sound('cancelMenu'));
             } else {
                backMenu();
             }
        }
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

    public function new(id:String, names:Array<String>, tags:Array<String>, desc:String)
    {
        this.id = id;
        this.names = names;
        this.tags = tags;
        this.desc = desc;
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