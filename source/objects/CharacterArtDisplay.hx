package objects;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.SongArtConfig;
import backend.Paths;
import backend.Mods;

class CharacterArtDisplay extends FlxSprite
{
    private var currentModFolder:String = "";
    private var currentArtName:String = "";
    private var isTweening:Bool = false;
    
    public function new()
    {
        super(FlxG.width + 300, FlxG.height * 0.4);
        antialiasing = ClientPrefs.data.antialiasing;
        scrollFactor.set();
        visible = false;
    }
    
    public function showCharacter(songName:String, folder:String, animated:Bool = true)
    {
        // 关键修改：传入模组文件夹获取正确的角色图
        var artName:String = SongArtConfig.getCharacterArtForSong(songName, folder);
        var scale:Float = SongArtConfig.getCharacterScaleForSong(songName, folder);
        
        if (artName == null)
        {
            hide();
            return;
        }
        
        if (currentModFolder == folder && currentArtName == artName && visible)
            return;
        
        // 保存当前模组目录并切换
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        
        var graphic = Paths.image('characterArt/$artName', null, true);
        
        // 恢复模组目录
        Mods.currentModDirectory = oldModDir;
        
        if (graphic == null)
        {
            hide();
            return;
        }
        
        if (isTweening)
        {
            FlxTween.cancelTweensOf(this);
            isTweening = false;
        }
        
        loadGraphic(graphic);
        
        var targetHeight:Float = 300 * scale;
        var s:Float = targetHeight / height;
        this.scale.set(s, s);
        updateHitbox();
        
        var targetX:Float = FlxG.width - width - 50;
        var targetY:Float = (FlxG.height - height) / 2;
        
        currentModFolder = folder;
        currentArtName = artName;
        
        y = targetY;
        
        if (!animated)
        {
            x = targetX;
            alpha = 1;
            visible = true;
            return;
        }
        
        x = FlxG.width + 50;
        alpha = 0;
        visible = true;
        
        isTweening = true;
        FlxTween.tween(this, { x: targetX, alpha: 1 }, 0.3, {
            ease: FlxEase.expoOut,
            onComplete: function(_) { isTweening = false; }
        });
    }
    
    public function hide()
    {
        if (isTweening)
        {
            FlxTween.cancelTweensOf(this);
            isTweening = false;
        }
        visible = false;
        currentModFolder = "";
        currentArtName = "";
    }
}