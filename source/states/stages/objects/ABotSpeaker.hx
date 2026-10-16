package states.stages.objects;

#if funkin.vis
import funkin.vis.dsp.SpectralAnalyzer;
#end

/**
 * ABot 音响（Nene 的音响 + 音浪频谱 + 眼动）。
 * 带 `?addDarkSprite`（spooky 周暗色形态）与 `?isPixel`（像素周 abotPixel 形态）两个可选参数，
 * 参照 Funkin-Psych-Online 的同名类；不传时行为与旧版完全一致（PhillyStreets / PhillyBlazin 继续可用）。
 */
class ABotSpeaker extends FlxSpriteGroup
{
	final VIZ_MAX = 7; // ranges from viz1 to viz7
	final VIZ_POS_X:Array<Float> = [0, 59, 56, 66, 54, 52, 51];
	final VIZ_POS_Y:Array<Float> = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];

	public var bg:FlxSprite;
	public var vizSprites:Array<FlxSprite> = [];
	public var eyeBg:FlxSprite;
	public var eyes:FlxAnimate;
	public var darkSpeaker:FlxAnimate;
	public var speaker:FlxAnimate;
	public var eyesPixel:FlxSprite;
	public var speakerPixel:FlxSprite;

	#if funkin.vis
	var analyzer:SpectralAnalyzer;
	#end
	var volumes:Array<Float> = [];

	public var snd(default, set):FlxSound;
	function set_snd(changed:FlxSound)
	{
		snd = changed;
		#if funkin.vis
		initAnalyzer();
		#end
		return snd;
	}

	public function new(x:Float = 0, y:Float = 0, ?addDarkSprite:Bool = false, ?isPixel:Bool = false)
	{
		super(x, y);

		var antialias = ClientPrefs.data.antialiasing && !isPixel;

		if (!isPixel)
		{
			bg = new FlxSprite(90, 20).loadGraphic(Paths.image('abot/stereoBG'));
			bg.antialiasing = antialias;
			add(bg);
		}
		else
		{
			bg = new FlxSprite(-71, -195).loadGraphic(Paths.image('characters/abotPixel/aBotPixelBack'));
			bg.antialiasing = antialias;
			bg.scale.set(6, 6);
			bg.updateHitbox();
			add(bg);
		}

		// 像素柱间距与 HD 不同（PSO：像素数组本身已含 6 倍间距，普通数组不能乘 6 再累加）
		var vizPosX:Array<Float> = isPixel ? [0, 42, 48, 54, 60, 36, 42] : VIZ_POS_X;
		var vizPosY:Array<Float> = isPixel ? [0, -12, -6, 0, 0, 6, 12] : VIZ_POS_Y;
		var vizX:Float = 0;
		var vizY:Float = 0;
		var vizFrames = Paths.getSparrowAtlas(isPixel ? 'characters/abotPixel/aBotVizPixel' : 'abot/aBotViz');
		for (i in 1...VIZ_MAX+1)
		{
			volumes.push(0.0);
			vizX += vizPosX[i-1];
			vizY += vizPosY[i-1];
			var viz:FlxSprite = new FlxSprite(vizX + 140, vizY + 74);
			if (isPixel) viz.setPosition(vizX - 11, vizY - 136);
			viz.frames = vizFrames;
			viz.animation.addByPrefix('VIZ', 'viz$i', 0);
			viz.animation.play('VIZ', true);
			viz.animation.curAnim.finish(); //make it go to the lowest point
			viz.antialiasing = antialias;
			vizSprites.push(viz);
			if (isPixel)
			{
				viz.scale.set(6, 6);
			}
			viz.updateHitbox();
			viz.centerOffsets();
			add(viz);
		}

		if (!isPixel)
		{
			eyeBg = new FlxSprite(-30, 215).makeGraphic(1, 1, FlxColor.WHITE);
			eyeBg.scale.set(160, 60);
			eyeBg.updateHitbox();
			add(eyeBg);

			eyes = new FlxAnimate(-10, 230);
			Paths.loadAnimateAtlas(eyes, 'abot/systemEyes');
			eyes.anim.addBySymbolIndices('lookleft', 'a bot eyes lookin', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], 24, false);
			eyes.anim.addBySymbolIndices('lookright', 'a bot eyes lookin', [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35], 24, false);
			eyes.anim.play('lookright', true);
			eyes.anim.curFrame = eyes.anim.length - 1;
			eyes.antialiasing = antialias;
			add(eyes);
		}
		else
		{
			eyesPixel = new FlxSprite(-227, -131);
			eyesPixel.frames = Paths.getSparrowAtlas('characters/abotPixel/abotHead');
			eyesPixel.animation.addByPrefix('lookleft', 'toleft', 24, false);
			eyesPixel.animation.addByPrefix('lookright', 'toright', 24, false);
			eyesPixel.animation.play('lookleft', true);
			eyesPixel.antialiasing = antialias;
			eyesPixel.scale.set(6, 6);
			eyesPixel.updateHitbox();
			add(eyesPixel);
		}

		if (addDarkSprite)
		{
			darkSpeaker = new FlxAnimate(-65, -10);
			Paths.loadAnimateAtlas(darkSpeaker, 'abot/dark/abotSystem');
			darkSpeaker.anim.addBySymbol('anim', 'Abot System', 24, false);
			darkSpeaker.anim.play('anim', true);
			darkSpeaker.anim.curFrame = darkSpeaker.anim.length - 1;
			darkSpeaker.antialiasing = antialias;
			add(darkSpeaker);
		}

		if (!isPixel)
		{
			speaker = new FlxAnimate(-65, -10);
			Paths.loadAnimateAtlas(speaker, 'abot/abotSystem');
			speaker.anim.addBySymbol('anim', 'Abot System', 24, false);
			speaker.anim.play('anim', true);
			speaker.anim.curFrame = speaker.anim.length - 1;
			speaker.antialiasing = antialias;
			add(speaker);
		}
		else
		{
			speakerPixel = new FlxSprite(-228, -226);
			speakerPixel.frames = Paths.getSparrowAtlas('characters/abotPixel/aBotPixel');
			speakerPixel.animation.addByPrefix('idle', 'idle', 24, false);
			speakerPixel.animation.play('idle', true);
			speakerPixel.antialiasing = antialias;
			speakerPixel.scale.set(6, 6);
			speakerPixel.updateHitbox();
			add(speakerPixel);
		}
	}

	#if funkin.vis
	var levels:Array<Bar>;
	var levelMax:Int = 0;
	var prevBeat:Float = 0;
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// 没接频谱（snd 未设置）时也能跟着节拍蹦
		if (analyzer == null && FlxG.state == PlayState.instance)
		{
			var curBeat:Float = Conductor.getBeat(Conductor.songPosition);
			if (prevBeat != curBeat && curBeat % Math.round(PlayState.instance.gfSpeed) == 0)
			{
				beatHit();
				prevBeat = curBeat;
			}
			return;
		}
		if (analyzer == null) return;

		levels = analyzer.getLevels(levels);
		var oldLevelMax = levelMax;
		levelMax = 0;
		for (i in 0...Std.int(Math.min(vizSprites.length, levels.length)))
		{
			var animFrame:Int = Math.round(levels[i].value * 5);
			animFrame = Std.int(Math.abs(FlxMath.bound(animFrame, 0, 5) - 5)); // shitty dumbass flip, cuz dave got da shit backwards lol!

			vizSprites[i].animation.curAnim.curFrame = animFrame;
			levelMax = Std.int(Math.max(levelMax, 5 - animFrame));
		}

		if(levelMax >= 4)
		{
			//trace(levelMax);
			if(oldLevelMax <= levelMax && (levelMax >= 5 || getCurSpeakerFrame() >= 3))
				beatHit();
		}
	}
	#end

	function getCurSpeakerFrame():Int
	{
		if (speaker != null) return speaker.anim.curFrame;
		if (speakerPixel != null && speakerPixel.animation.curAnim != null) return speakerPixel.animation.curAnim.curFrame;
		return 0;
	}

	public function beatHit()
	{
		if (speaker != null) speaker.anim.play('anim', true);
		if (speakerPixel != null) speakerPixel.animation.play('idle', true);
		if (darkSpeaker != null) darkSpeaker.anim.play('anim', true);
	}

	#if funkin.vis
	public function initAnalyzer()
	{
		@:privateAccess
		analyzer = new SpectralAnalyzer(snd._channel.__audioSource, VIZ_MAX, 0.1, 40);

		// A-Bot tuning (PSO)：
		analyzer.minDb = -65;
		analyzer.maxDb = -25;
		analyzer.maxFreq = 22000;
		analyzer.minFreq = 10;

		#if desktop
		// On desktop it uses FFT stuff that isn't as optimized as the direct browser stuff we use on HTML5
		// So we want to manually change it!
		analyzer.fftN = 256;
		#end
	}
	#end

	var lookingAtRight:Bool = true;
	public function lookLeft()
	{
		if(lookingAtRight)
		{
			if (eyes != null) eyes.anim.play('lookleft', true);
			if (eyesPixel != null) eyesPixel.animation.play('lookleft', true);
		}
		lookingAtRight = false;
	}
	public function lookRight()
	{
		if(!lookingAtRight)
		{
			if (eyes != null) eyes.anim.play('lookright', true);
			if (eyesPixel != null) eyesPixel.animation.play('lookright', true);
		}
		lookingAtRight = true;
	}
	public function finishEyes()
	{
		if (eyes != null) eyes.anim.curFrame = eyes.anim.length - 1;
		if (eyesPixel != null && eyesPixel.animation.curAnim != null) eyesPixel.animation.curAnim.finish();
	}

	/** aLookAt: 1 = 看玩家侧，其余 = 看对手侧 */
	public function updateABotEye(aLookAt:Int, finishInstantly:Bool = false)
	{
		if (aLookAt == 1) lookRight();
		else lookLeft();

		if (finishInstantly) finishEyes();
	}
}
