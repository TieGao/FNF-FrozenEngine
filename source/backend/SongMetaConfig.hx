package backend;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
#if MODS_ALLOWED
import backend.Mods;
#end

using StringTools;

/**
 * 歌曲补充元数据（音乐人 / 谱师）覆盖层。
 *
 * 数据来源：mods/<mod>/songMeta.json
 * {
 *   "songs": {
 *     "bopeebo": {
 *       "musican": "Kawai Sprite",
 *       "charters": ["NinjaMuffin", "PhantomArcade"]      // 数组：按难度下标
 *     },
 *     "fresh": {
 *       "musican": "Kawai Sprite",
 *       "charters": { "normal": "A", "hard": "B" }        // 映射：按难度名（优先）
 *     }
 *   }
 * }
 *
 * 优先级：songMeta.json > week.json 元组 > 不显示。
 * 文件不存在或解析失败时静默跳过，不影响启动。
 */
class SongMetaConfig
{
	private static var songToMusicanMap:Map<String, String> = new Map();
	private static var songToChartersMap:Map<String, Array<String>> = new Map();
	private static var songToCharterByNameMap:Map<String, Map<String, String>> = new Map();

	private static var loadedMods:Array<String> = [];
	// 已查过"谱面同目录 songMeta.json"的歌（key = mod:歌）。查过就记上，找不到也记
	// —— 否则每次切歌都要重查一遍磁盘。
	private static var loadedSongFiles:Array<String> = [];

	public static function loadAllConfigs():Void
	{
		resetAllConfigs();

		#if MODS_ALLOWED
		var enabledMods:Array<String> = Mods.parseList().enabled;

		for (mod in enabledMods)
		{
			if (mod != null && mod.length > 0 && mod != "base")
				tryLoadModConfig(mod);
		}

		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && Mods.currentModDirectory != "base")
		{
			if (!enabledMods.contains(Mods.currentModDirectory))
				tryLoadModConfig(Mods.currentModDirectory);
		}
		#end
	}

	public static function tryLoadModConfig(modName:String):Void
	{
		if (loadedMods.contains(modName)) return;

		var path:String = 'mods/$modName/songMeta.json';
		if (!FileSystem.exists(path)) return;

		loadedMods.push(modName);
		loadSongMeta(modName, path);
	}

	private static function loadSongMeta(modName:String, path:String):Void
	{
		try
		{
			var content:String = File.getContent(path);
			if (content == null || content.length == 0) return;

			var parsed:Dynamic = Json.parse(content);
			if (parsed == null || parsed.songs == null) return;

			for (songKey in Reflect.fields(parsed.songs))
			{
				var formattedSong:String = Paths.formatToSongPath(songKey);
				applySongEntry(modName + ":" + formattedSong, Reflect.getProperty(parsed.songs, songKey));
			}
		}
		catch (e:Dynamic)
		{
			trace('Error loading song meta from $modName: $e');
		}
	}

	/** 把一条 {musican, charters} 记进三张表。mod 级文件和谱面同目录文件共用这段。 */
	private static function applySongEntry(baseKey:String, entry:Dynamic):Void
	{
		if (entry == null) return;

		if (entry.musican != null)
		{
			var musican:String = Std.string(entry.musican);
			if (musican.length > 0)
				songToMusicanMap.set(baseKey, musican);
		}

		if (entry.charters == null) return;

		var charters:Dynamic = entry.charters;
		if (Std.isOfType(charters, Array))
		{
			var list:Array<Dynamic> = cast charters;
			var out:Array<String> = [];
			for (item in list)
				out.push(item == null ? "" : Std.string(item));
			if (out.length > 0)
				songToChartersMap.set(baseKey, out);
		}
		else
		{
			var byName:Map<String, String> = new Map();
			var namedCount:Int = 0;
			for (diffKey in Reflect.fields(charters))
			{
				var value:Dynamic = Reflect.getProperty(charters, diffKey);
				if (value == null) continue;
				byName.set(diffKey.toLowerCase().trim(), Std.string(value));
				namedCount++;
			}
			if (namedCount > 0)
				songToCharterByNameMap.set(baseKey, byName);
		}
	}

	/**
	 * 按需加载"和谱面同目录"的 songMeta.json。
	 *
	 * 为什么需要：mod 级文件固定是 mods/<mod>/songMeta.json，而引擎自带曲目在
	 * assets/shared/data/<song>/ 下、没有对应的 mod 目录，根本写不了。放谱面同目录既能
	 * 给任意一首歌单独配元数据，也方便跟着 mod 一起打包。
	 *
	 * 文件格式两种都吃：跟 mod 级一样的 {"songs": {...}}，或者整份就是一个条目
	 * （按目录名当歌曲键）。因为是按需加载、后写后赢，它比 mod 级文件优先。
	 */
	private static function tryLoadSongMetaFile(songName:String, modFolder:String):Void
	{
		var songPath:String = Paths.formatToSongPath(songName);
		var modKey:String = (modFolder == null ? "" : modFolder);
		var lookupKey:String = modKey + ":" + songPath;
		if (loadedSongFiles.contains(lookupKey)) return;
		loadedSongFiles.push(lookupKey);

		var path:String = null;
		if (modFolder != null && modFolder.length > 0 && modFolder != "base")
		{
			var modPath:String = 'mods/$modFolder/data/$songPath/songMeta.json';
			if (FileSystem.exists(modPath)) path = modPath;
		}
		if (path == null)
		{
			var sharedPath:String = Paths.getSharedPath('data/$songPath/songMeta.json');
			if (FileSystem.exists(sharedPath)) path = sharedPath;
		}
		if (path == null) return;

		try
		{
			var content:String = File.getContent(path);
			if (content == null || content.length == 0) return;

			var parsed:Dynamic = Json.parse(content);
			if (parsed == null) return;

			var baseKey:String = modKey + ":" + songPath;
			if (parsed.songs != null)
			{
				for (songKey in Reflect.fields(parsed.songs))
					applySongEntry(baseKey, Reflect.getProperty(parsed.songs, songKey));
			}
			else
			{
				// 裸条目：整份文件就是这一首歌的
				applySongEntry(baseKey, parsed);
			}
		}
		catch (e:Dynamic)
		{
			trace('Error loading song meta from $path: $e');
		}
	}

	public static function getMusicanForSong(songName:String, ?modFolder:String = null):String
	{
		if (songName == null) return null;

		tryLoadSongMetaFile(songName, modFolder);

		var formattedName:String = Paths.formatToSongPath(songName);

		if (modFolder != null && modFolder.length > 0 && modFolder != "base")
			return songToMusicanMap.get(modFolder + ":" + formattedName);

		for (key in songToMusicanMap.keys())
		{
			if (key.endsWith(":" + formattedName))
				return songToMusicanMap.get(key);
		}

		return null;
	}

	/**
	 * 按难度名优先、难度下标兜底取谱师。
	 */
	public static function getCharterForSong(songName:String, ?diffName:String = null, ?diffIdx:Int = 0, ?modFolder:String = null):String
	{
		if (songName == null) return null;

		tryLoadSongMetaFile(songName, modFolder);

		var formattedName:String = Paths.formatToSongPath(songName);
		var baseKey:String = (modFolder != null && modFolder.length > 0 && modFolder != "base")
			? modFolder + ":" + formattedName
			: null;

		var keys:Array<String> = (baseKey != null) ? [baseKey] : findKeysForSong(formattedName);
		if (keys.length == 0) return null;

		for (key in keys)
		{
			var byName:Map<String, String> = songToCharterByNameMap.get(key);
			if (byName != null && diffName != null && diffName.length > 0)
			{
				var named:String = byName.get(diffName.toLowerCase().trim());
				if (named != null && named.length > 0)
					return named;
			}

			var list:Array<String> = songToChartersMap.get(key);
			if (list != null && list.length > 0)
			{
				var idx:Int = (diffIdx == null || diffIdx < 0) ? 0 : diffIdx;
				if (idx >= list.length) idx = list.length - 1;
				var value:String = list[idx];
				if (value != null && value.length > 0)
					return value;
			}

			if (byName != null)
			{
				for (value in byName)
				{
					if (value != null && value.length > 0)
						return value;
				}
			}
		}

		return null;
	}

	private static function findKeysForSong(formattedName:String):Array<String>
	{
		var out:Array<String> = [];
		for (key in songToChartersMap.keys())
			if (key.endsWith(":" + formattedName) && !out.contains(key)) out.push(key);
		for (key in songToCharterByNameMap.keys())
			if (key.endsWith(":" + formattedName) && !out.contains(key)) out.push(key);
		return out;
	}

	private static function resetAllConfigs():Void
	{
		songToMusicanMap.clear();
		songToChartersMap.clear();
		songToCharterByNameMap.clear();
		loadedMods = [];
		loadedSongFiles = [];
	}
}
