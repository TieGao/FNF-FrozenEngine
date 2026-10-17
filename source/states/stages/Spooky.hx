package states.stages;

class Spooky extends BaseStage
{
	var halloweenBG:BGSprite;
	#if flxanimate
	/** 高画质：官方 VSlice 的 halloween_bg 图集（动画 timeline：static / thunder） */
	var halloweenAtlas:FlxAnimate;
	#end
	var halloweenWhite:BGSprite;
	override function create()
	{
		#if flxanimate
		if(!ClientPrefs.data.lowQuality) {
			// 官方 VSlice 图集。关键认知：
			// 1) 官方 stage JSON 的 prefix（static/thunder）是根时间线上的**帧标签**，不是符号：
			//    thunder = 0..29（闪电序列）、static = 30..34（暗态——闪电实例 PlayOnce 播完停在暗末帧）。
			//    用 addByFrameLabel 按标签切段播放，正是官方的本意。
			// 2) addByFrameLabel 走 addBySymbolIndices(根符号)，实例矩阵是恒等的，
			//    必须补上 STI 偏移 (-538.7,-496.1) 才与根时间线直接播放对齐。
			// 3) 内容中心（含 STI）对齐 PE 旧版 bg 中心 → 精灵位置 (0,-32)，实机若偏再微调。
			halloweenAtlas = new FlxAnimate(0, -32);
			halloweenAtlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(halloweenAtlas, 'halloween_bg');
				halloweenAtlas.anim.addByFrameLabel('idle', 'static', 24, true, -538.7, -496.1);
				halloweenAtlas.anim.addByFrameLabel('lightning', 'thunder', 24, false, -538.7, -496.1);
				halloweenAtlas.anim.play('idle');
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Could not load halloween_bg atlas: $e');
				trace(e.stack);
				halloweenAtlas = null;
			}
			if(halloweenAtlas != null)
			{
				halloweenAtlas.antialiasing = ClientPrefs.data.antialiasing;
				add(halloweenAtlas);
			}
			else
			{
				// 图集加载失败 → 回退 Psych 原版 spritesheet
				halloweenBG = new BGSprite('halloween_bg', -200, -100, ['halloweem bg0', 'halloweem bg lightning strike']);
				add(halloweenBG);
			}
		} else {
			halloweenBG = new BGSprite('halloween_bg_low', -200, -100);
			add(halloweenBG);
		}
		#else
		if(!ClientPrefs.data.lowQuality) {
			halloweenBG = new BGSprite('halloween_bg', -200, -100, ['halloweem bg0', 'halloweem bg lightning strike']);
		} else {
			halloweenBG = new BGSprite('halloween_bg_low', -200, -100);
		}
		add(halloweenBG);
		#end

		//PRECACHE SOUNDS
		Paths.sound('thunder_1');
		Paths.sound('thunder_2');

		//Monster cutscene
		if (isStoryMode && !seenCutscene)
		{
			switch(songName)
			{
				case 'monster':
					setStartCallback(monsterCutscene);
			}
		}
	}
	override function createPost()
	{
		halloweenWhite = new BGSprite(null, -800, -400, 0, 0);
		halloweenWhite.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
		halloweenWhite.alpha = 0;
		halloweenWhite.blend = ADD;
		add(halloweenWhite);
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;
	#if flxanimate
	/** 闪电（PlayOnce）播完后切回暗态 idle */
	var lightningPlaying:Bool = false;

	function backToIdle():Void
	{
		if(halloweenAtlas == null) return;
		halloweenAtlas.anim.play('idle');
		lightningPlaying = false;
	}
	#end

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		#if flxanimate
		if(lightningPlaying && halloweenAtlas != null && halloweenAtlas.anim.finished) backToIdle();
		#end
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
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		#if flxanimate
		if(halloweenAtlas != null)
		{
			halloweenAtlas.anim.play('lightning');
			lightningPlaying = true;
		}
		else if(!ClientPrefs.data.lowQuality) halloweenBG.animation.play('halloweem bg lightning strike');
		#else
		if(!ClientPrefs.data.lowQuality) halloweenBG.animation.play('halloweem bg lightning strike');
		#end

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if(boyfriend.hasAnimation('scared'))
			boyfriend.playAnim('scared', true);

		if(dad.hasAnimation('scared'))
			dad.playAnim('scared', true);

		if(gf != null && gf.hasAnimation('scared'))
			gf.playAnim('scared', true);

		if(ClientPrefs.data.camZooms) {
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if(!game.camZooming) { //Just a way for preventing it to be permanently zoomed until Skid & Pump hits a note
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}

		if(ClientPrefs.data.flashing) {
			halloweenWhite.alpha = 0.4;
			FlxTween.tween(halloweenWhite, {alpha: 0.5}, 0.075);
			FlxTween.tween(halloweenWhite, {alpha: 0}, 0.25, {startDelay: 0.15});
		}
	}

	function monsterCutscene()
	{
		inCutscene = true;
		camHUD.visible = false;

		FlxG.camera.focusOn(new FlxPoint(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100));

		// character anims
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		if(gf != null) gf.playAnim('scared', true);
		boyfriend.playAnim('scared', true);

		// white flash
		var whiteScreen:FlxSprite = new FlxSprite().makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
		whiteScreen.scrollFactor.set();
		whiteScreen.blend = ADD;
		add(whiteScreen);
		FlxTween.tween(whiteScreen, {alpha: 0}, 1, {
			startDelay: 0.1,
			ease: FlxEase.linear,
			onComplete: function(twn:FlxTween)
			{
				remove(whiteScreen);
				whiteScreen.destroy();

				camHUD.visible = true;
				startCountdown();
			}
		});
	}
}