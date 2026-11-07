package backend;

import backend.Song;

/**
 * Diff Rate 计算器 + NovaFlare 风格 osu 评分取色工具。
 *
 * 本版本配套 backend.Song.hx：
 *   backend.Song.parseJSON -> convert() 会把 note[1] 归一化为
 *     玩家侧: 0 .. columns-1
 *     对手侧: columns .. 2*columns-1
 *   其中 columns = song.mania + 1（4K 时 mania=3, columns=4）。
 * 标准谱按 [0, columns) / [columns, 2*columns) 区分两侧；
 * noConvert 自定义谱启用轨道拆分时，按原始键数的一半区分两侧。
 *
 *   因此这里 resolvePlayableLane 不再读取 section.mustHitSection，
 *   也不再使用 rawLane > song.mania 去翻转归属，
 *   直接按归一化后的 lane 判断玩家侧 / 对手侧。
 *
 * 模式：
 *   normal   = 只算玩家侧
 *   opponent = 只算对手侧
 *   coop     = 两侧都算
 *
 * 设置读取：
 *   - opponentplay -> normal / opponent / coop
 *   - mirrornotes  -> 按当前 K 数镜像
 *
 * 性能约定（2026-11 转化器优化）：
 *   calcForSong 每次调用会重新建一遍对象数组。Freeplay 预载对同一份谱面要算三套，
 *   改用 calcForSongAllModes：只建一次、排序一次，三个模式各走一份索引视图。
 *   两条路径共用 buildObjects / calcStrain，结果必须逐位相同。
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

    /**
     * 单个模式的评分。
     * @param mirrorNotes 显式指定镜像开关；null = 读 ClientPrefs（默认行为不变）。
     *                    后台线程必须显式传入 —— ClientPrefs 的 Map 是主线程可写的。
     */
    public static function calcForSong(song:SwagSong, ?mode:String = MODE_NORMAL, ?splitCustomTracks:Bool = false,
                                       ?mirrorNotes:Null<Bool> = null):Float
    {
        if (song == null || song.notes == null || song.notes.length == 0) return 0;

        mode = normalizeMode(mode);

        var columns:Int = getColumnCount(song, splitCustomTracks);
        var mirror:Bool = (mirrorNotes != null) ? mirrorNotes : ClientPrefs.getGameplaySetting('mirrornotes', false, true);

        var objs:Array<RawNote> = buildRawNotes(song, columns, splitCustomTracks, mirror, mode);
        if (objs.length <= 1) return 0;

        sortByStartTime(objs);

        var idx:Array<Int> = [];
        for (i in 0...objs.length) idx.push(i);

        return calcStrain(buildObjects(objs, idx, columns), columns);
    }

    /**
     * 三套评级一次算完：对象只建一遍、排序只做一次。
     * Freeplay 预载专用；结果必须与连续调三次 calcForSong 逐位相同。
     */
    public static function calcForSongAllModes(song:SwagSong, ?splitCustomTracks:Bool = false,
                                               ?mirrorNotes:Null<Bool> = null):{normal:Float, opponent:Float, coop:Float}
    {
        var zero:{normal:Float, opponent:Float, coop:Float} = {normal: 0, opponent: 0, coop: 0};
        if (song == null || song.notes == null || song.notes.length == 0) return zero;

        var columns:Int = getColumnCount(song, splitCustomTracks);
        var mirror:Bool = (mirrorNotes != null) ? mirrorNotes : ClientPrefs.getGameplaySetting('mirrornotes', false, true);

        // mode 传 null = 两侧都收，之后再按 side 分索引视图
        var raw:Array<RawNote> = buildRawNotes(song, columns, splitCustomTracks, mirror, null);
        if (raw.length == 0) return zero;

        sortByStartTime(raw);

        var normalIdx:Array<Int> = [];
        var opponentIdx:Array<Int> = [];
        var coopIdx:Array<Int> = [];
        for (i in 0...raw.length)
        {
            coopIdx.push(i);
            if (raw[i].opponent) opponentIdx.push(i);
            else normalIdx.push(i);
        }

        return {
            normal: calcStrain(buildObjects(raw, normalIdx, columns), columns),
            opponent: calcStrain(buildObjects(raw, opponentIdx, columns), columns),
            coop: calcStrain(buildObjects(raw, coopIdx, columns), columns)
        };
    }

    /**
     * 建「音符原始列表」。
     * mode 非空时只收该模式参与的音符；null 时两侧都收（供 calcForSongAllModes 分视图）。
     *
     * 性能要点：columns / boundary / mirror 三个量全部提到循环外。
     * 旧实现每个音符要调两次 Song.isOpponentLane（内部各 3 次 Reflect），
     * 再加一次 ClientPrefs.getGameplaySetting —— 千音符谱面就是上万次反射。
     * 这里用完全等价的 boundary 比较替代，语义不变。
     */
    private static function buildRawNotes(song:SwagSong, columns:Int, splitCustomTracks:Bool, mirror:Bool, mode:String):Array<RawNote>
    {
        var out:Array<RawNote> = [];

        var keyCount:Int = Song.getKeyCount(song);
        var split:Bool = Song.shouldSplitCustomTracks(song, splitCustomTracks);
        var boundary:Int = split ? Std.int(keyCount / 2) : keyCount;

        var wantPlayer:Bool = (mode != MODE_OPPONENT);
        var wantOpponent:Bool = (mode != MODE_NORMAL);

        for (sec in song.notes)
        {
            if (sec == null) continue;
            var notes:Array<Dynamic> = sec.sectionNotes;
            if (notes == null) continue;
            for (n in notes)
            {
                if (n == null || n.length < 2) continue;
                var rawLane:Int = Std.int(n[1]);
                if (rawLane < 0) continue;

                var isOpponent:Bool = rawLane >= boundary;
                if (isOpponent && !wantOpponent) continue;
                if (!isOpponent && !wantPlayer) continue;

                var start:Float = n[0];
                var sustain:Float = (n.length >= 3 && n[2] != null) ? n[2] : 0.0;
                var end:Float = start + (sustain > 0 ? sustain : 0);

                var lane:Int = rawLane % columns;
                if (lane < 0) lane += columns;
                if (mirror) lane = columns - 1 - lane;

                out.push({startTime: start, endTime: end, lane: lane, opponent: isOpponent});
            }
        }
        return out;
    }

    private static inline function sortByStartTime(objs:Array<RawNote>):Void
    {
        // 比较器必须与原实现一致（同 startTime 返回 0）。
        // ★ 这里依赖排序的稳定性：calcForSongAllModes 是「全量排序 + 按侧过滤」，
        //   而 calcForSong 是「按侧过滤 + 排序」，两者只有在稳定排序下才会得到同样的并列顺序。
        //   hxcpp 的 Array.sort 走 std::stable_sort（hxcpp/include/Array.h:908），成立。
        objs.sort(function(a, b) return a.startTime < b.startTime ? -1 : (a.startTime > b.startTime ? 1 : 0));
    }

    /**
     * 按索引视图构造 ManiaObj 序列。idx 必须是已按 startTime 升序的 raw 下标。
     * 与原实现逐行对应：objects[k] 对应 idx[k+1]，previousIndex 记的是视图内序号。
     */
    private static function buildObjects(raw:Array<RawNote>, idx:Array<Int>, columns:Int):Array<ManiaObj>
    {
        var objects:Array<ManiaObj> = [];
        if (idx.length <= 1) return objects;

        var perColumn:Array<Array<Int>> = [];
        for (i in 0...columns) perColumn.push([]);
        var prevByColumn:Array<Int> = [];
        for (i in 0...columns) prevByColumn.push(-1);

        for (i in 1...idx.length)
        {
            var prev:RawNote = raw[idx[i - 1]];
            var cur:RawNote = raw[idx[i]];
            var valueIndex:Int = objects.length;
            var delta:Float = cur.startTime - prev.startTime;
            var prevHit:Array<Int> = prevByColumn.copy();
            var col:Int = cur.lane;
            if (col < 0) col = 0;
            if (col >= columns) col = columns - 1;
            var colList:Array<Int> = perColumn[col];
            var prevInCol:Int = colList.length > 0 ? colList[colList.length - 1] : -1;
            var colStrainTime:Float = prevInCol >= 0
                ? cur.startTime - objects[prevInCol].startTime
                : cur.startTime;

            var m:ManiaObj = {
                startTime: cur.startTime,
                endTime: cur.endTime,
                column: col,
                index: valueIndex,
                deltaTime: delta,
                previousIndex: i - 1,
                previousStart: prev.startTime,
                previousHitByColumn: prevHit,
                columnStrainTime: colStrainTime
            };
            objects.push(m);
            colList.push(valueIndex);
            prevByColumn[col] = valueIndex;
        }
        return objects;
    }

    /** 原 strain 循环，逐行保持不变。objects 为空时返回 0（对应旧实现的 objs.length <= 1）。 */
    private static function calcStrain(objects:Array<ManiaObj>, columns:Int):Float
    {
        if (objects.length == 0) return 0;

        var individualStrains:Array<Float> = [];
        for (i in 0...columns) individualStrains.push(0);

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
            var indAdd = evaluateIndividual(obj, objects, columns);
            individualStrains[col] += indAdd;
            highestIndividualStrain = obj.deltaTime <= 1
                ? Math.max(highestIndividualStrain, individualStrains[col])
                : individualStrains[col];

            overallStrain = applyDecay(overallStrain, obj.deltaTime, 0.30);
            var overallAdd = evaluateOverall(obj, objects, columns);
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

    ///////////////////////////////////////////////////////////////////////////
    // lane 解析（配套 backend.Song.hx 的归一化 lane）
    ///////////////////////////////////////////////////////////////////////////

    public static function getColumnCount(song:SwagSong, ?splitCustomTracks:Bool = false):Int
    {
        return Song.getPlayableColumnCount(song, splitCustomTracks);
    }

    /**
     * 标准谱归一化后：
     *   rawLane ∈ [0, columns)          -> 玩家侧
     *   rawLane ∈ [columns, 2*columns)  -> 对手侧
     *
     * 返回该 note 在“可游玩侧”的列索引（0 .. columns-1），
     * 若该 note 不属于当前 mode 的可游玩侧则返回 -1。
     *
     * 注：calcForSong / calcForSongAllModes 已把等价逻辑内联进 buildRawNotes（避免每音符反射），
     *     这个函数保留给外部单点调用。
     */
    public static function resolvePlayableLane(rawLane:Int, song:SwagSong, mode:String, columns:Int, splitCustomTracks:Bool,
                                               ?mirrorNotes:Null<Bool> = null):Int
    {
        var isOpponentSide:Bool = Song.isOpponentLane(rawLane, song, splitCustomTracks);

        var mustPress:Bool;
        switch (mode)
        {
            case MODE_OPPONENT:
                mustPress = isOpponentSide;
            case MODE_COOP:
                mustPress = true;
            default: // MODE_NORMAL
                mustPress = !isOpponentSide;
        }

        if (!mustPress) return -1;

        var lane:Int = rawLane % columns;
        if (lane < 0) lane += columns;

        var flipChart:Bool = (mirrorNotes != null) ? mirrorNotes : ClientPrefs.getGameplaySetting('mirrornotes', false, true);
        if (flipChart) lane = columns - 1 - lane;

        return lane;
    }

    ///////////////////////////////////////////////////////////////////////////
    // 算法辅助（与原版一致，未改动）
    ///////////////////////////////////////////////////////////////////////////

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

/** 排序前的原始音符（只保留评分需要的字段，避免 ManiaObj 那些派生字段的分配）。 */
typedef RawNote = {
    var startTime:Float;
    var endTime:Float;
    var lane:Int;
    var opponent:Bool;
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
