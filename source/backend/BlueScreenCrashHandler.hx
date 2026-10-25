package backend;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.UncaughtErrorEvent;
import openfl.text.Font;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;

import haxe.CallStack;
import haxe.io.Path;
import lime.app.Application;
import sys.FileSystem;
import sys.io.File;

/**
 * 崩溃处理：捕获 Haxe 层未捕获异常，写崩溃报告，并按设置决定用蓝屏界面还是原生弹窗呈现。
 *
 * 本体是挂在 `FlxG.game` 上的 openfl Sprite（与 `debug.ScreenLog` 同层），靠自己的
 * ENTER_FRAME 与键盘事件工作，不依赖 `FlxG.state` / `FlxGame.step` —— 崩坏的 state
 * 每帧抛异常时它照样能画出来、照样能响应按键。
 *
 * ⚠️ `onUncaughtError` 运行在 `Stage.__handleError` 的 catch 块里，那个调用自身没有被 try 包住，
 * 从这里逃逸的异常会直接穿过原生层杀掉进程。整条崩溃路径必须不抛异常，catch 体保持空。
 */
class BlueScreenCrashHandler extends Sprite
{
	// 蓝屏底色（Windows 10 的 #0078D7）
	static inline var BSOD_BLUE:Int = 0xFF0078D7;
	static inline var PANEL_COLOR:Int = 0x00529E;
	static inline var PANEL_BORDER:Int = 0x8CC7F5;
	static inline var TEXT_COLOR:Int = 0xFFFFFFFF;
	static inline var TEXT_DIM:Int = 0xD6E6F5;

	/** 字体硬编码，不做回退链 */
	static inline var FONT_PATH:String = 'assets/fonts/HarmonyOS_Sans_SC_Medium.ttf';
	static inline var REPO_URL:String = 'https://github.com/TieGao/FNF-FrozenEngine/issues';

	// 布局按 FlxG.width x FlxG.height（1280x720）设计，实际由 stageHeight / FlxG.height 整体缩放
	static inline var MARGIN:Float = 60;
	static inline var EMOTICON_Y:Float = 20;
	static inline var EMOTICON_SIZE:Int = 76;
	static inline var LINE1_Y:Float = 140;
	static inline var LINE2_Y:Float = 180;
	static inline var LINE3_Y:Float = 208;
	static inline var CODE_Y:Float = 254;
	static inline var DIVIDER_Y:Float = 292;
	static inline var STACK_HEAD_Y:Float = 302;
	static inline var STACK_BOX_Y:Float = 328;
	static inline var FOOTER_Y:Float = 652;
	static inline var HINT_Y:Float = 674;
	/** 堆栈框距底部的留白 */
	static inline var STACK_BOTTOM_GAP:Float = 76;

	/** 同一条消息在这个窗口内重复出现时只处理一次（崩坏的 update 会每帧抛） */
	static inline var DEDUP_WINDOW:Float = 2.0;
	/** 蓝屏停留多久后自动回标题界面（秒），设置项读不到时的默认值 */
	static inline var DEFAULT_AUTO_RETURN:Int = 15;
	/** 连续崩这么多次就不再给界面，直接原生弹窗退出（避免"崩→回标题→又崩"死循环） */
	static inline var MAX_RECOVERIES:Int = 5;

	static var instance:BlueScreenCrashHandler = null;
	static var installed:Bool = false;
	static var fontFamily:String = 'HarmonyOS Sans SC';

	/** 本次进程是否已经弹过原生弹窗（阻塞式，最多一次） */
	static var nativePopupShown:Bool = false;
	static var lastMessage:String = null;
	static var lastTime:Float = 0;
	/** 本次进程已经崩过几次（用来兜住反复崩溃） */
	static var crashCount:Int = 0;

	/**
	 * 注册未捕获异常监听。`CRASH_HANDLER` 打开时由 `Main.setupGame()` 调用。
	 */
	public static function install():Void
	{
		if (installed) return;
		installed = true;

		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
	}

	/**
	 * 挂到 `FlxG.game`。必须在 `new FlxGame(...)` 之后调用；
	 * 挂得比 `debug.ScreenLog` 晚，所以画在它上面。
	 */
	public static function attach():Void
	{
		if (instance != null || FlxG.game == null) return;

		instance = new BlueScreenCrashHandler();
		FlxG.game.addChild(instance);
	}

	// =========================================================
	// 异常入口
	// =========================================================

	static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		try
		{
			if (e != null)
			{
				// 必须在其它操作之前：不 preventDefault 的话 OpenFL 会打印后重新抛出
				e.preventDefault();
				e.stopPropagation();
				e.stopImmediatePropagation();
			}
			handle(e);
		}
		catch (_:Dynamic)
		{
			// 故意留空：Std.string / trace / Sys.println 自身都可能抛
		}
	}

	static function handle(e:UncaughtErrorEvent):Void
	{
		var message:String = '';
		try message = Std.string(e == null ? null : e.error) catch (_:Dynamic) {}

		// 崩坏的 state 每帧都在抛，同一条消息只处理一次
		var now:Float = haxe.Timer.stamp();
		if (message == lastMessage && now - lastTime < DEDUP_WINDOW) return;
		lastMessage = message;
		lastTime = now;

		var stackFrames:Array<String> = collectStack();

		// 报告正文与原 CrashHandler 完全一致
		var report:String = buildReport(message, stackFrames);
		var savedPath:String = saveReport(report);

		#if DISCORD_ALLOWED
		try DiscordClient.shutdown() catch (_:Dynamic) {}
		#end

		crashCount++;
		if (crashCount > MAX_RECOVERIES)
		{
			// 反复崩（回标题也崩之类）就别再给界面了，退回原生弹窗 + 退出
			if (!nativePopupShown)
			{
				nativePopupShown = true;
				try Application.current.window.alert(report, 'Error!') catch (_:Dynamic) {}
			}
			exitGame();
			return;
		}

		var blueScreen:Bool = false;
		try blueScreen = (ClientPrefs.data != null && ClientPrefs.data.blueScreen) catch (_:Dynamic) {}

		if (blueScreen)
		{
			var shown:Bool = false;
			try
			{
				// 崩在 attach 之前（早期加载阶段）时补挂一次
				if (instance == null) attach();
				if (instance != null) shown = instance.showBlueScreen(message, stackFrames, report, savedPath);
			}
			catch (_:Dynamic) {}
			if (shown) return;
		}

		// 设置关掉 / 界面建不出来 / 崩在 attach 之前：退回原来的原生弹窗 + 退出
		if (!nativePopupShown)
		{
			nativePopupShown = true;
			try Application.current.window.alert(report, 'Error!') catch (_:Dynamic) {}
		}
		exitGame();
	}

	/**
	 * 收集堆栈。优先 hxcpp 原生帧（`类::函数::文件::行号`），拿不到时退回格式化后的 Haxe 栈。
	 */
	static function collectStack():Array<String>
	{
		var frames:Array<String> = [];

		#if cpp
		try
		{
			var native:Array<String> = haxe.NativeStackTrace.exceptionStack();
			if (native != null)
				for (frame in native)
					if (frame != null && frame.length > 0) frames.push(frame);
		}
		catch (_:Dynamic) {}
		#end

		if (frames.length > 0) return frames;

		try
		{
			for (item in CallStack.exceptionStack(true))
			{
				switch (item)
				{
					case FilePos(_, file, line, _):
						frames.push((file == null ? '<unknown>' : file) + ':' + line);
					default:
						frames.push(Std.string(item));
				}
			}
		}
		catch (_:Dynamic) {}

		return frames;
	}

	/** 报告正文，格式与原来的 `Main.onCrash` 逐行一致。 */
	static function buildReport(message:String, stackFrames:Array<String>):String
	{
		var errMsg:String = '';

		try
		{
			for (stackItem in CallStack.exceptionStack(true))
			{
				switch (stackItem)
				{
					case FilePos(_, file, line, _):
						errMsg += file + ' (line ' + line + ')\n';
					default:
						Sys.println(stackItem);
				}
			}
		}
		catch (_:Dynamic) {}

		errMsg += '\nUncaught Error: ' + message;
		#if officialBuild
		errMsg += '\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine';
		#end
		errMsg += '\n\n> Crash Handler written by: sqirra-rng';
		errMsg += '\n> Session log: crash/latest.log';

		return errMsg;
	}

	/** 落盘 + 进会话日志 + 命令行输出。返回报告路径，失败返回 null。 */
	static function saveReport(report:String):String
	{
		var path:String = null;

		try
		{
			var dateNow:String = Date.now().toString();
			dateNow = dateNow.replace(' ', '_');
			dateNow = dateNow.replace(':', "'");
			path = './crash/' + 'Frozen_Engine_' + dateNow + '.txt';

			if (!FileSystem.exists('./crash/'))
				FileSystem.createDirectory('./crash/');

			File.saveContent(path, report + '\n');

			// 崩溃信息也进会话日志，latest.log 的尾巴就是崩溃现场
			debug.LogFile.append(report);
			debug.LogFile.close();

			Sys.println(report);
			Sys.println('Crash dump saved in ' + Path.normalize(path));
		}
		catch (_:Dynamic) {}

		return path;
	}

	/** 由异常消息推导一个 Windows 风格的停止代码。 */
	static function stopCodeFor(message:String):String
	{
		var m:String = message == null ? '' : message.toLowerCase();

		if (m.indexOf('null object reference') > -1 || m.indexOf('null pointer') > -1) return 'NULL_OBJECT_REFERENCE';
		if (m.indexOf('index out of range') > -1 || m.indexOf('array index') > -1 || m.indexOf('out of bounds') > -1) return 'INDEX_OUT_OF_RANGE';
		if (m.indexOf('division by zero') > -1 || m.indexOf('divide by zero') > -1) return 'DIVIDE_BY_ZERO';
		if (m.indexOf('stack overflow') > -1 || m.indexOf('too much recursion') > -1) return 'STACK_OVERFLOW';
		if (m.indexOf('not found') > -1 || m.indexOf('no such file') > -1 || m.indexOf('missing') > -1) return 'ASSET_NOT_FOUND';
		if (m.indexOf('lua') > -1 || m.indexOf('hscript') > -1 || m.indexOf('script') > -1 || m.indexOf('attempt to') > -1) return 'SCRIPT_RUNTIME_ERROR';
		if (m.indexOf('invalid') > -1) return 'INVALID_PARAMETER';

		return 'CRITICAL_PROCESS_DIED';
	}

	static function exitGame():Void
	{
		try Main.saveSessionPlaytime() catch (_:Dynamic) {}
		Sys.exit(1);
	}

	/** 设置里的"崩溃测试"按钮：故意触发一次空对象崩溃，用来验证整条崩溃链路。 */
	public static function simulateNullCrash():Void
	{
		#if CRASH_HANDLER
		var sprite:FlxSprite = null;
		sprite.updateHitbox();
		#else
		try Application.current.window.alert('This build was compiled without CRASH_HANDLER.', 'Crash Test') catch (_:Dynamic) {}
		#end
	}

	/** 取 Project.xml 里的 app version，读不到就显示 unknown。 */
	static function engineVersion():String
	{
		try
		{
			var ver:Dynamic = Application.current.meta.get('version');
			if (ver != null) return Std.string(ver);
		}
		catch (_:Dynamic) {}
		return 'unknown';
	}

	// =========================================================
	// 界面
	// =========================================================

	var bg:Shape;
	var panel:Shape;
	var scrollBar:Shape;
	var emoticon:TextField;
	var line1:TextField;
	var line2:TextField;
	var line3:TextField;
	var codeLine:TextField;
	var stackHeader:TextField;
	var stackField:TextField;
	var footer:TextField;
	var hint:TextField;
	var toast:TextField;

	var reportText:String = '';
	var active:Bool = false;
	var toastTimer:Float = 0;
	var lastScale:Float = 1;
	/** 距离自动回标题界面还剩多少秒 */
	var autoReturn:Float = DEFAULT_AUTO_RETURN;
	/** 设置里把停留时间设成 0 = 不自动返回，只等按键 */
	var autoReturnEnabled:Bool = true;
	/** 上次算增量用的时间戳，用 Timer 而不是 FlxG.elapsed —— 游戏循环挂了也能走 */
	var lastStamp:Float = 0;
	/** hint 上当前显示的秒数，-2 = 还没算过、-1 = 不显示倒计时 */
	var hintSecond:Int = -2;

	public function new()
	{
		super();

		visible = false;
		mouseEnabled = false;
		mouseChildren = false;

		loadFont();
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	static function loadFont():Void
	{
		try
		{
			var font:Font = Font.fromFile(FONT_PATH);
			if (font != null && font.fontName != null && font.fontName.length > 0) fontFamily = font.fontName;
		}
		catch (_:Dynamic) {}
	}

	/**
	 * 建界面并接管屏幕。返回 false 表示没能显示（调用方退回原生弹窗）。
	 */
	function showBlueScreen(message:String, stackFrames:Array<String>, report:String, savedPath:String):Bool
	{
		if (stage == null) return false;

		reportText = report;

		var seconds:Int = DEFAULT_AUTO_RETURN;
		try if (ClientPrefs.data != null) seconds = ClientPrefs.data.blueScreenTime catch (_:Dynamic) {}
		autoReturnEnabled = seconds > 0;
		autoReturn = autoReturnEnabled ? seconds : 0;

		buildUi(message, stackFrames, savedPath);

		active = true;
		visible = true;
		hintSecond = -2;
		lastStamp = haxe.Timer.stamp();

		// 只压日志叠加；音乐不动，崩溃界面弹出来时曲子照放
		try debug.ScreenLog.suppressed = true catch (_:Dynamic) {}

		try stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown) catch (_:Dynamic) {}
		try stage.addEventListener(MouseEvent.MOUSE_WHEEL, onWheel) catch (_:Dynamic) {}

		return true;
	}

	function buildUi(message:String, stackFrames:Array<String>, savedPath:String):Void
	{
		// 二次崩溃会重建界面，先清掉上一次的
		removeChildren();

		var w:Float = FlxG.width;
		var h:Float = FlxG.height;
		var contentW:Float = w - MARGIN * 2;

		bg = new Shape();
		bg.graphics.beginFill(BSOD_BLUE);
		bg.graphics.drawRect(0, 0, w, h);
		bg.graphics.endFill();
		addChild(bg);

		var boxH:Float = h - STACK_BOX_Y - STACK_BOTTOM_GAP;
		panel = new Shape();
		panel.graphics.beginFill(PANEL_COLOR, 0.55);
		panel.graphics.drawRect(MARGIN, STACK_BOX_Y, contentW, boxH);
		panel.graphics.endFill();
		panel.graphics.lineStyle(1, PANEL_BORDER, 0.6);
		panel.graphics.drawRect(MARGIN, STACK_BOX_Y, contentW, boxH);
		addChild(panel);

		emoticon = makeText(EMOTICON_SIZE, TEXT_COLOR, MARGIN, EMOTICON_Y);
		emoticon.text = ':(';

		line1 = makeText(21, TEXT_COLOR, MARGIN, LINE1_Y, contentW);
		line1.text = Language.getPhrase('crash.bsod.line1', 'Your game ran into a problem and needs to close.');

		line2 = makeText(17, TEXT_COLOR, MARGIN, LINE2_Y, contentW);
		line2.text = Language.getPhrase('crash.bsod.line2', 'If you are sure this is caused by the engine, please report it to')
			+ ' ' + REPO_URL;

		line3 = makeText(17, TEXT_COLOR, MARGIN, LINE3_Y, contentW);
		line3.text = Language.getPhrase('crash.bsod.line3',
			'If you need help from someone else, send them the newest report txt under crash/ together with latest.log.');

		codeLine = makeText(19, TEXT_COLOR, MARGIN, CODE_Y, contentW);
		codeLine.text = Language.getPhrase('crash.bsod.code', 'Error code') + ': ' + stopCodeFor(message);

		stackHeader = makeText(15, TEXT_DIM, MARGIN, STACK_HEAD_Y, contentW);
		stackHeader.text = Language.getPhrase('crash.bsod.stack', 'Stack trace');

		var boxH:Float = h - STACK_BOX_Y - STACK_BOTTOM_GAP;
		stackField = makeText(13, TEXT_COLOR, MARGIN + 10, STACK_BOX_Y + 8);
		stackField.autoSize = TextFieldAutoSize.NONE;
		stackField.wordWrap = true;
		stackField.multiline = true;
		stackField.width = contentW - 26;
		stackField.height = boxH - 16;
		// 滚轮统一由本类的 stage 监听处理，避免和 TextField 自带的滚动叠加成两倍速
		stackField.mouseWheelEnabled = false;
		stackField.text = formatStack(message, stackFrames);

		scrollBar = new Shape();
		addChild(scrollBar);
		updateScrollBar();

		footer = makeText(12, TEXT_DIM, MARGIN, FOOTER_Y, contentW);
		footer.text = 'Frozen Engine ' + engineVersion() + ' · ' + Date.now().toString() + ' · '
			+ (savedPath == null ? 'crash/latest.log' : Path.normalize(savedPath));

		hint = makeText(12, TEXT_DIM, MARGIN, HINT_Y, contentW);
		updateHint();

		toast = makeText(14, TEXT_COLOR, MARGIN, HINT_Y - 24, contentW);
		toast.text = '';
	}

	/** 底部提示行：带自动返回倒计时，秒数变了才重建文本。 */
	function updateHint():Void
	{
		if (hint == null) return;

		if (!autoReturnEnabled)
		{
			if (hintSecond == -1) return;
			hintSecond = -1;
			hint.text = Language.getPhrase('crash.bsod.hint_nocount',
				'ESC to return to the title screen · C to copy · O to open crash folder · wheel to scroll');
			return;
		}

		var seconds:Int = Std.int(Math.ceil(autoReturn));
		if (seconds < 0) seconds = 0;
		if (seconds == hintSecond) return;
		hintSecond = seconds;

		hint.text = Language.getPhrase('crash.bsod.hint',
			'Returning to the title screen in {1}s · ESC to return now · C to copy · O to open crash folder · wheel to scroll',
			[seconds]);
	}

	/** 消息一行 + 堆栈帧，堆栈统一缩进两格方便区分。 */
	function formatStack(message:String, frames:Array<String>):String
	{
		var out:String = message;
		if (frames != null)
		{
			for (frame in frames)
				out += '\n  ' + frame;
		}
		return out;
	}

	function makeText(size:Int, color:Int, x:Float, y:Float, fieldWidth:Float = 0):TextField
	{
		var field = new TextField();
		field.mouseEnabled = false;
		field.selectable = false;
		field.multiline = true;
		field.autoSize = TextFieldAutoSize.LEFT;
		field.defaultTextFormat = new TextFormat(fontFamily, size, color);
		field.x = x;
		field.y = y;
		if (fieldWidth > 0)
		{
			field.width = fieldWidth;
			field.wordWrap = true;
		}
		addChild(field);
		return field;
	}

	function updateScrollBar():Void
	{
		if (scrollBar == null || stackField == null) return;

		var boxH:Float = FlxG.height - STACK_BOX_Y - STACK_BOTTOM_GAP;
		var trackX:Float = FlxG.width - MARGIN - 6;
		var trackY:Float = STACK_BOX_Y + 6;
		var trackH:Float = boxH - 12;

		scrollBar.graphics.clear();
		if (stackField.maxScrollV <= 1)
		{
			scrollBar.graphics.beginFill(PANEL_BORDER, 0.25);
			scrollBar.graphics.drawRect(trackX, trackY, 3, trackH);
			scrollBar.graphics.endFill();
			return;
		}

		scrollBar.graphics.beginFill(PANEL_BORDER, 0.25);
		scrollBar.graphics.drawRect(trackX, trackY, 3, trackH);
		scrollBar.graphics.endFill();

		var ratio:Float = trackH / stackField.maxScrollV;
		var thumbH:Float = Math.max(24, trackH * ratio);
		var progress:Float = (stackField.scrollV - 1) / Math.max(1, stackField.maxScrollV - 1);
		var thumbY:Float = trackY + (trackH - thumbH) * progress;

		scrollBar.graphics.beginFill(PANEL_BORDER, 0.85);
		scrollBar.graphics.drawRect(trackX - 1, thumbY, 5, thumbH);
		scrollBar.graphics.endFill();
	}

	function scrollStack(delta:Int):Void
	{
		if (stackField == null) return;

		var target:Int = stackField.scrollV + delta;
		if (target < 1) target = 1;
		if (target > stackField.maxScrollV) target = stackField.maxScrollV;
		if (target == stackField.scrollV) return;

		stackField.scrollV = target;
		updateScrollBar();
	}

	function onWheel(e:MouseEvent):Void
	{
		if (!active) return;
		try scrollStack(e.delta > 0 ? 3 : -3) catch (_:Dynamic) {}
	}

	function onKeyDown(e:KeyboardEvent):Void
	{
		if (!active) return;

		try
		{
			switch (e.keyCode)
			{
				case Keyboard.ESCAPE, Keyboard.ENTER:
					recover();
				case Keyboard.C:
					openfl.system.System.setClipboard(reportText);
					showToast(Language.getPhrase('crash.bsod.copied', 'Report copied to clipboard'));
				case Keyboard.O:
					#if windows
					Sys.command('explorer', ['crash']);
					#end
				case Keyboard.UP:
					scrollStack(-1);
				case Keyboard.DOWN:
					scrollStack(1);
				case Keyboard.PAGE_UP:
					scrollStack(-10);
				case Keyboard.PAGE_DOWN:
					scrollStack(10);
				case Keyboard.HOME:
					scrollStack(-99999);
				case Keyboard.END:
					scrollStack(99999);
				default:
			}
		}
		catch (_:Dynamic) {}
	}

	function showToast(text:String):Void
	{
		if (toast == null) return;
		toast.text = text;
		toastTimer = 2.5;
	}

	/**
	 * 收起蓝屏并回到标题界面。崩坏的 state 不能再回去，所以统一重置到 TitleState。
	 * 音乐不在这里处理 —— 保持播放，TitleState 只在没有音乐时才起自己的曲子。
	 */
	function recover():Void
	{
		if (!active) return;

		active = false;
		visible = false;

		try
		{
			if (stage != null)
			{
				stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
				stage.removeEventListener(MouseEvent.MOUSE_WHEEL, onWheel);
			}
		}
		catch (_:Dynamic) {}

		try debug.ScreenLog.suppressed = false catch (_:Dynamic) {}

		// 下一次崩溃（哪怕消息一模一样）也要能重新弹出来
		lastMessage = null;

		try FlxG.switchState(new states.TitleState()) catch (_:Dynamic) {}
	}

	function onFrame(e:Event):Void
	{
		if (!active) return;

		try
		{
			// 倒计时用 Timer 而不是 FlxG.elapsed：游戏循环卡住时 elapsed 不再更新
			var now:Float = haxe.Timer.stamp();
			var delta:Float = now - lastStamp;
			lastStamp = now;
			if (delta < 0 || delta > 1) delta = 0.016;

			autoReturn -= delta;
			if (autoReturnEnabled && autoReturn <= 0)
			{
				recover();
				return;
			}
			updateHint();

			// 窗口尺寸 / 分辨率变了就跟着缩放；子对象坐标统一用 game 坐标
			var mult:Float = (FlxG.stage != null) ? FlxG.stage.stageHeight / FlxG.height : 1;
			if (mult > 0 && mult != lastScale)
			{
				lastScale = mult;
				scaleX = scaleY = mult;
			}

			if (toastTimer > 0)
			{
				toastTimer -= delta;
				if (toastTimer <= 0 && toast != null) toast.text = '';
			}

			// 文本排版在首帧之后才稳定，滚动条跟着 maxScrollV 重算
			updateScrollBar();
		}
		catch (_:Dynamic) {}
	}
}
