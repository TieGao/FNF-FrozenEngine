package backend;

import haxe.Json;
import backend.WeekData.WeekFile;

/**
 * NMVMODS 内容包读取：content/NMVMODS/<mod>/ 下 NMV 布局的周定义。
 *
 * NMV 的周定义是 JSON（<mod>/data/weeks/*.json，回退 <mod>/weeks/*.json），
 * schema 与 FE 不同，必须重排后再交给 WeekData：
 *   NMV 元组：[歌名, 图标, 颜色, 立绘, 曲师, ?解锁条件, ?豆子价, ?金锁]
 *   FE  元组：[歌名, 角色, 颜色, 音乐人, [各难度谱师]]
 * 第 3/4 项语义不同，直接喂会让音乐人显示成立绘名、谱师显示成解锁条件里的歌名。
 */
class NMVContentData
{
	public static final GROUP:String = 'NMVMODS';
	public static final ROOT:String = Paths.CONTENT_ROOT + '/' + GROUP;

	/** 当前启用的 NMV 包目录名（content/NMVMODS/<mod>）；空 = 未启用 NMV 模式。 */
	public static var currentMod:String = null;

	#if sys
	/** content/NMVMODS 下的包目录名（按名称排序）。 */
	public static function listMods():Array<String>
	{
		var result:Array<String> = [];
		if (!FileSystem.exists(ROOT)) return result;

		for (name in FileSystem.readDirectory(ROOT))
		{
			if (name.startsWith('.')) continue;
			if (FileSystem.isDirectory('$ROOT/$name')) result.push(name);
		}
		result.sort(Reflect.compare);
		return result;
	}

	/** 包显示名：meta.json 的 name，回退目录名。 */
	public static function getTitle(mod:String):String
	{
		if (mod == null || mod.length == 0) return '';

		var path:String = '$ROOT/$mod/meta.json';
		if (!FileSystem.exists(path)) return mod;

		try
		{
			var data:Dynamic = Json.parse(File.getContent(path));
			var name:Dynamic = Reflect.field(data, 'name');
			if (name != null && Std.isOfType(name, String) && (cast name:String).length > 0) return cast name;
		}
		catch (e:Dynamic) {}

		return mod;
	}

	/**
	 * 包内的周定义文件（绝对/相对仓库根路径）。
	 * NMV 的约定是 data/weeks 优先、没有才回退 weeks；freeplay 子目录是分区定义，跳过。
	 */
	public static function listWeekFiles(mod:String):Array<String>
	{
		var result:Array<String> = [];
		if (mod == null || mod.length == 0) return result;

		var dir:String = '$ROOT/$mod/data/weeks';
		if (!FileSystem.exists(dir)) dir = '$ROOT/$mod/weeks';
		if (!FileSystem.exists(dir)) return result;

		for (file in FileSystem.readDirectory(dir))
		{
			if (!file.endsWith('.json')) continue;
			if (FileSystem.isDirectory('$dir/$file')) continue;
			result.push('$dir/$file');
		}
		result.sort(Reflect.compare);
		return result;
	}

	/** 读一个 NMV 周定义并转成 FE 的 WeekFile；不可用时返回 null。 */
	public static function readWeek(path:String):Null<WeekFile>
	{
		if (!FileSystem.exists(path)) return null;

		var raw:Dynamic = null;
		try
		{
			raw = Json.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('NMVContentData: failed to parse $path ($e)');
			return null;
		}
		if (raw == null) return null;

		var songs:Array<Dynamic> = convertSongs(Reflect.field(raw, 'songs'));
		if (songs.length == 0) return null;

		var out:WeekFile = WeekData.createWeekFile();
		out.songs = songs;

		var storyName:String = readString(raw, 'storyName');
		var weekName:String = readString(raw, 'weekName');
		if (weekName.length == 0) weekName = storyName;
		if (storyName.length == 0) storyName = weekName;

		out.storyName = storyName;
		out.weekName = weekName;
		out.weekBefore = readString(raw, 'weekBefore');
		out.weekCharacters = ['bf', 'bf', 'gf'];
		out.weekBackground = '';
		// NMV 的 section 是字符串分区名（story/bonus/henry…），FE 的 section 是 Int，丢弃
		out.section = 0;
		out.startUnlocked = readBool(raw, 'startUnlocked', false);
		out.hiddenUntilUnlocked = readBool(raw, 'hiddenUntilUnlocked', false);
		out.hideStoryMode = readBool(raw, 'hideStoryMode', false);
		out.hideFreeplay = readBool(raw, 'hideFreeplay', false);
		out.difficulties = '';
		return out;
	}

	/** NMV 元组 → FE 元组。立绘名（第 3 项）丢弃，曲师（第 4 项）提到 FE 的音乐人位置。 */
	static function convertSongs(raw:Dynamic):Array<Dynamic>
	{
		var out:Array<Dynamic> = [];
		if (raw == null || !Std.isOfType(raw, Array)) return out;

		for (entry in (cast raw:Array<Dynamic>))
		{
			if (!Std.isOfType(entry, Array)) continue;
			var tuple:Array<Dynamic> = cast entry;
			if (tuple.length < 1 || tuple[0] == null) continue;

			var name:String = Std.string(tuple[0]);
			if (name.length == 0) continue;

			var icon:String = (tuple.length > 1 && tuple[1] != null) ? Std.string(tuple[1]) : 'bf';
			var color:Array<Int> = [146, 113, 253];

			if (tuple.length > 2 && Std.isOfType(tuple[2], Array))
			{
				var channels:Array<Dynamic> = cast tuple[2];
				if (channels.length >= 3)
					color = [Std.int(channels[0]), Std.int(channels[1]), Std.int(channels[2])];
			}

			var composer:String = (tuple.length > 4 && tuple[4] != null) ? Std.string(tuple[4]) : '';
			if (composer.length > 0)
				out.push([name, icon, color, composer]);
			else
				out.push([name, icon, color]);
		}

		return out;
	}

	static function readString(data:Dynamic, field:String):String
	{
		var value:Dynamic = Reflect.field(data, field);
		if (value == null || !Std.isOfType(value, String)) return '';
		return cast value;
	}

	static function readBool(data:Dynamic, field:String, fallback:Bool):Bool
	{
		var value:Dynamic = Reflect.field(data, field);
		if (value == null || !Std.isOfType(value, Bool)) return fallback;
		return cast value;
	}
	#end
}
