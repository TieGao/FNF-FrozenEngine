package nmv.objects;

#if VIDEOS_ALLOWED
import hxvlc.flixel.FlxVideoSprite;
import hxvlc.openfl.Location;

/**
 * NMV funkin.video.FunkinVideoSprite 薄适配：hxvlc FlxVideoSprite 直包（FE pin hxvlc 2.3.1）。
 *
 * 语料用到的面：new(x, y, oneTimeUse)、onFormat、onEnd、load(Paths.video(...))、
 * delayAndStart()（legacy 的 videoCutscene / meltdown 都走这套）。
 * NMV 原类的字幕系统（FunkinCaption/srt）与 time/percent 面语料未用，不搬。
 * tiedToGame 字段保留 API 形状；FE 的暂停联动未接（NMV 原版在 FunkinGame 挂
 * focus/pause 信号，语料视频不依赖该行为，后续需要再补）。
 */
class FunkinVideoSprite extends FlxVideoSprite
{
	/** 全部存活实例（NMV 同名面；forEach 系列语料未用，保留静态面）。 */
	public static final instances:Array<FunkinVideoSprite> = [];

	/** load 选项：循环播放。 */
	public static final looping:String = ':input-repeat=65535';

	/** load 选项：静音。 */
	public static final muted:String = ':no-audio';

	/** 手动初始化 LibVLC 实例（NMV 同名面）。 */
	public static function init():Void
	{
		hxvlc.util.Handle.init();
	}

	/** false = 不随游戏暂停（联动未接，仅保留 NMV 字段形状）。 */
	public var tiedToGame:Bool = true;

	/**
	 * @param x x 位置
	 * @param y y 位置
	 * @param oneTimeUse true = 视频放完自动 destroy
	 */
	public function new(x:Float = 0, y:Float = 0, oneTimeUse:Bool = true)
	{
		super(x, y);

		instances.push(this);

		if (oneTimeUse) bitmap.onEndReached.add(this.destroy, true, -10);
	}

	/** 延迟起播（NMV 推荐 over play()；默认下一帧）。 */
	public function delayAndStart(delay:Float = 0):Void
	{
		flixel.util.FlxTimer.wait(delay, play);
	}

	/** 视频播到结尾回调。 */
	public function onEnd(func:Void->Void, once:Bool = false, priority:Int = 0):Void
	{
		bitmap.onEndReached.add(func, once, priority);
	}

	/** 视频开始回调。 */
	public function onStart(func:Void->Void, once:Bool = false, priority:Int = 0):Void
	{
		bitmap.onOpening.add(func, once, priority);
	}

	/** 视频格式就绪回调（推荐在此绑相机/缩放）。 */
	public function onFormat(func:Void->Void, once:Bool = false, priority:Int = 0):Void
	{
		bitmap.onFormatSetup.add(func, once, priority);
	}

	override function destroy():Void
	{
		if (instances.contains(this)) instances.remove(this);

		if (bitmap != null)
		{
			bitmap.stop();

			bitmap.onEndReached.removeAll();
			bitmap.onFormatSetup.removeAll();
			bitmap.onOpening.removeAll();
		}

		super.destroy();
	}
}
#end
