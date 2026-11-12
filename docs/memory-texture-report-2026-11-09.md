# FrozenEngine 贴图内存 & hxcpp GC 指示器 调查报告

> 日期：2026-11-09  
> 范围：`J:/FNF-FrozenEngine`（Psych 衍生，openfl `9.6.0-dev` fork / lime 8.4.0 / flixel 6.2.1 / hxcpp 4.3.184）  
> 对照：FNF-NovaFlare-Engine、VS Impostor Legacy、Codename Engine  
> 方法：源码逐行核对（含 openfl/lime/hxcpp 依赖源码）+ PNG 解码体积静态审计 + 类型检查验证。  
> 本文所有行号以当前工作区为准。

---

## 0. 结论速览

| # | 结论                                                                                                                                                                                                                                                    | 影响                                                       | 优先级            |
| - | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | -------------- |
| 1 | **贴图缓存键用的是"查找上下文"而不是"解析后的文件路径"**：`Paths.image()` 算出 `images/x.png\|<contentRoot>/<level>\|依赖根…`，而 `LoadingState` 预加载走 `Paths.cacheBitmap()` 只存 `images/x.png`。只要当前有内容包/mod 上下文，两边就对不上 → **同一个文件被解码两份并同时驻留**（FE 的 vanilla 内容基本都在 `content/` 下，所以这是常态）。 | 单曲多出 300–600MB；跨歌/跨周共享角色图也无法复用                           | **P1（最高性价比）**  |
| 2 | 默认 `cacheOnGPU = false`（桌面），openfl 会**同时**保留 CPU `Image` 和 GPU 纹理；而 `Paths` 又把所有图 `persist = true; destroyOnNoUse = false`，只进不出，清理只有"整片硬销毁"一档。                                                                                                        | CPU 像素缓冲是主战场：实测资源总量 148MB PNG → **5.5GB 解码后**            | **P2**         |
| 3 | 现有 GPU caching 分支（`Paths.hx:606-619`）是从老 openfl 抄来的，在 9.6.0-dev 上语义已变：`disposeImage()` 只置 `readable=false`，真正的释放发生在下一次 `getTexture()`；代码却手动 `image = null` 后再 `readable = true`，留下**悬垂的 cairo surface** 和"可读"假象。                                      | 开 GPU caching 时更容易崩（`getPixel32` 空引用），且 `__surface` 永久悬空 | **P1.5**       |
| 4 | FPS 计数器显示的 `Memory` 是 `Gc.memInfo64(MEM_INFO_USAGE)`。它统计的是 **hxcpp GC 堆**：≥4000B 的对象（贴图 ByteArray 全在此列）**分配时即时计入**，但**释放要等 GC 真正回收**；不含未回收垃圾之外的 native（OpenAL/FFmpeg/SDL/cairo）与显存。                                                                   | 贴图占用它会涨（可信）；但释放后不立刻降，且和任务管理器差一截                          | **P0（已补 RSS）** |

一句话：**不是贴图没释放，而是"同一张图被当成多张"+"释放策略只有全有全无"+"默认又保留了 CPU 副本"** 三件事叠在一起。GC 指示器本身没坏，只是它回答的不是"进程占了多少内存"。

---

## 1. 量级：贴图到底占多少

### 1.1 静态审计

新增脚本 `tools/atlas_memory_audit.py`（直接读 PNG IHDR，不依赖 PIL）：

```bash
python tools/atlas_memory_audit.py            # 扫 assets/ + content/
python tools/atlas_memory_audit.py --root export/release/windows/bin/content --top 40
```

当前工程结果：

```
PNG 数量: 770
磁盘体积: 148.1MB
解码后  : 5.5GB   (BGRA32, 37.9x 膨胀)
>=2048x2048 的图: 91 张，解码共 4.3GB
```

按目录（解码后）：

| 目录                   |  张数 |     解码后 |     磁盘 |
| -------------------- | --: | ------: | -----: |
| base_game/shared     | 100 |   1.7GB | 51.0MB |
| VanillaSongs/Erect   |  90 |   1.2GB | 26.6MB |
| shared/images        | 380 | 636.1MB | 19.9MB |
| VanillaSongs/PicoMix |  27 | 504.4MB | 13.2MB |
| VanillaSongs/Collab  |  37 | 293.6MB |  6.0MB |
| base_game/weekend1   |  27 | 246.6MB |  5.6MB |
| base_game/week2      |   3 | 233.5MB |  5.1MB |
| base_game/week7      |  19 | 205.9MB |  7.6MB |

单图最大（解码后）：

|      解码 | 尺寸        | 文件                                                                          |
| ------: | --------- | --------------------------------------------------------------------------- |
| 191.0MB | 6420×7800 | assets/base_game/week2/images/halloween_bg.png                              |
| 183.1MB | 8000×6000 | assets/shared/images/characters/GF_assets.png                               |
| 181.2MB | 8192×5800 | assets/base_game/shared/images/characters/mom_dad_christmas_assets.png      |
| 167.8MB | 8187×5374 | assets/base_game/shared/images/characters/picoExplosionDeath/spritemap1.png |
| 128.0MB | 8192×4096 | content/VanillaSongs/Erect/week5/images/christmas/erect/bottomBop.png       |

### 1.2 单曲示例：Erect week5

| 组成                                  |         解码后 |
| ----------------------------------- | ----------: |
| 舞台（10 张，`Erect/week5/images`）       |     248.2MB |
| dad/mom（`mom_dad_christmas_assets`） |     181.2MB |
| gf（`gfChristmas`）                   |      75.3MB |
| bf（`bfChristmas`）                   |      20.6MB |
| **合计**                              | **≈ 525MB** |

这还不含 note 皮肤、血条图标、UI、字体纹理。  
默认配置下 CPU 侧 525MB，首次绘制后 GPU 再来一份 ≈ 再 525MB；如果触发第 0 节第 1 条的双份缓存，峰值直接翻倍。

**结论：优化目标应该是"解码后的像素缓冲"，不是磁盘上的 PNG 体积，也不是优先砍显存。**

---

## 2. FE 的贴图路径逐层拆解

### 2.1 缓存键 = 查找上下文，不是文件（核心 bug）

`source/backend/Paths.hx:564-628`：

```haxe
key = Language.getFileTranslation('images/$key') + '.png';

var cacheKey = key;                                  // images/xxx.png
#if MODS_ALLOWED
if (Mods.currentModDirectory != null && ... != "base")
    cacheKey = Mods.currentModDirectory + ":" + key;
#end
if (currentContentRoot != null && currentContentRoot.length > 0)
{
    var level = (currentLevel != null && currentLevel.length > 0) ? currentLevel : 'shared';
    cacheKey = '$cacheKey|$currentContentRoot/$level|${currentContentDependencyRoots.join(":")}';
}

if (currentTrackedAssets.exists(cacheKey)) { ... return ...; }
```

问题有三层：

1. **`level` 是"这次查找的层级"，不是文件真正所在层级。**  
   `getPath()` 会依次试 `<root>/<level>/images/…` → `<root>/shared/images/…`。  
   角色图实际在 `shared`，但缓存键里写的是 `week5`。于是同一张 `bfChristmas.png`  
   在 week5 和 week6 各有一份 `FlxGraphic`，跨歌无法复用。
2. **`LoadingState` 预加载用的是另一个键。**  
   `source/states/LoadingState.hx:970-1003` 的 `preloadGraphic()` 把工作线程解码好的  
   `BitmapData` 交给 `Paths.cacheBitmap(requestKey, bitmap)`（:519），而  
   `cacheBitmap` 直接 `currentTrackedAssets.set(key, graph)`（:667），**不补 contentRoot / level 后缀**。  
   于是（有 `currentContentRoot` / 非 base 的 mod 时）：
   - 预加载存进 `images/characters/bf.png`；  
     |  |  |  |  
     | --- | --- | --- |
   - 进歌后 `Paths.image('characters/bf')` 查 `images/characters/bf.png|<root>/week5|…` → miss → **重新解码一份**。  
     两份都 `persist = true`，都留在 `currentTrackedAssets` 里，直到下一次整片 flush。
3. **`currentContentDependencyRoots.join(":")` 也在键里**：依赖根顺序一变（加载顺序/热重载），同一个文件又会多一份。

> 佐证：`cacheBitmap` 与 `image` 是两条独立路径，前者从不做键归一化。  
> 这也是"预加载了但进歌还是要等"的根因之一。

**建议（P1）**：把键改成"解析后的文件路径"（`getPath()` 的返回值），`image()` / `cacheBitmap()` / 预加载三处共用同一个 `resolveGraphicKey()`。  
文件路径天然包含 mod 目录、内容包目录、层级，且唯一 → 不可能重复；顺带让 `Level`/依赖顺序不再影响缓存。

---

### 2.2 默认配置 = CPU + GPU 双份

`ClientPrefs.hx:44`：

```haxe
public var cacheOnGPU:Bool = #if !switch false #else true #end;
```

桌面默认走 `false`，即 `Paths.image()` 里那段 GPU 分支完全不执行。此时：

- `openfl.BitmapData` 保留 `image`（lime `Image` → `ImageBuffer.data: UInt8Array` → `haxe.io.Bytes`），**这是解码后的 BGRA32 全量像素**；
- 首次渲染时 `getTexture()` 把 `image` 上传成 GL 纹理，**但 `readable == true` 时不会丢 `image`**（`openfl/display/BitmapData.hx:2254-2320`）。

所以一张 8192×5800 的图 = 181MB CPU + 181MB VRAM（未计 mipmap）。  
`lowQuality` 目前只控制舞台元素的显隐（`StageData.hx:259`），**不降采样**，对内存无效。

---

### 2.3 GPU caching 分支本身有问题

`Paths.hx:606-619`：

```haxe
if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
{
    bitmap.lock();
    if (bitmap.__texture == null)
    {
        bitmap.image.premultiplied = true;
        bitmap.getTexture(FlxG.stage.context3D);   // 上传；此时 readable 仍为 true → image 不丢
    }
    bitmap.getSurface();                            // ① 建 cairo surface
    bitmap.disposeImage();                          // ② 在 9.6.0-dev 只是 readable = false
    bitmap.image.data = null;                       // ③ 丢掉 Bytes 引用
    bitmap.image = null;                            // ④ 丢掉 Image
    bitmap.readable = true;                         // ⑤ 谎报"还能读像素"
}
```

逐条对照依赖源码：

- **① `getSurface()`**：`BitmapData.getSurface()` → `CairoImageSurface.fromImage(image)` →  
  `create(image.data.buffer, …)` → 原生 `cairo_image_surface_create_for_data(ptr, …)`。  
  它**不拷贝**，只拿裸指针（`lime/project/src/graphics/cairo/CairoBindings.cpp:999`）。  
  `__surface` 被存进 `BitmapData.__surface`，但之后 `image == null`，  
  `getTexture()` 里那句 `if (!readable && image != null) { __surface = null; image = null; }` 永远不会执行  
  → **`__surface` 永久悬空**，且指向的内存可能已被 GC 回收。它既没用又危险。
- **② `disposeImage()`**：openfl 9.6.0-dev 的实现是 `readable = false;` 一行（`BitmapData.hx:823-826`）。  
  真正的释放逻辑在 `getTexture()` 末尾：`if (!readable && image != null) { __surface = null; image = null; }`。  
  也就是说**只要在首次 `getTexture()` 之前把 `readable` 置 false，openfl 自己就会在上传后丢 CPU 图** —— 这才是当前版本的正确用法。
- **⑤ `readable = true`**：`readable` 是 `default, null` 的属性，`Paths` 靠 `@:access` 强写。  
  之后任何 `getPixel32/pixels` 都会走到 `bitmap.image.getPixel32` → `image == null` → 空引用。  
  `options/objects/win10/KeyboardColorPanel.hx:183` 已经踩过这个坑并留了注释。

**正确写法（P1.5，两行）**：

```haxe
if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
    bitmap.disposeImage();        // 只置 readable=false
// 之后首次 getTexture() 上传完，openfl 自己把 image/__surface 置 null
```

注意：这意味着**开 GPU caching 后 CPU 像素不可再读**，所有需要 `pixels/getPixel32` 的调用点必须传 `allowGPU = false`（现有 `KeyboardColorPanel` 已经这么做）。这是语义，不是 bug。

---

### 2.4 `persist = true` + `destroyOnNoUse = false`：只进不出

`Paths.hx:621-627`：

```haxe
var graph = FlxGraphic.fromBitmapData(bitmap, false, cacheKey);
graph.persist = true;
graph.destroyOnNoUse = false;
```

flixel 侧（`FlxGraphic.hx:575`）：

```haxe
if (useCount <= 0 && destroyOnNoUse && !persist) FlxG.bitmap.remove(this);
```

`persist` 同时会让 `FlxG.bitmap.clearCache()` 跳过（`BitmapFrontEnd.hx:279-296`）。  
所以这些图**只能**由 `Paths.destroyGraphic()` 显式销毁。而 `Paths` 没有任何"按预算/按 LRU"的淘汰，只有两档：

- `clearStoredMemory()`：销毁 `FlxG.bitmap` 里不在 `currentTrackedAssets` 的图 + 清空 `localTrackedAssets`；
- `clearUnusedMemory()`：销毁 `currentTrackedAssets` 里不在 `localTrackedAssets` 的图 + `System.gc()`。

---

### 2.5 清理语义的两个硬伤

**(a) `localTrackedAssets` 是只增不减的 `Array<String>`**

`Paths.hx:61` + 每次 `image()` 都 `localTrackedAssets.push(cacheKey)`（:586/:626）。  
它只在 `clearStoredMemory()` 末尾被整体清空（:83）。  
后果：同一进程第二次进歌时，"本地存活"判定完全失准 —— 上一首歌的所有 key 都还在里面。  
`PlayState.hx:1246` 的注释已经写明了这一点，并因此**直接禁用了 `clearUnusedMemory()`**：

> 不调 `Paths.clearUnusedMemory()`：它按 localTrackedAssets 判断存活，而该表跨歌只增不减、  
> key 还带 contentRoot 后缀。同一进程第二次进歌时判定失准，会把角色分尸图集当成未使用  
> 销毁掉，紧接着 cacheCountdown 重建同 key 图集时闪退。

**(b) `destroyGraphic()` 是硬销毁，不看 `useCount`**

`Paths.hx:142-148`：

```haxe
if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
    graphic.bitmap.__texture.dispose();
FlxG.bitmap.remove(graphic);      // → graphic.destroy() → bitmap.dispose()
```

`FlxG.bitmap.remove()` 无条件 `destroy()`（`BitmapFrontEnd.hx:242-254`），  
`FlxGraphic.destroy()` 会把 `frameCollections` 全部销毁、`frames.frames` 置 null。  
如果此时还有 sprite / 池化对象持有这套 frames，下一次 `set_clipRect` 就会空引用 ——  
`objects/Note.hx:420` 的注释就是为此写的。

**结果：清理只能在"确认没有对象引用"的时刻做，于是干脆不做了。** 这就是"内存只涨不降"的机制。

**建议（P2）**：把 `destroyGraphic` 改成"延迟释放"：

```haxe
graphic.persist = false;
graphic.destroyOnNoUse = true;      // 让 flixel 在 useCount 归零时自己收
```

（NovaFlare 的 `Paths.releaseGraphicWhenUnused()` 正是这么做的，见 §4。）  
但要先补一个 `FlxGraphic.destroy()` 不释放 GL 纹理的问题（见 2.6）。

---

### 2.6 openfl 侧的两个坑（9.6.0-dev / lime 8.4）

1. **`BitmapData.dispose()` 不删 GL 纹理。**  
   `BitmapData.hx:741-802` 里 `__texture = null;` 之后那段 `gl.deleteTexture` 是**注释掉的**。  
   因此只有显式调用 `TextureBase.dispose()` 才能释放显存（:84-96）。  
   FE 里唯一做对的地方就是 `Paths.destroyGraphic()`；任何走 flixel 自己的路径  
   （`FlxG.bitmap.clearCache()` / `reset()` / `destroyOnNoUse`）销毁的图都会留下 GL 纹理。
2. **`AssetLibrary.unload()` / `Assets.cache.clear()` 只清索引，不 dispose。**  
   这解释了为什么"卸载资源库"类做法在 native 上看起来很干净、实际内存不降。

---

### 2.7 次要占用（顺带记录，不在本期范围）

- **音频**：`Paths.currentTrackedSounds` 用完整路径做键，`clearStoredMemory()` 只清不在 `localTrackedAssets` 里的。  
  非 `streamedMusic` 模式下 `Sound.fromFile` 的解码缓冲由 OpenAL/Vorbis 持有，**不在 hxcpp GC 统计内**。
- **字体/文本**：每个 `FlxText` 都有自己的 `BitmapData`+纹理，对话框/歌词多的场景是第二大头。
- **视频**：hxvlc/FFmpeg 的帧缓冲同样是 native 分配。


## 3. hxcpp GC 指示器核实

### 3.1 调用链

```
FPSCounter.get_memoryMegas()                        source/debug/FPSCounter.hx:318
  → cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE)
    → __hxcpp_gc_mem_info(0)                        hxcpp Immix.cpp:6966
      → sGlobalAlloc->MemUsage()                    hxcpp Immix.cpp:5513
        → mLargeAllocated + (mRowsInUse << IMMIX_LINE_BITS)
```

`MEM_INFO_USAGE = 0`（`std/cpp/vm/Gc.hx:26`），Haxe 标准库对它的注释是：

> `MEM_INFO_USAGE` - estimate of how much is needed by program (**at last collect**)
> `MEM_INFO_RESERVED` - memory allocated for possible use
> `MEM_INFO_CURRENT` - memory in use, includes uncollected garbage.
>     This will generally saw-tooth between USAGE and RESERVED
> `MEM_INFO_LARGE` - Size of separate pool used for large allocs. Included in all the above.

### 3.2 为什么"不准"

| 现象 | 原因 |
|---|---|
| 贴图加载后数字**会**涨，而且基本对得上 | `IMMIX_LARGE_OBJ_SIZE = 4000`：≥4000B 的对象走 large 池，`mLargeAllocated += inSize` 在分配时**即时**更新（`Immix.cpp:3312`） |
| 贴图释放后数字**不立刻**降 | large 池要等 GC 真正回收才 `mLargeAllocated -= size`（`Immix.cpp:3206`）；没回收的垃圾继续计入 |
| 小对象（<4000B）分配不计入，直到下次 GC | `mRowsInUse` **只在 GC 时更新**（`Immix.cpp:5051-5052`） |
| 数字比进程 RSS 小很多 | 不含 native malloc：OpenAL/Vorbis 解码缓冲、FFmpeg、SDL、cairo surface、线程栈、驱动映射 |
| 数字比对象实际字节略大 | 小对象按 128B 行（`IMMIX_LINE_BITS = 7`）整行计入；`fraggedRows` 也算进去 |
| 数字忽然掉一大截 | `Paths.clearUnusedMemory()` 末尾有 `System.gc()`，而 `System.gc()` = `Gc.run(true)`（**阻塞式 full GC**，`openfl/system/System.hx:213`） |
| 显存完全不体现 | GC 只统计 hxcpp 堆；GL 纹理在驱动里 |

补充：`openfl.system.System.totalMemory` 在 cpp 上返回 `__hxcpp_gc_used_bytes()`，
**和 `MEM_INFO_USAGE` 是同一个数**（`openfl/system/System.hx:345-351`），换它没有意义。

### 3.3 已经做的修正（P0）

新增 `source/backend/MemoryStats.hx`：

- `gcUsage() / gcCurrent() / gcReserved() / gcLarge()` —— 四个口径一次看全；
- `processRSS()` —— Windows `K32GetProcessMemoryInfo` 取工作集（任务管理器那个数）；
- `trackedTextures()` / `totals()` / `duplicateKeys()` —— 按 `Paths.currentTrackedAssets` 统计 CPU/GPU 估算字节，
  并按「归一化后的文件路径」列出同一文件被缓存成多份的组与浪费字节（`normalizeKey()` 会去掉 mod 前缀和内容包后缀）；
- `buildReport()` / `dumpReport()` —— 写 `logs/memory-<时间戳>.txt`（含 Top 40 大图），
  并往 `logs/memory-session.txt` 追加一行摘要，多次采样直接看时间线。

接线（都是只读，不改缓存）：

- `PauseSubState`：**暂停时按 F9** 导出一份快照；
- `FPSCounter`：开启「Show Memory Peak」后，内存行追加 `RSS: xxx`。

这样后续任何一个优化都能用同一把尺子验收：**看 RSS 和 `Paths` 记账，不看 USAGE**。

---

## 4. 其他引擎怎么管（对比）

| 引擎                     | 纹理归属                                                        | 丢 CPU 像素的时机                                                                                                   | 释放策略                                                                              | 备注                                                        |
| ---------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **FE / Psych**         | `Paths.currentTrackedAssets` + `FlxG.bitmap`，`persist=true` | 仅当 `cacheOnGPU=true`，且实现有 bug（§2.3）                                                                           | 整片 hard destroy（不看 useCount）                                                      | 只有"全清"和"不清"两档                                             |
| **NovaFlare**          | `Cache.currentTrackedAssets` + `currentTrackedFrames/Anims` | `createRectangleTexture` → `uploadFromBitmapData` → `BitmapData.fromTexture(texture)`，**从构造就是 hardware-only** | `releaseGraphicWhenUnused()`：`persist=false; destroyOnNoUse=true`，交给 flixel 的引用计数 | 还额外缓存/销毁 `FlxFramesCollection` 和 `FlxAnimationController` |
| **VS Impostor Legacy** | `FunkinAssets.cache`（`CacheMap` + `permanentKeys`）          | `cacheBitmap` 里 `bitmap.disposeImage()`（依赖 openfl 在首次 `getTexture` 时丢 `image`）                                | `clearUnusedMemory()` = 移除不在 local 的 + `System.gc()` + `Gc.compact()`             | 有 `permanentKeys` 概念，比 FE 的 `dumpExclusions` 清晰           |
| **Codename Engine**    | lime `AssetLibrary` 生命周期，按 mod 装载/卸载                        | 不主动丢，靠 `Assets.cache`                                                                                         | `unloadLibraries()` → `AssetLibrary.unload()`（只清索引，不 dispose）                     | `MemoryUtil` 同时给出 GC 与 **进程 RSS** 两个口径                    |

**可借鉴的四条原则**：

1. **键 = 文件**，不是查找参数（NovaFlare 直接用 `file` 当键）。
2. **释放交给引用计数**（`persist=false/destroyOnNoUse=true`），不要自己 hard destroy。
3. **丢 CPU 像素要在"上传之后"**：要么 hardware-only（NovaFlare），要么先 `readable=false` 再让 openfl 在 `getTexture` 里丢（Impostor）。
4. **测量要看 RSS**，GC 只能用来判断"垃圾有没有回收"（Codename 的 `currentProcessMemUsage`）。

---

## 5. 优化路线（分期，可独立验收）

### P0 测量（本次已完成）

- `tools/atlas_memory_audit.py`：静态看"解码后体积"，定位大图。
- `backend/MemoryStats.hx` + 暂停 F9 + FPS 的 RSS：运行期看真实占用。
- 验收：同一首歌，F9 快照里 `RSS` 与 `Paths 追踪 CPU` 差值的解释能对上（差值 ≈ 音频/字体/native/显存映射）。

### P1 统一缓存键（最高性价比）

**改动点**：`Paths` 增加

```haxe
static function resolveGraphicKey(key:String, ?parentFolder:String):String
{
    // 返回 getPath() 实际命中的文件路径；找不到时退回 'images/xxx.png'
}
```

`image()` / `cacheBitmap()` / `LoadingState.preloadGraphic()` 三处统一调用它，  
`currentTrackedAssets` 的键从"上下文串"变成"文件路径"。

**预期**：预加载真正生效；同文件不再双份；跨歌/跨周共享资源可复用。  
按 Erect week5 估算，单曲峰值可直接少 300–500MB。  
**风险**：`FunkinLua.precacheImage` 之类按 key 查缓存的脚本要跟着改（它们只调 `Paths.image`，不直接摸 map，风险低）。  
**验收**：F9 快照里 `duplicateKeys()` 为空（重复浪费 0）；同一首歌第二次进入时 RSS 不出现台阶式上涨。

### P1.5 修 GPU caching 分支

**改动点**：删掉 `getSurface()/image.data = null/image = null/readable = true`，只留 `bitmap.disposeImage()`；  
所有需要读像素的调用点显式传 `allowGPU = false`。  
**预期**：开 GPU caching 时 CPU 侧不再常驻、不再有 `__surface` 悬垂；`getPixel32` 崩溃消失。  
**风险**：低（语义更接近上游），但要回归 `KeyboardColorPanel`、`NotesColorSubState` 这类读像素的地方。  
**验收**：开 GPU caching 跑一整周，RSS ≈ 显存占用 + 常数；无空引用崩溃。

### P2 释放语义：从"硬销毁"到"引用计数"

**改动点**：

1. `destroyGraphic()` → `releaseGraphicWhenUnused()`（`persist=false; destroyOnNoUse=true`）；
2. 给 flixel 的销毁路径补 GL 纹理释放（`BitmapData.dispose()` 不删纹理，见 §2.6）——  
   最小实现：`FlxGraphic.destroy()` 前若 `bitmap.__texture != null` 先 `dispose()`；
3. `localTrackedAssets` 从"只增数组"换成"代际标记"（每次 `clearStoredMemory` 递增 epoch，  
   `image()` 记录 `key -> epoch`；`clearUnusedMemory` 只保留 `epoch == current` 的）。

**预期**：可以按需淘汰，不再需要"进歌就全清"；`PlayState` 里那条禁用注释可以删掉。  
**风险**：中（生命周期改动），需要重点回归：角色重载、note 池、编辑器预览。  
**验收**：连续切 5 首歌，RSS 曲线呈锯齿而不是阶梯；无 `frames` 空引用。

### P3 纹理策略（真正的"省内存"）

1. **按需丢 CPU 像素**：对"只用于渲染、不做像素读"的大图（角色/舞台/背景），上传后立即 `disposeImage()`。  
   可加 `ClientPrefs` 开关「省内存模式（贴图上传后释放 CPU 副本）」。
2. **降采样**：`lowQuality` 时对 > 2048 的图在加载阶段做一次 `BitmapData` 缩放（`Image.resize` / `drawToBitmapData`）。  
   实测 8192×4096 → 4096×2048 可省 75% 内存，视觉损失在 1280×720 下几乎不可见。
3. **预算 + LRU**：给 `Paths` 加"解码字节预算"（例如 1.2GB），超预算时按 `lastUsedFrame` 淘汰非当前状态引用的图。  
   需要 P2 的引用计数做前提。
4. **预加载窗口**：只预加载"当前歌 + 下一首"，不要整周；`LoadingState.prepare()` 目前是累加式（`concat`），  
   要加"清空上一批"的边界。

### P4 长期

- **图集拆分**：把 8192×5800 这类巨图按动画拆成多张 2048，GPU 友好、也便于按需加载。
- **压缩纹理**：桌面 BC7 / 移动 ASTC；显存从 32bpp 降到 8bpp，约 4 倍（需 openfl 的 compressed texture 支持）。
- **纹理流式**：大背景按镜头分块（现有舞台的 `camScroll` 逻辑可复用）。

---

## 6. 本次落地的文件

| 文件                                  | 说明                                             |
| ----------------------------------- | ---------------------------------------------- |
| `tools/atlas_memory_audit.py`       | 新增。PNG 解码体积审计（group / top N / 膨胀比）。            |
| `source/backend/MemoryStats.hx`     | 新增。GC 四口径 + 进程 RSS + `Paths` 贴图记账 + 快照导出。      |
| `source/debug/FPSCounter.hx`        | 改。`showMEMPeak` 打开时内存行追加 `RSS:`（不改原有 GC 数字含义）。 |
| `source/substates/PauseSubState.hx` | 改。暂停时 F9 导出 `logs/memory-*.txt`。               |

构建 / 验证：

- 类型检查：`cp export/debug/windows/haxe/debug.hxml /tmp/t.hxml && echo --no-output >> /tmp/t.hxml && haxe /tmp/t.hxml` → 零输出。
- release 构建：`haxelib run lime build windows` 通过（MSVC 2022 Community 14.44.35207 + SDK 10.0.19041.0），
  产物 `export/release/windows/bin/FrozenEngine.exe`。
- 实机行为未验证（按约定由你实测）。

> 原生 RSS 读数的坑（已修）：`@:cppFileCode` 是**类型级**元数据，挂在方法上会被 hxcpp 静默忽略，
> 生成的 cpp 里不会出现 include → `PROCESS_MEMORY_COUNTERS_EX` 未声明。现已挪到 `class MemoryStats` 之前；
> 实现改用 `GetProcessMemoryInfo` + `#pragma comment(lib, "psapi.lib")`（psapi.h 按 NTDDI 把它映射到
> K32 或 psapi.dll，两种情况都能链）。**注入的 C++ 里不要写非 ASCII 注释**，否则触发 C4819。

## 7. 附录：关键源码索引

| 位置                                               | 内容                                                               |
| ------------------------------------------------ | ---------------------------------------------------------------- |
| `source/backend/Paths.hx:43-58`                  | `clearUnusedMemory()` + `System.gc()`                            |
| `source/backend/Paths.hx:64-85`                  | `clearStoredMemory()`，末尾 `localTrackedAssets = []`               |
| `source/backend/Paths.hx:142-148`                | `destroyGraphic()` 硬销毁 + `__texture.dispose()`                   |
| `source/backend/Paths.hx:564-628`                | `image()`：缓存键 + GPU 分支                                           |
| `source/backend/Paths.hx:630-670`                | `cacheBitmap()`：不做键归一化                                           |
| `source/states/LoadingState.hx:517-525`          | `checkLoaded()` → `cacheBitmap(原始 key, bitmap)`                  |
| `source/states/LoadingState.hx:970-1003`         | `preloadGraphic()` 工作线程解码                                        |
| `source/states/PlayState.hx:1246`                | 禁用 `clearUnusedMemory()` 的原因注释                                   |
| `source/objects/Note.hx:412-430`                 | note 池与 frames 悬垂引用的说明                                           |
| `openfl/display/BitmapData.hx:823-826`           | `disposeImage()` 只置 `readable=false`                             |
| `openfl/display/BitmapData.hx:2254-2320`         | `getTexture()` 末尾 `if (!readable && image != null) image = null` |
| `openfl/display/BitmapData.hx:741-802`           | `dispose()` 不删 GL 纹理（删除代码被注释）                                    |
| `openfl/display3D/textures/TextureBase.hx:84-96` | 唯一真正 `gl.deleteTexture` 的地方                                      |
| `lime/graphics/cairo/CairoImageSurface.hx:35-41` | `fromImage` 用裸指针，不拷贝                                             |
| `hxcpp/4,3,184/src/hx/gc/Immix.cpp:5513-5516`    | `MemUsage()` 定义                                                  |
| `hxcpp/4,3,184/src/hx/gc/Immix.cpp:5051-5052`    | `mRowsInUse` 仅在 GC 时更新                                           |
| `std/cpp/vm/Gc.hx:26-39`                         | 四个 `MEM_INFO_*` 的官方语义                                            |
