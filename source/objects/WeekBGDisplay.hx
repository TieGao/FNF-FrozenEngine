package objects;

import flixel.FlxSprite;
import flixel.FlxG;
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
    
    public function showWeek(weekKey:String, modFolder:String = "", animated:Bool = true):Void
    {
        if (weekKey == null || weekKey.length == 0 || (currentWeekKey == weekKey && currentModFolder == modFolder && visible))
            return;
        
        cancelAllTweens();
        
        currentWeekKey = weekKey;
        currentModFolder = modFolder;
        
        var oldModDir = Mods.currentModDirectory;
        if (modFolder != null && modFolder.length > 0 && modFolder != "base")
            Mods.currentModDirectory = modFolder;
        
        var config:WeekBGData = WeekBGConfig.getConfigForWeek(weekKey);
        
        if (config == null)
        {
            hide();
            Mods.currentModDirectory = oldModDir;
            return;
        }
        
        // 加载所有需要的图片（如果还没加载）
        for (elem in config.elements)
        {
            if (!elementSprites.exists(elem.name))
            {
                createElement(elem);
            }
        }
        
        // 动画移动所有元素到目标位置
        if (animated)
        {
            for (elem in config.elements)
            {
                var sprite = elementSprites.get(elem.name);
                if (sprite != null)
                {
                    animateElement(sprite, elem);
                }
            }
        }
        else
        {
            for (elem in config.elements)
            {
                var sprite = elementSprites.get(elem.name);
                if (sprite != null)
                {
                    setElementPosition(sprite, elem);
                }
            }
        }
        
        visible = true;
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
    
    private function animateElement(sprite:FlxSprite, elem:WeekBGElement):Void
    {
        var targetX:Float = elem.targetX != null ? elem.targetX : DEFAULT_X;
        var targetY:Float = elem.targetY != null ? elem.targetY : DEFAULT_Y;
        var targetAlpha:Float = elem.targetAlpha != null ? elem.targetAlpha : DEFAULT_ALPHA;
        
        // 使用 Reflect 动态获取，避免编译错误
        var duration:Float = 0.5;
        var ease:Dynamic = FlxEase.expoOut;
        
        if (Reflect.hasField(elem, "duration") && Reflect.field(elem, "duration") != null)
            duration = Reflect.field(elem, "duration");
        
        if (Reflect.hasField(elem, "ease") && Reflect.field(elem, "ease") != null)
            ease = WeekBGConfig.getEaseFunction(Reflect.field(elem, "ease"));
        
        var tween = FlxTween.tween(sprite, {
            x: targetX,
            y: targetY,
            alpha: targetAlpha
        }, duration, { ease: ease });
        
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