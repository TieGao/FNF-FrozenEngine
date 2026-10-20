package objects;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Matrix;
import openfl.Lib;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

import backend.Paths;
import backend.ClientPrefs;
import backend.MetroEase;
import backend.UITheme;

/**
 * 全局 Metro/Win8 风格消息通知（toast）。
 *
 * 与成就弹窗 `AchievementPopup` 同机制：直接挂到 `FlxG.game`，
 * 脱离 FlxState 显示列表，因此切换界面 / 切换 state 也不会消失，动画完全自驱动。
 *
 * 贴屏幕右边缘（直角、无阴影），从右侧推入并淡入，停留计时结束后向右滑出并淡出。
 * 缓动走 Win8 官方的两条 cubic-bezier：入场 entrance（先快后慢），
 * 出场 exit（先慢后快，不抢注意力）。
 *
 * 两种类型：
 *  - `MESSAGE`：纯消息，点击 = 关闭。
 *  - `ACTION`：点击 = 先执行触发方传入的回调，再关闭。
 *
 * 通过静态方法 `MessageBox.show(...)` 调用，内部用 `active` 队列维护多个堆叠，
 * 关闭后其余会自动上移重排。
 */
class MessageBox extends Sprite
{
	public static var active:Array<MessageBox> = [];

	/** 设计尺寸（game 坐标），Win8 通知条的 400x80 */
	static var WIDTH:Float = 400;
	static var HEIGHT:Float = 80;
	static var PAD:Float = 16;
	static var TOP_MARGIN:Float = 24;
	static var SIDE_MARGIN:Float = 0; // 紧贴右边缘
	static var STACK_GAP:Float = 8;

	// Win8 动效时长：入场 333ms，出场 200ms
	static var SLIDE_IN_TIME:Float = 0.33;
	static var SLIDE_OUT_TIME:Float = 0.20;
	static var FADE_IN_TIME:Float = 0.16;
	static var FADE_OUT_TIME:Float = 0.20;

	static var EASE_ENTER:Float->Float = MetroEase.ENTRANCE;
	static var EASE_EXIT:Float->Float = MetroEase.EXIT;

	/** 屏幕右侧之外（game 坐标） */
	static var START_X(get, never):Float;
	static function get_START_X():Float return FlxG.width + 8;

	/** 停留位置（game 坐标） */
	static var TARGET_X(get, never):Float;
	static function get_TARGET_X():Float return FlxG.width - WIDTH - SIDE_MARGIN;

	public static function show(title:String, body:String,
		?type:MessageBoxType = MESSAGE, ?action:Void->Void, ?duration:Float = 5.0):MessageBox
	{
		var mb = new MessageBox(title, body, type, action, duration);
		active.push(mb);
		recalcTargets();
		// 新条直接落在自己的槽位，只做横向推入
		mb.yPos = mb.targetY;
		mb.y = mb.yPos * mb.lastScale;
		mb.slideIn();
		return mb;
	}

	static function recalcTargets():Void
	{
		for (i in 0...active.length)
			active[i].targetY = TOP_MARGIN + i * (HEIGHT + STACK_GAP);
	}

	// =========================================================

	public var type:MessageBoxType;
	public var action:Void->Void = null;
	public var duration:Float;
	public var targetY:Float = TOP_MARGIN;

	var timeLeft:Float;
	var progress:Float = 1;
	var yPos:Float = TOP_MARGIN;
	var state:Int = 0; // 0=SLIDE_IN, 1=HOLD, 2=SLIDE_OUT
	var timePassed:Float = -1;
	var lastScale:Float = 1;

	var tweenX:FlxTween = null;
	var tweenFade:FlxTween = null;

	var bar:Shape;
	var bitmaps:Array<BitmapData> = [];

	public function new(title:String, body:String, type:MessageBoxType, ?action:Void->Void, ?duration:Float = 5.0)
	{
		super();

		this.type = type;
		this.action = action;
		this.duration = duration;
		this.timeLeft = duration;

		// 背景（Metro 扁平直角 + Win8 深蓝）
		graphics.beginFill(UITheme.toast);
		graphics.drawRect(0, 0, WIDTH, HEIGHT);
		graphics.endFill();

		// 标题（较大）
		drawText(title, 17, PAD, 8, WIDTH - PAD * 2, UITheme.textPrimary);
		// 正文（较小，可换行）
		drawText(body, 13, PAD, 30, WIDTH - PAD * 2, UITheme.textPrimary);

		// 进度条（贴底，每帧重画）
		bar = new Shape();
		addChild(bar);

		this.mouseEnabled = true;
		this.buttonMode = true;
		addEventListener(MouseEvent.CLICK, onClick);

		// 自身 graphics（背景 + 文本 bitmap）已覆盖整块区域，天然可命中，无需额外 hitArea
		FlxG.stage.addEventListener(Event.RESIZE, onResize);
		addEventListener(Event.ENTER_FRAME, update);

		lastScale = (FlxG.stage.stageHeight / FlxG.height);
		this.scaleX = lastScale;
		this.scaleY = lastScale;
		this.x = START_X * lastScale;
		this.y = yPos * lastScale;

		FlxG.game.addChild(this); // 全局挂载：切界面不消失
	}

	/** 从屏幕右侧推入并淡入 */
	function slideIn():Void
	{
		state = 0;
		cancelTweens();

		alpha = 0;
		tweenX = FlxTween.tween(this, {x: TARGET_X * lastScale}, SLIDE_IN_TIME, {
			ease: EASE_ENTER,
			onComplete: function(_) {
				tweenX = null;
				if (state == 0) state = 1;
			}
		});
		tweenFade = FlxTween.tween(this, {alpha: 1}, FADE_IN_TIME, {ease: EASE_ENTER});
	}

	/** 向右滑出屏幕并淡出，结束后自毁 */
	function slideOut():Void
	{
		if (state == 2) return;
		state = 2;
		cancelTweens();

		tweenX = FlxTween.tween(this, {x: START_X * lastScale}, SLIDE_OUT_TIME, {
			ease: EASE_EXIT,
			onComplete: function(_) {
				tweenX = null;
				destroy();
			}
		});
		tweenFade = FlxTween.tween(this, {alpha: 0}, FADE_OUT_TIME, {ease: EASE_EXIT});
	}

	function cancelTweens():Void
	{
		if (tweenX != null)
		{
			tweenX.cancel();
			tweenX = null;
		}
		if (tweenFade != null)
		{
			tweenFade.cancel();
			tweenFade = null;
		}
	}

	function drawText(text:String, size:Int, x:Float, y:Float, width:Float, color:FlxColor):Void
	{
		var t = new FlxText(0, 0, width, text, size);
		t.setFormat(Paths.font("vcr.ttf"), size, color, LEFT);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.updateHitbox();

		var bmp = t.graphic.bitmap.clone();
		bitmaps.push(bmp);
		graphics.beginBitmapFill(bmp, new Matrix(1, 0, 0, 1, x, y), false, false);
		graphics.drawRect(x, y, t.width, t.height);
		graphics.endFill();
		// 源 bitmap 在 flixel 全局缓存里按唯一 key 常驻，不释放会随 toast 数量无限堆积
		t.graphic.bitmap.dispose();
		t.graphic.bitmap.disposeImage();
		t.destroy();
	}

	function drawProgress(p:Float):Void
	{
		var barH:Float = 3;
		var barY:Float = HEIGHT - barH;

		bar.graphics.clear();
		bar.graphics.beginFill(UITheme.toastBarTrack);
		bar.graphics.drawRect(0, barY, WIDTH, barH);
		bar.graphics.beginFill(FlxColor.WHITE);
		bar.graphics.drawRect(0, barY, WIDTH * p, barH);
		bar.graphics.endFill();
	}

	function onClick(e:MouseEvent):Void
	{
		if (state == 2) return; // 已在关闭中
		if (type == ACTION && action != null)
			action();
		progress = 0; // 进度条到头
		slideOut();   // 立刻滑出
	}

	function update(e:Event):Void
	{
		if (timePassed < 0)
		{
			timePassed = Lib.getTimer();
			return;
		}

		var time = Lib.getTimer();
		var elapsed:Float = (time - timePassed) / 1000;
		timePassed = time;

		if (elapsed >= 0.5) return; // 跳过加载等大间隔

		// 横向由 tween 驱动，这里只管竖直方向（堆叠重排的平滑跟随）
		yPos += (targetY - yPos) * Math.min(1, elapsed * 11);

		if (state == 1)
		{
			timeLeft -= elapsed;
			progress = Math.max(0, timeLeft / duration);
			if (timeLeft <= 0) slideOut();
		}

		this.y = yPos * lastScale;
		drawProgress(progress);
	}

	private function onResize(e:Event):Void
	{
		var mult = (FlxG.stage.stageHeight / FlxG.height);
		scaleX = mult;
		scaleY = mult;

		y = (mult / lastScale) * y;
		lastScale = mult;

		// 滑入/滑出途中被缩放打断：tween 的起止值是旧的缩放基准，直接收尾到该状态的终点
		if (tweenX != null || tweenFade != null)
		{
			cancelTweens();
			if (state == 2)
			{
				destroy();
				return;
			}
			alpha = 1;
			state = 1;
		}

		x = (state == 2 ? START_X : TARGET_X) * lastScale;
	}

	public function destroy():Void
	{
		active.remove(this);
		recalcTargets();

		cancelTweens();

		if (FlxG.game.contains(this))
			FlxG.game.removeChild(this);

		FlxG.stage.removeEventListener(Event.RESIZE, onResize);
		removeEventListener(Event.ENTER_FRAME, update);
		removeEventListener(MouseEvent.CLICK, onClick);

		deleteBitmaps();
	}

	function deleteBitmaps():Void
	{
		for (bmp in bitmaps)
		{
			if (bmp != null)
			{
				bmp.dispose();
				bmp.disposeImage();
			}
		}
		bitmaps = null;
	}
}

enum MessageBoxType
{
	MESSAGE;
	ACTION;
}
