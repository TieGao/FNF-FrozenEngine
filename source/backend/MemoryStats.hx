package backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;

#if cpp
import cpp.vm.Gc;
#end

/**
 * 运行期内存观测（只读，不改任何缓存/生命周期）。
 *
 * 为什么需要它：`debug.FPSCounter` 里的 Memory 读的是
 * `Gc.memInfo64(MEM_INFO_USAGE)`，按 hxcpp 的定义那是「上一次 GC 时估算的活对象」，
 * 不含 native 分配、不含显存，也不含尚未回收的垃圾。贴图排查需要三组数：
 *
 *   1. GC 四个口径（usage / current / reserved / large）—— 判断是"真占用"还是"垃圾没回收"；
 *   2. 进程 RSS（Windows 工作集）—— 任务管理器里看到的那个数，含 native + 显存映射；
 *   3. 引擎自己追踪的贴图解码字节 —— 有多少像素缓冲还挂在 `Paths.currentTrackedAssets` 上。
 *
 * 用法（任意位置调用，不产生副作用）：
 *   trace(MemoryStats.summaryLine());
 *   MemoryStats.dumpReport();      // 写 logs/memory-<时间戳>.txt
 *
 * 注意：本类不主动调用 GC。需要回收时机由调用方决定（见报告 P2）。
 */
#if (cpp && windows)
// 注意：@:cppFileCode 是「类型级」元数据，挂在方法上会被 hxcpp 静默忽略（生成的 cpp 里看不到 include）。
// 这里用 GetProcessMemoryInfo，不直接写 K32：psapi.h 会按 NTDDI_VERSION 把它映射到 K32 或 psapi.dll，
// 显式链接 psapi.lib 后两种情况都能过（K32 走 kernel32 时多链一个 psapi.lib 也无害）。
@:cppFileCode('
#include <windows.h>
#include <psapi.h>
#include <dxgi.h>
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "dxgi.lib")
')
#end
@:access(openfl.display.BitmapData)
@:access(openfl.display3D.textures.TextureBase)
@:access(flixel.system.frontEnds.BitmapFrontEnd)
class MemoryStats
{
	/**
	 * 这张图是否真的还持有 GL 纹理。
	 *
	 * 不能只看 `__texture != null`：`TextureBase.dispose()` 只把 `__textureID` 置 null，
	 * `BitmapData.__texture` 字段本身还在 —— 用它统计会把已经释放的图继续算进显存。
	 */
	static inline function hasGpuTexture(bmp:BitmapData):Bool
	{
		return bmp != null && bmp.__texture != null && bmp.__texture.__textureID != null;
	}

	public static function gcUsage():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_USAGE);
		#else
		return 0;
		#end
	}

	/** 含未回收垃圾，通常会看到它在 usage 和 reserved 之间锯齿。 */
	public static function gcCurrent():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_CURRENT);
		#else
		return 0;
		#end
	}

	/** Immix 已向系统要到的块总量（近似 GC 堆的提交量）。 */
	public static function gcReserved():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_RESERVED);
		#else
		return 0;
		#end
	}

	/** 大对象池（> 半个 block 的对象，贴图 ByteArray 一般都在这里）。 */
	public static function gcLarge():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_LARGE);
		#else
		return 0;
		#end
	}

	/**
	 * 进程工作集（RSS），单位字节。
	 * 只有 Windows 走原生实现；其它平台返回 0（别拿它当跨平台指标）。
	 */
	public static function processRSS():Float
	{
		#if (cpp && windows)
		return getWindowsWorkingSet();
		#else
		return 0;
		#end
	}

	#if (cpp && windows)
	@:functionCode('
		PROCESS_MEMORY_COUNTERS_EX pmc;
		ZeroMemory(&pmc, sizeof(pmc));
		if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc)))
			return (double)pmc.WorkingSetSize;
		return 0.0;
	')
	static function getWindowsWorkingSet():Float
	{
		return 0;
	}
	#end

	#if (cpp && windows)
	/**
	 * 显卡的独占显存总量（字节）。走 DXGI（`IDXGIAdapter1::GetDesc1`），NVIDIA / AMD / Intel 通用。
	 *
	 * 为什么不用 openfl 的 `Context3D.totalGPUMemory`：那个只查 `NVX_gpu_memory_info`，
	 * 是 NVIDIA 专有扩展，AMD 上恒返回 0（`Context3D.hx:2804`）。我们要按显存分档，必须走系统 API。
	 */
	@:functionCode('
		IDXGIFactory1* factory = nullptr;
		if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory))) return 0.0;

		IDXGIAdapter1* adapter = nullptr;
		double best = 0.0;
		for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i)
		{
			DXGI_ADAPTER_DESC1 desc;
			if (SUCCEEDED(adapter->GetDesc1(&desc)) && !(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE))
			{
				double vram = (double)desc.DedicatedVideoMemory;
				if (vram > best) best = vram;
			}
			adapter->Release();
			adapter = nullptr;
		}

		factory->Release();
		return best;
	')
	static function getDedicatedVideoMemory():Float
	{
		return 0;
	}
	#end

	/** 显卡独占显存总量（字节）。非 Windows / 探测失败返回 0。结果缓存，DXGI 只查一次。 */
	public static function dedicatedVRAM():Float
	{
		#if (cpp && windows)
		if (__vramCache < 0)
			__vramCache = getDedicatedVideoMemory();
		return __vramCache;
		#else
		return 0;
		#end
	}

	#if (cpp && windows)
	/** DXGI 只查一次（枚举适配器有系统调用开销，而且显存总量不会变）。 */
	static var __vramCache:Float = -1;
	#end

	/**
	 * 自动分档的阈值：独占显存 >= 10GB 才认为"预载即上传"是安全的。
	 *
	 * 非 Windows 平台读不到显存（DXGI 是 Windows 专有），`dedicatedVRAM()` 恒返回 0，
	 * 于是 `auto` 一律退化为 `off` —— 要预载上传只能手动选 `on`。
	 */
	public static inline var PRELOAD_VRAM_THRESHOLD:Float = 10 * 1024 * 1024 * 1024;

	/**
	 * 预载阶段是否把贴图直接传进显存。
	 *
	 * - `on`：总是（大显存卡，进歌不用现传，代价是峰值高）；
	 * - `off`：从不（小显存卡，只在运行时第一次索取时上传）；
	 * - `auto`（默认）：显存 >= `PRELOAD_VRAM_THRESHOLD`(10GB) 时按 `on` 处理。
	 *
	 * 阈值取 10GB 而不是 8GB：Fatal Finale 这类 mod 预载就有 8.88GB，
	 * 8GB 卡上去会溢出到系统内存，反而比"运行时按需上传"更慢。
	 */
	public static function shouldPreloadToVRAM():Bool
	{
		var mode:String = ClientPrefs.data.preloadTextureToVRAM;
		if (mode == 'on') return true;
		if (mode == 'off') return false;
		return dedicatedVRAM() >= PRELOAD_VRAM_THRESHOLD;
	}

	/** 一张被追踪的贴图。cpu 是仍可读的像素缓冲，gpu 是估算的显存（BGRA8，无 mipmap）。 */
	public static function trackedTextures():Array<TextureEntry>
	{
		var result:Array<TextureEntry> = [];
		for (key in Paths.currentTrackedAssets.keys())
		{
			var graphic:FlxGraphic = Paths.currentTrackedAssets.get(key);
			// 已销毁的图 bitmap 会被置空，尺寸也归 0，别再算进统计
			if (graphic == null || graphic.isDestroyed || graphic.bitmap == null)
				continue;

			var bmp = graphic.bitmap;
			var bytes:Int = bmp.width * bmp.height * 4;
			// P1.5 之后，开了 GPU caching 的图是 `readable=false + image 还在`（等首次 getTexture 才释放），
			// 所以这里只认 image 是否存在，不看 readable，否则会把"还没上传"的 CPU 副本漏记成 0。
			var hasCPU:Bool = bmp.image != null;
			var hasGPU:Bool = hasGpuTexture(bmp);

			result.push({
				key: key,
				width: bmp.width,
				height: bmp.height,
				cpuBytes: hasCPU ? bytes : 0,
				gpuBytes: hasGPU ? bytes : 0,
				readable: bmp.readable
			});
		}
		return result;
	}

	/** 汇总：CPU/GPU 估算、条目数、FlxG.bitmap 缓存条目数。 */
	public static function totals():Totals
	{
		var entries = trackedTextures();
		var cpu:Float = 0;
		var gpu:Float = 0;

		for (e in entries)
		{
			cpu += e.cpuBytes;
			gpu += e.gpuBytes;
		}

		var cacheSize:Int = 0;
		if (FlxG.bitmap._cache != null)
			for (_ in FlxG.bitmap._cache.keys())
				cacheSize++;

		return {
			entries: entries.length,
			cpuBytes: cpu,
			gpuBytes: gpu,
			bitmapCacheSize: cacheSize,
			pending: Paths.pendingReleaseCount()
		};
	}

	/**
	 * 把缓存键归一化成"文件路径"：去掉 mod 前缀（`Mod:images/x.png`）和内容包后缀（`images/x.png|content/...`）。
	 * 同一个文件不管走哪条加载路径，归一化后应当得到同一个字符串。
	 */
	public static function normalizeKey(key:String):String
	{
		var k:String = key;
		var bar:Int = k.indexOf('|');
		if (bar >= 0)
			k = k.substring(0, bar);
		var colon:Int = k.indexOf(':');
		var slash:Int = k.indexOf('/');
		// 冒号出现在第一个斜杠之前 → 那是 mod 前缀，不是盘符
		if (colon > 0 && (slash < 0 || colon < slash))
			k = k.substring(colon + 1);
		return k;
	}

	/**
	 * 归一化后同一路径出现多次 = 同一个文件被解码成了多份 FlxGraphic。
	 * 按浪费字节降序返回（wasted = 总字节 - 单份最大字节）。
	 */
	public static function duplicateKeys():Array<DupGroup>
	{
		var groups = new Map<String, Array<TextureEntry>>();
		for (e in trackedTextures())
		{
			var n:String = normalizeKey(e.key);
			if (!groups.exists(n))
				groups.set(n, []);
			groups.get(n).push(e);
		}

		var out:Array<DupGroup> = [];
		for (n in groups.keys())
		{
			var list = groups.get(n);
			if (list.length < 2)
				continue;
			var total:Float = 0;
			var max:Float = 0;
			for (e in list)
			{
				var b:Float = e.cpuBytes + e.gpuBytes;
				total += b;
				if (b > max)
					max = b;
			}
			out.push({
				name: n,
				keys: [for (e in list) e.key],
				bytes: total,
				wasted: total - max
			});
		}
		out.sort((a, b) -> Std.int(b.wasted - a.wasted));
		return out;
	}

	public static function duplicateWaste():Float
	{
		var w:Float = 0;
		for (g in duplicateKeys())
			w += g.wasted;
		return w;
	}

	/** 待释放队列占的字节数（估算：w*h*4，CPU 与 GPU 各算一份）。 */
	public static function pendingBytes():Float
	{
		var total:Float = 0;
		for (graphic in Paths.pendingReleaseGraphics())
		{
			if (graphic == null || graphic.isDestroyed || graphic.bitmap == null) continue;
			var bmp = graphic.bitmap;
			var bytes:Int = bmp.width * bmp.height * 4;
			if (bmp.image != null) total += bytes;
			if (hasGpuTexture(bmp)) total += bytes;
		}
		return total;
	}

	public static function summaryLine():String
	{
		var t = totals();
		var parts:Array<String> = [];
		parts.push('GC usage ${fmt(gcUsage())}');
		parts.push('current ${fmt(gcCurrent())}');
		parts.push('reserved ${fmt(gcReserved())}');
		parts.push('large ${fmt(gcLarge())}');
		if (processRSS() > 0)
			parts.push('RSS ${fmt(processRSS())}');
		parts.push('贴图 ${t.entries} 张 / CPU ${fmt(t.cpuBytes)} / GPU≈${fmt(t.gpuBytes)}');
		var dupes = duplicateKeys();
		if (dupes.length > 0)
			parts.push('重复 ${dupes.length} 组 / 浪费 ${fmt(duplicateWaste())}');
		return parts.join(' | ');
	}

	/** 把完整报告写到 logs/memory-<时间戳>.txt，并往 logs/memory-session.txt 追加一行摘要。返回文件路径。 */
	public static function dumpReport():String
	{
		var now = Date.now();
		var stamp = '${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}';
		var dir:String = 'logs';
		if (!sys.FileSystem.exists(dir))
			sys.FileSystem.createDirectory(dir);

		var path:String = '$dir/memory-$stamp.txt';
		sys.io.File.saveContent(path, buildReport());

		// 时间线：多次按 F9 时不用一个个开文件，直接看这一行
		var session:String = '$dir/memory-session.txt';
		var out = sys.io.File.append(session, false);
		out.writeString('[$stamp] ${summaryLine()}\n');
		out.close();

		trace('[MemoryStats] $path');
		return path;
	}

	public static function buildReport():String
	{
		var sb = new StringBuf();
		var t = totals();

		sb.add('FrozenEngine 内存快照 ${Date.now()}\n');
		sb.add('========================================\n');
		sb.add('hxcpp GC（Immix）\n');
		sb.add('  USAGE    ${fmt(gcUsage())}   // 上次 GC 时估算的活对象，FPSCounter 显示的就是它\n');
		sb.add('  CURRENT  ${fmt(gcCurrent())}   // 含未回收垃圾\n');
		sb.add('  RESERVED ${fmt(gcReserved())}   // 已向系统申请的块\n');
		sb.add('  LARGE    ${fmt(gcLarge())}   // 大对象池（贴图 ByteArray 多在此）\n');
		sb.add('进程\n');
		sb.add('  RSS      ${fmt(processRSS())}   // Windows 工作集；非 Windows 为 0\n');
		sb.add('显卡\n');
		sb.add('  独占显存 ${fmt(dedicatedVRAM())}   // DXGI 查到的总量；探测失败为 0\n');
		sb.add('  预载上传 ${shouldPreloadToVRAM() ? '开' : '关'}   // ${ClientPrefs.data.preloadTextureToVRAM}（auto = 显存 >= 10GB）\n');
		sb.add('引擎追踪\n');
		sb.add('  FlxG.bitmap 条目 ${t.bitmapCacheSize}\n');
		sb.add('  Paths 追踪贴图   ${t.entries} 张，CPU ${fmt(t.cpuBytes)}，GPU≈${fmt(t.gpuBytes)}\n');
		sb.add('  重复浪费         ${fmt(duplicateWaste())}（同一文件被缓存成多份）\n');
		sb.add('  待释放         ${t.pending} 张 / ≈${fmt(pendingBytes())}（还有对象引用，引用掉光后下一次 flush 收）\n');
		sb.add('  （GPU 按 w*h*4 估算，未计 mipmap / 压缩格式）\n\n');

		var pendingList = Paths.pendingReleaseGraphics();
		if (pendingList.length > 0)
		{
			sb.add('\n待释放明细（还有对象引用，收不走；按体积降序）\n');
			var rows:Array<TextureEntry> = [];
			for (graphic in pendingList)
			{
				if (graphic == null || graphic.isDestroyed || graphic.bitmap == null) continue;
				var bmp = graphic.bitmap;
				var bytes:Int = bmp.width * bmp.height * 4;
				rows.push({
					key: graphic.key + '   useCount=${graphic.useCount}',
					width: bmp.width,
					height: bmp.height,
					cpuBytes: (bmp.image != null) ? bytes : 0,
					gpuBytes: hasGpuTexture(bmp) ? bytes : 0,
					readable: bmp.readable
				});
			}
			rows.sort((a, b) -> b.cpuBytes + b.gpuBytes - (a.cpuBytes + a.gpuBytes));
			for (i in 0...Std.int(Math.min(20, rows.length)))
			{
				var e = rows[i];
				sb.add(padRight(fmt(e.cpuBytes), 9) + padRight(fmt(e.gpuBytes), 9)
					+ padRight('${e.width}x${e.height}', 13) + e.key + '\n');
			}
			if (pendingList.length > 20)
				sb.add('  …还有 ${pendingList.length - 20} 张\n');
		}

		var entries = trackedTextures();
		entries.sort((a, b) -> b.cpuBytes + b.gpuBytes - (a.cpuBytes + a.gpuBytes));

		sb.add('Top 40（按 CPU+GPU 估算）\n');
		sb.add(padRight('CPU', 10) + padRight('GPU', 10) + padRight('尺寸', 14) + 'key\n');
		for (i in 0...Std.int(Math.min(40, entries.length)))
		{
			var e = entries[i];
			sb.add(padRight(fmt(e.cpuBytes), 10)
				+ padRight(fmt(e.gpuBytes), 10)
				+ padRight('${e.width}x${e.height}', 14)
				+ e.key
				+ '\n');
		}

		var dups = duplicateKeys();
		if (dups.length > 0)
		{
			sb.add('\n同一文件多份缓存（归一化 key 后同路径，${dups.length} 组，浪费 ${fmt(duplicateWaste())}）\n');
			for (i in 0...Std.int(Math.min(20, dups.length)))
			{
				var g = dups[i];
				sb.add('  浪费 ${padRight(fmt(g.wasted), 8)} ${g.name}  (${g.keys.length} 份 / 共 ${fmt(g.bytes)})\n');
				for (k in g.keys)
					sb.add('      $k\n');
			}
		}

		return sb.toString();
	}

	public static inline function fmt(bytes:Float):String
	{
		if (bytes <= 0)
			return '0';
		if (bytes < 1024)
			return '${Math.round(bytes)}B';
		if (bytes < 1024 * 1024)
			return '${Math.round(bytes / 1024)}KB';
		if (bytes < 1024 * 1024 * 1024)
			return '${Math.round(bytes / 1024 / 1024)}MB';
		return '${Math.round(bytes / (1024 * 1024 * 1024) * 100) / 100}GB';
	}

	static inline function pad(v:Int):String
		return v < 10 ? '0$v' : '$v';

	static inline function padRight(s:String, n:Int):String
	{
		while (s.length < n)
			s += ' ';
		return s;
	}
}

typedef TextureEntry = {
	var key:String;
	var width:Int;
	var height:Int;
	var cpuBytes:Int;
	var gpuBytes:Int;
	var readable:Bool;
}

typedef Totals = {
	var entries:Int;
	var cpuBytes:Float;
	var gpuBytes:Float;
	var bitmapCacheSize:Int;
	var pending:Int;
}

/** 归一化路径相同的多条缓存。wasted = 总字节 - 单份最大字节。 */
typedef DupGroup = {
	var name:String;
	var keys:Array<String>;
	var bytes:Float;
	var wasted:Float;
}
