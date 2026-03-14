package objects;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;

import states.PlayState;

class StrumGuideLine extends FlxTypedSpriteGroup<FlxSprite>
{
    // 4个黑条，对应4列
    var playerLines:Array<FlxSprite> = [];
    
    public function new()
    {
        super(0, 0);
        
        // 创建4个黑条
        for (i in 0...4)
        {
            var line = new FlxSprite();
            
            // 设置黑条属性 - 竖条，铺满整个屏幕高度
            line.makeGraphic(115, FlxG.height, FlxColor.BLACK); // 宽度30，高度铺满屏幕
            line.alpha = ClientPrefs.data.guideLineAlpha;
            
            // 默认隐藏，直到有strum时显示
            line.visible = false;
            
            playerLines.push(line);
            add(line);
        }
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        var playState = PlayState.instance;
        if (playState == null) return;
        
        // 更新每个黑条的位置，跟随对应的静态音符
        for (i in 0...playerLines.length)
        {
            var strum = playState.playerStrums.members[i];
            if (strum != null && strum.visible)
            {
                var line = playerLines[i];
                
                // 设置位置：X轴跟随strum，Y轴固定为屏幕顶部
                line.x = strum.x + (strum.width / 2) - (line.width / 2); // 居中于strum
                line.y = 0; // 从屏幕最顶部开始
                
                // 更新透明度（从ClientPrefs实时读取）
                line.alpha = ClientPrefs.data.guideLineAlpha;
                
                // 显示黑条
                line.visible = (line.alpha > 0);
            }
            else
            {
                playerLines[i].visible = false;
            }
        }
    }
    
    /**
     * 更新透明度
     */
    public function updateAlpha()
    {
        for (line in playerLines)
        {
            line.alpha = ClientPrefs.data.guideLineAlpha;
            line.visible = (line.alpha > 0);
        }
    }
    
    override public function destroy():Void
    {
        playerLines = null;
        super.destroy();
    }
}