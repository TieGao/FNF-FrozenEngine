package backend;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();

	public static function resetSong(song:String, diff:Int = 0, ?modFolder:String = null):Void
	{
		var daSong:String = formatSong(song, diff, modFolder);
		setScore(daSong, 0);
		setRating(daSong, 0);
	}

	public static function resetWeek(week:String, diff:Int = 0, ?modFolder:String = null):Void
	{
		var daWeek:String = formatSong(week, diff, modFolder);
		setWeekScore(daWeek, 0);
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1, ?modFolder:String = null):Void
	{
		if(song == null) return;
		var daSong:String = formatSong(song, diff, modFolder);

		if (songScores.exists(daSong))
		{
			if (songScores.get(daSong) < score)
			{
				setScore(daSong, score);
				if(rating >= 0) setRating(daSong, rating);
			}
		}
		else
		{
			setScore(daSong, score);
			if(rating >= 0) setRating(daSong, rating);
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0, ?modFolder:String = null):Void
	{
		var daWeek:String = formatSong(week, diff, modFolder);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else setWeekScore(daWeek, score);
	}

	static function setScore(song:String, score:Int):Void
	{
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}
	
	static function setWeekScore(week:String, score:Int):Void
	{
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	/**
	 * 格式化歌曲键名，支持模组隔离
	 * 格式：[模组名:]歌曲名_难度
	 */
	public static function formatSong(song:String, diff:Int, ?modFolder:String = null):String
	{
		var formattedSong:String = Paths.formatToSongPath(song);
		var diffPath:String = Difficulty.getFilePath(diff);
		
		// 如果有模组文件夹，使用模组隔离的键
		if (modFolder != null && modFolder.length > 0 && modFolder != "base")
		{
			return modFolder + ":" + formattedSong + diffPath;
		}
		
		// 默认行为（向后兼容）
		return formattedSong + diffPath;
	}

	public static function getScore(song:String, diff:Int, ?modFolder:String = null):Int
	{
		var daSong:String = formatSong(song, diff, modFolder);
		if (!songScores.exists(daSong))
			setScore(daSong, 0);

		return songScores.get(daSong);
	}

	public static function getRating(song:String, diff:Int, ?modFolder:String = null):Float
	{
		var daSong:String = formatSong(song, diff, modFolder);
		if (!songRating.exists(daSong))
			setRating(daSong, 0);

		return songRating.get(daSong);
	}

	public static function getWeekScore(week:String, diff:Int, ?modFolder:String = null):Int
	{
		var daWeek:String = formatSong(week, diff, modFolder);
		if (!weekScores.exists(daWeek))
			setWeekScore(daWeek, 0);

		return weekScores.get(daWeek);
	}

	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
			weekScores = FlxG.save.data.weekScores;

		if (FlxG.save.data.songScores != null)
			songScores = FlxG.save.data.songScores;

		if (FlxG.save.data.songRating != null)
			songRating = FlxG.save.data.songRating;
	}
}