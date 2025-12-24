// SpookyErect.hx - 完整实现
package states.stages;

import objects.Character;
import flixel.tweens.FlxTween;

class SpookyErect extends BaseStage
{
	// 背景元素
	var trees:BGSprite;
	var bgDark:BGSprite;
	var bgLight:BGSprite;
	var stairsDark:BGSprite;
	var stairsLight:BGSprite;
	
	// 黑暗角色
	var bfDark:Character;
	var dadDark:Character;
	var gfDark:Character;
	
	// 闪电相关
	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;
	var lightingFlash:FlxSprite;
	
	// 受光照影响的精灵列表
	var lightList:Array<FlxSprite> = [];

	override function create()
	{
		// 树木背景
		trees = new BGSprite('spookyMansion/erect/bgtrees', 190, 30, 0.85, 0.85, ['bgtrees'], true);
		add(trees);

		// 黑暗背景
		bgDark = new BGSprite('spookyMansion/erect/bgDark', -360, -220, 1, 1);
		add(bgDark);
		
		// 光亮背景（初始不可见）
		bgLight = new BGSprite('spookyMansion/erect/bgLight', -360, -220, 1, 1);
		lightList.push(bgLight);
		add(bgLight);

		// 楼梯
		stairsDark = new BGSprite('spookyMansion/erect/stairsDark', 966, -225, 1, 1);
		add(stairsDark);
		
		stairsLight = new BGSprite('spookyMansion/erect/stairsLight', 966, -225, 1, 1);
		lightList.push(stairsLight);
		add(stairsLight);

		// 闪电闪光效果
		if (ClientPrefs.data.flashing && !ClientPrefs.data.lowQuality) {
			lightingFlash = new FlxSprite(-800, -400);
			lightingFlash.makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.WHITE);
			lightingFlash.scrollFactor.set(0, 0);
			lightingFlash.blend = ADD;
			lightingFlash.alpha = 0;
			add(lightingFlash);
		}
		
		// 预加载音效
		Paths.sound('thunder_1');
		Paths.sound('thunder_2');
		
		// 对树木应用雨滴着色器
		if (ClientPrefs.data.shaders && !ClientPrefs.data.lowQuality) {
			applyRainShader();
		}
	}

	function applyRainShader()
	{
		// 对树木应用雨滴着色器
		// setShader(trees, 'rain');
		// setShaderFloat(trees, 'uScale', FlxG.height / 200 * 2);
		// setShaderFloat(trees, 'uIntensity', 0.4);
		// setShaderBool(trees, 'uSpriteMode', true);
	}

	override function createPost()
	{
		if (!ClientPrefs.data.lowQuality) {
			createDarkCharacters();
		}
		
		// 初始隐藏光照效果
		for (sprite in lightList) {
			sprite.alpha = 0;
		}
		
		// 对非黑暗变体的角色应用颜色
		var chars = [boyfriend, dad, gf];
		for (char in chars) {
			if (char != null && !char.curCharacter.endsWith('-dark')) {
				char.color = 0x070711;
			}
		}
	}

	function createDarkCharacters()
	{
		// 创建 BF 黑暗变体
		var darkChar = boyfriend.curCharacter + '-dark';
		if (Paths.fileExists('characters/' + darkChar + '.json', TEXT)) {
			bfDark = new Character(boyfriend.x, boyfriend.y, darkChar, boyfriend.isPlayer);
		} else {
			bfDark = new Character(boyfriend.x, boyfriend.y, boyfriend.curCharacter, boyfriend.isPlayer);
			bfDark.colorTransform.redOffset = -245;
			bfDark.colorTransform.greenOffset = -240;
			bfDark.colorTransform.blueOffset = -230;
		}
		bfDark.flipX = boyfriend.flipX;
		bfDark.alpha = 1; // 黑暗角色初始可见
		addBehindBF(bfDark);
		boyfriend.alpha = 0; // 正常角色初始隐藏

		// 创建 DAD 黑暗变体
		darkChar = dad.curCharacter + '-dark';
		if (Paths.fileExists('characters/' + darkChar + '.json', TEXT)) {
			dadDark = new Character(dad.x, dad.y, darkChar, dad.isPlayer);
		} else {
			dadDark = new Character(dad.x, dad.y, dad.curCharacter, dad.isPlayer);
			dadDark.colorTransform.redOffset = -245;
			dadDark.colorTransform.greenOffset = -240;
			dadDark.colorTransform.blueOffset = -230;
		}
		dadDark.flipX = dad.flipX;
		dadDark.alpha = 1;
		addBehindDad(dadDark);
		dad.alpha = 0;

		// 创建 GF 黑暗变体
		if (gf != null) {
			darkChar = gf.curCharacter + '-dark';
			if (Paths.fileExists('characters/' + darkChar + '.json', TEXT)) {
				gfDark = new Character(gf.x, gf.y, darkChar, gf.isPlayer);
			} else {
				gfDark = new Character(gf.x, gf.y, gf.curCharacter, gf.isPlayer);
				gfDark.colorTransform.redOffset = -245;
				gfDark.colorTransform.greenOffset = -240;
				gfDark.colorTransform.blueOffset = -230;
			}
			gfDark.flipX = gf.flipX;
			gfDark.alpha = 1;
			gfDark.x -= gfGroup.x;
			gfDark.y -= gfGroup.y;
			addBehindGF(gfDark);
			gf.alpha = 0;
		}
		
		// 将角色添加到光照列表
		lightList.push(boyfriend);
		lightList.push(dad);
		if (gf != null) lightList.push(gf);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// 更新黑暗角色的动画
		if (!ClientPrefs.data.lowQuality) {
			syncDarkCharacterAnimations();
		}
		
		// 光照效果淡出
		for (sprite in lightList) {
			sprite.alpha -= elapsed / 2;
		}
		
		// 更新雨滴着色器
		if (trees.shader != null) {
			// 更新着色器时间
		}
	}

	function syncDarkCharacterAnimations()
	{
		// 同步 BF 动画
		if (bfDark != null && boyfriend != null) {
			if (bfDark.animation.name != boyfriend.animation.name) {
				bfDark.playAnim(boyfriend.animation.name, true);
			}
			
			if (!checkNullAnim(bfDark, boyfriend)) {
				bfDark.animation.curAnim.curFrame = boyfriend.animation.curAnim.curFrame;
			}
		}
		
		// 同步 DAD 动画
		if (dadDark != null && dad != null) {
			if (dadDark.animation.name != dad.animation.name) {
				dadDark.playAnim(dad.animation.name, true);
			}
			
			if (!checkNullAnim(dadDark, dad)) {
				dadDark.animation.curAnim.curFrame = dad.animation.curAnim.curFrame;
			}
		}
		
		// 同步 GF 动画
		if (gfDark != null && gf != null) {
			if (gfDark.animation.name != gf.animation.name) {
				gfDark.playAnim(gf.animation.name, true);
			}
			
			if (!checkNullAnim(gfDark, gf)) {
				gfDark.animation.curAnim.curFrame = gf.animation.curAnim.curFrame;
			}
		}
	}

	inline function checkNullAnim(obj1:FlxSprite, obj2:FlxSprite):Bool
	{
		return obj1.animation.curAnim == null || obj2.animation.curAnim == null;
	}

	override function beatHit()
	{
		if (FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
		{
			lightningStrikeShit();
		}
	}

	function lightningStrikeShit():Void
	{
		var soundNum = FlxG.random.int(1, 2);
		FlxG.sound.play(Paths.sound('thunder_' + soundNum));
		
		if(!ClientPrefs.data.lowQuality) {
			for (sprite in lightList) {
				sprite.alpha = 1;
			}
			
			// 闪电闪光效果
			if (lightingFlash != null && ClientPrefs.data.flashing) {
				lightingFlash.alpha = 0.4;
				FlxTween.tween(lightingFlash, {alpha: 0.5}, 0.075, {
					ease: FlxEase.linear,
					onComplete: function(twn:FlxTween) {
						new FlxTimer().start(0.15, function(tmr:FlxTimer) {
							FlxTween.tween(lightingFlash, {alpha: 0}, 0.25, {ease: FlxEase.linear});
						});
					}
				});
			}
			
			// 延迟恢复黑暗
			new FlxTimer().start(0.06, function(tmr:FlxTimer) {
				// 先隐藏光照
				for (sprite in lightList) {
					sprite.alpha = 0;
				}
				
				// 显示黑暗角色
				if (bfDark != null) bfDark.alpha = 1;
				if (dadDark != null) dadDark.alpha = 1;
				if (gfDark != null) gfDark.alpha = 1;
				
				// 隐藏正常角色
				boyfriend.alpha = 0;
				dad.alpha = 0;
				if (gf != null) gf.alpha = 0;
				
				// 对于非黑暗变体，恢复颜色
				if (!boyfriend.curCharacter.endsWith('-dark')) boyfriend.color = 0xFFFFFF;
				if (!dad.curCharacter.endsWith('-dark')) dad.color = 0xFFFFFF;
				if (gf != null && !gf.curCharacter.endsWith('-dark')) gf.color = 0xFFFFFF;
			});
			
			// 延迟开始淡出
			new FlxTimer().start(0.12, function(tmr:FlxTimer) {
				// 对光照效果进行淡出
				for (sprite in lightList) {
					if (sprite != boyfriend && sprite != dad && (gf == null || sprite != gf)) {
						FlxTween.tween(sprite, {alpha: 0}, 1.5, {ease: FlxEase.linear});
					}
				}
				
				// 对角色进行淡入淡出
				if (bfDark != null) FlxTween.tween(bfDark, {alpha: 1}, 1.5, {ease: FlxEase.linear});
				if (dadDark != null) FlxTween.tween(dadDark, {alpha: 1}, 1.5, {ease: FlxEase.linear});
				if (gfDark != null) FlxTween.tween(gfDark, {alpha: 1}, 1.5, {ease: FlxEase.linear});
				
				boyfriend.alpha = 0;
				dad.alpha = 0;
				if (gf != null) gf.alpha = 0;
				
				// 对于非黑暗变体，渐变颜色
				if (!boyfriend.curCharacter.endsWith('-dark')) {
					FlxTween.color(boyfriend, 1.5, 0xFFFFFF, 0x070711, {ease: FlxEase.linear});
				}
				if (!dad.curCharacter.endsWith('-dark')) {
					FlxTween.color(dad, 1.5, 0xFFFFFF, 0x070711, {ease: FlxEase.linear});
				}
				if (gf != null && !gf.curCharacter.endsWith('-dark')) {
					FlxTween.color(gf, 1.5, 0xFFFFFF, 0x070711, {ease: FlxEase.linear});
				}
			});
		}

		// 摄像机缩放
		if (ClientPrefs.data.camZooms) {
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if(!game.camZooming) {
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}

		// 角色害怕动画
		if(boyfriend.animOffsets.exists('scared')) {
			boyfriend.playAnim('scared', true);
		}

		if(dad.animOffsets.exists('scared')) {
			dad.playAnim('scared', true);
		}

		if(gf != null && gf.animOffsets.exists('scared')) {
			gf.playAnim('scared', true);
		}

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);
	}
}