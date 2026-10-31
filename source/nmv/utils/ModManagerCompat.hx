package nmv.utils;

import flixel.FlxSprite;

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

	public function new() {}

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
		return a > 0 ? Math.max(1 - a, 0) : 1;
	}

	/**
	 * NMV AlphaModifier 的 stealth 白闪强度（RGBShader a_flash 语义，mix 向白）：
	 * getVisibility=1-stealth 过 getGlow 曲线 clamp(scale(1-s, 1, 0.5, 0, 1.3), 0, 1)
	 * 的线性段 = (1-s)*2.6（位置项 hidden/sudden/blink 未移植，只取常值部分）。
	 * attack/voting 外侧轨 stealth=0.5 → 1.0（全白）。
	 */
	public function laneStealthGlow(lane:Int):Float
	{
		var s:Float = getValue('stealth', lane);
		if (Math.isNaN(s)) s = 0;
		if (s <= 0) return 0;
		final g:Float = (1 - s) * 2.6;
		return Math.max(0, Math.min(g, 1));
	}

	public function registerMod(mod:Dynamic, ?subMod:Dynamic = null, ?save:Bool = true):Dynamic
	{
		final name:String = (mod != null && Reflect.hasField(mod, 'name')) ? Reflect.field(mod, 'name') : Std.string(Type.typeof(mod));
		warnOnce('registerMod', name);
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
