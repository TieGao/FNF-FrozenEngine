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
 *
 * `MessageBox.showProgress(...)` 是常驻版：不自动消失，进度条由 `setProgress` 推进，
 * 做完用 `closeIn(秒)` 收尾。用于「正在转换歌曲」这类要显示进度条的长任务。
 *
 * ⚠️ 动画**不能**用 `FlxTween`（曾经用过，会概率卡死）：
 * `FlxTweenManager` 构造时注册了 `FlxG.signals.preStateSwitch → clear()`，
 * 而 `clear()` 是 `tween.active = false; tween.destroy()`，**不会调 onComplete**。
 * 本类挂在 `FlxG.game` 上、天生跨 state 存活，只要切 state 的瞬间正好在滑入/滑出里，
 * 回调就永远不来 —— 滑入的条停在半路再也不计时、滑出的条停在半路再也不自毁。
 * 所以横竖两个方向统一由 `ENTER_FRAME` 自算缓动，状态机只靠自己推进。
 */
class MessageBox extends Sprite
{
	public static var active:Array<MessageBox> = [];

	/** 设计尺寸（game 坐标），Win8 通知条的 400x80；正文折行多了按行数往上撑 */
	static var WIDTH:Float = 400;
	static var MIN_HEIGHT:Float = 80;
	static var PAD:Float = 16;
	/** 标题基线（相对条顶）；正文起始 y 也兼作「头部高度」 */
	static var TITLE_Y:Float = 8;
	static var BODY_Y:Float = 30;
	static var TOP_MARGIN:Float = 24;
	static var SIDE_MARGIN:Float = 0; // 紧贴右边缘
	static var STACK_GAP:Float = 8;

	// Win8 动效时长：入场 333ms，出场 200ms
	static var SLIDE_IN_TIME:Float = 0.33;
	static var SLIDE_OUT_TIME:Float = 0.20;
	static var FADE_IN_TIME:Float = 0.16;
	static var FADE_OUT_TIME:Float = 0.20;

	/** 单帧最大推进量：加载之类的长间隔夹到一帧，别让条瞬移，也别整帧丢弃（丢弃会让计时卡住） */
	static var MAX_STEP:Float = 0.1;

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

	/**
	 * 常驻条：不走停留计时，停在那儿等 `setProgress` / `closeIn`。
	 *
	 * 不做滑入动画：调用方挂上之后紧接着就会去干阻塞的活（逐首转换），
	 * 滑到一半会被冻住，反而让条停在屏幕外。直接落在最终位置更实在。
	 */
	public static function showProgress(title:String, body:String):MessageBox
	{
		var mb = new MessageBox(title, body, MESSAGE, null, 0);
		mb.persistent = true;

		active.push(mb);
		recalcTargets();
		mb.yPos = mb.targetY;
		mb.xPos = TARGET_X;
		mb.x = mb.xPos * mb.lastScale;
		mb.y = mb.yPos * mb.lastScale;
		mb.alpha = 1;
		mb.state = 1; // 直接进 HOLD，closeIn 的倒计时才会走
		return mb;
	}

	/** 逐条按自己的高度往下排（正文长的条更高，不能再用固定 HEIGHT） */
	static function recalcTargets():Void
	{
		var y:Float = TOP_MARGIN;
		for (mb in active)
		{
			mb.targetY = y;
			y += mb.toastHeight + STACK_GAP;
		}
	}

	// =========================================================

	public var type:MessageBoxType;
	public var action:Void->Void = null;
	public var duration:Float;
	public var targetY:Float = TOP_MARGIN;
	/** true = 常驻：不走停留计时，靠 setProgress / closeIn 驱动 */
	public var persistent:Bool = false;

	var timeLeft:Float;
	var progress:Float = 1;
	var yPos:Float = TOP_MARGIN;
	/** 横向位置（game 坐标，未乘缩放；实际 x 每帧按 lastScale 换算） */
	var xPos:Float = 0;
	/** 本条实际高度：正文一行时就是 80，折成多行时按行数撑高 */
	var toastHeight:Float = MIN_HEIGHT;
	var state:Int = 0; // 0=SLIDE_IN, 1=HOLD, 2=SLIDE_OUT
	var timePassed:Float = -1;
	var lastScale:Float = 1;
	/** 常驻模式的关闭倒计时（<0 = 不关闭） */
	var closeTimer:Float = -1;
	/** destroy 幂等标记：滑出结束与外部 close 可能撞在一起 */
	var destroyed:Bool = false;

	// 当前这段动画的参数（横向与透明度进度独立，各自到点）
	var animTime:Float = 0;
	var animFromX:Float = 0;
	var animToX:Float = 0;
	var animDurX:Float = 1;
	var animFromAlpha:Float = 1;
	var animToAlpha:Float = 1;
	var animDurAlpha:Float = 1;
	var animEase:Float->Float = EASE_ENTER;

	var bar:Shape;
	var bitmaps:Array<BitmapData> = [];

	public function new(title:String, body:String, type:MessageBoxType, ?action:Void->Void, ?duration:Float = 5.0)
	{
		super();

		this.type = type;
		this.action = action;
		this.duration = duration;
		this.timeLeft = duration;

		// 先量正文折行后的高度：错误信息这类长文本会折成多行，固定 80 会溢出色块外
		var bodyH:Float = measureText(body, 13, WIDTH - PAD * 2);
		toastHeight = Math.max(MIN_HEIGHT, BODY_Y + bodyH + PAD);

		// 背景（Metro 扁平直角 + Win8 深蓝）
		graphics.beginFill(UITheme.toast);
		graphics.drawRect(0, 0, WIDTH, toastHeight);
		graphics.endFill();

		// 标题（较大）
		drawText(title, 17, PAD, TITLE_Y, WIDTH - PAD * 2, UITheme.textPrimary);
		// 正文（较小，可换行）
		drawText(body, 13, PAD, BODY_Y, WIDTH - PAD * 2, UITheme.textPrimary);

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
		xPos = START_X;
		this.x = xPos * lastScale;
		this.y = yPos * lastScale;

		FlxG.game.addChild(this); // 全局挂载：切界面不消失
	}

	/** 设置进度条（0~1）。仅常驻模式需要，普通通知条的进度是停留倒计时。 */
	public function setProgress(p:Float):Void
	{
		progress = Math.max(0, Math.min(1, p));
		drawProgress(progress);
	}

	/** 常驻模式收尾：再停留 seconds 秒后滑出。 */
	public function closeIn(seconds:Float):Void
		closeTimer = Math.max(0, seconds);

	/** 立刻滑出（不等停留 / 倒计时）。 */
	public function close():Void
		slideOut();

	/**
	 * 从当前横位滑到 toX、当前透明度淡到 toAlpha，各自用自己的时长。
	 * 从半路被打断时会接着当前值走，不会跳一下。
	 */
	function startAnim(toX:Float, durX:Float, toAlpha:Float, durAlpha:Float, ease:Float->Float):Void
	{
		animTime = 0;
		animFromX = xPos;
		animToX = toX;
		animDurX = durX;
		animFromAlpha = alpha;
		animToAlpha = toAlpha;
		animDurAlpha = durAlpha;
		animEase = ease;
	}

	/** 从屏幕右侧推入并淡入 */
	function slideIn():Void
	{
		state = 0;
		alpha = 0; // 首帧必须透明，别闪一下
		startAnim(TARGET_X, SLIDE_IN_TIME, 1, FADE_IN_TIME, EASE_ENTER);
	}

	/** 向右滑出屏幕并淡出，结束后自毁 */
	function slideOut():Void
	{
		if (destroyed || state == 2) return;
		state = 2;
		startAnim(START_X, SLIDE_OUT_TIME, 0, FADE_OUT_TIME, EASE_EXIT);
	}

	/** 量折行后的文本高度（不画，只建一次临时 FlxText 取尺寸后清掉） */
	static function measureText(text:String, size:Int, width:Float):Float
	{
		var t = new FlxText(0, 0, width, text, size);
		t.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, LEFT);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.updateHitbox();

		var h:Float = t.height;
		t.graphic.bitmap.dispose();
		t.graphic.bitmap.disposeImage();
		t.destroy();
		return h;
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
		var barY:Float = toastHeight - barH;

		bar.graphics.clear();
		bar.graphics.beginFill(UITheme.toastBarTrack);
		bar.graphics.drawRect(0, barY, WIDTH, barH);
		bar.graphics.beginFill(FlxColor.WHITE);
		bar.graphics.drawRect(0, barY, WIDTH * p, barH);
		bar.graphics.endFill();
	}

	function onClick(e:MouseEvent):Void
	{
		if (destroyed || state == 2) return; // 已在关闭中
		if (type == ACTION && action != null)
			action();
		progress = 0; // 进度条到头
		slideOut();   // 立刻滑出
	}

	function update(e:Event):Void
	{
		if (destroyed) return;

		if (timePassed < 0)
		{
			timePassed = Lib.getTimer();
			return;
		}

		var time = Lib.getTimer();
		var elapsed:Float = (time - timePassed) / 1000;
		timePassed = time;

		// 大间隔（加载、卡顿）夹到一帧，别让条瞬移；也绝不整帧丢弃，
		// 否则计时会停、状态机永远推不到下一步 —— 那就是"卡住"
		if (!(elapsed > 0)) elapsed = 0;
		else if (elapsed > MAX_STEP) elapsed = MAX_STEP;

		// 竖直方向：任何状态下都跟随堆叠重排（别的条进出会改 targetY）
		yPos += (targetY - yPos) * Math.min(1, elapsed * 11);

		// 滑入 / 滑出：自算缓动，不依赖任何外部 tween manager
		if (state != 1)
		{
			animTime += elapsed;
			var tX:Float = animDurX > 0 ? Math.min(1, animTime / animDurX) : 1;
			var tA:Float = animDurAlpha > 0 ? Math.min(1, animTime / animDurAlpha) : 1;
			xPos = animFromX + (animToX - animFromX) * animEase(tX);
			alpha = animFromAlpha + (animToAlpha - animFromAlpha) * animEase(tA);

			if (tX >= 1 && tA >= 1)
			{
				xPos = animToX;
				alpha = animToAlpha;
				if (state == 0)
					state = 1; // 滑入结束，开始停留计时
				else
				{
					destroy(); // 滑出结束：自毁（在 ENTER_FRAME 里摘监听是安全的）
					return;
				}
			}
		}
		else if (persistent)
		{
			// 常驻条：进度条由 setProgress 驱动，这里只跑关闭倒计时
			if (closeTimer >= 0)
			{
				closeTimer -= elapsed;
				if (closeTimer <= 0) slideOut();
			}
		}
		else
		{
			timeLeft -= elapsed;
			progress = Math.max(0, timeLeft / duration);
			if (timeLeft <= 0) slideOut();
		}

		this.x = xPos * lastScale;
		this.y = yPos * lastScale;
		drawProgress(progress);
	}

	private function onResize(e:Event):Void
	{
		var mult = (FlxG.stage.stageHeight / FlxG.height);
		// 最小化时 stageHeight 可能为 0，别把坐标 / 缩放乘成 0 或 NaN
		if (!(mult > 0)) return;

		lastScale = mult;
		scaleX = mult;
		scaleY = mult;

		// 坐标都是 game 空间里的连续量，缩放变了重新换算即可，
		// 动画不用中断（以前这里会把 tween 掐掉直接归位）
		x = xPos * mult;
		y = yPos * mult;
	}

	public function destroy():Void
	{
		if (destroyed) return;
		destroyed = true;

		active.remove(this);
		recalcTargets();

		if (FlxG.game != null && FlxG.game.contains(this))
			FlxG.game.removeChild(this);

		FlxG.stage.removeEventListener(Event.RESIZE, onResize);
		removeEventListener(Event.ENTER_FRAME, update);
		removeEventListener(MouseEvent.CLICK, onClick);

		deleteBitmaps();
	}

	function deleteBitmaps():Void
	{
		if (bitmaps == null) return;
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
