package backend;

class Difficulty
{
	public static final defaultList:Array<String> = [
		'Easy',
		'Normal',
		'Hard'
	];
	private static final defaultDifficulty:String = 'Normal'; //The chart that has no postfix and starting difficulty on Freeplay/Story Mode

	public static var list:Array<String> = [];

	// 难度颜色，给 Freeplay 的难度 carousel 染色用。
	// 和 list 同生命周期 —— list 一变颜色就得重算，所以只在给 list 赋值的三个入口
	// （loadFromWeek / resetList / copyFrom）里调 refreshColors()，别在别处改 list。
	public static var colors:Array<Int> = [];

	/** 取某个难度的颜色。越界或未知名返回中性灰。 */
	public static function getColor(?num:Null<Int> = null):Int
	{
		var i:Int = (num == null) ? PlayState.storyDifficulty : num;
		if (i < 0 || i >= colors.length) return 0xFF888888;
		return colors[i];
	}

	public static function refreshColors():Void
	{
		colors = [];
		for (name in list)
			colors.push(colorForName(name));
	}

	private static function colorForName(name:String):Int
	{
		if (name == null) return 0xFF888888;
		return switch (name.toLowerCase())
		{
			case 'easy':               0xFF7BD34A;
			case 'normal':             0xFFFFE228;
			case 'hard':               0xFFFF286C;
			case 'erect':              0xFF28C3FF;
			case 'pico':               0xFFF29B30;
			case 'nightmare', 'hmnf':  0xFFB91C1C;
			default:                   0xFF888888;
		}
	}

	inline public static function getFilePath(num:Null<Int> = null)
	{
		if(num == null) num = PlayState.storyDifficulty;

		var filePostfix:String = list[num];
		if(filePostfix != null && Paths.formatToSongPath(filePostfix) != Paths.formatToSongPath(defaultDifficulty))
			filePostfix = '-' + filePostfix;
		else
			filePostfix = '';
		return Paths.formatToSongPath(filePostfix);
	}

	inline public static function loadFromWeek(week:WeekData = null)
	{
		if(week == null) week = WeekData.getCurrentWeek();

		var diffStr:String = week.difficulties;
		if(diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.trim().split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if(diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if(diffs[i].length < 1) diffs.remove(diffs[i]);
				}
				--i;
			}

			if(diffs.length > 0 && diffs[0].length > 0)
				list = diffs;
		}
		else resetList();

		refreshColors();
	}

	inline public static function resetList()
	{
		list = defaultList.copy();
		refreshColors();
	}

	inline public static function copyFrom(diffs:Array<String>)
	{
		list = diffs.copy();
		refreshColors();
	}

	inline public static function getString(?num:Null<Int> = null, ?canTranslate:Bool = true):String
	{
		var diffName:String = list[num == null ? PlayState.storyDifficulty : num];
		if(diffName == null) diffName = defaultDifficulty;
		return canTranslate ? Language.getPhrase('difficulty_$diffName', diffName) : diffName;
	}

	inline public static function getDefault():String
	{
		return defaultDifficulty;
	}
	public static function getDefaultIndex():Int
{
    var defaultDiff:String = getDefault();
    var index:Int = Difficulty.list.indexOf(defaultDiff);
    if (index == -1) index = 0;
    return index;
}

	/**
	 * 变体难度的音轨目录后缀 —— 变体难度的音轨放在 `songs/<歌>-<后缀>/` 里，目录名带变体、文件名不带。
	 * 返回 null 表示该难度没有独立音轨目录（Easy / Normal / Hard）。
	 *
	 * ⚠️ 后缀不能直接取难度名：Funkin 的 erect 变体含 `erect` / `nightmare` 两个难度，
	 * 但 `playData.characters.instrumental` 只有一个 `"erect"`，原版也没有任何 `Inst-nightmare.ogg`
	 * —— nightmare 与 erect 共用一套音轨，所以后缀要按「变体」取。
	 */
	public static function getAudioVariant(?num:Null<Int> = null):String
	{
		if (num == null) num = PlayState.storyDifficulty;
		if (num < 0 || num >= list.length) return null;

		var name:String = list[num];
		if (name == null || name.length == 0) return null;

		var lower:String = name.toLowerCase();
		if (lower == 'nightmare' || lower == 'hmnf') return 'Erect';
		for (base in defaultList)
			if (base.toLowerCase() == lower) return null;

		// 其余难度名即变体目录后缀，保留 week 的 difficulties 里写的原始大小写
		return name;
	}
}