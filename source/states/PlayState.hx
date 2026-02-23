package states;

import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import cutscenes.DialogueBoxPsych;

import states.StoryMenuState;
import states.FreeplayState;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.NewPauseSubState;
import substates.PauseSubState;
import substates.GameOverSubstate;

#if !flash
import openfl.filters.ShaderFilter;
#end

import shaders.ErrorHandledShader;

import objects.VideoSprite;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.HScriptInfos;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

import backend.Replay;
import backend.OpponentModeSystem;

	typedef ReplayNote = 
	{
    var strumTime:Float;
    var column:Int;
    var sustainLength:Float;
    var diff:Float;
    var isMiss:Bool;
    var processed:Bool;
	}

/**
 * This is where all the Gameplay stuff happens and is managed
 *
 * here's some useful tips if you are making a mod in source:
 *
 * If you want to add your stage to the game, copy states/stages/Template.hx,
 * and put your stage code there, then, on PlayState, search for
 * "switch (curStage)", and add your stage to that list.
 *
 * If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
 *
 * "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
 * "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
 * "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
 * "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for
**/
class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	//event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var curStage:String = '';
	public static var stageUI(default, set):String = "normal";
	public static var uiPrefix:String = "";
	public static var uiPostfix:String = "";
	public static var isPixelStage(get, never):Bool;

	@:noCompletion
	static function set_stageUI(value:String):String
	{
		uiPrefix = uiPostfix = "";
		if (value != "normal")
		{
			uiPrefix = value.split("-pixel")[0].trim();
			if (value == "pixel" || value.endsWith("-pixel")) uiPostfix = "-pixel";
		}
		return stageUI = value;
	}

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;
	public static var inResults:Bool = false;

	public var spawnTime:Float = 2000;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	public var noteHoldCover:NoteHoldCover;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health(default, set):Float = 1;
	public var combo:Int = 0;
	public var highestCombo:Int = 0;

	public var healthBar:Bar;
	public var timeBar:Bar;
	var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;

	public var guitarHeroSustains:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;
	public var opponentMode:Bool = false;
	public var pressMissDamage:Float = 0.05;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;
	public var replayTxt:FlxText; 

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;

	//KE replay system
	public static var rep:Replay;
	public static var loadRep:Bool = false;
	public var repNoteIndex:Int = 0; // 回放音符索引
	private var replayMissTimer:FlxTimer; // 回放miss计时器
	private var lastReplayTime:Float = 0; // 上一次回放时间
	private var replayNoteQueue:Array<Array<Dynamic>> = []; // 回放音符队列（明确类型）
	public static var inReplay:Bool = false; 
	public static var replayFileName:String = "";

	var scoreTxtColorTween:FlxTween;
	var scoreTxtDefaultColor:FlxColor = 0xFFFFFFFF;

	// New modular UI objects (migrated out of inline PlayState code)
	var healthTextObj:objects.HealthText;
	var judgementCounterObj:objects.JudgementCounter;
	var songInfoTextObj:objects.SongInfoText;

	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;



	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	public var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Lua shit
	public static var instance:PlayState;
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end
	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;
	public var songName:String;

	// Callbacks for stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	private static var _lastLoadedModDirectory:String = '';
	public static var nextReloadAll:Bool = false;

	private var modInfoBox:ModInfoBox;
	var hitErrorBar:HitErrorBar;
	public var keyboardViewer:KeyboardViewer;

	override public function create()
	{
		 // ========== 回放系统初始化 ==========
    if (loadRep && rep != null)
    {
        trace('=== REPLAY MODE INITIALIZATION ===');
        trace('Loading replay: ' + rep.path);
        trace('Song: ' + rep.replay.songName);
        
        // 设置回放模式标志
        inReplay = true;
        cpuControlled = false; // 回放模式下禁用自动播放
        practiceMode = false;
        
        // 初始化回放数据
        initReplayData();
        
        trace('Replay mode activated with ${replayNoteQueue.length} notes');
    }

	if (inReplay)
{
    createReplayUI();
}

		//trace('Playback Rate: ' + playbackRate);
		_lastLoadedModDirectory = Mods.currentModDirectory;
		Paths.clearStoredMemory();
		if(nextReloadAll)
		{
			Paths.clearUnusedMemory();
			Language.reloadPhrases();
		}
		nextReloadAll = false;

		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		keysArray = [
			'note_left',
			'note_down',
			'note_up',
			'note_right'
		];

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		opponentMode = ClientPrefs.getGameplaySetting('opponentplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		persistentUpdate = true;
		persistentDraw = true;

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if DISCORD_ALLOWED
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		storyDifficultyText = Difficulty.getString();

		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if(SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));

		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else if (stageData.isPixelStage == true) //Backward compatibility
			stageUI = "pixel";

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage)
		{
			case 'stage': new StageWeek1(); 			//Week 1
			case 'spooky': new Spooky();				//Week 2
			case 'philly': new Philly();				//Week 3
			case 'limo': new Limo();					//Week 4
			case 'mall': new Mall();					//Week 5 - Cocoa, Eggnog
			case 'mallEvil': new MallEvil();			//Week 5 - Winter Horrorland
			case 'school': new School();				//Week 6 - Senpai, Roses
			case 'schoolEvil': new SchoolEvil();		//Week 6 - Thorns
			case 'tank': new Tank();					//Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new PhillyStreets(); 	//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new PhillyBlazin();	//Weekend 1 - Blazin
		}
		if(isPixelStage) introSoundsSuffix = '-pixel';

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		luaDebugGroup = new FlxTypedGroup<psychlua.DebugLuaText>();
		if (ClientPrefs.data.luadebugPrint)
		{
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		}
		#end

		if (!stageData.hide_girlfriend)
		{
			if(SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		
		if(stageData.objects != null && stageData.objects.length > 0)
		{
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup, boyfriendGroup, this);
			for (key => spr in list)
				if(!StageData.reservedNames.contains(key))
					variables.set(key, spr);
		}
		else
		{
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// "SCRIPTS FOLDER" SCRIPTS
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					new FunkinLua(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}
		#end
			
		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// STAGE SCRIPTS
		#if LUA_ALLOWED startLuasNamed('stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('stages/' + curStage + '.hx'); #end

		// CHARACTER SCRIPTS
		if(gf != null) startCharacterScripts(gf.curCharacter);
		startCharacterScripts(dad.curCharacter);
		startCharacterScripts(boyfriend.curCharacter);
		#end

		uiGroup = new FlxSpriteGroup();
		comboGroup = new FlxSpriteGroup();
		noteGroup = new FlxTypedGroup<FlxBasic>();
		add(comboGroup);
		add(uiGroup);
		add(noteGroup);

		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if(ClientPrefs.data.downScroll) timeTxt.y = FlxG.height - 44;
		if(ClientPrefs.data.timeBarType == 'Song Name') timeTxt.text = SONG.song;

		if(ClientPrefs.data.customColor && ClientPrefs.data.gradientTimeBar) {
			timeBar = new GradientTimeBar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		} else {
			// 使用普通Bar
			timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		}
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		noteGroup.add(strumLineNotes);

		noteHoldCover = new NoteHoldCover();
		noteGroup.add(noteHoldCover);
		if(ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		generateSong();

		noteGroup.add(grpNoteSplashes);

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		uiGroup.add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		uiGroup.add(scoreTxt);

		botplayTxt = new FlxText(400, healthBar.y - 90, FlxG.width - 800, Language.getPhrase("Botplay").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		uiGroup.add(botplayTxt);

		replayTxt = new FlxText(400, healthBar.y + (ClientPrefs.data.downScroll ? 100 : -150), FlxG.width - 800, "REPLAY MODE", 32);
		replayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		replayTxt.scrollFactor.set();
		replayTxt.borderSize = 1.25;
		replayTxt.visible = false;
		uiGroup.add(replayTxt);

		// Instantiate modular UI objects (migrated to objects/)
		healthTextObj = new objects.HealthText(this);
		judgementCounterObj = new objects.JudgementCounter(this);
		songInfoTextObj = new objects.SongInfoText(this);

		keyboardViewer = new KeyboardViewer(FlxG.width/2  - 100 + ClientPrefs.data.kbOffsetX, FlxG.height - 150 + ClientPrefs.data.kbOffsetY);
		keyboardViewer.antialiasing = ClientPrefs.data.antialiasing;
		keyboardViewer.cameras = [camOther];
		if (ClientPrefs.data.kb) add(keyboardViewer);
		if (ClientPrefs.data.hitErrorBarVisible)
		{
			hitErrorBar = new HitErrorBar();
			hitErrorBar.screenCenter();
			hitErrorBar.x -= 250 + ClientPrefs.data.hitErrorBarOffsetX;
			hitErrorBar.y = FlxG.height * 0.3 + ClientPrefs.data.hitErrorBarOffsetY; // 顶部10%位置
			if (ClientPrefs.data.downScroll) {
       		 hitErrorBar.y = FlxG.height - 100 + ClientPrefs.data.hitErrorBarOffsetY;
    		}
			uiGroup.add(hitErrorBar);
		}

		createModInfoBox();

		if(ClientPrefs.data.downScroll)
			botplayTxt.y = healthBar.y + 70;

		uiGroup.cameras = [camHUD];
		noteGroup.cameras = [camHUD];
		comboGroup.cameras = [camHUD];

		startingSong = true;

		reloadTimeBarAndTextColors();
		reloadCounterColors();

		#if LUA_ALLOWED
		for (notetype in noteTypes)
			startLuasNamed('custom_notetypes/' + notetype + '.lua');
		for (event in eventsPushed)
			startLuasNamed('custom_events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
			startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		for (event in eventsPushed)
			startHScriptsNamed('custom_events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		// SONG SPECIFIC SCRIPTS
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/$songName/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					new FunkinLua(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}
		#end

		if(eventNotes.length > 0)
		{
			for (event in eventNotes) event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		startCallback();
		RecalculateRating(false, false);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		//PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		if(ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');
		if(!ClientPrefs.data.ghostTapping) for (i in 1...4) Paths.sound('missnote$i');
		Paths.image('alphabet');

		if (PauseSubState.songName != null)
			Paths.music(PauseSubState.songName);
		else if(Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
			Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));

		resetRPC();

		stagesFunc(function(stage:BaseStage) stage.createPost());
		callOnScripts('onCreatePost');
		
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; //cant make it invisible or it won't allow precaching

		super.create();
		rep = new Replay("");

		// 使用新的 JudgementCounter 模块替代旧的 createCounterUI
		if (judgementCounterObj == null) judgementCounterObj = new objects.JudgementCounter(this);

		Paths.clearUnusedMemory();

		cacheCountdown();
		cachePopUpScore();

		if(eventNotes.length < 1) checkEventNote();
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
		{
			vocals.pitch = value;
			opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.offset = Reflect.hasField(PlayState.SONG, 'offset') ? (PlayState.SONG.offset / value) : 0;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if VIDEOS_ALLOWED
		if(videoCutscene != null && videoCutscene.videoSprite != null) videoCutscene.videoSprite.bitmap.rate = value;
		#end
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return playbackRate;
	}

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	public function addTextToDebug(text:String, color:FlxColor) {
		var newText:psychlua.DebugLuaText = luaDebugGroup.recycle(psychlua.DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:psychlua.DebugLuaText) {
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);

		Sys.println(text);
	}
	#end

	public function reloadHealthBarColors() {
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
			}

	public function reloadTimeBarAndTextColors() {
    if(ClientPrefs.data.customColor){
        var opponentColor:FlxColor = FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]);
        var playerColor:FlxColor = FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]);
        
        // 更新TimeBar颜色
        if (timeBar != null) {
            if(Std.isOfType(timeBar, GradientTimeBar)) {
                // 渐变TimeBar - 更新渐变颜色
                var gradientBar:GradientTimeBar = cast timeBar;
                gradientBar.updateGradientColors(opponentColor, playerColor);
            } else if(Std.isOfType(timeBar, Bar)) {
                // 普通Bar - 设置单色
                var bar:Bar = cast timeBar;
                bar.setColors(opponentColor);
            }
        }
        
        if (scoreTxt != null) {
            scoreTxt.color = opponentColor;
        }
        
        if (botplayTxt != null) {
            botplayTxt.color = opponentColor;
        }
    } else {
        if (timeBar != null) {
            if(Std.isOfType(timeBar, GradientTimeBar)) {
                var gradientBar:GradientTimeBar = cast timeBar;
                gradientBar.updateGradientColors(0xFFFFFFFF, 0xFFFFFFFF);
            } else if(Std.isOfType(timeBar, Bar)) {
                var bar:Bar = cast timeBar;
                bar.setColors(0xFFFFFFFF);
            }
        }
    }
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String)
	{
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(replacePath))
		{
			luaFile = replacePath;
			doPush = true;
		}
		else
		{
			luaFile = Paths.getSharedPath(luaFile);
			if(FileSystem.exists(luaFile))
				doPush = true;
		}
		#else
		luaFile = Paths.getSharedPath(luaFile);
		if(Assets.exists(luaFile)) doPush = true;
		#end

		if(doPush)
		{
			for (script in luaArray)
			{
				if(script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}
			if(doPush) new FunkinLua(luaFile);
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(scriptFile);
		if(FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		#end
		{
			scriptFile = Paths.getSharedPath(scriptFile);
			if(FileSystem.exists(scriptFile))
				doPush = true;
		}

		if(doPush)
		{
			if(Iris.instances.exists(scriptFile))
				doPush = false;

			if(doPush) initHScript(scriptFile);
		}
		#end
	}

	public function getLuaObject(tag:String):Dynamic
		return variables.get(tag);

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public var videoCutscene:VideoSprite = null;
	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = !forMidSong;
		canPause = forMidSong;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;

		if (foundFile)
		{
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);
			if(forMidSong) videoCutscene.videoSprite.bitmap.rate = playbackRate;

			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (!isDead && generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = true;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
			}
			if (GameOverSubstate.instance != null && isDead) GameOverSubstate.instance.add(videoCutscene);
			else add(videoCutscene);

			if (playOnLoad)
				videoCutscene.play();
			return videoCutscene;
		}
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		else addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		#else
		else FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	function startAndEnd()
	{
		if(endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = switch(stageUI) {
			case "pixel": ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
			case "normal": ["ready", "set" ,"go"];
			default: ['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
		}
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts) Paths.image(asset);

		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown()
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if(ret != LuaUtils.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			canPause = true;
			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			var swagCounter:Int = 0;
			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch(stageUI) {
					case "pixel": ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
					case "normal": ["ready", "set" ,"go"];
					default: ['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
				var tick:Countdown = THREE;

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
						tick = THREE;
					case 1:
						countdownReady = createCountdownSprite(introAlts[0], antialias);
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
						tick = TWO;
					case 2:
						countdownSet = createCountdownSprite(introAlts[1], antialias);
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
						tick = ONE;
					case 3:
						countdownGo = createCountdownSprite(introAlts[2], antialias);
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
						tick = GO;
					case 4:
						tick = START;
				}

				if(!skipArrowStartTween)
				{
					notes.forEachAlive(function(note:Note) {
						if(ClientPrefs.data.opponentStrums || note.mustPress)
						{
							note.copyAlpha = false;
							note.alpha = ClientPrefs.data.noteAlpha;
							if(ClientPrefs.data.middleScroll && !note.mustPress)
								note.alpha *= 0.35;
						}
					});
				}

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tick, swagCounter]);

				swagCounter += 1;
			}, 5);
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(noteGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	public dynamic function updateScore(miss:Bool = false, scoreBop:Bool = true)
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [miss], true);
		if (ret == LuaUtils.Function_Stop)
			return;

		updateScoreText();
		if (!miss && !cpuControlled && scoreBop)
			doScoreBop();

		callOnScripts('onUpdateScore', [miss]);
	}

	public dynamic function updateScoreText()
	{
		var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
		var str:String = Language.getPhrase('rating_$ratingName', ratingName) ;
		var impstr:String = Language.getPhrase('rating_$ratingName', ratingName) ;
		if(totalPlayed != 0)
		{
			str += ' (${percent}%) - ' + Language.getPhrase(ratingFC);
			impstr = '${percent}%' + ' [${Language.getPhrase(ratingFC)}]';
		}

		var tempScore:String;
		if(!instakillOnMiss) tempScore = Language.getPhrase('score_text', 'Score: {1} | Combo Breaks: {2} | Accuracy: {3}', [songScore, songMisses, impstr]);
		else tempScore = Language.getPhrase('score_text_instakill', 'Score: {1} | Rating: {2}', [songScore, str]);
		scoreTxt.text = tempScore;
	}

	public dynamic function fullComboFunction()
	{
		var marvelous:Int = ratingsData[0].hits;
		var sicks:Int = ratingsData[1].hits;
		var goods:Int = ratingsData[2].hits;
		var bads:Int = ratingsData[3].hits;
		var shits:Int = ratingsData[4].hits;
		var totalHits:Int = marvelous + sicks + goods + bads + shits;

		if (judgementCounterObj != null) judgementCounterObj.update();

		ratingFC = "";
		if(songMisses == 0)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0 || marvelous > 0) ratingFC = 'SFC';
		}
		else {
			if (songMisses < 10) ratingFC = 'SDCB';
			else ratingFC = 'Clear';
		}
	}
public function reloadCounterColors()
	{
		// Delegate counter/health/song color refresh to modules
		if (judgementCounterObj != null) judgementCounterObj.update();
		if (healthTextObj != null) healthTextObj.refresh();
		if (songInfoTextObj != null) songInfoTextObj.refresh();
	}

	function getOpponentHealthColor():FlxColor {
    if(dad != null && dad.healthColorArray != null) {
        var colors:Array<Int> = dad.healthColorArray;
        if(colors.length >= 3) {
            return FlxColor.fromRGB(colors[0], colors[1], colors[2]);
        }
    }
    return 0xFF149DFF;
}

	function updateHealthTextPosition()
    {
		// Delegate to modular HealthText
		if (healthTextObj != null) healthTextObj.refresh();
    }

	public function doScoreBop():Void {
		if(!ClientPrefs.data.scoreZoom)
			return;
		if(ClientPrefs.data.customColor){
		if (judgementCounterObj != null) judgementCounterObj.update();
		if (healthTextObj != null) healthTextObj.refresh();
		if (songInfoTextObj != null) songInfoTextObj.refresh();
	}
		if(scoreTxtTween != null)
			scoreTxtTween.cancel();

		scoreTxt.scale.x = 1.075;
		scoreTxt.scale.y = 1.075;
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(twn:FlxTween) {
				scoreTxtTween = null;
			}
		});
	}

	public function setSongTime(time:Float)
	{
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();

		FlxG.sound.music.time = time - Conductor.offset;
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.play();

		if (Conductor.songPosition < vocals.length)
		{
			vocals.time = time - Conductor.offset;
			#if FLX_PITCH vocals.pitch = playbackRate; #end
			vocals.play();
		}
		else vocals.pause();

		if (Conductor.songPosition < opponentVocals.length)
		{
			opponentVocals.time = time - Conductor.offset;
			#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
			opponentVocals.play();
		}
		else opponentVocals.pause();
		Conductor.songPosition = time;
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;
		
		if (modInfoBox != null && modInfoBox.shouldDisplay)
    {
        modInfoBox.slideIn();
    }

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		vocals.play();
		opponentVocals.play();

		setSongTime(Math.max(0, startOnTime - 500) + Conductor.offset);
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		if(autoUpdateRPC) DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
	}

	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];
	private var totalColumns: Int = 4;

	private function generateSong():Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(songData.song, (boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song));
				
				var oppVocals = Paths.voices(songData.song, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
				if(oppVocals != null && oppVocals.length > 0) opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch (e:Dynamic) {}

		#if FLX_PITCH
		vocals.pitch = playbackRate;
		opponentVocals.pitch = playbackRate;
		#end
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		noteGroup.add(notes);

		try
		{
			var eventsChart:SwagSong = Song.getChart('events', songName);
			if(eventsChart != null)
				for (event in eventsChart.events) //Event Notes
					for (i in 0...event[1].length)
						makeEvent(event, i);
		}
		catch(e:Dynamic) {}

		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = PlayState.SONG.notes;
		var ghostNotesCaught:Int = 0;
		var daBpm:Float = Conductor.bpm;
	
		for (section in sectionsData)
		{
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i in 0...section.sectionNotes.length)
			{
				final songNotes: Array<Dynamic> = section.sectionNotes[i];
				var spawnTime: Float = songNotes[0];
				var noteColumn: Int = Std.int(songNotes[1] % totalColumns);
				var holdLength: Float = songNotes[2];
				var noteType: String = !Std.isOfType(songNotes[3], String) ? Note.defaultNoteTypes[songNotes[3]] : songNotes[3];
				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				var gottaHitNote:Bool = (songNotes[1] < totalColumns);

				if (i != 0) {
					// CLEAR ANY POSSIBLE GHOST NOTES
					for (evilNote in unspawnNotes) {
						var matches: Bool = (noteColumn == evilNote.noteData && gottaHitNote == evilNote.mustPress && evilNote.noteType == noteType);
						if (matches && Math.abs(spawnTime - evilNote.strumTime) < flixel.math.FlxMath.EPSILON) {
							if (evilNote.tail.length > 0)
								for (tail in evilNote.tail)
								{
									tail.destroy();
									unspawnNotes.remove(tail);
								}
							evilNote.destroy();
							unspawnNotes.remove(evilNote);
							ghostNotesCaught++;
							//continue;
						}
					}
				}

				var swagNote:Note = new Note(spawnTime, noteColumn, oldNote);
				var isAlt: Bool = section.altAnim && !gottaHitNote;
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
				swagNote.animSuffix = isAlt ? "-alt" : "";
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = holdLength;
				swagNote.noteType = noteType;
	
				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);

				var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
				final roundSus:Int = Math.round(swagNote.sustainLength / curStepCrochet);
				if(roundSus > 0)
				{
					for (susNote in 0...roundSus)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(spawnTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);

						sustainNote.correctionOffset = swagNote.height / 2;
						if(!PlayState.isPixelStage)
						{
							if(oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
							}

							if(ClientPrefs.data.downScroll)
								sustainNote.correctionOffset = 0;
						}
						else if(oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
						}

						if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
						else if(ClientPrefs.data.middleScroll)
						{
							sustainNote.x += 310;
							if(noteColumn > 1) //Up and Right
								sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(ClientPrefs.data.middleScroll)
				{
					swagNote.x += 310;
					if(noteColumn > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}
				if(!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);

				oldNote = swagNote;
			}
		}
		trace('["${SONG.song.toUpperCase()}" CHART INFO]: Ghost Notes Cleared: $ghostNotesCaught');
		for (event in songData.events) //Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote) {
		eventPushedUnique(event);
		if(eventsPushed.contains(event.event)) {
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote) {
		switch(event.event) {
			case "Change Character":
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if(Math.isNaN(val1)) val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				Paths.sound(event.value1); //Precache sound
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float {
		var returnedValue:Null<Float> = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true);
		if(returnedValue != null && returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', [subEvent.event, subEvent.value1 != null ? subEvent.value1 : '', subEvent.value2 != null ? subEvent.value2 : '', subEvent.strumTime]);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = ClientPrefs.data.noteAlpha;
			if (player < 1)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				//babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {/*y: babyArrow.y + 10,*/ alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else
			{
				if(ClientPrefs.data.middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				opponentVocals.pause();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		super.closeSubState();
		
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong && canResync)
			{
				resyncVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = true);

			paused = false;
			callOnScripts('onResume');
			resetRPC(startTimer != null && startTimer.finished);
		}
	}

	#if DISCORD_ALLOWED
	override public function onFocus():Void
	{
		super.onFocus();
		if (!paused && health > 0)
		{
			resetRPC(Conductor.songPosition > 0.0);
		}
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();
		if (!paused && health > 0 && autoUpdateRPC)
		{
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
	}
	#end

	// Updating Discord Rich Presence.
	public var autoUpdateRPC:Bool = true; //performance setting for custom RPC things
	function resetRPC(?showTime:Bool = false)
	{
		#if DISCORD_ALLOWED
		if(!autoUpdateRPC) return;

		if (showTime)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.data.noteOffset);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			}
			else voc.pause();
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var freezeCamera:Bool = false;
	var allowDebugKeys:Bool = true;

	override public function update(elapsed:Float)
	{
		     if (inReplay && !paused && !endingSong && !startingSong && generatedMusic)
    {
        processReplayNotes(elapsed);
    }
    
	if(ClientPrefs.data.skipDeath&& health <=0)  
	{	
		openPauseMenu();
		PauseSubState.restartSong();
	}
		if(!inCutscene && !paused && !freezeCamera) {
			FlxG.camera.followLerp = 0.04 * cameraSpeed * playbackRate;
			var idleAnim:Bool = (boyfriend.getAnimationName().startsWith('idle') || boyfriend.getAnimationName().startsWith('danceLeft') || boyfriend.getAnimationName().startsWith('danceRight'));
			if(!startingSong && !endingSong && idleAnim) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		}
		else FlxG.camera.followLerp = 0;
		callOnScripts('onUpdate', [elapsed]);

		super.update(elapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if(botplayTxt != null && botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

 		if (controls.PAUSE && startedCountdown && canPause || FlxG.mouse.justPressedRight || FlxG.mouse.justPressedMiddle)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if(ret != LuaUtils.Function_Stop) {
				openPauseMenu();
			}
		}

		if(!endingSong && !inCutscene && allowDebugKeys)
		{
			if (controls.justPressed('debug_1'))
				openChartEditor();
			else if (controls.justPressed('debug_2'))
				openCharacterEditor();
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
			health = healthBar.bounds.max;

		updateIconsScale(elapsed);
		updateIconsPosition();

		if (startedCountdown && !paused)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			if (Conductor.songPosition >= Conductor.offset)
			{
				Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));
				var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			var songCalc:Float = (songLength - curTime);
			if(ClientPrefs.data.timeBarType == 'Time Elapsed') songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if(secondsTotal < 0) secondsTotal = 0;

			if(ClientPrefs.data.timeBarType != 'Song Name')
				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if(songSpeed < 1) time /= songSpeed;
			if(unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled)
					keysCheck();
				else
					playerDance();

				if(notes.length > 0)
				{
					if(startedCountdown)
					{
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						var i:Int = 0;
						while(i < notes.length)
						{
							var daNote:Note = notes.members[i];
							if(daNote == null) continue;

							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if(!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if(daNote.mustPress)
							{
								if(cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
								opponentNoteHit(daNote);

							if(daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
							{
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
									noteMiss(daNote);

								daNote.active = daNote.visible = false;
								invalidateNote(daNote);
							}
							if(daNote.exists) i++;
						}
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		if (healthTextObj != null) healthTextObj.refresh();
		if (judgementCounterObj != null) judgementCounterObj.update();

		setOnScripts('botPlay', cpuControlled);
		callOnScripts('onUpdatePost', [elapsed]);
	}

	// Health icon updaters
	public dynamic function updateIconsScale(elapsed:Float)
	{
		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	public dynamic function updateIconsPosition()
	{
		var iconOffset:Int = 26;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
	}

	var iconsAnimations:Bool = true;
	function set_health(value:Float):Float // You can alter how icon animations work here
	{
		value = FlxMath.roundDecimal(value, 5); //Fix Float imprecision
		if(!iconsAnimations || healthBar == null || !healthBar.enabled || healthBar.valueFunction == null)
		{
			health = value;
			return health;
		}

		// update health bar
		health = value;
		var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max), healthBar.bounds.min, healthBar.bounds.max, 0, 100);
		healthBar.percent = (newPercent != null ? newPercent : 0);

		iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : 0; //If health is under 20%, change player icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		iconP2.animation.curAnim.curFrame = (healthBar.percent > 80) ? 1 : 0; //If health is over 80%, change opponent icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		return health;
	}

	function openPauseMenu()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		if(FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}
		if(!cpuControlled)
		{
			for (note in playerStrums)
				if(note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}
		if (ClientPrefs.data.charmPause)
		{
		openSubState(new NewPauseSubState());
		}
		else
		{
		openSubState(new PauseSubState());
		}

		#if DISCORD_ALLOWED
		if(autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function openChartEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		chartingMode = true;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		MusicBeatState.switchState(new ChartingState());
	}

	function openCharacterEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	public var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead && gameOverTimer == null && !ClientPrefs.data.skipDeath)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if(ret != LuaUtils.Function_Stop)
			{
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;
				#if VIDEOS_ALLOWED
				if(videoCutscene != null)
				{
					videoCutscene.destroy();
					videoCutscene = null;
				}
				#end

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				FlxG.camera.filters =[];

				if(GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				return;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float) {
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if(Math.isNaN(flValue1)) flValue1 = null;
		if(Math.isNaN(flValue2)) flValue2 = null;

		switch(eventName) {
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				if(flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if(flValue1 == null || flValue1 < 1) flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if(ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35) {
					if(flValue1 == null) flValue1 = 0.015;
					if(flValue2 == null) flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						if(flValue2 == null) flValue2 = 0;
						switch(Math.round(flValue2)) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					isCameraOnForcedPos = false;
					if(flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if(flValue1 == null) flValue1 = 0;
						if(flValue2 == null) flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character':
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf') {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			if(ClientPrefs.data.customColor){
                reloadTimeBarAndTextColors();
                reloadCounterColors();
            }

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if(flValue1 == null) flValue1 = 1;
					if(flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if(flValue2 <= 0)
						songSpeed = newValue;
					else
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {ease: FlxEase.linear, onComplete:
							function (twn:FlxTween)
							{
								songSpeedTween = null;
							}
						});
				}

			case 'Set Property':
				try
				{
					var trueValue:Dynamic = value2.trim();
					if (trueValue == 'true' || trueValue == 'false') trueValue = trueValue == 'true';
					else if (flValue2 != null) trueValue = flValue2;
					else trueValue = value2;

					var split:Array<String> = value1.split('.');
					if(split.length > 1) {
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1], trueValue);
					} else {
						LuaUtils.setVarInArray(this, value1, trueValue);
					}
				}
				catch(e:Dynamic)
				{
					var len:Int = e.message.indexOf('\n') + 1;
					if(len <= 0) len = e.message.length;
					#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
					#else
					FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
					#end
				}

			case 'Play Sound':
				if(flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
	}

	public function moveCameraSection(?sec:Null<Int>):Void {
		if(sec == null) sec = curSection;
		if(sec < 0) sec = 0;

		if(SONG.notes[sec] == null) return;

		if (gf != null && SONG.notes[sec].gfSection)
		{
			moveCameraToGirlfriend();
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		moveCamera(isDad);
		if (isDad)
			callOnScripts('onMoveCamera', ['dad']);
		else
			callOnScripts('onMoveCamera', ['boyfriend']);
	}
	
	public function moveCameraToGirlfriend()
	{
		camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
		camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
		camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
		tweenCamIn();
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if(isDad)
		{
			if(dad == null) return;
			camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			if(boyfriend == null) return;
			camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
					function (twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	public function tweenCamIn() {
		if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3) {
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();
		opponentVocals.volume = 0;
		opponentVocals.pause();

		if(ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset) {
			endCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
				endCallback();
			});
		}
	}


	public var transitioning = false;
	public function endSong():Void
{
	//Should kill you if you tried to cheat
	if(!startingSong)
	{
		notes.forEachAlive(function(daNote:Note)
		{
			if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
				health -= 0.05 * healthLoss;
		});
		for (daNote in unspawnNotes)
		{
			if(daNote != null && daNote.strumTime < songLength - Conductor.safeZoneOffset)
				health -= 0.05 * healthLoss;
		}

		if(doDeathCheck()) {
			return;
		}
	}

	timeBar.visible = false;
	timeTxt.visible = false;
	canPause = false;
	endingSong = true;
	camZooming = false;
	inCutscene = false;
	updateTime = false;

	deathCounter = 0;
	seenCutscene = false;

	#if ACHIEVEMENTS_ALLOWED
	var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
	checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie' #if BASE_GAME_FILES, 'debugger' #end]);
	#end

	var ret:Dynamic = callOnScripts('onEndSong', null, true);
	if(ret != LuaUtils.Function_Stop && !transitioning)
	{
		#if !switch
		var percent:Float = ratingPercent;
		if(Math.isNaN(percent)) percent = 0;

		// 只在非回放模式下保存分数
		if (!loadRep && !inReplay)
		{
			Highscore.saveScore(Song.loadedSongName, songScore, storyDifficulty, percent);
		}
		#end
		
		if (loadRep || inReplay)
		{
			// ========== 回放结束，直接读取回放文件并显示结果 ==========
			trace('Replay mode ended, loading replay file for results...');
			
			// 停止所有声音
			if (vocals != null) vocals.stop();
			if (FlxG.sound.music != null) FlxG.sound.music.stop();
			
			// 获取当前回放的文件名（你需要一种方式来存储它）
			// 方法1：如果已经在PlayState中存储了replayFileName
			if (replayFileName != null && replayFileName.length > 0)
			{
				// 直接打开结果界面，并传递文件名
				paused = true;
				canPause = false;
				inResults = true;
				transitioning = true;
				
				// 传递文件名，让ResultsScreen自己读取文件
				openSubState(new ResultsScreen(replayFileName));
			}
			else
			{
				// 方法2：如果没有存储文件名，尝试从rep对象重建
				trace('No replay filename stored, attempting to find replay file...');
				
				// 查找最近创建的回放文件
				#if sys
				var replayDir = "assets/replays/";
				if (FileSystem.exists(replayDir))
				{
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
					
					// 找到第一个.kadeReplay文件
					for (file in files) {
						if (file.endsWith(".kadeReplay")) {
							trace('Found latest replay: $file');
							paused = true;
							canPause = false;
							inResults = true;
							transitioning = true;
							openSubState(new ResultsScreen(file));
							break;
						}
					}
				}
				#end
			}
			
			// 清理回放相关变量
			loadRep = false;
			inReplay = false;
			rep = null;
			replayNoteQueue = [];
			repNoteIndex = 0;
			
			if (replayTxt != null)
			{
				replayTxt.visible = false;
			}
			
			return; // 重要：不要继续执行后面的代码
		}
		
		playbackRate = 1;

		if (chartingMode)
		{
			openChartEditor();
			return; 
		}

		// ========== 保存回放数据 ==========
		if (!loadRep && rep != null && !practiceMode && !cpuControlled && !inReplay && ClientPrefs.data.saveReplays)
		{
			try
			{
				rep.finishRecording();
				rep.SaveReplay(rep.replay.songNotes, rep.replay.songJudgements, rep.replay.ana);
				trace('Replay saved successfully with ' + rep.replay.songNotes.length + ' notes');
			}
			catch (e:Dynamic)
			{
				trace('Error saving replay: ' + e);
			}
		}
		
		// ========== 结算页面逻辑 ==========
		if (ClientPrefs.data.scoreScreen && !loadRep && !inReplay)
		{
			if (vocals != null) vocals.stop();
			if (FlxG.sound.music != null) FlxG.sound.music.stop();
			
			paused = true;
			canPause = false;
		
			openSubState(new ResultsScreen());
			inResults = true;
			
			transitioning = true;
		}
		else
		{
			proceedToNextState();
		}
	}
}

public function proceedToNextState():Void
{
	// 确保游戏音乐已经停止
	if (vocals != null) vocals.stop();
	if (FlxG.sound.music != null) FlxG.sound.music.stop();
	
	if (isStoryMode)
	{
		campaignScore += songScore;
		campaignMisses += songMisses;

		storyPlaylist.remove(storyPlaylist[0]);

		if (storyPlaylist.length <= 0)
		{
			Mods.loadTopMod();
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

			canResync = false;
			MusicBeatState.switchState(new StoryMenuState());

			if(!ClientPrefs.getGameplaySetting('practice') && !ClientPrefs.getGameplaySetting('botplay')) {
				StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
				Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

				FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
				FlxG.save.flush();
			}
			changedDifficulty = false;
		}
		else
		{
			var difficulty:String = Difficulty.getFilePath();

			trace('LOADING NEXT SONG');
			trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			prevCamFollow = camFollow;

			Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
			FlxG.sound.music.stop();

			canResync = false;
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState(), false, false);
		}
	}
	else
	{
		trace('WENT BACK TO FREEPLAY??');
		Mods.loadTopMod();
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

		canResync = false;
		if(ClientPrefs.data.newFreeplay)
		{
			MusicBeatState.switchState(new NewFreeplayState());
		}
		else
		{
			MusicBeatState.switchState(new FreeplayState());
		}
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		changedDifficulty = false;
	}
	transitioning = true;
}
		
	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	// Stores Ratings and Combo Sprites in a group
	public var comboGroup:FlxSpriteGroup;
	// Stores HUD Objects in a Group
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	public var noteGroup:FlxTypedGroup<FlxBasic>;

	private function cachePopUpScore()
{
	var uiFolder:String = "";
	var customUIPath:String = "";
	
	// 获取自定义UI路径（如果存在）
	if (ClientPrefs.data.customUI != null && ClientPrefs.data.customUI != "")
	{
		customUIPath = ClientPrefs.data.customUI + "/";
	}
	
	if (stageUI != "normal")
	{
		// 优先使用自定义UI路径，否则使用默认路径
		if (customUIPath != "")
		{
			uiFolder = 'ratings/' + customUIPath + uiPrefix + "UI/";
		}
		else
		{
			uiFolder =  uiPrefix + "UI/";
		}
	}
	else if (customUIPath != "")
	{
		// 即使stageUI是normal，如果有自定义UI也使用
		uiFolder = 'ratings/' + customUIPath;
	}

	// 缓存评级图片
	for (rating in ratingsData)
	{
		Paths.image(uiFolder + rating.image + uiPostfix);
	}
	
	// 缓存数字图片
	for (i in 0...10)
	{
		Paths.image(uiFolder + 'num' + i + uiPostfix);
	}
	
	// 缓存combo图片
	if (Paths.fileExists('images/' + uiFolder + 'combo' + uiPostfix + '.png', IMAGE))
	{
		Paths.image(uiFolder + 'combo' + uiPostfix);
	}
}

	private function popUpScore(note:Note = null):Void
{
	if (combo >= highestCombo)
	{
		highestCombo = combo;
	}
	// 计算带符号的时间差
	var rawNoteDiff:Float = note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset;
	var noteDiff:Float = Math.abs(rawNoteDiff);
	vocals.volume = 1;

	for (spr in comboGroup)
	{
		if(spr == null) continue;
		
		if (Std.isOfType(spr, FlxText))
		{
			var text:FlxText = cast(spr, FlxText);
			// 如果是毫秒显示，立即销毁
			comboGroup.remove(text);
			text.destroy();
			break;
		}
	}

	if (!ClientPrefs.data.comboStacking && comboGroup.members.length > 0)
	{
		for (spr in comboGroup)
		{
			if(spr == null) continue;

			comboGroup.remove(spr);
			spr.destroy();
		}
	}

	var placement:Float = FlxG.width * 0.35;
	var rating:FlxSprite = new FlxSprite();
	var score:Int = 350;

	// 基于毫秒的判定
	var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

	totalNotesHit += daRating.ratingMod;
	note.ratingMod = daRating.ratingMod;
	if(!note.ratingDisabled) daRating.hits++;
	note.rating = daRating.name;
	score = daRating.score;

	// 添加毫秒显示
	var msTiming:Float = Math.round(rawNoteDiff * 100) / 100; // 保留3位小数
	var currentTimingShown:FlxText = null;
	
	if(daRating.noteSplash && !note.noteSplashData.disabled)
		spawnNoteSplashOnNote(note);

	if(!cpuControlled) {
		songScore += score;
		if(!note.ratingDisabled)
		{
			songHits++;
			totalPlayed++;
			RecalculateRating(false);
		}
	}

	var uiFolder:String = "";
	var customUIPath:String = "";
	var antialias:Bool = ClientPrefs.data.antialiasing;
	
	// 获取自定义UI路径
	if (ClientPrefs.data.customUI != null && ClientPrefs.data.customUI != "")
	{
		customUIPath = ClientPrefs.data.customUI + "/";
	}
	
	if (stageUI != "normal")
	{
		// 优先使用自定义UI路径，否则使用默认路径
		if (customUIPath != "")
		{
			uiFolder = 'ratings/' + customUIPath + uiPrefix + "UI/";
		}
		else
		{
			uiFolder = uiPrefix + "UI/";
		}
		antialias = !isPixelStage;
	}
	else if (customUIPath != "")
	{
		uiFolder = 'ratings/' + customUIPath;
	}

	// ==================== FOREVER套系特殊逻辑开始 ====================
	var ratingImageToUse:String = daRating.image;
	var shouldUseGoldenNumbers:Bool = false;
	
	// 检查是否为Forever套系
	var isForeverUI:Bool = (customUIPath.toLowerCase().contains("forever") || 
	                       (ClientPrefs.data.customUI != null && 
	                        ClientPrefs.data.customUI.toLowerCase().contains("forever")));
	
	if (isForeverUI)
	{
		// 检查ratingFC是否为MFC或SFC
		var isMFCOrSFC:Bool = (ratingFC == "MFC" || ratingFC == "SFC");
		
		// 如果ratingFC为MFC或SFC，始终使用Marvelous
		// 否则只在22.5ms内使用Marvelous
		if (isMFCOrSFC || (noteDiff <= ClientPrefs.data.marvelousWindow && daRating.name != "shit" && daRating.name != "bad" && daRating.name != "good"))
		{
			ratingImageToUse = "marvelous";
			shouldUseGoldenNumbers = true;
		}
		else
		{
			// 对于good/bad/shit评级，添加Early/Late后缀
			if (daRating.name == "good" || daRating.name == "bad" || daRating.name == "shit")
			{
				if (rawNoteDiff > 0)
				{
					ratingImageToUse = daRating.image + "-e"; // Early后缀
				}
				else
				{
					ratingImageToUse = daRating.image + "-l"; // Late后缀
				}
			}
		}
	}
	// ==================== FOREVER套系特殊逻辑结束 ====================

	var ratingImagePath:String = uiFolder + ratingImageToUse + uiPostfix;
	if (!Paths.fileExists('images/' + ratingImagePath + '.png', IMAGE) && uiFolder != "")
	{
		// 如果带后缀的图片不存在，尝试使用原始评级图片
		if (ratingImageToUse.contains("-e") || ratingImageToUse.contains("-l"))
		{
			ratingImagePath = uiFolder + daRating.image + uiPostfix;
			if (!Paths.fileExists('images/' + ratingImagePath + '.png', IMAGE))
			{
				var fallbackFolder:String = "";
				if (stageUI != "normal")
					fallbackFolder = uiPrefix + "UI/";
				ratingImagePath = fallbackFolder + daRating.image + uiPostfix;
			}
		}
		else
		{
			var fallbackFolder:String = "";
			if (stageUI != "normal")
				fallbackFolder = uiPrefix + "UI/";
			ratingImagePath = fallbackFolder + daRating.image + uiPostfix;
		}
	}

	rating.loadGraphic(Paths.image(ratingImagePath));
	rating.screenCenter();
	rating.x = placement - 40;
	rating.y -= 60;
	rating.acceleration.y = 550 * playbackRate * playbackRate;
	if (SONG.stage == "ejected")
	{
		rating.velocity.y -= FlxG.random.int(540, 600) * playbackRate;
		rating.velocity.x -= FlxG.random.int(-10, 20) * playbackRate;
	}
	else if (SONG.stage == "airship")
	{
	rating.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
	rating.velocity.x = FlxG.random.float(-250, -300) * playbackRate;	
	}
	else if (SONG.stage == "turbulence")
	{
	rating.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
	rating.velocity.x = FlxG.random.float(250, 300) * playbackRate;	
	}
	else
	{
	rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
	rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
	}
	rating.visible = (!ClientPrefs.data.hideHud && showRating);
	rating.x += ClientPrefs.data.comboOffset[0];
	rating.y -= ClientPrefs.data.comboOffset[1];
	rating.antialiasing = antialias;
	
	if (!ClientPrefs.data.hideHud && ClientPrefs.data.showMS)
	{
		var msText:String = (msTiming >= 0 ? "+" : "") + msTiming + "ms";
		
		currentTimingShown = new FlxText(0, 0, 0, msText, 16);
		currentTimingShown.setFormat(Paths.font('pixel-latin.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		
		if (ClientPrefs.data.customColor)
		{
			switch(daRating.name)
			{
				case 'sick': 
					currentTimingShown.color = FlxColor.CYAN;      // 0x00FFFF
				case 'good': 
					currentTimingShown.color = FlxColor.LIME;      // 0x00FF00
				case 'bad': 
					currentTimingShown.color = FlxColor.RED;    // 0xFF0000
				case 'shit': 
					currentTimingShown.color = FlxColor.RED;       // 0x970000
			}
		}
		currentTimingShown.size = 16;
		var msX:Float =	placement + ClientPrefs.data.comboOffset[0] + 175; // rating.x + 100
		var msY:Float = 310 - ClientPrefs.data.comboOffset[1] ;   // rating.y + 50
		currentTimingShown.x += msX;
		currentTimingShown.y += msY;
	}

	// 加载combo图片，检查是否存在
	var comboSpr:FlxSprite = new FlxSprite();
	var comboImagePath:String = uiFolder + 'combo' + uiPostfix;
	if (Paths.fileExists('images/' + comboImagePath + '.png', IMAGE))
	{
		comboSpr.loadGraphic(Paths.image(comboImagePath));
	}
	else
	{
		// 回退到默认路径
		var fallbackFolder:String = "";
		if (stageUI != "normal")
			fallbackFolder = uiPrefix + "UI/";
		comboSpr.loadGraphic(Paths.image(fallbackFolder + 'combo' + uiPostfix));
	}
	
	comboSpr.screenCenter();
	comboSpr.x = placement;
	comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
	comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
	comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
	comboSpr.x += ClientPrefs.data.comboOffset[0];
	comboSpr.y -= ClientPrefs.data.comboOffset[1];
	comboSpr.antialiasing = antialias;
	comboSpr.y += 60;
	comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
	comboGroup.add(rating);
	if (currentTimingShown != null)
		comboGroup.add(currentTimingShown);

	if (!PlayState.isPixelStage)
	{
		rating.setGraphicSize(Std.int(rating.width * 0.7));
		comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
	}
	else
	{
		rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
		comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
	}

	comboSpr.updateHitbox();
	rating.updateHitbox();

	var daLoop:Int = 0;
	var xThing:Float = 0;
	if (showCombo)
		comboGroup.add(comboSpr);

	var separatedScore:String = Std.string(combo).lpad('0', 3);
	
	// 数字根据评级变色
	for (i in 0...separatedScore.length)
	{
		var numImagePath:String;
		
		// ==================== FOREVER套系数字逻辑开始 ====================
		if (isForeverUI && shouldUseGoldenNumbers)
		{
			// 使用金色数字前缀
			numImagePath = uiFolder + 'goldennum' + Std.parseInt(separatedScore.charAt(i)) + uiPostfix;
			
			// 如果金色数字不存在，回退到普通数字
			if (!Paths.fileExists('images/' + numImagePath + '.png', IMAGE))
			{
				numImagePath = uiFolder + 'num' + Std.parseInt(separatedScore.charAt(i)) + uiPostfix;
			}
		}
		else
		{
			// 非Forever套系或非Marvelous情况，使用默认数字
			numImagePath = uiFolder + 'num' + Std.parseInt(separatedScore.charAt(i)) + uiPostfix;
		}
		// ==================== FOREVER套系数字逻辑结束 ====================
		
		// 检查数字图片是否存在，不存在则回退
		if (!Paths.fileExists('images/' + numImagePath + '.png', IMAGE) && uiFolder != "")
		{
			var fallbackFolder:String = "";
			if (stageUI != "normal")
				fallbackFolder = uiPrefix + "UI/";
			numImagePath = fallbackFolder + 'num' + Std.parseInt(separatedScore.charAt(i)) + uiPostfix;
		}
		
		var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(numImagePath));
		numScore.screenCenter();
		numScore.x = placement + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
		numScore.y += 80 - ClientPrefs.data.comboOffset[3];

		if (!PlayState.isPixelStage) 
		{
			numScore.setGraphicSize(Std.int(numScore.width * 0.5));
		}
		else 
		{
			numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
		}
		
		// 根据评级给数字着色
		if (ClientPrefs.data.customColor && ClientPrefs.data.customUI == "Frozen" || ClientPrefs.data.forceNumberColor)
		{
			switch(daRating.name)
			{
			case 'sick':
					numScore.color = 0x00FFFF; // 青色/CYAN
			case 'good':
				numScore.color = 0x00FF00; // 绿色/GREEN
			case 'bad':
				numScore.color = 0xFF0000; // 橙色/ORANGE
			case 'shit':
				numScore.color = 0x690000; // 红色/RED
		}
		}
		
		numScore.updateHitbox();

		numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
		if (SONG.stage == "ejected")
		{
		numScore.velocity.y -= FlxG.random.int(540, 580) * playbackRate;
		numScore.velocity.x = FlxG.random.float(-15, 15) * playbackRate;
		}
		else if (SONG.stage == "airship")
		{
		numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		numScore.velocity.x = FlxG.random.float(-250, -300) * playbackRate;	
		}
		else if (SONG.stage == "turbulence")
		{
		numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		numScore.velocity.x = FlxG.random.float(250, 300) * playbackRate;	
		}
		else
		{
		numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
		}
		numScore.visible = !ClientPrefs.data.hideHud;
		numScore.antialiasing = antialias;

		if(showComboNum)
			comboGroup.add(numScore);

		// 保持原来的消失时间
		FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
			onComplete: function(tween:FlxTween)
			{
				numScore.destroy();
			},
			startDelay: Conductor.crochet * 0.002 / playbackRate
		});

		daLoop++;
		if(numScore.x > xThing) xThing = numScore.x;
	}
	
	comboSpr.x = xThing + 50;
	FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
		startDelay: Conductor.crochet * 0.001 / playbackRate
	});

	FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
		onComplete: function(tween:FlxTween)
		{
			comboSpr.destroy();
			rating.destroy();
		},
		startDelay: Conductor.crochet * 0.002 / playbackRate
	});

	if (currentTimingShown != null)
	{
		FlxTween.tween(currentTimingShown, {alpha: 0}, 0.2 / playbackRate, {
			onComplete: function(tween:FlxTween)
			{},
			startDelay: Conductor.crochet * 0.001 / playbackRate // 与rating同时开始
		});
	}
}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{
	 if (loadRep || inReplay)
        return;
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			//Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return;
			#end

			if(FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		if(cpuControlled || paused || inCutscene || key < 0 || key >= playerStrums.length || !generatedMusic || endingSong || boyfriend.stunned) return;
		if (inReplay || loadRep) return;

		if (keyboardViewer != null) keyboardViewer.pressed(key);

		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if(Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool {
			var canHit:Bool = n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			return canHit && !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		if (plrInputNotes.length != 0) { // slightly faster than doing `> 0` lol
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1) {
				var doubleNote:Note = plrInputNotes[1];

				if (doubleNote.noteData == funnyNote.noteData) {
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
						invalidateNote(doubleNote);
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
			}
			goodNoteHit(funnyNote);
		}
		else
		{
			if (ClientPrefs.data.ghostTapping)
				callOnScripts('onGhostTap', [key]);
			else
				noteMissPress(key);
		}

		// Needed for the  "Just the Two of Us" achievement.
		//									- Shadow Mario
		if(!keysPressed.contains(key)) keysPressed.push(key);

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		var spr:StrumNote = playerStrums.members[key];
		if(strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyPress', [key]);
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
 if(cpuControlled || !startedCountdown || paused || key < 0 || key >= 4) return;

		if (keyboardViewer != null) keyboardViewer.released(key);
		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		var spr:StrumNote = playerStrums.members[key];
		if(spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if(key == noteKey)
						return i;
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		if (startedCountdown && !inCutscene && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0) {
				for (n in notes) { // I can't do a filter here, that's kinda awesome
					var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit
						&& n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;

					if (canHit && n.isSustainNote) {
						var released:Bool = !holdArray[n.noteData];

						if (!released)
							goodNoteHit(n);
					}
				}
			}

			if (!holdArray.contains(true) || endingSong)
				playerDance();

			#if ACHIEVEMENTS_ALLOWED
			else checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note);
		});

		noteMissCommon(daNote.noteData, daNote);
		stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('noteMiss', [daNote]);

		
    if(scoreTxt != null) {
        if(scoreTxtColorTween != null) {
            scoreTxtColorTween.cancel();
        }
        
        if(ClientPrefs.data.customColor){
            scoreTxtColorTween = FlxTween.color(scoreTxt, 0.1, scoreTxt.color, 0xFFFF1512, {
                onComplete: function(twn:FlxTween) {
                    new FlxTimer().start(0.4, function(tmr:FlxTimer) 
                    {
                        FlxTween.color(scoreTxt, 0.1, scoreTxt.color, getOpponentHealthColor());
                    });
                }
            });
        }
        else {
            scoreTxtColorTween = FlxTween.color(scoreTxt, 0.1, scoreTxt.color, 0xFFFF1512, {
                onComplete: function(twn:FlxTween) {
                    new FlxTimer().start(0.4, function(tmr:FlxTimer) 
                    {
                        FlxTween.color(scoreTxt, 0.1, scoreTxt.color, 0xFFFFFFFF);
                    });
                }
            });
        }
    }
    
    // ========== 回放录制 ==========
      if (rep != null && !loadRep && !cpuControlled && !practiceMode && !inReplay)
    {
        rep.recordMiss(daNote.noteData, daNote.strumTime);
        //trace('Replay recorded miss at strumTime: ' + daNote.strumTime);
    }
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.data.ghostTapping) return; //fuck it

		noteMissCommon(direction);
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		callOnScripts('noteMissPress', [direction]);

		    // ========== 回放录制 ==========
        if (rep != null && !loadRep && !cpuControlled && !practiceMode && !inReplay)
    {
        rep.recordMiss(direction, Conductor.songPosition);
    }
	}

	function noteMissCommon(direction:Int, note:Note = null)
	{
		// score and data
		var subtract:Float = pressMissDamage;
		if(note != null) subtract = note.missHealth;

		// GUITAR HERO SUSTAIN CHECK LOL!!!!
		if (note != null && guitarHeroSustains && note.parent == null) {
			if(note.tail.length > 0) {
				note.alpha = 0.35;
				for(childNote in note.tail) {
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				//subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -[REDACTED]
			}

			if (note.missed)
				return;
		}
		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote) {
			if (note.missed)
				return;

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0) {
				for (child in parentNote.tail) if (child != note) {
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		if(instakillOnMiss)
		{
			vocals.volume = 0;
			opponentVocals.volume = 0;
			doDeathCheck(true);
		}

		var lastCombo:Int = combo;
		combo = 0;

		health -= subtract * healthLoss;
		songScore -= 10;
		if(!endingSong) songMisses++;
		totalPlayed++;
		RecalculateRating(true);

		// play character anims
		var char:Character = boyfriend;
		if((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection)) char = gf;

		if(char != null && (note == null || !note.noMissAnimation) && char.hasMissAnimations)
		{
			var postfix:String = '';
			if(note != null) postfix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, direction)))] + 'miss' + postfix;
			char.playAnim(animToPlay, true);

			if(char != gf && lastCombo > 5 && gf != null && gf.hasAnimation('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		vocals.volume = 0;
	}

	function opponentNoteHit(note:Note):Void
	{
		var result:Dynamic = callOnLuas('opponentNoteHitPre', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('opponentNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		if (songName != 'tutorial')
			camZooming = true;

		if(note.noteType == 'Hey!' && dad.hasAnimation('hey'))
		{
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		}
		else if(!note.noAnimation)
		{
			var char:Character = dad;
			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;
			if(note.gfNote) char = gf;

			if(char != null)
			{
				var canPlay:Bool = true;
				if(note.isSustainNote)
				{
					var holdAnim:String = animToPlay + '-hold';
					if(char.animation.exists(holdAnim)) animToPlay = holdAnim;
					if(char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
				}

				if(canPlay) char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		if(opponentVocals.length <= 0) vocals.volume = 1;
		strumPlayAnim(true, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		note.hitByOpponent = true;
		
		stagesFunc(function(stage:BaseStage) stage.opponentNoteHit(note));
		var result:Dynamic = callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('opponentNoteHit', [note]);

		if (note.isSustainNote && noteHoldCover != null)
	{
		if (opponentMode)
		{
		noteHoldCover.onPlayerNoteHit(Std.int(Math.abs(note.noteData)), note.isSustainNote, note);
		}
		else
		{
		noteHoldCover.onOpponentNoteHit(Std.int(Math.abs(note.noteData)), note.isSustainNote, note);
		}
	}
		if (!note.isSustainNote) invalidateNote(note);
	}

	public function goodNoteHit(note:Note):Void
	{
		if(note.wasGoodHit) return;
		if(cpuControlled && note.ignoreNote) return;

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		var result:Dynamic = callOnLuas('goodNoteHitPre', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('goodNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		note.wasGoodHit = true;

		if (note.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);

		if(!note.hitCausesMiss) //Common notes
		{
			if(!note.noAnimation)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;

				var char:Character = boyfriend;
				var animCheck:String = 'hey';
				if(note.gfNote)
				{
					char = gf;
					animCheck = 'cheer';
				}

				if(char != null)
				{
					var canPlay:Bool = true;
					if(note.isSustainNote)
					{
						var holdAnim:String = animToPlay + '-hold';
						if(char.animation.exists(holdAnim)) animToPlay = holdAnim;
						if(char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
					}
	
					if(canPlay) char.playAnim(animToPlay, true);
					char.holdTimer = 0;

					if(note.noteType == 'Hey!')
					{
						if(char.hasAnimation(animCheck))
						{
							char.playAnim(animCheck, true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
					}
				}
			}

			if(!cpuControlled)
			{
				var spr = playerStrums.members[note.noteData];
				if(spr != null) spr.playAnim('confirm', true);
			}
			else strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			vocals.volume = 1;

			if (!note.isSustainNote)
			{
				combo++;
				if(combo > 9999) combo = 9999;
				popUpScore(note);
			}
			var gainHealth:Bool = true; // prevent health gain, *if* sustains are treated as a singular note
			if (guitarHeroSustains && note.isSustainNote) gainHealth = false;
			if (gainHealth) health += note.hitHealth * healthGain;

		}
		else //Notes that count as a miss if you hit them (Hurt notes for example)
		{
			if(!note.noMissAnimation)
			{
				switch(note.noteType)
				{
					case 'Hurt Note':
						if(boyfriend.hasAnimation('hurt'))
						{
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
				}
			}

			noteMiss(note);
			if(!note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(note);
		}

				if (note.isSustainNote && noteHoldCover != null)
		{
			if (opponentMode)
			{
				noteHoldCover.onOpponentNoteHit(Std.int(Math.abs(note.noteData)), note.isSustainNote, note);
			}
			else
			{
				noteHoldCover.onPlayerNoteHit(Std.int(Math.abs(note.noteData)), note.isSustainNote, note);
			}
		}

		stagesFunc(function(stage:BaseStage) stage.goodNoteHit(note));
		var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('goodNoteHit', [note]);
		if(!note.isSustainNote) invalidateNote(note);

		var diff = note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset;

		if (ClientPrefs.data.hitErrorBarVisible) {
		if (hitErrorBar != null && (!isSus )) {
			var hitTime:Float = -diff;
			hitErrorBar.registerHit(hitTime);
		}
		}	

		if (rep != null && !loadRep && !cpuControlled && !practiceMode && !inReplay)
		{
			// 如果是长箭头，不记录 diff（或记录为0，后续在 HitGraph 中过滤）
			var diffToRecord = diff;
			if (isSus)
			{
				diffToRecord = 0; // 或者 -9999，表示长箭头
				var judge = "";
				rep.judgementRecording.push(judge);
				rep.noteRecording.push([note.strumTime, note.sustainLength, note.noteData, diffToRecord]);
			}
			
			if (!isSus)
			{
				var absDiff = Math.abs(diff);
				var judge = "marvelous";
				var marvelousWindow:Float = ClientPrefs.data.marvelousWindow;
				var sickWindow:Float = ClientPrefs.data.sickWindow;
				var goodWindow:Float = ClientPrefs.data.goodWindow;
				var badWindow:Float = ClientPrefs.data.badWindow;
				if (absDiff <= marvelousWindow) judge = "marvelous";
				else if (absDiff <= sickWindow) judge = "sick";
				else if (absDiff <= goodWindow) judge = "good";
				else if (absDiff <= badWindow) judge = "bad";
				else judge = "shit";
				
				rep.judgementRecording.push(judge);			
				rep.noteRecording.push([note.strumTime, note.sustainLength, note.noteData, diff]);
			}
		}
	}

	public function invalidateNote(note:Note):Void {
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null)
				spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
		}
	}

	public function spawnNoteSplash(x:Float = 0, y:Float = 0, ?data:Int = 0, ?note:Note, ?strum:StrumNote) {
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.babyArrow = strum;
		splash.spawnSplashNote(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	override function destroy() {
		if (psychlua.CustomSubstate.instance != null)
		{
			closeSubState();
			resetSubState();
		}

		#if LUA_ALLOWED
		for (lua in luaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if(script != null)
			{
				if(script.exists('onDestroy')) script.call('onDestroy');
				script.destroy();
			}

		hscriptArray = null;
		#end
		stagesFunc(function(stage:BaseStage) stage.destroy());

		#if VIDEOS_ALLOWED
		if(videoCutscene != null)
		{
			videoCutscene.destroy();
			videoCutscene = null;
		}
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.camera.filters =[];

		#if FLX_PITCH FlxG.sound.music.pitch = 1; #end
		FlxG.animationTimeScale = 1;

		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		NoteSplash.configs.clear();
		instance = null;

		inReplay = false;
		loadRep = false;

		if (modInfoBox != null)
		{
			modInfoBox.destroy();
			modInfoBox = null;
		}
		super.destroy();
	}

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();

		if(curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		if(lastBeatHit >= curBeat) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		characterBopper(curBeat);

		super.beatHit();
		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}

	public function characterBopper(beat:Int):Void
	{
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
			gf.dance();
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();
	}

	public function playerDance():Void
	{
		var anim:String = boyfriend.getAnimationName();
		if(boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
			boyfriend.dance();
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		super.sectionHit();

		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String)
	{
		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getSharedPath(luaFile);

		if(FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getSharedPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if(script.scriptName == luaToLoad) return false;

			new FunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
		#if MODS_ALLOWED
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if(!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getSharedPath(scriptFile);
		#else
		var scriptToLoad:String = Paths.getSharedPath(scriptFile);
		#end

		if(FileSystem.exists(scriptToLoad))
		{
			if (Iris.instances.exists(scriptToLoad)) return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	public function initHScript(file:String)
	{
		var newScript:HScript = null;
		try
		{
			newScript = new HScript(null, file);
			if (newScript.exists('onCreate')) newScript.call('onCreate');
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
		}
		catch(e:IrisError)
		{
			var pos:HScriptInfos = cast {fileName: file, showLine: false};
			Iris.error(Printer.errorToString(e, false), pos);
			var newScript:HScript = cast (Iris.instances.get(file), HScript);
			if(newScript != null)
				newScript.destroy();
		}
	}
	#end

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if(result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var arr:Array<FunkinLua> = [];
		for (script in luaArray)
		{
			if(script.closed)
			{
				arr.push(script);
				continue;
			}

			if(exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(funcToCall, args);
			if((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if(myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if(script.closed) arr.push(script);
		}

		if(arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = new Array();
		if(excludeValues == null) excludeValues = new Array();
		excludeValues.push(LuaUtils.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1)
			return returnVal;

		for(script in hscriptArray)
		{
			@:privateAccess
			if(script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var callValue = script.call(funcToCall, args);
			if(callValue != null)
			{
				var myValue:Dynamic = callValue.returnValue;

				if((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if(myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if(exclusions == null) exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in hscriptArray) {
			if(exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = opponentStrums.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating(badHit:Bool = false, scoreBop:Bool = true) {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if(ret != LuaUtils.Function_Stop)
		{
			ratingName = '?';
			if(totalPlayed != 0) //Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				if(ratingPercent < 1)
					for (i in 0...ratingStuff.length-1)
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		setOnScripts('totalPlayed', totalPlayed);
		setOnScripts('totalNotesHit', totalNotesHit);
		updateScore(badHit, scoreBop); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if(chartingMode) return;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice') || ClientPrefs.getGameplaySetting('botplay'));
		if(cpuControlled) return;

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !practiceMode);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

					#if BASE_GAME_FILES
					case 'debugger':
						unlock = (songName == 'test' && !usedPractice);
					#end
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == 'HARD'
					&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end
	public function createRuntimeShader(shaderName:String):ErrorHandledRuntimeShader
	{
		#if (!flash && sys)
		if(!ClientPrefs.data.shaders) return new ErrorHandledRuntimeShader(shaderName);

		if(!runtimeShaders.exists(shaderName) && !initLuaShader(shaderName))
		{
			FlxG.log.warn('Shader $shaderName is missing!');
			return new ErrorHandledRuntimeShader(shaderName);
		}

		var arr:Array<String> = runtimeShaders.get(shaderName);
		return new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if(runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders/'))
		{
			var frag:String = folder + name + '.frag';
			var vert:String = folder + name + '.vert';
			var found:Bool = false;
			if(FileSystem.exists(frag))
			{
				frag = File.getContent(frag);
				found = true;
			}
			else frag = null;

			if(FileSystem.exists(vert))
			{
				vert = File.getContent(vert);
				found = true;
			}
			else vert = null;

			if(found)
			{
				runtimeShaders.set(name, [frag, vert]);
				//trace('Found shader $name!');
				return true;
			}
		}
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			addTextToDebug('Missing shader $name .frag AND .vert files!', FlxColor.RED);
			#else
			FlxG.log.warn('Missing shader $name .frag AND .vert files!');
			#end
		#else
		FlxG.log.warn('This platform doesn\'t support Runtime Shaders!');
		#end
		return false;
	}

	function createModInfoBox():Void
{
    if (SONG == null) return;
    
    // 获取对手颜色
    var opponentColor:FlxColor;
    
    if (dad != null && dad.healthColorArray != null && dad.healthColorArray.length >= 3)
    {
        // 使用 dad 的血条颜色
        opponentColor = FlxColor.fromRGB(
            dad.healthColorArray[0],
            dad.healthColorArray[1],
            dad.healthColorArray[2]
        );
        trace('Using dad color: R=${dad.healthColorArray[0]}, G=${dad.healthColorArray[1]}, B=${dad.healthColorArray[2]}');
    }
    else
    {
        // 默认颜色
        opponentColor = FlxColor.fromString('#7E1C4A');
        trace('Using default color for info box');
    }
    
    // 创建 ModInfoBox
    modInfoBox = new ModInfoBox(SONG.song, opponentColor);
    
    // 只有需要显示时才添加到舞台
    if (modInfoBox.shouldDisplay)
    {
        modInfoBox.cameras = [camOther];
        add(modInfoBox);
        trace('ModInfoBox created for song: ${SONG.song}');
    }
    else
    {
        modInfoBox = null; // 如果不显示，设为 null
        trace('No ModInfoBox for song: ${SONG.song}');
    }
}

private function initReplayData():Void
{
    if (rep == null || rep.replay == null || rep.replay.songNotes == null)
    {
        trace('ERROR: Replay data is null or invalid!');
        inReplay = false;
        return;
    }
    
    // 清空队列
    replayNoteQueue = [];
    repNoteIndex = 0;
    lastReplayTime = 0;
    
    // 解析回放音符数据
    for (i in 0...rep.replay.songNotes.length)
    {
        var noteData:Array<Dynamic> = rep.replay.songNotes[i];
        if (noteData == null || noteData.length < 4) continue;
        
        // 数组格式: [strumTime, sustainLength, column, diff, isMiss, processed]
        var replayNote:Array<Dynamic> = [
            noteData[0],                     // 0: strumTime (音符出现时间)
            noteData[1],                     // 1: sustainLength (长条长度)
            Std.int(noteData[2] % 4),        // 2: column (按键列)
            noteData[3],                     // 3: diff (击打时间差)
            (noteData[3] >= 9999),           // 4: isMiss (是否失误)
            false                            // 5: processed (是否已处理)
        ];
        
        replayNoteQueue.push(replayNote);
        
        //trace('Replay Note ${i}: time=${replayNote[0]}, col=${replayNote[2]}, ' +
             // 'sus=${replayNote[1]}, diff=${replayNote[3]}, ' +
             // 'miss=${replayNote[4]}');
    }
    
    // 按时间排序
    replayNoteQueue.sort(function(a:Array<Dynamic>, b:Array<Dynamic>):Int
    {
        return Std.int(a[0] - b[0]); // 按strumTime排序
    });
    
    //trace('Loaded ${replayNoteQueue.length} replay notes');
}

/**
 * 创建回放UI界面
 */
private function createReplayUI():Void
{
    if (!inReplay) return;
    
    //trace('Creating replay UI...');
    
    try {
        // 创建回放文字显示
        replayTxt = new FlxText(0, 0, FlxG.width, "REPLAY MODE", 32);
        replayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.YELLOW, CENTER, 
                         OUTLINE, FlxColor.BLACK);
        replayTxt.scrollFactor.set();
        replayTxt.borderSize = 2;
        replayTxt.alpha = 0.8;
        
        // 添加文字到组
        uiGroup.add(replayTxt);
        replayTxt.visible = true;
        
        // 根据滚动方向调整位置
        if (ClientPrefs.data.downScroll) {
            replayTxt.y = healthBar != null ? healthBar.y - 100 : FlxG.height - 150;
        } else {
            replayTxt.y = healthBar != null ? healthBar.y + 100 : 50;
        }
        
        //trace('Replay UI created successfully at y=${replayTxt.y}');
    } catch (e:Dynamic) {
        trace('ERROR creating replay UI: $e');
        trace('Stack: ${e.stack}');
    }
}

/**
 * 主回放处理函数 - 每帧调用
 */
private function processReplayNotes(elapsed:Float):Void
{
    if (!inReplay || !generatedMusic) {
        return;
    }
    
    if (replayNoteQueue.length == 0 || repNoteIndex >= replayNoteQueue.length) {
        return;
    }
    
    var currentTime:Float = Conductor.songPosition;
    var realCurrentTime:Float = currentTime + Conductor.offset; // 考虑offset
    
    // 每50个音符更新一次UI，避免过于频繁
    updateReplayUI(currentTime);
    
    // 调试信息：每2秒打印一次状态
    #if debug
    if (Math.floor(currentTime / 2000) > Math.floor(lastReplayTime / 2000)) {
        trace('Replay status at ${currentTime}ms: ${repNoteIndex}/${replayNoteQueue.length} notes processed');
    }
    #end
    
    lastReplayTime = currentTime;
    
    // 处理所有到期的回放音符
    var processedCount:Int = 0;
    while (repNoteIndex < replayNoteQueue.length && processedCount < 100) // 每帧最多处理10个音符
    {
        var replayNote:Array<Dynamic> = replayNoteQueue[repNoteIndex];
        
        if (replayNote == null || replayNote.length < 6) {
            repNoteIndex++;
            continue;
        }
        
        // 关键：使用实际应该击打的时间（原始strumTime + diff）
        var noteStrTime:Float = replayNote[0]; // 音符的原始出现时间
        var diff:Float = replayNote[3];        // 实际击打时间与音符时间的差值
        var actualHitTime:Float = noteStrTime + diff; // 实际应该在什么时候击打
        var isMiss:Bool = replayNote[4];
        var processed:Bool = replayNote[5];
        
        // 如果已经处理过，跳过
        if (processed) {
            repNoteIndex++;
            continue;
        }
        
        // 关键修改：应该基于实际击打时间来触发
        // 如果击打时间还没到，等待
        if (actualHitTime > realCurrentTime) { // 提前10ms准备
            break;
        }
        
        // 如果击打时间过期太多，跳过
        if (realCurrentTime - actualHitTime > Conductor.safeZoneOffset) {
            trace('Skipping too late note: noteTime=${noteStrTime}, hitTime=${actualHitTime}, current=${realCurrentTime}');
            replayNoteQueue[repNoteIndex][5] = true;
            repNoteIndex++;
            continue;
        }
        
        // 处理音符
        try {
            if (!isMiss) {
                processReplayHit(replayNote, realCurrentTime);
            } else {
                processReplayMiss(replayNote, realCurrentTime);
            }
            
            // 标记为已处理
            replayNoteQueue[repNoteIndex][5] = true;
            processedCount++;
            
        } catch (e:Dynamic) {
            trace('ERROR processing replay note at ${noteStrTime}: $e');
            trace('Stack: ${e.stack}');
        }
        
        repNoteIndex++;
    }
    
    // 如果没有更多音符，结束回放
    if (repNoteIndex >= replayNoteQueue.length && inReplay)
    {
        trace('Replay finished! All notes processed.');
        completeReplay();
    }
}

/**
 * 处理回放打击 (hit)
 */
private function processReplayHit(replayNote:Array<Dynamic>, currentTime:Float):Void
{
    var noteStrTime:Float = replayNote[0];
    var column:Int = replayNote[2];
    var diff:Float = replayNote[3];
    var actualHitTime:Float = noteStrTime + diff;
    
   // trace('Processing replay HIT: noteTime=$noteStrTime, col=$column, diff=$diff, actualHit=$actualHitTime, current=$currentTime');
    
    // 1. 播放按键动画
    var strum:StrumNote = playerStrums.members[column];
    if (strum != null)
    {
        strum.playAnim('confirm', true);
        strum.resetAnim = 0;
        
        // 0.15秒后恢复静态
        new FlxTimer().start(0.15, function(tmr:FlxTimer)
        {
            if (strum != null && strum.animation.curAnim.name == 'confirm')
            {
                strum.playAnim('static');
                strum.resetAnim = 0;
            }
        });
    }
    
    // 2. 查找并击中对应的游戏音符
    // 关键修改：基于音符的原始出现时间来查找
    var targetNote:Note = findNoteAtOriginalTime(noteStrTime, column);
    if (targetNote != null)
    {
        //trace('Found target note at ${targetNote.strumTime}, hitting...');
        
        // 这里需要确保在正确的时间调用goodNoteHit
        // 如果时间差太大，可能需要调整
        var timeDiff:Float = currentTime - targetNote.strumTime;
        
        // 如果时间差在安全区内，正常击中
        if (Math.abs(timeDiff) < Conductor.safeZoneOffset)
        {
            goodNoteHit(targetNote);
        }
        else
        {
            trace('WARNING: Time diff too large: $timeDiff, forcing hit');
            // 强制击中，但可能会影响评分
            goodNoteHit(targetNote);
            // 也可以手动设置状态
            targetNote.wasGoodHit = true;
            targetNote.canBeHit = false;
        }
        
        // 如果需要，处理长条音符
        var sustainLength:Float = replayNote[1];
        if (sustainLength > 0)
        {
            processSustainNotes(targetNote, replayNote);
        }
    }
    else
    {
       // trace('WARNING: No target note found for replay hit at $noteStrTime');
        
        // 如果没有找到对应音符，至少播放动画
        var animName:String = singAnimations[column];
        if (boyfriend != null && boyfriend.hasAnimation(animName))
        {
            boyfriend.playAnim(animName, true);
            boyfriend.holdTimer = 0;
        }
    }
}

/**
 * 处理回放失误 (miss)
 */
private function processReplayMiss(replayNote:Array<Dynamic>, currentTime:Float):Void
{
    var noteStrTime:Float = replayNote[0];
    var column:Int = replayNote[2];
    
    trace('Processing replay MISS: time=${noteStrTime}, col=${column}');
    
    // 播放miss效果
    noteMissPress(column);
    
    // 播放miss动画
    var animName:String = singAnimations[column] + 'miss';
    if (boyfriend != null && boyfriend.hasAnimation(animName))
    {
        boyfriend.playAnim(animName, true);
    }
}

/**
 * 基于音符的原始出现时间查找音符（关键修复）
 */
private function findNoteAtOriginalTime(targetTime:Float, column:Int):Note
{
    var bestNote:Note = null;
    var minTimeDiff:Float = 10; // 允许10ms的误差
    
    notes.forEachAlive(function(daNote:Note)
    {
        // 检查音符是否符合条件
        if (!daNote.mustPress || 
            daNote.wasGoodHit || 
            daNote.tooLate || 
            !daNote.canBeHit || 
            daNote.noteData != column)
            return;
        
        // 计算原始时间的差值
        var timeDiff:Float = Math.abs(daNote.strumTime - targetTime);
        
        // 找到时间最接近的音符
        if (timeDiff < minTimeDiff)
        {
            minTimeDiff = timeDiff;
            bestNote = daNote;
        }
    });
    
    // 如果没找到精确匹配，放宽条件
    if (bestNote == null)
    {
        var fallbackDiff:Float = 45; // 放宽到45ms
        
        notes.forEachAlive(function(daNote:Note)
        {
            if (!daNote.mustPress || 
                daNote.wasGoodHit || 
                daNote.tooLate || 
                daNote.noteData != column)
                return;
            
            var timeDiff:Float = Math.abs(daNote.strumTime - targetTime);
            if (timeDiff < fallbackDiff)
            {
                fallbackDiff = timeDiff;
                bestNote = daNote;
            }
        });
    }
    
    if (bestNote != null) {
        //trace('Found note: expected=${targetTime}, actual=${bestNote.strumTime}, diff=${bestNote.strumTime - targetTime}');
    }
    
    return bestNote;
}

/**
 * 备选方案：根据实际击打时间查找音符
 */
private function findNoteAtActualHitTime(hitTime:Float, column:Int):Note
{
    var bestNote:Note = null;
    var minTimeDiff:Float = Conductor.safeZoneOffset * 0.5; // 50%的安全区
    
    notes.forEachAlive(function(daNote:Note)
    {
        if (!daNote.mustPress || 
            daNote.wasGoodHit || 
            daNote.tooLate || 
            !daNote.canBeHit || 
            daNote.noteData != column)
            return;
        
        // 计算音符可被击打的时间窗口
        var noteHitWindowStart:Float = daNote.strumTime - Conductor.safeZoneOffset + ClientPrefs.data.ratingOffset;
        var noteHitWindowEnd:Float = daNote.strumTime + Conductor.safeZoneOffset + ClientPrefs.data.ratingOffset;
        
        // 如果击打时间在音符的可击打窗口内
        if (hitTime >= noteHitWindowStart && hitTime <= noteHitWindowEnd)
        {
            // 选择时间最接近的音符
            var timeDiff:Float = Math.abs(daNote.strumTime - hitTime);
            if (timeDiff < minTimeDiff)
            {
                minTimeDiff = timeDiff;
                bestNote = daNote;
            }
        }
    });
    
    return bestNote;
}

/**
 * 处理长条音符
 */
private function processSustainNotes(parentNote:Note, replayNote:Array<Dynamic>):Void
{
    if (parentNote == null || replayNote[1] <= 0)
        return;
    
    // 处理长条音符
    var sustainTime:Float = replayNote[1];
    
    if (sustainTime > 0)
    {
        // 这里可以添加长条音符的持续按键效果
        //trace('Note has sustain: ${sustainTime}ms');
    }
}

/**
 * 更新回放UI显示
 */
private function updateReplayUI(currentTime:Float):Void
{
    if (replayTxt == null) {
        // 尝试重新创建UI
        if (inReplay) {
            createReplayUI();
        }
        return;
    }
    
    try {
        var totalNotes:Int = replayNoteQueue.length;
        var progress:Float = totalNotes > 0 ? (repNoteIndex / totalNotes) * 100 : 100;
        
        // 添加时间信息
        var timeStr:String = FlxStringUtil.formatTime(Math.floor(currentTime / 1000), false);
        
        replayTxt.text = 'REPLAY MODE\n${Math.round(progress)}% (${repNoteIndex}/${totalNotes})\n${timeStr}';
        replayTxt.screenCenter(X);
        replayTxt.visible = true;
    } catch (e:Dynamic) {
        trace('ERROR updating replay UI: $e');
    }
}

/**
 * 完成回放
 */
private function completeReplay():Void
{
    trace('Completing replay...');
    
    if (replayTxt != null)
    {
        replayTxt.text = 'REPLAY COMPLETE!';
        replayTxt.color = FlxColor.GREEN;
        
        // 3秒后隐藏
        new FlxTimer().start(3, function(tmr:FlxTimer)
        {
            if (replayTxt != null) {
                replayTxt.visible = false;
            }
        });
    }
    
    // 可以选择自动退出回放模式
    inReplay = false;
}
}
