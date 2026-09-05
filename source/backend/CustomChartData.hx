package backend;

import haxe.Json;
import states.editors.content.OsuConverter;
import states.editors.content.VSlice;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef CustomChartDifficulty = {
    var name:String;
    var path:String;
}

typedef CustomChartSong = {
    var name:String;
    var sourceCategory:String;
    var category:String;
    var directory:String;
    var audioPath:String;
    var difficulties:Array<CustomChartDifficulty>;
    var info:Map<String, Dynamic>;
}

typedef CustomChartWeek = {
    var name:String;
    var category:String;
    var songs:Array<CustomChartSong>;
}

class CustomChartData
{
    static inline var INDEX_FILE:String = '.chart-index.json';
    public static var weeksLoaded:Map<String, CustomChartWeek> = new Map<String, CustomChartWeek>();
    public static var weeksList:Array<String> = [];

    public static function load(category:String):Array<CustomChartSong>
    {
        var result:Array<CustomChartSong> = [];
        weeksLoaded.clear();
        weeksList = [];
        #if sys
        if (category == null || category.length == 0)
            return result;

        var categories:Array<String> = category == 'custom' ? listChartCategories() : [category];
        for (chartCategory in categories)
        {
            var weekSongs:Array<CustomChartSong> = [];
            if (!loadCachedCategory(chartCategory, weekSongs))
            {
                loadCategory(chartCategory, weekSongs);
                saveCachedCategory(chartCategory, weekSongs);
            }
            for (song in weekSongs)
                preloadInfo(song);
            if (weekSongs.length > 0)
            {
                weeksLoaded.set(chartCategory, {name: chartCategory, category: chartCategory, songs: weekSongs});
                weeksList.push(chartCategory);
                result = result.concat(weekSongs);
            }
        }
        #end
        return result;
    }

    #if sys
    public static function listChartCategories():Array<String>
    {
        var result:Array<String> = [];
        if (!FileSystem.exists('mods/charts')) return result;
        for (item in FileSystem.readDirectory('mods/charts'))
        {
            var path:String = 'mods/charts/$item';
            if (!item.startsWith('.') && FileSystem.isDirectory(path) && categoryHasChartFiles(path)) result.push(item);
        }
        return result;
    }

    private static function categoryHasChartFiles(directory:String):Bool
    {
        for (item in FileSystem.readDirectory(directory))
        {
            if (item.startsWith('.')) continue;
            var path:String = '$directory/$item';
            if (FileSystem.isDirectory(path))
            {
                if (categoryHasChartFiles(path)) return true;
            }
            else if (isChartFile(item))
            {
                return true;
            }
        }
        return false;
    }
    #end

    #if sys
    private static function loadCategory(category:String, result:Array<CustomChartSong>):Void
    {
        var categoryPath:String = 'mods/charts/$category';
        if (!FileSystem.exists(categoryPath) || !FileSystem.isDirectory(categoryPath))
            return;

        for (firstDirectory in FileSystem.readDirectory(categoryPath))
        {
            if (firstDirectory.startsWith('.') || !FileSystem.isDirectory('$categoryPath/$firstDirectory'))
                continue;
            collectSongDirectory(category, '$categoryPath/$firstDirectory', firstDirectory, result);
        }
    }

    private static function collectSongDirectory(category:String, directory:String, name:String, result:Array<CustomChartSong>):Void
    {
        var difficulties:Array<CustomChartDifficulty> = category.toLowerCase() == 'v_slice'
            ? collectVSliceDifficulties(directory)
            : collectChartFiles(directory);
        if (difficulties.length > 0)
        {
            var detectedCategory:String = detectCategory(category, difficulties[0].path);
            result.push({name: name, sourceCategory: category, category: detectedCategory, directory: directory,
                audioPath: findAudio(directory, detectedCategory), difficulties: difficulties,
                info: new Map<String, Dynamic>()});
            return;
        }

        // Also accept charts/category/first-level/second-level/*.json|*.osu.
        for (child in FileSystem.readDirectory(directory))
        {
            var childPath:String = '$directory/$child';
            if (!child.startsWith('.') && FileSystem.isDirectory(childPath))
                collectSongDirectory(category, childPath, child, result);
        }
    }

    private static function collectChartFiles(directory:String):Array<CustomChartDifficulty>
    {
        var result:Array<CustomChartDifficulty> = [];
        for (fileName in FileSystem.readDirectory(directory))
        {
            var lower:String = fileName.toLowerCase();
            if (!isChartFile(fileName))
                continue;
            var dot:Int = fileName.lastIndexOf('.');
            var difficultyName:String = dot > 0 ? fileName.substring(0, dot) : fileName;
            if (difficultyName.length > 0) result.push({name: difficultyName, path: '$directory/$fileName'});
        }
        result.sort(function(a, b) return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1);
        return result;
    }

    public static function isChartFile(fileName:String):Bool
    {
        if (fileName == null || fileName.startsWith('.')) return false;
        var lower:String = fileName.toLowerCase();
        if (!lower.endsWith('.json') && !lower.endsWith('.osu')) return false;

        var dot:Int = lower.lastIndexOf('.');
        var stem:String = dot > 0 ? lower.substring(0, dot) : lower;
        var ignored:Array<String> = ['meta', 'metadata', 'event', 'events', 'gf', 'bf', 'boyfriend', 'dad', 'opponent'];
        return ignored.indexOf(stem) == -1 && stem != 'dialogue' && !stem.startsWith('dialogue-') && !stem.startsWith('dialogue_');
    }

    private static function collectVSliceDifficulties(directory:String):Array<CustomChartDifficulty>
    {
        var result:Array<CustomChartDifficulty> = [];
        var metadataPath:String = findMetadata(directory);
        if (metadataPath == null) return result;

        var chartPath:String = null;
        for (fileName in FileSystem.readDirectory(directory))
        {
            if (isChartFile(fileName) && fileName.toLowerCase().endsWith('.json'))
            {
                chartPath = '$directory/$fileName';
                if (fileName.toLowerCase() == 'chart.json') break;
            }
        }
        if (chartPath == null) return result;

        try
        {
            var metadata:Dynamic = Json.parse(File.getContent(metadataPath));
            var difficulties:Array<Dynamic> = metadata.playData.difficulties;
            var chart:Dynamic = Json.parse(File.getContent(chartPath));
            var chartFields:Array<String> = chart != null && chart.notes != null ? Reflect.fields(chart.notes) : [];
            if (difficulties != null)
                for (difficulty in difficulties)
                {
                    var name:String = Std.string(difficulty).trim();
                    var matchingField:String = null;
                    for (field in chartFields)
                        if (Paths.formatToSongPath(field) == Paths.formatToSongPath(name))
                        {
                            matchingField = field;
                            break;
                        }
                    if (matchingField != null)
                        result.push({name: matchingField, path: chartPath});
                }

            // Keep custom chart-only difficulties visible when metadata is incomplete.
            for (field in chartFields)
                if (result.filter(function(item) return item.name == field).length == 0 && field.length > 0)
                    result.push({name: field, path: chartPath});
        }
        catch (e:Dynamic) {}
        return result;
    }

    private static function detectCategory(rootCategory:String, chartPath:String):String
    {
        if (rootCategory.toLowerCase() == 'v_slice') return 'v_slice';
        return chartPath.toLowerCase().endsWith('.osu') ? 'osu_mania' : 'fnf';
    }

    private static function findAudio(directory:String, category:String):String
    {
        for (fileName in FileSystem.readDirectory(directory))
        {
            var lower:String = fileName.toLowerCase();
            if (lower == 'inst.ogg' || lower == 'inst.mp3' || lower == 'audio.ogg' || lower == 'audio.mp3' || lower == 'song.ogg' || lower == 'song.mp3'
                || lower == 'inst-erect.ogg' || lower == 'inst-erect.mp3' || lower == 'inst-pico.ogg' || lower == 'inst-pico.mp3')
                return '$directory/$fileName';
        }

        if (category == 'osu_mania' || category == 'fnf')
        {
            for (fileName in FileSystem.readDirectory(directory))
            {
                if (!fileName.toLowerCase().endsWith('.osu'))
                    continue;
                var sections = OsuConverter.parseOsuSections(File.getContent('$directory/$fileName'));
                var general = OsuConverter.parseKeyValues(sections['General']);
                var audioName:String = general.get('AudioFilename');
                if (audioName != null && FileSystem.exists('$directory/$audioName'))
                    return '$directory/$audioName';
            }
        }
        return null;
    }

    public static function getDifficulty(song:CustomChartSong, name:String):CustomChartDifficulty
    {
        if (song == null || song.difficulties == null)
            return null;
        for (difficulty in song.difficulties)
            if (difficulty.name == name)
                return difficulty;
        return null;
    }

    public static function loadChart(song:CustomChartSong, difficulty:String):Dynamic
    {
        var chart:CustomChartDifficulty = getDifficulty(song, difficulty);
        if (chart == null)
            return null;
        try
        {
            if (chart.path.toLowerCase().endsWith('.osu'))
                return OsuConverter.convertOsuToPsych(chart.path, song.category, song.name);
            if (song.category == 'v_slice')
            {
                var raw:Dynamic = Json.parse(File.getContent(chart.path));
                var metadataPath:String = findMetadata(song.directory);
                if (metadataPath == null)
                    return null;
                var pack = VSlice.convertToPsych(cast raw, cast Json.parse(File.getContent(metadataPath)));
                return pack.difficulties.get(Paths.formatToSongPath(difficulty));
            }
            return Song.parseJSON(File.getContent(chart.path), song.name);
        }
        catch (e:Dynamic)
        {
            trace('Failed to load custom chart ${chart.path}: $e');
            return null;
        }
    }

    public static function preloadInfo(song:CustomChartSong):Void
    {
        if (song == null)
            return;
        for (difficulty in song.difficulties)
        {
            var chart:Dynamic = loadChart(song, difficulty.name);
            if (chart != null)
                song.info.set(difficulty.name, SongInfoParser.getSongInfoFromChart(cast chart, difficulty.name));
        }
    }

    private static function loadCachedCategory(category:String, result:Array<CustomChartSong>):Bool
    {
        var categoryPath:String = 'mods/charts/$category';
        var indexPath:String = '$categoryPath/$INDEX_FILE';
        if (!FileSystem.exists(categoryPath) || !FileSystem.exists(indexPath)) return false;

        try
        {
            var cached:Dynamic = Json.parse(File.getContent(indexPath));
            if (cached == null || cached.sourceStamp == null || cached.sourceStamp != getDirectoryStamp(categoryPath))
                return false;

            for (entry in cast(cached.songs, Array<Dynamic>))
            {
                if (entry == null || entry.difficulties == null) return false;
                var difficulties:Array<CustomChartDifficulty> = [];
                for (difficulty in cast(entry.difficulties, Array<Dynamic>))
                {
                    if (difficulty == null || !FileSystem.exists(difficulty.path)) return false;
                    difficulties.push({name: difficulty.name, path: difficulty.path});
                }
                if (difficulties.length == 0) return false;
                var info:Map<String, Dynamic> = new Map<String, Dynamic>();
                if (entry.info != null)
                    for (difficulty in Reflect.fields(entry.info))
                        info.set(difficulty, Reflect.field(entry.info, difficulty));
                result.push({name: entry.name, sourceCategory: category, category: entry.category, directory: entry.directory,
                    audioPath: entry.audioPath, difficulties: difficulties, info: info});
            }
            return true;
        }
        catch (e:Dynamic)
        {
            return false;
        }
    }

    private static function saveCachedCategory(category:String, songs:Array<CustomChartSong>):Void
    {
        var categoryPath:String = 'mods/charts/$category';
        var indexPath:String = '$categoryPath/$INDEX_FILE';
        try
        {
            var serializable:Array<Dynamic> = [];
            for (song in songs)
                serializable.push({name: song.name, sourceCategory: song.sourceCategory, category: song.category, directory: song.directory,
                    audioPath: song.audioPath, difficulties: song.difficulties, info: song.info});
            File.saveContent(indexPath, Json.stringify({sourceStamp: getDirectoryStamp(categoryPath), songs: serializable}));
        }
        catch (e:Dynamic) {}
    }

    private static function getDirectoryStamp(directory:String):Float
    {
        var stamp:Float = FileSystem.stat(directory).mtime.getTime();
        for (item in FileSystem.readDirectory(directory))
        {
            if (item.startsWith('.') || item == INDEX_FILE) continue;
            var path:String = '$directory/$item';
            if (FileSystem.isDirectory(path))
                stamp = Math.max(stamp, getDirectoryStamp(path));
            else
                stamp = Math.max(stamp, FileSystem.stat(path).mtime.getTime());
        }
        return stamp;
    }

    #if sys
    private static function findMetadata(directory:String):String
    {
        for (fileName in FileSystem.readDirectory(directory))
            if (fileName.toLowerCase().indexOf('metadata') != -1 && fileName.toLowerCase().endsWith('.json'))
                return '$directory/$fileName';
        return null;
    }
    #end
    #end
}
