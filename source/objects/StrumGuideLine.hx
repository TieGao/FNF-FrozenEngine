package objects;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.FlxG;
import flixel.util.FlxColor;

import states.PlayState;

class StrumGuideLine extends FlxTypedSpriteGroup<FlxSprite>
{
    // 动态数组，根据键数变化
    var playerLines:Array<FlxSprite> = [];
    var opponentLines:Array<FlxSprite> = [];
    
    // 当前键数
    var currentKeyCount:Int = 4;
    
    public function new()
    {
        super(0, 0);
        
        // 根据键数创建黑条
        setupLinesForKeys();
    }
    
    /**
     * 根据当前键数设置引导线
     */
    function setupLinesForKeys():Void
    {
        var keys:Int = Note.getColumnsPerPlayer();
        currentKeyCount = keys;
        
        // 清理旧的引导线
        for (line in playerLines)
        {
            remove(line);
            line.destroy();
        }
        for (line in opponentLines)
        {
            remove(line);
            line.destroy();
        }
        playerLines = [];
        opponentLines = [];
        
        // 计算每条线的宽度
        var spacing:Float = Note.getNoteSpacing(keys);
        var strumWidth:Float = 115; // 基础宽度
        var lineWidth:Float = strumWidth * (4 / keys); // 根据键数调整宽度
        
        // 创建玩家侧的引导线
        for (i in 0...keys)
        {
            var line = new FlxSprite();
            line.makeGraphic(Math.round(lineWidth), FlxG.height, FlxColor.BLACK);
            line.alpha = ClientPrefs.data.guideLineAlpha;
            line.visible = false;
            playerLines.push(line);
            add(line);
        }
        
        // 创建对手侧的引导线
        for (i in 0...keys)
        {
            var line = new FlxSprite();
            line.makeGraphic(Math.round(lineWidth), FlxG.height, FlxColor.BLACK);
            line.alpha = ClientPrefs.data.guideLineAlpha;
            line.visible = false;
            opponentLines.push(line);
            add(line);
        }
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // 检查键数是否变化
        var keys:Int = Note.getColumnsPerPlayer();
        if (keys != currentKeyCount)
        {
            setupLinesForKeys();
        }
        
        var playState = PlayState.instance;
        if (playState == null) return;
        
        var opponentMode = playState.opponentMode;
        var isCoopMode:Bool = (opponentMode == "coop" || opponentMode == "coop_split");
        var isOpponentMode:Bool = (opponentMode == "opponent");
        
        // 更新玩家侧引导线
        for (i in 0...playerLines.length)
        {
            if (i < playState.playerStrums.members.length)
            {
                var strum = playState.playerStrums.members[i];
                var shouldShow:Bool = (strum != null && strum.visible);
                
                if (isOpponentMode)
                    shouldShow = false;
                
                if (shouldShow)
                {
                    var line = playerLines[i];
                    line.x = strum.x + (strum.width / 2) - (line.width / 2);
                    line.y = 0;
                    line.alpha = ClientPrefs.data.guideLineAlpha;
                    line.visible = (line.alpha > 0);
                }
                else
                {
                    playerLines[i].visible = false;
                }
            }
        }
        
        // 更新对手侧引导线
        for (i in 0...opponentLines.length)
        {
            if (i < playState.opponentStrums.members.length)
            {
                var strum = playState.opponentStrums.members[i];
                var shouldShow:Bool = (strum != null && strum.visible);
                
                if (!isCoopMode && !isOpponentMode)
                    shouldShow = false;
                
                if (shouldShow)
                {
                    var line = opponentLines[i];
                    line.x = strum.x + (strum.width / 2) - (line.width / 2);
                    line.y = 0;
                    line.alpha = ClientPrefs.data.guideLineAlpha;
                    line.visible = (line.alpha > 0);
                }
                else
                {
                    opponentLines[i].visible = false;
                }
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
        for (line in opponentLines)
        {
            line.alpha = ClientPrefs.data.guideLineAlpha;
            line.visible = (line.alpha > 0);
        }
    }
    
    /**
     * 重新加载引导线（当键数或设置改变时调用）
     */
    public function reloadLines():Void
    {
        setupLinesForKeys();
    }
    
    override public function destroy():Void
    {
        playerLines = null;
        opponentLines = null;
        super.destroy();
    }
}