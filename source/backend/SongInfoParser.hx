package backend;

import haxe.Json;
import openfl.utils.Assets;
import sys.io.File;
import sys.FileSystem;
import backend.Song;

typedef ParsedSongInfo = {
    bpm:Float,
    length:Float,
    formattedLength:String,
    noteCount:Int,
    difficultyRating:Float,
    ratingText:String,
    ratingColor:FlxColor
}

class SongInfoParser
{
    /**
     * 获取歌曲在指定难度的信息
     * @param songName 歌曲名称
     * @param folder 模组文件夹
     * @param difficulty 难度名称
     * @param weekData 周数据（用于获取自定义难度）
     * @return ParsedSongInfo
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
    
    return parseChartData(chartData, difficulty); // 传递难度参数
}
    
    public static function preloadAllDifficulties(songName:String, folder:String, difficulties:Array<String>, ?weekData:WeekData):Map<String, ParsedSongInfo>
{
    var result:Map<String, ParsedSongInfo> = new Map();
    var oldModDir = Mods.currentModDirectory;
    Mods.currentModDirectory = folder;
    
    var songLowercase:String = Paths.formatToSongPath(songName);
    
    // 获取模式并正确映射
    var mode:String = ClientPrefs.getGameplaySetting('opponentplay');
    if (mode == null) mode = 'normal';
    
    var difficultyMode:String = 'normal';
    switch(mode.toLowerCase())
    {
        case 'opponent', 'opponentplay':
            difficultyMode = 'opponent';
        case 'coop', 'both':
            difficultyMode = 'coop';
        default:
            difficultyMode = 'normal';
    }
    
    trace('Preloading difficulties for song: $songName, Mode: $difficultyMode');
    
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
                
                // 使用 DifficultyCalculator 计算
                var calcResult = DifficultyCalculator.calculateDifficulty(swagSong, difficultyMode);
                
                var ratingText:String = DifficultyCalculator.getRatingText(calcResult.difficultyRating);
                var ratingColor:FlxColor = DifficultyCalculator.getRatingColor(calcResult.difficultyRating);
                
                trace('Difficulty: $diffName, Notes: ${calcResult.noteCount}, Rating: ${calcResult.difficultyRating}');
                
                result.set(diffName, {
                    bpm: swagSong.bpm,
                    length: songLength,
                    formattedLength: formatLength(songLength),
                    noteCount: calcResult.noteCount,
                    difficultyRating: calcResult.difficultyRating,
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
    
    /**
     * 获取难度对应的文件名后缀
     */
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
    
    /**
     * 加载谱面数据
     */
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
    
    private static function parseChartData(rawData:String, ?difficulty:String = null):ParsedSongInfo
    {
        var bpm:Float = 0;
        var songLength:Float = 0;
        var noteCount:Int = 0;
        var difficultyRating:Float = 0;
        var ratingText:String = "BEGINNER";
        var ratingColor:FlxColor = FlxColor.fromRGB(150, 150, 150);
        
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
            
            var difficultyMode:String = 'normal';
            switch(gameplayMode.toLowerCase())
            {
                case 'opponent', 'opponentplay', 'opponentplaytrue':
                    difficultyMode = 'opponent';
                case 'coop', 'both', 'cooperative':
                    difficultyMode = 'coop';
                default:
                    difficultyMode = 'normal';
            }
            
            var calcResult = DifficultyCalculator.calculateDifficulty(swagSong, difficultyMode);
            
            noteCount = calcResult.noteCount;
            difficultyRating = calcResult.difficultyRating;
            ratingText = DifficultyCalculator.getRatingText(difficultyRating);
            ratingColor = DifficultyCalculator.getRatingColor(difficultyRating);
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
            difficultyRating: difficultyRating,
            ratingText: ratingText,
            ratingColor: ratingColor
        };
    }
    
    /**
     * 格式化时长
     */
    public static function formatLength(seconds:Float):String
    {
        if (seconds <= 0 || Math.isNaN(seconds)) return "0:00";
        var minutes:Int = Math.floor(seconds / 60);
        var secs:Int = Math.floor(seconds % 60);
        return minutes + ':' + (secs < 10 ? "0" + secs : Std.string(secs));
    }
    
    /**
     * 获取默认信息
     */
    private static function getDefaultInfo():ParsedSongInfo
    {
        return {
            bpm: 0,
            length: 0,
            formattedLength: "0:00",
            noteCount: 0,
            difficultyRating: 0,
            ratingText: "BEGINNER",
            ratingColor: FlxColor.fromRGB(150, 150, 150)
        };
    }
}