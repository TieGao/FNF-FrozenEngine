package nmv.scripts;

import flixel.util.FlxDestroyUtil;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import sys.FileSystem;

/**
 * 脚本容器：宿主 State 以**组合**方式持有，随宿主 update / 事件 / destroy 转发。
 *
 * 约定目录（相对内容包根）：
 * - 状态脚本：scripts/states/<StateName>.hx（走 Paths.getPath，命中 contentRoot 回退）
 * - 歌内脚本：谱面目录下全部 .hx（content/VanillaSongs/<包>/songs/<歌>/ 与
 *   content/CustomCharts/<分类>/<歌>/ 同一路径都由 setChartContext 写进 currentChartDirectory）
 */
class NMVSciptHolder implements IFlxDestroyable
{
	public var group:ScriptGroup;
	public var parent(default, null):Dynamic;

	public function new(parent:Dynamic)
	{
		this.parent = parent;
		group = new ScriptGroup(parent);
		group.holder = this;
	}

	/** 宿主 State 的 add/remove/insert 与相机句柄注入脚本（NMV Stage 的同名约定）。 */
	function injectHostVars(script:FunkinScript):Void
	{
		if (parent == null) return;

		for (name in ['add', 'remove', 'insert'])
		{
			final field:String = name;
			script.set(field, function(obj:Dynamic) return Reflect.callMethod(parent, Reflect.field(parent, field), [obj]));
		}

		// PlayState 的三个相机句柄；宿主没有该字段时 Reflect.field 返回 null，不污染
		for (name in ['camGame', 'camHUD', 'camOther'])
		{
			var cam:Dynamic = Reflect.field(parent, name);
			if (cam != null) script.set(name, cam);
		}
	}

	/** 加载单个脚本文件；成功返回 script，解析失败返回 null（已记日志）。 */
	public function load(file:String, ?name:String, modFolder:String = null):FunkinScript
	{
		if (!FunkinScript.isHxFile(file) || !FileSystem.exists(file)) return null;

		if (name == null || name.length == 0)
		{
			final base = file.substring(file.lastIndexOf('/') + 1);
			name = base.substring(0, base.lastIndexOf('.'));
		}

		var script:FunkinScript = FunkinScript.fromFile(file, name, true, group.scriptShareables, modFolder);
		if (script.parsingFailed())
		{
			FlxDestroyUtil.destroy(script);
			return null;
		}

		injectHostVars(script);

		if (!group.addScript(script))
		{
			FlxDestroyUtil.destroy(script);
			return null;
		}

		// 与 NMV Stage/ScriptedState 同一时机：加载完立即回调 onLoad
		script.call('onLoad');
		return script;
	}

	/**
	 * 加载 scripts/states/<stateName>.hx；返回是否有脚本加载成功。
	 *
	 * 两套内容包布局都试：
	 * - FE 布局：<contentRoot>/shared/scripts/states/<名>.hx（Paths.getPath 的 shared 回退）
	 * - NMV 样本布局：<contentRoot>/scripts/states/<名>.hx（内容包根下直接放 scripts/）
	 */
	public function loadStateScript(stateName:String, modFolder:String = null):Bool
	{
		final base = 'scripts/states/$stateName';

		if (load(FunkinScript.getPath(base), stateName, modFolder) != null) return true;

		final root = backend.Paths.currentContentRoot;
		if (root == null || root.length == 0) return false;

		return load(FunkinScript.getPath('$root/$base'), stateName, modFolder) != null;
	}

	/** 加载目录下全部 .hx（样板 songs/<歌>/）。 */
	public function loadDir(dir:String, modFolder:String = null):Void
	{
		if (dir == null || dir.length == 0 || !FileSystem.exists(dir)) return;

		for (file in FileSystem.readDirectory(dir))
		{
			if (!FunkinScript.isHxFile(file)) continue;
			load('$dir/$file', null, modFolder);
		}
	}

	public function call(event:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>):Dynamic
	{
		return group.call(event, args, ignoreStops, exclusions);
	}

	public function set(varName:String, arg:Dynamic)
	{
		group.set(varName, arg);
	}

	public function exists(event:String):Bool
	{
		for (script in group.members)
			if (script.exists(event)) return true;
		return false;
	}

	public function destroy()
	{
		group = FlxDestroyUtil.destroy(group);
	}
}
