package nmv.modchart;

import flixel.FlxSprite;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import nmv.backend.math.Vector3;

/**
 * NMV `funkin.game.modchart.Modifier` 原样移植（Nebula_Zorua 的 Schmovin'/Andromeda 混合体系）。
 *
 * 只改 import 路径：`funkin.objects.*` → FE 的 `objects.*`（这里用 FlxSprite 宽口径，
 * note/strum/splash 都由调用方判定，见 ModManager.applyObjectMods）。
 *
 * ## 与参考引擎的一处刻意偏差
 *
 * NMV 的 modifier 通过 `getPos` **改写绝对坐标**（`pos.setTo(...)` 之后逐个 modifier 改
 * x/y/z），再由 `updateObject` 写回 `obj.x/obj.y` 并 `centerOrigin/centerOffsets`。
 * 移植端不能接管坐标（Psych 的 note 滚动公式与 section BPM / downScroll / 像素舞台
 * 全绑在一起，见 63 号文档 §3），所以只取 **delta**：`getPosDelta = getPos - 基准`，
 * 由 Note/StrumNote 叠到自己的 x/y 上。默认 `activeMods` 为空 → delta 恒 0 → 零视觉变化。
 */
enum abstract ModifierType(String)
{
	var NOTE_MOD; // 会移动 note 的修改器
	var MISC_MOD; // 其它
}

enum abstract ModifierOrder(Int) to Int
{
	var FIRST = -1000;
	var PRE_REVERSE = -3;
	var REVERSE = -2;
	var POST_REVERSE = -1;
	var DEFAULT = 0;
	var LAST = 1000;
}

class Modifier implements IFlxDestroyable
{
	public var modMgr:ModManager;
	/** 每个 playfield/lane 一个值（NMV 用 [player] 索引）。 */
	public var percents:Array<Float> = [0, 0];
	public var submods:Map<String, Modifier> = [];
	public var parent:Modifier;
	public var active:Bool = false;

	public function getModType():ModifierType
		return MISC_MOD;

	public function doesUpdate():Bool
		return getModType() == MISC_MOD;

	public function shouldExecute(player:Int, value:Float):Bool
		return value != 0;

	public function getOrder():Int
		return DEFAULT;

	public function getName():String
	{
		throw new haxe.exceptions.NotImplementedException(); // 子类必须覆写
		return '';
	}

	public function getValue(player:Int):Float
		return percents[player];

	public function getPercent(player:Int):Float
		return getValue(player) * 100;

	public function setValue(value:Float, player:Int = -1)
	{
		if (player == -1)
		{
			for (idx in 0...percents.length)
				percents[idx] = value;
		}
		else percents[player] = value;
	}

	public function setPercent(percent:Float, player:Int = -1)
		setValue(percent * 0.01, player);

	public function getSubmods():Array<String>
		return [];

	public function getSubmodPercent(modName:String, player:Int)
		return submods.exists(modName) ? submods.get(modName).getPercent(player) : 0;

	public function getSubmodValue(modName:String, player:Int)
		return submods.exists(modName) ? submods.get(modName).getValue(player) : 0;

	public function setSubmodPercent(modName:String, endPercent:Float, player:Int)
		return submods.get(modName).setPercent(endPercent, player);

	public function setSubmodValue(modName:String, endValue:Float, player:Int)
		return submods.get(modName).setValue(endValue, player);

	public function new(modMgr:ModManager, ?parent:Modifier)
	{
		this.modMgr = modMgr;
		this.parent = parent;
		for (submod in getSubmods())
			submods.set(submod, new SubModifier(submod, modMgr, this));
	}

	// time  = note/receptor 的 strumTime
	// diff  = 可视差值（strumTime - 当前时间，已含滚动速度）
	// beat  = 带小数的 curBeat
	// pos   = 当前位置（NMV 里可被就地改写）
	// player= 0 玩家侧 / 1 对手侧 / >=2 多人唱的额外 playfield
	// data  = 列号（direction）

	public function updateReceptor(beat:Float, receptor:FlxSprite, pos:Vector3, player:Int) {}

	public function updateNote(beat:Float, note:FlxSprite, pos:Vector3, player:Int) {}

	public function updateNoteSplash(beat:Float, splash:FlxSprite, pos:Vector3, player:Int) {}

	public function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3
		return pos;

	public function update(elapsed:Float) {}

	public function destroy():Void {}
}
