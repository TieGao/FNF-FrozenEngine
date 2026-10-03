package states.stages;

#if BASE_GAME_ERECT
import states.stages.objects.*;
import objects.Character;
import shaders.AdjustColorShader;

/**
 * Week 3（philly）的 erect 变体舞台，参照 Erect Mode 的 `phillyErect.lua`。
 *
 * 天空 / 城市 / 窗光 / 列车 / 街道走 `philly/erect/*`，窗光复用 `philly/window`；
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
		var sky:BGSprite = new BGSprite('philly/erect/sky', -100, 0, 0.1, 0.1);
		add(sky);

		var city:BGSprite = new BGSprite('philly/erect/city', -10, 0, 0.3, 0.3);
		city.setGraphicSize(Std.int(city.width * 0.85));
		city.updateHitbox();
		add(city);

		lights = new BGSprite('philly/window', -10, 0, 0.3, 0.3);
		lights.setGraphicSize(Std.int(lights.width * 0.85));
		lights.updateHitbox();
		lights.alpha = 0;
		add(lights);

		var behindTrain:BGSprite = new BGSprite('philly/erect/behindTrain', -40, 50, 1, 1);
		add(behindTrain);

		phillyTrain = new PhillyTrain(2000, 360);
		add(phillyTrain);

		street = new BGSprite('philly/erect/street', -40, 50, 1, 1);
		add(street);
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

		phillyWindowEvent = new BGSprite('philly/window', lights.x, lights.y, 0.3, 0.3);
		phillyWindowEvent.setGraphicSize(Std.int(phillyWindowEvent.width * 0.85));
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
}
#end
