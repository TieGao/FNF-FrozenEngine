package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import backend.Replay;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import backend.Song;
import backend.Difficulty;
import backend.ClientPrefs;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

// 卡片类 - 使用 FlxSpriteGroup
class ReplayCard extends FlxSpriteGroup
{
    public var bg:FlxSprite;
    public var topBorder:FlxSprite;
    public var bottomBorder:FlxSprite;
    public var leftBorder:FlxSprite;
    public var rightBorder:FlxSprite;
    public var songText:FlxText;
    public var infoText:FlxText;
    public var scoreText:FlxText;
    public var accuracyFill:FlxSprite;
    public var accuracyBG:FlxSprite;
    public var modTag:FlxText;
    
    public var replayData:Dynamic;
    public var index:Int;
    public var selected:Bool = false;
    public var hovered:Bool = false;
    
    public function new(x:Float, y:Float, width:Float, height:Float, data:Dynamic, idx:Int)
    {
        super(x, y);
        this.index = idx;
        this.replayData = data;
        
        // 背景
        bg = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), FlxColor.BLACK);
        bg.alpha = 0.7;
        add(bg);
        
        // 边框元素（初始隐藏）
        topBorder = new FlxSprite(0, 0).makeGraphic(Std.int(width), 2, FlxColor.CYAN);
        topBorder.visible = false;
        add(topBorder);
        
        bottomBorder = new FlxSprite(0, Std.int(height) - 2).makeGraphic(Std.int(width), 2, FlxColor.CYAN);
        bottomBorder.visible = false;
        add(bottomBorder);
        
        leftBorder = new FlxSprite(0, 0).makeGraphic(2, Std.int(height), FlxColor.CYAN);
        leftBorder.visible = false;
        add(leftBorder);
        
        rightBorder = new FlxSprite(Std.int(width) - 2, 0).makeGraphic(2, Std.int(height), FlxColor.CYAN);
        rightBorder.visible = false;
        add(rightBorder);
        
        // 歌曲名
        var songName:String = data.songName != null ? data.songName : "Unknown Song";
        songText = new FlxText(10, 10, width - 20, songName, 20);
        songText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        add(songText);
        
        // 难度和日期
        var diffColor = getDifficultyColor(data.difficultyName);
        var dateStr = formatDate(data.timestamp);
        
        infoText = new FlxText(10, 35, width - 20, 
            '${data.difficultyName} • ${dateStr}', 16);
        infoText.setFormat(Paths.font("vcr.ttf"), 16, diffColor, LEFT);
        add(infoText);
        
        // 准确度背景条
        accuracyBG = new FlxSprite(10, 55).makeGraphic(Std.int(width - 20), 6, FlxColor.GRAY);
        add(accuracyBG);
        
        // 准确度填充条
        var accuracy:Float = data.accuracy != null ? data.accuracy : 0;
        var fillWidth = Std.int((width - 20) * Math.min(accuracy, 100) / 100);
        accuracyFill = new FlxSprite(10, 55).makeGraphic(fillWidth, 6, getAccuracyColor(accuracy));
        add(accuracyFill);
        
        // 分数和准确度文本
        var scoreStr = formatNumber(data.score);
        var accuracyStr = formatAccuracy(accuracy);
        scoreText = new FlxText(10, 65, width - 20, 
            'Score: $scoreStr • Acc: $accuracyStr%', 16);
        scoreText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
        add(scoreText);
        
        // 模组标记
        if (data.modDirectory != null && data.modDirectory.length > 0 && data.modDirectory != "")
        {
            modTag = new FlxText(width - 100, 10, 90, "MOD", 14);
            modTag.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, RIGHT);
            add(modTag);
        }
        
        updateSelection(false);
        updateHover(false);
    }
    
    public function updateSelection(isSelected:Bool)
    {
        this.selected = isSelected;
        updateVisuals();
    }
    
    public function updateHover(isHovered:Bool)
    {
        this.hovered = isHovered;
        updateVisuals();
    }
    
    function updateVisuals()
    {
        if (selected)
        {
            // 选中状态：深蓝色背景 + 青色边框
            bg.color = FlxColor.fromRGB(60, 60, 100);
            topBorder.visible = true;
            bottomBorder.visible = true;
            leftBorder.visible = true;
            rightBorder.visible = true;
            topBorder.color = FlxColor.CYAN;
            bottomBorder.color = FlxColor.CYAN;
            leftBorder.color = FlxColor.CYAN;
            rightBorder.color = FlxColor.CYAN;
        }
        else if (hovered)
        {
            // 悬停状态：稍浅的蓝色背景 + 黄色边框
            bg.color = FlxColor.fromRGB(80, 80, 120);
            topBorder.visible = true;
            bottomBorder.visible = true;
            leftBorder.visible = true;
            rightBorder.visible = true;
            topBorder.color = FlxColor.YELLOW;
            bottomBorder.color = FlxColor.YELLOW;
            leftBorder.color = FlxColor.YELLOW;
            rightBorder.color = FlxColor.YELLOW;
        }
        else
        {
            // 普通状态：黑色背景，无边框
            bg.color = FlxColor.BLACK;
            topBorder.visible = false;
            bottomBorder.visible = false;
            leftBorder.visible = false;
            rightBorder.visible = false;
        }
    }
    
    function getDifficultyColor(diff:String):FlxColor
    {
        if (diff == null) return FlxColor.WHITE;
        var diffLower = diff.toLowerCase();
        if (diffLower.indexOf("easy") >= 0) return FlxColor.LIME;
        if (diffLower.indexOf("normal") >= 0) return FlxColor.CYAN;
        if (diffLower.indexOf("hard") >= 0) return FlxColor.ORANGE;
        if (diffLower.indexOf("expert") >= 0) return FlxColor.RED;
        if (diffLower.indexOf("insane") >= 0) return FlxColor.PURPLE;
        return FlxColor.WHITE;
    }
    
    function getAccuracyColor(acc:Float):FlxColor
    {
        if (acc >= 95) return FlxColor.LIME;
        if (acc >= 90) return FlxColor.YELLOW;
        if (acc >= 80) return FlxColor.ORANGE;
        return FlxColor.RED;
    }
    
    function formatDate(timestamp:Dynamic):String
    {
        try
        {
            if (timestamp == null) return "Unknown";
            var dateStr = Std.string(timestamp);
            var datePattern = ~/(\d{4})-(\d{2})-(\d{2})/;
            if (datePattern.match(dateStr))
            {
                return datePattern.matched(3) + "/" + datePattern.matched(2) + "/" + datePattern.matched(1);
            }
            if (Std.isOfType(timestamp, Date))
            {
                var date:Date = cast timestamp;
                return '${date.getMonth()+1}/${date.getDate()}/${date.getFullYear()}';
            }
            return dateStr.length > 10 ? dateStr.substr(0, 10) : dateStr;
        }
        catch(e:Dynamic)
        {
            return "Unknown";
        }
    }
    
    function formatNumber(num:Dynamic):String
    {
        if (num == null) return "0";
        var n:Float = Std.parseFloat(Std.string(num));
        if (Math.isNaN(n)) return "0";
        if (n >= 1000000) return Std.int(n / 1000000) + "M";
        if (n >= 1000) return Std.int(n / 1000) + "K";
        return Std.string(Std.int(n));
    }
    
    function formatAccuracy(acc:Float):String
    {
        if (Math.isNaN(acc)) return "0.00";
        var rounded = Math.round(acc * 100) / 100;
        var str = Std.string(rounded);
        var dotIndex = str.indexOf(".");
        if (dotIndex == -1) {
            return str + ".00";
        } else {
            var decimalPlaces = str.length - dotIndex - 1;
            if (decimalPlaces == 1) {
                return str + "0";
            } else if (decimalPlaces == 0) {
                return str + ".00";
            }
        }
        return str;
    }
}

// 主状态类
class LoadReplayState extends MusicBeatState
{
    var grpReplays:FlxTypedGroup<ReplayCard>;
    var replays:Array<String> = [];
    var curSelected:Int = 0;
    
    var bg:FlxSprite;
    var titleText:FlxText;
    var noReplaysText:FlxText;
    var controlsText:FlxText;
    var statsText:FlxText;
    var pageText:FlxText;
    
    var currentPage:Int = 0;
    var itemsPerPage:Int = 4;
    var totalPages:Int = 1;
    
    var waitingForDeleteConfirm:Bool = false;
    var deleteConfirmText:FlxText;
    var replayToDelete:String = "";
    
    // 鼠标控制相关变量
    var lastMouseY:Float = 0;
    var mouseDragStartY:Float = 0;
    var isDragging:Bool = false;
    var dragThreshold:Float = 5;
    var wheelAccumulator:Float = 0;
    var wheelThreshold:Float = 0.3;
    var hoveredCardIndex:Int = -1;
    
    override function create()
    {
        bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF1A1A2E;
        bg.setGraphicSize(Std.int(bg.width * 1.1));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);
        
        titleText = new FlxText(0, 20, FlxG.width, "REPLAY LIBRARY", 32);
        titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 3;
        add(titleText);
        
        grpReplays = new FlxTypedGroup<ReplayCard>();
        add(grpReplays);
        
        statsText = new FlxText(20, 70, FlxG.width - 40, "", 18);
        statsText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.CYAN, LEFT);
        add(statsText);
        
        pageText = new FlxText(20, FlxG.height - 70, FlxG.width - 40, "", 18);
        pageText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.YELLOW, LEFT);
        add(pageText);
        
        controlsText = new FlxText(0, FlxG.height - 40, FlxG.width, 
            "ENTER/Click: Load | BACK/RightClick: Exit | F: Delete | ←→: Page | Scroll: Navigate", 16);
        controlsText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        controlsText.borderSize = 2;
        add(controlsText);
        
        noReplaysText = new FlxText(0, FlxG.height / 2 - 30, FlxG.width, 
            "No Replays Found", 24);
        noReplaysText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        noReplaysText.borderSize = 2;
        noReplaysText.visible = false;
        add(noReplaysText);
        
        deleteConfirmText = new FlxText(0, FlxG.height / 2 - 20, FlxG.width, 
            "", 24);
        deleteConfirmText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        deleteConfirmText.borderSize = 2;
        deleteConfirmText.visible = false;
        add(deleteConfirmText);
        
        lastMouseY = FlxG.mouse.screenY;
        mouseDragStartY = FlxG.mouse.screenY;
        
        loadReplays();
        updateDisplay();
        
        super.create();
    }
    
    function loadReplays()
    {
        #if sys
        replays = [];
        
        var replayDir = "assets/replays/";
        if (FileSystem.exists(replayDir)) {
            var files = FileSystem.readDirectory(replayDir);
            files.sort(function(a:String, b:String):Int {
                try {
                    var aPath = replayDir + a;
                    var bPath = replayDir + b;
                    var aStat = FileSystem.stat(aPath);
                    var bStat = FileSystem.stat(bPath);
                    return Std.int(bStat.mtime.getTime() - aStat.mtime.getTime());
                } catch(e:Dynamic) {
                    return 0;
                }
            });
            
            for (file in files) {
                if (file.endsWith(".kadeReplay")) {
                    replays.push(file);
                }
            }
        }
        
        totalPages = Math.ceil(replays.length / itemsPerPage);
        if (totalPages == 0) totalPages = 1;
        #end
    }
    
    function updateDisplay()
    {
        grpReplays.clear();
        hoveredCardIndex = -1;
        
        if (replays.length == 0)
        {
            noReplaysText.visible = true;
            statsText.text = "No replays found in assets/replays/";
            pageText.text = "";
            return;
        }
        
        noReplaysText.visible = false;
        
        var startIndex:Int = currentPage * itemsPerPage;
        var endIndex:Int = Math.floor(Math.min(startIndex + itemsPerPage, replays.length));
        
        statsText.text = 'Total Replays: ${replays.length}';
        pageText.text = 'Page ${currentPage + 1}/${totalPages} (${startIndex + 1}-${endIndex})';
        
        var cardWidth:Int = Std.int(FlxG.width * 0.9);
        var cardHeight:Int = 90;
        var cardSpacing:Int = 15;
        var startX:Int = Std.int((FlxG.width - cardWidth) / 2);
        var startY:Int = 120;
        
        for (i in 0...(endIndex - startIndex))
        {
            var replayIndex:Int = startIndex + i;
            var filename = replays[replayIndex];
            
            try
            {
                var filePath = "assets/replays/" + filename;
                var fileContent = File.getContent(filePath);
                var json:Dynamic = Json.parse(fileContent);
                
                if (json.songName == null) json.songName = "Unknown Song";
                if (json.difficultyName == null) {
                    if (json.songDiff != null) {
                        // 优先使用回放中记录的难度名称
                        json.difficultyName = Difficulty.getString(Std.int(json.songDiff));
                    } else {
                        json.difficultyName = "Normal";
                    }
                }
                if (json.accuracy == null) json.accuracy = 0;
                if (json.score == null) json.score = 0;
                if (json.timestamp == null) json.timestamp = Date.now();
                if (json.modDirectory == null) json.modDirectory = "";
                
                var card = new ReplayCard(
                    startX,
                    startY + i * (cardHeight + cardSpacing),
                    cardWidth,
                    cardHeight,
                    json,
                    replayIndex
                );
                
                card.updateSelection(replayIndex == curSelected);
                grpReplays.add(card);
            }
            catch(e:Dynamic)
            {
                trace('Error loading replay ${filename}: $e');
                var errorBg = new FlxSprite(startX, startY + i * (cardHeight + cardSpacing));
                errorBg.makeGraphic(cardWidth, cardHeight, FlxColor.RED);
                errorBg.alpha = 0.3;
                add(errorBg);
                
                var errorText = new FlxText(startX + 10, startY + i * (cardHeight + cardSpacing) + 10, 
                    cardWidth - 20, "Corrupted: " + filename, 16);
                errorText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
                add(errorText);
            }
        }
        
        checkMouseHover();
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (waitingForDeleteConfirm)
        {
            if (FlxG.keys.justPressed.Y)
            {
                confirmDelete();
            }
            else if (FlxG.keys.justPressed.N || FlxG.keys.justPressed.ESCAPE)
            {
                cancelDelete();
            }
            return;
        }
        
        handleMouseWheel(elapsed);
        checkMouseHover();
        handleMouseDrag(elapsed);
        handleMouseClicks();
        handleKeyboardControls();
    }
    
    function handleMouseWheel(elapsed:Float)
    {
        wheelAccumulator += FlxG.mouse.wheel;
        
        if (Math.abs(wheelAccumulator) >= wheelThreshold) {
            var direction = wheelAccumulator > 0 ? -1 : 1;
            wheelAccumulator = 0;
            
            if (replays.length > 0) {
                changeSelection(direction);
            }
        }
        
        wheelAccumulator *= Math.pow(0.5, elapsed * 60);
    }
    
    function checkMouseHover()
    {
        if (replays.length == 0 || grpReplays.members.length == 0) return;
        
        var mouseX = FlxG.mouse.screenX;
        var mouseY = FlxG.mouse.screenY;
        var newHoverIndex = -1;
        
        for (i in 0...grpReplays.members.length) {
            var card = grpReplays.members[i];
            if (card != null && card.exists && card.visible) {
                var cardScreenX = card.x;
                var cardScreenY = card.y;
                
                if (mouseX >= cardScreenX && 
                    mouseX <= cardScreenX + card.width &&
                    mouseY >= cardScreenY && 
                    mouseY <= cardScreenY + card.height) {
                    
                    newHoverIndex = card.index;
                    break;
                }
            }
        }
        
        if (newHoverIndex != hoveredCardIndex) {
            var oldHoverIndex = hoveredCardIndex;
            hoveredCardIndex = newHoverIndex;
            
            // 更新卡片悬停状态
            for (card in grpReplays.members) {
                if (card != null) {
                    if (card.index == oldHoverIndex) {
                        card.updateHover(false);
                    }
                    if (card.index == hoveredCardIndex) {
                        card.updateHover(true);
                    }
                }
            }
            
            // 如果鼠标悬停在卡片上，且不是当前选中的卡片，则选中它
            if (hoveredCardIndex >= 0 && hoveredCardIndex != curSelected) {
                changeSelectionTo(hoveredCardIndex);
            }
        }
    }
    
    function handleMouseDrag(elapsed:Float)
    {
        var currentMouseY = FlxG.mouse.screenY;
        var deltaY = currentMouseY - lastMouseY;
        
        if (FlxG.mouse.pressed) {
            if (!isDragging) {
                if (Math.abs(currentMouseY - mouseDragStartY) > dragThreshold) {
                    isDragging = true;
                }
            } else {
                if (Math.abs(deltaY) > 1 && replays.length > 0) {
                    var direction = deltaY > 0 ? 1 : -1;
                    if (Math.random() < 0.2) {
                        changeSelection(direction);
                    }
                }
            }
        } else {
            if (isDragging) {
                isDragging = false;
            }
            mouseDragStartY = currentMouseY;
        }
        
        lastMouseY = currentMouseY;
    }
    
    function handleMouseClicks()
    {
        if (FlxG.mouse.justPressed) {
            if (hoveredCardIndex >= 0 && hoveredCardIndex < replays.length) {
                if (hoveredCardIndex != curSelected) {
                    changeSelectionTo(hoveredCardIndex);
                }
                loadReplay(replays[curSelected]);
            }
        }
        
        if (FlxG.mouse.justPressedRight) {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new MainMenuState());
        }
    }
    
    function handleKeyboardControls()
    {
        if (controls.BACK)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new MainMenuState());
            return;
        }
        
        if (replays.length > 0)
        {
            if (controls.UI_UP_P)
            {
                changeSelection(-1);
            }
            
            if (controls.UI_DOWN_P)
            {
                changeSelection(1);
            }
            
            if (controls.UI_LEFT_P)
            {
                changePage(-1);
            }
            
            if (controls.UI_RIGHT_P)
            {
                changePage(1);
            }
            
            if (controls.ACCEPT)
            {
                if (curSelected >= 0 && curSelected < replays.length)
                {
                    loadReplay(replays[curSelected]);
                }
            }
            
            if (FlxG.keys.justPressed.F)
            {
                if (curSelected >= 0 && curSelected < replays.length)
                {
                    var selectedFile = replays[curSelected];
                    promptDelete(selectedFile);
                }
            }
        }
    }
    
    function changeSelectionTo(index:Int)
    {
        if (index < 0) index = 0;
        if (index >= replays.length) index = replays.length - 1;
        
        var change = index - curSelected;
        if (change != 0) {
            changeSelection(change);
        }
    }
    
    function changeSelection(change:Int)
    {
        if (replays.length == 0) return;
        
        var oldSelected = curSelected;
        curSelected += change;
        
        if (curSelected < 0)
            curSelected = replays.length - 1;
        if (curSelected >= replays.length)
            curSelected = 0;
        
        var startIndex = currentPage * itemsPerPage;
        var endIndex = Math.min(startIndex + itemsPerPage, replays.length);
        
        if (curSelected < startIndex)
        {
            currentPage = Math.floor(curSelected / itemsPerPage);
            updateDisplay();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
        else if (curSelected >= endIndex)
        {
            currentPage = Math.floor(curSelected / itemsPerPage);
            updateDisplay();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
        else
        {
            // 更新选中状态
            for (card in grpReplays)
            {
                if (card.index == oldSelected)
                {
                    card.updateSelection(false);
                    // 如果该卡片是悬停状态，恢复悬停显示
                    if (card.index == hoveredCardIndex) {
                        card.updateHover(true);
                    }
                }
                if (card.index == curSelected)
                {
                    card.updateSelection(true);
                }
            }
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
    }
    
    function changePage(change:Int)
    {
        if (totalPages <= 1) return;
        
        var oldPage = currentPage;
        currentPage += change;
        
        if (currentPage < 0)
            currentPage = totalPages - 1;
        if (currentPage >= totalPages)
            currentPage = 0;
            
        if (currentPage != oldPage)
        {
            updateDisplay();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
    }
    
    function loadReplay(filename:String):Void
    {
        trace('Loading replay: $filename');
        
        var rep:Replay = Replay.LoadReplay(filename);
        
        if (rep != null && rep.isValid())
        {
            trace('Successfully loaded replay: ${rep.replay.songName}');
            trace('Difficulty ID: ${rep.replay.songDiff}');
            trace('Difficulty Name: ${rep.replay.difficultyName}');
            trace('Mod Directory: ${rep.replay.modDirectory}');
            
            // 设置模组目录
            var modPath:String = rep.replay.modDirectory;
            #if MODS_ALLOWED
            if (modPath != null && modPath.length > 0 && modPath != "null")
            {
                Mods.currentModDirectory = modPath;
                trace('Set mod directory to: $modPath');
            }
            else
            {
                Mods.currentModDirectory = "";
                trace('No mod directory specified');
            }
            #end
            
            // 设置到 PlayState
            PlayState.rep = rep;
            PlayState.loadRep = true;
            PlayState.storyDifficulty = rep.replay.songDiff;
            
            // 加载歌曲 - 支持自定义难度名称
            try
            {
                var songName:String = rep.replay.songName;
                var recordedDifficultyName:String = rep.replay.difficultyName;
                
                trace('Loading song: $songName');
                trace('Recorded difficulty name: $recordedDifficultyName');
                
                var loadedSong:SwagSong = null;
                
                // 方法1: 直接使用回放中记录的难度ID
                try {
                    var difficultyPath = Difficulty.getFilePath(rep.replay.songDiff);
                    trace('Trying with difficulty ID path: $difficultyPath');
                    loadedSong = Song.loadFromJson(songName + difficultyPath, songName);
                    if (loadedSong != null) {
                        trace('Successfully loaded using difficulty ID');
                    }
                } catch(e:Dynamic) {
                    trace('Failed to load using difficulty ID: $e');
                }
                
                // 方法2: 如果标准难度加载失败，尝试自定义难度名称
                if (loadedSong == null && recordedDifficultyName != null) {
                    // 尝试加载自定义难度文件
                    var customDifficultyPath = "-" + recordedDifficultyName.toLowerCase();
                    trace('Trying custom difficulty path: $customDifficultyPath');
                    
                    try {
                        loadedSong = Song.loadFromJson(songName + customDifficultyPath, songName);
                        if (loadedSong != null) {
                            trace('Successfully loaded using custom difficulty name');
                        }
                    } catch(e:Dynamic) {
                        trace('Failed to load custom difficulty: $e');
                    }
                }
                
                // 方法3: 尝试常见的难度后缀
                if (loadedSong == null) {
                    var commonDifficulties = ["-easy", "", "-hard", "-insane"];
                    for (diff in commonDifficulties) {
                        try {
                            loadedSong = Song.loadFromJson(songName + diff, songName);
                            if (loadedSong != null) {
                                trace('Successfully loaded using common difficulty: $diff');
                                break;
                            }
                        } catch(e:Dynamic) {
                            trace('Failed to load $diff: $e');
                        }
                    }
                }
                
                if (loadedSong != null)
                {
                    // 设置游戏状态
                    PlayState.isStoryMode = false;
                    PlayState.SONG = loadedSong;
                    
                    // 设置下滚选项
                    ClientPrefs.data.downScroll = rep.replay.isDownscroll;
                    
                    // 切换到PlayState
                    FlxG.sound.music.stop();
                    LoadingState.loadAndSwitchState(new PlayState());
                    return;
                }
                else
                {
                    trace('Failed to load any difficulty for song: $songName');
                }
            }
            catch(e:Dynamic)
            {
                trace('Error loading song: $e');
            }
            
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Failed to load replay song!\nChart file may be missing or corrupted.");
        }
        else
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Invalid replay file!");
        }
    }
    
    function showError(message:String):Void
    {
        var errorMsg:FlxText = new FlxText(0, FlxG.height / 2 - 30, FlxG.width, 
            message, 20);
        errorMsg.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
        errorMsg.borderSize = 2;
        errorMsg.screenCenter(X);
        add(errorMsg);
        
        new FlxTimer().start(3, function(tmr:FlxTimer) {
            remove(errorMsg);
            errorMsg.destroy();
        });
    }
    
    function promptDelete(filename:String):Void
    {
        replayToDelete = filename;
        waitingForDeleteConfirm = true;
        
        var displayName = filename;
        if (displayName.length > 30) {
            displayName = displayName.substr(0, 27) + "...";
        }
        
        deleteConfirmText.text = 'Delete "${displayName}"? (Y/N)';
        deleteConfirmText.screenCenter(X);
        deleteConfirmText.visible = true;
        
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }
    
    function confirmDelete():Void
    {
        #if sys
        var replayPath = "assets/replays/" + replayToDelete;
        if (FileSystem.exists(replayPath))
        {
            FileSystem.deleteFile(replayPath);
            trace('Deleted replay: $replayToDelete');
            
            loadReplays();
            curSelected = 0;
            currentPage = 0;
            updateDisplay();
            
            FlxG.sound.play(Paths.sound('cancelMenu'));
        }
        #end
        
        cancelDelete();
    }
    
    function cancelDelete():Void
    {
        waitingForDeleteConfirm = false;
        replayToDelete = "";
        deleteConfirmText.visible = false;
        FlxG.sound.play(Paths.sound('cancelMenu'));
    }
}