package debug;

/**
 * 会话日志文件：把屏幕日志的每一行同时落盘到 crash/latest.log。
 * 布局照 Minecraft 的 logs/latest.log —— 启动时把上一次的日志挪成 latest.1.log，
 * 这样原生崩溃（0xc0000005 / 栈溢出）之后重启，仍能翻到崩溃前的最后几行：
 * 那类崩溃不走 UncaughtError 处理器，也不会生成 Frozen_Engine_<时间>.txt。
 * 每行写完立即 flush：stdio 缓冲在进程内存里，进程被原生异常杀掉时会一起丢。
 * 开关 = ClientPrefs.data.sessionLog（Advanced → Debug → Save Session Log）。
 */
class LogFile
{
	static inline var DIR:String = 'crash/';
	static inline var CURRENT:String = 'crash/latest.log';
	static inline var PREVIOUS:String = 'crash/latest.1.log';

	#if sys
	static var out:sys.io.FileOutput = null;
	/** 写失败（目录只读 / 磁盘满）之后不再重试 */
	static var broken:Bool = false;
	/** 本次进程已经轮转过。轮转只做一次，之后开关只影响读写 */
	static var started:Bool = false;
	#end

	/**
	 * 会话入口：轮转上一份日志并开好文件。重复调用无副作用。
	 *
	 * 必须在 `ClientPrefs.loadPrefs()` 之后调用（现在是 `TitleState.create`）：
	 * 存档没读出来时只能拿到默认值，关掉日志的玩家也会被建一份文件、
	 * 还会把上一次会话的日志挤成 latest.1.log。
	 */
	public static function start():Void
	{
		#if sys
		if (started || broken) return;
		started = true;

		if (!wanted()) return;   // 关着：不建文件、也不轮转
		rotate();
		open();
		#end
	}

	/** 追加一段文本。带换行的会按行拆开，每行前面补时间戳。 */
	public static function append(text:String):Void
	{
		#if sys
		if (!started || broken || text == null) return;

		// 每行都对一次开关：哪套设置菜单改的都能立刻生效，不用各写一份回调
		if (!wanted())
		{
			close();
			return;
		}
		if (out == null) open();
		if (out == null) return;

		for (line in text.split('\n'))
		{
			var s:String = line.rtrim();
			if (s.length == 0) continue;
			write('[' + DateTools.format(Date.now(), '%H:%M:%S') + '] ' + s);
		}
		#end
	}

	public static function close():Void
	{
		#if sys
		if (out == null) return;
		try
		{
			out.close();
		}
		catch (e:Dynamic) {}
		out = null;
		#end
	}

	/** 设置项的值；存档还没加载时按"开"处理 */
	inline static function wanted():Bool
	{
		return ClientPrefs.data == null || ClientPrefs.data.sessionLog;
	}

	/** 上一份日志挪成 latest.1.log */
	static function rotate():Void
	{
		#if sys
		try
		{
			if (!sys.FileSystem.exists(CURRENT)) return;
			if (sys.FileSystem.exists(PREVIOUS)) sys.FileSystem.deleteFile(PREVIOUS);
			sys.FileSystem.rename(CURRENT, PREVIOUS);
		}
		catch (e:Dynamic) {}
		#end
	}

	/** 以追加模式打开（文件不存在就建）。关掉再打开会补一行新表头。 */
	static function open():Void
	{
		#if sys
		if (out != null || broken) return;

		try
		{
			if (!sys.FileSystem.exists(DIR)) sys.FileSystem.createDirectory(DIR);
			out = sys.io.File.append(CURRENT, false);
			write('=== Frozen Engine log start: ' + Date.now().toString() + ' / ' + Sys.systemName() + ' ===');
		}
		catch (e:Dynamic)
		{
			broken = true;
			out = null;
		}
		#end
	}

	static function write(line:String):Void
	{
		#if sys
		if (out == null) return;

		try
		{
			out.writeString(line + '\n');
			out.flush();
		}
		catch (e:Dynamic)
		{
			broken = true;
			try
			{
				out.close();
			}
			catch (e:Dynamic) {}
			out = null;
		}
		#end
	}
}
