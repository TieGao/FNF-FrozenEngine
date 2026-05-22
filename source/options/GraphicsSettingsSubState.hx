package options;

import objects.Character;
import openfl.Lib;
import flixel.system.scaleModes.RatioScaleMode;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	
	// 分辨率相关
	var resolutionOption:Int;
	var resolutions:Array<Array<Int>> = [
		[1280, 720],
		[1600, 900],
		[1920, 1080],
		[2560, 1440],
		[3840, 2160]
	];
	var resolutionNames:Array<String> = [
		"1280x720 (720p)",
		"1600x900 (900p)",
		"1920x1080 (1080p)",
		"2560x1440 (1440p)",
		"3840x2160 (4K)"
	];
	
	public function new()
	{
		title = Language.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu';

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.finishCallback = function (name:String) boyfriend.dance();
		boyfriend.visible = false;

		// Low Quality
		var option:Option = new Option('Low Quality',
			'If checked, disables some background details,\ndecreases loading times and improves performance.',
			'lowQuality',
			BOOL);
		addOption(option);

		// Anti-Aliasing
		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing;
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		// 分辨率选项
		var option:Option = new Option('Resolution',
			'Changes the game\'s render resolution.\nHigher resolution = sharper image but worse performance.',
			'renderResolution',
			INT);
		option.minValue = 0;
		option.maxValue = resolutions.length - 1;
		option.displayFormat = resolutionNames[option.getValue()];
		option.onChange = onChangeResolution;
		addOption(option);
		resolutionOption = optionsArray.length - 1;
		
		// 设置默认值
		if (ClientPrefs.data.renderResolution < 0 || ClientPrefs.data.renderResolution >= resolutions.length) {
			ClientPrefs.data.renderResolution = 0;
		}

		// Shaders
		var option:Option = new Option('Shaders',
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker.",
			'shaders',
			BOOL);
		addOption(option);

		// GPU Caching
		var option:Option = new Option('GPU Caching',
			"If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card.",
			'cacheOnGPU',
			BOOL);
		addOption(option);

		#if !html5
		var option:Option = new Option('Framerate',
			"Pretty self explanatory, isn't it?",
			'framerate',
			INT);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 60;
		option.maxValue = 240;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		#end

		// FPS Rework
		var option:Option = new Option('FPS Rework',
			"If checked, this works around the game becoming \"slow\" and \"smooth\" when the current FPS is lower than the FPS cap.",
			'fpsRework',
			BOOL);
		addOption(option);

		super();
		insert(1, boyfriend);
		
		// 应用保存的分辨率设置
		applyResolutionSetting();
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate()
	{
		if(ClientPrefs.data.framerate > FlxG.drawFramerate)
		{
			if (ClientPrefs.data.fpsRework)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;
			else
			{
				FlxG.updateFramerate = ClientPrefs.data.framerate;
				FlxG.drawFramerate = ClientPrefs.data.framerate;
			}
		}
		else
		{
			if (ClientPrefs.data.fpsRework)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;
			else
			{
				FlxG.drawFramerate = ClientPrefs.data.framerate;
				FlxG.updateFramerate = ClientPrefs.data.framerate;
			}
		}
	}
	
	// 分辨率改变回调
	function onChangeResolution()
	{
		var selectedResolution = resolutions[ClientPrefs.data.renderResolution];
		changeRenderResolution(selectedResolution[0], selectedResolution[1]);
	}
	
	// 实际改变分辨率的函数
	function changeRenderResolution(newWidth:Int, newHeight:Int):Void 
	{
		try 
		{
			// 1. 改变窗口物理尺寸
			var window = Lib.current.stage.window;
			window.resize(newWidth, newHeight);

			// 2. 将窗口移动到屏幕中央（获取主显示器分辨率）
			#if (cpp || hl)
			// 需要 openfl 8.9+ 支持 window.display.bounds
			var displayBounds = window.display.bounds;
			var screenWidth = displayBounds.width;
			var screenHeight = displayBounds.height;
			window.x = Std.int(displayBounds.x + (screenWidth - newWidth) / 2);
			window.y = Std.int(displayBounds.y + (screenHeight - newHeight) / 2);
			#end

			// 3. 使用 FlxG.resizeGame() - 它会处理所有渲染相关的更新！
			FlxG.resizeGame(newWidth, newHeight);

			// 4. 重新应用缩放模式（保持原有的拉伸窗口行为）
			FlxG.scaleMode = new RatioScaleMode(false);

			trace('Resolution changed to: $newWidth x $newHeight');
		}
		catch (e:Dynamic)
		{
			trace('Error changing resolution: $e');
		}
	}
	
	// 应用保存的分辨率
	function applyResolutionSetting():Void
	{
		if (ClientPrefs.data.renderResolution >= 0 && ClientPrefs.data.renderResolution < resolutions.length)
		{
			var selectedResolution = resolutions[ClientPrefs.data.renderResolution];
			changeRenderResolution(selectedResolution[0], selectedResolution[1]);
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}