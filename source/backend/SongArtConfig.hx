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
}

typedef CharacterArtData = {
    var image:String;
    var songs:Array<String>;
    var ?scale:Float; // 可选的角色缩放比例
}

class SongArtConfig
{
    public static var songArts:Array<SongArtData> = [];
    private static var songToArtMap:Map<String, String> = new Map();
    
    public static var characterArts:Array<CharacterArtData> = [];
    private static var songToCharacterArtMap:Map<String, String> = new Map();
    private static var songToCharacterScaleMap:Map<String, Float> = new Map();
    
    public static function loadAllConfigs():Void
    {
        resetAllConfigs();
        
        #if MODS_ALLOWED
        if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
        {
            loadSongArtFromMod(Mods.currentModDirectory);
            loadCharacterArtFromMod(Mods.currentModDirectory);
        }
        
        for (mod in Mods.getGlobalMods())
        {
            if (mod != Mods.currentModDirectory)
            {
                loadSongArtFromMod(mod);
                loadCharacterArtFromMod(mod);
            }
        }
        #end
    }
    
    public static function getArtForSong(songName:String):String
    {
        var formattedName:String = Paths.formatToSongPath(songName);
        return songToArtMap.get(formattedName);
    }
    
    public static function hasArtForSong(songName:String):Bool
    {
        return getArtForSong(songName) != null;
    }
    
    public static function getCharacterArtForSong(songName:String):String
    {
        var formattedName:String = Paths.formatToSongPath(songName);
        return songToCharacterArtMap.get(formattedName);
    }
    
    public static function getCharacterScaleForSong(songName:String):Float
    {
        var formattedName:String = Paths.formatToSongPath(songName);
        var scale:Null<Float> = songToCharacterScaleMap.get(formattedName);
        return scale != null ? scale : 1.0;
    }
    
    public static function hasCharacterArtForSong(songName:String):Bool
    {
        return getCharacterArtForSong(songName) != null;
    }
    
    private static function resetAllConfigs():Void
    {
        songArts = [];
        songToArtMap.clear();
        characterArts = [];
        songToCharacterArtMap.clear();
        songToCharacterScaleMap.clear();
    }
    
    private static function loadSongArtFromMod(modName:String):Void
    {
        var configPath:String = 'mods/$modName/songArts.json';
        
        if (!FileSystem.exists(configPath))
            return;
            
        try
        {
            var content:String = File.getContent(configPath);
            var parsed:Dynamic = Json.parse(content);
            
            if (!Reflect.hasField(parsed, "songArts") || parsed.songArts == null)
                return;
                
            var songArtsArray:Array<Dynamic> = parsed.songArts;
            
            for (artData in songArtsArray)
            {
                if (!Reflect.hasField(artData, "image") || !Reflect.hasField(artData, "songs"))
                    continue;
                    
                var imageName:String = Std.string(artData.image);
                var songsArray:Array<Dynamic> = artData.songs;
                
                var songArtData:SongArtData = {
                    image: imageName,
                    songs: []
                };
                
                for (song in songsArray)
                {
                    var songStr:String = Std.string(song);
                    var formattedSong:String = Paths.formatToSongPath(songStr);
                    songArtData.songs.push(songStr);
                    songToArtMap.set(formattedSong, imageName);
                }
                
                songArts.push(songArtData);
            }
        }
        catch (e:Dynamic)
        {
            trace('Error loading song art config from $modName: $e');
        }
    }
    
    private static function loadCharacterArtFromMod(modName:String):Void
    {
        var configPath:String = 'mods/$modName/characterarts.json';
        
        if (!FileSystem.exists(configPath))
            return;
            
        try
        {
            var content:String = File.getContent(configPath);
            var parsed:Dynamic = Json.parse(content);
            
            if (!Reflect.hasField(parsed, "characterArts") || parsed.characterArts == null)
                return;
                
            var characterArtsArray:Array<Dynamic> = parsed.characterArts;
            
            for (artData in characterArtsArray)
            {
                if (!Reflect.hasField(artData, "image") || !Reflect.hasField(artData, "songs"))
                    continue;
                    
                var imageName:String = Std.string(artData.image);
                var songsArray:Array<Dynamic> = artData.songs;
                var scale:Float = 1.0;
                
                if (Reflect.hasField(artData, "scale") && artData.scale != null)
                {
                    var scaleValue:Dynamic = artData.scale;
                    if (Std.isOfType(scaleValue, Float))
                        scale = cast scaleValue;
                    else if (Std.isOfType(scaleValue, Int))
                        scale = cast scaleValue;
                    else if (Std.isOfType(scaleValue, String))
                    {
                        var strScale:String = Std.string(scaleValue);
                        var parsedScale = Std.parseFloat(strScale);
                        if (!Math.isNaN(parsedScale))
                            scale = parsedScale;
                    }
                }
                
                var characterArtData:CharacterArtData = {
                    image: imageName,
                    songs: [],
                    scale: scale
                };
                
                for (song in songsArray)
                {
                    var songStr:String = Std.string(song);
                    var formattedSong:String = Paths.formatToSongPath(songStr);
                    characterArtData.songs.push(songStr);
                    songToCharacterArtMap.set(formattedSong, imageName);
                    songToCharacterScaleMap.set(formattedSong, scale);
                }
                
                characterArts.push(characterArtData);
            }
        }
        catch (e:Dynamic)
        {
            trace('Error loading character art config from $modName: $e');
        }
    }
    
    public static function getAllSongArts():Array<SongArtData>
    {
        return songArts.copy();
    }
    
    public static function getAllCharacterArts():Array<CharacterArtData>
    {
        return characterArts.copy();
    }
}