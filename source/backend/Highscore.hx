package backend;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();
	/** 游玩次数（歌曲+难度+模组+模式 分档），键与 songScores 同构 */
	public static var songPlayCount:Map<String, Int> = new Map<String, Int>();

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

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1, ?modFolder:String = null, ?mode:String = null):Void
	{
		if(song == null) return;
		var daSong:String = formatSong(song, diff, modFolder, mode);

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

	static function setPlayCount(song:String, count:Int):Void
	{
		songPlayCount.set(song, count);
		FlxG.save.data.songPlayCount = songPlayCount;
		FlxG.save.flush();
	}

	/**
	 * 格式化歌曲键名，支持模组隔离
	 * 格式：[模组名:]歌曲名_难度
	 */
	public static function formatSong(song:String, diff:Int, ?modFolder:String = null, ?mode:String = null):String
	{
		var formattedSong:String = Paths.formatToSongPath(song);
		var diffPath:String = Difficulty.getFilePath(diff);
		var modeSuffix:String = '';
		if (mode != null && mode.length > 0 && mode != 'player')
			modeSuffix = '_' + mode;

		// 如果有模组文件夹，使用模组隔离的键
		if (modFolder != null && modFolder.length > 0 && modFolder != "base")
		{
			return modFolder + ":" + formattedSong + diffPath + modeSuffix;
		}
		
		// 默认行为（向后兼容）
		return formattedSong + diffPath + modeSuffix;
	}

	public static function getScore(song:String, diff:Int, ?modFolder:String = null, ?mode:String = null):Int
	{
		var daSong:String = formatSong(song, diff, modFolder, mode);
		if (!songScores.exists(daSong))
			setScore(daSong, 0);

		return songScores.get(daSong);
	}

	public static function getRating(song:String, diff:Int, ?modFolder:String = null, ?mode:String = null):Float
	{
		var daSong:String = formatSong(song, diff, modFolder, mode);
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

	/**
	 * 游玩次数 +1。键必须走 formatSong，保证模组隔离与 opponentplay 分档一致。
	 */
	public static function savePlayCount(song:String, diff:Int = 0, ?modFolder:String = null, ?mode:String = null):Void
	{
		if (song == null) return;
		var daSong:String = formatSong(song, diff, modFolder, mode);
		setPlayCount(daSong, getPlayCount(song, diff, modFolder, mode) + 1);
	}

	/**
	 * 读取游玩次数。缺失返回 0 且**不写回存档**（避免给老存档灌一堆 0 键）。
	 */
	public static function getPlayCount(song:String, diff:Int = 0, ?modFolder:String = null, ?mode:String = null):Int
	{
		var daSong:String = formatSong(song, diff, modFolder, mode);
		var value:Null<Int> = songPlayCount.get(daSong);
		return (value == null) ? 0 : value;
	}

	public static function resetPlayCount(song:String, diff:Int = 0, ?modFolder:String = null, ?mode:String = null):Void
	{
		if (song == null) return;
		setPlayCount(formatSong(song, diff, modFolder, mode), 0);
	}

	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
			weekScores = FlxG.save.data.weekScores;

		if (FlxG.save.data.songScores != null)
			songScores = FlxG.save.data.songScores;

		if (FlxG.save.data.songRating != null)
			songRating = FlxG.save.data.songRating;

		if (FlxG.save.data.songPlayCount != null)
			songPlayCount = FlxG.save.data.songPlayCount;
	}
}