package nmv.scripts.preset;

import crowplexus.iris.Iris;

import nmv.scripts.FunkinScript;

/**
 * NMV preset 的补桩段：能接 FE 的接上，接不上的显式抛异常。
 *
 * 抛异常而不是静默 no-op：NMV 脚本调错 API 时，Unknown variable 定位成本高，
 * 带原因文案的异常能直接告诉移植者缺什么（见 docs/nmv-port-plan/35 小节）。
 */
class PresetStubs
{
	public static function register(script:FunkinScript):Void
	{
		// shader：FE 侧走 shaders/<name>.frag + ErrorHandledRuntimeShader（PSL/GLSL 编译报错有兜底弹窗）
		script.set("newShader", (name:String) -> {
			final fragPath = backend.Paths.shaderFragment(name);

			var source:Null<String> = null;
			if (sys.FileSystem.exists(fragPath)) source = sys.io.File.getContent(fragPath);
			else if (lime.utils.Assets.exists(fragPath)) source = lime.utils.Assets.getText(fragPath);

			if (source == null)
				throw 'newShader("$name"): shader fragment not found (looked at "$fragPath").';

			return new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(name, source);
		});

		// modchart 族：FE 没有等价体系，统一显式失败（样本仅 CreditsRollSubState.hx 用到）
		for (name in ['ModManager', 'SubModifier', 'NoteModifier', 'ScriptedModifier', 'EventTimeline', 'Modifier',
			'StepCallbackEvent', 'CallbackEvent', 'ModEvent', 'EaseEvent', 'SetEvent'])
		{
			missing(script, name, 'NMV modchart 未移植（FE 无 modchart 体系）。');
		}

		// NMV 专有类，FE 无对应物
		missing(script, 'WeekData', 'FE 的 WeekData 与 NMV 字段不同义，禁止直读。');
		missing(script, 'StageData', 'FE 的 StageData 与 NMV 字段不同义，禁止直读。');
		missing(script, 'FunkinCamera', 'FE 相机类名是 flixel.FlxCamera / backend.PsychCamera。');
		missing(script, 'BackgroundDancer', 'NMV 舞台装饰角色，FE 未移植。');
		missing(script, 'BackgroundGirls', 'NMV 舞台装饰角色，FE 未移植。');
		missing(script, 'FunkinSound', 'FE 音频类是 flixel.FlxSound / flixel.sound.FlxSound。');
		// 语料实测会撞到的 NMV 引擎类（路线 C 不搬引擎本体，明确报缺失）
		// 注意：AmongWalker 已移植（nmv.objects.AmongWalker，PresetFnf 注册），此处桩若
		// 留着会反覆盖真类——hscript new 走到函数桩会静默得到 null，报错面目全非。
		missing(script, 'FinaleState', 'NMV 剧情地图专属 State（storyNodes 系统），未接入。');
		missing(script, 'CameraUtil', 'NMV 相机工具类，仅 storyNodes 系统使用，未接入。');

		// 脚本内再加载脚本：交给所属容器，宿主变量与事件广播沿用同一组
		script.set('initScript', function(path:String):Bool {
			final group = script.scriptGroup;
			final holder = group == null ? null : group.holder;
			if (holder == null)
				throw 'initScript("$path"): script is not attached to a state holder (load it through NMVSciptHolder).';

			return holder.load(FunkinScript.getPath(path), null, script.modFolder) != null;
		});

		// 机制型 API：模组设置属后续阶段
		missing(script, 'getInstance', 'NMV 单例容器语义，FE 未移植。');
		missing(script, 'newOption', 'NMV ModOptions 未移植（FE 模组设置在 ModSettingsSubState）。');
		missing(script, 'getOption', 'NMV ModOptions 未移植（FE 模组设置在 ModSettingsSubState）。');
	}

	/** 注册一个必然抛出的占位；参数个数不限，调用形态像函数。 */
	static function missing(script:Iris, name:String, reason:String):Void
	{
		script.set(name, Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
			throw 'NMV API "$name" is not implemented in this port. $reason';
		}));
	}
}
