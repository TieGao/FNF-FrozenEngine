package objects;

import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;

/**
 * Credits 界面右侧的视频展示面板。
 *
 * - 全程只保留一个 VideoSprite（VLC 句柄代价高，不反复 destroy/load）
 * - 尺寸不跟随屏幕宽度拉满：按「框」等比缩放（默认 75% 屏高），右对齐、垂直居中
 * - 静音、循环、不可跳过、不建全屏黑幕
 * - 没有 VIDEOS_ALLOWED 宏时整类退化成一堆空实现，调用方无需 #if
 */
class CreditsVideoPanel extends FlxGroup
{
	public var currentPath(default, null):String = '';

	#if VIDEOS_ALLOWED
	var sprite:VideoSprite = null;
	var fadeTween:FlxTween = null;

	var centerX:Float = 0;
	var centerY:Float = 0;
	var maxW:Float = 0;
	var maxH:Float = 0;
	var sizing:Bool = false;
	#end

	public function new()
	{
		super();
	}

	/** 设定展示框（屏幕坐标）。尺寸在视频解码出真实分辨率后自动等比适配。 */
	public function setBox(centerX:Float, centerY:Float, maxWidth:Float, maxHeight:Float):Void
	{
		#if VIDEOS_ALLOWED
		this.centerX = centerX;
		this.centerY = centerY;
		this.maxW = maxWidth;
		this.maxH = maxHeight;
		if (sprite != null) fit();
		#end
	}

	/** path 为空 = 隐藏。同一路径重复调用只恢复播放，不重新 load。 */
	public function showVideo(path:String):Void
	{
		#if VIDEOS_ALLOWED
		if (path == null || path.length == 0)
		{
			hideVideo();
			return;
		}

		if (sprite == null)
		{
			sprite = new VideoSprite(path, true, false, true);
			if (sprite.videoSprite.bitmap != null)
			{
				sprite.videoSprite.bitmap.volumeAdjust = 0;
				sprite.videoSprite.bitmap.onFormatSetup.add(fit);
			}
			sprite.alpha = 0;
			add(sprite);
			currentPath = path;
			sprite.visible = true;
			sprite.play();
			fadeTo(1, false);
			return;
		}

		if (currentPath == path)
		{
			sprite.visible = true;
			sprite.resume();
			fadeTo(1, false);
			return;
		}

		currentPath = path;
		sprite.visible = true;
		sprite.videoSprite.load(path, ['input-repeat=65545']);
		sprite.play();
		fadeTo(1, false);
		#end
	}

	public function hideVideo():Void
	{
		#if VIDEOS_ALLOWED
		if (sprite == null || !sprite.visible) return;
		sprite.pause();
		fadeTo(0, true);
		// 故意保留 currentPath：下次回到同一条目直接 resume，不重新 load
		#end
	}

	#if VIDEOS_ALLOWED
	function fadeTo(target:Float, hideAfter:Bool):Void
	{
		if (sprite == null) return;
		if (fadeTween != null) fadeTween.cancel();
		if (!hideAfter && sprite.alpha >= 1) return;

		fadeTween = FlxTween.tween(sprite, {alpha: target}, 0.22, {
			ease: FlxEase.quadOut,
			onComplete: function(_) {
				if (hideAfter && sprite != null) sprite.visible = false;
			}
		});
	}
	#end

	public function dispose():Void
	{
		#if VIDEOS_ALLOWED
		if (sprite == null) return;
		if (fadeTween != null)
		{
			fadeTween.cancel();
			fadeTween = null;
		}
		remove(sprite, true);
		sprite.destroy();
		sprite = null;
		currentPath = '';
		#end
	}

	#if VIDEOS_ALLOWED
	/** 覆盖 VideoSprite 构造函数里那句 setGraphicSize(FlxG.width)：按框等比适配。 */
	function fit():Void
	{
		if (sizing || sprite == null) return;
		var bmp = sprite.videoSprite.bitmap;
		if (bmp == null) return;
		var bd = bmp.bitmapData;
		if (bd == null || bd.width <= 0 || bd.height <= 0) return;

		sizing = true;

		var scale:Float = Math.min(maxH / bd.height, maxW / bd.width);
		if (scale <= 0 || !Math.isFinite(scale)) scale = 1;

		var w:Float = Math.round(bd.width * scale);
		var h:Float = Math.round(bd.height * scale);

		sprite.videoSprite.setGraphicSize(Std.int(w), Std.int(h));
		sprite.videoSprite.updateHitbox();

		// 子精灵用世界坐标直接定位：FlxSpriteGroup 的 x/y 会平移所有子对象，这里保持组在 0,0
		sprite.videoSprite.x = centerX - sprite.videoSprite.width * 0.5;
		sprite.videoSprite.y = centerY - sprite.videoSprite.height * 0.5;

		sizing = false;
	}
	#end
}
