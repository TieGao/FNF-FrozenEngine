package backend;

import flixel.util.FlxColor;
import openfl.display.Sprite;
import flixel.FlxSprite;
import openfl.display.BitmapData;

class OFLSprite extends FlxSprite
{
    public var flSprite:Sprite;
    private var _width:Int;
    private var _height:Int;

    public function new(x:Float, y:Float, width:Int, height:Int, sprite:Sprite)
    {
        super(x, y);
        _width = width;
        _height = height;
        
        // 创建透明背景
        makeGraphic(width, height, FlxColor.TRANSPARENT);
        flSprite = sprite;
        
        // 立即绘制一次
        updateDisplay();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        // 每帧都更新显示，确保图表实时更新
        updateDisplay();
    }

    public function updateDisplay()
    {
        // 清除现有像素
        pixels.fillRect(pixels.rect, FlxColor.TRANSPARENT);
        
        // 重新绘制 OpenFL Sprite
        pixels.draw(flSprite);
        
        // 更新纹理
        dirty = true;
    }
}