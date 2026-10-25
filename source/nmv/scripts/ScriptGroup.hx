package nmv.scripts;

import nmv.scripting.ScriptConstants;

import flixel.util.FlxDestroyUtil;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;

/**
 * `FunkinScript` 实例容器：统管脚本的加载、事件广播与销毁。
 */
@:nullSafety(Strict)
class ScriptGroup implements IFlxDestroyable
{
	public var scriptShareables:Sharables = new Sharables();

	/** 应用到组内所有脚本的 interp parent。 */
	public var parent(default, set):Dynamic;

	function set_parent(value:Dynamic)
	{
		if (value != null && value == parent)
		{
			return parent;
		}

		parent = value;
		@:privateAccess
		for (script in members)
		{
			copyGroup(script);
		}

		return parent;
	}

	/** 组内全部 `FunkinScript` 实例。 */
	public var members:Array<FunkinScript> = [];

	/** 承载本组的容器（NMVSciptHolder），供脚本内 initScript 再加载用。 */
	public var holder:Dynamic = null;

	public function new(?parent:Dynamic)
	{
		@:privateAccess
		if (FlxG.game != null)
		{
			parent ??= FlxG.state;
		}

		@:bypassAccessor this.parent = parent;
	}

	/** 向组内添加一个脚本；重名默认拒绝。 */
	public function addScript(script:Null<FunkinScript>, allowDupeNames:Bool = false):Bool
	{
		if (script == null || (!allowDupeNames && exists(script.name))) return false;

		copyGroup(script);
		script.scriptGroup = this;
		members.push(script);
		return true;
	}

	/** 从组内移除一个脚本。 */
	public function removeScript(script:FunkinScript):Bool
	{
		return members.remove(script);
	}

	/** 把组的 parent 与 scriptShareables 复制给脚本。 */
	function copyGroup(script:FunkinScript)
	{
		@:privateAccess
		final interp:InterpEx = cast script.interp;
		if (interp.parent != parent) interp.parent = parent;
		interp.sharedFields = scriptShareables;
	}

	/** 给组内所有脚本设置同名变量。 */
	public function set(varName:String, arg:Dynamic)
	{
		for (i in members)
		{
			i.set(varName, arg);
		}
	}

	/** 向组内所有脚本广播事件；返回 HALT_FUNC 时中断，返回最后的非 CONTINUE 值。 */
	public function call(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>):Dynamic
	{
		exclusions ??= [];
		var returnVal:Dynamic = ScriptConstants.CONTINUE_FUNC;
		for (i in members)
		{
			if (i == null || !i.exists(event) || exclusions.contains(i.name))
			{
				continue;
			}

			var ret:Dynamic = i.call(event, args)?.returnValue;
			if (ret is Int)
			{
				if (ret == ScriptConstants.HALT_FUNC)
				{
					ret = returnVal;
					if (!ignoreStops) return returnVal;
				};

				if (ret != ScriptConstants.CONTINUE_FUNC) returnVal = ret;
			}
		}

		return returnVal;
	}

	/** 按名取脚本，找不到返回 null。 */
	public function getScript(name:String):Null<FunkinScript>
	{
		for (script in members)
			if (script.name == name) return script;

		return null;
	}

	/** 是否存在指定名字的脚本。 */
	public function exists(name:String):Bool
	{
		for (script in members)
			if (script.name == name) return true;
		return false;
	}

	/** 销毁全部成员。 */
	public function destroy()
	{
		scriptShareables.clear();
		@:nullSafety(Off)
		scriptShareables = null;
		members = FlxDestroyUtil.destroyArray(members);
		@:bypassAccessor parent = null;
	}

	/** 清空组（可先广播 onDestroy）。 */
	public function clear(callOnDestroy:Bool = true)
	{
		if (callOnDestroy) call('onDestroy', null, true);
		for (i in 0...members.length)
		{
			var script = members[0];
			members.remove(script);
			script.destroy();
		}
	}
}
