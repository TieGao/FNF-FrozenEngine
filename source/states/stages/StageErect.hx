// StageErect.hx - 完整实现
package states.stages;

import states.stages.objects.*;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import shaders.AdjustColorEffect;

class StageErect extends BaseStage
{
	// 背景元素
	var darkBG:BGSprite;
	var crowd:BGSprite;
	var backStage:BGSprite;
	var orangeHue:BGSprite;
	var stageLights:BGSprite;
	var light:BGSprite;
	
	// 服务器相关
	var server:BGSprite;
	var greenServerLight:BGSprite;
	var redServerLight:BGSprite;
	var smallLight:BGSprite;
	
	// 聚光灯事件相关
	var blackenScreen:FlxSprite;
	var spotlight:BGSprite;
	var smoke1:BGSprite;
	var smoke2:BGSprite;
	
	// 烟雾参数
	var smoke1Velocity:Float = 0;
	var smoke2Velocity:Float = 0;

	var adjustEffects:Map<String, AdjustColorEffect> = new Map();

	override function create()
	{
		// 黑暗背景
		darkBG = new BGSprite('erect/backDark', 729, -170, 1, 1);
		add(darkBG);

		// 人群
		crowd = new BGSprite('erect/crowd', 560, 290, 0.8, 0.8, ['Symbol 2 instance 1'], true);
		add(crowd);

		if (!ClientPrefs.data.lowQuality) {
			// 小灯光
			smallLight = new BGSprite('erect/brightLightSmall', 967, -103, 1.2, 1.2);
			smallLight.blend = ADD;
			add(smallLight);
		}

		// 舞台背景
		backStage = new BGSprite('erect/bg', -603, -277, 1, 1);
		backStage.setGraphicSize(Std.int(backStage.width * 1.1));
		backStage.updateHitbox();
		add(backStage);

		if (!ClientPrefs.data.lowQuality) {
			// 服务器
			server = new BGSprite('erect/server', -361, 215, 1, 1);
			add(server);

			// 绿色服务器灯
			greenServerLight = new BGSprite('erect/lightgreen', -171, 242, 1, 1);
			greenServerLight.blend = ADD;
			add(greenServerLight);

			// 红色服务器灯
			redServerLight = new BGSprite('erect/lightred', -101, 560, 1, 1);
			redServerLight.blend = ADD;
			add(redServerLight);
		}

		// 橙色色调
		orangeHue = new BGSprite('erect/orangeLight', 189, -195, 1, 1);
		orangeHue.blend = ADD;
		add(orangeHue);

		if (!ClientPrefs.data.lowQuality) {
			// 舞台灯光
			stageLights = new BGSprite('erect/lights', -601, -147, 1.2, 1.2);
			add(stageLights);

			// 上方灯光
			light = new BGSprite('erect/lightAbove', 804, -117, 1, 1);
			light.blend = ADD;
			add(light);
		}
	}

	override function createPost()
	{
		// 检查是否需要聚光灯事件
		checkSpotlightEvent();
		
		// 应用着色器效果
		if (ClientPrefs.data.shaders) {
			applyColorAdjustmentToCharacters();
		}
	}

	function checkSpotlightEvent()
	{
		for (event in PlayState.instance.eventNotes) {
			if (event.event == 'Dadbattle Spotlight') {
				createSpotlightSprites();
				break;
			}
		}
	}

	function createSpotlightSprites()
	{
		// 黑色屏幕覆盖
		blackenScreen = new FlxSprite(-800, -400);
		blackenScreen.makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		blackenScreen.scrollFactor.set(0, 0);
		blackenScreen.alpha = 0.25;
		blackenScreen.visible = false;
		add(blackenScreen);
		
		// 聚光灯
		spotlight = new BGSprite('spotlight', 400, -400);
		spotlight.blend = ADD;
		spotlight.alpha = 0;
		spotlight.visible = false;
		add(spotlight);
		
		// 烟雾效果
		var smoke1OffsetY = FlxG.random.float(-15, 15);
		var smoke1Scale = FlxG.random.float(1.1, 1.22);
		smoke1Velocity = FlxG.random.float(15, 22);
		
		smoke1 = new BGSprite('smoke',-1650, 680 + smoke1OffsetY);
		smoke1.scale.set(smoke1Scale, smoke1Scale);
		smoke1.scrollFactor.set(1.2, 1.05);
		smoke1.alpha = 0;
		smoke1.velocity.x = smoke1Velocity;
		add(smoke1);
		
		var smoke2OffsetY = FlxG.random.float(-15, 15);
		var smoke2Scale = FlxG.random.float(1.1, 1.22);
		smoke2Velocity = FlxG.random.float(-22, -15);
		
		smoke2 = new BGSprite('smoke',1850, 680 + smoke2OffsetY);
		smoke2.scale.set(smoke2Scale, smoke2Scale);
		smoke2.scrollFactor.set(1.2, 1.05);
		smoke2.alpha = 0;
		smoke2.flipX = true;
		smoke2.velocity.x = smoke2Velocity;
		add(smoke2);
	}

	function applyColorAdjustmentToCharacters()
{
    var characters = [boyfriend, dad, gf];
    var characterNames = ['boyfriend', 'dad', 'gf'];
    
    for (i in 0...characters.length) {
        var char = characters[i];
        var name = characterNames[i];
        
        if (char != null) {
            var effect = new AdjustColorEffect();
            
            switch(name) {
                case 'boyfriend':
                    effect.setValues(12, 0, -23, 7); // hue: 12, saturation: 0, brightness: -23, contrast: 7
                case 'dad':
                    effect.setValues(-32, 0, -33, -23); // hue: -32, saturation: 0, brightness: -33, contrast: -23
                case 'gf':
                    effect.setValues(-9, 0, -30, -4); // hue: -9, saturation: 0, brightness: -30, contrast: -4
            }
            
            char.shader = effect.shader;
        }
    }
}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Dadbattle Spotlight":
				handleSpotlightEvent(Std.parseInt(value1));
		}
	}

	function handleSpotlightEvent(value:Int)
	{
		if (value > 0) {
			// 激活事件
			if (value == 1) {
				game.defaultCamZoom += 0.12;
				
				if (smallLight != null) smallLight.visible = false;
				if (light != null) light.visible = false;
				if (blackenScreen != null) blackenScreen.visible = true;
				if (spotlight != null) spotlight.visible = true;
				if (smoke1 != null) smoke1.visible = true;
				if (smoke2 != null) smoke2.visible = true;
			}
			
			// 设置聚光灯目标
			var target = dad;
			if (value > 2) {
				target = boyfriend;
			}
			
			if (spotlight != null && target != null) {
				spotlight.x = target.getMidpoint().x - spotlight.width / 2;
				spotlight.y = target.y + target.height - spotlight.height + 50;
				
				new FlxTimer().start(0.12, function(tmr:FlxTimer) {
					spotlight.alpha = 0.375;
				});
			}
			
			// 烟雾渐入
			if (smoke1 != null) {
				FlxTween.tween(smoke1, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
			}
			if (smoke2 != null) {
				FlxTween.tween(smoke2, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
			}
		} else {
			// 停用事件
			game.defaultCamZoom -= 0.12;
			
			if (smallLight != null) smallLight.visible = true;
			if (light != null) light.visible = true;
			if (blackenScreen != null) blackenScreen.visible = false;
			if (spotlight != null) spotlight.visible = false;
			
			// 烟雾渐出
			if (smoke1 != null) {
				FlxTween.tween(smoke1, {alpha: 0}, 0.7, {ease: FlxEase.linear});
			}
			if (smoke2 != null) {
				FlxTween.tween(smoke2, {alpha: 0}, 0.7, {ease: FlxEase.linear});
			}
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// 更新烟雾位置
		if (smoke1 != null && smoke1.visible) {
			if (smoke1.x > FlxG.width * 2) {
				smoke1.x = -1650;
			}
		}
		
		if (smoke2 != null && smoke2.visible) {
			if (smoke2.x < -FlxG.width * 2) {
				smoke2.x = 1850;
			}
		}
	}
}