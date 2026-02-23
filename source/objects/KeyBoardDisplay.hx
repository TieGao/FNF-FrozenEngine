//已废弃
package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import openfl.display.Shape;
import openfl.display.BitmapData;
import backend.Controls;
import backend.InputFormatter;
import backend.Conductor;
import states.PlayState;
import flixel.graphics.FlxGraphic;

// 时间显示数据
typedef TimeDisplayData = {
    var sprite:FlxSprite;
    var startTime:Float;
    var endTime:Float;
    var keyIndex:Int;
}

class KeyboardDisplay extends FlxSpriteGroup
{
    // 按键精灵
    public var keySprites:Array<FlxSprite> = [];
    
    // 按键覆盖层（按键按下效果）
    public var keyOverlays:Array<FlxSprite> = [];
    
    // 按键标签（显示按键字符）
    public var keyLabels:Array<FlxText> = [];
    
    // 瀑布效果显示数组
    private var waterfallDisplays:Array<Array<WaterfallSprite>> = [];
    
    // 按键尺寸
    public static var keySize:Int = 50;
    private var keySpacing:Int = 4;
    
    // 位置
    public var displayX:Float = 0 + ClientPrefs.data.kbOffsetX;
    public var displayY:Float = 0 + ClientPrefs.data.kbOffsetY;
    
    // 键位数量
    public var keys:Int = 4;
    
    // 瀑布效果显示高度
    private var waterfallHeight:Int = Std.int(keySize * 3);
    
    // 显示设置
    private var displayAlpha:Float = 0.8;
    private var bgColor:FlxColor = FlxColor.GRAY;
    private var textColor:FlxColor = FlxColor.WHITE;
    private var overlayColor:FlxColor = FlxColor.WHITE;
    
    public function new(X:Float = 0, Y:Float = 0)
    {
        super(X, Y);
        displayX = X;
        displayY = Y;
        
        // 确定键位数
        keys = 4;
        
        // 初始化瀑布效果数组
        for(i in 0...keys) {
            waterfallDisplays.push([]);
        }
        
        createKeyboardDisplay();
        
        trace("KeyboardDisplay created at (" + X + ", " + Y + ")");
    }
    
    private function createKeyboardDisplay():Void
    {
        // 创建按键背景
        for (i in 0...keys)
        {
            var keyX = i * (keySize + keySpacing);
            
            // 按键背景
            var keySprite = createKeyButton(keyX, 0, keySize, keySize);
            add(keySprite);
            keySprites.push(keySprite);
            
            // 按键覆盖层（用于按下效果）
            var overlay = createKeyOverlay(keyX, 0, keySize, keySize);
            overlay.alpha = 0;
            add(overlay);
            keyOverlays.push(overlay);
        }
        
        // 创建按键标签
        var labelArray = getKeyLabels();
        for (i in 0...keys)
        {
            var keyX = i * (keySize + keySpacing);
            var keyLabel = new FlxText(keyX, 0, keySize, labelArray[i]);
            keyLabel.setFormat(Paths.font("vcr.ttf"), 24, textColor, CENTER);
            keyLabel.y = (keySize - keyLabel.height) / 2;
            keyLabel.alpha = displayAlpha;
            add(keyLabel);
            keyLabels.push(keyLabel);
        }
    }
    
    private function createKeyButton(X:Float, Y:Float, Width:Int, Height:Int):FlxSprite
    {
        var shape:Shape = new Shape();
        shape.graphics.lineStyle(2, FlxColor.WHITE, 0.8 * displayAlpha);
        shape.graphics.drawRect(0, 0, Width, Height);
        shape.graphics.lineStyle();
        shape.graphics.beginFill(FlxColor.WHITE, 0.3 * displayAlpha);
        shape.graphics.drawRect(0, 0, Width, Height);
        shape.graphics.endFill();
        
        var bitmapData:BitmapData = new BitmapData(Width, Height, 0x00FFFFFF);
        bitmapData.draw(shape);
        
        var sprite = new FlxSprite(X, Y);
        sprite.loadGraphic(bitmapData);
        sprite.color = bgColor;
        sprite.alpha = displayAlpha;
        
        return sprite;
    }
    
    private function createKeyOverlay(X:Float, Y:Float, Width:Int, Height:Int):FlxSprite
    {
        var shape:Shape = new Shape();
        shape.graphics.beginFill(overlayColor, 1);
        shape.graphics.drawRect(0, 0, Width, Height);
        shape.graphics.endFill();
        
        var bitmapData:BitmapData = new BitmapData(Width, Height, 0x00FFFFFF);
        bitmapData.draw(shape);
        
        var sprite = new FlxSprite(X, Y);
        sprite.loadGraphic(bitmapData);
        sprite.alpha = 0;
        
        return sprite;
    }
    
    private function getKeyLabels():Array<String>
    {
        var array:Array<String> = ["A", "S", "W", "D"];
        
        try {
            if (Controls.instance != null && Controls.instance.keyboardBinds != null)
            {
                if (Controls.instance.keyboardBinds.exists('note_left') && Controls.instance.keyboardBinds['note_left'].length > 0)
                    array[0] = InputFormatter.getKeyName(Controls.instance.keyboardBinds['note_left'][0]);
                    
                if (Controls.instance.keyboardBinds.exists('note_down') && Controls.instance.keyboardBinds['note_down'].length > 0)
                    array[1] = InputFormatter.getKeyName(Controls.instance.keyboardBinds['note_down'][0]);
                    
                if (Controls.instance.keyboardBinds.exists('note_up') && Controls.instance.keyboardBinds['note_up'].length > 0)
                    array[2] = InputFormatter.getKeyName(Controls.instance.keyboardBinds['note_up'][0]);
                    
                if (Controls.instance.keyboardBinds.exists('note_right') && Controls.instance.keyboardBinds['note_right'].length > 0)
                    array[3] = InputFormatter.getKeyName(Controls.instance.keyboardBinds['note_right'][0]);
            }
        } catch (e:Dynamic) {
            trace("Using default key labels: " + e);
        }
        
        return array;
    }
    
   public function keyPressed(key:Int):Void
{
    if(key >= 0 && key < keyOverlays.length) {
        keyOverlays[key].alpha = displayAlpha;
        keyLabels[key].color = FlxColor.BLACK;
    }
    
    // 创建新的瀑布效果（每次按下都会创建新的）
    if (key >= 0 && key < waterfallDisplays.length) {
        createWaterfallDisplay(key);
    }
}

public function keyReleased(key:Int):Void
{
    if(key >= 0 && key < keyOverlays.length) {
        keyOverlays[key].alpha = 0;
        keyLabels[key].color = textColor;
    }
    
    // 标记当前正在生长的瀑布为释放状态
    if(key >= 0 && key < waterfallDisplays.length) {
        var arr = waterfallDisplays[key];
        if(arr.length > 0) {
            var lastDisplay = arr[arr.length - 1];
            if (lastDisplay.isStillGrowing()) {
                lastDisplay.markReleased(getCurrentTime());
            }
        }
    }
}
    
    private function getCurrentTime():Float
    {
        var time:Float = 0;
        try {
            time = Conductor.songPosition;
            if (Math.isNaN(time)) {
                time = FlxG.game.ticks;
            }
        } catch (e:Dynamic) {
            time = FlxG.game.ticks;
        }
        return time;
    }

private function createWaterfallDisplay(key:Int):Void
{
    var displayX = key * (keySize + keySpacing);
    var visibleHeight = Std.int(keySize * 3); // 可见的图形高度
    
    // 创建瀑布，可以无限生长但图形有固定高度
    var sprite = new WaterfallSprite(key, getCurrentTime(), displayX, 0, visibleHeight);
    sprite.color = overlayColor;
    add(sprite);
    
    waterfallDisplays[key].push(sprite);
}


    private function updateWaterfallDisplays(elapsed:Float):Void
    {
        var currentTime = getCurrentTime();
        
        for (key in 0...waterfallDisplays.length)
        {
            var keyDisplays = waterfallDisplays[key];
            var i = keyDisplays.length - 1;
            
            while (i >= 0)
            {
                var display = keyDisplays[i];
                
                if (display != null && display.exists) {
                    // 更新瀑布
                    var shouldRemove = display.updateWaterfall(currentTime);
                    
                    if (shouldRemove) {
                        // 移除已结束的瀑布
                        remove(display, true);
                        display.destroy();
                        keyDisplays.splice(i, 1);
                    } else {
                        // 安全移除：超过最大存活时间
                        if (currentTime - display.startTime > 5000) {
                            display.exists = false;
                        }
                    }
                } else if (display != null && !display.exists) {
                    // 移除已标记为不存在的显示
                    remove(display, true);
                    display.destroy();
                    keyDisplays.splice(i, 1);
                }
                i--;
            }
        }
    }
    
    private function removeWaterfallDisplay(sprite:WaterfallSprite):Void
    {
        if(sprite.keyIndex < waterfallDisplays.length) {
            waterfallDisplays[sprite.keyIndex].remove(sprite);
        }
        remove(sprite, true);
        sprite.destroy();
    }
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        // 更新瀑布效果显示
        updateWaterfallDisplays(elapsed);
    }
 
    public function setDisplayPosition(X:Float, Y:Float):Void
    {
        setPosition(X, Y);
        displayX = X;
        displayY = Y;
    }
    
    public function setVisible(visible:Bool):Void
    {
        this.visible = visible;
    }
    
    public function setAlpha(alpha:Float):Void
    {
        displayAlpha = alpha;
        for (sprite in keySprites) {
            sprite.alpha = alpha;
        }
        for (label in keyLabels) {
            label.alpha = alpha;
        }
    }
    
    public function setColors(bg:FlxColor, text:FlxColor, overlay:FlxColor):Void
    {
        bgColor = bg;
        textColor = text;
        overlayColor = overlay;
        
        for (sprite in keySprites) {
            sprite.color = bgColor;
        }
        for (label in keyLabels) {
            label.color = textColor;
        }
    }
    
    override public function destroy():Void
    {
        // 清理所有瀑布效果显示
        for (keyDisplays in waterfallDisplays)
        {
            for (display in keyDisplays)
            {
                if (display != null && display.exists)
                {
                    display.destroy();
                }
            }
        }
        waterfallDisplays = [];
        
           WaterfallSprite.cleanup();
           
        super.destroy();
    }
}

class WaterfallSprite extends FlxSprite
{
    public var keyIndex:Int;
    public var startTime:Float;
    public var endTime:Float = -999999;
    public var originalY:Float;
    private var maxHeight:Int;
    private var isActive:Bool = true;
    
    // 瀑布相关
    private var currentHeight:Float = 0; // 当前瀑布高度（可以无限生长）
    private var growthSpeed:Float = 0.25; // 生长速度（像素/毫秒）
    private var visibleMaxHeight:Int; // 可见的最大高度（用于图形）
    
    // 飞行参数（基于距离）
    private var travelSpeed:Float = 0.25; // 固定飞行速度（像素/毫秒）
    private var travelStartTime:Float = -1; // 开始飞行的时间
    private var currentTravelDistance:Float = 0; // 当前飞行距离
    private var maxTravelDistance:Float = 200; // 最大飞行距离（像素）
    private var fadeStartDistance:Float = 100; // 飞行开始淡出的距离
    
    // 使用静态缓存，但在销毁时清理
    private static var cachedGraphic:FlxGraphic = null;
    private static var graphicKey:String = null;
    
    public function new(KeyIndex:Int, Time:Float, X:Float, Y:Float, VisibleHeight:Int)
    {
        // 固定生成位置：从按键顶部
        var startY = Y + 270 + ClientPrefs.data.kbOffsetY;
        super(X, startY);
        
        this.keyIndex = KeyIndex;
        this.startTime = Time;
        this.originalY = startY;
        this.visibleMaxHeight = VisibleHeight * 2; // 图形的最大高度
        this.maxHeight = VisibleHeight * 2; // 逻辑上可以生长到图形的2倍高度
        
        // 生成当前图形的唯一标识
        var currentKey = 'waterfall_${KeyboardDisplay.keySize}_${visibleMaxHeight}';
        
        // 检查是否需要创建新图形
        if (cachedGraphic == null || graphicKey != currentKey ) {
            createCachedGraphicWithTopFade(KeyboardDisplay.keySize, visibleMaxHeight);
            graphicKey = currentKey;
        }
        
        // 加载缓存的图形
        loadGraphic(cachedGraphic);
        
        // 初始裁剪：完全不显示（高度为0）
        this.clipRect = new FlxRect(0, visibleMaxHeight, KeyboardDisplay.keySize, 0);
        
        // 设置颜色和透明度
        this.color = FlxColor.WHITE;
        this.alpha = 1.0;
    }
    
    private static function createCachedGraphicWithTopFade(width:Int, height:Int):Void
    {
        var bitmapData:BitmapData = new BitmapData(width, height, true, 0);
        var shape:Shape = new Shape();
        
        // 创建带顶部淡出效果的渐变
        for (i in 0...height)
        {
            var normalizedY:Float = i / height; // 0=顶部, 1=底部
            
            // 计算透明度：底部实色，顶部淡出
            var alpha:Float = 1.0;
            
            if (normalizedY < 0.7) {
                // 顶部30%：从0.3透明到0.7（更明显的淡出）
                alpha = 0.2 + normalizedY * 0.8 / 0.7;
            } else {
                // 底部70%：实色
                alpha = 1.0;
            }
            
            shape.graphics.beginFill(FlxColor.WHITE, alpha);
            shape.graphics.drawRect(0, i, width, 1);
            shape.graphics.endFill();
        }
        
        bitmapData.draw(shape);
        
        // 销毁旧的图形（如果存在）
        if (cachedGraphic != null) {
            cachedGraphic.destroy();
        }
        
        cachedGraphic = FlxGraphic.fromBitmapData(bitmapData);
        cachedGraphic.persist = true;
    }
    
    // 静态清理方法，在KeyboardDisplay销毁时调用
    public static function cleanup():Void
    {
        if (cachedGraphic != null) {
            cachedGraphic.destroy();
            cachedGraphic = null;
            graphicKey = null;
        }
    }
    
    public function updateWaterfall(currentTime:Float):Bool
    {
        var shouldRemove = false;
        
        if (isActive)
        {
            // 瀑布无限生长中（按键按下）
            var elapsed = currentTime - startTime;
            
            // 计算新的瀑布高度（可以无限生长）
            currentHeight = elapsed * growthSpeed;
            
            if (currentHeight > 0) {
                // 显示的高度受限于图形尺寸，但逻辑上可以无限生长
                var displayHeight = Math.min(currentHeight, visibleMaxHeight);
                
                // 更新裁剪区域：从底部开始显示
                var clipRect = this.clipRect;
                clipRect.y = visibleMaxHeight - displayHeight; // 从底部开始裁剪
                clipRect.height = displayHeight;
                this.clipRect = clipRect;
                
                // 生长时，底部固定不动！
                this.y = originalY;
                
                // 如果生长超过图形高度，需要滚动显示
                if (currentHeight > visibleMaxHeight) {
                    // 计算超出部分的比例
                    var overflow = currentHeight - visibleMaxHeight;
                    var scrollRatio = overflow / visibleMaxHeight;
                    
                    // 调整裁剪区域显示顶部部分
                    clipRect.y = 0;
                    clipRect.height = visibleMaxHeight;
                    
                    // 根据超出程度调整整体透明度（超出的越多，整体越透明）
                    var overflowAlpha = Math.max(0.3, 1.0 - scrollRatio * 0.3);
                    this.alpha = overflowAlpha;
                } else {
                    // 在图形高度内，正常显示
                    this.alpha = 1.0;
                }
            }
        }
        
        if (endTime != -999999)
        {
            // 按键已释放，开始飞行
            if (travelStartTime == -1) {
                travelStartTime = currentTime;
                
                // 保存当前高度
                if (currentHeight == 0 && isActive) {
                    currentHeight = 10;
                }
            }
            
            // 计算飞行距离
            var travelElapsed = currentTime - travelStartTime;
            currentTravelDistance = travelElapsed * travelSpeed;
            
            if (currentTravelDistance <= maxTravelDistance)
            {
                // 整个瀑布向上飞行
                this.y = originalY - currentTravelDistance;
                
                // 飞行时保持显示高度
                var displayHeight = Math.min(currentHeight, visibleMaxHeight);
                var clipRect = this.clipRect;
                clipRect.y = visibleMaxHeight - displayHeight;
                clipRect.height = displayHeight;
                this.clipRect = clipRect;
                
                // 飞行时的整体淡出效果（基于距离）
                if (currentTravelDistance > fadeStartDistance) {
                    var fadeProgress = (currentTravelDistance - fadeStartDistance) / (maxTravelDistance - fadeStartDistance);
                    fadeProgress = Math.min(fadeProgress, 1.0);
                    
                    // 结合生长时的透明度
                    var baseAlpha = (currentHeight > visibleMaxHeight) ? 
                        Math.max(0.3, 1.0 - ((currentHeight - visibleMaxHeight) / visibleMaxHeight) * 0.3) : 
                        1.0;
                    
                    this.alpha = baseAlpha * (1.0 - fadeProgress);
                }
            }
            else
            {
                // 飞行距离达到最大值，准备移除
                shouldRemove = true;
                this.exists = false;
                this.visible = false;
            }
        }
        
        return shouldRemove;
    }
    
    // 标记按键释放
    public function markReleased(time:Float):Void
    {
        if (endTime == -999999) {
            endTime = time;
            isActive = false; // 停止生长
            
            // 确保有最小高度
            if (currentHeight < 10) {
                currentHeight = 10;
            }
        }
    }
    
    // 获取当前飞行距离
    public function getTravelDistance():Float
    {
        return currentTravelDistance;
    }
    
    // 获取当前瀑布高度
    public function getCurrentHeight():Float
    {
        return currentHeight;
    }
    
    // 检查是否仍在生成中
    public function isStillGrowing():Bool
    {
        return isActive && endTime == -999999;
    }
}