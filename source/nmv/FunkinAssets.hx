package nmv;

import flixel.FlxG;

import openfl.utils.Assets;
import openfl.utils.AssetType;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * NMV `funkin.FunkinAssets` 的 FE 等价物：按路径直接读写资源。
 *
 * NMV 的脚本先 `Paths.getPath(...)` 拿到绝对路径，再交给这里读内容（dialogue.hx 读
 * `data/dialogue/<char>.json`）。FE 的 `Assets` 只认编译期清单，内容包是运行时磁盘
 * 资源，所以一律先看文件系统。
 */
class FunkinAssets
{
	/** `haxe.Json.parse` 的安全版：解析失败返回 null 并告警，不中断脚本。 */
	public static function parseJson(content:String, ?pos:haxe.PosInfos):Dynamic
	{
		if (content == null) return null;
		try
		{
			return haxe.Json.parse(content);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('FunkinAssets.parseJson failed: $e');
			return null;
		}
	}

	/**
	 * JSON5 解析。语料里的对话 json 实际是标准 JSON，先按标准 JSON 解析；
	 * 失败再去掉注释与尾逗号重试一次（够用即可，不实现完整的 JSON5）。
	 */
	public static function parseJson5(content:String, ?pos:haxe.PosInfos):Dynamic
	{
		if (content == null) return null;

		var parsed:Dynamic = null;
		try
		{
			parsed = haxe.Json.parse(content);
		}
		catch (e:Dynamic)
		{
			try
			{
				parsed = haxe.Json.parse(_relaxJson(content));
			}
			catch (e2:Dynamic)
			{
				FlxG.log.warn('FunkinAssets.parseJson5 failed: $e2');
				return null;
			}
		}
		return parsed;
	}

	/** 去掉 `//`、`/* *\/` 注释与对象/数组里的尾逗号。 */
	static function _relaxJson(src:String):String
	{
		var out = new StringBuf();
		var i = 0;
		var len = src.length;
		var inString = false;

		while (i < len)
		{
			var c = src.charCodeAt(i);

			if (inString)
			{
				out.addChar(c);
				if (c == 92 && i + 1 < len) // 反斜杠转义
				{
					out.addChar(src.charCodeAt(i + 1));
					i += 2;
					continue;
				}
				if (c == 34) inString = false;
				i++;
				continue;
			}

			if (c == 34)
			{
				inString = true;
				out.addChar(c);
				i++;
				continue;
			}

			if (c == 47 && i + 1 < len) // '/'
			{
				var n = src.charCodeAt(i + 1);
				if (n == 47) // //
				{
					while (i < len && src.charCodeAt(i) != 10) i++;
					continue;
				}
				if (n == 42) // /*
				{
					i += 2;
					while (i + 1 < len && !(src.charCodeAt(i) == 42 && src.charCodeAt(i + 1) == 47)) i++;
					i += 2;
					continue;
				}
			}

			out.addChar(c);
			i++;
		}

		// 尾逗号：,] 或 ,}
		var text = out.toString();
		var cleaned = new StringBuf();
		var j = 0;
		while (j < text.length)
		{
			var ch = text.charCodeAt(j);
			if (ch == 44) // ','
			{
				var k = j + 1;
				while (k < text.length && (text.charCodeAt(k) == 32 || text.charCodeAt(k) == 9 || text.charCodeAt(k) == 10 || text.charCodeAt(k) == 13)) k++;
				if (k < text.length && (text.charCodeAt(k) == 93 || text.charCodeAt(k) == 125)) // ] }
				{
					j++;
					continue;
				}
			}
			cleaned.addChar(ch);
			j++;
		}
		return cleaned.toString();
	}

	public static function exists(path:String, ?type:AssetType):Bool
	{
		if (path == null) return false;
		#if sys
		if (FileSystem.exists(path)) return true;
		#end
		return Assets.exists(path, type);
	}

	public static function getContent(path:String):String
	{
		#if sys
		if (FileSystem.exists(path)) return File.getContent(path);
		#end
		if (Assets.exists(path)) return Assets.getText(path);
		throw 'Couldn\'t find file at path [$path]';
	}

	public static function getBytes(path:String):haxe.io.Bytes
	{
		#if sys
		if (FileSystem.exists(path)) return File.getBytes(path);
		#end
		if (Assets.exists(path)) return Assets.getBytes(path);
		throw 'Couldn\'t find file at path [$path]';
	}

	public static function readDirectory(directory:String):Array<String>
	{
		#if sys
		return FileSystem.exists(directory) ? FileSystem.readDirectory(directory) : [];
		#else
		return [];
		#end
	}

	public static function isDirectory(directory:String):Bool
	{
		#if sys
		return FileSystem.exists(directory) && FileSystem.isDirectory(directory);
		#else
		return false;
		#end
	}
}
