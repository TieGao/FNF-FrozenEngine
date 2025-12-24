// FranksSpiritsBowling.hx - 完整实现
package states.stages;

import states.stages.objects.TankmenBG;
import objects.Character;
import openfl.media.Sound;
import shaders.AdjustColorEffect;

class FranksSpiritsBowling extends BaseStage
{
	// 背景元素
	var bg:BGSprite;
	var guy:BGSprite;
	var sniper:BGSprite;
	var dancers:Array<BGSprite> = [];
	
	// 坦克人相关
	var tankmanRun:FlxTypedGroup<TankmenBG>;
	
	// 结束动画
	var tankmanEnd:FlxAnimate;
	var stressEndAudio:Sound;
	
	// 狙击手状态
	var sniperSpecialAnim:Bool = false;

	override function create()
	{
		// 酒吧背景
		bg = new BGSprite('erect/bg', -985, -805);
		bg.setGraphicSize(Std.int(bg.width * 1.15));
		bg.updateHitbox();
		add(bg);

		// 坦克人
		guy = new BGSprite('erect/guy', 1398, 407, 1, 1, ['BLTank2 instance 1'], false);
		guy.setGraphicSize(Std.int(guy.width * 1.15));
		guy.updateHitbox();
		add(guy);
		dancers.push(guy);

		// 狙击手
		if (!ClientPrefs.data.lowQuality) {
			sniper = new BGSprite('erect/sniper', -127, 349, 1, 1, ['Tankmanidlebaked instance 1'], false);
			sniper.setGraphicSize(Std.int(sniper.width * 1.15));
			sniper.updateHitbox();
			sniper.animation.addByPrefix('sip', 'tanksippingBaked instance 1', 24, false);
			add(sniper);
			dancers.push(sniper);
		}

		// 坦克人奔跑组
		tankmanRun = new FlxTypedGroup<TankmenBG>();
		add(tankmanRun);
		
		// 预加载死亡音效
	}

	override function createPost()
	{
		// 应用着色器效果
		if (ClientPrefs.data.shaders) {
			applyColorAdjustmentToCharacters();
		}
		
		// 检查是否需要坦克人事件
		if (songName == 'stress' || songName == 'stress-pico') {
			prepareStressEnding();
		}
		
		// 添加坦克人奔跑动画
		if (!ClientPrefs.data.lowQuality) {
			addTankmenRunning();
		}
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
				
				// 基础设置
				effect.setValues(-38, -20, -46, -25); // hue: -38, saturation: -20, brightness: -46, contrast: -25
				
				// GF坦克特殊处理
				if (char == gf && gf.curCharacter == 'gf-tankmen') {
					// thr2: 0.4（这个是 DropShadow 参数，不是 AdjustColor）
					// AdjustColor 保持相同
				}
				
				char.shader = effect.shader;
			}
		}
	}

	function prepareStressEnding()
	{
		tankmanEnd = new FlxAnimate(778, 513);
		tankmanEnd.antialiasing = ClientPrefs.data.antialiasing;
		Paths.loadAnimateAtlas(tankmanEnd, 'erect/cutscene/tankmanEnding');
		tankmanEnd.anim.addBySymbol('scene', 'tankman stress ending', 24, false);
		
		stressEndAudio = Paths.sound('erect/endCutscene');
		
		if (songName == 'stress-pico' && !seenCutscene) {
			setStartCallback(() -> {
				game.startVideo('stressPicoCutscene');
				inCutscene = true;
				canPause = true;
			});
		}
		
		setEndCallback(stressEndCutscene);
	}

	function addTankmenRunning()
	{
		for (daGf in gfGroup) {
			if (Std.isOfType(daGf, Character)) {
				var gf:Character = cast daGf;
				if (gf.curCharacter.endsWith('-speaker')) {
					// 添加第一个坦克人
					var firstTank:TankmenBG = new TankmenBG(20, 500, true);
					firstTank.resetShit(20, 600, true);
					firstTank.strumTime = 10;
					firstTank.visible = false;
					tankmanRun.add(firstTank);
					
					// 添加其他坦克人
					for (i in 0...TankmenBG.animationNotes.length) {
						if (FlxG.random.bool(20)) {
							var tankBih = tankmanRun.recycle(TankmenBG);
							tankBih.strumTime = TankmenBG.animationNotes[i][0];
							tankBih.resetShit(500, 320, TankmenBG.animationNotes[i][1] < 2);
							tankBih.scale.set(1.1, 1.1);
							tankBih.updateHitbox();
							tankmanRun.add(tankBih);
						}
					}
					break;
				}
			}
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// 更新坦克人奔跑
		if (tankmanRun != null) {
			tankmanRun.forEach(function(tank:TankmenBG) {
				tank.update(elapsed);
			});
		}
	}

	override function countdownTick(count:Countdown, num:Int)
	{
		// 每两拍触发一次动画
		if (num % 2 == 0) {
			if (!ClientPrefs.data.lowQuality && sniper != null) {
				if (FlxG.random.bool(2) && !sniperSpecialAnim) {
					sniper.animation.play('sip', true);
					sniperSpecialAnim = true;
					
					var animLength = sniper.animation.curAnim.numFrames / 24;
					new FlxTimer().start(animLength, function(tmr:FlxTimer) {
						sniperSpecialAnim = false;
					});
				}
				
				if (!sniperSpecialAnim) {
					sniper.animation.play('Tankmanidlebaked instance 1', true);
				}
			}
			
			if (guy != null) {
				guy.animation.play('BLTank2 instance 1', true);
			}
		}
	}

	override function beatHit()
	{
		// 每两拍触发一次动画
		if (curBeat % 2 == 0) {
			if (!ClientPrefs.data.lowQuality && sniper != null) {
				if (FlxG.random.bool(2) && !sniperSpecialAnim) {
					sniper.animation.play('sip', true);
					sniperSpecialAnim = true;
					
					var animLength = sniper.animation.curAnim.numFrames / 24;
					new FlxTimer().start(animLength, function(tmr:FlxTimer) {
						sniperSpecialAnim = false;
					});
				}
				
				if (!sniperSpecialAnim) {
					sniper.animation.play('Tankmanidlebaked instance 1', true);
				}
			}
			
			if (guy != null) {
				guy.animation.play('BLTank2 instance 1', true);
			}
		}
	}

	function stressEndCutscene()
	{
		inCutscene = true;
		game.canPause = false;
		game.canReset = false;

		FlxTween.tween(game.camHUD, {alpha: 0}, 1, {ease: FlxEase.quadIn});
		
		game.tweenCameraZoom(0.65, 2, true, FlxEase.expoOut);
		game.moveCamera(true, false, 270, -70);
		game.tweenCameraToFollowPoint(2.8, FlxEase.expoOut);

		FlxG.sound.play(stressEndAudio);

		game.dad.visible = false;
		tankmanEnd.anim.play('scene');
		add(tankmanEnd);

		var bgSprite = new FlxSprite(0, 0);
		bgSprite.makeGraphic(2000, 2500, 0xFF000000);
		bgSprite.cameras = [PlayState.instance.camOther];
		bgSprite.alpha = 0;
		add(bgSprite);

		new FlxTimer().start(176 / 24, _ -> {
			game.boyfriend.playAnim('laughEnd', true);
		});

		new FlxTimer().start(270 / 24, _ -> {
			game.tweenCameraToPosition(camFollow.x, camFollow.y - 370, 2, FlxEase.quadInOut);
			FlxTween.tween(bgSprite, {alpha: 1}, 2, null);
			if (sniper != null) {
				sniper.animation.play('sip', true);
			}
		});

		new FlxTimer().start(320 / 24, _ -> {
			endSong();
		});
	}
	
	// 游戏结束音效处理（需要在实际的 GameOverSubstate 中实现）
}