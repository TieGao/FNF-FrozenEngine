package backend;

import objects.HitErrorBar;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import states.TitleState;

// Add a variable here and it will get automatically saved
@:structInit class SaveVariables {
	// Mobile and Mobile Controls Releated [Psych Engine Mobile 1.0.4 OG]
	public var extraButtons:String = "NONE"; // mobile extra button option
	public var hitboxPos:Bool = true; // hitbox extra button position option
	public var dynamicColors:Bool = true; // yes cause its cool -Karim
	public var controlsAlpha:Float = FlxG.onMobile ? 0.6 : 0;
	public var screensaver:Bool = false;
	public var wideScreen:Bool = false;
	public var hitboxType:String = "Gradient";
	public var popUpRating:Bool = true;
	public var vsync:Bool = false;
	public var gameOverVibration:Bool = false;
	public var fpsRework:Bool = false;
	//PE 1.0.4 OG
	public var downScroll:Bool = false;
	public var middleScroll:Bool = false;
	public var opponentStrums:Bool = true;
	public var showFPS:Bool = true;
	public var flashing:Bool = true;
	public var autoPause:Bool = true;
	public var antialiasing:Bool = true;
	public var noteSkin:String = 'Default';
	public var splashSkin:String = 'Psych';
	public var holdCoverSkin:String = 'Default';//FE
	public var customUI:String = 'Default';
	public var forceNumberColor:Bool = false;
	public var noteAlpha:Float = 0.9;
	public var splashAlpha:Float = 0.8;//FE
	public var holdcoverAlpha:Float = 0.8;//FE
	public var lowQuality:Bool = false;
	public var shaders:Bool = true;
	public var cacheOnGPU:Bool = #if !switch false #else true #end; // GPU Caching made by Raltyro
	public var framerate:Int = 60;
	public var updaterate:Int = 60;
	public var unlimitedFPS:Bool = false;
	public var devideDrawAndUpdate:Bool = false;
	public var camZooms:Bool = true;
	public var hideHud:Bool = false;
	public var showMS:Bool = true;
	public var oldFreeplay:Bool = false;
	public var skipDeath:Bool = false;
	public var noteOffset:Int = 0;
	// 在 ClientPrefs.hx 的 SaveVariables 中
	public var arrowRGB:Array<Array<FlxColor>> = [
		[0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56], // 0 - 左
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF1542B7], // 1 - 下
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447], // 2 - 上
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038], // 3 - 右
		// 多K额外颜色 (4-15)
		[0xFFFF8C00, 0xFFFFFFFF, 0xFF4A2800], // 4 - 橙色
		[0xFFFF00FF, 0xFFFFFFFF, 0xFF4A004A], // 5 - 品红
		[0xFFFFD700, 0xFFFFFFFF, 0xFF4A3F00], // 6 - 金色
		[0xFF00FF7F, 0xFFFFFFFF, 0xFF004A25], // 7 - 春绿
		[0xFF8B00FF, 0xFFFFFFFF, 0xFF29004A], // 8 - 紫色
		[0xFFFF4500, 0xFFFFFFFF, 0xFF4A1400], // 9 - 橙红
		[0xFF00CED1, 0xFFFFFFFF, 0xFF003E3F], // 10 - 深天蓝
		[0xFFFF1493, 0xFFFFFFFF, 0xFF4A062C], // 11 - 深粉
		[0xFFFFFF00, 0xFFFFFFFF, 0xFF4A4A00], // 12 - 黄色
		[0xFF7FFF00, 0xFFFFFFFF, 0xFF264A00], // 13 - 亮绿
		[0xFF1E90FF, 0xFFFFFFFF, 0xFF092B4A], // 14 - 道奇蓝
		[0xFFFF6EB4, 0xFFFFFFFF, 0xFF4A2136]  // 15 - 热粉
	];
	public var arrowRGBPixel:Array<Array<FlxColor>> = [
		// 4K 基础颜色 (像素风格 - 更鲜艳/亮眼)
		[0xFFE276FF, 0xFFFFF9FF, 0xFF60008D], // 0 - 左 (紫色)
		[0xFF3DCAFF, 0xFFF4FFFF, 0xFF003060], // 1 - 下 (蓝色)
		[0xFF71E300, 0xFFF6FFE6, 0xFF003100], // 2 - 上 (绿色)
		[0xFFFF884E, 0xFFFFFAF5, 0xFF6C0000], // 3 - 右 (红色)
		[0xFFFFA500, 0xFFFFF5E6, 0xFF4A2F00], // 4 - 橙色
		[0xFFFF6B9D, 0xFFFFF0F5, 0xFF4A001F], // 5 - 粉色
		[0xFF00E5FF, 0xFFF0FFFF, 0xFF00454A], // 6 - 青色
		[0xFFB8FF00, 0xFFF5FFE6, 0xFF354A00], // 7 - 黄绿
		[0xFFFF00D4, 0xFFFFF0FC, 0xFF4A003D], // 8 - 洋红
		[0xFF4DD0FF, 0xFFF0FAFF, 0xFF00334A], // 9 - 天蓝
		[0xFFFFD740, 0xFFFFFCF0, 0xFF4A3C00], // 10 - 金色
		[0xFF69F0AE, 0xFFF0FFF5, 0xFF004A25], // 11 - 薄荷
		[0xFFD9A0FF, 0xFFFCF0FF, 0xFF3D004A], // 12 - 薰衣草
		[0xFFFF8A80, 0xFFFFF5F5, 0xFF4A1A00], // 13 - 珊瑚
		[0xFF80D8A0, 0xFFF0FFF5, 0xFF004A2F], // 14 - 翡翠
		[0xFFFF80B0, 0xFFFFF0F5, 0xFF4A0020], // 15 - 玫瑰
	];

	public var ghostTapping:Bool = true;
	public var timeBarType:String = 'Time Left';
	public var scoreZoom:Bool = true;
	public var Counter:Bool = true;
	public var noReset:Bool = false;
	public var healthBarAlpha:Float = 1;
	public var hitsoundVolume:Float = 0;
	public var hitsound:String = 'hitsound';
	public var pauseMusic:String = 'Tea Time';
	public var checkForUpdates:Bool = true;
	public var comboStacking:Bool = true;

	//FE Options
	public var centerPause:Bool = false;
	public var coolBackdrop:Bool = true;
	public var customColor:Bool = true;
	public var healthText:Bool = true;
	public var songText:Bool = true;
	public var ImpStory:Bool = false;
	public var freeplayspace:Bool = false;
	public var saveFreeplayCache:Bool = true;
	public var globalspace:Bool = false;
	public var cardGlow:Bool = true; // 新增：在 Freeplay 卡片下显示呼吸发光
	public var freeplayModFolder:Bool = true; // 使用模组文件夹管理器隔离歌曲
	public var scoreScreen:Bool = true;
	public var keOptions:Bool = true;
	public var gradientTimeBar:Bool = true;
	public var guideLineAlpha:Float = 0.0;
	public var modInfoBox:Bool = true;
	public var toolBar:Bool = false;
	public var freeplaySearch:Bool = true;
	public var charmPause:Bool = false;
	public var legacyMouseWheelScroll:Bool = false; //是否启用旧版鼠标滚轮行为（滚轮滚动数值选项时改变数值，滚轮滚动选项列表时滚动列表）
	public var forceSplashSkin:Bool = false;
	public var forceNoteSkin:Bool = false;
	public var forceRGBShader:Bool = false;
	public var customChartFolder:String = 'custom';
	public var customChartModFolder:String = '';
	public var customChartStage:String = 'audiostage';
	public var customChartPlayer:String = 'bf';
	public var customChartOpponent:String = 'dad';
	public var customChartGirlfriend:String = 'gf';
	public var customChart8KTo4K:Bool = false;
	public var customChartSwapSides:Bool = false;

	public var msInErrorBar:Bool = false; // 是否在误差条上显示ms文本
	public var pointerType:String = "triangle"; // 误差条指针样式
	
	public var totalPlaytime:Float = 0;        // 累计总时长（秒）
	public var sessionStartTime:Float = 0;     // 本次会话开始时间（毫秒时间戳）

	// 新增统计变量
	public var totalScore:Int = 0;             // 累计总分
	public var totalPlays:Int = 0;             // 总游玩次数
	public var totalSongsCleared:Int = 0;      // 通关歌曲总数（不包括失败）
	public var totalMarvelous:Int = 0;         // 累计 Marvelous 数
	public var totalSicks:Int = 0;             // 累计 Sick 数
	public var totalGoods:Int = 0;             // 累计 Good 数
	public var totalBads:Int = 0;              // 累计 Bad 数
	public var totalShits:Int = 0;             // 累计 Shit 数
	public var totalMisses:Int = 0;            // 累计 Miss 数
	public var highestScore:Int = 0;           // 历史最高分（单首歌曲）
	public var highestCombo:Int = 0;           // 历史最高连击
	public var bestAccuracy:Float = 0;         // 历史最高准确率
	public var perfectClears:Int = 0;          // 完美通关次数（FC/无Miss）
	public var fullComboCount:Int = 0;         // Full Combo 次数
	public var songsByDifficulty:Array<Int> = [0, 0, 0]; // 各难度通关次数 [Easy, Normal, Hard]

	public var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative', 
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		// -kade
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'botplay' => false,
		'opponentplay' => 'player'
	];

	public var comboOffset:Array<Int> = [0, 0, 0, 0];
	public var ratingOffset:Int = 0;
	public var marvelousWindow:Float = 22.5;
	public var sickWindow:Float = 45.0;
	public var goodWindow:Float = 90.0;
	public var badWindow:Float = 135.0;
	public var safeFrames:Float = 10.0;

	public var guitarHeroSustains:Bool = true;
	public var discordRPC:Bool = true;
	public var loadingScreen:Bool = true;
	public var language:String = 'en-US';

	//FE Advanced Options
	public var saveReplays:Bool = true;
	public var luadebugPrint:Bool = true;

	public var beamparticle:Bool = false;
	public var particleAmount:Int = 1;
	public var particleSpeed:Float = 1.5;
	public var particleTrail:Int = 36;

	public var hitErrorBarVisible:Bool = false;
	public var hitBarLines:Int = 5;
	public var hitBarLineTime:Float = 2.0;
	public var kb:Bool = false;
	public var kbalpha:Float = 1.0;
	public var kbsize:Float = 1.0;
	public var kbOffsetX:Float = 0.0;
	public var kbOffsetY:Float = 0.0;
	public var keyboardAlpha:Float = 1.0;
	public var keyboardBGColor:FlxColor = FlxColor.BLACK;
	public var keyboardTextColor:FlxColor = FlxColor.WHITE;
	public var keyboardTimeDisplay:Bool = true;
	public var keyboardTime:Float = 500.0;
	public var hitErrorBarOffsetX:Int = 0;
	public var hitErrorBarOffsetY:Int = 0;
	public var noteSustainsOffset:Float = 0.0;
	public var legacymp:Bool = true;
	public var useSystemCursor:Bool = false;
	public var showEarlyLate:Bool = true;
	public var showCombo:Bool = false;
	public var forceNoteSkins:Bool = false;
	public var forceSplashSkins:Bool = false;
	public var forceNoteRGB:Bool = false;
	public var blurEffects:Bool = true;
	public var skipResultExitAnim:Bool = false;

	public var showHC:Bool = true;
	public var showCB:Bool = true;
	public var showMiss:Bool = true;
	public var showTNH:Bool = true;
	public var showEngineVer:Bool = true;
	public var showDifficulty:Bool = true;

	public var relaxAudioNumber:Int = 16;
	public var relaxAudioDisplayQuality:Int = 4;
	public var audioDisplayUpdate:Float = 33.0;
	public var audioGain:Float = 1.5;
	public var transitionType:String = "fade";
	
	public  var renderResolution:Int = 0;
	public var useDpiSettings:Bool = true;
	public var dpiSettingsAsked:Bool = false;
	public var showStage:Bool = true;

	public var showOS:Bool = false; // show os in fps counter
	public var showTPS:Bool = false;
	public var showMEMPeak:Bool = false;
	public var showApi:Bool = false;

	public var luatextantialiasing = true;
	public var keLike:Bool = false;
	public var clipoffset:Float = 0;
	public var betaUpdates:Bool = false;
}

class ClientPrefs {
	public static var data:SaveVariables = {};
	public static var defaultData:SaveVariables = {};

	//Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		'note_up'		=> [W, UP],
		'note_left'		=> [A, LEFT],
		'note_down'		=> [S, DOWN],
		'note_right'	=> [D, RIGHT],

		'note_5k_1'     => [ONE],
		'note_5k_2'     => [TWO],
		'note_5k_3'     => [THREE],
		'note_5k_4'     => [FOUR],
		'note_5k_5'     => [FIVE],
		
		// 6k (使用 1-6 数字键)
		'note_6k_1'     => [ONE],
		'note_6k_2'     => [TWO],
		'note_6k_3'     => [THREE],
		'note_6k_4'     => [FOUR],
		'note_6k_5'     => [FIVE],
		'note_6k_6'     => [SIX],
		
		// 7k (使用 1-7 数字键)
		'note_7k_1'     => [ONE],
		'note_7k_2'     => [TWO],
		'note_7k_3'     => [THREE],
		'note_7k_4'     => [FOUR],
		'note_7k_5'     => [FIVE],
		'note_7k_6'     => [SIX],
		'note_7k_7'     => [SEVEN],
		
		// 8k (使用 1-8 数字键)
		'note_8k_1'     => [ONE],
		'note_8k_2'     => [TWO],
		'note_8k_3'     => [THREE],
		'note_8k_4'     => [FOUR],
		'note_8k_5'     => [FIVE],
		'note_8k_6'     => [SIX],
		'note_8k_7'     => [SEVEN],
		'note_8k_8'     => [EIGHT],
		
		// 9k (使用 1-9 数字键)
		'note_9k_1'     => [ONE],
		'note_9k_2'     => [TWO],
		'note_9k_3'     => [THREE],
		'note_9k_4'     => [FOUR],
		'note_9k_5'     => [FIVE],
		'note_9k_6'     => [SIX],
		'note_9k_7'     => [SEVEN],
		'note_9k_8'     => [EIGHT],
		'note_9k_9'     => [NINE],
		
		// 10k (使用 1-9, 0)
		'note_10k_1'    => [ONE],
		'note_10k_2'    => [TWO],
		'note_10k_3'    => [THREE],
		'note_10k_4'    => [FOUR],
		'note_10k_5'    => [FIVE],
		'note_10k_6'    => [SIX],
		'note_10k_7'    => [SEVEN],
		'note_10k_8'    => [EIGHT],
		'note_10k_9'    => [NINE],
		'note_10k_10'   => [ZERO],
		
		// 11k (使用 QWERTY 第一行)
		'note_11k_1'    => [Q],
		'note_11k_2'    => [W],
		'note_11k_3'    => [E],
		'note_11k_4'    => [R],
		'note_11k_5'    => [T],
		'note_11k_6'    => [Y],
		'note_11k_7'    => [U],
		'note_11k_8'    => [I],
		'note_11k_9'    => [O],
		'note_11k_10'   => [P],
		'note_11k_11'   => [S],
		
		// 12k (使用 QWERTY 第一行 + 数字)
		'note_12k_1'    => [Q],
		'note_12k_2'    => [W],
		'note_12k_3'    => [E],
		'note_12k_4'    => [R],
		'note_12k_5'    => [T],
		'note_12k_6'    => [Y],
		'note_12k_7'    => [U],
		'note_12k_8'    => [I],
		'note_12k_9'    => [O],
		'note_12k_10'   => [P],
		'note_12k_11'   => [S],
		'note_12k_12'   => [A],
		
		// 13k (使用 QWERTY 第一行 + 数字 + 符号)
		'note_13k_1'    => [Q],
		'note_13k_2'    => [W],
		'note_13k_3'    => [E],
		'note_13k_4'    => [R],
		'note_13k_5'    => [T],
		'note_13k_6'    => [Y],
		'note_13k_7'    => [U],
		'note_13k_8'    => [I],
		'note_13k_9'    => [O],
		'note_13k_10'   => [P],
		'note_13k_11'   => [S],
		'note_13k_12'   => [A],
		'note_13k_13'   => [],
		
		// 14k (使用 QWERTY 第一行 + ASDF 行)
		'note_14k_1'    => [Q],
		'note_14k_2'    => [W],
		'note_14k_3'    => [E],
		'note_14k_4'    => [R],
		'note_14k_5'    => [T],
		'note_14k_6'    => [Y],
		'note_14k_7'    => [U],
		'note_14k_8'    => [I],
		'note_14k_9'    => [O],
		'note_14k_10'   => [P],
		'note_14k_11'   => [A],
		'note_14k_12'   => [S],
		'note_14k_13'   => [D],
		'note_14k_14'   => [F],
		
		// 15k (使用 QWERTY 第一行 + ASDF 行 + G)
		'note_15k_1'    => [Q],
		'note_15k_2'    => [W],
		'note_15k_3'    => [E],
		'note_15k_4'    => [R],
		'note_15k_5'    => [T],
		'note_15k_6'    => [Y],
		'note_15k_7'    => [U],
		'note_15k_8'    => [I],
		'note_15k_9'    => [O],
		'note_15k_10'   => [P],
		'note_15k_11'   => [A],
		'note_15k_12'   => [S],
		'note_15k_13'   => [D],
		'note_15k_14'   => [F],
		'note_15k_15'   => [G],
		
		// 16k (使用 QWERTY 第一行 + ASDF 行 + GH)
		'note_16k_1'    => [Q],
		'note_16k_2'    => [W],
		'note_16k_3'    => [E],
		'note_16k_4'    => [R],
		'note_16k_5'    => [T],
		'note_16k_6'    => [Y],
		'note_16k_7'    => [U],
		'note_16k_8'    => [I],
		'note_16k_9'    => [O],
		'note_16k_10'   => [P],
		'note_16k_11'   => [A],
		'note_16k_12'   => [S],
		'note_16k_13'   => [D],
		'note_16k_14'   => [F],
		'note_16k_15'   => [G],
		'note_16k_16'   => [H],
		
		'ui_up'			=> [W, UP],
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R],
		
		'volume_mute'	=> [ZERO],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN],
		'debug_2'		=> [EIGHT],
		
		'fullscreen'	=> [F11]
	];
	public static var gamepadBinds:Map<String, Array<FlxGamepadInputID>> = [
		'note_up'		=> [DPAD_UP, Y],
		'note_left'		=> [DPAD_LEFT, X],
		'note_down'		=> [DPAD_DOWN, A],
		'note_right'	=> [DPAD_RIGHT, B],

		'note_5k_1'     => [DPAD_LEFT],
		'note_5k_2'     => [DPAD_DOWN],
		'note_5k_3'     => [DPAD_RIGHT],
		'note_5k_4'     => [A],
		'note_5k_5'     => [B],
		
		// 6k (使用 D-Pad + ABXY)
		'note_6k_1'     => [DPAD_LEFT],
		'note_6k_2'     => [DPAD_DOWN],
		'note_6k_3'     => [DPAD_RIGHT],
		'note_6k_4'     => [A],
		'note_6k_5'     => [B],
		'note_6k_6'     => [X],
		
		// 7k (使用 D-Pad + ABXY + 肩键)
		'note_7k_1'     => [DPAD_LEFT],
		'note_7k_2'     => [DPAD_DOWN],
		'note_7k_3'     => [DPAD_RIGHT],
		'note_7k_4'     => [A],
		'note_7k_5'     => [B],
		'note_7k_6'     => [X],
		'note_7k_7'     => [Y],
		
		// 8k (使用 D-Pad + ABXY + 肩键)
		'note_8k_1'     => [DPAD_LEFT],
		'note_8k_2'     => [DPAD_DOWN],
		'note_8k_3'     => [DPAD_RIGHT],
		'note_8k_4'     => [A],
		'note_8k_5'     => [B],
		'note_8k_6'     => [X],
		'note_8k_7'     => [Y],
		'note_8k_8'     => [LEFT_SHOULDER],
		
		// 9k (D-Pad + ABXY + 肩键 + 扳机)
		'note_9k_1'     => [DPAD_LEFT],
		'note_9k_2'     => [DPAD_DOWN],
		'note_9k_3'     => [DPAD_RIGHT],
		'note_9k_4'     => [A],
		'note_9k_5'     => [B],
		'note_9k_6'     => [X],
		'note_9k_7'     => [Y],
		'note_9k_8'     => [LEFT_SHOULDER],
		'note_9k_9'     => [RIGHT_SHOULDER],
		
		// 10k (上面 + 扳机)
		'note_10k_1'    => [DPAD_LEFT],
		'note_10k_2'    => [DPAD_DOWN],
		'note_10k_3'    => [DPAD_RIGHT],
		'note_10k_4'    => [A],
		'note_10k_5'    => [B],
		'note_10k_6'    => [X],
		'note_10k_7'    => [Y],
		'note_10k_8'    => [LEFT_SHOULDER],
		'note_10k_9'    => [RIGHT_SHOULDER],
		'note_10k_10'   => [LEFT_TRIGGER],
		
		// 11k (使用摇杆方向 + 所有按键)
		'note_11k_1'    => [DPAD_LEFT],
		'note_11k_2'    => [DPAD_DOWN],
		'note_11k_3'    => [DPAD_RIGHT],
		'note_11k_4'    => [A],
		'note_11k_5'    => [B],
		'note_11k_6'    => [X],
		'note_11k_7'    => [Y],
		'note_11k_8'    => [LEFT_SHOULDER],
		'note_11k_9'    => [RIGHT_SHOULDER],
		'note_11k_10'   => [LEFT_TRIGGER],
		'note_11k_11'   => [RIGHT_TRIGGER],
		
		// 12k (使用左右摇杆方向)
		'note_12k_1'    => [DPAD_LEFT],
		'note_12k_2'    => [DPAD_DOWN],
		'note_12k_3'    => [DPAD_RIGHT],
		'note_12k_4'    => [A],
		'note_12k_5'    => [B],
		'note_12k_6'    => [X],
		'note_12k_7'    => [Y],
		'note_12k_8'    => [LEFT_SHOULDER],
		'note_12k_9'    => [RIGHT_SHOULDER],
		'note_12k_10'   => [LEFT_TRIGGER],
		'note_12k_11'   => [RIGHT_TRIGGER],
		'note_12k_12'   => [LEFT_STICK_DIGITAL_UP],
		
		// 13k (更多摇杆方向)
		'note_13k_1'    => [DPAD_LEFT],
		'note_13k_2'    => [DPAD_DOWN],
		'note_13k_3'    => [DPAD_RIGHT],
		'note_13k_4'    => [A],
		'note_13k_5'    => [B],
		'note_13k_6'    => [X],
		'note_13k_7'    => [Y],
		'note_13k_8'    => [LEFT_SHOULDER],
		'note_13k_9'    => [RIGHT_SHOULDER],
		'note_13k_10'   => [LEFT_TRIGGER],
		'note_13k_11'   => [RIGHT_TRIGGER],
		'note_13k_12'   => [LEFT_STICK_DIGITAL_UP],
		'note_13k_13'   => [LEFT_STICK_DIGITAL_DOWN],
		
		// 14k
		'note_14k_1'    => [DPAD_LEFT],
		'note_14k_2'    => [DPAD_DOWN],
		'note_14k_3'    => [DPAD_RIGHT],
		'note_14k_4'    => [A],
		'note_14k_5'    => [B],
		'note_14k_6'    => [X],
		'note_14k_7'    => [Y],
		'note_14k_8'    => [LEFT_SHOULDER],
		'note_14k_9'    => [RIGHT_SHOULDER],
		'note_14k_10'   => [LEFT_TRIGGER],
		'note_14k_11'   => [RIGHT_TRIGGER],
		'note_14k_12'   => [LEFT_STICK_DIGITAL_UP],
		'note_14k_13'   => [LEFT_STICK_DIGITAL_DOWN],
		'note_14k_14'   => [LEFT_STICK_DIGITAL_LEFT],
		
		// 15k
		'note_15k_1'    => [DPAD_LEFT],
		'note_15k_2'    => [DPAD_DOWN],
		'note_15k_3'    => [DPAD_RIGHT],
		'note_15k_4'    => [A],
		'note_15k_5'    => [B],
		'note_15k_6'    => [X],
		'note_15k_7'    => [Y],
		'note_15k_8'    => [LEFT_SHOULDER],
		'note_15k_9'    => [RIGHT_SHOULDER],
		'note_15k_10'   => [LEFT_TRIGGER],
		'note_15k_11'   => [RIGHT_TRIGGER],
		'note_15k_12'   => [LEFT_STICK_DIGITAL_UP],
		'note_15k_13'   => [LEFT_STICK_DIGITAL_DOWN],
		'note_15k_14'   => [LEFT_STICK_DIGITAL_LEFT],
		'note_15k_15'   => [LEFT_STICK_DIGITAL_RIGHT],
		
		// 16k
		'note_16k_1'    => [DPAD_LEFT],
		'note_16k_2'    => [DPAD_DOWN],
		'note_16k_3'    => [DPAD_RIGHT],
		'note_16k_4'    => [A],
		'note_16k_5'    => [B],
		'note_16k_6'    => [X],
		'note_16k_7'    => [Y],
		'note_16k_8'    => [LEFT_SHOULDER],
		'note_16k_9'    => [RIGHT_SHOULDER],
		'note_16k_10'   => [LEFT_TRIGGER],
		'note_16k_11'   => [RIGHT_TRIGGER],
		'note_16k_12'   => [LEFT_STICK_DIGITAL_UP],
		'note_16k_13'   => [LEFT_STICK_DIGITAL_DOWN],
		'note_16k_14'   => [LEFT_STICK_DIGITAL_LEFT],
		'note_16k_15'   => [LEFT_STICK_DIGITAL_RIGHT],
		'note_16k_16'   => [RIGHT_STICK_DIGITAL_UP],
		
		
		'ui_up'			=> [DPAD_UP, LEFT_STICK_DIGITAL_UP],
		'ui_left'		=> [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
		'ui_down'		=> [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
		'ui_right'		=> [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
		
		'accept'		=> [A, START],
		'back'			=> [B],
		'pause'			=> [START],
		'reset'			=> [BACK]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;
	public static var defaultButtons:Map<String, Array<FlxGamepadInputID>> = null;

	public static function resetKeys(controller:Null<Bool> = null) //Null = both, False = Keyboard, True = Controller
	{
		if(controller != true)
			for (key in keyBinds.keys())
				if(defaultKeys.exists(key))
					keyBinds.set(key, defaultKeys.get(key).copy());

		if(controller != false)
			for (button in gamepadBinds.keys())
				if(defaultButtons.exists(button))
					gamepadBinds.set(button, defaultButtons.get(button).copy());
	}

	public static function clearInvalidKeys(key:String)
	{
		var keyBind:Array<FlxKey> = keyBinds.get(key);
		var gamepadBind:Array<FlxGamepadInputID> = gamepadBinds.get(key);
		while(keyBind != null && keyBind.contains(NONE)) keyBind.remove(NONE);
		while(gamepadBind != null && gamepadBind.contains(NONE)) gamepadBind.remove(NONE);
	}

	public static function loadDefaultKeys()
	{
		defaultKeys = keyBinds.copy();
		defaultButtons = gamepadBinds.copy();
	}

	public static function saveSettings() {
		for (key in Reflect.fields(data))
			Reflect.setField(FlxG.save.data, key, Reflect.field(data, key));

		#if ACHIEVEMENTS_ALLOWED Achievements.save(); #end
		FlxG.save.flush();

		//Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		save.data.keyboard = keyBinds;
		save.data.gamepad = gamepadBinds;
		save.flush();
		FlxG.log.add("Settings saved!");
	}

	public static function loadPrefs() {
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		for (key in Reflect.fields(data))
			if (key != 'gameplaySettings' && Reflect.hasField(FlxG.save.data, key))
				Reflect.setField(data, key, Reflect.field(FlxG.save.data, key));
		
		if(Main.fpsVar != null)
			Main.fpsVar.visible = data.showFPS;

		#if (!html5 && !switch)
		FlxG.autoPause = ClientPrefs.data.autoPause;

		if(FlxG.save.data.framerate == null) {
			final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
			data.framerate = Std.int(FlxMath.bound(refreshRate, 60, 240));
		}
		#end

		// 核心修改：正确区分设置 Update 和 Draw 帧率
		if (data.fpsRework)
		{
			// 使用 fpsRework 模式，可以完全分离 TPS 和 FPS
			FlxG.stage.window.frameRate = data.framerate;  // 绘制帧率（屏幕刷新）
			
			if (data.devideDrawAndUpdate)
			{
				// 完全分离模式：更新速率和绘制速率可以完全不同
				var drawFps = Std.int(FlxMath.bound(data.framerate, 30, 480));
				var updateTps = Std.int(FlxMath.bound(data.updaterate, 30, 480));
				
				FlxG.drawFramerate = drawFps;
				FlxG.updateFramerate = updateTps;
			}
			else
			{
				// 同步模式：更新速率跟随绘制速率（传统行为）
				var fps = Std.int(FlxMath.bound(data.framerate, 30, 480));
				FlxG.drawFramerate = fps;
				FlxG.updateFramerate = fps;
			}
		}
		else
		{
			// 传统模式（不使用 fpsRework）
			if (data.devideDrawAndUpdate)
			{
				var fps = Std.int(FlxMath.bound(data.framerate, 30, 480));
				var tps = Std.int(FlxMath.bound(data.updaterate, 30, 480));
				FlxG.drawFramerate = fps;
				FlxG.updateFramerate = tps;
			}
			else
			{
				var fps = Std.int(FlxMath.bound(data.framerate, 30, 480));
				FlxG.updateFramerate = fps;
				FlxG.drawFramerate = fps;
			}
		}

		if(FlxG.save.data.gameplaySettings != null)
		{
			var savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
			for (name => value in savedMap)
				data.gameplaySettings.set(name, value);
		}
		
		// flixel automatically saves your volume!
		if(FlxG.save.data.volume != null)
			FlxG.sound.volume = FlxG.save.data.volume;
		if (FlxG.save.data.mute != null)
			FlxG.sound.muted = FlxG.save.data.mute;

		#if DISCORD_ALLOWED DiscordClient.check(); #end

		// controls on a separate save file
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		if(save != null)
		{
			if(save.data.keyboard != null)
			{
				var loadedControls:Map<String, Array<FlxKey>> = save.data.keyboard;
				for (control => keys in loadedControls)
					if(keyBinds.exists(control)) keyBinds.set(control, keys);
			}
			if(save.data.gamepad != null)
			{
				var loadedControls:Map<String, Array<FlxGamepadInputID>> = save.data.gamepad;
				for (control => keys in loadedControls)
					if(gamepadBinds.exists(control)) gamepadBinds.set(control, keys);
			}
			reloadVolumeKeys();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic = null, ?customDefaultValue:Bool = false):Dynamic
	{
		if(!customDefaultValue) defaultValue = defaultData.gameplaySettings.get(name);

		var value:Dynamic = data.gameplaySettings.exists(name) ? data.gameplaySettings.get(name) : defaultValue;
		if (name == 'opponentplay')
		{
			if (Std.is(value, Bool))
				return value ? 'opponent' : 'player';
			if (value == null)
				return 'player';
			return value;
		}

		return /*PlayState.isStoryMode ? defaultValue : */ value;
	}

	public static function reloadVolumeKeys()
	{
		TitleState.muteKeys = keyBinds.get('volume_mute').copy();
		TitleState.volumeDownKeys = keyBinds.get('volume_down').copy();
		TitleState.volumeUpKeys = keyBinds.get('volume_up').copy();
		toggleVolumeKeys(true);
	}
	public static function toggleVolumeKeys(?turnOn:Bool = true)
	{
		final emptyArray = [];
		FlxG.sound.muteKeys = turnOn ? TitleState.muteKeys : emptyArray;
		FlxG.sound.volumeDownKeys = turnOn ? TitleState.volumeDownKeys : emptyArray;
		FlxG.sound.volumeUpKeys = turnOn ? TitleState.volumeUpKeys : emptyArray;
	}
}
