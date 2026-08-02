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
			if (Reflect.hasField(FlxG.save.data, 'renderResolution'))
				renderResIdx = cast FlxG.save.data.renderResolution;
			if (Reflect.hasField(FlxG.save.data, 'wideScreen'))
				wideScreen = cast FlxG.save.data.wideScreen;
		}

		// 获取分辨率
		var resolved:Array<Int> = getResolutionPreset(renderResIdx, wideScreen);
		game.width = resolved[0];
		game.height = resolved[1];

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
		applyRenderResolution(renderResIdx, wideScreen);
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

	// 分辨率预设 - 宽屏模式下直接返回21:9比例
	public static function getResolutionPreset(resIdx:Int, ?wideScreen:Bool = null):Array<Int>
	{
		var presets:Array<Array<Int>> = [
			[1280, 720],
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
	public static function applyRenderResolution(?resIdx:Int = -1, ?wideScreen:Bool = null):Void
	{
		if (resIdx == -1) resIdx = ClientPrefs.data.renderResolution;
		if (wideScreen == null)
		{
			wideScreen = ClientPrefs.data != null && Reflect.hasField(ClientPrefs.data, 'wideScreen') && cast ClientPrefs.data.wideScreen;
		}
		
		var useDpi = ClientPrefs.data.useDpiSettings;
		var window = Lib.current.stage.window;

		if (!useDpi)
		{
			var resolved:Array<Int> = getResolutionPreset(resIdx, wideScreen);
			var w:Int = resolved[0];
			var h:Int = resolved[1];
			
			window.resize(w, h);
			var displayBounds = window.display.bounds;
			window.x = Std.int(displayBounds.x + (displayBounds.width - w) / 2);
			window.y = Std.int(displayBounds.y + (displayBounds.height - h) / 2);
			
			FlxG.resizeGame(w, h);
			FlxG.scaleMode = new flixel.system.scaleModes.RatioScaleMode(false);
			
			try { Lib.current.stage.quality = openfl.display.StageQuality.BEST; } catch(e:Dynamic) {}
		}

		try {
			if (FlxG.cameras != null) {
				for (cam in FlxG.cameras.list) {
					try { resetSpriteCache(cam.flashSprite); } catch(e:Dynamic) {}
				}
			}
			try { resetSpriteCache(FlxG.game); } catch(e:Dynamic) {}
		} catch(e:Dynamic) {}
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