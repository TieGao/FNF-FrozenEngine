package objects;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.SongArtConfig;

class SongArtDisplay extends FlxSprite
{
    private var currentArtPath:String = "";
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
        var artName:String = SongArtConfig.getArtForSong(songName);
        
        if (artName == null)
        {
            hide();
            return;
        }
        
        var newArtPath = artName + "_" + folder;
        if (currentArtPath == newArtPath && visible)
            return;
            
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = folder;
        
        var graphic:FlxGraphic = null;
        try {
            graphic = Paths.image('songArt/$artName', null, true);
        } catch (e:Dynamic) {}
        
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
        var targetY:Float = FlxG.height - 300;
        
        currentArtPath = newArtPath;
        
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
        visible = false;
        currentArtPath = "";
    }
}