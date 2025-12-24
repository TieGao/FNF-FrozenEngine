// PhillyErect.hx
package states.stages;

import states.stages.objects.*;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import objects.Character;
import shaders.AdjustColorEffect;

class PhillyErect extends BaseStage
{
	// 背景元素
	var sky:BGSprite;
	var city:BGSprite;
	var window:BGSprite;
	var behindTrain:BGSprite;
	var train:BGSprite;
	var street:BGSprite;
	
	// 火车状态
	var isTrainMoving:Bool = false;
	var isTrainFinished:Bool = false;
	var startedMoving:Bool = false;
	var trainCars:Int = 8;
	var trainCooldown:Int = 0;
	var trainFrameTiming:Float = 0;
	
	// 窗户颜色
	static var windowColors:Array<FlxColor> = [
		FlxColor.fromRGB(0x26, 0x63, 0xAC),  // 蓝色
		FlxColor.fromRGB(0x32, 0x9A, 0x6D),  // 绿色
		FlxColor.fromRGB(0x50, 0x2D, 0x64),  // 紫色
		FlxColor.fromRGB(0x93, 0x2C, 0x28),  // 红色
		FlxColor.fromRGB(0xB6, 0x6F, 0x43)   // 橙色
	];
	var curLight:Int = 0;
	
	// 发光事件相关
	var blammedLightsBlack:FlxSprite;
	var phillyGlowGradient:PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlowParticle>;
	var phillyWindowEvent:BGSprite;
	var curLightEvent:Int = -1;
	var phillyLightsColors:Array<FlxColor>;

	var adjustEffects:Map<String, AdjustColorEffect> = new Map();

	override function createPost()
	{
		// 角色着色器效果
		if (ClientPrefs.data.shaders) {
			applyColorAdjustmentToCharacters();
		}
	}

	override function create()
	{
		// 天空
		if (!ClientPrefs.data.lowQuality) {
			sky = new BGSprite('philly/erect/sky', -100, 0, 0.1, 0.1);
			add(sky);
		}

		// 城市
		city = new BGSprite('philly/erect/city', -10, 0, 0.3, 0.3);
		city.setGraphicSize(Std.int(city.width * 0.85));
		city.updateHitbox();
		add(city);

		// 窗户和颜色
		phillyLightsColors = [
			FlxColor.fromString("0xFF31A2FD"),
			FlxColor.fromString("0xFF31FD8C"),
			FlxColor.fromString("0xFFFB33F5"),
			FlxColor.fromString("0xFFFD4531"),
			FlxColor.fromString("0xFFFBA633")
		];
		
		window = new BGSprite('philly/window', city.x, city.y, 0.3, 0.3);
		window.setGraphicSize(Std.int(window.width * 0.85));
		window.updateHitbox();
		add(window);
		window.alpha = 0;

		if (!ClientPrefs.data.lowQuality) {
			// 火车后方
			behindTrain = new BGSprite('philly/erect/behindTrain', -40, 50);
			add(behindTrain);
		}

		// 火车
		train = new BGSprite('philly/train', 2000, 360);
		add(train);

		// 街道
		street = new BGSprite('philly/erect/street', -40, 50);
		add(street);
	}

	function applyColorAdjustmentToCharacters()
{
    var characters = [boyfriend, dad, gf, train];
    var characterNames = ['boyfriend', 'dad', 'gf', 'train'];
    
    for (i in 0...characters.length) {
        var char = characters[i];
        var name = characterNames[i];
        
        if (char != null) {
            var effect = new AdjustColorEffect();
            effect.setValues(-26, -16, -5, 0); // hue: -26, saturation: -16, brightness: -5, contrast: 0
            char.shader = effect.shader;
        }
    }
}

	override function eventPushed(event:objects.Note.EventNote)
	{
		switch(event.event)
		{
			case "Philly Glow":
				blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5);
				blammedLightsBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				blammedLightsBlack.visible = false;
				insert(members.indexOf(street), blammedLightsBlack);

				phillyWindowEvent = new BGSprite('philly/window', window.x, window.y, 0.3, 0.3);
				phillyWindowEvent.setGraphicSize(Std.int(phillyWindowEvent.width * 0.85));
				phillyWindowEvent.updateHitbox();
				phillyWindowEvent.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);

				phillyGlowGradient = new PhillyGlowGradient(-400, 225);
				phillyGlowGradient.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyGlowGradient);
				if(!ClientPrefs.data.flashing) phillyGlowGradient.intendedAlpha = 0.7;

				phillyGlowParticles = new FlxTypedGroup<PhillyGlowParticle>();
				phillyGlowParticles.visible = false;
				insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// 更新火车动画
		if (isTrainMoving) {
			trainFrameTiming += elapsed;
			
			if (trainFrameTiming >= 1 / 24) {
				updateTrainPos();
				trainFrameTiming = 0;
			}
		}
		
		// 窗户淡出
		window.alpha -= (Conductor.crochet / 1000) * elapsed * 1.5;
		
		// 更新粒子
		if (phillyGlowParticles != null) {
			phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle) {
				if (particle.alpha <= 0)
					particle.kill();
			});
		}
	}

	function updateTrainPos()
	{
		if (train.animation.getByName('train') != null && train.animation.curAnim != null) {
			if (train.animation.curAnim.curFrame >= 1) {
				startedMoving = true;
				
				// GF 头发飘动
				if (gf != null) {
					gf.playAnim('hairBlow');
					gf.specialAnim = true;
				}
			}
		}
		
		if (startedMoving) {
			train.x -= 400;
			
			if (train.x < -2000 && !isTrainFinished) {
				train.x = -1150;
				trainCars--;
				
				if (trainCars <= 0) {
					isTrainFinished = true;
				}
			}
			
			if (train.x - 400 < -4000 && isTrainFinished) {
				trainReset();
			}
		}
	}

	function trainReset()
	{
		isTrainMoving = false;
		trainCars = 8;
		isTrainFinished = false;
		startedMoving = false;
		train.x = FlxG.width + 200;
		
		if (gf != null) {
			gf.danced = false;
			gf.playAnim('hairFall');
			gf.specialAnim = true;
		}
	}

	override function beatHit()
	{
		super.beatHit();
		
		// 火车节拍
		if (train != null && train.animation.getByName('train') != null) {
			train.animation.play('train', true);
		}
		
		if (!isTrainMoving) {
			trainCooldown++;
		}
		
		// 每4拍改变窗户颜色
		if (curBeat % 4 == 0) {
			curLight = FlxG.random.int(0, windowColors.length - 1, [curLight]);
			window.alpha = 1;
			window.color = windowColors[curLight];
		}
		
		// 随机火车启动
		if (curBeat % 8 == 4 && FlxG.random.bool(30) && !isTrainMoving && trainCooldown > 8) {
			trainCooldown = FlxG.random.int(-4, 0);
			trainStart();
		}
	}

	function trainStart()
	{
		isTrainMoving = true;
		FlxG.sound.play(Paths.sound('train_passes'));
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Philly Glow":
				handleGlowEvent(flValue1);
		}
	}

	function handleGlowEvent(lightId:Null<Float>)
	{
		if(lightId == null || lightId <= 0) lightId = 0;
		var lightNum:Int = Math.round(lightId);

		// 修正：创建 Character 数组的正确方式
		var chars:Array<Character> = [];
		if (boyfriend != null) chars.push(boyfriend);
		if (gf != null) chars.push(gf);
		if (dad != null) chars.push(dad);
		
		switch(lightNum)
		{
			case 0:
				if(phillyGlowGradient != null && phillyGlowGradient.visible)
				{
					doFlash();
					if(ClientPrefs.data.camZooms)
					{
						FlxG.camera.zoom += 0.5;
						camHUD.zoom += 0.1;
					}

					blammedLightsBlack.visible = false;
					phillyWindowEvent.visible = false;
					phillyGlowGradient.visible = false;
					phillyGlowParticles.visible = false;
					curLightEvent = -1;

					// 修正：使用明确的循环
					for (i in 0...chars.length) {
						var who = chars[i];
						who.color = FlxColor.WHITE;
					}
					street.color = FlxColor.WHITE;
				}

			case 1: // 开启
				curLightEvent = FlxG.random.int(0, phillyLightsColors.length - 1, [curLightEvent]);
				var color:FlxColor = phillyLightsColors[curLightEvent];

				if(phillyGlowGradient != null && !phillyGlowGradient.visible)
				{
					doFlash();
					if(ClientPrefs.data.camZooms)
					{
						FlxG.camera.zoom += 0.5;
						camHUD.zoom += 0.1;
					}

					blammedLightsBlack.visible = true;
					blammedLightsBlack.alpha = 1;
					phillyWindowEvent.visible = true;
					phillyGlowGradient.visible = true;
					phillyGlowParticles.visible = true;
				}
				else if(ClientPrefs.data.flashing)
				{
					var colorButLower:FlxColor = color;
					colorButLower.alphaFloat = 0.25;
					FlxG.camera.flash(colorButLower, 0.5, null, true);
				}

				var charColor:FlxColor = color;
				if(!ClientPrefs.data.flashing) charColor.saturation *= 0.5;
				else charColor.saturation *= 0.75;

				// 修正：使用明确的循环
				for (i in 0...chars.length) {
					var who = chars[i];
					who.color = charColor;
				}
				
				if (phillyGlowParticles != null) {
					phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle)
					{
						particle.color = color;
					});
				}
				
				if (phillyGlowGradient != null) phillyGlowGradient.color = color;
				if (phillyWindowEvent != null) phillyWindowEvent.color = color;

				color.brightness *= 0.5;
				street.color = color;

			case 2: // 生成粒子
				if(!ClientPrefs.data.lowQuality && phillyGlowParticles != null)
				{
					var particlesNum:Int = FlxG.random.int(8, 12);
					var width:Float = (2000 / particlesNum);
					var color:FlxColor = phillyLightsColors[curLightEvent];
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
				if (phillyGlowGradient != null) phillyGlowGradient.bop();
		}
	}

	function doFlash()
	{
		var color:FlxColor = FlxColor.WHITE;
		if(!ClientPrefs.data.flashing) color.alphaFloat = 0.5;

		FlxG.camera.flash(color, 0.15, null, true);
	}
}