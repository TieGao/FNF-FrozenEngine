package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxTimer;
import backend.Replay;
import backend.HitGraph;
import backend.OFLSprite;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import backend.Song;
import backend.Difficulty;
import backend.ClientPrefs;
import StringTools;
import objects.SearchBar;
import objects.Bar;
import openfl.display.Sprite;

// ========== 回放卡片类 - 简洁竖向设计 ==========
class ReplayCard extends FlxSpriteGroup
{
    public var bg:FlxSprite;
    public var songText:FlxText;
    public var infoText:FlxText;
    public var scoreText:FlxText;
    public var accuracyFill:FlxSprite;
    public var accuracyBG:FlxSprite;
    public var modTag:FlxText;
    public var ratingText:FlxText;
    
    public var replayData:Dynamic;
    public var filename:String;
    public var index:Int;
    public var selected:Bool = false;
    
    // 回调
    public var onClick:Void->Void;
    public var onDoubleClick:Void->Void;
    
    private var cardWidth:Float;
    private var cardHeight:Float;
    private var lastClickTime:Float = 0;
    private static var DOUBLE_CLICK_DELAY:Float = 0.3;
    
    public function new(x:Float, y:Float, width:Float, height:Float, data:Dynamic, fileName:String, idx:Int)
    {
        super(x, y);
        this.cardWidth = width;
        this.cardHeight = height;
        this.index = idx;
        this.replayData = data;
        this.filename = fileName;
        
        // 背景
        bg = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), FlxColor.BLACK);
        bg.alpha = 0.7;
        bg.color = FlxColor.BLACK;
        add(bg);
        
        // 歌曲名
        var songName:String = data.songName != null ? data.songName : "Unknown Song";
        songText = new FlxText(12, 8, width - 100, songName, 18);
        songText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
        add(songText);
        
        // 难度和日期
        var diffColor = getDifficultyColor(data.difficultyName);
        var dateStr = formatDate(data.timestamp);
        
        infoText = new FlxText(12, 32, width - 100, 
            '${data.difficultyName}  •  ${dateStr}', 12);
        infoText.setFormat(Paths.font("vcr.ttf"), 12, diffColor, LEFT);
        add(infoText);
        
        // 评分显示
        var ratingStr:String = (data.rating != null) ? data.rating : "N/A";
        var fcStr:String = (data.ratingFC != null && data.ratingFC != "N/A") ? data.ratingFC : "";
        var ratingDisplay:String = fcStr != "" ? '$ratingStr ($fcStr)' : ratingStr;
        
        ratingText = new FlxText(width - 80, 8, 75, ratingDisplay, 14);
        ratingText.setFormat(Paths.font("vcr.ttf"), 14, getRatingColor(ratingStr), RIGHT);
        add(ratingText);
        
        // 准确度背景条
        accuracyBG = new FlxSprite(12, 52).makeGraphic(Std.int(width - 24), 4, FlxColor.GRAY);
        accuracyBG.alpha = 0.8;
        add(accuracyBG);
        
        // 准确度填充条
        var accuracy:Float = data.accuracy != null ? data.accuracy : 0;
        var fillWidth = Std.int((width - 24) * Math.min(accuracy, 100) / 100);
        accuracyFill = new FlxSprite(12, 52).makeGraphic(fillWidth, 4, getAccuracyColor(accuracy));
        add(accuracyFill);
        
        // 分数和准确度文本
        var scoreStr = formatNumber(data.score);
        var accuracyStr = formatAccuracy(accuracy);
        scoreText = new FlxText(12, 62, width - 24, 
            'Score: $scoreStr  •  Acc: $accuracyStr%', 12);
        scoreText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT);
        add(scoreText);
        
        // 模组标记
        if (data.modDirectory != null && data.modDirectory.length > 0 && data.modDirectory != "")
        {
            modTag = new FlxText(width - 60, 32, 55, "MOD", 10);
            modTag.setFormat(Paths.font("vcr.ttf"), 10, FlxColor.YELLOW, RIGHT);
            add(modTag);
        }
        
        updateSelected(false);
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (FlxG.mouse.visible && FlxG.mouse.overlaps(this))
        {
            if (FlxG.mouse.justPressed)
                handleClick();
        }
    }
    
    private function handleClick()
    {
        var currentTime = FlxG.game.ticks / 1000;
        
        if (currentTime - lastClickTime <= DOUBLE_CLICK_DELAY)
        {
            if (onDoubleClick != null) onDoubleClick();
            lastClickTime = 0;
        }
        else
        {
            if (onClick != null) onClick();
            lastClickTime = currentTime;
        }
    }
    
    public function updateSelected(isSelected:Bool)
    {
        this.selected = isSelected;
        if (selected)
        {
            bg.color = FlxColor.fromRGB(50, 70, 110);
            bg.alpha = 0.9;
        }
        else
        {
            bg.color = FlxColor.BLACK;
            bg.alpha = 0.7;
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
    
    function getRatingColor(rating:String):FlxColor
    {
        var r = rating.toLowerCase();
        if (r == "p" || r == "marvelous") return FlxColor.fromRGB(255, 215, 0);
        if (r == "gp" || r == "sick") return FlxColor.CYAN;
        if (r == "ep" || r == "good") return FlxColor.LIME;
        if (r == "e") return FlxColor.fromRGB(150, 255, 100);
        if (r == "sg") return FlxColor.YELLOW;
        if (r == "g") return FlxColor.ORANGE;
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
        if (timestamp == null) return "Unknown";
        return Std.string(timestamp);
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
        var rounded:Float = FlxMath.roundDecimal(acc, 2);
        return Std.string(rounded);
    }
}

// ========== 右侧详情面板 - 使用 ResultsScreen 的 HitGraph 逻辑 ==========
// ========== 右侧详情面板 - 使用 ResultsScreen 的 HitGraph 逻辑 ==========
class ReplayDetailPanel extends FlxSpriteGroup
{
    public var bg:FlxSprite;
    
    // 左侧信息区域 (中间1/3)
    public var infoBg:FlxSprite;
    public var infoTexts:Array<FlxText> = [];
    
    // 右侧图表区域 (右侧1/3)
    public var graphBg:FlxSprite;
    public var hitGraph:HitGraph;
    public var hitGraphSprite:OFLSprite;
    public var loadingText:FlxText;
    
    // 判定进度条区域 - 使用简单的 FlxSprite
    public var ratingBarsBg:FlxSprite;
    public var ratingBars:Map<String, FlxSprite> = new Map();
    public var ratingBarsBgMap:Map<String, FlxSprite> = new Map(); // 背景条
    public var ratingLabels:Map<String, FlxText> = new Map();
    public var ratingPercentTexts:Map<String, FlxText> = new Map();
    
    private var currentReplayData:Dynamic = null;
    private var currentFilename:String = "";
    private var panelWidth:Float;
    private var panelHeight:Float;
    
    // 判定颜色映射
    private var ratingColors:Map<String, FlxColor> = [
        "Marvelous" => FlxColor.fromRGB(255, 215, 0),
        "Sick" => FlxColor.CYAN,
        "Good" => FlxColor.LIME,
        "Bad" => FlxColor.fromRGB(255, 100, 100),
        "Shit" => FlxColor.RED,
        "Miss" => FlxColor.fromRGB(100, 0, 0)
    ];
    
    public function new(x:Float, y:Float, width:Float, height:Float)
    {
        super(x, y);
        this.panelWidth = width;
        this.panelHeight = height;
        
        // 主背景
        bg = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), FlxColor.fromRGB(20, 20, 35));
        bg.alpha = 0.6;
        add(bg);
        
        var sectionWidth:Float = width / 2; // 中间和右边各占一半
        
        // ========== 左侧信息区域 (sectionWidth 宽度) ==========
        infoBg = new FlxSprite(0, 0).makeGraphic(Std.int(sectionWidth), Std.int(height), FlxColor.fromRGB(15, 15, 25));
        infoBg.alpha = 0.6;
        add(infoBg);
        
        var infoTitle = new FlxText(10, 10, sectionWidth - 20, "REPLAY INFO", 18);
        infoTitle.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.CYAN, CENTER);
        add(infoTitle);
        
        // 创建信息文本区域
        var infoY:Float = 50;
        var infoLabels:Array<String> = [
            "Song Name:",
            "Difficulty:",
            "Mod Folder:",
            "Date:",
            "Score:",
            "Accuracy:",
            "Misses:",
            "Rating:",
            "Max Combo:"
        ];
        
        for (i in 0...infoLabels.length)
        {
            var label = new FlxText(12, infoY + i * 26, 120, infoLabels[i], 16);
            label.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, LEFT);
            add(label);
            
            var value = new FlxText(130, infoY + i * 26, sectionWidth - 120, "--", 16);
            value.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
            add(value);
            infoTexts.push(value);
        }
        
        // ========== 右侧图表区域 (sectionWidth 宽度) ==========
        graphBg = new FlxSprite(sectionWidth, 0).makeGraphic(Std.int(sectionWidth), Std.int(height), FlxColor.fromRGB(15, 15, 25));
        graphBg.alpha = 0.6;
        add(graphBg);
        
        var graphTitle = new FlxText(sectionWidth + 10, 10, sectionWidth - 20, "HIT GRAPH", 18);
        graphTitle.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.CYAN, CENTER);
        add(graphTitle);
        
        // HitGraph 区域 (上方 40%)
        var graphAreaHeight:Float = height * 0.4;
        var graphY:Float = 55;
        var graphWidth:Float = sectionWidth - 24;
        
        hitGraph = new HitGraph(Std.int(sectionWidth + 12), Std.int(graphY), Std.int(graphWidth), Std.int(graphAreaHeight - 10));
        hitGraph.alpha = 1;
        
        hitGraphSprite = new OFLSprite(sectionWidth + 12, graphY, Std.int(graphWidth), Std.int(graphAreaHeight - 10), hitGraph);
        hitGraphSprite.scrollFactor.set();
        hitGraphSprite.visible = false;
        add(hitGraphSprite);
        
        // 加载提示文本
        loadingText = new FlxText(sectionWidth + 12, graphY + graphAreaHeight / 2 - 20, graphWidth, "Select a replay to view hit graph", 14);
        loadingText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, CENTER);
        add(loadingText);
        
        // ========== 判定进度条区域 (下方区域，间距更大) ==========
        var barsY:Float = graphY + graphAreaHeight + 20; // 增加顶部间距
        var barsHeight:Float = height - barsY - 20;
        var barsWidth:Float = sectionWidth - 24;

        var barsTitle = new FlxText(sectionWidth + 12, barsY - 8, barsWidth, "JUDGEMENT BREAKDOWN", 16);
        barsTitle.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
        add(barsTitle);

        // 创建6个判定进度条 (Marvelous, Sick, Good, Bad, Shit, Miss)
        var ratingNames:Array<String> = ["Marvelous", "Sick", "Good", "Bad", "Shit", "Miss"];
        var barYPos:Float = barsY + 15;
        var barHeight:Int = 16;      // 进度条更高
        var barSpacing:Int = 34;     // 间距更大

        for (i in 0...ratingNames.length)
        {
            var ratingName = ratingNames[i];
            var color = ratingColors.get(ratingName);
            if (color == null) color = FlxColor.WHITE;
            
            // 标签
            var label = new FlxText(sectionWidth , barYPos + i * barSpacing, 125, ratingName + ":", 16);
            label.setFormat(Paths.font("vcr.ttf"), 16, color, LEFT);
            add(label);
            ratingLabels.set(ratingName, label);
            
            // 百分比文本
            var percentText = new FlxText(sectionWidth + barsWidth - 60, barYPos + i * barSpacing, 64, "0%", 16);
            percentText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT);
            add(percentText);
            ratingPercentTexts.set(ratingName, percentText);
            
            // 进度条背景（灰色底）
            var barBg = new FlxSprite(sectionWidth + 95, barYPos + i * barSpacing + 1).makeGraphic(Std.int(barsWidth - 155), barHeight, FlxColor.GRAY);
            barBg.alpha = 0.5;
            add(barBg);
            ratingBarsBgMap.set(ratingName, barBg);
            
            // 进度条填充（初始宽度为0）
            var barFill = new FlxSprite(sectionWidth + 95, barYPos + i * barSpacing + 1).makeGraphic(0, barHeight, color);
            add(barFill);
            ratingBars.set(ratingName, barFill);
        }
    }
    
    public function updateWithReplay(filename:String, replayData:Dynamic)
    {
        this.currentFilename = filename;
        this.currentReplayData = replayData;
        
        if (replayData == null)
        {
            clearInfo();
            return;
        }
        
        // 更新文本信息
        var accuracyValue:String = (replayData.accuracy != null) ? formatAccuracyValue(replayData.accuracy) : "0";
        var scoreValue:Float = (replayData.score != null) ? Std.parseFloat(Std.string(replayData.score)) : 0;
        
        var values:Array<String> = [
            replayData.songName != null ? replayData.songName : "Unknown",
            replayData.difficultyName != null ? replayData.difficultyName : "Unknown",
            (replayData.modDirectory != null && replayData.modDirectory != "") ? replayData.modDirectory : "Base Game",
            formatDate(replayData.timestamp),
            formatNumberValue(scoreValue),
            accuracyValue + "%",
            replayData.misses != null ? Std.string(replayData.misses) : "0",
            (replayData.rating != null ? replayData.rating : "N/A") + 
                (replayData.ratingFC != null && replayData.ratingFC != "N/A" ? " (" + replayData.ratingFC + ")" : ""),
            replayData.maxCombo != null ? Std.string(replayData.maxCombo) : "--"
        ];
        
        for (i in 0...values.length)
        {
            if (i < infoTexts.length)
                infoTexts[i].text = values[i];
        }
        
        // 清除之前的图表数据
        if (hitGraph != null)
        {
            hitGraph.history = [];
            hitGraph.update();
        }
        if (hitGraphSprite != null)
            hitGraphSprite.visible = false;
        
        // 加载命中图表数据和判定统计
        loadReplayData();
    }
    
    function loadReplayData():Void
    {
        if (hitGraph == null || currentFilename == null || currentFilename == "")
        {
            if (loadingText != null)
            {
                loadingText.text = "No replay selected";
                loadingText.visible = true;
            }
            return;
        }
        
        loadingText.visible = true;
        loadingText.text = "Loading replay data...";
        loadingText.color = FlxColor.YELLOW;
        
        var currentHitGraph = hitGraph;
        var currentHitGraphSprite = hitGraphSprite;
        var currentLoadingText = loadingText;
        var currentFilename_safe = currentFilename;
        var currentRatingBars = ratingBars;
        var currentRatingBarsBg = ratingBarsBgMap;
        var currentRatingPercentTexts = ratingPercentTexts;
        
        new FlxTimer().start(0.05, function(tmr:FlxTimer)
        {
            if (currentHitGraph == null)
            {
                trace('HitGraph is null, cannot load hit data');
                if (currentLoadingText != null) currentLoadingText.text = "HitGraph not available";
                return;
            }
            
            try
            {
                var rep:Replay = Replay.LoadReplay(currentFilename_safe);
                if (rep == null || rep.replay == null)
                {
                    if (currentLoadingText != null)
                    {
                        currentLoadingText.text = "Failed to load replay data";
                        currentLoadingText.color = FlxColor.RED;
                    }
                    return;
                }
                
                var playbackRate:Float = 1.0;
                
                // 清空历史数据
                currentHitGraph.history = [];
                
                // 统计判定数量
                var ratingCounts:Map<String, Int> = new Map();
                for (rating in ratingColors.keys())
                    ratingCounts.set(rating, 0);
                
                // 加载命中数据
                var songNotes = rep.replay.songNotes;
                var songJudgements = rep.replay.songJudgements;
                
                if (songNotes != null && songNotes.length > 0)
                {
                    var addedCount:Int = 0;
                    
                    for (i in 0...songNotes.length)
                    {
                        var obj = songNotes[i];
                        if (obj == null) continue;
                        
                        var obj2:Dynamic = "";
                        if (songJudgements != null && i < songJudgements.length) obj2 = songJudgements[i];
                        
                        var diff:Float = 0;
                        var time:Float = 0;
                        var judge:String = "";
                        
                        try {
                            if (obj.length > 3 && obj[3] != null) diff = Std.parseFloat(Std.string(obj[3]));
                        } catch(e:Dynamic) { diff = 0; }
                        
                        try {
                            if (obj.length > 0 && obj[0] != null) time = Std.parseFloat(Std.string(obj[0]));
                        } catch(e:Dynamic) { time = 0; }
                        
                        if (obj2 != null) {
                            try { judge = Std.string(obj2); } catch(e:Dynamic) { judge = ""; }
                        }
                        
                        // 统计判定
                        if (judge != null && judge != "")
                        {
                            var normalizedJudge = judge.toLowerCase();
                            if (normalizedJudge.indexOf("marvelous") >= 0)
                                ratingCounts.set("Marvelous", ratingCounts.get("Marvelous") + 1);
                            else if (normalizedJudge.indexOf("sick") >= 0)
                                ratingCounts.set("Sick", ratingCounts.get("Sick") + 1);
                            else if (normalizedJudge.indexOf("good") >= 0)
                                ratingCounts.set("Good", ratingCounts.get("Good") + 1);
                            else if (normalizedJudge.indexOf("bad") >= 0)
                                ratingCounts.set("Bad", ratingCounts.get("Bad") + 1);
                            else if (normalizedJudge.indexOf("shit") >= 0)
                                ratingCounts.set("Shit", ratingCounts.get("Shit") + 1);
                            else if (normalizedJudge.indexOf("miss") >= 0)
                                ratingCounts.set("Miss", ratingCounts.get("Miss") + 1);
                        }
                        
                        if (obj.length > 1 && obj[1] != -1 && judge != null && judge != "")
                        {
                            currentHitGraph.addToHistory(diff / playbackRate, judge, time / playbackRate);
                            addedCount++;
                        }
                    }
                    
                    trace('Loaded $addedCount entries from replay');
                }
                
                // 计算总数并更新进度条
                var totalNotes:Int = 0;
                for (count in ratingCounts)
                    totalNotes += count;
                
                if (totalNotes > 0)
                {
                    for (ratingName in ratingColors.keys())
                    {
                        var count = ratingCounts.get(ratingName);
                        var percent:Float = (count / totalNotes) * 100;
                        
                        // 获取背景条宽度来计算填充宽度
                        var barBg = currentRatingBarsBg.get(ratingName);
                        var barFill = currentRatingBars.get(ratingName);
                        
                        if (barBg != null && barFill != null)
                        {
                            var maxWidth = barBg.width;
                            var fillWidth = Std.int(maxWidth * percent / 100);
                            
                            // 重新生成填充条图形
                            barFill.makeGraphic(fillWidth, Std.int(barBg.height), ratingColors.get(ratingName));
                            barFill.x = barBg.x;
                            barFill.y = barBg.y;
                        }
                        
                        var percentText = currentRatingPercentTexts.get(ratingName);
                        if (percentText != null)
                        {
                            percentText.text = Math.round(percent) + "% (" + count + ")";
                        }
                    }
                }
                
                if (currentHitGraph.history.length > 0)
                {
                    currentHitGraph.update();
                    if (currentHitGraphSprite != null)
                    {
                        currentHitGraphSprite.visible = true;
                        currentHitGraphSprite.updateDisplay();
                    }
                    if (currentLoadingText != null)
                        currentLoadingText.visible = false;
                }
                else
                {
                    if (currentLoadingText != null)
                    {
                        currentLoadingText.text = "No valid hit data found";
                        currentLoadingText.color = FlxColor.YELLOW;
                    }
                }
            }
            catch(e:Dynamic)
            {
                trace('Error loading replay data: ' + e);
                if (currentLoadingText != null)
                {
                    currentLoadingText.text = "Error loading data";
                    currentLoadingText.color = FlxColor.RED;
                }
            }
        });
    }
    
    private function clearInfo()
    {
        for (text in infoTexts)
            text.text = "--";
        
        if (hitGraph != null)
        {
            hitGraph.history = [];
            hitGraph.update();
        }
        if (hitGraphSprite != null)
            hitGraphSprite.visible = false;
        
        // 重置进度条
        for (barFill in ratingBars)
        {
            if (barFill != null)
                barFill.makeGraphic(0, 0, FlxColor.TRANSPARENT);
        }
        for (text in ratingPercentTexts)
        {
            if (text != null)
                text.text = "0%";
        }
        
        if (loadingText != null)
        {
            loadingText.text = "Select a replay to view details";
            loadingText.visible = true;
            loadingText.color = FlxColor.YELLOW;
        }
    }
    
    function formatDate(timestamp:Dynamic):String
    {
        if (timestamp == null) return "Unknown";
        return Std.string(timestamp);
    }
    
    private function formatNumberValue(num:Float):String
    {
        if (Math.isNaN(num)) return "0";
        if (num >= 1000000) return Std.int(num / 1000000) + "M";
        if (num >= 1000) return Std.int(num / 1000) + "K";
        return Std.string(Std.int(num));
    }
    
    private function formatAccuracyValue(acc:Dynamic):String
    {
        var value:Float = Std.parseFloat(Std.string(acc));
        if (Math.isNaN(value)) return "0.00";
        var rounded:Float = FlxMath.roundDecimal(value, 2);
        return Std.string(rounded);
    }
    
    override public function destroy()
    {
        if (hitGraphSprite != null)
        {
            remove(hitGraphSprite);
            hitGraphSprite.destroy();
            hitGraphSprite = null;
        }
        hitGraph = null;
        
        for (bar in ratingBars)
        {
            if (bar != null) bar.destroy();
        }
        ratingBars.clear();
        
        for (barBg in ratingBarsBgMap)
        {
            if (barBg != null) barBg.destroy();
        }
        ratingBarsBgMap.clear();
        
        super.destroy();
    }
}

// ========== 主状态类 ==========
class LoadReplayState extends MusicBeatState
{
    var grpReplays:FlxTypedGroup<ReplayCard>;
    var replays:Array<String> = [];
    var curSelected:Int = 0;
    var replayJsons:Map<String, Dynamic> = new Map();
    var searchInput:SearchBar;
    
    var bg:FlxSprite;
    var starsBG:FlxBackdrop;
    var starsFG:FlxBackdrop;
    var space:FlxSprite;
    
    var topBlackBar:FlxSprite;
    var bottomBlackBar:FlxSprite;
    
    var titleText:FlxText;
    var noReplaysText:FlxText;
    var controlsText:FlxText;
    var statsText:FlxText;
    
    var detailPanel:ReplayDetailPanel;
    
    // 滚动相关
    var cardScrollPos:Float = 0;
    var cardScroller:backend.MouseMove;
    var cardsContainer:FlxTypedGroup<ReplayCard>;
    var visibleCards:Array<ReplayCard> = [];
    var allCards:Array<ReplayCard> = [];
    
    static inline var CARD_WIDTH:Int = 400;
    static inline var CARD_HEIGHT:Int = 85;
    static inline var CARD_SPACING:Int = 10;
    static inline var CARDS_PER_PAGE:Int = 6;
    
    var waitingForDeleteConfirm:Bool = false;
    var deleteConfirmText:FlxText;
    var replayToDelete:String = "";
    
    var filterTimer:Float = -1;
    var originalReplays:Array<String> = [];
    var originalJsons:Map<String, Dynamic> = new Map();
    
    override function create()
    {
        // 背景
        bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF3E3EF3;
        bg.setGraphicSize(Std.int(bg.width * 1.1));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);
        
        // 星空效果
        space = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        space.antialiasing = ClientPrefs.data.antialiasing;
        space.scrollFactor.set();
        space.alpha = 0;
        add(space);
        
        starsBG = new FlxBackdrop(Paths.image('starBG'));
        starsBG.setPosition(111.3, 67.95);
        starsBG.antialiasing = true;
        starsBG.scrollFactor.set();
        starsBG.alpha = 0;
        add(starsBG);
        
        starsFG = new FlxBackdrop(Paths.image('starFG'));
        starsFG.setPosition(54.3, 59.45);
        starsFG.scrollFactor.set();
        starsFG.antialiasing = true;
        starsFG.alpha = 0;
        add(starsFG);
        
        if (ClientPrefs.data.globalspace)
        {
            space.alpha = 1;
            starsBG.alpha = 1;
            starsFG.alpha = 1;
        }
        
        // 顶部黑框
        var barHeight:Int = Std.int(FlxG.height * 0.1);
        topBlackBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, barHeight, FlxColor.BLACK);
        topBlackBar.alpha = 0.7;
        topBlackBar.scrollFactor.set();
        add(topBlackBar);
        
        // 底部黑框
        bottomBlackBar = new FlxSprite(0, FlxG.height - barHeight).makeGraphic(FlxG.width, barHeight, FlxColor.BLACK);
        bottomBlackBar.alpha = 0.7;
        bottomBlackBar.scrollFactor.set();
        add(bottomBlackBar);
        
        // 标题
        titleText = new FlxText(0, 15, FlxG.width, "REPLAY LIBRARY", 28);
        titleText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 2;
        add(titleText);
        
        // 搜索框 - 放在左侧区域
        searchInput = new SearchBar(15, 60, 280);
        searchInput.onChange = function(oldText:String, newText:String) {
            filterTimer = 0.3;
        };
        add(searchInput);
        
        // 统计文本
        statsText = new FlxText(15, 95, 200, "", 14);
        statsText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.CYAN, LEFT);
        statsText.visible = false;
        add(statsText);
        
        // 卡片容器 - 左侧1/3区域 (大约 1/3 宽度)
        var leftPanelWidth:Int = Std.int(FlxG.width / 3);
        
        // 详情面板 - 右侧2/3区域
        detailPanel = new ReplayDetailPanel(leftPanelWidth, barHeight, FlxG.width - leftPanelWidth, FlxG.height - barHeight * 2);
        add(detailPanel);
        
        // 底部控制文本
        controlsText = new FlxText(0, FlxG.height - barHeight + 8, FlxG.width, 
            "↑/↓: Navigate | Enter/Double Click: Load | F: Delete | ESC: Back", 16);
        controlsText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        controlsText.borderSize = 1;
        add(controlsText);
        
        // 无回放提示
        noReplaysText = new FlxText(0, FlxG.height / 2 - 30, leftPanelWidth - 30, 
            "No Replays Found\n\nPlace .kadeReplay files in assets/replays/", 16);
        noReplaysText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        noReplaysText.borderSize = 2;
        noReplaysText.visible = false;
        add(noReplaysText);
        
        // 删除确认文本
        deleteConfirmText = new FlxText(0, FlxG.height / 2 - 20, FlxG.width, "", 22);
        deleteConfirmText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        deleteConfirmText.borderSize = 2;
        deleteConfirmText.visible = false;
        add(deleteConfirmText);
        
        FlxG.mouse.visible = true;
        
        cardsContainer = new FlxTypedGroup<ReplayCard>();
        add(cardsContainer);

        loadReplays();
                
        updateDisplay();
        
        // 初始化滚动器 - 限制在左侧区域
        var maxScroll:Float = Math.max(0, (replays.length - CARDS_PER_PAGE) * (CARD_HEIGHT + CARD_SPACING));
        cardScroller = new backend.MouseMove(this, 'cardScrollPos', [0, maxScroll], 
            [[0, FlxG.width], [barHeight + 10, FlxG.height - barHeight - 20]],
            function() { updateCardsPosition(); });
        cardScroller.useLerp = true;
        cardScroller.lerpSmooth = 12;
        cardScroller.dragSensitivity = 1.6;
        cardScroller.deceleration = 0.94;
        cardScroller.mouseWheelSensitivity = -200.0;
        add(cardScroller);
        
        super.create();
    }
    
    override function update(elapsed:Float)
    {
        starsBG.x -= 0.05;
        starsFG.x -= 0.15;
        if (starsBG.x < -starsBG.width) starsBG.x = 0;
        if (starsFG.x < -starsFG.width) starsFG.x = 0;
        
        super.update(elapsed);
        
        if (filterTimer > 0)
        {
            filterTimer -= elapsed;
            if (filterTimer <= 0)
                filterSongs();
        }
        
        if (waitingForDeleteConfirm)
        {
            handleDeleteConfirmation();
            return;
        }
        
        handleKeyboardControls();
        updateMouseSelection();
    }
    
    function loadReplays()
    {
        #if sys
        replays = [];
        replayJsons.clear();
        
        var replayDir = "assets/replays/";
        var entries:Array<{file:String, ts:Float, json:Dynamic}> = [];
        
        if (FileSystem.exists(replayDir))
        {
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
                    if (json.songName == null) json.songName = "Unknown Song";
                    if (json.difficultyName == null) json.difficultyName = 
                        (json.songDiff != null ? Difficulty.getString(Std.int(json.songDiff)) : "Normal");
                    if (json.timestamp == null) json.timestamp = Date.now();
                    if (json.modDirectory == null) json.modDirectory = "";
                    if (json.rating == null) json.rating = "N/A";
                    if (json.ratingFC == null) json.ratingFC = "N/A";
                    if (json.maxCombo == null) json.maxCombo = 0;
                    
                    var ts:Float = 0;
                    try {
                        ts = Date.now().getTime();
                    } catch(e:Dynamic) { ts = 0; }
                    
                    entries.push({ file: file, ts: ts, json: json });
                }
                catch(e:Dynamic) { trace('Error parsing replay: $e'); }
            }
            
            entries.sort(function(a,b):Int { return Std.int(b.ts - a.ts); });
            
            for (entry in entries)
            {
                replays.push(entry.file);
                replayJsons.set(entry.file, entry.json);
            }
        }
        
        originalReplays = replays.copy();
        originalJsons = new Map();
        for (key in replayJsons.keys())
            originalJsons.set(key, replayJsons.get(key));
        #end
    }
    
    function filterSongs()
    {
        var searchText:String = (searchInput != null && searchInput.text != null) ? searchInput.text : "";
        searchText = StringTools.trim(searchText.toLowerCase());
        
        if (searchText.length == 0)
        {
            replays = originalReplays.copy();
            replayJsons.clear();
            for (key in originalJsons.keys())
                replayJsons.set(key, originalJsons.get(key));
        }
        else
        {
            replays = [];
            replayJsons.clear();
            
            for (file in originalReplays)
            {
                var json = originalJsons.get(file);
                if (json == null) continue;
                
                var match = false;
                if (file.toLowerCase().indexOf(searchText) != -1) match = true;
                if (!match && json.songName != null && 
                    Std.string(json.songName).toLowerCase().indexOf(searchText) != -1) match = true;
                if (!match && json.difficultyName != null && 
                    Std.string(json.difficultyName).toLowerCase().indexOf(searchText) != -1) match = true;
                
                if (match)
                {
                    replays.push(file);
                    replayJsons.set(file, json);
                }
            }
        }
        
        curSelected = 0;
        cardScrollPos = 0;
        if (cardScroller != null)
        {
            var maxScroll = Math.max(0, (replays.length - CARDS_PER_PAGE) * (CARD_HEIGHT + CARD_SPACING));
            cardScroller.moveLimit = [0, maxScroll];
            cardScroller.tweenData = 0;
        }
        
        updateDisplay();
    }
    
    function updateDisplay()
    {
        cardsContainer.clear();
        allCards = [];
        
        if (replays.length == 0)
        {
            noReplaysText.visible = true;
            detailPanel.updateWithReplay("", null);
            return;
        }
        
        noReplaysText.visible = false;
        statsText.text = 'Total: ${replays.length} replays';
        statsText.visible = true;
        
        var startX:Float = 15;
        var startY:Float = 130;
        
        for (i in 0...replays.length)
        {
            var filename = replays[i];
            var json = replayJsons.get(filename);
            
            if (json == null) continue;
            
            var card = new ReplayCard(
                startX,
                startY + i * (CARD_HEIGHT + CARD_SPACING),
                CARD_WIDTH,
                CARD_HEIGHT,
                json,
                filename,
                i
            );
            
            card.onClick = function() {
                if (card.index == curSelected)
                    loadReplay(card.filename);
                else
                    changeSelection(card.index);
            };
            
            card.onDoubleClick = function() {
                changeSelection(card.index);
                loadReplay(card.filename);
            };
            
            card.updateSelected(i == curSelected);
            cardsContainer.add(card);
            allCards.push(card);
        }
        
        updateCardsPosition();
        
        if (curSelected >= 0 && curSelected < replays.length)
        {
            var selectedJson = replayJsons.get(replays[curSelected]);
            detailPanel.updateWithReplay(replays[curSelected], selectedJson);
        }
    }
    
    function updateCardsPosition()
    {
        var cardIndex:Float = cardScrollPos / (CARD_HEIGHT + CARD_SPACING);
        
        for (i in 0...allCards.length)
        {
            var card = allCards[i];
            var distance = i - cardIndex;
            var visible = Math.abs(distance) <= CARDS_PER_PAGE + 2;
            
            if (visible)
            {
                card.visible = true;
                card.active = true;
                var targetY:Float = 130 + (i * (CARD_HEIGHT + CARD_SPACING)) - cardScrollPos;
                card.y = targetY;
            }
            else
            {
                card.visible = false;
                card.active = false;
            }
        }
    }
    
    function updateMouseSelection()
    {
        if (waitingForDeleteConfirm) return;
        
        for (card in allCards)
        {
            if (card != null && card.visible && FlxG.mouse.overlaps(card))
            {
                if (card.index != curSelected)
                {
                    changeSelection(card.index);
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
                }
                
                if (FlxG.mouse.justPressed)
                {
                    if (card.index == curSelected)
                        loadReplay(card.filename);
                }
                break;
            }
        }
    }
    
    function changeSelection(index:Int, playSound:Bool = true)
    {
        if (index < 0) index = 0;
        if (index >= replays.length) index = replays.length - 1;
        
        var oldSelected = curSelected;
        curSelected = index;
        
        for (card in allCards)
        {
            if (card != null)
                card.updateSelected(card.index == curSelected);
        }
        
        if (curSelected >= 0 && curSelected < replays.length)
        {
            var selectedJson = replayJsons.get(replays[curSelected]);
            detailPanel.updateWithReplay(replays[curSelected], selectedJson);
        }
        
        if (playSound && oldSelected != curSelected)
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }
    
    function handleKeyboardControls()
    {
        if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new FreeplayState());
            return;
        }
        
        if (replays.length == 0) return;
        
        if (controls.UI_UP_P)
            changeSelection(curSelected - 1);
        
        if (controls.UI_DOWN_P)
            changeSelection(curSelected + 1);
        
        if (FlxG.keys.justPressed.PAGEUP)
            changeSelection(curSelected - CARDS_PER_PAGE);
        
        if (FlxG.keys.justPressed.PAGEDOWN)
            changeSelection(curSelected + CARDS_PER_PAGE);
        
        if (controls.ACCEPT)
        {
            if (curSelected >= 0 && curSelected < replays.length)
                loadReplay(replays[curSelected]);
        }
        
        if (FlxG.keys.justPressed.F)
        {
            if (curSelected >= 0 && curSelected < replays.length)
                promptDelete(replays[curSelected]);
        }
        
        if (FlxG.keys.justPressed.HOME)
            changeSelection(0);
        if (FlxG.keys.justPressed.END)
            changeSelection(replays.length - 1);
    }
    
    function handleDeleteConfirmation()
    {
        if (FlxG.keys.justPressed.Y)
            confirmDelete();
        else if (FlxG.keys.justPressed.N || FlxG.keys.justPressed.ESCAPE)
            cancelDelete();
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
            Mods.currentModDirectory = rep.replay.modDirectory;
        #end
        
        PlayState.rep = rep;
        PlayState.loadRep = true;
        PlayState.inReplay = true;
        PlayState.replayFileName = filename;
        
        var difficultyID:Int = 1;
        if (rep.replay.difficultyName != null)
        {
            var diffLower = rep.replay.difficultyName.toLowerCase();
            if (diffLower.indexOf('easy') >= 0) difficultyID = 0;
            else if (diffLower.indexOf('normal') >= 0 || diffLower.indexOf('standard') >= 0) difficultyID = 1;
            else if (diffLower.indexOf('hard') >= 0) difficultyID = 2;
            else difficultyID = rep.replay.songDiff;
        }
        else
            difficultyID = rep.replay.songDiff;
        
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
            
            PlayState.SONG = Song.loadFromJson(jsonToLoad, songName);
            
            if (PlayState.SONG == null)
                throw 'Failed to load song';
            
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
    
    function showError(message:String):Void
    {
        var errorMsg:FlxText = new FlxText(0, FlxG.height / 2 - 30, FlxG.width, message, 18);
        errorMsg.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
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
        if (displayName.length > 40)
            displayName = displayName.substr(0, 37) + "...";
        
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
            filterSongs();
            curSelected = 0;
            cardScrollPos = 0;
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
    
    override function destroy()
    {
        if (detailPanel != null) detailPanel.destroy();
        super.destroy();
    }
}