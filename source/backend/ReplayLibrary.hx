package backend;

import haxe.Json;

/**
 * 回放库扫描：一次扫全库、按歌名归组，供周回放挑选「每首歌一条」。
 *
 * 为什么不能每首歌扫一遍：单个 .replay 是带缩进的 JSON，通常 300KB~1MB；
 * 7 首 × N 个文件全量 Json.parse 会让菜单卡好几秒。
 *
 * 三层匹配：
 *   1. 文件名前缀预筛 `Replay_<sanitize(歌名)>_<sanitize(难度)>_`（纯 ASCII，无歧义）
 *   2. 某首歌一条前缀都没命中时才做兜底全扫（歌名标点差异）
 *   3. 只在候选上 File.getContent + Json.parse，按归一化歌名归组
 */
typedef ReplayFileInfo = {
	var filename:String;
	var fullPath:String;
	var songName:String;
	var difficultyName:String;
	/** 录制时的难度下标（语言无关，优先用它匹配） */
	var songDiff:Int;
	/** 0..100 */
	var finalAccuracy:Float;
	var finalRatingFC:String;
	var timestampMs:Float;
	var modDirectory:String;
	var contentRoot:String;
}

class ReplayLibrary
{
	/** 归一化歌名：只留字母数字，让 "Dad Battle" 与 "dad-battle" 落到同一个 key。 */
	public static function normalizeSongName(name:String):String
	{
		if (name == null) return "";
		var out = new StringBuf();
		for (i in 0...name.length)
		{
			var c = name.charAt(i).toLowerCase();
			if ((c >= "a" && c <= "z") || (c >= "0" && c <= "9"))
				out.add(c);
		}
		return out.toString();
	}

	/**
	 * 找出本周每首歌在指定难度下的全部回放。
	 * @return key = normalizeSongName(歌名)，value 可能为空数组
	 */
	public static function findForSongs(songNames:Array<String>, difficultyIndex:Int):Map<String, Array<ReplayFileInfo>>
	{
		var result:Map<String, Array<ReplayFileInfo>> = new Map();
		var wanted:Map<String, String> = new Map();
		for (name in songNames)
			wanted.set(normalizeSongName(name), name);
		for (key in wanted.keys())
			result.set(key, []);

		#if sys
		var all:Array<String> = Replay.getAllReplayFiles();
		if (all.length == 0) return result;

		var hasDiff:Bool = (difficultyIndex >= 0 && difficultyIndex < Difficulty.list.length);
		var diffName:String = hasDiff ? Difficulty.list[difficultyIndex] : Difficulty.getDefault();
		var diffSlug:String = Replay.sanitizeForFileName(diffName).toLowerCase();

		// ---- 1) 文件名前缀预筛 ----
		var candidates:Array<String> = [];
		var hitSongs:Map<String, Bool> = new Map();
		for (rel in all)
		{
			var file:String = rel.substr(rel.lastIndexOf('/') + 1);
			for (key in wanted.keys())
			{
				var prefix:String = 'Replay_' + Replay.sanitizeForFileName(wanted.get(key)) + '_' + diffSlug + '_';
				if (file.indexOf(prefix) == 0)
				{
					candidates.push(rel);
					hitSongs.set(key, true);
					break;
				}
			}
		}

		// ---- 2) 有歌一条都没命中 → 兜底全扫 ----
		var needFullScan:Bool = false;
		for (key in wanted.keys())
		{
			if (!hitSongs.exists(key)) needFullScan = true;
		}

		var pool:Array<String> = candidates.copy();
		if (needFullScan)
		{
			var seen:Map<String, Bool> = new Map();
			for (rel in pool) seen.set(rel, true);
			for (rel in all)
			{
				if (!seen.exists(rel)) pool.push(rel);
			}
		}

		// ---- 3) 只解析候选 ----
		for (rel in pool)
		{
			var info:ReplayFileInfo = parseFile(rel);
			if (info == null) continue;

			var key:String = normalizeSongName(info.songName);
			if (!result.exists(key)) continue; // 不是本周的歌

			// 难度匹配优先用 songDiff（语言无关）；老档缺失才退回难度名比较
			if (hasDiff)
			{
				var diffOk:Bool = (info.songDiff >= 0)
					? (info.songDiff == difficultyIndex)
					: (normalizeSongName(info.difficultyName) == normalizeSongName(diffName));
				if (!diffOk) continue;
			}

			result.get(key).push(info);
		}
		#end

		return result;
	}

	/** 准确率最高的一条；同分取更新的。列表为空返回 null。 */
	public static function bestByAccuracy(list:Array<ReplayFileInfo>):ReplayFileInfo
	{
		if (list == null || list.length == 0) return null;

		var best:ReplayFileInfo = list[0];
		for (i in 1...list.length)
		{
			var cur:ReplayFileInfo = list[i];
			if (cur.finalAccuracy > best.finalAccuracy
				|| (cur.finalAccuracy == best.finalAccuracy && cur.timestampMs > best.timestampMs))
				best = cur;
		}
		return best;
	}

	#if sys
	static function parseFile(rel:String):ReplayFileInfo
	{
		var fullPath:String = Replay.getReplayRootDir() + rel;
		try
		{
			if (!FileSystem.exists(fullPath)) return null;

			var data:Dynamic = Json.parse(File.getContent(fullPath));
			if (data == null || (data.songName == null && data.difficultyName == null)) return null;

			var songDiff:Int = -1;
			if (data.songDiff != null)
			{
				var rawDiff:Float = data.songDiff;
				songDiff = Std.int(rawDiff);
			}

			var acc:Float = 0;
			if (data.finalAccuracy != null)
			{
				var rawAcc:Float = data.finalAccuracy;
				acc = rawAcc;
			}

			var mtimeMs:Float = 0;
			try
			{
				mtimeMs = FileSystem.stat(fullPath).mtime.getTime();
			}
			catch (e:Dynamic) {}

			return {
				filename: rel.substr(rel.lastIndexOf('/') + 1),
				fullPath: fullPath,
				songName: Std.string(data.songName),
				difficultyName: (data.difficultyName != null) ? Std.string(data.difficultyName) : "",
				songDiff: songDiff,
				finalAccuracy: acc,
				finalRatingFC: (data.finalRatingFC != null) ? Std.string(data.finalRatingFC) : "",
				timestampMs: mtimeMs,
				modDirectory: (data.modDirectory != null) ? Std.string(data.modDirectory) : "",
				contentRoot: (data.chartContentRoot != null) ? Std.string(data.chartContentRoot) : ""
			};
		}
		catch (e:Dynamic)
		{
			trace('[ReplayLibrary] skip unreadable replay: $rel ($e)');
			return null;
		}
	}
	#end
}
