package backend;

import openfl.utils.Assets;
import sys.io.File;
import sys.FileSystem;
import backend.Song;
import backend.DiffRating;

typedef ParsedSongInfo = {
    bpm:Float,
    length:Float,
    formattedLength:String,
    noteCount:Int,
    keyCount:Int,
    playerNoteCount:Int,
    opponentNoteCount:Int,
    difficultyRating:Float,
    difficultyRatingPlayer:Float,
    difficultyRatingOpponent:Float,
    difficultyRatingCoop:Float,
    ratingText:String,
    ratingColor:FlxColor,
    // 专辑 id，取自谱面 JSON 的 album 字段。null = 这首歌没有封面。
    album:String
}

class SongInfoParser
{
    /**
     * 已确认取不到谱面文件的 (模组 + 内容根 + 歌 + 难度)。
     * Freeplay 每轮都会把解析失败的难度重新入队（bpm<=0 一律判无效），坏谱面因此会被
     * 无限重试、日志刷屏。记下来后同一进程内只试一次；不落盘，重启会重试一次，
     * 谱面补上后无需清缓存即可恢复。
     */
    static var missingCharts:Map<String, Bool> = new Map<String, Bool>();

    // ===================== 转化耗时剖析（仅 debug） =====================
    #if (debug || SONGINFO_PROFILE)
    /** 读文件（File.getContent）累计秒数 */
    public static var profRead:Float = 0;
    /** Json.parse + Song.convert 累计秒数 */
    public static var profParse:Float = 0;
    /** 时长 / 侧计数统计累计秒数 */
    public static var profStats:Float = 0;
    /** 三套评级累计秒数 */
    public static var profRating:Float = 0;
    /** 已剖析的难度数 */
    public static var profCharts:Int = 0;
    /** 单档最慢耗时（秒） */
    public static var profMaxChart:Float = 0;

    static inline function ms(seconds:Float):String
        return Std.string(Math.round(seconds * 10000) / 10) + 'ms';

    static function pct(part:Float, total:Float):String
        return total <= 0 ? '0%' : Std.string(Math.round(part / total * 1000) / 10) + '%';

    public static function resetProfile():Void
    {
        profRead = 0;
        profParse = 0;
        profStats = 0;
        profRating = 0;
        profCharts = 0;
        profMaxChart = 0;
    }

    /** 在 FreeplayState.destroy() 打一行：四段占比 + 单档最慢。 */
    public static function dumpProfile(tag:String = 'Freeplay'):Void
    {
        if (profCharts == 0) return;
        var total:Float = profRead + profParse + profStats + profRating;
        if (total <= 0) return;
        trace('[$tag] 转化耗时: ${profCharts} 档 / 合计 ${ms(total)} (均 ${ms(total / profCharts)})');
        trace('  读文件 ${ms(profRead)} ${pct(profRead, total)} | 解析+转换 ${ms(profParse)} ${pct(profParse, total)}'
            + ' | 统计 ${ms(profStats)} ${pct(profStats, total)} | 评级 ${ms(profRating)} ${pct(profRating, total)}'
            + ' | 单档最慢 ${ms(profMaxChart)}');
    }
    #end

    inline static function makeChartKey(folder:String, contentRoot:String, songLowercase:String, diffFileName:String):String
    {
        return (folder == null ? '' : folder) + '|' + (contentRoot == null ? '' : contentRoot)
            + '|' + songLowercase + '|' + diffFileName;
    }

    /** 该歌该难度是否已确认没有谱面文件 —— Freeplay 用它跳过重复解析。 */
    public static function isChartMissing(songName:String, folder:String, difficulty:String, ?weekData:WeekData):Bool
    {
        var contentRoot:String = (weekData == null) ? null : weekData.contentRoot;
        var diffFileName:String = getDifficultyFileName(difficulty, weekData);
        return missingCharts.exists(makeChartKey(folder, contentRoot, Paths.formatToSongPath(songName), diffFileName));
    }

    /** 清空缺失记录（重新扫盘 / 换模组目录后想让坏谱面再试一次时调用）。 */
    public static function clearMissingCharts():Void
        missingCharts.clear();

    /** 把「当前游玩模式」解析成 DiffRating 的模式名；worker 线程请显式传 gameplayMode。 */
    public static function resolveDifficultyMode(?gameplayMode:String):String
    {
        var mode:String = gameplayMode;
        if (mode == null)
        {
            mode = ClientPrefs.getGameplaySetting('opponentplay');
            if (mode == null) mode = 'normal';
        }
        return DiffRating.normalizeMode(mode);
    }

    /**
     * 谱面对象 → ParsedSongInfo。**纯函数**：不读全局、不写全局，可在后台线程调用。
     *
     * @param gameplayMode  null = 读 ClientPrefs（主线程默认）；worker 必须显式传
     * @param mirrorNotes   null = 读 ClientPrefs；worker 必须显式传
     */
    public static function parseChartObject(chart:SwagSong, ?difficulty:String = null,
                                            ?splitCustomTracks:Bool = false, ?mirrorNotes:Null<Bool> = null,
                                            ?gameplayMode:String = null, ?silent:Bool = false):ParsedSongInfo
    {
        if (chart == null) return getDefaultInfo();

        var songLength:Float = 0;
        var playerCount:Int = 0;
        var opponentCount:Int = 0;
        var keyCount:Int = 4;

        #if (debug || SONGINFO_PROFILE) var tStats:Float = haxe.Timer.stamp(); #end
        try
        {
            keyCount = Song.getKeyCount(chart);

            // 一遍同时求时长与两侧音符数（旧实现是两遍独立遍历）
            if (chart.notes != null && chart.notes.length > 0)
            {
                var split:Bool = Song.shouldSplitCustomTracks(chart, splitCustomTracks);
                var boundary:Int = split ? Std.int(keyCount / 2) : keyCount;

                for (section in chart.notes)
                {
                    if (section == null || section.sectionNotes == null) continue;
                    for (note in section.sectionNotes)
                    {
                        // 时长按「任意长度 >= 1 的音符」算（与旧实现一致）
                        if (note == null || note.length == 0) continue;
                        var time:Float = note[0];
                        if (time > songLength) songLength = time;

                        // 侧计数要求至少 [time, lane]
                        if (note.length < 2) continue;
                        var noteData:Int = Std.int(note[1]);
                        if (noteData < 0) continue;
                        if (noteData >= boundary) opponentCount++;
                        else playerCount++;
                    }
                }
                songLength /= 1000;
            }
        }
        catch (e:Dynamic)
        {
            if (!silent) trace('Error scanning chart stats: $e');
        }
        #if (debug || SONGINFO_PROFILE)
        var tRating:Float = haxe.Timer.stamp();
        profStats += tRating - tStats;
        #end

        var playerRating:Float = 0;
        var opponentRating:Float = 0;
        var coopRating:Float = 0;
        try
        {
            // ★ 一次对象构建 + 一次排序，三套评级共用（旧实现是三次独立 build+sort）
            var ratings = DiffRating.calcForSongAllModes(chart, splitCustomTracks, mirrorNotes);
            playerRating = ratings.normal;
            opponentRating = ratings.opponent;
            coopRating = ratings.coop;
        }
        catch (e:Dynamic)
        {
            if (!silent) trace('Error parsing song ratings: $e');
        }
        #if (debug || SONGINFO_PROFILE)
        var tEnd:Float = haxe.Timer.stamp();
        profRating += tEnd - tRating;

        profCharts++;
        var single:Float = (tEnd - tStats);
        if (single > profMaxChart) profMaxChart = single;
        #end

        #if SONGINFO_VERIFY
        // 对拍只在主线程做：worker 里不能 trace（ScreenLog 无锁 / LogFile 是共享句柄）
        if (!silent) verifyAllModes(chart, splitCustomTracks, mirrorNotes, {normal: playerRating, opponent: opponentRating, coop: coopRating});
        #end

        playerRating = Math.floor(playerRating * 100) / 100;
        opponentRating = Math.floor(opponentRating * 100) / 100;
        coopRating = Math.floor(coopRating * 100) / 100;

        var difficultyMode:String = resolveDifficultyMode(gameplayMode);
        var difficultyRating:Float = switch (difficultyMode)
        {
            case DiffRating.MODE_OPPONENT: opponentRating;
            case DiffRating.MODE_COOP:     coopRating;
            default:                       playerRating;
        }

        return {
            bpm: chart.bpm,
            length: songLength,
            formattedLength: formatLength(songLength),
            noteCount: playerCount + opponentCount,
            keyCount: keyCount,
            playerNoteCount: playerCount,
            opponentNoteCount: opponentCount,
            difficultyRating: difficultyRating,
            difficultyRatingPlayer: playerRating,
            difficultyRatingOpponent: opponentRating,
            difficultyRatingCoop: coopRating,
            ratingText: DiffRating.formatRating(difficultyRating),
            ratingColor: DiffRating.getColorFromRating(difficultyRating),
            album: chart.album
        };
    }

    /**
     * 评级对拍开关：-D SONGINFO_VERIFY 构建时，把「一次算三套」的结果与三次独立 calcForSong 比对。
     * 只在临时验证时打开 —— 它会把评级成本翻倍，不要留在常态构建里。
     */
    #if SONGINFO_VERIFY
    static function verifyAllModes(chart:SwagSong, split:Bool, mirror:Null<Bool>, got:{normal:Float, opponent:Float, coop:Float}):Void
    {
        var n:Float = DiffRating.calcForSong(chart, DiffRating.MODE_NORMAL, split, mirror);
        var o:Float = DiffRating.calcForSong(chart, DiffRating.MODE_OPPONENT, split, mirror);
        var c:Float = DiffRating.calcForSong(chart, DiffRating.MODE_COOP, split, mirror);
        if (n != got.normal || o != got.opponent || c != got.coop)
            trace('评级对拍不一致: normal $n / ${got.normal}, opponent $o / ${got.opponent}, coop $c / ${got.coop}');
    }
    #end

    /** 已经是解析后对象的谱面直接算信息 —— 不再 Json.stringify → Json.parse 往返一次。 */
    public static function getSongInfoFromChart(chart:SwagSong, ?difficulty:String = null, ?splitCustomTracks:Bool = false):ParsedSongInfo
        return parseChartObject(chart, difficulty, splitCustomTracks);

    /**
     * 获取歌曲在指定难度的信息
     */
    public static function getSongInfo(songName:String, folder:String, difficulty:String, ?weekData:WeekData):ParsedSongInfo
    {
        var resolved = resolveChartPathFor(songName, folder, difficulty, weekData);

        if (resolved.path == null)
        {
            missingCharts.set(resolved.key, true);
            trace('No chart file found for: $songName - $difficulty');
            return getDefaultInfo();
        }

        var chartData:String = loadChartDataFromPath(resolved.path);
        if (chartData == null) return getDefaultInfo();

        try
        {
            return parseChartObject(Song.parseJSON(chartData, null, 'psych_v1', true), difficulty);
        }
        catch (e:Dynamic)
        {
            trace('Error parsing song details: $e');
            return getDefaultInfo();
        }
    }

    /**
     * 一次解析一首歌的多个难度。
     *
     * 注意：入队时请把 diffFileName 提前算好 —— 这个函数内部会读全局 Difficulty 上下文，
     * 而 Freeplay 的队列是延迟执行的，期间 Difficulty.list 可能已被切到别的周。
     */
    public static function preloadAllDifficulties(songName:String, folder:String, difficulties:Array<String>, ?weekData:WeekData):Map<String, ParsedSongInfo>
    {
        var result:Map<String, ParsedSongInfo> = new Map();
        var oldModDir:String = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        // 内容包歌的谱面在 content/VanillaSongs/<包>/shared/data 下，靠资源根命中
        var oldContentRoot:String = Paths.currentContentRoot;
        if (weekData != null) Paths.currentContentRoot = weekData.contentRoot;

        var songLowercase:String = Paths.formatToSongPath(songName);
        var difficultyMode:String = resolveDifficultyMode();

        for (diffName in difficulties)
        {
            result.set(diffName, preloadOneDifficulty(songLowercase, diffName, songName, folder, weekData, difficultyMode));
        }

        Mods.currentModDirectory = oldModDir;
        Paths.currentContentRoot = oldContentRoot;
        return result;
    }

    /**
     * 只解析一档难度（内部设好 / 还原 Mods 与内容包上下文）。
     * Freeplay 的转化队列按「单难度」调度，这是它的落点。
     */
    public static function preloadDifficulty(songName:String, folder:String, difficulty:String, ?weekData:WeekData):ParsedSongInfo
    {
        var oldModDir:String = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        var oldContentRoot:String = Paths.currentContentRoot;
        if (weekData != null) Paths.currentContentRoot = weekData.contentRoot;

        var songLowercase:String = Paths.formatToSongPath(songName);
        var difficultyMode:String = resolveDifficultyMode();
        var info:ParsedSongInfo = preloadOneDifficulty(songLowercase, difficulty, songName, folder, weekData, difficultyMode);

        Mods.currentModDirectory = oldModDir;
        Paths.currentContentRoot = oldContentRoot;
        return info;
    }

    /** 单难度解析（内部用，调用方必须已经设好 Mods / 内容包上下文）。 */
    static function preloadOneDifficulty(songLowercase:String, diffName:String, songName:String, folder:String,
                                         weekData:WeekData, difficultyMode:String):ParsedSongInfo
    {
        var diffFileName:String = getDifficultyFileName(diffName, weekData);
        var jsonFileName:String = songLowercase + diffFileName;
        var chartKey:String = makeChartKey(folder, (weekData == null) ? null : weekData.contentRoot, songLowercase, diffFileName);

        // 已确认缺谱面的难度直接给默认值，不再读盘 / 解析 / 刷日志
        if (missingCharts.exists(chartKey)) return getDefaultInfo();

        #if (debug || SONGINFO_PROFILE) var t0:Float = haxe.Timer.stamp(); #end
        // 读盘失败（权限 / 文件被占用）不能让异常冒出去 —— 调用方是逐帧的转化队列，
        // 一旦抛出会把改过的 Mods/内容包上下文留在原地，后续所有路径解析都跟着错。
        var chartData:String = null;
        try
        {
            chartData = loadChartData(songLowercase, jsonFileName);
        }
        catch (e:Dynamic)
        {
            chartData = null;
        }
        #if (debug || SONGINFO_PROFILE)
        var t1:Float = haxe.Timer.stamp();
        profRead += t1 - t0;
        #end

        if (chartData == null)
        {
            missingCharts.set(chartKey, true);
            trace('No chart data found for: $songName - $diffName');
            return getDefaultInfo();
        }

        var swagSong:SwagSong = null;
        try
        {
            swagSong = Song.parseJSON(chartData, null, 'psych_v1', true);
        }
        catch (e:Dynamic)
        {
            trace('Error parsing $diffName for $songName: $e');
            return getDefaultInfo();
        }
        #if (debug || SONGINFO_PROFILE)
        var t2:Float = haxe.Timer.stamp();
        profParse += t2 - t1;
        #end

        if (swagSong == null) return getDefaultInfo();
        return parseChartObject(swagSong, diffName, false, null, difficultyMode);
    }

    /**
     * **主线程**解析谱面路径（内部临时改写 Mods/内容根，函数返回前一定还原）。
     * 后台线程方案只把「读文件 + 解析」丢出去，路径解析留在这里，避免两个 worker 互踩全局。
     */
    public static function resolveChartPathFor(songName:String, folder:String, difficulty:String,
                                               ?weekData:WeekData):{path:String, diffFileName:String, key:String}
    {
        var oldModDir:String = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        var oldContentRoot:String = Paths.currentContentRoot;
        if (weekData != null) Paths.currentContentRoot = weekData.contentRoot;

        // Haxe 没有 finally：先把不依赖全局的键算完，路径查找包 try，最后无条件还原上下文
        var songLowercase:String = Paths.formatToSongPath(songName);
        var diffFileName:String = getDifficultyFileName(difficulty, weekData);
        var chartKey:String = makeChartKey(folder, (weekData == null) ? null : weekData.contentRoot, songLowercase, diffFileName);

        var path:String = null;
        try
        {
            path = resolveChartPath(songLowercase, songLowercase + diffFileName);
            if (path == null && diffFileName != '')
                path = resolveChartPath(songLowercase, songLowercase + 'song');
        }
        catch (e:Dynamic)
        {
            path = null;
        }

        Mods.currentModDirectory = oldModDir;
        Paths.currentContentRoot = oldContentRoot;

        return {path: path, diffFileName: diffFileName, key: chartKey};
    }

    /**
     * **可在后台线程调用**：从已解析好的磁盘路径读出谱面并算信息。
     * 只碰 File / Json / 纯运算，不读任何全局；返回 null 表示「线程里搞不定，请回主线程」。
     */
    public static function parseChartFile(path:String, ?gameplayMode:String = null,
                                          ?splitCustomTracks:Bool = false, ?mirrorNotes:Null<Bool> = null):ParsedSongInfo
    {
        #if sys
        if (path == null || path.length == 0) return null;
        // 只认磁盘文件：编译期资源索引（Assets.getText）不是线程安全的，交给主线程回退
        if (!FileSystem.exists(path)) return null;

        var raw:String = null;
        try raw = File.getContent(path) catch (e:Dynamic) return null;
        if (raw == null || raw.length == 0) return null;

        var swagSong:SwagSong = null;
        try swagSong = Song.parseJSON(raw, null, 'psych_v1', true) catch (e:Dynamic) return null;
        if (swagSong == null) return null;

        return parseChartObject(swagSong, null, splitCustomTracks, mirrorNotes, gameplayMode, true);
        #else
        return null;
        #end
    }

    public static function getDifficultyFileName(difficulty:String, ?weekData:WeekData):String
    {
        // 变体包（PicoMix…）：档位名是标准 Easy/Normal/Hard，但谱面文件是
        // <歌>-<变体>-<档位>.json（Normal 也带后缀），变体只写在周定义里。
        if (weekData != null && weekData.variant != null && weekData.variant.length > 0)
            return Difficulty.getFilePathForName(difficulty, weekData.variant);

        var defaultDifficulty:String = Difficulty.getDefault();

        if (difficulty == defaultDifficulty)
        {
            return '';
        }

        if (weekData != null && weekData.difficulties != null && weekData.difficulties.length > 0)
        {
            var diffStr:String = weekData.difficulties;
            var diffList:Array<String> = diffStr.split(',');

            for (i in 0...diffList.length)
            {
                diffList[i] = diffList[i].trim();
            }

            if (diffList.indexOf(difficulty) != -1)
            {
                // 难度名可能带空格（变体难度 'Pico Easy'），磁盘文件名是 '-pico-easy' ——
                // 必须走 formatToSongPath 才能和 Difficulty.getFilePath 拼出的路径一致。
                return Paths.formatToSongPath('-' + difficulty);
            }
        }

        var lowerDiff:String = difficulty.toLowerCase();
        if (lowerDiff == 'erect' || lowerDiff == 'nightmare' || lowerDiff == 'hmnf')
        {
            return '-' + lowerDiff;
        }

        var diffIndex:Int = Difficulty.list.indexOf(difficulty);
        if (diffIndex != -1)
        {
            var filePath:String = Difficulty.getFilePath(diffIndex);
            if (filePath != null && filePath.length > 0)
            {
                return filePath;
            }
        }

        return Paths.formatToSongPath('-' + difficulty);
    }

    /** 按 模组 → mods → 内容包/资源 → assets/data → assets/shared/data 的顺序找谱面文件。 */
    static function resolveChartPath(songLowercase:String, fileName:String):String
    {
        var currentModDir:String = Mods.currentModDirectory;

        #if MODS_ALLOWED
        if (currentModDir != null && currentModDir.length > 0)
        {
            var modPath:String = 'mods/' + currentModDir + '/data/' + songLowercase + '/' + fileName + '.json';
            if (FileSystem.exists(modPath)) return modPath;
        }

        var modPath:String = Paths.modsJson(songLowercase + '/' + fileName);
        if (FileSystem.exists(modPath)) return modPath;
        #end

        var assetsPath:String = Paths.json(songLowercase + '/' + fileName);
        #if sys
        // 内容包是运行时磁盘资源、不在编译期 assets 清单里，Assets.exists 查不到；
        // getPath 命中内容包时返回的本来就是磁盘路径，先按磁盘判存在。
        if (FileSystem.exists(assetsPath)) return assetsPath;
        #end
        if (Paths.assetExists(assetsPath, TEXT)) return assetsPath;

        var directPath:String = 'assets/data/' + songLowercase + '/' + fileName + '.json';
        #if sys
        if (FileSystem.exists(directPath)) return directPath;
        #end

        var sharedPath:String = 'assets/shared/data/' + songLowercase + '/' + fileName + '.json';
        #if sys
        if (FileSystem.exists(sharedPath)) return sharedPath;
        #end

        return null;
    }

    static function loadChartData(songLowercase:String, fileName:String):String
    {
        var path:String = resolveChartPath(songLowercase, fileName);
        if (path == null) return null;
        return loadChartDataFromPath(path);
    }

    static function loadChartDataFromPath(path:String):String
    {
        if (path == null) return null;
        #if sys
        if (FileSystem.exists(path)) return File.getContent(path);
        #end
        return Assets.getText(path);
    }

    /**
     * 谱面文件的修改时间（毫秒）；不存在或非 sys 平台返回 0。
     * Freeplay 用它判断「上次确认解析失败之后，谱面有没有被改过」——
     * 没改就不再重试，改了（或文件后来补上，0 → 非 0）自动重新解析。
     */
    public static function getChartStamp(songName:String, folder:String, difficulty:String, ?weekData:WeekData):Float
    {
        #if sys
        var resolved = resolveChartPathFor(songName, folder, difficulty, weekData);
        if (resolved.path == null) return 0;
        try
        {
            return FileSystem.stat(resolved.path).mtime.getTime();
        }
        catch (e:Dynamic)
        {
            return 0;
        }
        #else
        return 0;
        #end
    }

    public static function formatLength(seconds:Float):String
    {
        if (seconds <= 0 || Math.isNaN(seconds)) return "0:00";
        var minutes:Int = Math.floor(seconds / 60);
        var secs:Int = Math.floor(seconds % 60);
        return minutes + ':' + (secs < 10 ? "0" + secs : Std.string(secs));
    }

    private static function getDefaultInfo():ParsedSongInfo
    {
        return {
            bpm: 0,
            length: 0,
            formattedLength: "0:00",
            noteCount: 0,
            keyCount: 0,
            playerNoteCount: 0,
            opponentNoteCount: 0,
            difficultyRating: 0,
            difficultyRatingPlayer: 0,
            difficultyRatingOpponent: 0,
            difficultyRatingCoop: 0,
            ratingText: "BEGINNER",
            ratingColor: FlxColor.fromRGB(150, 150, 150),
            album: null
        };
    }
}
