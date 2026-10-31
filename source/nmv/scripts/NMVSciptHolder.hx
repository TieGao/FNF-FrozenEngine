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

		sharePublicVars(script, file);

		// 与 NMV Stage/ScriptedState 同一时机：加载完立即回调 onLoad。
		// 大量 NMV 全局脚本（camTweenEvent/cheatMenu/dialogue 等）没有 onLoad——
		// iris 对缺失函数 call 会报 "Tried to call a non-function"，必须先判存在。
		if (script.exists('onLoad'))
			script.call('onLoad');
		return script;
	}

	/**
	 * NMV 的 `public var` 是跨脚本共享的，而 hscript 的 Parser 把 public 当修饰符丢掉
	 * （顶层 var 只进脚本自己的 locals）。这里按源码里的 public var 名单把值同步进
	 * Sharables —— 否则 videoCheckStory 这类开关在别的脚本里读到 null，
	 * `if (videoCheckStory && !isStoryMode)` 整段判断失效，过场就会在 Freeplay 里误触发。
	 *
	 * 顶层函数同理共享（NMV LOOSE 语义 = 全部脚本一个作用域）：dialogue.hx 的
	 * videoCutscene、refreshZ 等被 mando/oversight/danger/49 的 onLoad 直接调用，
	 * 不共享则 "Null Function Pointer"（2026-10-30 bread.log 实证）。
	 * iris 的 exists() 只查脚本自身 variables，共享回调函数不会干扰 group.call 的逐脚本派发。
	 */
	function sharePublicVars(script:FunkinScript, file:String):Void
	{
		var src:String = null;
		try src = sys.io.File.getContent(file) catch (e:Dynamic) {}
		if (src == null) return;

		for (line in src.split('\n'))
		{
			final t:String = StringTools.trim(line);
			final isPublicVar:Bool = StringTools.startsWith(t, 'public var ');
			final isTopFunc:Bool = (StringTools.startsWith(t, 'function ') || StringTools.startsWith(t, 'public function '));
			if (!isPublicVar && !isTopFunc) continue;

			var id:String;
			if (isPublicVar)
			{
				final rest:String = t.substr('public var '.length);
				id = StringTools.trim(rest.split(':')[0].split('=')[0]);
			}
			else
			{
				// 函数名 = 'function'/'public function' 之后到 '(' 之前的标识符
				final kw:String = t.startsWith('public ') ? 'public function' : 'function';
				final rest:String = t.substr(kw.length);
				id = StringTools.trim(rest.split('(')[0]);
			}
			if (id.length == 0) continue;

			// 顶层变量在 execute 结束时被 restore 清出 locals，只能走 Iris 的变量查找
			try
			{
				final v:Dynamic = script.get(id);
				if (v != null) group.scriptShareables.set(id, v);
			}
			catch (e:Dynamic) {}
		}
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

	/**
	 * 加载 NMV 角色脚本 data/characters/<name>.hx 并注入 parent（NMV
	 * PlayState.startCharacterScript 的对应物）：先设 parent 再 onLoad，
	 * 与 holder.load 的"载完立即 onLoad"不同，不能走 load()。
	 */
	public function loadCharacterScript(characterName:String, char:Dynamic, modFolder:String = null):Bool
	{
		if (characterName == null || characterName.length == 0) return false;
		final root = backend.Paths.currentContentRoot;
		if (root == null || root.length == 0) return false;

		final path = FunkinScript.getPath('$root/data/characters/$characterName');
		if (!FileSystem.exists(path)) return false;

		final script = FunkinScript.fromFile(path, path, true, group.scriptShareables, modFolder);
		if (script.parsingFailed())
		{
			FlxDestroyUtil.destroy(script);
			return false;
		}

		injectHostVars(script);
		script.set('parent', char);

		if (!group.addScript(script))
		{
			FlxDestroyUtil.destroy(script);
			return false;
		}

		if (script.exists('onLoad')) script.call('onLoad');
		return true;
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
		// 垫片是共享单例，换歌时清会话内存（finaleUI 换的终局血条引用不能带进下一首）
		nmv.objects.PlayHUDShim.instance.resetSession();
		nmv.objects.PetStub.instance.resetSession();
		group = FlxDestroyUtil.destroy(group);
	}
}
