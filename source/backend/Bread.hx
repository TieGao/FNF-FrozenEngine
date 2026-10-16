package backend;

/**
 * 崩溃定位面包屑：往 crash/bread.log 逐行追加。
 * 栈溢出（c00000fd）这类原生崩溃不走崩溃处理器、Haxe trace 也不落盘，
 * 靠在可疑链路里手工留痕来二分定位。问题修完后可以把调用点删掉。
 */
class Bread
{
	public static var path:String = 'crash/bread.log';

	public static function crumb(msg:String):Void
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
