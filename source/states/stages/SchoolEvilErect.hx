package states.stages;

import states.stages.objects.*;
import substates.GameOverSubstate;
import cutscenes.DialogueBox;
import openfl.utils.Assets as OpenFlAssets;
import flixel.addons.effects.FlxTrail;
import shaders.DropShadowShader;
import shaders.WiggleEffect;
import objects.Character;

class SchoolEvilErect extends BaseStage
{
	// 背景精灵
	var schoolBuildingEvil:BGSprite;
	var bgGhouls:BGSprite;
	
	// 拖尾效果
	var trail:FlxTrail;
	
	// 着色器
	var wiggleEffect:WiggleEffect;
	var bfShader:DropShadowShader;
	var dadShader:DropShadowShader;
	var gfShader:DropShadowShader;
	
	// 计时器
	var elapsedTime:Float = 0;
	
	override function create()
	{
		var _song = PlayState.SONG;
		if(_song.gameOverSound == null || _song.gameOverSound.trim().length < 1) 
			GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		if(_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1) 
			GameOverSubstate.loopSoundName = 'gameOver-pixel';
		if(_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1) 
			GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		if(_song.gameOverChar == null || _song.gameOverChar.trim().length < 1) 
			GameOverSubstate.characterName = 'bf-pixel-dead';
		
		// 创建邪恶学校背景
		schoolBuildingEvil = new BGSprite('weeb/erect/evilSchoolBG', -275, -20);
		schoolBuildingEvil.scrollFactor.set(0.8, 0.9);
		schoolBuildingEvil.scale.set(6, 6);
		schoolBuildingEvil.updateHitbox();
		schoolBuildingEvil.antialiasing = false;
		add(schoolBuildingEvil);
		
		// 设置默认女友角色
		setDefaultGF('gf-pixel');

		// 播放恐怖版午餐盒音乐
		FlxG.sound.playMusic(Paths.music('LunchboxScary'), 0);
		FlxG.sound.music.fadeIn(1, 0, 0.8);
		if(isStoryMode && !seenCutscene)
		{
			initDoof();
			setStartCallback(schoolIntro);
		}
	}
	
	override function createPost()
	{
		// 为对手添加拖尾效果
		if(!ClientPrefs.data.lowQuality && dad != null) {
			trail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
			addBehindDad(trail);
		}
		
		// 应用角色着色器
		if(ClientPrefs.data.shaders)
		{
			applyCharacterShaders();
		}
		
		// 应用wiggle效果到背景（高质量模式）
		if(ClientPrefs.data.shaders && !ClientPrefs.data.lowQuality && schoolBuildingEvil != null)
		{
			wiggleEffect = new WiggleEffect();
			wiggleEffect.effectType = DREAMY;
			wiggleEffect.waveSpeed = 2.0;
			wiggleEffect.waveFrequency = 4.0;
			wiggleEffect.waveAmplitude = 0.017;
			schoolBuildingEvil.shader = wiggleEffect.shader;
		}
	}
	
	function applyCharacterShaders()
	{
		// 为boyfriend应用着色器
		if(boyfriend != null)
		{
			bfShader = new DropShadowShader();
			setupEvilSchoolShader(bfShader, 'boyfriend');
			boyfriend.shader = bfShader;
			setupShaderFrameCallback(boyfriend, bfShader);
		}
		
		// 为dad应用着色器
		if(dad != null)
		{
			dadShader = new DropShadowShader();
			setupEvilSchoolShader(dadShader, 'dad');
			
			// DAD特殊处理
			dadShader.ang.value = [Math.PI * 105 / 180]; // 105度
			dadShader.str.value = [0.34];
			dadShader.dist.value = [3.0];
			
			dad.shader = dadShader;
			setupShaderFrameCallback(dad, dadShader);
		}
		
		// 为gf应用着色器
		if(gf != null)
		{
			gfShader = new DropShadowShader();
			setupEvilSchoolShader(gfShader, 'gf');
			
			// GF像素特殊处理
			if(gf.curCharacter == 'gf-pixel')
			{
				gfShader.hue.value = [-28.0];
				gfShader.saturation.value = [-20.0];
				gfShader.contrast.value = [11.0];
				gfShader.brightness.value = [-42.0];
				gfShader.dist.value = [3.0];
				gfShader.thr.value = [0.3];
			}
			
			// GF角度特殊处理
			gfShader.ang.value = [Math.PI * 90 / 180]; // 90度
			
			gf.shader = gfShader;
			setupShaderFrameCallback(gf, gfShader);
		}
	}
	
	function setupEvilSchoolShader(shader:DropShadowShader, type:String)
	{
		// 根据Lua版本设置邪恶学校版本的参数
		shader.hue.value = [-28.0];
		shader.saturation.value = [-20.0];
		shader.contrast.value = [31.0];
		shader.brightness.value = [-66.0];
		
		// dropShadow 基础参数
		shader.ang.value = [Math.PI * 120 / 180]; // 120度
		shader.str.value = [1.0];
		shader.dist.value = [4.0];
		shader.thr.value = [0.1];
		
		// 其他参数
		shader.AA_STAGES.value = [0.0];
		shader.dropColor.value = [82/255, 29/255, 75/255]; // RGB: 82, 29, 75
		shader.angOffset.value = [0.0];
		
		// 检查并设置遮罩
		var char = type == 'boyfriend' ? boyfriend : (type == 'dad' ? dad : gf);
		if(char != null)
		{
			var imageFile = char.imageFile;
			if(imageFile != null)
			{
				var imageName = imageFile.split('/').pop();
				var maskPath = 'images/characters/masks/${imageName}_mask.png';
				if(Paths.fileExists(maskPath, IMAGE))
				{
					shader.useMask.value = [true];
					shader.thr2.value = [1.0];
				}
				else
				{
					shader.useMask.value = [false];
				}
			}
		}
	}
	
	function setupShaderFrameCallback(char:Character, shader:DropShadowShader)
	{
		char.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
		{
			if(char.frame != null && char.frame.uv != null)
			{
				shader.uFrameBounds.value = [
					char.frame.uv.x,
					char.frame.uv.y,
					char.frame.uv.width,
					char.frame.uv.height
				];
				shader.angOffset.value = [char.frame.angle * Math.PI / 180];
			}
		};
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// 更新wiggle效果时间
		if(wiggleEffect != null)
		{
			elapsedTime += elapsed;
			wiggleEffect.setValue(elapsedTime);
		}
	}

	// 鬼魂事件
	override function eventPushed(event:objects.Note.EventNote)
	{
		switch(event.event)
		{
			case "Trigger BG Ghouls":
				if(!ClientPrefs.data.lowQuality && bgGhouls == null)
				{
					bgGhouls = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
					bgGhouls.scale.set(6, 6);
					bgGhouls.updateHitbox();
					bgGhouls.visible = false;
					bgGhouls.antialiasing = false;
					bgGhouls.animation.finishCallback = function(name:String)
					{
						if(name == 'BG freaks glitch instance')
							bgGhouls.visible = false;
					}
					addBehindGF(bgGhouls);
				}
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Trigger BG Ghouls":
				if(!ClientPrefs.data.lowQuality && bgGhouls != null)
				{
					bgGhouls.dance(true);
					bgGhouls.visible = true;
				}
		}
	}

	var doof:DialogueBox = null;
	function initDoof()
	{
		var file:String = Paths.txt('$songName/${songName}Dialogue_${ClientPrefs.data.language}');
		#if MODS_ALLOWED
		if (!FileSystem.exists(file))
		#else
		if (!OpenFlAssets.exists(file))
		#end
		{
			file = Paths.txt('$songName/${songName}Dialogue');
		}

		#if MODS_ALLOWED
		if (!FileSystem.exists(file))
		#else
		if (!OpenFlAssets.exists(file))
		#end
		{
			startCountdown();
			return;
		}

		doof = new DialogueBox(false, CoolUtil.coolTextFile(file));
		doof.cameras = [camHUD];
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = PlayState.instance.startNextDialogue;
		doof.skipDialogueThing = PlayState.instance.skipDialogue;
	}
	
	function schoolIntro():Void
	{
		inCutscene = true;
		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();
		add(red);

		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.getSparrowAtlas('weeb/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();
		senpaiEvil.x += 300;
		camHUD.visible = false;

		new FlxTimer().start(2.1, function(tmr:FlxTimer)
		{
			if (doof != null)
			{
				add(senpaiEvil);
				senpaiEvil.alpha = 0;
				new FlxTimer().start(0.3, function(swagTimer:FlxTimer)
				{
					senpaiEvil.alpha += 0.15;
					if (senpaiEvil.alpha < 1)
					{
						swagTimer.reset();
					}
					else
					{
						senpaiEvil.animation.play('idle');
						FlxG.sound.play(Paths.sound('Senpai_Dies'), 1, false, null, true, function()
						{
							remove(senpaiEvil);
							senpaiEvil.destroy();
							remove(red);
							red.destroy();
							FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
							{
								add(doof);
								camHUD.visible = true;
							}, true);
						});
						new FlxTimer().start(3.2, function(deadTime:FlxTimer)
						{
							FlxG.camera.fade(FlxColor.WHITE, 1.6, false);
						});
					}
				});
			}
		});
	}
}