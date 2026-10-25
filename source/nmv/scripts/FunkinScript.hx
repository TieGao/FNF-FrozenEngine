package nmv.scripts;

import crowplexus.iris.Iris;

import backend.Paths;
import flixel.FlxG;
import flixel.util.FlxDestroyUtil;
import sys.FileSystem;

import nmv.scripts.preset.PresetCore;
import nmv.scripts.preset.PresetFlixel;
import nmv.scripts.preset.PresetFnf;

@:access(crowplexus.iris.Iris)
class FunkinScript extends IrisEx implements IFlxDestroyable
{
	/** 支持的 hscript 扩展名。 */
	public static final H_EXTS:Array<String> = ['hx', 'hxs', 'hscript'];

	/** 依次尝试追加支持的扩展名，返回第一个存在的路径。 */
	public static function getPath(path:String):String
	{
		for (extension in H_EXTS)
		{
			final file = '$path.$extension';

			final targetPath = Paths.getPath(file);
			if (FileSystem.exists(targetPath)) return targetPath;
			if (FileSystem.exists(file)) return file;
		}
		return path;
	}

	/** 路径是否以支持的扩展名结尾。 */
	public static function isHxFile(path:String):Bool
	{
		for (extension in H_EXTS)
			if (path.endsWith(extension)) return true;

		return false;
	}

	/** 读脚本内容：内容包在磁盘上，先查文件系统，再回退 openfl Assets。 */
	public static function getContent(file:String):String
	{
		if (FileSystem.exists(file)) return sys.io.File.getContent(file);
		return lime.utils.Assets.getText(file);
	}

	/** 把 Iris 相关类注册进 FLX_DEBUG 控制台；release 构建下为空。 */
	public static function init()
	{
		#if FLX_DEBUG
		FlxG.console.registerClass(Iris);
		FlxG.console.registerClass(IrisEx);
		FlxG.console.registerClass(FunkinScript);
		#end
	}

	/** 从字符串创建脚本。 */
	public static function fromString(script:String, ?name:String = "Script", autoExecute:Bool = true, ?shareables:Sharables, ?modFolder:String)
	{
		return new FunkinScript(script, name, autoExecute, shareables, modFolder);
	}

	/** 从文件创建脚本；调用方需自行确认文件存在。 */
	public static function fromFile(file:String, ?name:String, autoExecute:Bool = true, ?shareables:Sharables, ?modFolder:String)
	{
		name ??= file;

		return new FunkinScript(getContent(file), name, autoExecute, shareables, modFolder);
	}

	/** 执行失败时的异常；解析成功时为 null。 */
	public var parsingException:Null<haxe.Exception> = null;

	/** 解析是否失败。 */
	public function parsingFailed():Bool
	{
		return parsingException != null;
	}

	public var modFolder:Null<String>;

	/** 所属脚本组；由 ScriptGroup.addScript 写入，供 initScript 这类脚本内再加载用。 */
	public var scriptGroup:ScriptGroup = null;

	public function new(script:String, ?name:String = "Script", autoExecute:Bool = true, ?shareables:Sharables, ?modFolder:String)
	{
		super(script, {name: name, autoRun: false, autoPreset: false}, shareables);

		(cast interp : InterpEx).parent = FlxG.state;

		this.modFolder = modFolder;

		preset();

		if (autoExecute) execute();
	}

	override function execute():Dynamic
	{
		final retVal = try
		{
			super.execute();
		}
		catch (e)
		{
			parsingException = e;

			FlxG.log.error('[${name}]: PARSING ERROR: $e');
			null;
		}
		return retVal;
	}

	/** 调用脚本内的指定函数（notescript 等场景用）。 */
	public function executeFunc(func:String, ?parameters:Array<Dynamic>, ?theObject:Any, ?extraVars:Map<String, Dynamic>):Dynamic
	{
		extraVars ??= [];

		if (exists(func))
		{
			var daFunc = get(func);
			if (Reflect.isFunction(daFunc))
			{
				var returnVal:Dynamic = null;
				var defaultShit:Map<String, Dynamic> = [];

				if (theObject != null) extraVars.set("this", theObject);

				for (key in extraVars.keys())
				{
					defaultShit.set(key, get(key));
					set(key, extraVars.get(key));
				}

				try
				{
					returnVal = Reflect.callMethod(theObject, daFunc, parameters ?? []);
				}
				catch (e)
				{
					#if sys
					Sys.println(e.message);
					#end
				}

				for (key in defaultShit.keys())
				{
					set(key, defaultShit.get(key));
				}

				return returnVal;
			}
		}
		return null;
	}

	override function preset()
	{
		super.preset();

		// NMV preset API 的 FE 映射，按档位分组注册：
		// 核心/std、flixel、FNF 类与上下文、补桩/未移植项
		PresetCore.register(this);
		PresetFlixel.register(this);
		PresetFnf.register(this);
	}
}
