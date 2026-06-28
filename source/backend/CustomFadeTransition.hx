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
	var loadingTween:FlxTween;
	var greenBgTween:FlxTween;
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
			
			greenBg = new FlxSprite(0, 0).makeGraphic(width, height, 0xFFCAFF4D);
			greenBg.scrollFactor.set();
			greenBg.screenCenter();
			greenBg.alpha = isTransIn ? 1 : 0;
			add(greenBg);

			loadingSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('funkay'));
			loadingSprite.scrollFactor.set();
			loadingSprite.screenCenter();
			loadingSprite.alpha = isTransIn ? 1 : 0;
			loadingSprite.setGraphicSize(0, FlxG.height);
			add(loadingSprite);


			if (!isTransIn) 
			{
				// ★ 淡出（退出场景）：从 0 -> 1，完成后只调用 finishCallback，不关闭 substate
				loadingTween = FlxTween.tween(loadingSprite, {alpha: 1}, duration, {
					ease: FlxEase.sineInOut,
					onComplete: function(_) {
						// 只执行回调，不调用 close()，让精灵保留
						if (finishCallback != null) {
							finishCallback();
							finishCallback = null;
						}
						// ★ 不调用 close()！substate 保留，精灵继续显示
					}
				});

				greenBgTween = FlxTween.tween(greenBg, {alpha: 1}, duration * 0.7, {
					ease: FlxEase.sineInOut,
					onComplete: function(_) {
						// 只执行回调，不调用 close()，让精灵保留
						if (finishCallback != null) {
							finishCallback();
							finishCallback = null;
						}
						// ★ 不调用 close()！substate 保留，精灵继续显示
					}
				});
			} 
			else 
			{
				// 淡入（进入场景）：从 1 -> 0，完成后关闭
				loadingTween = FlxTween.tween(loadingSprite, {alpha: 0}, duration, {
					ease: FlxEase.sineInOut,
					onComplete: function(_) {
						close(); // 关闭 substate，移除精灵
					}
				});
				greenBgTween = FlxTween.tween(greenBg, {alpha: 0}, duration * 1.2, {
					ease: FlxEase.sineInOut
				});
			}
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

	override function close():Void
	{
		// 取消所有 tween
		if (effectTween != null) {
			effectTween.cancel();
			effectTween = null;
		}
		if (loadingTween != null) {
			loadingTween.cancel();
			loadingTween = null;
		}
		if (greenBgTween != null) {
			greenBgTween.cancel();
			greenBgTween = null;
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