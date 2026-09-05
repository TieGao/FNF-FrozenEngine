package substates;

import backend.Replay;
import backend.MusicBeatState;
import backend.MouseMove;
import backend.Mods;
import backend.Song;
import backend.Paths;
import backend.CustomChartData;

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
    var parent:FreeplayState;

    // 当前歌曲信息
    var currentSongName:String;
    var currentModFolder:String;
    var currentDifficultyName:String;

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
    var totalItems:Int = 0;
    var cardScroller:MouseMove;

    static inline var PADDING_TOP:Int = 20;
    static inline var PADDING_BOTTOM:Int = 20;
    static inline var ITEM_SPACING:Int = 6;

    var noReplaysText:FlxText;
    var deleteConfirmText:FlxText;
    var waitingForDeleteConfirm:Bool = false;
    var replayToDelete:String = "";
    var headerText:FlxText;

    public function new(parent:FreeplayState, songName:String, modFolder:String, difficultyName:String)
    {
        super();
        this.parent = parent;
        this.currentSongName = songName;
        this.currentModFolder = modFolder;
        this.currentDifficultyName = difficultyName;
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

        // 子标题 - 显示模组和当前难度
        var subText:String = 'Mod: ' + (currentModFolder != null && currentModFolder.length > 0 ? currentModFolder : 'Base Game');
        subText += '  |  Current: $currentDifficultyName';
        var subHeader = new FlxText(bgList.x + 10, bgList.y + 32, panelWidth - 20, subText, 14);
        subHeader.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
        subHeader.borderSize = 1;
        subHeader.antialiasing = ClientPrefs.data.antialiasing;
        add(subHeader);

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
        selectedReplayName = new FlxText(FlxG.width * 0.2 + 20, 130, 300, "Select a Replay", 28);
        selectedReplayName.antialiasing = ClientPrefs.data.antialiasing;
        selectedReplayName.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        selectedReplayName.borderSize = 2;
        selectedReplayName.scrollFactor.set();
        add(selectedReplayName);

        selectedReplayInfo = new FlxText(FlxG.width * 0.2 + 20, 175, 300, "", 18);
        selectedReplayInfo.antialiasing = ClientPrefs.data.antialiasing;
        selectedReplayInfo.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
        selectedReplayInfo.borderSize = 1;
        selectedReplayInfo.scrollFactor.set();
        add(selectedReplayInfo);

        selectedReplayAccuracy = new FlxText(FlxG.width * 0.2 + 20, 215, 300, "", 32);
        selectedReplayAccuracy.antialiasing = ClientPrefs.data.antialiasing;
        selectedReplayAccuracy.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.CYAN, CENTER, OUTLINE, FlxColor.BLACK);
        selectedReplayAccuracy.borderSize = 2;
        selectedReplayAccuracy.scrollFactor.set();
        add(selectedReplayAccuracy);

        // 操作提示
        var controlsText:FlxText = new FlxText(FlxG.width * 0.2 + 20, FlxG.height - 70, FlxG.width,
            "↑/↓: Navigate  |  ENTER: Load  |  F: Delete  |  ESC: Close", 16);
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
        selectedReplayName.x = startX + 50;
        selectedReplayInfo.x = startX + 50;
        selectedReplayAccuracy.x = startX + 50;

        for (item in replaysGroup)
        {
            item.x = startX + 10;
        }

        FlxTween.tween(bgList, {x: targetX}, 0.6, {ease: FlxEase.circOut});
        FlxTween.tween(headerText, {x: targetX + 10}, 0.6, {ease: FlxEase.circOut});
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

    function loadReplays()
    {
        #if sys
        replayFiles = [];

        // 如果模组文件夹为空，使用 "base" 作为默认
        var modFolder = currentModFolder != null && currentModFolder.length > 0 ? currentModFolder : "base";
        var replayDir = "assets/replays/" + modFolder + "/";
        
        if (!FileSystem.exists(replayDir))
        {
            trace('Replay directory does not exist: $replayDir');
            return;
        }

        var files = FileSystem.readDirectory(replayDir);
        for (file in files)
        {
            if (!file.endsWith(".kadeReplay")) continue;
            
            try
            {
                var filePath = replayDir + file;
                var fileContent = File.getContent(filePath);
                var json:Dynamic = Json.parse(fileContent);
                
                if (json == null) continue;
                
                // 检查歌曲名是否匹配（不区分大小写）
                var replaySongName = json.songName != null ? json.songName : "";
                if (replaySongName.toLowerCase() != currentSongName.toLowerCase()) continue;
                
                var entry:ReplayEntry = {
                    filename: file,
                    modFolder: modFolder,
                    songName: replaySongName,
                    difficultyName: json.difficultyName != null ? json.difficultyName : 
                        (json.songDiff != null ? Difficulty.getString(Std.int(json.songDiff)) : "Normal"),
                    accuracy: json.accuracy != null ? Std.parseFloat(Std.string(json.accuracy)) : 0,
                    score: json.score != null ? Std.parseInt(Std.string(json.score)) : 0,
                    misses: json.misses != null ? Std.parseInt(Std.string(json.misses)) : 0,
                    rating: json.rating != null ? json.rating : "N/A",
                    ratingFC: json.ratingFC != null ? json.ratingFC : "N/A",
                    modDirectory: json.modDirectory != null ? json.modDirectory : modFolder,
                    isDownscroll: json.isDownscroll == true,
                    noteSpeed: json.noteSpeed != null ? Std.parseFloat(Std.string(json.noteSpeed)) : 1.5,
                    rawJson: json,
                    dateStr: extractDateFromReplay(json),
                    fullPath: filePath
                };
                
                replayFiles.push(entry);
            }
            catch(e:Dynamic)
            {
                trace('Error parsing replay $file: $e');
            }
        }
        
        // 按日期排序（最新在前）
        replayFiles.sort(function(a, b):Int {
            return Reflect.compare(b.dateStr, a.dateStr);
        });
        #end
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

    function rebuildItems()
    {
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
    }

    function updateItemsPosition()
    {
        var panelY:Float = bgList.y + PADDING_TOP + 55;
        
        for (i in 0...replaysGroup.members.length)
        {
            var item = replaysGroup.members[i];
            var baseY:Float = panelY + i * (itemHeight + ITEM_SPACING);
            var offsetY:Float = -scrollPos;
            
            item.y = baseY + offsetY;
            
            var isVisible = item.y + itemHeight > bgList.y + 55 && item.y < bgList.y + bgList.height;
            item.visible = isVisible;
            item.active = isVisible;
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (shouldClose)
        {
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

        // 鼠标支持
        for (i in 0...replaysGroup.members.length)
        {
            var item = replaysGroup.members[i];
            if (item.visible && FlxG.mouse.overlaps(item) && FlxG.mouse.justPressed)
            {
                curSelected = i;
                scrollToItemMiddle(i);
                updateSelection();
                loadSelectedReplay();
                break;
            }
        }

        // 悬停效果
        for (i in 0...replaysGroup.members.length)
        {
            var item = replaysGroup.members[i];
            if (item.visible && FlxG.mouse.overlaps(item))
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
        var mouseX = FlxG.mouse.screenX;
        var mouseY = FlxG.mouse.screenY;
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
            selectedReplayInfo.text = entry.difficultyName + '  •  ' + entry.dateStr;
            
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
        
        var rep:Replay = Replay.LoadReplay(filePath);
        if (rep == null || !rep.isValid())
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Invalid replay file!");
            return;
        }
        
        #if MODS_ALLOWED
        if (rep.replay.modDirectory != null && rep.replay.modDirectory.length > 0)
            Mods.currentModDirectory = rep.replay.modDirectory;
        #end
        
        PlayState.rep = rep;
        PlayState.loadRep = true;
        PlayState.inReplay = true;
        PlayState.replayFileName = filePath;
        
        var difficultyID:Int = 1;
        if (rep.replay.difficultyName != null)
        {
            var diffLower = rep.replay.difficultyName.toLowerCase();
            if (diffLower.indexOf('easy') >= 0) difficultyID = 0;
            else if (diffLower.indexOf('normal') >= 0 || diffLower.indexOf('standard') >= 0) difficultyID = 1;
            else if (diffLower.indexOf('hard') >= 0) difficultyID = 2;
            else difficultyID = rep.replay.songDiff;
        }
        else difficultyID = rep.replay.songDiff;
        
        PlayState.storyDifficulty = difficultyID;
        PlayState.storyWeek = 0;
        
        var songName:String = rep.replay.songName;
        var difficultyName:String = rep.replay.difficultyName;
        
        try
        {
            var diffSuffix = '';
            if (difficultyName != null)
            {
                var lowerDiff = difficultyName.toLowerCase();
                if (lowerDiff != 'normal' && lowerDiff != 'standard')
                    diffSuffix = '-' + lowerDiff;
            }
            var jsonToLoad = songName + diffSuffix;
            trace('Loading JSON: $jsonToLoad');
            if (rep.replay.chartCategory != null && rep.replay.chartCategory.length > 0)
            {
                Paths.currentChartCategory = rep.replay.chartCategory;
                Paths.currentChartDirectory = rep.replay.chartDirectory != null && rep.replay.chartDirectory.length > 0
                    ? rep.replay.chartDirectory : rep.replay.chartPath;
                Paths.currentChartHasVSliceMetadata = rep.replay.chartHasVSliceMetadata;
                Paths.currentChartAudioSuffix = rep.replay.chartAudioSuffix;
                PlayState.chartCategory = Paths.currentChartCategory;
                PlayState.chartDirectory = Paths.currentChartDirectory;
                PlayState.chartHasVSliceMetadata = Paths.currentChartHasVSliceMetadata;
                PlayState.chartAudioSuffix = Paths.currentChartAudioSuffix;

                var customSongs = CustomChartData.load(Paths.currentChartCategory);
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

                Paths.currentChartDirectory = customSong.directory;
                PlayState.SONG = cast CustomChartData.loadChart(customSong, difficultyName);
            }
            else
            {
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
}

/**
 * 回放项目 - 带进度条
 */
class ReplayItem extends FlxSpriteGroup
{
    public var selectBg:FlxFilteredSprite;
    public var songText:FlxText;
    public var infoText:FlxText;
    public var ratingText:FlxText;
    public var modTag:FlxText;
    public var progressBarBg:FlxSprite;
    public var progressBarFill:FlxSprite;
    public var progressText:FlxText;

    public var filename:String;
    public var dateStr:String;
    public var isSelected:Bool = false;
    public var isHovered:Bool = false;

    static inline var WIDTH:Int = 450;
    static inline var HEIGHT:Int = 80;

    public function new(songName:String, accuracy:Float, modDir:String, filename:String, 
                         dateStr:String, difficulty:String, modFolder:String, 
                         rating:String, ratingFC:String, index:Int)
    {
        super();

        this.filename = filename;
        this.dateStr = dateStr;

        // 背景
        selectBg = new FlxFilteredSprite();
        selectBg.makeGraphic(WIDTH, HEIGHT, FlxColor.WHITE);
        selectBg.filters = [new BlurFilter(30, 30, BitmapFilterQuality.HIGH)];
        selectBg.color = 0xFF888888;
        selectBg.alpha = 0.3;
        add(selectBg);

        // 歌曲名称
        var displayName = songName;
        if (displayName.length > 20) displayName = displayName.substr(0, 17) + "...";
        songText = new FlxText(15, 4, WIDTH - 120, displayName, 18);
        songText.antialiasing = ClientPrefs.data.antialiasing;
        songText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        songText.borderSize = 2;
        add(songText);

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
        add(ratingText);

        // 日期和难度
        infoText = new FlxText(15, 26, WIDTH - 120, '$difficulty  •  $dateStr', 14);
        infoText.antialiasing = ClientPrefs.data.antialiasing;
        infoText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.GRAY, LEFT, OUTLINE, FlxColor.BLACK);
        infoText.borderSize = 1;
        add(infoText);

        // 完成度进度条
        progressBarBg = new FlxSprite(15, 48).makeGraphic(WIDTH - 130, 6, FlxColor.fromRGB(50, 50, 70));
        progressBarBg.alpha = 0.6;
        add(progressBarBg);

        var fillWidth = Std.int((WIDTH - 130) * Math.min(accuracy, 100) / 100);
        progressBarFill = new FlxSprite(15, 48).makeGraphic(fillWidth, 6, getAccuracyColor(accuracy));
        add(progressBarFill);

        // 准确率显示在进度条上
        var accStr:String = FlxMath.roundDecimal(accuracy, 2) + '%';
        progressText = new FlxText(15, 44, WIDTH - 130, accStr, 11);
        progressText.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        progressText.borderSize = 1;
        progressText.x = 15 + (WIDTH - 130) / 2 - progressText.width / 2;
        add(progressText);

        // MOD标签
        if (modFolder != null && modFolder.length > 0 && modFolder != "" && modFolder != "base")
        {
            var displayMod = modFolder;
            if (displayMod.length > 8) displayMod = displayMod.substr(0, 6) + "..";
            modTag = new FlxText(WIDTH - 55, 30, 50, displayMod, 11);
            modTag.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.YELLOW, RIGHT, OUTLINE, FlxColor.BLACK);
            modTag.borderSize = 1;
            add(modTag);
        }

        updateSelection(false);
    }

    public function updateSelection(isSelected:Bool)
    {
        this.isSelected = isSelected;
        if (this.isSelected)
        {
            selectBg.color = FlxColor.fromRGB(50, 70, 110);
            selectBg.alpha = 0.9;
        }
        else if (isHovered)
        {
            selectBg.color = FlxColor.fromRGB(40, 55, 80);
            selectBg.alpha = 0.6;
        }
        else
        {
            selectBg.color = 0xFF888888;
            selectBg.alpha = 0.3;
        }
    }

    public function updateHover(isHovered:Bool)
    {
        this.isHovered = isHovered;
        if (!isSelected)
        {
            if (isHovered)
            {
                selectBg.color = FlxColor.fromRGB(40, 55, 80);
                selectBg.alpha = 0.6;
            }
            else
            {
                selectBg.color = 0xFF888888;
                selectBg.alpha = 0.3;
            }
        }
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