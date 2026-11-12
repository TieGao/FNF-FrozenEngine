package debug;

/**
 * 会话日志文件：把屏幕日志的每一行同时落盘到 crash/latest.log。
 * 布局照 Minecraft 的 logs/latest.log —— 启动时把上一次的 latest.log 挪成带时间戳的
 * 档案 crash/log_年-月-日_时-分-秒.log（时间戳取文件最后写入时刻，即上次会话
 * 结束/崩溃的时刻；老版本的 latest.1.log 也在启动时收编进这套命名），再按保留
 * 上限清掉最老的：ClientPrefs.data.sessionLogMax（Advanced → Debug → Session
 * Log Files），0 = 一份不留、1~49 = 最多留 N 份、50 = 不限制（默认 30）。
 * 这样原生崩溃（0xc0000005 / 栈溢出）之后重启，仍能翻到崩溃前的最后几行：
 * 那类崩溃不走 UncaughtError 处理器，也不会生成 Frozen_Engine_<时间>.txt。
 * 每行写完立即 flush：stdio 缓冲在进程内存里，进程被原生异常杀掉时会一起丢。
 * 开关 = ClientPrefs.data.sessionLog（Advanced → Debug → Save Session Log）。
 */
class LogFile
{
	static inline var DIR:String = 'crash/';
	static inline var CURRENT:String = 'crash/latest.log';
	/** 老版本的轮转产物，启动时收编成时间戳档案，之后跟随保留上限 */
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

		if (!wanted())
		{
			// 关着：不建文件、也不轮转，但保留上限照常清一次，旧档案不至于永远躺着
			trimArchives();
			return;
		}
		rotate();
		open();
		trimArchives();
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

	/** 启动轮转：上一次会话的 latest.log 挪成时间戳档案，老版本的 latest.1.log 一并收编 */
	static function rotate():Void
	{
		#if sys
		try
		{
			if (sys.FileSystem.exists(CURRENT)) archive(CURRENT);
			if (sys.FileSystem.exists(PREVIOUS)) archive(PREVIOUS);
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * 把一份旧日志挪成 crash/log_年-月-日_时-分-秒.log。
	 * 时间戳取文件最后写入时刻（stat.mtime），也就是那次会话结束/崩溃的时刻；
	 * stat 不到就退回当前时间。同秒重名（理论撞不上）补 _1、_2 后缀。
	 */
	static function archive(path:String):Void
	{
		#if sys
		try
		{
			var mtime:Date = Date.now();
			try
			{
				var st = sys.FileSystem.stat(path);
				if (st != null) mtime = st.mtime;
			}
			catch (e:Dynamic) {}

			var name:String = 'log_' + DateTools.format(mtime, '%Y-%m-%d_%H-%M-%S') + '.log';
			var target:String = DIR + name;
			var n:Int = 0;
			while (sys.FileSystem.exists(target) && n < 99)
			{
				n++;
				target = DIR + name.substr(0, name.length - 4) + '_' + n + '.log';
			}
			sys.FileSystem.rename(path, target);
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * 按 ClientPrefs.data.sessionLogMax 清理历史档案（crash/log_*.log）：
	 * 0 = 一份不留、1~49 = 最多留 N 份、>= 50 = 不限制。设置菜单改完立即调。
	 * 文件名里的时间戳定宽，字典序即时间序，从最老的开始删；
	 * 单个删不掉（被别的进程占用）就跳过，下次启动再试。
	 */
	public static function trimArchives():Void
	{
		#if sys
		if (ClientPrefs.data == null) return;
		var max:Int = ClientPrefs.data.sessionLogMax;
		if (max >= 50) return;

		try
		{
			if (!sys.FileSystem.exists(DIR)) return;

			var files:Array<String> = [];
			for (f in sys.FileSystem.readDirectory(DIR))
				if (StringTools.startsWith(f, 'log_') && StringTools.endsWith(f, '.log'))
					files.push(f);
			if (files.length <= max) return;

			files.sort(function(a:String, b:String) return Reflect.compare(a, b));
			for (i in 0...(files.length - max))
			{
				try sys.FileSystem.deleteFile(DIR + files[i]) catch (e:Dynamic) {}
			}
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
