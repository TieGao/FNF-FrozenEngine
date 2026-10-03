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
