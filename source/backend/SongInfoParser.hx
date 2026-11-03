package backend;

import haxe.Json;
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

    public static function getSongInfoFromChart(chart:SwagSong, ?difficulty:String = null, ?splitCustomTracks:Bool = false):ParsedSongInfo
    {
        if (chart == null)
            return getDefaultInfo();
        return parseChartData(Json.stringify(chart), difficulty, splitCustomTracks);
    }

    /**
     * 获取歌曲在指定难度的信息
     */
    public static function getSongInfo(songName:String, folder:String, difficulty:String, ?weekData:WeekData):ParsedSongInfo
    {
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        // 内容包歌的谱面在 content/VanillaSongs/<包>/shared/data 下，靠资源根命中
        var oldContentRoot:String = Paths.currentContentRoot;
        if (weekData != null) Paths.currentContentRoot = weekData.contentRoot;

        var songLowercase:String = Paths.formatToSongPath(songName);
        var diffFileName:String = getDifficultyFileName(difficulty, weekData);
        var jsonFileName:String = songLowercase + diffFileName;

        var chartKey:String = makeChartKey(folder, (weekData == null) ? null : weekData.contentRoot, songLowercase, diffFileName);
        var chartData:String = loadChartData(songLowercase, jsonFileName);

        if (chartData == null && diffFileName != '')
        {
            chartData = loadChartData(songLowercase, 'song');
        }

        Mods.currentModDirectory = oldModDir;
        Paths.currentContentRoot = oldContentRoot;

        if (chartData == null)
        {
            missingCharts.set(chartKey, true);
            trace('No chart file found for: $songName - $difficulty');
            return getDefaultInfo();
        }

        return parseChartData(chartData, difficulty);
    }

    public static function preloadAllDifficulties(songName:String, folder:String, difficulties:Array<String>, ?weekData:WeekData):Map<String, ParsedSongInfo>
    {
        var result:Map<String, ParsedSongInfo> = new Map();
        var oldModDir:String = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        // 内容包歌的谱面在 content/VanillaSongs/<包>/shared/data 下，靠资源根命中
        var oldContentRoot:String = Paths.currentContentRoot;
        if (weekData != null) Paths.currentContentRoot = weekData.contentRoot;

        var songLowercase:String = Paths.formatToSongPath(songName);

        // 获取模式并正确映射
        var mode:String = ClientPrefs.getGameplaySetting('opponentplay');
        if (mode == null) mode = 'normal';
        var difficultyMode:String = DiffRating.normalizeMode(mode);

        for (diffName in difficulties)
        {
            var diffFileName:String = getDifficultyFileName(diffName, weekData);
            var jsonFileName:String = songLowercase + diffFileName;
            var chartKey:String = makeChartKey(folder, (weekData == null) ? null : weekData.contentRoot, songLowercase, diffFileName);

            // 已确认缺谱面的难度直接给默认值，不再读盘 / 解析 / 刷日志
            if (missingCharts.exists(chartKey))
            {
                result.set(diffName, getDefaultInfo());
                continue;
            }

            var chartData:String = loadChartData(songLowercase, jsonFileName);

            if (chartData != null)
            {
                try
                {
                    var swagSong:SwagSong = Song.parseJSON(chartData);

                    // 获取歌曲时长
                    var songLength:Float = 0;
                    if (swagSong.notes != null && swagSong.notes.length > 0)
                    {
                        for (section in swagSong.notes)
                        {
                            if (section.sectionNotes != null && section.sectionNotes.length > 0)
                            {
                                for (note in section.sectionNotes)
                                {
                                    if (note != null && note.length > 0)
                                    {
                                        var time:Float = note[0];
                                        if (time > songLength) songLength = time;
                                    }
                                }
                            }
                        }
                        songLength /= 1000;
                    }

                    // 统计整首谱面的音符数量，并区分玩家/对手箭头
                    var sideCounts = countNoteSides(swagSong);
                    var totalNoteCount:Int = sideCounts.player + sideCounts.opponent;

                    // ★★★ 使用 DiffRating 计算三种模式的评分 ★★★
                    var playerRating:Float   = DiffRating.calcForSong(swagSong, DiffRating.MODE_NORMAL);
                    var opponentRating:Float = DiffRating.calcForSong(swagSong, DiffRating.MODE_OPPONENT);
                    var coopRating:Float     = DiffRating.calcForSong(swagSong, DiffRating.MODE_COOP);

                    playerRating = Math.floor(playerRating * 100) / 100;
                    opponentRating = Math.floor(opponentRating * 100) / 100;
                    coopRating = Math.floor(coopRating * 100) / 100;

                    var selectedRating:Float = switch (difficultyMode)
                    {
                        case DiffRating.MODE_OPPONENT: opponentRating;
                        case DiffRating.MODE_COOP:     coopRating;
                        default:                       playerRating;
                    }

                    var ratingText:String = DiffRating.formatRating(selectedRating);
                    var ratingColor:FlxColor = DiffRating.getColorFromRating(selectedRating);

                    result.set(diffName, {
                        bpm: swagSong.bpm,
                        length: songLength,
                        formattedLength: formatLength(songLength),
                        noteCount: totalNoteCount,
                        keyCount: Song.getKeyCount(swagSong),
                        playerNoteCount: sideCounts.player,
                        opponentNoteCount: sideCounts.opponent,
                        difficultyRating: selectedRating,
                        difficultyRatingPlayer: playerRating,
                        difficultyRatingOpponent: opponentRating,
                        difficultyRatingCoop: coopRating,
                        ratingText: ratingText,
                        ratingColor: ratingColor,
                        album: swagSong.album
                    });
                }
                catch(e:Dynamic)
                {
                    trace('Error parsing $diffName for $songName: $e');
                    result.set(diffName, getDefaultInfo());
                }
            }
            else
            {
                missingCharts.set(chartKey, true);
                trace('No chart data found for: $songName - $diffName');
                result.set(diffName, getDefaultInfo());
            }
        }

        Mods.currentModDirectory = oldModDir;
        Paths.currentContentRoot = oldContentRoot;
        return result;
    }

    private static function getDifficultyFileName(difficulty:String, ?weekData:WeekData):String
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
    private static function resolveChartPath(songLowercase:String, fileName:String):String
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
        if (Assets.exists(assetsPath, TEXT)) return assetsPath;

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

    private static function loadChartData(songLowercase:String, fileName:String):String
    {
        var path:String = resolveChartPath(songLowercase, fileName);
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
        var oldModDir:String = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        var oldContentRoot:String = Paths.currentContentRoot;
        if (weekData != null) Paths.currentContentRoot = weekData.contentRoot;

        var songLowercase:String = Paths.formatToSongPath(songName);
        var diffFileName:String = getDifficultyFileName(difficulty, weekData);
        var path:String = resolveChartPath(songLowercase, songLowercase + diffFileName);
        if (path == null && diffFileName != '')
            path = resolveChartPath(songLowercase, songLowercase + 'song');

        Mods.currentModDirectory = oldModDir;
        Paths.currentContentRoot = oldContentRoot;

        if (path == null) return 0;
        try
        {
            return FileSystem.stat(path).mtime.getTime();
        }
        catch (e:Dynamic)
        {
            return 0;
        }
        #else
        return 0;
        #end
    }

    private static function countNotes(swagSong:SwagSong):Int
    {
        if (swagSong == null || swagSong.notes == null) return 0;
        var count:Int = 0;
        for (section in swagSong.notes)
        {
            if (section == null || section.sectionNotes == null) continue;
            for (note in section.sectionNotes)
            {
                if (note != null && note.length > 0) count++;
            }
        }
        return count;
    }

    private static function parseChartData(rawData:String, ?difficulty:String = null, ?splitCustomTracks:Bool = false):ParsedSongInfo
    {
        var bpm:Float = 0;
        var songLength:Float = 0;
        var noteCount:Int = 0;
        var keyCount:Int = 0;
        var difficultyRating:Float = 0;
        var ratingText:String = "BEGINNER";
        var ratingColor:FlxColor = FlxColor.fromRGB(150, 150, 150);
        var sideCounts:{player:Int, opponent:Int} = {player: 0, opponent: 0};
        var playerRating:Float = 0.0;
        var opponentRating:Float = 0.0;
        var coopRating:Float = 0.0;
        var album:String = null;

        if (rawData == null || rawData.length == 0)
        {
            return getDefaultInfo();
        }

        try
        {
            var swagSong:SwagSong = Song.parseJSON(rawData);

            bpm = swagSong.bpm;
            keyCount = Song.getKeyCount(swagSong);
            album = swagSong.album;

            // 获取歌曲时长
            if (swagSong.notes != null && swagSong.notes.length > 0)
            {
                for (section in swagSong.notes)
                {
                    if (section.sectionNotes != null && section.sectionNotes.length > 0)
                    {
                        for (note in section.sectionNotes)
                        {
                            if (note != null && note.length > 0)
                            {
                                var time:Float = note[0];
                                if (time > songLength) songLength = time;
                            }
                        }
                    }
                }
                songLength /= 1000;
            }

            // 获取当前游戏模式设置
            var gameplayMode:String = ClientPrefs.getGameplaySetting('opponentplay');
            if (gameplayMode == null) gameplayMode = 'normal';
            var difficultyMode:String = DiffRating.normalizeMode(gameplayMode);

            // ★★★ 使用 DiffRating 计算三种模式的评分 ★★★
            playerRating   = DiffRating.calcForSong(swagSong, DiffRating.MODE_NORMAL, splitCustomTracks);
            opponentRating = DiffRating.calcForSong(swagSong, DiffRating.MODE_OPPONENT, splitCustomTracks);
            coopRating     = DiffRating.calcForSong(swagSong, DiffRating.MODE_COOP, splitCustomTracks);

            sideCounts = countNoteSides(swagSong, splitCustomTracks);
            noteCount = sideCounts.player + sideCounts.opponent;

            playerRating = Math.floor(playerRating * 100) / 100;
            opponentRating = Math.floor(opponentRating * 100) / 100;
            coopRating = Math.floor(coopRating * 100) / 100;
            difficultyRating = switch (difficultyMode)
            {
                case DiffRating.MODE_OPPONENT: opponentRating;
                case DiffRating.MODE_COOP:     coopRating;
                default:                       playerRating;
            }

            ratingText = DiffRating.formatRating(difficultyRating);
            ratingColor = DiffRating.getColorFromRating(difficultyRating);
        }
        catch(e:Dynamic)
        {
            trace('Error parsing song details: $e');
        }

        return {
            bpm: bpm,
            length: songLength,
            formattedLength: formatLength(songLength),
            noteCount: noteCount,
            keyCount: keyCount,
            playerNoteCount: sideCounts.player,
            opponentNoteCount: sideCounts.opponent,
            difficultyRating: difficultyRating,
            difficultyRatingPlayer: playerRating,
            difficultyRatingOpponent: opponentRating,
            difficultyRatingCoop: coopRating,
            ratingText: ratingText,
            ratingColor: ratingColor,
            album: album
        };
    }

    private static function countNoteSides(swagSong:SwagSong, ?splitCustomTracks:Bool = false):{player:Int, opponent:Int}
    {
        var counts:{player:Int, opponent:Int} = {player: 0, opponent: 0};
        if (swagSong == null || swagSong.notes == null) return counts;
        for (section in swagSong.notes)
        {
            if (section == null || section.sectionNotes == null) continue;
            for (note in section.sectionNotes)
            {
                if (note == null || note.length < 2) continue;
                var noteData:Int = Std.int(note[1]);
                if (noteData < 0) continue;
                if (!Song.isOpponentLane(noteData, swagSong, splitCustomTracks))
                    counts.player++;
                else
                    counts.opponent++;
            }
        }
        return counts;
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