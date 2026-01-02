package states.stages;

import states.stages.objects.*;
import substates.GameOverSubstate;
import cutscenes.DialogueBox;
import openfl.utils.Assets as OpenFlAssets;
import shaders.DropShadowShader;
import shaders.AdjustColorEffect;
import objects.Character;

class SchoolErect extends BaseStage
{
	// 背景精灵
	var bgSky:BGSprite;
	var treesBackground:BGSprite;
	var schoolBuilding:BGSprite;
	var schoolStreet:BGSprite;
	var treesBack:BGSprite;
	var trees:FlxSprite;
	var fallingPetals:BGSprite;
	
	// 角色着色器
	var bfShader:DropShadowShader;
	var dadShader:DropShadowShader;
	var gfShader:DropShadowShader;
	
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

		// 创建背景天空
		bgSky = new BGSprite('weeb/erect/weebSky', -164, -78);
		bgSky.scrollFactor.set(0.2, 0.2);
		bgSky.scale.set(6, 6);
		bgSky.updateHitbox();
		add(bgSky);
		bgSky.antialiasing = false;

		// 创建背景树木
		treesBackground = new BGSprite('weeb/erect/weebBackTrees', -242, -80);
		treesBackground.scrollFactor.set(0.5, 0.5);
		treesBackground.scale.set(6, 6);
		treesBackground.updateHitbox();
		add(treesBackground);
		treesBackground.antialiasing = false;

		// 创建学校建筑
		schoolBuilding = new BGSprite('weeb/erect/weebSchool', -216, -38);
		schoolBuilding.scrollFactor.set(0.75, 0.75);
		schoolBuilding.scale.set(6, 6);
		schoolBuilding.updateHitbox();
		add(schoolBuilding);
		schoolBuilding.antialiasing = false;

		// 创建街道
		schoolStreet = new BGSprite('weeb/erect/weebStreet', -200, 6);
		schoolStreet.scale.set(6, 6);
		schoolStreet.updateHitbox();
		add(schoolStreet);
		schoolStreet.antialiasing = false;

		// 创建前景树木（低质量模式下不显示）
		if(!ClientPrefs.data.lowQuality) {
			treesBack = new BGSprite('weeb/erect/weebTreesBack', -200, 6);
			treesBack.scale.set(6, 6);
			treesBack.updateHitbox();
			add(treesBack);
			treesBack.antialiasing = false;
		}

		// 创建动画树木
		trees = new FlxSprite(-806, -1050);
		trees.frames = Paths.getPackerAtlas('weeb/erect/weebTrees');
		trees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
		trees.animation.play('treeLoop');
		trees.scrollFactor.set(0.85, 0.85);
		trees.scale.set(6, 6);
		trees.updateHitbox();
		trees.antialiasing = false;
		addBehindGF(trees);

		// 创建花瓣动画（低质量模式下不显示）
		if(!ClientPrefs.data.lowQuality) {
			fallingPetals = new BGSprite('weeb/erect/petals', -20, -40, 0.85, 0.85, ['PETALS ALL'], true);
			fallingPetals.scale.set(6, 6);
			fallingPetals.updateHitbox();
			fallingPetals.antialiasing = false;
			addBehindGF(fallingPetals);
		}

		// 设置默认女友角色
		setDefaultGF('gf-pixel');

		// 根据歌曲设置音乐
		switch(songName.toLowerCase()) {
			case 'senpai':
				FlxG.sound.playMusic(Paths.music('Lunchbox'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
			case 'roses':
				FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));
		}
		if(isStoryMode && !seenCutscene)
		{
			if(songName.toLowerCase() == 'roses') FlxG.sound.play(Paths.sound('ANGRY'));
			initDoof();
			setStartCallback(schoolIntro);
		}
	}
	
	override function createPost()
	{
		// 为角色应用着色器
		if(ClientPrefs.data.shaders)
		{
			applyCharacterShaders();
		}
	}
	
	function applyCharacterShaders()
	{
		// 为boyfriend应用着色器
		if(boyfriend != null)
		{
			bfShader = new DropShadowShader();
			setupNormalSchoolShader(bfShader, 'boyfriend');
			boyfriend.shader = bfShader;
			setupShaderFrameCallback(boyfriend, bfShader);
		}
		
		// 为dad应用着色器
		if(dad != null)
		{
			dadShader = new DropShadowShader();
			setupNormalSchoolShader(dadShader, 'dad');
			dad.shader = dadShader;
			setupShaderFrameCallback(dad, dadShader);
		}
		
		// 为gf应用着色器
		if(gf != null)
		{
			gfShader = new DropShadowShader();
			setupNormalSchoolShader(gfShader, 'gf');
			
			// GF像素特殊处理
			if(gf.curCharacter == 'gf-pixel')
			{
				gfShader.hue.value = [-10.0];
				gfShader.saturation.value = [-25.0];
				gfShader.contrast.value = [5.0];
				gfShader.brightness.value = [-42.0];
				gfShader.dist.value = [3.0];
				gfShader.thr.value = [0.3];
			}
			
			gf.shader = gfShader;
			setupShaderFrameCallback(gf, gfShader);
		}
	}
	
	function setupNormalSchoolShader(shader:DropShadowShader, type:String)
	{
		// 根据Lua版本设置普通学校版本的参数
		shader.hue.value = [-10.0];
		shader.saturation.value = [-23.0];
		shader.contrast.value = [24.0];
		shader.brightness.value = [-66.0];
		
		// dropShadow 参数
		shader.ang.value = [Math.PI * 90 / 180]; // 90度
		shader.str.value = [1.0];
		shader.dist.value = [5.0];
		shader.thr.value = [0.1];
		
		// 其他参数
		shader.AA_STAGES.value = [0.0];
		shader.dropColor.value = [82/255, 53/255, 29/255]; // RGB: 82, 53, 29
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

	override function beatHit()
	{
		super.beatHit();
		if(trees != null && trees.animation != null) {
			trees.animation.play('treeLoop', true);
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
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		if(songName.toLowerCase() == 'senpai') add(black);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;

			if (black.alpha > 0)
			{
				tmr.reset(0.3);
			}
			else
			{
				if (doof != null)
				{
					add(doof);
				}
				else
				{
					startCountdown();
				}

				remove(black);
				black.destroy();
			}
		});
	}
}