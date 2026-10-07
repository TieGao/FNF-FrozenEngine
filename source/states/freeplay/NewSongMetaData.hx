package states.freeplay;

import backend.SongInfoParser.ParsedSongInfo;
import backend.CustomChartMetadata.CustomChartMetadata;

/** 单曲在 Freeplay 列表里展示用的元数据（歌曲名 / 周 / 角色 / 配色 / 所属 mod / 各难度解析结果）。 */
class NewSongMetaData
{
    public var songName:String = "";
    public var week:Int = 0;
    public var songCharacter:String = "";
    public var color:Int = -7179779;
    public var folder:String = "";
    public var lastDifficulty:String = null;
    
    public var difficultyInfo:Map<String, ParsedSongInfo> = new Map<String, ParsedSongInfo>();
    public var customChart:CustomChartMetadata = null;

    /** 音乐人 / 作曲（来自 week.json 元组第 4 项） */
    public var songMusican:String = null;
    /** 各难度谱师（来自 week.json 元组第 5 项，按本曲难度顺序） */
    public var songCharters:Array<String> = null;
    
    public function new(song:String, week:Int, songCharacter:String, color:Int)
    {
        this.songName = song;
        this.week = week;
        this.songCharacter = songCharacter;
        this.color = color;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
    }
}