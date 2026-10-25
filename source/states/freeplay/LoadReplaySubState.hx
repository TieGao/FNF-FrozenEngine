package states.freeplay;

import backend.Replay as FrameReplay;
import backend.MusicBeatState;
import backend.MouseMove;
import backend.Mods;
import backend.Song;
import backend.Paths;
import backend.CustomChartData;
import backend.StageData;
import backend.WeekData;


import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxSprite;

import states.FreeplayState;
import states.LoadingState;
import states.PlayState;

import openfl.filters.BlurFilter;
import openfl.filters.BitmapFilterQuality;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
#end

/**
 * LoadReplay 子界面 - 显示当前选中歌曲的 replay
 * 只显示相同歌曲名和相同模组文件夹的 replay
 */
class LoadReplaySubState extends MusicBeatSubstate
{
    var replayFiles:Array<ReplayEntry> = [];
    var curSelected:Int = 0;
    var pressedItem:Int = -1;
    var parent:FreeplayState;

    // 当前歌曲信息
    var currentSongName:String;
    var currentModFolder:String;
    var currentDifficultyName:String;
    /** 当前浏览的歌曲所属内容包资源根（content/VanillaSongs/PicoMix）；普通歌为 null。 */
    var currentContentRoot:String;
    /** 当前浏览的歌曲所属变体（Pico…）；无变体为 null。 */
    var currentVariant:String;

    var bgList:FlxFilteredSprite;
    var bgDim:FlxSprite;

    var selectedReplayName:FlxText;
    var selectedReplayInfo:FlxText;
    var selectedReplayAccuracy:FlxText;
    
    var replaysGroup:FlxTypedGroup<ReplayItem>;

    var startX:Float;
    var targetX:Float;

    // 滚动相关
    var scrollPos:Float = 0;
    var maxScrollPos:Float = 0;
    var itemHeight:Int = 80;
    var visibleItemCount:Int = 0;
    var cardScroller:MouseMove;

    static inline var PADDING_TOP:Int = 20;
    static inline var PADDING_BOTTOM:Int = 20;
    static inline var ITEM_SPACING:Int = 6;

    var noReplaysText:FlxText;
    var deleteConfirmText:FlxText;
    var waitingForDeleteConfirm:Bool = false;
    var replayToDelete:String = "";
    var headerText:FlxText;
    var sortText:FlxText;
    var sortMode:Int = 0;   // 0=日期降序, 1=准确率降序

    public function new(parent:FreeplayState, songName:String, modFolder:String, difficultyName:String,
                        ?contentRoot:String = null, ?variant:String = null)
    {
        super();
        this.parent = parent;
        this.currentSongName = songName;
        this.currentModFolder = modFolder;
        this.currentDifficultyName = difficultyName;
        this.currentContentRoot = (contentRoot != null && contentRoot.length > 0) ? contentRoot : null;
        this.currentVariant = (variant != null && variant.length > 0) ? variant : null;
    }

    override function create()
    {
        // 昏暗背景
        bgDim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bgDim.alpha = 0;
        bgDim.scrollFactor.set();
        add(bgDim);

        // 加载回放列表
        loadReplays();

        // 计算可见项目数量
        var panelHeight:Int = FlxG.height;
        visibleItemCount = Math.floor((panelHeight - PADDING_TOP - PADDING_BOTTOM - 60) / (itemHeight + ITEM_SPACING));
        if (visibleItemCount < 1) visibleItemCount = 1;
        
        updateMaxScroll();

        // 创建背景面板
        var panelWidth:Int = 500;
        bgList = new FlxFilteredSprite();
        bgList.makeGraphic(panelWidth, panelHeight, FlxColor.BLACK);
        bgList.filters = [new BlurFilter(30, 30, BitmapFilterQuality.HIGH)];
        bgList.alpha = 0.85;
        bgList.scrollFactor.set();
        add(bgList);

        // 标题头
        var displaySong = currentSongName;
        if (displaySong.length > 25) displaySong = displaySong.substr(0, 22) + "...";
        headerText = new FlxText(bgList.x + 10, bgList.y + 8, panelWidth - 20, 
            'Replays for: $displaySong', 20);
        headerText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.CYAN, CENTER, OUTLINE, FlxColor.BLACK);
        headerText.borderSize = 2;
        headerText.antialiasing = ClientPrefs.data.antialiasing;
        add(headerText);

        // 子标题 - 显示来源和当前难度
        // content 模式下按大类区分：自定义谱面印 Custom Charts，内容包印它的分类路径。
        // 内容包（content/VanillaSongs/PicoMix 这类）不是 content 模式，靠 contentRoot 认出来。
        var sourceLabel:String = getSourceLabel();
        var subText:String = 'Mod: ' + sourceLabel;
        subText += '  |  Current: $currentDifficultyName';
        var subHeader = new FlxText(bgList.x + 10, bgList.y + 32, panelWidth - 20, subText, 14);
        subHeader.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
        subHeader.borderSize = 1;
        subHeader.antialiasing = ClientPrefs.data.antialiasing;
        add(subHeader);

        // 顶部排序指示（点击切换 日期/准确率）
        sortText = new FlxText(bgList.x + 10, bgList.y + 50, panelWidth - 20, '', 14);
        sortText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.LIME, CENTER, OUTLINE, FlxColor.BLACK);
        sortText.borderSize = 1;
        sortText.antialiasing = ClientPrefs.data.antialiasing;
        add(sortText);
        updateSortText();

        // 创建回放项目组
        replaysGroup = new FlxTypedGroup<ReplayItem>();
        add(replaysGroup);

        // 如果没有回放，显示提示
        noReplaysText = new FlxText(bgList.x + 20, FlxG.height / 2 - 30, panelWidth - 40,
            "No Replays Found\n\nPlay and complete this song\nto save a replay", 20);
        noReplaysText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        noReplaysText.borderSize = 2;
        noReplaysText.antialiasing = ClientPrefs.data.antialiasing;
        noReplaysText.visible = replayFiles.length == 0;
        add(noReplaysText);
        
        rebuildItems(); 

        // 删除确认文本
        deleteConfirmText = new FlxText(0, 0, FlxG.width, "", 24);
        deleteConfirmText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        deleteConfirmText.borderSize = 2;
        deleteConfirmText.antialiasing = ClientPrefs.data.antialiasing;
        deleteConfirmText.visible = false;
        deleteConfirmText.screenCenter();
        add(deleteConfirmText);

        // 右侧信息显示区域
        selectedReplayName = new FlxText(FlxG.width * 0.2 + 20, 120, 340, "Select a Replay", 28);
        selectedReplayName.antialiasing = ClientPrefs.data.antialiasing;
        selectedReplayName.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        selectedReplayName.borderSize = 2;
        selectedReplayName.scrollFactor.set();
        add(selectedReplayName);

        selectedReplayInfo = new FlxText(FlxG.width * 0.2 + 20, 220, 340, "", 16);
        selectedReplayInfo.antialiasing = ClientPrefs.data.antialiasing;
        selectedReplayInfo.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
        selectedReplayInfo.borderSize = 1;
        selectedReplayInfo.scrollFactor.set();
        add(selectedReplayInfo);

        selectedReplayAccuracy = new FlxText(FlxG.width * 0.2 + 20, 160, 340, "", 32);
        selectedReplayAccuracy.antialiasing = ClientPrefs.data.antialiasing;
        selectedReplayAccuracy.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.CYAN, CENTER, OUTLINE, FlxColor.BLACK);
        selectedReplayAccuracy.borderSize = 2;
        selectedReplayAccuracy.scrollFactor.set();
        add(selectedReplayAccuracy);

        // 操作提示
        var controlsText:FlxText = new FlxText(FlxG.width * 0.2 + 20, FlxG.height - 70, FlxG.width,
            "↑/↓: Navigate | ENTER: Load | F: Delete | Click Sort header to toggle | ESC/Click Outside: Close", 16);
        controlsText.antialiasing = ClientPrefs.data.antialiasing;
        controlsText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
        controlsText.borderSize = 1;
        controlsText.scrollFactor.set();
        add(controlsText);

        // 起始位置和目标位置
        startX = FlxG.width;
        targetX = FlxG.width - 420;

        // 弹出动画
        bgList.x = startX;
        headerText.x = startX + 10;
        sortText.x = startX + 10;
        selectedReplayName.x = startX + 50;
        selectedReplayInfo.x = startX + 50;
        selectedReplayAccuracy.x = startX + 50;

        for (item in replaysGroup)
        {
            item.x = startX + 10;
        }

        FlxTween.tween(bgList, {x: targetX}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(headerText, {x: targetX + 10}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(sortText, {x: targetX + 10}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(selectedReplayName, {x: targetX - 450}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(selectedReplayInfo, {x: targetX - 450}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(selectedReplayAccuracy, {x: targetX - 450}, 0.6, {ease: FlxEase.circOut});

        for (item in replaysGroup)
        {
            FlxTween.tween(item, {x: targetX + 10}, 0.6, {ease: FlxEase.circOut});
        }

        FlxTween.tween(bgDim, {alpha: 0.5}, 0.6, {ease: FlxEase.circOut});

        // 创建鼠标滚动控制器
        cardScroller = new MouseMove(this, 'scrollPos', [0, maxScrollPos],
            [[0, FlxG.width], [60, FlxG.height]],
            function() { updateItemsPosition(); }
        );
        cardScroller.useLerp = true;
        cardScroller.lerpSmooth = 12;
        cardScroller.dragSensitivity = 1.6;
        cardScroller.deceleration = 0.94;
        cardScroller.mouseWheelSensitivity = -200.0;
        add(cardScroller);

        // 如果有回放，默认选中第一个
        if (replayFiles.length > 0)
        {
            curSelected = 0;
            updateSelection();
        }

        updateItemsPosition();

        super.create();
    }

    function updateMaxScroll()
    {
        var total = replayFiles.length;
        maxScrollPos = Math.max(0, (total * (itemHeight + ITEM_SPACING)) - (FlxG.height - PADDING_TOP - PADDING_BOTTOM - 60));
    }

    /** 子标题里的来源文案：Content 分类 / 内容包 / mod / base。 */
    function getSourceLabel():String
    {
        if (parent != null && parent.isContentMode())
            return parent.isCustomChartMode() ? 'Custom Charts' : Paths.currentChartCategory;

        if (currentContentRoot != null)
        {
            var parts:Array<String> = currentContentRoot.split('/');
            var packName:String = (parts.length > 0) ? parts[parts.length - 1] : currentContentRoot;
            return 'Vanilla: $packName';
        }

        if (currentModFolder != null && currentModFolder.length > 0) return currentModFolder;
        return 'Base Game';
    }

    /**
     * 这首歌曲要扫的回放目录（相对 assets/replays/）。
     * 内容包按包分目录（content/VanillaSongs/PicoMix），另外补扫 base/ ——
     * 老版本把内容包回放存在 base/ 里，不补一次老存档就看不见了。
     */
    function getReplayBuckets():Array<String>
    {
        var buckets:Array<String> = [];

        if (parent != null && parent.isCustomChartMode())
        {
            buckets.push(FrameReplay.CUSTOM_REPLAY_BUCKET);
            return buckets;
        }

        var modBucket:String = (currentModFolder != null && currentModFolder.length > 0) ? currentModFolder : "base";
        var contentBucket:String = FrameReplay.getContentReplayBucket(currentContentRoot);

        if (contentBucket != null) buckets.push(contentBucket);
        buckets.push(modBucket);
        if (contentBucket != null && !buckets.contains("base")) buckets.push("base");
        return buckets;
    }

    /** 把内容包资源根规整成可比较的形态（去掉尾斜杠与反斜杠）。 */
    static function normalizeRoot(root:String):String
    {
        if (root == null) return "";
        var out:String = root.split('\\').join('/');
        while (out.length > 0 && out.charAt(out.length - 1) == '/')
            out = out.substring(0, out.length - 1);
        return out;
    }

    /** 难度名里是否自带变体前缀（旧 PicoMix 存档写的是 'Pico Normal'）。 */
    static function difficultyVariantHint(diffName:String):String
    {
        if (diffName == null) return null;
        var lower:String = diffName.toLowerCase();
        if (lower.indexOf('pico') >= 0) return 'pico';
        if (lower.indexOf('erect') >= 0) return 'erect';
        if (lower == 'nightmare' || lower == 'hmnf') return 'erect';
        return null;
    }

    function loadReplays()
    {
        #if sys
        replayFiles = [];

        var buckets:Array<String> = getReplayBuckets();
        var currentRootNorm:String = normalizeRoot(currentContentRoot);
        var currentVariantLower:String = (currentVariant != null) ? currentVariant.toLowerCase() : null;

        // 规范化歌曲名，用于模糊匹配。
        // replay 里存的是谱面内部 song 字段，Freeplay 传进来的是周 JSON 的显示名，
        // 两者只在空格/连字符上必然一致（"Dad Battle" vs "dad-battle"），其余标点
        // （' , . ! # & ( ) : 等）两边写法可能不同。因此只保留字母数字，
        // 把一切非字母数字字符都丢掉，才能让显示名和 slug 落到同一个 key。
        function normalizeSongName(name:String):String {
            if (name == null) return "";
            var out = new StringBuf();
            for (i in 0...name.length) {
                var c = name.charAt(i).toLowerCase();
                if ((c >= "a" && c <= "z") || (c >= "0" && c <= "9"))
                    out.add(c);
            }
            return out.toString();
        }

        var normalizedCurrent:String = normalizeSongName(currentSongName);
        var seen:Map<String, Bool> = [];

        for (modFolder in buckets)
        {
            var replayDir:String = FrameReplay.getReplayRootDir() + modFolder + "/";
            if (!FileSystem.exists(replayDir) || !FileSystem.isDirectory(replayDir))
            {
                trace('Replay directory does not exist: $replayDir');
                continue;
            }

            var files:Array<String> = FileSystem.readDirectory(replayDir);
            for (file in files)
            {
                if (!file.endsWith(".replay") && !file.endsWith(".kadeReplay")) continue;
                if (seen.exists(modFolder + "/" + file)) continue;

                try
                {
                    var filePath = replayDir + file;
                    var fileContent = File.getContent(filePath);
                    var json:Dynamic = Json.parse(fileContent);

                    if (json == null) continue;

                    // 检查歌曲名是否匹配（规范化后比较）
                    var replaySongName = json.songName != null ? json.songName : "";
                    var normalizedReplay:String = normalizeSongName(replaySongName);

                    // 模糊匹配：规范化后相同即可
                    if (normalizedReplay != normalizedCurrent) continue;

                    // 同一条回放可能被多个 bucket 扫到（base/ 回退），按歌曲归属过一遍：
                    //   回放自带资源根 → 必须与当前浏览的包一致（普通歌则为空根）；
                    //   老存档没有资源根 → 用难度名里的变体前缀猜，猜不出就当 base 的。
                    var replayRoot:String = normalizeRoot(json.chartContentRoot != null ? Std.string(json.chartContentRoot) : "");
                    var entryDiffName:String = json.difficultyName != null ? json.difficultyName :
                        (json.songDiff != null ? Difficulty.getString(Std.int(json.songDiff)) : "Normal");
                    var isCustomEntry:Bool = (json.isCustomChart == true) || modFolder == FrameReplay.CUSTOM_REPLAY_BUCKET;

                    if (!isCustomEntry)
                    {
                        if (replayRoot.length > 0)
                        {
                            if (replayRoot != currentRootNorm) continue;
                        }
                        else
                        {
                            var hint:String = difficultyVariantHint(entryDiffName);
                            if (hint != null && (currentVariantLower == null || hint != currentVariantLower)) continue;
                        }
                    }

                    seen.set(modFolder + "/" + file, true);

                    var entry:ReplayEntry = {
                        filename: file,
                        modFolder: modFolder,
                        songName: replaySongName,
                        difficultyName: entryDiffName,
                        accuracy: json.finalAccuracy != null ? Std.parseFloat(Std.string(json.finalAccuracy)) :
                            (json.accuracy != null ? Std.parseFloat(Std.string(json.accuracy)) : 0),
                        score: json.finalScore != null ? Std.parseInt(Std.string(json.finalScore)) :
                            (json.score != null ? Std.parseInt(Std.string(json.score)) : 0),
                        misses: json.finalMisses != null ? Std.parseInt(Std.string(json.finalMisses)) :
                            (json.misses != null ? Std.parseInt(Std.string(json.misses)) : 0),
                        rating: json.finalRating != null ? json.finalRating :
                            (json.rating != null ? json.rating : "N/A"),
                        ratingFC: json.finalRatingFC != null ? json.finalRatingFC :
                            (json.ratingFC != null ? json.ratingFC : "N/A"),
                        modDirectory: json.modDirectory != null ? json.modDirectory : modFolder,
                        isDownscroll: json.isDownscroll == true,
                        noteSpeed: json.noteSpeed != null ? Std.parseFloat(Std.string(json.noteSpeed)) : 1.5,
                        rawJson: json,
                        dateStr: extractDateFromReplay(json),
                        fullPath: filePath,
                        isCustomChart: isCustomEntry,
                        sustainOffset: json.sustainOffset != null ? Std.parseFloat(Std.string(json.sustainOffset)) : 0,
                        keyCount: json.keyCount != null ? Std.parseInt(Std.string(json.keyCount)) : 4,
                        keyLayout: buildKeyLayout(json.laneKeys),
                        mirrorNotes: json.mirrorNotes == true,
                        timestampMs: extractTimestampMs(json),
                        dateTimeStr: extractDateTimeFromReplay(json)
                    };

                    replayFiles.push(entry);
                }
                catch(e:Dynamic)
                {
                    trace('Error parsing replay $file: $e');
                }
            }
        }
        
        // 排序（默认日期降序，最新在前）
        sortReplays();
        #end
    }
    
    /** 从 replay 的 timestamp 解析出 Date；解析不出返回 null。 */
    function parseReplayDate(json:Dynamic):Date
    {
        if (json == null) return null;
        var timestamp = json.timestamp;
        if (timestamp == null) return null;
        try
        {
            if (Std.isOfType(timestamp, Date))
                return cast timestamp;

            if (Std.isOfType(timestamp, String))
            {
                var str:String = cast timestamp;
                try { return Date.fromString(str); } catch (e:Dynamic) {}
                var parts = str.split('T')[0].split(' ');
                parts = parts[0].split('-');
                if (parts.length >= 3)
                {
                    var year = Std.parseInt(parts[0]);
                    var month = Std.parseInt(parts[1]);
                    var day = Std.parseInt(parts[2]);
                    if (year != null && month != null && day != null)
                        return new Date(year, month - 1, day, 0, 0, 0);
                }
                return null;
            }

            if (Std.isOfType(timestamp, Float) || Std.isOfType(timestamp, Int))
            {
                var num:Float = Std.parseFloat(Std.string(timestamp));
                if (!Math.isNaN(num)) return Date.fromTime(num);
            }
        }
        catch (e:Dynamic) {}
        return null;
    }

    function formatReplayDate(date:Date, withTime:Bool):String
    {
        var year = StringTools.lpad(Std.string(date.getFullYear()), '0', 4);
        var month = StringTools.lpad(Std.string(date.getMonth() + 1), '0', 2);
        var day = StringTools.lpad(Std.string(date.getDate()), '0', 2);
        if (!withTime) return '$year-$month-$day';
        var hour = StringTools.lpad(Std.string(date.getHours()), '0', 2);
        var minute = StringTools.lpad(Std.string(date.getMinutes()), '0', 2);
        var second = StringTools.lpad(Std.string(date.getSeconds()), '0', 2);
        return '$year-$month-$day $hour:$minute:$second';
    }

    function extractDateTimeFromReplay(json:Dynamic):String
    {
        var date:Date = parseReplayDate(json);
        if (date == null) return "0000-00-00 00:00:00";
        return formatReplayDate(date, true);
    }

    function extractTimestampMs(json:Dynamic):Float
    {
        var date:Date = parseReplayDate(json);
        return date == null ? 0 : date.getTime();
    }

    /** laneKeys（lane -> 键名数组）取每 lane 首键名拼成键型串，如 "ASWD"。 */
    function buildKeyLayout(laneKeys:Dynamic):String
    {
        if (laneKeys == null) return "----";
        var out:String = "";
        try
        {
            var lanes:Array<Dynamic> = cast laneKeys;
            for (lane in lanes)
            {
                var keys:Array<Dynamic> = cast lane;
                if (keys != null && keys.length > 0 && keys[0] != null)
                    out += Std.string(keys[0]);
                else
                    out += "?";
            }
        }
        catch (e:Dynamic) {}
        return out.length > 0 ? out : "----";
    }

    function extractDateFromReplay(json:Dynamic):String
    {
        var timestamp = json.timestamp;
        if (timestamp == null) return "0000-00-00";
        
        try {
            var date:Date = null;
            if (Std.isOfType(timestamp, Date)) {
                date = cast timestamp;
            } 
            else if (Std.isOfType(timestamp, String)) {
                var str:String = cast timestamp;
                if (str.indexOf('T') > -1) {
                    try {
                        date = Date.fromString(str);
                    } catch(e:Dynamic) {
                        var parts = str.split('T')[0].split('-');
                        if (parts.length >= 3) {
                            var year = Std.parseInt(parts[0]);
                            var month = Std.parseInt(parts[1]);
                            var day = Std.parseInt(parts[2]);
                            if (year != null && month != null && day != null) {
                                return StringTools.lpad(Std.string(year), '0', 4) + '-' +
                                    StringTools.lpad(Std.string(month), '0', 2) + '-' +
                                    StringTools.lpad(Std.string(day), '0', 2);
                            }
                        }
                    }
                } 
                else {
                    try {
                        date = Date.fromString(str);
                    } catch(e:Dynamic) {}
                }
            } 
            else if (Std.isOfType(timestamp, Float) || Std.isOfType(timestamp, Int)) {
                var num:Float = Std.parseFloat(Std.string(timestamp));
                if (!Math.isNaN(num)) date = Date.fromTime(num);
            }
            
            if (date != null) {
                var year:String = StringTools.lpad(Std.string(date.getFullYear()), '0', 4);
                var month:String = StringTools.lpad(Std.string(date.getMonth() + 1), '0', 2);
                var day:String = StringTools.lpad(Std.string(date.getDate()), '0', 2);
                return '$year-$month-$day';
            }
        } catch(e:Dynamic) {}
        return "0000-00-00";
    }

    /** 按当前 sortMode 重排 replayFiles。 */
    function sortReplays():Void
    {
        if (sortMode == 1)
        {
            replayFiles.sort(function(a, b):Int {
                return Reflect.compare(b.accuracy, a.accuracy);
            });
        }
        else
        {
            replayFiles.sort(function(a, b):Int {
                return Reflect.compare(b.timestampMs, a.timestampMs);
            });
        }
    }

    function updateSortText():Void
    {
        if (sortText == null) return;
        sortText.text = (sortMode == 1) ? 'Sort: Accuracy ↓  (click to change)' : 'Sort: Date ↓  (click to change)';
    }

    function toggleSort():Void
    {
        var keepFile:String = (curSelected >= 0 && curSelected < replayFiles.length) ? replayFiles[curSelected].filename : null;
        sortMode = (sortMode == 0) ? 1 : 0;
        sortReplays();
        if (keepFile != null)
        {
            for (i in 0...replayFiles.length)
            {
                if (replayFiles[i].filename == keepFile) { curSelected = i; break; }
            }
        }
        if (replayFiles.length > 0 && (curSelected < 0 || curSelected >= replayFiles.length)) curSelected = 0;
        rebuildItems();
        updateMaxScroll();
        updateItemsPosition();
        updateSelection();
        updateSortText();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    function buildInfoText(entry:ReplayEntry):String
    {
        var lines:Array<String> = [];
        var diffLine:String = 'Difficulty: ' + entry.difficultyName;
        if (entry.isCustomChart) diffLine += '   [Custom Chart]';
        lines.push(diffLine);
        lines.push('Time: ' + entry.dateTimeStr);
        lines.push('Sustain Offset: ' + FlxMath.roundDecimal(entry.sustainOffset, 2));
        lines.push('Keys: ' + entry.keyCount + 'K (' + entry.keyLayout + ')');
        lines.push('Mirror: ' + (entry.mirrorNotes ? 'ON' : 'OFF'));
        lines.push('Score: ' + entry.score + '   Misses: ' + entry.misses);
        return lines.join('\n');
    }

    /** 面板完整矩形（含顶部表头）——点它外面即退出。 */
    function isMouseOverPanel():Bool
    {
        if (bgList == null) return false;
        var mouseX = FlxG.mouse.viewX;
        var mouseY = FlxG.mouse.viewY;
        return mouseX >= bgList.x && mouseX <= bgList.x + bgList.width &&
               mouseY >= bgList.y && mouseY <= bgList.y + bgList.height;
    }

    function isMouseOverSortText():Bool
    {
        if (sortText == null) return false;
        var mouseX = FlxG.mouse.viewX;
        var mouseY = FlxG.mouse.viewY;
        return mouseX >= sortText.x && mouseX <= sortText.x + sortText.width &&
               mouseY >= sortText.y && mouseY <= sortText.y + sortText.height;
    }

    function rebuildItems()
    {
        clearPressedItem();
        for (item in replaysGroup)
        {
            item.destroy();
        }
        replaysGroup.clear();

        var startY:Float = bgList.y + PADDING_TOP + 55;

        for (i in 0...replayFiles.length)
        {
            var entry = replayFiles[i];
            
            var item = new ReplayItem(
                entry.songName,
                entry.accuracy,
                entry.modDirectory,
                entry.filename,
                entry.dateStr,
                entry.difficultyName,
                entry.modFolder,
                entry.rating,
                entry.ratingFC,
                i
            );
            item.setPosition(bgList.x + 10, startY + (i * (itemHeight + ITEM_SPACING)));
            replaysGroup.add(item);
        }

        noReplaysText.visible = replayFiles.length == 0;
        updateItemsPosition();
    }

    function clearPressedItem():Void
    {
        pressedItem = -1;
        if (replaysGroup == null || replaysGroup.members == null) return;
        for (item in replaysGroup.members)
        {
            if (item != null) item.setPressed(false);
        }
    }

    function updateItemsPosition()
    {
        var viewTop:Float = bgList.y + PADDING_TOP + 55;
        var viewBottom:Float = bgList.y + bgList.height;
        var viewLeft:Float = bgList.x;
        var viewRight:Float = bgList.x + bgList.width;

        for (i in 0...replaysGroup.members.length)
        {
            var item = replaysGroup.members[i];
            var baseY:Float = viewTop + i * (itemHeight + ITEM_SPACING);

            item.y = baseY - scrollPos;

            // 整行在视口外直接不画；露出来一截的交给 clipToViewport 裁到视口边上
            var isVisible:Bool = item.y + item.itemHeight > viewTop && item.y < viewBottom;
            item.visible = isVisible;
            item.active = isVisible;
            item.clipToViewport(viewLeft, viewTop, viewRight, viewBottom);
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (shouldClose)
        {
            clearPressedItem();
            closingTimer += elapsed;
            if (closingTimer >= 0.65)
            {
                _closeNow();
                return;
            }
            return;
        }

        if (waitingForDeleteConfirm)
        {
            clearPressedItem();
            if (FlxG.keys.justPressed.Y) confirmDelete();
            else if (FlxG.keys.justPressed.N || FlxG.keys.justPressed.ESCAPE) cancelDelete();
            return;
        }

        // 鼠标滚轮滚动
        if (FlxG.mouse.wheel != 0 && isMouseOverList())
        {
            var newScroll = scrollPos - FlxG.mouse.wheel * 40;
            scrollPos = Math.max(0, Math.min(newScroll, maxScrollPos));
            updateItemsPosition();
        }

        // 点击面板外空白处退出
        if (FlxG.mouse.justPressed && !isMouseOverPanel())
        {
            close();
            return;
        }

        // 点击顶部排序文字切换 日期/准确率
        if (FlxG.mouse.justPressed && isMouseOverSortText())
        {
            toggleSort();
            return;
        }

        if (controls.UI_UP_P)
            changeSelection(-1);
        else if (controls.UI_DOWN_P)
            changeSelection(1);
        else if (controls.ACCEPT)
            loadSelectedReplay();
        else if (controls.BACK || FlxG.keys.justPressed.ESCAPE || FlxG.mouse.justPressedRight)
            close();

        if (FlxG.keys.justPressed.F && replayFiles.length > 0 && !waitingForDeleteConfirm)
        {
            if (curSelected >= 0 && curSelected < replayFiles.length)
                promptDelete(replayFiles[curSelected].filename);
        }

        if (shouldClose || waitingForDeleteConfirm)
        {
            clearPressedItem();
            return;
        }

        // 按下项保存在成员中，才能在后续松开帧与命中项比较。
        var releasedItem:Int = -1;
        if (FlxG.mouse.justPressed)
        {
            clearPressedItem();
            for (i in 0...replaysGroup.members.length)
            {
                var item = replaysGroup.members[i];
                if (item.visible && item.overlapsMouse())
                {
                    pressedItem = i;
                    item.setPressed(true);
                    break;
                }
            }
        }
        else if (pressedItem >= 0 && !FlxG.mouse.pressed && !FlxG.mouse.justReleased)
        {
            clearPressedItem();
        }

        if (FlxG.mouse.justReleased)
        {
            for (i in 0...replaysGroup.members.length)
            {
                var item = replaysGroup.members[i];
                if (item.visible && item.overlapsMouse())
                {
                    releasedItem = i;
                    break;
                }
            }

            var clickedItem:Int = pressedItem;
            clearPressedItem();
            if (releasedItem >= 0 && releasedItem == clickedItem)
            {
                curSelected = releasedItem;
                scrollToItemMiddle(releasedItem);
                updateSelection();
                loadSelectedReplay();
            }
        }

        // 悬停效果
        for (i in 0...replaysGroup.members.length)
        {
            var item = replaysGroup.members[i];
            if (item.visible && item.overlapsMouse())
            {
                item.updateHover(true);
            }
            else
            {
                item.updateHover(false);
            }
        }
    }

    function isMouseOverList():Bool
    {
        var mouseX = FlxG.mouse.viewX;
        var mouseY = FlxG.mouse.viewY;
        return mouseX >= bgList.x && mouseX <= bgList.x + bgList.width &&
               mouseY >= bgList.y + 55 && mouseY <= bgList.y + bgList.height - 10;
    }

    function scrollToItemMiddle(index:Int)
    {
        var targetScroll = index * (itemHeight + ITEM_SPACING) - (visibleItemCount * (itemHeight + ITEM_SPACING)) / 2 + (itemHeight / 2);
        targetScroll = Math.max(0, Math.min(targetScroll, maxScrollPos));
        
        if (cardScroller != null)
        {
            cardScroller.tweenData = targetScroll;
        }
        else
        {
            scrollPos = targetScroll;
            updateItemsPosition();
        }
    }

    function changeSelection(change:Int = 0)
    {
        if (replayFiles.length == 0) return;
        
        curSelected = FlxMath.wrap(curSelected + change, 0, replayFiles.length - 1);
        scrollToItemMiddle(curSelected);
        updateSelection();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    function updateSelection()
    {
        for (i in 0...replaysGroup.members.length)
        {
            var item = replaysGroup.members[i];
            item.updateSelection(i == curSelected);
        }

        if (curSelected >= 0 && curSelected < replayFiles.length)
        {
            var entry = replayFiles[curSelected];
            selectedReplayName.text = entry.songName;
            selectedReplayInfo.text = buildInfoText(entry);

            var accStr:String = FlxMath.roundDecimal(entry.accuracy, 2) + '%';
            selectedReplayAccuracy.text = accStr;
            selectedReplayAccuracy.color = getAccuracyColor(entry.accuracy);
        }
        else
        {
            selectedReplayName.text = "No Replay Selected";
            selectedReplayInfo.text = "";
            selectedReplayAccuracy.text = "";
        }
    }

    function getAccuracyColor(acc:Float):FlxColor
    {
        if (acc >= 95) return FlxColor.LIME;
        if (acc >= 90) return FlxColor.YELLOW;
        if (acc >= 80) return FlxColor.ORANGE;
        return FlxColor.RED;
    }

    function loadSelectedReplay()
    {
        if (curSelected < 0 || curSelected >= replayFiles.length) return;
        loadReplay(replayFiles[curSelected].fullPath);
    }

    function loadReplay(filePath:String)
    {
        trace('Loading replay: $filePath');
        
        var rep:FrameReplay = FrameReplay.LoadReplay(filePath);
        if (rep == null || !rep.isValid())
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Invalid replay file!");
            return;
        }
        
        #if MODS_ALLOWED
        // 回放没记 mod 目录（base 歌 / 内容包歌）时要显式清空：
        // 否则会把界面上一次浏览留下的 mod 目录带进去，资源先往 mods/<m>/ 里找。
        Mods.currentModDirectory = (rep.replay.modDirectory != null && rep.replay.modDirectory.length > 0)
            ? rep.replay.modDirectory : "";
        #end
        
        PlayState.frameRep = rep;
        PlayState.loadRep = true;
        PlayState.inReplay = true;
        PlayState.replayFileName = filePath;
        
        var difficultyID:Int = 1;
        if (rep.replay.difficultyName != null)
        {
            // 先按名字在当前难度表里精确匹配：变体难度名（'Pico Normal'）只有这样才能拿到
            // 正确下标，PlayState 侧 getAudioVariant() 才认得出音轨变体目录。
            // 关键词分支会丢掉变体前缀（'Pico Normal' 里含 'normal' → 落到 1 = 普通 Normal），
            // 变体回放就会静默放原曲音轨，所以只作为匹配不到时的兜底。
            var listedIndex:Int = Difficulty.list.indexOf(rep.replay.difficultyName);
            if (listedIndex >= 0)
            {
                difficultyID = listedIndex;
            }
            else
            {
                var diffLower = rep.replay.difficultyName.toLowerCase();
                if (diffLower.indexOf('easy') >= 0) difficultyID = 0;
                else if (diffLower.indexOf('normal') >= 0) difficultyID = 1;
                else if (diffLower.indexOf('hard') >= 0) difficultyID = 2;
                else difficultyID = rep.replay.songDiff;
            }
        }
        else difficultyID = rep.replay.songDiff;
        
        PlayState.storyDifficulty = difficultyID;
        PlayState.storyWeek = 0;
        
        var songName:String = rep.replay.songName;
        var difficultyName:String = rep.replay.difficultyName;

        // ---- 内容包上下文 ----
        // 回放里的 chartContentRoot 是后加的字段，早期版本录的 PicoMix / Erect 存档没有它。
        // 这时靠三层兜底把资源根找回来，否则谱面会去 assets/ 找（-pico-normal 不在那儿），
        // 结果是"回放点了没反应 / 报缺谱面"。
        //   1. 回放自带 chartContentRoot
        //   2. Freeplay 传进来的当前浏览歌的资源根（回放列表本来就是按这首过滤的）
        //   3. 扫 content/VanillaSongs/* 找哪份谱面真的存在
        var replayContentRoot:String = normalizeRoot(rep.replay.chartContentRoot);
        if (replayContentRoot.length == 0) replayContentRoot = normalizeRoot(currentContentRoot);
        if (replayContentRoot.length == 0)
        {
            // 只有难度名自带变体前缀（旧 PicoMix 的 'Pico Normal'）才敢去包里翻谱面 ——
            // 否则 base 的 Bopeebo Normal 会被误认成 PicoMix 里的同名谱面。
            var diffVariantHint:String = difficultyVariantHint(difficultyName);
            if (diffVariantHint != null)
            {
                var probed:String = findContentRootForChart(songName, difficultyName, diffVariantHint);
                if (probed != null) replayContentRoot = probed;
            }
        }
        if (replayContentRoot.length == 0) replayContentRoot = null;

        var replayVariant:String = (replayContentRoot != null) ? WeekData.getVariantForContentRoot(replayContentRoot) : null;
        // 周定义没登记（包被隐藏 / weeksLoaded 里查不到）时，只有当前浏览的正是同一个包，
        // 才敢借用界面上那首歌的变体 —— 借错包会拼出别的包的音轨目录。
        if (replayVariant == null && replayContentRoot != null && currentContentRoot != null
            && normalizeRoot(currentContentRoot) == replayContentRoot)
            replayVariant = currentVariant;

        try
        {
            // 后缀一律交给 Difficulty 拼：它会按变体决定要不要带前缀，
            // 也保证与存档键、SongInfoParser 拼出来的文件名一致。
            // 旧 PicoMix 存档的难度名自带变体前缀（'Pico Normal'），先剥掉再拼，
            // 否则会得到 -pico-pico-normal。
            var diffSuffix:String = Difficulty.getFilePathForName(stripVariantPrefix(difficultyName, replayVariant), replayVariant);
            var jsonToLoad = songName + diffSuffix;
            trace('Loading JSON: $jsonToLoad (contentRoot=$replayContentRoot variant=$replayVariant)');
            // 只有 CustomCharts 才走自定义谱面那套；内容包（VanillaSongs/*）不是自定义谱面，
            // 以前只要 chartCategory 非空就往这边走，内容包回放会被判成"找不到自定义谱面"。
            if (rep.replay.chartCategory != null && rep.replay.chartCategory.length > 0
                && Paths.isCustomChartCategory(rep.replay.chartCategory))
            {
                var customSongs = CustomChartData.load(rep.replay.chartCategory);
                var customSong:CustomChartSong = null;
                for (candidate in customSongs)
                {
                    if (candidate.name == songName || Paths.formatToSongPath(candidate.name) == Paths.formatToSongPath(songName))
                    {
                        customSong = candidate;
                        break;
                    }
                }
                if (customSong == null)
                    throw 'Custom chart not found: $songName';

                // 资源根 / 曲师谱师按谱面目录重新推导；回放里存的 chartContentRoot 只作兜底
                // （内容包目录被挪走时仍能定位到 songs/ 下的变体音轨）。
                var contentRoot:String = customSong.contentRoot;
                if ((contentRoot == null || contentRoot.length == 0) && rep.replay.chartContentRoot != null)
                    contentRoot = rep.replay.chartContentRoot;

                Paths.setChartContext(rep.replay.chartCategory, customSong.directory,
                    rep.replay.chartHasVSliceMetadata, rep.replay.chartAudioSuffix,
                    contentRoot, customSong.artist, customSong.charter);
                PlayState.chartCategory = Paths.currentChartCategory;
                PlayState.chartDirectory = Paths.currentChartDirectory;
                PlayState.chartHasVSliceMetadata = Paths.currentChartHasVSliceMetadata;
                PlayState.chartAudioSuffix = Paths.currentChartAudioSuffix;
                PlayState.chartContentRoot = Paths.currentContentRoot;
                PlayState.chartMetadataArtist = Paths.currentChartMetaArtist;
                PlayState.chartMetadataCharter = Paths.currentChartMetaCharter;

                PlayState.SONG = cast CustomChartData.loadChart(customSong, difficultyName);
                StageData.loadDirectory(PlayState.SONG); // 同上：内容包回放也要定下舞台目录
            }
            else
            {
                // 普通歌 / 内容包回放：清掉上一次 content 浏览留下的谱面上下文，
                // 否则 PlayState.create() 会把普通歌误判成 content 模式。
                // 内容包回放要把资源根（连同变体）带回去 —— 谱面与变体音轨都在包里。
                Paths.setChartContext(null, null, false, null, replayContentRoot, null, null, replayVariant);
                PlayState.clearChartContext();
                PlayState.SONG = Song.loadFromJson(jsonToLoad, songName);
            }
            
            if (PlayState.SONG == null) throw 'Failed to load song';
            
            PlayState.isStoryMode = false;
            ClientPrefs.data.downScroll = rep.replay.isDownscroll;
            
            FlxG.sound.music.stop();
            close();
            LoadingState.loadAndSwitchState(new PlayState());
        }
        catch(e:Dynamic)
        {
            trace('Error loading song: $e');
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Failed to load song!\nMissing: ${songName + diffSuffix}.json");
        }
    }

    /** 旧 PicoMix 存档的难度名自带变体前缀（'Pico Normal'），拼文件名前先剥掉。 */
    static function stripVariantPrefix(diffName:String, variant:String):String
    {
        if (diffName == null) return null;
        if (variant == null || variant.length == 0) return diffName;

        var lower:String = diffName.toLowerCase();
        var v:String = variant.toLowerCase();
        if (lower.indexOf(v) != 0) return diffName;

        var rest:String = diffName.substring(variant.length);
        while (rest.length > 0 && (rest.charAt(0) == ' ' || rest.charAt(0) == '-'))
            rest = rest.substring(1);
        // 整个难度名就是变体名（'Pico'）时保留原样，别剥成空串
        return rest.length > 0 ? rest : diffName;
    }

    /**
     * 兜底：回放没有 chartContentRoot（早期版本录的）时，去 content 各包里找这首歌这一档的谱面，
     * 找到就返回它所属的资源根（content/VanillaSongs/PicoMix）。
     */
    static function findContentRootForChart(songName:String, difficultyName:String, variant:String):String
    {
        #if sys
        if (songName == null) return null;

        var songPath:String = Paths.formatToSongPath(songName);
        var diffSlug:String = (difficultyName != null)
            ? Paths.formatToSongPath(stripVariantPrefix(difficultyName, variant)) : null;

        var groupRoot:String = '${Paths.CONTENT_ROOT}/VanillaSongs';
        if (!FileSystem.exists(groupRoot)) return null;

        for (pack in FileSystem.readDirectory(groupRoot))
        {
            if (pack.startsWith('.')) continue;
            var root:String = '$groupRoot/$pack';
            if (!FileSystem.isDirectory(root)) continue;

            for (dataDir in ['$root/shared/data/$songPath', '$root/data/$songPath', '$root/songs/$songPath'])
            {
                if (!FileSystem.exists(dataDir) || !FileSystem.isDirectory(dataDir)) continue;
                for (file in FileSystem.readDirectory(dataDir))
                {
                    if (!file.endsWith('.json')) continue;
                    var chartName:String = file.substr(0, file.length - 5).toLowerCase();

                    // 无后缀 = 普通 Normal
                    if (chartName == songPath)
                    {
                        if (diffSlug == null || diffSlug.length == 0 || diffSlug == 'normal') return root;
                        continue;
                    }

                    if (chartName.indexOf(songPath) != 0) continue;
                    if (diffSlug == null || diffSlug.length == 0) continue;
                    // <歌>-<变体>-<档位> 或 <歌>-<档位>，都靠"以 -<档位> 结尾"命中
                    if (chartName.endsWith('-' + diffSlug)) return root;
                }
            }
        }
        #end
        return null;
    }

    function showError(message:String)
    {
        var errorMsg:FlxText = new FlxText(0, FlxG.height / 2 - 30, FlxG.width, message, 18);
        errorMsg.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
        errorMsg.borderSize = 2;
        errorMsg.antialiasing = ClientPrefs.data.antialiasing;
        errorMsg.screenCenter(X);
        add(errorMsg);
        
        new FlxTimer().start(3, function(tmr:FlxTimer) {
            remove(errorMsg);
            errorMsg.destroy();
        });
    }

    function promptDelete(filename:String)
    {
        clearPressedItem();
        replayToDelete = filename;
        waitingForDeleteConfirm = true;
        var displayName = filename;
        if (displayName.length > 40) displayName = displayName.substr(0, 37) + "...";
        deleteConfirmText.text = 'Delete "${displayName}"? (Y/N)';
        deleteConfirmText.visible = true;
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    function confirmDelete()
    {
        #if sys
        var fullPath:String = "";
        for (entry in replayFiles)
        {
            if (entry.filename == replayToDelete)
            {
                fullPath = entry.fullPath;
                break;
            }
        }
        
        if (fullPath != "" && FileSystem.exists(fullPath))
        {
            FileSystem.deleteFile(fullPath);
            trace('Deleted replay: $replayToDelete');
            
            loadReplays();
            curSelected = 0;
            scrollPos = 0;
            updateMaxScroll();
            rebuildItems();
            updateSelection();
            updateItemsPosition();
            
            FlxG.sound.play(Paths.sound('cancelMenu'));
        }
        #end
        cancelDelete();
    }

    function cancelDelete()
    {
        waitingForDeleteConfirm = false;
        replayToDelete = "";
        deleteConfirmText.visible = false;
        FlxG.sound.play(Paths.sound('cancelMenu'));
    }

    private function _closeNow():Void
    {
        if (parent != null)
            parent.inModFolderSelector = false;
        super.close();
    }

    var closingTimer:Float = 0;
    var shouldClose:Bool = false;

    override function close()
    {
        clearPressedItem();
        if (shouldClose) 
        {
            #if !flash
            FlxTransitionableState.skipNextTransOut = false;
            #end
            _closeNow();
            return;
        }
        
        shouldClose = true;
        closingTimer = 0;

        // ===== 背景和主面板 =====
        FlxTween.tween(bgList, {x: startX, alpha: 0}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(bgDim, {alpha: 0}, 0.6, {ease: FlxEase.circOut});
        
        // ===== 标题和子标题 =====
        FlxTween.tween(headerText, {x: startX + 10, alpha: 0}, 0.6, {ease: FlxEase.circOut});
        
        // 子标题（需要找到它，或者直接遍历所有文本）
        for (member in members)
        {
            if (Std.isOfType(member, FlxText))
            {
                var text:FlxText = cast member;
                // 跳过一些特殊的文本（deleteConfirmText 和 noReplaysText 单独处理）
                if (text == deleteConfirmText || text == noReplaysText) continue;
                if (text.text == 'Replays for:' || text.text.indexOf('Mod:') == 0)
                {
                    FlxTween.tween(text, {x: startX + 10, alpha: 0}, 0.6, {ease: FlxEase.circOut});
                }
            }
        }
        
        // ===== 右侧信息区域 =====
        FlxTween.tween(selectedReplayName, {x: startX + 50, alpha: 0}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(selectedReplayInfo, {x: startX + 50, alpha: 0}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(selectedReplayAccuracy, {x: startX + 50, alpha: 0}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(sortText, {x: startX + 10, alpha: 0}, 0.6, {ease: FlxEase.circOut});

        // ===== 操作提示 =====
        for (member in members)
        {
            if (Std.isOfType(member, FlxText))
            {
                var text:FlxText = cast member;
                if (text.text.indexOf("↑/↓: Navigate") == 0)
                {
                    FlxTween.tween(text, {alpha: 0}, 0.6, {ease: FlxEase.circOut});
                }
            }
        }

        // ===== Replay 项目列表 =====
        for (item in replaysGroup)
        {
            FlxTween.tween(item, {x: startX + 10, alpha: 0}, 0.6, {ease: FlxEase.circOut});
        }

        // ===== noReplaysText（如果没有 replay 时显示） =====
        if (noReplaysText != null)
        {
            FlxTween.tween(noReplaysText, {alpha: 0}, 0.6, {ease: FlxEase.circOut});
        }

        // ===== deleteConfirmText =====
        if (deleteConfirmText != null)
        {
            FlxTween.tween(deleteConfirmText, {alpha: 0}, 0.6, {ease: FlxEase.circOut});
        }
        
        if (cardScroller != null)
        {
            remove(cardScroller);
            cardScroller.destroy();
            cardScroller = null;
        }
    }

    override function destroy()
    {
        clearPressedItem();
        for (item in replaysGroup)
        {
            item.destroy();
        }
        replaysGroup = null;
        replayFiles = [];
        
        super.destroy();
    }
}

/**
 * 回放条目数据
 */
typedef ReplayEntry = {
    var filename:String;
    var modFolder:String;
    var songName:String;
    var difficultyName:String;
    var accuracy:Float;
    var score:Int;
    var misses:Int;
    var rating:String;
    var ratingFC:String;
    var modDirectory:String;
    var isDownscroll:Bool;
    var noteSpeed:Float;
    var dateStr:String;
    var rawJson:Dynamic;
    var fullPath:String;
    // 新增字段
    var isCustomChart:Bool;
    var sustainOffset:Float;
    var keyCount:Int;
    var keyLayout:String;
    var mirrorNotes:Bool;
    var timestampMs:Float;
    var dateTimeStr:String;
}

/**
 * 回放项目 - 带进度条
 */
class ReplayItem extends FreeplayListItem
{
    public var songText:FlxText;
    public var infoText:FlxText;
    public var ratingText:FlxText;
    public var modTag:FlxText;
    public var progressBarBg:FlxSprite;
    public var progressBarFill:FlxSprite;
    public var progressText:FlxText;

    public var filename:String;
    public var dateStr:String;

    static inline var WIDTH:Int = FreeplayListItem.DEFAULT_WIDTH;
    static inline var HEIGHT:Int = FreeplayListItem.DEFAULT_HEIGHT;

    public function new(songName:String, accuracy:Float, modDir:String, filename:String, 
                         dateStr:String, difficulty:String, modFolder:String, 
                         rating:String, ratingFC:String, index:Int)
    {
        super(WIDTH, HEIGHT);

        this.filename = filename;
        this.dateStr = dateStr;

        // 配色沿用这个列表原来的蓝灰三点式
        setColors(0xFF888888, FlxColor.fromRGB(40, 55, 80), FlxColor.fromRGB(70, 95, 140),
            FlxColor.fromRGB(50, 70, 110), 0.3);

        // 歌曲名称
        var displayName = songName;
        if (displayName.length > 20) displayName = displayName.substr(0, 17) + "...";
        songText = new FlxText(15, 4, WIDTH - 120, displayName, 18);
        songText.antialiasing = ClientPrefs.data.antialiasing;
        songText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        songText.borderSize = 2;
        content.add(songText);

        // 评级
        var ratingDisplay = rating != null ? rating : "N/A";
        if (ratingFC != null && ratingFC != "N/A" && ratingFC != "")
        {
            ratingDisplay += ' ($ratingFC)';
        }
        ratingText = new FlxText(WIDTH - 180, 4, 110, ratingDisplay, 16);
        ratingText.antialiasing = ClientPrefs.data.antialiasing;
        ratingText.setFormat(Paths.font("vcr.ttf"), 16, getRatingColor(rating), RIGHT, OUTLINE, FlxColor.BLACK);
        ratingText.borderSize = 1;
        content.add(ratingText);

        // 日期和难度
        infoText = new FlxText(15, 26, WIDTH - 120, '$difficulty  •  $dateStr', 14);
        infoText.antialiasing = ClientPrefs.data.antialiasing;
        infoText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.GRAY, LEFT, OUTLINE, FlxColor.BLACK);
        infoText.borderSize = 1;
        content.add(infoText);

        // 完成度进度条
        progressBarBg = new FlxSprite(15, 48).makeGraphic(WIDTH - 130, 6, FlxColor.fromRGB(50, 50, 70));
        progressBarBg.alpha = 0.6;
        content.add(progressBarBg);

        var fillWidth = Std.int((WIDTH - 130) * Math.min(accuracy, 100) / 100);
        progressBarFill = new FlxSprite(15, 48).makeGraphic(fillWidth, 6, getAccuracyColor(accuracy));
        content.add(progressBarFill);

        // 准确率显示在进度条上
        var accStr:String = FlxMath.roundDecimal(accuracy, 2) + '%';
        progressText = new FlxText(15, 44, WIDTH - 130, accStr, 11);
        progressText.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        progressText.borderSize = 1;
        progressText.x = 15 + (WIDTH - 130) / 2 - progressText.width / 2;
        content.add(progressText);

        // MOD标签（内容包的 bucket 是多级路径，只印最后一段：content/VanillaSongs/PicoMix → PicoMix）
        if (modFolder != null && modFolder.length > 0 && modFolder != "" && modFolder != "base")
        {
            var displayMod = modFolder;
            var slash:Int = displayMod.lastIndexOf('/');
            if (slash >= 0) displayMod = displayMod.substring(slash + 1);
            if (displayMod.length > 8) displayMod = displayMod.substr(0, 6) + "..";
            modTag = new FlxText(WIDTH - 55, 30, 50, displayMod, 11);
            modTag.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.YELLOW, RIGHT, OUTLINE, FlxColor.BLACK);
            modTag.borderSize = 1;
            content.add(modTag);
        }

        setSelected(false);
    }

    public function updateSelection(isSelected:Bool)
    {
        setSelected(isSelected);
    }

    public function updateHover(isHovered:Bool)
    {
        setHovered(isHovered);
    }

    function getAccuracyColor(acc:Float):FlxColor
    {
        if (acc >= 95) return FlxColor.LIME;
        if (acc >= 90) return FlxColor.YELLOW;
        if (acc >= 80) return FlxColor.ORANGE;
        return FlxColor.RED;
    }

    function getRatingColor(rating:String):FlxColor
    {
        if (rating == null) return FlxColor.WHITE;
        var r = rating.toLowerCase();
        if (r == "p" || r == "marvelous") return FlxColor.fromRGB(255, 215, 0);
        if (r == "gp" || r == "sick") return FlxColor.CYAN;
        if (r == "ep" || r == "good") return FlxColor.LIME;
        if (r == "e") return FlxColor.fromRGB(150, 255, 100);
        if (r == "sg") return FlxColor.YELLOW;
        if (r == "g") return FlxColor.ORANGE;
        return FlxColor.WHITE;
    }
}