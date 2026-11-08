package backend;

import backend.Replay as FrameReplay;
import backend.CustomChartData;

import states.PlayState;

/**
 * 回放启动器：从一条 .replay 把「谱面上下文 + PlayState 静态入口」全部准备好。
 *
 * 原来这段逻辑长在 states/freeplay/LoadReplaySubState.loadReplay() 里，周回放（WeekReplay）
 * 也要用同一套解析，所以抽出来共用。**切状态由调用方负责**：
 *   - 单曲回放：子状态先 close()，再 LoadingState.loadAndSwitchState(new PlayState())
 *   - 周回放：直接 LoadingState.loadAndSwitchState(new PlayState(), false, false)
 *
 * 只写 PlayState.pendingReplay，不写 frameRep —— 旧 state 的 destroy() 会把 frameRep 清空，
 * 而 pendingReplay 会在新 PlayState 的 create() 里被接管。
 */
typedef ReplayLaunchOptions = {
	/** 内容包资源根兜底（单曲回放传当前浏览歌的根；周回放传本周的 contentRoot） */
	?fallbackContentRoot:String,
	/** 变体兜底（只在和上面同一个根时才采信） */
	?fallbackVariant:String,
	/** 强制难度下标（周回放：整周同一难度，不再按名字猜） */
	?forcedDifficulty:Null<Int>,
	/** 写回 PlayState.storyWeek（周回放传 weeksList 下标） */
	?weekIndex:Null<Int>,
	/** 默认 false。周回放也传 false，避免踩 story 分支的存档/成就逻辑 */
	?storyMode:Null<Bool>,
	/** 默认 true（保持单曲回放原行为）。周回放传 false，不逐首改玩家的下滚设置 */
	?applyDownscroll:Null<Bool>,
}

class ReplayLauncher
{
	/** 成功返回 null；失败返回错误文案，并把所有已写的全局回滚。 */
	public static function prepare(filePath:String, ?opts:ReplayLaunchOptions):Null<String>
	{
		trace('Loading replay: $filePath');

		var rep:FrameReplay = FrameReplay.LoadReplay(filePath);
		if (rep == null || !rep.isValid())
			return "Invalid replay file!";

		#if MODS_ALLOWED
		// 回放没记 mod 目录（base 歌 / 内容包歌）时要显式清空：
		// 否则会把上一次浏览留下的 mod 目录带进去，资源先往 mods/<m>/ 里找。
		Mods.currentModDirectory = (rep.replay.modDirectory != null && rep.replay.modDirectory.length > 0)
			? rep.replay.modDirectory : "";
		#end

		PlayState.pendingReplay = rep;
		PlayState.loadRep = true;
		PlayState.inReplay = true;
		PlayState.replayFileName = filePath;

		var difficultyID:Int = resolveDifficultyID(rep, opts);
		PlayState.storyDifficulty = difficultyID;
		PlayState.storyWeek = (opts != null && opts.weekIndex != null && opts.weekIndex >= 0) ? opts.weekIndex : 0;

		var songName:String = rep.replay.songName;
		var difficultyName:String = rep.replay.difficultyName;
		var jsonToLoad:String = songName;

		try
		{
			var fallbackRoot:String = (opts != null) ? opts.fallbackContentRoot : null;
			var fallbackVariant:String = (opts != null) ? opts.fallbackVariant : null;

			// ---- 内容包上下文 ----
			// 回放里的 chartContentRoot 是后加的字段，早期录的 PicoMix / Erect 存档没有它。
			//   1. 回放自带 chartContentRoot
			//   2. 调用方传进来的资源根
			//   3. 扫 content/VanillaSongs/* 找哪份谱面真的存在（仅当难度名自带变体前缀）
			var replayContentRoot:String = normalizeRoot(rep.replay.chartContentRoot);
			if (replayContentRoot.length == 0) replayContentRoot = normalizeRoot(fallbackRoot);
			if (replayContentRoot.length == 0)
			{
				var diffVariantHint:String = difficultyVariantHint(difficultyName);
				if (diffVariantHint != null)
				{
					var probed:String = findContentRootForChart(songName, difficultyName, diffVariantHint);
					if (probed != null) replayContentRoot = probed;
				}
			}
			if (replayContentRoot.length == 0) replayContentRoot = null;

			var replayVariant:String = (replayContentRoot != null) ? WeekData.getVariantForContentRoot(replayContentRoot) : null;
			// 周定义没登记（包被隐藏 / weeksLoaded 里查不到）时，只有调用方给的正是同一个包，
			// 才敢借用它的变体 —— 借错包会拼出别的包的音轨目录。
			if (replayVariant == null && replayContentRoot != null && fallbackRoot != null
				&& normalizeRoot(fallbackRoot) == replayContentRoot)
				replayVariant = fallbackVariant;

			// 难度名：replay.difficultyName 是 Difficulty.getString() 写进去的**翻译名**，
			// 直接拿去拼谱面文件名在 zh-TW / pt-BR 下会失败。能确认是翻译名就换回 Difficulty.list[i]。
			var nameForSuffix:String = difficultyName;
			if (difficultyID >= 0 && difficultyID < Difficulty.list.length)
			{
				var rawName:String = Difficulty.list[difficultyID];
				if (nameForSuffix == null || nameForSuffix.length == 0)
					nameForSuffix = rawName;
				else if (isTranslatedDifficulty(nameForSuffix, rawName))
					nameForSuffix = rawName;
			}
			if (nameForSuffix == null || nameForSuffix.length == 0) nameForSuffix = Difficulty.getDefault();

			var diffSuffix:String = Difficulty.getFilePathForName(stripVariantPrefix(nameForSuffix, replayVariant), replayVariant);
			jsonToLoad = songName + diffSuffix;
			trace('Loading JSON: $jsonToLoad (contentRoot=$replayContentRoot variant=$replayVariant)');

			if (rep.replay.chartCategory != null && rep.replay.chartCategory.length > 0
				&& Paths.isCustomChartCategory(rep.replay.chartCategory))
			{
				var customSongs = CustomChartData.load(rep.replay.chartCategory);
				var customSong:CustomChartSong = null;
				for (candidate in customSongs)
				{
					if (candidate.name == songName || Paths.formatToSongPath(candidate.name) == Paths.formatToSongPath(songName))
					{
						customSong = candidate;
						break;
					}
				}
				if (customSong == null)
					throw 'Custom chart not found: $songName';

				// 资源根 / 曲师谱师按谱面目录重新推导；回放里存的 chartContentRoot 只作兜底
				var contentRoot:String = customSong.contentRoot;
				if ((contentRoot == null || contentRoot.length == 0) && rep.replay.chartContentRoot != null)
					contentRoot = rep.replay.chartContentRoot;

				Paths.setChartContext(rep.replay.chartCategory, customSong.directory,
					rep.replay.chartHasVSliceMetadata, rep.replay.chartAudioSuffix,
					contentRoot, customSong.artist, customSong.charter);
				PlayState.chartCategory = Paths.currentChartCategory;
				PlayState.chartDirectory = Paths.currentChartDirectory;
				PlayState.chartHasVSliceMetadata = Paths.currentChartHasVSliceMetadata;
				PlayState.chartAudioSuffix = Paths.currentChartAudioSuffix;
				PlayState.chartContentRoot = Paths.currentContentRoot;
				PlayState.chartMetadataArtist = Paths.currentChartMetaArtist;
				PlayState.chartMetadataCharter = Paths.currentChartMetaCharter;

				PlayState.SONG = cast CustomChartData.loadChart(customSong, nameForSuffix);
				StageData.loadDirectory(PlayState.SONG);
			}
			else
			{
				// 普通歌 / 内容包回放：清掉上一次 content 浏览留下的谱面上下文，
				// 否则 PlayState.create() 会把普通歌误判成 content 模式。
				Paths.setChartContext(null, null, false, null, replayContentRoot, null, null, replayVariant);
				PlayState.clearChartContext();
				PlayState.SONG = Song.loadFromJson(jsonToLoad, songName);
			}

			if (PlayState.SONG == null) throw 'Failed to load song';

			PlayState.isStoryMode = (opts != null && opts.storyMode == true);
			if (opts == null || opts.applyDownscroll != false)
				ClientPrefs.data.downScroll = rep.replay.isDownscroll;

			return null;
		}
		catch (e:Dynamic)
		{
			trace('Error loading song: $e');
			// 失败必须回滚，否则下一个 PlayState 会捡到这个半截回放
			PlayState.pendingReplay = null;
			PlayState.loadRep = false;
			PlayState.inReplay = false;
			PlayState.replayFileName = null;
			return 'Failed to load song!\nMissing: ' + jsonToLoad + '.json';
		}
	}

	public static function resolveDifficultyID(rep:FrameReplay, ?opts:ReplayLaunchOptions):Int
	{
		if (opts != null && opts.forcedDifficulty != null) return opts.forcedDifficulty;

		var defaultID:Int = 1;
		var name:String = (rep.replay != null) ? rep.replay.difficultyName : null;
		if (name != null)
		{
			// 先按名字在当前难度表里精确匹配：变体难度名（'Pico Normal'）只有这样才能拿到
			// 正确下标，PlayState 侧 getAudioVariant() 才认得出音轨变体目录。
			var listedIndex:Int = Difficulty.list.indexOf(name);
			if (listedIndex >= 0) return listedIndex;

			var lower:String = name.toLowerCase();
			if (lower.indexOf('easy') >= 0) return 0;
			if (lower.indexOf('normal') >= 0) return 1;
			if (lower.indexOf('hard') >= 0) return 2;
		}
		return (rep.replay != null) ? rep.replay.songDiff : defaultID;
	}

	/** 判断 replay 里存的名字是不是 rawName 的翻译名（而不是自定义难度名）。 */
	static function isTranslatedDifficulty(name:String, rawName:String):Bool
	{
		if (name == null || rawName == null) return false;
		if (name == rawName) return true;
		return Language.getPhrase('difficulty_$rawName', rawName) == name;
	}

	// ---------------------------------------------------------
	// 路径 / 变体工具（原来散在 LoadReplaySubState 里，两处共用）
	// ---------------------------------------------------------
	public static function normalizeRoot(root:String):String
	{
		if (root == null) return "";
		var out:String = root.split('\\').join('/');
		while (out.length > 0 && out.charAt(out.length - 1) == '/')
			out = out.substring(0, out.length - 1);
		return out;
	}

	/** 难度名里是否自带变体前缀（旧 PicoMix 存档写的是 'Pico Normal'）。 */
	public static function difficultyVariantHint(diffName:String):String
	{
		if (diffName == null) return null;
		var lower:String = diffName.toLowerCase();
		if (lower.indexOf('pico') >= 0) return 'pico';
		if (lower.indexOf('erect') >= 0) return 'erect';
		if (lower == 'nightmare' || lower == 'hmnf') return 'erect';
		return null;
	}

	/** 旧 PicoMix 存档的难度名自带变体前缀（'Pico Normal'），拼文件名前先剥掉。 */
	public static function stripVariantPrefix(diffName:String, variant:String):String
	{
		if (diffName == null) return null;
		if (variant == null || variant.length == 0) return diffName;

		var lower:String = diffName.toLowerCase();
		var v:String = variant.toLowerCase();
		if (lower.indexOf(v) != 0) return diffName;

		var rest:String = diffName.substring(variant.length);
		while (rest.length > 0 && (rest.charAt(0) == ' ' || rest.charAt(0) == '-'))
			rest = rest.substring(1);
		// 整个难度名就是变体名（'Pico'）时保留原样，别剥成空串
		return rest.length > 0 ? rest : diffName;
	}

	/**
	 * 兜底：回放没有 chartContentRoot（早期版本录的）时，去 content 各包里找这首歌这一档的谱面，
	 * 找到就返回它所属的资源根（content/VanillaSongs/PicoMix）。
	 */
	public static function findContentRootForChart(songName:String, difficultyName:String, variant:String):String
	{
		#if sys
		if (songName == null) return null;

		var songPath:String = Paths.formatToSongPath(songName);
		var diffSlug:String = (difficultyName != null)
			? Paths.formatToSongPath(stripVariantPrefix(difficultyName, variant)) : null;

		var groupRoot:String = '${Paths.CONTENT_ROOT}/VanillaSongs';
		if (!FileSystem.exists(groupRoot)) return null;

		for (pack in FileSystem.readDirectory(groupRoot))
		{
			if (pack.startsWith('.')) continue;
			var root:String = '$groupRoot/$pack';
			if (!FileSystem.isDirectory(root)) continue;

			for (dataDir in ['$root/shared/data/$songPath', '$root/data/$songPath', '$root/songs/$songPath'])
			{
				if (!FileSystem.exists(dataDir) || !FileSystem.isDirectory(dataDir)) continue;
				for (file in FileSystem.readDirectory(dataDir))
				{
					if (!file.endsWith('.json')) continue;
					var chartName:String = file.substr(0, file.length - 5).toLowerCase();

					// 无后缀 = 普通 Normal
					if (chartName == songPath)
					{
						if (diffSlug == null || diffSlug.length == 0 || diffSlug == 'normal') return root;
						continue;
					}

					if (chartName.indexOf(songPath) != 0) continue;
					if (diffSlug == null || diffSlug.length == 0) continue;
					// <歌>-<变体>-<档位> 或 <歌>-<档位>，都靠"以 -<档位> 结尾"命中
					if (chartName.endsWith('-' + diffSlug)) return root;
				}
			}
		}
		#end
		return null;
	}
}
