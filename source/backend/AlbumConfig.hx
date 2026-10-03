package backend;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import openfl.utils.Assets;

/**
 * 专辑定义加载器。读 `albums/<id>.json`（id 就是文件名），供 Freeplay 显示专辑封面用。
 *
 * 查找走 Paths.getPath，所以 mod 放一份 `albums/<id>.json` 就能覆盖引擎自带的同名专辑。
 */
typedef AlbumData = {
	var name:String;
	var artists:Array<String>;
	var albumArtAsset:String; // 封面图资源键，如 "freeplay/albumRoll/volume1"
	@:optional var albumTitleAsset:String;
	@:optional var albumTitleOffsets:Array<Float>;
	@:optional var version:String;
}

class AlbumConfig
{
	private static var cache:Map<String, AlbumData> = new Map();

	/**
	 * 取专辑定义。albumId 为空、文件不存在或解析失败都返回 null —— 调用方据此隐藏封面。
	 */
	public static function getAlbum(albumId:String, ?modFolder:String = null):AlbumData
	{
		if (albumId == null || albumId.length < 1)
			return null;

		var key:String = (modFolder == null ? '' : modFolder) + ':' + albumId;
		if (cache.exists(key))
			return cache.get(key);

		var data:AlbumData = loadAlbumFile(albumId, modFolder);
		// 失败也缓存 null：Freeplay 每帧都会问，不缓存会反复读盘。
		cache.set(key, data);
		return data;
	}

	private static function loadAlbumFile(albumId:String, ?modFolder:String):AlbumData
	{
		// 必须切到目标 mod 目录再查 —— Paths.getPath 的 mod 分支读的是 Mods.currentModDirectory，
		// 不切会命中"上一个 mod"的同名专辑，或者漏掉这个 mod 自带的。
		var oldModDir:String = Mods.currentModDirectory;
		if (modFolder != null && modFolder.length > 0)
			Mods.currentModDirectory = modFolder;

		var result:AlbumData = null;
		try
		{
			var path:String = Paths.getPath('albums/$albumId.json');
			var raw:String = null;

			#if MODS_ALLOWED
			if (FileSystem.exists(path))
				raw = File.getContent(path);
			else if (Assets.exists(path))
				raw = Assets.getText(path);
			#else
			if (Assets.exists(path))
				raw = Assets.getText(path);
			#end

			if (raw != null)
			{
				var parsed:Dynamic = Json.parse(raw);
				// albumArtAsset 是唯一必需的字段：没有它就画不出封面，当作"这份定义无效"。
				if (parsed != null && parsed.albumArtAsset != null)
				{
					result = {
						name: parsed.name == null ? albumId : Std.string(parsed.name),
						artists: parsed.artists == null ? [] : cast parsed.artists,
						albumArtAsset: Std.string(parsed.albumArtAsset),
						albumTitleAsset: parsed.albumTitleAsset == null ? null : Std.string(parsed.albumTitleAsset),
						albumTitleOffsets: parsed.albumTitleOffsets,
						version: parsed.version == null ? null : Std.string(parsed.version)
					};
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('AlbumConfig: failed to load album "$albumId": $e');
		}

		Mods.currentModDirectory = oldModDir;
		return result;
	}

	/** 清缓存。Freeplay 退出时调，避免切了 mod 之后还拿着旧定义。 */
	public static function reset():Void
	{
		cache.clear();
	}
}
