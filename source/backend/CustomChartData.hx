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
    @:optional var variant:String;
}

typedef CustomChartSong = {
    var name:String;
    var sourceCategory:String;
    var category:String;
    var directory:String;
    var audioPath:String;
    var difficulties:Array<CustomChartDifficulty>;
    var info:Map<String, Dynamic>;
    /** 内容包资源根（相对仓库根），如 content/VanillaSongs/Erect；非内容包为 null。 */
    var contentRoot:String;
    /** 卡片显示名（内容包取 metadata.songName，如 "Bopeebo Erect"）；缺省 = name。 */
    var displayName:String;
    /** metadata 里的曲师 / 谱师（内容包才有）。 */
    var artist:String;
    var charter:String;
}

/** 内容包 metadata 里我们关心的字段。 */
typedef CustomChartMetadataInfo = {
    var songName:String;
    var artist:String;
    var charter:String;
}

typedef CustomChartWeek = {
    var name:String;
    var category:String;
    var songs:Array<CustomChartSong>;
}

class CustomChartData
{
    static inline var INDEX_FILE:String = '.chart-index.json';
    static inline var INFO_CACHE_FILE:String = '.freeplay-info.json';
    static inline var INDEX_VERSION:Int = 3;
    static inline var INFO_CACHE_VERSION:Int = 3;
    public static var weeksLoaded:Map<String, CustomChartWeek> = new Map<String, CustomChartWeek>();
    public static var weeksList:Array<String> = [];

    /**
     * 已确认转换 / 解析失败的 (谱面路径 + 难度)。
     * preloadInfo 失败的难度不会进 song.info，Freeplay 因此每轮都把它重新入队；
     * 记下来后同一进程内只试一次。不落盘 —— 重启会重试一次，修好谱面即可恢复。
     */
    static var failedCharts:Map<String, Bool> = new Map<String, Bool>();

    /** 该歌该难度是否已确认转换失败（Freeplay 用它跳过重复入队）。 */
    public static function isChartFailed(song:CustomChartSong, difficulty:String):Bool
    {
        if (song == null) return true;
        var chart:CustomChartDifficulty = getDifficulty(song, difficulty);
        if (chart == null) return true;
        return failedCharts.exists(chart.path + '|' + difficulty);
    }

    /** 清空失败记录（重新扫盘 / 修好谱面后想再试一次时调用）。 */
    public static function clearFailedCharts():Void
        failedCharts.clear();

    public static function load(category:String):Array<CustomChartSong>
    {
        var result:Array<CustomChartSong> = [];
        weeksLoaded.clear();
        weeksList = [];
        #if sys
        if (category == null || category.length == 0)
            return result;

        // 'custom' = "全部自定义谱面分类"的聚合伪分类，展开成 content/CustomCharts 下每个子目录的相对路径。
        var categories:Array<String> = [category];
        if (category == 'custom')
        {
            categories = [];
            for (name in listChartCategories()) categories.push('CustomCharts/$name');
        }
        for (chartCategory in categories)
        {
            var weekSongs:Array<CustomChartSong> = [];
            if (!loadCachedCategory(chartCategory, weekSongs))
            {
                loadCategory(chartCategory, weekSongs);
                saveCachedCategory(chartCategory, weekSongs);
            }
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
    /** content/CustomCharts 下的分类名（保留旧名给既有调用点）。 */
    public static function listChartCategories():Array<String>
        return listSubCategories('CustomCharts');

    /** content/ 下的一级内容大类（VanillaSongs / CustomCharts / NMVMODS …）。 */
    public static function listContentGroups():Array<String>
    {
        var result:Array<String> = [];
        if (!FileSystem.exists(Paths.CONTENT_ROOT)) return result;
        for (item in FileSystem.readDirectory(Paths.CONTENT_ROOT))
        {
            var path:String = '${Paths.CONTENT_ROOT}/$item';
            // VanillaSongs 的曲目由各自的 week.json 定义（见 WeekData.addContentPackWeeks），
            // 不走 CustomCharts 这套目录扫描，所以不在这里列出来。
            if (!item.startsWith('.') && item != 'VanillaSongs' && FileSystem.isDirectory(path)) result.push(item);
        }
        return result;
    }

    /** content/<group> 下"确实含谱面"的子分类名（自定义分类或内容包变体）。 */
    public static function listSubCategories(group:String):Array<String>
    {
        var result:Array<String> = [];
        if (group == null || group.length == 0) return result;
        var groupPath:String = '${Paths.CONTENT_ROOT}/$group';
        if (!FileSystem.exists(groupPath)) return result;
        for (item in FileSystem.readDirectory(groupPath))
        {
            var path:String = '$groupPath/$item';
            if (!item.startsWith('.') && FileSystem.isDirectory(path) && categoryHasChartFiles(path)) result.push(item);
        }
        return result;
    }

    private static function categoryHasChartFiles(directory:String):Bool
    {
        // 内容包布局：shared/data 下放谱面。
        if (FileSystem.exists('$directory/shared/data')) return true;

        for (item in FileSystem.readDirectory(directory))
        {
            if (item.startsWith('.')) continue;
            var path:String = '$directory/$item';
            if (FileSystem.isDirectory(path))
            {
                if (categoryHasChartFiles(path)) return true;
            }
            else if (isChartFile(item) || isMetadataFile(item))
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
        var categoryPath:String = '${Paths.CONTENT_ROOT}/$category';
        if (!FileSystem.exists(categoryPath) || !FileSystem.isDirectory(categoryPath))
            return;

        // 内容包布局（shared/data + songs）：VanillaSongs 这类整包镜像 assets 的目录。
        if (FileSystem.exists('$categoryPath/shared/data'))
        {
            loadPackCategory(category, categoryPath, result);
            return;
        }

        for (firstDirectory in FileSystem.readDirectory(categoryPath))
        {
            if (firstDirectory.startsWith('.') || !FileSystem.isDirectory('$categoryPath/$firstDirectory'))
                continue;
            collectSongDirectory(category, '$categoryPath/$firstDirectory', firstDirectory, result);
        }
    }

    private static function collectSongDirectory(category:String, directory:String, name:String, result:Array<CustomChartSong>):Void
    {
        var isVSlice:Bool = isVSliceDirectory(category, directory) || findMetadata(directory) != null;
        var difficulties:Array<CustomChartDifficulty> = isVSlice
            ? collectVSliceDifficulties(directory)
            : collectChartFiles(directory);
        if (difficulties.length > 0)
        {
            var detectedCategory:String = isVSlice ? 'v_slice' : detectCategory(category, difficulties[0].path);
            result.push({name: name, sourceCategory: category, category: detectedCategory, directory: directory,
                audioPath: findAudio(directory, detectedCategory), difficulties: difficulties,
                info: new Map<String, Dynamic>(), contentRoot: null, displayName: name,
                artist: null, charter: null});
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

    /**
     * 内容包布局扫描（如 content/VanillaSongs/Erect）：
     *   谱面 shared/data/<歌>/<歌>-<难度>.json；音轨 songs/<歌>-<变体>/。
     * 整包与 assets/ 同构，资源定位靠 Paths.currentContentRoot，这里只负责列曲目与难度。
     */
    private static function loadPackCategory(category:String, categoryPath:String, result:Array<CustomChartSong>):Void
    {
        var dataPath:String = '$categoryPath/shared/data';
        if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) return;

        for (songDir in FileSystem.readDirectory(dataPath))
        {
            if (songDir.startsWith('.')) continue;
            var dir:String = '$dataPath/$songDir';
            if (!FileSystem.isDirectory(dir)) continue;

            var difficulties:Array<CustomChartDifficulty> = collectPackChartFiles(dir, songDir);
            if (difficulties.length == 0) continue;

            var meta:CustomChartMetadataInfo = readMetadataInfo(dir);
            var displayName:String = (meta != null && meta.songName != null && meta.songName.length > 0) ? meta.songName : songDir;

            result.push({name: songDir, sourceCategory: category, category: 'fnf', directory: dir,
                audioPath: null, difficulties: difficulties, info: new Map<String, Dynamic>(),
                contentRoot: categoryPath, displayName: displayName,
                artist: meta != null ? meta.artist : null, charter: meta != null ? meta.charter : null});
        }
    }

    /**
     * 内容包谱面文件名形如 <歌>-<难度>.json（bopeebo-erect.json）。
     * 难度名 = 去掉 "<歌>-" 前缀后的 stem；靠前缀天然排除 events-erect.json，再显式排除 metadata。
     */
    private static function collectPackChartFiles(directory:String, songName:String):Array<CustomChartDifficulty>
    {
        var result:Array<CustomChartDifficulty> = [];
        var prefix:String = songName.toLowerCase() + '-';
        for (fileName in FileSystem.readDirectory(directory))
        {
            if (!isChartFile(fileName) || isMetadataFile(fileName)) continue;
            var dot:Int = fileName.lastIndexOf('.');
            var stem:String = dot > 0 ? fileName.substring(0, dot) : fileName;
            if (!stem.toLowerCase().startsWith(prefix)) continue;
            var difficultyName:String = stem.substring(prefix.length);
            if (difficultyName.length == 0) continue;
            result.push({name: difficultyName, path: '$directory/$fileName'});
        }
        result.sort(function(a, b) return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1);
        return result;
    }

    /**
     * 读某个歌曲数据目录下 metadata（*-metadata*.json）里的 artist / charter。
     * 内容包（content/VanillaSongs/<包>/shared/data/<歌>）与 base（assets/shared/data/<歌>）共用；
     * 找不到文件或字段返回 null，交给 SongCredits 继续往下一级回退。
     */
    public static function readMetadataCredits(directory:String):{artist:String, charter:String}
    {
        if (directory == null || directory.length == 0) return null;
        if (!FileSystem.exists(directory)) return null;
        var info:CustomChartMetadataInfo = readMetadataInfo(directory);
        if (info == null) return null;
        return {artist: info.artist, charter: info.charter};
    }

    /** 读 metadata 的 songName / artist / charter（文件缺失或解析失败返回 null）。 */
    private static function readMetadataInfo(directory:String):CustomChartMetadataInfo
    {
        var metadataPath:String = findMetadata(directory);
        if (metadataPath == null) return null;
        try
        {
            var parsed:Dynamic = Json.parse(File.getContent(metadataPath));
            if (parsed == null) return null;
            return {
                songName: parsed.songName != null ? Std.string(parsed.songName) : null,
                artist: parsed.artist != null ? Std.string(parsed.artist) : null,
                charter: parsed.charter != null ? Std.string(parsed.charter) : null
            };
        }
        catch (e:Dynamic) {}
        return null;
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

    private static function isMetadataFile(fileName:String):Bool
    {
        if (fileName == null) return false;
        var lower:String = fileName.toLowerCase();
        return lower.endsWith('.json') && lower.indexOf('metadata') != -1;
    }

    private static function isVSliceDirectory(category:String, directory:String):Bool
    {
        var categoryName:String = category == null ? '' : category.toLowerCase();
        var directoryName:String = directory == null ? '' : directory.toLowerCase();
        return categoryName.indexOf('v_slice') != -1 || directoryName.indexOf('v_slice') != -1;
    }

    private static function collectVSliceDifficulties(directory:String):Array<CustomChartDifficulty>
    {
        var result:Array<CustomChartDifficulty> = [];
        var metadataPath:String = findMetadata(directory);
        var metadata:Dynamic = null;
        if (metadataPath != null)
        {
            try metadata = Json.parse(File.getContent(metadataPath)) catch (e:Dynamic) metadata = null;
        }
        if (metadata == null || metadata.playData == null || metadata.playData.difficulties == null)
            return result;

        for (fileName in FileSystem.readDirectory(directory))
        {
            if (!isChartFile(fileName) || !fileName.toLowerCase().endsWith('.json'))
                continue;

            try
            {
                var chart:Dynamic = Json.parse(File.getContent('$directory/$fileName'));
                if (chart == null || chart.notes == null || chart.scrollSpeed == null)
                    continue;

                var chartMetadataPath:String = findMetadata(directory, getVariantName(fileName));
                if (chartMetadataPath == null)
                    continue;
                var chartMetadata:Dynamic = Json.parse(File.getContent(chartMetadataPath));
                if (chartMetadata == null || chartMetadata.playData == null || chartMetadata.playData.difficulties == null)
                    continue;

                var chartFields:Array<String> = Reflect.fields(chart.notes);
                var variant:String = getVariantName(fileName);
                for (difficulty in cast(chartMetadata.playData.difficulties, Array<Dynamic>))
                {
                    var name:String = Std.string(difficulty).trim();
                    for (field in chartFields)
                    {
                        if (Paths.formatToSongPath(field) == Paths.formatToSongPath(name))
                        {
                            result.push({name: field, path: '$directory/$fileName', variant: variant});
                            break;
                        }
                    }
                }

                for (field in chartFields)
                {
                    var exists:Bool = false;
                    for (entry in result)
                        if (entry.name == field && entry.path == '$directory/$fileName') exists = true;
                    if (!exists && field.length > 0)
                        result.push({name: field, path: '$directory/$fileName', variant: variant});
                }
            }
            catch (e:Dynamic) {}
        }
        result.sort(function(a, b) return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1);
        return result;
    }

    private static function getVariantName(fileName:String):String
    {
        var lower:String = fileName.toLowerCase();
        var dot:Int = lower.lastIndexOf('.');
        var stem:String = dot > 0 ? lower.substring(0, dot) : lower;
        var chartMarker:Int = stem.indexOf('chart-');
        if (chartMarker >= 0 && chartMarker + 6 < stem.length)
            return stem.substring(chartMarker + 6);
        var metadataMarker:Int = stem.indexOf('metadata-');
        if (metadataMarker >= 0 && metadataMarker + 10 < stem.length)
            return stem.substring(metadataMarker + 10);
        if (stem.indexOf('chart') >= 0 || stem.indexOf('metadata') >= 0)
            return 'default';
        return stem;
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
        var fallback:CustomChartDifficulty = null;
        for (difficulty in song.difficulties)
        {
            if (Paths.formatToSongPath(difficulty.name) != Paths.formatToSongPath(name))
                continue;
            if (fallback == null)
                fallback = difficulty;
            if (difficulty.variant == null || difficulty.variant == 'default')
                return difficulty;
        }
        return fallback;
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
                var metadataPath:String = findMetadata(song.directory, chart.variant);
                if (metadataPath == null)
                    return null;
                var pack = VSlice.convertToPsych(cast raw, cast Json.parse(File.getContent(metadataPath)));
                if (pack == null || pack.difficulties == null)
                    return null;
                var normalizedDifficulty:String = Paths.formatToSongPath(difficulty);
                for (key in pack.difficulties.keys())
                    if (Paths.formatToSongPath(key) == normalizedDifficulty)
                        return pack.difficulties.get(key);
                return null;
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
            var chartInfo:CustomChartDifficulty = getDifficulty(song, difficulty.name);
            if (chartInfo != null && failedCharts.exists(chartInfo.path + '|' + difficulty.name))
                continue;

            var chart:Dynamic = loadChart(song, difficulty.name);
            if (chart != null)
                song.info.set(difficulty.name, SongInfoParser.getSongInfoFromChart(
                    cast chart, difficulty.name, ClientPrefs.data.customChartTrackSplit));
            else if (chartInfo != null)
                failedCharts.set(chartInfo.path + '|' + difficulty.name, true);
        }
        saveInfoCache(song);
    }

    private static function loadInfoCache(song:CustomChartSong):Map<String, Dynamic>
    {
        var result:Map<String, Dynamic> = new Map<String, Dynamic>();
        if (song == null || song.directory == null)
            return result;

        var cachePath:String = '${song.directory}/$INFO_CACHE_FILE';
        if (!FileSystem.exists(cachePath))
            return result;

        try
        {
            var cached:Dynamic = Json.parse(File.getContent(cachePath));
            if (cached == null || cached.version != INFO_CACHE_VERSION
                || cached.trackSplit != ClientPrefs.data.customChartTrackSplit
                || cached.sourceStamp != getDirectoryStamp(song.directory) || cached.data == null)
                return result;

            for (difficulty in Reflect.fields(cached.data))
                result.set(difficulty, Reflect.field(cached.data, difficulty));

            // 回填失败记录：sourceStamp 已经把「目录内文件改动」纳入失效条件，
            // 所以缓存里的 failed 只在谱面没变时可信，谱面一改整个缓存就作废重来。
            if (cached.failed != null)
            {
                var failedList:Array<Dynamic> = cached.failed;
                for (rawName in failedList)
                {
                    var diffName:String = cast rawName;
                    var diffInfo:CustomChartDifficulty = getDifficulty(song, diffName);
                    if (diffInfo != null)
                        failedCharts.set(diffInfo.path + '|' + diffName, true);
                }
            }
        }
        catch (e:Dynamic) {}
        return result;
    }

    private static function saveInfoCache(song:CustomChartSong):Void
    {
        if (song == null || song.directory == null || song.info == null)
            return;

        try
        {
            var data:Dynamic = {};
            for (difficulty in song.info.keys())
                Reflect.setField(data, difficulty, song.info.get(difficulty));

            // 转换失败的难度落盘，Freeplay 下次不再入队；sourceStamp 变了这份缓存整体作废
            var failed:Array<String> = [];
            for (difficulty in song.difficulties)
            {
                var diffInfo:CustomChartDifficulty = getDifficulty(song, difficulty.name);
                if (diffInfo != null && failedCharts.exists(diffInfo.path + '|' + difficulty.name))
                    failed.push(difficulty.name);
            }

            File.saveContent('${song.directory}/$INFO_CACHE_FILE', Json.stringify({
                version: INFO_CACHE_VERSION,
                trackSplit: ClientPrefs.data.customChartTrackSplit,
                sourceStamp: getDirectoryStamp(song.directory),
                data: data,
                failed: failed
            }));
        }
        catch (e:Dynamic) {}
    }

    private static function loadCachedCategory(category:String, result:Array<CustomChartSong>):Bool
    {
        var categoryPath:String = '${Paths.CONTENT_ROOT}/$category';
        var indexPath:String = '$categoryPath/$INDEX_FILE';
        if (!FileSystem.exists(categoryPath) || !FileSystem.exists(indexPath)) return false;

        try
        {
            var cached:Dynamic = Json.parse(File.getContent(indexPath));
            if (cached == null || cached.version != INDEX_VERSION || cached.sourceStamp == null || cached.sourceStamp != getDirectoryStamp(categoryPath))
                return false;

            for (entry in cast(cached.songs, Array<Dynamic>))
            {
                if (entry == null || entry.difficulties == null) return false;
                var difficulties:Array<CustomChartDifficulty> = [];
                for (difficulty in cast(entry.difficulties, Array<Dynamic>))
                {
                    if (difficulty == null || !FileSystem.exists(difficulty.path)) return false;
                    difficulties.push({name: difficulty.name, path: difficulty.path, variant: difficulty.variant});
                }
                if (difficulties.length == 0) return false;
                var song:CustomChartSong = {name: entry.name, sourceCategory: category, category: entry.category, directory: entry.directory,
                    audioPath: entry.audioPath, difficulties: difficulties, info: new Map<String, Dynamic>(),
                    contentRoot: entry.contentRoot, displayName: entry.displayName,
                    artist: entry.artist, charter: entry.charter};
                song.info = loadInfoCache(song);
                result.push(song);
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
        var categoryPath:String = '${Paths.CONTENT_ROOT}/$category';
        var indexPath:String = '$categoryPath/$INDEX_FILE';
        try
        {
            var serializable:Array<Dynamic> = [];
            for (song in songs)
                serializable.push({name: song.name, sourceCategory: song.sourceCategory, category: song.category, directory: song.directory,
                    audioPath: song.audioPath, difficulties: song.difficulties, info: song.info,
                    contentRoot: song.contentRoot, displayName: song.displayName,
                    artist: song.artist, charter: song.charter});
            File.saveContent(indexPath, Json.stringify({version: INDEX_VERSION, sourceStamp: getDirectoryStamp(categoryPath), songs: serializable}));
        }
        catch (e:Dynamic) {}
    }

    private static function getDirectoryStamp(directory:String):Float
    {
        var stamp:Float = FileSystem.stat(directory).mtime.getTime();
        for (item in FileSystem.readDirectory(directory))
        {
            if (item.startsWith('.') || item == INDEX_FILE || item == INFO_CACHE_FILE) continue;
            var path:String = '$directory/$item';
            if (FileSystem.isDirectory(path))
                stamp = Math.max(stamp, getDirectoryStamp(path));
            else
                stamp = Math.max(stamp, FileSystem.stat(path).mtime.getTime());
        }
        return stamp;
    }

    #if sys
    private static function findMetadata(directory:String, ?variant:String):String
    {
        var fallback:String = null;
        for (fileName in FileSystem.readDirectory(directory))
        {
            if (!isMetadataFile(fileName)) continue;
            if (fallback == null) fallback = '$directory/$fileName';
            if (variant != null && getVariantName(fileName) == variant.toLowerCase())
                return '$directory/$fileName';
        }
        return fallback;
    }
    #end
    #end
}
