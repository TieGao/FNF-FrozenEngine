package backend;

/**
 * 游玩模式。字符串值与存档 / 回放 / Lua 里的 opponentplay 完全一致，可直接互转。
 *
 * - PLAYER：玩家打 BF 侧（mustPress），对手侧由 CPU 打
 * - OPPONENT：玩家打对手侧（!mustPress），BF 侧由 CPU 打
 * - COOP：两侧都由玩家打，共用一套 HUD / 血条
 * - COOP_SPLIT：同 COOP，但两侧各有独立 HUD / 血条 / 判定统计
 *
 * 所有"谁在打这个 note"的判断都收敛到 sideIsHuman()，不要在调用方重新拼字符串比较。
 */
enum abstract PlayMode(String) from String to String
{
	var PLAYER = 'player';
	var OPPONENT = 'opponent';
	var COOP = 'coop';
	var COOP_SPLIT = 'coop_split';

	/** 把存档 / 回放 / 设置里的任意值（含旧版 bool）收成合法模式。 */
	public static function normalize(value:Dynamic):PlayMode
	{
		if (value == null) return PLAYER;
		if (Std.isOfType(value, Bool)) return (value:Bool) ? OPPONENT : PLAYER;

		return switch (Std.string(value).trim().toLowerCase())
		{
			case 'opponent', 'opponentplaytrue': OPPONENT;
			case 'coop', 'both', 'cooperative': COOP;
			case 'coop_split': COOP_SPLIT;
			default: PLAYER;
		}
	}

	public inline function isPlayer():Bool
		return this == PLAYER;

	public inline function isOpponent():Bool
		return this == OPPONENT;

	public inline function isCoop():Bool
		return this == COOP || this == COOP_SPLIT;

	public inline function isSplitCoop():Bool
		return this == COOP_SPLIT;

	/**
	 * 该侧（mustPress）是否由玩家操作。
	 * coop 两侧都是人：keyBindIndex 0 = 玩家侧、1 = 对手侧；传 -1 表示不区分操作者。
	 */
	public function sideIsHuman(mustPress:Bool, keyBindIndex:Int = -1):Bool
	{
		if (this == OPPONENT) return !mustPress;
		if (isCoop()) return keyBindIndex < 0 ? true : (keyBindIndex == 0) == mustPress;
		return mustPress;
	}

	/** 由 CPU 自动演奏的那一侧是否为玩家侧（只有 opponent 模式是）。 */
	public inline function cpuDrivesPlayerSide():Bool
		return this == OPPONENT;
}
