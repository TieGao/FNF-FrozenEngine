package backend;

import flixel.util.FlxGradient;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.filters.ShaderFilter;
import shaders.MosaicEffect;

class CustomFadeTransition extends MusicBeatSubstate {
	public static var finishCallback:Void->Void;
	var isTransIn:Bool = false;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;
	
	var mosaicEffect:MosaicEffect;
	var isPixelTransition:Bool = false;
	var pixelStrength:Float = 1;
	var maxPixelStrength:Float = 15;
	var effectTween:FlxTween;
	var shaderFilter:ShaderFilter;

	var duration:Float;
	var transitionType:String;

	// loading 模式专用变量
	var loadingSprite:FlxSprite;
	var greenBg:FlxSprite;
	var coverTween:FlxTween;
	var isLoadingMode:Bool = false;
	
	public function new(duration:Float, isTransIn:Bool, ?transitionType:String = null)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		this.transitionType = (transitionType != null) ? transitionType : ClientPrefs.data.transitionType;
		super();
	}

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		var width:Int = Std.int(FlxG.width / Math.max(camera.zoom, 0.001));
		var height:Int = Std.int(FlxG.height / Math.max(camera.zoom, 0.001));
		
		// loading 分支
		if (transitionType == "loading")
		{
			isLoadingMode = true;

			// 纯色底用 1×1 缩放，别分配整屏贴图
			greenBg = new FlxSprite().makeGraphic(1, 1, 0xFFCAFF4D);
			greenBg.scale.set(width, height);
			greenBg.updateHitbox();
			greenBg.scrollFactor.set();
			greenBg.screenCenter();
			greenBg.alpha = isTransIn ? 1 : 0;
			add(greenBg);

			loadingSprite = new FlxSprite().loadGraphic(Paths.image('funkay'));
			loadingSprite.scrollFactor.set();
			// 和 LoadingState 里的 funkay 保持完全一致的缩放 / 抗锯齿，交接瞬间才看不出换过手
			loadingSprite.antialiasing = ClientPrefs.data.antialiasing;
			loadingSprite.setGraphicSize(0, Std.int(height));
			// ★ 先按缩放后的尺寸刷 hitbox 再居中，落点才和 LoadingState 里的 funkay 完全一致
			//   （以前是先 screenCenter 再 setGraphicSize，funkay 会偏左，交接时横向跳一大截）
			loadingSprite.updateHitbox();
			loadingSprite.screenCenter();
			loadingSprite.alpha = isTransIn ? 1 : 0;
			add(loadingSprite);

			// 两个精灵走同一条时间轴，只在两者都到位的时刻收尾：
			// 以前 greenBg 在 duration * 0.7 就回调切状态，那时 funkay 才 ~0.79 不透明度，
			// 接手的 LoadingState 又是满不透明，视觉上 funkay 会突然"跳实"一下
			startCoverTween(isTransIn ? 1 : 0, isTransIn ? 0 : 1, function() {
				if (isTransIn)
				{
					close();
					return;
				}

				// ★ 盖板完全铺满后才切状态，LoadingState 首帧就是同一张盖板，中间不会露黑底
				if (finishCallback != null)
				{
					var cb:Void->Void = finishCallback;
					finishCallback = null;
					cb();
				}
			});
			return;
		}
		
		if (transitionType == "pixel")
		{
			isPixelTransition = true;
			mosaicEffect = new MosaicEffect();
			pixelStrength = isTransIn ? maxPixelStrength : 0;
			mosaicEffect.setStrength(pixelStrength, pixelStrength);

			shaderFilter = new ShaderFilter(mosaicEffect.shader);
			camera.filters = [shaderFilter];

			startPixelTween(pixelStrength, isTransIn ? 0 : maxPixelStrength, 1.0, FlxEase.quadOut);
		}
		else
		{
			// 渐变模式
			transGradient = FlxGradient.createGradientFlxSprite(1, height, 
				(isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
			transGradient.scale.x = width;
			transGradient.updateHitbox();
			transGradient.scrollFactor.set();
			transGradient.screenCenter(X);
			add(transGradient);

			transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			transBlack.scale.set(width, height + 400);
			transBlack.updateHitbox();
			transBlack.scrollFactor.set();
			transBlack.screenCenter(X);
			add(transBlack);

			if(isTransIn)
				transGradient.y = transBlack.y - transBlack.height;
			else
				transGradient.y = -transGradient.height;
		}

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!isLoadingMode && !isPixelTransition)
		{
			updateFadeTransition(elapsed);
		}
	}

	function updateFadeTransition(elapsed:Float)
	{
		if (transGradient == null) return;
		final height:Float = FlxG.height * Math.max(camera.zoom, 0.001);
		final targetPos:Float = transGradient.height + 50 * Math.max(camera.zoom, 0.001);
		if(duration > 0)
			transGradient.y += (height + targetPos) * elapsed / duration;
		else
			transGradient.y = (targetPos) * elapsed;

		if(isTransIn)
			transBlack.y = transGradient.y + transGradient.height;
		else
			transBlack.y = transGradient.y - transBlack.height;

		if(transGradient.y >= targetPos)
		{
			close();
		}
	}

	public function startPixelTween(from:Float, to:Float, duration:Float = 0.5, ?ease:EaseFunction)
	{
		if (!isPixelTransition || mosaicEffect == null) return;
		if (effectTween != null) effectTween.cancel();
		if (ease == null) ease = FlxEase.quadOut;

		effectTween = FlxTween.num(from, to, duration, {
			type: ONESHOT,
			ease: ease,
			onComplete: function(_) {
				close();
			}
		}, function(v:Float) {
			pixelStrength = v;
			if (mosaicEffect != null) {
				mosaicEffect.setStrength(v, v);
			}
		});
	}

	public function startCoverTween(from:Float, to:Float, onDone:Void->Void)
	{
		if (coverTween != null) coverTween.cancel();

		coverTween = FlxTween.num(from, to, duration, {
			type: ONESHOT,
			ease: FlxEase.sineInOut,
			onComplete: function(_) {
				coverTween = null;
				onDone();
			}
		}, function(v:Float) {
			// 底色和 funkay 同一条曲线，保证收尾那一刻两者都精确到达 0 / 1
			if (greenBg != null) greenBg.alpha = v;
			if (loadingSprite != null) loadingSprite.alpha = v;
		});
	}

	override function close():Void
	{
		// 取消所有 tween
		if (effectTween != null) {
			effectTween.cancel();
			effectTween = null;
		}
		if (coverTween != null) {
			coverTween.cancel();
			coverTween = null;
		}
		// 如果是像素模式且为进入，清除滤镜
		if (isPixelTransition && camera != null && isTransIn)
		{
			camera.filters = null;
			shaderFilter = null;
		}
		
		super.close();

		if(finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}
	}
}