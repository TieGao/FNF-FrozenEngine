package states.freeplay;

/**
 * Freeplay 卡片右上角的评级档位。
 * 阈值按最佳 accuracy 百分比（全难度取最高）：
 *   >=98 彩色P（粉P素材 + ColorSwap 色相循环）
 *   >=96 粉P   >=90 金P   >=80 金E   >=70 银G   >=60 铜G   <60 蓝L   0=未游玩
 * 底层为 Int 抽象枚举，可直接用 > 比较升档。
 */
enum abstract FreeplayRank(Int) to Int
{
	var NONE;          // 未游玩 / rating 0 → 无徽章
	var LOSS;          // <60  蓝L
	var GOOD;          // 60-70 铜G
	var GREAT;         // 70-80 银G
	var EXCELLENT;     // 80-90 金E
	var PERFECT_GOLD;  // 90-96 金P（官方 PERFECT rank GOLD 素材）
	var PERFECT;       // 96-98 粉P
	var RAINBOW;       // >=98 彩色P（粉P素材 + 色相循环）

	/** 升档判定用：newRank > oldRank */
	@:op(A > B) static inline function gt(a:FreeplayRank, b:FreeplayRank):Bool
		return (a:Int) > (b:Int);

	@:op(A >= B) static inline function gte(a:FreeplayRank, b:FreeplayRank):Bool
		return (a:Int) >= (b:Int);

	public static function fromAccuracy(percent:Float):FreeplayRank
	{
		if (percent <= 0) return NONE;
		if (percent >= 98) return RAINBOW;
		if (percent >= 96) return PERFECT;
		if (percent >= 90) return PERFECT_GOLD;
		if (percent >= 80) return EXCELLENT;
		if (percent >= 70) return GREAT;
		if (percent >= 60) return GOOD;
		return LOSS;
	}

	/** rankbadges.xml 里的动画前缀（含空格，addByPrefix 原样传） */
	public var animName(get, never):Null<String>;

	function get_animName():Null<String>
	{
		return switch (cast(this, FreeplayRank))
		{
			case LOSS: 'LOSS rank';
			case GOOD: 'GOOD rank';
			case GREAT: 'GREAT rank';
			case EXCELLENT: 'EXCELLENT rank';
			case PERFECT_GOLD: 'PERFECT rank GOLD';
			case PERFECT | RAINBOW: 'PERFECT rank';
			default: null;
		}
	}

	/** vignette / 火花 tint 用（照官方 getRankingFreeplayColor） */
	public var freeplayColor(get, never):FlxColor;

	function get_freeplayColor():FlxColor
	{
		return switch (cast(this, FreeplayRank))
		{
			case LOSS: 0xFF6044FF;
			case GOOD: 0xFFEF8764;
			case GREAT: 0xFFEAF6FF;
			case EXCELLENT: 0xFFFDCB42;
			case PERFECT: 0xFFFF58B4;
			case PERFECT_GOLD | RAINBOW: 0xFFFFB619;
			default: FlxColor.WHITE;
		}
	}

	/** rank-in / slam 音效 key（assets/shared/sounds/ranks/） */
	public var rankInSound(get, never):String;

	function get_rankInSound():String
	{
		return switch (cast(this, FreeplayRank))
		{
			case LOSS: 'ranks/rankinbad';
			case PERFECT | PERFECT_GOLD | RAINBOW: 'ranks/rankinperfect';
			default: 'ranks/rankinnormal';
		}
	}

	public var slamSound(get, never):String;

	function get_slamSound():String
	{
		return switch (cast(this, FreeplayRank))
		{
			case LOSS: 'ranks/loss';
			case GOOD: 'ranks/good';
			case GREAT: 'ranks/great';
			case EXCELLENT: 'ranks/excellent';
			case PERFECT | PERFECT_GOLD | RAINBOW: 'ranks/perfect';
			default: 'ranks/loss';
		}
	}
}
