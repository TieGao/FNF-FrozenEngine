package backend;

import backend.Song;

/**
 * Diff Rate 计算器 + NovaFlare 风格 osu 评分取色工具。
 *
 * 相比旧版：
 *  - calcForSong 增加 mode 参数，支持 normal / opponent / coop。
 *  - normal   = 只算玩家侧
 *  - opponent = 只算对手侧
 *  - coop     = 两侧都算
 *
 * mode 只影响 resolvePlayableLane 的筛选，算法主体不变。
 *
 * 本版本不再读取 ClientPrefs.data.playOpponent / flipChart，
 * 改为读取 gameplaySettings 中的 'opponentplay' 与 'mirrornotes'。
 *
 * 颜色部分：内置 osu 风格七彩渐变取色（来自 NovaFlare StarRect）。
 */
class DiffRating
{
    public static inline var MODE_NORMAL:String = 'normal';
    public static inline var MODE_OPPONENT:String = 'opponent';
    public static inline var MODE_COOP:String = 'coop';

    ///////////////////////////////////////////////////////////////////////////
    // 颜色渐变表（NovaFlare 风格，输入值域 [0, 1]）
    ///////////////////////////////////////////////////////////////////////////

    public static final STOPS:Array<{value:Float, color:FlxColor}> = [
        {value: 0,     color: 0x7FFFFB}, // 青
        {value: 0.166, color: 0x83FF7F}, // 绿
        {value: 0.33,  color: 0xFFF17F}, // 黄
        {value: 0.5,   color: 0xFF7F7F}, // 红
        {value: 0.666, color: 0xFF7FF9}, // 粉
        {value: 0.833, color: 0x4444FE}, // 蓝
        {value: 1,     color: 0x21202C}, // 深灰
    ];

    /**
     * 默认评分上限。DiffRating.calcForSong 返回值大致落在这个范围内。
     * 如果你的 osu 算法上限不同，改这里即可。
     */
    public static inline var MAX_RATING:Float = 10.0;

    ///////////////////////////////////////////////////////////////////////////
    // 模式归一化
    ///////////////////////////////////////////////////////////////////////////

    public static function normalizeMode(mode:String):String
    {
        if (mode == null) return MODE_NORMAL;
        switch (mode.toLowerCase())
        {
            case 'player', 'normal':
                return MODE_NORMAL;
            case 'opponent', 'opponentplay', 'opponentplaytrue':
                return MODE_OPPONENT;
            case 'coop', 'both', 'cooperative':
                return MODE_COOP;
            default:
                return MODE_NORMAL;
        }
    }

    /**
     * 从 gameplaySettings 中解析出当前玩家实际游玩的模式。
     * 'opponentplay' 的可选值：'player' / 'opponent' / 'coop' / 'coop_split'
     */
    public static function resolvePlayMode():String
    {
        var setting:Dynamic = ClientPrefs.getGameplaySetting('opponentplay', 'player');
        if (setting == null) return MODE_NORMAL;

        var value:String = Std.string(setting).toLowerCase();
        switch (value)
        {
            case 'opponent':
                return MODE_OPPONENT;
            case 'coop', 'coop_split':
                return MODE_COOP;
            case 'player', 'normal':
                return MODE_NORMAL;
            default:
                return MODE_NORMAL;
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // 评分计算
    ///////////////////////////////////////////////////////////////////////////

    public static function calcForSong(song:SwagSong, ?mode:String = MODE_NORMAL):Float
    {
        if (song == null || song.notes == null || song.notes.length == 0) return 0;

        mode = normalizeMode(mode);

        var objs:Array<ManiaObj> = [];
        var totalColumns:Int = song.mania + 1;
        if (totalColumns <= 0) totalColumns = 4;

        for (sec in song.notes)
        {
            var notes:Array<Dynamic> = sec.sectionNotes;
            if (notes == null) continue;
            for (n in notes)
            {
                if (n == null || n.length < 2) continue;
                var rawLane:Int = Std.int(n[1]);
                if (rawLane < 0) continue;
                var lane:Int = resolvePlayableLane(sec, rawLane, song, mode);
                if (lane < 0) continue;
                var start:Float = n[0];
                var sustain:Float = (n.length >= 3 && n[2] != null) ? n[2] : 0.0;
                var end:Float = start + (sustain > 0 ? sustain : 0);
                objs.push({
                    startTime: start,
                    endTime: end,
                    column: lane,
                    index: 0,
                    deltaTime: 0,
                    previousIndex: -1,
                    previousStart: 0,
                    previousHitByColumn: [],
                    columnStrainTime: 0
                });
            }
        }

        if (objs.length <= 1) return 0;

        objs.sort(function(a, b) return a.startTime < b.startTime ? -1 : (a.startTime > b.startTime ? 1 : 0));

        var perColumn:Array<Array<Int>> = [];
        for (i in 0...totalColumns) perColumn.push([]);
        var prevByColumn:Array<Int> = [];
        for (i in 0...totalColumns) prevByColumn.push(-1);

        var objects:Array<ManiaObj> = [];
        for (i in 1...objs.length)
        {
            var prev = objs[i - 1];
            var cur = objs[i];
            var idx = objects.length;
            var delta = cur.startTime - prev.startTime;
            var prevHit:Array<Int> = prevByColumn.copy();
            var col = cur.column;
            var colList = perColumn[col];
            var prevInCol:Int = colList.length > 0 ? colList[colList.length - 1] : -1;
            var colStrainTime:Float = prevInCol >= 0 ? cur.startTime - objects[prevInCol].startTime : cur.startTime;
            var m:ManiaObj = {
                startTime: cur.startTime,
                endTime: cur.endTime,
                column: col,
                index: idx,
                deltaTime: delta,
                previousIndex: i - 1,
                previousStart: prev.startTime,
                previousHitByColumn: prevHit,
                columnStrainTime: colStrainTime
            };
            objects.push(m);
            colList.push(idx);
            prevByColumn[col] = idx;
        }

        var individualStrains:Array<Float> = [];
        for (i in 0...totalColumns) individualStrains.push(0);

        var highestIndividualStrain:Float = 0;
        var overallStrain:Float = 1;
        var currentStrain:Float = 0;
        var sectionLength:Int = 400;
        var decayWeight:Float = 0.9;
        var currentSectionPeak:Float = 0;
        var currentSectionEnd:Float = Math.ceil(objects[0].startTime / sectionLength) * sectionLength;
        var strainPeaks:Array<Float> = [];

        for (obj in objects)
        {
            while (obj.startTime > currentSectionEnd)
            {
                strainPeaks.push(currentSectionPeak);
                var offset = currentSectionEnd;
                var prevStart = obj.previousStart;
                var initial = applyDecay(highestIndividualStrain, offset - prevStart, 0.125)
                    + applyDecay(overallStrain, offset - prevStart, 0.30);
                currentSectionPeak = initial;
                currentSectionEnd += sectionLength;
            }

            var col = obj.column;
            individualStrains[col] = applyDecay(individualStrains[col], obj.columnStrainTime, 0.125);
            var indAdd = evaluateIndividual(obj, objects, totalColumns);
            individualStrains[col] += indAdd;
            highestIndividualStrain = obj.deltaTime <= 1
                ? Math.max(highestIndividualStrain, individualStrains[col])
                : individualStrains[col];

            overallStrain = applyDecay(overallStrain, obj.deltaTime, 0.30);
            var overallAdd = evaluateOverall(obj, objects, totalColumns);
            overallStrain += overallAdd;

            var sValueOf = highestIndividualStrain + overallStrain - currentStrain;
            currentStrain += sValueOf;
            currentSectionPeak = Math.max(currentStrain, currentSectionPeak);
        }

        var peaks:Array<Float> = [];
        for (p in strainPeaks) if (p > 0) peaks.push(p);
        if (currentSectionPeak > 0) peaks.push(currentSectionPeak);

        peaks.sort(function(a, b) return a > b ? -1 : (a < b ? 1 : 0));

        var difficulty:Float = 0;
        var weight:Float = 1;
        for (p in peaks)
        {
            difficulty += p * weight;
            weight *= decayWeight;
        }

        return difficulty * 0.018;
    }

    static function resolvePlayableLane(sec:SwagSection, rawLane:Int, song:SwagSong, mode:String):Int
    {
        var gottaHit:Bool = sec.mustHitSection;

        // 如果 lane 超过 mania 范围，说明该 note 属于另一侧
        if (rawLane > song.mania)
        {
            gottaHit = !sec.mustHitSection;
        }

        // 彻底三分支：只依据传入的 mode，不再读取 playOpponent
        var mustPress:Bool;
        switch (mode)
        {
            case MODE_OPPONENT:
                // 只算对手侧
                mustPress = !gottaHit;
            case MODE_COOP:
                // 两侧都算
                mustPress = true;
            default: // MODE_NORMAL
                // 只算玩家侧
                mustPress = gottaHit;
        }

        if (!mustPress) return -1;

        var columns:Int = song.mania + 1;
        if (columns <= 0) columns = 4;
        var lane = rawLane % columns;

        // 从 gameplaySettings 读取镜像谱面设置，替代 ClientPrefs.data.flipChart
        var flipChart:Bool = ClientPrefs.getGameplaySetting('mirrornotes', false, true);
        if (flipChart && columns == 4)
        {
            lane -= Std.int((lane - 1.5) * 2);
        }
        return lane;
    }

    static inline function applyDecay(value:Float, deltaTime:Float, decayBase:Float):Float
    {
        return value * Math.pow(decayBase, deltaTime / 1000);
    }

    static function evaluateIndividual(obj:ManiaObj, objects:Array<ManiaObj>, totalColumns:Int):Float
    {
        var start = obj.startTime;
        var end = obj.endTime;
        var holdFactor:Float = 1.0;
        for (c in 0...totalColumns)
        {
            var idx = obj.previousHitByColumn[c];
            if (idx < 0) continue;
            var prev = objects[idx];
            if (defBigger(prev.endTime, end, 1) && defBigger(start, prev.startTime, 1))
            {
                holdFactor = 1.25;
                break;
            }
        }
        return 2.0 * holdFactor;
    }

    static function evaluateOverall(obj:ManiaObj, objects:Array<ManiaObj>, totalColumns:Int):Float
    {
        var start = obj.startTime;
        var end = obj.endTime;
        var isOverlapping = false;
        var closestEndTime:Float = Math.abs(end - start);
        var holdFactor:Float = 1.0;
        for (c in 0...totalColumns)
        {
            var idx = obj.previousHitByColumn[c];
            if (idx < 0) continue;
            var prev = objects[idx];
            if (defBigger(prev.endTime, start, 1) && defBigger(end, prev.endTime, 1) && defBigger(start, prev.startTime, 1))
                isOverlapping = true;
            if (defBigger(prev.endTime, end, 1) && defBigger(start, prev.startTime, 1))
                holdFactor = 1.25;
            var diff = Math.abs(end - prev.endTime);
            if (diff < closestEndTime) closestEndTime = diff;
        }
        var holdAddition:Float = 0;
        if (isOverlapping) holdAddition = logistic(closestEndTime, 30, 0.27, 1);
        return (1 + holdAddition) * holdFactor;
    }

    static inline function logistic(x:Float, midpointOffset:Float, multiplier:Float, maxValue:Float = 1):Float
    {
        return maxValue / (1 + Math.exp(multiplier * (midpointOffset - x)));
    }

    static inline function defBigger(a:Float, b:Float, eps:Float):Bool
    {
        return a > b + eps;
    }

    ///////////////////////////////////////////////////////////////////////////
    // 颜色工具（来自 NovaFlare StarRect）
    ///////////////////////////////////////////////////////////////////////////

    /**
     * 按 [0, 1] 的值取 osu 风格七彩渐变颜色。
     * 超出范围自动 clamp。
     */
    public static function getColor(value:Float):FlxColor
    {
        if (value <= STOPS[0].value) return STOPS[0].color;
        var last = STOPS[STOPS.length - 1];
        if (value >= last.value) return last.color;

        for (i in 0...STOPS.length - 1)
        {
            var a = STOPS[i];
            var b = STOPS[i + 1];
            if (value <= b.value)
            {
                var denom = b.value - a.value;
                var t = denom == 0 ? 1 : (value - a.value) / denom;
                if (t < 0) t = 0;
                if (t > 1) t = 1;
                return FlxColor.interpolate(a.color, b.color, t);
            }
        }
        return last.color;
    }

    /**
     * 把评分（默认 0~MAX_RATING）归一化到 [0, 1] 后取色。
     */
    public static function getColorFromRating(rating:Float, maxRating:Float = MAX_RATING):FlxColor
    {
        if (maxRating <= 0) return getColor(0);
        return getColor(rating / maxRating);
    }

    /**
     * 把评分格式化成 "X.XX" 字符串。
     */
    public static function formatRating(rating:Float):String
    {
        return Std.string(Math.floor(rating * 100) / 100);
    }

    /**
     * 便捷方法：直接把 calcForSong 的结果转成颜色。
     */
    public static function getColorForSong(song:SwagSong, ?mode:String = MODE_NORMAL):FlxColor
    {
        return getColorFromRating(calcForSong(song, mode));
    }

    /**
     * 便捷方法：直接把 calcForSong 的结果转成文字。
     */
    public static function getTextForSong(song:SwagSong, ?mode:String = MODE_NORMAL):String
    {
        return formatRating(calcForSong(song, mode));
    }
}

typedef ManiaObj = {
    var startTime:Float;
    var endTime:Float;
    var column:Int;
    var index:Int;
    var deltaTime:Float;
    var previousIndex:Int;
    var previousStart:Float;
    var previousHitByColumn:Array<Int>;
    var columnStrainTime:Float;
}