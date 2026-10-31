package nmv.scripts;

import haxe.Constraints.IMap;
import haxe.PosInfos;

import Type.ValueType;

import crowplexus.iris.Iris;
import crowplexus.hscript.*;
import crowplexus.hscript.Expr;
import crowplexus.hscript.Tools;
import flixel.graphics.frames.FlxFrame;

import nmv.objects.FunkinSprite;

/**
 * Modified Iris Interp for variety of improvements.
 * 
 * crash fix on for loops in debug
 * 
 * improved error reporting on null functions
 * 
 * parent field to directly access an object
 * 
 * public fields support with `Sharables`
 */
class InterpEx extends crowplexus.hscript.Interp #if flixel implements flixel.util.FlxDestroyUtil.IFlxDestroyable #end
{
	static var cachedFields:Map<String, Array<String>> = [];
	
	public var sharedFields:Null<Sharables> = null;
	
	public function new(?parent:Dynamic, ?shareables:Sharables)
	{
		super();
		if (parent != null) this.parent = parent;
		this.sharedFields = shareables;
		showPosOnLog = false;
	}
	
	public var parentFields:Array<String> = [];
	public var parent(default, set):Dynamic;
	
	function set_parent(value:Dynamic)
	{
		parent = value;
		if (value != null)
		{
			var clName = Type.getClassName(Type.getClass(value));
			if (!cachedFields.exists(clName))
			{
				cachedFields.set(clName, Type.getInstanceFields(Type.getClass(value)));
			}
			
			parentFields = cachedFields.get(clName) ?? [];
		}
		else
		{
			parentFields = [];
		}
		
		return parent;
	}
	
	override function increment(e:Expr, prefix:Bool, delta:Int):Dynamic
	{
		#if hscriptPos
		curExpr = e;
		#end
		
		switch (e.e)
		{
			case EIdent(id):
				final v:Dynamic = resolve(id);
				
				if (prefix) return setTo(id, v + delta);
				
				setTo(id, v + delta);
				
				return v;
				
			default:
				return super.increment(e, prefix, delta);
		}
	}
	
	function setTo(id:String, v:Dynamic, canDefine:Bool = false):Dynamic
	{
		if (locals.exists(id))
		{
			var l = locals.get(id);
			
			if (l.const != true) l.r = v;
			else warn(ECustom('Cannot reassign final, for constant expression -> $id'));
		}
		else
		{
			if (variables.exists(id))
			{
				setVar(id, v);
				return v;
			}
			
			if (parentFields.contains(id) || parentFields.contains('set_$id'))
			{
				Reflect.setProperty(parent, id, v);
				return v;
			}
			
			if (sharedFields != null && sharedFields.exists(id)) sharedFields.set(id, v);
		}
		
		if (canDefine) setVar(id, v);
		return v;
	}
	
	override function resolve(id:String):Dynamic
	{
		if (locals.exists(id)) return locals.get(id).r;

		if (variables.exists(id)) return variables.get(id);

		if (imports.exists(id)) return imports.get(id);

		// NMV LOOSE 共享域在读路径上必须先于宿主字段：全局脚本的顶层函数/公共变量与
		// PlayState 同名字段撞名时（dialogue.hx 的 videoCutscene() 函数 vs 宿主的
		// PlayState.videoCutscene:VideoSprite 字段），脚本语义永远指向共享域。
		// 旧顺序下 song 脚本解析到宿主的 null 字段，调用即 "Null Function Pointer"
		// （2026-10-31 bread.log 实证：meltdown:6 / danger script:3 每次进歌必炸）。
		// 写路径（setTo）保持宿主字段优先，songStartCallback 等桥接语义依赖它。
		if (sharedFields?.exists(id)) return sharedFields.get(id);

		if (parentFields.contains(id) || parentFields.contains('get_$id')) return Reflect.getProperty(parent, id);

		// 最后一道兜底：报错前查 proxyImports。iris 各处（cnew/表达式求值）都可能拿着
		// 整条 FQ 路径调 resolve，这层接住 `new funkin.xxx.Yyy()` 和 FQ 静态引用。
		if (Iris.proxyImports.exists(id)) return Iris.proxyImports.get(id);

		error(EUnknownVariable(id));

		return null;
	}
	
	override function evalAssignOp(op, fop, e1, e2):Dynamic
	{
		var v;
		switch (Tools.expr(e1))
		{
			case EIdent(id):
				return setTo(id, fop(expr(e1), expr(e2)));
			case EField(e, f, s):
				var obj = expr(e);
				if (obj == null) if (!s) error(EInvalidAccess(f));
				else return null;
				v = fop(get(obj, f), expr(e2));
				v = set(obj, f, v);
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr))
				{
					v = fop(getMapValue(arr, index), expr(e2));
					setMapValue(arr, index, v);
				}
				else
				{
					v = fop(arr[index], expr(e2));
					arr[index] = v;
				}
			default:
				return error(EInvalidOp(op));
		}
		return v;
	}
	
	override function assign(e1:Expr, e2:Expr):Dynamic
	{
		var v = expr(e2);
		switch (Tools.expr(e1))
		{
			case EIdent(id):
				return setTo(id, v, true);
			case EField(e, f, s):
				var e = expr(e);
				if (e == null) if (!s) error(EInvalidAccess(f));
				else return null;
				v = set(e, f, v);
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr))
				{
					setMapValue(arr, index, v);
				}
				else
				{
					arr[index] = v;
				}
				
			default:
				error(EInvalidOp("="));
		}
		return v;
	}
	
	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic
	{
		// hscript 不认 Haxe 4 的 contains 扩展方法，NMV 脚本对 String/Array 大量拿它
		// 做成员判断（bf-running.hx 每帧调，报错会中断 onUpdate 后续行）
		if (f == 'contains')
		{
			if (Std.isOfType(o, String))
				return args.length > 0 && StringTools.contains(cast o, Std.string(args[0]));
			if (Std.isOfType(o, Array))
				return args.length > 0 && (cast o : Array<Dynamic>).indexOf(args[0]) != -1;
		}

		// FlxObject/FlxSprite 没有 .set(x, y)（那是 FlxPoint 的方法）；NMV 全局脚本
		// camTweenEvent.hx 的瞬时分支用 game.camFollow.set(x, y) 直设镜头焦点，
		// 同语义映射到 setPosition（FlxPoint 等自带 set 的类型不走这里）。
		if (f == 'set' && args.length == 2 && Std.isOfType(o, flixel.FlxObject))
		{
			cast(o, flixel.FlxObject).setPosition(args[0], args[1]);
			return null;
		}

		// NMV 的 getPath 是 (file, ?parentFolder, mode)，FE 是 (file, ?type, ?parentFolder, ?modsAllowed)。
		// 第二个参数为 null 或 String 时按 NMV 签名重排，否则原样交给 FE。
		if (f == 'getPath' && o == backend.Paths && args.length >= 2 && (args[1] == null || Std.isOfType(args[1], String)))
			return backend.Paths.getPath(cast args[0], openfl.utils.AssetType.TEXT, cast args[1], true);

		// NMV 的链式 loadAtlas：flxanimate 库自带的 loadAtlas 是 Adobe Animate 布局、
		// 返回 Void，与 NMV 的 spritemap 布局 + 返回自身不符，对 FunkinSprite 特判
		if (f == 'loadAtlas' && Std.isOfType(o, FunkinSprite))
		{
			final spr:FunkinSprite = cast o;
			if (args.length > 0) spr.loadNmvAtlas(cast args[0]);
			return spr;
		}

		for (_using in usings)
		{
			var v = _using.call(o, f, args);
			if (v != null) return v;
		}
		
		final method = get(o, f);
		
		if (method == null)
		{
			Iris.error('Unknown function: $f', posInfos());
			return null; // return before call so we dont double error messages
		}
		
		return call(o, method, args);
	}
	
	#if (hl)
	override public function get(o:Dynamic, f:String):Dynamic
	{
		if (o is Enum)
		{
			return Type.createEnum(o, f);
		}

		return super.get(o, f);
	}
	#end

	#if (hxcpp && !hl)
	/**
	 * hxcpp 目标的 get() 覆写（hl 分支另有一份）。`f(x).contains(y)` 这类"调用结果上
	 * 取字段"走 get() 不走 fcall（bf-running.hx:26）；而 hxcpp 的 Reflect.field 对
	 * String/Array 的缺失字段会原生抛 "Invalid access to field contains"，必须赶在
	 * super 之前截下，返回可调用包装。
	 */
	override public function get(o:Dynamic, f:String):Dynamic
	{
		// zIndex 读旁表：写路径记 zIndexStore（19a40f87），但脚本读 boyfriendGroup.zIndex
		// 这类组级值（danger.hx:98 `bfPlatform.zIndex = boyfriendGroup.zIndex - 1`）不走
		// 旁表就得到 null → null-1=-1 → refreshZ 后被天空底图盖死（danger 车轮不可见的直接原因）
		if (f == 'zIndex' && o != null)
			return getZ(o);

		// NMV 的 FlxCamera.scrollAngle（相机旋转）：FE fork 的 FlxCamera 有 angle，
		// 映射过去让 camHUD 摇摆真实生效（ejected/danger/turbulence 的运镜）。
		if (f == 'scrollAngle' && Std.isOfType(o, flixel.FlxCamera))
			return o.angle;

		// NMV 的 game.playHUD（finaleUI.hx:26 读 healthLerp）：PlayState 实例上没有该
		// 字段，Reflect.field 得 null，下一级 null.healthLerp 报 "Invalid access to
		// field healthLerp"（2026-10-31 崩溃实证，finale 进去即炸）。返回共享垫片
		if (f == 'playHUD' && Std.isOfType(o, states.PlayState))
			return nmv.objects.PlayHUDShim.instance;

		// NMV fork 的 FlxFrame.angle 是 Float 角度（FE pin 是 FlxFrameAngle 枚举）——
		// beach.hx 的轮光 shader 用 frame.angle * Math.PI / 180 求弧度，枚举乘法会炸
		if (f == 'angle' && Std.isOfType(o, flixel.graphics.frames.FlxFrame))
		{
			final fa:Int = o.angle; // FlxFrameAngle 是 Int 枚举抽象
			return fa == 90 ? 90 : (fa == -90 ? -90 : 0);
		}

		if (f == 'contains')
		{
			if (Std.isOfType(o, String))
				return Reflect.makeVarArgs(function(a:Array<Dynamic>):Dynamic
				{
					return a.length > 0 && StringTools.contains(cast o, Std.string(a[0]));
				});
			if (Std.isOfType(o, Array))
				return Reflect.makeVarArgs(function(a:Array<Dynamic>):Dynamic
				{
					return a.length > 0 && (cast o : Array<Dynamic>).indexOf(a[0]) != -1;
				});
		}

		// NMV 的 atlas 角色动画面（danger/bf-running 的每帧腿部帧同步）：FE 对 atlas
		// 角色 animation.curAnim 恒 null（动画全走 atlas.anim.play，共享 flixel 不动），
		// 语料读 curAnim.numFrames/curFrame/looped 每帧炸 "Invalid access to field"
		// （2026-10-31 bread.log 实测各 ×573，onUpdate 整段中断）。借控制器私有 _sprite
		// （hxcpp Reflect 可达私有字段）反查宿主，宿主是带 atlas 的 Character 时返回薄
		// 适配（委托 atlas.anim 控制器）；Sparrow 路径 curAnim 正常，不进这里。
		if (f == 'curAnim' && Std.isOfType(o, flixel.animation.FlxAnimationController))
		{
			final curAnim:Dynamic = super.get(o, f);
			if (curAnim != null) return curAnim;

			final owner:Dynamic = Reflect.field(o, '_sprite');
			if (owner != null && Std.isOfType(owner, objects.Character))
			{
				final atlas:Dynamic = Reflect.field(owner, 'atlas');
				if (atlas != null && Reflect.field(atlas, 'anim') != null)
					return new nmv.objects.NmvAtlasCurAnimShim(Reflect.field(atlas, 'anim'));
			}
		}

		return super.get(o, f);
	}
	#end

	/**
	 * NMV 兼容：pin 的 flixel fork 的 FlxSprite 没有 zIndex 字段（用户否决为脚本动共享库），
	 * 而 NMV 脚本对原生 flixel 对象写 zIndex 是常规分层操作（dialogue.hx skipText 等）。
	 * hxcpp 的 Reflect.setProperty 对缺失字段抛 "Invalid field:zIndex"，并中断脚本函数
	 * 的后续行。这里对 zIndex 写入做定向吸收：带 zIndex 的移植类（NmvSprite 等）走
	 * super 正常写入，原生 flixel 对象静默忽略（无渲染语义，同 NmvSprite shim 先例）。
	 */
	/**
	 * zIndex 旁表：fork 的 FlxBasic/FlxSprite 没有 zIndex 字段，脚本对原生对象的
	 * zIndex 写入（maroon 雪=13、danger 的 gf/bf/dad 层级等）此前被静默吸收成 no-op，
	 * 层级完全失效（雪花被背景盖住的直接原因）。现在写入记进此表，
	 * PlayState.create 末尾的 NMV 同款 refreshZ(state) 按它排序。
	 * 带真 zIndex 字段的移植类（NmvSprite/PetStub/PlayFieldShim）仍走 super 正常写入。
	 */
	public static var zIndexStore:Map<{}, Float> = [];

	/** 读对象的有效 zIndex：真字段优先，旁表兜底，都没有 = 0。 */
	public static function getZ(obj:Dynamic):Float
	{
		if (obj == null) return 0;
		try
		{
			final v:Dynamic = Reflect.getProperty(obj, 'zIndex');
			if (v != null) return v;
		}
		catch (e:Dynamic) {}
		return zIndexStore.exists(obj) ? zIndexStore.get(obj) : 0;
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic
	{
		// FlxCamera.scrollAngle → angle（真实旋转，ejected/danger/turbulence 运镜在用）
		if (f == 'scrollAngle' && o is flixel.FlxCamera)
		{
			o.angle = v;
			return v;
		}

		if (f == 'zIndex' && o != null)
		{
			try
			{
				return super.set(o, f, v);
			}
			catch (e:Dynamic)
			{
				// 原生 flixel 对象没有 zIndex 字段：记旁表供 create 末尾排序消费
				zIndexStore.set(o, v);
				return v;
			}
		}
		return super.set(o, f, v);
	}

	override public function expr(e:Expr):Dynamic
	{
		#if hscriptPos
		curExpr = e;
		#end
		
		return switch (e.e)
		{
			case EMeta(meta, _, e):
				if (meta == ':sharable' && sharedFields != null)
				{
					switch (Tools.expr(e))
					{
						case EFunction(_, _, field) if (depth == 0):
							final r = expr(e);
							sharedFields.set(field, r);
							r;
							
						case EVar(field, _, e) if (depth == 0):
							final r = (e != null ? expr(e) : null);
							sharedFields.set(field, r);
							r;
							
						default:
							expr(e);
					}
				}
				else
				{
					expr(e);
				}
				
			case EFor(i, v, it, e):
				forLoop(i, v, it, e);
				return null;
				
			default:
				super.expr(e);
		}
	}
	
	override function makeIterator(v:Dynamic):Iterator<Dynamic>
	{
		if (v is Array) return (v : Array<Dynamic>).iterator();
		
		var iter:Dynamic = v.iterator;
		v = (iter != null ? #if hl Reflect.callMethod(v, iter, []) #else (iter : haxe.Constraints.Function)() #end : v);
		
		if (v.hasNext == null || v.next == null) error(EInvalidIterator(v));
		
		return v;
	}
	
	function makeKeyValueIterator(v:Dynamic):KeyValueIterator<Dynamic, Dynamic>
	{
		if ((v is haxe.ds.IntMap) || (v is haxe.ds.StringMap) || (v is haxe.ds.ObjectMap) || (v is haxe.ds.EnumValueMap))
		{
			return (v : haxe.Constraints.IMap<Dynamic, Dynamic>).keyValueIterator();
		}
		else if (v is Array)
		{
			return (v : Array<Dynamic>).keyValueIterator();
		}
		
		var iter:Dynamic = v.keyValueIterator;
		v = (iter != null ? #if hl Reflect.callMethod(v, iter, []) #else (iter : haxe.Constraints.Function)() #end : v);
		
		if (v.hasNext == null || v.next == null) error(EInvalidIterator(v));
		
		return v;
	}
	
	override function forLoop(n, v, it:Dynamic, e):Void
	{
		final old = declared.length;
		final ef = expr.bind(e);
		
		declared.push({n: n, old: locals.get(n)});
		
		if (v == null)
		{
			var it = makeIterator(expr(it));
			var next:Void->Dynamic = it.next, hasNext:Void->Bool = it.hasNext;
			
			while (hasNext())
			{
				locals.set(n, {r: next(), const: false});
				
				if (!loopRun(ef)) break;
			}
		}
		else // keyvalue
		{
			declared.push({n: v, old: locals.get(v)});
			
			var it = makeKeyValueIterator(expr(it));
			var next:Void->Dynamic = it.next, hasNext:Void->Bool = it.hasNext;
			
			while (hasNext())
			{
				var r:Dynamic = next();
				
				if (r.key == null) error(ECustom('$v has no field key'));
				if (r.value == null) error(ECustom('$v has no field value'));
				
				locals.set(n, {r: r.key, const: false});
				locals.set(v, {r: r.value, const: false});
				
				if (!loopRun(ef)) break;
			}
		}
		
		restore(old);
	}
	
	inline function loopRun(f:Void->Void)
	{
		var cont:Bool = true;
		
		try
		{
			f();
		}
		catch (err:Any)
		{
			switch (Type.typeof(err))
			{
				case ValueType.TEnum(_): // just cuase someone wouldnt make the enum PUBLIC DIE
					switch (Type.enumConstructor(err))
					{
						case 'SContinue':
						case 'SBreak': cont = false;
						default: throw err;
					}
					
				default:
					throw err;
			}
		}
		
		return cont;
	}
	
	/**
	 * hxcpp 的 Type.createInstance 对非类对象(典型:PresetStubs.missing 注册的
	 * 函数桩)静默返回 null——脚本里 `var x = new Stubbed(...)` 不报错、首次碰
	 * 字段才 "Invalid access to field xxx"，定位成本极高。这里显式抛回。
	 */
	/**
	 * 覆写：先直查 Iris.proxyImports 再走基类。基类同名方法在 hxcpp 目标上对
	 * "调用即抛"函数桩返回 null（探针实测：同一次调用里 exists(key)==true 而基类
	 * 读不到——根因未明，用直查绕开），FQ 名的 `new funkin.xxx.Yyy()` 全靠这张表。
	 */
	override function getOrImportClass(name:String):Dynamic
	{
		final v:Dynamic = Iris.proxyImports.get(name);
		if (v != null) return v;
		return super.getOrImportClass(name);
	}

	override function cnew(cl:String, args:Array<Dynamic>):Dynamic
	{
		// 解析顺序：真类 → proxyImports（FQ 名在 new 表达式里不经 import 语句）→
		// 脚本变量/函数桩；全空时 resolve 原样抛 EUnknownVariable（保留原报错路径）。
		var c = Type.resolveClass(cl);
		if (c == null) c = getOrImportClass(cl);
		if (c == null) c = resolve(cl);

		if (Type.typeof(c) == ValueType.TFunction)
			error(ECustom('new $cl(...): "$cl" 是补桩函数(PresetStubs.missing),不是可构造的类。'));

		return Type.createInstance(c, args);
	}

	public function destroy()
	{
		parent = null;
	}
}
