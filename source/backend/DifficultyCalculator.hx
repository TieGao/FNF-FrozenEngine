package backend;

import backend.Song.SwagSong;
import flixel.math.FlxMath;

class DifficultyCalculator
{
    public static var scale:Float = 3 * 1.8;
    
    private static var cache:Map<String, {noteCount:Int, difficultyRating:Float}> = new Map();
    
    private static function getCacheKey(songName:String, difficulty:String, mode:String):String
    {
        return songName + "_" + difficulty + "_" + mode;
    }
    
    public static function clearCache():Void
    {
        cache.clear();
    }
    
/**
 * 计算歌曲难度评级和音符数量
 * @param songData SwagSong 格式的谱面数据
 * @param mode 模式：'normal'=玩家侧, 'opponent'=对手侧, 'coop'=双方
 * @param accuracy 准确度，默认0.93
 */
public static function calculateDifficulty(songData:SwagSong, mode:String = 'normal', ?accuracy:Float = 0.93):{noteCount:Int, difficultyRating:Float}
{
    if (songData == null || songData.notes == null || songData.notes.length == 0)
    {
        return {noteCount: 0, difficultyRating: 0.0};
    }
    
    // 根据模式提取音符
    var notes:Array<{strumTime:Float, noteData:Int, isPlayerNote:Bool}> = extractNotesByMode(songData, mode);
    
    if (notes.length == 0)
    {
        return {noteCount: 0, difficultyRating: 0.0};
    }
    
    var noteCount:Int = notes.length;
    var difficultyRating:Float = calculateRatingFromNotes(notes, songData.bpm, accuracy);
    
    return {
        noteCount: noteCount,
        difficultyRating: FlxMath.roundDecimal(difficultyRating, 2)
    };
}

/**
 * 根据模式提取音符
 * 关键修复：正确区分玩家和对手音符，并过滤掉长按音符的尾部
 */
private static function extractNotesByMode(songData:SwagSong, mode:String):Array<{strumTime:Float, noteData:Int, isPlayerNote:Bool}>
{
    var result:Array<{strumTime:Float, noteData:Int, isPlayerNote:Bool}> = [];
    
    for (section in songData.notes)
    {
        if (section == null || section.sectionNotes == null) continue;
        
        var mustHitSection:Bool = section.mustHitSection;
        
        for (note in section.sectionNotes)
        {
            if (note == null || note.length < 2) continue;
            
            // 过滤长按音符的尾部：如果 sustain 长度 > 0，跳过
            // 在 Psych 中，长按音符的头部和尾部是分开的，我们只计数头部
            if (note.length > 2 && note[2] != null && note[2] > 0)
            {
                var sustainLength:Float = note[2];
                // 如果 sustain 长度大于 0，这是一个长按音符的尾部或持续部分，跳过
                // 注意：有些谱面可能将长按头部的 sustain 也设为 0，所以只过滤 >0 的
                if (sustainLength > 0)
                {
                    continue;
                }
            }
            
            var strumTime:Float = note[0];
            var rawNoteData:Int = Std.int(Math.abs(note[1]));
            
            // 判断这是玩家还是对手的音符
            var isPlayerNote:Bool;
            if (mustHitSection)
            {
                isPlayerNote = (rawNoteData < 4);
            }
            else
            {
                isPlayerNote = (rawNoteData >= 4);
            }
            
            var normalizedData:Int = rawNoteData % 4;
            
            var shouldInclude:Bool = false;
            
            switch (mode)
            {
                case 'normal':
                    shouldInclude = isPlayerNote;
                case 'opponent':
                    shouldInclude = !isPlayerNote;
                case 'coop', 'both':
                    shouldInclude = true;
                default:
                    shouldInclude = isPlayerNote;
            }
            
            if (shouldInclude)
            {
                result.push({
                    strumTime: strumTime,
                    noteData: normalizedData,
                    isPlayerNote: isPlayerNote
                });
            }
        }
    }
    
    result.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
    
    return result;
}
    
    /**
     * 从音符列表计算难度评级
     */
    private static function calculateRatingFromNotes(notes:Array<{strumTime:Float, noteData:Int, isPlayerNote:Bool}>, songBpm:Float, accuracy:Float):Float
    {
        if (notes.length == 0) return 0.0;
        
        // 标准化时间
        var firstNoteTime:Float = notes[0].strumTime;
        var normalizedNotes:Array<{strumTime:Float, noteData:Int}> = [];
        for (note in notes)
        {
            normalizedNotes.push({
                strumTime: (note.strumTime - firstNoteTime) * 2,
                noteData: note.noteData
            });
        }
        
        // 分成左右手
        var handOne:Array<{strumTime:Float, noteData:Int}> = [];
        var handTwo:Array<{strumTime:Float, noteData:Int}> = [];
        
        for (note in normalizedNotes)
        {
            if (note.noteData == 0 || note.noteData == 1)
                handOne.push(note);
            else
                handTwo.push(note);
        }
        
        // 计算歌曲分段长度
        var lastNoteTime:Float = normalizedNotes[normalizedNotes.length - 1].strumTime;
        var length:Int = Math.ceil((lastNoteTime / 1000) / 0.5);
        if (length < 1) length = 1;
        
        // 创建时间段数组
        var segmentsOne:Array<Array<{strumTime:Float, noteData:Int}>> = [];
        var segmentsTwo:Array<Array<{strumTime:Float, noteData:Int}>> = [];
        
        for (i in 0...length)
        {
            segmentsOne.push([]);
            segmentsTwo.push([]);
        }
        
        // 将音符分配到时间段
        for (note in handOne)
        {
            var index:Int = Std.int(((note.strumTime * 2) / 1000));
            if (index >= 0 && index < length)
                segmentsOne[index].push(note);
        }
        
        for (note in handTwo)
        {
            var index:Int = Std.int(((note.strumTime * 2) / 1000));
            if (index >= 0 && index < length)
                segmentsTwo[index].push(note);
        }
        
        // 计算每只手的 NPS
        var handNpsOne:Array<Float> = [];
        var handNpsTwo:Array<Float> = [];
        var pointsOne:Array<Float> = [];
        var pointsTwo:Array<Float> = [];
        
        for (segment in segmentsOne)
        {
            if (segment.length > 0)
            {
                handNpsOne.push(segment.length * scale * 1.6);
                pointsOne.push(segment.length);
            }
        }
        
        for (segment in segmentsTwo)
        {
            if (segment.length > 0)
            {
                handNpsTwo.push(segment.length * scale * 1.6);
                pointsTwo.push(segment.length);
            }
        }
        
        // 计算每只手的难度向量
        var handDiffOne:Array<Float> = calculateHandDifficulty(segmentsOne, handNpsOne);
        var handDiffTwo:Array<Float> = calculateHandDifficulty(segmentsTwo, handNpsTwo);
        
        // 平滑处理
        for (i in 0...4)
        {
            smoothArray(handNpsOne);
            smoothArray(handNpsTwo);
            smoothArrayDiff(handDiffOne);
            smoothArrayDiff(handDiffTwo);
        }
        
        // 计算总音符数
        var totalPoints:Float = 0;
        for (p in pointsOne) totalPoints += p;
        for (p in pointsTwo) totalPoints += p;
        
        if (totalPoints == 0) return 0.0;
        
        if (accuracy > 0.965) accuracy = 0.965;
        
        return chisel(accuracy, handDiffOne, handDiffTwo, pointsOne, pointsTwo, totalPoints);
    }
    
    private static function calculateHandDifficulty(segments:Array<Array<{strumTime:Float, noteData:Int}>>, npsValues:Array<Float>):Array<Float>
    {
        var result:Array<Float> = [];
        var npsIndex:Int = 0;
        
        for (i in 0...segments.length)
        {
            var segment = segments[i];
            if (segment == null || segment.length == 0) continue;
            
            var fingerOne:Array<{strumTime:Float, noteData:Int}> = [];
            var fingerTwo:Array<{strumTime:Float, noteData:Int}> = [];
            
            for (note in segment)
            {
                if (note.noteData == 0 || note.noteData == 2)
                    fingerOne.push(note);
                else
                    fingerTwo.push(note);
            }
            
            var fingerDiffOne:Float = calculateFingerDifficulty(fingerOne);
            var fingerDiffTwo:Float = calculateFingerDifficulty(fingerTwo);
            
            var maxFingerDiff:Float = fingerDiffOne > fingerDiffTwo ? fingerDiffOne : fingerDiffTwo;
            var currentNps:Float = npsIndex < npsValues.length ? npsValues[npsIndex] : 0;
            
            var segmentDiff:Float = ((maxFingerDiff * 8) + (currentNps / scale) * 5) / 13 * scale;
            result.push(segmentDiff);
            
            npsIndex++;
        }
        
        return result;
    }
    
    private static function calculateFingerDifficulty(notes:Array<{strumTime:Float, noteData:Int}>):Float
    {
        if (notes.length <= 1) return 0.0;
        
        var totalInterval:Float = 0;
        for (i in 0...notes.length - 1)
        {
            var interval:Float = notes[i + 1].strumTime - notes[i].strumTime;
            if (interval > 0)
                totalInterval += interval;
        }
        
        if (totalInterval == 0) return 0.0;
        
        return (1375 * (notes.length - 1)) / totalInterval;
    }
    
    private static function chisel(scoreGoal:Float, diffOne:Array<Float>, diffTwo:Array<Float>, 
                                    pointsOne:Array<Float>, pointsTwo:Array<Float>, maxPoints:Float):Float
    {
        var lowerBound:Float = 0;
        var upperBound:Float = 100;
        
        while (upperBound - lowerBound > 0.01)
        {
            var average:Float = (upperBound + lowerBound) / 2;
            var amtOfPoints:Float = calculatePointsForAverage(average, diffOne, pointsOne) +
                                    calculatePointsForAverage(average, diffTwo, pointsTwo);
            
            if (amtOfPoints / maxPoints < scoreGoal)
                lowerBound = average;
            else
                upperBound = average;
        }
        
        return upperBound;
    }
    
    private static function calculatePointsForAverage(midPoint:Float, diff:Array<Float>, points:Array<Float>):Float
    {
        var output:Float = 0;
        
        for (i in 0...diff.length)
        {
            var res:Float = diff[i];
            if (midPoint > res)
                output += points[i];
            else
                output += points[i] * Math.pow(midPoint / res, 1.2);
        }
        
        return output;
    }
    
    private static function smoothArray(arr:Array<Float>):Void
    {
        if (arr.length < 3) return;
        
        var prev:Float = arr[0];
        var curr:Float = arr[1];
        
        for (i in 1...arr.length - 1)
        {
            var next:Float = arr[i + 1];
            arr[i] = (prev + curr + next) / 3;
            prev = curr;
            curr = next;
        }
    }
    
    private static function smoothArrayDiff(arr:Array<Float>):Void
    {
        if (arr.length < 2) return;
        
        var prev:Float = arr[0];
        for (i in 1...arr.length)
        {
            var curr:Float = arr[i];
            arr[i] = (prev + curr) / 2;
            prev = curr;
        }
    }
    
    public static function getRatingText(rating:Float):String
    {
        if (rating >= 25) return "INSANE";
        if (rating >= 22) return "EXPERT";
        if (rating >= 19) return "HARD";
        if (rating >= 15) return "MEDIUM";
        if (rating >= 10) return "EASY";
        return "BEGINNER";
    }
    
    public static function getRatingColor(rating:Float):FlxColor
    {
        if (rating >= 25) return FlxColor.fromRGB(255, 50, 50);   // 红色
        if (rating >= 22) return FlxColor.fromRGB(255, 100, 50);  // 橙色
        if (rating >= 19) return FlxColor.fromRGB(255, 200, 50);  // 金色
        if (rating >= 15) return FlxColor.fromRGB(100, 200, 100); // 绿色
        if (rating >= 10) return FlxColor.fromRGB(100, 150, 255); // 蓝色
        return FlxColor.fromRGB(150, 150, 150);                    // 灰色
    }
}