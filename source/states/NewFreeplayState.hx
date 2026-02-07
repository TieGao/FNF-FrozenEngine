package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.SongArtConfig;

import objects.HealthIcon;
import objects.NewMusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;

import openfl.utils.Assets;

import haxe.Json;

import flixel.addons.display.FlxBackdrop;

class NewFreeplayState extends MusicBeatState
{
    var songs:Array<NewSongMetaData> = [];
    var cards:Array<FreeplayCard> = [];

    private static var curSelected:Int = 0;
    private var lerpSelected:Float = 0;
    
    var space:FlxSprite;
    var starsBG:FlxBackdrop;
    var starsFG:FlxBackdrop;
    
    var menuBg:FlxSprite;
    var intendedColor:Int;
    
    var cornerGlow:FlxSprite;
    var songArt:FlxSprite;
    var songArtTweening:Bool = false;
    var currentArtPath:String = ""; // 当前显示的艺术图路径
    
    var characterSprite:FlxSprite;
    var characterTweening:Bool = false;
    var currentCharacterArtPath:String = "";

    var scoreBG:FlxSprite;
    var scoreText:FlxText;
    var diffText:FlxText;
    var lerpScore:Int = 0;
    var lerpRating:Float = 0;
    var intendedScore:Int = 0;
    var intendedRating:Float = 0;
    
    var curDifficulty:Int = -1;
    private static var lastDifficultyName:String = Difficulty.getDefault();
    
    var bottomString:String;
    var bottomText:FlxText;
    var bottomBG:FlxSprite;
    
    var topBar:FlxSprite;
    
    var instPlaying:Int = -1;
    public static var vocals:FlxSound = null;
    public static var opponentVocals:FlxSound = null;
    var holdTime:Float = 0;
    var stopMusicPlay:Bool = false;
    
    var mouseOverCard:Int = -1;
    
    var musicPlayer:NewMusicPlayer;
    
    var updateTimer:Float = 0;
    var updateInterval:Float = 0.016;

    override function create()
    {
        
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory();
        
        persistentUpdate = true;
        PlayState.isStoryMode = false;
        WeekData.reloadWeekFiles(false);

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Freeplay Menu", null);
        #end

        if(WeekData.weeksList.length < 1)
        {
            MusicBeatState.switchState(new MainMenuState());
            return;
        }

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
        
        Mods.loadTopMod();

        SongArtConfig.loadAllConfigs();
        // 预加载所有歌曲艺术图
        preloadConfiguredArts();

        
        // 4. 原版菜单背景（带颜色渐变）
        menuBg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        menuBg.antialiasing = ClientPrefs.data.antialiasing;
        menuBg.alpha = 0.4;
        add(menuBg);
        menuBg.screenCenter();
        
          // 1. 太空背景层
        space = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        space.antialiasing = ClientPrefs.data.antialiasing;
        space.updateHitbox();
        space.scrollFactor.set();
        space.alpha = 0;
        add(space);

        // 2. 背景星空
        starsBG = new FlxBackdrop(Paths.image('freeplay/starBG'));
        starsBG.setPosition(111.3, 67.95);
        starsBG.antialiasing = true;
        starsBG.updateHitbox();
        starsBG.scrollFactor.set();
        starsBG.alpha = 0;
        add(starsBG);

        // 3. 前景星空
        starsFG = new FlxBackdrop(Paths.image('freeplay/starFG'));
        starsFG.setPosition(54.3, 59.45);
        starsFG.updateHitbox();
        starsFG.antialiasing = true;
        starsFG.scrollFactor.set();
        starsFG.alpha = 0;
        add(starsFG);


        
        // 5. 右下角发光效果
        cornerGlow = new FlxSprite().loadGraphic(Paths.image('freeplay/backGlow'));
        cornerGlow.antialiasing = true;
        cornerGlow.updateHitbox();
        cornerGlow.scrollFactor.set();
        cornerGlow.color = FlxColor.RED;
        cornerGlow.alpha = 0;
        cornerGlow.x = FlxG.width - cornerGlow.width + 100;
        cornerGlow.y = FlxG.height - cornerGlow.height + 120;
        add(cornerGlow); 

        characterSprite = new FlxSprite(FlxG.width + 300, FlxG.height * 0.4);
        characterSprite.antialiasing = ClientPrefs.data.antialiasing;
        characterSprite.scrollFactor.set();
        characterSprite.visible = false;
        add(characterSprite);


        if (ClientPrefs.data.freeplayspace)
        {
            space.alpha = 1;
            starsBG.alpha = 1;
            starsFG.alpha = 1;
            cornerGlow.alpha = 0.7;
        }
        
        // 创建卡片
        cards = [];
        for (i in 0...songs.length)
        {
            var oldModDir = Mods.currentModDirectory;
            Mods.currentModDirectory = songs[i].folder;
            
            var card = new FreeplayCard(0, 0, songs[i].songName, songs[i].songCharacter, songs[i].color, songs[i].week);
            card.targetY = i;
            cards.push(card);
            add(card);
            
            Mods.currentModDirectory = oldModDir;
        }

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

        topBar = new FlxSprite(0, 0 ).loadGraphic(Paths.image('freeplay/topBar'));
        topBar.alpha = 0.8;
        add(topBar);

        bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
        bottomBG.alpha = 0.6;
        add(bottomBG);

        var leText:String = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
        bottomString = leText;
        var size:Int = 16;
        bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
        bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
        bottomText.scrollFactor.set();
        add(bottomText);

        // 新增：创建音乐播放器
        musicPlayer = new NewMusicPlayer(this);
        add(musicPlayer);
        
        // 初始设置
        if(curSelected >= songs.length) curSelected = 0;
        menuBg.color = songs[curSelected].color;
        intendedColor = menuBg.color;
        lerpSelected = curSelected;

        curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));
        
        // 初始化选中项
        Mods.currentModDirectory = songs[curSelected].folder;
        PlayState.storyWeek = songs[curSelected].week;
        Difficulty.loadFromWeek();
        
        changeDiff();
        
        // 创建艺术图精灵
        songArt = new FlxSprite(-150, FlxG.height/2);
        songArt.visible = false;
        songArt.antialiasing = true;
        songArt.scrollFactor.set();
        add(songArt);

        // 在初始选择时直接显示（无出入动画）
        showSongArtForIndex(curSelected, false);

        // 在初始选择时显示人物
        showCharacterArtForIndex(curSelected, false);

        // 更新右下角发光颜色
        updateCornerGlow();
        
        // 初始更新卡片位置
        updateCardsPosition();

        updateCardsRating();
        
        // 显示鼠标
        FlxG.mouse.visible = true;
        
        super.create();
    }

    // 预加载所有歌曲艺术图
    function preloadSongArts()
    {
        for (song in songs)
        {
            try
            {
                var oldDir = Mods.currentModDirectory;
                Mods.currentModDirectory = song.folder;
                
                // 尝试加载艺术图
                Paths.getSongGraphic(song.songName);
                
                Mods.currentModDirectory = oldDir;
            }
            catch(e:Dynamic)
            {
                // 有些歌曲可能没有艺术图，忽略错误
            }
        }
    }

    override function closeSubState()
    {
        changeSelection(0, false);
        persistentUpdate = true;
        super.closeSubState();
    }

    public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
    {
        var song = new NewSongMetaData(songName, weekNum, songCharacter, color);
        song.folder = Mods.currentModDirectory;
        songs.push(song);
    }

    function weekIsLocked(name:String):Bool
    {
        var leWeek:WeekData = WeekData.weeksLoaded.get(name);
        return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
    }

    function updateCardsRating()
        for (card in cards)
        {
            card.updateRatingSprite();
        }

    function updateCardsPosition()
    {
        for (card in cards)
        {
            var distance = Math.abs(card.targetY - lerpSelected);
            var isVisible = distance <= 5;
            card.updatePosition(lerpSelected, isVisible);
        }
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
    
    // 更新右下角发光颜色
    function updateCornerGlow()
    {
        if (cornerGlow != null)
        {
            var targetColor = songs[curSelected].color;
            FlxTween.cancelTweensOf(cornerGlow);
            FlxTween.color(cornerGlow, 0.5, cornerGlow.color, targetColor);
        }
    }
    
    function togglePlaySong()
    {
        // 如果正在播放，停止播放
        if (musicPlayer.playingMusic)
        {
            musicPlayer.stopMusic();
            return;
        }
        
        // 开始播放当前选中的歌曲
        var songName:String = songs[curSelected].songName;
        var songLowercase:String = Paths.formatToSongPath(songName);
        var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
        
        try
        {
            destroyFreeplayVocals();
            
            var oldModDirectory = Mods.currentModDirectory;
            Mods.currentModDirectory = songs[curSelected].folder;
            
            // 检查文件是否存在
            var chartPath:String = Paths.modsJson(songLowercase + '/' + poop);
            if (!sys.FileSystem.exists(chartPath))
            {
                chartPath = Paths.json(songLowercase + '/' + poop);
                if (!sys.FileSystem.exists(chartPath))
                {
                    Mods.currentModDirectory = oldModDirectory;
                    throw new haxe.Exception('Chart file not found: $poop');
                }
            }
            
            PlayState.SONG = Song.loadFromJson(poop, songLowercase);
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDifficulty;
            
            #if DISCORD_ALLOWED
            DiscordClient.changePresence("Freeplay - Listening to " + songName, null);
            #end
            
            if (FlxG.sound.music != null)
                FlxG.sound.music.stop();
            
            FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7, false);
            
            // 设置播放完成回调
            FlxG.sound.music.onComplete = function()
            {
                //trace("Music completed, stopping player...");
                destroyFreeplayVocals();
                FlxG.sound.music.time = 0;
                if (musicPlayer.playingMusic)
                    musicPlayer.stopMusic();
            };
            
            // 加载人声
            vocals = new FlxSound();
            if (PlayState.SONG.needsVoices)
                vocals.loadEmbedded(Paths.voices(PlayState.SONG.song));
            else
                vocals.loadEmbedded(Paths.voices(PlayState.SONG.song, "empty"));
            
            FlxG.sound.list.add(vocals);
            
            opponentVocals = new FlxSound();
            opponentVocals.loadEmbedded(Paths.voices(PlayState.SONG.song, "empty"));
            FlxG.sound.list.add(opponentVocals);
            
            // 重要：必须先设置为true再调用switchPlayMusic
            musicPlayer.playingMusic = true;
            musicPlayer.switchPlayMusic();
            
            Mods.currentModDirectory = oldModDirectory;
        }
        catch(e:haxe.Exception)
        {
            trace('ERROR: ${e.message}');
            FlxG.sound.play(Paths.sound('cancelMenu'));
            
            var errorMessage = e.message;
            var errorText = new FlxText(0, FlxG.height/2 - 50, FlxG.width, 'Error: $errorMessage', 24);
            errorText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
            errorText.borderColor = FlxColor.BLACK;
            errorText.borderSize = 2;
            add(errorText);
            
            FlxG.sound.music.stop();
            
            new FlxTimer().start(2, function(tmr:FlxTimer)
            {
                remove(errorText);
                
                if (FlxG.sound.music == null || !FlxG.sound.music.playing)
                    FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
            });
        }
    }

    override function update(elapsed:Float)
    {
        if(WeekData.weeksList.length < 1)
            return;

        // 星空背景滚动
        starsBG.x -= 0.05;
        starsFG.x -= 0.15;
        
        if (starsBG.x < -starsBG.width) starsBG.x = 0;
        if (starsFG.x < -starsFG.width) starsFG.x = 0;

        // 背景音乐 - 仅在未播放音乐时恢复音量
        if (FlxG.sound.music.volume < 0.7 && !musicPlayer.playingMusic)
            FlxG.sound.music.volume += 0.5 * elapsed;

        // 平滑过渡分数
        lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
        lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

        if (Math.abs(lerpScore - intendedScore) <= 10)
            lerpScore = intendedScore;
        if (Math.abs(lerpRating - intendedRating) <= 0.01)
            lerpRating = intendedRating;

        // 平滑选择过渡
        lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
        
        // 控制更新频率
        updateTimer += elapsed;
        if (updateTimer >= updateInterval)
        {
            updateCardsPosition();
            updateTexts();
            updateTimer = 0;
        }

        // 鼠标交互 - 仅在未播放音乐时可用
        if (!musicPlayer.playingMusic)
        {
            updateMouseInteraction();
        }

        var shiftMult:Int = 1;
        if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

        // 鼠标滚轮 - 仅在未播放音乐时可用
        if (FlxG.mouse.wheel != 0 && songs.length > 1 && !musicPlayer.playingMusic)
        {
            var wheelShiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
            changeSelection(-wheelShiftMult * FlxG.mouse.wheel, false);
        }

        // 键盘导航 - 仅在未播放音乐时可用
        if(songs.length > 1 && !musicPlayer.playingMusic)
        {
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

        // 难度切换 - 仅在未播放音乐时可用
        if (controls.UI_LEFT_P && !musicPlayer.playingMusic)
        {
            changeDiff(-1);
            _updateSongLastDifficulty();
        }
        else if (controls.UI_RIGHT_P && !musicPlayer.playingMusic)
        {
            changeDiff(1);
            _updateSongLastDifficulty();
        }

        // 返回
        if (controls.BACK || FlxG.mouse.justPressedRight)
        {
            if (musicPlayer.playingMusic)
            {
                // 如果正在播放音乐，停止播放
                musicPlayer.stopMusic();
                FlxG.sound.play(Paths.sound('cancelMenu'));
            }
            else
            {
                persistentUpdate = false;
                FlxG.sound.play(Paths.sound('cancelMenu'));
                MusicBeatState.switchState(new MainMenuState());
                FlxG.mouse.visible = false;
            }
        }
        else if(FlxG.keys.justPressed.CONTROL || FlxG.mouse.justPressedMiddle)
        {
            persistentUpdate = false;
            openSubState(new GameplayChangersSubstate());
        }
        // 选择歌曲（开始游戏）- 仅在未播放音乐时可用
        else if (FlxG.keys.justPressed.ENTER && !musicPlayer.playingMusic)
        {
            selectSong();
        }
        // 播放/暂停歌曲（空格键）- 仅在未播放音乐时可用
        else if (FlxG.keys.justPressed.SPACE)
        {
            togglePlaySong();
        }
        // 重置分数 - 仅在未播放音乐时可用
        else if(controls.RESET && !musicPlayer.playingMusic)
        {
            persistentUpdate = false;
            openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        super.update(elapsed);
    }
    
    function updateMouseInteraction()
    {
        var newMouseOverCard:Int = -1;
        for (i in 0...cards.length)
        {
            var distance = Math.abs(cards[i].targetY - curSelected);
            if (distance <= 5 && cards[i].checkMouseOver())
            {
                newMouseOverCard = i;
                break;
            }
        }
        
        if (FlxG.mouse.justPressed)
        {
            if (newMouseOverCard != -1 && newMouseOverCard != curSelected)
            {
                curSelected = newMouseOverCard;
                changeSelection();
                FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
            }
            else if (newMouseOverCard == curSelected)
            {
                selectSong();
            }
        }
        
        mouseOverCard = newMouseOverCard;
    }
    
    function selectSong()
    {
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
            if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1);
            else errorStr += '\n\n' + e.stack;
        }

        @:privateAccess
        if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
        {
            Paths.freeGraphicsFromMemory();
        }
        
        LoadingState.prepareToSong();
        LoadingState.loadAndSwitchState(new PlayState());
        #if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
        stopMusicPlay = true;

        destroyFreeplayVocals();
        #if (MODS_ALLOWED && DISCORD_ALLOWED)
        DiscordClient.loadModRPC();
        #end
    }

    public static function destroyFreeplayVocals() {
        if(vocals != null) vocals.stop();
        vocals = FlxDestroyUtil.destroy(vocals);

        if(opponentVocals != null) opponentVocals.stop();
        opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
    }

    function changeDiff(change:Int = 0)
    {
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
        #if !switch
        intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
        intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
        #end

        lastDifficultyName = Difficulty.getString(curDifficulty, false);
        var displayDiff:String = Difficulty.getString(curDifficulty);
        if (Difficulty.list.length > 1)
            diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
        else
            diffText.text = displayDiff.toUpperCase();

        positionHighscore();
    }

    function changeSelection(change:Int = 0, playSound:Bool = true)
    {
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
        _updateSongLastDifficulty();
        
        if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

        // 更新背景颜色
        var newColor:Int = songs[curSelected].color;
        if(newColor != intendedColor)
        {
            intendedColor = newColor;
            FlxTween.cancelTweensOf(menuBg);
            FlxTween.color(menuBg, 0.5, menuBg.color, intendedColor);
        }

        // 更新右下角发光颜色
        updateCornerGlow();

        // 设置正确的Mod目录
        Mods.currentModDirectory = songs[curSelected].folder;
        PlayState.storyWeek = songs[curSelected].week;
        Difficulty.loadFromWeek();
        
        changeDiff();
        _updateSongLastDifficulty();
        
        // 如果正在播放音乐，停止当前音乐
        if (musicPlayer.playingMusic)
        {
            musicPlayer.switchPlayMusic();
            destroyFreeplayVocals();
            FlxG.sound.music.stop();
            if (!stopMusicPlay)
                FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
        }

        // 显示艺术图（处理相同艺术图的情况）
        showSongArtForIndex(curSelected, true);
        showCharacterArtForIndex(curSelected, true);
    }

// 预加载配置的艺术图
function preloadConfiguredArts()
{
    #if MODS_ALLOWED
    var oldModDir = Mods.currentModDirectory;
    
    // 为每首歌曲预加载其艺术图
    for (song in songs)
    {
        var artName:String = SongArtConfig.getArtForSong(song.songName);
        if (artName != null)
        {
            // 尝试在当前模组中加载
            Mods.currentModDirectory = song.folder;
            try {
                Paths.image('songArt/$artName', null, true);
               // trace('Preloaded art "$artName" for song "${song.songName}"');
            } catch (e:Dynamic) {
                trace('Failed to preload art "$artName" for song "${song.songName}": $e');
            }
        }
    }
    
    Mods.currentModDirectory = oldModDir;
    #end
}

  // 简化的showSongArtForIndex函数
    public function showSongArtForIndex(index:Int, animated:Bool) {
        if (index < 0 || index >= songs.length) return;
        
        var songData = songs[index];
        
        // 直接从配置获取艺术图名称
        var artName:String = SongArtConfig.getArtForSong(songData.songName);
        
        if (artName == null) {
            // 没有配置的艺术图，直接隐藏
            if (songArt != null) {
                songArt.visible = false;
            }
            currentArtPath = "";
            return;
        }
        
        // 加载艺术图
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = songData.folder;
        
        var graphic:FlxGraphic = null;
        try {
            graphic = Paths.image('songArt/$artName', null, true);
        } catch (e:Dynamic) {
            // 忽略错误
        }
        
        Mods.currentModDirectory = oldModDir;
        
        if (graphic == null) {
            if (songArt != null) songArt.visible = false;
            currentArtPath = "";
            return;
        }
        
        // 检查是否是相同的艺术图
        var newArtPath = artName + "_" + songData.folder;
        var isSameArt = (currentArtPath == newArtPath);
        
        // 如果是相同的艺术图，不执行动画
        if (isSameArt && songArt != null && songArt.visible) {
            return;
        }

        if (songArt == null) {
            songArt = new FlxSprite(-150, FlxG.height/2);
            songArt.antialiasing = ClientPrefs.data.antialiasing;
            songArt.scrollFactor.set();
            add(songArt);
        }

        // 如果有动画正在进行，取消它
        if (songArtTweening) {
            FlxTween.cancelTweensOf(songArt);
            songArtTweening = false;
        }

        songArt.loadGraphic(graphic);
        var targetHeight:Float = 140;
        var s:Float = targetHeight / songArt.height;
        songArt.scale.set(s, s);
        songArt.updateHitbox();

        // 计算目标位置
        var targetX:Float = FlxG.width / 2 - songArt.width / 2;
        var targetY:Float = FlxG.height - 300;
        if (bottomText != null) targetY = bottomText.y - songArt.height - 8;

        // 更新当前艺术图路径
        currentArtPath = newArtPath;

        if (!animated || isSameArt) {
            // 直接设置到目标位置（无动画）
            songArt.x = targetX;
            songArt.y = targetY;
            songArt.alpha = 1;
            songArt.visible = true;
            return;
        }

        // 设置初始位置
        songArt.x = targetX - 50;
        songArt.y = targetY;
        songArt.alpha = 0;
        songArt.visible = true;
        
        songArtTweening = true;
        
        // 淡入动画
        FlxTween.tween(songArt, { 
            x: targetX,
            alpha: 1 
        }, 0.25, { 
            ease: FlxEase.circOut, 
            onComplete: function(t) {
                songArtTweening = false;
            }
        });
    }

    public function showCharacterArtForIndex(index:Int, animated:Bool) {
    if (index < 0 || index >= songs.length) return;
    
    var songData = songs[index];
    
    // 从配置获取人物艺术图和缩放比例
    var artName:String = SongArtConfig.getCharacterArtForSong(songData.songName);
    
    if (artName == null) {
        if (characterSprite != null) {
            characterSprite.visible = false;
        }
        currentCharacterArtPath = "";
        return;
    }
    
    // 获取缩放比例
    var scale:Float = SongArtConfig.getCharacterScaleForSong(songData.songName);
    
    var oldModDir = Mods.currentModDirectory;
    Mods.currentModDirectory = songData.folder;
    
    var graphic:FlxGraphic = null;
    try {
        graphic = Paths.image('characterArt/$artName', null, true);
    } catch (e:Dynamic) {
        // 忽略错误
    }
    
    Mods.currentModDirectory = oldModDir;
    
    if (graphic == null) {
        if (characterSprite != null) characterSprite.visible = false;
        currentCharacterArtPath = "";
        return;
    }
    
    var newArtPath = artName + "_" + songData.folder;
    var isSameArt = (currentCharacterArtPath == newArtPath);
    
    if (isSameArt && characterSprite != null && characterSprite.visible) {
        return;
    }

    if (characterSprite == null) {
        characterSprite = new FlxSprite(FlxG.width + 300, FlxG.height * 0.4);
        characterSprite.antialiasing = ClientPrefs.data.antialiasing;
        characterSprite.scrollFactor.set();
        // 确保角色在正确的图层层级
        var menuBgIndex = members.indexOf(menuBg);
        if (menuBgIndex != -1) {
            remove(characterSprite);
            insert(menuBgIndex + 1, characterSprite); // 放在菜单背景之后
        }
    }

    // 如果有动画正在进行，取消它们
    if (characterTweening) {
        FlxTween.cancelTweensOf(characterSprite);
        characterTweening = false;
    }

    // 加载新图像前保存当前位置和透明度
    var startX:Float = characterSprite.x;
    var startAlpha:Float = characterSprite.alpha;
    
    characterSprite.loadGraphic(graphic);
    
    // 应用配置的缩放比例
    var targetHeight:Float = 300 * scale;
    var s:Float = targetHeight / characterSprite.height;
    characterSprite.scale.set(s, s);
    characterSprite.updateHitbox();

    currentCharacterArtPath = newArtPath;

    // 计算目标位置（屏幕右侧）
    var targetX:Float = FlxG.width - characterSprite.width - 50;
    var targetY:Float = (FlxG.height - characterSprite.height) / 2;
    
    // 设置Y位置（不需要动画）
    characterSprite.y = targetY;

    if (!animated || isSameArt) {
        characterSprite.x = targetX;
        characterSprite.alpha = 1;
        characterSprite.visible = true;
        return;
    }

    // 设置初始位置（从右侧屏幕外开始）和透明度
    characterSprite.x = FlxG.width + 50;
    characterSprite.alpha = 0;
    characterSprite.visible = true;
    
    characterTweening = true;
    
    // 使用更丝滑的动画效果 - 参考 portraitTween
    // 同时进行位置和透明度动画，使用 expoOut 缓动
    FlxTween.tween(characterSprite, { 
        x: targetX,
        alpha: 1 
    }, 0.3, { 
        ease: FlxEase.expoOut, // 德福
        onComplete: function(t) {
            characterTweening = false;
        }
    });
}

    inline private function _updateSongLastDifficulty()
        songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

    override function destroy():Void
    {
        super.destroy();

        FlxG.autoPause = ClientPrefs.data.autoPause;
        if (!FlxG.sound.music.playing && !stopMusicPlay)
            FlxG.sound.playMusic(Paths.music('freakyMenu'));

        // 销毁艺术图资源
        if (songArt != null) {
            FlxTween.cancelTweensOf(songArt);
            songArt.destroy();
            songArt = null;
        }

        if (characterSprite != null) {
            FlxTween.cancelTweensOf(characterSprite);
            characterSprite.destroy();
            characterSprite = null;
        }
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
    
    public function new(x:Float, y:Float, songName:String, songCharacter:String, coloring:Int, week:Int)
    {
        super();
        
        this.songName = songName;
        this.songCharacter = songCharacter;
        this.coloring = coloring;
        this.week = week;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
        
        // 卡片背景 - 永远保持灰色，不再变色
        bgSprite = new FlxSprite(x, y);
        bgSprite.makeGraphic(450, 75, 0xFF4A4A4A);
        bgSprite.alpha = 0.67;
        bgSprite.scrollFactor.set();
        add(bgSprite);
        
        // 歌曲文本
        textSprite = new FlxText(x + 60, y + 15, 380, songName, 20);
        textSprite.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        textSprite.borderSize = 2;
        textSprite.borderColor = FlxColor.BLACK;
        textSprite.scrollFactor.set();
        add(textSprite);
        
        // 角色图标
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = this.folder;
        
        icon = new HealthIcon(songCharacter, false);
        icon.setPosition(x + 30, y + 5);
        icon.scale.set(0.6, 0.6);
        icon.updateHitbox();
        icon.scrollFactor.set();
        add(icon);
        
        Mods.currentModDirectory = oldModDir;
        
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
    
    public function updateRatingSprite()
    {
        var songLowercase:String = songName.toLowerCase();
        songLowercase = songLowercase.replace(" ", "-");
        
        var bestRating:Float = 0;
        for (diff in 0...Difficulty.list.length)
        {
            var rating:Float = Highscore.getRating(songLowercase, diff);
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
    
    public function updatePosition(curSelected:Float, isVisible:Bool = true)
    {
        var distance = targetY - curSelected;
        
        if (Math.abs(distance) > 5) 
        {
            bgSprite.visible = bgSprite.active = false;
            textSprite.visible = textSprite.active = false;
            icon.visible = icon.active = false;
            rhombusBg.visible = rhombusBg.active = false;
            ratingSprite.visible = ratingSprite.active = false;
            return;
        }
        
        bgSprite.visible = bgSprite.active = true;
        textSprite.visible = textSprite.active = true;
        icon.visible = icon.active = true;
        rhombusBg.visible = rhombusBg.active = true;
        ratingSprite.visible = ratingSprite.active = true;
        
        var middleY = FlxG.height * 0.5;
        var spacing = 80;
        
        var offsetY = distance * spacing;
        var offsetX = Math.abs(distance) * -60;
        
        var targetX = 200 + offsetX;
        var targetYPos = middleY + offsetY - 30;
        
        bgSprite.x = targetX - 50;
        bgSprite.y = targetYPos;
        
        textSprite.x = targetX + 60;
        textSprite.y = targetYPos + 15;
        
        icon.x = targetX - 80;
        icon.y = targetYPos - 45;
        
        rhombusBg.x = targetX  + 400;
        rhombusBg.y = targetYPos;
        
        if (ratingSprite.graphic != null)
        {
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 100;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }
        

        var alpha = 0.6;
        if (Math.abs(distance) < 1) {
            alpha = 0.8;
            bgSprite.color = 0xFF4A4A4A; 
        } else {
            bgSprite.color = 0xFF4A4A4A; 
        }
        
        rhombusBg.color = coloring;
        
        bgSprite.alpha = alpha;
        textSprite.alpha = alpha;
        icon.alpha = alpha;
        rhombusBg.alpha = alpha;
        ratingSprite.alpha = alpha;
    }
    
    public function checkMouseOver():Bool
    {
        return FlxG.mouse.overlaps(bgSprite) || FlxG.mouse.overlaps(rhombusBg) || FlxG.mouse.overlaps(ratingSprite);
    }
}