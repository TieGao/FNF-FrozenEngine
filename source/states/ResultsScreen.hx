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

    public function new()
    {
        if (PlayState.isStoryMode && PlayState.storyPlaylist.length > 1)
        {
            var playState = PlayState.instance;
            playState.proceedToNextState();
        }
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

        var playState = PlayState.instance;
        var score = playState.songScore;
        if (PlayState.isStoryMode)
        {
            text.text = "Week Cleared!";
        }

        var ratingsData = playState.ratingsData;
        var sicks:Int = 0;
        var goods:Int = 0;
        var bads:Int = 0;
        var shits:Int = 0;
        
        if (ratingsData != null && ratingsData.length >= 4)
        {
            sicks = ratingsData[0].hits;
            goods = ratingsData[1].hits;
            bads = ratingsData[2].hits;
            shits = ratingsData[3].hits;
        }
        
        var misses = playState.songMisses;
        
        var highestCombo = playState.highestCombo;
        
        var totalNotesHit = sicks + goods + bads + shits;
        
        var totalNotes = sicks + goods + bads + shits + misses;
        var accuracy:Float = 0;
        if (totalNotes > 0) {
            accuracy = (sicks * 1.0 + goods * 0.75 + bads * 0.25) / totalNotes * 100;
        }

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

        if (PlayState.rep != null && PlayState.rep.replay != null && PlayState.rep.replay.songNotes.length > 0) {
            loadRealHitData();
        } 

        graph.update();

        var mean = calculateMean();
        var ratioText = calculateRatios(sicks, goods, bads);

        comboText = new FlxText(20, FlxG.height + 100, 400,
            'Judgements:\n' +
            'Sicks - ${sicks}\n' +
            'Goods - ${goods}\n' +
            'Bads - ${bads}\n' +
            'Shits - ${shits}\n\n' +
            'Combo Breaks: ${misses}\n' +
            'Highest Combo: ${highestCombo}\n' +
            'Total Notes Hit: ${totalNotesHit}\n' +
            'Score: ${score}\n' +
            'Accuracy: ${truncateFloat(accuracy, 2)}%\n\n' +
            '${generateLetterRank(accuracy)}\n' +
            'Rate: ${playState.playbackRate}x'
        );
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

        var difficultyName:String = Difficulty.getString();
        
        var sfText = (PlayState.rep != null && PlayState.rep.replay != null) ? 'SF: ${PlayState.rep.replay.sf} | ' : '';
        settingsText = new FlxText(0, FlxG.height + 50, FlxG.width, 
            '${sfText}${ratioText} | Mean: ${mean}ms | Played on ${PlayState.SONG.song} ${difficultyName}'
        );
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
        
        // 初始化音乐 - 使用与pause界面相同的逻辑
        initMusic();
        startAnimations();
    }

    function initMusic()
    {
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
        var playbackRate = PlayState.instance.playbackRate;
        
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

        // 更新音乐音量 - 与pause界面相同的逻辑
        if (pauseMusic != null && pauseMusic.volume < 0.5)
            pauseMusic.volume += 0.01 * elapsed;

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
        #if sys
        if (PlayState.rep != null && PlayState.rep.replay != null && PlayState.rep.replay.songNotes.length > 0) {
            try {
                PlayState.rep.SaveReplay(PlayState.rep.replay.songNotes, PlayState.rep.replay.songJudgements, PlayState.rep.replay.ana);
            } catch (e:Dynamic) {}
        }
        #end

        // 音乐渐出 - 使用与pause界面退出时相同的逻辑
        if (pauseMusic != null && pauseMusic.playing)
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
        var playState = PlayState.instance;
        playState.proceedToNextState();
    }

    function replaySong()
    {
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

    function finishReplay()
    {
        if (pauseMusic != null) {
            pauseMusic.stop();
        }
        FlxG.cameras.remove(camResults);
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
        FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
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
}