// MallErect.hx - 修正版
package states.stages;

import states.stages.objects.*;
import objects.Character;
import shaders.AdjustColorEffect;

class MallErect extends BaseStage
{
	// 背景元素
	var upperBoppers:BGSprite;
	var bottomBoppers:MallCrowd;
	var santa:BGSprite;
	var fog:BGSprite;
	var bgEscalator:BGSprite;
	
	// 着色器效果
	var adjustEffects:Map<String, AdjustColorEffect> = new Map();

	override function create()
	{
		// 墙壁背景
		var bg:BGSprite = new BGSprite('christmas/erect/bgWalls', -1000, -440, 0.2, 0.2);
		bg.scale.set(0.9, 0.9);
		bg.updateHitbox();
		add(bg);

		if (!ClientPrefs.data.lowQuality) {
			// 上部人群
			upperBoppers = new BGSprite('christmas/erect/upperBop', -240, -40, 0.33, 0.33, ['upperBop'], true);
			upperBoppers.scale.set(0.85, 0.85);
			upperBoppers.updateHitbox();
			add(upperBoppers);

			// 电梯
			bgEscalator = new BGSprite('christmas/erect/bgEscalator', -1100, -540, 0.3, 0.3);
			bgEscalator.scale.set(0.9, 0.9);
			bgEscalator.updateHitbox();
			add(bgEscalator);

			// 雾效果
			fog = new BGSprite('christmas/erect/white', -1000, 100, 0.85, 0.85);
			fog.scale.set(0.9, 0.9);
			fog.updateHitbox();
			add(fog);
		}

		// 圣诞树
		var tree:BGSprite = new BGSprite('christmas/erect/christmasTree', 370, -250, 0.4, 0.4);
		add(tree);

		// 下部人群 - 使用 MallCrowd 类
		// 注意：根据你的 MallCrowd 构造函数，需要传递正确的参数
		bottomBoppers = new MallCrowd(-400, 120, 'christmas/erect/bottomBop', 'bottomBop');
		add(bottomBoppers);

		// 雪地前景
		var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -600, 680);
		add(fgSnow);

		// 圣诞老人
		santa = new BGSprite('christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
		add(santa);
		
		setDefaultGF('gf-christmas');
	}

	override function createPost()
	{
		// 角色着色器效果
		if (ClientPrefs.data.shaders) {
			applyColorAdjustmentToCharacters();
		}
	}
	
	function applyColorAdjustmentToCharacters()
	{
		var characters:Array<Character> = [];
		var characterNames:Array<String> = [];
		
		// 添加主要角色
		if (boyfriend != null) {
			characters.push(boyfriend);
			characterNames.push('boyfriend');
		}
		if (dad != null) {
			characters.push(dad);
			characterNames.push('dad');
		}
		if (gf != null) {
			characters.push(gf);
			characterNames.push('gf');
		}
		
		for (i in 0...characters.length) {
			var char = characters[i];
			var name = characterNames[i];
			
			if (char != null) {
				try {
					var effect = new AdjustColorEffect();
					effect.setValues(5, 20, 0, 0); // 根据 Lua 脚本设置参数
					char.shader = effect.shader;
					adjustEffects.set(name, effect);
				} catch (e:Dynamic) {
					trace('Error applying shader to $name: $e');
				}
			}
		}
		
		// 圣诞老人
		if (santa != null) {
			try {
				var effect = new AdjustColorEffect();
				effect.setValues(5, 20, 0, 0);
				santa.shader = effect.shader;
				adjustEffects.set('santa', effect);
			} catch (e:Dynamic) {
				trace('Error applying shader to santa: $e');
			}
		}
	}

	override function countdownTick(count:Countdown, num:Int)
	{
		everyoneDance();
	}

	override function beatHit()
	{
		everyoneDance();
	}

	function everyoneDance()
	{
		if (!ClientPrefs.data.lowQuality && upperBoppers != null) {
			upperBoppers.animation.play('upperBop', true);
		}
			bottomBoppers.dance(true);
			santa.animation.play('santa idle in fear', true);
		
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Hey!":
				// 检查是否是给 boyfriend 的
				var target = value1.toLowerCase().trim();
				if (target == 'bf' || target == 'boyfriend' || target == '0') {
					return;
				}
				
					// 播放 hey 动画
					bottomBoppers.animation.play('hey', true);
					
					// 设置计时器
					if (flValue2 != null && flValue2 > 0) {
						bottomBoppers.heyTimer = flValue2;
					} else {
						bottomBoppers.heyTimer = 0.6; // 默认值，与 Lua 脚本一致
					}

		}
	}
}