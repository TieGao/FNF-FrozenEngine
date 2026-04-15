package objects;

import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.group.FlxGroup;
import backend.WeekBGConfig;
import backend.Paths;
import backend.Mods;

class WeekBGDisplay extends FlxTypedGroup<FlxSprite>
{
    private static var DEFAULT_X:Float = -5000;
    private static var DEFAULT_Y:Float = -5000;
    private static var DEFAULT_ALPHA:Float = 0;
    
    private var currentWeekKey:String = "";
    private var currentModFolder:String = "";
    private var elementSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    private var elementConfigs:Map<String, WeekBGElement> = new Map<String, WeekBGElement>();
    private var activeTweens:Array<FlxTween> = [];
    
    public function new()
    {
        super();
        visible = false;
    }
    
    public function switchToWeek(newWeekKey:String, modFolder:String = "", animated:Bool = true):Void
    {
        if (newWeekKey == null || newWeekKey.length == 0 || (currentWeekKey == newWeekKey && currentModFolder == modFolder && visible))
            return;
        
        cancelAllTweens();
        
        var oldModDir = Mods.currentModDirectory;
        if (modFolder != null && modFolder.length > 0 && modFolder != "base")
            Mods.currentModDirectory = modFolder;
        
        var newConfig:WeekBGData = WeekBGConfig.getConfigForWeek(newWeekKey);
        var oldConfig:WeekBGData = WeekBGConfig.getConfigForWeek(currentWeekKey);
        
        // 如果新周目没有配置，隐藏
        if (newConfig == null)
        {
            hide();
            Mods.currentModDirectory = oldModDir;
            currentWeekKey = newWeekKey;
            currentModFolder = modFolder;
            return;
        }
        
        // 加载新周目的元素
        for (elem in newConfig.elements)
        {
            if (!elementSprites.exists(elem.name))
            {
                createElement(elem);
            }
        }
        
        if (animated)
        {
            // 应用旧周目的退出动画
            if (oldConfig != null && oldConfig.exitTransitions != null)
            {
                for (trans in oldConfig.exitTransitions)
                {
                    var sprite = elementSprites.get(trans.elementName);
                    if (sprite != null)
                    {
                        animateTransition(sprite, trans);
                    }
                }
            }
            else
            {
                // 默认退出动画
                for (sprite in elementSprites)
                {
                    FlxTween.tween(sprite, {
                        x: DEFAULT_X,
                        y: DEFAULT_Y,
                        alpha: DEFAULT_ALPHA
                    }, 0.5, { ease: FlxEase.expoOut });
                }
            }
            
            // 应用新周目的进入动画
            for (trans in newConfig.transitions)
            {
                var sprite = elementSprites.get(trans.elementName);
                if (sprite != null)
                {
                    animateTransition(sprite, trans);
                }
            }
        }
        else
        {
            // 非动画模式，直接设置位置
            for (elem in newConfig.elements)
            {
                var sprite = elementSprites.get(elem.name);
                if (sprite != null)
                {
                    setElementPosition(sprite, elem);
                }
            }
        }
        
        visible = true;
        currentWeekKey = newWeekKey;
        currentModFolder = modFolder;
        Mods.currentModDirectory = oldModDir;
    }
    
    private function createElement(elem:WeekBGElement):Void
    {
        var graphic = Paths.image('storybackgrounds/' + elem.image, null, true);
        if (graphic == null) return;
        
        var sprite = new FlxSprite();
        sprite.loadGraphic(graphic);
        
        // 设置缩放
        var scaleX:Float = elem.scaleX != null ? elem.scaleX : 1.0;
        var scaleY:Float = elem.scaleY != null ? elem.scaleY : 1.0;
        sprite.setGraphicSize(Std.int(sprite.width * scaleX), Std.int(sprite.height * scaleY));
        sprite.updateHitbox();
        
        // 设置滚动因子
        var scrollX:Float = elem.scrollX != null ? elem.scrollX : 1.0;
        var scrollY:Float = elem.scrollY != null ? elem.scrollY : 1.0;
        sprite.scrollFactor.set(scrollX, scrollY);
        
        // 先放到默认位置
        sprite.x = DEFAULT_X;
        sprite.y = DEFAULT_Y;
        sprite.alpha = DEFAULT_ALPHA;
        
        // 设置层级
        var layer:Int = elem.layer != null ? elem.layer : 1;
        var insertIndex:Int = 0;
        for (i in 0...members.length)
        {
            var existingLayer:Int = 1;
            for (key in elementSprites.keys())
            {
                if (elementSprites.get(key) == members[i])
                {
                    var existingConfig = elementConfigs.get(key);
                    if (existingConfig != null)
                        existingLayer = existingConfig.layer != null ? existingConfig.layer : 1;
                    break;
                }
            }
            if (existingLayer > layer) break;
            insertIndex++;
        }
        
        add(sprite);
        elementSprites.set(elem.name, sprite);
        elementConfigs.set(elem.name, elem);
    }
    
    private function animateTransition(sprite:FlxSprite, trans:WeekBGTransition):Void
    {
        var easeFunc:Dynamic = WeekBGConfig.getEaseFunction(trans.ease);
        var tweenOptions:Dynamic = { ease: easeFunc };
        if (trans.delay > 0)
        {
            tweenOptions.startDelay = trans.delay;
        }
        
        var tweenData:Dynamic = {};
        Reflect.setField(tweenData, trans.property, trans.toValue);
        
        var tween = FlxTween.tween(sprite, tweenData, trans.duration, tweenOptions);
        activeTweens.push(tween);
    }

    private function setElementPosition(sprite:FlxSprite, elem:WeekBGElement):Void
    {
        sprite.x = elem.targetX != null ? elem.targetX : DEFAULT_X;
        sprite.y = elem.targetY != null ? elem.targetY : DEFAULT_Y;
        sprite.alpha = elem.targetAlpha != null ? elem.targetAlpha : DEFAULT_ALPHA;
    }
    
    public function resetAllToDefault():Void
    {
        for (sprite in elementSprites)
        {
            FlxTween.tween(sprite, {
                x: DEFAULT_X,
                y: DEFAULT_Y,
                alpha: DEFAULT_ALPHA
            }, 0.3, { ease: FlxEase.expoOut });
        }
    }
    
    public function hide():Void
    {
        cancelAllTweens();
        resetAllToDefault();
        visible = false;
        currentWeekKey = "";
    }
    
    private function cancelAllTweens():Void
    {
        for (tween in activeTweens)
        {
            if (tween != null) tween.cancel();
        }
        activeTweens = [];
    }
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
    }
}