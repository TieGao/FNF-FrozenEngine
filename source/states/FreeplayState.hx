package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.SongArtConfig;
import backend.SongInfoParser;

import objects.HealthIcon;
import objects.NewMusicPlayer;
import objects.MusicPlayerLegacy;
import objects.CharacterArtDisplay;
import objects.SongArtDisplay;

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

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class FreeplayState extends MusicBeatState
{
    var songs:Array<NewSongMetaData> = [];
    var cards:Array<FreeplayCard> = [];

    var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();
    
    var space:FlxSprite;
    var starsBG:FlxBackdrop;
    var starsFG:FlxBackdrop;
    
    var menuBg:FlxSprite;
    var intendedColor:Int;
    
    var cornerGlow:FlxSprite;
    
    // 独立的艺术图显示模块
    var songArtDisplay:SongArtDisplay;
    var characterArtDisplay:CharacterArtDisplay;

    var scoreBG:FlxSprite;
    var scoreText:FlxText;
    var diffText:FlxText;
    var lerpScore:Int = 0;
    var lerpRating:Float = 0;
    var intendedScore:Int = 0;
    var intendedRating:Float = 0;

    var missingTextBG:FlxSprite;
	var missingText:FlxText;
    
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
    var musicPlayerLegacy:MusicPlayerLegacy;

    var replayButton:FlxSprite;
    
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
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
			function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
			function() MusicBeatState.switchState(new states.MainMenuState())));
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

        menuBg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        menuBg.antialiasing = ClientPrefs.data.antialiasing;
        menuBg.alpha = 0.4;
        add(menuBg);
        menuBg.screenCenter();
        // 背景层
        space = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        space.antialiasing = ClientPrefs.data.antialiasing;
        space.updateHitbox();
        space.scrollFactor.set();
        space.alpha = 0;
        add(space);

        starsBG = new FlxBackdrop(Paths.image('freeplay/starBG'));
        starsBG.setPosition(111.3, 67.95);
        starsBG.antialiasing = true;
        starsBG.updateHitbox();
        starsBG.scrollFactor.set();
        starsBG.alpha = 0;
        add(starsBG);

        starsFG = new FlxBackdrop(Paths.image('freeplay/starFG'));
        starsFG.setPosition(54.3, 59.45);
        starsFG.updateHitbox();
        starsFG.antialiasing = true;
        starsFG.scrollFactor.set();
        starsFG.alpha = 0;
        add(starsFG);

        cornerGlow = new FlxSprite().loadGraphic(Paths.image('freeplay/backGlow'));
        cornerGlow.antialiasing = true;
        cornerGlow.updateHitbox();
        cornerGlow.scrollFactor.set();
        cornerGlow.color = FlxColor.RED;
        cornerGlow.alpha = 0;
        cornerGlow.x = FlxG.width - cornerGlow.width + 100;
        cornerGlow.y = FlxG.height - cornerGlow.height + 120;
        add(cornerGlow);
        
        characterArtDisplay = new CharacterArtDisplay();
        add(characterArtDisplay);

        songArtDisplay = new SongArtDisplay();
        add(songArtDisplay);

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

        missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

        if(curSelected >= songs.length) curSelected = 0;
        menuBg.color = songs[curSelected].color;
        intendedColor = menuBg.color;
        lerpSelected = curSelected;

        curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

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

        replayButton = new FlxSprite(FlxG.width - 200, 0); // 右上角位置
        replayButton.loadGraphic(Paths.image('replay')); // 从 images 文件夹加载
        replayButton.antialiasing = ClientPrefs.data.antialiasing;
        replayButton.scrollFactor.set(); 
        replayButton.setGraphicSize(200, 100); // 初始缩放
        replayButton.updateHitbox();
        replayButton.alpha = 0.8;  
        add(replayButton);

        // 创建音乐播放器
        musicPlayer = new NewMusicPlayer(this);
        musicPlayerLegacy = new MusicPlayerLegacy(this);
        add(musicPlayer);
        add(musicPlayerLegacy);

        Mods.currentModDirectory = songs[curSelected].folder;
        PlayState.storyWeek = songs[curSelected].week;
        Difficulty.loadFromWeek();
        
        changeDiff();
        
        // 在初始选择时直接显示艺术图和角色（无出入动画）
        showArtForIndex(curSelected, false);
        showCharacterForIndex(curSelected, false);

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
    function preloadConfiguredArts()
    {
        #if MODS_ALLOWED
        var oldModDir = Mods.currentModDirectory;
        
        for (song in songs)
        {
            var artName:String = SongArtConfig.getArtForSong(song.songName);
            if (artName != null)
            {
                Mods.currentModDirectory = song.folder;
                try {
                    Paths.image('songArt/$artName', null, true);
                } catch (e:Dynamic) {}
            }
            
            var charArtName:String = SongArtConfig.getCharacterArtForSong(song.songName);
            if (charArtName != null)
            {
                Mods.currentModDirectory = song.folder;
                try {
                    Paths.image('characterArt/$charArtName', null, true);
                } catch (e:Dynamic) {}
            }
        }
        
        Mods.currentModDirectory = oldModDir;
        #end
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
    
    // 重要：先保存当前目录
    var oldModDir = Mods.currentModDirectory;
    
    // 设置到歌曲所在的模组目录
    Mods.currentModDirectory = song.folder;
    
    // 从当前周加载难度
    var weekData = WeekData.weeksLoaded.get(WeekData.weeksList[weekNum]);
    var difficulties:Array<String> = [];
    
    if (weekData != null)
    {
        WeekData.setDirectoryFromWeek(weekData);
        
        // 从周数据加载难度列表
        Difficulty.loadFromWeek(weekData);
        
        // 获取周定义的难度列表
        if (weekData.difficulties != null && weekData.difficulties.length > 0)
        {
            // weekData.difficulties 是一个字符串，如 "Easy,Normal,Hard" 或 "erect,nightmare"
            var diffStr:String = weekData.difficulties;
            difficulties = diffStr.split(',');
            
            // 清理每个难度名称（去除空格）
            for (i in 0...difficulties.length)
            {
                difficulties[i] = difficulties[i].trim();
            }
            
            //trace('Song $songName (Week: ${weekData.weekName}) Custom Difficulties: ' + difficulties.join(', '));
            
            // 重要：将周定义的自定义难度设置到 Difficulty.list
            Difficulty.copyFrom(difficulties);
        }
        else
        {
            // 如果没有自定义难度，使用默认列表
            difficulties = Difficulty.defaultList.copy();
           // trace('Song $songName (Week: ${weekData.weekName}) Using Default Difficulties: ' + difficulties.join(', '));
        }
        
        // 使用 SongInfoParser 预加载所有难度的信息，传入 weekData
        song.difficultyInfo = SongInfoParser.preloadAllDifficulties(songName, song.folder, difficulties, weekData);
        
        // 打印预加载结果
        for (diffName in difficulties)
        {
            var info = song.difficultyInfo.get(diffName);
            if (info != null)
            {
                //trace('$songName - $diffName: BPM=${info.bpm}, Length=${info.formattedLength}');
            }
        }
    }
    else
    {
        trace('WARNING: Week data not found for week index $weekNum');
        // 使用默认难度
        difficulties = Difficulty.defaultList.copy();
        song.difficultyInfo = SongInfoParser.preloadAllDifficulties(songName, song.folder, difficulties, null);
    }
    
    // 恢复原来的目录
    Mods.currentModDirectory = oldModDir;
    
    songs.push(song);
}

    function weekIsLocked(name:String):Bool
    {
        var leWeek:WeekData = WeekData.weeksLoaded.get(name);
        return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
    }

    function updateCardsRating()
    {
        for (card in cards)
        {
            card.updateRatingSprite();
        }
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
    
    function updateCornerGlow()
    {
        if (cornerGlow != null)
        {
            var targetColor = songs[curSelected].color;
            FlxTween.cancelTweensOf(cornerGlow);
            FlxTween.color(cornerGlow, 0.5, cornerGlow.color, targetColor);
        }
    }

    // 更新卡片显示的难度信息
    function updateCardDifficultyInfo()
    {
        if (cards.length <= curSelected) return;
        
        var currentSong = songs[curSelected];
        var currentDiffName = Difficulty.getString(curDifficulty, false);
        
        var diffInfo = currentSong.difficultyInfo.get(currentDiffName);
        
        if (diffInfo != null)
        {
            cards[curSelected].updateDifficultyInfo(
                diffInfo.bpm,
                diffInfo.formattedLength
            );
        }
        else
        {
            cards[curSelected].updateDifficultyInfo(0, "0:00");
        }
    }
    
    function togglePlaySong()
    {
        if (musicPlayer.playingMusic)
        {
            musicPlayer.stopMusic();
            return;
        }
        
        var songName:String = songs[curSelected].songName;
        var songLowercase:String = Paths.formatToSongPath(songName);
        var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
        
        try
        {
            destroyFreeplayVocals();
            
            var oldModDirectory = Mods.currentModDirectory;
            Mods.currentModDirectory = songs[curSelected].folder;
            
            #if sys
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
            #end
            
            PlayState.SONG = Song.loadFromJson(poop, songLowercase);
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDifficulty;
            
            #if DISCORD_ALLOWED
            DiscordClient.changePresence("Freeplay - Listening to " + songName, null);
            #end
            
            if (FlxG.sound.music != null)
                FlxG.sound.music.stop();
            
            FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7, false);
            
            FlxG.sound.music.onComplete = function()
            {
                destroyFreeplayVocals();
                FlxG.sound.music.time = 0;
                if (musicPlayer.playingMusic)
                    musicPlayer.stopMusic();
            };
            
            vocals = new FlxSound();
            if (PlayState.SONG.needsVoices)
                vocals.loadEmbedded(Paths.voices(PlayState.SONG.song));
            else
                vocals.loadEmbedded(Paths.voices(PlayState.SONG.song, "empty"));
            
            FlxG.sound.list.add(vocals);
            
            opponentVocals = new FlxSound();
            opponentVocals.loadEmbedded(Paths.voices(PlayState.SONG.song, "empty"));
            FlxG.sound.list.add(opponentVocals);
            
            musicPlayer.playingMusic = true;
            musicPlayer.switchPlayMusic();
            
            Mods.currentModDirectory = oldModDirectory;
        }
        catch(e:haxe.Exception)
        {
            trace('ERROR: ${e.message}');
            FlxG.sound.play(Paths.sound('cancelMenu'));
        }
    }

    override function update(elapsed:Float)
    {
        if(WeekData.weeksList.length < 1)
            return;

        starsBG.x -= 0.05;
        starsFG.x -= 0.15;
        
        if (starsBG.x < -starsBG.width) starsBG.x = 0;
        if (starsFG.x < -starsFG.width) starsFG.x = 0;

        if (FlxG.sound.music.volume < 0.7 && !musicPlayer.playingMusic)
            FlxG.sound.music.volume += 0.5 * elapsed;

        lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
        lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

        if (Math.abs(lerpScore - intendedScore) <= 10)
            lerpScore = intendedScore;
        if (Math.abs(lerpRating - intendedRating) <= 0.01)
            lerpRating = intendedRating;

        lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
        
        updateTimer += elapsed;
        if (updateTimer >= updateInterval)
        {
            updateCardsPosition();
            updateTexts();
            updateTimer = 0;
        }

        if (!musicPlayer.playingMusic)
        {
            updateMouseInteraction();
        }

        // ===== replay 按钮交互 =====
        // 悬停效果
        if (FlxG.mouse.overlaps(replayButton))
        {
            replayButton.alpha = 1.0;
            replayButton.scale.set(0.55, 0.55);
        }
        else
        {
            replayButton.alpha = 0.8;
            replayButton.scale.set(0.5, 0.5);
        }
        
        // 点击处理
        if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(replayButton))
        {
            FlxG.sound.play(Paths.sound('confirmMenu'), 0.7); // 播放确认音效
            MusicBeatState.switchState(new LoadReplayState()); // 切换回放菜单
        }
        // ==========================

        var shiftMult:Int = 1;
        if(FlxG.keys.pressed.SHIFT && !musicPlayer.playingMusic) shiftMult = 3;

        if (!musicPlayer.playingMusic && !musicPlayerLegacy.playingMusic)
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

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
        }

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

        if (controls.BACK || FlxG.mouse.justPressedRight)
        {
            if (musicPlayer.playingMusic && !ClientPrefs.data.legacymp)
            {
                musicPlayer.stopMusic();
                FlxG.sound.play(Paths.sound('cancelMenu'));

                FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
            }
            else if (musicPlayerLegacy.playingMusic && ClientPrefs.data.legacymp)
            {
                FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				musicPlayerLegacy.playingMusic = false;
				musicPlayerLegacy.switchPlayMusic();

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
        else if(FlxG.keys.justPressed.CONTROL || FlxG.mouse.justPressedMiddle && !musicPlayer.playingMusic)
        {
            persistentUpdate = false;
            openSubState(new GameplayChangersSubstate());
        }
        else if (FlxG.keys.justPressed.ENTER && !musicPlayer.playingMusic)
        {
            selectSong();
        }
        else if (FlxG.keys.justPressed.SPACE && !ClientPrefs.data.legacymp)
        {
            togglePlaySong();
        }
        else if (FlxG.keys.justPressed.SPACE && ClientPrefs.data.legacymp)
        {
			if(instPlaying != curSelected && !musicPlayerLegacy.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
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
							vocals.loadEmbedded(loadedVocals);
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
					
					opponentVocals = new FlxSound();
					try
					{
						//trace('please work...');
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				musicPlayerLegacy.playingMusic = true;
				musicPlayerLegacy.curTime = 0;
				musicPlayerLegacy.switchPlayMusic();
				musicPlayerLegacy.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && musicPlayerLegacy.playingMusic)
			{
				musicPlayerLegacy.pauseOrResume(!musicPlayerLegacy.playingMusic);
			}
        }

        else if(controls.RESET && !musicPlayer.playingMusic)
        {
            persistentUpdate = false;
            openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter, -1, songs[curSelected].folder));
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
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				return;
        }

        @:privateAccess
        if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
        {
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
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

    public static function destroyFreeplayVocals() {
        if(vocals != null) vocals.stop();
        vocals = FlxDestroyUtil.destroy(vocals);

        if(opponentVocals != null) opponentVocals.stop();
        opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
    }

    function changeDiff(change:Int = 0)
{
    if (musicPlayer.playingMusic)
        return;

    curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
    
    // 关键修改：传入模组文件夹获取分数
    #if !switch
    intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty, songs[curSelected].folder);
    intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty, songs[curSelected].folder);
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
}

    // 修复：完整的 changeSelection 函数
  function changeSelection(change:Int = 0, playSound:Bool = true)
{
    if (musicPlayer.playingMusic)
        return;

    curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
    _updateSongLastDifficulty(); // 先保存当前歌曲的最后使用难度
    
    if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

    var newColor:Int = songs[curSelected].color;
    if(newColor != intendedColor)
    {
        intendedColor = newColor;
        FlxTween.cancelTweensOf(menuBg);
        FlxTween.color(menuBg, 0.5, menuBg.color, intendedColor);
    }

    updateCornerGlow();

    // 重要：先保存当前目录
    var oldModDir = Mods.currentModDirectory;
    
    // 设置到选中歌曲的模组目录
    Mods.currentModDirectory = songs[curSelected].folder;
    
    // 设置周目录并加载难度
    PlayState.storyWeek = songs[curSelected].week;
    var weekData = WeekData.weeksLoaded.get(WeekData.weeksList[PlayState.storyWeek]);
    if (weekData != null)
    {
        WeekData.setDirectoryFromWeek(weekData);
        
        // 加载周定义的自定义难度
        if (weekData.difficulties != null && weekData.difficulties.length > 0)
        {
            var diffStr:String = weekData.difficulties;
            var customDiffs:Array<String> = diffStr.split(',');
            for (i in 0...customDiffs.length)
            {
                customDiffs[i] = customDiffs[i].trim();
            }
            Difficulty.copyFrom(customDiffs);
            //trace('Loaded custom difficulties: ' + customDiffs.join(', '));
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
    
    // 恢复原来的目录
    Mods.currentModDirectory = oldModDir;
    
    // 修复：恢复选中歌曲的最后使用难度
    var savedDiff:String = songs[curSelected].lastDifficulty;
    var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
    
    if (savedDiff != null && Difficulty.list.contains(savedDiff))
    {
        // 如果歌曲保存了最后使用的难度，且该难度在当前周存在，就使用它
        curDifficulty = Difficulty.list.indexOf(savedDiff);
    }
    else if (lastDiff > -1 && lastDiff < Difficulty.list.length)
    {
        // 否则使用全局最后使用的难度
        curDifficulty = lastDiff;
    }
    else
    {
        // 最后保底使用第一个难度
        curDifficulty = 0;
    }
    
    // 确保难度索引有效
    if (curDifficulty == -1 || curDifficulty >= Difficulty.list.length)
        curDifficulty = 0;
    
    changeDiff();
    _updateSongLastDifficulty(); // 更新当前歌曲的最后使用难度
    
    if (musicPlayer.playingMusic)
    {
        musicPlayer.switchPlayMusic();
        destroyFreeplayVocals();
        FlxG.sound.music.stop();
        if (!stopMusicPlay)
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
    }

    if (ClientPrefs.data.legacymp && musicPlayerLegacy.playingMusic)
    {
        musicPlayerLegacy.switchPlayMusic();
        destroyFreeplayVocals();
        FlxG.sound.music.stop();
        if (!stopMusicPlay)
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
    }

    // 使用独立的显示模块显示艺术图和角色
    showArtForIndex(curSelected, true);
    showCharacterForIndex(curSelected, true);

    missingText.visible = false;
	missingTextBG.visible = false;
}

    // 显示艺术图
    function showArtForIndex(index:Int, animated:Bool)
    {
        if (index < 0 || index >= songs.length) return;
        songArtDisplay.showArt(songs[index].songName, songs[index].folder, animated);
    }

    // 显示角色
    function showCharacterForIndex(index:Int, animated:Bool)
    {
        if (index < 0 || index >= songs.length) return;
        characterArtDisplay.showCharacter(songs[index].songName, songs[index].folder, animated);
    }

    // 修复：更新歌曲的最后使用难度
    inline private function _updateSongLastDifficulty()
    {
        if (curSelected >= 0 && curSelected < songs.length)
        {
            songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
        }
    }

    override function destroy():Void
    {
        super.destroy();

        FlxG.autoPause = ClientPrefs.data.autoPause;
        if (!FlxG.sound.music.playing && !stopMusicPlay)
            FlxG.sound.playMusic(Paths.music('freakyMenu'));

        if (songArtDisplay != null)
            songArtDisplay.destroy();
            
        if (characterArtDisplay != null)
            characterArtDisplay.destroy();
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
    
    public var difficultyInfo:Map<String, ParsedSongInfo> = new Map<String, ParsedSongInfo>();
    
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
    
    public var bpmText:FlxText;
    public var lengthText:FlxText;

    public function new(x:Float, y:Float, songName:String, songCharacter:String, coloring:Int, week:Int)
    {
        super();
        
        this.songName = songName;
        this.songCharacter = songCharacter;
        this.coloring = coloring;
        this.week = week;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
        
        bgSprite = new FlxSprite(x, y);
        bgSprite.makeGraphic(450, 75, 0xFF4A4A4A);
        bgSprite.alpha = 0.67;
        bgSprite.scrollFactor.set();
        add(bgSprite);
        
        textSprite = new FlxText(x + 60, y + 10, 380, songName, 20);
        textSprite.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        textSprite.borderSize = 2;
        textSprite.borderColor = FlxColor.BLACK;
        textSprite.scrollFactor.set();
        add(textSprite);

        bpmText = new FlxText(x + 60, y + 35, 150, 'BPM: --', 14);
        bpmText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        bpmText.borderSize = 1;
        bpmText.borderColor = FlxColor.BLACK;
        bpmText.scrollFactor.set();
        add(bpmText);
        
        lengthText = new FlxText(x + 220, y + 35, 150, 'LENGTH: 0:00', 14);
        lengthText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        lengthText.borderSize = 1;
        lengthText.borderColor = FlxColor.BLACK;
        lengthText.scrollFactor.set();
        add(lengthText);
        
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = this.folder;
        
        icon = new HealthIcon(songCharacter, false, true, this.folder);
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
    
    public function updateDifficultyInfo(bpm:Float, formattedLength:String)
    {
        if (bpm > 0)
            bpmText.text = 'BPM: ${Math.round(bpm)}';
        else
            bpmText.text = 'BPM: --';
            
        lengthText.text = 'LENGTH: $formattedLength';
    }
    
    public function updateRatingSprite()
    {
        var songLowercase:String = songName.toLowerCase();
        songLowercase = songLowercase.replace(" ", "-");
        
        var bestRating:Float = 0;
        for (diff in 0...Difficulty.list.length)
        {
            var rating:Float = Highscore.getRating(songLowercase, diff, folder);
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
            bpmText.visible = bpmText.active = false;
            lengthText.visible = lengthText.active = false;
            return;
        }
        
        bgSprite.visible = bgSprite.active = true;
        textSprite.visible = textSprite.active = true;
        icon.visible = icon.active = true;
        rhombusBg.visible = rhombusBg.active = true;
        ratingSprite.visible = ratingSprite.active = true;
        bpmText.visible = bpmText.active = true;
        lengthText.visible = lengthText.active = true;
        
        var middleY = FlxG.height * 0.5;
        var spacing = 80;
        
        var offsetY = distance * spacing;
        var offsetX = Math.abs(distance) * -60;
        
        var targetX = 200 + offsetX;
        var targetYPos = middleY + offsetY - 30;
        
        bgSprite.x = targetX - 50;
        bgSprite.y = targetYPos;
        
        textSprite.x = targetX + 60;
        textSprite.y = targetYPos + 10;

        bpmText.x = targetX + 60;
        bpmText.y = targetYPos + 35;
        
        lengthText.x = targetX + 220;
        lengthText.y = targetYPos + 35;
        
        icon.x = targetX - 80;
        icon.y = targetYPos - 45;
        
        rhombusBg.x = targetX + 400;
        rhombusBg.y = targetYPos;
        
        if (ratingSprite.graphic != null)
        {
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 100;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }
        
        var alpha = 0.6;
        if (Math.abs(distance) < 0.7) {
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
        bpmText.alpha = alpha;
        lengthText.alpha = alpha;
    }
    
    public function checkMouseOver():Bool
    {
        return FlxG.mouse.overlaps(bgSprite) || FlxG.mouse.overlaps(rhombusBg) || FlxG.mouse.overlaps(ratingSprite);
    }
}