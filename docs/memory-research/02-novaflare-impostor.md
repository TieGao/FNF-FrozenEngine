# NovaFlare / VS Impostor Legacy 资源与内存管理调查

调查对象：`F:/FNF-NovaFlare-Engine`（NovaFlare，vendored fork openfl 9.5.0 + fork flixel 5.9.0 + fork hxcpp）
与 `D:/funkin-sources/impostorLegacyPublic`（Impostor Legacy，上游 openfl + flixel 5.x）。
GPU 侧细节与 `01-openfl-gpu-caching.md` 交叉验证；NovaFlare 的 openfl 读的是仓库内
`.haxelib/openfl/git/`（9.5.0），不是 `E:` 下那套 9.5.2。

## 1. 一句话总览

两家都没有 LRU / 预算 / 降采样；差异只在**什么时候清**和**谁来销毁**：
NovaFlare 用「本代碰过集合 + flixel 自己的 useCount」软释放（不自己动手销毁），Impostor 用
「state 边界 mark & sweep + 显式 `__texture.dispose()`」硬释放。两家的 GPU 策略都把 CPU 副本
交给 openfl 自己丢；真正的 hardware-only 只有 NovaFlare 一处，而且**正确的那条在预载路径上**。

## 2. NovaFlare 拆解

### 2.1 缓存结构（`general/backend/Cache.hx:42-50`）

```haxe
public static var localTrackedAssets:Array<String> = [];          // 本代「碰过」的 key
public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
public static var currentTrackedSounds:Map<String, Sound> = [];
public static var currentTrackedFrames:Map<String,{graphic,frame}> = []; // Note/HealthIcon 帧复用
public static var currentTrackedAnims:Map<String, FlxAnimationController> = [];
```

key = 解析后的实际文件路径。所有读写都套 `Mutex`（`Cache.hx:13-39`），因为它是唯一做了多线程
预载的引擎。`currentTrackedFrames` 是 FE 没有的：按 `skin` 缓存 `FlxFramesCollection`
（`Note.hx:845`、`HealthIcon.hx:46`），省的是 atlas 解析而不是像素。

### 2.2 释放判定：交还给 flixel

```haxe
// Paths.hx:35-44
static function releaseGraphicWhenUnused(graphic:FlxGraphic):Void {
    if (graphic == null || graphic.isDestroyed) return;
    graphic.persist = false;
    graphic.destroyOnNoUse = true;   // 置位时 flixel 的 setter 会立刻 checkUseCount()
}
```

`clearUnusedMemory()`（`Paths.hx:109-140`）遍历 `currentTrackedAssets`，凡不在
`localTrackedAssets` 且不在 `dumpExclusions` 的就交给上面这个函数。**没有 pending 队列、
不读 useCount、不自己销毁** —— 有引用就继续活着，引用归零时由 flixel 收。

### 2.3 销毁出口：它自己也在漏纹理

实际路径 `checkUseCount → FlxG.bitmap.remove() → FlxGraphic.destroy() → bitmap.dispose()`。
**fork 的 `dispose()` 与上游逐字节一致**：`gl.deleteTexture` 整块注释（fork `BitmapData.hx:799-817`），
`disposeImage()` 同样只有 `readable = false`（fork `:832-835`），全 fork 库 `__texture.dispose()`
零命中，唯一生效的删除在 `TextureBase.hx:165`。→ 这条软释放路线**在它自己身上也漏**，只是没有
FE `full` 的双份、涨得慢。**FE 必须保留自建 `destroyGraphic`（`Paths.hx:378-399`），不要改。**

### 2.4 GPU caching / hardware-only（`Paths.hx:509-552`）

它有两条完全不同的路径，必须分开看：

**(a) 预载路径 —— 正确的那条。** `LoadingState.hx:419` `BitmapData.fromFile(realPath, true)`
把第二参 `disposeOnUpload` 置 true（嵌入资源在 `Paths.hx:458` 手置）。该字段是 fork 新增
（fork `BitmapData.hx:178`），`getTexture()` 上传成功后补一句
`if (disposeOnUpload) readable = false;`（fork `:2317`），紧接着 `:2320-2324` 的
`if (!readable && image != null) { __surface = null; image = null; }` 就把 CPU 副本丢了。
→ 由 openfl 自己在**第一次上传的那一帧**释放：**零额外纹理、零临时 buffer、零时序风险**。
这是 hardware-only 最省的实现，也是 FE `full` 模式缺的东西。

**(b) 运行期路径 —— 有 bug 的那条。** `cacheBitmap` 里 `allowGPU && cacheOnGPU && !thread`
时走 createRectangleTexture → uploadFromBitmapData → fromTexture（:533-541）：

```haxe
var texture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true); // :535
texture.uploadFromBitmapData(bitmap);
bitmap.image.data = null; bitmap.dispose(); bitmap.disposeImage();
bitmap = BitmapData.fromTexture(texture);
```
- ⚠️ `optimizeForRenderToTexture` **误传 true**。`RectangleTexture.hx:39` → `TextureBase.hx:126-160`
  为每张图额外 `createFramebuffer` + `createRenderbuffer(DEPTH/STENCIL)` + `renderbufferStorage(w,h)`，
  每像素多约 3 字节 ≈ **+75% 显存**；openfl 自己的 `getTexture():2260` 传的是 `false`。
- ⚠️ `fromTexture()` 有一次性 `w*h*4` 的 CPU 临时分配（`BitmapData.hx:1397` 构造 → `:1401 image = null` 丢弃），
  批量转换的峰值 = 全量 CPU + 全量纹理 + 被丢的临时 buffer。
- 无 `try/catch`、无 context3D 判空（:535 直接解引用）。FE 的 `makeHardwareOnly`（`Paths.hx:979-1008`）
  有兜底，但**同样传了 `true`**（`:990`），见 5.①。
- `cacheBitmapPBO`（:554-568）走 fork 的 `getTextureAsync`（fork `:2330-2388`）：先
  `createRectangleTexture(..., false)` 预分配，再每帧 `texSubImage2D` 一个瓦片（默认 1024²），
  传完回调。设计正确，但有坑，见 5.⑦。

### 2.5 GC

- `clearUnusedMemory(true)` 才 `cpp.vm.Gc.run(true)`（`Paths.hx:132-139`），默认 false。
- `GCManager.enable(false)` 包住整个 LoadingState（`LoadingState.hx:259` → `:348`）和
  `PlayState.create()`（`PlayState.hx:389` → `:930`），加载/建场景期间完全停 GC。
- 倒计时开始 `GameplayGC.begin()`（`PlayState.hx:1430`）→ `GCManager.enterGameplay(...)`
  （`gc/GCManager.hx:308-328`），进游戏前一次 full GC，之后只跑 nursery。
- 这些 `__hxcpp_gc_*` 接口来自它们自己改的 hxcpp（仓库内 `hxcpp/`），**不可移植**。

### 2.6 预加载

一次性把所有 `imagesToPrepare` 丢进 `ThreadPool`（4 线程，`LoadingState.hx:384`），线程里
只 `BitmapData.fromFile(realPath, true)` 解码（:419），主线程 `checkLoaded` 逐个
`cacheBitmap(..., false)`。无 pin/keepAlive，因为**清理点在加载之前**：
`prepareSongCache()`（`LoadingState.hx:62-79`）只在 `mod|level|song` 变化时
`clearStoredMemory()+clearUnusedMemory()`；`cacheBitmap` 里 `Cache.trackLocalAsset(file)`
（`Paths.hx:531`）已把预载图标记为「本代碰过」，进 PlayState 不会被误收。
`PlayState.create()` 末尾只 `Paths.clearUnusedMemory(false)`（`PlayState.hx:931`），不带 GC。

## 3. Impostor 拆解

### 3.1 缓存结构（`funkin/backend/FunkinCache.hx:14-38, 102-106`）

`CacheMap<T>{cache:Map<String,T>, permanentKeys:Array<String>}` × 2（graphics / sounds）
+ `localTrackedAssets:Array<String>`。**没有 epoch、没有帧缓存**。`permanentKeys` 只给
`assets/music/freakyMenu.ogg` 用了一处（`Init.hx:75`），等价于 FE 的 `dumpExclusions`。

### 3.2 释放判定：state 边界 mark & sweep

```haxe
// PlayState.hx:620 —— create 一开始：只清声音，并把「本代碰过」清空
FunkinAssets.cache.clearStoredMemory();
// PlayState.hx:911 —— create 结束（super.create() 之后）：
FunkinAssets.cache.clearUnusedMemory();
```

`clearStoredMemory()`（`FunkinCache.hx:50-79`）不碰图形，只清声音 + `localTrackedAssets.resize(0)`；
此后 create 里所有 `Paths.image()` 命中都会 `localTrackedAssets.push(key)`（`FunkinAssets.hx:157`），
到末尾 `clearUnusedMemory()`（:84-98）把没被碰过的图全部清掉。**一次 create 就是一整代**，
前提是「建场景期间必然把所有要用的图都碰一遍」。

### 3.3 销毁实现：不看引用、不排队

```haxe
// FunkinCache.hx:149-153
if (graphic.bitmap.__texture != null) graphic.bitmap.__texture.dispose();
@:nullSafety(Off) FlxG.bitmap.remove(graphic);   // 内部还会 destroy() → bitmap.dispose()
```

`removeFromCache`（:114-141）直接调它再 `currentTrackedGraphics.remove(key)`。
**完全不检查 `useCount`** —— 只要「这一代没碰过」就立刻杀。FE 踩过的那个坑
（精灵池还攥着 frames）在这里理论存在，它靠「对象都在 create 里加载」兜住。

### 3.4 GPU caching：只丢 CPU 副本（`FunkinCache.hx:161-175`）

`if (allowGPU && ClientPrefs.gpuCaching) bitmap.disposeImage();`（默认 true）。
上游 `disposeImage()` 只是 `readable = false`（`BitmapData.hx:823-826`），真正的 CPU 释放
发生在**下一次上传纹理时**：`BitmapData.hx:2314-2318` 的 `getTexture()` 里
`if (!readable && image != null) { __surface = null; image = null; }`
→ 语义 = 「第一次画到它时丢 CPU 像素」。FE 的 `auto` 模式（`Paths.hx:1064` `disposeCPUImage`）
**已经是同一套**，没有新东西可抄。风险：预载了但没画到的图 CPU 副本会一直留着。

### 3.5 GC

`clearUnusedMemory()` 末尾无条件 `System.gc()` + `cpp.vm.Gc.compact()`（`FunkinCache.hx:94-97`），
每次进 PlayState 一次。FE 已学过去（`Paths.hx:52-61`），但挂在默认关闭的 `frequentGC` 后面。

### 3.6 预加载与缺失能力

**没有 LoadingState / Preloader**（`find source -iname "*Preload*"` 为空）。全部同步 JIT：
`PlayState.create()` 里直接 `new CharacterGroup(...)` 拉图，用加载卡顿换内存峰值。
`FreeplayState.hx:177-178` 甚至把 `clearUnusedMemory()` 注释掉了，只清声音。
降采样 / 纹理压缩 / LRU / 显存预算 / 分批预载：**全部不存在**（全仓库 grep
`lru|budget|memoryLimit|downscale|textureScale` 无命中，`lowQuality` 只影响粒子数量）。

## 4. 三方对比

| 维度 | FE 现状 | NovaFlare | Impostor |
|---|---|---|---|
| 键 | 实际文件路径 | 实际文件路径 | 实际文件路径 |
| 记账 | `trackedEpochs:Map<key,epoch>`，+1/次，保留 2 代（`Paths.hx:74-77,229-233`） | `localTrackedAssets:Array<key>`，单代（`Cache.hx:42`） | `localTrackedAssets:Array<key>`，单代（`FunkinCache.hx:106`） |
| 引用计数 | 读 `useCount`，有引用进 `pendingReleases`（`Paths.hx:307-346`） | 交给 flixel `persist/destroyOnNoUse` | 完全不看 |
| 销毁出口 | 自建 `destroyGraphic`：`__texture.dispose()` + `FlxG.bitmap.remove`（`Paths.hx:378-399`） | 无自建，走 `bitmap.dispose()` → **漏纹理**（fork 也没补） | 自建 `disposeGraphic`：显式 `__texture.dispose()` + `remove` |
| GPU 策略 | 三态 `full`/`auto`/`disabled`；`full` 走 `makeHardwareOnly`，**optimizeRTT=true**（`Paths.hx:990`） | 预载用 fork `disposeOnUpload`（最优）；运行期 hardware-only **optimizeRTT=true**（`Paths.hx:535`） | 二态默认开；只 `disposeImage()` |
| CPU 副本何时释放 | `full`=转换时；`auto`=首次绘制 | 预载=首次绘制后由 openfl 丢；运行期=转换时 | 首次绘制 |
| 预载是否传显存 | **是**（`LoadingState.hx:521` 默认 allowGPU=true） | **否**（`LoadingState.hx:368` 传 false） | 无预载，JIT 加载 |
| 预载线程 | `FixedThreadPool`（`LoadingState.hx:598`） | `ThreadPool` 4 线程（`LoadingState.hx:384`） | 无 |
| 清理时机 | 进 PlayState **前**（`PlayState.hx:644-647`）→ 需要 pin | 加载**前**，且仅 context 变化时（`LoadingState.hx:62-79`） | create **末尾**（`PlayState.hx:911`）→ 不需要 pin |
| GC | `frequentGC` 可选 `Gc.compact`（默认关） | `Gc.run(true)` 仅显式请求；加载期停 GC | 每次进歌 `System.gc()+Gc.compact()`，无条件 |
| 降采样/压缩/LRU/预算 | 无 | 无 | 无 |

## 5. 值得移植清单（按性价比排序）

**① `optimizeForRenderToTexture` 改为 false**
做法：FE `Paths.hx:990` 末参 `true` → `false`（与 openfl 自己的 `BitmapData.getTexture():2260` 一致）。
证据：`RectangleTexture.hx:39` + `TextureBase.hx:126-160`（每张图多一套 FBO + DEPTH/STENCIL RBO）。
成本：**极低**（一个字符）。收益：**极高** —— full 模式省约 3B/px，8GB 级预载约省 2~3GB，
`Fatal Finale` 的 5.76→8.76GB 里这部分是纯浪费。风险：仅当之后要 `setRenderToTexture` 时才需要
true，FE 没有这种用法。

**② 预载不传显存（allowGPU=false），改为运行期按需上传**
做法：`LoadingState.checkLoaded` 改 `Paths.cacheBitmap(key, bitmap, false)`；`full` 语义从
「预载即上传」改成「首次被 `image()` 索取时上传」（FE 已有该分支 `Paths.hx:1027-1029`）。
证据：NovaFlare `LoadingState.hx:368` vs FE `LoadingState.hx:521`。
成本：**低**（一行）。收益：**高**（不再一次性顶满显存）。风险：每张图首帧上传 hitch 搬进
游戏内 —— 建议在 loading 界面还在时，只对白名单（角色/舞台/UI）做一次 `getTexture()` warm-up。

**③ 用 fork 的 `disposeOnUpload` 语义替换 `makeHardwareOnly`（根治，代价是给 openfl 打 4 行补丁）**
做法：给上游 openfl 加 `public var disposeOnUpload:Bool = false;`（fork `:178`）、
`fromFile(path, disposeOnUpload)`（fork `:1350/:3361`）、以及 `getTexture()` 上传成功后的
`if (disposeOnUpload) readable = false;`（fork `:2317`）。之后 `full` 模式只需在 `image()` 里
标记，不必 `createRectangleTexture + uploadFromBitmapData + fromTexture`。
证据：fork `BitmapData.hx:2308-2324`（`readable=false` 立即触发 `image = null`）。
成本：**中**（patch openfl + 重编；FE 用的是 `E:/.../openfl/git`，能直接改，但会影响同机其它项目）。
收益：**高** —— 去掉 `fromTexture` 的 `w*h*4` 临时 buffer、去掉 FBO/RBO、去掉 `clone()` 共享
`__texture` 的 owner 问题（`BitmapData.hx:418-433`，任一方 dispose 另一方永久黑）。
风险：`readable=false` 后 `getPixel32` 静默返回 0、`getPixels` 返回 null；**Cairo 生成的图
（Graphics/TextField）绝不能标记**（fork 自己在 `CairoGraphics.hx:468/1891` 显式置 false）。

**④ 同一首歌重开不复用旧缓存 → 改成 context key 判断**
做法：记录 `mod|level|song`，只在变化时才在 PlayState 入口 `clearStoredMemory()+clearUnusedMemory()`。
证据：NovaFlare `LoadingState.hx:62-79`；FE `PlayState.hx:644` 是无条件清。
成本：**低**。收益：**高**（重开歌省一次全量解码和一次 8GB 级峰值）。风险：编辑器/热重载
改文件后吃旧图 → 非编辑器模式才启用。

**⑤ 把清理点从 create 开头挪到 create 结尾**
做法：开头只 `clearStoredMemory()`（换代标记），`super.create()` 后 `clearUnusedMemory()`；
随后可删掉 `pinGraphic/pinSound` 及 `LoadingState:520-522` 那套补丁。
证据：Impostor `PlayState.hx:620` + `:911`；FE `Paths.hx:113-126` 的 pin 正是为了对冲「create 开头就清」。
成本：**中**（需验证 pendingReleases 不会在 create 期间堆积）。收益：**中-高**（记账简化）。

**⑥ 按销毁量阈值触发 `Gc.compact()`**
做法：`destroyedSinceGc` 或释放字节超阈值才 compact，且只在 loading 界面执行。
证据：Impostor `FunkinCache.hx:94-97`；FE 已有 `Paths.hx:52-61` 但默认关。
成本：**低**。收益：**高**（RSS 真正回落，单次 `System.gc()` 常常纹丝不动）。风险：长停顿。

**⑦ 分片上传 `getTextureAsync`（想消掉预载卡顿才上，成本最高）**
证据：fork `BitmapData.hx:2330-2388` + `_internal/AsyncTextureUploader.hx`。三个必看坑：
(a) 渲染仍走同步 `getTexture()`（`ShaderInput.hx:172`），图在屏上时会把同一张纹理**再全量传一次**，
与异步瓦片交叉写 —— 上传期间该图必须不在显示树里；(b) `init()` 早退时 `onComplete` 永不回调，
`await` 风格会挂死；(c) 每瓦片临时分配 = `sliceSize²*4`（默认 1024 → 4MB/片）。
成本 **高**（vendor 上传器 + 改调度），收益 **中**（把尖峰摊到 N 帧）。

**⑧ 加载期停 GC、加载完补一次 full GC**（NovaFlare `LoadingState.hx:259/348`、`PlayState.hx:389/930`）
成本 **中**（异常路径必须恢复 enable），收益 **中**（消除加载期 GC 抖动）；风险：加载期垃圾
全积压、RSS 峰值更高 —— 只建议包住「线程解码产出的临时 BitmapData」这一段。

**⑨ 不可移植 / 反面教材**
`GameplayGC`/`enterGameplay`（`gc/GCManager.hx:285-362`）需 fork hxcpp；
Impostor 的 `disposeGraphic` 不看 `useCount`（`FunkinCache.hx:149`）会让 FE 的 Note 池拿到已销毁
frames；NovaFlare 的 GPU 路径无 try/catch（`Paths.hx:535`）；两家都没有降采样/LRU/预算。

## 6. 疑点

1. NovaFlare 的 `releaseGraphicWhenUnused` 在 `useCount==0` 时会**立刻**
   `FlxG.bitmap.remove→destroy`；若某 sprite 正在 `draw()` 里还没 increment，理论上会拿到
   已销毁对象。FE 的 `pendingReleases` 正是为了避开这一点，**不要**改回这种写法。
2. `__texture.dispose()` 之后 `bitmap.__texture` 引用仍非 null 且 `__textureContext` 没变，
   `getTexture()` **不会重建纹理** → 永久黑图且不报错。释放必须
   `__texture.dispose()` + `bitmap.dispose()` 两条一起（FE `destroyGraphic:384-398` 已经是）。
3. `readable=false` 时 `getPixel32` 返回 0、`getPixels` 返回 null（静默 no-op 不崩）；
   会炸的是「`readable=true` + `image=null`」，别手动造。
4. Impostor 的 `gpuCaching` 默认 true 意味着所有图 `readable=false`；FE 若把 `auto` 设为
   默认，需先扫一遍 `getPixels`/`draw` 调用点。另：它没有加载界面，「create 里同步加载 + 末尾扫」
   的收益部分来自它敢卡加载；FE 有 LoadingState，照搬 ⑤ 效果会打折，但仍能省掉 pin 记账。
5. `Fatal Finale` 的 8.88GB 是「预载总量」不是「同时存活量」。两家都无法降低「一局里所有图
   同时活着」的上限；真正的解只有 ①②③（减少重复解码与无谓上传）或做预算淘汰，而后者两家都没有。
