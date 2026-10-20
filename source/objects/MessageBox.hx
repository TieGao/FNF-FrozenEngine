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
import backend.UITheme;

/**
 * 全局 Metro/Win8 风格消息通知（toast）。
 *
 * 与成就弹窗 `AchievementPopup` 同机制：直接挂到 `FlxG.game`，
 * 脱离 FlxState 显示列表，因此切换界面 / 切换 state 也不会消失，动画完全自驱动。
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

	/** 设计尺寸（game 坐标） */
	static var WIDTH:Float = 360;
	static var HEIGHT:Float = 110;
	static var TOP_MARGIN:Float = 50; // 距顶部 50px
	static var SIDE_MARGIN:Float = 20;
	static var STACK_GAP:Float = 12;

	static var START_Y(get, never):Float;
	static function get_START_Y():Float return -(HEIGHT + 20); // 屏幕上方（game 坐标）

	public static function show(title:String, body:String,
		?type:MessageBoxType = MESSAGE, ?action:Void->Void, ?duration:Float = 5.0):MessageBox
	{
		var mb = new MessageBox(title, body, type, action, duration);
		active.push(mb);
		recalcTargets();
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
	var yPos:Float = START_Y;
	var state:Int = 0; // 0=SLIDE_IN, 1=HOLD, 2=SLIDE_OUT
	var timePassed:Float = -1;
	var lastScale:Float = 1;

	var bar:Shape;
	var bitmaps:Array<BitmapData> = [];

	public function new(title:String, body:String, type:MessageBoxType, ?action:Void->Void, ?duration:Float = 5.0)
	{
		super();

		this.type = type;
		this.action = action;
		this.duration = duration;
		this.timeLeft = duration;

		// 背景（Metro 扁平，强调色）
		graphics.beginFill(UITheme.accent);
		graphics.drawRoundRect(0, 0, WIDTH, HEIGHT, 8, 8);
		graphics.endFill();

		// 标题（较大）
		drawText(title, 18, 16, 14, WIDTH - 32, UITheme.textPrimary);
		// 正文（较小，可换行）
		drawText(body, 14, 16, 46, WIDTH - 32, UITheme.textPrimary);

		// 进度条（底部，每帧重画）
		bar = new Shape();
		addChild(bar);

		this.mouseEnabled = true;
		this.buttonMode = true;
		addEventListener(MouseEvent.CLICK, onClick);

		// 自身 graphics（背景圆角矩形 + 文本 bitmap）已覆盖整块区域，天然可命中，无需额外 hitArea
		FlxG.stage.addEventListener(Event.RESIZE, onResize);
		addEventListener(Event.ENTER_FRAME, update);

		lastScale = (FlxG.stage.stageHeight / FlxG.height);
		this.scaleX = lastScale;
		this.scaleY = lastScale;
		this.x = (FlxG.width - WIDTH - SIDE_MARGIN) * lastScale;
		this.y = yPos * lastScale;

		FlxG.game.addChild(this); // 全局挂载：切界面不消失
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
		var barH:Float = 6;
		var pad:Float = 14;
		var barW:Float = WIDTH - pad * 2;
		var barY:Float = HEIGHT - barH - 10;

		bar.graphics.clear();
		bar.graphics.beginFill(UITheme.accentDeep);
		bar.graphics.drawRect(pad, barY, barW, barH);
		bar.graphics.beginFill(FlxColor.WHITE);
		bar.graphics.drawRect(pad, barY, barW * p, barH);
		bar.graphics.endFill();
	}

	function onClick(e:MouseEvent):Void
	{
		if (state == 2) return; // 已在关闭中
		if (type == ACTION && action != null)
			action();
		progress = 0; // 进度条到头
		state = 2;    // 立刻回缩
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

		switch (state)
		{
			case 0: // SLIDE_IN
				yPos += (targetY - yPos) * Math.min(1, elapsed * 11);
				if (Math.abs(targetY - yPos) < 1)
				{
					yPos = targetY;
					state = 1;
				}
			case 1: // HOLD（同时平滑跟随 targetY，支持堆叠重排）
				yPos += (targetY - yPos) * Math.min(1, elapsed * 11);
				timeLeft -= elapsed;
				progress = Math.max(0, timeLeft / duration);
				if (timeLeft <= 0)
					state = 2;
			case 2: // SLIDE_OUT
				yPos += (START_Y - yPos) * Math.min(1, elapsed * 13);
				if (yPos <= START_Y + 1)
				{
					destroy();
					return;
				}
		}

		this.y = yPos * lastScale;
		drawProgress(progress);
	}

	private function onResize(e:Event):Void
	{
		var mult = (FlxG.stage.stageHeight / FlxG.height);
		scaleX = mult;
		scaleY = mult;

		x = (mult / lastScale) * x;
		y = (mult / lastScale) * y;
		lastScale = mult;
	}

	public function destroy():Void
	{
		active.remove(this);
		recalcTargets();

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
