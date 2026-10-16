package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;

#if sys
import sys.FileSystem;
#end


#if MODS_ALLOWED
import backend.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = ['assets/shared/music/freakyMenu.$SOUND_EXT'];
	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}

		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
				{
					//trace('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			//trace('check...');
			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null)
				{
					protectedGfx.push(gfx);
					//trace('gfx added to the list successfully!');
				}
			}
			//catch(haxe.Exception) {}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if(FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					//trace('deleted $key');
				}
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var customFile:String = file;
			if (parentfolder != null) customFile = '$parentfolder/$file';

			var modded:String = modFolders(customFile);
			if(FileSystem.exists(modded)) return modded;
		}
		#end

		// 内容包（content/）优先于 assets/：内部与 assets 同构，按 parentfolder / currentLevel / shared
		// 三段依次探测。命中即返回，找不到落回下面的 assets 分支 —— 加性回退、不排他。
		if (currentContentRoot != null && currentContentRoot.length > 0)
		{
			var contentCandidates:Array<String> = [];
			if (parentfolder != null)
				contentCandidates.push('$currentContentRoot/$parentfolder/$file');
			else
			{
				if (currentLevel != null && currentLevel != 'shared')
					contentCandidates.push('$currentContentRoot/$currentLevel/$file');
				contentCandidates.push('$currentContentRoot/shared/$file');
			}
			for (dependencyRoot in currentContentDependencyRoots)
			{
				if (parentfolder != null)
					contentCandidates.push('$dependencyRoot/$parentfolder/$file');
				else
				{
					if (currentLevel != null && currentLevel != 'shared')
						contentCandidates.push('$dependencyRoot/$currentLevel/$file');
					contentCandidates.push('$dependencyRoot/shared/$file');
				}
			}
			for (candidate in contentCandidates)
			{
				#if sys
				if (FileSystem.exists(candidate)) return candidate;
				#else
				if (OpenFlAssets.exists(candidate, type)) return candidate;
				#end
			}
		}

		if (parentfolder != null)
			return getFolderPath(file, parentfolder);

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath = getFolderPath(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}
		return getSharedPath(file);
	}

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	public static var currentTrackedVideos:Map<String, String> = [];
	
		static public function video(key:String):String
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	// 新增缓存视频函数
	static public function cachedVideo(key:String):String
	{
		var videoPath:String = video(key); // 先获取原始路径
		
		// 检查是否已缓存
		if (currentTrackedVideos.exists(videoPath))
		{
			localTrackedAssets.push(videoPath);
			return currentTrackedVideos.get(videoPath);
		}
		
		return cacheVideoPath(videoPath);
	}

	// 缓存视频路径
	static function cacheVideoPath(filePath:String):String
	{
		// 验证视频文件是否存在
		var exists:Bool = false;
		
		#if MODS_ALLOWED
		if (FileSystem.exists(filePath))
			exists = true;
		#end
		
		#if !MODS_ALLOWED
		if (OpenFlAssets.exists(filePath, VIDEO))
			exists = true;
		#end
		
		if (!exists)
		{
			trace('Video not found for caching: $filePath');
			return filePath;
		}
		
		// 缓存视频路径
		currentTrackedVideos.set(filePath, filePath);
		localTrackedAssets.push(filePath);
		
		return filePath;
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', modsAllowed);

	public static function inst(song:String, ?modsAllowed:Bool = true, ?chartCategory:String = null):Sound
	{
		var songPath:String = formatToSongPath(song);
		var candidates:Array<String> = [];

		// 变体难度（Erect / Pico / …）的音轨在 songs/<歌>-<变体>/ 里，文件名不带变体后缀。
		// ⚠️ 必须排在无后缀候选之前 —— 否则变体难度会命中原曲的 Inst.ogg。
		var variant:String = Difficulty.getAudioVariant();
		if (variant != null)
		{
			candidates.push(getPath('$songPath-$variant/Inst.$SOUND_EXT', SOUND, 'songs', modsAllowed));
			#if sys
			// 目录名大小写可能与难度名不一致，精确路径 miss 时会静默回退原曲；补一条不敏感解析出的真实目录。
			var variantDir:String = resolveVariantSongDir(songPath, variant);
			if (variantDir != null) candidates.push('$variantDir/Inst.$SOUND_EXT');
			#end
		}

		// Keep the normal Psych Engine path first, then support chart-pack layouts.
		candidates.push(getPath('$songPath/Inst.$SOUND_EXT', SOUND, 'songs', modsAllowed));
		candidates.push(getPath('data/$songPath/inst.ogg', SOUND, null, modsAllowed));
		candidates.push(getPath('data/$songPath/song/inst.ogg', SOUND, null, modsAllowed));
		candidates.push(getPath('data/$songPath/audio.mp3', SOUND, null, modsAllowed));
		candidates.push(getPath('data/$songPath/audio.ogg', SOUND, null, modsAllowed));

		#if MODS_ALLOWED
		if (chartCategory != null && chartCategory.length > 0)
		{
			var chartDir:String = (currentChartDirectory != null && currentChartDirectory.length > 0)
				? currentChartDirectory : '$CHART_ROOT/$chartCategory/$songPath';
			#if sys
			// 只有当前目录未知时才靠分类名去猜路径。已经有精确目录时再猜一次，
			// 一旦分类名指向别的目录（例如浏览聚合分类 'custom' 时恰好存在同名文件夹），
			// 就会把正确目录覆盖成错的。
			if (currentChartDirectory == null || currentChartDirectory.length == 0)
			{
				var actualCategory:String = findCaseInsensitiveDirectory(CHART_ROOT, chartCategory);
				if (actualCategory != null)
				{
					var actualSong:String = findCaseInsensitiveDirectory(actualCategory, songPath);
					if (actualSong != null) chartDir = actualSong;
				}
			}
			#end
			chartDir += '/';
			if (currentChartHasVSliceMetadata && currentChartAudioSuffix != null && currentChartAudioSuffix.length > 0)
			{
				candidates.push(chartDir + 'Inst-' + currentChartAudioSuffix + '.ogg');
				candidates.push(chartDir + 'Inst-' + currentChartAudioSuffix + '.mp3');
				candidates.push(chartDir + 'inst-' + currentChartAudioSuffix + '.ogg');
				candidates.push(chartDir + 'inst-' + currentChartAudioSuffix + '.mp3');
			}
			candidates.push(chartDir + 'inst.ogg');
			candidates.push(chartDir + 'inst.mp3');
			candidates.push(chartDir + 'audio.ogg');
			candidates.push(chartDir + 'audio.mp3');
			candidates.push(chartDir + 'Inst-erect.ogg');
			candidates.push(chartDir + 'Inst-erect.mp3');
			candidates.push(chartDir + 'Inst-pico.ogg');
			candidates.push(chartDir + 'Inst-pico.mp3');
			candidates.push(chartDir + 'inst-erect.ogg');
			candidates.push(chartDir + 'inst-erect.mp3');
			candidates.push(chartDir + 'inst-pico.ogg');
			candidates.push(chartDir + 'inst-pico.mp3');
		}
		#end

		for (candidate in candidates)
		{
			var sound:Sound = loadSoundCandidate(candidate);
			if (sound != null)
			{
				localTrackedAssets.push(candidate);
				return sound;
			}
		}

		trace('SOUND NOT FOUND: $songPath');
		FlxG.log.error('SOUND NOT FOUND: $songPath');
		return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
	}

	#if sys
	static function findCaseInsensitiveDirectory(basePath:String, name:String):String
	{
		if (!FileSystem.exists(basePath)) return null;
		var exactPath:String = '$basePath/$name';
		if (FileSystem.isDirectory(exactPath)) return exactPath;
		for (item in FileSystem.readDirectory(basePath))
			if (item.toLowerCase() == name.toLowerCase() && FileSystem.isDirectory('$basePath/$item'))
				return '$basePath/$item';
		return null;
	}

	/**
	 * 变体音轨目录名的大小写可能与难度名不一致（磁盘是 <歌>-Erect，难度名可能是 erect）。
	 * 大小写敏感的文件系统上精确路径会 miss，随后静默回退到原曲音轨 —— 这里按不敏感方式
	 * 解析出真实目录；解析不到返回 null，由调用方回退到常规候选。
	 */
	static function resolveVariantSongDir(songPath:String, variant:String):String
	{
		var roots:Array<String> = [];
		if (currentContentRoot != null && currentContentRoot.length > 0)
			roots.push('$currentContentRoot/songs');
		for (dependencyRoot in currentContentDependencyRoots) roots.push('$dependencyRoot/songs');
		roots.push('assets/songs');
		for (root in roots)
		{
			var found:String = findCaseInsensitiveDirectory(root, '$songPath-$variant');
			if (found != null) return found;
		}
		return null;
	}
	#end

	static function loadSoundCandidate(file:String):Sound
	{
		if (file == null || file.length == 0 || currentTrackedSounds.exists(file))
			return currentTrackedSounds.get(file);

		#if sys
		if (FileSystem.exists(file))
		{
			var sound:Sound = Sound.fromFile(file);
			currentTrackedSounds.set(file, sound);
			return sound;
		}
		#else
		if (OpenFlAssets.exists(file, SOUND))
		{
			var sound:Sound = OpenFlAssets.getSound(file);
			currentTrackedSounds.set(file, sound);
			return sound;
		}
		#end
		return null;
	}

	public static function voices(song:String, postfix:String = null, ?modsAllowed:Bool = true, ?chartCategory:String = null):Sound
	{
		var songPath:String = formatToSongPath(song);
		var voiceName:String = 'Voices';
		if (postfix != null && postfix.length > 0) voiceName += '-$postfix';
		var candidates:Array<String> = [];

		if (currentChartHasVSliceMetadata && currentChartAudioSuffix != null && currentChartAudioSuffix.length > 0)
		{
			candidates.push(getPath('$songPath/Voices-$currentChartAudioSuffix.$SOUND_EXT', SOUND, 'songs', modsAllowed));
			candidates.push(getPath('data/$songPath/voices-$currentChartAudioSuffix.ogg', SOUND, null, modsAllowed));
			candidates.push(getPath('data/$songPath/song/voices-$currentChartAudioSuffix.ogg', SOUND, null, modsAllowed));
		}

		// 变体难度的人声同样在 songs/<歌>-<变体>/ 里（Voices-Player.ogg / Voices-Opponent.ogg）。
		// 与 inst() 一样，必须排在无后缀候选之前。
		var variant:String = Difficulty.getAudioVariant();
		if (variant != null)
		{
			candidates.push(getPath('$songPath-$variant/$voiceName.$SOUND_EXT', SOUND, 'songs', modsAllowed));
			#if sys
			var variantDir:String = resolveVariantSongDir(songPath, variant);
			if (variantDir != null) candidates.push('$variantDir/$voiceName.$SOUND_EXT');
			#end
		}

		candidates.push(getPath('$songPath/$voiceName.$SOUND_EXT', SOUND, 'songs', modsAllowed));
		candidates.push(getPath('data/$songPath/${voiceName.toLowerCase()}.ogg', SOUND, null, modsAllowed));
		candidates.push(getPath('data/$songPath/song/${voiceName.toLowerCase()}.ogg', SOUND, null, modsAllowed));

		#if MODS_ALLOWED
		if (chartCategory == null) chartCategory = currentChartCategory;
		if (chartCategory != null && chartCategory.length > 0)
		{
			var chartDir:String = (currentChartDirectory != null && currentChartDirectory.length > 0)
				? currentChartDirectory : '$CHART_ROOT/$chartCategory/$songPath';
			#if sys
			// 只有当前目录未知时才靠分类名去猜路径。已经有精确目录时再猜一次，
			// 一旦分类名指向别的目录（例如浏览聚合分类 'custom' 时恰好存在同名文件夹），
			// 就会把正确目录覆盖成错的。
			if (currentChartDirectory == null || currentChartDirectory.length == 0)
			{
				var actualCategory:String = findCaseInsensitiveDirectory(CHART_ROOT, chartCategory);
				if (actualCategory != null)
				{
					var actualSong:String = findCaseInsensitiveDirectory(actualCategory, songPath);
					if (actualSong != null) chartDir = actualSong;
				}
			}
			#end
			chartDir += '/';
			if (currentChartHasVSliceMetadata && currentChartAudioSuffix != null && currentChartAudioSuffix.length > 0)
			{
				candidates.push(chartDir + 'Voices-' + currentChartAudioSuffix + '.ogg');
				candidates.push(chartDir + 'Voices-' + currentChartAudioSuffix + '.mp3');
				candidates.push(chartDir + 'voices-' + currentChartAudioSuffix + '.ogg');
				candidates.push(chartDir + 'voices-' + currentChartAudioSuffix + '.mp3');
			}
			candidates.push(chartDir + '${voiceName.toLowerCase()}.ogg');
			candidates.push(chartDir + '${voiceName.toLowerCase()}.mp3');

			// 添加无后缀版本（需要修改）
			candidates.push(chartDir + 'voices.ogg');   // ← 新增
			candidates.push(chartDir + 'voices.mp3');   // ← 新增
			
			// ========== 新增 vocals 回退支持 ==========
			// 添加 vocals.ogg/mp3 回退（无后缀版本）
			candidates.push(chartDir + 'vocals.ogg');
			candidates.push(chartDir + 'vocals.mp3');
			// ==========================================
		}
		#end

		// ========== 新增全局 vocals 回退支持 ==========
		// 标准路径下的 vocals 回退
		candidates.push(getPath('$songPath/vocals.$SOUND_EXT', SOUND, 'songs', modsAllowed));
		candidates.push(getPath('data/$songPath/vocals.ogg', SOUND, null, modsAllowed));
		candidates.push(getPath('data/$songPath/song/vocals.ogg', SOUND, null, modsAllowed));
		// =============================================

		for (candidate in candidates)
		{
			var sound:Sound = loadSoundCandidate(candidate);
			if (sound != null)
			{
				localTrackedAssets.push(candidate);
				return sound;
			}
		}
		return null;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
{
    key = Language.getFileTranslation('images/$key') + '.png';
    
    // 关键修改：如果当前有模组目录，使用模组隔离的缓存键
    var cacheKey = key;
    #if MODS_ALLOWED
    if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && Mods.currentModDirectory != "base")
    {
        cacheKey = Mods.currentModDirectory + ":" + key;
    }
    #end

    if (currentContentRoot != null && currentContentRoot.length > 0)
    {
        var level:String = (currentLevel != null && currentLevel.length > 0) ? currentLevel : 'shared';
        cacheKey = '$cacheKey|$currentContentRoot/$level|${currentContentDependencyRoots.join(":")}';
    }
    
    // 检查全局缓存（使用模组隔离的键）
    if (currentTrackedAssets.exists(cacheKey))
    {
        localTrackedAssets.push(cacheKey);
        return currentTrackedAssets.get(cacheKey);
    }
    
    // 加载位图
    var bitmap:BitmapData = null;
    var file:String = getPath(key, IMAGE, parentFolder, true);
    
    #if MODS_ALLOWED
    if (FileSystem.exists(file))
        bitmap = BitmapData.fromFile(file);
    else #end if (OpenFlAssets.exists(file, IMAGE))
        bitmap = OpenFlAssets.getBitmapData(file);
    
    if (bitmap == null)
    {
        trace('Bitmap not found: $file | key: $key');
        return null;
    }
    
    if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
    {
        bitmap.lock();
        if (bitmap.__texture == null)
        {
            bitmap.image.premultiplied = true;
            bitmap.getTexture(FlxG.stage.context3D);
        }
        bitmap.getSurface();
        bitmap.disposeImage();
        bitmap.image.data = null;
        bitmap.image = null;
        bitmap.readable = true;
    }
    
    var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, cacheKey);
    graph.persist = true;
    graph.destroyOnNoUse = false;
    
    currentTrackedAssets.set(cacheKey, graph);
    localTrackedAssets.push(cacheKey);
    return graph;
}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else #end if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				trace('Bitmap not found: $file | key: $key');
				return null;
			}
		}

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		var path:String = getPath(key, TEXT, !ignoreMods);
		#if sys
		return (FileSystem.exists(path)) ? File.getContent(path) : null;
		#else
		return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
		#end
	}

	/**
	 * 解析字体路径。
	 * @param noTranslate true = 走"游戏内通道"：不查语言翻译表，直接用原始 key 查 mod。
	 *                    mod 查询必须带 `fonts/` 前缀（modFolders 认的是带前缀的 key），漏了就查不到 mod。
	 */
	inline static public function font(key:String, ?noTranslate:Bool = false)
	{
		var folderKey:String = noTranslate ? 'fonts/$key' : Language.getFileTranslation('fonts/$key');
		#if MODS_ALLOWED
		var file:String = modFolders(folderKey);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
	{
		#if MODS_ALLOWED
		if(!ignoreMods)
		{
			var modKey:String = key;
			if(parentFolder == 'songs') modKey = 'songs/$key';

			for(mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$modKey')))
					return true;

			if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + modKey)) || FileSystem.exists(mods(modKey)))
				return true;
		}
		#end
		var resolved:String = getPath(key, type, parentFolder, false);
		#if sys
		// 内容包是运行时磁盘资源、不在编译期 assets 清单里，OpenFlAssets.exists 查不到。
		if (FileSystem.exists(resolved)) return true;
		#end
		return OpenFlAssets.exists(resolved);
	}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
		if(OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
		{
			#if MODS_ALLOWED
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
			#else
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			#end
		}
		else
		{
			var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
			if(OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
			{
				#if MODS_ALLOWED
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
				#else
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				#end
			}
		}
		return getPackerAtlas(key, parentFolder);
	}
	
	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
		if(keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if(extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	inline static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		if(key.contains('psychic')) trace(key, parentFolder, allowGPU);
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var xmlExists:Bool = false;

		var xml:String = modsXml(key);
		if(FileSystem.exists(xml)) xmlExists = true;

		return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder));
		#end
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var txtExists:Bool = false;
		
		var txt:String = modsTxt(key);
		if(FileSystem.exists(txt)) txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? File.getContent(txt) : getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if(FileSystem.exists(json)) jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? File.getContent(json) : getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder));
		#end
	}

	inline static public function formatToSongPath(path:String) {
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	/** Content 体系根目录，与 mods/ 同级。三类内容（VanillaSongs / CustomCharts / NMVMODS）都在这里。 */
	public static final CONTENT_ROOT:String = 'content';
	/** content 下「自定义谱面」这一大类的目录名。 */
	public static final CUSTOM_CHART_GROUP:String = 'CustomCharts';
	/** 自定义谱面根目录，位于 Content 体系下。 */
	public static final CHART_ROOT:String = CONTENT_ROOT + '/' + CUSTOM_CHART_GROUP;
	public static var currentChartCategory:String = null;
	public static var currentChartDirectory:String = null;
	public static var currentChartAudioSuffix:String = null;
	public static var currentChartHasVSliceMetadata:Bool = false;
	/**
	 * 内容包资源根（相对仓库根），如 content/VanillaSongs/Erect。
	 * 非空时 getPath() 会优先在这里找资源（舞台 json / 角色 json / 图片 / events 等），
	 * 找不到再落回 assets/ —— 加性回退、不排他，所以舞台类里混用的 base 资源仍能命中。
	 */
	public static var currentContentRoot:String = null;
	/**
	 * 当前内容包的变体标识（Pico / Erect…）；无变体为 null。
	 * 变体包（如 PicoMix）的难度表是标准档位 Easy/Normal/Hard，变体只在这里表达：
	 * 谱面文件名走 <歌>-<变体>-<档位>.json，音轨目录走 songs/<歌>-<变体>/。
	 * 跟着 currentContentRoot 一起写 —— 只看资源根的调用方（回放）也能推出变体。
	 */
	public static var currentContentVariant:String = null;
	public static var currentContentDependencyRoots:Array<String> = [];
	/** 当前谱面 metadata 里的曲师 / 谱师（content 谱面加载时写入，暂停界面取数用）。 */
	public static var currentChartMetaArtist:String = null;
	public static var currentChartMetaCharter:String = null;

	#if sys
	static function loadContentDependencies(root:String):Array<String>
	{
		var result:Array<String> = [];
		if (root == null || root.length == 0) return result;
		var manifest:String = '$root/dependencies.json';
		if (!FileSystem.exists(manifest)) return result;
		try
		{
			var data:Dynamic = Json.parse(File.getContent(manifest));
			var names:Dynamic = Reflect.field(data, 'dependencies');
			if (!Std.isOfType(names, Array)) return result;
			for (name in (cast names:Array<Dynamic>))
			{
				if (!Std.isOfType(name, String) || !~/^[A-Za-z0-9_-]+$/.match(name)) continue;
				var dependency:String = 'content/VanillaSongs/$name';
				if (FileSystem.isDirectory(dependency)) result.push(dependency);
			}
		}
		catch (e:Dynamic) {}
		return result;
	}
	#end

	/**
	 * 一次性写入整套自定义谱面上下文。
	 * 这些字段必须一起改：分散赋值很容易漏项，把上一首的残留（尤其 hasVSlice / audioSuffix）带到下一首。
	 */
	public static function setChartContext(category:String, directory:String, hasVSlice:Bool = false, audioSuffix:String = null,
		contentRoot:String = null, metaArtist:String = null, metaCharter:String = null,
		variant:String = null):Void
	{
		currentChartCategory = (category != null && category.length > 0) ? category : null;
		currentChartDirectory = (directory != null && directory.length > 0) ? directory : null;
		currentChartHasVSliceMetadata = hasVSlice;
		currentChartAudioSuffix = audioSuffix;
		setContentRoot(contentRoot, variant);
		currentChartMetaArtist = metaArtist;
		currentChartMetaCharter = metaCharter;
	}

	/**
	 * 写入内容包资源根，并同步它的变体标识。
	 * variant 传空时按资源根反查周定义（同一包内变体唯一）—— 只拿到 contentRoot
	 * 的调用方（回放加载、加载器）因此也能推出变体，不用到处传参。
	 */
	/**
	 * Editor "browsing" mode has no currentContentRoot; find which content pack
	 * (content/VanillaSongs/<pack>/shared) actually contains relPath, so editors can
	 * temporarily switch into that pack context before loading a content-pack asset.
	 */
	public static function findContentRootForFile(relPath:String):String
	{
		#if sys
		var vanillaRoot:String = 'content/VanillaSongs';
		if (FileSystem.exists(vanillaRoot))
		{
			for (pack in FileSystem.readDirectory(vanillaRoot))
			{
				var candidate:String = vanillaRoot + '/' + pack + '/shared/' + relPath;
				if (FileSystem.exists(candidate))
					return vanillaRoot + '/' + pack;
			}
		}
		#end
		return null;
	}

	public static function setContentRoot(root:String, variant:String = null):Void
	{
		currentContentRoot = (root != null && root.length > 0) ? root : null;
		#if sys
		currentContentDependencyRoots = loadContentDependencies(currentContentRoot);
		#else
		currentContentDependencyRoots = [];
		#end

		var resolved:String = (variant != null && variant.length > 0) ? variant : null;
		if (resolved == null && currentContentRoot != null)
			resolved = WeekData.getVariantForContentRoot(currentContentRoot);
		currentContentVariant = resolved;
	}

	/**
	 * 分类是不是「自定义谱面」。
	 * content 模式下只有 CustomCharts 算自定义谱面；VanillaSongs / NMVMODS 是内容包，不算。
	 * 必须看分类路径而不是 currentContentRoot —— 浏览态还没选歌，currentContentRoot 是空的。
	 */
	public static function isCustomChartCategory(?category:String = null):Bool
	{
		var cat:String = (category != null && category.length > 0) ? category : currentChartCategory;
		if (cat == null || cat.length == 0) return false;
		if (cat == 'custom') return true;   // 「全部自定义谱面」聚合伪分类
		return cat == CUSTOM_CHART_GROUP || cat.indexOf(CUSTOM_CHART_GROUP + '/') == 0;
	}

	#if sys
	/**
	 * 确保 content 下的自定义谱面目录存在，用户可直接往里放谱面。
	 * v_slice 是编辑器「从 content 打开谱面」对话框用的默认子分类。
	 */
	public static function ensureContentDirs():Void
	{
		// 顺序不能换：createDirectory 不递归，父目录必须先存在。
		for (dir in [CONTENT_ROOT, CHART_ROOT, CHART_ROOT + '/v_slice'])
		{
			try
			{
				if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			}
			catch (e:Dynamic) {}
		}
	}
	#end

	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true)
	{
		var file:String = getPath(Language.getFileTranslation(key) + '.$SOUND_EXT', SOUND, path, modsAllowed);

		//trace('precaching sound: $file');
		if(!currentTrackedSounds.exists(file))
		{
			#if sys
			if(FileSystem.exists(file))
				currentTrackedSounds.set(file, Sound.fromFile(file));
			#else
			if(OpenFlAssets.exists(file, SOUND))
				currentTrackedSounds.set(file, OpenFlAssets.getSound(file));
			#end
			else if(beepOnNull)
			{
				trace('SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
				return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
		return 'mods/' + key;

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	static public function modFolders(key:String)
	{
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		for(mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}
		return 'mods/' + key;
	}
	#end

	#if flxanimate
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson = false;
		var changedAtlasJson = false;
		var changedImage = false;
		
		if(spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = File.getContent(spriteJson);
		}

		if(animationJson != null) 
		{
			changedAnimJson = true;
			animationJson = File.getContent(animationJson);
		}

		// is folder or image path
		if(Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;
			for (i in 0...10)
			{
				var st:String = '$i';
				if(i == 0) st = '';

				if(!changedAtlasJson)
				{
					spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
					if(spriteJson != null)
					{
						//trace('found Sprite Json');
						changedImage = true;
						changedAtlasJson = true;
						folderOrImg = image('$originalPath/spritemap$st');
						break;
					}
				}
				else if(fileExists('images/$originalPath/spritemap$st.png', IMAGE))
				{
					//trace('found Sprite PNG');
					changedImage = true;
					folderOrImg = image('$originalPath/spritemap$st');
					break;
				}
			}

			if(!changedImage)
			{
				//trace('Changing folderOrImg to FlxGraphic');
				changedImage = true;
				folderOrImg = image(originalPath);
			}

			if(!changedAnimJson)
			{
				//trace('found Animation Json');
				changedAnimJson = true;
				animationJson = getTextFromFile('images/$originalPath/Animation.json');
			}
		}

		//trace(folderOrImg);
		//trace(spriteJson);
		//trace(animationJson);
		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
	}
	#end
}
