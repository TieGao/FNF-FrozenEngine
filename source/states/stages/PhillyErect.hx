package states.stages;

#if BASE_GAME_ERECT
import states.stages.objects.*;
import objects.Character;
import shaders.AdjustColorShader;

/**
 * Week 3（philly）的 erect 变体舞台，参照 Erect Mode 的 `phillyErect.lua`。
 *
 * 天空 / 城市 / 列车 / 街道走 `philly/erect/*`，窗光用官方重绘的 `philly/win`；
 * 列车每拍推进、每 4 拍换一次窗光颜色，与正常 Philly 同逻辑。
 * 角色 / 列车染色用 `AdjustColorShader`（hue -26 / sat -16 / bright -5 / contrast 0）。
 *
 * `Philly Glow` 事件（blammed 的高潮段）照 base `Philly.hx` 搬：黑幕 + 事件窗光 + 渐变 +
 * 粒子 + 角色 / 街道染色 + 闪光与缩放。区别是 erect 的角色挂着 `AdjustColorShader`，
 * 而 shader 的输出会盖掉 `color` 染色，所以事件开启时要把 shader 摘掉、结束时再装回去。
 */
class PhillyErect extends BaseStage
{
	/** 每 4 拍随机换的窗光颜色（比 Philly Glow 的暗一档） */
	static var lightColors = [0xB66F43, 0x329A6D, 0x932C28, 0x2663AC, 0x502D64];
	/** Philly Glow 事件用的高饱和窗光颜色 */
	static var glowColors = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];

	var curLight:Int = 0;

	var lights:BGSprite;
	var street:BGSprite;
	var phillyTrain:PhillyTrain;

	// Philly Glow 事件用的精灵（谱面里有该事件时才创建）
	var blammedLightsBlack:FlxSprite;
	var phillyWindowEvent:BGSprite;
	var phillyGlowGradient:PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlowParticle>;
	var curLightEvent:Int = -1;

	/** 角色身上原有的染色 shader，事件期间摘掉、结束后装回 */
	var charShaders:Map<Character, AdjustColorShader> = new Map();

	override function create()
	{
		// 官方 VSlice phillyTrainErect.json 的属性坐标；窗光用官方重绘的 philly/win（旧 philly/window 铺不满 erect 城市）
		var sky:BGSprite = new BGSprite('philly/erect/sky', -100, 0, 0.1, 0.1);
		add(sky);

		var city:BGSprite = new BGSprite('philly/erect/city', -255, 45, 0.3, 0.3);
		city.setGraphicSize(Std.int(city.width * 0.9));
		city.updateHitbox();
		add(city);

		lights = new BGSprite('philly/win', -184, 155, 0.3, 0.3);
		lights.setGraphicSize(Std.int(lights.width * 0.9));
		lights.updateHitbox();
		lights.alpha = 0;
		add(lights);

		var behindTrain:BGSprite = new BGSprite('philly/erect/behindTrain', -299, 144, 1, 1);
		add(behindTrain);

		phillyTrain = new PhillyTrain(2000, 360);
		add(phillyTrain);

		street = new BGSprite('philly/erect/street', -299, 144, 1, 1);
		add(street);

		// 官方 phillyTrainErect.hxc：玩家为 pico-playable（Pico Mix week3）时先播替身开场过场
		// 死亡重试会重建 stage，用时间戳避免 2 分钟内重播
		if (PlayState.SONG != null && PlayState.SONG.player1 == 'pico-playable' && !PlayState.chartingMode)
		{
			dopCutArmed = (Date.now().getTime() - dopLastPlayedAt > 120000);
			if (dopCutArmed) setStartCallback(dopGangerCutscene);
		}
	}

	override function createPost()
	{
		if (ClientPrefs.data.shaders)
		{
			var colorShader:AdjustColorShader = new AdjustColorShader();
			colorShader.apply(-26, -16, -5, 0);
			applyCharShader(boyfriend, colorShader);
			applyCharShader(dad, colorShader);
			applyCharShader(gf, colorShader);
		}
	}

	function applyCharShader(char:Character, shader:AdjustColorShader):Void
	{
		if (char == null) return;
		char.shader = shader;
		charShaders.set(char, shader);
	}

	// 谱面里有 Philly Glow 事件时才预建这些精灵，事件触发再显隐
	override function eventPushed(event:objects.Note.EventNote)
	{
		if (event.event != 'Philly Glow') return;

		blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		blammedLightsBlack.visible = false;
		insert(members.indexOf(street), blammedLightsBlack);

		phillyWindowEvent = new BGSprite('philly/win', lights.x, lights.y, 0.3, 0.3);
		phillyWindowEvent.setGraphicSize(Std.int(phillyWindowEvent.width * 0.9));
		phillyWindowEvent.updateHitbox();
		phillyWindowEvent.visible = false;
		insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);

		phillyGlowGradient = new PhillyGlowGradient(-400, 225);
		phillyGlowGradient.visible = false;
		insert(members.indexOf(blammedLightsBlack) + 1, phillyGlowGradient);
		if (!ClientPrefs.data.flashing) phillyGlowGradient.intendedAlpha = 0.7;

		Paths.image('philly/particle'); //precache philly glow particle image
		phillyGlowParticles = new FlxTypedGroup<PhillyGlowParticle>();
		phillyGlowParticles.visible = false;
		insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (lights != null) lights.alpha -= (Conductor.crochet / 1000) * elapsed * 1.5;

		if (phillyGlowParticles != null)
		{
			phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle)
			{
				if (particle.alpha <= 0) particle.kill();
			});
		}

		// ---- 替身过场的逐帧部分 ----
		if (dopBloodExtending && dopBloodPool != null)
		{
			// 官方 PicoBloodPool：播完后血泊缓慢扩大
			var f:Float = 0.02 * elapsed;
			dopBloodPool.scale.set(dopBloodPool.scale.x + f, dopBloodPool.scale.y + f);
		}
		if (dopCutActive && dopExplode && dopPlayer != null)
		{
			// 爆炸动画播完接 loop（官方 animation.onFinish.add(startLoop)）
			// 图集里没有 'loop'，只有 'loopPlayer' / 'loopOpponent'
			var sprs = [dopPlayer, dopOpponent];
			for (spr in sprs)
			{
				if (spr == null || spr.anim == null) continue;
				if (spr.anim.finished) spr.anim.play(spr == dopPlayer ? 'loopPlayer' : 'loopOpponent', true);
			}
		}
		if (dopCutActive && !dopCutSkipped && Controls.instance.justPressed('accept'))
		{
			if (!dopCanSkip)
			{
				dopCanSkip = true;
				if (dopSkipText != null)
					FlxTween.tween(dopSkipText, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
			}
			else dopSkip();
		}
	}

	override function beatHit()
	{
		phillyTrain.beatHit(curBeat);

		if (curBeat % 4 == 0)
		{
			curLight = FlxG.random.int(0, lightColors.length - 1, [curLight]);
			if (lights != null)
			{
				lights.color = lightColors[curLight];
				lights.alpha = 1;
			}
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		if (eventName != 'Philly Glow' || phillyGlowGradient == null) return;

		if (flValue1 == null || flValue1 <= 0) flValue1 = 0;
		var lightId:Int = Math.round(flValue1);

		var chars:Array<Character> = [boyfriend, gf, dad];
		switch (lightId)
		{
			case 0: // 关闭
				if (phillyGlowGradient.visible)
				{
					doFlash();
					if (ClientPrefs.data.camZooms)
					{
						FlxG.camera.zoom += 0.5;
						camHUD.zoom += 0.1;
					}

					blammedLightsBlack.visible = false;
					phillyWindowEvent.visible = false;
					phillyGlowGradient.visible = false;
					phillyGlowParticles.visible = false;
					curLightEvent = -1;

					for (who in chars)
					{
						if (who == null) continue;
						who.color = FlxColor.WHITE;
						if (charShaders.exists(who)) who.shader = charShaders.get(who); // 装回染色 shader
					}
					street.color = FlxColor.WHITE;
				}

			case 1: // 开启 / 换色
				curLightEvent = FlxG.random.int(0, glowColors.length - 1, [curLightEvent]);
				var color:FlxColor = glowColors[curLightEvent];

				if (!phillyGlowGradient.visible)
				{
					doFlash();
					if (ClientPrefs.data.camZooms)
					{
						FlxG.camera.zoom += 0.5;
						camHUD.zoom += 0.1;
					}

					blammedLightsBlack.visible = true;
					blammedLightsBlack.alpha = 1;
					phillyWindowEvent.visible = true;
					phillyGlowGradient.visible = true;
					phillyGlowParticles.visible = true;

					for (who in chars)
					{
						if (who == null) continue;
						// shader 会把 color 染色盖掉，事件期间先摘掉
						if (charShaders.exists(who)) who.shader = null;
					}
				}
				else if (ClientPrefs.data.flashing)
				{
					var colorButLower:FlxColor = color;
					colorButLower.alphaFloat = 0.25;
					FlxG.camera.flash(colorButLower, 0.5, null, true);
				}

				var charColor:FlxColor = color;
				if (!ClientPrefs.data.flashing) charColor.saturation *= 0.5;
				else charColor.saturation *= 0.75;

				for (who in chars)
				{
					if (who != null) who.color = charColor;
				}
				phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle)
				{
					particle.color = color;
				});
				phillyGlowGradient.color = color;
				phillyWindowEvent.color = color;

				color.brightness *= 0.5;
				street.color = color;

			case 2: // 重置渐变并生成粒子
				if (!ClientPrefs.data.lowQuality)
				{
					var particlesNum:Int = FlxG.random.int(8, 12);
					var width:Float = (2000 / particlesNum);
					var color:FlxColor = glowColors[curLightEvent];
					for (j in 0...3)
					{
						for (i in 0...particlesNum)
						{
							var particle:PhillyGlowParticle = phillyGlowParticles.recycle(PhillyGlowParticle);
							particle.x = -400 + width * i + FlxG.random.float(-width / 5, width / 5);
							particle.y = phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40);
							particle.color = color;
							particle.start();
							phillyGlowParticles.add(particle);
						}
					}
				}
				phillyGlowGradient.bop();
		}
	}

	function doFlash()
	{
		var color:FlxColor = FlxColor.WHITE;
		if (!ClientPrefs.data.flashing) color.alphaFloat = 0.5;

		FlxG.camera.flash(color, 0.15, null, true);
	}

	// ---------------------------------------------------------------------------
	// 官方 phillyTrainErect.hxc 的替身开场过场（Pico Mix week3：pico / philly-nice / blammed）
	// 触发：玩家为 pico-playable 且非编辑器试玩（官方判 bf.characterId == 'pico-playable'）
	// 50% 谁开枪、8% 爆炸分支；时序 0.3 喘气 → 4s 烟 → 6.3s 射手 → 8.75s 禁跳过(+爆炸 gf 吐血)
	// → 11.2s 血泊 / 11.5s 香烟 → 13s 收尾（爆炸+玩家开枪 = 对手已死，爆炸+对手开枪 = 直接结算）
	// ---------------------------------------------------------------------------
	var dopCutArmed:Bool = false;
	var dopCutActive:Bool = false;
	var dopCutSkipped:Bool = false;
	var dopCanSkip:Bool = false;
	var dopCutGen:Int = 0;
	var dopTimers:Array<FlxTimer> = [];
	var dopPlayer:FlxAnimate;
	var dopOpponent:FlxAnimate;
	var dopBloodPool:FlxAnimate;
	var dopBloodExtending:Bool = false;
	var dopCigarette:BGSprite;
	var dopSkipText:FlxText;
	var dopMusic:FlxSound;
	var dopPlayerShoots:Bool = false;
	var dopExplode:Bool = false;
	var dopWasExplodeKill:Bool = false;
	static var dopLastPlayedAt:Float = 0;

	/** 射手那只（活下来开枪的） */
	var dopShooter:FlxAnimate;
	/** 被打死那只（开场抽着烟、倒地的那只） */
	var dopDead:FlxAnimate;
	var dopShooterCenterX:Float = 0;
	var dopDeadCenterX:Float = 0;

	/**
	 * 替身过场两个 pico 的落点微调（像素，正数 = 往下 / 往右）。
	 * 默认按图集内容自动对齐，一般不用动。
	 */
	public static var dopplegangerOffsetX:Float = -100;
	public static var dopplegangerOffsetY:Float = 100;

	/**
	 * `pico_doppleganger` 图集的几何量（相对精灵注册锚点，像素）。
	 * 锚点在 pico 膝盖附近：内容从锚点往上约 440、脚底在 +91，左右中心在锚点右侧
	 * （玩家那只是镜像图，中心偏 171；对手那只 151）。
	 */
	static inline var DOP_FEET_Y:Float = 91;
	static inline var DOP_PLAYER_CENTER_X:Float = 171;
	static inline var DOP_OPPONENT_CENTER_X:Float = 151;
	/** 两只 pico 站在街上的横向间距 */
	static inline var DOP_GAP_X:Float = 700;
	/** 嘴的位置（相对锚点），香烟从这里飞出去 */
	static inline var DOP_MOUTH_X:Float = 145;
	static inline var DOP_MOUTH_Y:Float = -225;
	/** `cigarette` 图集第 0 帧的内容中心：画布右侧 515 / 翻转后左侧 42，纵向 74 */
	static inline var CIG_FRAME_RIGHT_X:Float = 515;
	static inline var CIG_FRAME_LEFT_X:Float = 42;
	static inline var CIG_FRAME_Y:Float = 74;
	/** `bloodPool` 图集内容中心（相对锚点） */
	static inline var BLOOD_CENTER_X:Float = 1362;
	static inline var BLOOD_CENTER_Y:Float = 626;

	/**
	 * 把图集里的帧标签注册成动画。
	 * `pico_doppleganger` 的 8 段动作（shootPlayer / cigaretteOpponent …）只有帧标签，
	 * flxanimate 不会自动把标签变成 anim，直接 play 会失败并退回播主时间轴 ——
	 * 表现就是两只 pico 播同一套动作、完全没有互动。
	 */
	function registerDopplegangerAnims(spr:FlxAnimate, role:String):Void
	{
		for (base in ['shoot', 'explode', 'loop', 'cigarette'])
		{
			var name:String = base + role;
			if (spr.anim.existsByName(name)) continue;
			spr.anim.addByFrameLabel(name, name, 24, base == 'loop');
		}
	}

	function createDopplegangerAssets():Void
	{
		dopPlayerShoots = FlxG.random.bool(50);
		dopExplode = FlxG.random.bool(8);

		dopBloodPool = new FlxAnimate(0, 0);
		Paths.loadAnimateAtlas(dopBloodPool, 'philly/erect/bloodPool');
		dopBloodPool.visible = false;

		dopPlayer = new FlxAnimate(0, 0);
		Paths.loadAnimateAtlas(dopPlayer, 'philly/erect/pico_doppleganger');
		dopOpponent = new FlxAnimate(0, 0);
		Paths.loadAnimateAtlas(dopOpponent, 'philly/erect/pico_doppleganger');

		registerDopplegangerAnims(dopPlayer, 'Player');
		registerDopplegangerAnims(dopOpponent, 'Opponent');

		// 站位：脚底贴对手的脚底（对手是普通分尸图角色，y + height 就是脚底），玩家那只按间距往右挪。
		// 不能拿 bf.x / bf.y 当基准 —— pico-playable 是分尸图角色，它的 x/y 是图集画布原点，跟实际站位差好几百像素。
		var groundY:Float = dad.y + dad.height;
		var opponentCenterX:Float = dad.x + dad.width / 2;
		var playerCenterX:Float = opponentCenterX + DOP_GAP_X;

		dopPlayer.setPosition(playerCenterX - DOP_PLAYER_CENTER_X + dopplegangerOffsetX,
			groundY - DOP_FEET_Y + dopplegangerOffsetY);
		dopOpponent.setPosition(opponentCenterX - DOP_OPPONENT_CENTER_X + dopplegangerOffsetX,
			groundY - DOP_FEET_Y + dopplegangerOffsetY);

		dopShooter = dopPlayerShoots ? dopPlayer : dopOpponent;
		dopDead = dopPlayerShoots ? dopOpponent : dopPlayer;
		dopShooterCenterX = dopPlayerShoots ? DOP_PLAYER_CENTER_X : DOP_OPPONENT_CENTER_X;
		dopDeadCenterX = dopPlayerShoots ? DOP_OPPONENT_CENTER_X : DOP_PLAYER_CENTER_X;

		// 血泊铺在倒地那只的脚下
		dopBloodPool.setPosition(dopDead.x + dopDeadCenterX - BLOOD_CENTER_X,
			dopDead.y + DOP_FEET_Y - BLOOD_CENTER_Y);

		// 香烟从倒地那只嘴里飞出去：玩家朝左不翻转（往左飞），对手朝右翻转（往右飞）。
		// 必须把动画名传进 BGSprite 构造 —— 不传 animArray 时 BGSprite 走 loadGraphic，
		// 整张 cigarette.png 会被当成一帧画出来（看到的"一整个图集"）。
		dopCigarette = new BGSprite('philly/erect/cigarette', 0, 0, 1, 1, ['cigarette spit'], false);
		dopCigarette.flipX = dopPlayerShoots;
		dopCigarette.setPosition(dopDead.x + DOP_MOUTH_X - (dopPlayerShoots ? CIG_FRAME_LEFT_X : CIG_FRAME_RIGHT_X),
			dopDead.y + DOP_MOUTH_Y - CIG_FRAME_Y);
		dopCigarette.visible = false;

		// 分层：血泊/香烟垫底，射手一侧的替身在上
		addBehindDad(dopBloodPool);
		addBehindDad(dopCigarette);
		if (dopPlayerShoots)
		{
			addBehindDad(dopOpponent);
			addBehindDad(dopPlayer);
		}
		else
		{
			addBehindDad(dopPlayer);
			addBehindDad(dopOpponent);
		}
	}

	/** 镜头焦点：直接按替身精灵的实际位置算（分尸图角色的 getMidpoint 拿到的不是站位）。 */
	function dopCameraFocus(spr:FlxAnimate, centerOffsetX:Float, isOpponent:Bool):Array<Float>
	{
		var cx:Float = spr.x + centerOffsetX;
		var cy:Float = spr.y + DOP_FEET_Y - 337;   // 身体中段再上移 100，同 PlayState.moveCamera
		if (isOpponent)
			return [cx + 150 + game.opponentCameraOffset[0], cy + game.opponentCameraOffset[1]];
		return [cx - 100 + game.boyfriendCameraOffset[0], cy + game.boyfriendCameraOffset[1]];
	}

	function dopGangerCutscene()
	{
		if (!dopCutArmed) { startCountdown(); return; }   // 防重入
		dopCutArmed = false;
		dopLastPlayedAt = Date.now().getTime();
		dopCutActive = true;
		dopCutSkipped = false;
		dopCanSkip = false;

		inCutscene = true;
		canPause = false;
		camHUD.visible = false;

		createDopplegangerAssets();

		if (ClientPrefs.data.shaders && boyfriend != null && boyfriend.shader != null)
		{
			dopPlayer.shader = boyfriend.shader;
			dopOpponent.shader = boyfriend.shader;
			dopBloodPool.shader = boyfriend.shader;
		}

		boyfriend.visible = false;
		dad.visible = false;

		dopMusic = FlxG.sound.play(Paths.music('cutscene/' + (dopExplode ? 'cutscene2' : 'cutscene')), 1, false);
		FlxG.sound.music.pause();   // 官方此时歌还没起，保险静音标题音乐残留

		// 动画 + 音效（官方 PicoDopplegangerSprite.doAnim）
		var gen = dopCutGen;
		dopPlayer.anim.play((dopPlayerShoots ? 'shoot' : (dopExplode ? 'explode' : 'cigarette')) + 'Player', true);
		dopOpponent.anim.play((!dopPlayerShoots ? 'shoot' : (dopExplode ? 'explode' : 'cigarette')) + 'Opponent', true);

		dopTimer(0.3, gen, function() FlxG.sound.play(Paths.sound('cutscene/picoGasp'), 1));
		if (dopPlayerShoots)
		{
			dopTimer(6.29, gen, function() FlxG.sound.play(Paths.sound('cutscene/picoShoot'), 1));
			dopTimer(10.33, gen, function() FlxG.sound.play(Paths.sound('cutscene/picoSpin'), 1));
		}
		else if (dopExplode)
		{
			dopTimer(3.7, gen, function() FlxG.sound.play(Paths.sound('cutscene/picoCigarette2'), 1));
			dopTimer(8.75, gen, function() FlxG.sound.play(Paths.sound('cutscene/picoExplode'), 1));
		}
		else
		{
			dopTimer(3.7, gen, function() FlxG.sound.play(Paths.sound('cutscene/picoCigarette'), 1));
		}

		// 相机：两人中点 → 烟 → 射手 → （8.75s 禁跳过）回烟 → 血泊 → 香烟
		var shooter = dopCameraFocus(dopShooter, dopShooterCenterX, !dopPlayerShoots);
		var cigarettePos = dopCameraFocus(dopDead, dopDeadCenterX, dopPlayerShoots);
		var mid = [(shooter[0] + cigarettePos[0]) / 2, (shooter[1] + cigarettePos[1]) / 2];

		game.isCameraOnForcedPos = true;
		camFollow.setPosition(mid[0], mid[1]);
		// FE 没有 Psych 的 camFollowPos（官方靠它把镜头瞬时搬到位），用 snapToTarget 等效硬切
		FlxG.camera.snapToTarget();

		dopTimer(4, gen, function() game.camFollow.setPosition(cigarettePos[0], cigarettePos[1]));
		dopTimer(6.3, gen, function() game.camFollow.setPosition(shooter[0], shooter[1]));
		dopTimer(8.75, gen, function() {
			dopCutSkipped = true;   // 官方在此关闭跳过
			dopCanSkip = false;
			if (dopSkipText != null)
			{
				FlxTween.tween(dopSkipText, {alpha: 0}, 0.5, {ease: FlxEase.quadIn,
					onComplete: function(_) { if (dopSkipText != null) dopSkipText.visible = false; }});
			}
			game.camFollow.setPosition(cigarettePos[0], cigarettePos[1]);
			// 爆炸时 gf 吐血（FE nene atlas 无 drop70 动画时静默跳过）
			if (dopExplode && gf != null && gf.hasAnimation('drop70')) gf.playAnim('drop70', true);
		});
		dopTimer(11.2, gen, function() {
			if (dopExplode)
			{
				dopBloodPool.visible = true;
				dopBloodPool.anim.play('', true);
				dopBloodExtending = true;
			}
		});
		dopTimer(11.5, gen, function() {
			if (!dopExplode)
			{
				dopCigarette.visible = true;
				dopCigarette.animation.play('cigarette spit', true);
			}
		});
		dopTimer(13, gen, function() dopFinish());

		// 跳过提示
		dopSkipText = new FlxText(FlxG.width - 344, FlxG.height - 102, 320, 'Skip [Enter]', 20);
		dopSkipText.font = 'vcr.ttf';
		dopSkipText.alignment = 'right';
		dopSkipText.borderSize = 2;
		dopSkipText.borderColor = FlxColor.BLACK;
		dopSkipText.scrollFactor.set();
		dopSkipText.alpha = 0;
		insert(members.length, dopSkipText);
	}

	function dopTimer(sec:Float, gen:Int, fn:Void->Void)
	{
		var tmr = new FlxTimer();
		dopTimers.push(tmr);
		tmr.start(sec, function(_) {
			if (gen != dopCutGen) return;
			fn();
		});
	}

	function dopCleanupSprites()
	{
		if (dopPlayer != null) { remove(dopPlayer, true); dopPlayer = null; }
		if (dopOpponent != null) { remove(dopOpponent, true); dopOpponent = null; }
		if (dopBloodPool != null) { remove(dopBloodPool, true); dopBloodPool = null; }
		if (dopCigarette != null) { remove(dopCigarette, true); dopCigarette = null; }
		if (dopSkipText != null) { remove(dopSkipText, true); dopSkipText = null; }
		dopShooter = null;
		dopDead = null;
		dopBloodExtending = false;
	}

	function dopFinish()
	{
		dopCutActive = false;
		dopCutGen++;
		for (t in dopTimers) { try t.cancel(); }
		dopTimers = [];
		if (dopMusic != null) { dopMusic.stop(); dopMusic = null; }
		var wasExplodeKill = dopExplode && !dopPlayerShoots;
		dopWasExplodeKill = wasExplodeKill;
		dopCleanupSprites();

		if (wasExplodeKill)
		{
			// 官方：对手开枪 + 爆炸 = 玩家被爆头，歌直接结束
			if (dad != null) dad.visible = true;
			camHUD.fade(FlxColor.BLACK, 1, false, null, true);
			dopTimer(1, dopCutGen, function() {
				camHUD.fade(FlxColor.BLACK, 0.5, true, null, true);
				game.health = 2;
				dopCutActive = false;
				endSong();
			});
			dopCutActive = true; // 保持屏蔽输入直到结束
		}
		else
		{
			dopCutActive = false;
			if (boyfriend != null) boyfriend.visible = true;
			if (dad != null) dad.visible = true;
			inCutscene = false;
			canPause = true;
			// 对手已死：静掉对手人声（FE 的对手人声是独立音轨 opponentVocals）
			if (dopExplode && dopPlayerShoots && game.opponentVocals != null) game.opponentVocals.volume = 0;
			dopRestoreCamera();
			startCountdown();
		}

		inCutscene = false;
		canPause = true;
		camHUD.visible = true;

	}

	// 过场把镜头锁在舞台中间，收尾要还给常规 section 跟随
	function dopRestoreCamera():Void
	{
		game.isCameraOnForcedPos = false;
		moveCameraSection();
	}

	function dopSkip()
	{
		if (dopCutSkipped || !dopCutActive) return;
		dopCutSkipped = true;
		dopExplode = false;   // 官方：跳过强制走非爆炸收尾
		dopCutGen++;
		for (t in dopTimers) { try t.cancel(); }
		dopTimers = [];
		if (dopMusic != null) dopMusic.fadeOut(0.5, 0);
		camHUD.fade(FlxColor.BLACK, 0.5, false, null, true);
		dopTimer(0.5, dopCutGen, function() {
			camHUD.fade(FlxColor.BLACK, 0.5, true, null, true);
			if (dopMusic != null) { dopMusic.stop(); dopMusic = null; }
			dopCleanupSprites();
			if (boyfriend != null) boyfriend.visible = true;
			if (dad != null) dad.visible = true;
			inCutscene = false;
			canPause = true;
			dopRestoreCamera();
			startCountdown();
		});
	}

	override function startSong()
	{
		super.startSong();
		// 爆炸 + 玩家开枪：对手已死，全程静音对手人声
		if (dopWasExplodeKill && game.opponentVocals != null) game.opponentVocals.volume = 0;
	}
}
#end
