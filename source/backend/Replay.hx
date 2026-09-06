package backend;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.input.FlxInput;

import haxe.Json;
import states.PlayState;

// ========== 数据结构 ==========

/**
 * 单帧数据 - 记录某一时刻的所有按键变化
 */
typedef FrameSave = {
    var time:Float;
    var pressKey:Array<String>;
    var releaseKey:Array<String>;
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
    var sf:Float;
    
    // 核心数据 - 帧序列
    var frameData:Array<FrameSave>;
    var songNotes:Array<Array<Dynamic>>;
    var songJudgements:Array<String>;
    
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
 */
class Replay
{
    // ========== 版本信息 ==========
    public static var version:String = "2.0";
    
    // ========== 实例变量 ==========
    
    public var path:String = "";
    public var fullPath:String = "";
    public var replay:ReplayData;
    public var currentFrameIndex:Int = 0;
    
    /** 当前按住的键 (用于回放时维持状态) */
    private var keysHeld:Map<String, Bool> = new Map<String, Bool>();
    
    /** 上一次回放的时间 (用于速度同步) */
    private var lastReplayTime:Float = Math.NaN;
    
    /** 录制相关 */
    private var isRecording:Bool = false;
    private var frameData:Array<FrameSave> = [];
    private var recordTick:Int = 0;
    private var noteRecording:Array<Array<Dynamic>> = [];
    private var judgementRecording:Array<String> = [];
    private var pendingPressKeys:Array<String> = [];
    private var pendingReleaseKeys:Array<String> = [];
    
    /** 缓存的键名列表 (用于快速遍历) */
    private static var cachedKeyNames:Array<String> = null;

    private static function roundToTwo(value:Float):Float
    {
        return Math.round(value * 100) / 100;
    }
    
    // ========== 构造函数 ==========
    
    public function new(path:String = "")
    {
        this.path = path;
        this.fullPath = path;
        
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
            sf: 10.0,
            frameData: [],
            songNotes: [],
            songJudgements: [],
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
        
        if (cachedKeyNames == null) {
            cachedKeyNames = [for (k in FlxKey.toStringMap.keys()) k];
        }
    }
    
    // ========== 录制方法 ==========
    
    public function startRecording():Void
    {
        isRecording = true;
        frameData = [];
        recordTick = 0;
        noteRecording = [];
        judgementRecording = [];
        pendingPressKeys = [];
        pendingReleaseKeys = [];
        trace('Started recording replay');
    }
    
    public function stopRecording():Void
    {
        isRecording = false;
        trace('Stopped recording replay, ${frameData.length} frames recorded');
    }
    
    public function recordFrame(currentTime:Float, songSpeed:Float, playbackRate:Float, keysArray:Array<String>):Void
    {
        if (!isRecording) return;

        recordTick++;
        
        var pressKey:Array<String> = pendingPressKeys;
        var releaseKey:Array<String> = pendingReleaseKeys;
        pendingPressKeys = [];
        pendingReleaseKeys = [];
        
        for (keyName in cachedKeyNames)
        {
            var key:FlxKey = FlxKey.toStringMap.get(keyName);
            if (key == FlxKey.ANY || key == FlxKey.NONE) continue;
            
            if (!isGameKey(keyName, keysArray)) continue;
            
            if (FlxG.keys.checkStatus(key, JUST_PRESSED)) {
                var replayKeyName:String = InputFormatter.getKeyName(key);
                if (!pressKey.contains(replayKeyName)) pressKey.push(replayKeyName);
            }
            if (FlxG.keys.checkStatus(key, JUST_RELEASED)) {
                var replayKeyName:String = InputFormatter.getKeyName(key);
                if (!releaseKey.contains(replayKeyName)) releaseKey.push(replayKeyName);
            }
        }
        
        if (pressKey.length == 0 && releaseKey.length == 0) {
            if (recordTick % 30 != 0) return;
        }
        
        var frame:FrameSave = {
            time: roundToTwo(currentTime),
            pressKey: pressKey,
            releaseKey: releaseKey
        };
        
        frameData.push(frame);
    }

    public function recordInput(key:FlxKey, pressed:Bool):Void
    {
        if (!isRecording || key == FlxKey.NONE || key == FlxKey.ANY) return;

        var keyName:String = InputFormatter.getKeyName(key);
        var target:Array<String> = pressed ? pendingPressKeys : pendingReleaseKeys;
        if (!target.contains(keyName)) target.push(keyName);
    }

    public function recordNote(strumTime:Float, noteData:Int, sustainLength:Float, diff:Float):Void
    {
        if (isRecording) noteRecording.push([
            roundToTwo(strumTime),
            roundToTwo(sustainLength),
            noteData,
            roundToTwo(diff)
        ]);
    }

    public function recordMiss(noteData:Int, strumTime:Float):Void
    {
        if (!isRecording) return;
        noteRecording.push([roundToTwo(strumTime), 0, noteData, -10000]);
        judgementRecording.push("miss");
    }

    public function recordJudgement(judge:String):Void
    {
        if (isRecording) judgementRecording.push(judge);
    }
    
    private function isGameKey(keyName:String, keysArray:Array<String>):Bool
    {
        var targetKey:FlxKey = FlxKey.toStringMap.get(keyName);
        if (targetKey == FlxKey.NONE || targetKey == FlxKey.ANY) return false;
        
        var bindNames:Array<String> = getInputBindNames(keysArray);
        for (k in bindNames) {
            var keys = Controls.instance.keyboardBinds.get(k);
            if (keys != null) {
                for (key in keys) {
                    if (key == targetKey) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    private function getInputBindNames(keysArray:Array<String>):Array<String>
        {
            if (keysArray.length == 4) {
                return ['note_left', 'note_down', 'note_up', 'note_right'];
            }
            return keysArray;
        }
    
    
    public function finishRecording(playState:PlayState):Void
    {
        isRecording = false;
        
        if (playState != null && PlayState.SONG != null) {
            replay.songName = PlayState.SONG.song;
            replay.songDiff = PlayState.storyDifficulty;
            replay.difficultyName = Difficulty.getString();
            replay.noteSpeed = roundToTwo(PlayState.SONG.speed);
            replay.isDownscroll = ClientPrefs.data.downScroll;
            replay.opponentMode = playState.opponentMode;
            replay.sf = ClientPrefs.data.safeFrames;
            
            replay.finalScore = playState.songScore;
            replay.finalMisses = playState.songMisses;
            replay.finalAccuracy = roundToTwo(playState.ratingPercent * 100);
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
        replay.songNotes = noteRecording;
        replay.songJudgements = judgementRecording;
        replay.timestamp = Date.now();
        replay.replayGameVer = version;
        
        trace('Finished recording replay: ${frameData.length} frames');
    }
    
    // ========== 保存方法 ==========
    
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
            
            var jsonString:String = Json.stringify(replay, null, "\t");
            
            var replayDir:String = ensureReplayDirExists(currentMod);
            
            var songNameForFile:String = StringTools.replace(StringTools.replace(replay.songName, " ", "_"), ":", "_");
            var diffName:String = replay.difficultyName.toLowerCase();
            var time:Float = Date.now().getTime();
            var fileName:String = 'Replay_${songNameForFile}_${diffName}_${time}.replay';
            var fullFilePath:String = replayDir + fileName;
            
            File.saveContent(fullFilePath, jsonString);
            
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
    
    public function LoadFromJSON():Void
    {
        #if sys
        try {
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
            
            if (data.replayGameVer != version) {
                trace('Warning: Replay version mismatch. Replay: ${data.replayGameVer}, Current: $version');
            }
            
            currentFrameIndex = 0;
            keysHeld = new Map<String, Bool>();
            lastReplayTime = Math.NaN;
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
    
    private function findReplayFile(path:String):String
    {
        #if sys
        var rootDir:String = getReplayRootDir();
        var possiblePaths:Array<String> = [];
        
        if (path != null && path.length > 0) {
            if (FileSystem.exists(path)) return path;
            possiblePaths.push(path.indexOf(rootDir) == 0 ? path : rootDir + path);
        }
        
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
        
        for (p in possiblePaths) {
            if (FileSystem.exists(p)) {
                return p;
            }
        }
        
        var testPath:String = path != null && path.indexOf(rootDir) == 0 ? path : rootDir + path;
        if (FileSystem.exists(testPath)) {
            return testPath;
        }
        #end
        
        return null;
    }
    
    // ========== 回放方法 ==========
    
    public function startPlayback():Void
    {
        trace('Starting replay playback for: ' + replay.songName);
        if (replay.frameData == null) replay.frameData = [];
        trace('Total frames: ' + replay.frameData.length);
        currentFrameIndex = 0;
        keysHeld = new Map<String, Bool>();
        lastReplayTime = Math.NaN;
    }
    
    public function processReplayFrames(currentTime:Float, playState:PlayState):Bool
    {
        if (currentFrameIndex >= replay.frameData.length) {
            return false;
        }
        
        var processedCount:Int = 0;
        var maxProcessPerFrame:Int = 10;
        
        while (currentFrameIndex < replay.frameData.length && processedCount < maxProcessPerFrame)
        {
            var frame:FrameSave = replay.frameData[currentFrameIndex];
            
            if (frame.time > currentTime) {
                break;
            }
            
            processSingleFrame(frame, playState);
            
            currentFrameIndex++;
            processedCount++;
        }
        
        return currentFrameIndex < replay.frameData.length;
    }
    
    private function processSingleFrame(frame:FrameSave, playState:PlayState):Void
    {
        for (keyName in frame.pressKey) {
            simulateKeyPress(keyName, playState);
        }
        
        for (keyName in frame.releaseKey) {
            simulateKeyRelease(keyName, playState);
        }
    }
    
    /**
     * 模拟按键按下 - 使用 @:privateAccess 访问 FlxKeyManager._keyListMap
     */
    private function simulateKeyPress(keyName:String, playState:PlayState):Void
    {
        var key:FlxKey = InputFormatter.getKeyFromName(keyName);
        if (key == FlxKey.NONE || key == FlxKey.ANY) return;
        
        // 使用 @:privateAccess 访问 FlxKeyManager 的 _keyListMap
        @:privateAccess
        var keyObj:FlxInput<FlxKey> = FlxG.keys._keyListMap.get(key);
        if (keyObj != null) {
            keyObj.press();
        }
        
        keysHeld.set(keyName, true);
        
        var binding = getKeyBinding(key, playState);
        if (binding.keyIndex >= 0) {
            playState.keyPressed(binding.keyIndex, binding.bindIndex);
        }
    }
    
    /**
     * 模拟按键释放 - 使用 @:privateAccess 访问 FlxKeyManager._keyListMap
     */
    private function simulateKeyRelease(keyName:String, playState:PlayState):Void
    {
        var key:FlxKey = InputFormatter.getKeyFromName(keyName);
        if (key == FlxKey.NONE || key == FlxKey.ANY) return;
        
        // 使用 @:privateAccess 访问 FlxKeyManager 的 _keyListMap
        @:privateAccess
        var keyObj:FlxInput<FlxKey> = FlxG.keys._keyListMap.get(key);
        if (keyObj != null) {
            keyObj.release();
        }
        
        keysHeld.remove(keyName);
        
        var binding = getKeyBinding(key, playState);
        if (binding.keyIndex >= 0) {
            playState.keyReleased(binding.keyIndex, binding.bindIndex);
        }
    }
    
    /**
     * 获取键名对应的按键索引
     */
    private function getKeyBinding(targetKey:FlxKey, playState:PlayState):{keyIndex:Int, bindIndex:Int}
    {
        if (targetKey == FlxKey.NONE || targetKey == FlxKey.ANY) return {keyIndex: -1, bindIndex: 0};
        
        var keysArray:Array<String> = playState.keysArray;
        var binding = findKeyBinding(targetKey, keysArray);
        if (binding.keyIndex >= 0) return binding;

        if (keysArray.length == 4)
            return findKeyBinding(targetKey, ['note_left', 'note_down', 'note_up', 'note_right']);

        return {keyIndex: -1, bindIndex: 0};
    }

    private function findKeyBinding(targetKey:FlxKey, keysArray:Array<String>):{keyIndex:Int, bindIndex:Int}
    {
        for (i in 0...keysArray.length) {
            var binds = Controls.instance.keyboardBinds.get(keysArray[i]);
            if (binds != null) {
                for (bindIndex in 0...binds.length) {
                    if (binds[bindIndex] == targetKey)
                        return {keyIndex: i, bindIndex: bindIndex};
                }
            }
        }
        return {keyIndex: -1, bindIndex: 0};
    }
    
    /**
     * 每帧更新按键状态 - 需要调用来让 JUST_PRESSED 转为 PRESSED
     * 使用 @:privateAccess 访问 FlxKeyManager 的 update()
     */
    public function updateKeyStates():Void
    {
        @:privateAccess
        FlxG.keys.update();
    }
    
    // ========== 文件管理 ==========
    
    public static function getReplayRootDir():String
    {
        return "assets/replays/";
    }
    
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
                    if (file.endsWith(".replay") || file.endsWith(".kadeReplay")) {
                        allFiles.push(entry + "/" + file);
                    }
                }
            } else if (entry.endsWith(".replay") || entry.endsWith(".kadeReplay")) {
                allFiles.push(entry);
            }
        }
        
        return allFiles;
        #else
        return [];
        #end
    }
    
    public static function getReplayFilesForMod(?modName:String = null):Array<String>
    {
        #if sys
        var files:Array<String> = [];
        var dir:String = getReplayModDir(modName);
        
        if (!FileSystem.exists(dir)) {
            return files;
        }
        
        for (file in FileSystem.readDirectory(dir)) {
            if (file.endsWith(".replay") || file.endsWith(".kadeReplay")) {
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
    
    public function isValid():Bool
    {
        return replay != null &&
               replay.songName != null &&
               replay.songName != "Unknown" &&
               replay.frameData != null &&
               replay.frameData.length > 0;
    }
    
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
    
    public function getReplayData():ReplayData
    {
        return replay;
    }
    
    public function getPlaybackProgress():Float
    {
        if (replay.frameData.length == 0) return 0;
        return currentFrameIndex / replay.frameData.length;
    }
    
    public function isPlaying():Bool
    {
        return currentFrameIndex < replay.frameData.length;
    }
    
    // ========== 静态工厂方法 ==========
    
    public static function LoadReplay(path:String):Replay
    {
        var rep:Replay = new Replay(path);
        rep.LoadFromJSON();
        return rep;
    }
    
    public static function CreateRecorder():Replay
    {
        return new Replay("");
    }
}