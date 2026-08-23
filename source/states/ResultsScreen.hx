package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.sound.FlxSound;

import backend.Replay;
import backend.HitGraph;
import backend.OFLSprite;

enum ResultsMode {
    NORMAL;         // 正常游戏结算
    REPLAY_END;     // 游戏后回放结束
}

class ResultsScreen extends MusicBeatSubstate
{
    public var background:FlxSprite;
    public var text:FlxText;
    public var comboText:FlxText;
    public var contText:FlxText;
    public var settingsText:FlxText;
    public var replayText:FlxText;
    public var replayLibText:FlxText;

    public var anotherBackground:FlxSprite;
    public var graph:HitGraph;
    public var graphSprite:OFLSprite;

    public var camResults:FlxCamera;
    
    public var pauseMusic:FlxSound;

    var animationsStarted:Bool = false;
    public var replayToLoad:String = null;
    
    // 模式标识
    var mode:ResultsMode;
    var loadedReplay:Replay = null;
    
    // 存储游戏统计数据
    var gameStats:Dynamic = null;

    // 构造函数 - 支持两种模式
    public function new(?mode:ResultsMode, ?replayFile:String = null)
    {
        this.mode = mode != null ? mode : NORMAL;
        this.replayToLoad = replayFile;
        
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

        text = new FlxText(0, -100, FlxG.width, "");
        text.setFormat(Paths.font("vcr.ttf"), 34, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        text.borderSize = 4;
        text.scrollFactor.set();
        text.cameras = [camResults];
        text.antialiasing = ClientPrefs.data.antialiasing;
        text.alpha = 0;
        add(text);

        // 根据模式设置标题
        switch(mode) {
            case NORMAL:
                if (PlayState.isStoryMode)
                    text.text = "Week Cleared!";
                else
                    text.text = "Song Cleared!";
                collectGameStats();
                
            case REPLAY_END:
                text.text = "REPLAY FINISHED";
                text.color = FlxColor.YELLOW;
                collectGameStats();
        }
        
        // 创建通用UI元素
        createCommonUI();
        
        trace('ResultsScreen created. Mode: $mode');
    }

    // 为了兼容旧代码，保留原有的构造函数
    public static function forGameResults():ResultsScreen {
        return new ResultsScreen(NORMAL);
    }

    public static function forReplayEnd():ResultsScreen {
        return new ResultsScreen(REPLAY_END);
    }
    
    function collectGameStats():Void
    {
        // 回放结束模式下不收集数据（数据已存在）
        if (mode == REPLAY_END && PlayState.rep != null) return;
        
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
        var accuracy:Float = PlayState.instance.ratingPercent * 100;
        var songScore = playState.songScore;
        var songName = PlayState.SONG.song;
        var difficulty = Difficulty.getString();
        var isFullCombo = (misses == 0);
        var isPerfectClear = (misses == 0 && shits == 0 && bads == 0);
        var difficultyIndex = getDifficultyIndex(difficulty);
        
        // 保存游戏统计数据
        gameStats = {
            songName: songName,
            score: songScore,
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
            difficultyName: difficulty,
            isFullCombo: isFullCombo,
            isPerfectClear: isPerfectClear
        };
        
        if (mode == REPLAY_END) return;
        // ========== 保存统计数据到 ClientPrefs ==========
        saveGameStatsToClientPrefs();
    }

    function getDifficultyIndex(difficulty:String):Int
    {
        var diffLower = difficulty.toLowerCase();
        if (diffLower.indexOf('easy') >= 0) return 0;
        if (diffLower.indexOf('normal') >= 0) return 1;
        if (diffLower.indexOf('hard') >= 0) return 2;
        return 1; // 默认 Normal
    }

    function saveGameStatsToClientPrefs():Void
    {
        if (gameStats == null) return;
        
        var stats = gameStats;
        
        // 累计总分
        ClientPrefs.data.totalScore += stats.score;
        
        // 总游玩次数
        ClientPrefs.data.totalPlays++;
        
        // 通关次数（只有通关才算，游戏结束不算）
        ClientPrefs.data.totalSongsCleared++;
        
        // 累计各种判定
        ClientPrefs.data.totalMarvelous += stats.marvelous;
        ClientPrefs.data.totalSicks += stats.sicks;
        ClientPrefs.data.totalGoods += stats.goods;
        ClientPrefs.data.totalBads += stats.bads;
        ClientPrefs.data.totalShits += stats.shits;
        ClientPrefs.data.totalMisses += stats.misses;
        
        // 历史最高分（单曲）
        if (stats.score > ClientPrefs.data.highestScore) {
            ClientPrefs.data.highestScore = stats.score;
        }
        
        // 历史最高连击
        if (stats.highestCombo > ClientPrefs.data.highestCombo) {
            ClientPrefs.data.highestCombo = stats.highestCombo;
        }
        
        // 历史最高准确率
        if (stats.accuracy > ClientPrefs.data.bestAccuracy) {
            ClientPrefs.data.bestAccuracy = stats.accuracy;
        }
        
        // 完美通关
        if (stats.isPerfectClear) {
            ClientPrefs.data.perfectClears++;
        }
        
        // Full Combo（无Miss）
        if (stats.isFullCombo) {
            ClientPrefs.data.fullComboCount++;
        }
        
        // 各难度通关次数
        var diffIndex = getDifficultyIndex(stats.difficultyName);
        ClientPrefs.data.songsByDifficulty[diffIndex]++;
        
        // 保存到文件
        ClientPrefs.saveSettings();
        
        trace('Game stats saved! Total Score: ${ClientPrefs.data.totalScore}, Total Plays: ${ClientPrefs.data.totalPlays}');
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
        comboText.antialiasing = ClientPrefs.data.antialiasing;
        add(comboText);

        // 根据模式设置不同的提示文本
        switch(mode) {
            case NORMAL, REPLAY_END:
                contText = new FlxText(FlxG.width + 100, FlxG.height - 60, 400, 'Press ENTER to continue');
        }
        contText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
        contText.borderSize = 4;
        contText.scrollFactor.set();
        contText.cameras = [camResults];
        contText.alpha = 0;
        contText.antialiasing = ClientPrefs.data.antialiasing;
        add(contText);

        // F1 - 回放当前歌曲 (在所有模式下都可用)
        replayLibText = new FlxText(-400, FlxG.height - 100, 400, 'F1 - Replay This Song');
        replayLibText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.CYAN, LEFT, OUTLINE, FlxColor.BLACK);
        replayLibText.borderSize = 4;
        replayLibText.scrollFactor.set();
        replayLibText.cameras = [camResults];
        replayLibText.alpha = 0;
        replayLibText.antialiasing = ClientPrefs.data.antialiasing;
        add(replayLibText);

        // F2 - 重新开始
        replayText = new FlxText(-400, FlxG.height - 60, 400, 'F2 - Replay Song');
        replayText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        replayText.borderSize = 4;
        replayText.scrollFactor.set();
        replayText.cameras = [camResults];
        replayText.alpha = 0;
        replayText.antialiasing = ClientPrefs.data.antialiasing;
        add(replayText);

        settingsText = new FlxText(0, FlxG.height + 50, FlxG.width, "");
        settingsText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        settingsText.borderSize = 2;
        settingsText.scrollFactor.set();
        settingsText.cameras = [camResults];
        settingsText.alpha = 0;
        settingsText.antialiasing = ClientPrefs.data.antialiasing;
        add(settingsText);
    }

    override function create()
    {
        super.create();
        
        // 根据模式加载数据
        switch(mode) {
            case NORMAL, REPLAY_END:
                if (mode == REPLAY_END && PlayState.rep != null) {
                    loadReplayData();
                } else if (PlayState.rep != null && PlayState.rep.replay != null) {
                    loadRealHitData();
                }
                updateUIForGameResults();
        }
        
        // 初始化音乐 (所有模式)
        initMusic();
        
        // 开始动画
        startAnimations();
    }
    
    function loadReplayData():Void
    {
        trace('Loading replay data for REPLAY_END mode');
        
        // 从 PlayState.rep 获取回放数据
        loadedReplay = PlayState.rep;
        
        if (loadedReplay == null || !loadedReplay.isValid()) {
            trace('Cannot load replay from PlayState.rep');
            showError("Cannot load replay data!");
            return;
        }
        
        // 加载数据到图表
        loadRealHitData();
        
        trace('Replay data loaded successfully');
    }
    
    function updateUIForGameResults():Void
    {
        if (gameStats == null) {
            // 如果 gameStats 为空，尝试从回放数据构建
            if (loadedReplay != null) {
                buildStatsFromReplay();
            }
            return;
        }
        
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

    function buildStatsFromReplay():Void
    {
        if (loadedReplay == null) return;
        
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
        
        gameStats = {
            songName: rep.songName,
            score: rep.score,
            accuracy: accuracy,
            marvelous: marvelous,
            sicks: sicks,
            goods: goods,
            bads: bads,
            shits: shits,
            misses: misses,
            highestCombo: highestCombo,
            totalNotes: totalNotes,
            totalNotesHit: totalHits,
            ratingName: rep.rating != null ? rep.rating : "N/A",
            ratingFC: rep.ratingFC != null ? rep.ratingFC : "N/A",
            playbackRate: 1.0,
            difficultyName: rep.difficultyName != null ? rep.difficultyName : "Normal",
            isFullCombo: (misses == 0),
            isPerfectClear: (misses == 0 && shits == 0 && bads == 0)
        };
        
        // 如果是回放结束模式，更新标题
        if (mode == REPLAY_END) {
            text.text = 'REPLAY FINISHED: ${rep.songName}';
        }
    }

    function initMusic()
    {
        // 停止当前音乐
        if (FlxG.sound.music != null) {
            FlxG.sound.music.stop();
        }
        
        // 创建音乐对象
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
                pauseMusic.loadEmbedded(Paths.music('breakfast'), true, true);
            }
        }
        catch(e:Dynamic) 
        {
            pauseMusic.loadEmbedded(Paths.music('breakfast'), true, true);
        }
        
        pauseMusic.volume = 0;
        pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
        FlxG.sound.list.add(pauseMusic);
        
        FlxTween.tween(pauseMusic, {volume: 1}, 0.8);
    }

    function getPauseSong():String
    {
        var luaSongName:String = getLuaPauseMusic();
        if (luaSongName != null && luaSongName.length > 0) {
            var formattedLuaSong = Paths.formatToSongPath(luaSongName);
            if (formattedLuaSong != 'none') {
                return formattedLuaSong;
            }
        }
        
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
            if (obj == null) continue;

            // safe-get judgement
            var obj2:Dynamic = "";
            if (rep.songJudgements != null && i < rep.songJudgements.length) obj2 = rep.songJudgements[i];

            // ensure types and defaults
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

            // only add if note is not a special -1 sustain marker
            if (obj.length > 1 && obj[1] != -1) {
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

            FlxTween.tween(replayLibText, {alpha: 1, x: 20}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.7
            });

            FlxTween.tween(replayText, {alpha: 1, x: 20}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 0.9
            });

            FlxTween.tween(settingsText, {alpha: 1, y: FlxG.height - 30}, 0.4, {
                ease: FlxEase.quartInOut,
                startDelay: 1.1
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

        // 更新音乐音量
        if (pauseMusic != null && pauseMusic.volume < 0.5) {
            pauseMusic.volume += 0.01 * elapsed;
        }
        
        // 根据模式处理输入
        switch(mode) {
            case NORMAL, REPLAY_END:
                if (controls.BACK || controls.ACCEPT || FlxG.mouse.justPressed) {
                    closeResults();
                }
        }
        
        // F1 - 回放当前歌曲 (在所有模式下)
        if (FlxG.keys.justPressed.F1) {
            replayCurrentSong();
        }
        
        // F2 - 重新开始
        if (FlxG.keys.justPressed.F2) {
            restartSong();
        }

        super.update(elapsed);
    }

    function closeResults()
    {
        // 音乐渐出
        if (pauseMusic != null && pauseMusic.playing && !ClientPrefs.data.skipResultExitAnim)
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

        if (ClientPrefs.data.skipResultExitAnim) return;
        FlxTween.tween(background, {alpha: 0}, 0.3);
        FlxTween.tween(text, {alpha: 0}, 0.3);
        FlxTween.tween(comboText, {alpha: 0}, 0.3);
        FlxTween.tween(contText, {alpha: 0}, 0.3);
        FlxTween.tween(replayLibText, {alpha: 0}, 0.3);
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
        
        switch(mode) {
            case NORMAL, REPLAY_END:
                var playState = PlayState.instance;
                if (playState != null) {
                    playState.proceedToNextState();
                } else {
                    close();
                }
        }
    }

    /**
     * 回放当前歌曲 - 进入录制模式
     */
    function replayCurrentSong()
    {
        trace('Replaying current song from ResultsScreen');
        
        var playState = PlayState.instance;
        if (playState == null) {
            trace('ERROR: PlayState.instance is null, cannot replay song');
            FlxG.sound.play(Paths.sound('cancelMenu'));
            return;
        }
        
        if (PlayState.SONG == null) {
            trace('ERROR: PlayState.SONG is null, cannot replay song');
            FlxG.sound.play(Paths.sound('cancelMenu'));
            return;
        }
        
        // 停止音乐
        if (pauseMusic != null) {
            pauseMusic.stop();
        }
        
        // 移除相机
        FlxG.cameras.remove(camResults);
        
        // 设置回放录制模式
        var rep = new Replay("");
        PlayState.rep = rep;
        PlayState.loadRep = false;
        PlayState.inReplay = false;
        PlayState.replayFileName = null;
        
        // 保留当前歌曲数据
        PlayState.isStoryMode = false;
        
        // 停止所有声音
        if (FlxG.sound.music != null) {
            FlxG.sound.music.stop();
        }
        
        trace('Starting replay recording for: ${PlayState.SONG.song}');
        
        // 使用 LoadingState 切换到 PlayState
        LoadingState.loadAndSwitchState(new PlayState());
    }

    function restartSong()
    {
        trace('Restarting song from ResultsScreen');
        
        if (pauseMusic != null && pauseMusic.playing)
        {
            FlxTween.tween(pauseMusic, {volume: 0}, 0.5, {
                onComplete: function(twn:FlxTween) {
                    finishRestart();
                }
            });
        }
        else
        {
            finishRestart();
        }

        FlxTween.tween(background, {alpha: 0}, 0.3);
        FlxTween.tween(text, {alpha: 0}, 0.3);
        FlxTween.tween(comboText, {alpha: 0}, 0.3);
        FlxTween.tween(contText, {alpha: 0}, 0.3);
        FlxTween.tween(replayLibText, {alpha: 0}, 0.3);
        FlxTween.tween(replayText, {alpha: 0}, 0.3);
        FlxTween.tween(settingsText, {alpha: 0}, 0.3);
        FlxTween.tween(anotherBackground, {alpha: 0}, 0.3);
        FlxTween.tween(graph, {alpha: 0}, 0.3);
        FlxTween.tween(graphSprite, {alpha: 0}, 0.3);
    }

    function finishRestart()
    {
        if (pauseMusic != null) {
            pauseMusic.stop();
        }
        FlxG.cameras.remove(camResults);
        
        // 重新开始游戏
        PlayState.isStoryMode = false;
        LoadingState.loadAndSwitchState(new PlayState());
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
        
        // 只有在正常游戏模式下才切换回菜单音乐
        if (mode == NORMAL) {
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