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
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import backend.Paths;
import backend.Language;

class HitErrorBar extends FlxSpriteGroup
{
    public var timingBar:FlxSprite;
    public var pointer:FlxSprite;
    public var middleLine:FlxSprite;
    public var hitBars:FlxTypedSpriteGroup<FlxSprite>;
    
    // 打击note竖线相关
    public var hitNotes:FlxTypedSpriteGroup<FlxSprite>;
    var hitNoteTimers:Array<Float> = [];
    var maxHitNotes:Int = ClientPrefs.data.hitBarLines;
    var hitNoteDuration:Float = ClientPrefs.data.hitBarLineTime;
    
    // ms显示文本
    var currentMsText:FlxText = null;
    
    var currentMS:Float = 0;
    var targetMS:Float = 0;
    var maxTiming:Float = 0;
    
    var returnTimer:Float = 0;
    var shouldReturn:Bool = false;
    var returning:Bool = false;
    
    var barWidth:Float;
    var barHeight:Float = 5;
    
    // 组本身的原点就在中心，所有子对象相对于中心定位
    var centerX:Float = 0;
    var centerY:Float = 0;
    
    var ratingColors:Map<String, FlxColor> = [
        'marvelous' => FlxColor.fromRGB(255, 215, 0),
        'sick'      => FlxColor.fromRGB(135, 206, 235),
        'good'      => FlxColor.fromRGB(0, 255, 0),
        'bad'       => FlxColor.fromRGB(255, 0, 0),
        'shit'      => FlxColor.fromRGB(139, 0, 0)
    ];
    
    public function new()
    {
        super();
        
        barWidth = FlxG.width * 0.25;
        maxTiming = 166;
        
        createTimingBar();
        createPointer();
        createMiddleLine();
        createHitBars();
        createHitNotes();
        
        // 设置组的宽高
        this.width = timingBar.width;
        this.height = 50;
        
        // 修正组的原点到左上角
        this.x = 0;
        this.y = 0;
        
        this.alpha = 0.7;
    }
    
    public function setHitNoteConfig(maxNotes:Int = 5, duration:Float = 2.0)
    {
        maxHitNotes = maxNotes;
        hitNoteDuration = duration;
        
        if (hitNotes != null && hitNotes.length > maxHitNotes)
        {
            for (i in maxHitNotes...hitNotes.members.length)
            {
                var note = hitNotes.members[i];
                if (note != null)
                {
                    note.kill();
                    note.destroy();
                }
            }
            while (hitNotes.members.length > maxHitNotes)
                hitNotes.members.pop();
            while (hitNoteTimers.length > maxHitNotes)
                hitNoteTimers.pop();
        }
    }
    
    function createTimingBar()
    {
        var marvWindow = ClientPrefs.data.marvelousWindow;
        var sickWindow = ClientPrefs.data.sickWindow;
        var goodWindow = ClientPrefs.data.goodWindow;
        var badWindow = ClientPrefs.data.badWindow;
        
        var totalWidth = barWidth;
        var bitmapData = new BitmapData(Std.int(totalWidth), Std.int(barHeight), true);
        var centerX = totalWidth / 2;
        var pixelsPerMs = centerX / maxTiming;
        
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
        timingBar.x = 0;
        timingBar.y = 20; // 在组内向下偏移一点
        add(timingBar);
    }
    
    function createPointer()
    {
        var style = ClientPrefs.data.pointerType;
        var pointerColor = FlxColor.WHITE;
        
        pointer = new FlxSprite().makeGraphic(16, 20, FlxColor.TRANSPARENT);
        
        switch(style)
        {
        case 'inverted': // 倒三角
            FlxSpriteUtil.drawPolygon(pointer, [
                FlxPoint.get(0, 0),
                FlxPoint.get(8, 20),
                FlxPoint.get(16, 0)
            ], pointerColor);
            // 倒三角向下移动更多
            pointer.y = timingBar.y - pointer.height + 6; // 原来是 +2，改为 +6
            
        case 'thick_line': // 粗竖线 I形
            var lineWidth = 6;
            var lineHeight = 20;
            var centerX = Std.int((pointer.width - lineWidth) / 2);
            
            FlxSpriteUtil.drawRect(pointer, centerX, 0, lineWidth, lineHeight, pointerColor);
            FlxSpriteUtil.drawRect(pointer, 0, 0, pointer.width, 3, pointerColor);
            FlxSpriteUtil.drawRect(pointer, 0, lineHeight - 3, pointer.width, 3, pointerColor);
            // 粗竖线向下移动
            pointer.y = timingBar.y - pointer.height + 10; // 原来是 +2，改为 +5
                
            default: // 原三角 (default)
                FlxSpriteUtil.drawPolygon(pointer, [
                    FlxPoint.get(0, 20),
                    FlxPoint.get(8, 0),
                    FlxPoint.get(16, 20)
                ], pointerColor);
                pointer.y = timingBar.y - pointer.height + 2;
        }
        
        pointer.updateHitbox();
        pointer.x = (timingBar.width / 2) - (pointer.width / 2);
        add(pointer);
    }
    
    function createMiddleLine()
    {
        middleLine = new FlxSprite().makeGraphic(2, 20, FlxColor.WHITE);
        middleLine.x = (timingBar.width / 2) - 1;
        middleLine.y = timingBar.y - 8;
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
    
    function createHitNotes()
    {
        hitNotes = new FlxTypedSpriteGroup<FlxSprite>();
        hitNoteTimers = [];
        for (i in 0...maxHitNotes)
        {
            var noteLine = new FlxSprite().makeGraphic(2, 24, FlxColor.WHITE);
            noteLine.updateHitbox(); // <-- 添加这行确保宽高正确
            noteLine.visible = false;
            noteLine.active = false;
            noteLine.alpha = 0;
            hitNotes.add(noteLine);
            hitNoteTimers.push(0);
        }
        add(hitNotes);
    }
    
    function showMsText(ms:Float, xPos:Float, ratingName:String)
    {
        if (ClientPrefs.data.hideHud || !ClientPrefs.data.msInErrorBar) return;
        
        if (currentMsText != null)
        {
            FlxTween.cancelTweensOf(currentMsText);
            if (this.members.contains(currentMsText))
            {
                this.remove(currentMsText);
            }
            currentMsText.destroy();
            currentMsText = null;
        }
        
        currentMsText = new FlxText(0, 0, 0, "", 16);
        if (Language.getPhrase('ms', 'ms').contains('ms')) 
        {
            currentMsText.setFormat(Paths.font('pixel-latin.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        }
        else
        {    
            currentMsText.antialiasing = ClientPrefs.data.antialiasing;
            currentMsText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        }
        
        var msTiming:Float = Math.round(Math.abs(ms) * 100) / 100;
        var sign:String = ms >= 0 ? "-" : "+";
        currentMsText.text = sign + msTiming + Language.getPhrase('ms', 'ms');
        currentMsText.updateHitbox();
        
        if (ClientPrefs.data.customColor)
        {
            switch(ratingName.toLowerCase())
            {
                case 'sick': currentMsText.color = ratingColors['sick'];
                case 'good': currentMsText.color = ratingColors['good'];
                case 'bad': currentMsText.color = ratingColors['bad'];
                case 'shit': currentMsText.color = ratingColors['shit'];
                default: currentMsText.color = FlxColor.WHITE;
            }
        }
        currentMsText.x = (timingBar.width / 2) - (currentMsText.width / 2);
        currentMsText.y = 25;

        add(currentMsText);
        
        FlxTween.tween(currentMsText, {alpha: 0}, 0.2 / states.PlayState.instance.playbackRate, {
            ease: FlxEase.quadOut,
            onComplete: function(tween:FlxTween) {
                if (currentMsText != null && this.members.contains(currentMsText))
                {
                    this.remove(currentMsText);
                    currentMsText.destroy();
                    currentMsText = null;
                }
            },
            startDelay: Conductor.crochet * 0.004 / states.PlayState.instance.playbackRate
        });
    }
    
    function getRatingName(ms:Float):String
    {
        var absMs = Math.abs(ms);
        if (absMs <= ClientPrefs.data.marvelousWindow)
            return 'marvelous';
        else if (absMs <= ClientPrefs.data.sickWindow)
            return 'sick';
        else if (absMs <= ClientPrefs.data.goodWindow)
            return 'good';
        else if (absMs <= ClientPrefs.data.badWindow)
            return 'bad';
        else
            return 'shit';
    }
    
    public function addHitNote(ms:Float, noteDirection:Int = 0)
    {
        var centerX = timingBar.x + timingBar.width / 2;
        var halfBar = timingBar.width / 2;
        var percent = ms / maxTiming;
        percent = FlxMath.bound(percent, -1, 1);
        var xPos = centerX + percent * halfBar;
        
        var absMs = Math.abs(ms);
        var color:FlxColor;
        var ratingName = getRatingName(ms);
        
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
        
        if (noteDirection != 0)
        {
            if (noteDirection < 0)
                color = color.getLightened(0.2);
            else if (noteDirection > 0)
            {
                var rgb = color.to24Bit();
                var r = (rgb >> 16) & 0xFF;
                var g = (rgb >> 8) & 0xFF;
                var b = rgb & 0xFF;
                r = Std.int(Math.min(255, r * 1.2));
                color = FlxColor.fromRGB(r, g, b);
            }
        }
        
        var foundSlot = false;
        for (i in 0...maxHitNotes)
        {
            if (hitNoteTimers[i] <= 0)
            {
                var noteLine = hitNotes.members[i];
                if (noteLine != null)
                {
                    // 修正：xPos 已经是相对于 timingBar 左边缘的位置，直接使用
                    // 但要确保竖线居中于 xPos
                    noteLine.x = xPos - (noteLine.width / 2);
                    noteLine.y = timingBar.y - 15;
                    noteLine.color = color;
                    noteLine.alpha = 0.9;
                    noteLine.visible = true;
                    noteLine.active = true;
                    hitNoteTimers[i] = hitNoteDuration;
                    foundSlot = true;
                    break;
                }
            }
        }
        
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
                noteLine.x = xPos - (noteLine.width / 2);
                noteLine.y = timingBar.y - 15;
                noteLine.color = color;
                noteLine.alpha = 0.9;
                noteLine.visible = true;
                noteLine.active = true;
                hitNoteTimers[oldestIndex] = hitNoteDuration;
            }
        }
        
        showMsText(ms, xPos, ratingName);
        this.alpha = 0.9;
    }
    
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
        
        if (currentMsText != null)
        {
            FlxTween.cancelTweensOf(currentMsText);
            if (this.members.contains(currentMsText))
            {
                this.remove(currentMsText);
            }
            currentMsText.destroy();
            currentMsText = null;
        }
    }
    
    public function registerHit(ms:Float, noteDirection:Int = 0)
    {
        currentMS = ms;
        targetMS = ms;
        returnTimer = 2.0;
        shouldReturn = false;
        returning = false;
        addHitMarker(ms);
        addHitNote(ms, noteDirection);
        updatePointerColor();
        this.alpha = 0.9;
    }
    
    function calculatePointerX(ms:Float):Float
    {
        var centerX = timingBar.x + timingBar.width / 2;   // 基于 timingBar 的实际左边缘
        var halfBar = timingBar.width / 2;
        if (ms == 0) return centerX - pointer.width / 2;
        var percent = ms / maxTiming;
        percent = FlxMath.bound(percent, -1, 1);
        return centerX + percent * halfBar - pointer.width / 2;
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
        var centerX = timingBar.x + timingBar.width / 2;
        var halfBar = timingBar.width / 2;
        var percent = ms / maxTiming;
        percent = FlxMath.bound(percent, -1, 1);
        var xPos = centerX + percent * halfBar - bar.width / 2;
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
        var centerX = timingBar.width / 2;
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
        addHitNote(maxTiming, noteDirection);
        this.alpha = 0.9;
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (targetMS != 0 && !returning)
        {
            returnTimer -= elapsed;
            if (returnTimer <= 0)
            {
                shouldReturn = true;
                returning = true;
            }
        }
        
        if (shouldReturn && returning)
        {
            targetMS = FlxMath.lerp(targetMS, 0, 0.1);
            currentMS = targetMS;
            if (Math.abs(targetMS) < 0.5)
            {
                targetMS = 0;
                currentMS = 0;
                shouldReturn = false;
                returning = false;
            }
            updatePointerColor();
        }
        
        var targetX = calculatePointerX(targetMS);
        pointer.x = FlxMath.lerp(pointer.x, targetX, 0.3);
        
        for (i in 0...maxHitNotes)
        {
            if (hitNoteTimers[i] > 0)
            {
                hitNoteTimers[i] -= elapsed;
                var noteLine = hitNotes.members[i];
                if (noteLine != null && noteLine.visible)
                {
                    if (hitNoteTimers[i] < 0.5)
                        noteLine.alpha = FlxMath.lerp(0, 0.9, hitNoteTimers[i] / 0.5);
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
        
        if (alpha > 0.5)
            alpha -= 0.3 * elapsed;
    }
    
    public function resetAll()
    {
        currentMS = 0;
        targetMS = 0;
        returnTimer = 0;
        shouldReturn = false;
        returning = false;
        pointer.x = (timingBar.width / 2) - (pointer.width / 2);
        pointer.color = FlxColor.WHITE;
        for (bar in hitBars)
        {
            bar.visible = false;
            bar.kill();
        }
        clearHitNotes();
        this.alpha = 0.7;
    }
}