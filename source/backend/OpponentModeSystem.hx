package backend;

import objects.Note;
import objects.Character;
import objects.StrumNote;

class OpponentModeSystem
{
    /**
     * 判断是否启用 opponent mode
     */
    public static inline function isEnabled():Bool
    {
        return ClientPrefs.getGameplaySetting('opponentplay');
    }
    
    /**
     * 获取玩家控制的轨道
     * - 正常模式：玩家控制playerStrums（右侧）
     * - 对手模式：玩家控制opponentStrums（左侧）
     */
 public static function getPlayerStrums():FlxTypedGroup<StrumNote> {
    if (isEnabled()) {
        return PlayState.instance.opponentStrums; // 对手模式下，玩家控制对手轨道
    } else {
        return PlayState.instance.playerStrums; // 正常模式下，玩家控制玩家轨道
    }
}

public static function getPlayerCharacter():Character {
    if (isEnabled()) {
        return PlayState.instance.dad; // 对手模式下，玩家控制dad角色
    } else {
        return PlayState.instance.boyfriend; // 正常模式下，玩家控制boyfriend
    }
}
    
    /**
     * 获取对手控制的轨道
     */
    public static function getOpponentStrums():FlxTypedGroup<StrumNote>
    {
        if (PlayState.instance == null) return null;
        return isEnabled() ? PlayState.instance.playerStrums : PlayState.instance.opponentStrums;
    }
    
    
    /**
     * 获取对手控制的角色
     */
    public static function getOpponentCharacter():Character
    {
        if (PlayState.instance == null) return null;
        return isEnabled() ? PlayState.instance.boyfriend : PlayState.instance.dad;
    }
    
    /**
     * 获取玩家声音
     */
    public static function getPlayerVocals():flixel.system.FlxSound
    {
        if (PlayState.instance == null) return null;
        return isEnabled() ? PlayState.instance.opponentVocals : PlayState.instance.vocals;
    }
    
    /**
     * 获取对手声音
     */
    public static function getOpponentVocals():flixel.system.FlxSound
    {
        if (PlayState.instance == null) return null;
        return isEnabled() ? PlayState.instance.vocals : PlayState.instance.opponentVocals;
    }
    
    public static inline function shouldControlNote(note:Note):Bool
    {
        if (note == null) return false;
        return isEnabled() ? !note.mustPress : note.mustPress;
    }

    public static inline function shouldOpponentControl(note:Note):Bool
    {
        if (note == null) return false;
        return isEnabled() ? note.mustPress : !note.mustPress;
    }
}