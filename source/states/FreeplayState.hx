package states;

import backend.DiffRating;
import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.SongArtConfig;
import backend.SongMetaConfig;
import backend.SongInfoParser;
import backend.CustomChartData;
import backend.CustomChartMetadata;

import objects.HealthIcon;

// Freeplay 专用组件全在 states.freeplay 下，一条通配导入省得逐个维护
import states.freeplay.*;

import backend.AlbumConfig;
import options.psychoptions.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import shaders.MosaicEffect;

import haxe.Json;

import flixel.addons.display.FlxBackdrop;

import openfl.filters.BlurFilter;
import backend.FlxFilteredSprite;
import openfl.filters.BitmapFilterQuality;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

class FreeplayState extends MusicBeatState
{
    public static var selectedCustomChartCategory:String = null;
    public var songs:Array<NewSongMetaData> = [];
    // 只保留当前可视范围的卡片对象；歌曲全集仍由 songs 元数据保存。
    var cards:Array<FreeplayCard> = [];
    
    // 用于模组文件夹管理
    var allSongs:Array<NewSongMetaData> = []; // 所有歌曲
    var songsByFolder:Map<String, Array<NewSongMetaData>> = new Map(); // 按模组分类的歌曲
    var currentFolderFilter:String = null; // 当前模组过滤器（null 表示显示全部）

    var selector:FlxText;
	public static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
    // 用于鼠标滚动/拖拽的滚动位置（以索引像素为单位，spacing 为每项高度）
    public var cardScrollPos:Float = 0;
    var cardScroller:backend.MouseMove;
    inline static var CARD_SPACING:Int = 80;
	public var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();
    
    var space:FlxSprite;
    var basicBG:FlxSprite;
    var starsBG:FlxBackdrop;
    var starsFG:FlxBackdrop;
    
    var menuBg:FlxSprite;
    var intendedColor:Int;

    var bgEffect:MosaicEffect;
    var bgEffectTween:FlxTween;
    
    var cornerGlow:FlxSprite;
    
    // 独立的艺术图显示模块
    var songArtDisplay:SongArtDisplay;
    var characterArtDisplay:CharacterArtDisplay;
    var albumArtDisplay:AlbumArtDisplay;
    var difficultyCarousel:DifficultyCarousel;

    var scoreBG:FlxFilteredSprite;
    var scoreText:FlxText;
    var diffText:FlxText;
    var noteCountText:FlxText;
    var difficultyRatingText:FlxText;
    var modFolderText:FlxText;
    // 右下角补充信息（音乐人 / 谱师 / 游玩次数），纯文字，无面板
    var musicanText:FlxText;
    var charterText:FlxText;
    var playCountText:FlxText;
    var lerpScore:Int = 0;
    var lerpRating:Float = 0;
    var intendedScore:Int = 0;
    var intendedRating:Float = 0;

    var missingTextBG:FlxSprite;
	var missingText:FlxText;
    
    var bottomString:String;
    var bottomText:FlxText;
    var bottomBG:FlxFilteredSprite;
    var toolBar:ToolBar;
    
    var topBar:FlxFilteredSprite;
    
    var instPlaying:Int = -1;
    public static var vocals:FlxSound = null;
    public static var opponentVocals:FlxSound = null;
    var holdTime:Float = 0;
    var stopMusicPlay:Bool = false;
    
    var mouseOverCard:Int = -1;
    var visibleCardMin:Int = 0;
    var visibleCardMax:Int = -1;
    // 卡片绘制的锚点：懒加载的卡片插入到它之前，保证始终画在背景/信息栏的底层。
    var cardLayer:FlxSprite;
    
    public var musicPlayer:MusicPlayerLegacy;

    var replayButton:FlxSprite;
    
    var freeplaySongCache:Map<String, Dynamic> = new Map<String, Dynamic>();
    var freeplayCacheDirty:Bool = false;
    var difficultyPreloadQueue:Array<Dynamic> = [];
    var menuBgGraphicCache:Map<String, Dynamic> = new Map<String, Dynamic>();
        
    var updateTimer:Float = 0;
    var updateInterval:Float = 0.033; // 约 30fps 刷新卡片位置（视觉上足够平滑）

    public var inModFolderSelector:Bool = false; // 当前是否在模组文件夹选择器中

    var searchHitbox:FlxSprite;
    var searchLabel:FlxText;

    inline function isPureChartMode():Bool
    {
        if (Paths.currentChartCategory == null && selectedCustomChartCategory != null)
            Paths.currentChartCategory = selectedCustomChartCategory;
        return (Paths.currentChartCategory != null && Paths.currentChartCategory.length > 0)
            || (selectedCustomChartCategory != null && selectedCustomChartCategory.length > 0);
    }

    override function create()
    {
        // 状态边界先清掉上一界面留下的非本地资源，再建立本界面的局部缓存。
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory();
        persistentUpdate = true;
        PlayState.isStoryMode = false;
        freeplaySongCache = loadFreeplaySongCache();
        WeekData.reloadWeekFiles(false);
        options.keoptions.KEOptionsMenu.isFreeplay = true;
        options.keoptions.KEOptionsMenu.onPlayState = false;

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Freeplay Menu", null);
        #end

        if(WeekData.weeksList.length < 1 && !isPureChartMode())
        {
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
			function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
			function() MusicBeatState.switchState(new states.MainMenuState())));
            return;
        }

        // 加载歌曲
        for (i in 0...WeekData.weeksList.length)
        {
            if(weekIsLocked(WeekData.weeksList[i])) continue;

            var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
            
            WeekData.setDirectoryFromWeek(leWeek);
            for (song in leWeek.songs)
            {
                var colors:Array<Int> = song[2];
                if(colors == null || colors.length < 3)
                {
                    colors = [146, 113, 253];
                }
                addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
            }
        }

        allSongs = songs.copy();
        if (ClientPrefs.data.freeplayModFolder)
        {
            for (song in allSongs)
            {
                var folder = (song.folder == null || song.folder.length == 0) ? "base" : song.folder;
                if (!songsByFolder.exists(folder))
                    songsByFolder.set(folder, []);
                songsByFolder.get(folder).push(song);
            }

        }

        if (isPureChartMode())
        {
            songs = [];
            Paths.currentChartDirectory = null;
            #if sys
            loadCustomChartSongs();
            #end
        }

        if (songs.length == 0)
        {
            FlxTransitionableState.skipNextTransIn = true;
            persistentUpdate = false;
            MusicBeatState.switchState(new states.ErrorState("NO CUSTOM CHARTS FOUND.",
                function() MusicBeatState.switchState(new states.MainMenuState()),
                function() MusicBeatState.switchState(new states.MainMenuState())));
            return;
        }

        Mods.loadTopMod();
        if (isPureChartMode())
            Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;

        SongArtConfig.loadAllConfigs();
        SongMetaConfig.loadAllConfigs();
        // 艺术图与背景按当前歌曲懒加载，避免歌曲/模组数量把 Freeplay 入口峰值推高。

        if (songs.length == 0)
        {
            menuBg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        }
        else
        {
            if (curSelected >= songs.length || curSelected < 0)
                curSelected = 0;

            var menuBgGraphic:Dynamic = getMenuDesatGraphicForFolder(songs[curSelected].folder);
            menuBg = new FlxSprite().loadGraphic(menuBgGraphic);
        }

        menuBg.antialiasing = ClientPrefs.data.antialiasing;
        menuBg.alpha = 1;
        add(menuBg);
        menuBg.screenCenter();

        bgEffect = new MosaicEffect();
        menuBg.shader = bgEffect.shader;

        if (ClientPrefs.data.freeplayspace)
        {
            space = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
            space.antialiasing = ClientPrefs.data.antialiasing;
            space.updateHitbox();
            space.scrollFactor.set();
            space.alpha = 0;
            add(space);

            starsBG = new FlxBackdrop(Paths.image('starBG'));
            starsBG.setPosition(111.3, 67.95);
            starsBG.antialiasing = true;
            starsBG.updateHitbox();
            starsBG.scrollFactor.set();
            starsBG.alpha = 0;
            add(starsBG);

            starsFG = new FlxBackdrop(Paths.image('starFG'));
            starsFG.setPosition(54.3, 59.45);
            starsFG.updateHitbox();
            starsFG.antialiasing = true;
            starsFG.scrollFactor.set();
            starsFG.alpha = 0;
            add(starsFG);

            cornerGlow = new FlxSprite().loadGraphic(Paths.image('freeplay/backGlow'));
            cornerGlow.antialiasing = true;
            cornerGlow.updateHitbox();
            cornerGlow.scrollFactor.set();
            cornerGlow.color = FlxColor.RED;
            cornerGlow.alpha = 0;
            cornerGlow.x = FlxG.width - cornerGlow.width + 100;
            cornerGlow.y = FlxG.height - cornerGlow.height + 120;
            add(cornerGlow);
        }
        characterArtDisplay = new CharacterArtDisplay();
        add(characterArtDisplay);

        songArtDisplay = new SongArtDisplay();
        add(songArtDisplay);

        // 专辑封面：没配 characterArt 的歌由它顶上右侧同一个位置（判断在 showCharacterForIndex）
        albumArtDisplay = new AlbumArtDisplay();
        add(albumArtDisplay);

        if (ClientPrefs.data.freeplayspace)
        {
            space.alpha = 1;
            starsBG.alpha = 1;
            starsFG.alpha = 1;
            cornerGlow.alpha = 0.7;
        }
        
        initializeCardSlots();

        // 卡片分层的占位锚点：必须是不可见、不参与鼠标判定的普通元素，
        // 懒加载的卡片都插在它前面，绘制顺序等价于“卡片在背景之上、UI 之下”。
        cardLayer = new FlxSprite();
        cardLayer.visible = false;
        cardLayer.active = false;
        add(cardLayer);

        cardScrollPos = curSelected * CARD_SPACING;

        cardScroller = new backend.MouseMove(this, 'cardScrollPos', [0, Math.max(0, (songs.length - 1) * CARD_SPACING)], [[0, FlxG.width], [0, FlxG.height]], function() { computeVisibleCardRange(); updateCardsPosition(); });
        cardScroller.useLerp = true;
        cardScroller.lerpSmooth = 12;
        cardScroller.dragSensitivity = 1.6;
        cardScroller.deceleration = 0.94;
        cardScroller.mouseWheelSensitivity = -200.0;
        add(cardScroller);

        scoreText = new FlxText(FlxG.width * 0.7, 85, 0, "", 32);
        scoreText.antialiasing = ClientPrefs.data.antialiasing;
        scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

        scoreBG = new FlxFilteredSprite(scoreText.x - 6, 85);
        scoreBG.makeGraphic(1, 66, 0xFF000000);
        scoreBG.alpha = 0.8;
        scoreBG.filters = [new BlurFilter(40, 40, BitmapFilterQuality.HIGH)];
        add(scoreBG);
        add(scoreText);

        diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
        diffText.antialiasing = ClientPrefs.data.antialiasing;
        diffText.font = scoreText.font;
        add(diffText);

        // 难度改由下方 carousel 展示。这个控件留着不删 —— changeDiff 和
        // positionHighscore 还在写它的 text / x。
        diffText.visible = false;

        noteCountText = new FlxText(scoreText.x, scoreText.y + 66, 0, "", 20);
        noteCountText.antialiasing = ClientPrefs.data.antialiasing;
        noteCountText.font = scoreText.font;
        noteCountText.color = 0xFFAAAAAA;
        add(noteCountText);

        difficultyRatingText = new FlxText(scoreText.x, scoreText.y + 90, 0, "", 20);
        difficultyRatingText.antialiasing = ClientPrefs.data.antialiasing;
        difficultyRatingText.font = scoreText.font;
        difficultyRatingText.color = DiffRating.getColorFromRating(0);
        add(difficultyRatingText);

        // 右下角补充信息：音乐人 / 谱师 / 游玩次数（FE 风格，纯文字，无面板）
        // 往下挪，给难度 carousel 让位（carousel 占 FlxG.height*0.75 上下各 28px）
        musicanText = makeSongMetaText(FlxG.height - 140);
        charterText = makeSongMetaText(FlxG.height - 116);
        playCountText = makeSongMetaText(FlxG.height - 92);
        add(musicanText);
        add(charterText);
        add(playCountText);

        if (ClientPrefs.data.freeplayspace)
        {
            topBar = new FlxFilteredSprite(0, 0 );
            topBar.loadGraphic(Paths.image('freeplay/topBar'));
            topBar.alpha = 0.8;
            add(topBar);
        }
        else
        {
            topBar = new FlxFilteredSprite(-100, -75);
            topBar.makeGraphic(FlxG.width + 200, 185, 0xFF000000);
            topBar.filters = [new BlurFilter(40, 40, BitmapFilterQuality.HIGH)];
            topBar.alpha = 0.75;
            add(topBar);
        }

        // 必须在 topBar 之后 add —— 卡片都插在 cardLayer 之前，只有排在 topBar 后面的
        // 元素才画在卡片之上。中心 x 取 FlxG.width - 200，和角色图/专辑封面的中心对齐。
        difficultyCarousel = new DifficultyCarousel(FlxG.width - 200, FlxG.height * 0.75);
        add(difficultyCarousel);


       if (ClientPrefs.data.freeplaySearch)
        {
            // 隐藏背景（增大点击区域）
            searchHitbox = new FlxSprite(0, 0);
            searchHitbox.makeGraphic(240, 50, FlxColor.TRANSPARENT);
            searchHitbox.x = (FlxG.width - searchHitbox.width) / 2;
            searchHitbox.y = 6;
            searchHitbox.scrollFactor.set();
            add(searchHitbox);
            
            // 搜索图标（放大镜）
            var searchIcon:FlxSprite = new FlxSprite(0, 0);
            searchIcon.loadGraphic(Paths.image('freeplay/search_icon')); // 需要准备图标，或使用文本替代
            if (searchIcon.graphic == null)
            {
                // 如果没有图标，用文本替代
                searchIcon = null;
                var iconText:FlxText = new FlxText(0, 8, 0, "🔍", 20);
                iconText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
                iconText.x = (FlxG.width - 240) / 2 + 10;
                iconText.y = 10;
                iconText.scrollFactor.set();
                add(iconText);
            }
            else
            {
                searchIcon.setGraphicSize(20, 20);
                searchIcon.updateHitbox();
                searchIcon.x = (FlxG.width - 240) / 2 + 12;
                searchIcon.y = 14;
                searchIcon.scrollFactor.set();
                add(searchIcon);
            }
            
            // 搜索提示文字
            searchLabel = new FlxText(0, 0, 0, "Search songs...", 18);
            searchLabel.antialiasing = ClientPrefs.data.antialiasing;
            searchLabel.setFormat(Paths.font("vcr.ttf"), 18, 0xFFAAAAAA, LEFT);
            searchLabel.x = (FlxG.width - 240) / 2 + 38;
            searchLabel.y = 13;
            searchLabel.scrollFactor.set();
            add(searchLabel);
            
            // 底部线条
            var lineBg:FlxSprite = new FlxSprite(0, 0);
            lineBg.makeGraphic(200, 1, FlxColor.WHITE);
            lineBg.alpha = 0.25;
            lineBg.x = (FlxG.width - lineBg.width) / 2;
            lineBg.y = 42;
            lineBg.scrollFactor.set();
            add(lineBg);
            
            // 悬停/点击高亮线条（默认透明）
            var highlightLine:FlxSprite = new FlxSprite(0, 0);
            highlightLine.makeGraphic(200, 2, FlxColor.WHITE);
            highlightLine.alpha = 0;
            highlightLine.x = (FlxG.width - highlightLine.width) / 2;
            highlightLine.y = 42;
            highlightLine.scrollFactor.set();
            add(highlightLine);
        }

        var modDisplayText:String = "Mod: ";
        if (ClientPrefs.data.freeplayModFolder)
        {
            modDisplayText += (Mods.currentModDirectory == null ? "ALL" : Mods.currentModDirectory);
        }
        else
        {
            modDisplayText += Mods.currentModDirectory;
        }
        
        modFolderText = new FlxText(10, 50, 0, modDisplayText, 24);
        modFolderText.antialiasing = ClientPrefs.data.antialiasing;
        modFolderText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
        add(modFolderText);

        missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
        missingText.antialiasing = ClientPrefs.data.antialiasing;
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

        if(curSelected >= songs.length) curSelected = 0;
        if (curSelected >= 0 && curSelected < songs.length) {
            menuBg.color = songs[curSelected].color;
            intendedColor = menuBg.color;
        }
        lerpSelected = curSelected;

        curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

        var leText:String = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
        bottomString = leText;
        var size:Int = 16;

        if (ClientPrefs.data.toolBar)
        {
            toolBar = new ToolBar(this, FlxG.width + 200, 50);
            add(toolBar);

            bottomBG = new FlxFilteredSprite(0, FlxG.height - 26);
            bottomBG.makeGraphic(FlxG.width, 26, 0xFF000000);
            bottomBG.alpha = 0;
            add(bottomBG);

            bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
            bottomText.alpha = 0;
            bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
            bottomText.scrollFactor.set();
            add(bottomText);
        }
        else
        {
            bottomBG = new FlxFilteredSprite(0, FlxG.height - 26);
            bottomBG.makeGraphic(FlxG.width +200, 30, 0xFF000000);
            bottomBG.alpha = 0.6;
            bottomBG.filters = [new BlurFilter(4, 4, BitmapFilterQuality.HIGH)];
            add(bottomBG);

            bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
            bottomText.antialiasing = ClientPrefs.data.antialiasing;
            bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
            bottomText.scrollFactor.set();
            add(bottomText);
        }

        replayButton = new FlxSprite(FlxG.width - 200, 0);
        replayButton.loadGraphic(Paths.image('replay'));
        replayButton.antialiasing = ClientPrefs.data.antialiasing;
        replayButton.scrollFactor.set(); 
        replayButton.setGraphicSize(200, 100);
        replayButton.updateHitbox();
        replayButton.alpha = 0.8;  
        add(replayButton);

        musicPlayer = new MusicPlayerLegacy(this);
        add(musicPlayer);

        Mods.currentModDirectory = songs[curSelected].folder;
        if (isPureChartMode())
            setCustomDifficultyList(songs[curSelected]);
        else
        {
            PlayState.storyWeek = songs[curSelected].week;
            Difficulty.loadFromWeek();
        }
        
        changeDiff();
        // carousel 在 create 早期就 new 出来了，但那时 Difficulty.list 还没定；
        // 这里（loadFromWeek / setCustomDifficultyList 之后）才是首次填充。
        rebuildDifficultyCarousel();
        showArtForIndex(curSelected, false);
        showCharacterForIndex(curSelected, false);
        updateCornerGlow();
        updateCardsPosition();
        updateCardsRating();
        updateSongInfoTexts();
        
        FlxG.mouse.visible = true;
        
        super.create();
    }


    override function closeSubState()
    {
        persistentUpdate = true;
        // 子状态期间本 state 暂停更新，鼠标的按下/松开事件都没被处理，
        // 恢复更新前先丢掉过期的输入状态，否则第一帧会被误判成拖拽而取消跳转
        if (cardScroller != null)
            cardScroller.resetInputState();
        super.closeSubState();

        refreshCurrentSelectionAfterSubState();
    }

    private function refreshCurrentSelectionAfterSubState():Void
    {
        if (songs == null || songs.length == 0)
            return;

        if (curSelected < 0 || curSelected >= songs.length)
            curSelected = 0;

        updateSongInfoTexts();
        updateCardDifficultyInfo();
        updateTexts();
        rebuildDifficultyCarousel();

        var start:Int = visibleCardMin;
        var end:Int = visibleCardMax;
        if (start < 0) start = 0;
        if (end < start || end >= cards.length)
            end = cards.length - 1;

        for (i in start...end + 1)
        {
            if (i >= 0 && i < cards.length && cards[i] != null)
                cards[i].updateRatingSprite();
        }

        if (curSelected >= 0 && curSelected < cards.length && cards[curSelected] != null)
            cards[curSelected].updateRatingSprite();
    }

    public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
    {
        var song = new NewSongMetaData(songName, weekNum, songCharacter, color);
        var cacheKey:String = getFreeplaySongCacheKey(songName, song.folder);
        
        var weekData = WeekData.weeksLoaded.get(WeekData.weeksList[weekNum]);
        var difficulties:Array<String> = [];
        
        if (weekData != null)
        {
            WeekData.setDirectoryFromWeek(weekData);
            Difficulty.loadFromWeek(weekData);
            
            if (weekData.difficulties != null && weekData.difficulties.length > 0)
            {
                var diffStr:String = weekData.difficulties;
                difficulties = diffStr.split(',');
                for (i in 0...difficulties.length)
                {
                    difficulties[i] = difficulties[i].trim();
                }
                Difficulty.copyFrom(difficulties);
            }
            else
            {
                difficulties = Difficulty.defaultList.copy();
            }

            // 从 week.json 的 songs 元组里取音乐人 / 谱师（旧版 3 元组会返回 null）
            var songEntry:Array<Dynamic> = WeekData.findSongEntry(weekData, songName);
            if (songEntry != null)
            {
                song.songMusican = WeekData.getSongMusican(songEntry);
                song.songCharters = WeekData.getSongCharters(songEntry);
            }
        }
        else
        {
            trace('WARNING: Week data not found for week index $weekNum');
            difficulties = Difficulty.defaultList.copy();
        }

        var cachedEntry:Dynamic = freeplaySongCache.get(cacheKey);
        if (cachedEntry != null)
        {
            song.difficultyInfo = buildSongInfoMapFromCache(cachedEntry, difficulties);
            var missingDiffs:Array<String> = getMissingDifficulties(cachedEntry, difficulties);
            if (missingDiffs.length == 0)
            {
                songs.push(song);
                return;
            }
            difficultyPreloadQueue.push({ song: song, songName: songName, folder: song.folder, difficulties: missingDiffs, weekData: weekData, cacheKey: cacheKey });
            songs.push(song);
            return;
        }

        difficultyPreloadQueue.push({ song: song, songName: songName, folder: song.folder, difficulties: difficulties, weekData: weekData, cacheKey: cacheKey });
        songs.push(song);
    }

    #if sys
    private function loadCustomChartSongs():Void
    {
        var category:String = Paths.currentChartCategory != null && Paths.currentChartCategory.length > 0
            ? Paths.currentChartCategory : selectedCustomChartCategory;
		if ((category == null || category.length == 0) && ClientPrefs.data.customChartFolder != null)
			category = ClientPrefs.data.customChartFolder;
        for (customSong in CustomChartData.load(category))
        {
            var chart:NewSongMetaData = new NewSongMetaData(customSong.name, -1, 'bf', FlxColor.fromRGB(146, 113, 253));
            chart.folder = '';
            chart.customChart = new CustomChartMetadata(customSong);
            chart.difficultyInfo = cast chart.customChart.difficultyInfo;
            songs.push(chart);

            var missingInfo:Array<String> = [];
            for (difficulty in chart.customChart.difficulties)
            {
                if (!isParsedSongInfoValid(chart.difficultyInfo.get(difficulty)))
                    missingInfo.push(difficulty);
            }
            if (missingInfo.length > 0)
                difficultyPreloadQueue.push({customChart: chart.customChart});
        }
    }

    #end

    private function loadCustomChart(index:Int):Bool
    {
        if (index < 0 || index >= songs.length || songs[index].customChart == null || !songs[index].customChart.isValid())
            return false;

        var chart:NewSongMetaData = songs[index];
        try
        {
            Paths.currentChartCategory = chart.customChart.category;
            if (chart.customChart.sourceFolder != null && chart.customChart.sourceFolder.length > 0)
                Paths.currentChartCategory = chart.customChart.sourceFolder;
            selectedCustomChartCategory = Paths.currentChartCategory;
            Paths.currentChartDirectory = chart.customChart.directory;
            Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
            var difficultyName:String = Difficulty.getString(curDifficulty, false);
            var lowerDifficulty:String = difficultyName == null ? '' : difficultyName.toLowerCase();
			Paths.currentChartHasVSliceMetadata = chart.customChart.category.toLowerCase() == 'v_slice';
            Paths.currentChartAudioSuffix = Paths.currentChartHasVSliceMetadata && (lowerDifficulty == 'erect' || lowerDifficulty == 'pico') ? lowerDifficulty : null;
            PlayState.chartCategory = Paths.currentChartCategory;
            PlayState.chartDirectory = Paths.currentChartDirectory;
            PlayState.chartHasVSliceMetadata = Paths.currentChartHasVSliceMetadata;
            PlayState.chartAudioSuffix = Paths.currentChartAudioSuffix;
            var loaded:SwagSong = cast CustomChartData.loadChart(chart.customChart.song, difficultyName);

            if (loaded == null) return false;
            PlayState.SONG = loaded;
            PlayState.SONG.song = chart.songName;
            return true;
        }
        catch (e:Dynamic)
        {
            trace('Failed to load custom chart: $e');
            return false;
        }
    }
    private function getFreeplaySongCacheKey(songName:String, folder:String):String
    {
        return (folder == null ? '' : folder) + '|' + songName;
    }

    private function isSongCacheEntryValid(entry:Dynamic, difficulties:Array<String>):Bool
    {
        if (entry == null || entry.data == null) return false;
        for (diffName in difficulties)
        {
            if (Reflect.field(entry.data, diffName) == null) return false;
        }
        return true;
    }

    private function buildSongInfoMapFromCache(entry:Dynamic, difficulties:Array<String>):Map<String, ParsedSongInfo>
    {
        var result:Map<String, ParsedSongInfo> = new Map();
        if (entry == null || entry.data == null)
            return result;

        for (diffName in difficulties)
        {
            var info:Dynamic = Reflect.field(entry.data, diffName);
            if (isParsedSongInfoValid(info))
                result.set(diffName, cast info);
        }
        return result;
    }

    private function getMissingDifficulties(entry:Dynamic, difficulties:Array<String>):Array<String>
    {
        var missing:Array<String> = [];
        if (entry == null || entry.data == null)
            return difficulties.copy();

        for (diffName in difficulties)
        {
            if (!isParsedSongInfoValid(Reflect.field(entry.data, diffName)))
                missing.push(diffName);
        }
        return missing;
    }

    private function isParsedSongInfoValid(info:Dynamic):Bool
    {
        if (info == null)
            return false;

        var requiredFields:Array<String> = [
            'bpm', 'length', 'formattedLength', 'noteCount',
            'playerNoteCount', 'opponentNoteCount', 'difficultyRating',
            'difficultyRatingPlayer', 'difficultyRatingOpponent',
            'difficultyRatingCoop', 'ratingText', 'ratingColor'
        ];
        for (field in requiredFields)
        {
            if (!Reflect.hasField(info, field) || Reflect.field(info, field) == null)
                return false;
        }

        // album 只要求"键存在"，不要求非空 —— 没有专辑的歌写的就是 null。
        // 这同时是缓存格式的门：加 album 之前写的缓存条目没有这个键，会被判无效、
        // 整条重新解析一次。少了它，旧缓存永远命中，专辑封面一直拿不到 id。
        if (!Reflect.hasField(info, 'album'))
            return false;

        return true;
    }

    private function buildFreeplayCacheEntry(infoMap:Map<String, ParsedSongInfo>):Dynamic
    {
        var entry:Dynamic = {};
        entry.data = {};
        for (diffName in infoMap.keys())
        {
            var info:ParsedSongInfo = infoMap.get(diffName);
            if (info == null)
                continue;

            Reflect.setField(entry.data, diffName, {
                bpm: info.bpm,
                length: info.length,
                formattedLength: info.formattedLength,
                noteCount: info.noteCount,
                playerNoteCount: info.playerNoteCount,
                opponentNoteCount: info.opponentNoteCount,
                difficultyRating: info.difficultyRating,
                difficultyRatingPlayer: info.difficultyRatingPlayer,
                difficultyRatingOpponent: info.difficultyRatingOpponent,
                difficultyRatingCoop: info.difficultyRatingCoop,
                ratingText: info.ratingText,
                ratingColor: info.ratingColor,
                // 缓存必须带上 album，否则开了 saveFreeplayCache 的玩家拿不到封面。
                // 注意 isParsedSongInfoValid 的 requiredFields 不能加它 —— 老缓存没这个字段。
                album: info.album
            });
        }
        return entry;
    }

    private function loadFreeplaySongCache():Map<String, Dynamic>
    {
        var cache:Map<String, Dynamic> = new Map();
        if (!ClientPrefs.data.saveFreeplayCache)
            return cache;

        #if sys 
        var cachePath:String = 'freeplaySongCache.json';
        if (FileSystem.exists(cachePath))
        {
            try
            {
                var raw:String = File.getContent(cachePath);
                var parsed:Dynamic = Json.parse(raw);
                if (parsed != null)
                {
                    for (key in Reflect.fields(parsed))
                    {
                        var entry:Dynamic = Reflect.field(parsed, key);
                        if (entry != null && entry.data != null)
                            cache.set(key, entry);
                    }
                }
            }
            catch(e:Dynamic)
            {
                trace('Failed to load Freeplay cache: $e');
            }
        }
        #end
        return cache;
    }

    private function saveFreeplaySongCache():Void
    {
        if (!ClientPrefs.data.saveFreeplayCache)
            return;
        trace('cache saved');
        #if sys 
        var cachePath:String = 'freeplaySongCache.json';
        var tempPath:String = cachePath + '.tmp';
        var output = File.write(tempPath, false);
        try
        {
            output.writeString('{');
            var isFirst:Bool = true;
            for (key in freeplaySongCache.keys())
            {
                var entry:Dynamic = freeplaySongCache.get(key);
                if (entry == null || entry.data == null)
                    continue;

                if (!isFirst)
                    output.writeString(',');
                output.writeString(Json.stringify(key));
                output.writeString(':');
                output.writeString(Json.stringify(entry));
                isFirst = false;
            }
            output.writeString('}');
        }
        catch (e:Dynamic)
        {
            output.close();
            throw e;
        }
        output.close();
        if (FileSystem.exists(cachePath))
            FileSystem.deleteFile(cachePath);
        FileSystem.rename(tempPath, cachePath);
        freeplayCacheDirty = false;
        #end
    }

    private function getMenuDesatGraphicForFolder(folder:String):Dynamic
    {
        var key:String = folder == null ? '' : folder;
        var cached:Dynamic = menuBgGraphicCache.get(key);
        if (cached != null)
            return cached;

        return cacheMenuDesatGraphic(folder);
    }

    private function cacheMenuBgGraphics():Void
    {
        var folderSet:Map<String, Bool> = new Map<String, Bool>();
        for (song in songs)
        {
            var folder:String = song.folder == null ? '' : song.folder;
            if (folderSet.get(folder) == null)
                folderSet.set(folder, true);
        }

        for (folder in folderSet.keys())
            cacheMenuDesatGraphic(folder);
    }

    private function cacheMenuDesatGraphic(folder:String):Dynamic
    {
        var key:String = folder == null ? '' : folder;
        if (menuBgGraphicCache.get(key) != null)
            return menuBgGraphicCache.get(key);

        #if MODS_ALLOWED
        var oldModDir:String = Mods.currentModDirectory;
        if (folder == null || folder == '' || folder == "base")
            Mods.currentModDirectory = null;
        else
            Mods.currentModDirectory = folder;
        #end

        var graphic:Dynamic = Paths.image('menuDesat');
        #if MODS_ALLOWED
        if (graphic == null)
        {
            Mods.currentModDirectory = null;
            graphic = Paths.image('menuDesat');
        }
        Mods.currentModDirectory = oldModDir;
        #end

        menuBgGraphicCache.set(key, graphic);
        return graphic;
    }

    function weekIsLocked(name:String):Bool
    {
        var leWeek:WeekData = WeekData.weeksLoaded.get(name);
        return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
    }

    function updateCardsRating()
    {
        if (songs.length == 0) return;
        var start:Int = Std.int(Math.max(0, visibleCardMin));
        var end:Int = Std.int(Math.min(songs.length - 1, visibleCardMax));
        if (end < start) return;
        for (i in start...end + 1)
        {
            var card:FreeplayCard = cards[i];
            if (card != null) card.updateRatingSprite();
        }
    }

    inline function computeVisibleCardRange():Void
    {
        if (inModFolderSelector) return;
        if (songs.length == 0)
        {
            visibleCardMin = 0;
            visibleCardMax = -1;
            return;
        }

        visibleCardMin = Std.int(Math.floor(lerpSelected - 5));
        if (visibleCardMin < 0) visibleCardMin = 0;
        visibleCardMax = Std.int(Math.ceil(lerpSelected + 5));
        if (visibleCardMax >= songs.length) visibleCardMax = songs.length - 1;
    }

    private function initializeCardSlots():Void
    {
        cards = [];
        for (i in 0...songs.length) cards.push(null);
        visibleCardMin = 0;
        visibleCardMax = -1;
    }

    private function ensureCard(index:Int):FreeplayCard
    {
        if (index < 0 || index >= songs.length) return null;
        var card:FreeplayCard = cards[index];
        if (card != null) return card;

        var oldModDir:String = Mods.currentModDirectory;
        Mods.currentModDirectory = songs[index].folder;
        card = new FreeplayCard(0, 0, songs[index].songName, songs[index].songCharacter, songs[index].color, songs[index].week);
        Mods.currentModDirectory = oldModDir;
        card.targetY = index;
        cards[index] = card;
        // 懒加载会让卡片在后续帧才创建：FlxGroup.draw 按 members 顺序绘制，
        // 直接 add 会排在背景/分数栏之后。这里显式插到背景组之前，保证卡片仍在底层。
        if (cardLayer != null) insert(members.indexOf(cardLayer), card);
        else add(card);
        return card;
    }

    private function releaseCard(index:Int):Void
    {
        if (index < 0 || index >= cards.length) return;
        var card:FreeplayCard = cards[index];
        if (card == null) return;
        remove(card);
        card.destroy();
        cards[index] = null;
    }

    function updateCardsPosition()
    {
        if (songs.length == 0 || inModFolderSelector) return;

        var oldMin:Int = visibleCardMin;
        var oldMax:Int = visibleCardMax;
        computeVisibleCardRange();

        if (oldMax >= 0)
        {
            for (i in oldMin...oldMax + 1)
                if (i < visibleCardMin || i > visibleCardMax) releaseCard(i);
        }

        for (i in visibleCardMin...visibleCardMax + 1)
        {
            var card:FreeplayCard = ensureCard(i);
            if (card != null) card.updatePosition(lerpSelected, curSelected, true);
        }
    }

    function updateTexts()
    {
        var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
        if(ratingSplit.length < 2) ratingSplit.push('');
        
        while(ratingSplit[1].length < 2) ratingSplit[1] += '0';
            
        scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
        positionHighscore();
    }

    function positionHighscore()
    {
        scoreText.x = FlxG.width - scoreText.width - 6;
        scoreBG.scale.x = FlxG.width - scoreText.x + 6;
        scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
        diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
        diffText.x -= diffText.width / 2;
    }
    
    function updateCornerGlow()
    {
        if (cornerGlow == null) return;

        if (songs == null || songs.length == 0 || curSelected < 0 || curSelected >= songs.length)
        {
            FlxTween.cancelTweensOf(cornerGlow);
            cornerGlow.alpha = 0;
            return;
        }

        var targetColor = songs[curSelected].color;
        FlxTween.cancelTweensOf(cornerGlow);
        FlxTween.color(cornerGlow, 0.5, cornerGlow.color, targetColor);
    }

    function getModeDifficultyRating(diffInfo:ParsedSongInfo):Float
    {
        if (diffInfo == null) return 0.0;
        var mode:String = ClientPrefs.getGameplaySetting('opponentplay');
        switch (mode)
        {
            case 'opponent': return diffInfo.difficultyRatingOpponent;
            case 'coop': return diffInfo.difficultyRatingCoop;
            case 'coop-split': return diffInfo.difficultyRatingCoop;
            default: return diffInfo.difficultyRatingPlayer;
        }
    }

    function updateCardDifficultyInfo()
    {
        if (songs.length == 0) return;
        var currentDiffName = Difficulty.getString(curDifficulty, false);
        var start:Int = Std.int(Math.max(0, visibleCardMin));
        var end:Int = Std.int(Math.min(songs.length - 1, visibleCardMax));
        if (end < start) return;

        for (i in start...end + 1)
        {
            var card:FreeplayCard = cards[i];
            if (card == null) continue;
            var diffInfo:ParsedSongInfo = songs[i].difficultyInfo.get(currentDiffName);
            if (diffInfo != null)
                card.updateDifficultyInfo(diffInfo.bpm, diffInfo.formattedLength, diffInfo.noteCount, getModeDifficultyRating(diffInfo), diffInfo.keyCount);
            else
                card.updateDifficultyInfo(0, "0:00", 0, 0.0, 0);
        }
    }
    
    function updateSongInfoTexts()
    {
        if (songs == null || songs.length == 0 || curSelected < 0 || curSelected >= songs.length)
        {
            if (noteCountText != null)
                noteCountText.text = Language.getPhrase('freeplay_notes_missing', 'NOTES: --');
            if (difficultyRatingText != null)
            {
                difficultyRatingText.text = Language.getPhrase('freeplay_rating_missing', 'RATING: --');
                difficultyRatingText.color = DiffRating.getColorFromRating(0);
            }
            updateSongMetaTexts();
            return;
        }

        var currentSong = songs[curSelected];
        var currentDiffName = Difficulty.getString(curDifficulty, false);
        
        var diffInfo = currentSong.difficultyInfo.get(currentDiffName);
        
        if (diffInfo != null)
        {
            noteCountText.text = Language.getPhrase('freeplay_notes_side', 'PLAYER: {1} / OPPONENT: {2}', [diffInfo.playerNoteCount, diffInfo.opponentNoteCount]);
            var rating:Float = getModeDifficultyRating(diffInfo);
            difficultyRatingText.text = Language.getPhrase('freeplay_rating', 'RATING: {1}', [rating]);
            difficultyRatingText.color = DiffRating.getColorFromRating(rating);
        }
        else
        {
            noteCountText.text = Language.getPhrase('freeplay_notes_missing', 'NOTES: --');
            difficultyRatingText.text = Language.getPhrase('freeplay_rating_missing', 'RATING: --');
            difficultyRatingText.color = DiffRating.getColorFromRating(0);
        }

        updateSongMetaTexts();
    }

    function makeSongMetaText(y:Float):FlxText
    {
        var t:FlxText = new FlxText(FlxG.width - 320, y, 300, "", 18);
        t.setFormat(Paths.font("vcr.ttf"), 18, 0xFFAAAAAA, RIGHT, OUTLINE, FlxColor.BLACK);
        t.borderSize = 1;
        t.antialiasing = ClientPrefs.data.antialiasing;
        t.scrollFactor.set();
        return t;
    }

    /**
     * 右下角补充信息：音乐人 / 谱师 / 游玩次数。
     * 数据来源优先级：songMeta.json 覆盖层 > week.json 元组 > 留空（该行不显示）。
     */
    function updateSongMetaTexts()
    {
        if (musicanText == null || charterText == null || playCountText == null) return;

        if (!ClientPrefs.data.freeplaySongMeta)
        {
            musicanText.visible = charterText.visible = playCountText.visible = false;
            return;
        }
        musicanText.visible = charterText.visible = playCountText.visible = true;

        if (songs == null || songs.length == 0 || curSelected < 0 || curSelected >= songs.length)
        {
            musicanText.text = "";
            charterText.text = "";
            playCountText.text = "";
            return;
        }

        var song:NewSongMetaData = songs[curSelected];

        var musican:String = SongMetaConfig.getMusicanForSong(song.songName, song.folder);
        if (musican == null || musican.length == 0) musican = song.songMusican;
        musicanText.text = (musican != null && musican.length > 0)
            ? Language.getPhrase('freeplay_musican', 'BY: {1}', [musican]) : "";

        var diffName:String = Difficulty.getString(curDifficulty, false);
        var charter:String = SongMetaConfig.getCharterForSong(song.songName, diffName, curDifficulty, song.folder);
        if ((charter == null || charter.length == 0) && song.songCharters != null && song.songCharters.length > 0)
        {
            var idx:Int = curDifficulty;
            if (idx < 0) idx = 0;
            if (idx >= song.songCharters.length) idx = song.songCharters.length - 1;
            charter = song.songCharters[idx];
        }
        charterText.text = (charter != null && charter.length > 0)
            ? Language.getPhrase('freeplay_charter', 'CHARTER: {1}', [charter]) : "";

        var songLowercase:String = Paths.formatToSongPath(song.songName);
        var plays:Int = Highscore.getPlayCount(songLowercase, curDifficulty, song.folder, ClientPrefs.getGameplaySetting('opponentplay'));
        playCountText.text = Language.getPhrase('freeplay_plays', 'PLAYS: {1}', [plays]);
    }
    
    public function togglePlaySong():Void
    {
        if (curSelected < 0 || curSelected >= songs.length) return;

        // 如果已经在播放音乐，则停止
        if (musicPlayer.playingMusic)
        {
            releasePreviewAudio();
            if (FlxG.sound.music != null)
            {
                FlxG.sound.music.stop();
                FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
                FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
            }
            
            if (ClientPrefs.data.toolBar && toolBar != null)
            {
                toolBar.setNormalMode();
            }
            instPlaying = -1; // 重置播放状态
            return;
        }
        
        // ========== 开始播放音乐 ==========
        var songName:String = songs[curSelected].songName;
        var songLowercase:String = Paths.formatToSongPath(songName);
        var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
        
        try
        {
            destroyFreeplayVocals();

            Mods.currentModDirectory = songs[curSelected].folder;
            Paths.currentChartDirectory = null;
            
            #if sys
            if (songs[curSelected].customChart == null || !songs[curSelected].customChart.isValid())
            {
                var chartPath:String = Paths.modsJson(songLowercase + '/' + poop);
                if (!sys.FileSystem.exists(chartPath))
                {
                    chartPath = Paths.json(songLowercase + '/' + poop);
                    if (!sys.FileSystem.exists(chartPath))
                        throw new haxe.Exception('Chart file not found: $poop');
                }
            }
            #end
            
            if (songs[curSelected].customChart != null && songs[curSelected].customChart.isValid())
            {
                if (!loadCustomChart(curSelected))
                    throw new haxe.Exception('Unable to convert custom chart');
            }
            else
            {
                PlayState.SONG = Song.loadFromJson(poop, songLowercase);
            }
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDifficulty;
            
            #if DISCORD_ALLOWED
            DiscordClient.changePresence("Freeplay - Listening to " + songName, null);
            #end
            
            // 停止当前音乐
            if (FlxG.sound.music != null)
                FlxG.sound.music.stop();
            
            // 播放器音乐 (Inst)
            FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song, true, Paths.currentChartCategory), 0.7, false);
            FlxG.sound.music.pause(); // 先暂停，等用户点击播放
            
            // 音乐结束回调
            FlxG.sound.music.onComplete = function()
            {
                releasePreviewAudio();
                if (FlxG.sound.music != null)
                    FlxG.sound.music.time = 0;
                if (ClientPrefs.data.toolBar && toolBar != null)
                    toolBar.setNormalMode();
            };
            
            // ========== 加载人声 ==========
            // 玩家 Vocals
            if (PlayState.SONG.needsVoices)
            {
                vocals = new FlxSound();
                try
                {
                    var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
                    var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
                    if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
                    
                    if(loadedVocals != null && loadedVocals.length > 0)
                    {
                        vocals.load(loadedVocals);
                        FlxG.sound.list.add(vocals);
                        vocals.persist = vocals.looped = true;
                        vocals.volume = 0.8;
                        vocals.play();
                        vocals.pause();
                    }
                    else vocals = FlxDestroyUtil.destroy(vocals);
                }
                catch(e:Dynamic)
                {
                    vocals = FlxDestroyUtil.destroy(vocals);
                }
                
                // 对手 Vocals
                opponentVocals = new FlxSound();
                try
                {
                    var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
                    var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
                    
                    if(loadedVocals != null && loadedVocals.length > 0)
                    {
                        opponentVocals.load(loadedVocals);
                        FlxG.sound.list.add(opponentVocals);
                        opponentVocals.persist = opponentVocals.looped = true;
                        opponentVocals.volume = 0.8;
                        opponentVocals.play();
                        opponentVocals.pause();
                    }
                    else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
                }
                catch(e:Dynamic)
                {
                    opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
                }
            }
            else
            {
                // 无声音轨，创建空声音
                vocals = new FlxSound();
                vocals.load(Paths.voices(PlayState.SONG.song, "empty"));
                FlxG.sound.list.add(vocals);
                
                opponentVocals = new FlxSound();
                opponentVocals.load(Paths.voices(PlayState.SONG.song, "empty"));
                FlxG.sound.list.add(opponentVocals);
            }
            
            // 更新音乐播放器状态
            musicPlayer.playingMusic = true;
            musicPlayer.curTime = 0;
            musicPlayer.switchPlayMusic();
            musicPlayer.pauseOrResume(true); // 默认暂停，等待用户点击播放
            
            instPlaying = curSelected; // 记录当前播放的歌曲索引
            
            if (ClientPrefs.data.toolBar && toolBar != null)
            {
                toolBar.setMusicPlayerMode(songName, songs[curSelected].color);
            }
        }
        catch(e:haxe.Exception)
        {
            trace('ERROR: ${e.message}');
            FlxG.sound.play(Paths.sound('cancelMenu'));
        }
    }

    public function stopMusicAndReset():Void
    {
        if (musicPlayer.playingMusic)
        {
            releasePreviewAudio();
            FlxG.sound.play(Paths.sound('cancelMenu'));
            
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
            FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
            
            if (ClientPrefs.data.toolBar && toolBar != null)
            {
                toolBar.setNormalMode();
            }
        }
    }

    public function prevSong():Void
    {
        if (musicPlayer.playingMusic)
        {
            releasePreviewAudio();
            FlxG.sound.music.stop();
            
            var newIndex = curSelected - 1;
            if (newIndex < 0) newIndex = songs.length - 1;
            
            changeSelection(newIndex - curSelected);
            togglePlaySong();
        }
    }

    public function nextSong():Void
    {
        if (musicPlayer.playingMusic)
        {
            releasePreviewAudio();
            FlxG.sound.music.stop();
            
            var newIndex = curSelected + 1;
            if (newIndex >= songs.length) newIndex = 0;
            
            changeSelection(newIndex - curSelected);
            togglePlaySong();
        }
    }

    override function update(elapsed:Float)
    {
        if(WeekData.weeksList.length < 1 && !isPureChartMode())
            return;
        if (musicPlayer == null)
            return;
        if (ClientPrefs.data.freeplayspace)
        {
            starsBG.x -= 0.05;
            starsFG.x -= 0.15;
            
            if (starsBG.x < -starsBG.width) starsBG.x = 0;
            if (starsFG.x < -starsFG.width) starsFG.x = 0;
        }

        if (FlxG.sound.music.volume < 0.7 && !musicPlayer.playingMusic)
            FlxG.sound.music.volume += 0.5 * elapsed;

        lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
        lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

        if (Math.abs(lerpScore - intendedScore) <= 10)
            lerpScore = intendedScore;
        if (Math.abs(lerpRating - intendedRating) <= 0.01)
            lerpRating = intendedRating;

        var desiredIndex:Float = cardScrollPos / CARD_SPACING;
        lerpSelected = FlxMath.lerp(desiredIndex, lerpSelected, Math.exp(-elapsed * 9.6));

        if (Math.abs(lerpSelected - desiredIndex) < 0.0001) {
            lerpSelected = desiredIndex;
        }
        
        updateTimer += elapsed;
        updateCardsPosition();
        // 使用 updateInterval 控制刷新频率，避免每帧都更新文本和卡片位置
        if (updateTimer >= updateInterval)
        {
            updateTexts();
            updateTimer = 0;
        }

        // 每帧最多处理 1 个预加载任务（防止卡顿）
        if (difficultyPreloadQueue.length > 0)
        {
            var item = difficultyPreloadQueue.shift();
            try
            {
                #if sys
                if (item.customChart != null)
                {
                    CustomChartData.preloadInfo(item.customChart.song);
                    item.customChart.difficultyInfo = item.customChart.song.info;
                    for (i in 0...songs.length)
                    {
                        if (songs[i].customChart == item.customChart)
                        {
                            songs[i].difficultyInfo = cast item.customChart.difficultyInfo;
                            if (i < cards.length && cards[i] != null)
                                cards[i].updateRatingSprite();
                            break;
                        }
                    }
                }
                else
                #end
                {
                    var info = SongInfoParser.preloadAllDifficulties(item.songName, item.folder, item.difficulties, item.weekData);

                    // 合并进已有的 map，不能整体替换：命中缓存时 item.difficulties 只是
                    // 「缺的那几档」，替换会把已经解析好的评级丢掉，缓存条目也会被改写成只剩一半
                    // —— 症状是难度评级时有时无，且每次启动在两个子集之间来回翻转。
                    if (item.song.difficultyInfo == null)
                        item.song.difficultyInfo = new Map<String, ParsedSongInfo>();
                    for (diffName in info.keys())
                        item.song.difficultyInfo.set(diffName, info.get(diffName));

                    if (ClientPrefs.data.saveFreeplayCache)
                    {
                        var entry:Dynamic = freeplaySongCache.get(item.cacheKey);
                        if (entry == null || entry.data == null)
                            entry = {data: {}};
                        var fresh:Dynamic = buildFreeplayCacheEntry(info);
                        for (field in Reflect.fields(fresh.data))
                            Reflect.setField(entry.data, field, Reflect.field(fresh.data, field));
                        freeplaySongCache.set(item.cacheKey, entry);
                        freeplayCacheDirty = true;
                    }
                }
                if (item.customChart != null || item.song == songs[curSelected])
                {
                    updateCardDifficultyInfo();
                    updateSongInfoTexts();
                    // album 和评级数字都是异步到达的，到了要一起刷新
                    showCharacterForIndex(curSelected, false);
                    if (difficultyCarousel != null)
                        difficultyCarousel.refreshRatings(carouselRatingProvider);
                }
            }
            catch(e:Dynamic)
            {
                trace('Failed to preload song info: $e');
            }
        }
        else if (freeplayCacheDirty)
        {
            saveFreeplaySongCache();
        }

        if (!musicPlayer.playingMusic)
        {
            if (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0 || FlxG.mouse.justPressed || FlxG.mouse.wheel != 0)
                updateMouseInteraction();
        }

        // replay 按钮交互
        if (FlxG.mouse.overlaps(replayButton))
        {
            replayButton.alpha = 1.0;
            replayButton.scale.set(0.55, 0.55);
        }
        else
        {
            replayButton.alpha = 0.8;
            replayButton.scale.set(0.5, 0.5);
        }

        if (searchHitbox != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(searchHitbox) && !musicPlayer.playingMusic)
        {
            openSearchSubstate();
        }
        
        if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(replayButton))
        {
            if (curSelected < 0 || curSelected >= songs.length) return;
            
            FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
            persistentUpdate = false;
            openSubState(new LoadReplaySubState(
                this,
                songs[curSelected].songName,
                songs[curSelected].folder,
                Difficulty.getString(curDifficulty)
            ));
        }

        if (ClientPrefs.data.freeplayModFolder && FlxG.mouse.justPressed && FlxG.mouse.overlaps(modFolderText) && !musicPlayer.playingMusic && !inModFolderSelector)
        {
            openModFolderSelector();
        }

        // 点难度方块：点别的块 = 切难度（音效由 changeDiff -> setSelected 放），
        // 点当前选中的那块 = 直接开始这首歌。
        if (FlxG.mouse.justPressed && difficultyCarousel != null)
        {
            var hitDiff:Int = difficultyCarousel.tryClick();
            if (hitDiff >= 0)
            {
                if (hitDiff == curDifficulty)
                {
                    selectSong();
                }
                else
                {
                    changeDiff(hitDiff - curDifficulty);
                    _updateSongLastDifficulty();
                    updateCardDifficultyInfo();
                }
            }
        }

        var shiftMult:Int = 1;
        if(FlxG.keys.pressed.SHIFT && !musicPlayer.playingMusic) shiftMult = 3;

        if (!musicPlayer.playingMusic && PsychUIInputText.focusOn == null && !inModFolderSelector)
        {
            if(songs.length > 1)
            {
                if(FlxG.keys.justPressed.HOME)
                {
                    curSelected = 0;
                    changeSelection();
                    holdTime = 0;	
                }
                else if(FlxG.keys.justPressed.END)
                {
                    curSelected = songs.length - 1;
                    changeSelection();
                    holdTime = 0;	
                }
                if (controls.UI_UP_P)
                {
                    changeSelection(-shiftMult);
                    holdTime = 0;
                }
                if (controls.UI_DOWN_P)
                {
                    changeSelection(shiftMult);
                    holdTime = 0;
                }

                if(controls.UI_DOWN || controls.UI_UP)
                {
                    var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
                    holdTime += elapsed;
                    var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

                    if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
                        changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
                }
            
                if (controls.UI_LEFT_P)
                {
                    changeDiff(-1);
                    _updateSongLastDifficulty();
                    updateCardDifficultyInfo();
                }
                else if (controls.UI_RIGHT_P)
                {
                    changeDiff(1);
                    _updateSongLastDifficulty();
                    updateCardDifficultyInfo();
                }
            }
        }

        if (!inModFolderSelector && (controls.BACK || FlxG.mouse.justPressedRight))
        {
            if (PsychUIInputText.focusOn != null)
                return;
            
            if (musicPlayer.playingMusic)
            {
                releasePreviewAudio();
                FlxG.sound.play(Paths.sound('cancelMenu'));

                FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
                FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
            }
            else
            {
                persistentUpdate = false;
                FlxG.sound.play(Paths.sound('cancelMenu'));
                MusicBeatState.switchState(new MainMenuState());
            }
        }
        else if (!inModFolderSelector && PsychUIInputText.focusOn == null)
        {
            if(FlxG.keys.justPressed.CONTROL || FlxG.mouse.justPressedMiddle && !musicPlayer.playingMusic)
            {
                persistentUpdate = false;
                openSubState(new GameplayChangersSubstate());
            }
            else if (FlxG.keys.justPressed.ENTER && !musicPlayer.playingMusic)
            {
                selectSong();
            }
            else if (FlxG.keys.justPressed.SPACE)
            {
                togglePlaySong();
            }
        }

        if (!inModFolderSelector && PsychUIInputText.focusOn == null && controls.RESET && !musicPlayer.playingMusic)
        {
            if (curSelected < 0 || curSelected >= songs.length)
            {
                FlxG.sound.play(Paths.sound('cancelMenu'));
            }
            else
            {
                persistentUpdate = false;
                openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter, -1, songs[curSelected].folder));
                FlxG.sound.play(Paths.sound('scrollMenu'));
            }
        }

        if (ClientPrefs.data.toolBar && toolBar != null)
        {
            toolBar.update(elapsed);
        }

        if (!musicPlayer.playingMusic && toolBar != null)
        {
            toolBar.setNormalMode();
        }

        super.update(elapsed);

    }
    
    function updateMouseInteraction()
    {
        if (cards.length == 0) return;
        if (inModFolderSelector) return;
        if (FlxG.mouse.y >= FlxG.height - 50 || FlxG.mouse.y <= 85)
        {
            mouseOverCard = -1;
            return;
        }
        computeVisibleCardRange();
        var newMouseOverCard:Int = -1;
        for (i in visibleCardMin...visibleCardMax + 1)
        {
            var card:FreeplayCard = cards[i];
            if (card != null && card.checkMouseOver())
            {
                card.setAlpha(0.7);
                newMouseOverCard = i;
                break;
            }
        }
        
        if (FlxG.mouse.justPressed)
        {
            if (newMouseOverCard != -1)
            {
                if (newMouseOverCard != curSelected)
                {
                    curSelected = newMouseOverCard;
                    changeSelection();
                    for (i in visibleCardMin...visibleCardMax + 1)
                        if (cards[i] != null) cards[i].setAlpha(0.9);
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
                }
                else
                {
                    selectSong();
                }

                if (cardScroller != null)
                {
                    cardScroller.tweenData = curSelected * CARD_SPACING;
                }
            }
        }
        
        mouseOverCard = newMouseOverCard;
    }
    
    /**
     * 把当前选中的谱面加载进 PlayState.SONG（进入游戏 / 编辑器的公共部分）。
     * 成功返回 true；失败时写 missingText 并返回 false。
     */
    function loadSongIntoPlayState():Bool
    {
        if (curSelected < 0 || curSelected >= songs.length) return false;

        var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
        var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

        try
        {           
            Mods.currentModDirectory = songs[curSelected].folder;
            
            if (songs[curSelected].customChart != null && songs[curSelected].customChart.isValid())
            {
                if (!loadCustomChart(curSelected))
                    throw new haxe.Exception('Unable to convert custom chart');
            }
            else
            {
                Song.loadFromJson(poop, songLowercase);
            }
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDifficulty;

            if (!isPureChartMode())
                trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
        }
        catch(e:haxe.Exception)
        {
            trace('ERROR! ${e.message}');

            var errorStr:String = e.message;
            if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1);
            else errorStr += '\n\n' + e.stack;

            missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
            missingText.screenCenter(Y);
            missingText.visible = true;
            missingTextBG.visible = true;
            FlxG.sound.play(Paths.sound('cancelMenu'));

            return false;
        }

        return true;
    }

    /**
     * 游玩次数 +1。键走 Highscore.formatSong，保证模组隔离与 opponentplay 分档一致。
     * 练习模式 / botplay 默认不计（ClientPrefs.data.countPracticePlays）。
     */
    function countSongPlay():Void
    {
        if (curSelected < 0 || curSelected >= songs.length) return;

        var isPractice:Bool = ClientPrefs.getGameplaySetting('practice') == true;
        var isBotplay:Bool = ClientPrefs.getGameplaySetting('botplay') == true;
        if ((isPractice || isBotplay) && !ClientPrefs.data.countPracticePlays) return;

        var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
        Highscore.savePlayCount(songLowercase, curDifficulty, songs[curSelected].folder, ClientPrefs.getGameplaySetting('opponentplay'));
    }

    /**
     * 从 Freeplay 直接进入谱面编辑器（Toolbar 的 EDITOR 按钮）。
     * ChartingState 从 PlayState.SONG 读谱，所以必须先加载成功。
     */
    public function openChartEditor():Void
    {
        if (!loadSongIntoPlayState()) return;

        persistentUpdate = false;
        releasePreviewAudio();

        @:privateAccess
        if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
            Paths.freeGraphicsFromMemory();

        LoadingState.prepareToSong();
        LoadingState.loadAndSwitchState(new states.editors.ChartingState(), false);
        stopMusicPlay = true;

        destroyFreeplayVocals();
        #if (MODS_ALLOWED && DISCORD_ALLOWED)
        DiscordClient.loadModRPC();
        #end
    }

    function selectSong()
    {
        if (curSelected < 0 || curSelected >= songs.length) return;

        persistentUpdate = false;
        releasePreviewAudio();

        if (!loadSongIntoPlayState()) return;

        countSongPlay();

        @:privateAccess
        if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
        {
            trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
            Paths.freeGraphicsFromMemory();
        }
        LoadingState.prepareToSong();
        if(ClientPrefs.data.transitionType == "fade") FlxTransitionableState.skipNextTransOut = true;
        LoadingState.loadAndSwitchState(new PlayState());
        #if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
        stopMusicPlay = true;

        destroyFreeplayVocals();
        #if (MODS_ALLOWED && DISCORD_ALLOWED)
        DiscordClient.loadModRPC();
        #end
    }
    
    function getVocalFromCharacter(char:String)
    {
        try
        {
            var path:String = Paths.getPath('characters/$char.json', TEXT);
            #if MODS_ALLOWED
            var character:Dynamic = Json.parse(File.getContent(path));
            #else
            var character:Dynamic = Json.parse(Assets.getText(path));
            #end
            return character.vocals_file;
        }
        catch (e:Dynamic) {}
        return null;
    }

    public static function destroyFreeplayVocals():Void
    {
        var playerVocals:FlxSound = vocals;
        vocals = null;
        if (playerVocals != null)
        {
            playerVocals.onComplete = null;
            playerVocals.stop();
            playerVocals.persist = false;
            FlxDestroyUtil.destroy(playerVocals);
        }

        var opponent:FlxSound = opponentVocals;
        opponentVocals = null;
        if (opponent != null)
        {
            opponent.onComplete = null;
            opponent.stop();
            opponent.persist = false;
            FlxDestroyUtil.destroy(opponent);
        }
    }

    private function releasePreviewAudio():Void
    {
        // 音乐回调闭包会捕获整个 FreeplayState，必须先断开再销毁音频。
        if (FlxG.sound.music != null)
            FlxG.sound.music.onComplete = null;
        if (musicPlayer != null && musicPlayer.playingMusic)
            musicPlayer.stopMusic();
        destroyFreeplayVocals();
        instPlaying = -1;
    }

    function changeDiff(change:Int = 0)
    {
        if (musicPlayer.playingMusic || curSelected < 0 || curSelected >= songs.length)
            return;
        
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
        
        #if !switch
        var highscoreMode:String = ClientPrefs.getGameplaySetting('opponentplay');
        intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty, songs[curSelected].folder, highscoreMode);
        intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty, songs[curSelected].folder, highscoreMode);
        #end

        lastDifficultyName = Difficulty.getString(curDifficulty, false);
        var displayDiff:String = Difficulty.getString(curDifficulty);
        if (Difficulty.list.length > 1)
            diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
        else
            diffText.text = displayDiff.toUpperCase();

        positionHighscore();
        missingText.visible = false;
        missingTextBG.visible = false;

        updateCardDifficultyInfo();
        updateSongInfoTexts();
        // 专辑是按难度取的（原版每个变体一个 album），换难度要重挑一次封面
        showCharacterForIndex(curSelected, false);

        if (difficultyCarousel != null)
        {
            // 只有用户主动切（change != 0）才响 —— create / changeSelection 里的
            // 无参 changeDiff() 不该出声
            difficultyCarousel.setSelected(curDifficulty, change != 0);
            difficultyCarousel.refreshRatings(carouselRatingProvider);
        }
    }

    function openSearchSubstate()
    {
        if (musicPlayer.playingMusic) return;
        persistentUpdate = false;
        openSubState(new SearchSubState(songs, function(song:NewSongMetaData) {
            // ★ 打开搜索界面的那一帧，MouseMove 已经把本次鼠标按下记成了“待拖拽”，
            //   而搜索期间本 state 不更新，这个状态会一直残留到点击搜索结果之后。
            //   若不清掉，恢复更新的第一帧会被判成“开始拖拽”并 cancelMoveTo()，
            //   把下面设置的 tweenData 跳转取消掉（表现为只选中卡片、列表不滚动）。
            if (cardScroller != null) cardScroller.resetInputState();

            for (i in 0...songs.length) {
                if (songs[i] == song) {
                    curSelected = i;
                    changeSelection(0, true);
                    break;
                }
            }
            persistentUpdate = true;
        }));
    }

    function changeSelection(change:Int = 0, playSound:Bool = true)
    {
        if (songs.length == 0) return;
        
        var previousFolder:String = Mods.currentModDirectory;

        difficultyRatingText.color = DiffRating.getColorFromRating(0);
        
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
        var targetScroll:Float = curSelected * CARD_SPACING;
        var maxScroll = Math.max(0, (songs.length - 1) * CARD_SPACING);
        targetScroll = Math.max(0, Math.min(targetScroll, maxScroll));
        if (cardScroller != null && !inModFolderSelector)
            cardScroller.tweenData = targetScroll;

        Mods.currentModDirectory = songs[curSelected].folder;
        Paths.currentChartDirectory = songs[curSelected].customChart == null ? null : songs[curSelected].customChart.directory;
        if (musicPlayer.playingMusic)
            return;
        _updateSongLastDifficulty();
        
        if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

        var newColor:Int = songs[curSelected].color;
        if(newColor != intendedColor)
        {
            intendedColor = newColor;
            FlxTween.cancelTweensOf(menuBg);
            FlxTween.color(menuBg, 0.5, menuBg.color, intendedColor);
        }

        updateCornerGlow();

        if (songs[curSelected].folder != previousFolder)
        {
            var newMenuBgGraphic:Dynamic = getMenuDesatGraphicForFolder(songs[curSelected].folder);
            if (newMenuBgGraphic != null && newMenuBgGraphic != menuBg.graphic)
            {
                changeBackgroundWithFade(newMenuBgGraphic);
            }
        }
        
        if (!isPureChartMode())
        {
            PlayState.storyWeek = songs[curSelected].week;
            var weekData = WeekData.weeksLoaded.get(WeekData.weeksList[PlayState.storyWeek]);
            if (weekData != null)
            {
                WeekData.setDirectoryFromWeek(weekData);

                if (weekData.difficulties != null && weekData.difficulties.length > 0)
                {
                    var diffStr:String = weekData.difficulties;
                    var customDiffs:Array<String> = diffStr.split(',');
                    for (i in 0...customDiffs.length)
                    {
                        customDiffs[i] = customDiffs[i].trim();
                    }
                    Difficulty.copyFrom(customDiffs);
                }
                else
                {
                    Difficulty.loadFromWeek(weekData);
                }
            }
            else
            {
                Difficulty.loadFromWeek();
            }
        }
        else
            setCustomDifficultyList(songs[curSelected]);
        
        var savedDiff:String = songs[curSelected].lastDifficulty;
        var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
        
        if (savedDiff != null && Difficulty.list.contains(savedDiff))
        {
            curDifficulty = Difficulty.list.indexOf(savedDiff);
        }
        else if (lastDiff > -1 && lastDiff < Difficulty.list.length)
        {
            curDifficulty = lastDiff;
        }
        else
        {
            curDifficulty = 0;
        }
        
        if (curDifficulty == -1 || curDifficulty >= Difficulty.list.length)
            curDifficulty = 0;
        
        changeDiff();
        _updateSongLastDifficulty();

        // 难度列表刚按周/谱面重设过，carousel 得跟着重建；且必须放在 curDifficulty
        // 定稿之后 —— 上面那句 changeDiff() 就是定稿点。
        rebuildDifficultyCarousel();
        
        showArtForIndex(curSelected, true);
        showCharacterForIndex(curSelected, true);

        missingText.visible = false;
        missingTextBG.visible = false;
        
        if (songs[curSelected].customChart != null && songs[curSelected].customChart.isValid())
            modFolderText.text = "Chart Folder:" + Paths.currentChartCategory;
        else
            modFolderText.text = "Mod: " + songs[curSelected].folder;

        for (i in visibleCardMin...visibleCardMax + 1)
        {
            if (i >= 0 && i < cards.length && cards[i] != null)
                cards[i].updateSelection(i == curSelected);
        }
    }

    function changeBackgroundWithFade(newGraphic:Dynamic)
    {
        if (newGraphic == null || newGraphic == menuBg.graphic) return;
        
        if (bgEffectTween != null) bgEffectTween.cancel();
        
        if (menuBg.shader == null)
        {
            bgEffect = new MosaicEffect();
            menuBg.shader = bgEffect.shader;
        }
        
        bgEffectTween = FlxTween.num(MosaicEffect.DEFAULT_STRENGTH, 48, 0.25, {type: ONESHOT, ease: FlxEase.quadIn}, function(v:Float)
        {
            bgEffect.setStrength(v, v);
        });
        
        bgEffectTween.onComplete = function(twn:FlxTween)
        {
            menuBg.loadGraphic(newGraphic);
            menuBg.screenCenter();
            
            bgEffectTween = FlxTween.num(48, MosaicEffect.DEFAULT_STRENGTH, 0.35, {type: ONESHOT, ease: FlxEase.quadOut}, function(v:Float)
            {
                bgEffect.setStrength(v, v);
            });
            
            bgEffectTween.onComplete = function(twn2:FlxTween)
            {
                bgEffectTween = null;
            };
        };
    }

    function showArtForIndex(index:Int, animated:Bool)
    {
        if (index < 0 || index >= songs.length) return;
        songArtDisplay.showArt(songs[index].songName, songs[index].folder, animated);
    }

    function showCharacterForIndex(index:Int, animated:Bool)
    {
        if (index < 0 || index >= songs.length) return;

        // 角色图优先：配了 characterArt 就显示它，否则用专辑封面顶上同一个位置。
        // 这个判断放在宿主而不是组件里 —— 两个组件互不知道对方，编排留给宿主。
        var hasChar:Bool = characterArtDisplay.showCharacter(songs[index].songName, songs[index].folder, animated);
        if (hasChar)
            albumArtDisplay.hide();
        else
            albumArtDisplay.showAlbum(getAlbumIdForCurrentDiff(index), songs[index].folder, animated);
    }

    /**
     * 取当前难度对应的专辑 id。当前难度没写 album 就回退到默认难度那一档。
     * 难度信息是异步解析的，没到之前返回 null（封面先不显示，到了会再调一次）。
     */
    function getAlbumIdForCurrentDiff(index:Int):String
    {
        if (index < 0 || index >= songs.length) return null;

        // difficultyInfo 的 key 是原始难度名，不是译文 —— 所以传 false。
        var info:ParsedSongInfo = songs[index].difficultyInfo.get(Difficulty.getString(curDifficulty, false));
        if (info != null && info.album != null) return info.album;

        var baseInfo:ParsedSongInfo = songs[index].difficultyInfo.get(Difficulty.getDefault());
        return baseInfo == null ? null : baseInfo.album;
    }

    /** 难度列表变了就重建 carousel（块数、名字都跟着变）。 */
    function rebuildDifficultyCarousel():Void
    {
        if (difficultyCarousel == null) return;
        difficultyCarousel.rebuild(Difficulty.list, curDifficulty);
        difficultyCarousel.refreshRatings(carouselRatingProvider);
    }

    /** carousel 每块下面的评级数字。负数 = 这一档还没解析出来。 */
    function carouselRatingProvider(index:Int):Float
    {
        if (curSelected < 0 || curSelected >= songs.length) return -1;

        // 和 updateCardDifficultyInfo 一样按原始难度名查 —— difficultyInfo 的 key 不是译文。
        var info:ParsedSongInfo = songs[curSelected].difficultyInfo.get(Difficulty.getString(index, false));
        if (info == null) return -1;
        return getModeDifficultyRating(info);
    }

    inline private function _updateSongLastDifficulty()
    {
        if (curSelected >= 0 && curSelected < songs.length)
        {
            songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
        }
    }

    private function setCustomDifficultyList(song:NewSongMetaData):Void
    {
        if (song != null && song.customChart != null && song.customChart.difficulties.length > 0)
            Difficulty.copyFrom(song.customChart.difficulties);
        else
            Difficulty.resetList();
    }

    function openModFolderSelector()
    {
        var modFolder = new ModFolderSubstate(this);
        inModFolderSelector = true;
        openSubState(modFolder);
    }

    /**
     * 供 ModFolderSubstate 显示「该模组下有多少首歌」。folder 为空表示全部。
     */
    public function getSongCountForFolder(?folder:String = null):Int
    {
        if (folder == null || folder.length == 0)
            return (allSongs != null) ? allSongs.length : ((songs != null) ? songs.length : 0);

        if (songsByFolder != null && songsByFolder.exists(folder))
        {
            var list:Array<NewSongMetaData> = songsByFolder.get(folder);
            return (list != null) ? list.length : 0;
        }
        return 0;
    }

    public function onModFolderChanged()
    {
        // 队列项持有旧歌曲元数据；筛选变化后必须丢弃，不能让旧任务继续占内存。
        difficultyPreloadQueue = [];
        selectedCustomChartCategory = Paths.currentChartCategory;
        if (Paths.currentChartCategory != null && Paths.currentChartCategory.length > 0)
        {
            songs = [];
            Paths.currentChartDirectory = null;
            #if sys
            loadCustomChartSongs();
            #end
        }
        else if (ClientPrefs.data.freeplayModFolder)
        {
            Paths.currentChartDirectory = null;
            var folder:String = Mods.currentModDirectory;
            if (folder == null || folder.length == 0)
            {
                songs = allSongs.copy();
            }
            else
            {
                if (songsByFolder.exists(folder))
                    songs = songsByFolder.get(folder).copy();
                else
                    songs = [];
            }
        }

        // 只销毁已物化的卡片，歌曲元数据数组不受影响。
        for (i in 0...cards.length)
            releaseCard(i);
        cards = [];
        visibleCardMin = 0;
        visibleCardMax = -1;

        if (songs.length == 0)
        {
            curSelected = 0;
            resetCardScroller();
            return;
        }

        curSelected = 0;
        initializeCardSlots();

        // 重置滚动控制器
        resetCardScroller();

        var modDisplayText:String = "Mod: ";
        if (Paths.currentChartCategory != null && Paths.currentChartCategory.length > 0)
        {
            modDisplayText = "Chart Folder:" + Paths.currentChartCategory;
        }
        else if (ClientPrefs.data.freeplayModFolder)
        {
            modDisplayText += (Mods.currentModDirectory == null || Mods.currentModDirectory.length == 0 ? "ALL" : Mods.currentModDirectory);
        }
        else
        {
            modDisplayText += (Mods.currentModDirectory == null ? "" : Mods.currentModDirectory);
        }
        modFolderText.text = modDisplayText;

        if (curSelected >= 0 && curSelected < songs.length)
        {
            menuBg.color = songs[curSelected].color;
            intendedColor = menuBg.color;
        }

        updateCornerGlow();
        updateCardsPosition();
        setCustomDifficultyList(songs[curSelected]);
        changeDiff();
        updateCardsRating();
        updateSongInfoTexts();
        showArtForIndex(curSelected, false);
        showCharacterForIndex(curSelected, false);
        rebuildDifficultyCarousel();
        if (toolBar != null)
            toolBar.refreshChartModeButtons();
    }

    function resetCardScroller():Void
    {
        if (cardScroller != null)
        {
            remove(cardScroller);
            cardScroller.destroy();
            cardScroller = null;
        }
        
        cardScrollPos = 0;
        lerpSelected = 0;
        
        if (songs.length > 0)
        {
            cardScroller = new backend.MouseMove(this, 'cardScrollPos', [0, Math.max(0, (songs.length - 1) * CARD_SPACING)], [[0, FlxG.width], [0, FlxG.height]], function() { computeVisibleCardRange(); updateCardsPosition(); });
            cardScroller.useLerp = true;
            cardScroller.lerpSmooth = 12;
            cardScroller.dragSensitivity = 1.6;
            cardScroller.deceleration = 0.94;
            cardScroller.mouseWheelSensitivity = -200.0;
            add(cardScroller);
            cardScroller.tweenData = 0;
        }
    }

    override function destroy():Void
    {
        if (freeplayCacheDirty)
            saveFreeplaySongCache();

        releasePreviewAudio();
        difficultyPreloadQueue = [];
        if (cardScroller != null)
        {
            remove(cardScroller);
            cardScroller.destroy();
            cardScroller = null;
        }
        if (bgEffectTween != null)
        {
            bgEffectTween.cancel();
            bgEffectTween = null;
        }
        menuBgGraphicCache.clear();
        cards = [];

        super.destroy();

        // 返回普通菜单时没有下一状态替我们做资源边界清理；进入 PlayState 则交给其加载阶段保护预加载资源。
        if (!stopMusicPlay)
        {
            Paths.clearStoredMemory();
            Paths.clearUnusedMemory();
        }

        FlxG.autoPause = ClientPrefs.data.autoPause;
        if (!FlxG.sound.music.playing && !stopMusicPlay)
            FlxG.sound.playMusic(Paths.music('freakyMenu'));

        // 上面的 super.destroy() 已经销毁了全部成员（这 4 个都是 add() 进来的），
        // 再显式 destroy 一遍是多余的 —— 而且 DifficultyCarousel 是 FlxTypedGroup，
        // 二次 destroy 会撞上 members == null（在这里崩过）。

        AlbumConfig.reset();
    }
}   

class NewSongMetaData
{
    public var songName:String = "";
    public var week:Int = 0;
    public var songCharacter:String = "";
    public var color:Int = -7179779;
    public var folder:String = "";
    public var lastDifficulty:String = null;
    
    public var difficultyInfo:Map<String, ParsedSongInfo> = new Map<String, ParsedSongInfo>();
    public var customChart:CustomChartMetadata = null;

    /** 音乐人 / 作曲（来自 week.json 元组第 4 项） */
    public var songMusican:String = null;
    /** 各难度谱师（来自 week.json 元组第 5 项，按本曲难度顺序） */
    public var songCharters:Array<String> = null;
    
    public function new(song:String, week:Int, songCharacter:String, color:Int)
    {
        this.songName = song;
        this.week = week;
        this.songCharacter = songCharacter;
        this.color = color;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
    }
}

class FreeplayCard extends FlxTypedGroup<FlxSprite>
{
    public var targetY:Float = 0;
    public var songName:String;
    public var songCharacter:String;
    public var coloring:Int;
    public var week:Int;
    public var folder:String;
    
    public var bgSprite:FlxSprite;
    public var textSprite:FlxText;
    public var icon:HealthIcon;
    
    public var rhombusBg:FlxSprite;
    public var ratingSprite:FlxSprite;
    
    public var bpmText:FlxText;
    public var lengthText:FlxText;
    public var keysText:FlxText;
    private var ratingText:FlxText;

    public var isCardSelected:Bool = false;

    public function new(x:Float, y:Float, songName:String, songCharacter:String, coloring:Int, week:Int)
    {
        super();
        
        this.songName = songName;
        this.songCharacter = songCharacter;
        this.coloring = coloring;
        this.week = week;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
        
        bgSprite = new FlxSprite(x, y);
        bgSprite.makeGraphic(450, 75, 0xFF4A4A4A);
        bgSprite.alpha = 0.67;
        bgSprite.scrollFactor.set();
        
        add(bgSprite);
        
        textSprite = new FlxText(x + 60, y + 10, 380, songName, 20);
        textSprite.antialiasing = ClientPrefs.data.antialiasing;
        textSprite.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        textSprite.borderSize = 2;
        textSprite.borderColor = FlxColor.BLACK;
        textSprite.scrollFactor.set();
        add(textSprite);

        bpmText = new FlxText(x + 60, y + 35, 110, 'BPM: --', 14);
        bpmText.antialiasing = ClientPrefs.data.antialiasing;
        bpmText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        bpmText.borderSize = 1;
        bpmText.borderColor = FlxColor.BLACK;
        bpmText.scrollFactor.set();
        add(bpmText);
        
        lengthText = new FlxText(x + 180, y + 35, 130, 'LENGTH: 0:00', 14);
        lengthText.antialiasing = ClientPrefs.data.antialiasing;
        lengthText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        lengthText.borderSize = 1;
        lengthText.borderColor = FlxColor.BLACK;
        lengthText.scrollFactor.set();
        add(lengthText);

        keysText = new FlxText(x + 320, y + 35, 80, 'KEYS: --', 14);
        keysText.antialiasing = ClientPrefs.data.antialiasing;
        keysText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        keysText.borderSize = 1;
        keysText.borderColor = FlxColor.BLACK;
        keysText.scrollFactor.set();
        add(keysText);
        
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = this.folder;
        
        icon = new HealthIcon(songCharacter, false, true, this.folder);
        icon.setPosition(x + 30, y + 5);
        icon.scale.set(0.6, 0.6);
        icon.updateHitbox();
        icon.scrollFactor.set();
        add(icon);
        
        rhombusBg = new FlxSprite(x + 400, y);

        try {
            rhombusBg.loadGraphic(Paths.image('freeplay/rhombus'));
        } catch (e:Dynamic) {
            rhombusBg.makeGraphic(60, 75, 0xFF333333);
        }
        
        rhombusBg.color = coloring;
        rhombusBg.alpha = 0.6;
        rhombusBg.scrollFactor.set();
        add(rhombusBg);
        
        ratingSprite = new FlxSprite(x + 490, y + 20);
        ratingSprite.antialiasing = true;
        ratingSprite.scrollFactor.set();
        add(ratingSprite);
        updateRatingSprite();
    }
    
    public function updateSelection(isSelected:Bool):Void
    {
        isCardSelected = isSelected;
        // 发光已移除，这里只保留状态，不执行额外操作
    }
    
    public function updateDifficultyInfo(bpm:Float, formattedLength:String, ?noteCount:Int = 0, ?difficultyRating:Float = 0.0, ?keyCount:Int = 0)
    {
        if (bpm > 0)
        {
            var bpmValue:String = Math.round(bpm) == bpm ? Std.string(Math.round(bpm)) : Std.string(FlxMath.roundDecimal(bpm, 1));
            bpmText.text = 'BPM: $bpmValue';
        }
        else
            bpmText.text = 'BPM: --';
            
        lengthText.text = 'LENGTH: $formattedLength';

        if (keysText != null)
            keysText.text = (keyCount > 0) ? 'KEYS: $keyCount' : 'KEYS: --';
    }
    
    public function updateRatingSprite(?mode:String = null)
    {
        if (mode == null) mode = ClientPrefs.getGameplaySetting('opponentplay');
        var songLowercase:String = songName.toLowerCase();
        songLowercase = songLowercase.replace(" ", "-");
        
        var bestRating:Float = 0;
        for (diff in 0...Difficulty.list.length)
        {
            var rating:Float = Highscore.getRating(songLowercase, diff, folder, mode);
            if (rating > bestRating)
            {
                bestRating = rating;
            }
        }
        
        var percent:Float = bestRating * 100;
        
        var ratingImage:String = "air";
        
        if (percent >= 99) {
            ratingImage = "P";
        } else if (percent >= 97.5) {
            ratingImage = "GP";
        } else if (percent >= 95) {
            ratingImage = "EP";
        } else if (percent >= 92.5) {
            ratingImage = "E";
        } else if (percent >= 90) {
            ratingImage = "SG";
        } else if (percent >= 80) {
            ratingImage = "G";
        } else if (percent >= 70) {
            ratingImage = "L";
        }
        
        try
        {
            ratingSprite.loadGraphic(Paths.image('freeplay/ratings/$ratingImage'));
            if (ratingText != null) ratingText.visible = false;
            ratingSprite.scale.set(0.7, 0.7);
            ratingSprite.updateHitbox();
            
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 205;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }
        catch (e:Dynamic)
        {
            trace('Failed to load rating image: $ratingImage');
            ratingSprite.makeGraphic(40, 40, FlxColor.TRANSPARENT);
            
            if (ratingText == null)
            {
                ratingText = new FlxText(ratingSprite.x, ratingSprite.y, 40, ratingImage, 20);
                ratingText.antialiasing = ClientPrefs.data.antialiasing;
                ratingText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
                ratingText.borderSize = 2;
                ratingText.borderColor = FlxColor.BLACK;
                add(ratingText);
            }
            else
            {
                ratingText.text = ratingImage;
                ratingText.x = ratingSprite.x;
                ratingText.y = ratingSprite.y;
            }
            ratingText.visible = true;
        }
    }
    
    public function updatePosition(curSelected:Float, selectedIndex:Int, isVisible:Bool = true)
    {
        var distance = targetY - curSelected;
        
        if (Math.abs(distance) > 5) 
        {
            bgSprite.visible = bgSprite.active = false;
            textSprite.visible = textSprite.active = false;
            icon.visible = icon.active = false;
            rhombusBg.visible = rhombusBg.active = false;
            ratingSprite.visible = ratingSprite.active = false;
            bpmText.visible = bpmText.active = false;
            lengthText.visible = lengthText.active = false;
            keysText.visible = keysText.active = false;
            return;
        }
        
        bgSprite.visible = bgSprite.active = true;
        textSprite.visible = textSprite.active = true;
        icon.visible = icon.active = true;
        rhombusBg.visible = rhombusBg.active = true;
        ratingSprite.visible = ratingSprite.active = true;
        bpmText.visible = bpmText.active = true;
        lengthText.visible = lengthText.active = true;
        keysText.visible = keysText.active = true;
        
        var middleY = FlxG.height * 0.5;
        var spacing = 80;
        
        var offsetY = distance * spacing;
        var offsetX = Math.abs(distance) * -60;
        
        var targetX = FlxG.width * 0.175 + offsetX;
        var targetYPos = middleY + offsetY - 30;
        
        bgSprite.x = targetX - 50;
        bgSprite.y = targetYPos;
        
        textSprite.x = targetX + 60;
        textSprite.y = targetYPos + 10;

        bpmText.x = targetX + 60;
        bpmText.y = targetYPos + 35;
        
        lengthText.x = targetX + 180;
        lengthText.y = targetYPos + 35;

        keysText.x = targetX + 320;
        keysText.y = targetYPos + 35;
        
        icon.x = targetX - 80;
        icon.y = targetYPos - 45;
        
        rhombusBg.x = targetX + 400;
        rhombusBg.y = targetYPos;
        
        if (ratingSprite.graphic != null)
        {
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 100;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }

        var isSelected:Bool = (targetY == selectedIndex);
        updateSelection(isSelected);
        
        var alpha = if (isSelected) 1.0 else 0.6;
        if (isSelected) {
            bgSprite.color = 0xFF5A5A5A;
            alpha = 0.8;
        } else {
            bgSprite.color = 0xFF4A4A4A;
        }
        
        rhombusBg.color = coloring;
        
        bgSprite.alpha = alpha;
        textSprite.alpha = alpha;
        icon.alpha = alpha;
        rhombusBg.alpha = alpha;
        ratingSprite.alpha = alpha;
        bpmText.alpha = alpha;
        lengthText.alpha = alpha;
        keysText.alpha = alpha;
    }
    
    public function checkMouseOver():Bool
    {
        return FlxG.mouse.overlaps(bgSprite) || FlxG.mouse.overlaps(rhombusBg) || FlxG.mouse.overlaps(ratingSprite);
    }

    public function setAlpha(alphat:Float)
    {
        bgSprite.alpha = alphat;
        textSprite.alpha = alphat;
        icon.alpha = alphat;
        rhombusBg.alpha = alphat;
        ratingSprite.alpha = alphat;
        bpmText.alpha = alphat;
        lengthText.alpha = alphat;
        keysText.alpha = alphat;
    }
}