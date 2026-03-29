package backend;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
#if MODS_ALLOWED
import backend.Mods;
#end

using StringTools;

typedef SongArtData = {
    var image:String;
    var songs:Array<String>;
    var modName:String;
}

typedef CharacterArtData = {
    var image:String;
    var songs:Array<String>;
    var ?scale:Float;
    var modName:String;
}

class SongArtConfig
{
    public static var songArts:Array<SongArtData> = [];
    private static var songToArtMap:Map<String, String> = new Map();
    
    public static var characterArts:Array<CharacterArtData> = [];
    private static var songToCharacterArtMap:Map<String, String> = new Map();
    private static var songToCharacterScaleMap:Map<String, Float> = new Map();
    
    private static var loadedMods:Array<String> = [];
    
    public static function loadAllConfigs():Void
    {
        resetAllConfigs();
        
        #if MODS_ALLOWED
        var enabledMods:Array<String> = Mods.parseList().enabled;
        
        for (mod in enabledMods)
        {
            if (mod != null && mod.length > 0 && mod != "base")
            {
                tryLoadModConfig(mod);
            }
        }
        
        if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && Mods.currentModDirectory != "base")
        {
            if (!enabledMods.contains(Mods.currentModDirectory))
            {
                tryLoadModConfig(Mods.currentModDirectory);
            }
        }
        #end
    }
    
    public static function tryLoadModConfig(modName:String):Void
    {
        if (loadedMods.contains(modName)) return;
        
        var hasSongArt:Bool = FileSystem.exists('mods/$modName/songArts.json');
        var hasCharArt:Bool = FileSystem.exists('mods/$modName/characterarts.json');
        
        if (!hasSongArt && !hasCharArt) return;
        
        loadedMods.push(modName);
        
        if (hasSongArt) loadSongArt(modName);
        if (hasCharArt) loadCharacterArt(modName);
    }
    
    private static function loadSongArt(modName:String):Void
    {
        try
        {
            var content:String = File.getContent('mods/$modName/songArts.json');
            var parsed:Dynamic = Json.parse(content);
            
            // 转换为数组
            var songArtsArray:Array<Dynamic> = parsed.songArts;
            if (songArtsArray == null) return;
            
            for (artData in songArtsArray)
            {
                var imageName:String = Std.string(artData.image);
                if (imageName == null) continue;
                
                // 转换为数组
                var songsArray:Array<Dynamic> = artData.songs;
                if (songsArray == null) continue;
                
                for (song in songsArray)
                {
                    var songStr:String = Std.string(song);
                    var formattedSong:String = Paths.formatToSongPath(songStr);
                    songToArtMap.set(modName + ":" + formattedSong, imageName);
                }
            }
        }
        catch (e:Dynamic)
        {
            trace('Error loading song art from $modName: $e');
        }
    }
    
    private static function loadCharacterArt(modName:String):Void
    {
        try
        {
            var content:String = File.getContent('mods/$modName/characterarts.json');
            var parsed:Dynamic = Json.parse(content);
            
            // 转换为数组
            var characterArtsArray:Array<Dynamic> = parsed.characterArts;
            if (characterArtsArray == null) return;
            
            for (artData in characterArtsArray)
            {
                var imageName:String = Std.string(artData.image);
                if (imageName == null) continue;
                
                var scale:Float = 1.0;
                if (artData.scale != null)
                {
                    scale = Std.parseFloat(Std.string(artData.scale));
                    if (Math.isNaN(scale)) scale = 1.0;
                }
                
                // 转换为数组
                var songsArray:Array<Dynamic> = artData.songs;
                if (songsArray == null) continue;
                
                for (song in songsArray)
                {
                    var songStr:String = Std.string(song);
                    var formattedSong:String = Paths.formatToSongPath(songStr);
                    var key = modName + ":" + formattedSong;
                    songToCharacterArtMap.set(key, imageName);
                    songToCharacterScaleMap.set(key, scale);
                }
            }
        }
        catch (e:Dynamic)
        {
            trace('Error loading character art from $modName: $e');
        }
    }
    
    public static function getArtForSong(songName:String, ?modFolder:String = null):String
    {
        var formattedName:String = Paths.formatToSongPath(songName);
        
        if (modFolder != null && modFolder.length > 0 && modFolder != "base")
        {
            return songToArtMap.get(modFolder + ":" + formattedName);
        }
        
        for (key in songToArtMap.keys())
        {
            if (key.endsWith(":" + formattedName))
                return songToArtMap.get(key);
        }
        
        return null;
    }
    
    public static function getCharacterArtForSong(songName:String, ?modFolder:String = null):String
    {
        var formattedName:String = Paths.formatToSongPath(songName);
        
        if (modFolder != null && modFolder.length > 0 && modFolder != "base")
        {
            return songToCharacterArtMap.get(modFolder + ":" + formattedName);
        }
        
        for (key in songToCharacterArtMap.keys())
        {
            if (key.endsWith(":" + formattedName))
                return songToCharacterArtMap.get(key);
        }
        
        return null;
    }
    
    public static function getCharacterScaleForSong(songName:String, ?modFolder:String = null):Float
    {
        var formattedName:String = Paths.formatToSongPath(songName);
        
        if (modFolder != null && modFolder.length > 0 && modFolder != "base")
        {
            var scale = songToCharacterScaleMap.get(modFolder + ":" + formattedName);
            if (scale != null) return scale;
        }
        
        for (key in songToCharacterScaleMap.keys())
        {
            if (key.endsWith(":" + formattedName))
                return songToCharacterScaleMap.get(key);
        }
        
        return 1.0;
    }
    
    private static function resetAllConfigs():Void
    {
        songArts = [];
        songToArtMap.clear();
        characterArts = [];
        songToCharacterArtMap.clear();
        songToCharacterScaleMap.clear();
        loadedMods = [];
    }
}