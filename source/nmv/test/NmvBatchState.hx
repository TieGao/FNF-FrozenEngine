package nmv.test;

#if NMV_BATCH
import flixel.FlxG;
import flixel.FlxState;
import sys.FileSystem;
import sys.io.File;

import nmv.scripts.FunkinScript;
import nmv.scripts.InterpEx;
import nmv.scripts.Sharables;

/**
 * Phase 5 回归集批量加载器（docs/nmv-port-plan/50）。
 *
 * 启动：`FrozenEngine.exe -nmvbatch [root] [-o report.md]`（构建需 `-D NMV_BATCH`）。
 * 从 exe 工作目录扫 root（默认 content/NMVMODS）下每个包，镜像 NMV PlayState
 * 的宿主时序：先载全部包的 scripts/ 下全局脚本（NMV LOOSE 语义 = 启用包并集，
 * 共享一份 Sharables），再逐包 stages → data/characters → songs/<歌> → 状态脚本；
 * 每个脚本 parse + 顶层执行后注入上下文变量（songName 等，取 NMV preset 的
 * PlayState 段为参照），然后直接 Reflect 调用 onLoad 与常见回调 —— 不走 Iris.call，
 * 它会把函数体内的异常 catch 成日志，统计就看不见了（首轮实测教训）。
 *
 * 报告默认写到 exe 工作目录 nmv-batch-report.md。
 */
@:access(crowplexus.iris.Iris)
class NmvBatchState extends FlxState
{
	static inline var FLAG:String = '-nmvbatch';

	/** 除 onLoad 外顺带调用的常见回调（安全参数，能大幅扩展函数体覆盖率）。 */
	static final CB_CALLS:Array<{fn:String, args:Array<Dynamic>}> = [
		{fn: 'onUpdate', args: [0.016]},
		{fn: 'onUpdatePost', args: [0.016]},
		{fn: 'onBeatHit', args: []},
		{fn: 'onStepHit', args: []},
		{fn: 'onSongStart', args: []},
		{fn: 'onCountdownTick', args: [0]},
		{fn: 'onMoveCamera', args: ['dad']},
		{fn: 'onEndSong', args: []},
	];

	// 脚本引用的相机句柄（宿主字段，parentFields 命中用）
	public var camGame:flixel.FlxCamera;
	public var camHUD:flixel.FlxCamera;
	public var camOther:flixel.FlxCamera;

	// PlayState 常见宿主面（真实游戏由 PlayState 提供；空组即可让脚本的 add 走通）
	public var dadGroup:flixel.group.FlxSpriteGroup;
	public var boyfriendGroup:flixel.group.FlxSpriteGroup;
	public var gfGroup:flixel.group.FlxSpriteGroup;
	public var defaultCamZoom:Float = 1.05;
	public var health:Float = 1;

	var shared:Sharables;
	var spawned:Array<Dynamic> = [];
	var currentPkg:String = '';
	var keepAlive:Array<FunkinScript> = [];

	// 统计：loadOk = load + onLoad 全通过
	var loadOk:Int = 0;
	var loadFails:Array<Row> = [];
	var onLoadFails:Array<Row> = [];
	var cbFails:Array<Row> = [];
	var misses:Map<String, {count:Int, files:Map<String, Bool>}> = [];

	override public function create():Void
	{
		super.create();

		final args = Sys.args();
		final flagIdx = args.indexOf(FLAG);

		var root = 'content/NMVMODS';
		var report = 'nmv-batch-report.md';
		if (flagIdx >= 0 && flagIdx + 1 < args.length && !args[flagIdx + 1].startsWith('-')) root = args[flagIdx + 1];
		final oIdx = args.indexOf('-o');
		if (oIdx >= 0 && oIdx + 1 < args.length) report = args[oIdx + 1];

		// 相机句柄：真实宿主在 create 里建 camHUD/camOther，这里同样让脚本解析得到
		camGame = FlxG.camera;
		camHUD = new flixel.FlxCamera();
		camHUD.bgColor = 0x0;
		camOther = new flixel.FlxCamera();
		camOther.bgColor = 0x0;

		dadGroup = new flixel.group.FlxSpriteGroup();
		boyfriendGroup = new flixel.group.FlxSpriteGroup();
		gfGroup = new flixel.group.FlxSpriteGroup();

		final pkgs:Array<String> = [];
		if (FileSystem.exists(root) && FileSystem.isDirectory(root))
		{
			for (d in FileSystem.readDirectory(root))
				if (FileSystem.isDirectory('$root/$d')) pkgs.push(d);
		}
		pkgs.sort((a, b) -> Reflect.compare(a, b));

		// NMV LOOSE 语义：全局脚本是启用包并集、共享 Sharables（当前包在真实接线里优先）
		shared = new Sharables();
		for (pkg in pkgs)
			runPackageGlobals(root, pkg);

		for (pkg in pkgs)
			runPackageContent(root, pkg);

		final total = loadOk + loadFails.length + onLoadFails.length;
		Sys.println('NMV BATCH DONE: $total files, load+onLoad ok=$loadOk, load fail=${loadFails.length}, onLoad fail=${onLoadFails.length}, cb fail=${cbFails.length}');

		File.saveContent(report, buildReport(root));
		Sys.println('NMV BATCH REPORT: ${FileSystem.absolutePath(report)}');

		// 回调阶段留下的 tween/timer 引用已销毁的对象，不清会在退出延迟里炸（VarTween 等）
		flixel.tweens.FlxTween.globalManager.clear();
		flixel.util.FlxTimer.globalManager.clear();

		// 让窗口画一帧再退出，避免 lime 在极端时序下退出崩溃
		haxe.Timer.delay(function() lime.system.System.exit(0), 500);
	}

	function setContentRoot(pkg:String):Void
	{
		currentPkg = pkg;
		// 与真实接线一致：exe 相对路径、含 /NMVMODS/（isNmvContentRoot 判据）
		backend.Paths.currentContentRoot = 'content/NMVMODS/$pkg';
		backend.Paths.currentChartDirectory = null;
	}

	function runPackageGlobals(root:String, pkg:String):Void
	{
		setContentRoot(pkg);
		// NMV PlayState 的全局加载是扁平一层（listAllFilesInDirectory 不递归）：
		// scripts/*.hx；storyNodes/states/substates 子目录不在此加载
		final globals = listHxFlat('$root/$pkg/scripts');
		globals.sort((a, b) -> Reflect.compare(a, b));
		for (f in globals)
			runOne(f, 'global');
		clearSpawned();
	}

	function runPackageContent(root:String, pkg:String):Void
	{
		setContentRoot(pkg);
		spawned = [];

		final stageDir = '$root/$pkg/stages';
		if (FileSystem.exists(stageDir))
		{
			final files = listHxFlat(stageDir);
			files.sort((a, b) -> Reflect.compare(a, b));
			for (f in files)
				runOne(f, 'stage');
		}

		final charDir = '$root/$pkg/data/characters';
		if (FileSystem.exists(charDir))
		{
			final files = listHxFlat(charDir);
			files.sort((a, b) -> Reflect.compare(a, b));
			for (f in files)
				runOne(f, 'character');
		}

		final songsDir = '$root/$pkg/songs';
		if (FileSystem.exists(songsDir))
		{
			for (song in FileSystem.readDirectory(songsDir))
			{
				final songPath = '$songsDir/$song';
				if (!FileSystem.isDirectory(songPath)) continue;
				final files = listHxFlat(songPath);
				files.sort((a, b) -> Reflect.compare(a, b));
				for (f in files)
					runOne(f, 'song');
			}
		}

		// 状态脚本最后（真实宿主按 state 打开时序载，这里只取 load 统计）
		for (sub in ['scripts/states', 'scripts/substates'])
		{
			final files = listHxFlat('$root/$pkg/$sub');
			files.sort((a, b) -> Reflect.compare(a, b));
			for (f in files)
				runOne(f, 'state');
		}

		clearSpawned();
	}

	function runOne(file:String, cat:String):Void
	{
		var script:FunkinScript = null;
		try
		{
			script = FunkinScript.fromFile(file, file, true, shared, currentPkg);
			keepAlive.push(script); // 防 GC：回调阶段还要用到它的闭包
		}
		catch (e:Dynamic)
		{
			record('load', cat, file, 'constructor throw: $e');
			return;
		}

		if (script.parsingFailed())
		{
			record('load', cat, file, Std.string(script.parsingException));
			script.destroy();
			return;
		}

		// 宿主句柄：parent 指向本 State（add/remove/insert 走收集器，相机走宿主字段）
		final interp:InterpEx = cast script.interp;
		interp.parent = this;

		script.set('add', makeHostFn('add'));
		script.set('remove', makeHostFn('remove'));
		script.set('insert', makeHostFn('insert'));
		// preset 在构造期取 FlxG.state，首个 state 切换时序下可能还是旧值，这里统一指向本 State
		script.set('game', this);
		script.set('state', this);

		// 歌上下文（NMV preset PlayState 段的合理值；songName 从目录取）
		final songDir = extractSongDir(file);
		script.set('songName', songDir != null ? songDir : 'Test Song');
		script.set('isStoryMode', true);
		script.set('difficulty', 0);
		script.set('difficultyName', 'normal');
		script.set('bpm', 102.0);
		script.set('scrollSpeed', 2.4);
		script.set('songLength', 120000.0);
		script.set('weekRaw', 0);
		script.set('seenCutscene', false);
		script.set('mustHitSection', true);
		// 角色脚本：NMV 宿主在 onLoad 前设 parent = 角色对象；这里用 FlxSprite 桩
		// （PetStub 即 FlxSprite + curPet/loadPet），脚本碰 parent.y/alpha 等不炸
		if (cat == 'character') script.set('parent', new nmv.objects.PetStub());

		// 直接 Reflect 调用：Iris.call 会把函数体内异常 catch 成日志，统计看不见
		if (script.exists('onLoad'))
		{
			final fn:Dynamic = script.get('onLoad');
			try
			{
				Reflect.callMethod(null, fn, []);
			}
			catch (e:Dynamic)
			{
				record('onLoad', cat, file, posTag(script) + Std.string(e));
				clearSpawned();
				return;
			}
		}

		loadOk++;

		for (cb in CB_CALLS)
		{
			if (!script.exists(cb.fn)) continue;
			final fn:Dynamic = script.get(cb.fn);
			try
			{
				Reflect.callMethod(null, fn, cb.args);
			}
			catch (e:Dynamic)
			{
				record('cb:' + cb.fn, cat, file, posTag(script) + Std.string(e));
			}
		}

		clearSpawned();
	}

	/** 取解释器最近执行位置的 file:line 与异常栈首几帧（NPE 这类裸异常没有位置信息，补上）。 */
	function posTag(script:FunkinScript):String
	{
		try
		{
			final pos:haxe.PosInfos = (cast script.interp : InterpEx).posInfos();
			final line = pos != null && pos.lineNumber > 0 ? '${pos.fileName}:${pos.lineNumber}: ' : '';
			// 裸 cpp 异常（Null Object Reference 等）没有脚本侧信息，用 Haxe 栈定位来源
			// （例：栈顶在 nmv.objects.AmongWalker.* = 构造函数内部抛的，不是脚本行）
			final frames = haxe.CallStack.exceptionStack();
			final stack = frames.length > 0
				? ' [stack: ' + frames.slice(0, 4).map(f -> switch (f)
				{
					case Method(cn, mn): cn.split('.').pop() + '.' + mn;
					default: null;
				}).filter(f -> f != null).join(' < ') + ']'
				: '';
			return line + stack;
		}
		catch (e:Dynamic) {}
		return '';
	}

	function makeHostFn(kind:String):Dynamic
	{
		return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
			final first:Dynamic = args.length > 0 ? args[0] : null;
			switch (kind)
			{
				case 'add':
					if (first != null) spawned.push(first);
					return first;
				case 'remove':
					if (first != null) spawned.remove(first);
					return first;
				case 'insert':
					final obj:Dynamic = args.length > 1 ? args[1] : first;
					if (obj != null) spawned.push(obj);
					return null;
			}
			return null;
		});
	}

	/** 清掉脚本 add 进来的对象与其无引用纹理，防逐文件堆积。 */
	function clearSpawned():Void
	{
		for (obj in spawned)
		{
			if (obj != null && Reflect.hasField(obj, 'destroy')) Reflect.callMethod(obj, Reflect.field(obj, 'destroy'), []);
		}
		spawned.resize(0);
		try
		{
			FlxG.bitmap.clearUnused();
		}
		catch (e:Dynamic) {}
	}

	// ---------- 扫描与统计 ----------

	function collectHx(dir:String, out:Array<String>):Void
	{
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return;
		for (f in FileSystem.readDirectory(dir))
		{
			final p = '$dir/$f';
			if (FileSystem.isDirectory(p)) collectHx(p, out);
			else if (f.endsWith('.hx')) out.push(p);
		}
	}

	function listHxFlat(dir:String):Array<String>
	{
		final out:Array<String> = [];
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return out;
		for (f in FileSystem.readDirectory(dir))
		{
			final p = '$dir/$f';
			if (!FileSystem.isDirectory(p) && f.endsWith('.hx')) out.push(p);
		}
		return out;
	}

	function extractSongDir(file:String):Null<String>
	{
		final idx = file.indexOf('/songs/');
		if (idx == -1) return null;
		final rest = file.substring(idx + '/songs/'.length);
		final slash = rest.indexOf('/');
		return slash == -1 ? null : rest.substring(0, slash);
	}

	function record(phase:String, cat:String, file:String, msg:String):Void
	{
		final row:Row = {pkg: currentPkg, file: file, cat: cat, phase: phase, msg: msg};
		if (phase == 'load') loadFails.push(row);
		else if (phase == 'onLoad') onLoadFails.push(row);
		else cbFails.push(row);

		// Unknown variable 直方图：API 缺口的主数据
		final re = ~/Unknown variable: ([A-Za-z_0-9]+)/;
		if (re.match(msg))
		{
			final id = re.matched(1);
			if (!misses.exists(id)) misses[id] = {count: 0, files: new Map()};
			misses[id].count++;
			misses[id].files[file] = true;
		}

		Sys.println('[$currentPkg $cat/$phase] $file :: ${oneLine(msg, 140)}');
	}

	function oneLine(s:String, max:Int):String
	{
		var out = StringTools.replace(StringTools.replace(s, '\n', ' '), '\r', '');
		while (out.indexOf('  ') != -1)
			out = StringTools.replace(out, '  ', ' ');
		return out.length > max ? out.substring(0, max) + '...' : out;
	}

	function buildReport(root:String):String
	{
		final buf = new StringBuf();
		final total = loadOk + loadFails.length + onLoadFails.length;
		final loadPassed = loadOk + onLoadFails.length;

		buf.add('# NMV 批量回归报告\n\n');
		buf.add('- 根目录：`$root`\n');
		buf.add('- 时间：${Date.now().toString()}\n');
		buf.add('- 口径：parse + 顶层执行（load）+ onLoad + 常见回调；全局脚本按 NMV LOOSE 语义先载（启用包并集、共享 Sharables）；\n');
		buf.add('- 函数体经 Reflect 直调（不走 Iris.call，异常可见）\n\n');

		buf.add('## 汇总\n\n');
		buf.add('| 指标 | 值 |\n|---|---|\n');
		buf.add('| 文件总数 | $total |\n');
		buf.add('| load 通过（parse+顶层执行） | $loadPassed |\n');
		buf.add('| load 失败 | ${loadFails.length} |\n');
		buf.add('| onLoad 失败 | ${onLoadFails.length} |\n');
		buf.add('| 回调失败（onUpdate/Beat/Step 等） | ${cbFails.length} |\n');
		buf.add('| load+onLoad 全通过 | $loadOk |\n');
		if (total > 0)
		{
			buf.add('| 可加载率（验收口径，全通过/总数） | ${Math.round(loadOk / total * 1000) / 10}% |\n');
			buf.add('| load 通过率 | ${Math.round(loadPassed / total * 1000) / 10}% |\n');
		}
		buf.add('\n');

		function rows(name:String, list:Array<Row>):Void
		{
			buf.add('## $name（${list.length}）\n\n');
			if (list.length == 0)
			{
				buf.add('（无）\n\n');
				return;
			}
			buf.add('| 文件 | 类别 | 阶段 | 错误 |\n|---|---|---|---|\n');
			for (r in list)
				buf.add('| ${r.file} | ${r.cat} | ${r.phase} | ${oneLine(r.msg, 300)} |\n');
			buf.add('\n');
		}
		rows('load 失败明细', loadFails);
		rows('onLoad 失败明细', onLoadFails);
		rows('回调失败明细', cbFails);

		buf.add('## Unknown variable 直方图\n\n');
		if (Lambda.count(misses) == 0) buf.add('（无）\n');
		else
		{
			buf.add('| 标识符 | 次数 | 文件数 |\n|---|---|---|\n');
			final ids = [for (id in misses.keys()) id];
			ids.sort((a, b) -> misses[b].count - misses[a].count);
			for (id in ids)
				buf.add('| $id | ${misses[id].count} | ${Lambda.count(misses[id].files)} |\n');
		}
		buf.add('\n');

		return buf.toString();
	}
}

typedef Row =
{
	var pkg:String;
	var file:String;
	var cat:String;
	var phase:String;
	var msg:String;
}
#end
