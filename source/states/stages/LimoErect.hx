// LimoErect.hx - 完整版本
package states.stages;

import states.stages.objects.*;
import backend.Achievements;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import shaders.AdjustColorEffect;

class LimoErect extends BaseStage
{
	// 背景元素
	var skyBG:BGSprite;
	var shootingStar:BGSprite;
	var bgLimo:BGSprite;
	var fastCar:BGSprite;
	
	// 舞者组
	var grpLimoDancers:FlxTypedGroup<BackgroundDancer>;
	
	// 雾效果
	var mist1:FlxBackdrop;
	var mist2:FlxBackdrop;
	var mist3:FlxBackdrop;
	var mist4:FlxBackdrop;
	var mist5:FlxBackdrop;
	
	// 事件相关精灵
	var limoMetalPole:BGSprite;
	var limoLight:BGSprite;
	var limoCorpse:BGSprite;
	var limoCorpseTwo:BGSprite;
	var grpLimoParticles:FlxTypedGroup<BGSprite>;
	var dancersDiff:Float = 320;
	
	// 状态
	var limoKillingState:Int = 0; // 0:WAIT, 1:KILLING, 2:SPEEDING_OFFSCREEN, 3:SPEEDING, 4:STOPPING
	var shootingStarBeat:Int = 0;
	var shootingStarOffset:Int = 2;
	var fastCarCanDrive:Bool = true;
	
	// 计时器
	var elapsedTime:Float = 0;
	var carTimer:FlxTimer;

	override function create()
	{
		// 日落背景
		skyBG = new BGSprite('limo/erect/limoSunset', -220, -80, 0.1, 0.1);
		skyBG.scale.set(0.9, 0.9);
		skyBG.updateHitbox();
		add(skyBG);

		if (!ClientPrefs.data.lowQuality) {
			// 流星
			shootingStar = new BGSprite('limo/erect/shooting star', 200, 0, 0.12, 0.12, ['shooting star'], false);
			shootingStar.blend = ADD;
			shootingStar.visible = false;
			add(shootingStar);

			// 豪华轿车背景
			bgLimo = new BGSprite('limo/erect/bgLimo', -200, 480, 0.4, 0.4, ['background limo blue'], true);
			add(bgLimo);

			// 舞者
			grpLimoDancers = new FlxTypedGroup<BackgroundDancer>();
			add(grpLimoDancers);

			for (i in 0...5) {
				var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + dancersDiff + bgLimo.x, bgLimo.y - 400);
				dancer.scrollFactor.set(0.4, 0.4);
				grpLimoDancers.add(dancer);
			}

			// 事件相关精灵
			limoMetalPole = new BGSprite('gore/metalPole', -500, 220, 0.4, 0.4);
			limoMetalPole.visible = false;
			add(limoMetalPole);

			limoCorpse = new BGSprite('gore/noooooo', -500, limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true);
			limoCorpse.visible = false;
			add(limoCorpse);

			limoCorpseTwo = new BGSprite('gore/noooooo', -500, limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true);
			limoCorpseTwo.visible = false;
			add(limoCorpseTwo);

			limoLight = new BGSprite('gore/coldHeartKiller', limoMetalPole.x - 180, limoMetalPole.y - 80, 0.4, 0.4);
			limoLight.visible = false;
			add(limoLight);

			grpLimoParticles = new FlxTypedGroup<BGSprite>();
			add(grpLimoParticles);

			// 预加载血液
			var particle:BGSprite = new BGSprite('gore/stupidBlood', -400, -400, 0.4, 0.4, ['blood'], false);
			particle.alpha = 0.01;
			grpLimoParticles.add(particle);

			// 雾效果
			mist5 = new FlxBackdrop(Paths.image('limo/erect/mistMid'), X);
			mist5.setPosition(-650, -400);
			mist5.scrollFactor.set(0.2, 0.2);
			mist5.blend = ADD;
			mist5.color = 0xFFE7A480;
			mist5.alpha = 1;
			mist5.velocity.x = 100;
			mist5.scale.set(1.5, 1.5);
			add(mist5);

			mist3 = new FlxBackdrop(Paths.image('limo/erect/mistMid'), X);
			mist3.setPosition(-650, -100);
			mist3.scrollFactor.set(0.8, 0.8);
			mist3.blend = ADD;
			mist3.color = 0xFFa7d9be;
			mist3.alpha = 0.5;
			mist3.velocity.x = 900;
			mist3.scale.set(1.5, 1.5);
			add(mist3);

			mist4 = new FlxBackdrop(Paths.image('limo/erect/mistBack'), X);
			mist4.setPosition(-650, -380);
			mist4.scrollFactor.set(0.6, 0.6);
			mist4.blend = ADD;
			mist4.color = 0xFF9c77c7;
			mist4.alpha = 1;
			mist4.velocity.x = 700;
			mist4.scale.set(1.5, 1.5);
			add(mist4);
		}

		// 快车
		fastCar = new BGSprite('limo/fastCarLol', -12600, 160);
		fastCar.active = true;
		add(fastCar);

		
		setDefaultGF('gf-car');
		
		// 音效预加载
		Paths.sound('carPass0');
		Paths.sound('carPass1');
		Paths.sound('dancerdeath');
	}

	override function createPost()
	{
		var limo:BGSprite; // BF脚下的豪华轿车
		limo = new BGSprite('limo/erect/limoDrive', -120, 520, 1, 1, ['Limo stage'], true);
		addBehindGF(limo);

		if (!ClientPrefs.data.lowQuality) {
			// 更多雾效果
			mist1 = new FlxBackdrop(Paths.image('limo/erect/mistMid'), X);
			mist1.setPosition(-650, -100);
			mist1.scrollFactor.set(1.1, 1.1);
			mist1.blend = ADD;
			mist1.color = 0xFFc6bfde;
			mist1.alpha = 0.4;
			mist1.velocity.x = 1700;
			mist1.scale.set(1.3, 1.3);
			add(mist1);

			mist2 = new FlxBackdrop(Paths.image('limo/erect/mistBack'), X);
			mist2.setPosition(-650, -100);
			mist2.scrollFactor.set(1.2, 1.2);
			mist2.blend = ADD;
			mist2.color = 0xFF6a4da1;
			mist2.alpha = 1;
			mist2.velocity.x = 2100;
			add(mist2);
		}
		
		// 应用 Adjust Color 着色器
		if (ClientPrefs.data.shaders) {
			applyColorAdjustmentToSprites();
		}
		
		resetFastCar();
	}
	
	function applyColorAdjustmentToSprites()
	{
		// 主要角色
		var characters = [boyfriend, dad, gf];
		var characterNames = ['boyfriend', 'dad', 'gf'];
		
		for (i in 0...characters.length) {
			var char = characters[i];
			var name = characterNames[i];
			
			if (char != null) {
				var effect = new AdjustColorEffect();
				effect.setValues(-30, -20, -30, 0);
				char.shader = effect.shader;
			}
		}
		
		// 车辆
		if (fastCar != null) {
			var effect = new AdjustColorEffect();
			effect.setValues(-30, -20, -30, 0);
			fastCar.shader = effect.shader;
		}
		
		
		// 舞者（高质量模式下）
		if (!ClientPrefs.data.lowQuality && grpLimoDancers != null) {
			for (dancer in grpLimoDancers) {
				if (dancer != null) {
					var effect = new AdjustColorEffect();
					effect.setValues(-30, -20, -30, 0);
					dancer.shader = effect.shader;
				}
			}
		}
		
		// 事件精灵（如果存在）
		if (!ClientPrefs.data.lowQuality) {
			var eventSprites = [limoMetalPole, limoLight, limoCorpse, limoCorpseTwo];
			for (sprite in eventSprites) {
				if (sprite != null) {
					var effect = new AdjustColorEffect();
					effect.setValues(-30, -20, -30, 0);
					sprite.shader = effect.shader;
				}
			}
		}
	}

	var limoSpeed:Float = 0;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		elapsedTime += elapsed;

		// 更新雾的上下移动
		if (!ClientPrefs.data.lowQuality) {
			mist1.y = 100 + Math.sin(elapsedTime) * 200;
			mist2.y = 0 + Math.sin(elapsedTime * 0.8) * 100;
			mist3.y = -20 + Math.sin(elapsedTime * 0.5) * 200;
			mist4.y = -180 + Math.sin(elapsedTime * 0.4) * 300;
			mist5.y = -450 + Math.sin(elapsedTime * 0.2) * 150;

			grpLimoParticles.forEach(function(spr:BGSprite) {
				if (spr.animation.curAnim.finished) {
					spr.kill();
					grpLimoParticles.remove(spr, true);
					spr.destroy();
				}
			});

			switch (limoKillingState) {
				case 1: // KILLING
					limoMetalPole.x += 5000 * elapsed;
					limoLight.x = limoMetalPole.x - 180;
					limoCorpse.x = limoLight.x - 50;
					limoCorpseTwo.x = limoLight.x + 35;

					var dancers:Array<BackgroundDancer> = grpLimoDancers.members;
					for (i in 0...dancers.length) {
						if (dancers[i].x < FlxG.width * 1.5 && limoLight.x > (370 * i) + 170) {
							switch (i) {
								case 0 | 3:
									if (i == 0) FlxG.sound.play(Paths.sound('dancerdeath'), 0.5);

									var diffStr:String = i == 3 ? ' 2 ' : ' ';
									var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 200, dancers[i].y, 0.4, 0.4, ['hench leg spin' + diffStr + 'PINK'], false);
									grpLimoParticles.add(particle);
									var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 160, dancers[i].y + 200, 0.4, 0.4, ['hench arm spin' + diffStr + 'PINK'], false);
									grpLimoParticles.add(particle);
									var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x, dancers[i].y + 50, 0.4, 0.4, ['hench head spin' + diffStr + 'PINK'], false);
									grpLimoParticles.add(particle);

									var particle:BGSprite = new BGSprite('gore/stupidBlood', dancers[i].x - 110, dancers[i].y + 20, 0.4, 0.4, ['blood'], false);
									particle.flipX = true;
									particle.angle = -57.5;
									grpLimoParticles.add(particle);
								case 1:
									limoCorpse.visible = true;
								case 2:
									limoCorpseTwo.visible = true;
							}
							dancers[i].x += FlxG.width * 2;
						}
					}

					if (limoMetalPole.x > FlxG.width * 2) {
						resetLimoKill();
						limoSpeed = 800;
						limoKillingState = 2; // SPEEDING_OFFSCREEN
					}

				case 2: // SPEEDING_OFFSCREEN
					limoSpeed -= 4000 * elapsed;
					bgLimo.x -= limoSpeed * elapsed;
					if (bgLimo.x > FlxG.width * 1.5) {
						limoSpeed = 3000;
						limoKillingState = 3; // SPEEDING
					}

				case 3: // SPEEDING
					limoSpeed -= 2000 * elapsed;
					if (limoSpeed < 1000) limoSpeed = 1000;

					bgLimo.x -= limoSpeed * elapsed;
					if (bgLimo.x < -275) {
						limoKillingState = 4; // STOPPING
						limoSpeed = 800;
					}
					dancersParenting();

				case 4: // STOPPING
					bgLimo.x = FlxMath.lerp(bgLimo.x, -200, FlxMath.bound(elapsed * 9, 0, 1));
					if (Math.round(bgLimo.x) == -200) {
						bgLimo.x = -200;
						limoKillingState = 0; // WAIT
					}
					dancersParenting();

				default: // 0: WAIT
					// nothing
			}
		}
	}

	function dancersParenting()
	{
		if (grpLimoDancers != null && bgLimo != null) {
			var dancers:Array<BackgroundDancer> = grpLimoDancers.members;
			for (i in 0...dancers.length) {
				dancers[i].x = (370 * i) + dancersDiff + bgLimo.x;
			}
		}
	}

	override function beatHit()
	{
		if (!ClientPrefs.data.lowQuality) {
			grpLimoDancers.forEach(function(dancer:BackgroundDancer) {
				dancer.dance();
			});

			if (FlxG.random.bool(10) && curBeat > (shootingStarBeat + shootingStarOffset)) {
				doShootingStar(curBeat);
			}
		}

		if (FlxG.random.bool(10) && fastCarCanDrive) {
			fastCarDrive();
		}
	}
	
	override function closeSubState()
	{
		if (paused) {
			if (carTimer != null) carTimer.active = true;
		}
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		if (paused) {
			if (carTimer != null) carTimer.active = false;
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch (eventName) {
			case "Kill Henchmen":
				killHenchmen();
		}
	}

	function resetLimoKill():Void
	{
		limoMetalPole.x = -500;
		limoMetalPole.visible = false;
		limoLight.x = -500;
		limoLight.visible = false;
		limoCorpse.x = -500;
		limoCorpse.visible = false;
		limoCorpseTwo.x = -500;
		limoCorpseTwo.visible = false;
	}

	function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	function fastCarDrive()
	{
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = FlxG.random.int(30600, 39600);
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer) {
			resetFastCar();
			carTimer = null;
		});
	}

	function doShootingStar(beat:Int):Void
	{
		shootingStar.x = FlxG.random.int(50, 900);
		shootingStar.y = FlxG.random.int(-10, 20);
		shootingStar.flipX = FlxG.random.bool(50);
		shootingStar.animation.play('shooting star', true);
		shootingStar.visible = true;

		shootingStarBeat = beat;
		shootingStarOffset = FlxG.random.int(4, 8);

		new FlxTimer().start(1, function(tmr:FlxTimer) {
			shootingStar.visible = false;
		});
	}

	function killHenchmen():Void
	{
		if (!ClientPrefs.data.lowQuality) {
			if (limoKillingState == 0) { // WAIT
				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpseTwo.visible = false;
				limoKillingState = 1; // KILLING

				#if ACHIEVEMENTS_ALLOWED
				Achievements.addScore("roadkill_enthusiast");
				#end
			}
		}
	}
}