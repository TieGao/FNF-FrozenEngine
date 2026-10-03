package states.stages;

#if BASE_GAME_ERECT
import shaders.DropShadowShader;

/**
 * Week 7（tank）的 erect 变体舞台，道具 / 坐标照原版 `tankmanBattlefieldErect` 舞台。
 *
 * 原版这里有两处 animateatlas（sniper / rando），而 FE 的 flxanimate 没有 `applyStageMatrix`，
 * 摆不出原版位置 —— 改用 Erect Mode 的 sparrow 版本（`erect/sniper`、`erect/guy`），坐标也随之取 Erect Mode 的值。
 *
 * sniper / guy 只在 `lowQuality` 关掉时建；`beatHit` 每两拍让他们动一下，sniper 另有小概率喝水。
 * Tankman 死亡语音（`jeffGameover`）由 `GameOverSubstate` 处理。
 */
class TankErect extends BaseStage
{
	var sniper:FlxSprite;
	var tankGuy:FlxSprite;
	var sniperSipping:Bool = false;

	override function create()
	{
		var bg:BGSprite = new BGSprite('erect/bg', -985, -805, 1, 1);
		bg.setGraphicSize(Std.int(bg.width * 1.15));
		bg.updateHitbox();
		add(bg);

		if (!ClientPrefs.data.lowQuality)
		{
			sniper = new FlxSprite(-127, 349);
			sniper.frames = Paths.getSparrowAtlas('erect/sniper');
			sniper.animation.addByPrefix('idle', 'Tankmanidlebaked instance ', 24, false);
			sniper.animation.addByPrefix('sip', 'tanksippingBaked instance ', 24, false);
			sniper.animation.play('idle');
			sniper.setGraphicSize(Std.int(sniper.width * 1.15));
			sniper.updateHitbox();
			add(sniper);

			tankGuy = new FlxSprite(1398, 407);
			tankGuy.frames = Paths.getSparrowAtlas('erect/guy');
			tankGuy.animation.addByPrefix('idle', 'BLTank2 instance ', 24, false);
			tankGuy.animation.play('idle');
			tankGuy.setGraphicSize(Std.int(tankGuy.width * 1.15));
			tankGuy.updateHitbox();
			add(tankGuy);
		}

		if (songName == 'stress') setDefaultGF('pico-speaker');
		else setDefaultGF('gf-tankmen');
	}

	override function createPost()
	{
		// 原版 zIndex 101：压在 gf 之上、bf/dad 之下
		var bricksGround:BGSprite = new BGSprite('erect/bricksGround', 465, 760, 1, 1);
		bricksGround.setGraphicSize(Std.int(bricksGround.width * 1.15));
		bricksGround.updateHitbox();
		bricksGround.flipX = true;
		addBehindDad(bricksGround);

		if (!ClientPrefs.data.shaders) return;

		// 原版 tankErect.lua：hue -38 / sat -20 / contrast -25 / brightness -46，
		// 边缘光朝上、强度 1、距离 15、阈值 0.1，颜色 #DFEF3C；dad 改成 135 度、阈值 0.3
		attachShadow(boyfriend, -38, -20, -46, -25, 90, 15, 0.1);
		attachShadow(dad, -38, -20, -46, -25, 135, 15, 0.3);
		attachShadow(gf, -38, -20, -46, -25, 90, 15, 0.1);
	}

	static inline var RIM_COLOR:Int = 0xFFDFEF3C;

	/** 原版 `dropShadow` 的边缘高光 + Adjust Color 合一，颜色固定为本舞台的 RIM_COLOR。 */
	function attachShadow(char:FlxSprite, hue:Float, saturation:Float, brightness:Float, contrast:Float,
		angle:Float, distance:Float, threshold:Float, strength:Float = 1):Void
	{
		if (char == null) return;
		DropShadowShader.attach(char, {
			hue: hue,
			saturation: saturation,
			brightness: brightness,
			contrast: contrast,
			color: RIM_COLOR,
			angle: angle,
			strength: strength,
			distance: distance,
			threshold: threshold
		});
	}

	override function countdownTick(count:Countdown, num:Int)
	{
		if (num % 2 == 0) bopTankmen();
	}

	override function beatHit()
	{
		if (curBeat % 2 == 0) bopTankmen();
	}

	function bopTankmen():Void
	{
		if (sniper == null || tankGuy == null) return;

		if (!sniperSipping)
		{
			if (FlxG.random.bool(2))
			{
				sniper.animation.play('sip', true);
				sniperSipping = true;
				new FlxTimer().start(sniper.animation.curAnim.numFrames / 24.0, function(_) sniperSipping = false);
			}
			else sniper.animation.play('idle', true);
		}
		tankGuy.animation.play('idle', true);
	}
}
#end
