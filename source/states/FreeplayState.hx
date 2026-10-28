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
import backend.StageData;
import backend.SongCredits;
import backend.SongCredits.SongCreditsContext;

import objects.HealthIcon;
import objects.MessageBox;

// Freeplay 专用组件全在 states.freeplay 下，一条通配导入省得逐个维护
import states.freeplay.*;

import backend.AlbumConfig;
import options.psychoptions.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import flixel.FlxBasic;

import shaders.MosaicEffect;

import haxe.Json;

import flixel.addons.display.FlxBackdrop;

import openfl.filters.BlurFilter;
import openfl.display.BlendMode;
import backend.FlxFilteredSprite;
import openfl.filters.BitmapFilterQuality;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

class FreeplayState extends MusicBeatState
{
    public var songs:Array<NewSongMetaData> = [];
    // 只保留当前可视范围的卡片对象；歌曲全集仍由 songs 元数据保存。
    var cards:Array<FreeplayCard> = [];
    
    // 用于模组文件夹管理
    var allSongs:Array<NewSongMetaData> = []; // 所有歌曲
    var songsByFolder:Map<String, Array<NewSongMetaData>> = new Map(); // 按模组分类的歌曲

    /** 原版「基础周」（assets 侧）的筛选键 —— 这些歌的 contentRoot 为 null。 */
    public static inline var SOURCE_VANILLA_BASE:String = '__vanilla_base__';
    /** ModFolder 一级来源筛选：'all' | 'vanilla' | 'mods'。CustomCharts 走 content 模式，不在这里。 */
    public static var sourceFilter:String = 'all';
    /** 二级细分：vanilla → 内容包资源根（SOURCE_VANILLA_BASE = 仅基础周）；mods → 模组目录名；null = 该来源全部。 */
    public static var sourceSubFilter:String = null;

    // ===================== 评级应用动画（官方 rankAnim 移植） =====================
    /** PlayState.endSong 升档时写入，FreeplayState.create 消费后清空 */
    public static var pendingRankAnim:{ song:String, folder:String, mode:String, newRank:FreeplayRank, oldRank:FreeplayRank } = null;

    /** 仅当徽章升档（newRank > oldRank 且非 NONE）时挂起动画；其余情况清掉残留 */
    public static function checkPendingRankAnim(song:String, oldBestPct:Float, newPct:Float, folder:String, mode:String):Void
    {
        var oldRank:FreeplayRank = FreeplayRank.fromAccuracy(oldBestPct);
        var newRank:FreeplayRank = FreeplayRank.fromAccuracy(newPct);
        if (newRank > oldRank && newRank != FreeplayRank.NONE)
            pendingRankAnim = { song: song, folder: folder == null ? '' : folder, mode: mode, newRank: newRank, oldRank: oldRank };
        else
            pendingRankAnim = null;
    }

    public static var curSelected:Int = 0;
    var lerpSelected:Float = 0;
    // 用于鼠标滚动/拖拽的滚动位置（以索引像素为单位，spacing 为每项高度）
    public var cardScrollPos:Float = 0;
    var cardScroller:backend.MouseMove;
    inline static var CARD_SPACING:Int = 80;
    // 右下角署名文字（曲师/谱师/游玩次数）的文本框宽度与右边距
    inline static var SONG_META_FIELD_WIDTH:Float = 750;
    inline static var SONG_META_RIGHT_MARGIN:Float = 20;
	public var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();
    
    var space:FlxSprite;
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
    // Personal Best 行的 FC 档位（SFC/GFC/FC/SDCB/Clear），随 changeDiff 与子状态关闭刷新
    var intendedFC:String = "";

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

    // ---- 评级应用动画运行时状态 ----
    var rankAnimActive:Bool = false;
    var rankAnimCard:FreeplayCard = null;
    /**
     * 评级动画专用前景层。黑幕 / 爆线 / 目标卡 / 火花 全在这里，组内 add 顺序 = 画序。
     * 别改回"对 state 的 members 做 remove + add"那套 —— FlxGroup.add() 会优先填
     * remove 挖出来的 null 槽，卡片会被塞回原位（黑幕之下），整段动画就全被压暗了。
     */
    var rankFx:FlxTypedGroup<FlxBasic>;
    var rankOverlay:FlxSprite;
    var rankSparks:FlxSprite;
    var rankSparksAdd:FlxSprite;
    var rankVignette:FlxSprite;
    /** 动画锁卡前记录的成员原位置，slam 回原位用 */
    var rankAnimOrigPos:Array<{ spr:FlxSprite, x:Float, y:Float }> = [];
    
    var mouseOverCard:Int = -1;
    // 卡片点击：按下只记录候选卡与按下位置，松手时位移小于阈值才算点击（拖拽不误触）。
    // 松手处理放在 update 主体而不是 updateMouseInteraction —— 按下后不动鼠标直接松开时
    // 不会再进那个函数（它有鼠标位移/按下/滚轮的触发门槛），点击会被吞掉。
    var cardPressedIndex:Int = -1;
    var cardPressY:Float = 0;
    inline static var CARD_CLICK_SLOP:Float = 12;
    var visibleCardMin:Int = 0;
    var visibleCardMax:Int = -1;
    // 卡片绘制的锚点：懒加载的卡片插入到它之前，保证始终画在背景/信息栏的底层。
    var cardLayer:FlxSprite;
    
    public var musicPlayer:MusicPlayerLegacy;

    var replayButton:FlxSprite;
    // Replay 按钮的悬停基准尺寸。origin 不动（故意留左上角）：setGraphicSize 已把 offset
    // 补偿到居中，改 origin 会把 offset 的补偿拆掉、按钮整体位移。
    static inline var REPLAY_BTN_SCALE:Float = 0.5;
    // 按下时回落到哪一档。用 Boolean 记录"这一下是从按钮上按下去的"，
    // 松手时才据此决定要不要触发，避免"别处按下、拖到按钮上松手"也算点击。
    var replayPressed:Bool = false;
    var modTextPressed:Bool = false;
    
    var freeplaySongCache:Map<String, Dynamic> = new Map<String, Dynamic>();
    var freeplayCacheDirty:Bool = false;
    var difficultyPreloadQueue:Array<Dynamic> = [];
    var menuBgGraphicCache:Map<String, Dynamic> = new Map<String, Dynamic>();

    // ===================== 转换进度提示 =====================
    /** 本轮待处理难度总数（内容包解析 / 谱面转换都算，按难度计） */
    var convertTotal:Int = 0;
    /** 已处理完的难度数 */
    var convertDone:Int = 0;
    /** 常驻提示（objects.MessageBox.showProgress），底部那根条就是进度 */
    var convertToast:MessageBox = null;
        
    var updateTimer:Float = 0;
    var updateInterval:Float = 0.033; // 约 30fps 刷新卡片位置（视觉上足够平滑）

    public var inModFolderSelector:Bool = false; // 当前是否在模组文件夹选择器中

    /**
     * 来源 / 文件夹切换后需要整体重建一次卡片。
     * onModFolderChanged 是在选择器还开着的时候调的，那时 inModFolderSelector 还是 true，
     * updateCardsPosition 会直接返回 —— 卡片既没建也没刷新，会停在旧一首的内容上。
     * 这里记一个待办，等选择器关掉后的第一帧统一重建。
     */
    var cardsNeedRefresh:Bool = false;

    var searchHitbox:FlxSprite;
    var searchLabel:FlxText;

    /**
     * 是否处于 Content（自定义谱面）浏览模式。
     * Paths.currentChartCategory 是唯一的模式标志：非空 = Content，空 = 默认 Mods 体系。
     * 这里只读不回填 —— 回填会让已经切回 Mods 的界面被上一轮残留重新拉进 Content。
     */
    public function isContentMode():Bool
    {
        return Paths.currentChartCategory != null && Paths.currentChartCategory.length > 0;
    }

    /** 当前浏览的分类是不是「自定义谱面」（而非 VanillaSongs 这类内容包）。 */
    public function isCustomChartMode():Bool
    {
        return Paths.isCustomChartCategory();
    }

    /**
     * 进入 Content 模式的唯一入口：浏览指定分类（空 = 设置里的默认分类）。
     * 模式标志、谱面上下文、资源 mod 目录一次写全，避免出现半套状态。
     */
    public function enterContentMode(?category:String):Void
    {
        var target:String = category;
        if (target == null || target.length == 0) target = ClientPrefs.data.customChartFolder;
        if (target == null || target.length == 0) target = 'custom';

        Paths.setChartContext(target, null);
        Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
        onModFolderChanged();
    }

    /**
     * 退出 Content 模式、回到默认 Mods 体系的唯一入口；folder 为空 = 显示全部模组。
     * 必须把谱面上下文显式清空，否则下次进入 Freeplay 还会被当成 Content。
     */
    public function exitContentMode(?folder:String):Void
    {
        Paths.setChartContext(null, null);
        Mods.currentModDirectory = (folder == null || folder.length == 0) ? null : folder;
        onModFolderChanged();
    }

    /**
     * 按来源筛选歌曲 —— ModFolder 一级 / 二级菜单的落点。
     * filter：'all'（原版 + 模组）/ 'vanilla'（仅原版，含 assets 基础周与 content/VanillaSongs 内容包）/ 'mods'（仅模组）。
     * sub：vanilla 传内容包资源根（SOURCE_VANILLA_BASE = 仅基础周）、mods 传模组目录名，null = 该来源全部。
     * CustomCharts 不走这里，仍由 enterContentMode 处理。
     */
    public function applySourceFilter(filter:String, sub:String = null):Void
    {
        sourceFilter = (filter == null || filter.length == 0) ? 'all' : filter;
        sourceSubFilter = (sub != null && sub.length > 0) ? sub : null;
        Paths.setChartContext(null, null);
        Mods.currentModDirectory = null;
        onModFolderChanged();
    }

    /** 当前来源筛选是否命中这首歌。原版与模组靠 folder 区分：空 folder = 原版。 */
    function matchesSourceFilter(song:NewSongMetaData):Bool
    {
        if (song == null) return false;

        if (sourceFilter == 'vanilla')
        {
            if (song.folder != null && song.folder.length > 0) return false;
            if (sourceSubFilter == null) return true;
            if (sourceSubFilter == SOURCE_VANILLA_BASE) return song.contentRoot == null;
            return song.contentRoot == sourceSubFilter;
        }
        if (sourceFilter == 'mods')
        {
            if (song.folder == null || song.folder.length == 0) return false;
            if (sourceSubFilter == null) return true;
            return song.folder == sourceSubFilter;
        }
        return true;
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

        // 失败时 loadSongs 内部已经切到 ErrorState
        if (!loadSongs()) return;

        Mods.loadTopMod();
        if (isContentMode())
            Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;

        SongArtConfig.loadAllConfigs();
        SongMetaConfig.loadAllConfigs();
        // 艺术图与背景按当前歌曲懒加载，避免歌曲/模组数量把 Freeplay 入口峰值推高。

        if (curSelected >= songs.length || curSelected < 0)
            curSelected = 0;

        buildBackground();
        buildArtDisplays();
        buildCardLayer();
        buildInfoPanel();
        buildSearchBar();
        buildStatusOverlay();
        buildBottomBar();
        initializeSelection();

        FlxG.mouse.visible = true;

        startRankAnimIfPending();

        super.create();
    }

    /**
     * 收集周定义并展开成歌曲列表（含 ModFolder 分组与来源筛选）。
     * 返回 false 表示没有可显示的歌曲，create 直接结束。
     */
    private function loadSongs():Bool
    {
        if (WeekData.weeksList.length < 1 && !isContentMode())
        {
            FlxTransitionableState.skipNextTransIn = true;
            persistentUpdate = false;
            MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
            function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
            function() MusicBeatState.switchState(new states.MainMenuState())));
            return false;
        }

        for (i in 0...WeekData.weeksList.length)
        {
            if (weekIsLocked(WeekData.weeksList[i])) continue;

            var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

            WeekData.setDirectoryFromWeek(leWeek);
            for (song in leWeek.songs)
            {
                var colors:Array<Int> = song[2];
                if (colors == null || colors.length < 3)
                    colors = [146, 113, 253];
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

        if (isContentMode())
        {
            songs = [];
            Paths.currentChartDirectory = null;
            #if sys
            loadCustomChartSongs();
            #end
        }
        else if (sourceFilter != 'all')
        {
            var filtered:Array<NewSongMetaData> = [];
            for (song in allSongs)
                if (matchesSourceFilter(song)) filtered.push(song);
            songs = filtered;
        }

        if (songs.length == 0)
        {
            FlxTransitionableState.skipNextTransIn = true;
            persistentUpdate = false;
            MusicBeatState.switchState(new states.ErrorState("NO CUSTOM CHARTS FOUND.",
                function() MusicBeatState.switchState(new states.MainMenuState()),
                function() MusicBeatState.switchState(new states.MainMenuState())));
            return false;
        }

        return true;
    }

    /** 背景：menuDesat 底图 + 马赛克 shader + freeplayspace 的星空与角光。 */
    private function buildBackground():Void
    {
        var menuBgGraphic:Dynamic = getMenuDesatGraphicForFolder(songs[curSelected].folder);
        menuBg = new FlxSprite().loadGraphic(menuBgGraphic);
        menuBg.antialiasing = ClientPrefs.data.antialiasing;
        menuBg.alpha = 1;
        add(menuBg);
        menuBg.screenCenter();

        bgEffect = new MosaicEffect();
        menuBg.shader = bgEffect.shader;

        if (!ClientPrefs.data.freeplayspace) return;

        space = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        space.antialiasing = ClientPrefs.data.antialiasing;
        space.updateHitbox();
        space.scrollFactor.set();
        space.alpha = 1;
        add(space);

        starsBG = new FlxBackdrop(Paths.image('starBG'));
        starsBG.setPosition(111.3, 67.95);
        starsBG.antialiasing = true;
        starsBG.updateHitbox();
        starsBG.scrollFactor.set();
        starsBG.alpha = 1;
        add(starsBG);

        starsFG = new FlxBackdrop(Paths.image('starFG'));
        starsFG.setPosition(54.3, 59.45);
        starsFG.updateHitbox();
        starsFG.antialiasing = true;
        starsFG.scrollFactor.set();
        starsFG.alpha = 1;
        add(starsFG);

        cornerGlow = new FlxSprite().loadGraphic(Paths.image('freeplay/backGlow'));
        cornerGlow.antialiasing = true;
        cornerGlow.updateHitbox();
        cornerGlow.scrollFactor.set();
        cornerGlow.color = FlxColor.RED;
        cornerGlow.alpha = 0.7;
        cornerGlow.x = FlxG.width - cornerGlow.width + 100;
        cornerGlow.y = FlxG.height - cornerGlow.height + 120;
        add(cornerGlow);
    }

    /** 歌曲图 / 角色图 / 专辑封面三个右侧展示层。 */
    private function buildArtDisplays():Void
    {
        characterArtDisplay = new CharacterArtDisplay();
        add(characterArtDisplay);

        songArtDisplay = new SongArtDisplay();
        add(songArtDisplay);

        // 专辑封面：没配 characterArt 的歌由它顶上右侧同一个位置（判断在 showCharacterForIndex）
        albumArtDisplay = new AlbumArtDisplay();
        add(albumArtDisplay);
    }

    /**
     * 卡片层级锚点 + 滚动控制器。
     * 卡片是懒加载的：ensureCard 会把新卡插到 cardLayer 之前，保证画在背景之上、UI 之下。
     */
    private function buildCardLayer():Void
    {
        initializeCardSlots();

        cardLayer = new FlxSprite();
        cardLayer.visible = false;
        cardLayer.active = false;
        add(cardLayer);

        cardScrollPos = curSelected * CARD_SPACING;
        cardScroller = createCardScroller();
        add(cardScroller);
    }

    /** 右上角成绩区 + 右下角曲目信息 + 顶栏 + 难度 carousel。 */
    private function buildInfoPanel():Void
    {
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
    }

    /** 顶部搜索入口（图标 / 提示文字 / 下划线 / 高亮线）。 */
    private function buildSearchBar():Void
    {
        if (!ClientPrefs.data.freeplaySearch) return;

        // 隐藏背景（增大点击区域）
        searchHitbox = new FlxSprite(0, 0);
        searchHitbox.makeGraphic(240, 50, FlxColor.TRANSPARENT);
        searchHitbox.x = (FlxG.width - searchHitbox.width) / 2;
        searchHitbox.y = 6;
        searchHitbox.scrollFactor.set();
        add(searchHitbox);

        // 搜索图标（放大镜）
        var searchIcon:FlxSprite = new FlxSprite(0, 0);
        searchIcon.loadGraphic(Paths.image('freeplay/search_icon'));
        if (searchIcon.graphic == null)
        {
            // 没有图标资源时用文本替代
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

        searchLabel = new FlxText(0, 0, 0, "Search songs...", 18);
        searchLabel.antialiasing = ClientPrefs.data.antialiasing;
        searchLabel.setFormat(Paths.font("vcr.ttf"), 18, 0xFFAAAAAA, LEFT);
        searchLabel.x = (FlxG.width - 240) / 2 + 38;
        searchLabel.y = 13;
        searchLabel.scrollFactor.set();
        add(searchLabel);

        var lineBg:FlxSprite = new FlxSprite(0, 0);
        lineBg.makeGraphic(200, 1, FlxColor.WHITE);
        lineBg.alpha = 0.25;
        lineBg.x = (FlxG.width - lineBg.width) / 2;
        lineBg.y = 42;
        lineBg.scrollFactor.set();
        add(lineBg);

        var highlightLine:FlxSprite = new FlxSprite(0, 0);
        highlightLine.makeGraphic(200, 2, FlxColor.WHITE);
        highlightLine.alpha = 0;
        highlightLine.x = (FlxG.width - highlightLine.width) / 2;
        highlightLine.y = 42;
        highlightLine.scrollFactor.set();
        add(highlightLine);
    }

    /** 左上角来源标签 + 谱面加载失败提示层。 */
    private function buildStatusOverlay():Void
    {
        var selectedSong:NewSongMetaData = (curSelected >= 0 && curSelected < songs.length) ? songs[curSelected] : null;
        modFolderText = new FlxText(10, 50, 0, getModFolderDisplayText(selectedSong), 24);
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
    }

    /** 底部提示条 + ToolBar + Replay 按钮 + 试听播放器。 */
    private function buildBottomBar():Void
    {
        bottomString = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
        var size:Int = 16;

        if (ClientPrefs.data.toolBar)
        {
            toolBar = new ToolBar(this, FlxG.width + 200, 50);
            add(toolBar);

            bottomBG = new FlxFilteredSprite(0, FlxG.height - 26);
            bottomBG.makeGraphic(FlxG.width, 26, 0xFF000000);
            bottomBG.alpha = 0;
            add(bottomBG);

            bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, bottomString, size);
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

            bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, bottomString, size);
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
    }

    /** 首屏选中项：颜色 / 难度列表 / 成绩 / 艺术图 / 卡片摆位一次定好。 */
    private function initializeSelection():Void
    {
        menuBg.color = songs[curSelected].color;
        intendedColor = menuBg.color;
        lerpSelected = curSelected;

        curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

        // 内容根 + 变体 / 难度表要在第一批 Highscore / Difficulty 查询之前写好，
        // 否则 PicoMix 的档位键会拼成 base 的（-easy 而不是 -pico-easy）。
        applySelectionContext(songs[curSelected]);

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
    }


    override function closeSubState()
    {
        persistentUpdate = true;
        // 子状态期间本 state 暂停更新，鼠标的按下/松开事件都没被处理，
        // 恢复更新前先丢掉过期的输入状态，否则第一帧会被误判成拖拽而取消跳转
        if (cardScroller != null)
            cardScroller.resetInputState();
        cardPressedIndex = -1; // 卡片点击候选同理，防止子状态残留的按下被当成松手点击
        super.closeSubState();

        // 选择器关掉了才允许重建卡片（切换期间 inModFolderSelector 会挡住全部摆位逻辑）
        if (cardsNeedRefresh && !inModFolderSelector)
            refreshCardsAfterSourceChange();

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
        refreshIntendedFC(); // 重置成绩后 FC 也可能被清掉，重读一次（要在 updateTexts 之前）
        updateTexts();
        rebuildDifficultyCarousel();

        updateCardsRating();
        // 选中卡可能落在可视范围之外（子状态里滚动过），单独补一次
        if (curSelected >= 0 && curSelected < cards.length && cards[curSelected] != null)
            cards[curSelected].updateRatingSprite();
    }

    public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
    {
        var song = new NewSongMetaData(songName, weekNum, songCharacter, color);
        
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
                song.contentRoot = weekData.contentRoot;
                song.variant = weekData.variant;
                song.variantLabel = weekData.variantLabel;
                #if sys
                applyMetadataCredits(song, weekData);
                #end
            }
        }
        else
        {
            trace('WARNING: Week data not found for week index $weekNum');
            difficulties = Difficulty.defaultList.copy();
        }

        applyVariantLabel(song);
        // 变体必须在算缓存键之前定下来：同名歌（Bopeebo）分布在 base / Erect / PicoMix，
        // 变体包改成标准档位后光靠 "folder|歌名" 会互相覆盖。
        var cacheKey:String = getFreeplaySongCacheKey(songName, song.folder, song.variant);

        var cachedEntry:Dynamic = freeplaySongCache.get(cacheKey);
        if (cachedEntry != null)
        {
            song.difficultyInfo = buildSongInfoMapFromCache(cachedEntry, difficulties);
            var missingDiffs:Array<String> = getMissingDifficulties(cachedEntry, difficulties, songName, song.folder, weekData);
            if (missingDiffs.length == 0)
            {
                songs.push(song);
                return;
            }
            var pendingDiffs:Array<String> = filterPendingDifficulties(songName, song.folder, weekData, missingDiffs);
            if (pendingDiffs.length > 0)
                enqueuePreload({ song: song, songName: songName, folder: song.folder, difficulties: pendingDiffs, weekData: weekData, cacheKey: cacheKey },
                    pendingDiffs.length);
            songs.push(song);
            return;
        }

        var pendingDiffs:Array<String> = filterPendingDifficulties(songName, song.folder, weekData, difficulties);
        if (pendingDiffs.length > 0)
            enqueuePreload({ song: song, songName: songName, folder: song.folder, difficulties: pendingDiffs, weekData: weekData, cacheKey: cacheKey },
                pendingDiffs.length);
        songs.push(song);
    }

    /**
     * 入队一个预加载任务，并把它的「进度权重」累进总量。
     * units 按难度算：转化一首 3 难度的歌，进度条走 3 格。
     */
    private function enqueuePreload(item:Dynamic, units:Int):Void
    {
        item.units = units;
        convertTotal += units;
        difficultyPreloadQueue.push(item);
    }

    /**
     * 剔除已确认没有谱面文件的难度。
     * isParsedSongInfoValid 会把解析失败（bpm 0）判为无效以便自愈，代价是坏谱面每轮都会
     * 被重新入队；这里靠 SongInfoParser 的缺失记录把它挡掉，只让真正缺文件的难度试一次。
     */
    private function filterPendingDifficulties(songName:String, folder:String, weekData:WeekData, difficulties:Array<String>):Array<String>
    {
        var pending:Array<String> = [];
        for (diffName in difficulties)
        {
            if (!SongInfoParser.isChartMissing(songName, folder, diffName, weekData))
                pending.push(diffName);
        }
        return pending;
    }

    #if sys
    private function loadCustomChartSongs():Void
    {
        var category:String = Paths.currentChartCategory;
        if (category == null || category.length == 0) category = ClientPrefs.data.customChartFolder;
        if (category == null || category.length == 0) category = 'custom';
        for (customSong in CustomChartData.load(category))
        {
            var displayName:String = (customSong.displayName != null && customSong.displayName.length > 0) ? customSong.displayName : customSong.name;
            // 数据包 meta.json 自带配色时用它，否则沿用默认紫色
            var chartColor:Int = (customSong.color != null) ? customSong.color : FlxColor.fromRGB(146, 113, 253);
            var chart:NewSongMetaData = new NewSongMetaData(displayName, -1, 'bf', chartColor);
            chart.folder = '';
            chart.customChart = new CustomChartMetadata(customSong);
            chart.difficultyInfo = cast chart.customChart.difficultyInfo;
            songs.push(chart);

            var missingInfo:Array<String> = [];
            for (difficulty in chart.customChart.difficulties)
            {
                // 已确认转换失败的难度不再入队，否则每轮都会重试同一批坏谱面
                if (!isParsedSongInfoValid(chart.difficultyInfo.get(difficulty))
                    && !CustomChartData.isChartFailed(chart.customChart.song, difficulty))
                    missingInfo.push(difficulty);
            }
            if (missingInfo.length > 0)
            {
                // 进度按难度计：一首 3 档的歌走 3 格，条动得更细
                enqueuePreload({customChart: chart.customChart}, missingInfo.length);
            }
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
            // Paths.currentChartCategory 保持"浏览分类"不动（可能是 'custom' 聚合），
            // 只写当前这首的目录与变体标志 —— 换回 Freeplay 时才能回到原来那一级列表。
            var difficultyName:String = Difficulty.getString(curDifficulty, false);
            var lowerDifficulty:String = difficultyName == null ? '' : difficultyName.toLowerCase();
            var hasVSlice:Bool = chart.customChart.category != null && chart.customChart.category.toLowerCase() == 'v_slice';
            var audioSuffix:String = hasVSlice && (lowerDifficulty == 'erect' || lowerDifficulty == 'pico') ? lowerDifficulty : null;
            Paths.setChartContext(Paths.currentChartCategory, chart.customChart.directory, hasVSlice, audioSuffix,
                chart.customChart.contentRoot, chart.customChart.artist, chart.customChart.charter);
            Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
            PlayState.chartCategory = Paths.currentChartCategory;
            PlayState.chartDirectory = Paths.currentChartDirectory;
            PlayState.chartHasVSliceMetadata = Paths.currentChartHasVSliceMetadata;
            PlayState.chartAudioSuffix = Paths.currentChartAudioSuffix;
            PlayState.chartContentRoot = Paths.currentContentRoot;
            PlayState.chartMetadataArtist = Paths.currentChartMetaArtist;
            PlayState.chartMetadataCharter = Paths.currentChartMetaCharter;
            var loaded:SwagSong = cast CustomChartData.loadChart(chart.customChart.song, difficultyName);

            if (loaded == null) return false;
            PlayState.SONG = loaded;
            // SONG.song 用"基础歌名"（内容包 = 数据目录名），不能用卡片显示名：
            // events / 音轨 / 舞台查找都按基础歌名拼路径。
            PlayState.SONG.song = chart.customChart.song.name;
            Song.loadedSongName = chart.customChart.song.name;
            // 与 Song.loadFromJson 对齐：先定下舞台的 directory，LoadingState.loadNextDirectory()
            // 才会把 currentLevel 设成它（内容包的舞台图在 <包>/week<N>/images/ 下）。
            StageData.loadDirectory(PlayState.SONG);
            return true;
        }
        catch (e:Dynamic)
        {
            trace('Failed to load custom chart: $e');
            return false;
        }
    }
    #if sys
    /**
     * 内容包 / base 歌的署名从包内 metadata 读（week 元组通常没有第 4/5 项）。
     * 内容包取 <contentRoot>/shared/data/<歌>；base 取 assets/shared/data/<歌>；mod 歌暂不走这里。
     */
    function applyMetadataCredits(song:NewSongMetaData, weekData:WeekData):Void
    {
        if (song == null) return;

        var songLower:String = Paths.formatToSongPath(song.songName);
        var dir:String = null;
        if (song.contentRoot != null && song.contentRoot.length > 0)
            dir = '${song.contentRoot}/shared/data/$songLower';
        else if (weekData == null || weekData.folder == null || weekData.folder.length == 0)
            dir = Paths.getSharedPath('data/$songLower');

        if (dir == null) return;
        var credits = CustomChartData.readMetadataCredits(dir);
        if (credits == null) return;
        song.metaArtist = credits.artist;
        song.metaCharter = credits.charter;
    }
    #end

    /**
     * 变体标签（week.json 的 variantLabel，如 'Pico Mix'）只改展示名。
     * songName 保持原样 —— 谱面 / 音轨 / 存档 / 回放全是按它拼的。
     */
    private function applyVariantLabel(song:NewSongMetaData):Void
    {
        if (song == null) return;
        var label:String = song.variantLabel;
        song.displayName = (label != null && label.length > 0)
            ? '${song.songName} ($label)'
            : song.songName;
    }

    private function getFreeplaySongCacheKey(songName:String, folder:String, ?variant:String):String
    {
        // 变体包的歌名与原曲重名（Bopeebo 同时存在于 base / Erect / PicoMix），
        // 档位名又已经统一成 Easy/Normal/Hard —— 不带变体前缀的话，两条缓存条目
        // 会共用同一个键、同名字段互相覆盖，显示出来的 BPM / 评级会串。
        // 无变体时不加前缀，base / mod 的旧键保持不变，不触发全量重算。
        var prefix:String = (variant != null && variant.length > 0) ? variant + '|' : '';
        return prefix + (folder == null ? '' : folder) + '|' + songName;
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

    /**
     * 缓存里仍然缺的难度。
     * entry.missing 记的是「已确认解析失败 + 当时的谱面时间戳」：谱面没改动就不再重试，
     * 改动过（或后来补上，时间戳从 0 变成非 0）会自动重新入队。
     */
    private function getMissingDifficulties(entry:Dynamic, difficulties:Array<String>, songName:String, folder:String, weekData:WeekData):Array<String>
    {
        var missing:Array<String> = [];
        if (entry == null || entry.data == null)
            return difficulties.copy();

        for (diffName in difficulties)
        {
            if (isParsedSongInfoValid(Reflect.field(entry.data, diffName))) continue;
            if (isMissingRecorded(entry, songName, folder, diffName, weekData)) continue;
            missing.push(diffName);
        }
        return missing;
    }

    /** 缓存里记过这个难度失败、且谱面自那以后没被改动过 → 不再重试。 */
    private function isMissingRecorded(entry:Dynamic, songName:String, folder:String, diffName:String, weekData:WeekData):Bool
    {
        if (entry == null || entry.missing == null) return false;
        if (!Reflect.hasField(entry.missing, diffName)) return false;

        var recorded:Float = Reflect.field(entry.missing, diffName);
        return SongInfoParser.getChartStamp(songName, folder, diffName, weekData) == recorded;
    }

    /** 缓存条目必须具备的字段，与 buildFreeplayCacheEntry 写入的字段一一对应。 */
    static var CACHE_REQUIRED_FIELDS:Array<String> = [
        'bpm', 'length', 'formattedLength', 'noteCount', 'keyCount',
        'playerNoteCount', 'opponentNoteCount', 'difficultyRating',
        'difficultyRatingPlayer', 'difficultyRatingOpponent',
        'difficultyRatingCoop', 'ratingText', 'ratingColor'
    ];

    private function isParsedSongInfoValid(info:Dynamic):Bool
    {
        if (info == null)
            return false;

        var requiredFields:Array<String> = CACHE_REQUIRED_FIELDS;
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

        // 谱面解析失败时 SongInfoParser 会兜一份 getDefaultInfo()（bpm 0 / 时长 0），
        // 它的字段是齐的、能通过上面所有检查 —— 一旦被当成"有效"写进缓存就再也重算不了，
        // 之后就算修好解析逻辑，Freeplay 上也永远显示 BPM/LENGTH/KEYS: --、评级 0。
        // 变体难度（'Pico Easy' 那轮拼不出 -pico-easy 时的表现）就是这么把空值焊死进缓存的，
        // 所以这里把 bpm <= 0 也判为"没解析成功"：每轮重新入队重算，缓存能自愈。
        var cachedBpm:Float = Reflect.field(info, 'bpm');
        if (cachedBpm <= 0)
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
                // 必须与 requiredFields 保持一致：漏写会让缓存条目永远缺这个字段，
                // 卡片 KEYS 变成 --，而且因为校验也漏了它，旧条目一直"有效"、不会重算。
                keyCount: info.keyCount,
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

    // 预热所有模组的 menuDesat：当前没有调用点（背景是按选中歌懒加载的），先留着备用。
    // private function cacheMenuBgGraphics():Void
    // {
    //     var folderSet:Map<String, Bool> = new Map<String, Bool>();
    //     for (song in songs)
    //     {
    //         var folder:String = song.folder == null ? '' : song.folder;
    //         if (folderSet.get(folder) == null)
    //             folderSet.set(folder, true);
    //     }
    //
    //     for (folder in folderSet.keys())
    //         cacheMenuDesatGraphic(folder);
    // }

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

    /**
     * 给一张卡补全当前难度的 BPM / 时长 / 键数 / 评级徽章。
     * 卡片是懒创建的（只有滑到可视范围才 new），而 updateCardDifficultyInfo / updateCardsRating
     * 只刷"已经存在的卡" —— 切来源后卡片在下一帧才建出来，就会一直停在占位的
     * "BPM: -- / LENGTH: 0:00 / KEYS: --" 和没有徽章的状态。所以建卡时自己补一次。
     */
    /**
     * 这首歌的谱面/存档键应该带的变体标识。
     * 优先用歌自带的 variant；只拿到内容根时（Content 模式里的内容包谱面）按包反查 ——
     * 与 Paths.setContentRoot 的解析口径保持一致，徽章才不会和存档键脱节。
     */
    private function getSongVariant(song:NewSongMetaData):String
    {
        if (song == null) return null;
        if (song.variant != null && song.variant.length > 0) return song.variant;
        var root:String = song.contentRoot;
        if ((root == null || root.length == 0) && song.customChart != null) root = song.customChart.contentRoot;
        return (root != null && root.length > 0) ? WeekData.getVariantForContentRoot(root) : null;
    }

    /**
     * 这首歌真实拥有的难度名（按已解析的谱面信息）。
     * 还没解析出任何难度时返回 null —— 卡片会退回全局 Difficulty.list。
     */
    private function getSongDifficultyNames(song:NewSongMetaData):Array<String>
    {
        if (song == null || song.difficultyInfo == null) return null;
        var names:Array<String> = [];
        for (name in song.difficultyInfo.keys())
            if (name != null && name.length > 0) names.push(name);
        return names.length > 0 ? names : null;
    }

    private function applyCardSongInfo(index:Int, card:FreeplayCard):Void
    {
        if (card == null || index < 0 || index >= songs.length) return;

        var song:NewSongMetaData = songs[index];
        // 谱面信息是异步预载的，难度名列表可能在建卡之后才齐 —— 这里跟着顺手更新
        card.variant = getSongVariant(song);
        card.diffNames = getSongDifficultyNames(song);
        var diffInfo:ParsedSongInfo = song.difficultyInfo.get(Difficulty.getString(curDifficulty, false));
        if (diffInfo != null)
            card.updateDifficultyInfo(diffInfo.bpm, diffInfo.formattedLength, diffInfo.noteCount, getModeDifficultyRating(diffInfo), diffInfo.keyCount);
        else
            card.updateDifficultyInfo(0, "0:00", 0, 0.0, 0);

        card.updateRatingSprite();
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
        card = new FreeplayCard(0, 0, songs[index].songName, songs[index].songCharacter, songs[index].color,
            songs[index].displayName, getSongVariant(songs[index]), getSongDifficultyNames(songs[index]));
        card.targetY = index;
        cards[index] = card;
        // 建完立刻补内容（BPM / 时长 / 键数 / 徽章），别让它停在占位状态
        applyCardSongInfo(index, card);
        Mods.currentModDirectory = oldModDir;
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
        // 评级动画期间卡片被搬到了前景层，这里销毁会让动画持着一张死卡
        if (card == rankAnimCard) return;
        if (mouseOverCard == index) mouseOverCard = -1;
        if (cardPressedIndex == index) cardPressedIndex = -1;
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
            if (card != null) card.updatePosition(lerpSelected, curSelected);
        }
    }

    // ===================== 评级应用动画编排 =====================
    // 对照官方 rankAnimStart → rankDisplayNew → rankAnimSlam：
    // 黑幕渐入 + 相机推近 → 徽章从巨幅缩入爆点 + 火花 + rank-in 音效 → 相机脉冲/卡片歪头
    // → 黑幕退出 + per-rank 音效 + 卡片甩回原位 + 震屏 + zoom 弹回 + vignette 闪色。
    //
    // 画序一律交给 rankFx 组内部（从下到上：黑幕 → 爆线 → 目标卡 → 火花），
    // state 这一层只用 insert 把组整体压到最顶层，不再逐个成员挪位置。

    function startRankAnimIfPending():Void
    {
        var pending = pendingRankAnim;
        pendingRankAnim = null; // 消费即清，防止残留到下次进 Freeplay
        if (pending == null || songs.length == 0) return;

        // 按歌名 + 模组目录找目标歌（搜索过滤 / 列表变化时可能找不到，直接放弃）
        // pending.song 是 Song.loadedSongName = formatToSongPath 后的形态，两端必须归一化再比
        var targetIndex:Int = -1;
        for (i in 0...songs.length)
        {
            var f:String = songs[i].folder == null ? '' : songs[i].folder;
            if (Paths.formatToSongPath(songs[i].songName) == pending.song && f == pending.folder)
            {
                targetIndex = i;
                break;
            }
        }
        if (targetIndex < 0) return;

        var card:FreeplayCard = ensureCard(targetIndex);
        if (card == null || !card.hasBadgeAtlas) return;

        rankAnimActive = true;
        rankAnimCard = card;

        // 静默选中目标歌（contentRoot / 难度 / 背景 / 立绘同步照常走 changeSelection）
        changeSelection(targetIndex - curSelected, false);
        cardScrollPos = targetIndex * CARD_SPACING;
        lerpSelected = targetIndex;
        updateCardsPosition();

        // ---- 前景层（画序全靠组内顺序）----
        // 组整体插到 members 尾部 = 最顶层。这里必须用 insert 而不是 add：
        // add 会去填空槽，位置不确定，可能被塞到 UI 下面。
        rankFx = new FlxTypedGroup<FlxBasic>();
        insert(members.length, rankFx);

        // 黑幕（组内最底层）。2 倍屏：slam 阶段相机 zoom 会降到 0.8（视野超出屏幕），单屏尺寸会露边
        rankOverlay = new FlxSprite().makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
        rankOverlay.setPosition(-FlxG.width * 0.5, -FlxG.height * 0.5);
        rankOverlay.scrollFactor.set();
        rankOverlay.alpha = 0;
        rankFx.add(rankOverlay);

        // 爆线（官方 rankVignette：640×360 白色边缘渐变，靠 ADD + rank 色上色）。
        // 提前建好压在卡片下面，slam 时只调 alpha —— 那会儿再算插入位置容易插错层。
        rankVignette = new FlxSprite();
        var vignetteGraphic = Paths.image('freeplay/rankVignette');
        if (vignetteGraphic != null)
        {
            rankVignette.loadGraphic(vignetteGraphic);
            // 素材只有 640×360；这一拍镜头正从 0.8 弹回 1，按 1.4 倍铺，缩到 0.8 那帧也不会露边
            rankVignette.setGraphicSize(FlxG.width * 1.4, FlxG.height * 1.4);
            rankVignette.updateHitbox();
            rankVignette.screenCenter();
            rankVignette.scrollFactor.set();
            rankVignette.blend = BlendMode.ADD;
            rankVignette.alpha = 0;
            rankFx.add(rankVignette);
        }
        else
        {
            // 素材缺失不该连累整个 Freeplay（进不了界面比少一个特效严重得多）
            rankVignette = null;
        }

        // 目标卡搬进前景层（在爆线之后 add → 画在爆线之上）。
        // remove 用 splice，别留 null 槽给后面的 add 复用。
        remove(card, true);
        rankFx.add(card);

        // ---- 锁卡 + 记录原布局 ----
        card.animLock = true;
        rankAnimOrigPos = [];
        for (spr in card.members)
        {
            if (spr == null) continue;
            FlxTween.cancelTweensOf(spr);
            rankAnimOrigPos.push({spr: spr, x: spr.x, y: spr.y});
            // 列表里卡片是 0.6/0.8 的半透明；半透明卡片压在黑幕上看着就像"被压暗了"，动画期间拉满
            spr.alpha = 1;
        }

        if (FlxG.sound.music != null)
            FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.4);

        FlxG.camera.zoom = 1;
        FlxTween.tween(FlxG.camera, {zoom: 1.85}, 0.5, {ease: FlxEase.sineIn});
        FlxTween.tween(rankOverlay, {alpha: 0.9}, 0.5);

        // 目标卡居中（官方是直接 setPosition，靠黑幕渐入 + zoom 推近掩盖瞬移）
        var dx:Float = (FlxG.width * 0.5 - 225) - card.bgSprite.x;
        var dy:Float = (FlxG.height * 0.5 - 37) - card.bgSprite.y;
        card.shiftCard(dx, dy);

        // 徽章先定格旧 rank（官方用 fakeRanking 承担，这里复用同一张）
        if (pending.oldRank != FreeplayRank.NONE)
        {
            card.ratingSprite.visible = true;
            card.ratingSprite.color = 0xFFFFFFFF;
            card.ratingSprite.alpha = 1;
            card.ratingSprite.animation.play(pending.oldRank.animName, true, false, 0);
            card.ratingSprite.animation.finishCallback = null; // 旧徽章定格在最后一帧
            card.ratingSprite.animation.curAnim.finish();
        }
        else
        {
            card.ratingSprite.visible = false;
        }

        // ---- 0.5s：徽章爆点 ----
        new FlxTimer().start(0.5, function(_)
        {
            card.ratingSprite.visible = true;
            card.ratingSprite.color = 0xFFFFFFFF;
            card.ratingSprite.alpha = 1;
            card.ratingSprite.animation.play(pending.newRank.animName, true, false, 0);
            card.ratingSprite.animation.finishCallback = function(name:String)
            {
                // 官方徽章是非循环闪烁，播完停帧即可
            };
            // 放大到 20 倍时故意不 updateHitbox：offset 留在 1 倍的值，视觉中心就钉在
            // 卡片的徽章槽上，于是看起来是"从巨幅缩进槽里"；结尾补一次 updateHitbox 收正。
            card.ratingSprite.scale.set(20, 20);
            FlxTween.tween(card.ratingSprite.scale, {x: FreeplayCard.BADGE_SCALE, y: FreeplayCard.BADGE_SCALE}, 0.1, {ease: FlxEase.quadOut,
                onComplete: function(_) card.ratingSprite.updateHitbox()});

            // 火花（tint 旧 rank 色；旧档为空时用新 rank 色）
            var sparkColor:FlxColor = (pending.oldRank != FreeplayRank.NONE) ? pending.oldRank.freeplayColor : pending.newRank.freeplayColor;
            spawnRankSparks(card.ratingSprite.getMidpoint(), sparkColor);

            FlxG.sound.play(Paths.sound(pending.newRank.rankInSound), 0.7);

            FlxG.camera.zoom = 1.3;
            FlxTween.tween(FlxG.camera, {zoom: 1.5}, 0.3, {ease: FlxEase.backInOut});

            card.setCardAngle(-3);
            for (spr in card.members)
                if (spr != null) FlxTween.tween(spr, {angle: 0}, 0.5, {ease: FlxEase.backOut});
            FlxG.camera.shake(0.005, 0.15);
        });

        // ---- 1.1s：slam 归位 ----
        new FlxTimer().start(1.1, function(_)
        {
            FlxG.sound.play(Paths.sound(pending.newRank.slamSound), 0.7);

            if (rankOverlay != null)
            {
                FlxTween.tween(rankOverlay, {alpha: 0}, 0.3, {ease: FlxEase.expoIn,
                    onComplete: function(_)
                    {
                        // 回调里别再走 clearRankOverlay：那里会 cancelTweensOf，正在收尾的 tween 被就地处决容易踩迭代
                        if (rankFx != null) rankFx.remove(rankOverlay, true);
                        rankOverlay.destroy();
                        rankOverlay = null;
                    }});
            }

            // 卡片甩回原位
            for (rec in rankAnimOrigPos)
            {
                FlxTween.cancelTweensOf(rec.spr);
                FlxTween.tween(rec.spr, {x: rec.x, y: rec.y, angle: 0}, 0.5, {ease: FlxEase.expoOut});
            }

            FlxG.camera.shake(0.004, 0.2);
            FlxG.camera.zoom = 0.8;
            FlxTween.tween(FlxG.camera, {zoom: 1}, 0.8, {ease: FlxEase.elasticOut,
                onComplete: function(_) FlxG.camera.zoom = 1});

            // 大边缘爆线（新 rank 色）：ADD 叠加，边缘亮、中心透明
            if (rankVignette != null)
            {
                rankVignette.color = pending.newRank.freeplayColor;
                rankVignette.alpha = 1;
                FlxTween.tween(rankVignette, {alpha: 0}, 0.6, {ease: FlxEase.expoOut,
                    onComplete: function(_)
                    {
                        if (rankFx != null) rankFx.remove(rankVignette, true);
                        rankVignette.destroy();
                        rankVignette = null;
                    }});
            }
        });

        // ---- 1.9s：收尾（等 zoom elastic 结束再还权给 update） ----
        new FlxTimer().start(1.9, function(_)
        {
            finishRankAnim();
        });
    }

    function spawnRankSparks(mid:FlxPoint, color:FlxColor):Void
    {
        if (rankFx == null) return;

        rankSparks = new FlxSprite();
        rankSparks.frames = Paths.getSparrowAtlas('freeplay/sparks');
        rankSparks.animation.addByPrefix('sparks', 'sparks', 24, false);
        rankSparks.blend = BlendMode.ADD;
        rankSparks.scale.set(0.7, 0.7);
        rankSparks.updateHitbox();
        rankSparks.setPosition(mid.x - rankSparks.width / 2, mid.y - rankSparks.height / 2);
        rankSparks.color = color;
        rankFx.add(rankSparks); // 组内最后 add = 画在卡片之上

        rankSparksAdd = new FlxSprite();
        rankSparksAdd.frames = Paths.getSparrowAtlas('freeplay/sparksadd');
        rankSparksAdd.animation.addByPrefix('sparks add', 'sparks add', 24, false);
        rankSparksAdd.blend = BlendMode.ADD;
        rankSparksAdd.scale.set(0.7, 0.7);
        rankSparksAdd.updateHitbox();
        rankSparksAdd.setPosition(mid.x - rankSparksAdd.width / 2, mid.y - rankSparksAdd.height / 2);
        rankSparksAdd.color = color;
        rankFx.add(rankSparksAdd);

        function hideWhenDone(spr:FlxSprite, anim:String):Void
        {
            spr.animation.play(anim, true, false, 0);
            spr.animation.finishCallback = function(name:String)
            {
                // 这里绝不能 destroy：回调返回后 flixel 还会继续 onFinish.dispatch，
                // 销毁过的动画控制器会在信号分发上炸空引用（flixel #2782 同类坑）
                spr.visible = false;
            };
        }
        hideWhenDone(rankSparks, 'sparks');
        hideWhenDone(rankSparksAdd, 'sparks add');
    }

    /** 从前景层摘掉再销毁（必须 splice：留 null 槽会让后面的 add 又把对象塞回原位置）。 */
    function detachRankFx(spr:FlxSprite):Void
    {
        if (spr == null) return;
        if (rankFx != null) rankFx.remove(spr, true);
        spr.destroy();
    }

    function clearRankSparks():Void
    {
        // 火花只藏不销毁（见 finishCallback 注释），统一在这里清理
        if (rankSparks != null) { detachRankFx(rankSparks); rankSparks = null; }
        if (rankSparksAdd != null) { detachRankFx(rankSparksAdd); rankSparksAdd = null; }
    }

    /** 爆线 / 黑幕平时靠 tween 的 onComplete 收尾；tween 被打断就会留在屏幕上，收尾时补一刀。 */
    function clearRankVignette():Void
    {
        if (rankVignette == null) return;
        FlxTween.cancelTweensOf(rankVignette);
        detachRankFx(rankVignette);
        rankVignette = null;
    }

    function clearRankOverlay():Void
    {
        if (rankOverlay == null) return;
        FlxTween.cancelTweensOf(rankOverlay);
        detachRankFx(rankOverlay);
        rankOverlay = null;
    }

    function finishRankAnim():Void
    {
        var card:FreeplayCard = rankAnimCard;
        rankAnimCard = null;
        rankAnimActive = false;
        clearRankSparks();
        clearRankVignette();
        clearRankOverlay();

        if (card != null)
        {
            card.animLock = false;
            card.setCardAngle(0);
            card.ratingSprite.scale.set(FreeplayCard.BADGE_SCALE, FreeplayCard.BADGE_SCALE);
            card.ratingSprite.updateHitbox();
            // 卡片搬回状态层（背景组之前）；先从前景层摘掉，别让 rankFx.destroy 顺手销毁它
            if (rankFx != null) rankFx.remove(card, true);
            if (cardLayer != null) insert(members.indexOf(cardLayer), card);
            else add(card);
        }

        // 前景层成员已全部摘除；组本身也要从 members 里拿掉（destroy 不会自动脱父）
        if (rankFx != null)
        {
            remove(rankFx, true);
            rankFx.destroy();
            rankFx = null;
        }

        rankAnimOrigPos = [];
        updateCardsPosition();
        updateCardsRating();
    }

    function updateTexts()
    {
        var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
        if(ratingSplit.length < 2) ratingSplit.push('');
        
        while(ratingSplit[1].length < 2) ratingSplit[1] += '0';
            
        var pbText:String = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
        // 功能上线后刷新过纪录的曲目才带 FC（SFC/GFC/FC/SDCB/Clear）；老存档读到空串、显示不变
        if (intendedFC != null && intendedFC.length > 0)
            pbText += ' [${intendedFC}]';
        scoreText.text = pbText;
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

    /** 重读 Personal Best 的 FC 档位（changeDiff / 子状态关闭后调用）。老存档曲目没有 FC，读到空串、显示保持原样。 */
    function refreshIntendedFC():Void
    {
        if (curSelected >= 0 && curSelected < songs.length)
            intendedFC = Highscore.getRatingFC(songs[curSelected].songName, curDifficulty, songs[curSelected].folder, ClientPrefs.getGameplaySetting('opponentplay'));
        else
            intendedFC = "";
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
        // FlxText 固定字段宽 + RIGHT 对齐时，文本右边界 = x + 字段宽。
        // 所以 x 必须由「屏宽 - 字段宽 - 右边距」推出来；若沿用 300 宽时代的
        // x = FlxG.width - 320 再配 750 宽，整行会被推到屏幕右侧外面（看不见）。
        var t:FlxText = new FlxText(FlxG.width - SONG_META_FIELD_WIDTH - SONG_META_RIGHT_MARGIN, y, SONG_META_FIELD_WIDTH, "", 18);
        t.setFormat(Paths.font("vcr.ttf"), 18, 0xFFAAAAAA, RIGHT, OUTLINE, FlxColor.BLACK);
        t.borderSize = 1;
        t.antialiasing = ClientPrefs.data.antialiasing;
        t.scrollFactor.set();
        return t;
    }

    /**
     * 右下角补充信息：音乐人 / 谱师 / 游玩次数。
     * 曲师 / 谱师走 backend.SongCredits 的统一优先级链（metadata > songMeta.json > 谱面内嵌 > week 元组）。
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

        var ctx:SongCreditsContext = {
            songName: song.songName,
            diffName: Difficulty.getString(curDifficulty, false),
            diffIdx: curDifficulty,
            modFolder: song.folder,
            weekMusican: song.songMusican,
            weekCharters: song.songCharters
        };
        if (song.customChart != null)
        {
            ctx.metadataArtist = song.customChart.artist;
            ctx.metadataCharter = song.customChart.charter;
        }
        else if (song.metaArtist != null || song.metaCharter != null)
        {
            // 内容包 / base 歌：署名来自包内 metadata（addSong 时解析）
            ctx.metadataArtist = song.metaArtist;
            ctx.metadataCharter = song.metaCharter;
        }

        var musican:String = SongCredits.getArtist(ctx);
        musicanText.text = (musican != null && musican.length > 0)
            ? Language.getPhrase('freeplay_musican', 'BY: {1}', [musican]) : "";

        var charter:String = SongCredits.getCharter(ctx);
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

            #if sys
            // 试听前先确认谱面文件存在，否则 Song.loadFromJson 抛出的 assets 错误很难定位
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

            loadCurrentChartIntoPlayState();
            
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
            // 试听期间不再走鼠标命中逻辑，悬停态要在这里清掉，否则会一直亮着
            setHoveredCard(-1);
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
        if(WeekData.weeksList.length < 1 && !isContentMode())
            return;
        if (musicPlayer == null)
            return;

        updateBackgroundScroll();

        if (rankAnimActive)
        {
            // 评级应用动画期间：锁输入 / 锁卡片摆位 / 锁音乐回升。
            // 跳过 super.update 会把所有成员的 update 一起跳掉，帧动画（徽章闪烁 / 火花）
            // 会冻在第一帧 —— 这里手动推进这几个动画成员。
            if (rankAnimCard != null)
            {
                rankAnimCard.updateRankHue(elapsed);
                rankAnimCard.ratingSprite.update(elapsed);
            }
            if (rankSparks != null) rankSparks.update(elapsed);
            if (rankSparksAdd != null) rankSparksAdd.update(elapsed);
            return;
        }

        if (FlxG.sound.music.volume < 0.7 && !musicPlayer.playingMusic)
            FlxG.sound.music.volume += 0.5 * elapsed;

        // 来源 / 文件夹切换后的卡片重建：选择器关掉后第一帧补上，
        // 不让卡片停在旧列表（或占位 BPM/LENGTH）的状态上。
        if (cardsNeedRefresh && !inModFolderSelector)
            refreshCardsAfterSourceChange();

        updateScoreLerp(elapsed);
        updateCardScroll(elapsed);
        updateTextsThrottled(elapsed);
        processPreloadQueue();
        handleMouseInput();
        handleKeyboardInput(elapsed);

        if (ClientPrefs.data.toolBar && toolBar != null)
            toolBar.update(elapsed);

        if (!musicPlayer.playingMusic && toolBar != null)
            toolBar.setNormalMode();

        super.update(elapsed);
    }

    /** freeplayspace 的星空横向滚动。 */
    private function updateBackgroundScroll():Void
    {
        if (!ClientPrefs.data.freeplayspace) return;

        starsBG.x -= 0.05;
        starsFG.x -= 0.15;

        if (starsBG.x < -starsBG.width) starsBG.x = 0;
        if (starsFG.x < -starsFG.width) starsFG.x = 0;
    }

    /** Personal Best 数字向目标值缓动。 */
    private function updateScoreLerp(elapsed:Float):Void
    {
        lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
        lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

        if (Math.abs(lerpScore - intendedScore) <= 10)
            lerpScore = intendedScore;
        if (Math.abs(lerpRating - intendedRating) <= 0.01)
            lerpRating = intendedRating;
    }

    /** 滚动位置 → lerpSelected → 卡片摆位；顺带推进彩P 的色相循环。 */
    private function updateCardScroll(elapsed:Float):Void
    {
        var desiredIndex:Float = cardScrollPos / CARD_SPACING;
        lerpSelected = FlxMath.lerp(desiredIndex, lerpSelected, Math.exp(-elapsed * 9.6));

        if (Math.abs(lerpSelected - desiredIndex) < 0.0001)
            lerpSelected = desiredIndex;

        updateCardsPosition();

        // 彩P 色相循环由 State 每帧驱动（卡片自身无 update）
        for (i in visibleCardMin...visibleCardMax + 1)
            if (i >= 0 && i < cards.length && cards[i] != null)
                cards[i].updateRankHue(elapsed);
    }

    /** 成绩文本按 updateInterval 节流刷新，避免每帧重建字符串。 */
    private function updateTextsThrottled(elapsed:Float):Void
    {
        updateTimer += elapsed;
        if (updateTimer < updateInterval) return;

        updateTexts();
        updateTimer = 0;
    }

    /** 每帧最多处理 1 个预加载任务（防止卡顿）；队列空了再把缓存落盘。 */
    private function processPreloadQueue():Void
    {
        if (difficultyPreloadQueue.length == 0)
        {
            finishConvertToast();
            if (freeplayCacheDirty) saveFreeplaySongCache();
            return;
        }

        // 提示单独占一帧：转换是同步阻塞的，同帧创建的话要等它跑完才画得出来
        if (convertToast == null)
        {
            beginConvertToast();
            return;
        }

        var item:Dynamic = difficultyPreloadQueue.shift();
        runPreloadItem(item);
        convertDone = Std.int(Math.min(convertTotal, convertDone + unitsOf(item)));
        convertToast.setProgress(convertProgress());
    }

    /** 队列项的进度权重（按难度算）。 */
    private inline function unitsOf(item:Dynamic):Int
        return (item.units == null) ? 0 : item.units;

    /** 单个预加载任务的实际工作。 */
    private function runPreloadItem(item:Dynamic):Void
    {
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

                    // 仍然解析不出来的难度连同谱面时间戳一起记下，下次进 Freeplay 不再重试。
                    // 谱面改动后时间戳会变，isMissingRecorded 就会放行重新解析。
                    var itemDiffs:Array<String> = item.difficulties;
                    for (diffName in itemDiffs)
                    {
                        if (isParsedSongInfoValid(item.song.difficultyInfo.get(diffName))) continue;
                        if (entry.missing == null) entry.missing = {};
                        Reflect.setField(entry.missing, diffName,
                            SongInfoParser.getChartStamp(item.songName, item.folder, diffName, item.weekData));
                    }

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

    // ========================= 转换进度提示 =========================

    /** 挂出常驻提示：标题 + 说明，底部那根条就是进度。 */
    private function beginConvertToast():Void
    {
        convertToast = MessageBox.showProgress(
            Language.getPhrase('freeplay_converter_title', 'Song Converter'),
            Language.getPhrase('freeplay_converter_body', 'Please wait while converting songs...'));
        convertToast.setProgress(convertProgress());
    }

    /** 队列清空：条拉满，稍停一下自己缩回去。 */
    private function finishConvertToast():Void
    {
        if (convertToast == null) return;
        convertDone = convertTotal;
        convertToast.setProgress(1);
        convertToast.closeIn(1.2);
        convertToast = null; // 之后交给 MessageBox 自己滑出销毁
    }

    /** 丢弃进度并立刻收起（切换来源 / 离开 Freeplay 时）。 */
    private function resetConvertProgress():Void
    {
        convertTotal = 0;
        convertDone = 0;
        if (convertToast != null)
        {
            convertToast.close();
            convertToast = null;
        }
    }

    private inline function convertProgress():Float
        return convertTotal > 0 ? Math.min(1, convertDone / convertTotal) : 0;

    /** 鼠标：卡片命中 / 卡片点击 / Replay / 搜索 / 来源标签 / 难度方块。 */
    private function handleMouseInput():Void
    {
        if (!musicPlayer.playingMusic)
        {
            if (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0 || FlxG.mouse.justPressed || FlxG.mouse.wheel != 0)
                updateMouseInteraction();
        }

        // 卡片点击松手生效：按下时的卡片还在（位移小于阈值）才算点击，选中或直接开歌；
        // 拖拽列表（位移超出阈值）松手后不触发，避免误触。
        if (FlxG.mouse.justReleased)
        {
            if (!musicPlayer.playingMusic && cardPressedIndex != -1
                && Math.abs(FlxG.mouse.y - cardPressY) < CARD_CLICK_SLOP)
            {
                if (cardPressedIndex != curSelected)
                {
                    curSelected = cardPressedIndex;
                    changeSelection();
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
                }
                else
                {
                    selectSong();
                }

                if (cardScroller != null)
                    cardScroller.tweenData = curSelected * CARD_SPACING;
            }
            cardPressedIndex = -1;
        }

        // replay 按钮交互：悬停放大、按住缩回原大小 + 提亮。
        // 命中区随 scale 变（FlxG.mouse.overlaps 走未缩放的 AABB）——鼠标划过边缘时会
        // 出现"刚放大就脱出命中区"的抖动，用户基本察觉不到，先不动。
        var replayHover:Bool = FlxG.mouse.overlaps(replayButton);
        if (replayHover && FlxG.mouse.justPressed)
            replayPressed = true;

        if (replayPressed)
        {
            replayButton.alpha = 1.0;
            replayButton.scale.set(REPLAY_BTN_SCALE, REPLAY_BTN_SCALE);
        }
        else if (replayHover)
        {
            replayButton.alpha = 1.0;
            replayButton.scale.set(0.55, 0.55);
        }
        else
        {
            replayButton.alpha = 0.8;
            replayButton.scale.set(REPLAY_BTN_SCALE, REPLAY_BTN_SCALE);
        }

        if (searchHitbox != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(searchHitbox) && !musicPlayer.playingMusic)
            openSearchSubstate();

        // 松手生效：按下时指针在按钮上（replayPressed）且松手时仍在上面才算点击
        if (FlxG.mouse.justReleased && replayPressed && FlxG.mouse.overlaps(replayButton)
            && curSelected >= 0 && curSelected < songs.length)
        {
            FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
            persistentUpdate = false;
            openSubState(new LoadReplaySubState(
                this,
                songs[curSelected].songName,
                songs[curSelected].folder,
                Difficulty.getString(curDifficulty),
                songs[curSelected].contentRoot,
                songs[curSelected].variant
            ));
        }

        if (FlxG.mouse.justReleased)
            replayPressed = false;

        // Mod 文本同理：按住时提亮，松手仍在文本上才打开选择器
        var modTextHover:Bool = ClientPrefs.data.freeplayModFolder && FlxG.mouse.overlaps(modFolderText);
        if (modTextHover && FlxG.mouse.justPressed)
            modTextPressed = true;

        modFolderText.alpha = (modTextHover || modTextPressed) ? 1.0 : 0.8;

        if (modTextPressed && FlxG.mouse.justReleased && modTextHover && !musicPlayer.playingMusic && !inModFolderSelector)
            openModFolderSelector();

        // 处理完才清空
        if (FlxG.mouse.justReleased)
            modTextPressed = false;

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
    }

    /** 键盘：切歌 / 切难度 / 返回 / 确认 / 试听 / 重置成绩。 */
    private function handleKeyboardInput(elapsed:Float):Void
    {
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
            }

            // 切难度与歌曲数量无关：筛选到只剩一首时也要能换档
            if (Difficulty.list.length > 1)
            {
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
    }
    
    function updateMouseInteraction()
    {
        if (cards.length == 0) return;
        if (inModFolderSelector) return;

        var newMouseOverCard:Int = -1;
        // 顶部栏与底部提示条区域不参与卡片命中
        if (FlxG.mouse.y < FlxG.height - 50 && FlxG.mouse.y > 85)
        {
            computeVisibleCardRange();
            for (i in visibleCardMin...visibleCardMax + 1)
            {
                var card:FreeplayCard = cards[i];
                if (card != null && card.checkMouseOver())
                {
                    newMouseOverCard = i;
                    break;
                }
            }
        }

        setHoveredCard(newMouseOverCard);

        if (FlxG.mouse.justPressed && newMouseOverCard != -1)
        {
            // 按下只记录候选卡，不立刻选中 / 不立刻开歌 —— 统一在松手时判定
            // （见 update 主体的松手处理），拖拽列表时不会误触选中已按下的卡片。
            cardPressedIndex = newMouseOverCard;
            cardPressY = FlxG.mouse.y;
        }
    }

    /** 切换卡片悬停态。updatePosition 每帧重算 alpha，所以悬停只能靠状态位，不能直接 setAlpha。 */
    function setHoveredCard(index:Int):Void
    {
        if (index == mouseOverCard) return;

        if (mouseOverCard >= 0 && mouseOverCard < cards.length && cards[mouseOverCard] != null)
            cards[mouseOverCard].setHovered(false);
        if (index >= 0 && index < cards.length && cards[index] != null)
            cards[index].setHovered(true);

        mouseOverCard = index;
    }
    
    /**
     * 把当前选中歌的谱面读进 PlayState.SONG。
     * 自定义谱面走转换；普通歌 / 内容包走 Song.loadFromJson（内容包带上资源根与变体）。
     * 失败时抛异常，由调用方决定是显示错误还是回退。
     */
    private function loadCurrentChartIntoPlayState():Void
    {
        var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
        var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

        Mods.currentModDirectory = songs[curSelected].folder;
        Paths.currentChartDirectory = null;

        if (songs[curSelected].customChart != null && songs[curSelected].customChart.isValid())
        {
            if (!loadCustomChart(curSelected))
                throw new haxe.Exception('Unable to convert custom chart');
        }
        else
        {
            // 普通歌 / 内容包歌：清空自定义谱面上下文；内容包把资源根 + 变体带上
            Paths.setChartContext(null, null, false, null, songs[curSelected].contentRoot,
                songs[curSelected].metaArtist, songs[curSelected].metaCharter, songs[curSelected].variant);
            PlayState.clearChartContext();
            Song.loadFromJson(poop, songLowercase);
        }

        PlayState.isStoryMode = false;
        PlayState.storyDifficulty = curDifficulty;
    }

    /**
     * 把当前选中的谱面加载进 PlayState.SONG（进入游戏 / 编辑器的公共部分）。
     * 成功返回 true；失败时写 missingText 并返回 false。
     */
    function loadSongIntoPlayState():Bool
    {
        if (curSelected < 0 || curSelected >= songs.length) return false;

        try
        {
            loadCurrentChartIntoPlayState();

            if (!isContentMode())
                trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
        }
        catch(e:haxe.Exception)
        {
            trace('ERROR! ${e.message}');

            var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
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
     * 离开 Freeplay 前的公共前置：停试听、把谱面读进 PlayState.SONG、
     * 换过模组目录就释放旧图形、准备加载屏。
     * 返回 false 表示谱面加载失败（错误已写进 missingText），界面保持可操作。
     */
    private function prepareSongLoad():Bool
    {
        releasePreviewAudio();

        if (!loadSongIntoPlayState()) return false;

        persistentUpdate = false;

        @:privateAccess
        if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
            Paths.freeGraphicsFromMemory();

        LoadingState.prepareToSong();
        return true;
    }

    /** 进 PlayState / 编辑器之后的收尾：标记离开、销毁试听人声、刷新 Discord。 */
    private function finishSongLoad():Void
    {
        stopMusicPlay = true;
        destroyFreeplayVocals();
        #if (MODS_ALLOWED && DISCORD_ALLOWED)
        DiscordClient.loadModRPC();
        #end
    }

    /**
     * 从 Freeplay 直接进入谱面编辑器（Toolbar 的 EDITOR 按钮）。
     * ChartingState 从 PlayState.SONG 读谱，所以必须先加载成功。
     */
    public function openChartEditor():Void
    {
        if (!prepareSongLoad()) return;

        LoadingState.loadAndSwitchState(new states.editors.ChartingState(), false);
        finishSongLoad();
    }

    function selectSong()
    {
        if (curSelected < 0 || curSelected >= songs.length) return;
        backend.Bread.crumb('FP.selectSong ' + songs[curSelected].songName);

        if (!prepareSongLoad()) return;

        countSongPlay();

        if (ClientPrefs.data.transitionType == "fade") FlxTransitionableState.skipNextTransOut = true;
        LoadingState.loadAndSwitchState(new PlayState());
        #if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
        finishSongLoad();
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
        // 用只读版：切难度会反复读，getScore/getRating 对缺失键会写回存档并 flush
        intendedScore = Highscore.peekScore(songs[curSelected].songName, curDifficulty, songs[curSelected].folder, highscoreMode);
        intendedRating = Highscore.peekRating(songs[curSelected].songName, curDifficulty, songs[curSelected].folder, highscoreMode);
        refreshIntendedFC();
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

        Mods.currentModDirectory = isContentMode() ? ClientPrefs.data.customChartModFolder : songs[curSelected].folder;
        Paths.currentChartDirectory = songs[curSelected].customChart == null ? null : songs[curSelected].customChart.directory;
        modFolderText.text = getModFolderDisplayText(songs[curSelected]);
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
        
        if (!isContentMode())
        {
            // 浏览普通歌 / 内容包歌时同步资源根与变体，卡片与角色图才能取到包内资源，
            // 档位键（Highscore / 谱面文件名）也才带得上变体后缀
            Paths.setContentRoot(songs[curSelected].contentRoot, songs[curSelected].variant);
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
        {
            // Content 模式的内容包谱面也要带回自己的资源根（变体由包反查），
            // 否则切歌时 Highscore / 谱面键会沿用上一首的上下文。
            var contentRoot:String = songs[curSelected].contentRoot;
            if ((contentRoot == null || contentRoot.length == 0) && songs[curSelected].customChart != null)
                contentRoot = songs[curSelected].customChart.contentRoot;
            Paths.setContentRoot(contentRoot, songs[curSelected].variant);
            setCustomDifficultyList(songs[curSelected]);
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
        
        // 出图必须排在 changeDiff() 之前：changeDiff 会用 animated=false 先摆一次图
        // （它要处理按难度换封面的情况），同图已显示时 display 的守卫会直接返回，
        // 后面这里带动画的调用就再也放不出来了 —— 入场动画会被同一个帧里的静态出图吃掉。
        showArtForIndex(curSelected, true);
        showCharacterForIndex(curSelected, true);

        changeDiff();
        _updateSongLastDifficulty();

        // 难度列表刚按周/谱面重设过，carousel 得跟着重建；且必须放在 curDifficulty
        // 定稿之后 —— 上面那句 changeDiff() 就是定稿点。
        rebuildDifficultyCarousel();

        missingText.visible = false;
        missingTextBG.visible = false;
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

    /**
     * 把「当前选中歌」的资源根 / 变体 / 难度表写回全局（Paths / Difficulty / Mods）。
     *
     * 所有 Highscore 键与谱面文件名都靠 Difficulty.getFilePath() 拼，而它取的是全局
     * Paths.currentContentVariant。切来源（onModFolderChanged）不会走 changeSelection，
     * 所以必须在这里补一次，否则：
     *   - PicoMix 的卡拿 null 变体拼键 → 读到 base 同名歌的成绩；
     *   - Erect 这类「难度名内嵌变体」的包被重置成 Easy/Normal/Hard → 徽章与 BPM 全错。
     */
    private function applySelectionContext(song:NewSongMetaData):Void
    {
        if (song == null) return;

        if (isContentMode())
        {
            Mods.currentModDirectory = ClientPrefs.data.customChartModFolder;
            var root:String = song.contentRoot;
            if ((root == null || root.length == 0) && song.customChart != null)
                root = song.customChart.contentRoot;
            Paths.setContentRoot(root, song.variant);
            setCustomDifficultyList(song);
            return;
        }

        Mods.currentModDirectory = song.folder;
        Paths.setContentRoot(song.contentRoot, song.variant);
        PlayState.storyWeek = song.week;

        var weekData:WeekData = null;
        if (song.week >= 0 && song.week < WeekData.weeksList.length)
            weekData = WeekData.weeksLoaded.get(WeekData.weeksList[song.week]);

        if (weekData != null)
        {
            WeekData.setDirectoryFromWeek(weekData);
            if (weekData.difficulties != null && weekData.difficulties.length > 0)
            {
                var customDiffs:Array<String> = weekData.difficulties.split(',');
                for (i in 0...customDiffs.length)
                    customDiffs[i] = customDiffs[i].trim();
                Difficulty.copyFrom(customDiffs);
            }
            else
                Difficulty.loadFromWeek(weekData);
        }
        else
            Difficulty.loadFromWeek();
    }

    function getModFolderDisplayText(?song:NewSongMetaData):String
    {
        if (song != null && song.customChart != null && song.customChart.isValid())
        {
            var category:String = Paths.currentChartCategory;
            if (category == null || category.length == 0 || category == 'custom')
                category = song.customChart.sourceFolder;
            if (category == null || category.length == 0)
                category = 'custom';
            if (category.startsWith('VanillaSongs/'))
                return 'Vanilla: ' + category.substring('VanillaSongs/'.length);
            return 'Chart Folder: ' + category;
        }

        if (sourceFilter == 'vanilla')
        {
            if (sourceSubFilter == null || sourceSubFilter == SOURCE_VANILLA_BASE)
                return 'Vanilla';
            var slash:Int = sourceSubFilter.lastIndexOf('/');
            return 'Vanilla: ' + (slash >= 0 ? sourceSubFilter.substring(slash + 1) : sourceSubFilter);
        }
        if (sourceFilter == 'mods')
        {
            if (sourceSubFilter == null || sourceSubFilter.length == 0)
                return 'Mods';
            return 'Mod: ' + sourceSubFilter;
        }

        var folder:String = song != null ? song.folder : Mods.currentModDirectory;
        if (folder == null || folder.length == 0)
            folder = 'ALL';
        return 'Mod: ' + folder;
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
        // 换分类后进度条的前提（总数）也作废，连同提示一起清掉
        resetConvertProgress();
        if (isContentMode())
        {
            songs = [];
            Paths.currentChartDirectory = null;
            #if sys
            loadCustomChartSongs();
            #end
        }
        else if (sourceFilter != 'all')
        {
            // 来源筛选（ModFolder 一级 / 二级选的）：从 allSongs 里按来源过一遍。
            // allSongs 只含原版与模组的歌 —— CustomCharts 走上面的 content 分支。
            Paths.currentChartDirectory = null;
            songs = [];
            for (song in allSongs)
                if (matchesSourceFilter(song)) songs.push(song);
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
        else
        {
            // 没开模组文件夹筛选时也要回到全部歌曲，否则从 Content 切回来会残留谱面列表
            Paths.currentChartDirectory = null;
            songs = allSongs.copy();
        }

        // 只销毁已物化的卡片，歌曲元数据数组不受影响。
        for (i in 0...cards.length)
            releaseCard(i);
        cards = [];
        mouseOverCard = -1;
        cardPressedIndex = -1;
        visibleCardMin = 0;
        visibleCardMax = -1;

        // 选择器还开着（inModFolderSelector = true）时上面的 updateCardsPosition 是空转，
        // 卡片只能等关掉之后再建 —— 这里挂个待办，保证一定会重建一遍。
        cardsNeedRefresh = true;

        curSelected = 0;
        var selectedSong:NewSongMetaData = songs.length > 0 ? songs[curSelected] : null;
        modFolderText.text = getModFolderDisplayText(selectedSong);

        if (songs.length == 0)
        {
            resetCardScroller();
            return;
        }

        initializeCardSlots();

        // 重置滚动控制器
        resetCardScroller();

        if (curSelected >= 0 && curSelected < songs.length)
        {
            menuBg.color = songs[curSelected].color;
            intendedColor = menuBg.color;
        }

        updateCornerGlow();
        updateCardsPosition();
        // 来源已经换了：先把新选中歌的资源根 / 变体 / 难度表写回全局，再算卡片与难度轮盘。
        // 这一步以前只在 initializeSelection / changeSelection 里做 —— 切文件夹后没人写，
        // 卡片徽章就会用 null（或上一个包）的变体去拼 Highscore 键，读到 base 同名歌的成绩。
        applySelectionContext(songs[curSelected]);
        changeDiff();
        updateCardsRating();
        updateSongInfoTexts();
        showArtForIndex(curSelected, false);
        showCharacterForIndex(curSelected, false);
        rebuildDifficultyCarousel();
        if (toolBar != null)
            toolBar.refreshChartModeButtons();
    }

    /**
     * 来源切换后的完整卡片重建：清空已物化的卡片，按新列表重新摆位并把
     * BPM / 时长 / 键数 / 评级徽章补上。由 update() 在卡片待刷新且选择器已关闭时调用。
     */
    private function refreshCardsAfterSourceChange():Void
    {
        cardsNeedRefresh = false;

        for (i in 0...cards.length)
            releaseCard(i);
        cards = [];
        mouseOverCard = -1;
        cardPressedIndex = -1;
        visibleCardMin = 0;
        visibleCardMax = -1;

        if (songs.length == 0)
        {
            visibleCardMin = 0;
            visibleCardMax = -1;
            return;
        }

        initializeCardSlots();

        if (cardScrollPos > (songs.length - 1) * CARD_SPACING)
            cardScrollPos = Math.max(0, (songs.length - 1) * CARD_SPACING);

        updateCardsPosition();
        updateCardDifficultyInfo();
        updateCardsRating();
    }

    /** 卡片列表的滚动控制器。create 与来源切换后重建走同一份参数。 */
    private function createCardScroller():backend.MouseMove
    {
        var scroller:backend.MouseMove = new backend.MouseMove(this, 'cardScrollPos',
            [0, Math.max(0, (songs.length - 1) * CARD_SPACING)], [[0, FlxG.width], [0, FlxG.height]],
            function() { computeVisibleCardRange(); updateCardsPosition(); });
        scroller.useLerp = true;
        scroller.lerpSmooth = 12;
        scroller.dragSensitivity = 1.6;
        scroller.deceleration = 0.94;
        scroller.mouseWheelSensitivity = -200.0;
        return scroller;
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
            cardScroller = createCardScroller();
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
        // 提示条挂在 FlxG.game 上，不随 state 自动消失，离开界面时主动收掉
        resetConvertProgress();
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

        AlbumConfig.reset();
    }
}   
