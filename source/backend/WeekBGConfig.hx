package backend;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import flixel.tweens.FlxEase;
#if MODS_ALLOWED
import backend.Mods;
#end

using StringTools;

typedef WeekBGData = {
    var weekKey:String;              // 周目唯一标识（fileName 或 weekName）
    var background:String;
    var elements:Array<WeekBGElement>;
    var transitions:Array<WeekBGTransition>;
    var ?exitTransitions:Array<WeekBGTransition>;
}

typedef WeekBGElement = {
    var name:String;
    var image:String;
    var x:Float;
    var y:Float;
    var ?targetX:Float;
    var ?targetY:Float;
    var ?scaleX:Float;
    var ?scaleY:Float;
    var ?alpha:Float;
    var ?targetAlpha:Float;
    var ?scrollX:Float;
    var ?scrollY:Float;
    var ?layer:Int;
    var ?animated:Bool;
    var ?animationName:String;
    var ?frames:String;
}

typedef WeekBGTransition = {
    var elementName:String;
    var property:String;
    var fromValue:Float;
    var toValue:Float;
    var duration:Float;
    var ?ease:String;
    var ?delay:Float;
}

class WeekBGConfig
{
    private static var weekConfigs:Map<String, WeekBGData> = new Map<String, WeekBGData>();
    private static var loadedMods:Array<String> = [];
    
    public static function getEaseFunction(easeName:String):Dynamic
    {
        switch (easeName)
        {
            case "expoOut": return FlxEase.expoOut;
            case "expoIn": return FlxEase.expoIn;
            case "expoInOut": return FlxEase.expoInOut;
            case "quadOut": return FlxEase.quadOut;
            case "quadIn": return FlxEase.quadIn;
            case "quadInOut": return FlxEase.quadInOut;
            case "circOut": return FlxEase.circOut;
            case "circIn": return FlxEase.circIn;
            case "circInOut": return FlxEase.circInOut;
            case "sineOut": return FlxEase.sineOut;
            case "sineIn": return FlxEase.sineIn;
            case "sineInOut": return FlxEase.sineInOut;
            case "backOut": return FlxEase.backOut;
            case "backIn": return FlxEase.backIn;
            case "backInOut": return FlxEase.backInOut;
            case "elasticOut": return FlxEase.elasticOut;
            case "elasticIn": return FlxEase.elasticIn;
            case "elasticInOut": return FlxEase.elasticInOut;
            case "bounceOut": return FlxEase.bounceOut;
            case "bounceIn": return FlxEase.bounceIn;
            case "bounceInOut": return FlxEase.bounceInOut;
            case "linear": return FlxEase.linear;
            default: return FlxEase.expoOut;
        }
    }
    
    public static function loadAllConfigs():Void
    {
        trace('WeekBGConfig.loadAllConfigs() called');
        weekConfigs.clear();
        loadedMods = [];
        
        #if MODS_ALLOWED
        var enabledMods:Array<String> = Mods.parseList().enabled;
        trace('Enabled mods: ' + enabledMods);
        
        for (mod in enabledMods)
        {
            if (mod != null && mod.length > 0 && mod != "base")
            {
                tryLoadModConfig(mod);
            }
        }
        
        if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && Mods.currentModDirectory != "base")
        {
            if (!enabledMods.contains(Mods.currentModDirectory))
            {
                tryLoadModConfig(Mods.currentModDirectory);
            }
        }
        #end
        
       // trace('WeekBGConfig loaded, total configs: ' + weekConfigs.count());
    }
    
    public static function tryLoadModConfig(modName:String):Void
    {
        if (loadedMods.contains(modName)) return;
        
        var configPath:String = 'mods/$modName/weekBackgrounds.json';
        
        if (!FileSystem.exists(configPath))
        {
            trace('No weekBackgrounds.json found for mod: $modName');
            return;
        }
        
        trace('Loading week backgrounds config from: $configPath');
        loadedMods.push(modName);
        
        try
        {
            var content:String = File.getContent(configPath);
            var parsed:Dynamic = Json.parse(content);
            
            if (parsed.weeks != null && Std.is(parsed.weeks, Array))
            {
                var weeksArray:Array<Dynamic> = parsed.weeks;
                for (weekData in weeksArray)
                {
                    parseWeekConfig(weekData, modName);
                }
            }
            else if (Std.is(parsed, Array))
            {
                var weeksArray:Array<Dynamic> = parsed;
                for (weekData in weeksArray)
                {
                    parseWeekConfig(weekData, modName);
                }
            }
            else
            {
                parseWeekConfig(parsed, modName);
            }
            
            trace('Successfully loaded config for mod: $modName');
        }
        catch (e:Dynamic)
        {
            trace('Error loading week backgrounds config from $modName: $e');
        }
    }
    
    private static function parseWeekConfig(data:Dynamic, modName:String):Void
    {
        // weekKey 可以是 fileName 或 weekName
        var weekKey:String = data.weekKey != null ? Std.string(data.weekKey) : null;
        
        // 兼容旧的 weekId 格式
        if (weekKey == null && data.weekId != null)
        {
            weekKey = Std.string(data.weekId);
        }
        
        // 兼容旧的 weekFileName 格式
        if (weekKey == null && data.weekFileName != null)
        {
            weekKey = Std.string(data.weekFileName);
        }
        
        // 兼容旧的 weekName 格式
        if (weekKey == null && data.weekName != null)
        {
            weekKey = Std.string(data.weekName);
        }
        
        if (weekKey == null)
        {
            trace('Warning: week config has no weekKey/weekId/weekFileName/weekName, skipping');
            return;
        }
        
        trace('Parsing week config for weekKey: ' + weekKey);
        
        var bgData:WeekBGData = {
            weekKey: weekKey,
            background: data.background != null ? Std.string(data.background) : "",
            elements: [],
            transitions: []
        };
        
        // 解析元素
        if (data.elements != null && Std.is(data.elements, Array))
        {
            var elementsArray:Array<Dynamic> = data.elements;
            for (elem in elementsArray)
            {
                var element:WeekBGElement = {
                    name: elem.name,
                    image: elem.image,
                    x: elem.x != null ? Std.parseFloat(Std.string(elem.x)) : 0,
                    y: elem.y != null ? Std.parseFloat(Std.string(elem.y)) : 0,
                    targetX: elem.targetX != null ? Std.parseFloat(Std.string(elem.targetX)) : null,
                    targetY: elem.targetY != null ? Std.parseFloat(Std.string(elem.targetY)) : null,
                    scaleX: elem.scaleX != null ? Std.parseFloat(Std.string(elem.scaleX)) : 1.0,
                    scaleY: elem.scaleY != null ? Std.parseFloat(Std.string(elem.scaleY)) : 1.0,
                    alpha: elem.alpha != null ? Std.parseFloat(Std.string(elem.alpha)) : 1.0,
                    targetAlpha: elem.targetAlpha != null ? Std.parseFloat(Std.string(elem.targetAlpha)) : null,
                    scrollX: elem.scrollX != null ? Std.parseFloat(Std.string(elem.scrollX)) : 1.0,
                    scrollY: elem.scrollY != null ? Std.parseFloat(Std.string(elem.scrollY)) : 1.0,
                    layer: elem.layer != null ? Std.parseInt(Std.string(elem.layer)) : 1,
                    animated: elem.animated != null ? Std.string(elem.animated) == "true" : false,
                    animationName: elem.animationName != null ? Std.string(elem.animationName) : null,
                    frames: elem.frames != null ? Std.string(elem.frames) : null
                };
                bgData.elements.push(element);
                trace('Added element: ' + element.name);
            }
        }
        
        // 解析过渡动画
        if (data.transitions != null && Std.is(data.transitions, Array))
        {
            var transitionsArray:Array<Dynamic> = data.transitions;
            for (trans in transitionsArray)
            {
                var transition:WeekBGTransition = {
                    elementName: trans.elementName,
                    property: trans.property,
                    fromValue: trans.fromValue != null ? Std.parseFloat(Std.string(trans.fromValue)) : 0,
                    toValue: trans.toValue != null ? Std.parseFloat(Std.string(trans.toValue)) : 0,
                    duration: trans.duration != null ? Std.parseFloat(Std.string(trans.duration)) : 0.5,
                    ease: trans.ease != null ? Std.string(trans.ease) : "expoOut",
                    delay: trans.delay != null ? Std.parseFloat(Std.string(trans.delay)) : 0
                };
                bgData.transitions.push(transition);
            }
        }
        
        // 解析退出过渡动画
        if (data.exitTransitions != null && Std.is(data.exitTransitions, Array))
        {
            bgData.exitTransitions = [];
            var exitTransitionsArray:Array<Dynamic> = data.exitTransitions;
            for (trans in exitTransitionsArray)
            {
                var transition:WeekBGTransition = {
                    elementName: trans.elementName,
                    property: trans.property,
                    fromValue: trans.fromValue != null ? Std.parseFloat(Std.string(trans.fromValue)) : 0,
                    toValue: trans.toValue != null ? Std.parseFloat(Std.string(trans.toValue)) : 0,
                    duration: trans.duration != null ? Std.parseFloat(Std.string(trans.duration)) : 0.5,
                    ease: trans.ease != null ? Std.string(trans.ease) : "expoOut",
                    delay: trans.delay != null ? Std.parseFloat(Std.string(trans.delay)) : 0
                };
                bgData.exitTransitions.push(transition);
            }
        }
        
        weekConfigs.set(weekKey.toLowerCase(), bgData);
        trace('Week config stored for weekKey: ' + weekKey + ', elements: ' + bgData.elements.length);
    }
    
    public static function getConfigForWeek(weekKey:String):WeekBGData
    {
        if (weekKey == null || weekKey.length == 0) return null;
        
        var keyLower = weekKey.toLowerCase();
        var config = weekConfigs.get(keyLower);
        
        if (config != null)
        {
            trace('Found config for weekKey: ' + weekKey);
        }
        else
        {
            trace('No config found for weekKey: ' + weekKey);
        }
        
        return config;
    }
    
    public static function hasConfig(weekKey:String):Bool
    {
        return weekKey != null && weekConfigs.exists(weekKey.toLowerCase());
    }
    
    public static function reset():Void
    {
        weekConfigs.clear();
        loadedMods = [];
    }
}