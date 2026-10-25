package substates;

import objects.VideoSprite;

/**
 * 全屏播放一个 credit 视频（组级）。
 *
 * - `isWaiting=false` → VideoSprite 自带全屏黑幕
 * - 长按确认 1 秒跳过；播完 / 跳过都会自动关闭，回到 Credits
 * - 播放期间暂停 BGM，销毁时恢复（`destroy()` 在整个 FlxState 生命周期里一定会被调）
 * - 没有 `VIDEOS_ALLOWED` / 文件不存在 → 立刻关闭，绝不白屏
 */
class CreditsVideoSubState extends MusicBeatSubstate
{
	var path:String;
	var closed:Bool = false;
	/** 防止"按住确认键进来 → 立刻被跳过"：必须先松手才武装 canSkip */
	var armed:Bool = false;

	var musicVol:Float = 1;
	var musicWasPlaying:Bool = false;
	var musicTouched:Bool = false;

	#if VIDEOS_ALLOWED
	var video:VideoSprite = null;
	#end

	public function new(path:String)
	{
		super();
		this.path = path;
	}

	override function create():Void
	{
		super.create();
		bgColor = FlxColor.BLACK;

		#if VIDEOS_ALLOWED
		if (path == null || path.length == 0)
		{
			closeVideo();
			return;
		}

		#if sys
		if (!FileSystem.exists(path))
		{
			trace('[CreditsVideo] missing: $path');
			closeVideo();
			return;
		}
		#end

		pauseMusic();

		video = new VideoSprite(path, false, false, false);
		video.finishCallback = closeVideo;
		video.onSkip = closeVideo;

		var bmp = video.videoSprite.bitmap;
		if (bmp != null) bmp.onFormatSetup.add(fitVideo);

		add(video);
		video.play();
		#else
		closeVideo();
		#end
	}

	#if VIDEOS_ALLOWED
	/** 覆盖 VideoSprite 构造里那句 setGraphicSize(FlxG.width)：按屏幕等比 contain。 */
	function fitVideo():Void
	{
		if (video == null) return;
		var bmp = video.videoSprite.bitmap;
		if (bmp == null) return;
		var bd = bmp.bitmapData;
		if (bd == null || bd.width <= 0 || bd.height <= 0) return;

		var s:Float = Math.min(FlxG.width / bd.width, FlxG.height / bd.height);
		if (s <= 0 || !Math.isFinite(s)) s = 1;

		video.videoSprite.setGraphicSize(Std.int(bd.width * s), Std.int(bd.height * s));
		video.videoSprite.updateHitbox();
		video.videoSprite.screenCenter();
	}
	#end

	override function update(elapsed:Float):Void
	{
		#if VIDEOS_ALLOWED
		// 必须在 super.update() 之前：VideoSprite.update 会用 pressed('accept') 累加长按时间
		if (!armed && !Controls.instance.pressed('accept'))
		{
			armed = true;
			if (video != null) video.canSkip = true;
		}
		#end

		if (!closed && (controls.BACK || FlxG.mouse.justPressedRight)) closeVideo();

		super.update(elapsed);
	}

	function closeVideo():Void
	{
		if (closed) return;
		closed = true;
		close();
	}

	// ================================================================
	// BGM
	// ================================================================

	function pauseMusic():Void
	{
		if (FlxG.sound.music == null) return;
		musicVol = FlxG.sound.music.volume;
		musicWasPlaying = FlxG.sound.music.playing;
		FlxG.sound.music.pause();
		musicTouched = true;
	}

	function resumeMusic():Void
	{
		if (!musicTouched || FlxG.sound.music == null) return;
		musicTouched = false;
		FlxG.sound.music.volume = musicVol;
		if (musicWasPlaying && !FlxG.sound.music.playing) FlxG.sound.music.resume();
	}

	override function destroy():Void
	{
		#if VIDEOS_ALLOWED
		if (video != null)
		{
			video.finishCallback = null;
			video.onSkip = null;
			remove(video, true);
			video.destroy();
			video = null;
		}
		#end

		resumeMusic();
		super.destroy();
	}
}
