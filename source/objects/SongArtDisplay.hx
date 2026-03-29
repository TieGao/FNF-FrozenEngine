package objects;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.SongArtConfig;
import backend.Paths;
import backend.Mods;

class SongArtDisplay extends FlxSprite
{
    private var currentModFolder:String = "";
    private var currentArtName:String = "";
    private var isTweening:Bool = false;
    
    public function new()
    {
        super(-150, FlxG.height / 2);
        antialiasing = ClientPrefs.data.antialiasing;
        scrollFactor.set();
        visible = false;
    }
    
    public function showArt(songName:String, folder:String, animated:Bool = true)
    {
        // 关键修改：传入模组文件夹获取正确的艺术图
        var artName:String = SongArtConfig.getArtForSong(songName, folder);
        
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
        
        var graphic = Paths.image('songArt/$artName', null, true);
        
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
        
        var targetHeight:Float = 140;
        var scale:Float = targetHeight / height;
        this.scale.set(scale, scale);
        updateHitbox();
        
        var targetX:Float = FlxG.width / 2 - width / 2;
        var targetY:Float = FlxG.height - 175;
        
        currentModFolder = folder;
        currentArtName = artName;
        
        if (!animated)
        {
            x = targetX;
            y = targetY;
            alpha = 1;
            visible = true;
            return;
        }
        
        x = targetX - 50;
        y = targetY;
        alpha = 0;
        visible = true;
        
        isTweening = true;
        FlxTween.tween(this, { x: targetX, alpha: 1 }, 0.25, {
            ease: FlxEase.circOut,
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