package debug;

import flixel.FlxG;
import openfl.Lib;
import haxe.Timer;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System as OpenFlSystem;
import lime.system.System as LimeSystem;
import lime.graphics.RenderContext;
import lime.graphics.RenderContextType;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif mac
@:cppFileCode('#include <mach-o/arch.h>')
#elseif linux
@:headerInclude('sys/utsname.h')
#end
#end
class FPSCounter extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;
	public var currentTPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;
	public var peakMemoryMegas(default, null):Float = 0;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var lastFramerateUpdateTime:Float;
	@:noCompletion private var updateTime:Int;
	@:noCompletion private var framesCount:Int;
	@:noCompletion private var prevTime:Int;
	@:noCompletion private var lastTPSUpdateTime:Float;
	@:noCompletion private var tpsUpdateTime:Int;
	@:noCompletion private var tpsCount:Int;
	@:noCompletion private var prevTPSTime:Int;

	public var graphicsAPI:String = '';

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();
		
		// 获取图形 API 信息（运行时不变，只获取一次）
		graphicsAPI = getGraphicsAPI();
		
		positionFPS(x, y);

		currentFPS = 0;
		currentTPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("vcr.ttf", 14, color);
		width = FlxG.width;
		multiline = true;
		text = "FPS: ";

		times = [];
		lastFramerateUpdateTime = Timer.stamp();
		prevTime = Lib.getTimer();
		updateTime = prevTime + 500;
		
		// TPS 计时
		prevTPSTime = Lib.getTimer();
		tpsUpdateTime = prevTPSTime + 500;
		tpsCount = 0;
	}

	/**
		获取当前使用的图形 API
	**/
	private function getGraphicsAPI():String
	{
		try
		{
			if (FlxG.stage != null && FlxG.stage.window != null)
			{
				#if (lime >= "8.0.0")
				var contextType = FlxG.stage.window.context.type;
				return getAPINameFromType(contextType);
				#else
				return detectGraphicsAPI();
				#end
			}
			else
			{
				return detectGraphicsAPI();
			}
		}
		catch (e:Dynamic)
		{
			return detectGraphicsAPI();
		}
	}

	/**
		从 RenderContextType 获取可读的 API 名称
	**/
	private function getAPINameFromType(type:RenderContextType):String
	{
		return switch (type)
		{
			case RenderContextType.OPENGL: "OpenGL";
			case RenderContextType.OPENGLES: "OpenGL ES";
			case RenderContextType.WEBGL: "WebGL";
			//case RenderContextType.VULKAN: "Vulkan";
			case RenderContextType.CAIRO: "Cairo";
			case RenderContextType.CANVAS: "Canvas 2D";
			case RenderContextType.DOM: "DOM";
			case RenderContextType.FLASH: "Flash";
			case RenderContextType.CUSTOM: "Custom";
			default: "Unknown";
		}
	}

	/**
		当无法直接从 RenderContext 获取时的备用检测方法
	**/
	private function detectGraphicsAPI():String
	{
		#if (js && html5)
		try
		{
			var canvas = cast(FlxG.stage.window.element, js.html.CanvasElement);
			if (canvas != null)
			{
				var gl = canvas.getContext("webgl");
				if (gl != null) return "WebGL";
				gl = canvas.getContext("webgl2");
				if (gl != null) return "WebGL 2";
				var ctx = canvas.getContext("2d");
				if (ctx != null) return "Canvas 2D";
			}
			return "HTML5";
		}
		catch (e:Dynamic)
		{
			return "HTML5";
		}
		#elseif (cpp && (linux || windows || mac))
		#if (lime_opengl)
		return "OpenGL";
		#elseif (lime_vulkan)
		return "Vulkan";
		#else
		return "OpenGL";
		#end
		#elseif android
		#if (lime_opengles)
		return "OpenGL ES";
		#elseif (lime_vulkan)
		return "Vulkan";
		#else
		return "OpenGL ES";
		#end
		#elseif ios
		return "OpenGL ES (Metal)";
		#elseif flash
		return "Flash Stage3D";
		#else
		return "Unknown";
		#end
	}

	/**
		实时获取操作系统信息
	**/
	private function getOSInfo():String
	{
		if (!ClientPrefs.data.showOS) return '';
		
		var platformName = LimeSystem.platformName;
		var platformVersion = LimeSystem.platformVersion;
		
		#if ios
		// iOS 只显示系统版本，不显示架构
		return platformVersion != null ? 'iOS $platformVersion' : 'iOS';
		#else
		// 其他平台显示系统名称 + 架构 + 版本
		var arch = #if cpp getArch() #else "" #end;
		if (platformName == platformVersion || platformVersion == null)
			return platformName + (arch != 'Unknown' && arch != '' ? ' $arch' : '');
		else
			return platformName + (arch != 'Unknown' && arch != '' ? ' $arch' : '') + ' - $platformVersion';
		#end
	}

	public dynamic function updateText():Void
	{
		var lines:Array<String> = [];
		
		// 第一行：FPS | TPS
		var fpsTpsLine = 'FPS: $currentFPS';
		if (ClientPrefs.data.showTPS)
		{
			fpsTpsLine += ' | TPS: $currentTPS';
		}
		lines.push(fpsTpsLine);
		
		// 第二行：内存信息
		var memLine = 'Memory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}';
		if (ClientPrefs.data.showMEMPeak)
		{
			updatePeakMemory();
			memLine += ' (${flixel.util.FlxStringUtil.formatBytes(peakMemoryMegas)} Peak)';
		}
		lines.push(memLine);
		
		// 第三行：OS 和 Render（实时获取，切换设置立即生效）
		var infoParts:Array<String> = [];
		if (ClientPrefs.data.showOS)
		{
			var osInfo = getOSInfo();
			if (osInfo != '') infoParts.push('OS: $osInfo');
		}
		if (ClientPrefs.data.showApi && graphicsAPI != '')
		{
			infoParts.push('Render: $graphicsAPI');
		}
		if (infoParts.length > 0)
		{
			lines.push(infoParts.join(' | '));
		}
		
		text = lines.join('\n');
		
		textColor = 0xFFFFFFFF;
		if (currentFPS < FlxG.stage.window.frameRate * 0.5)
			textColor = 0xFFFF0000;
	}
	
	private function updatePeakMemory():Void
	{
		var currentMem = memoryMegas;
		if (currentMem > peakMemoryMegas)
			peakMemoryMegas = currentMem;
	}

	var deltaTimeout:Float = 0.0;
	private override function __enterFrame(deltaTime:Float):Void
	{
		if (ClientPrefs.data.fpsRework)
		{
			// Flixel keeps reseting this to 60 on focus gained
			if (FlxG.stage.window.frameRate != ClientPrefs.data.framerate && FlxG.stage.window.frameRate != FlxG.game.focusLostFramerate)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;

			var currentTime = openfl.Lib.getTimer();
			framesCount++;
			tpsCount++;

			if (currentTime >= updateTime)
			{
				var elapsed = currentTime - prevTime;
				currentFPS = Math.ceil((framesCount * 1000) / elapsed);
				framesCount = 0;
				prevTime = currentTime;
				updateTime = currentTime + 500;
			}
			
			// TPS 更新
			if (currentTime >= tpsUpdateTime)
			{
				var elapsedTPS = currentTime - prevTPSTime;
				currentTPS = Math.ceil((tpsCount * 1000) / elapsedTPS);
				tpsCount = 0;
				prevTPSTime = currentTime;
				tpsUpdateTime = currentTime + 500;
			}

			// Set Update and Draw framerate to the current FPS every 1.5 second to prevent "slowness" issue
			if ((FlxG.updateFramerate >= currentFPS + 5 || FlxG.updateFramerate <= currentFPS - 5)
				&& haxe.Timer.stamp() - lastFramerateUpdateTime >= 1.5
				&& currentFPS >= 30)
			{
				FlxG.updateFramerate = FlxG.drawFramerate = currentFPS;
				lastFramerateUpdateTime = haxe.Timer.stamp();
			}
		}
		else
		{
			final now:Float = haxe.Timer.stamp() * 1000;
			times.push(now);
			while (times[0] < now - 1000)
				times.shift();
			// prevents the overlay from updating every frame, why would you need to anyways @crowplexus
			if (deltaTimeout < 50)
			{
				deltaTimeout += deltaTime;
				return;
			}

			currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
			// 在不使用 fpsRework 时，TPS 等于 FPS
			currentTPS = currentFPS;
			deltaTimeout = 0.0;
		}

		updateText();
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1){
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}

	#if cpp
	#if windows
	@:functionCode('
		SYSTEM_INFO osInfo;
		GetSystemInfo(&osInfo);
		switch(osInfo.wProcessorArchitecture)
		{
			case 9: return ::String("x86_64");
			case 5: return ::String("ARM");
			case 12: return ::String("ARM64");
			case 6: return ::String("IA-64");
			case 0: return ::String("x86");
			default: return ::String("Unknown");
		}
	')
	#elseif mac
	@:functionCode('
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
		return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
	#elseif linux
	@:functionCode('
		struct utsname osInfo{};
		uname(&osInfo);
		return ::String(osInfo.machine);
	')
	#end
	@:noCompletion
	private function getArch():String
	{
		return "Unknown";
	}
	#end
}