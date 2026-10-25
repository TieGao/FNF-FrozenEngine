package debug;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

private typedef LogLine = {
	text:String,
	/** 连续重复次数（同一行被连着重打时只在末尾追加 xN） */
	count:Int,
	color:Int,
	/** 最后一次出现的时间戳（haxe.Timer.stamp），用来算存活时间 */
	time:Float
}

/**
 * 全局屏幕日志：把 `trace()`（也就是命令行输出）同步画到屏幕上，方便不开控制台调试。
 *
 * - 静态侧 `install()` 接管 `haxe.Log.trace`：先原样交给命令行，再压进环形缓冲。
 * - 同一批行同时落盘到 `crash/latest.log`（见 `debug.LogFile`，开关在 Advanced → Debug）。
 *   文件由 `LogFile.start()` 在 `ClientPrefs.loadPrefs()` 之后打开，这里只负责往里送行。
 * - 实例侧是一个 openfl `Sprite`，挂到 `FlxG.game`（不属于任何 FlxState），
 *   所以切界面、换 state 都不会消失，并且盖在所有 flixel 内容之上。
 * - 显示开关 = `ClientPrefs.data.screenLog`（Advanced → Show Console Log）。
 *   关掉只掐显示，trace 仍照常进命令行。
 * - 控制台式排版：最新一行贴在最下面，往上回滚；ERROR / WARN 自动染色。
 */
class ScreenLog extends Sprite
{
	/** 缓冲区上限，超出丢最旧的 */
	static inline var MAX_BUFFER:Int = 300;
	/** 单行字符上限，防止超长对象串把屏幕刷满 */
	static inline var MAX_CHARS:Int = 500;
	/** 屏幕上最多显示几行 */
	static inline var MAX_VISIBLE:Int = 14;
	/** 文本块最多占屏幕高度的比例（换行多时自动少显示几行） */
	static inline var MAX_HEIGHT_RATIO:Float = 0.5;

	static inline var FONT:String = 'vcr.ttf';
	static inline var FONT_SIZE:Int = 14;
	static inline var LINE_GAP:Float = 1;
	static inline var PAD:Float = 5;
	static inline var BASE_X:Float = 10;
	/** 起点让开左上角 FPS 计数器（y=3 起三行） */
	static inline var BASE_Y:Float = 64;
	static inline var MIN_PANEL_W:Float = 260;
	static inline var BG_ALPHA:Float = 0.45;
	/** 重排间隔：trace 可能每帧都来，别跟着每帧重画文本 */
	static inline var REBUILD_INTERVAL:Float = 1 / 20;
	/** 设置读不到时的兜底存活时长（秒） */
	static inline var DEFAULT_LIFETIME:Float = 2;

	static var buffer:Array<LogLine> = [];
	static var dirty:Bool = true;
	static var installed:Bool = false;
	static var origTrace:Dynamic = null;
	static var instance:ScreenLog = null;

	/** 崩溃界面接管屏幕时置 true，别让日志叠在蓝屏上面 */
	public static var suppressed:Bool = false;

	/**
	 * 接管 `haxe.Log.trace`。越早调用越好（`Main.setupGame()` 开头），
	 * 这样加载阶段的 trace 也能进缓冲。重复调用是安全的。
	 */
	public static function install():Void
	{
		if (installed) return;
		installed = true;

		origTrace = haxe.Log.trace;
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos):Void {
			// 命令行输出保持原样
			if (origTrace != null)
			{
				try
				{
					origTrace(v, infos);
				}
				catch (e:Dynamic) {}
			}
			pushTrace(v, infos);
		}
	}

	/** 挂到 `FlxG.game`。必须在 `new FlxGame(...)` 之后调用。 */
	public static function attach():Void
	{
		if (instance != null || FlxG.game == null) return;
		instance = new ScreenLog();
		FlxG.game.addChild(instance);
	}

	/** 外部（脚本 / 调试代码）也可以直接往屏幕上丢一行 */
	public static function add(text:String):Void
	{
		addRaw(text);
		dirty = true;
	}

	public static function clear():Void
	{
		buffer = [];
		dirty = true;
	}

	static function pushTrace(v:Dynamic, ?infos:haxe.PosInfos):Void
	{
		var str:String = Std.string(v);
		// 和原版 trace 的格式保持一致，屏幕上才能对上命令行里的行
		if (infos != null) str = '${infos.fileName}:${infos.lineNumber}: $str';
		addRaw(str);
		dirty = true;
	}

	static function addRaw(str:String):Void
	{
		if (str == null) return;
		for (line in str.split('\n'))
		{
			var text:String = line.rtrim();
			if (text.length == 0) continue;
			// 屏幕缓冲有字符上限，文件侧留全量
			LogFile.append(text);
			if (text.length > MAX_CHARS) text = text.substr(0, MAX_CHARS) + '...';
			appendLine(text);
		}
	}

	static function appendLine(text:String):Void
	{
		var last:LogLine = (buffer.length > 0) ? buffer[buffer.length - 1] : null;
		// 同一行连着刷（每帧打同一句之类）只涨计数、刷新存活时间，不占新行
		if (last != null && last.text == text)
		{
			last.count++;
			last.time = haxe.Timer.stamp();
			return;
		}

		buffer.push({text: text, count: 1, color: colorFor(text), time: haxe.Timer.stamp()});
		while (buffer.length > MAX_BUFFER) buffer.shift();
	}

	static function colorFor(text:String):Int
	{
		var up:String = text.toUpperCase();
		if (up.indexOf('ERROR') > -1 || up.indexOf('FATAL') > -1 || up.indexOf('EXCEPTION') > -1) return 0xFFFF6060;
		if (up.indexOf('WARN') > -1) return 0xFFFFD24A;
		return 0xFFFFFFFF;
	}

	/** 单行存活时长（秒）。每帧都读设置 —— KE 菜单没有 onChange，改完要立刻生效。 */
	static function lifetime():Float
	{
		var data = ClientPrefs.data;
		if (data == null) return DEFAULT_LIFETIME;

		var seconds:Int = data.screenLogLifetime;
		return seconds < 1 ? 1 : seconds;
	}

	/** 淡出时长：占存活时长的 35%，最多 1 秒 */
	static function fadeTime():Float
	{
		var fade:Float = lifetime() * 0.35;
		return fade > 1 ? 1 : fade;
	}

	/** 丢掉超过存活时间的行；有行处在淡出区间时置 dirty，让 rebuild 逐帧更新透明度。 */
	static function expireLines():Void
	{
		var life:Float = lifetime();
		var fade:Float = fadeTime();
		var now:Float = haxe.Timer.stamp();
		var i:Int = buffer.length - 1;
		while (i >= 0)
		{
			var age:Float = now - buffer[i].time;
			if (age >= life)
			{
				buffer.splice(i, 1);
				dirty = true;
			}
			else if (age >= life - fade)
			{
				dirty = true;
			}
			i--;
		}
	}

	static function lineAlpha(line:LogLine, now:Float):Float
	{
		var life:Float = lifetime();
		var fade:Float = fadeTime();
		var age:Float = now - line.time;
		if (age <= life - fade) return 1;

		var alpha:Float = (life - age) / fade;
		return alpha < 0 ? 0 : (alpha > 1 ? 1 : alpha);
	}

	// =========================================================
	// 显示侧
	// =========================================================

	var fields:Array<TextField> = [];
	var panel:Shape;
	var lastScale:Float = 1;
	var lastRebuild:Float = 0;

	public function new()
	{
		super();

		mouseEnabled = false;
		mouseChildren = false;

		panel = new Shape();
		addChild(panel);

		lastScale = (FlxG.stage != null) ? FlxG.stage.stageHeight / FlxG.height : 1;
		scaleX = scaleY = lastScale;

		rebuild();
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(e:Event):Void
	{
		if (suppressed || ClientPrefs.data == null || !ClientPrefs.data.screenLog)
		{
			visible = false;
			return;
		}
		visible = true;

		// 到期的行直接丢掉，剩下的自动顶上；淡出中的行要逐帧重排
		expireLines();

		// 窗口尺寸 / 分辨率变了就跟着缩放；子对象坐标统一用 game 坐标，缩放交给这里
		var mult:Float = (FlxG.stage != null) ? FlxG.stage.stageHeight / FlxG.height : 1;
		if (mult > 0 && mult != lastScale)
		{
			lastScale = mult;
			scaleX = scaleY = mult;
		}

		// trace 可能在任意时刻来，这里按帧合并重排，别每行都重画
		if (dirty)
		{
			var now:Float = haxe.Timer.stamp();
			if (now - lastRebuild >= REBUILD_INTERVAL)
			{
				lastRebuild = now;
				dirty = false;
				rebuild();
			}
		}
	}

	function getField(index:Int):TextField
	{
		while (fields.length <= index)
		{
			var field = new TextField();
			field.mouseEnabled = false;
			field.selectable = false;
			field.multiline = true;
			field.wordWrap = true;
			field.autoSize = TextFieldAutoSize.LEFT;
			field.defaultTextFormat = new TextFormat(FONT, FONT_SIZE, 0xFFFFFFFF);
			field.x = BASE_X;
			addChild(field);
			fields.push(field);
		}
		return fields[index];
	}

	function rebuild():Void
	{
		var fieldWidth:Float = FlxG.width - BASE_X * 2 - PAD * 2;
		var budget:Float = FlxG.height * MAX_HEIGHT_RATIO;
		var now:Float = haxe.Timer.stamp();

		// 从最新一行往回收集，受「行数」和「高度」双重限制
		var count:Int = 0;
		var totalH:Float = 0;
		var i:Int = buffer.length - 1;
		while (i >= 0 && count < MAX_VISIBLE)
		{
			var line:LogLine = buffer[i];
			var field:TextField = getField(count);
			field.width = fieldWidth;
			field.text = (line.count > 1) ? '${line.text} (x${line.count})' : line.text;
			field.textColor = line.color;
			field.alpha = lineAlpha(line, now);

			var h:Float = field.height;
			if (count > 0 && totalH + h > budget) break; // 至少留一行
			totalH += h + LINE_GAP;
			count++;
			i--;
		}

		// fields[k] 里装的是「倒数第 k 新」的一行：index 0 最新 → 画在最下面
		var y:Float = BASE_Y;
		var maxW:Float = MIN_PANEL_W;
		var k:Int = count - 1;
		while (k >= 0)
		{
			var field:TextField = fields[k];
			field.y = y;
			y += field.height + LINE_GAP;
			// 背景板按「实际最长一行」收窄，不跟着 wordWrap 的固定宽度铺满屏幕
			if (field.textWidth > maxW) maxW = field.textWidth;
			k--;
		}

		panel.graphics.clear();
		if (count > 0)
		{
			var blockH:Float = totalH - LINE_GAP;
			panel.graphics.beginFill(0x000000, BG_ALPHA);
			panel.graphics.drawRect(BASE_X - PAD, BASE_Y - PAD, maxW + PAD * 2, blockH + PAD * 2);
			panel.graphics.endFill();
		}

		// 多出来的行藏掉（下一帧要用时会被重新赋值）
		for (j in 0...fields.length)
			fields[j].visible = (j < count);
	}
}
