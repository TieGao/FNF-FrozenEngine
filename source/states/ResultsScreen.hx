package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;

import backend.Replay;
import backend.HitGraph;
import backend.OFLSprite;

class ResultsScreen extends MusicBeatSubstate
{
    public var background:FlxSprite;
    public var text:FlxText;
    public var comboText:FlxText;
    public var contText:FlxText;
    public var settingsText:FlxText;
    public var replayText:FlxText;

    public var anotherBackground:FlxSprite;
    public var graph:HitGraph;
    public var graphSprite:OFLSprite;

    public var camResults:FlxCamera;
    
    public var pauseMusic:FlxSound;

    var animationsStarted:Bool = false;
    public var replayToLoad:String = null;
    
    // 新增：模式标识
    var isReplayPreview:Bool = false;
    var loadedReplay:Replay = null;
    
    // 新增：存储游戏统计数据（用于普通模式）
    var gameStats:Dynamic = null;

    public function new(replayFile:String = null)
    {
        this.replayToLoad = replayFile;
        this.isReplayPreview = (replayFile != null);
        
        super();
        
        camResults = new FlxCamera();
        camResults.bgColor = 0x00000000;
        FlxG.cameras.add(camResults, false);
        cameras = [camResults];
        
        background = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        background.scrollFactor.set();
        background.alpha = 0;
        background.cameras = [camResults];
        add(background);

        text = new FlxText(0, -100, FlxG.width, "Song Cleared!");
        text.setFormat(Paths.font("vcr.ttf"), 34, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        text.borderSize = 4;
        text.scrollFactor.set();
        text.cameras = [camResults];
        text.alpha = 0;
        add(text);

        // 游戏模式：从PlayState获取数据
        if (!isReplayPreview) {
            collectGameStats();
        }
        
        // 回放预览模式：标题改为"REPLAY RESULTS"
        if (isReplayPreview) {
            text.text = "REPLAY RESULTS";
            text.color = FlxColor.CYAN;
        } else if (PlayState.isStoryMode) {
            text.text = "Week Cleared!";
        }
        
        // 创建通用UI元素
        createCommonUI();
        
        trace('ResultsScreen created. Mode: ${isReplayPreview ? "Replay Preview" : "Game Results"}');
    }
    
    function collectGameStats():Void
    {
        // 只有在游戏模式下才收集数据
        if (isReplayPreview) return;
        
        var playState = PlayState.instance;
        if (playState == null) return;
        
        var ratingsData = playState.ratingsData;
        var marvelous:Int = 0;
        var sicks:Int = 0;
        var goods:Int = 0;
        var bads:Int = 0;
        var shits:Int = 0;
        
        if (ratingsData != null && ratingsData.length >= 4) {
            marvelous = ratingsData[0].hits;
            sicks = ratingsData[1].hits;
            goods = ratingsData[2].hits;
            bads = ratingsData[3].hits;
            shits = ratingsData[4].hits;
        }
        
        var misses = playState.songMisses;
        var highestCombo = playState.highestCombo;
        var totalNotesHit = marvelous + sicks + goods + bads + shits;
        var totalNotes = totalNotesHit + misses;
        var accuracy:Float = 0;
        if (totalNotes > 0) {
            accuracy = (marvelous * 1.0 + sicks * 1.0 + goods * 0.75 + bads * 0.25) / totalNotes * 100;
        }
        
        // 保存游戏统计数据
        gameStats = {
            songName: PlayState.SONG.song,
            score: playState.songScore,
            accuracy: accuracy,
            marvelous: marvelous,
            sicks: sicks,
            goods: goods,
            bads: bads,
            shits: shits,
            misses: misses,
            highestCombo: highestCombo,
            totalNotes: totalNotes,
            totalNotesHit: totalNotesHit,
            ratingName: playState.ratingName,
            ratingFC: playState.ratingFC,
            playbackRate: playState.playbackRate,
            difficultyName: Difficulty.getString()
        };
    }
    
    function createCommonUI():Void
    {
        anotherBackground = new FlxSprite(FlxG.width - 500, 45).makeGraphic(450, 240, FlxColor.BLACK);
        anotherBackground.scrollFactor.set();
        anotherBackground.alpha = 0;
        anotherBackground.cameras = [camResults];
        add(anotherBackground);

        graph = new HitGraph(FlxG.width - 500, 45, 450, 240);
        graph.alpha = 0;
        graphSprite = new OFLSprite(FlxG.width - 500, 45, 450, 240, graph);
        graphSprite.scrollFactor.set();
        graphSprite.alpha = 0;
        add(graphSprite);
        
        // 创建通用的comboText，稍后根据模式填充内容
        comboText = new FlxText(20, FlxG.height + 100, 400, "");
        comboText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        comboText.borderSize = 4;
        comboText.scrollFactor.set();
        comboText.cameras = [camResults];
        comboText.alpha = 0;
        add(comboText);

        contText = new FlxText(FlxG.width + 100, FlxG.height - 60, 400, 'Press ENTER to continue.');
        contText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
        contText.borderSize = 4;
        contText.scrollFactor.set();
        contText.cameras = [camResults];
        contText.alpha = 0;
        add(contText);

        replayText = new FlxText(-400, FlxG.height - 60, 400, 'F1 - Replay Song');
        replayText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        replayText.borderSize = 4;
        replayText.scrollFactor.set();
        replayText.cameras = [camResults];
        replayText.alpha = 0;
        add(replayText);

        settingsText = new FlxText(0, FlxG.height + 50, FlxG.width, "");
        settingsText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        settingsText.borderSize = 2;
        settingsText.scrollFactor.set();
        settingsText.cameras = [camResults];
        settingsText.alpha = 0;
        add(settingsText);
    }

    override function create()
    {
        super.create();
        
        // 加载数据
        if (isReplayPreview) {
            loadReplayPreviewData();
        } else {
            loadGameResultsData();
        }
        
        // 根据模式更新UI
        updateUIForCurrentMode();
        
        // 开始动画
        startAnimations();
    }
    
    function loadReplayPreviewData():Void
    {
        trace('Loading replay preview data: $replayToLoad');
        
        // 加载回放文件
        loadedReplay = Replay.LoadReplay(replayToLoad);
        
        if (loadedReplay == null || !loadedReplay.isValid()) {
            trace('Cannot load replay from file: $replayToLoad');
            showError("Cannot load replay!");
            return;
        }
        
        // 保存到PlayState以便其他部分访问
        PlayState.rep = loadedReplay;
        
        // 加载数据到图表
        loadRealHitData();
        
        trace('Replay preview data loaded successfully');
    }
    
    function loadGameResultsData():Void
    {
        trace('Loading game results data');
        
        // 加载图表数据
        if (PlayState.rep != null && PlayState.rep.replay != null && PlayState.rep.replay.songNotes.length > 0) {
            loadRealHitData();
        }
        
        // 初始化音乐
        initMusic();
    }
    
    function updateUIForCurrentMode():Void
    {
        if (isReplayPreview) {
            updateUIForReplayPreview();
        } else {
            updateUIForGameResults();
        }
    }
    
    function updateUIForReplayPreview():Void
    {
        if (loadedReplay == null) {
            comboText.text = "Failed to load replay data";
            return;
        }
        
        var rep = loadedReplay.replay;
        
        // 计算各种判定的数量
        var marvelous:Int = 0;
        var sicks:Int = 0;
        var goods:Int = 0;
        var bads:Int = 0;
        var shits:Int = 0;
        var misses:Int = rep.misses != 0 ? rep.misses : 0;
        
        if (rep.songJudgements != null) {
            for (judge in rep.songJudgements) {
                var j = judge.toLowerCase();
                switch (j) {
                    case "marvelous": marvelous++;
                    case "sick": sicks++;
                    case "good": goods++;
                    case "bad": bads++;
                    case "shit": shits++;
                    case "miss": misses++;
                    default: if (j.indexOf("sick") >= 0) sicks++;
                }
            }
        }
        
        var totalNotes = marvelous + sicks + goods + bads + shits + misses;
        var totalHits = totalNotes - misses;
        var accuracy:Float = rep.accuracy != 0 ? rep.accuracy : 
            (totalNotes > 0 ? (totalHits / totalNotes) * 100 : 0);
        
        // 计算最高连击
        var highestCombo:Int = 0;
        var currentCombo:Int = 0;
        if (rep.songJudgements != null) {
            for (judge in rep.songJudgements) {
                if (judge.toLowerCase() == "miss") {
                    if (currentCombo > highestCombo) highestCombo = currentCombo;
                    currentCombo = 0;
                } else {
                    currentCombo++;
                }
            }
            if (currentCombo > highestCombo) highestCombo = currentCombo;
        }
        
        // 更新comboText
        comboText.text = 
            'Judgements:\n' +
            'Marvelous - ${marvelous}\n' +
            'Sicks - ${sicks}\n' +
            'Goods - ${goods}\n' +
            'Bads - ${bads}\n' +
            'Shits - ${shits}\n\n' +
            'Combo Breaks: ${misses}\n' +
            'Highest Combo: ${highestCombo}\n' +
            'Total Notes Hit: ${totalHits}\n' +
            'Score: ${rep.score}\n' +
            'Accuracy: ${truncateFloat(accuracy, 2)}%\n\n' +
            'Rating: ${rep.rating != null ? rep.rating : "N/A"}\n' +
            '${generateLetterRank(accuracy)}\n' +
            'Rate: 1.0x';
        
        // 更新底部设置文本
        var difficultyName:String = rep.difficultyName != null ? rep.difficultyName : "Normal";
        var dateStr = formatDate(rep.timestamp);
        var sfText = (rep.sf != 0) ? 'SF: ${rep.sf} | ' : '';
        var mean = calculateMean();
        var ratioText = calculateRatios(sicks, goods, bads);
        
        settingsText.text = 
            '${sfText}${ratioText} | Mean: ${mean}ms | Played on ${rep.songName} ${difficultyName} | Date: ${dateStr}';
            
        if (rep.modDirectory != null && rep.modDirectory.length > 0 && rep.modDirectory != "") {
            settingsText.text += ' | Mod: ${rep.modDirectory}';
        }
        
        // 更新标题为歌曲名
        text.text = 'REPLAY: ${rep.songName}';
    }
    
    function updateUIForGameResults():Void
    {
        if (gameStats == null) return;
        
        var stats = gameStats;
        var mean = calculateMean();
        var ratioText = calculateRatios(stats.sicks, stats.goods, stats.bads);
        var sfText = (PlayState.rep != null && PlayState.rep.replay != null) ? 'SF: ${PlayState.rep.replay.sf} | ' : '';
        
        // 更新comboText
        comboText.text = 
            'Judgements:\n' +
            'Marvelous - ${stats.marvelous}\n' +
            'Sicks - ${stats.sicks}\n' +
            'Goods - ${stats.goods}\n' +
            'Bads - ${stats.bads}\n' +
            'Shits - ${stats.shits}\n\n' +
            'Combo Breaks: ${stats.misses}\n' +
            'Highest Combo: ${stats.highestCombo}\n' +
            'Total Notes Hit: ${stats.totalNotesHit}\n' +
            'Score: ${stats.score}\n' +
            'Accuracy: ${truncateFloat(stats.accuracy, 2)}%\n\n' +
            '${generateLetterRank(stats.accuracy)}\n' +
            'Rate: ${stats.playbackRate}x';
        
        // 更新底部设置文本
        settingsText.text = 
            '${sfText}${ratioText} | Mean: ${mean}ms | Played on ${stats.songName} ${stats.difficultyName}';
    }

    function initMusic()
    {
        // 只在游戏模式下播放暂停音乐
        if (isReplayPreview) return;
        
        // 先停止当前音乐
        if (FlxG.sound.music != null) {
            FlxG.sound.music.stop();
        }
        
        // 创建音乐对象 - 与pause界面完全相同的逻辑
        pauseMusic = new FlxSound();
        try
        {
            var pauseSong:String = getPauseSong();
            if(pauseSong != null) 
            {
                pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
            }
            else
            {
                // 如果没有指定暂停音乐，使用默认音乐
                pauseMusic.loadEmbedded(Paths.music('breakfast'), true, true);
            }
        }
        catch(e:Dynamic) 
        {
            // 如果出错，使用默认音乐
            pauseMusic.loadEmbedded(Paths.music('breakfast'), true, true);
        }
        
        // 设置音量为0并播放
        pauseMusic.volume = 0;
        pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
        FlxG.sound.list.add(pauseMusic);
        
        // 使用与pause界面相同的渐入逻辑
        FlxTween.tween(pauseMusic, {volume: 1}, 0.8);
    }

    function getPauseSong():String
    {
        // 首先检查 Lua 是否修改了 PauseSubState 的 songName
        var luaSongName:String = getLuaPauseMusic();
        if (luaSongName != null && luaSongName.length > 0) {
            var formattedLuaSong = Paths.formatToSongPath(luaSongName);
            if (formattedLuaSong != 'none') {
                return formattedLuaSong;
            }
        }
        
        // 使用与 PauseSubState 相同的逻辑
        var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
        
        if(formattedPauseMusic == 'none') 
            return null;

        return formattedPauseMusic;
    }

    function getLuaPauseMusic():String
    {
        if (Type.resolveClass("substates.PauseSubState") != null) {
            try {
                var pauseClass = Type.resolveClass("substates.PauseSubState");
                if (Reflect.hasField(pauseClass, "songName")) {
                    var luaMusic:String = Reflect.field(pauseClass, "songName");
                    if (luaMusic != null && luaMusic.length > 0 && luaMusic != 'none') {
                        return luaMusic;
                    }
                }
            } catch (e:Dynamic) {}
        }
        
        if (Type.resolveClass("PauseSubState") != null) {
            try {
                var pauseClass = Type.resolveClass("PauseSubState");
                if (Reflect.hasField(pauseClass, "songName")) {
                    var luaMusic:String = Reflect.field(pauseClass, "songName");
                    if (luaMusic != null && luaMusic.length > 0 && luaMusic != 'none') {
                        return luaMusic;
                    }
                }
            } catch (e:Dynamic) {}
        }
        
        return null;
    }

    function loadRealHitData()
    {
        var rep = PlayState.rep.replay;
        var playbackRate = PlayState.instance != null ? PlayState.instance.playbackRate : 1.0;
        
        for (i in 0...rep.songNotes.length)
        {
            var obj = rep.songNotes[i];
            var obj2 = rep.songJudgements[i];
            
            var diff = obj[3];
            var judge = obj2;
            var time = obj[0];
            
            if (obj[1] != -1) {
                graph.addToHistory(diff / playbackRate, judge, time / playbackRate);
            }
        }
        graph.update();
        if (graphSprite != null) {
            graphSprite.updateDisplay();
        }
    }

    function startAnimations()
    {
        if (animationsStarted) return;
        animationsStarted = true;
        
        new flixel.util.FlxTimer().start(0.05, function(tmr:flixel.util.FlxTimer) {
            
            FlxTween.tween(background, {alpha: 0.7}, 0.4, {ease: FlxEase.quartInOut});
            
            FlxTween.tween(anotherBackground, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
            
            FlxTween.tween(text, {alpha: 1, y: 20}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.3
            });

            FlxTween.tween(comboText, {alpha: 1, y: 80}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.5
            });

            FlxTween.tween(contText, {alpha: 1, x: FlxG.width - 475}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.7
            });

            FlxTween.tween(replayText, {alpha: 1, x: 20}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.7
            });

            FlxTween.tween(settingsText, {alpha: 1, y: FlxG.height - 30}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.9
            });

            FlxTween.tween(graph, {alpha: 1}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.5
            });

            FlxTween.tween(graphSprite, {alpha: 1}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.5
            });
        });
    }

    override function update(elapsed:Float)
    {
        if (!animationsStarted) {
            startAnimations();
        }

        // 更新音乐音量 - 只在游戏模式下
        if (!isReplayPreview && pauseMusic != null && pauseMusic.volume < 0.5) {
            pauseMusic.volume += 0.01 * elapsed;
        }

        if (controls.ACCEPT || FlxG.mouse.justPressed)
        {
            closeResults();
        }

        if (FlxG.keys.justPressed.F1 || FlxG.mouse.justPressedRight)
        {
            replaySong();
        }

        super.update(elapsed);
    }

    function closeResults()
    {
        // 音乐渐出 - 只在游戏模式下
        if (!isReplayPreview && pauseMusic != null && pauseMusic.playing)
        {
            FlxTween.tween(pauseMusic, {volume: 0}, 0.5, {
                onComplete: function(twn:FlxTween) {
                    finishClose();
                }
            });
        }
        else
        {
            finishClose();
        }

        FlxTween.tween(background, {alpha: 0}, 0.3);
        FlxTween.tween(text, {alpha: 0}, 0.3);
        FlxTween.tween(comboText, {alpha: 0}, 0.3);
        FlxTween.tween(contText, {alpha: 0}, 0.3);
        FlxTween.tween(replayText, {alpha: 0}, 0.3);
        FlxTween.tween(settingsText, {alpha: 0}, 0.3);
        FlxTween.tween(anotherBackground, {alpha: 0}, 0.3);
        FlxTween.tween(graph, {alpha: 0}, 0.3);
        FlxTween.tween(graphSprite, {alpha: 0}, 0.3);
    }

    function finishClose()
    {
        if (pauseMusic != null) {
            pauseMusic.stop();
        }
        FlxG.cameras.remove(camResults);
        
        if (isReplayPreview) {
            // 回放预览模式：直接关闭
            close();
        } else {
            // 游戏模式：继续游戏流程
            var playState = PlayState.instance;
            playState.proceedToNextState();
        }
    }

    function replaySong()
    {
        if (isReplayPreview) {
            // 回放预览模式：直接加载并播放回放
            if (replayToLoad != null) {
                trace('Loading replay from preview: $replayToLoad');
                finishReplay();
            }
        } else {
            // 游戏模式：重新开始歌曲
            if (pauseMusic != null && pauseMusic.playing)
            {
                FlxTween.tween(pauseMusic, {volume: 0}, 0.5, {
                    onComplete: function(twn:FlxTween) {
                        finishReplay();
                    }
                });
            }
            else
            {
                finishReplay();
            }

            FlxTween.tween(background, {alpha: 0}, 0.3);
            FlxTween.tween(text, {alpha: 0}, 0.3);
            FlxTween.tween(comboText, {alpha: 0}, 0.3);
            FlxTween.tween(contText, {alpha: 0}, 0.3);
            FlxTween.tween(replayText, {alpha: 0}, 0.3);
            FlxTween.tween(settingsText, {alpha: 0}, 0.3);
            FlxTween.tween(anotherBackground, {alpha: 0}, 0.3);
            FlxTween.tween(graph, {alpha: 0}, 0.3);
            FlxTween.tween(graphSprite, {alpha: 0}, 0.3);
        }
    }

    function finishReplay()
    {
        if (pauseMusic != null) {
            pauseMusic.stop();
        }
        FlxG.cameras.remove(camResults);
        
        if (isReplayPreview) {
            // 回放预览模式：加载回放
            var loadState = new LoadReplayState();
            loadState.loadReplay(replayToLoad);
        } else {
            // 游戏模式：重新开始游戏
            PlayState.isStoryMode = false;
            LoadingState.loadAndSwitchState(new PlayState());
        }
    }

    override function destroy()
    {
        if (pauseMusic != null) {
            pauseMusic.destroy();
        }
        
        if (camResults != null && FlxG.cameras.list.contains(camResults))
        {
            FlxG.cameras.remove(camResults);
        }
        super.destroy();
        
        // 只在游戏模式切换回菜单音乐
        if (!isReplayPreview) {
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
        }
    }

    // ========== 工具函数 ==========
    
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
    
    function truncateFloat(number:Float, precision:Int):Float
    {
        if (Math.isNaN(number)) return 0.0;
        var num = number;
        num = num * Math.pow(10, precision);
        num = Math.round(num) / Math.pow(10, precision);
        return num;
    }

    function generateLetterRank(accuracy:Float):String
    {
        if (accuracy >= 99) return "S+";
        else if (accuracy >= 95) return "S";
        else if (accuracy >= 90) return "A";
        else if (accuracy >= 80) return "B";
        else if (accuracy >= 70) return "C";
        else if (accuracy >= 60) return "D";
        else return "F";
    }

    function calculateMean():Float
    {
        if (graph.history.length == 0) return 0.0;
        
        var sum:Float = 0;
        var validCount:Int = 0;
        
        for (hit in graph.history)
        {
            var diff = hit[0];
            if (Math.abs(diff) < 200) {
                sum += diff;
                validCount++;
            }
        }
        
        if (validCount == 0) return 0.0;
        return truncateFloat(sum / validCount, 2);
    }

    function calculateRatios(sicks:Int, goods:Int, bads:Int):String
    {
        var sickRatio = goods > 0 ? truncateFloat(sicks / goods, 1) : 0;
        var goodRatio = bads > 0 ? truncateFloat(goods / bads, 1) : 0;
        
        if (sickRatio == Math.POSITIVE_INFINITY || Math.isNaN(sickRatio)) sickRatio = 0;
        if (goodRatio == Math.POSITIVE_INFINITY || Math.isNaN(goodRatio)) goodRatio = 0;
        
        return 'Ratio (S/G): ${Math.round(sickRatio)}:1 ${Math.round(goodRatio)}:1';
    }
    
    function showError(message:String):Void
    {
        var errorText = new FlxText(0, FlxG.height / 2 - 20, FlxG.width, message, 24);
        errorText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
        errorText.borderSize = 2;
        errorText.screenCenter(X);
        errorText.cameras = [camResults];
        add(errorText);
        
        new FlxTimer().start(3, function(tmr:FlxTimer) {
            remove(errorText);
            errorText.destroy();
        });
    }
}