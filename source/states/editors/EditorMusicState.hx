package states.editors;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import backend.ClientPrefs;

class EditorMusicState extends MusicBeatState
{
    var pauseMusic:FlxSound;

    override function create()
    {
        initPauseMusic();
        super.create();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        updatePauseMusicVolume(elapsed);
    }

    override function destroy()
    {
        if (pauseMusic != null)
        {
            if (pauseMusic.playing)
                pauseMusic.stop();

            pauseMusic.destroy();
            pauseMusic = null;
        }

        super.destroy();
    }

    function initPauseMusic():Void
    {
        if (FlxG.sound.music != null && FlxG.sound.music.playing)
            FlxG.sound.music.stop();

        pauseMusic = new FlxSound();
        var pauseSong:String = getPauseSongName();

        try
        {
            if (pauseSong != null)
                pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
            else
                pauseMusic.loadEmbedded(Paths.music('breakfast'), true, true);
        }
        catch(e:Dynamic)
        {
            pauseMusic.loadEmbedded(Paths.music('breakfast'), true, true);
        }

        pauseMusic.volume = 0;
        pauseMusic.play();
        FlxG.sound.list.add(pauseMusic);
        FlxTween.tween(pauseMusic, {volume: 0.5}, 0.8);
    }

    function getPauseSongName():String
    {
        var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
        if (formattedPauseMusic == 'none')
            return null;
        return formattedPauseMusic;
    }

    function fadeOutAndStopPauseMusic(?onComplete:Void->Void):Void
    {
        if (pauseMusic != null && pauseMusic.playing)
        {
            FlxTween.tween(pauseMusic, {volume: 0}, 0.1, {
                onComplete: function(_) {
                    if (pauseMusic != null) {
                        pauseMusic.stop();
                        pauseMusic.destroy();
                        pauseMusic = null;
                    }
                    if (onComplete != null) onComplete();
                }
            });
        }
        else if (onComplete != null)
        {
            onComplete();
        }
    }

    function updatePauseMusicVolume(elapsed:Float):Void
    {
        if (pauseMusic != null && pauseMusic.volume < 0.5)
            pauseMusic.volume += 0.01 * elapsed;
    }
}
