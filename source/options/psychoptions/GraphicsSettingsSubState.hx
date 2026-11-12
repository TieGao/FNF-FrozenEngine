package options.psychoptions;

import objects.Character;
import openfl.Lib;
import flixel.system.scaleModes.RatioScaleMode;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	
	var resolutionOption:Int;
	
	// 普通分辨率
	var normalResolutions:Array<Array<Int>> = [
		[1280, 720],
		[1920, 1080],
		[2560, 1440],
		[3840, 2160]
	];
	
	// 21:9 宽屏分辨率
	var wideResolutions:Array<Array<Int>> = [
		[Math.round(720 * 21.0 / 9.0), 720],   // 1680x720
		[Math.round(1080 * 21.0 / 9.0), 1080], // 2520x1080
		[Math.round(1440 * 21.0 / 9.0), 1440], // 3360x1440
		[Math.round(2160 * 21.0 / 9.0), 2160]  // 5040x2160
	];
	
	var resolutionNames:Array<String> = [
		"1280x720 (720p)",
		"1920x1080 (1080p)",
		"2560x1440 (1440p)",
		"3840x2160 (2160p)"
	];
	
	// 获取当前使用的分辨率列表
	function getCurrentResolutions():Array<Array<Int>>
	{
		return (ClientPrefs.data != null && ClientPrefs.data.wideScreen) ? wideResolutions : normalResolutions;
	}
	
	public function new()
	{
		title = Language.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu';

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.onFinish.add(function (name:String) boyfriend.dance());
		boyfriend.visible = false;

		var option:Option = new Option('Low Quality',
			'If checked, disables some background details,\ndecreases loading times and improves performance.',
			'lowQuality',
			BOOL);
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing;
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Resolution',
			'Changes the game\'s render resolution.\nHigher resolution = sharper image but worse performance.',
			'renderResolution',
			INT);
		option.minValue = 0;
		option.maxValue = resolutionNames.length - 1;
		option.displayFormat = resolutionNames[option.getValue()];
		option.onChange = onChangeResolution;
		addOption(option);
		resolutionOption = optionsArray.length - 1;

		var wideScreenOption:Option = new Option('Wide Screen',
			'Enable 21:9 widescreen mode for the game viewport width.',
			'wideScreen',
			BOOL);
		wideScreenOption.onChange = onChangeWideScreen;
		addOption(wideScreenOption);
		
		if (ClientPrefs.data.renderResolution < 0 || ClientPrefs.data.renderResolution >= resolutionNames.length) {
			ClientPrefs.data.renderResolution = 0;
		}

		var option:Option = new Option('Shaders',
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker.",
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Caching',
			"Texture caching mode://ndisabled = RAM only\nauto = drop the CPU copy after the first draw\nfull = upload and drop the CPU copy at load (least RAM, risky on low VRAM)",
			'gpuCaching',
			STRING, ['disabled', 'auto', 'full']);
		addOption(option);

		var option:Option = new Option('Preload to VRAM',
			"Upload textures to VRAM during preload. auto = only when the GPU has 10GB+ dedicated memory; on = always; off = never (upload on first use). Only matters when GPU Caching is set to full",
			'preloadTextureToVRAM',
			STRING, ['auto', 'on', 'off']);
		addOption(option);

		var option:Option = new Option('Keep Song on Freeplay',
			"Keep textures of the last played song loaded when returning to Freeplay, so replaying the same song skips decoding entirely. They are freed when you pick a different song or leave the menu. Costs RAM while you sit in the menu",
			'keepSongAssetsOnFreeplay',
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

	var unlimitedOption:Option = new Option('Unlimited FPS',
		"Removes the framerate cap (lime UNCAPPED profile). Takes priority over FPS Rework.",
		'unlimitedFPS',
		BOOL);
	unlimitedOption.onChange = onChangeFramerate;
	addOption(unlimitedOption);
	#end

	var option:Option = new Option('FPS Rework',
		"If checked, this works around the game becoming \"slow\" and \"smooth\" when the current FPS is lower than the FPS cap.",
		'fpsRework',
		BOOL);
	option.onChange = onChangeFramerate;
	addOption(option);

		super();
		insert(1, boyfriend);
		
		applyResolutionSetting();
	}

	function onChangeWideScreen()
	{
		// 切换宽屏后立即应用分辨率
		onChangeResolution();
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
		ClientPrefs.applyFrameTiming();
	}
	
	function onChangeResolution()
	{
		var resList = getCurrentResolutions();
		var selectedResolution = resList[ClientPrefs.data.renderResolution];
		changeRenderResolution(selectedResolution[0], selectedResolution[1]);
	}
	
	function changeRenderResolution(newWidth:Int, newHeight:Int):Void 
	{
		try 
		{
			#if (cpp || hl)
			var window = Lib.current.stage.window;
			window.resize(newWidth, newHeight);

			var displayBounds = window.display.bounds;
			var screenWidth = displayBounds.width;
			var screenHeight = displayBounds.height;
			window.x = Std.int(displayBounds.x + (screenWidth - newWidth) / 2);
			window.y = Std.int(displayBounds.y + (screenHeight - newHeight) / 2);
			#end

			FlxG.resizeGame(newWidth, newHeight);
			FlxG.scaleMode = new RatioScaleMode(false);

			trace('Resolution changed to: $newWidth x $newHeight');
		}
		catch (e:Dynamic)
		{
			trace('Error changing resolution: $e');
		}
	}
	
	function applyResolutionSetting():Void
	{
		var resList = getCurrentResolutions();
		if (ClientPrefs.data.renderResolution >= 0 && ClientPrefs.data.renderResolution < resList.length)
		{
			var selectedResolution = resList[ClientPrefs.data.renderResolution];
			changeRenderResolution(selectedResolution[0], selectedResolution[1]);
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}