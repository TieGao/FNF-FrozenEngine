package nmv.modchart;

import flixel.FlxG;
import flixel.FlxSprite;
import nmv.backend.math.Vector3;
import objects.Note;

/**
 * NMV `funkin.game.modchart.ModManager` 的移植（P0 骨架 + P1 delta 管线）。
 *
 * ## 为什么不是照搬
 *
 * 参考引擎的 note 位置**完全由这里给**（`getPos` 写绝对屏幕坐标 → `updateObject`
 * 写回 obj.x/obj.y → `centerOrigin/centerOffsets`）。移植端的 note 位置由 Psych 的
 * 滚动公式算（section BPM / downScroll / 像素舞台 / `Note.swagWidth` 全绑在一起），
 * 接管等于重写 note 渲染 —— 见 `docs/nmv-port-plan/63-modchart-port-plan.md` §3。
 *
 * 所以这里只提供两条接口：
 * - **绝对布局**：`getBaseX / getCenterX / getStrumX / getBaseY` —— 多人唱（多条
 *   playfield）排布用，NMV 原式，不碰 Psych 的现有布局；
 * - **增量管线**：`getPosDelta` 返回 `getPos - 基准`，调用方叠到自己已有的 x/y 上。
 *   `activeMods` 为空时恒 0 → **默认零视觉变化**，可以安全合入。
 *
 * ## 现状
 *
 * P0（本文件）+ P1（delta 接口）已就位；**P2 的具体 modifier 子类尚未搬**（语料 218
 * 个谱面零 `mods` 数据，见 63 号文档 §1），`register` 目前只由脚本 `registerMod` 填充。
 * 接 P2 时只需把 modifier 子类放进 `nmv.modchart.modifiers` 并在 `registerDefaults()`
 * 里 `quickRegister`，调用点（Note/StrumNote 叠 delta）不用改。
 */
class ModManager
{
	/** playfield 条数（NMV `SONG.lanes`）：多人唱 > 1。 */
	public var lanes:Int = 1;
	/** 每条 playfield 的键数（NMV `SONG.keys`）。 */
	public var keys:Int = 4;

	/** 名字 → 修改器（含子模）。 */
	public var register:Map<String, Modifier> = [];

	/** 每个 lane 当前激活的修改器名（按 getOrder 排序后逐帧过链）。 */
	public var activeMods:Array<Array<String>> = [[], []];

	/** 每个 lane 是否有任何非零修饰值（快速短路：无 mod 不建 Vector3）。 */
	var anyActive:Array<Bool> = [false, false];

	var warned:Map<String, Bool> = [];

	public function new(?lanes:Int = 1, ?keys:Int = 4)
	{
		this.lanes = lanes;
		this.keys = keys;
	}

	function warnOnce(what:String, field:String):Void
	{
		final key:String = what + ':' + field;
		if (warned.exists(key)) return;
		warned.set(key, true);
		backend.Bread.crumb('nmv modchart P0: ' + what + '(\'' + field + '\') 尚无对应 modifier（P2 未搬）');
	}

	// ---------------------------------------------------------------- 注册表

	public function quickRegister(mod:Modifier):Modifier
	{
		if (mod == null) return null;
		registerMod(mod, mod.getName());
		for (sub in mod.submods.keys())
			register.set(sub, mod.submods.get(sub));
		return mod;
	}

	public function registerMod(mod:Modifier, ?name:String):Modifier
	{
		if (mod == null) return null;
		final n:String = (name != null && name.length > 0) ? name : mod.getName();
		register.set(n, mod);
		return mod;
	}

	/** 查一个名字（主模或子模）；子模返回其父模 + 子模本身由调用方区分。 */
	public function getMod(name:String):Modifier
		return register.get(name);

	// ---------------------------------------------------------------- 取值/设值

	function ensureLane(player:Int):Void
	{
		while (activeMods.length <= player)
		{
			activeMods.push([]);
			anyActive.push(false);
		}
	}

	/**
	 * `setValue('xmod', 100, 0)` / `setValue('xmod2', 50, 0)` —— 两种都吃：
	 * 名字直接命中主模，或命中某主模的 submods（子模名如 `xmod0`）。
	 */
	public function setValue(field:String, value:Float, player:Int = 0):Void
	{
		final mod:Modifier = register.get(field);
		if (mod == null)
		{
			warnOnce('setValue', field);
			return;
		}

		mod.setValue(value, player);

		// 子模的父模也要在活跃表里，否则 getPos 链不会走到它
		final owner:Modifier = (mod.parent != null) ? mod.parent : mod;
		ensureLane(player);
		refreshLane(player, owner);
	}

	public function getValue(field:String, player:Int = 0):Float
	{
		final mod:Modifier = register.get(field);
		if (mod == null)
		{
			warnOnce('getValue', field);
			return 0;
		}
		return mod.getValue(player);
	}

	/** 重排某 lane 的活跃表（有值或有非零子模才进来）。 */
	function refreshLane(player:Int, owner:Modifier):Void
	{
		ensureLane(player);
		final list:Array<String> = activeMods[player];
		final name:String = owner.getName();

		var run:Bool = owner.shouldExecute(player, owner.getValue(player));
		if (!run)
		{
			for (sub in owner.submods)
			{
				if (sub.getValue(player) != 0)
				{
					run = true;
					break;
				}
			}
		}

		if (run)
		{
			if (!list.contains(name)) list.push(name);
		}
		else list.remove(name);

		list.sort(function(a:String, b:String):Int
		{
			final ma:Modifier = register.get(a);
			final mb:Modifier = register.get(b);
			final oa:Int = (ma == null) ? 0 : ma.getOrder();
			final ob:Int = (mb == null) ? 0 : mb.getOrder();
			return oa - ob;
		});

		anyActive[player] = list.length > 0;
	}

	// ---------------------------------------------------------------- 绝对布局（多人唱）

	/** 某条 playfield 的中心 X：lane 0 贴右、1 贴左、>=2 居中（NMV `getCenterX` 原式）。 */
	public static function getCenterX(lane:Int, keys:Int):Float
	{
		return switch (lane)
		{
			case 0: (FlxG.width - Note.swagWidth * (keys / 2) - 100 - 3);
			case 1: (Note.swagWidth * (keys / 2) + 100 - 3);
			default: (FlxG.width * 0.5 - 3);
		}
	}

	/** 轨道内某一列相对中心的 X。 */
	public static function getStrumX(direction:Int, keys:Int):Float
		return (Note.swagWidth * (direction - (keys / 2) + .5));

	/** 某 lane 某列的绝对 X（不含 modifier）。 */
	public function getBaseX(direction:Int, lane:Int):Float
		return getCenterX(lane, keys) + getStrumX(direction, keys);

	/** 轨道基准 Y（NMV：`swagWidth*.5 + 50`；downScroll 由调用方翻转）。 */
	public static function getBaseY():Float
		return (Note.swagWidth * .5 + 50);

	// ---------------------------------------------------------------- 增量管线（P1）

	/**
	 * NMV `getPos` 原样：基准 + 逐个 modifier 改写，返回**绝对**坐标。
	 * 移植端只在 `getPosDelta` 内部调用它，外部不要直接用。
	 */
	public function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, data:Int, player:Int, obj:FlxSprite, ?exclusions:Array<String>,
			?pos:Vector3):Vector3
	{
		if (pos == null) pos = Vector3.get();
		if (obj != null && !obj.active) return pos;

		pos.setTo(getBaseX(data, player), getBaseY() + diff, 0);

		if (player < 0 || player >= activeMods.length || activeMods[player] == null) return pos;

		for (name in activeMods[player])
		{
			if (exclusions != null && exclusions.contains(name)) continue;
			final mod:Modifier = register.get(name);
			if (mod == null) continue;
			final next:Vector3 = mod.getPos(time, diff, tDiff, beat, pos, data, player, obj);
			if (next != null && next != pos)
			{
				pos.put();
				pos = next;
			}
		}
		return pos;
	}

	/**
	 * **P1 核心**：modifier 链对基准位置的偏移量（不含基准本身）。
	 *
	 * 调用方（Note / StrumNote）把它叠到自己算好的 x/y 上即可，不接管坐标。
	 * 没有激活的 modifier 时**直接返回池化的 (0,0,0)**（不建 Vector3、不进链）。
	 * 返回值是池对象，调用方用完必须 `put()`。
	 */
	public function getPosDelta(time:Float, diff:Float, tDiff:Float, beat:Float, data:Int, player:Int, obj:FlxSprite):Vector3
	{
		if (player < 0 || player >= activeMods.length || !anyActive[player]) return Vector3.get(0, 0, 0);

		final base:Vector3 = Vector3.get(getBaseX(data, player), getBaseY() + diff, 0);
		final out:Vector3 = getPos(time, diff, tDiff, beat, data, player, obj);
		out.subtract(base, out);
		base.put();
		return out;
	}

	/**
	 * 逐 modifier 的 note/receptor 钩子（NMV `updateObject` 的后半段）。
	 *
	 * **不含** NMV 的 `obj.x = pos.x - width*.5` 与 `centerOrigin/centerOffsets` ——
	 * 那两笔在 Psych 上会撕裂 sustain 的 clipRect（63 号文档风险 1、3）。
	 */
	public function applyObjectMods(beat:Float, obj:FlxSprite, player:Int, ?isNote:Bool = false, ?isReceptor:Bool = false):Void
	{
		if (player < 0 || player >= activeMods.length || !anyActive[player]) return;

		final pos:Vector3 = Vector3.get(obj.x + obj.width * .5, obj.y + obj.height * .5, 0);
		for (name in activeMods[player])
		{
			final mod:Modifier = register.get(name);
			if (mod == null) continue;
			if (isNote) mod.updateNote(beat, obj, pos, player);
			else if (isReceptor) mod.updateReceptor(beat, obj, pos, player);
			else mod.updateNoteSplash(beat, obj, pos, player);
		}
		pos.put();
	}

	/** 逐帧推各 modifier 的 update(elapsed)（NMV `update`）。 */
	public function update(elapsed:Float):Void
	{
		for (lane in 0...activeMods.length)
		{
			if (!anyActive[lane]) continue;
			for (name in activeMods[lane])
			{
				final mod:Modifier = register.get(name);
				if (mod != null && mod.active && mod.doesUpdate()) mod.update(elapsed);
			}
		}
	}

	public function destroy():Void
	{
		for (mod in register)
			if (mod != null) mod.destroy();
		register = [];
		activeMods = [[], []];
	}
}
