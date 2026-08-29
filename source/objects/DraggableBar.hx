package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;

class DraggableBar extends Bar
{
    public var onValueChanged:Float->Void = null;
    public var isDragging(default, null):Bool = false;
    public var draggable:Bool = true;
    public var jumpOnClick:Bool = true;   // 若为true，点击立即跳转并拖拽
    
    public var valueText:FlxText = null;
    
    var dragStartPercent:Float = 0;
    var dragStartMouseX:Float = 0;
    var dragStartMouseScreenX:Float = 0;
    
    public function new(x:Float, y:Float, image:String = 'healthBar', valueFunction:Void->Float = null, boundX:Float = 0, boundY:Float = 1)
    {
        super(x, y, image, valueFunction, boundX, boundY);
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (!draggable) return;
        
        var mouseOverBg = FlxG.mouse.overlaps(bg, FlxG.camera);
        
        // --- 开始拖拽（按下时立即跳转） ---
        if (FlxG.mouse.justPressed && mouseOverBg && !isDragging)
        {
            // 1. 计算鼠标在条上的相对位置（百分比）
            var mouseCamPos = FlxG.mouse.getPositionInCameraView(cameras[0]);
            if (mouseCamPos != null)
            {
                var bgCamPos = bg.getScreenPosition(cameras[0]);
                var relativeX = mouseCamPos.x - bgCamPos.x - barOffset.x;
                var clickPercent = (relativeX / barWidth) * 100;
                clickPercent = Math.max(0, Math.min(100, clickPercent));
                
                // 2. 如果允许点击跳转，立即将条设置到点击位置
                if (jumpOnClick)
                {
                    percent = clickPercent;
                    updateBar();
                    if (onValueChanged != null) onValueChanged(percent);
                }
                
                // 3. 记录拖拽起始数据（基于当前百分比）
                isDragging = true;
                dragStartPercent = percent;                  // 起始百分比（可能是新跳转后的值）
                dragStartMouseX = relativeX;                // 当前鼠标相对位置
                dragStartMouseScreenX = FlxG.mouse.screenX;
                
                leftBar.alpha = 0.7;
                rightBar.alpha = 0.7;
            }
        }
        
        // --- 拖拽中（基于偏移量更新） ---
        if (isDragging && FlxG.mouse.pressed)
        {
            var mouseCamPos = FlxG.mouse.getPositionInCameraView(cameras[0]);
            if (mouseCamPos != null)
            {
                var bgCamPos = bg.getScreenPosition(cameras[0]);
                var currentMouseX = mouseCamPos.x - bgCamPos.x - barOffset.x;
                
                var deltaX = currentMouseX - dragStartMouseX;
                var newPercent = dragStartPercent + (deltaX / barWidth) * 100;
                newPercent = Math.max(0, Math.min(100, newPercent));
                
                if (newPercent != percent)
                {
                    percent = newPercent;
                    updateBar();
                    if (onValueChanged != null) onValueChanged(percent);
                }
            }
        }
        
        // --- 结束拖拽 ---
        if (FlxG.mouse.justReleased && isDragging)
        {
            isDragging = false;
            leftBar.alpha = 1;
            rightBar.alpha = 1;
        }
        
        // 注意：原来的“点击跳转”逻辑（justReleased）已移除，因为按下时已经处理了跳转和拖拽。
        // 若jumpOnClick为false，则不会跳转，但按下时仍会进入拖拽（从当前百分比开始）。
        
        // 更新数值显示
        if (valueText != null)
        {
            valueText.text = Math.round(percent) + "%";
            valueText.x = x;
            valueText.y = y - 25;
        }
    }
    
    public function setPercent(value:Float, triggerCallback:Bool = true):Void
    {
        var newPercent = Math.max(0, Math.min(100, value));
        if (newPercent == percent) return;
        
        percent = newPercent;
        updateBar();
        
        if (triggerCallback && onValueChanged != null)
        {
            onValueChanged(percent);
        }
    }
    
    override public function destroy():Void
    {
        if (valueText != null) valueText.destroy();
        super.destroy();
    }
}