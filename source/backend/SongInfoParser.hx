package backend;

import haxe.Json;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ParsedSongInfo = {
    bpm:Float,
    length:Float,
    formattedLength:String
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
        
        // 获取难度对应的文件名
        var diffFileName:String = getDifficultyFileName(difficulty, weekData);
        var jsonFileName:String = songLowercase + diffFileName; // 注意：不再自动加 '-'
        
        trace('Attempting to load chart: $jsonFileName');
        
        // 尝试加载谱面
        var chartData:String = loadChartData(songLowercase, jsonFileName);
        
        // 如果没找到，尝试加载基础谱面（不带难度后缀）
        if (chartData == null && diffFileName != '')
        {
            trace('Could not find $jsonFileName, trying base chart');
            chartData = loadChartData(songLowercase, 'song');
        }
        
        Mods.currentModDirectory = oldModDir;
        
        if (chartData == null)
        {
            trace('No chart file found for: $songName - $difficulty');
            return {
                bpm: 0,
                length: 0,
                formattedLength: "0:00"
            };
        }
        
        trace('Chart found, parsing data');
        return parseChartData(chartData);
    }
    
    /**
     * 预加载歌曲所有难度的信息
     * @param songName 歌曲名称
     * @param folder 模组文件夹
     * @param difficulties 难度列表
     * @param weekData 周数据（用于获取自定义难度）
     * @return Map<String, ParsedSongInfo>
     */
    public static function preloadAllDifficulties(songName:String, folder:String, difficulties:Array<String>, ?weekData:WeekData):Map<String, ParsedSongInfo>
    {
        var result:Map<String, ParsedSongInfo> = new Map();
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        
        var songLowercase:String = Paths.formatToSongPath(songName);
        
        //trace('Preloading song: $songName, folder: $folder');
        //trace('Difficulties: ' + difficulties.join(', '));
        
        // 先尝试加载基础谱面（用于回退）
        var baseChartData:String = loadChartData(songLowercase, 'song');
        var baseInfo:ParsedSongInfo = null;
        
        if (baseChartData != null)
        {
            trace('Base chart found');
            baseInfo = parseChartData(baseChartData);
            trace('Base chart - BPM: ${baseInfo.bpm}, Length: ${baseInfo.formattedLength}');
        }
        else
        {
            //trace('Base chart not found');
        }
        
        // 为每个难度加载信息
        for (diffName in difficulties)
        {
            //trace('Processing difficulty: $diffName');
            
            // 获取难度对应的文件名后缀
            var diffFileName:String = getDifficultyFileName(diffName, weekData);
            var jsonFileName:String = songLowercase + diffFileName;
            
            // 构建完整的文件路径用于调试
            var modPath:String = '';
            var assetsPath:String = '';
            
            #if MODS_ALLOWED
            modPath = Paths.modsJson(songLowercase + '/' + jsonFileName);
            #end
            assetsPath = Paths.json(songLowercase + '/' + jsonFileName);
            
            //trace('  Looking for: $modPath');
            //trace('  or: $assetsPath');
            
            var chartData:String = loadChartData(songLowercase, jsonFileName);
            
            if (chartData != null)
            {
               // trace('Found difficulty chart: $jsonFileName');
                var info = parseChartData(chartData);
                //trace('Parsed result - BPM: ${info.bpm}, Length: ${info.formattedLength}');
                result.set(diffName, info);
            }
            else if (baseInfo != null)
            {
                trace('Using base chart info for $diffName');
                result.set(diffName, baseInfo);
            }
            else
            {
                //trace('No chart info found for $diffName, using default values');
                result.set(diffName, {
                    bpm: 0,
                    length: 0,
                    formattedLength: "0:00"
                });
            }
        }
        
        Mods.currentModDirectory = oldModDir;
        return result;
    }
    
    /**
     * 获取难度对应的文件名后缀
     * 规则：
     * - 如果是默认难度（Normal），返回空字符串
     * - 其他难度返回 "-难度名"（小写）
     */
    /**
 * 获取难度对应的文件名后缀
 * 规则：
 * - 如果是默认难度（Normal），返回空字符串
 * - 其他难度返回 "-难度名"（小写）
 */
private static function getDifficultyFileName(difficulty:String, ?weekData:WeekData):String
{
    // 获取默认难度名称
    var defaultDifficulty:String = Difficulty.getDefault();
    
    // 如果是默认难度，返回空字符串（无后缀）
    if (difficulty == defaultDifficulty)
    {
       // trace('Difficulty $difficulty is default, using no suffix');
        return '';
    }
    
    // 检查是否有周自定义难度列表
    if (weekData != null && weekData.difficulties != null && weekData.difficulties.length > 0)
    {
        // weekData.difficulties 是一个字符串，如 "Easy,Normal,Hard" 或 "erect,nightmare"
        var diffStr:String = weekData.difficulties;
        var diffList:Array<String> = diffStr.split(',');
        
        // 清理每个难度名称（去除空格）
        for (i in 0...diffList.length)
        {
            diffList[i] = diffList[i].trim();
        }
        
        // 如果当前难度在自定义列表中，直接使用难度名称（小写）作为后缀
        if (diffList.indexOf(difficulty) != -1)
        {
            //trace('Using custom difficulty suffix: -${difficulty.toLowerCase()}');
            return '-' + difficulty.toLowerCase();
        }
    }
    
    // 对于 erect 和 nightmare 这样的特殊难度，直接返回
    var lowerDiff:String = difficulty.toLowerCase();
    if (lowerDiff == 'erect' || lowerDiff == 'nightmare' || lowerDiff == 'hmnf')
    {
        trace('Using special difficulty suffix: -$lowerDiff');
        return '-' + lowerDiff;
    }
    
    // 尝试在全局难度列表中找到对应的索引
    var diffIndex:Int = Difficulty.list.indexOf(difficulty);
    if (diffIndex != -1)
    {
        var filePath:String = Difficulty.getFilePath(diffIndex);
        //trace('Got filePath from Difficulty.getFilePath: "$filePath"');
        
        if (filePath != null && filePath.length > 0)
        {
            // Difficulty.getFilePath 返回类似 "-easy" 或 "" 的字符串
            return filePath;
        }
    }
    
    // 如果不是默认难度且没有在其他地方找到，使用 "-难度名" 的格式
    trace('Using fallback suffix: -${difficulty.toLowerCase()}');
    return '-' + difficulty.toLowerCase();
}
    
    /**
     * 加载谱面数据
     */
    private static function loadChartData(songLowercase:String, fileName:String):String
{
    var chartData:String = null;
    
    // 获取当前的模组目录
    var currentModDir:String = Mods.currentModDirectory;
    
    #if MODS_ALLOWED
    // 优先尝试在正确的模组目录中查找
    if (currentModDir != null && currentModDir.length > 0)
    {
        var modPath:String = 'mods/' + currentModDir + '/data/' + songLowercase + '/' + fileName + '.json';
        if (FileSystem.exists(modPath))
        {
            chartData = File.getContent(modPath);
            //trace('Loaded from mods (correct path): $modPath');
            return chartData;
        }
    }
    
    // 然后尝试标准的 mods 路径
    var modPath:String = Paths.modsJson(songLowercase + '/' + fileName);
    if (FileSystem.exists(modPath))
    {
        chartData = File.getContent(modPath);
        trace('Loaded from mods: $modPath');
        return chartData;
    }
    #end
    
    // 尝试 assets 路径
    var assetsPath:String = Paths.json(songLowercase + '/' + fileName);
    if (Assets.exists(assetsPath, TEXT))
    {
        chartData = Assets.getText(assetsPath);
        //trace('Loaded from assets: $assetsPath');
        return chartData;
    }
    
    // 尝试直接路径
    var directPath:String = 'assets/data/' + songLowercase + '/' + fileName + '.json';
    #if sys
    if (FileSystem.exists(directPath))
    {
        chartData = File.getContent(directPath);
        trace('Loaded from direct path: $directPath');
        return chartData;
    }
    #end
    
    // 尝试 assets/shared/data 路径
    var sharedPath:String = 'assets/shared/data/' + songLowercase + '/' + fileName + '.json';
    #if sys
    if (FileSystem.exists(sharedPath))
    {
        chartData = File.getContent(sharedPath);
        trace('Loaded from shared path: $sharedPath');
        return chartData;
    }
    #end
    
    //trace('Could not find chart file: $fileName.json in any path');
    return null;
}
    
    /**
     * 解析谱面数据
     */
    private static function parseChartData(rawData:String):ParsedSongInfo
    {
        var bpm:Float = 0;
        var songLength:Float = 0;
        
        if (rawData == null || rawData.length == 0)
        {
            trace('Chart data is empty');
            return {
                bpm: 0,
                length: 0,
                formattedLength: "0:00"
            };
        }
        
        try
        {
           // trace('Parsing JSON data');
            var songJson:Dynamic = Json.parse(rawData);
            var songData:Dynamic = songJson;
            
            // 检查是否是嵌套结构（有song字段）
            if (Reflect.hasField(songJson, 'song'))
            {
                //trace('Found "song" field, using nested data');
                songData = Reflect.field(songJson, 'song');
            }
            
            // 获取BPM - 多种可能的位置
            bpm = extractBPM(songJson, songData);
            //trace('Extracted BPM: $bpm');
            
            // 获取歌曲时长
            songLength = extractSongLength(songJson, songData);
            //trace('Extracted length: $songLength seconds');
        }
        catch(e:Dynamic)
        {
            trace('Error parsing song details: $e');
        }
        
        return {
            bpm: bpm,
            length: songLength,
            formattedLength: formatLength(songLength)
        };
    }
    
    /**
     * 从谱面数据中提取BPM
     */
    private static function extractBPM(songJson:Dynamic, songData:Dynamic):Float
    {
        // 直接从song对象获取bpm
        if (songData != null && Reflect.hasField(songData, 'bpm'))
        {
            var bpmVal:Dynamic = Reflect.field(songData, 'bpm');
            if (Std.isOfType(bpmVal, Float) || Std.isOfType(bpmVal, Int))
            {
                return bpmVal;
            }
        }
        
        // 从根对象获取bpm
        if (Reflect.hasField(songJson, 'bpm'))
        {
            var bpmVal:Dynamic = Reflect.field(songJson, 'bpm');
            if (Std.isOfType(bpmVal, Float) || Std.isOfType(bpmVal, Int))
            {
                return bpmVal;
            }
        }
        
        // 从事件中获取BPM (Psych Engine格式)
        var events:Dynamic = null;
        if (songData != null && Reflect.hasField(songData, 'events'))
        {
            events = Reflect.field(songData, 'events');
        }
        else if (Reflect.hasField(songJson, 'events'))
        {
            events = Reflect.field(songJson, 'events');
        }
        
        if (events != null)
        {
            if (Std.isOfType(events, Array))
            {
                var eventArray:Array<Dynamic> = cast events;
                for (event in eventArray)
                {
                    if (event != null && Reflect.hasField(event, 'name') && Reflect.field(event, 'name') == 'BPM Change')
                    {
                        if (Reflect.hasField(event, 'value'))
                        {
                            var val:Dynamic = Reflect.field(event, 'value');
                            if (Std.isOfType(val, Float) || Std.isOfType(val, Int))
                            {
                                return val;
                            }
                        }
                    }
                }
            }
        }
        
        // 从eventObjects获取BPM (旧格式)
        var eventObjects:Dynamic = null;
        if (songData != null && Reflect.hasField(songData, 'eventObjects'))
        {
            eventObjects = Reflect.field(songData, 'eventObjects');
        }
        else if (Reflect.hasField(songJson, 'eventObjects'))
        {
            eventObjects = Reflect.field(songJson, 'eventObjects');
        }
        
        if (eventObjects != null && Std.isOfType(eventObjects, Array))
        {
            var eventArray:Array<Dynamic> = cast eventObjects;
            for (event in eventArray)
            {
                if (event != null && Reflect.hasField(event, 'type') && Reflect.field(event, 'type') == "BPM Change")
                {
                    if (Reflect.hasField(event, 'value'))
                    {
                        var val:Dynamic = Reflect.field(event, 'value');
                        if (Std.isOfType(val, Float) || Std.isOfType(val, Int))
                        {
                            return val;
                        }
                    }
                }
            }
        }
        
        trace('Could not find BPM in chart');
        return 0;
    }
    
    /**
     * 从谱面数据中提取歌曲时长
     */
    private static function extractSongLength(songJson:Dynamic, songData:Dynamic):Float
    {
        var notes:Dynamic = null;
        if (songData != null && Reflect.hasField(songData, 'notes'))
        {
            notes = Reflect.field(songData, 'notes');
        }
        else if (Reflect.hasField(songJson, 'notes'))
        {
            notes = Reflect.field(songJson, 'notes');
        }
        
        if (notes != null && Std.isOfType(notes, Array))
        {
            var sections:Array<Dynamic> = cast notes;
            var lastNoteTime:Float = 0;
            
            for (section in sections)
            {
                if (section != null && Reflect.hasField(section, 'sectionNotes'))
                {
                    var sectionNotes:Dynamic = Reflect.field(section, 'sectionNotes');
                    if (sectionNotes != null && Std.isOfType(sectionNotes, Array))
                    {
                        var notesArray:Array<Dynamic> = cast sectionNotes;
                        for (note in notesArray)
                        {
                            if (note != null && note.length > 0)
                            {
                                var noteTime:Dynamic = note[0];
                                if (Std.isOfType(noteTime, Float) || Std.isOfType(noteTime, Int))
                                {
                                    var time:Float = noteTime;
                                    if (time > lastNoteTime)
                                    {
                                        lastNoteTime = time;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if (lastNoteTime > 0)
            {
                return lastNoteTime / 1000; // 转换为秒
            }
        }
        
        //trace('Could not extract song length');
        return 0;
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
}