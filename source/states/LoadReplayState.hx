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
import flixel.input.mouse.FlxMouseEventManager;
import flixel.input.mouse.FlxMouseButton;

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
    public var filename:String;
    public var index:Int;
    public var selected:Bool = false;
    public var hovered:Bool = false;
    
    // 回调函数
    public var onClick:Void->Void;
    public var onRightClick:Void->Void;
    public var onMiddleClick:Void->Void;
    public var onDoubleClick:Void->Void;
    public var onMouseOver:Void->Void;
    public var onMouseOut:Void->Void;
    
    // 鼠标悬停计时
    private var hoverTime:Float = 0;
    private var doubleClickTimer:Float = 0;
    private var lastClickTime:Float = 0;
    private static var DOUBLE_CLICK_DELAY:Float = 0.3;
    
    public function new(x:Float, y:Float, width:Float, height:Float, data:Dynamic, fileName:String, idx:Int)
    {
        super(x, y);
        this.index = idx;
        this.replayData = data;
        this.filename = fileName;
        
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
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // 更新双点计时器
        if (doubleClickTimer > 0)
        {
            doubleClickTimer -= elapsed;
        }
        
        // 更新悬停状态
        if (hovered)
        {
            hoverTime += elapsed;
        }
        else
        {
            hoverTime = 0;
        }
        
        // 处理鼠标交互
        if (FlxG.mouse.visible && FlxG.mouse.overlaps(this))
        {
            if (!hovered)
            {
                hovered = true;
                if (onMouseOver != null) onMouseOver();
            }
            
            // 处理鼠标点击
            if (FlxG.mouse.justPressed)
            {
                handleClick();
            }
            
            if (FlxG.mouse.justPressedRight)
            {
                if (onRightClick != null) onRightClick();
            }
            
            if (FlxG.mouse.justPressedMiddle)
            {
                if (onMiddleClick != null) onMiddleClick();
            }
        }
        else
        {
            if (hovered)
            {
                hovered = false;
                if (onMouseOut != null) onMouseOut();
            }
        }
    }
    
    private function handleClick()
    {
        var currentTime = FlxG.game.ticks / 1000;
        
        // 检查双点
        if (currentTime - lastClickTime <= DOUBLE_CLICK_DELAY)
        {
            if (onDoubleClick != null) onDoubleClick();
            lastClickTime = 0; // 重置，避免三次点击触发两次双点
        }
        else
        {
            // 单点
            if (onClick != null) onClick();
            lastClickTime = currentTime;
        }
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
    
    // 滚动相关
    var scrollVelocity:Float = 0;
    var scrollDecay:Float = 0.95;
    var minScrollSpeed:Float = 0.5;
    var lastMouseY:Float = 0;
    var isDragging:Bool = false;
    var dragStartY:Float = 0;
    var dragThreshold:Float = 10;
    
    // 悬停相关
    var hoveredCard:ReplayCard = null;
    
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
            "Click: Select/Load | Right Click: View Results | Double Click: Load | Middle Click: View | Drag: Scroll | F: Delete", 16);
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
        
        FlxG.mouse.visible = true;
        lastMouseY = FlxG.mouse.screenY;
        
        loadReplays();
        updateDisplay();
        
        super.create();
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (waitingForDeleteConfirm)
        {
            handleDeleteConfirmation();
            return;
        }
        
        // 处理鼠标拖动滚动
        handleMouseDrag(elapsed);
        
        // 处理鼠标滚轮
        handleMouseWheel(elapsed);
        
        // 应用滚动速度
        applyScrollVelocity(elapsed);
        
        // 处理键盘控制
        handleKeyboardControls();
        
        // 检查并处理悬停卡片
        updateHoverState();
    }
    
    function handleMouseDrag(elapsed:Float)
    {
        var currentMouseY = FlxG.mouse.screenY;
        
        if (FlxG.mouse.pressed)
        {
            if (!isDragging)
            {
                // 检查是否开始拖动（超过阈值）
                if (Math.abs(currentMouseY - dragStartY) > dragThreshold)
                {
                    isDragging = true;
                }
            }
            else
            {
                // 计算拖动速度
                var deltaY = currentMouseY - lastMouseY;
                if (Math.abs(deltaY) > 0)
                {
                    // 根据拖动方向添加滚动速度
                    scrollVelocity += deltaY * 0.5;
                    
                    // 限制最大速度
                    scrollVelocity = Math.max(-30, Math.min(30, scrollVelocity));
                    
                    // 实时应用滚动
                    scrollBy(deltaY);
                }
            }
            
            dragStartY = currentMouseY;
        }
        else
        {
            if (isDragging)
            {
                isDragging = false;
            }
            dragStartY = currentMouseY;
        }
        
        lastMouseY = currentMouseY;
    }
    
    function handleMouseWheel(elapsed:Float)
    {
        var wheelDelta = FlxG.mouse.wheel;
        if (wheelDelta != 0)
        {
            // 添加滚轮速度
            scrollVelocity += wheelDelta * -15; // 负号使滚动方向自然
            
            // 立即应用一些滚动
            scrollBy(wheelDelta * -50);
            
            // 播放滚动音效
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
        }
    }
    
    function applyScrollVelocity(elapsed:Float)
    {
        if (Math.abs(scrollVelocity) > minScrollSpeed)
        {
            scrollBy(scrollVelocity * elapsed * 60);
            scrollVelocity *= scrollDecay;
        }
        else
        {
            scrollVelocity = 0;
        }
    }
    
    function scrollBy(amount:Float)
    {
        if (grpReplays.members.length == 0) return;
        
        // 获取第一张和最后一张卡片的位置
        var firstCard = grpReplays.members[0];
        var lastCard = grpReplays.members[grpReplays.members.length - 1];
        
        if (firstCard == null || lastCard == null) return;
        
        // 计算可滚动范围
        var topBoundary = 120; // 顶部边界
        var bottomBoundary = FlxG.height - 100; // 底部边界
        
        // 尝试移动所有卡片
        var newY = firstCard.y + amount;
        
        // 检查是否超出边界
        if (newY > topBoundary)
        {
            // 到达顶部，修正位置并停止速度
            amount = topBoundary - firstCard.y;
            scrollVelocity = 0;
        }
        else if (lastCard.y + lastCard.height < bottomBoundary)
        {
            // 到达底部，修正位置并停止速度
            amount = bottomBoundary - (lastCard.y + lastCard.height);
            scrollVelocity = 0;
        }
        
        // 移动所有卡片
        for (card in grpReplays.members)
        {
            if (card != null)
            {
                card.y += amount;
            }
        }
        
        // 更新分页基于最上面的卡片
        updatePageBasedOnScroll();
    }
    
    function updatePageBasedOnScroll()
    {
        if (grpReplays.members.length == 0) return;
        
        // 根据第一张卡片的位置计算当前页
        var firstCard = grpReplays.members[0];
        if (firstCard != null)
        {
            var cardHeight = 105; // 卡片高度 + 间距
            var estimatedIndex = Math.floor((firstCard.y - 120) / cardHeight) * -1;
            estimatedIndex = Math.floor(estimatedIndex / itemsPerPage) * itemsPerPage;
            
            var newPage = Math.floor(estimatedIndex / itemsPerPage);
            if (newPage < 0) newPage = 0;
            if (newPage >= totalPages) newPage = totalPages - 1;
            
            if (newPage != currentPage)
            {
                currentPage = newPage;
                updatePageText();
            }
        }
    }
    
    function updatePageText()
    {
        var startIndex = currentPage * itemsPerPage;
        var endIndex = Math.min(startIndex + itemsPerPage, replays.length);
        pageText.text = 'Page ${currentPage + 1}/${totalPages} (${startIndex + 1}-${endIndex})';
    }
    
    function updateHoverState()
    {
        var newHoveredCard:ReplayCard = null;
        
        // 检查鼠标悬停在哪个卡片上
        for (card in grpReplays.members)
        {
            if (card != null && FlxG.mouse.overlaps(card))
            {
                newHoveredCard = card;
                break;
            }
        }
        
        // 更新悬停状态
        if (newHoveredCard != hoveredCard)
        {
            if (hoveredCard != null)
            {
                hoveredCard.updateHover(false);
            }
            
            hoveredCard = newHoveredCard;
            
            if (hoveredCard != null)
            {
                hoveredCard.updateHover(true);
                
                // 如果不处于拖动状态，自动选中悬停的卡片
                if (!isDragging && hoveredCard.index != curSelected)
                {
                    changeSelectionTo(hoveredCard.index, false);
                }
            }
        }
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
        hoveredCard = null;
        
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
                    filename,
                    replayIndex
                );
                
                // 设置回调函数
                card.onClick = function() {
                    if (card.index == curSelected) {
                        // 如果已经选中，点击就加载
                        loadReplay(card.filename);
                    } else {
                        // 否则只选中
                        changeSelectionTo(card.index, true);
                    }
                };
                
                card.onDoubleClick = function() {
                    changeSelectionTo(card.index, false);
                    loadReplay(card.filename);
                };
                
                card.onRightClick = function() {
                    changeSelectionTo(card.index, true);
                    viewReplayResults(card.filename);
                };
                
                card.onMiddleClick = function() {
                    changeSelectionTo(card.index, true);
                    viewReplayResults(card.filename);
                };
                
                card.onMouseOver = function() {
                    // 鼠标悬停处理已经在updateHoverState中处理
                };
                
                card.onMouseOut = function() {
                    // 鼠标离开处理已经在updateHoverState中处理
                };
                
                card.updateSelection(replayIndex == curSelected);
                grpReplays.add(card);
            }
            catch(e:Dynamic)
            {
                trace('Error loading replay ${filename}: $e');
            }
        }
    }
    
    function handleKeyboardControls()
    {
        if (controls.BACK)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new FreeplayState());
            return;
        }
        
        if (replays.length > 0)
        {
            if (controls.UI_UP_P)
            {
                changeSelection(-1, true);
            }
            
            if (controls.UI_DOWN_P)
            {
                changeSelection(1, true);
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
            
            if (FlxG.keys.justPressed.V)
            {
                if (curSelected >= 0 && curSelected < replays.length)
                {
                    viewReplayResults(replays[curSelected]);
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
    
    function handleDeleteConfirmation()
    {
        if (FlxG.keys.justPressed.Y)
        {
            confirmDelete();
        }
        else if (FlxG.keys.justPressed.N || FlxG.keys.justPressed.ESCAPE)
        {
            cancelDelete();
        }
    }
    
    function changeSelectionTo(index:Int, playSound:Bool = true)
    {
        if (index < 0) index = 0;
        if (index >= replays.length) index = replays.length - 1;
        
        var change = index - curSelected;
        if (change != 0) {
            changeSelection(change, playSound);
        }
    }
    
    function changeSelection(change:Int, playSound:Bool = true)
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
            if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
        else if (curSelected >= endIndex)
        {
            currentPage = Math.floor(curSelected / itemsPerPage);
            updateDisplay();
            if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
        }
        else
        {
            // 更新选中状态
            for (card in grpReplays)
            {
                if (card.index == oldSelected)
                {
                    card.updateSelection(false);
                }
                if (card.index == curSelected)
                {
                    card.updateSelection(true);
                }
            }
            if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
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
    
    public function loadReplay(filename:String):Void
    {
        trace('Loading replay: $filename');
        
        var rep:Replay = Replay.LoadReplay(filename);
        
        if (rep == null || !rep.isValid())
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Invalid replay file!");
            return;
        }
        
        #if MODS_ALLOWED
        if (rep.replay.modDirectory != null && rep.replay.modDirectory.length > 0)
        {
            Mods.currentModDirectory = rep.replay.modDirectory;
            trace('Set mod directory to: ${rep.replay.modDirectory}');
        }
        #end
        
        PlayState.rep = rep;
        PlayState.loadRep = true;
        PlayState.inReplay = true;
        PlayState.replayFileName = filename;
        trace('Set replayFileName to: $filename');
        
        var difficultyID:Int = 1;
        
        if (rep.replay.difficultyName != null)
        {
            var diffLower = rep.replay.difficultyName.toLowerCase();
            
            if (diffLower.indexOf('easy') >= 0)
                difficultyID = 0;
            else if (diffLower.indexOf('normal') >= 0 || diffLower.indexOf('standard') >= 0)
                difficultyID = 1;
            else if (diffLower.indexOf('hard') >= 0)
                difficultyID = 2;
            else
                difficultyID = rep.replay.songDiff;
        }
        else
        {
            difficultyID = rep.replay.songDiff;
        }
        
        PlayState.storyDifficulty = difficultyID;
        trace('Setting storyDifficulty to: $difficultyID (${Difficulty.getString(difficultyID)})');
        
        var songName:String = rep.replay.songName;
        var difficultyName:String = rep.replay.difficultyName;
        
        try
        {
            var diffSuffix = '';
            if (difficultyName != null)
            {
                var lowerDiff = difficultyName.toLowerCase();
                if (lowerDiff == 'normal' || lowerDiff == 'standard')
                    diffSuffix = '';
                else
                    diffSuffix = '-' + lowerDiff;
            }
            
            var jsonToLoad = songName + diffSuffix;
            trace('Loading JSON: $jsonToLoad');
            
            PlayState.SONG = Song.loadFromJson(jsonToLoad, songName);
            
            if (PlayState.SONG == null)
            {
                throw 'Failed to load song';
            }
            
            PlayState.storyDifficulty = difficultyID;
            PlayState.isStoryMode = false;
            ClientPrefs.data.downScroll = rep.replay.isDownscroll;
            
            FlxG.sound.music.stop();
            LoadingState.loadAndSwitchState(new PlayState());
        }
        catch(e:Dynamic)
        {
            trace('Error loading song: $e');
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Failed to load song!\nMissing: ${songName + diffSuffix}.json");
        }
    }
    
    function viewReplayResults(filename:String):Void
    {
        trace('Viewing replay results: $filename');
        
        try
        {
            var filePath = "assets/replays/" + filename;
            if (!FileSystem.exists(filePath)) {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                showError("Replay file not found!");
                return;
            }
            
            var rep:Replay = Replay.LoadReplay(filename);
            if (rep == null || !rep.isValid())
            {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                showError("Invalid replay file!");
                return;
            }
            
            PlayState.rep = rep;
            
            var resultsScreen = new ResultsScreen(REPLAY_PREVIEW, filename);
            
            openSubState(resultsScreen);
            FlxG.sound.play(Paths.sound('confirmMenu'));
        }
        catch(e:Dynamic)
        {
            trace('Error viewing replay: $e');
            FlxG.sound.play(Paths.sound('cancelMenu'));
            showError("Error loading replay: " + e);
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