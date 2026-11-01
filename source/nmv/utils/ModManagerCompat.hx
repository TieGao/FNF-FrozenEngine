package nmv.utils;

import flixel.FlxG;
import flixel.FlxSprite;
import objects.Note;

/**
 * NMV ModManager（Nebula_Zorua modchart 体系）的 FE 兼容面。
 *
 * 完整 modchart 引擎（transformX/stealth/queueEase 时间线等）明确 defer（见 52 号文档），
 * 但此前 PresetStubs 的"调用即抛"桩会**炸断** attack/defeat/sigh 等舞台脚本的
 * onCreatePost——它们 setValue 完才会继续做正事（attack 的 noteType 路由、defeat 的
 * opponentSwap），连锁把"切换角色唱歌"的歌曲搞坏。
 *
 * 语义分级：
 * - setValue/getValue：真存值（per 车道），脚本回读一致；
 * - registerMod：接受并记录名字；
 * - queueEase/queueFuncOnce/updateObject/getPos/updateTimeline/update：记录式 no-op
 *   + 每个修改器名只打一次面包屑（视觉效果退化但有迹可查）。
 */
class ModManagerCompat
{
	/** per 车道的修改器值：mods[field][playFieldIndex] = value */
	final values:Map<String, Map<Int, Dynamic>> = [];
	final warned:Map<String, Bool> = [];

	/**
	 * NMV `ModManager.lanes` / `keys`：**多人唱（多 playfield）的布局地基**。
	 *
	 * NMV 的 `SONG.lanes` 是"playfield 条数"（monotone-attack = 4），每条 `keys` 键；
	 * 谱面 `sectionNotes` 的 noteData 是**绝对车道** 0 .. lanes*keys-1。
	 * NMV 的排布（`ModManager.getCenterX`）：
	 *   lane 0 = 玩家侧（贴右边），lane 1 = 对手侧（贴左边），lane >=2 = 屏幕正中。
	 * 移植端此前 `keys` 恒 4/8、不读 SONG.lanes，16 轨谱面被折回 8 轨 → 多出来的
	 * 车道全落到对手轨（用户报的"白 note 本应 2 人分着唱，结果全被 dad 唱"）。
	 */
	public var lanes:Int = 1;
	public var keys:Int = 4;

	/**
	 * 真 modchart 内核（P0 骨架 + P1 delta 管线）。脚本侧仍走本兼容面（`setValue`
	 * 等沿用记录式语义，保住 attack/voting/Finale 的 alpha/stealth 表现），但
	 * `registerMod` 会把真的 `Modifier` 实例转登记进内核，`getPosDelta` 也委托给它 ——
	 * 这样 P2 把 modifier 子类补上后，delta 会自动开始生效，调用点不用改。
	 */
	public var core:nmv.modchart.ModManager = new nmv.modchart.ModManager();

	public function new(?lanes:Int = 1, ?keys:Int = 4)
	{
		this.lanes = lanes;
		this.keys = keys;
		core.lanes = lanes;
		core.keys = keys;
	}

	// ---- 位置函数（NMV ModManager 原式，供多人唱排布与 modchart delta 使用）----

	/**
	 * 清空本首歌累积的修饰值（`values` / 面包屑去重表）。
	 *
	 * 本实例是 `PresetFnf.sharedModManager`（**跨歌静态共享**），而 `setValue` 是永久赋值：
	 * 不重置的话上一首 voting-time 留下的 `transformX = ±865` 会带进下一首多轨歌，
	 * 把人家的轨道推飞。每首歌建脚本容器时调一次（NMVSciptHolder.new）。
	 * `core`（真 modchart 内核）不动：它有自己的注册表与生命周期。
	 */
	public function reset():Void
	{
		values.clear();
		warned.clear();
	}

	/** 某条 playfield 的中心 X。lane 0 右、lane 1 左、>=2 居中（NMV 原式）。 */
	public static inline function getCenterX(lane:Int, keys:Int):Float
		return nmv.modchart.ModManager.getCenterX(lane, keys);

	/** 轨道内某一列相对中心的 X。 */
	public static inline function getStrumX(direction:Int, keys:Int):Float
		return nmv.modchart.ModManager.getStrumX(direction, keys);

	/** 某 lane 某列的绝对 X（不叠 mod）。 */
	public function getBaseX(direction:Int, lane:Int):Float
		return nmv.modchart.ModManager.getCenterX(lane, keys) + nmv.modchart.ModManager.getStrumX(direction, keys);

	/** 轨道基准 Y（NMV：`swagWidth*.5 + 50`，downScroll 由调用方翻转）。 */
	public static inline function getBaseY():Float
		return nmv.modchart.ModManager.getBaseY();

	/**
	 * P1 · delta 管线（只算**变换量**，不接管坐标）。
	 *
	 * NMV 的 `getPos` 返回绝对屏幕坐标，直接套到 Psych 上会炸（滚动公式与 section BPM、
	 * downScroll、像素舞台全绑在一起，见 63 号文档 §3）。这里返回 `getPos - 基准`，
	 * 调用方叠到已有的 x/y 上：**没有激活的 modifier 时恒为 0 → 零视觉变化**。
	 * 返回值是池对象，用完要 `put()`。
	 */
	public function getPosDelta(time:Float, diff:Float, tDiff:Float, beat:Float, data:Int, lane:Int, obj:FlxSprite):nmv.backend.math.Vector3
		return core.getPosDelta(time, diff, tDiff, beat, data, lane, obj);

	inline function bucket(field:String):Map<Int, Dynamic>
	{
		if (!values.exists(field)) values.set(field, []);
		return values.get(field);
	}

	function warnOnce(what:String, field:String):Void
	{
		final key:String = what + ':' + field;
		if (warned.exists(key)) return;
		warned.set(key, true);
		backend.Bread.crumb('nmv modchart no-op: ' + what + '(\'' + field + '\')（modchart 体系未移植，视觉退化）');
	}

	public function setValue(field:String, value:Dynamic, ?playFieldIndex:Int = 0):Dynamic
	{
		bucket(field).set(playFieldIndex ?? 0, value);
		warnOnce('setValue', field);
		return value;
	}

	public function getValue(field:String, ?playFieldIndex:Int = 0):Dynamic
	{
		final b:Map<Int, Dynamic> = values.get(field);
		return (b != null && b.exists(playFieldIndex ?? 0)) ? b.get(playFieldIndex ?? 0) : 0;
	}

	/**
	 * 数值版 getValue：缺失 / 非数值一律 0（= NMV 修饰器的 percents 默认值）。
	 *
	 * 供**布局类**取值使用：`transformX` 在 NMV 是 TransformModifier 的
	 * `pos.x += getValue(player)`（增量语义），舞台脚本用
	 * `setValue("transformX", ±865, lane)` 把整条 playfield 推出屏幕
	 * （voting.hx:120 / attack.hx:151）。移植端没有跑 modifier 链，
	 * 但值本身已经在 values 里，直接读即可 —— 见 PlayState.applyLaneStrumOffsets()。
	 */
	public function getLaneValue(field:String, lane:Int):Float
	{
		final v:Dynamic = getValue(field, lane);
		if (Std.isOfType(v, Float)) return cast v;
		if (Std.isOfType(v, Int)) return cast v;
		return 0;
	}

	/**
	 * NMV AlphaModifier（'stealth'）note 侧语义的 port 版：该车道 note 透明度乘数。
	 * - 'alpha'：attack/voting 的 2v2 外侧轨 setValue("alpha",0.7) → 0.3（半透明）；
	 *   Finale setValue("alpha",1) → 0（NMV 同款 = 对手轨 note 隐藏）。
	 *   注：NMV 本体里 'alpha' 未注册为修饰器（setValue 走 register.get 报错无效），
	 *   这里采纳脚本作者的设置意图 + 用户实测要的"白色半透明"观感。
	 */
	public function laneNoteAlphaMult(lane:Int):Float
	{
		var a:Float = getValue('alpha', lane);
		if (Math.isNaN(a)) a = 0;
		var mult:Float = a > 0 ? Math.max(1 - a, 0) : 1;

		// NMV AlphaModifier.updateNote 的完整乘积是
		// `(1-alpha) * (1-alpha{col}) * (1-noteAlpha) * (1-noteAlpha{col})`。
		// noteAlpha 是**整条 playfield 的 note 透明度**：attack.hx:163 / voting.hx:117
		// 给 lane 2/3 设 `noteAlpha = 1` → 这两条轨道的 note 完全透明。
		// 不做这一项的话，即使 strum 被 transformX 推出屏幕，note 仍会半透明地挂在那。
		var na:Float = getValue('noteAlpha', lane);
		if (Math.isNaN(na)) na = 0;
		if (na > 0) mult *= Math.max(1 - na, 0);

		return mult;
	}

	/**
	 * NMV AlphaModifier 的可见度常值项（`getVisibility` 里只取 stealth 那一段）：
	 * `clamp(1 - stealth, 0, 1)`。位置项（hidden / sudden / blink / randomVanish）未移植，
	 * 因为它们要逐帧算 note 的 y —— FE 的滚动公式与 NMV 不同源，照抄会算出错的 y。
	 */
	public function laneVisibility(lane:Int):Float
	{
		var s:Float = getValue('stealth', lane);
		if (Math.isNaN(s)) s = 0;
		return Math.max(0, Math.min(1 - s, 1));
	}

	/**
	 * NMV `AlphaModifier.getAlpha(visible)`：`scale(v, 0.5, 0, 1, 0)` → `v * 2`，clamp 0..1。
	 * 即 visible ≥ 0.5 全不透明、0 全透明。
	 */
	public function laneStealthAlpha(lane:Int):Float
	{
		final v:Float = laneVisibility(lane);
		return Math.max(0, Math.min(v * 2, 1));
	}

	/**
	 * NMV `AlphaModifier.getGlow(visible)`：`scale(v, 1, 0.5, 0, 1.3)` → `(1 - v) * 2.6`，clamp 0..1。
	 *
	 * 关键：白闪只在 **部分淡出**（visible 从 1 掉到 0.5）时出现；visible = 1 时为 0。
	 * attack/voting 的外侧轨 stealth=0.5 → visible 0.5 → glow 1（全白），
	 * 但同时 `noteAlpha=1` 会把 note 整体隐藏 —— 两端都要有，只做白不做透明就是
	 * "屏幕上挂着一堆白 note"。
	 */
	public function laneStealthGlow(lane:Int):Float
	{
		final v:Float = laneVisibility(lane);
		if (v >= 1) return 0;
		final g:Float = (1 - v) * 2.6;
		return Math.max(0, Math.min(g, 1));
	}

	/**
	 * NMV `AlphaModifier.updateReceptor`：`(1 - alpha) * (1 - alpha{col})`。
	 * 作用在轨道受体（strum）上 —— attack/voting 给外侧轨 `alpha=0.7` → 受体只剩 30%。
	 */
	public function laneReceptorAlpha(lane:Int, column:Int = -1):Float
	{
		var a:Float = getValue('alpha', lane);
		if (Math.isNaN(a)) a = 0;
		var mult:Float = Math.max(1 - a, 0);
		if (column >= 0)
		{
			var ca:Float = getValue('alpha' + column, lane);
			if (Math.isNaN(ca)) ca = 0;
			if (ca > 0) mult *= Math.max(1 - ca, 0);
		}
		return mult;
	}

	public function registerMod(mod:Dynamic, ?subMod:Dynamic = null, ?save:Bool = true):Dynamic
	{
		final name:String = (mod != null && Reflect.hasField(mod, 'name')) ? Reflect.field(mod, 'name') : Std.string(Type.typeof(mod));
		warnOnce('registerMod', name);
		// 真的 Modifier 实例转登记进内核：P2 把子类搬齐后，getPosDelta 会自己开始出量，
		// 脚本侧（仍走本兼容面）不用改一行。
		if (Std.isOfType(mod, nmv.modchart.Modifier)) core.registerMod(cast mod);
		return mod;
	}

	public function quickRegister(mod:Dynamic):Dynamic
	{
		return registerMod(mod);
	}

	// ---- 时间线/对象操作：记录式 no-op（完整时间线引擎未移植）

	public function queueEase(playFieldIndex:Int, startTime:Float, endTime:Float, value:Dynamic, field:String, ?ease:String = 'linear'):Void
	{
		bucket(field).set(playFieldIndex, value);
		warnOnce('queueEase', field);
	}

	public function queueFuncOnce(func:Dynamic, timestamp:Float, ?playFieldIndex:Int = 0):Void
	{
		// 一次性回调推迟执行会破坏时序语义，直接执行保逻辑正确（如 defeat 的 UI 切换）
		try
		{
			if (Reflect.isFunction(func)) Reflect.callMethod(null, func, []);
		}
		catch (e:Dynamic)
		{
			backend.Bread.crumb('nmv modchart queueFuncOnce exec failed: ' + e);
		}
	}

	public function queueSet(playFieldIndex:Int, timestamp:Float, field:String, value:Dynamic):Void
	{
		bucket(field).set(playFieldIndex, value);
		warnOnce('queueSet', field);
	}

	public function updateObject(beat:Float, obj:FlxSprite, pos:Dynamic, ?playFieldIndex:Int = 0):Void
	{
		warnOnce('updateObject', 'objects');
	}

	public function getPos(playFieldIndex:Int, beat:Float, time:Float, height:Float, column:Int, ?player:Int = 0, ?data:Dynamic = null):Dynamic
	{
		warnOnce('getPos', 'pos');
		return null;
	}

	public function updateTimeline(timeline:Dynamic):Void
	{
		warnOnce('updateTimeline', 'timeline');
	}

	public function update(elapsed:Float):Void {}
}
