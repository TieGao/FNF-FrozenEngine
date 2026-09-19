package options.groupData;

import options.objects.OptionCategory;
import options.Option;
import flixel.FlxG;

class GraphicsData
{
    // ---------- 分辨率表（标签 -> [w, h]） ----------
    public static var normalResolutionMap:Map<String, Array<Int>> = [
        "1280x720"  => [1280, 720],
        "1600x900"  => [1600, 900],
        "1920x1080" => [1920, 1080],
        "2560x1440" => [2560, 1440],
        "3840x2160" => [3840, 2160]
    ];

    public static var wideResolutionMap:Map<String, Array<Int>> = [
        "1680x720"  => [1680, 720],
        "2520x1080" => [2520, 1080],
        "3360x1440" => [3360, 1440],
        "5040x2160" => [5040, 2160]
    ];

    static var NORMAL_LABELS:Array<String> = ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"];
    static var WIDE_LABELS:Array<String>   = ["1680x720", "2520x1080", "3360x1440", "5040x2160"];

    // ---------- 上次已应用快照 ----------
    static var _lastLabel:String = null;
    static var _lastWide:Bool = false;
    static var _lastDpi:Bool = false;
    static var _hooked:Bool = false;
    static var _resOpt:Option = null;

    // ========================================================
    // 构建选项页
    // ========================================================
    public static function build():OptionCategory
    {
        _tryHook();

        var cat = new OptionCategory('Graphics', 'Graphics', 'specIcon');
        var sub = cat.section("Graphics", "Graphics");

        _resOpt = new Option('Resolution', 'Change the game\'s render resolution.',
            'renderResolution', STRING, getResolutionLabels());
        _resOpt.onChange = checkAndApplyResolution;
        sub.add(_resOpt);

        sub.add(new Option('Low Quality', 'Reduce graphics for performance', 'lowQuality', BOOL));
        sub.add(new Option('Anti-Aliasing', 'Smoother visuals', 'antialiasing', BOOL));

        var dpiOpt = new Option('dpiScale', 'Scale the game based on your screen\'s DPI', 'useDpiSettings', BOOL);
        dpiOpt.onChange = checkAndApplyResolution;
        sub.add(dpiOpt);

        sub.add(new Option('Shaders', 'Enable shader effects', 'shaders', BOOL));

        var wideOpt = new Option('Wide Screen', 'Enable 21:9 widescreen mode', 'wideScreen', BOOL);
        wideOpt.onChange = function() {
            // 切换宽屏时同步分辨率选项列表 + 强制重新应用
            _syncResolutionOptions();
            _forceApply();
        };
        sub.add(wideOpt);

        sub.add(new Option('GPU Caching', 'Use GPU for texture caching', 'cacheOnGPU', BOOL));
        sub.add(new Option('Devide Draw And Update', 'Draw and Update in separate threads', 'devideDrawAndUpdate', BOOL));

        var fps = new Option('Framerate', 'Target framerate', 'framerate', INT);
        fps.minValue = 60; fps.maxValue = 480; fps.changeValue = 1; sub.add(fps);

        var ups = new Option('Update Rate', 'Target update rate', 'updaterate', INT);
        ups.minValue = 60; ups.maxValue = 480; ups.changeValue = 1; sub.add(ups);

        sub.add(new Option('Unlimited FPS', 'Remove framerate cap (also for update rate)', 'unlimitedFPS', BOOL));
        sub.add(new Option('FPS Rework', 'Make ur game more smooth', 'fpsRework', BOOL));

        var sub2 = cat.section('FPSCounter', 'FPS Counter');
        sub2.add(new Option('FPS Counter', 'Show FPS counter', 'showFPS', BOOL));
        sub2.add(new Option('Show OS', 'Show operating system in FPS Counter', 'showOS', BOOL));
        sub2.add(new Option('Show API', 'Show graphics API in FPS Counter', 'showApi', BOOL));
        sub2.add(new Option('Show TPS', 'Show ticks per second in FPS Counter', 'showTPS', BOOL));
        sub2.add(new Option('Show Memory Peak', 'Show peak memory usage in FPS Counter', 'showMEMPeak', BOOL));

        // 首次构建时同步一次，并确保初始状态被应用
        _syncResolutionOptions();

        return cat;
    }

    // ========================================================
    // 查询
    // ========================================================
    public static inline function isWide():Bool
    {
        if (ClientPrefs.data == null) return false;
        return cast Reflect.field(ClientPrefs.data, 'wideScreen');
    }

    public static inline function isDpi():Bool
    {
        if (ClientPrefs.data == null) return false;
        return cast Reflect.field(ClientPrefs.data, 'useDpiSettings');
    }

    public static function getResolutionLabels(?wide:Bool = null):Array<String>
        return ((wide != null ? wide : isWide()) ? WIDE_LABELS : NORMAL_LABELS).copy();

    public static function getResolutionSize(label:String, wide:Bool):Array<Int>
    {
        var map = wide ? wideResolutionMap : normalResolutionMap;
        return (label != null && map.exists(label))
            ? map.get(label)
            : map.get(wide ? "1680x720" : "1280x720");
    }

    // ========================================================
    // 唯一入口：检测并应用
    // ========================================================
    public static function checkAndApplyResolution():Void
    {
        _tryHook();
        _applyIfChanged(false);
    }

    // 强制应用（用于宽屏切换这种结构性变化）
    static function _forceApply():Void
    {
        _tryHook();
        _applyIfChanged(true);
    }

    // ========================================================
    // 内部实现
    // ========================================================
    static function _tryHook():Void
    {
        if (_hooked) return;
        try
        {
            if (FlxG.signals != null)
            {
                FlxG.signals.preUpdate.add(function() _applyIfChanged(false));
                _hooked = true;
            }
        }
        catch (e:Dynamic) {}
    }

    /**
     * 让 _resOpt.options / curOption 与当前 wideScreen 状态保持一致。
     * 若当前存储值不在新列表里，则回退到列表首项并写回 ClientPrefs。
     */
    static function _syncResolutionOptions():Void
    {
        if (_resOpt == null || ClientPrefs.data == null) return;

        var labels = getResolutionLabels();
        _resOpt.options = labels;

        var s:String = ClientPrefs.data.renderResolution != null
            ? StringTools.trim(Std.string(ClientPrefs.data.renderResolution))
            : null;

        var idx:Int = -1;
        if (s != null) idx = labels.indexOf(s);

        if (idx < 0)
        {
            idx = 0;
            ClientPrefs.data.renderResolution = labels[0];
        }

        _resOpt.curOption = idx;
    }

    /**
     * @param force  true = 跳过快照比较强制重应用；false = 仅在状态变化时应用
     */
    static function _applyIfChanged(force:Bool = false):Void
    {
        #if (cpp || hl)
        if (ClientPrefs.data == null) return;

        var label:String = _readLabel();
        if (label == null) return;

        // 规范化写回
        var raw:String = ClientPrefs.data.renderResolution != null
            ? StringTools.trim(Std.string(ClientPrefs.data.renderResolution))
            : null;
        if (raw != label)
            ClientPrefs.data.renderResolution = label;

        var wide:Bool = isWide();
        var dpi:Bool  = isDpi();

        if (!force && label == _lastLabel && wide == _lastWide && dpi == _lastDpi)
            return;

        var success:Bool = false;
        try
        {
            _apply(label, wide, dpi);
            success = true;
        }
        catch (e:Dynamic)
        {
            trace('[GraphicsData] _apply failed: $e');
            success = false;
        }

        // 只有真正成功时才更新快照，避免失败后被永久跳过
        if (success)
        {
            _lastLabel = label;
            _lastWide  = wide;
            _lastDpi   = dpi;
        }
        #end
    }

    static function _readLabel():String
    {
        if (ClientPrefs.data == null) return null;

        // 直接读，不做 hasField 检测
        var raw:Dynamic = ClientPrefs.data.renderResolution;
        if (raw == null) return null;

        var labels:Array<String> = getResolutionLabels();
        var s:String = StringTools.trim(Std.string(raw));
        if (labels.indexOf(s) >= 0) return s;

        // 不在当前列表（比如宽屏状态刚切换）→ 返回 null，让调用方跳过
        return null;
    }

    static function _apply(label:String, wide:Bool, dpi:Bool):Void
    {
        #if (cpp || hl)
        var labels:Array<String> = getResolutionLabels(wide);
        var idx:Int = labels.indexOf(label);
        if (idx < 0) idx = 0;

        // DPI 模式：只改逻辑尺寸，不调整窗口
        // 非 DPI 模式：调整窗口 + 逻辑尺寸
        var resizeWindow:Bool = !dpi;

        trace('[GraphicsData] applying label=$label wide=$wide dpi=$dpi idx=$idx resizeWindow=$resizeWindow');
        Main.applyRenderResolution(idx, wide, resizeWindow);
        #end
    }
}