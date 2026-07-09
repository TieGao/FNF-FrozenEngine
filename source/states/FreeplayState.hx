package states;

import backend.DifficultyCalculator;
import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.SongArtConfig;
import backend.SongInfoParser;

import objects.HealthIcon;
import objects.MusicPlayerLegacy;
import objects.CharacterArtDisplay;
import objects.SongArtDisplay;
import objects.ToolBar;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import substates.ModFolderSubstate;
import substates.SearchSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.FlxG;

import shaders.MosaicEffect;

import haxe.Json;

import flixel.addons.display.FlxBackdrop;

#if sys
import sys.io.File;
#end

class FreeplayState extends MusicBeatState
{
    public var songs:Array<NewSongMetaData> = [];
    var cards:Array<FreeplayCard> = [];
    var allCards:Array<FreeplayCard> = [];
    
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

    var scoreBG:FlxSprite;
    var scoreText:FlxText;
    var diffText:FlxText;
    var noteCountText:FlxText;
    var difficultyRatingText:FlxText;
    var modFolderText:FlxText;
    var lerpScore:Int = 0;
    var lerpRating:Float = 0;
    var intendedScore:Int = 0;
    var intendedRating:Float = 0;

    var missingTextBG:FlxSprite;
	var missingText:FlxText;
    
    var bottomString:String;
    var bottomText:FlxText;
    var bottomBG:FlxSprite;
    var toolBar:ToolBar;
    
    var topBar:FlxSprite;
    
    var instPlaying:Int = -1;
    public static var vocals:FlxSound = null;
    public static var opponentVocals:FlxSound = null;
    var holdTime:Float = 0;
    var stopMusicPlay:Bool = false;
    
    var mouseOverCard:Int = -1;
    var visibleCardMin:Int = 0;
    var visibleCardMax:Int = -1;
    
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

    override function create()
    {
        persistentUpdate = true;
        PlayState.isStoryMode = false;
        freeplaySongCache = loadFreeplaySongCache();
        WeekData.reloadWeekFiles(false);
        options.KEOptionsMenu.isFreeplay = true;
        options.KEOptionsMenu.onPlayState = false;

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Freeplay Menu", null);
        #end

        if(WeekData.weeksList.length < 1)
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
        
        if (ClientPrefs.data.freeplayModFolder)
        {
            allSongs = songs.copy();
            for (song in allSongs)
            {
                var folder = (song.folder == null || song.folder.length == 0) ? "base" : song.folder;
                if (!songsByFolder.exists(folder))
                    songsByFolder.set(folder, []);
                songsByFolder.get(folder).push(song);
            }
        }
        
        #if sys
        if (ClientPrefs.data.saveFreeplayCache && freeplayCacheDirty)
            saveFreeplaySongCache();
        #end
        
        Mods.loadTopMod();

        SongArtConfig.loadAllConfigs();
        //preloadConfiguredArts();
        cacheMenuBgGraphics();

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

        if (ClientPrefs.data.freeplayspace)
        {
            space.alpha = 1;
            starsBG.alpha = 1;
            starsFG.alpha = 1;
            cornerGlow.alpha = 0.7;
        }
        
        cards = [];
        allCards = [];
        for (i in 0...songs.length)
        {
            var oldModDir = Mods.currentModDirectory;
            Mods.currentModDirectory = songs[i].folder;
            
            var card = new FreeplayCard(0, 0, songs[i].songName, songs[i].songCharacter, songs[i].color, songs[i].week);
            card.targetY = i;
            cards.push(card);
            allCards.push(card);
            add(card);
        }

        cardScrollPos = curSelected * CARD_SPACING;

        cardScroller = new backend.MouseMove(this, 'cardScrollPos', [0, Math.max(0, (songs.length - 1) * CARD_SPACING)], [[0, FlxG.width], [0, FlxG.height]], function() { computeVisibleCardRange(); updateCardsPosition(); });
        cardScroller.useLerp = true;
        cardScroller.lerpSmooth = 12;
        cardScroller.dragSensitivity = 1.6;
        cardScroller.deceleration = 0.94;
        cardScroller.mouseWheelSensitivity = -200.0;
        add(cardScroller);

        scoreText = new FlxText(FlxG.width * 0.7, 85, 0, "", 32);
        scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

        scoreBG = new FlxSprite(scoreText.x - 6, 85).makeGraphic(1, 66, 0xFF000000);
        scoreBG.alpha = 0.8;
        add(scoreBG);
        add(scoreText);

        diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
        diffText.font = scoreText.font;
        add(diffText);

        noteCountText = new FlxText(scoreText.x, scoreText.y + 66, 0, "", 20);
        noteCountText.font = scoreText.font;
        noteCountText.color = 0xFFAAAAAA;
        add(noteCountText);

        difficultyRatingText = new FlxText(scoreText.x, scoreText.y + 90, 0, "", 20);
        difficultyRatingText.font = scoreText.font;
        difficultyRatingText.color = DifficultyCalculator.getRatingColor(0);
        add(difficultyRatingText);

        if (ClientPrefs.data.freeplayspace)
        {
            topBar = new FlxSprite(0, 0 ).loadGraphic(Paths.image('freeplay/topBar'));
            topBar.alpha = 0.8;
            add(topBar);
        }
        else
        {
            topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 85, 0xFF000000);
            topBar.alpha = 0.75;
            add(topBar);
        }


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
        modFolderText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
        add(modFolderText);

        missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
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
            toolBar = new ToolBar(this, FlxG.width, 50);
            add(toolBar);

            bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
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
            bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
            bottomBG.alpha = 0.6;
            add(bottomBG);

            bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
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
        PlayState.storyWeek = songs[curSelected].week;
        Difficulty.loadFromWeek();
        
        changeDiff();
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
        changeSelection(0, false);
        persistentUpdate = true;
        super.closeSubState();
        for (card in cards)
        {
            if (card != null)
                card.updateRatingSprite();
        }
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
        for (diffName in difficulties)
        {
            var info:Dynamic = Reflect.field(entry.data, diffName);
            if (info != null)
                result.set(diffName, cast info);
        }
        return result;
    }

    private function getMissingDifficulties(entry:Dynamic, difficulties:Array<String>):Array<String>
    {
        var missing:Array<String> = [];
        for (diffName in difficulties)
        {
            if (Reflect.field(entry.data, diffName) == null)
                missing.push(diffName);
        }
        return missing;
    }

    private function buildFreeplayCacheEntry(infoMap:Map<String, ParsedSongInfo>):Dynamic
    {
        var entry:Dynamic = {};
        entry.data = {};
        for (diffName in infoMap.keys())
        {
            Reflect.setField(entry.data, diffName, infoMap.get(diffName));
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
                        cache.set(key, Reflect.field(parsed, key));
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

        #if sys 
        var cacheObj:Dynamic = {};
        for (key in freeplaySongCache.keys())
            Reflect.setField(cacheObj, key, freeplaySongCache.get(key));

        File.saveContent('freeplaySongCache.json', Json.stringify(cacheObj));
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
        for (card in cards)
        {
            card.updateRatingSprite();
        }
    }

    inline function computeVisibleCardRange():Void
    {
        if (inModFolderSelector) return;
        if (cards.length == 0)
        {
            visibleCardMin = 0;
            visibleCardMax = -1;
            return;
        }

        for (card in cards)
        {
            var distance = Math.abs(card.targetY - lerpSelected);
            var isVisible = distance <= 5;
            card.updatePosition(lerpSelected, curSelected, isVisible);
        }
        
        visibleCardMin = Std.int(Math.floor(lerpSelected - 5));
        if (visibleCardMin < 0) visibleCardMin = 0;
        visibleCardMax = Std.int(Math.ceil(lerpSelected + 5));
        if (visibleCardMax >= cards.length) visibleCardMax = cards.length - 1;
    }

    function updateCardsPosition()
    {
        if (cards.length == 0) return;
        if (inModFolderSelector) return;

        var oldMin = visibleCardMin;
        var oldMax = visibleCardMax;
        computeVisibleCardRange();

        if (visibleCardMin < 0) visibleCardMin = 0;
        if (visibleCardMax >= cards.length) visibleCardMax = cards.length - 1;
        if (visibleCardMin > visibleCardMax) return;

        if (oldMax < 0)
        {
            for (i in 0...visibleCardMin)
                if (i >= 0 && i < cards.length) cards[i].updatePosition(lerpSelected, curSelected, false);
            for (i in visibleCardMax + 1...cards.length)
                if (i >= 0 && i < cards.length) cards[i].updatePosition(lerpSelected, curSelected, false);
        }
        else
        {
            if (visibleCardMin > oldMin)
            {
                for (i in oldMin...visibleCardMin)
                    if (i >= 0 && i < cards.length) cards[i].updatePosition(lerpSelected, curSelected, false);
            }
            if (visibleCardMax < oldMax)
            {
                for (i in visibleCardMax + 1...oldMax + 1)
                    if (i >= 0 && i < cards.length) cards[i].updatePosition(lerpSelected, curSelected, false);
            }
        }

        for (i in visibleCardMin...visibleCardMax + 1)
            if (i >= 0 && i < cards.length) cards[i].updatePosition(lerpSelected, curSelected, true);
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
        var mode:String = DifficultyCalculator.normalizeMode(ClientPrefs.getGameplaySetting('opponentplay'));
        switch (mode)
        {
            case 'opponent': return diffInfo.difficultyRatingOpponent;
            case 'coop': return diffInfo.difficultyRatingCoop;
            default: return diffInfo.difficultyRatingPlayer;
        }
    }

    function updateCardDifficultyInfo()
    {
        if (songs.length == 0) return;
        var currentDiffName = Difficulty.getString(curDifficulty, false);

        for (i in 0...cards.length)
        {
            var diffInfo:ParsedSongInfo = null;
            if (i >= 0 && i < songs.length)
                diffInfo = songs[i].difficultyInfo.get(currentDiffName);

            if (diffInfo != null)
            {
                cards[i].updateDifficultyInfo(
                    diffInfo.bpm,
                    diffInfo.formattedLength,
                    diffInfo.noteCount,
                    getModeDifficultyRating(diffInfo)
                );
            }
            else
            {
                cards[i].updateDifficultyInfo(0, "0:00", 0, 0.0);
            }
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
                difficultyRatingText.color = DifficultyCalculator.getRatingColor(0);
            }
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
            difficultyRatingText.color = DifficultyCalculator.getRatingColor(rating);
        }
        else
        {
            noteCountText.text = Language.getPhrase('freeplay_notes_missing', 'NOTES: --');
            difficultyRatingText.text = Language.getPhrase('freeplay_rating_missing', 'RATING: --');
            difficultyRatingText.color = DifficultyCalculator.getRatingColor(0);
        }
    }
    
    public function togglePlaySong():Void
    {
        if (curSelected < 0 || curSelected >= songs.length) return;

        if (musicPlayer.playingMusic)
        {
            musicPlayer.stopMusic();
            if (ClientPrefs.data.toolBar && toolBar != null)
            {
                toolBar.setNormalMode();
            }
            return;
        }
        
        var songName:String = songs[curSelected].songName;
        var songLowercase:String = Paths.formatToSongPath(songName);
        var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
        
        try
        {
            destroyFreeplayVocals();

            Mods.currentModDirectory = songs[curSelected].folder;
            
            #if sys
            var chartPath:String = Paths.modsJson(songLowercase + '/' + poop);
            if (!sys.FileSystem.exists(chartPath))
            {
                chartPath = Paths.json(songLowercase + '/' + poop);
                if (!sys.FileSystem.exists(chartPath))
                {
                    throw new haxe.Exception('Chart file not found: $poop');
                }
            }
            #end
            
            PlayState.SONG = Song.loadFromJson(poop, songLowercase);
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDifficulty;
            
            #if DISCORD_ALLOWED
            DiscordClient.changePresence("Freeplay - Listening to " + songName, null);
            #end
            
            if (FlxG.sound.music != null)
                FlxG.sound.music.stop();
            
            FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7, false);
            
            FlxG.sound.music.onComplete = function()
            {
                destroyFreeplayVocals();
                FlxG.sound.music.time = 0;
                if (musicPlayer.playingMusic)
                    musicPlayer.stopMusic();
                if (ClientPrefs.data.toolBar && toolBar != null)
                {
                    toolBar.setNormalMode();
                }
            };
            
            vocals = new FlxSound();
            if (PlayState.SONG.needsVoices)
                vocals.loadEmbedded(Paths.voices(PlayState.SONG.song));
            else
                vocals.loadEmbedded(Paths.voices(PlayState.SONG.song, "empty"));
            
            FlxG.sound.list.add(vocals);
            
            opponentVocals = new FlxSound();
            opponentVocals.loadEmbedded(Paths.voices(PlayState.SONG.song, "empty"));
            FlxG.sound.list.add(opponentVocals);
            
            musicPlayer.playingMusic = true;
            musicPlayer.switchPlayMusic();
            
            if (ClientPrefs.data.toolBar && toolBar != null)
            {
                toolBar.setMusicPlayerMode(songName);
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
            musicPlayer.stopMusic();
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
            musicPlayer.stopMusic();
            destroyFreeplayVocals();
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
            musicPlayer.stopMusic();
            destroyFreeplayVocals();
            FlxG.sound.music.stop();
            
            var newIndex = curSelected + 1;
            if (newIndex >= songs.length) newIndex = 0;
            
            changeSelection(newIndex - curSelected);
            togglePlaySong();
        }
    }

    override function update(elapsed:Float)
    {
        if(WeekData.weeksList.length < 1)
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

        if (desiredIndex == 0) {
            lerpSelected = 0;
        } else if (desiredIndex == (songs.length - 1)) {
            lerpSelected = songs.length - 1;
        } else if (Math.abs(lerpSelected - desiredIndex) < 0.0001) {
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
                var info = SongInfoParser.preloadAllDifficulties(item.songName, item.folder, item.difficulties, item.weekData);
                item.song.difficultyInfo = info;
                if (ClientPrefs.data.saveFreeplayCache)
                {
                    freeplaySongCache.set(item.cacheKey, buildFreeplayCacheEntry(info));
                    freeplayCacheDirty = true;
                }
            }
            catch(e:Dynamic)
            {
                trace('Failed to preload song info: $e');
            }
        }

        if (!musicPlayer.playingMusic)
        {
            if (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0 || FlxG.mouse.justPressed || FlxG.mouse.wheel != 0)
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
            FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
            MusicBeatState.switchState(new LoadReplayState());
        }

        if (ClientPrefs.data.freeplayModFolder && FlxG.mouse.justPressed && FlxG.mouse.overlaps(modFolderText) && !musicPlayer.playingMusic && !inModFolderSelector)
        {
            openModFolderSelector();
        }

        if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(diffText))
        {
            changeDiff(1);
            _updateSongLastDifficulty();
            updateCardDifficultyInfo();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
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

        if (controls.BACK || FlxG.mouse.justPressedRight)
        {
            if (PsychUIInputText.focusOn != null)
                return;
            
            if (musicPlayer.playingMusic)
            {
                musicPlayer.stopMusic();
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
        else if (PsychUIInputText.focusOn == null)
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
            else if (FlxG.keys.justPressed.SPACE && !ClientPrefs.data.legacymp)
            {
                togglePlaySong();
            }
            else if (FlxG.keys.justPressed.SPACE && ClientPrefs.data.legacymp)
            {
                if (curSelected < 0 || curSelected >= songs.length)
                {
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                }
                else
                {
                    if(instPlaying != curSelected && !musicPlayer.playingMusic)
                    {
                        destroyFreeplayVocals();
                        FlxG.sound.music.volume = 0;

                        Mods.currentModDirectory = songs[curSelected].folder;
                        var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
                        Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
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
                                    vocals.loadEmbedded(loadedVocals);
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
                            
                            opponentVocals = new FlxSound();
                            try
                            {
                                var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
                                var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
                                
                                if(loadedVocals != null && loadedVocals.length > 0)
                                {
                                    opponentVocals.loadEmbedded(loadedVocals);
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

                        FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
                        FlxG.sound.music.pause();
                        instPlaying = curSelected;

                        musicPlayer.playingMusic = true;
                        musicPlayer.curTime = 0;
                        musicPlayer.switchPlayMusic();
                        musicPlayer.pauseOrResume(true);
                    }
                    else if (instPlaying == curSelected && musicPlayer.playingMusic)
                    {
                        musicPlayer.pauseOrResume(!musicPlayer.playingMusic);
                    }
                }
            }
        }

        if (PsychUIInputText.focusOn == null && controls.RESET && !musicPlayer.playingMusic)
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

        // ★★★ 性能优化关键点 ★★★
        // 使用索引循环，避免 cards.indexOf(card) 导致 O(n²)
        for (i in 0...cards.length)
        {
            var card = cards[i];
            if (card != null)
            {
                card.updateSelection(i == curSelected);
            }
        }
    }
    
    function updateMouseInteraction()
    {
        if (cards.length == 0) return;
        if (inModFolderSelector) return;
        computeVisibleCardRange();
        var newMouseOverCard:Int = -1;
        for (i in visibleCardMin...visibleCardMax + 1)
        {
            if (cards[i].checkMouseOver())
            {
                cards[i].setAlpha(0.7);
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
                    for (i in visibleCardMin...visibleCardMax + 1) cards[i].setAlpha(0.9);
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
    
    function selectSong()
    {
        if (curSelected < 0 || curSelected >= songs.length) return;

        persistentUpdate = false;
        var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
        var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

        try
        {           
            Mods.currentModDirectory = songs[curSelected].folder;
            
            Song.loadFromJson(poop, songLowercase);
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDifficulty;

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

            return;
        }

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

    public static function destroyFreeplayVocals() {
        if(vocals != null) vocals.stop();
        vocals = FlxDestroyUtil.destroy(vocals);

        if(opponentVocals != null) opponentVocals.stop();
        opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
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
    }

    function openSearchSubstate()
    {
        if (musicPlayer.playingMusic) return;
        persistentUpdate = false;
        openSubState(new SearchSubState(songs, function(song:NewSongMetaData) {
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

        difficultyRatingText.color = DifficultyCalculator.getRatingColor(0);
        
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
        cardScrollPos = curSelected * CARD_SPACING;
        if (cardScroller != null && !inModFolderSelector)
            cardScroller.tweenData = cardScrollPos;
        Mods.currentModDirectory = songs[curSelected].folder;
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
        
        if (musicPlayer.playingMusic)
        {
            musicPlayer.switchPlayMusic();
            destroyFreeplayVocals();
            FlxG.sound.music.stop();
            if (!stopMusicPlay)
                FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
        }

        if (musicPlayer.playingMusic)
        {
            musicPlayer.switchPlayMusic();
            destroyFreeplayVocals();
            FlxG.sound.music.stop();
            if (!stopMusicPlay)
                FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
        }

        showArtForIndex(curSelected, true);
        showCharacterForIndex(curSelected, true);

        missingText.visible = false;
        missingTextBG.visible = false;
        
        modFolderText.text = "Mod: " + songs[curSelected].folder;

        for (i in 0...cards.length)
        {
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
        characterArtDisplay.showCharacter(songs[index].songName, songs[index].folder, animated);
    }

    inline private function _updateSongLastDifficulty()
    {
        if (curSelected >= 0 && curSelected < songs.length)
        {
            songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
        }
    }

    function openModFolderSelector()
    {
        var modFolder = new ModFolderSubstate(this);
        inModFolderSelector = true;
        openSubState(modFolder);
    }

    public function onModFolderChanged()
    {
        if (ClientPrefs.data.freeplayModFolder)
        {
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

        if (songs.length == 0)
        {
            curSelected = 0;
            return;
        }

        curSelected = 0;
        cardScrollPos = 0;
        lerpSelected = 0;

        for (card in cards)
        {
            remove(card);
            card.destroy();
        }
        cards = [];
        allCards = [];

        for (i in 0...songs.length)
        {
            var oldModDir = Mods.currentModDirectory;
            Mods.currentModDirectory = songs[i].folder;
            
            var card = new FreeplayCard(0, 0, songs[i].songName, songs[i].songCharacter, songs[i].color, songs[i].week);
            card.targetY = i;
            cards.push(card);
            allCards.push(card);
            add(card);

            Mods.currentModDirectory = oldModDir;
        }

        var modDisplayText:String = "Mod: ";
        if (ClientPrefs.data.freeplayModFolder)
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
        updateCardsRating();
        updateSongInfoTexts();
        changeDiff();
        showArtForIndex(curSelected, false);
        showCharacterForIndex(curSelected, false);
        inModFolderSelector = false;
    }

    override function destroy():Void
    {
        #if sys
        if (ClientPrefs.data.saveFreeplayCache && freeplayCacheDirty)
            saveFreeplaySongCache();
        #end

        super.destroy();

        FlxG.autoPause = ClientPrefs.data.autoPause;
        if (!FlxG.sound.music.playing && !stopMusicPlay)
            FlxG.sound.playMusic(Paths.music('freakyMenu'));

        if (songArtDisplay != null)
            songArtDisplay.destroy();
            
        if (characterArtDisplay != null)
            characterArtDisplay.destroy();
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
        textSprite.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        textSprite.borderSize = 2;
        textSprite.borderColor = FlxColor.BLACK;
        textSprite.scrollFactor.set();
        add(textSprite);

        bpmText = new FlxText(x + 60, y + 35, 150, 'BPM: --', 14);
        bpmText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        bpmText.borderSize = 1;
        bpmText.borderColor = FlxColor.BLACK;
        bpmText.scrollFactor.set();
        add(bpmText);
        
        lengthText = new FlxText(x + 220, y + 35, 150, 'LENGTH: 0:00', 14);
        lengthText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        lengthText.borderSize = 1;
        lengthText.borderColor = FlxColor.BLACK;
        lengthText.scrollFactor.set();
        add(lengthText);
        
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
    
    public function updateDifficultyInfo(bpm:Float, formattedLength:String, ?noteCount:Int = 0, ?difficultyRating:Float = 0.0)
    {
        if (bpm > 0)
        {
            var bpmValue:String = Math.round(bpm) == bpm ? Std.string(Math.round(bpm)) : Std.string(FlxMath.roundDecimal(bpm, 1));
            bpmText.text = 'BPM: $bpmValue';
        }
        else
            bpmText.text = 'BPM: --';
            
        lengthText.text = 'LENGTH: $formattedLength';
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
            ratingSprite.scale.set(0.7, 0.7);
            ratingSprite.updateHitbox();
            
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 205;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }
        catch (e:Dynamic)
        {
            trace('Failed to load rating image: $ratingImage');
            ratingSprite.makeGraphic(40, 40, FlxColor.TRANSPARENT);
            
            var ratingText = new FlxText(ratingSprite.x, ratingSprite.y, 40, ratingImage, 20);
            ratingText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
            ratingText.borderSize = 2;
            ratingText.borderColor = FlxColor.BLACK;
            add(ratingText);
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
            return;
        }
        
        bgSprite.visible = bgSprite.active = true;
        textSprite.visible = textSprite.active = true;
        icon.visible = icon.active = true;
        rhombusBg.visible = rhombusBg.active = true;
        ratingSprite.visible = ratingSprite.active = true;
        bpmText.visible = bpmText.active = true;
        lengthText.visible = lengthText.active = true;
        
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
        
        lengthText.x = targetX + 220;
        lengthText.y = targetYPos + 35;
        
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
    }
}