package states.stages;

#if BASE_GAME_ERECT
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import objects.Character;

/**
 * Week 2（spooky）的 erect 变体舞台，参照 Erect Mode 的 `spookyErect.lua`。
 *
 * 道具：`erect/bgtrees`（5fps 循环）、`erect/bgDark`（常显）、`erect/bgLight`（闪电时显）、
 * `erect/stairsDark`、`erect/stairsLight`。
 *
 * 角色走 `-dark` 变体（bf-dark / gf-dark / spooky-dark）。Erect Mode 的机制是：
 * 暗色角色是本体，另外在它正下方叠一个**亮色镜像孪生**（同一个角色、去掉 `-dark` 后缀），
 * 位置 / 动画逐帧同步；平时孪生 alpha = 0（只看得到暗色剪影），闪电瞬间把本体 alpha 压到 0、
 * 孪生拉到 1（露出亮色），随后再淡回去。
 *
 * 孪生必须 `active = false`：`Character.update()` 在 holdTimer 到期、非玩家角色唱完、
 * 或 miss 动画播完时会自己 `dance()`，会把镜像过来的帧覆盖掉。位置与帧全部由本舞台手写。
 *
 * 明暗不用 FlxTween 而是自己积一个 `lightLevel`（0 全暗 / 1 全亮）：闪电的双闪节奏
 * （亮 → 立刻转暗 → 再亮起并 1.5s 淡出）要连着改两次目标值，tween 会互相打架；
 * 自积还能保证结束态是干净的 0 / 1，不会留下 0.999 让孪生永远显形。
 *
 * 原版脚本还给 `outdoorTrees` 挂了 sprite 级的 rain shader，FE 的 `shaders.RainShader`
 * 只有全屏模式、没有 `uSpriteMode`，这里不做。
 */
class SpookyErect extends BaseStage
{
	/** 没有暗色变体时，闪电熄灭后角色回到的暗色（原版脚本里的 0x070711） */
	static inline var DARK_TINT:Int = 0x070711;
	/** 闪电第二次亮起后淡回全暗用的时长 */
	static inline var LIGHT_FADE:Float = 1.5;

	/** 闪电时一起亮的图层（bgLight / stairsLight） */
	var lightLayers:Array<FlxSprite> = [];
	/** 参与明暗切换的角色，下标与 lightChars 一一对应 */
	var darkChars:Array<Character> = [];
	/** 暗色本体对应的亮色镜像孪生；角色没有 `-dark` 变体时为 null */
	var lightChars:Array<Character> = [];

	/** 0 = 全暗（暗色本体可见），1 = 全亮（亮色孪生可见） */
	var lightLevel:Float = 0;
	/** lightLevel 每秒的变化量；0 表示停在当前值 */
	var lightRamp:Float = 0;

	var lightingFlash:FlxSprite;

	override function create()
	{
		var trees:BGSprite = new BGSprite('erect/bgtrees', 200, 50, 0.8, 0.8, ['bgtrees'], true);
		if (trees.animation.curAnim != null) trees.animation.curAnim.frameRate = 5; // 原版 5fps
		add(trees);

		add(new BGSprite('erect/bgDark', -360, -220, 1, 1));

		if (!ClientPrefs.data.lowQuality)
		{
			var bgLight:BGSprite = new BGSprite('erect/bgLight', -360, -220, 1, 1);
			bgLight.alpha = 0;
			lightLayers.push(bgLight);
			add(bgLight);
		}

		// PRECACHE SOUNDS
		Paths.sound('thunder_1');
		Paths.sound('thunder_2');
	}

	override function createPost()
	{
		if (!ClientPrefs.data.lowQuality)
		{
			add(new BGSprite('erect/stairsDark', 966, -225, 1, 1));

			var stairsLight:BGSprite = new BGSprite('erect/stairsLight', 966, -225, 1, 1);
			stairsLight.alpha = 0;
			lightLayers.push(stairsLight);
			add(stairsLight);
		}

		if (ClientPrefs.data.flashing)
		{
			lightingFlash = new BGSprite(null, -800, -400, 0, 0);
			lightingFlash.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
			lightingFlash.blend = ADD;
			lightingFlash.alpha = 0;
			add(lightingFlash);
		}

		addDarkTwin(boyfriend, 'bf', boyfriendGroup);
		addDarkTwin(dad, 'spooky', dadGroup);
		if (gf != null) addDarkTwin(gf, 'gf', gfGroup);
	}

	/**
	 * 给暗色角色建一个亮色镜像孪生，插在角色组正下方（绘制层级紧贴其下）。
	 * 角色不是 `-dark` 变体时没有孪生，改由闪电时整体染色近似。
	 */
	function addDarkTwin(dark:Character, baseName:String, group:FlxSpriteGroup):Void
	{
		if (dark == null) return;

		if (!dark.curCharacter.endsWith('-dark'))
		{
			darkChars.push(dark);
			lightChars.push(null);
			return;
		}

		var light:Character = new Character(0, 0, baseName, dark.isPlayer);
		light.x = dark.x;
		light.y = dark.y;
		light.scrollFactor.copyFrom(dark.scrollFactor);
		light.antialiasing = dark.antialiasing;
		light.alpha = 0;
		light.active = false; // 不跑自己的 update，位置与帧全由本舞台同步
		insert(members.indexOf(group), light);

		darkChars.push(dark);
		lightChars.push(light);
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;
	override function beatHit()
	{
		if (FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
		{
			lightningStrikeShit();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (lightRamp != 0)
		{
			lightLevel = FlxMath.bound(lightLevel + elapsed * lightRamp, 0, 1);
			if (lightLevel == 0 || lightLevel == 1) lightRamp = 0;
		}

		for (layer in lightLayers)
			layer.alpha = lightLevel;

		for (i in 0...darkChars.length)
		{
			var dark:Character = darkChars[i];
			if (dark == null) continue;

			var twin:Character = lightChars[i];
			if (twin == null)
			{
				// 没有暗色变体：换不了图集，用整体染色近似
				dark.color = FlxColor.interpolate(DARK_TINT, FlxColor.WHITE, lightLevel);
				continue;
			}

			dark.alpha = 1 - lightLevel;
			syncTwin(dark, twin);
		}
	}

	/** 把孪生的位置 / 可见性 / 动画对齐到本体；alpha 取本体 alpha 的反相（本体被压暗时孪生才显形） */
	function syncTwin(dark:Character, light:Character):Void
	{
		light.x = dark.x;
		light.y = dark.y;
		light.angle = dark.angle;
		light.flipX = dark.flipX;
		light.visible = dark.visible;
		light.alpha = (lightLevel > 0) ? 1 : 0;

		var darkAnim = dark.animation.curAnim;
		if (darkAnim == null) return;

		var lightAnim = light.animation.curAnim;
		// 亮色 / 暗色两套图集的前缀名不同，但 `Character` 里的动画名一致，按名字同步
		if ((lightAnim == null || lightAnim.name != darkAnim.name) && light.hasAnimation(darkAnim.name))
			light.playAnim(darkAnim.name, true);

		lightAnim = light.animation.curAnim;
		if (lightAnim != null) lightAnim.curFrame = darkAnim.curFrame;
	}

	function lightningStrikeShit():Void
	{
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if (lightingFlash != null)
		{
			FlxTween.cancelTweensOf(lightingFlash);
			lightingFlash.alpha = 0.4;
			FlxTween.tween(lightingFlash, {alpha: 0.5}, 0.075, {
				ease: FlxEase.linear,
				onComplete: function(_) FlxTween.tween(lightingFlash, {alpha: 0}, 0.25, {ease: FlxEase.linear})
			});
		}

		if (!ClientPrefs.data.lowQuality)
		{
			// 原版是「闪亮 → 立刻转暗 → 再亮起并 1.5s 淡出」的双闪，靠两个定时器排出来
			lightLevel = 1;
			lightRamp = 0;
			new FlxTimer().start(0.06, function(_)
			{
				lightLevel = 0;
				lightRamp = 0;
			});
			new FlxTimer().start(0.12, function(_)
			{
				lightLevel = 1;
				lightRamp = -1 / LIGHT_FADE;
			});
		}

		if (boyfriend != null && boyfriend.animOffsets.exists('scared'))
			boyfriend.playAnim('scared', true);
		if (gf != null && gf.animOffsets.exists('scared'))
			gf.playAnim('scared', true);

		if (ClientPrefs.data.camZooms)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if (!game.camZooming) // 防止被永久放大，直到 Skid & Pump 打到音符
			{
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}
	}
}
#end
