package backend;

/**
 * 诊断落盘：往 crash/bread.log 逐行追加。
 *
 * 两个入口，用途不同、编译期开关不同：
 * - `crumb()` —— NMV 移植期的**探针**（舞台/角色/车道/锚点等逐项留痕）。
 *   只在 `-D NMV_BATCH` 构建里落盘，常规构建编译成空函数，一行日志都不会写。
 *   用法：`lime build windows -DNMV_BATCH`（同一个 flag 也开批量回归 harness）。
 * - `write()` —— **常驻**诊断（hscript 报错等）。任何构建都写，否则 GUI 下脚本错误
 *   完全没有落盘记录。
 *
 * 栈溢出（c00000fd）这类原生崩溃不走崩溃处理器、Haxe trace 也不落盘，
 * 靠在可疑链路里手工留痕来二分定位。
 */
class Bread
{
	public static var path:String = 'crash/bread.log';

	/**
	 * 探针留痕：仅 `NMV_BATCH` 构建有效，常规构建是空函数。
	 * 调用点保持原样即可，不需要在每处再包 `#if`。
	 */
	public static function crumb(msg:String):Void
	{
		#if NMV_BATCH
		write(msg);
		#end
	}

	/** 常驻诊断：任何构建都写（调用方自己做去重）。 */
	public static function write(msg:String):Void
	{
		try
		{
			var f:sys.io.FileOutput = sys.io.File.append(path, false);
			f.writeString(Date.now().toString() + ' ' + msg + '\n');
			f.close();
		}
		catch (e:Dynamic) {}
	}
}
