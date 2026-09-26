package objects;

import flixel.FlxSprite;
import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

class GradientTimeBar extends Bar
{
    public var leftColor:FlxColor = FlxColor.RED;
    public var rightColor:FlxColor = FlxColor.BLUE;
    
    public function new(x:Float, y:Float, image:String = 'timeBar', valueFunc:Void->Float = null, boundX:Float = 0, boundY:Float = 1)
    {
        super(x, y, image, valueFunc, boundX, boundY);
        
        // 移除原有的leftBar，用渐变条替代
        if(leftBar != null) {
            remove(leftBar);
            leftBar.destroy();
            leftBar = null;
        }
        
        // 创建渐变条
        rebuildGradient();
        
        // 重新生成剪辑区域
        regenerateClips();
    }
    
    // 名字不能叫 createGradientBar：父类 Bar 现在有一个同名的公开方法（签名不同），
    // 子类定义同名不同参的方法会报 "should be declared with 'override'" + "Different number of function arguments"。
    // 直接复用父类那个方法，顺带把两边重复的渐变生成逻辑合并掉。
    function rebuildGradient() {
        createGradientBar([rightColor], [leftColor], 1, 180);
    }
    
    function createGradientBitmap(width:Int, height:Int, startColor:FlxColor, endColor:FlxColor):BitmapData {
        var bitmap:BitmapData = new BitmapData(width, height, true, 0x00000000);
        
        var segments:Int = 100;
        for (i in 0...segments) {
            var ratio:Float = i / (segments - 1);
            var currentColor:FlxColor = FlxColor.interpolate(startColor, endColor, ratio);
            
            var segmentWidth:Int = Math.ceil(width / segments);
            var xPos:Int = Math.floor(i * (width / segments));
            var segmentRect:Rectangle = new Rectangle(xPos, 0, segmentWidth, height);
            
            bitmap.fillRect(segmentRect, currentColor);
        }
        
        return bitmap;
    }
    
    public function updateGradientColors(newLeftColor:FlxColor, newRightColor:FlxColor) {
        if (leftColor == newLeftColor && rightColor == newRightColor) return;
        
        leftColor = newLeftColor;
        rightColor = newRightColor;
        
        // 重新创建渐变条
        if(leftBar != null) {
            remove(leftBar);
            leftBar.destroy();
        }
        rebuildGradient();
        regenerateClips();
    }
    
    // 重写setColors方法以支持渐变
    override public function setColors(left:FlxColor = null, right:FlxColor = null) {
        if (left != null) {
            // 对于渐变条，我们更新整个渐变
            updateGradientColors(left, right != null ? right : this.rightColor);
        }
        if (right != null) {
            rightBar.color = right;
        }
    }
}