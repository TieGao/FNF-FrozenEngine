package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
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
		releaseUnusedTrackedAssets();
		flushReleasedGraphics();
		destroyedSinceGc = 0;

		if (ClientPrefs.data.frequentGC)
		{
			// Impostor 的做法（Advanced 里的「Frequent GC」，默认关）：full GC 之后再 compact。
			// hxcpp 的 Gc.compact() 就是「反复 full collect 直到堆不再缩小」，只有这样才能把
			// 贴图 ByteArray 释放掉的那几百 MB 真正还给系统（单纯 System.gc() 之后 RSS 往往纹丝不动）。
			#if cpp
			cpp.vm.Gc.compact();
			#else
			System.gc();
			#end
		}
		else System.gc();
	}

	// ---------- 资源记账 / 释放 ----------
	//
	// 旧实现是「硬销毁 + 只增不减的本地记账表」：销毁不看 useCount，存活判定又永远为真
	// （该表只在 clearStoredMemory 末尾清空），所以只能在 PlayState 里整个禁用（见
	// docs/memory-optimization-handover.md §4）。现在拆成三件事：
	//   1. 记账 = key -> 代际（哪一代被请求过），每次 clearStoredMemory 递增；
	//   2. 释放 = releaseGraphic()：useCount 归零才真销毁，否则排队等下一次 flush；
	//   3. 销毁 = destroyGraphic()：唯一出口，先 dispose GL 纹理再摘缓存。

	/** 资源代际：每次 clearStoredMemory() 递增，用来判断「这一代还用过它没有」。 */
	public static var assetEpoch(default, null):Int = 0;

	/** key -> 最后一次被请求的代际（贴图与声音共用一套记账）。 */
	static var trackedEpochs:Map<String, Int> = new Map();

	/** 已请求释放、但还有对象引用（useCount > 0）的图，等引用掉光再销毁。 */
	static var pendingReleases:Array<FlxGraphic> = [];

	/** 自上次 GC 以来真正销毁掉的贴图张数：用来决定切歌时要不要补一次 full GC。 */
	static var destroyedSinceGc:Int = 0;

	/**
	 * 预加载的临时引用：LoadingState 预载完就 +1，撑过紧接着那次 clearStoredMemory 的释放。
	 * 否则「已经解码好、但角色还没接管」（useCount 还是 0）的图会在进 PlayState 时被当成垃圾收掉，
	 * 预加载等于白做。
	 */
	static var pinnedGraphics:Array<FlxGraphic> = [];

	/** 预加载的声音 key：同理撑过紧接着那次清理，否则预载完进 PlayState 就被清掉、白解一遍。 */
	static var pinnedSounds:Array<String> = [];

	/** 标记该 key 在「当前代」被请求过（贴图命中、新加载、声音加载都要走这里）。 */
	public static function markAssetUsed(key:String):Void
	{
		trackedEpochs.set(key, assetEpoch);
	}

	/** 丢掉某个 key 的记账（编辑器换歌时手动清声音缓存用）。 */
	public static function forgetAsset(key:String):Void
	{
		trackedEpochs.remove(key);
	}

	static inline function isCurrentAsset(key:String):Bool
	{
		return trackedEpochs.exists(key) && trackedEpochs.get(key) == assetEpoch;
	}

	/** 给预加载的图加一道临时引用（重复 pin 只算一次，避免和 unpin 配不上）。 */
	public static function pinGraphic(graphic:FlxGraphic):Void
	{
		if (graphic == null || graphic.isDestroyed || pinnedGraphics.contains(graphic))
			return;
		pinnedGraphics.push(graphic);
		graphic.incrementUseCount();
	}

	/** 给预加载的声音加一道保护（重复 pin 无害）。 */
	public static function pinSound(key:String):Void
	{
		if (key != null && !pinnedSounds.contains(key))
			pinnedSounds.push(key);
	}

	/** 放下所有预加载临时引用。**不要**在这之后立刻 flush，否则刚预载的图会被当场收掉。 */
	public static function unpinGraphics():Void
	{
		for (graphic in pinnedGraphics)
		{
			if (graphic != null && !graphic.isDestroyed)
				graphic.decrementUseCount();
		}
		pinnedGraphics = [];
	}

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// 新一代从这里开始：上一代请求过的东西都算「待释放候选」
		assetEpoch++;

		// FlxG.bitmap 里不属于 Paths 记账的图（makeGraphic / FlxG.bitmap.create 现画的）：
		// 有 sprite 还在用就留到下一次，别在别人的 update/draw 中间把它抽掉。
		// 先把 key 拷出来：releaseGraphic 失败路径会改 _cache。
		var cacheKeys:Array<String> = [];
		for (key in FlxG.bitmap._cache.keys())
			cacheKeys.push(key);
		for (key in cacheKeys)
		{
			if (!currentTrackedAssets.exists(key))
				releaseGraphic(FlxG.bitmap.get(key));
		}

		releaseUnusedTrackedAssets();

		// clear all sounds that are cached
		var soundKeys:Array<String> = [];
		for (key in currentTrackedSounds.keys())
			soundKeys.push(key);
		for (key in soundKeys)
		{
			var asset:Sound = currentTrackedSounds.get(key);
			if (!isCurrentAsset(key) && !pinnedSounds.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
				trackedEpochs.remove(key);
			}
		}

		flushReleasedGraphics();
		// 预加载引用必须最后放：放完不再 flush，让它们活到下一次切场景，
		// 这中间真正用到它们的角色/舞台才能把引用接过去。
		unpinGraphics();
		pinnedSounds = [];
		pruneTrackedEpochs();
		#if !html5 openfl.Assets.cache.clear("songs"); #end

		// 释放完立刻回收：hxcpp 的大对象块要等 full GC 才还给系统，否则「已经销毁」的贴图
		// 还挂在进程工作集里，RSS 看起来只涨不跌。只有真销毁过东西才付这次 GC 的钱。
		if (destroyedSinceGc > 0)
		{
			destroyedSinceGc = 0;
			// 频繁 GC 是 Advanced 里的可选项（默认关）：不做的话释放掉的贴图要等下一次
			// clearUnusedMemory 的 System.gc() 才会真正还给系统。
			if (ClientPrefs.data.frequentGC) System.gc();
		}
	}

	/**
	 * 释放「这一代没被请求过、且没有对象引用」的图。
	 * 有引用的进待释放队列 —— 旧实现在这里直接 destroy，会抽掉精灵池/角色还攥着的图集
	 * （PlayState 里那条禁用注释说的就是这件事）。
	 */
	static function releaseUnusedTrackedAssets():Int
	{
		var keys:Array<String> = [];
		for (key in currentTrackedAssets.keys())
			keys.push(key);

		var count:Int = 0;
		for (key in keys)
		{
			if (dumpExclusions.contains(key) || isCurrentAsset(key))
				continue;

			var graphic:FlxGraphic = currentTrackedAssets.get(key);
			// 本次刚预载进来、还没被任何 sprite 接管的图：算作这一代，留着给角色/舞台用
			if (graphic != null && pinnedGraphics.contains(graphic))
			{
				markAssetUsed(key);
				continue;
			}

			currentTrackedAssets.remove(key);
			releaseGraphic(graphic);
			count++;
		}
		return count;
	}

	/** 记账表别无限涨：只保留还可能被重新请求到的 key。 */
	static function pruneTrackedEpochs():Void
	{
		var stale:Array<String> = [];
		for (key => epoch in trackedEpochs)
		{
			if (epoch >= assetEpoch - 1) continue;
			if (currentTrackedAssets.exists(key) || currentTrackedSounds.exists(key)) continue;
			stale.push(key);
		}
		for (key in stale)
			trackedEpochs.remove(key);
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

		var trackedKeys:Array<String> = [];
		for (key in currentTrackedAssets.keys())
			trackedKeys.push(key);

		for (key in trackedKeys)
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					releaseGraphic(graphic); // 延迟释放：别的地方还在用就先留着
					//trace('deleted $key');
				}
			}
		}
	}

	/**
	 * 请求释放一张图：没有对象引用（useCount <= 0）就立刻销毁，否则排队，
	 * 等最后一个引用消失后的下一次 flush 再收。
	 *
	 * 为什么不能直接 destroy：FlxGraphic.destroy() 会把 frames.frames 置 null，
	 * 而精灵池 / 角色对象可能还攥着这套 frames（见 objects/Note.hx 的 prepareForPool）。
	 * 为什么不交给 flixel 的 destroyOnNoUse：那条销毁路径走 BitmapData.dispose()，
	 * 里面 gl.deleteTexture 是注释掉的（openfl 9.6），显存会漏 —— 销毁必须统一走 destroyGraphic()。
	 */
	public static function releaseGraphic(graphic:FlxGraphic):Void
	{
		if (graphic == null || graphic.isDestroyed)
			return;

		if (graphic.useCount <= 0)
		{
			destroyGraphic(graphic);
			return;
		}

		if (!pendingReleases.contains(graphic))
			pendingReleases.push(graphic);
	}

	/** 把待释放队列里引用已经掉光的图真正销毁，返回本次销毁张数。 */
	public static function flushReleasedGraphics():Int
	{
		if (pendingReleases.length < 1)
			return 0;

		// 先摘下来再遍历：destroyGraphic 会顺手把这张图从队列里删掉，
		// 边遍历边改会让后面几张被漏掉（漏掉就永远回收不到）。
		var snapshot:Array<FlxGraphic> = pendingReleases.copy();
		pendingReleases = [];

		var destroyed:Int = 0;
		for (graphic in snapshot)
		{
			if (graphic == null || graphic.isDestroyed)
				continue;
			if (graphic.useCount <= 0)
			{
				destroyGraphic(graphic);
				destroyed++;
			}
			else pendingReleases.push(graphic);
		}
		return destroyed;
	}

	/** 排队中、还没销毁的张数（MemoryStats 观测用）。 */
	public static function pendingReleaseCount():Int
	{
		return pendingReleases.length;
	}

	/** 待释放队列的快照（只读，给内存报告列明细用：谁还攥着它）。 */
	public static function pendingReleaseGraphics():Array<FlxGraphic>
	{
		return pendingReleases.copy();
	}

	/**
	 * 释放一张图自己的像素 + 显存，但**不**动 FlxG.bitmap 的登记。
	 * FlxText 那种「建完就扔」的临时图用它：openfl 的 BitmapData.dispose() 不删 GL 纹理，
	 * 只调 dispose() 的话每建一次文本就漏一张纹理。
	 */
	public static function disposeGraphicData(graphic:FlxGraphic):Void
	{
		if (graphic == null || graphic.isDestroyed || graphic.bitmap == null)
			return;
		if (graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		graphic.bitmap.dispose();
	}

	/**
	 * 唯一的销毁出口。openfl 的 BitmapData.dispose() 只把 __texture 置 null，
	 * 真正的 gl.deleteTexture 在源码里是注释掉的 → 不在这里显式 dispose，显存就漏。
	 */
	static function destroyGraphic(graphic:FlxGraphic):Void
	{
		if (graphic == null || graphic.isDestroyed)
			return;

		// free some gpu memory
		if (graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();

		var key:String = graphic.key;
		if (key != null)
		{
			if (currentTrackedAssets.get(key) == graphic)
				currentTrackedAssets.remove(key);
			trackedEpochs.remove(key);
		}
		if (pendingReleases.contains(graphic))
			pendingReleases.remove(graphic);

		destroyedSinceGc++;
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
			if (assetExists(levelPath, type))
				return levelPath;
		}
		return getSharedPath(file);
	}

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	/**
	 * 资源是否存在：磁盘优先，其次编译期资源索引。
	 * lime 的 Assets 是构建期快照，外挂目录（content/、外部导入的 assets/）里的文件不在里面，
	 * 所以存在性判断必须先问磁盘，索引只当打包进二进制的兜底。
	 */
	public static function assetExists(path:String, ?type:AssetType = TEXT):Bool
	{
		if (path == null || path.length == 0) return false;
		#if sys
		if (FileSystem.exists(path)) return true;
		#end
		return OpenFlAssets.exists(path, type);
	}

	/** 读文本：磁盘优先，其次编译期资源索引。 */
	public static function assetText(path:String):String
	{
		if (path == null || path.length == 0) return null;
		#if sys
		if (FileSystem.exists(path))
		{
			try return File.getContent(path) catch (e:Dynamic) {}
		}
		#end
		return OpenFlAssets.exists(path, TEXT) ? OpenFlAssets.getText(path) : null;
	}

	/** 读字节：磁盘优先，其次编译期资源索引。 */
	public static function assetBytes(path:String):haxe.io.Bytes
	{
		if (path == null || path.length == 0) return null;
		#if sys
		if (FileSystem.exists(path))
		{
			try return File.getBytes(path) catch (e:Dynamic) {}
		}
		#end
		return OpenFlAssets.exists(path, BINARY) ? OpenFlAssets.getBytes(path) : null;
	}

	/**
	 * 按 getPath() 的实际查找顺序列出「资源根」（不带结尾斜杠）：
	 * `mods/<当前mod>` → `mods/<全局mod…>` → `content/<包>{/<level>|/shared}`（含依赖包）→ `assets/<level>` → `assets/shared`。
	 * 用于「同一个资源键在不同根里格式不同」的场景（角色 image：sparrow 散图 vs flxanimate 图集），
	 * 只有知道谁先提供资源，才能判断该用哪种格式。
	 * @param parentfolder 与 getPath 同义：非空时直接拼这个子目录，不再套 level/shared。
	 */
	public static function getResourceRoots(?parentfolder:String = null):Array<String>
	{
		var roots:Array<String> = [];
		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			roots.push(mods(Mods.currentModDirectory));
		for (mod in Mods.getGlobalMods())
		{
			var root:String = mods(mod);
			if (!roots.contains(root)) roots.push(root);
		}
		#end

		if (currentContentRoot != null && currentContentRoot.length > 0)
		{
			var packs:Array<String> = [currentContentRoot];
			for (dependencyRoot in currentContentDependencyRoots) packs.push(dependencyRoot);
			for (pack in packs)
			{
				if (parentfolder != null) roots.push('$pack/$parentfolder');
				else
				{
					if (currentLevel != null && currentLevel != 'shared') roots.push('$pack/$currentLevel');
					roots.push('$pack/shared');
				}
			}
		}

		if (parentfolder != null) roots.push('assets/$parentfolder');
		else
		{
			if (currentLevel != null && currentLevel != 'shared') roots.push('assets/$currentLevel');
			roots.push('assets/shared');
		}
		return roots;
	}

	/**
	 * 从资源路径反推它所属的资源根：`<root>/characters/x.json` → `<root>`。
	 * 认不出（相对路径 / 层级不全）时返回 null。
	 */
	public static function getRootOf(path:String, folder:String):String
	{
		if (path == null || folder == null) return null;
		var needle:String = '/' + folder + '/';
		var idx:Int = path.lastIndexOf(needle);
		if (idx < 1) return null;
		return path.substr(0, idx);
	}

	/** 某个资源根里有没有这个 image 的散图（sparrow / packer / texturepacker 都算）。 */
	static function hasSparrowImage(root:String, key:String):Bool
	{
		return assetExists('$root/images/$key.png', IMAGE)
			|| assetExists('$root/images/$key.xml', TEXT)
			|| assetExists('$root/images/$key.txt', TEXT)
			|| assetExists('$root/images/$key.json', TEXT);
	}

	/**
	 * 角色的 `image` 是否为 flxanimate 图集（文件夹形式，内含 Animation.json）。
	 *
	 * 不能直接用 `getPath('images/<image>/Animation.json')` 一票判定：getPath 是**全链回退**，
	 * mod 只提供同名 sparrow 散图（png+xml）时，它仍会一路回退到 content / assets 里的同名图集目录，
	 * 结果 mod 角色被 base 的 atlas 顶掉（`Erect Mode` 的 nene：json 走 assets 的 Nene.png/xml，
	 * 却被 PicoMix 的 characters/nene/Animation.json 判成图集，实机变成另一套角色）。
	 *
	 * 正确做法：先看**定义这个角色的那棵资源树**提供的是哪种格式（谁写 json 谁决定画法）；
	 * 那棵树自己不带图（mod 只写 json、美术沿用 base）时，才回到全局链 —— 此时只要有任何一根
	 * 提供散图就按 sparrow 算（图集是新机制，必须由定义方显式提供，不能被别人"顺手"命中）。
	 *
	 * @param characterJsonPath 角色 json 的已解析路径（`Paths.getPath('characters/x.json')` 的结果），可为空。
	 */
	public static function isAnimateAtlasImage(image:String, ?characterJsonPath:String):Bool
	{
		if (image == null) return false;
		var key:String = image.split(',')[0].trim(); // 多图集只按首个判定，图集和散图不可能混在同一个角色里
		if (key.length < 1) return false;

		var jsonRoot:String = getRootOf(characterJsonPath, 'characters');
		if (jsonRoot != null)
		{
			if (assetExists('$jsonRoot/images/$key/Animation.json', TEXT)) return true;
			if (hasSparrowImage(jsonRoot, key)) return false;
		}

		var roots:Array<String> = getResourceRoots();
		for (root in roots)
			if (hasSparrowImage(root, key)) return false;

		for (root in roots)
			if (assetExists('$root/images/$key/Animation.json', TEXT)) return true;

		return false;
	}

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

	/** 视频扩展名候选（libvlc 按内容探测 demux，这些格式都能播）。 */
	public static var VIDEO_EXTS:Array<String> = ['mp4', 'mkv', 'webm', 'ogv'];

	/** 视频候选目录：内容包 videos/ → 依赖包同式 → assets/videos（mods 最优先）。 */
	static public function video(key:String):String
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) return file;
		#end
		#if sys
		if (currentContentRoot != null && currentContentRoot.length > 0)
		{
			var packDirs:Array<String> = [currentContentRoot + '/videos'];
			for (dependencyRoot in currentContentDependencyRoots)
				packDirs.push(dependencyRoot + '/videos');
			for (dir in packDirs)
				for (ext in VIDEO_EXTS)
				{
					var candidate:String = '$dir/$key.$ext';
					if (FileSystem.exists(candidate)) return candidate;
				}
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
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
		// 只要有精确谱面目录就要走这段，分类名可以为空：编辑器从局内进来时只带目录不带分类，
		// 少了这段就只能按歌名去猜路径，自定义谱面（歌名≠目录名）必然找不到音轨。
		if ((chartCategory != null && chartCategory.length > 0) || (currentChartDirectory != null && currentChartDirectory.length > 0))
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
			// 数据包布局（charts/ + song/）：从 charts/ 里直接打开谱面时，音轨在上一级目录
			if (chartDir.endsWith('/charts')) chartDir = chartDir.substr(0, chartDir.length - 7);
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
			// 数据包布局（charts/ + song/）：音轨在歌目录的 song/ 子目录里
			candidates.push(chartDir + 'song/inst.ogg');
			candidates.push(chartDir + 'song/inst.mp3');
			candidates.push(chartDir + 'song/audio.ogg');
			candidates.push(chartDir + 'song/audio.mp3');
		}
		#end

		for (candidate in candidates)
		{
			var sound:Sound = loadSoundCandidate(candidate);
			if (sound != null)
			{
				markAssetUsed(candidate);
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
		// 与 inst() 同理：有精确目录就够了，分类名缺省时也要查谱面目录下的人声
		if ((chartCategory != null && chartCategory.length > 0) || (currentChartDirectory != null && currentChartDirectory.length > 0))
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
			// 数据包布局（charts/ + song/）：从 charts/ 里直接打开谱面时，音轨在上一级目录
			if (chartDir.endsWith('/charts')) chartDir = chartDir.substr(0, chartDir.length - 7);
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

			// 数据包布局（charts/ + song/）：人声在歌目录的 song/ 子目录里
			candidates.push(chartDir + 'song/' + voiceName.toLowerCase() + '.ogg');
			candidates.push(chartDir + 'song/' + voiceName.toLowerCase() + '.mp3');
			candidates.push(chartDir + 'song/voices.ogg');
			candidates.push(chartDir + 'song/voices.mp3');
			candidates.push(chartDir + 'song/vocals.ogg');
			candidates.push(chartDir + 'song/vocals.mp3');
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
				markAssetUsed(candidate);
				return sound;
			}
		}
		return null;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	/**
	 * 把图片键解析成「缓存键 + 实际文件」。
	 *
	 * 缓存键直接用 `getPath()` 解析出来的文件路径 —— 旧键是"查找上下文"
	 * （`<mod>:<key>|<contentRoot>/<level>|<依赖根>`），同一个文件换个入口、换个层级、
	 * 或者换条预加载路径就会算出不同的键，于是同一个文件被解码多份
	 * （Fatal Finale 实测：94~97 组、1.9~2.6GB）。
	 *
	 * 文件路径里已经包含 mod 目录 / 内容包 / 层级，天然唯一；找不到文件时退回旧键，
	 * 保持原有的报错与回退行为不变。
	 */
	public static function resolveImage(fullKey:String, ?parentFolder:String):ImageResolve
	{
		var file:String = getPath(fullKey, IMAGE, parentFolder, true);
		#if sys
		if (file != null && FileSystem.exists(file))
			return {key: file, file: file};
		#end
		return {key: contextCacheKey(fullKey), file: file};
	}

	/** 旧式上下文缓存键，只在文件解析失败时兜底 */
	static function contextCacheKey(key:String):String
	{
		var cacheKey:String = key;
		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && Mods.currentModDirectory != "base")
			cacheKey = Mods.currentModDirectory + ":" + key;
		#end

		if (currentContentRoot != null && currentContentRoot.length > 0)
		{
			var level:String = (currentLevel != null && currentLevel.length > 0) ? currentLevel : 'shared';
			cacheKey = '$cacheKey|$currentContentRoot/$level|${currentContentDependencyRoots.join(":")}';
		}
		return cacheKey;
	}

	/**
	 * 开了「GPU Caching」时把 CPU 像素标记为不可读：openfl 在第一次 `getTexture()` 上传后会自己把
	 * `image` / `__surface` 置 null。**不要**手动 `image = null` 再 `readable = true`——
	 * 那样会留下悬垂的 cairo surface（`getSurface()` 只拿裸指针、不拷贝），
	 * 并且让 `getPixel32` 落到空引用上。
	 */
	static inline function disposeCPUImage(bitmap:BitmapData):Void
	{
		if (bitmap != null && bitmap.image != null)
			bitmap.disposeImage();
	}

	/**
	 * 把一张图的像素当场交给 GPU，并丢掉 CPU 副本（`gpuCaching = full` 用）。
	 *
	 * 走 openfl 自己的上传路径：先 `disposeImage()` 把 readable 置 false，再 `getTexture()` 让它
	 * 建纹理、premultiply 上传；末尾的 `if (!readable && image != null)` 会由 openfl 自己把 `image` 置 null。
	 *
	 * **不要**改回 createRectangleTexture + uploadFromBitmapData + BitmapData.fromTexture：
	 * ① 第 4 参 `optimizeForRenderToTexture` 传 true 会给每张图多建 FBO + DEPTH24_STENCIL8
	 *    renderbuffer（≈ +100% 显存），openfl 自己传的是 false；
	 * ② `fromTexture` 内部先 `new BitmapData(w, h, true, 0)` 再丢弃，每张图多一份 w*h*4 临时分配；
	 * ③ 新建的 BitmapData 与任何 clone 共享同一张纹理，所有权语义脆弱（改副本会写穿原图）。
	 *
	 * 必须在**主线程**调用（GL 上下文不是线程安全的）。拿不到 context3D 时退化成「只标记不可读」
	 * （readable=false 但 image 还在），不影响正确性，只是没省到内存。
	 */
	static function makeHardwareOnly(bitmap:BitmapData):BitmapData
	{
		if (bitmap == null || bitmap.image == null)
			return bitmap;

		try
		{
			var stage = FlxG.stage;
			var context = (stage != null) ? stage.context3D : null;
			if (context != null)
			{
				bitmap.disposeImage();
				// 上传成功后 openfl 自己把 image / __surface 置 null，CPU 像素当场释放
				bitmap.getTexture(context);
			}
		}
		catch (e:Dynamic)
		{
			// 上传失败：最坏停在「readable=false + image 还在」，不影响绘制
		}

		return bitmap;
	}

	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		key = Language.getFileTranslation('images/$key') + '.png';

		var resolved = resolveImage(key, parentFolder);
		var cacheKey:String = resolved.key;
		var file:String = resolved.file;

		// 检查全局缓存（键 = 实际文件路径）
		if (currentTrackedAssets.exists(cacheKey))
		{
			var cached:FlxGraphic = currentTrackedAssets.get(cacheKey);
			if (cached != null && !cached.isDestroyed)
			{
				// 预载路径现在传 allowGPU=false（见 LoadingState.checkLoaded），所以「模式」要在这里补：
				//   full → 这一局真要用它，就地转显存（之前是预载即传，会把 6GB 卡挤爆）；
				//   auto → 补一次 disposeImage()，否则预载的图永远 readable=true，
				//          首次绘制上传后也不会丢 CPU 副本，白白双份。
				if (allowGPU && cached.bitmap != null)
				{
					if (ClientPrefs.data.gpuCaching == 'full')
					{
						if (cached.bitmap.image != null && cached.bitmap.__texture == null)
							makeHardwareOnly(cached.bitmap);
					}
					else if (ClientPrefs.data.gpuCaching == 'auto')
						disposeCPUImage(cached.bitmap);
				}

				markAssetUsed(cacheKey);
				return cached;
			}
			currentTrackedAssets.remove(cacheKey);
		}

		// 被释放过、但还留在 flixel 缓存里的同 key 图（说明还有别的对象在用）：直接接管，别再解码一份
		var reused:FlxGraphic = FlxG.bitmap.get(cacheKey);
		if (reused != null)
		{
			if (!reused.isDestroyed)
				return adoptGraphic(cacheKey, reused);
			FlxG.bitmap.remove(reused);
		}

		// 加载位图
		var bitmap:BitmapData = null;

		#if sys
		if (file != null && FileSystem.exists(file))
			bitmap = BitmapData.fromFile(file);
		else #end if (file != null && OpenFlAssets.exists(file, IMAGE))
			bitmap = OpenFlAssets.getBitmapData(file);

		if (bitmap == null)
		{
			trace('Bitmap not found: $file | key: $key');
			return null;
		}

		if (allowGPU)
		{
			if (ClientPrefs.data.gpuCaching == 'full') bitmap = makeHardwareOnly(bitmap);
			else if (ClientPrefs.data.gpuCaching == 'auto') disposeCPUImage(bitmap);
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, cacheKey);
		// persist 保持 true：销毁时机必须捏在 Paths 手里（destroyGraphic 会先 dispose GL 纹理）。
		// 交给 flixel 的 destroyOnNoUse / clearCache 销毁，显存不会跟着释放。
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(cacheKey, graph);
		markAssetUsed(cacheKey);
		return graph;
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		// key 可能是「图片键」（images/x.png），也可能已经是文件路径（ModsMenu / ModFolder 的图标）。
		// 与 image() 共用同一套解析，保证预加载写进去的键和运行期查的键是同一个。
		var cacheKey:String = key;
		var file:String = key;
		#if sys
		if (!FileSystem.exists(cacheKey))
		#end
		{
			var resolved = resolveImage(key, parentFolder);
			cacheKey = resolved.key;
			file = resolved.file;
		}

		if (bitmap == null)
		{
			// 同一个文件已经解过（被释放但还有引用 / 预加载先到）：接管，别再解一份
			var reused:FlxGraphic = FlxG.bitmap.get(cacheKey);
			if (reused != null)
			{
				if (!reused.isDestroyed)
					return adoptGraphic(cacheKey, reused);
				FlxG.bitmap.remove(reused);
			}

			#if sys
			if (file != null && FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else #end if (file != null && OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				trace('Bitmap not found: $file | key: $key');
				return null;
			}
		}

		// full 模式一次预载几十上百张图会全传显存（Fatal Finale 预载 8.88GB → 6GB 卡上会溢出），
		// 这是用户显式选的取舍；auto 模式只标记不可读，等首次绘制再丢 CPU 副本。
		if (allowGPU)
		{
			if (ClientPrefs.data.gpuCaching == 'full') bitmap = makeHardwareOnly(bitmap);
			else if (ClientPrefs.data.gpuCaching == 'auto') disposeCPUImage(bitmap);
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, cacheKey);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(cacheKey, graph);
		markAssetUsed(cacheKey);
		return graph;
	}

	/** 接管一张已存在的图（被释放过 / 预加载先到 / 别处缓存的同 key），重新纳入 Paths 记账。 */
	static function adoptGraphic(key:String, graphic:FlxGraphic):FlxGraphic
	{
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		if (pendingReleases.contains(graphic))
			pendingReleases.remove(graphic);
		currentTrackedAssets.set(key, graphic);
		markAssetUsed(key);
		return graphic;
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		return assetText(getPath(key, TEXT, null, !ignoreMods));
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
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		var xmlText:String = assetText(getPath('images/$key.xml', TEXT, parentFolder, true));
		if (xmlText != null)
		{
			var frames:FlxAtlasFrames = FlxAtlasFrames.fromSparrow(imageLoaded, xmlText);
			return frames;
		}

		var jsonText:String = assetText(getPath('images/$key.json', TEXT, parentFolder, true));
		if (jsonText != null)
		{
			var frames:FlxAtlasFrames = FlxAtlasFrames.fromTexturePackerJson(imageLoaded, jsonText);
			return frames;
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
		var xmlText:String = assetText(getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder));
		if (xmlText == null)
		{
			FlxG.log.error('Atlas XML not found: images/$key.xml (parent=$parentFolder)');
			return null;
		}
		var frames:FlxAtlasFrames = FlxAtlasFrames.fromSparrow(imageLoaded, xmlText);
		return frames;
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		var txtText:String = assetText(getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder));
		if (txtText == null)
		{
			FlxG.log.error('Atlas TXT not found: images/$key.txt (parent=$parentFolder)');
			return null;
		}
		var frames:FlxAtlasFrames = FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, txtText);
		return frames;
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		var jsonText:String = assetText(getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder));
		if (jsonText == null)
		{
			FlxG.log.error('Atlas JSON not found: images/$key.json (parent=$parentFolder)');
			return null;
		}
		var frames:FlxAtlasFrames = FlxAtlasFrames.fromTexturePackerJson(imageLoaded, jsonText);
		return frames;
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

	/**
	 * 启动时打一行资源环境，用于定位「文件明明在磁盘上、游戏却认不到」。
	 * manifest 是 lime 的构建期索引：条目数明显少于磁盘文件数，就说明构建时没打包进来，
	 * 运行期只能走磁盘通道（这也是外挂资源唯一能生效的通道）。
	 */
	public static function logAssetEnvironment():Void
	{
		var cwd:String = '';
		#if sys
		try cwd = Sys.getCwd() catch (e:Dynamic) {}
		#end

		var packs:Int = 0;
		#if sys
		var packsRoot:String = '$CONTENT_ROOT/VanillaSongs';
		if (FileSystem.exists(packsRoot))
		{
			try packs = FileSystem.readDirectory(packsRoot).length catch (e:Dynamic) {}
		}
		#end

		var manifest:Int = 0;
		try manifest = OpenFlAssets.list().length catch (e:Dynamic) {}

		trace('[assets] cwd=$cwd | content packs=$packs | manifest=$manifest entries');
	}

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
		markAssetUsed(file);
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

/** `resolveImage()` 的结果：`key` 是缓存键（通常是文件路径），`file` 是磁盘路径（找不到时为推测路径） */
typedef ImageResolve = {
	var key:String;
	var file:String;
}
