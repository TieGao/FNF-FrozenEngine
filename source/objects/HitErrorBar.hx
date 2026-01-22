package objects;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.util.FlxSpriteUtil;
import flixel.tweens.FlxTween;
import backend.ClientPrefs;

class HitErrorBar extends FlxSpriteGroup
{
    public var timingBar:FlxSprite;
    public var pointer:FlxSprite;
    public var middleLine:FlxSprite;
    public var hitBars:FlxTypedSpriteGroup<FlxSprite>;
    
    var currentMS:Float = 0;
    var targetMS:Float = 0;
    var maxTiming:Float = 0;
    
    // 计时器相关
    var returnTimer:Float = 0;
    var shouldReturn:Bool = false;
    var returning:Bool = false;
    
    var barWidth:Float = 300;
    var barHeight:Float = 5;
    
    // 颜色：
    var ratingColors:Map<String, FlxColor> = [
        'marvelous' => FlxColor.fromRGB(255, 215, 0),     // 金色
        'sick'      => FlxColor.fromRGB(135, 206, 235),   // 天蓝色
        'good'      => FlxColor.fromRGB(0, 255, 0),       // 绿色
        'bad'       => FlxColor.fromRGB(255, 0, 0),       // 红色
        'shit'      => FlxColor.fromRGB(139, 0, 0)        // 深红色
    ];
    
    public function new()
    {
        super();
        
        var marvWindow = ClientPrefs.data.marvelousWindow;
        var sickWindow = ClientPrefs.data.sickWindow;
        var goodWindow = ClientPrefs.data.goodWindow;
        var badWindow = ClientPrefs.data.badWindow;
        maxTiming = 166;
        
        createTimingBar(marvWindow, sickWindow, goodWindow, badWindow);
        createPointer();
        createMiddleLine();
        createHitBars();
        
        this.alpha = 0.7;
        
        screenCenter();
        y = FlxG.height * 0.6;
    }
    
    function createTimingBar(marvWindow:Float, sickWindow:Float, goodWindow:Float, badWindow:Float)
    {
        var totalWidth = barWidth;
        var bitmapData = new BitmapData(Std.int(totalWidth), Std.int(barHeight), true);
        var centerX = totalWidth / 2;
        var pixelsPerMs = centerX / maxTiming;
        
        // 左侧区域
        var currentX = 0.0;
        var shitWidth = (166 - badWindow) * pixelsPerMs;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, shitWidth, barHeight), ratingColors['shit']);
        currentX += shitWidth;
        
        var badWidth = (badWindow - goodWindow) * pixelsPerMs;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, badWidth, barHeight), ratingColors['bad']);
        currentX += badWidth;
        
        var goodWidth = (goodWindow - sickWindow) * pixelsPerMs;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, goodWidth, barHeight), ratingColors['good']);
        currentX += goodWidth;
        
        var sickWidth = (sickWindow - marvWindow) * pixelsPerMs;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, sickWidth, barHeight), ratingColors['sick']);
        currentX += sickWidth;
        
        var marvWidth = marvWindow * pixelsPerMs;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, marvWidth, barHeight), ratingColors['marvelous']);
        
        // 右侧区域
        currentX = centerX;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, marvWidth, barHeight), ratingColors['marvelous']);
        currentX += marvWidth;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, sickWidth, barHeight), ratingColors['sick']);
        currentX += sickWidth;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, goodWidth, barHeight), ratingColors['good']);
        currentX += goodWidth;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, badWidth, barHeight), ratingColors['bad']);
        currentX += badWidth;
        bitmapData.fillRect(new openfl.geom.Rectangle(currentX, 0, shitWidth, barHeight), ratingColors['shit']);
        
        timingBar = new FlxSprite().loadGraphic(FlxGraphic.fromBitmapData(bitmapData));
        timingBar.updateHitbox();
        timingBar.x = FlxG.width / 2 - timingBar.width / 2;
        add(timingBar);
    }
    
    function createPointer()
    {
        pointer = new FlxSprite().makeGraphic(12, 16, FlxColor.TRANSPARENT);
        
        FlxSpriteUtil.drawPolygon(pointer, [
            FlxPoint.get(0, 16),
            FlxPoint.get(6, 0),
            FlxPoint.get(12, 16)
        ], FlxColor.WHITE);
        
        pointer.updateHitbox();
        pointer.x = timingBar.x + (timingBar.width / 2) - (pointer.width / 2);
        pointer.y = timingBar.y - pointer.height + 2;
        add(pointer);
    }
    
    function createMiddleLine()
    {
        middleLine = new FlxSprite().makeGraphic(2, 20, FlxColor.WHITE);
        middleLine.x = timingBar.x + (timingBar.width / 2) - 1;
        middleLine.y = timingBar.y - 10;
        add(middleLine);
    }
    
    function createHitBars()
    {
        hitBars = new FlxTypedSpriteGroup<FlxSprite>();
        for (i in 0...20)
        {
            var bar = new FlxSprite().makeGraphic(2, 14, FlxColor.WHITE);
            bar.visible = false;
            hitBars.add(bar);
        }
        add(hitBars);
    }
    
    public function registerHit(ms:Float)
    {
        currentMS = ms;
        targetMS = ms;
        
        // 重置计时器
        returnTimer = 5.0; // 2秒
        shouldReturn = false;
        returning = false;
        
        // 添加命中标记
        addHitMarker(ms);
        
        // 更新指针颜色
        updatePointerColor();
        
        this.alpha = 0.9;
    }
    
    function calculatePointerX(ms:Float):Float
    {
        var centerX = timingBar.x + (timingBar.width / 2);
        
        if (ms == 0) return centerX - (pointer.width / 2);
        
        var percent = ms / maxTiming;
        percent = FlxMath.bound(percent, -1, 1);
        var halfBar = timingBar.width / 2;
        return centerX + (percent * halfBar) - (pointer.width / 2);
    }
    
    function updatePointerColor()
    {
        var absMs = Math.abs(currentMS);
        if (absMs <= ClientPrefs.data.marvelousWindow)
            pointer.color = ratingColors['marvelous'];
        else if (absMs <= ClientPrefs.data.sickWindow)
            pointer.color = ratingColors['sick'];
        else if (absMs <= ClientPrefs.data.goodWindow)
            pointer.color = ratingColors['good'];
        else if (absMs <= ClientPrefs.data.badWindow)
            pointer.color = ratingColors['bad'];
        else
            pointer.color = ratingColors['shit'];
    }
    
    function addHitMarker(ms:Float)
    {
        var bar = hitBars.getFirstAvailable();
        if (bar == null) return;
        
        var centerX = timingBar.x + (timingBar.width / 2);
        var halfBar = timingBar.width / 2;
        var percent = ms / maxTiming;
        percent = FlxMath.bound(percent, -1, 1);
        var xPos = centerX + (percent * halfBar) - (bar.width / 2);
        
        bar.setPosition(xPos, timingBar.y - 12);
        
        var absMs = Math.abs(ms);
        var color:FlxColor;
        
        if (absMs <= ClientPrefs.data.marvelousWindow)
            color = ratingColors['marvelous'];
        else if (absMs <= ClientPrefs.data.sickWindow)
            color = ratingColors['sick'];
        else if (absMs <= ClientPrefs.data.goodWindow)
            color = ratingColors['good'];
        else if (absMs <= ClientPrefs.data.badWindow)
            color = ratingColors['bad'];
        else
            color = ratingColors['shit'];
        
        bar.color = color;
        bar.alpha = 0.8;
        bar.visible = true;
        
        FlxTween.tween(bar, {alpha: 0}, 1, {
            onComplete: function(twn:FlxTween) {
                bar.visible = false;
                bar.kill();
            }
        });
    }
    
    public function registerMiss()
    {
        var bar = hitBars.getFirstAvailable();
        if (bar == null) return;
        
        var centerX = timingBar.x + (timingBar.width / 2);
        var halfBar = timingBar.width / 2;
        var xPos = centerX + halfBar - (bar.width / 2);
        
        bar.setPosition(xPos, timingBar.y - 12);
        bar.color = FlxColor.GRAY;
        bar.alpha = 0.8;
        bar.visible = true;
        
        FlxTween.tween(bar, {alpha: 0}, 1, {
            onComplete: function(twn:FlxTween) {
                bar.visible = false;
                bar.kill();
            }
        });
        
        this.alpha = 0.9;
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // 更新计时器
        if (targetMS != 0 && !returning)
        {
            returnTimer -= elapsed;
            if (returnTimer <= 0)
            {
                shouldReturn = true;
                returning = true;
            }
        }
        
        // 如果需要回中且正在回中
        if (shouldReturn && returning)
        {
            // 平滑回中
            targetMS = FlxMath.lerp(targetMS, 0, 0.1);
            currentMS = targetMS;
            
            // 当接近中心时停止回中
            if (Math.abs(targetMS) < 0.5)
            {
                targetMS = 0;
                currentMS = 0;
                shouldReturn = false;
                returning = false;
            }
            
            updatePointerColor();
        }
        
        // 平滑移动到目标位置
        var targetX = calculatePointerX(targetMS);
        pointer.x = FlxMath.lerp(pointer.x, targetX, 0.3);
        
        // 逐渐降低透明度
        if (alpha > 0.5)
            alpha -= 0.3 * elapsed;
    }
}