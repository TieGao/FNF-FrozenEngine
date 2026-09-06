package backend;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.FileReference;
import lime.utils.Assets;
import haxe.Json;
import openfl.utils.Dictionary;
import states.PlayState;


    // ========== 数据结构 ==========
    
    /**
     * 单帧数据 - 记录某一时刻的所有按键变化
     */
    typedef FrameSave = {
        var time:Float;              // 当前歌曲时间 (ms)
        var pressKey:Array<String>;  // 这一帧按下的键名列表
        var releaseKey:Array<String>;// 这一帧释放的键名列表
        @:optional var songSpeed:Float;    // 当前滚动速度 (可选)
        @:optional var playbackRate:Float; // 当前播放速率 (可选)
    }
    
    /**
     * 回放文件完整数据结构
     */
    typedef ReplayData = {
        // 元数据
        var replayGameVer:String;
        var timestamp:Date;
        var songName:String;
        var songDiff:Int;
        var difficultyName:String;
        var modDirectory:String;
        var opponentMode:String;
        var isDownscroll:Bool;
        var noteSpeed:Float;
        var sf:Int;
        
        // 核心数据 - 帧序列
        var frameData:Array<FrameSave>;
        
        // 结果统计 (仅用于显示，不作为判定依据)
        var finalScore:Int;
        var finalMisses:Int;
        var finalAccuracy:Float;
        var finalRating:String;
        var finalRatingFC:String;
        
        // 元数据
        var chartPath:String;
        var chartCategory:String;
        var chartDirectory:String;
        var chartHasVSliceMetadata:Bool;
        var chartAudioSuffix:String;
        var sm:Bool;
    }
    
/**
 * 高保真回放系统 - 结合帧记录与按键模拟
 * 
 * 核心机制：
 * 1. 录制：每帧记录按键状态（按下/释放）和游戏速度参数
 * 2. 回放：通过模拟按键输入，让游戏引擎自行判定
 * 
 * 优势：
 * - 更高保真度：回放完整输入序列，而非判定结果
 * - 更真实测试：可用于测试判定窗口变化的影响
 * - 文件较小：只记录按键变化，而非每个音符
 */

class Replay
{
    // ========== 版本信息 ==========
    public static var version:String = "2.0";
    
    // ========== 实例变量 ==========
    
    /** 回放文件路径 (相对路径，如 "modName/replay_xxx.kadeReplay") */
    public var path:String = "";
    
    /** 回放文件完整路径 */
    public var fullPath:String = "";
    
    /** 回放数据 */
    public var replay:ReplayData;
    
    /** 当前播放的帧索引 */
    public var currentFrameIndex:Int = 0;
    
    /** 当前按住的键 (用于回放时维持状态) */
    private var keysHeld:Map<String, Bool> = new Map<String, Bool>();
    
    /** 全局Tick计数器 (用于模拟按键的reTick) */
    private var globalTick:Int = 0;
    
    /** 上一次回放的时间 (用于速度同步) */
    private var lastReplayTime:Float = Math.NaN;
    
    /** 速度去同步累积时间 (用于容错) */
    private var songSpeedDesyncMs:Float = 0;
    private var playbackRateDesyncMs:Float = 0;
    
    /** 速度重新同步阈值 */
    public static var songSpeedResyncThreshold:Float = 0.1;
    public static var playbackRateResyncThreshold:Float = 0.1;
    public static var songSpeedResyncDelayMs:Float = 250;
    public static var playbackRateResyncDelayMs:Float = 250;
    
    /** 录制相关 */
    private var isRecording:Bool = false;
    private var frameData:Array<FrameSave> = [];
    private var lastRecordTime:Float = 0;
    private var minRecordInterval:Float = 1000 / 60; // ~16.67ms
    
    /** 缓存的键名列表 (用于快速遍历) */
    private static var cachedKeyNames:Array<String> = null;
    
    // ========== 构造函数 ==========
    
    public function new(path:String = "")
    {
        this.path = path;
        this.fullPath = path;
        
        // 初始化回放数据
        replay = {
            replayGameVer: version,
            timestamp: Date.now(),
            songName: "Unknown",
            songDiff: 1,
            difficultyName: "Normal",
            modDirectory: "",
            opponentMode: "player",
            isDownscroll: false,
            noteSpeed: 1.5,
            sf: 10,
            frameData: [],
            finalScore: 0,
            finalMisses: 0,
            finalAccuracy: 0,
            finalRating: "N/A",
            finalRatingFC: "N/A",
            chartPath: "",
            chartCategory: "",
            chartDirectory: "",
            chartHasVSliceMetadata: false,
            chartAudioSuffix: "",
            sm: false
        };
        
        // 初始化键名缓存
        if (cachedKeyNames == null) {
            cachedKeyNames = [for (k in FlxKey.toStringMap.keys()) k];
        }
    }
    
    // ========== 录制方法 ==========
    
    /**
     * 开始录制
     */
    public function startRecording():Void
    {
        isRecording = true;
        frameData = [];
        lastRecordTime = 0;
        trace('Started recording replay');
    }
    
    /**
     * 停止录制
     */
    public function stopRecording():Void
    {
        isRecording = false;
        trace('Stopped recording replay, ${frameData.length} frames recorded');
    }
    
    /**
     * 录制一帧 - 在 PlayState.update 中每帧调用
     * @param currentTime 当前歌曲时间
     * @param songSpeed 当前滚动速度
     * @param playbackRate 当前播放速率
     * @param keysArray 按键映射数组
     */
    public function recordFrame(currentTime:Float, songSpeed:Float, playbackRate:Float, keysArray:Array<String>):Void
    {
        if (!isRecording) return;
        
        // 控制采样频率，避免文件过大
        if (currentTime - lastRecordTime < minRecordInterval) return;
        lastRecordTime = currentTime;
        
        var pressKey:Array<String> = [];
        var releaseKey:Array<String> = [];
        
        // 检测所有按键的变化
        for (keyName in cachedKeyNames)
        {
            var key:FlxKey = FlxKey.toStringMap.get(keyName);
            if (key == FlxKey.ANY || key == FlxKey.NONE) continue;
            
            // 只检测绑定的游戏键
            if (!isGameKey(keyName, keysArray)) continue;
            
            if (FlxG.keys.checkStatus(key, JUST_PRESSED)) {
                pressKey.push(keyName);
            }
            if (FlxG.keys.checkStatus(key, JUST_RELEASED)) {
                releaseKey.push(keyName);
            }
        }
        
        // 只有按键有变化时才记录帧
        if (pressKey.length == 0 && releaseKey.length == 0) {
            // 但每30帧至少记录一次，用于速度同步
            if (frameData.length % 30 != 0) return;
        }
        
        var frame:FrameSave = {
            time: currentTime,
            pressKey: pressKey,
            releaseKey: releaseKey,
            songSpeed: songSpeed,
            playbackRate: playbackRate
        };
        
        frameData.push(frame);
    }
    
    /**
     * 检查某个键是否是游戏按键
     */
    private function isGameKey(keyName:String, keysArray:Array<String>):Bool
    {
        // 检查是否在 keysArray 中
        for (k in keysArray) {
            var keys = Controls.instance.keyboardBinds.get(k);
            if (keys != null) {
                for (key in keys) {
                    if (FlxKey.toStringMap.get(keyName) == key) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
    
    /**
     * 结束录制并准备保存
     */
    public function finishRecording(playState:PlayState):Void
    {
        isRecording = false;
        
        // 填充元数据
        if (playState != null && PlayState.SONG != null) {
            replay.songName = PlayState.SONG.song;
            replay.songDiff = PlayState.storyDifficulty;
            replay.difficultyName = Difficulty.getString();
            replay.noteSpeed = PlayState.SONG.speed;
            replay.isDownscroll = ClientPrefs.data.downScroll;
            replay.opponentMode = playState.opponentMode;
            replay.sf = ClientPrefs.data.safeFrames;
            
            replay.finalScore = playState.songScore;
            replay.finalMisses = playState.songMisses;
            replay.finalAccuracy = playState.ratingPercent * 100;
            replay.finalRating = playState.ratingName;
            replay.finalRatingFC = playState.ratingFC;
            
            #if MODS_ALLOWED
            replay.modDirectory = Mods.currentModDirectory;
            #else
            replay.modDirectory = "";
            #end
            
            replay.chartPath = Paths.currentChartDirectory != null ? Paths.currentChartDirectory : "";
            replay.chartCategory = Paths.currentChartCategory != null ? Paths.currentChartCategory : "";
            replay.chartDirectory = replay.chartPath;
            replay.chartHasVSliceMetadata = Paths.currentChartHasVSliceMetadata;
            replay.chartAudioSuffix = Paths.currentChartAudioSuffix != null ? Paths.currentChartAudioSuffix : "";
        }
        
        replay.frameData = frameData;
        replay.timestamp = Date.now();
        replay.replayGameVer = version;
        
        trace('Finished recording replay: ${frameData.length} frames');
    }
    
    // ========== 保存方法 ==========
    
    /**
     * 保存回放文件
     */
    public function SaveReplay():Void
    {
        #if sys
        try {
            var currentMod:String = "";
            #if MODS_ALLOWED
            if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) {
                currentMod = Mods.currentModDirectory;
            }
            #end
            
            // 准备数据
            var jsonData:ReplayData = {
                replayGameVer: replay.replayGameVer,
                timestamp: replay.timestamp,
                songName: replay.songName,
                songDiff: replay.songDiff,
                difficultyName: replay.difficultyName,
                modDirectory: replay.modDirectory,
                opponentMode: replay.opponentMode,
                isDownscroll: replay.isDownscroll,
                noteSpeed: replay.noteSpeed,
                sf: replay.sf,
                frameData: replay.frameData,
                finalScore: replay.finalScore,
                finalMisses: replay.finalMisses,
                finalAccuracy: replay.finalAccuracy,
                finalRating: replay.finalRating,
                finalRatingFC: replay.finalRatingFC,
                chartPath: replay.chartPath,
                chartCategory: replay.chartCategory,
                chartDirectory: replay.chartDirectory,
                chartHasVSliceMetadata: replay.chartHasVSliceMetadata,
                chartAudioSuffix: replay.chartAudioSuffix,
                sm: replay.sm
            };
            
            var jsonString:String = Json.stringify(jsonData, null, "\t");
            
            // 确保目录存在
            var replayDir:String = ensureReplayDirExists(currentMod);
            
            // 生成文件名
            var songNameForFile:String = StringTools.replace(StringTools.replace(replay.songName, " ", "_"), ":", "_");
            var diffName:String = replay.difficultyName.toLowerCase();
            var time:Float = Date.now().getTime();
            var fileName:String = 'replay_${songNameForFile}_${diffName}_${time}.kadeReplay';
            var fullFilePath:String = replayDir + fileName;
            
            // 保存文件
            File.saveContent(fullFilePath, jsonString);
            
            // 存储路径
            this.fullPath = fullFilePath;
            if (currentMod != null && currentMod.length > 0) {
                this.path = currentMod + "/" + fileName;
            } else {
                this.path = fileName;
            }
            
            trace('=== REPLAY SAVED ===');
            trace('File: $fileName');
            trace('Full Path: $fullFilePath');
            trace('Frames: ${replay.frameData.length}');
            trace('Mod: ${replay.modDirectory}');
            trace('====================');
            
        } catch(e:Dynamic) {
            trace('Error saving replay: $e');
        }
        #end
    }
    
    // ========== 加载方法 ==========
    
    /**
     * 加载回放文件
     */
    public function LoadFromJSON():Void
    {
        #if sys
        try {
            // 尝试多种可能的路径
            var filePath:String = findReplayFile(path);
            
            if (filePath == null) {
                trace('Replay file not found: $path');
                return;
            }
            
            trace('Loading replay from: $filePath');
            
            var fileContent:String = File.getContent(filePath);
            var data:ReplayData = cast Json.parse(fileContent);
            replay = data;
            this.fullPath = filePath;
            
            // 版本兼容性检查
            if (data.replayGameVer != version) {
                trace('Warning: Replay version mismatch. Replay: ${data.replayGameVer}, Current: $version');
                // 尝试兼容旧版本
                tryConvertOldFormat(data);
            }
            
            // 初始化回放状态
            currentFrameIndex = 0;
            keysHeld = new Map<String, Bool>();
            lastReplayTime = Math.NaN;
            songSpeedDesyncMs = 0;
            playbackRateDesyncMs = 0;
            
            trace('Successfully loaded replay:');
            trace('  Song: ${data.songName}');
            trace('  Difficulty: ${data.difficultyName}');
            trace('  Mod: ${data.modDirectory}');
            trace('  Frames: ${data.frameData.length}');
            trace('  Accuracy: ${data.finalAccuracy}%');
            trace('  File: $filePath');
            
        } catch(e:Dynamic) {
            trace('Failed to load replay: ' + e);
        }
        #end
    }
    
    /**
     * 查找回放文件
     */
    private function findReplayFile(path:String):String
    {
        #if sys
        var rootDir:String = getReplayRootDir();
        var possiblePaths:Array<String> = [];
        
        // 1. 直接路径
        if (path != null && path.length > 0) {
            possiblePaths.push(rootDir + path);
        }
        
        // 2. 如果路径不包含 "/"，在所有子目录中查找
        if (path != null && path.length > 0 && path.indexOf("/") == -1) {
            if (FileSystem.exists(rootDir)) {
                for (entry in FileSystem.readDirectory(rootDir)) {
                    var fullPath:String = rootDir + entry;
                    if (FileSystem.isDirectory(fullPath)) {
                        var filePath:String = fullPath + "/" + path;
                        if (FileSystem.exists(filePath)) {
                            possiblePaths.push(filePath);
                        }
                    }
                }
            }
        }
        
        // 3. 拆分为 Mod名/文件名 格式
        if (path != null && path.length > 0 && path.indexOf("/") > 0) {
            var parts:Array<String> = path.split("/");
            if (parts.length == 2) {
                var modName:String = parts[0];
                var fileName:String = parts[1];
                var modPath:String = rootDir + modName + "/" + fileName;
                if (!possiblePaths.contains(modPath)) {
                    possiblePaths.push(modPath);
                }
            }
        }
        
        // 查找存在的文件
        for (p in possiblePaths) {
            if (FileSystem.exists(p)) {
                return p;
            }
        }
        
        // 最后尝试直接拼接
        var testPath:String = rootDir + path;
        if (FileSystem.exists(testPath)) {
            return testPath;
        }
        #end
        
        return null;
    }
    
    /**
     * 尝试转换旧版本格式
     */
    private function tryConvertOldFormat(data:ReplayData):Void
    {
        // 如果旧版本使用 songNotes 格式，尝试转换
        // 这里可以根据需要实现兼容逻辑
        trace('Attempting to convert old format...');
        // 具体转换逻辑取决于旧版本的格式
    }
    
    // ========== 回放方法 ==========
    
    /**
     * 开始回放
     */
    public function startPlayback():Void
    {
        trace('Starting replay playback for: ' + replay.songName);
        trace('Total frames: ' + replay.frameData.length);
        currentFrameIndex = 0;
        keysHeld = new Map<String, Bool>();
        lastReplayTime = Math.NaN;
        songSpeedDesyncMs = 0;
        playbackRateDesyncMs = 0;
        globalTick = 0;
    }
    
    /**
     * 处理回放帧 - 在 PlayState.update 中每帧调用
     * @param currentTime 当前歌曲时间
     * @param playState 当前的 PlayState 实例
     * @return 是否还有更多帧需要播放
     */
    public function processReplayFrames(currentTime:Float, playState:PlayState):Bool
    {
        if (currentFrameIndex >= replay.frameData.length) {
            return false; // 所有帧已播放完毕
        }
        
        var processedCount:Int = 0;
        var maxProcessPerFrame:Int = 10; // 防止一次性处理过多帧
        
        while (currentFrameIndex < replay.frameData.length && processedCount < maxProcessPerFrame)
        {
            var frame:FrameSave = replay.frameData[currentFrameIndex];
            
            // 检查是否到了该播放这一帧的时间
            if (frame.time > currentTime) {
                break;
            }
            
            // 播放这一帧
            processSingleFrame(frame, playState);
            
            currentFrameIndex++;
            processedCount++;
            globalTick++;
        }
        
        return currentFrameIndex < replay.frameData.length;
    }
    
    /**
     * 处理单帧
     */
    private function processSingleFrame(frame:FrameSave, playState:PlayState):Void
    {
        // 1. 速度同步 (容错机制)
        applyRateResync(frame, playState);
        
        // 2. 处理按键按下
        for (keyName in frame.pressKey) {
            simulateKeyPress(keyName, playState);
        }
        
        // 3. 更新按住键的状态
        updateHeldKeys(playState);
        
        // 4. 处理按键释放
        for (keyName in frame.releaseKey) {
            simulateKeyRelease(keyName, playState);
        }
    }
    
    /**
     * 模拟按键按下
     */
    private function simulateKeyPress(keyName:String, playState:PlayState):Void
    {
        var key:FlxKey = FlxKey.fromString(keyName);
        if (key == FlxKey.NONE || key == FlxKey.ANY) return;
        
        var keyObj = @:privateAccess FlxG.keys.getKey(key);
        if (keyObj != null) {
            // 直接修改 FlxG.keys 内部状态
            // 这样 PlayState 的 keysCheck 会检测到"按键被按下"
            @:privateAccess keyObj.current = 2; // JUST_PRESSED
            @:privateAccess keyObj.reTick = globalTick;
        }
        
        keysHeld.set(keyName, true);
        
        // 触发 PlayState 的按键按下事件
        var keyIndex:Int = getKeyIndex(keyName, playState);
        if (keyIndex >= 0) {
            playState.keyPressed(keyIndex);
        }
    }
    
    /**
     * 模拟按键释放
     */
    private function simulateKeyRelease(keyName:String, playState:PlayState):Void
    {
        var key:FlxKey = FlxKey.fromString(keyName);
        if (key == FlxKey.NONE || key == FlxKey.ANY) return;
        
        var keyObj = @:privateAccess FlxG.keys.getKey(key);
        if (keyObj != null) {
            @:privateAccess keyObj.current = -1; // RELEASED
            @:privateAccess keyObj.reTick = -9999;
        }
        
        keysHeld.remove(keyName);
        
        // 触发 PlayState 的按键释放事件
        var keyIndex:Int = getKeyIndex(keyName, playState);
        if (keyIndex >= 0) {
            playState.keyReleased(keyIndex);
        }
    }
    
    /**
     * 更新按住键的状态 (保持按键持续按下)
     */
    private function updateHeldKeys(playState:PlayState):Void
    {
        for (keyName in keysHeld.keys()) {
            var key:FlxKey = FlxKey.fromString(keyName);
            if (key == FlxKey.NONE || key == FlxKey.ANY) continue;
            
            var keyObj = @:privateAccess FlxG.keys.getKey(key);
            if (keyObj != null && keyObj.reTick != -9999) {
                // 如果按键已经按下超过1帧，设置为 "按住" 状态
                if (globalTick - keyObj.reTick >= 1) {
                    @:privateAccess keyObj.current = 1; // PRESSED
                }
            }
        }
    }
    
    /**
     * 获取键名对应的按键索引
     */
    private function getKeyIndex(keyName:String, playState:PlayState):Int
    {
        var targetKey:FlxKey = FlxKey.fromString(keyName);
        if (targetKey == FlxKey.NONE || targetKey == FlxKey.ANY) return -1;
        
        var keysArray:Array<String> = playState.keysArray;
        for (i in 0...keysArray.length) {
            var binds = Controls.instance.keyboardBinds.get(keysArray[i]);
            if (binds != null) {
                for (bindKey in binds) {
                    if (bindKey == targetKey) {
                        return i;
                    }
                }
            }
        }
        return -1;
    }
    
    /**
     * 速度重新同步 (容错机制)
     * 如果速度与录制值偏差过大且持续一定时间，强制同步
     */
    private function applyRateResync(frame:FrameSave, playState:PlayState):Void
    {
        var dtMs:Float = 0;
        if (!Math.isNaN(lastReplayTime)) {
            dtMs = frame.time - lastReplayTime;
            if (dtMs < 0) dtMs = 0;
        }
        lastReplayTime = frame.time;
        
        // 同步 songSpeed
        if (frame.songSpeed != null) {
            var curSongSpeed:Float = playState.songSpeed;
            if (Math.abs(curSongSpeed - frame.songSpeed) > songSpeedResyncThreshold) {
                songSpeedDesyncMs += dtMs;
            } else {
                songSpeedDesyncMs = 0;
            }
            if (songSpeedDesyncMs >= songSpeedResyncDelayMs) {
                playState.songSpeed = frame.songSpeed;
                songSpeedDesyncMs = 0;
            }
        }
        
        // 同步 playbackRate
        if (frame.playbackRate != null) {
            var curPlaybackRate:Float = playState.playbackRate;
            if (Math.abs(curPlaybackRate - frame.playbackRate) > playbackRateResyncThreshold) {
                playbackRateDesyncMs += dtMs;
            } else {
                playbackRateDesyncMs = 0;
            }
            if (playbackRateDesyncMs >= playbackRateResyncDelayMs) {
                playState.playbackRate = frame.playbackRate;
                playbackRateDesyncMs = 0;
            }
        }
    }
    
    // ========== 文件管理 ==========
    
    /**
     * 获取Replay根目录
     */
    public static function getReplayRootDir():String
    {
        return "assets/replays/";
    }
    
    /**
     * 获取当前Mod对应的Replay子目录
     */
    public static function getReplayModDir(?modName:String = null):String
    {
        var rootDir:String = getReplayRootDir();
        
        #if MODS_ALLOWED
        if (modName == null) {
            modName = Mods.currentModDirectory;
        }
        
        if (modName != null && modName.length > 0 && modName != "base") {
            return rootDir + modName + "/";
        }
        #end
        
        return rootDir + "base/";
    }
    
    /**
     * 确保Replay目录存在
     */
    public static function ensureReplayDirExists(?modName:String = null):String
    {
        #if sys
        var dir:String = getReplayModDir(modName);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
            trace('Created replay directory: $dir');
        }
        return dir;
        #else
        return getReplayModDir(modName);
        #end
    }
    
    /**
     * 获取所有Replay文件
     */
    public static function getAllReplayFiles():Array<String>
    {
        #if sys
        var allFiles:Array<String> = [];
        var rootDir:String = getReplayRootDir();
        
        if (!FileSystem.exists(rootDir)) {
            return allFiles;
        }
        
        for (entry in FileSystem.readDirectory(rootDir)) {
            var fullPath:String = rootDir + entry;
            
            if (FileSystem.isDirectory(fullPath)) {
                for (file in FileSystem.readDirectory(fullPath)) {
                    if (file.endsWith(".kadeReplay")) {
                        allFiles.push(entry + "/" + file);
                    }
                }
            } else if (entry.endsWith(".kadeReplay")) {
                allFiles.push(entry);
            }
        }
        
        return allFiles;
        #else
        return [];
        #end
    }
    
    /**
     * 获取指定Mod目录下的Replay文件
     */
    public static function getReplayFilesForMod(?modName:String = null):Array<String>
    {
        #if sys
        var files:Array<String> = [];
        var dir:String = getReplayModDir(modName);
        
        if (!FileSystem.exists(dir)) {
            return files;
        }
        
        for (file in FileSystem.readDirectory(dir)) {
            if (file.endsWith(".kadeReplay")) {
                var modDirName:String = (modName != null && modName.length > 0) ? modName : "";
                if (modDirName.length > 0) {
                    files.push(modDirName + "/" + file);
                } else {
                    files.push(file);
                }
            }
        }
        
        return files;
        #else
        return [];
        #end
    }
    
    // ========== 辅助方法 ==========
    
    /**
     * 检查回放是否有效
     */
    public function isValid():Bool
    {
        return replay != null &&
               replay.songName != null &&
               replay.songName != "Unknown" &&
               replay.frameData != null &&
               replay.frameData.length > 0;
    }
    
    /**
     * 获取回放信息
     */
    public function getReplayInfo():String
    {
        if (!isValid()) return "Invalid Replay";
        
        var info:String = 'Song: ${replay.songName}\n';
        info += 'Difficulty: ${replay.difficultyName}\n';
        if (replay.modDirectory != null && replay.modDirectory.length > 0) {
            info += 'Mod: ${replay.modDirectory}\n';
        }
        info += 'Accuracy: ${Math.round(replay.finalAccuracy * 100) / 100}%\n';
        info += 'Score: ${replay.finalScore}\n';
        info += 'Misses: ${replay.finalMisses}\n';
        info += 'Rating: ${replay.finalRating} (${replay.finalRatingFC})\n';
        info += 'Frames: ${replay.frameData.length}\n';
        info += 'Date: ${replay.timestamp}';
        
        return info;
    }
    
    /**
     * 获取回放数据 (用于外部读取)
     */
    public function getReplayData():ReplayData
    {
        return replay;
    }
    
    /**
     * 获取当前播放进度 (0-1)
     */
    public function getPlaybackProgress():Float
    {
        if (replay.frameData.length == 0) return 0;
        return currentFrameIndex / replay.frameData.length;
    }
    
    /**
     * 是否正在回放中
     */
    public function isPlaying():Bool
    {
        return currentFrameIndex < replay.frameData.length;
    }
    
    // ========== 静态工厂方法 ==========
    
    /**
     * 加载回放文件
     */
    public static function LoadReplay(path:String):Replay
    {
        var rep:Replay = new Replay(path);
        rep.LoadFromJSON();
        return rep;
    }
    
    /**
     * 创建新的回放录制器
     */
    public static function CreateRecorder():Replay
    {
        return new Replay("");
    }
}