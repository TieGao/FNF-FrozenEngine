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
import flixel.FlxG;

class HitErrorBar extends FlxSpriteGroup
{
    public var timingBar:FlxSprite;
    public var pointer:FlxSprite;
    public var middleLine:FlxSprite;
    public var hitBars:FlxTypedSpriteGroup<FlxSprite>;
    
    // 新增：打击note竖线相关
    public var hitNotes:FlxTypedSpriteGroup<FlxSprite>;
    var hitNoteTimers:Array<Float> = [];
    var maxHitNotes:Int = ClientPrefs.data.hitBarLines; // 可配置：同一时间最多显示的数量
    var hitNoteDuration:Float = ClientPrefs.data.hitBarLineTime; // 可配置：显示持续时间（秒）
    
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
        createHitNotes(); // 新增：创建打击note竖线容器
        
        this.alpha = 0.7;
        
        screenCenter();
        y = FlxG.height * 0.6;
    }
    
    // 新增：配置函数
    public function setHitNoteConfig(maxNotes:Int = 5, duration:Float = 2.0)
    {
        maxHitNotes = maxNotes;
        hitNoteDuration = duration;
        
        // 如果减少了最大数量，清理多余的竖线
        if (hitNotes != null && hitNotes.length > maxHitNotes)
        {
            // 不能直接设置length，需要手动清理
            for (i in maxHitNotes...hitNotes.members.length)
            {
                var note = hitNotes.members[i];
                if (note != null)
                {
                    note.kill();
                    note.destroy();
                }
            }
            // 重新设置数组长度
            while (hitNotes.members.length > maxHitNotes)
            {
                hitNotes.members.pop();
            }
            while (hitNoteTimers.length > maxHitNotes)
            {
                hitNoteTimers.pop();
            }
        }
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
    
    // 新增：创建打击note竖线容器
    function createHitNotes()
    {
        hitNotes = new FlxTypedSpriteGroup<FlxSprite>();
        hitNoteTimers = [];
        
        // 创建最大数量的竖线（全部预创建以提高性能）
        for (i in 0...maxHitNotes)
        {
            // 创建竖线：宽度2像素，高度略高于中间的标志线
            var noteLine = new FlxSprite().makeGraphic(2, 24, FlxColor.WHITE);
            noteLine.visible = false;
            noteLine.active = false;
            noteLine.alpha = 0; // 初始透明
            hitNotes.add(noteLine);
            hitNoteTimers.push(0);
        }
        
        add(hitNotes);
    }
    
    // 新增：添加打击note竖线
    public function addHitNote(ms:Float, noteDirection:Int = 0)
    {
        // 计算竖线位置
        var centerX = timingBar.x + (timingBar.width / 2);
        var halfBar = timingBar.width / 2;
        var percent = ms / maxTiming;
        percent = FlxMath.bound(percent, -1, 1);
        var xPos = centerX + (percent * halfBar);
        
        // 根据偏移量和note方向选择颜色（可以根据方向使用不同颜色）
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
        
        // 如果有方向信息，可以根据方向微调颜色
        if (noteDirection != 0)
        {
            // 可以根据note方向调整颜色亮度或色调
            // 例如：左侧note稍微偏蓝，右侧note稍微偏红
            if (noteDirection < 0)
                color = color.getLightened(0.2); // 左侧亮一点
            else if (noteDirection > 0)
            {
                // 右侧偏红
                var rgb = color.to24Bit();
                var r = (rgb >> 16) & 0xFF;
                var g = (rgb >> 8) & 0xFF;
                var b = rgb & 0xFF;
                r = Std.int(Math.min(255, r * 1.2));
                color = FlxColor.fromRGB(r, g, b);
            }
        }
        
        // 查找可用的竖线槽位
        var foundSlot = false;
        for (i in 0...maxHitNotes)
        {
            if (hitNoteTimers[i] <= 0)
            {
                var noteLine = hitNotes.members[i];
                if (noteLine != null)
                {
                    // 设置竖线位置（中心对齐）
                    noteLine.setPosition(xPos - noteLine.width / 2, timingBar.y - 15);
                    noteLine.color = color;
                    noteLine.alpha = 0.9; // 初始透明度
                    noteLine.visible = true;
                    noteLine.active = true;
                    
                    // 重置计时器
                    hitNoteTimers[i] = hitNoteDuration;
                    
                    foundSlot = true;
                    break;
                }
            }
        }
        
        // 如果所有槽位都在使用中，替换最旧的
        if (!foundSlot)
        {
            var oldestIndex = 0;
            var oldestTime = hitNoteTimers[0];
            
            for (i in 1...maxHitNotes)
            {
                if (hitNoteTimers[i] < oldestTime)
                {
                    oldestTime = hitNoteTimers[i];
                    oldestIndex = i;
                }
            }
            
            var noteLine = hitNotes.members[oldestIndex];
            if (noteLine != null)
            {
                noteLine.setPosition(xPos - noteLine.width / 2, timingBar.y - 15);
                noteLine.color = color;
                noteLine.alpha = 0.9;
                noteLine.visible = true;
                noteLine.active = true;
                
                hitNoteTimers[oldestIndex] = hitNoteDuration;
            }
        }
        
        // 重置整个条目的透明度
        this.alpha = 0.9;
    }
    
    // 新增：删除所有打击note竖线（重置时调用）
    public function clearHitNotes()
    {
        for (i in 0...maxHitNotes)
        {
            var noteLine = hitNotes.members[i];
            if (noteLine != null)
            {
                noteLine.visible = false;
                noteLine.active = false;
                noteLine.alpha = 0;
            }
            hitNoteTimers[i] = 0;
        }
    }
    
    // 修改：更新registerHit函数，添加打击note竖线
    public function registerHit(ms:Float, noteDirection:Int = 0)
    {
        currentMS = ms;
        targetMS = ms;
        
        // 重置计时器
        returnTimer = 2.0; // 2秒
        shouldReturn = false;
        returning = false;
        
        // 添加命中标记
        addHitMarker(ms);
        
        // 新增：添加打击note竖线
        addHitNote(ms, noteDirection);
        
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
        var bar = hitBars.recycle();
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
    
    public function registerMiss(noteDirection:Int = 0)
    {
        var bar = hitBars.recycle();
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
        
        // 新增：为miss也添加竖线（放在最右边，灰色）
        addHitNote(maxTiming, noteDirection); // miss时放在最右边
        
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
        
        // 新增：更新打击note竖线的计时器和淡出效果
        for (i in 0...maxHitNotes)
        {
            if (hitNoteTimers[i] > 0)
            {
                hitNoteTimers[i] -= elapsed;
                
                var noteLine = hitNotes.members[i];
                if (noteLine != null && noteLine.visible)
                {
                    // 计算剩余时间的比例
                    var timeRatio = hitNoteTimers[i] / hitNoteDuration;
                    
                    // 在最后0.5秒开始淡出
                    if (hitNoteTimers[i] < 0.5)
                    {
                        noteLine.alpha = FlxMath.lerp(0, 0.9, hitNoteTimers[i] / 0.5);
                    }
                    
                    // 计时结束，隐藏竖线
                    if (hitNoteTimers[i] <= 0)
                    {
                        noteLine.visible = false;
                        noteLine.active = false;
                        noteLine.alpha = 0;
                        hitNoteTimers[i] = 0;
                    }
                }
            }
        }
        
        // 逐渐降低透明度
        if (alpha > 0.5)
            alpha -= 0.3 * elapsed;
    }
    
    // 新增：自定义重置函数（不是override父类的reset）
    public function resetAll()
    {
        currentMS = 0;
        targetMS = 0;
        returnTimer = 0;
        shouldReturn = false;
        returning = false;
        
        // 重置指针位置
        pointer.x = timingBar.x + (timingBar.width / 2) - (pointer.width / 2);
        pointer.color = FlxColor.WHITE;
        
        // 清除所有打击标记
        for (bar in hitBars)
        {
            bar.visible = false;
            bar.kill();
        }
        
        // 清除所有打击note竖线
        clearHitNotes();
        
        this.alpha = 0.7;
    }
}