package;

#if android
import android.content.Context;
#end

import debug.FPSCounter;
import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import lime.system.System;
import states.TitleState;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig;
#end

#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import backend.Highscore;

#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

class Main extends Sprite
{
	public static final game = {
		width: 1280,
		height: 720,
		initialState: TitleState,
		zoom: -1.0,
		framerate: 60,
		skipSplash: true,
		startFullscreen: false
	};

	public static var fpsVar:FPSCounter;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		#if (cpp && windows)
		backend.Native.fixScaling();
		#end

		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#end

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		// 加载保存的数据
		FlxG.save.bind('funkin', CoolUtil.getSavePath());

		var renderResIdx:Int = 0;
		var wideScreen:Bool = false;

		if (FlxG.save.data != null)
		{
			if (Reflect.hasField(FlxG.save.data, 'wideScreen'))
				wideScreen = cast FlxG.save.data.wideScreen;
			if (Reflect.hasField(FlxG.save.data, 'renderResolution'))
				renderResIdx = getRenderResolutionIndex(FlxG.save.data.renderResolution, wideScreen);
		}

		// 根据宽屏模式设置游戏舞台尺寸
		game.width = wideScreen ? Math.round(720 * 21.0 / 9.0) : 1280;
		game.height = 720;

		if (game.zoom == -1.0)
		{
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
		}

		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end);
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		Highscore.load();

		#if HSCRIPT_ALLOWED
		Iris.warn = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(WARN, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('WARNING: $msgInfo', FlxColor.YELLOW);
		}
		Iris.error = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(ERROR, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('ERROR: $msgInfo', FlxColor.RED);
		}
		Iris.fatal = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(FATAL, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('FATAL: $msgInfo', 0xFFBB0000);
		}
		#end

		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		addChild(new FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		#if (cpp || hl)
		// 启动时：如果 useDpiSettings 为 true，则不 resize 物理窗口
		var startupResize:Bool = !ClientPrefs.data.useDpiSettings;
		applyRenderResolution(renderResIdx, wideScreen, startupResize);
		#end

		#if !mobile
		fpsVar = new FPSCounter(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}
		#end

		#if (linux || mac)
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = true;
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end

		FlxG.signals.gameResized.add(function (w, h) {
		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			}

			if (FlxG.game != null)
			resetSpriteCache(FlxG.game);
		});

        ClientPrefs.data.sessionStartTime = Date.now().getTime();

        var currentApp = Application.current;
        if (currentApp != null)
        {
            currentApp.onExit.add(function(code:Int) {
                saveSessionPlaytime();
            });
        }

        #if (cpp || hl)
        Lib.current.stage.window.onClose.add(function() {
            saveSessionPlaytime();
            return true;
        });
        #end
	}

	public static function getResolutionNames(?wideScreen:Bool = null):Array<String>
	{
		if (wideScreen == null)
		{
			wideScreen = ClientPrefs.data != null && Reflect.hasField(ClientPrefs.data, 'wideScreen') && cast ClientPrefs.data.wideScreen;
		}

		if (wideScreen)
		{
			return [
				"1680x720",
				"2520x1080",
				"3360x1440",
				"5040x2160"
			];
		}

		return [
			"1280x720",
			"1600x900",
			"1920x1080",
			"2560x1440",
			"3840x2160"
		];
	}

	public static function getRenderResolutionIndex(value:Dynamic, ?wideScreen:Bool = null, ?fallback:Int = 0):Int
	{
		var names:Array<String> = getResolutionNames(wideScreen);
		if (value == null) return fallback;

		if (Std.isOfType(value, String))
		{
			var label:String = StringTools.trim(cast value);
			var idx:Int = names.indexOf(label);
			if (idx >= 0) return idx;

			var parsed:Null<Int> = Std.parseInt(label);
			if (parsed != null) return parsed;

			return fallback;
		}

		try
		{
			return Std.int(value);
		}
		catch (e:Dynamic)
		{
			return fallback;
		}
	}

	// 分辨率预设 - 宽屏模式下直接返回21:9比例
	public static function getResolutionPreset(resIdx:Int, ?wideScreen:Bool = null):Array<Int>
	{
		var presets:Array<Array<Int>> = [
			[1280, 720],
			[1600, 900],
			[1920, 1080],
			[2560, 1440],
			[3840, 2160]
		];

		if (wideScreen == null)
		{
			wideScreen = ClientPrefs.data != null && Reflect.hasField(ClientPrefs.data, 'wideScreen') && cast ClientPrefs.data.wideScreen;
		}

		// 宽屏模式：返回21:9比例的分辨率
		if (wideScreen)
		{
			var widePresets:Array<Array<Int>> = [
				[Math.round(720 * 21.0 / 9.0), 720],   // 1680x720
				[Math.round(1080 * 21.0 / 9.0), 1080], // 2520x1080
				[Math.round(1440 * 21.0 / 9.0), 1440], // 3360x1440
				[Math.round(2160 * 21.0 / 9.0), 2160]  // 5040x2160
			];
			if (resIdx >= 0 && resIdx < widePresets.length)
				return widePresets[resIdx];
			return widePresets[0];
		}

		// 普通模式
		if (resIdx >= 0 && resIdx < presets.length)
			return presets[resIdx];
		return presets[0];
	}

	#if (cpp || hl)
	/**
	 * 应用渲染分辨率。
	 * @param resIdx       可以是标签字符串 / 整数索引；-1 或 null 表示从 ClientPrefs 读取
	 * @param wideScreen   null 表示从 ClientPrefs 读取
	 * @param resizeWindow 是否调整物理窗口大小（DPI 模式下应当为 false）
	 *
	 * 关键修复：不再内部重复判断 useDpiSettings，完全由调用方通过 resizeWindow 决定。
	 */
	public static function applyRenderResolution(?resIdx:Dynamic = -1, ?wideScreen:Bool = null, ?resizeWindow:Bool = true):Void
	{
		if (ClientPrefs.data == null) return;

		if (resIdx == null || (Std.isOfType(resIdx, Int) && (cast resIdx:Int) == -1))
			resIdx = ClientPrefs.data.renderResolution;

		if (wideScreen == null)
			wideScreen = Reflect.hasField(ClientPrefs.data, 'wideScreen')
				&& cast Reflect.field(ClientPrefs.data, 'wideScreen');

		var resolvedIndex:Int = getRenderResolutionIndex(resIdx, wideScreen, 0);
		var resolved:Array<Int> = getResolutionPreset(resolvedIndex, wideScreen);

		var stageW:Int = resolved[0];
		var stageH:Int = resolved[1];

		// ---- 1. 窗口物理尺寸（仅由 resizeWindow 决定，不再叠加 useDpi 判断）----
		if (resizeWindow)
		{
			try
			{
				var window = Lib.current.stage.window;
				window.resize(stageW, stageH);
				var b = window.display.bounds;
				window.x = Std.int(b.x + (b.width  - stageW) / 2);
				window.y = Std.int(b.y + (b.height - stageH) / 2);
				Lib.current.stage.quality = openfl.display.StageQuality.BEST;
			}
			catch (e:Dynamic) {}
		}

		// ---- 2. OpenFL stage 逻辑尺寸 ----
		var logicalOK:Bool = false;
		try
		{
			@:privateAccess Lib.current.stage.__setLogicalSize(stageW, stageH);
			logicalOK = true;
		}
		catch (e:Dynamic) {}

		// ---- 3. Flixel 逻辑画布尺寸（这一步失败必须让上层知道）----
		FlxG.resizeGame(stageW, stageH);

		// ---- 4. 缩放模式 ----
		FlxG.scaleMode = new flixel.system.scaleModes.RatioScaleMode(false);

		// ---- 5. 清理渲染缓存 ----
		try
		{
			if (FlxG.cameras != null)
				for (cam in FlxG.cameras.list)
					try { resetSpriteCache(cam.flashSprite); } catch (e:Dynamic) {}
			resetSpriteCache(FlxG.game);
		}
		catch (e:Dynamic) {}
	}
	#end

	public static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "Frozen_Engine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;
		#if officialBuild
		errMsg += "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine";
		#end
		errMsg += "\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
		  saveSessionPlaytime();
	}
	#end

	public static function saveSessionPlaytime():Void
	{
		if (ClientPrefs.data.sessionStartTime > 0)
		{
			var currentTime:Float = Date.now().getTime();
			var sessionSeconds:Float = (currentTime - ClientPrefs.data.sessionStartTime) / 1000;
			ClientPrefs.data.totalPlaytime += sessionSeconds;
			ClientPrefs.saveSettings();

			ClientPrefs.data.sessionStartTime = 0;
		}
	}
}