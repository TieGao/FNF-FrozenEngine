package states.editors.content;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.Entry;
import haxe.zip.Reader;
import sys.io.File;
import sys.FileSystem;


 typedef ExtractResult = {
        var osuContent:String;
        var audioPath:Null<String>;
        var tempDir:String;
    }
    
/**
 * OSZ 压缩包提取器 (纯 Haxe 实现)
 */
class OsuArchiveExtractor
{
    /**
     * 提取结果
     */

    /**
     * 从 OSZ 文件中提取内容
     */
    public static function extract(oszPath:String):Null<ExtractResult>
    {
        if (!FileSystem.exists(oszPath))
        {
            trace('[OsuArchiveExtractor] 文件不存在: $oszPath');
            return null;
        }

        if (!oszPath.toLowerCase().endsWith('.osz'))
        {
            trace('[OsuArchiveExtractor] 不是 OSZ 文件: $oszPath');
            return null;
        }

        try
        {
            // 创建临时目录
            var tempDir = createTempDir();
            trace('[OsuArchiveExtractor] 临时目录: $tempDir');

            // 读取并解压
            var bytes = File.getBytes(oszPath);
            var input = new BytesInput(bytes);
            var reader = new Reader(input);
            var entries = reader.read();

            var osuContent:String = null;
            var audioPath:String = null;

            for (entry in entries)
            {
                var fileName = extractFileName(entry.fileName);
                var fullPath = '$tempDir/$fileName';

                // 保存文件到临时目录
                File.saveBytes(fullPath, entry.data);

                var lower = fileName.toLowerCase();

                // 查找 .osu 谱面文件
                if (osuContent == null && lower.endsWith('.osu'))
                {
                    osuContent = entry.data.toString();
                    trace('[OsuArchiveExtractor] 找到谱面: $fileName');
                }

                // 查找音频文件
                if (audioPath == null && isAudioFile(lower))
                {
                    audioPath = fullPath;
                    trace('[OsuArchiveExtractor] 找到音频: $fileName');
                }
            }

            if (osuContent == null)
            {
                trace('[OsuArchiveExtractor] 错误: 未找到 .osu 谱面文件');
                cleanup(tempDir);
                return null;
            }

            return {
                osuContent: osuContent,
                audioPath: audioPath,
                tempDir: tempDir
            };
        }
        catch (e:Dynamic)
        {
            trace('[OsuArchiveExtractor] 解压失败: $e');
            return null;
        }
    }

    /**
     * 保存音频到歌曲目录
     * @param sourcePath 源音频文件路径
     * @param songName 歌曲名称
     * @return 保存后的文件路径，失败返回 null
     */
    public static function saveAudioToSong(sourcePath:String, songName:String, ?chartCategory:String, ?chartSongDir:String):Null<String>
    {
        if (sourcePath == null || !FileSystem.exists(sourcePath))
        {
            trace('[OsuArchiveExtractor] 音频文件不存在');
            return null;
        }

        try
        {
            var songPath = Paths.formatToSongPath(songName);
            var targetDir = (chartCategory != null && chartSongDir != null)
                ? 'mods/charts/$chartCategory/$chartSongDir/'
                : 'songs/$songPath/';

            // 创建目录
            if (!FileSystem.exists(targetDir))
                FileSystem.createDirectory(targetDir);

            // 获取文件扩展名并复制
            var ext = sourcePath.substr(sourcePath.lastIndexOf('.'));
            var targetPath = targetDir + 'inst' + ext;

            File.copy(sourcePath, targetPath);
            trace('[OsuArchiveExtractor] 音频已保存: $targetPath');
            return targetPath;
        }
        catch (e:Dynamic)
        {
            trace('[OsuArchiveExtractor] 保存音频失败: $e');
            return null;
        }
    }

    /**
     * 清理临时目录
     */
    public static function cleanup(tempDir:String):Void
    {
        try
        {
            if (FileSystem.exists(tempDir))
            {
                deleteDirectoryRecursive(tempDir);
                trace('[OsuArchiveExtractor] 已清理临时目录');
            }
        }
        catch (e:Dynamic)
        {
            trace('[OsuArchiveExtractor] 清理临时目录失败: $e');
        }
    }

    // ========== 内部辅助函数 ==========

    private static function createTempDir():String
    {
        var timestamp = Date.now().getTime();
        var tempRoot = Sys.getEnv("TEMP") ?? Sys.getEnv("TMP") ?? "/tmp";
        var tempDir = '$tempRoot/osu_extract_$timestamp';
        FileSystem.createDirectory(tempDir);
        return tempDir;
    }

    private static function extractFileName(path:String):String
    {
        // 处理 Windows 和 Unix 路径分隔符
        var parts = path.split('/');
        if (parts.length > 1) return parts[parts.length - 1];
        parts = path.split('\\');
        return (parts.length > 1) ? parts[parts.length - 1] : path;
    }

    private static function isAudioFile(fileName:String):Bool
    {
        var lower = fileName.toLowerCase();
        return lower.endsWith('.mp3') || 
               lower.endsWith('.ogg') || 
               lower.endsWith('.wav') ||
               lower.endsWith('.flac');
    }

    private static function deleteDirectoryRecursive(path:String):Void
    {
        if (!FileSystem.exists(path)) return;

        for (entry in FileSystem.readDirectory(path))
        {
            var fullPath = '$path/$entry';
            if (FileSystem.isDirectory(fullPath))
                deleteDirectoryRecursive(fullPath);
            else
                FileSystem.deleteFile(fullPath);
        }
        FileSystem.deleteDirectory(path);
    }
}