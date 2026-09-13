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

    // 卡片网格
    var cardGroup:Array<CategoryCard> = [];
    var cardContainer:FlxSpriteGroup;

    // 分类数据
    var categoryData:Array<CategoryData> = [];

    // 底部返回按钮
    // var backButton:GeneralBack;   // 预留

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

        // ---------- 分类数据 ----------
        buildCategoryData();

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
        background = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        background.scrollFactor.set();
        add(background);

        // 半透明遮罩
        overlay = new Rect(0, 0, FlxG.width, FlxG.height, 0, 0, 0x000000, 0.5);
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

        // ---------- 卡片网格 ----------
        cardContainer = new FlxSpriteGroup();
        cardContainer.scrollFactor.set();
        add(cardContainer);
        buildCards();

        // ---------- 底部返回按钮 ----------
        // 预留：backButton = new GeneralBack(...);
        // add(backButton);

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
    // =========================================================
    function buildCards(filterText:String = '')
    {
        cardContainer.clear();
        cardGroup = [];

        var filteredCategoryData:Array<CategoryData> = [];
        var query = filterText.trim().toLowerCase();

        for (data in categoryData) {
            if (query.length == 0 || categoryMatchesQuery(data, query)) {
                filteredCategoryData.push(data);
            }
        }

        var cols = 4;
        var cardW = FlxG.width * 0.20;   // 稍宽
        var cardH = FlxG.height * 0.11;  // 更矮 → 长方形
        var gapX = FlxG.width * 0.012;
        var gapY = FlxG.height * 0.012;

        var totalW = cols * cardW + (cols - 1) * gapX;
        var startX = (FlxG.width - totalW) / 2;
        var startY = FlxG.height * 0.2;

        for (i in 0...filteredCategoryData.length) {
            var col = i % cols;
            var row = Math.floor(i / cols);
            var cx = startX + col * (cardW + gapX);
            var cy = startY + row * (cardH + gapY);

            var card = new CategoryCard(cx, cy, cardW, cardH, filteredCategoryData[i], onCardClick);
            cardGroup.push(card);
            cardContainer.add(card);
        }
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

		switch (data.id)
		{
			case 'Basics':
				var cat = BasicsData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			case 'Gameplay':
				var cat = GameplayData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			case 'Skin':
				var cat = SkinData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			case 'Components':
				var cat = ComponentsData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			case 'GameUI':
				var cat = GameUIData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			case 'OuterUI':
				var cat = OuterUIData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			case 'Graphics':
				var cat = GraphicsData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			case 'Advanced':
				var cat = AdvancedData.build();
				MusicBeatState.switchState(new OptionsPageState([cat], cat, function() {}));

			default:
				trace('Category not wired yet: ' + data.id);
		}
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
        super.update(elapsed);

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
    public function changeTip(str:String) {}
    public function resetData() {}
    public function changeLanguage() {
        for (card in cardGroup) card.changeLanguage();
    }

    public function changeCata(cataSort:Int, memSort:Int) {}
    public function addCata(type:String, follow:Dynamic, mem:Dynamic, extraPath:String = '') {}
    public function addMove(tar:Dynamic) {}
    public function cataMoveEvent() {}
    public function cataMoveChange() {}
    public function naviMoveEvent() {}
    public function changeNavi(navi:Dynamic, isOpened:Bool, naviTime:Float = 0.45) {}
    public function specChange() {}
    public function moveState(type:Int) {}
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