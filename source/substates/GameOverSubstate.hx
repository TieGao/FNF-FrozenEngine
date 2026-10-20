package substates;

import objects.Character;
import flixel.FlxObject;
import flixel.math.FlxPoint;

import states.StoryMenuState;
import states.OldFreeplayState;
import states.FreeplayState;

class GameOverSubstate extends MusicBeatSubstate
{
	public var boyfriend:Character;
	var camFollow:FlxObject;

	var stagePostfix:String = "";

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	public static var deathDelay:Float = 0;

	/**
	 * 死亡镜头微调（像素）：正数 = 镜头往右 / 往下移。
	 * 角色的 camera_position 已经按 PlayState.moveCamera 的约定算进去了，这里只做最后的目测微调。
	 */
	public static var deathCamOffsetX:Float = 0;
	public static var deathCamOffsetY:Float = 0;

	/** nene 扔刀相对 gf 的落点（像素，官方 pico-playable.hxc 用 gf.originalPosition + [120, 0]） */
	public static var neneKnifeOffset:Array<Float> = [120, 0];

	public static var instance:GameOverSubstate;
	public function new(?playStateBoyfriend:Character = null)
	{
		if(playStateBoyfriend != null && playStateBoyfriend.curCharacter == characterName) //Avoids spawning a second boyfriend cuz animate atlas is laggy
		{
			this.boyfriend = playStateBoyfriend;
		}
		super();
	}

	public static function resetVariables() {
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		deathDelay = 0;

		var _song = PlayState.SONG;
		if(_song != null)
		{
			if(_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) characterName = _song.gameOverChar;
			if(_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) deathSoundName = _song.gameOverSound;
			if(_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0) loopSoundName = _song.gameOverLoop;
			if(_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0) endSoundName = _song.gameOverEnd;
		}
	}

	var charX:Float = 0;
	var charY:Float = 0;

	var overlay:FlxSprite;
	var overlayConfirmOffsets:FlxPoint = FlxPoint.get();
	override function create()
	{
		instance = this;

		Conductor.songPosition = 0;

		if(boyfriend == null)
		{
			boyfriend = new Character(PlayState.instance.boyfriend.getViewPosition().x, PlayState.instance.boyfriend.getViewPosition().y, characterName, true);
			boyfriend.x += boyfriend.positionArray[0] - PlayState.instance.boyfriend.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1] - PlayState.instance.boyfriend.positionArray[1];
		}
		boyfriend.skipDance = true;
		add(boyfriend);

		FlxG.sound.play(Paths.sound(deathSoundName));
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		boyfriend.playAnim('firstDeath');

		camFollow = new FlxObject(0, 0, 1, 1);
		// 与 PlayState.moveCamera 保持同一套符号：camera_position.x 是**减**。
		// （Psych 原版这里写成加；pico 的 camera_position 是负值，加完镜头整体偏左，PicoMix 死亡时特别明显）
		var camOff:Array<Float> = boyfriend.cameraPosition != null ? boyfriend.cameraPosition : [0, 0];
		camFollow.setPosition(boyfriend.getGraphicMidpoint().x - camOff[0] + deathCamOffsetX,
			boyfriend.getGraphicMidpoint().y + camOff[1] + deathCamOffsetY);
		FlxG.camera.focusOn(new FlxPoint(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2)));
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
		add(camFollow);
		
		PlayState.instance.setOnScripts('inGameOver', true);
		PlayState.instance.callOnScripts('onGameOverStart', []);
		FlxG.sound.music.load(Paths.music(loopSoundName), true);

		if(characterName == 'pico-dead')
		{
			overlay = new FlxSprite(boyfriend.x + 205, boyfriend.y - 80);
			overlay.frames = Paths.getSparrowAtlas('Pico_Death_Retry');
			overlay.animation.addByPrefix('deathLoop', 'Retry Text Loop', 24, true);
			overlay.animation.addByPrefix('deathConfirm', 'Retry Text Confirm', 24, false);
			overlay.antialiasing = ClientPrefs.data.antialiasing;
			overlayConfirmOffsets.set(250, 200);
			overlay.visible = false;
			add(overlay);

			boyfriend.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
			{
				switch(name)
				{
					case 'firstDeath':
						if(frameNumber >= 36 - 1)
						{
							overlay.visible = true;
							overlay.animation.play('deathLoop');
							boyfriend.animation.callback = null;
						}
					default:
						boyfriend.animation.callback = null;
				}
			}

			if(PlayState.instance.gf != null && PlayState.instance.gf.curCharacter == 'nene')
				spawnNeneKnife(boyfriend.x - 450, boyfriend.y - 250);
		}
		// PicoMix：官方 pico-playable.hxc（PicoPlayerBaseCharacter）在 firstDeath 时无条件生成 NeneKnifeToss，
		// 所以 pico-playable / pico-christmas / pico-dark 的死亡都该有 nene 扔刀。
		// pico-pixel 和 pico-holding-nene 是另一套基类，官方没有这段，这里跟着不放。
		else if(isPicoPlayerDeath(characterName) && PlayState.instance.gf != null)
		{
			spawnNeneKnife(PlayState.instance.gf.x + neneKnifeOffset[0], PlayState.instance.gf.y + neneKnifeOffset[1]);
		}

		super.create();
	}

	/** 官方 PicoPlayerBaseCharacter 派生的死亡角色（这几个才有 nene 扔刀） */
	inline static function isPicoPlayerDeath(char:String):Bool
		return char == 'pico-playable' || char == 'pico-christmas' || char == 'pico-dark';

	/** nene 扔刀（官方 NeneKnifeToss，播完自己移除） */
	function spawnNeneKnife(x:Float, y:Float):Void
	{
		var neneKnife:FlxSprite = new FlxSprite(x, y);
		neneKnife.frames = Paths.getSparrowAtlas('NeneKnifeToss');
		neneKnife.animation.addByPrefix('anim', 'knife toss', 24, false);
		neneKnife.antialiasing = ClientPrefs.data.antialiasing;
		neneKnife.animation.finishCallback = function(_)
		{
			remove(neneKnife);
		}
		insert(0, neneKnife);
		neneKnife.animation.play('anim', true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		var justPlayedLoop:Bool = false;
		if (!boyfriend.isAnimationNull() && boyfriend.getAnimationName() == 'firstDeath' && boyfriend.isAnimationFinished())
		{
			boyfriend.playAnim('deathLoop');
			if(overlay != null && overlay.animation.exists('deathLoop'))
			{
				overlay.visible = true;
				overlay.animation.play('deathLoop');
			}
			justPlayedLoop = true;
		}

		if(!isEnding)
		{
			if (controls.ACCEPT)
			{
			endBullshit();
			}
			else if (controls.BACK || FlxG.mouse.justPressedRight)
			{
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
				FlxG.camera.visible = false;
				FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = false;
				PlayState.chartingMode = false;
	
				Mods.loadTopMod();
				if (PlayState.isStoryMode)
					MusicBeatState.switchState(new StoryMenuState());
				else if (!ClientPrefs.data.oldFreeplay)
					MusicBeatState.switchState(new FreeplayState());
				else
					MusicBeatState.switchState(new OldFreeplayState());

				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
			}
			else if (justPlayedLoop)
			{
				switch(PlayState.SONG.stage)
				{
					case 'tank' | 'tank-erect':
						coolStartDeath(0.2);

						var exclude:Array<Int> = [];
						//if(!ClientPrefs.cursing) exclude = [1, 3, 8, 13, 17, 21];

						// Pico Mix 变体用 pico 版台词组（官方 jeffGameover-pico，10 条）
						if (Paths.currentContentVariant == 'pico')
						{
							FlxG.sound.play(Paths.sound('jeffGameover-pico/jeffGameover-' + FlxG.random.int(1, 10, exclude)), 1, false, null, true, function() {
								if(!isEnding)
								{
									FlxG.sound.music.fadeIn(0.2, 1, 4);
								}
							});
						}
						else
						{
							FlxG.sound.play(Paths.sound('jeffGameover/jeffGameover-' + FlxG.random.int(1, 25, exclude)), 1, false, null, true, function() {
								if(!isEnding)
								{
									FlxG.sound.music.fadeIn(0.2, 1, 4);
								}
							});
						}

					default:
						coolStartDeath();
				}
			}
			
			if (FlxG.sound.music.playing)
			{
				Conductor.songPosition = FlxG.sound.music.time;
			}
		}
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	var isEnding:Bool = false;
	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = volume;
	}

	function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;
			if(boyfriend.hasAnimation('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);
			else if(boyfriend.hasAnimation('deathLoop'))
				boyfriend.playAnim('deathLoop', true);

			if(overlay != null && overlay.animation.exists('deathConfirm'))
			{
				overlay.visible = true;
				overlay.animation.play('deathConfirm');
				overlay.offset.set(overlayConfirmOffsets.x, overlayConfirmOffsets.y);
			}
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.music(endSoundName));
			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					MusicBeatState.resetState();
				});
			});
			PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
