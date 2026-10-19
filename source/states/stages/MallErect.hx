package states.stages;

#if BASE_GAME_ERECT
import states.stages.objects.*;
import shaders.AdjustColorShader;


/**
 * Week 5（mall）的 erect 变体舞台，参照原版 `mallXmasErect` 舞台与 Erect Mode 的 `mallErect.lua`。
 *
 * 道具 / 坐标照原版 erect 舞台 json（引擎侧的 erect 图片与原版逐字节相同，所以坐标能直接用）。
 * 唯一的例外是 `bottomBoppers`：原版是 animateatlas，FE 的 flxanimate 没有 `applyStageMatrix`，
 * 摆不出原版位置，改用 Erect Mode 的 sparrow 版本（`bop0` / `hey0`），坐标随之取 Erect Mode 的值。
 *
 * 角色与 santa 挂 `AdjustColorShader`（hue 5 / sat 20），对应原版脚本的 `adjustColor`。
 */
class MallErect extends BaseStage
{
	var upperBoppers:BGSprite;
	var bottomBoppers:MallCrowd;
	var santa:BGSprite;
	var fog:BGSprite;

	/** 雾的整图 alpha。white.png 自身峰值约 0.86，乘完约 0.26，是层薄雾而不是白遮挡。 */
	static inline var FOG_ALPHA:Float = 0.3;
	/** white.png 的 alpha 峰值落在图像高度的这个比例处（按 alpha 剖面量出来的）。 */
	static inline var FOG_PEAK_Y:Float = 0.62;

	override function create()
	{

				// 雪地纯色底：1x1 图靠 scale 铺开，不能调 updateHitbox()，否则 offset/origin 会把整块推飞
		var snowUnder:BGSprite = new BGSprite(null, -1500, 800, 1, 1);
		snowUnder.makeGraphic(1, 1, 0xFFF3F4F5);
		snowUnder.scale.set(5700, 3000);
		snowUnder.antialiasing = false;
		add(snowUnder);
		
		var bgWalls:BGSprite = new BGSprite('christmas/erect/bgWalls', -726, -566, 0.2, 0.2);
		bgWalls.setGraphicSize(Std.int(bgWalls.width * 0.9));
		bgWalls.updateHitbox();
		add(bgWalls);

		if (!ClientPrefs.data.lowQuality)
		{
			upperBoppers = new BGSprite('christmas/erect/upperBop', -374, -98, 0.28, 0.28, ['upperBop']);
			upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85));
			upperBoppers.updateHitbox();
			add(upperBoppers);

			var bgEscalator:BGSprite = new BGSprite('christmas/erect/bgEscalator', -1100, -540, 0.3, 0.3);
			bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
			bgEscalator.updateHitbox();
			add(bgEscalator);
		}

		var christmasTree:BGSprite = new BGSprite('christmas/erect/christmasTree', 370, -250, 0.4, 0.4);
		add(christmasTree);

		// 原版的 fog（christmas/erect/white，zIndex 49）压在 bgWalls / upperBoppers / bgEscalator /
		// christmasTree 之上，按原值直接用就是一块白色遮挡，会把商场内景和圣诞树盖掉。
		// white.png 是横向平顶、纵向渐变的软边白带，所以这里当雾用：alpha 压到 FOG_ALPHA，
		// 位置在 createPost 里对到相机中心（原版坐标 (-1000,100) 会让白斑偏在屏幕下半）。
		fog = new BGSprite('christmas/erect/white', 0, 0, 0.85, 0.85);
		fog.setGraphicSize(Std.int(fog.width * 0.9));
		fog.updateHitbox();
		fog.alpha = FOG_ALPHA;
		fog.antialiasing = false;
		add(fog);

		// 原版这里是 animateatlas，FE 定位不了；用 Erect Mode 的 sparrow 版，坐标也随它
		bottomBoppers = new MallCrowd(-410, 100, 'christmas/erect/bottomBop', 'bop0', 'hey0');
		add(bottomBoppers);

		var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -1350, 680, 1, 1);
		fgSnow.scale.set(1.1, 1);
		fgSnow.updateHitbox();
		add(fgSnow);

		santa = new BGSprite('christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
		add(santa);

		Paths.sound('Lights_Shut_off');
		setDefaultGF('gf-christmas');

		if (isStoryMode && !seenCutscene)
			setEndCallback(eggnogEndCutscene);
		// erect 变体（含 nightmare）：官方 eggnog-erect.hxc 的 Santa Dies 结尾过场（全模式）
		else if (Paths.currentContentVariant == 'erect')
			setEndCallback(santaDiesCutscene);
	}

	// ---------------------------------------------------------------------------
	// 官方 eggnog-erect.hxc 的 Santa Dies 结尾过场
	// santa_speaks_assets（'santa whole scene'）/ parents_shoot_assets（'parents whole scene'）
	// 时序：2.8s 拉近 → 11.375s 枪响 → 12.83s 震屏 → 15s 黑幕 → 16s endSong；0.5s 后可跳过
	// ---------------------------------------------------------------------------
	var santaCutArmed:Bool = false;
	var santaCutActive:Bool = false;
	var santaCutSkipped:Bool = false;
	var santaCanSkip:Bool = false;
	var santaCutGen:Int = 0;
	var santaTimers:Array<FlxTimer> = [];
	var santaDeadSpr:FlxAnimate;
	var parentsShootSpr:FlxAnimate;
	var santaSkipText:FlxText;
	var santaSubText:FlxText;
var santaSound:FlxSound;
	var shootSound:FlxSound;
	var santaCutElapsed:Float = 0;

	// santa-emotions.srt（文本 + 起止秒）
	static var SANTA_SUBS:Array<Dynamic> = [
		{t0: 0.72, t1: 1.80, text: 'Wow...'},
		{t0: 2.14, t1: 4.84, text: "Uh, not even gonna lie to you guys."},
		{t0: 5.54, t1: 7.84, text: "That's the most beautiful thing I..."},
		{t0: 8.08, t1: 10.30, text: 'ever heard in my whole life...'}
	];

	function santaTimer(sec:Float, fn:FlxTimer->Void)
	{
		var gen = santaCutGen;
		var tmr = new FlxTimer();
		santaTimers.push(tmr);
		tmr.start(sec, function(t:FlxTimer) {
			if (gen != santaCutGen) return;
			fn(t);
		});
	}

	function santaCamTo(x:Float, y:Float, dur:Float, ease:flixel.tweens.FlxEase.EaseFunction)
	{
		// 歌已结束，camFollow 不会再被 moveCameraSection 改写，直接 tween 即可
		FlxTween.tween(camFollow, {x: x, y: y}, dur, {ease: ease});
	}

	function santaZoomTo(target:Float, dur:Float, ease:flixel.tweens.FlxEase.EaseFunction)
	{
		PlayState.instance.camZooming = false;
		FlxTween.tween(PlayState.instance, {defaultCamZoom: target}, dur, {ease: ease,
			onUpdate: function(_) PlayState.instance.camGame.zoom = PlayState.instance.defaultCamZoom,
			onComplete: function(_) PlayState.instance.camGame.zoom = PlayState.instance.defaultCamZoom});
	}

	function santaDiesCutscene()
	{
		if (!santaCutArmed) { endSong(); return; }   // 过场收尾后的二次 endSong 直接放行
		santaCutArmed = false;
		santaCutActive = true;
		santaCutSkipped = false;
		santaCutElapsed = 0;
		inCutscene = true;
		canPause = false;

		if (santa != null) santa.visible = false;
		if (dad != null) dad.visible = false;

		// santa 挨枪图集
		santaDeadSpr = new FlxAnimate(-1300, 100);
		Paths.loadAnimateAtlas(santaDeadSpr, 'christmas/santa_speaks_assets');
		santaDeadSpr.antialiasing = ClientPrefs.data.antialiasing;
		if (santa != null && santa.shader != null) santaDeadSpr.shader = santa.shader;
		addBehindDad(santaDeadSpr);
		santaDeadSpr.anim.play('santa whole scene');

		// 爸妈开枪图集（zIndex 更低一档 → 再插到 santaDead 后面）
		parentsShootSpr = new FlxAnimate(-602, -3.5);
		Paths.loadAnimateAtlas(parentsShootSpr, 'christmas/parents_shoot_assets');
		parentsShootSpr.antialiasing = ClientPrefs.data.antialiasing;
		if (santa != null && santa.shader != null) parentsShootSpr.shader = santa.shader;
		addBehindDad(parentsShootSpr);
		parentsShootSpr.anim.play('parents whole scene');

		// 跳过提示 + 字幕（camGame 屏幕空间）
		santaSkipText = new FlxText(FlxG.width - 344, FlxG.height - 102, 320, 'Skip [Enter]', 20);
		santaSkipText.font = 'vcr.ttf';
		santaSkipText.alignment = 'right';
		santaSkipText.borderSize = 2;
		santaSkipText.borderColor = FlxColor.BLACK;
		santaSkipText.scrollFactor.set();
		santaSkipText.alpha = 0;
		insert(members.length, santaSkipText);

		santaSubText = new FlxText(0, FlxG.height - 80, FlxG.width, '', 22);
		santaSubText.alignment = 'center';
		santaSubText.borderSize = 2;
		santaSubText.borderColor = FlxColor.BLACK;
		santaSubText.scrollFactor.set();
		santaSubText.visible = false;
		insert(members.length, santaSubText);

		santaCamTo(santaDeadSpr.x + 1200, santaDeadSpr.y + 300, 2.8, FlxEase.expoOut);
		santaZoomTo(0.73, 2, FlxEase.quadInOut);

		santaSound = FlxG.sound.play(Paths.sound('santa_emotion'), 1, false, null, false);
		shootSound = FlxG.sound.load(Paths.sound('santa_shot_n_falls'), 1, false, null, false, false);

		santaTimer(2.8, function(_) {
			santaCamTo(santaDeadSpr.x + 1050, santaDeadSpr.y + 300, 9, FlxEase.quartInOut);
			santaZoomTo(0.79, 9, FlxEase.quadInOut);
		});
		santaTimer(11.375, function(_) {
			if (!santaCutSkipped) shootSound.play();
		});
		santaTimer(12.83, function(_) {
			PlayState.instance.camGame.shake(0.005, 0.2);
			santaCamTo(santaDeadSpr.x + 1060, santaDeadSpr.y + 380, 5, FlxEase.expoOut);
		});
		santaTimer(15, function(_) {
			camHUD.fade(FlxColor.BLACK, 1, false, null, true);
		});
		santaTimer(16, function(_) {
			if (!santaCutSkipped)
			{
				camHUD.fade(FlxColor.BLACK, 0.5, true, null, true);
				santaFinish();
			}
		});

		// 跳过与字幕在 update() 里逐帧处理（BaseStage 无现成钩子，直接覆写 FlxBasic.update）
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!santaCutActive) return;
		santaCutElapsed += elapsed;

		// 字幕
		if (santaSubText != null)
		{
			var line:Dynamic = null;
			for (s in SANTA_SUBS)
				if (santaCutElapsed >= s.t0 && santaCutElapsed <= s.t1) { line = s; break; }
			if (line == null) santaSubText.visible = false;
			else
			{
				if (santaSubText.text != line.text) santaSubText.text = line.text;
				santaSubText.visible = true;
			}
		}

		// 跳过：首按显示提示，再按跳过（官方是 0.5s 窗口后可跳）
		if (Controls.instance.justPressed('accept'))
		{
			if (!santaCanSkip)
			{
				santaCanSkip = true;
				if (santaSkipText != null)
					FlxTween.tween(santaSkipText, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
			}
			else santaSkip();
		}
	}

	function santaSkip()
	{
		if (santaCutSkipped) return;
		santaCutSkipped = true;
		santaCutActive = false;
		if (santaSound != null) santaSound.stop();
		if (shootSound != null) shootSound.stop();
		if (santaSkipText != null) FlxTween.tween(santaSkipText, {alpha: 0}, 0.5, {ease: FlxEase.quadOut});
		camHUD.fade(FlxColor.BLACK, 0.5, false, null, true);
		santaCutGen++;
		for (t in santaTimers) { try t.cancel(); }
		santaTimers = [];
		new FlxTimer().start(0.5, function(_) santaFinish());
	}

	function santaFinish()
	{
		santaCutActive = false;
		santaCutGen++;
		for (t in santaTimers) { try t.cancel(); }
		santaTimers = [];
		if (santaDeadSpr != null) { remove(santaDeadSpr, true); santaDeadSpr = null; }
		if (parentsShootSpr != null) { remove(parentsShootSpr, true); parentsShootSpr = null; }
		if (santaSkipText != null) { remove(santaSkipText, true); santaSkipText = null; }
		if (santaSubText != null) { remove(santaSubText, true); santaSubText = null; }
		if (santa != null) santa.visible = true;
		if (dad != null) dad.visible = true;
		inCutscene = false;
		canPause = true;
		PlayState.instance.health = 2;   // 防 endSong 重入时 doDeathCheck 误杀
		endSong();
	}

	override function createPost()
	{
		// 白带的 alpha 峰值对到相机中心，否则雾会明显偏在屏幕下半
		if (fog != null)
		{
			fog.x = camFollow.x - fog.width * 0.5 + fog.offset.x;
			fog.y = camFollow.y - fog.height * FOG_PEAK_Y + fog.offset.y;
		}

		if (!ClientPrefs.data.shaders) return;

		var colorShader:AdjustColorShader = new AdjustColorShader();
		colorShader.apply(5, 20, 0, 0);
		if (boyfriend != null) boyfriend.shader = colorShader;
		if (dad != null) dad.shader = colorShader;
		if (gf != null) gf.shader = colorShader;
		if (santa != null) santa.shader = colorShader;
	}

	override function countdownTick(count:Countdown, num:Int) everyoneDance();
	override function beatHit() everyoneDance();

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch (eventName)
		{
			case "Hey!":
				switch (value1.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend' | '0':
						return;
				}
				bottomBoppers.animation.play('hey', true);
				bottomBoppers.heyTimer = flValue2;
		}
	}

	function everyoneDance()
	{
		if (upperBoppers != null) upperBoppers.dance(true);
		bottomBoppers.dance(true);
		santa.dance(true);
	}

	function eggnogEndCutscene()
	{
		if (PlayState.storyPlaylist[1] == null)
		{
			endSong();
			return;
		}

		var nextSong:String = Paths.formatToSongPath(PlayState.storyPlaylist[1]);
		if (nextSong == 'winter-horrorland')
		{
			FlxG.sound.play(Paths.sound('Lights_Shut_off'));

			var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
				-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			blackShit.scrollFactor.set();
			add(blackShit);
			camHUD.visible = false;

			inCutscene = true;
			canPause = false;

			new FlxTimer().start(1.5, function(tmr:FlxTimer) endSong());
		}
		else endSong();
	}
}
#end
