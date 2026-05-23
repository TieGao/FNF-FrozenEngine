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
import objects.SearchBar;
import objects.ToolBar;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

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
    
    var searchInput:SearchBar;
    var originalSongs:Array<NewSongMetaData> = [];
    var freeplaySongCache:Map<String, Dynamic> = new Map<String, Dynamic>();
    var freeplayCacheDirty:Bool = false;
    var difficultyPreloadQueue:Array<Dynamic> = [];
    var menuBgGraphicCache:Map<String, Dynamic> = new Map<String, Dynamic>();
    var filterTimer:Float = -1; // -1表示不需要过滤
        
    var updateTimer:Float = 0;
    var updateInterval:Float = 0.0033;

    override function create()
    {
        //Paths.clearStoredMemory();
        //Paths.clearUnusedMemory();
        
        persistentUpdate = true;
        PlayState.isStoryMode = false;
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

        // 尝试从缓存加载 Freeplay 歌曲参数
        freeplaySongCache = loadFreeplaySongCache();

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
        
        // 如果有新歌曲或未缓存的歌曲，保存缓存数据
        #if sys
        if (freeplayCacheDirty)
            saveFreeplaySongCache();
        #end

        // 保存原始歌曲列表用于搜索
        originalSongs = songs.copy();
        
        Mods.loadTopMod();

        SongArtConfig.loadAllConfigs();
        // 预加载所有歌曲艺术图
        preloadConfiguredArts();

        // 预缓存所有模组的 Freeplay 背景图，避免切换时卡顿
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

        // 背景层
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
        
        // 创建卡片
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

        // 初始化 cardScrollPos，使其与当前选择同步（以像素为单位）
        cardScrollPos = curSelected * CARD_SPACING;

        // 创建 MouseMove 用于列表拖拽与滚轮
        cardScroller = new backend.MouseMove(this, 'cardScrollPos', [0, Math.max(0, (songs.length - 1) * CARD_SPACING)], [[0, FlxG.width], [0, FlxG.height]], function() { computeVisibleCardRange(); updateCardsPosition(); });
        cardScroller.useLerp = true;
        cardScroller.lerpSmooth = 12;
        cardScroller.dragSensitivity = 1.6;
        cardScroller.deceleration = 0.94;
        cardScroller.mouseWheelSensitivity = -200.0;
        add(cardScroller);

        // 分数显示
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

        // 添加搜索框到topBar中
        searchInput = new SearchBar(0, 50, Std.int(topBar.width * 0.3));
        searchInput.onChange = function(oldText:String, newText:String) {
            filterTimer = 0.3; // 延迟0.3秒过滤
        };
        searchInput.x = (topBar.width - searchInput.fieldWidth) / 2;
        add(searchInput);

        // 确保进入时焦点不在搜索框上
        PsychUIInputText.focusOn = null;

        modFolderText = new FlxText(10, 50, 0, "Mod: " + Mods.currentModDirectory, 24);
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

        replayButton = new FlxSprite(FlxG.width - 200, 0); // 右上角位置
        replayButton.loadGraphic(Paths.image('replay')); // 从 images 文件夹加载
        replayButton.antialiasing = ClientPrefs.data.antialiasing;
        replayButton.scrollFactor.set(); 
        replayButton.setGraphicSize(200, 100); // 初始缩放
        replayButton.updateHitbox();
        replayButton.alpha = 0.8;  
        add(replayButton);

        // 创建音乐播放器
        musicPlayer = new MusicPlayerLegacy(this);
        add(musicPlayer);

        Mods.currentModDirectory = songs[curSelected].folder;
        PlayState.storyWeek = songs[curSelected].week;
        Difficulty.loadFromWeek();
        
        changeDiff();
        
        // 在初始选择时直接显示艺术图和角色（无出入动画）
        showArtForIndex(curSelected, false);
        showCharacterForIndex(curSelected, false);

        // 更新右下角发光颜色
        updateCornerGlow();
        
        // 初始更新卡片位置
        updateCardsPosition();

        updateCardsRating();
        
        // 初始更新歌曲信息
        updateSongInfoTexts();
        
        // 显示鼠标
        FlxG.mouse.visible = true;
        
        super.create();
    }

    // 预加载所有歌曲艺术图
    function preloadConfiguredArts()
    {
        #if MODS_ALLOWED
        
        // 避免重复预加载：按 mod:art 做唯一键，且按歌曲所在模组获取映射，避免配置跨模组污染
        var loadedArt:Map<String, Bool> = new Map<String, Bool>();
        var loadedChar:Map<String, Bool> = new Map<String, Bool>();

        for (song in songs)
        {
            var artName:String = SongArtConfig.getArtForSong(song.songName, song.folder);
            if (artName != null)
            {
                var key = song.folder + ':' + artName;
                if (loadedArt.get(key) == null)
                {
                    var oldModDir = Mods.currentModDirectory;
                    Mods.currentModDirectory = song.folder;
                    try {
                        Paths.image('songArt/$artName', null, true);
                    } catch (e:Dynamic) {}
                    Mods.currentModDirectory = oldModDir;
                    loadedArt.set(key, true);
                }
            }

            var charArtName:String = SongArtConfig.getCharacterArtForSong(song.songName, song.folder);
            if (charArtName != null)
            {
                var key2 = song.folder + ':' + charArtName;
                if (loadedChar.get(key2) == null)
                {
                    var oldModDir2 = Mods.currentModDirectory;
                    Mods.currentModDirectory = song.folder;
                    try {
                        Paths.image('characterArt/$charArtName', null, true);
                    } catch (e:Dynamic) {}
                    Mods.currentModDirectory = oldModDir2;
                    loadedChar.set(key2, true);
                }
            }
        }

        #end
    }

    override function closeSubState()
    {
        changeSelection(0, false);
        persistentUpdate = true;
        super.closeSubState();
        // Update rating sprite in case gameplay settings changed
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
        
        // 从当前周加载难度
        var weekData = WeekData.weeksLoaded.get(WeekData.weeksList[weekNum]);
        var difficulties:Array<String> = [];
        
        if (weekData != null)
        {
            WeekData.setDirectoryFromWeek(weekData);
            
            // 从周数据加载难度列表
            Difficulty.loadFromWeek(weekData);
            
            // 获取周定义的难度列表
            if (weekData.difficulties != null && weekData.difficulties.length > 0)
            {
                // weekData.difficulties 是一个字符串，如 "Easy,Normal,Hard" 或 "erect,nightmare"
                var diffStr:String = weekData.difficulties;
                difficulties = diffStr.split(',');
                
                // 清理每个难度名称（去除空格）
                for (i in 0...difficulties.length)
                {
                    difficulties[i] = difficulties[i].trim();
                }
                
                // 重要：将周定义的自定义难度设置到 Difficulty.list
                Difficulty.copyFrom(difficulties);
            }
            else
            {
                // 如果没有自定义难度，使用默认列表
                difficulties = Difficulty.defaultList.copy();
            }
        }
        else
        {
            trace('WARNING: Week data not found for week index $weekNum');
            // 使用默认难度
            difficulties = Difficulty.defaultList.copy();
        }

        // 尝试使用缓存条目加速加载
        var cachedEntry:Dynamic = freeplaySongCache.get(cacheKey);
        if (cachedEntry != null && isSongCacheEntryValid(cachedEntry, difficulties))
        {
            song.difficultyInfo = buildSongInfoMapFromCache(cachedEntry, difficulties);
            songs.push(song);
            return;
        }

        // 延迟预加载：将任务加入队列，避免一次性解析所有歌曲导致卡顿
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

        var oldMin = visibleCardMin;
        var oldMax = visibleCardMax;
        computeVisibleCardRange();

        if (oldMax < 0)
        {
            for (i in 0...visibleCardMin)
                cards[i].updatePosition(lerpSelected, curSelected, false);
            for (i in visibleCardMax + 1...cards.length)
                cards[i].updatePosition(lerpSelected, curSelected, false);
        }
        else
        {
            if (visibleCardMin > oldMin)
            {
                for (i in oldMin...visibleCardMin)
                    cards[i].updatePosition(lerpSelected, curSelected, false);
            }
            if (visibleCardMax < oldMax)
            {
                for (i in visibleCardMax + 1...oldMax + 1)
                    cards[i].updatePosition(lerpSelected, curSelected, false);
            }
        }

        for (i in visibleCardMin...visibleCardMax + 1)
            cards[i].updatePosition(lerpSelected, curSelected, true);
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
        if (cornerGlow != null)
        {
            var targetColor = songs[curSelected].color;
            FlxTween.cancelTweensOf(cornerGlow);
            FlxTween.color(cornerGlow, 0.5, cornerGlow.color, targetColor);
        }
    }

    // 获取当前模式对应的难度评分
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

    // 更新卡片显示的难度信息
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
    
    // 更新歌曲信息文本（note数量和难度评级）
    function updateSongInfoTexts()
    {
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
        
        // 切换到播放器模式
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
        // 停止当前播放
        musicPlayer.stopMusic();
        destroyFreeplayVocals();
        FlxG.sound.music.stop();
        
        // 切换到上一首歌
        var newIndex = curSelected - 1;
        if (newIndex < 0) newIndex = songs.length - 1;
        
        // 先改变选择
        changeSelection(newIndex - curSelected);
        
        // 然后播放新歌曲
        togglePlaySong();
    }
}

public function nextSong():Void
{
    if (musicPlayer.playingMusic)
    {
        // 停止当前播放
        musicPlayer.stopMusic();
        destroyFreeplayVocals();
        FlxG.sound.music.stop();
        
        // 切换到下一首歌
        var newIndex = curSelected + 1;
        if (newIndex >= songs.length) newIndex = 0;
        
        // 先改变选择
        changeSelection(newIndex - curSelected);
        
        // 然后播放新歌曲
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

        // lerpSelected 不再自动跟随 curSelected；它跟随 cardScrollPos（以索引为单位）
        var desiredIndex:Float = cardScrollPos / CARD_SPACING;
        lerpSelected = FlxMath.lerp(desiredIndex, lerpSelected, Math.exp(-elapsed * 9.6));
        
        updateTimer += elapsed;
        if (updateTimer >= elapsed)
        {
            updateCardsPosition();
            updateTexts();
            updateTimer = 0;
        }

        // 处理搜索过滤延迟
        if (filterTimer > 0)
        {
            filterTimer -= elapsed;
            if (filterTimer <= 0)
            {
                filterSongs((searchInput != null ? searchInput.text : ""));
                filterTimer = -1;
            }
        }

        // 按帧处理歌曲难度预加载队列，避免一次性导致卡顿（每帧处理最多1项）
        if (difficultyPreloadQueue.length > 0)
        {
            var toProcess:Int = 1;
            while (toProcess > 0 && difficultyPreloadQueue.length > 0)
            {
                var item = difficultyPreloadQueue.shift();
                try
                {
                    var info = SongInfoParser.preloadAllDifficulties(item.songName, item.folder, item.difficulties, item.weekData);
                    item.song.difficultyInfo = info;
                    freeplaySongCache.set(item.cacheKey, buildFreeplayCacheEntry(info));
                    freeplayCacheDirty = true;
                }
                catch(e:Dynamic)
                {
                    trace('Failed to preload song info: $e');
                }
                toProcess--;
            }
        }

        if (!musicPlayer.playingMusic)
        {
            if (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0 || FlxG.mouse.justPressed || FlxG.mouse.wheel != 0)
                updateMouseInteraction();
        }

        // ===== replay 按钮交互 =====
        // 悬停效果
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
        
        // 点击处理
        if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(replayButton))
        {
            FlxG.sound.play(Paths.sound('confirmMenu'), 0.7); // 播放确认音效
            MusicBeatState.switchState(new LoadReplayState()); // 切换回放菜单
        }
        // ==========================

        var shiftMult:Int = 1;
        if(FlxG.keys.pressed.SHIFT && !musicPlayer.playingMusic) shiftMult = 3;

        if (!musicPlayer.playingMusic && PsychUIInputText.focusOn == null)
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
                return; // 当搜索条有焦点时，不处理BACK键退出
            
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
						//trace('please work...');
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
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
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

        if (PsychUIInputText.focusOn == null && controls.RESET && !musicPlayer.playingMusic)
        {
            persistentUpdate = false;
            openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter, -1, songs[curSelected].folder));
            FlxG.sound.play(Paths.sound('scrollMenu'));
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

        computeVisibleCardRange();
        var newMouseOverCard:Int = -1;
        for (i in visibleCardMin...visibleCardMax + 1)
        {
            if (cards[i].checkMouseOver())
            {
                cards[i].setAlpha(0.7); // 鼠标悬停时全亮
                newMouseOverCard = i;
                break;
            }
        }
        
        if (FlxG.mouse.justPressed)
        {
            if (newMouseOverCard != -1)
            {
                // 选中某张卡片（点击）：更新选择并将滚动平滑移动到该卡片
                if (newMouseOverCard != curSelected)
                {
                    curSelected = newMouseOverCard;
                    changeSelection();
                    for (i in visibleCardMin...visibleCardMax + 1) cards[i].setAlpha(0.9); // 鼠标悬停时全亮
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
                }
                else
                {
                    // 再次点击已选中卡片 -> 进入歌曲
                    selectSong();
                }

                // 平滑移动到选中卡片位置（以像素为单位）
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
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
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
        FlxTransitionableState.skipNextTransOut = true; // 跳过退出渐变，直接进入LoadingState
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
        return; // 如果正在播放音乐或选择无效，直接返回
    
    curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
    
    // 关键修改：传入模组文件夹获取分数
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

    // 修复：完整的 changeSelection 函数
  function changeSelection(change:Int = 0, playSound:Bool = true)
{
    if (songs.length == 0) return; // 防止在无歌曲时崩溃
    
    var previousFolder:String = Mods.currentModDirectory;

    difficultyRatingText.color = DifficultyCalculator.getRatingColor(0);
    
    curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
    cardScrollPos = curSelected * CARD_SPACING;
    if (cardScroller != null)
        cardScroller.tweenData = cardScrollPos;
    Mods.currentModDirectory = songs[curSelected].folder;
    if (musicPlayer.playingMusic)
        return;
    _updateSongLastDifficulty(); // 先保存当前歌曲的最后使用难度
    
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
    
    // 设置周目录并加载难度
    PlayState.storyWeek = songs[curSelected].week;
    var weekData = WeekData.weeksLoaded.get(WeekData.weeksList[PlayState.storyWeek]);
    if (weekData != null)
    {
        WeekData.setDirectoryFromWeek(weekData);
        
        // 加载周定义的自定义难度
        if (weekData.difficulties != null && weekData.difficulties.length > 0)
        {
            var diffStr:String = weekData.difficulties;
            var customDiffs:Array<String> = diffStr.split(',');
            for (i in 0...customDiffs.length)
            {
                customDiffs[i] = customDiffs[i].trim();
            }
            Difficulty.copyFrom(customDiffs);
            //trace('Loaded custom difficulties: ' + customDiffs.join(', '));
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
    
    
    // 修复：恢复选中歌曲的最后使用难度
    var savedDiff:String = songs[curSelected].lastDifficulty;
    var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
    
    if (savedDiff != null && Difficulty.list.contains(savedDiff))
    {
        // 如果歌曲保存了最后使用的难度，且该难度在当前周存在，就使用它
        curDifficulty = Difficulty.list.indexOf(savedDiff);
    }
    else if (lastDiff > -1 && lastDiff < Difficulty.list.length)
    {
        // 否则使用全局最后使用的难度
        curDifficulty = lastDiff;
    }
    else
    {
        // 最后保底使用第一个难度
        curDifficulty = 0;
    }
    
    // 确保难度索引有效
    if (curDifficulty == -1 || curDifficulty >= Difficulty.list.length)
        curDifficulty = 0;
    
    changeDiff();
    _updateSongLastDifficulty(); // 更新当前歌曲的最后使用难度
    
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

    // 使用独立的显示模块显示艺术图和角色
    showArtForIndex(curSelected, true);
    showCharacterForIndex(curSelected, true);

    missingText.visible = false;
	missingTextBG.visible = false;
	
	// 更新模组文件夹显示
	modFolderText.text = "Mod: " + songs[curSelected].folder;
}

function changeBackgroundWithFade(newGraphic:Dynamic)
{
    if (newGraphic == null || newGraphic == menuBg.graphic) return;
    
    if (bgEffectTween != null) bgEffectTween.cancel();
    
    // 确保 shader 已经应用
    if (menuBg.shader == null)
    {
        //trace("ERROR: bgEffect shader is not applied to menuBg!");
        bgEffect = new MosaicEffect();
        menuBg.shader = bgEffect.shader;
    }
    
    //trace("Starting mosaic transition - strength from " + MosaicEffect.DEFAULT_STRENGTH + " to 48");
    
    // 第一阶段：增加马赛克强度
    bgEffectTween = FlxTween.num(MosaicEffect.DEFAULT_STRENGTH, 48, 0.25, {type: ONESHOT, ease: FlxEase.quadIn}, function(v:Float)
    {
        bgEffect.setStrength(v, v);
        //trace("Mosaic strength: " + v); // 查看强度变化
    });
    
    bgEffectTween.onComplete = function(twn:FlxTween)
    {
       // trace("Switching background at max strength");
        menuBg.loadGraphic(newGraphic);
        menuBg.screenCenter();
        
        bgEffectTween = FlxTween.num(48, MosaicEffect.DEFAULT_STRENGTH, 0.35, {type: ONESHOT, ease: FlxEase.quadOut}, function(v:Float)
        {
            bgEffect.setStrength(v, v);
           // trace("Mosaic strength: " + v);
        });
        
        bgEffectTween.onComplete = function(twn2:FlxTween)
        {
            //trace("Transition complete");
            bgEffectTween = null;
        };
    };
}

    // 显示艺术图
    function showArtForIndex(index:Int, animated:Bool)
    {
        if (index < 0 || index >= songs.length) return;
        songArtDisplay.showArt(songs[index].songName, songs[index].folder, animated);
    }

    // 显示角色
    function showCharacterForIndex(index:Int, animated:Bool)
    {
        if (index < 0 || index >= songs.length) return;
        characterArtDisplay.showCharacter(songs[index].songName, songs[index].folder, animated);
    }

    // 修复：更新歌曲的最后使用难度
    inline private function _updateSongLastDifficulty()
    {
        if (curSelected >= 0 && curSelected < songs.length)
        {
            songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
        }
    }

    override function destroy():Void
    {
        super.destroy();

        FlxG.autoPause = ClientPrefs.data.autoPause;
        if (!FlxG.sound.music.playing && !stopMusicPlay)
            FlxG.sound.playMusic(Paths.music('freakyMenu'));

        if (songArtDisplay != null)
            songArtDisplay.destroy();
            
        if (characterArtDisplay != null)
            characterArtDisplay.destroy();
    }
    
    // 搜索歌曲功能
    // 在 filterSongs 函数中，修改为：

function filterSongs(searchText:String):Void
{
    var originalQuery:String = searchText == null ? "" : searchText;
    if (searchText == null) searchText = "";
    searchText = searchText.toLowerCase();
    searchText = StringTools.trim(searchText);
    searchText = StringTools.replace(searchText, " ", "");
    
    if (searchText == null || searchText.length == 0)
    {
        // 恢复所有歌曲
        songs = originalSongs.copy();
        // 隐藏缺失提示
        missingText.visible = false;
        missingTextBG.visible = false;
    }
    else
    {
        // 过滤歌曲
        songs = [];
        for (song in originalSongs)
        {
            var songName = song.songName.toLowerCase();
            songName = StringTools.replace(songName, " ", "");
            if (songName.indexOf(searchText) != -1)
            {
                songs.push(song);
            }
        }
        
        // 如果搜索无结果，显示提示信息
        if (songs.length == 0)
        {
            missingText.text = 'No songs found for:\n"' + originalQuery + '"';
            missingText.screenCenter(Y);
            missingText.visible = true;
            missingTextBG.visible = true;
        }
        else
        {
            missingText.visible = false;
            missingTextBG.visible = false;
        }
    }
    
    // 复用卡片对象，避免每次搜索都销毁重建
    var cardMap:Map<String, FreeplayCard> = new Map<String, FreeplayCard>();
    for (card in allCards)
        cardMap.set(card.folder + '|' + card.songName, card);

    cards = [];
    for (card in allCards)
    {
        card.visible = false;
        card.active = false;
    }

    for (i in 0...songs.length)
    {
        var key:String = songs[i].folder + '|' + songs[i].songName;
        var card:FreeplayCard = cardMap.get(key);
        if (card != null)
        {
            card.targetY = i;
            card.visible = true;
            card.active = true;
            cards.push(card);
        }
    }
    
    // 重置选择 - 处理无歌曲的情况
    if (songs.length == 0) {
        curSelected = -1;
        lerpSelected = -1;
        
        // 隐藏或重置艺术图显示
        if (songArtDisplay != null) songArtDisplay.visible = false;
        if (characterArtDisplay != null) characterArtDisplay.visible = false;
        
        // 清空分数显示
        scoreText.text = "";
        diffText.text = "";
        noteCountText.text = "";
        difficultyRatingText.text = "";
        
        // 隐藏右下角发光
        if (cornerGlow != null) cornerGlow.alpha = 0;
        
        return; // 直接返回，避免后续操作
    }
    
    // 有歌曲时的正常处理
    if (songArtDisplay != null) songArtDisplay.visible = true;
    if (characterArtDisplay != null) characterArtDisplay.visible = true;
    if (cornerGlow != null) cornerGlow.alpha = 0.7;
    
    curSelected = 0;
    lerpSelected = 0;
    cardScrollPos = 0;
    if (cardScroller != null)
    {
        cardScroller.moveLimit = [0, Math.max(0, (songs.length - 1) * CARD_SPACING)];
        cardScroller.tweenData = 0;
    }
    menuBg.color = songs[curSelected].color;
    intendedColor = menuBg.color;
    
    changeDiff();
    showArtForIndex(curSelected, false);
    showCharacterForIndex(curSelected, false);
    updateCornerGlow();
    updateCardsPosition();
    updateCardsRating();
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
        
        var isSelected:Bool = targetY == selectedIndex;
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