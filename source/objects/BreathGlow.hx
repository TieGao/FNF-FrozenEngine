package objects;

import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.geom.Matrix;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import flixel.FlxSprite;

class BreathGlow extends FlxSprite
{
    private static var glowCache:Map<String, FlxGraphic> = new Map();
    
    public var glowColor:FlxColor = 0xFFFFFF;
    public var glowIntensity:Float = 0.5;
    public var pulseSpeed:Float = 1.5;
    
    private var _baseAlpha:Float = 0.2;
    private var _currentPulse:Float = 0;
    private var _targetWidth:Float;
    private var _targetHeight:Float;
    private var _cacheKey:String;
    private var _currentColor:FlxColor;
    
    public function new(width:Float, height:Float, color:FlxColor = 0xFFFFFF)
    {
        super();
        
        _targetWidth = width;
        _targetHeight = height;
        _currentColor = color;
        glowColor = color;
        _cacheKey = "breathGlow_${width}_${height}_${color}";
        
        regenGlowGraphic();
        
        this.blend = openfl.display.BlendMode.ADD;
    }
    
    /**
     * 重新生成发光纹理
     */
    public function regenGlowGraphic():Void
    {
        var w:Int = Std.int(_targetWidth + 40);
        var h:Int = Std.int(_targetHeight + 40);
        
        // 创建BitmapData
        var bitmap:BitmapData = new BitmapData(w, h, true, 0x00000000);
        
        // 使用Shape的Graphics绘制
        var shape:Shape = new Shape();
        var graphics:Graphics = shape.graphics;
        
        // 提取RGB分量
        var r:Int = (glowColor >> 16) & 0xFF;
        var g:Int = (glowColor >> 8) & 0xFF;
        var b:Int = glowColor & 0xFF;
        
        // 径向渐变
        var matrix:Matrix = new Matrix();
        matrix.createGradientBox(w, h, 0, 0, 0);
        
        graphics.beginGradientFill(
            openfl.display.GradientType.RADIAL,
            [glowColor, glowColor, 0x000000],
            [0.9, 0.3, 0],
            [0, 150, 255],
            matrix
        );
        graphics.drawRect(0, 0, w, h);
        graphics.endFill();
        
        // 将Shape绘制到BitmapData
        bitmap.draw(shape);
        
        // 转换为FlxGraphic并缓存
        var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, _cacheKey);
        graphic.persist = true;
        graphic.destroyOnNoUse = false;
        glowCache.set(_cacheKey, graphic);
        Paths.currentTrackedAssets.set(_cacheKey, graphic);
        Paths.localTrackedAssets.push(_cacheKey);
        this.loadGraphic(graphic);
        this.dirty = true;
        
        // 清理Shape
        shape.graphics.clear();
    }
    
    /**
     * 设置发光颜色（会重新生成纹理）
     */
    public function setColor(color:FlxColor):Void
    {
        if (_currentColor != color)
        {
            _currentColor = color;
            glowColor = color;
            
            // 更新缓存键
            var newCacheKey:String = "breathGlow_${_targetWidth}_${_targetHeight}_${color}";
            
            // 检查新颜色是否有缓存
            var cached:FlxGraphic = glowCache.get(newCacheKey);
            if (cached != null && isGraphicValid(cached))
            {
                this.loadGraphic(cached);
                _cacheKey = newCacheKey;
            }
            else
            {
                // 重新生成并缓存
                _cacheKey = newCacheKey;
                regenGlowGraphic();
            }
            
            this.dirty = true;
        }
    }
    
    /**
     * 更新呼吸动画
     */
    public function updatePulse(elapsed:Float):Void
    {
        ensureGraphic();
        _currentPulse += elapsed * pulseSpeed;
        var pulseValue:Float = 0.5 + 0.5 * Math.sin(_currentPulse * Math.PI * 2);
        
        // 透明度呼吸
        this.alpha = _baseAlpha + pulseValue * glowIntensity * 0.5;
        
        // 缩放呼吸
        var scalePulse:Float = 0.05 * pulseValue;
        this.scale.set(1 + scalePulse, 1 + scalePulse);
        
        // 注意：位置由父对象管理，避免在这里改变 this.x/this.y
    }
    
    /**
     * 重新设置尺寸
     */
    public function resize(newWidth:Float, newHeight:Float):Void
    {
        if (_targetWidth != newWidth || _targetHeight != newHeight)
        {
            _targetWidth = newWidth;
            _targetHeight = newHeight;
            _cacheKey = "breathGlow_${_targetWidth}_${_targetHeight}_${_currentColor}";
            regenGlowGraphic();
        }
    }

    private static function isGraphicValid(graphic:FlxGraphic):Bool
    {
        if (graphic == null) return false;
        if (graphic.bitmap == null) return false;
        if (Reflect.hasField(graphic.bitmap, "__texture") && Reflect.field(graphic.bitmap, "__texture") == null) return false;
        return true;
    }

    private function ensureGraphic():Void
    {
        if (!isGraphicValid(this.graphic))
        {
            var cached:FlxGraphic = glowCache.get(_cacheKey);
            if (cached != null && isGraphicValid(cached))
            {
                this.loadGraphic(cached);
            }
            else
            {
                regenGlowGraphic();
            }
        }
    }
    
    /**
     * 设置基础透明度
     */
    public function setBaseAlpha(alpha:Float):Void
    {
        _baseAlpha = Math.max(0, Math.min(1, alpha));
    }
    
    /**
     * 清除缓存（可选）
     */
    public static function clearCache():Void
    {
        glowCache.clear();
    }
}