package backend;

import flixel.FlxG;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;

import objects.VideoSprite;
import states.editors.content.EditorPlayState;

/**
 * 闲置节能（FPS 减速器）：一段时间没有任何输入就压低帧率省电，任意输入立刻恢复。
 *
 * 活动判定（三路兜底）：
 *  - 输入事件：键盘按下 / 鼠标按下·移动·滚轮（openfl stage 事件，事件驱动零轮询开销）；
 *  - 每帧轮询：按住的键 / 鼠标 / 手柄（防止 key auto-repeat 或一帧内完成的超短点按被漏掉）；
 *  - 窗口重新获得焦点（alt-tab 回来）。
 *
 * 降帧手段：ClientPrefs.applyFrameTiming(idleFps) —— UNCAPPED 档完全无视 frameRate，
 * 闲置时必须临时切到 BALANCED + 关 vsync；flixel 的 set_drawFramerate 会把帧率落到
 * stage.frameRate（本引擎 fixedTimestep = false，update/draw 同帧耦合，天然一起降）。
 * 唤醒时无参调用 applyFrameTiming() 完整还原（unlimitedFPS 用户自动切回 UNCAPPED）。
 *
 * 每帧检查挂在 stage 的 ENTER_FRAME 上而不是 FlxG.signals.preUpdate：autoPause
 * （窗口失焦暂停）会跳过 flixel 的 step，signals 不再触发，而 openfl 的 ENTER_FRAME
 * 照发 —— 失焦挂机是节能的主要场景，不能漏。
 *
 * 不降帧的场景（宁可费电）：游玩中（update 粒度变粗会影响判定）、编辑器试玩中、
 * 视频播放中（画面会卡成幻灯片）—— 见 isOccupied()。
 *
 * fpsRework 的自动对档（FPSCounter 每帧回写 window.frameRate / 每 1.5s 对齐 FlxG
 * 帧率）会和本类打架，FPSCounter 侧已用 active 标志做了守卫。
 */
class IdleFPSManager
{
	/** 当前处于节能降帧状态（FPSCounter 据此暂停回写与自动对档） */
	public static var active(default, null):Bool = false;

	static var hooked:Bool = false;
	static var lastActivityMs:Float = 0;
	static var pendingActivity:Bool = false;

	public static function init():Void
	{
		if (hooked || FlxG.stage == null) return;
		hooked = true;

		// 事件驱动：任何按键 / 鼠标按下、移动、滚轮都算活动
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onActivity);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onActivity);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onActivity);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_WHEEL, onActivity);

		// alt-tab 回来：重新获得焦点也算活动
		FlxG.signals.focusGained.add(onFocusGained);

		// 每帧检查：ENTER_FRAME 与 flixel 内部状态无关，子状态 / 编辑器 / autoPause 都照跑
		FlxG.stage.addEventListener(Event.ENTER_FRAME, onFrame);

		lastActivityMs = Lib.getTimer();
	}

	static function onActivity(_:Event) pendingActivity = true;
	static function onFocusGained() pendingActivity = true;

	static function onFrame(_:Event):Void
	{
		final now:Float = Lib.getTimer();

		if (pendingActivity || isInputHeld())
		{
			pendingActivity = false;
			lastActivityMs = now;
			if (active) wake();
			return;
		}

		if (active)
		{
			// 闲置期间落入"不许降帧"的场景 → 立刻还原
			if (isOccupied()) wake();
			return;
		}

		if (!ClientPrefs.data.idleFPSReducer) return;

		final delayMs:Float = Std.int(FlxMath.bound(ClientPrefs.data.idleFPSTime, 10, 600)) * 1000;
		if (now - lastActivityMs >= delayMs && !isOccupied())
			enterIdle();
	}

	/** 按住的键 / 鼠标 / 手柄也算活动 */
	static function isInputHeld():Bool
	{
		if (FlxG.keys.pressed.ANY) return true;
		if (FlxG.mouse.pressed || FlxG.mouse.wheel != 0) return true;
		// gamepads.list 在本 flixel fork 里是 Dynamic，不能 for-in；按标准 4 个槽位查
		for (i in 0...4)
		{
			final gamepad = FlxG.gamepads.getByID(i);
			if (gamepad != null && gamepad.pressed.ANY) return true;
		}
		return false;
	}

	/** 这些场景不降帧：游玩中（update 粒度变粗会影响判定）、编辑器试玩、视频播放 */
	static function isOccupied():Bool
	{
		if (PlayState.instance != null && !PlayState.instance.paused) return true;
		if (Std.isOfType(FlxG.state, EditorPlayState)) return true;
		if (VideoSprite.playingVideos > 0) return true;
		return false;
	}

	static function enterIdle():Void
	{
		active = true;
		ClientPrefs.applyFrameTiming(ClientPrefs.data.idleFPSValue);
	}

	static function wake():Void
	{
		if (!active) return;
		active = false;
		ClientPrefs.applyFrameTiming();
	}
}
