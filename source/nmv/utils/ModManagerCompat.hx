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
