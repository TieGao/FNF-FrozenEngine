package options;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.Alphabet;

class VisualsSettingsSubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var splashes:FlxTypedGroup<NoteSplash>;
	var noteY:Float = 90;
	public function new()
	{
		title = Language.getPhrase('visuals_menu', 'Visuals Settings');
		rpcTitle = 'Visuals Settings Menu'; //for Discord Rich Presence

		// for note skins and splash skins
		notes = new FlxTypedGroup<StrumNote>();
		splashes = new FlxTypedGroup<NoteSplash>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			changeNoteSkin(note);
			notes.add(note);
			
			var splash:NoteSplash = new NoteSplash(0, 0, NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix());
			splash.inEditor = true;
			splash.babyArrow = note;
			splash.ID = i;
			splash.kill();
			splashes.add(splash);
		}

		// options
		var noteSkins:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
		if(noteSkins.length > 0)
		{
			if(!noteSkins.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin; //Reset to default if saved noteskin couldnt be found

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin); //Default skin always comes first
			var option:Option = new Option('Note Skins:',
				"Select your prefered Note skin.",
				'noteSkin',
				STRING,
				noteSkins);
			addOption(option);
			option.onChange = onChangeNoteSkin;
			noteOptionID = optionsArray.length - 1;
		}
		
		var noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
		if(noteSplashes.length > 0)
		{
			if(!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); //Default skin always comes first
			var option:Option = new Option('Note Splashes:',
				"Select your prefered Note Splash variation.",
				'splashSkin',
				STRING,
				noteSplashes);
			addOption(option);
			option.onChange = onChangeSplashSkin;
		}

		var holdCovers:Array<String> = Mods.mergeAllTextsNamed('images/holdCover/list.txt');
		if(holdCovers.length > 0)
		{
			if(!holdCovers.contains(ClientPrefs.data.holdCoverSkin))
				ClientPrefs.data.holdCoverSkin = ClientPrefs.defaultData.holdCoverSkin; //Reset to default if saved splashskin couldnt be found

			holdCovers.insert(0, ClientPrefs.defaultData.holdCoverSkin); //Default skin always comes first
			var option:Option = new Option('Note holdCovers:',
				"Select your prefered Note holdCover variation.",
				'holdCoverSkin',
				STRING,
				holdCovers);
			addOption(option);
		}

		var option:Option = new Option('Note Opacity',
			'How much transparent should the Note be.',
			'noteAlpha',
			PERCENT);

		var option:Option = new Option('Note Splash Opacity',
			'How much transparent should the Note Splashes be.',
			'splashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		option.onChange = playNoteSplashes;

		// KEOptions: 强制数字颜色（forceNumberColor）
		var option:Option = new Option('Force Number Color',
			'Force numbers to a specific color instead of team color',
			'forceNumberColor',
			BOOL);
		addOption(option);

		// 粒子设置（从 KEOptions 反向移植）
		var optParticle:Option = new Option('Show Particles in Menu',
			"Show particle effects inside menus",
			'particle',
			BOOL);
		addOption(optParticle);

		var optParticleAmount:Option = new Option('Particle Amount',
			"Amount of particles used in menu effects",
			'particleAmount',
			INT);
		optParticleAmount.scrollSpeed = 1.6;
		optParticleAmount.minValue = 0;
		optParticleAmount.maxValue = 200;
		optParticleAmount.changeValue = 1;
		addOption(optParticleAmount);

		var optParticleSpeed:Option = new Option('Particle Speed',
			"Speed multiplier for particles",
			'particleSpeed',
			FLOAT);
		optParticleSpeed.scrollSpeed = 1.0;
		optParticleSpeed.minValue = 0.1;
		optParticleSpeed.maxValue = 5.0;
		optParticleSpeed.changeValue = 0.1;
		optParticleSpeed.decimals = 2;
		addOption(optParticleSpeed);

		var optParticleTrail:Option = new Option('Particle Trail Length',
			"Length of particle trails",
			'particleTrail',
			INT);
		optParticleTrail.scrollSpeed = 1.0;
		optParticleTrail.minValue = 0;
		optParticleTrail.maxValue = 50;
		optParticleTrail.changeValue = 1;
		addOption(optParticleTrail);

		var option:Option = new Option('Hide HUD',
			'If checked, hides most HUD elements.',
			'hideHud',
			BOOL);
		addOption(option);
		
		var option:Option = new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			STRING,
			['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']);
		addOption(option);

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option('Score Text Grow on Hit',
			"If unchecked, disables the Score text growing\neverytime you hit a note.",
			'scoreZoom',
			BOOL);
		addOption(option);

		var option:Option = new Option('Health Bar Opacity',
			'How much transparent should the health bar and icons be.',
			'healthBarAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		#if !mobile
		var option:Option = new Option('FPS Counter',
			'If unchecked, hides FPS Counter.',
			'showFPS',
			BOOL);
		addOption(option);
		option.onChange = onChangeFPSCounter;
		#end
		
		// Pause Music 列表：优先从 mods/shared 扫描 music/list.txt，回退到内置列表
		var pauseMusicList:Array<String> = Mods.mergeAllTextsNamed('music/list.txt');
		if(pauseMusicList.length > 0)
		{
			if(!pauseMusicList.contains(ClientPrefs.data.pauseMusic))
				ClientPrefs.data.pauseMusic = ClientPrefs.defaultData.pauseMusic;

			// 默认值始终放在第一位
			if(!pauseMusicList.contains(ClientPrefs.defaultData.pauseMusic))
				pauseMusicList.insert(0, ClientPrefs.defaultData.pauseMusic);
			if(!pauseMusicList.contains('None'))
				pauseMusicList.insert(0, 'None');
		}
		else
		{
			pauseMusicList = ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)'];
		}

		var option:Option = new Option('Pause Music:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			STRING,
			pauseMusicList);
		addOption(option);
		option.onChange = onChangePauseMusic;
		
		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord Rich Presence',
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord",
			'discordRPC',
			BOOL);
		addOption(option);
		#end

			var option:Option = new Option('NoteHits Counter',
			"If checked, a counter will show your notehits ",
			'Counter',
			BOOL);
		addOption(option);	

			// 键盘显示设置（部分来自 KEOptions）
			var option:Option = new Option('Show Keyboard',
				"Display keyboard on screen",
				'kb',
				BOOL);
			addOption(option);

			var option:Option = new Option('Keyboard Opacity',
				"Transparency of the keyboard display",
				'keyboardAlpha',
				PERCENT);
			option.scrollSpeed = 1.6;
			option.minValue = 0.0;
			option.maxValue = 1.0;
			option.changeValue = 0.05;
			option.decimals = 2;
			addOption(option);

			var option:Option = new Option('Keyboard Offset X',
				"Horizontal position of the keyboard display",
				'kbOffsetX',
				INT);
			option.minValue = -750;
			option.maxValue = 750;
			option.changeValue = 10;
			addOption(option);

			var option:Option = new Option('Keyboard Offset Y',
				"Vertical position of the keyboard display",
				'kbOffsetY',
				INT);
			option.minValue = -450;
			option.maxValue = 750;
			option.changeValue = 10;
			addOption(option);

			var option:Option = new Option('Keyboard Time Display',
				"Show time on keyboard display",
				'keyboardTimeDisplay',
				BOOL);
			addOption(option);

			var option:Option = new Option('Keyboard Time Length',
				"How long the keyboard is displayed (ms)",
				'keyboardTime',
				FLOAT);
			option.minValue = 0;
			option.maxValue = 2000;
			option.changeValue = 20;
			option.decimals = 0;
			addOption(option);

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read",
			'comboStacking',
			BOOL);
		addOption(option);

		var option:Option = new Option('Center Pause',
			"If checked, pause menu will stay in the screen center",
			'centerPause',
			BOOL);
		addOption(option);

		var option:Option = new Option('Cool Backdrops',
			"If checked, some states will have special effect",
			'coolBackdrop',
			BOOL);
		addOption(option);

		var option:Option = new Option('Custom Color',
			"If checked, timeBar and Scoretxt will change to opponent's icon color",
			'customColor',
			BOOL);
		addOption(option);

		var option:Option = new Option('Gradient TimeBar',
			"If checked, timeBar will be Gradient Color",
			'gradientTimeBar',
			BOOL);
		addOption(option);

		var option:Option = new Option('Health Text',
			"Show ur health as a value!",
			'healthText',
			BOOL);
		addOption(option);

		var option:Option = new Option('KE Style Watermark',
			"Add a text that will show song info",
			'songText',
			BOOL);
		addOption(option);

		var option:Option = new Option('Score Screen',
			"Show ur results like Kade Engine!",
			'scoreScreen',
			BOOL);
		addOption(option);

		var option:Option = new Option('Impostor Story(V3)',
		"If checked, storymenu will change to Impostor V3 style",
		'ImpStory',
		BOOL);
		addOption(option);

		var option:Option = new Option('KE Styled Options',
		"If checked, options will change to KE style",
		'keOptions',
		BOOL);
		addOption(option);

		super();
		add(notes);
		add(splashes);
	}

	var notesShown:Bool = false;
	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		
		switch(curOption.variable)
		{
			case 'noteSkin', 'splashSkin', 'splashAlpha':
				if(!notesShown)
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = true;
				if(curOption.variable.startsWith('splash') && Math.abs(notes.members[0].y - noteY) < 25) playNoteSplashes();

			default:
				if(notesShown) 
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = false;
		}
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.data.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));

		changedMusic = true;
	}

	function onChangeNoteSkin()
	{
		notes.forEachAlive(function(note:StrumNote) {
			changeNoteSkin(note);
			note.centerOffsets();
			note.centerOrigin();
		});
	}

	function changeNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		note.texture = skin; //Load texture and anims
		note.reloadNote();
		note.playAnim('static');
	}

	function onChangeSplashSkin()
	{
		var skin:String = NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix();
		for (splash in splashes)
			splash.loadSplash(skin);

		playNoteSplashes();
	}

	function playNoteSplashes()
	{
		var rand:Int = 0;
		if (splashes.members[0] != null && splashes.members[0].maxAnims > 1)
			rand = FlxG.random.int(0, splashes.members[0].maxAnims - 1); // For playing the same random animation on all 4 splashes

		for (splash in splashes)
		{
			splash.revive();

			splash.spawnSplashNote(0, 0, splash.ID, null, false);
			if (splash.maxAnims > 1)
				splash.noteData = splash.noteData % Note.colArray.length + (rand * Note.colArray.length);

			var anim:String = splash.playDefaultAnim();
			var conf = splash.config.animations.get(anim);
			var offsets:Array<Float> = [0, 0];

			var minFps:Int = 22;
			var maxFps:Int = 26;
			if (conf != null)
			{
				offsets = conf.offsets;

				minFps = conf.fps[0];
				if (minFps < 0) minFps = 0;

				maxFps = conf.fps[1];
				if (maxFps < 0) maxFps = 0;
			}

			splash.offset.set(10, 10);
			if (offsets != null)
			{
				splash.offset.x += offsets[0];
				splash.offset.y += offsets[1];
			}

			if (splash.animation.curAnim != null)
				splash.animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
		}
	}

	override function destroy()
	{
		if(changedMusic && !OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		Note.globalRgbShaders = [];
		super.destroy();
	}

	#if !mobile
	function onChangeFPSCounter()
	{
		if(Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.data.showFPS;
	}
	#end

	override function update(elapsed:Float)
{
    super.update(elapsed);
    
    // 右键返回支持
    #if !mobile
    if (FlxG.mouse.justPressedRight)
    {
        FlxG.sound.play(Paths.sound('cancelMenu'));
        close();
        return;
    }
    #end
}
}
