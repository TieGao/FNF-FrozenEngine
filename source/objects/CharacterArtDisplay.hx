package objects;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.SongArtConfig;

class CharacterArtDisplay extends FlxSprite
{
    private var currentArtPath:String = "";
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
        var artName:String = SongArtConfig.getCharacterArtForSong(songName);
        var scale:Float = SongArtConfig.getCharacterScaleForSong(songName);
        
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
            graphic = Paths.image('characterArt/$artName', null, true);
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
        
        var targetHeight:Float = 300 * scale;
        var s:Float = targetHeight / height;
        this.scale.set(s, s);
        updateHitbox();
        
        var targetX:Float = FlxG.width - width - 50;
        var targetY:Float = (FlxG.height - height) / 2;
        
        currentArtPath = newArtPath;
        
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
        visible = false;
        currentArtPath = "";
    }
}