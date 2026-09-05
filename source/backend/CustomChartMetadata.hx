package backend;

import backend.CustomChartData.CustomChartSong;

class CustomChartMetadata
{
    public var sourceFolder:String = null;
    public var category:String = null;
    public var path:String = null;
    public var directory:String = null;
    public var variant:String = null;
    public var audioPath:String = null;
    public var difficulties:Array<String> = [];
    public var files:Map<String, String> = new Map<String, String>();
    public var song:CustomChartSong = null;
    public var difficultyInfo:Map<String, Dynamic> = new Map<String, Dynamic>();

    public function new(chartSong:CustomChartSong)
    {
        song = chartSong;
        if (chartSong == null)
            return;

        sourceFolder = chartSong.sourceCategory;
        category = chartSong.category;
        directory = chartSong.directory;
        audioPath = chartSong.audioPath;
        difficultyInfo = chartSong.info;

        if (chartSong.difficulties == null || chartSong.difficulties.length == 0)
            return;

        path = chartSong.difficulties[0].path;
        for (difficulty in chartSong.difficulties)
        {
            difficulties.push(difficulty.name);
            files.set(difficulty.name, difficulty.path);
        }
    }

    public inline function isValid():Bool
    {
        return song != null && path != null;
    }
}
