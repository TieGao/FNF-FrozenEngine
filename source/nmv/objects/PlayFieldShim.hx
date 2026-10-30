package nmv.objects;

import flixel.FlxBasic;
import flixel.FlxSprite;

/**
 * NMV PlayField 的 FE 兼容面：NMV 的谱面车道容器（strums + owner/playerControls 等字段）。
 *
 * 语料用面（2026-10-30 全包扫描）：
 * - `for (playField in playFields)` 迭代车道；
 * - `for (strum in playField)` 迭代车道内的 strum（sigh.hx）；
 * - `playFields.members[2/3].owner/isPlayer/playerControls`（attack/voting 的
 *   2v2 "Opponent Two" 机制 —— FE 无此系统，2/3 号位为空壳仅保字段面）；
 * - `refreshZ(playFields)`（PlayState.refreshZ 兼容，按 zIndex 排序）。
 *
 * 0/1 号位包住 FE 真实的 playerStrums/opponentStrums（活引用，strums 后建也能迭代到）；
 * 2/3 号位为空壳（members 为空），脚本写 owner/isPlayer 不炸，但无渲染/输入语义。
 * 刻意不继承 FlxTypedGroup：其 iterator/sort 是 inline 不可覆盖，自行实现迭代面。
 * ID 用 FlxBasic 的（只读面足够：脚本只读 `playField.ID != 0`）。
 */
class PlayFieldShim extends FlxBasic
{
	public var playerControls:Bool = true;
	public var owner:Dynamic = null;
	public var isPlayer:Bool = true;

	/** 本车道对应的 FE strum 组（0/1 号位；2/3 号位为 null）。迭代时取活成员。 */
	public var strums:Iterable<FlxSprite>;

	public function new(id:Int, isPlayerSide:Bool, ?strumGroup:Iterable<FlxSprite>)
	{
		super();
		this.ID = id;
		this.isPlayer = isPlayerSide;
		this.strums = strumGroup;
	}

	/** `for (strum in playField)`：迭代 strums 组的当前成员（空位车道为空迭代）。 */
	public function iterator():Iterator<FlxSprite>
	{
		return (strums != null) ? strums.iterator() : ([] : Array<FlxSprite>).iterator();
	}
}
