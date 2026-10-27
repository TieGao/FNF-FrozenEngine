package nmv.data;

/**
 * NMV funkin.data.GameFlags 的最小移植：语料只用到剧情旗标
 * （attack.hx 的 giveFlag/hasFlag）。NMV 原版持久化在 ClientPrefs.tidbits，
 * FE 没有这个存档段 —— 这里会话内存放（跨启动不保留），与"无 NMV 存档"
 * 的现实一致； achievements/Awards 族是 NMV 专属系统，不移植。
 */
class GameFlags
{
	static var flags:Array<String> = [];

	public static function hasFlag(id:String):Bool
	{
		return flags.contains(id);
	}

	public static function giveFlag(id:String):Void
	{
		if (hasFlag(id)) return;
		flags.push(id);
		trace('Added flag: $id');
	}
}
