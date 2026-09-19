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
    playerNoteCount:Int,
    opponentNoteCount:Int,
    difficultyRating:Float,
    difficultyRatingPlayer:Float,
    difficultyRatingOpponent:Float,
    difficultyRatingCoop:Float,
    ratingText:String,
    ratingColor:FlxColor
}

class SongInfoParser
{
    public static function getSongInfoFromChart(chart:SwagSong, ?difficulty:String = null):ParsedSongInfo
    {
        if (chart == null)
            return getDefaultInfo();
        return parseChartData(Json.stringify(chart), difficulty);
    }

    /**
     * 获取歌曲在指定难度的信息
     */
    public static function getSongInfo(songName:String, folder:String, difficulty:String, ?weekData:WeekData):ParsedSongInfo
    {
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;

        var songLowercase:String = Paths.formatToSongPath(songName);
        var diffFileName:String = getDifficultyFileName(difficulty, weekData);
        var jsonFileName:String = songLowercase + diffFileName;

        var chartData:String = loadChartData(songLowercase, jsonFileName);

        if (chartData == null && diffFileName != '')
        {
            chartData = loadChartData(songLowercase, 'song');
        }

        Mods.currentModDirectory = oldModDir;

        if (chartData == null)
        {
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

        var songLowercase:String = Paths.formatToSongPath(songName);

        // 获取模式并正确映射
        var mode:String = ClientPrefs.getGameplaySetting('opponentplay');
        if (mode == null) mode = 'normal';
        var difficultyMode:String = DiffRating.normalizeMode(mode);

        for (diffName in difficulties)
        {
            var diffFileName:String = getDifficultyFileName(diffName, weekData);
            var jsonFileName:String = songLowercase + diffFileName;

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
                        playerNoteCount: sideCounts.player,
                        opponentNoteCount: sideCounts.opponent,
                        difficultyRating: selectedRating,
                        difficultyRatingPlayer: playerRating,
                        difficultyRatingOpponent: opponentRating,
                        difficultyRatingCoop: coopRating,
                        ratingText: ratingText,
                        ratingColor: ratingColor
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
                trace('No chart data found for: $songName - $diffName');
                result.set(diffName, getDefaultInfo());
            }
        }

        Mods.currentModDirectory = oldModDir;
        return result;
    }

    private static function getDifficultyFileName(difficulty:String, ?weekData:WeekData):String
    {
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
                return '-' + difficulty.toLowerCase();
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

        return '-' + difficulty.toLowerCase();
    }

    private static function loadChartData(songLowercase:String, fileName:String):String
    {
        var chartData:String = null;
        var currentModDir:String = Mods.currentModDirectory;

        #if MODS_ALLOWED
        if (currentModDir != null && currentModDir.length > 0)
        {
            var modPath:String = 'mods/' + currentModDir + '/data/' + songLowercase + '/' + fileName + '.json';
            if (FileSystem.exists(modPath))
            {
                chartData = File.getContent(modPath);
                return chartData;
            }
        }

        var modPath:String = Paths.modsJson(songLowercase + '/' + fileName);
        if (FileSystem.exists(modPath))
        {
            chartData = File.getContent(modPath);
            return chartData;
        }
        #end

        var assetsPath:String = Paths.json(songLowercase + '/' + fileName);
        if (Assets.exists(assetsPath, TEXT))
        {
            chartData = Assets.getText(assetsPath);
            return chartData;
        }

        var directPath:String = 'assets/data/' + songLowercase + '/' + fileName + '.json';
        #if sys
        if (FileSystem.exists(directPath))
        {
            chartData = File.getContent(directPath);
            return chartData;
        }
        #end

        var sharedPath:String = 'assets/shared/data/' + songLowercase + '/' + fileName + '.json';
        #if sys
        if (FileSystem.exists(sharedPath))
        {
            chartData = File.getContent(sharedPath);
            return chartData;
        }
        #end

        return null;
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

    private static function parseChartData(rawData:String, ?difficulty:String = null):ParsedSongInfo
    {
        var bpm:Float = 0;
        var songLength:Float = 0;
        var noteCount:Int = 0;
        var difficultyRating:Float = 0;
        var ratingText:String = "BEGINNER";
        var ratingColor:FlxColor = FlxColor.fromRGB(150, 150, 150);
        var sideCounts:{player:Int, opponent:Int} = {player: 0, opponent: 0};
        var playerRating:Float = 0.0;
        var opponentRating:Float = 0.0;
        var coopRating:Float = 0.0;

        if (rawData == null || rawData.length == 0)
        {
            return getDefaultInfo();
        }

        try
        {
            var swagSong:SwagSong = Song.parseJSON(rawData);

            bpm = swagSong.bpm;

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
            playerRating   = DiffRating.calcForSong(swagSong, DiffRating.MODE_NORMAL);
            opponentRating = DiffRating.calcForSong(swagSong, DiffRating.MODE_OPPONENT);
            coopRating     = DiffRating.calcForSong(swagSong, DiffRating.MODE_COOP);

            sideCounts = countNoteSides(swagSong);
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
            playerNoteCount: sideCounts.player,
            opponentNoteCount: sideCounts.opponent,
            difficultyRating: difficultyRating,
            difficultyRatingPlayer: playerRating,
            difficultyRatingOpponent: opponentRating,
            difficultyRatingCoop: coopRating,
            ratingText: ratingText,
            ratingColor: ratingColor
        };
    }

    private static function countNoteSides(swagSong:SwagSong):{player:Int, opponent:Int}
    {
        var counts:{player:Int, opponent:Int} = {player: 0, opponent: 0};
        if (swagSong == null || swagSong.notes == null) return counts;
        for (section in swagSong.notes)
        {
            if (section == null || section.sectionNotes == null) continue;
            for (note in section.sectionNotes)
            {
                if (note == null || note.length < 2) continue;
                var noteData:Int = Std.int(Math.abs(note[1]));
                // note[1] 已经被归一化为 0-3 表示玩家音符，4-7 表示对手音符。
                if (noteData < 4)
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
            playerNoteCount: 0,
            opponentNoteCount: 0,
            difficultyRating: 0,
            difficultyRatingPlayer: 0,
            difficultyRatingOpponent: 0,
            difficultyRatingCoop: 0,
            ratingText: "BEGINNER",
            ratingColor: FlxColor.fromRGB(150, 150, 150)
        };
    }
}