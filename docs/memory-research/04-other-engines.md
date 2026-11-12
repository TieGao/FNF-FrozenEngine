# Codename / NMV / FE-0.4("Vulkan") / Psych-Online 资源与内存管理调查

调查日期 2026-11-12，**只读**（无编译、无 checkout）。仓库：`D:/funkin-sources/`。
已有 `01-openfl-gpu-caching.md`、`02-novaflare-impostor.md`、`05-flixel-graphics.md` 覆盖 openfl/flixel/NovaFlare/Impostor，
本文只写这四家，重复处一句带过。

## 1. 一句话总览

| 引擎 | 水平 | 一句话 |
|---|---|---|
| Codename Engine | **进阶** | 直接换掉 openfl 全局 `AssetCache`，做「**两层代际缓存**」：切场景时前一层里没被新场景再要一次的资源整批清掉（BitmapData/Sound/Font 全覆盖）；但**没有**显式 `__texture.dispose()` |
| NightmareVision (NMV) | **进阶** | 与 Psych 同源的 key 记账 + `localTrackedAssets`，补齐了 `bitmap.__texture.dispose()`、`Gc.compact()`、原生 RSS 读数、跨场景常驻 key；仍无预算/降采样 |
| FNF-FrozenEngine-Vulkan | **基础**（**不是 Vulkan**） | 实为 FE **0.4.10**（flixel 5.9.0）历史分支；`destroyGraphic` + 显示树 mark&sweep + `SpritePool`，大半已被 FE 0.6 继承 |
| Funkin-Psych-Online | **基础** | Psych 原版 `clearUnusedMemory`，用 `obj.destroy()` 顶替纹理释放，`cacheOnGPU` 整段被注释掉（`Paths.hx:344-355`），网络层之外无独门内存技术 |

**四家里没有任何一家做「纹理降采样」或「按显存预算淘汰」**（Q4 的答案），也没有角色懒加载（Q6），
图集拆分只有「美术侧预先拆成 1..N.png，引擎负责拼」（Q5）。

## 2. 逐个拆解

### 2.1 Codename Engine

**资源结构**：不是 Psych 的 `Map<String,FlxGraphic>`，而是把资源组织成 lime `AssetLibrary` 列表
（`backend/assets/AssetsLibraryList.hx:11-30`：`libraries:Array<AssetLibrary>` + `rootDirectory`）。
查找走 `getAssetPathLibrary()`（`:65-121`），带**按时间过期的 id→library 解析缓存**
（`Flags.PATHS_CACHE_LIFETIME`，`Flags.hx:64`，默认 null=永不过期），注释写明是为了多键谱面 2k+ note 不卡。
`Paths.image()` 只负责拼路径（`Paths.hx:158-168`），真正的解码在 `Paths.getFrames/loadFrames`（`Paths.hx:381-412`），
最终仍落到 `FlxG.bitmap.add(path, Unique, Key)`——**没有自己的 FlxGraphic 记账表**，这点比 Psych 更"轻"。

**释放时机（核心）**：`funkin/backend/system/modules/FunkinCache.hx` 继承 `openfl.utils.AssetCache`，
在 `Main.hx:126` 用 `openfl.utils.Assets.cache = new FunkinCache()` **替换全局缓存**（`:36`）：

- `preStateSwitch` → `moveToSecondLayer()`（`:47-54`）：把 `bitmapData/font/sound` 整表挪到 `xxx2`，当前层清空；
- `postStateSwitch` → `clearSecondLayer()`（`:56-71`）：`xxx2` 里剩下的（= 新场景**没**再请求过的）
  逐个 `FlxG.bitmap.removeByKey(k)` + `LimeAssets.cache.image/audio/font.remove(k)`；
- `getBitmapData/getSound/getFont`（`:79-128`）命中第二层时**降级晋升**回第一层。

这就是一套**分代 GC**：等价于「跨越一次场景切换 = 上升一代，未幸存即死」。它比 FE 的 `useCount` 方案更抗打，
因为它不依赖「精灵是否真的 destroy 了去 decrement」——`localTrackedAssets` 那种表它压根没有。
flixel 6 的 `BitmapFrontEnd.removeByKey()` 是**无条件** `graphic.destroy()`（`flixel/system/frontEnds/BitmapFrontEnd.hx:260-270`），
所以即使还有精灵引用也会被抽掉——这是它"敢删"的前提，也是它最大的风险。

**销毁实现**：Codename 全仓只有一处 `dispose()` 跟图形无关（`BloomEffect`），**没有任何 `__texture.dispose()`**。
显存回收完全押在 flixel `FlxGraphic.destroy()` → openfl `BitmapData.dispose()` 上。
openfl-probe 已核实这条链**是断的**：`dispose()` 只把 `__texture` 置 null（`openfl/display/BitmapData.hx:787`），
`gl.deleteTexture` 整块被注释（`:790-808`），全仓只有 `TextureBase.hx:96` 一处生效，没有上下文兜底/纹理池/finalizer。
→ **Codename 每次切场景丢掉的图，纹理全部滞留到进程结束**。对比 NMV/FE 的 `destroyGraphic`，这是硬伤（详见 §5 疑点 4）。

**按 mod 卸载能力**：有，但是**核弹级**——`ModsFolder.reloadMods()` → `FlxG.switchState(new MainState())`
（`ModsFolder.hx:77-80`），`MainState.create()` 里一口气
`FlxG.bitmap.reset()` / `FlxG.sound.destroy(true)` / `FlxG.sound.resetCache()` / `Paths.assetsTree.reset()`
（`system/MainState.hx:41-45`）。`AssetsLibraryList.removeLibrary()`（`:36-55`）**定义了但全仓无调用者**（死 API），
`unloadLibraries()`→`AssetLibrary.unload()` 只清 lime 内部 `cachedBytes/cachedImages` 表（`lime/utils/AssetLibrary.hx:647-654`），**不 dispose**。所以答案是：
**能按 mod 全卸，但实现是"全部重建"，没有单 mod 粒度**。

**特色**：
- `GraphicCacheSprite`（`system/GraphicCacheSprite.hx:28-56`）：预加载精灵。`cacheGraphic()` 把 `useCount+1`、
  `destroyOnNoUse=false`，并在 `draw()` 里 `loadGraphic()+drawComplex()` **强制首帧上传 GPU**（`:57-62`）；
  `destroy()` 时把 `destroyOnNoUse=true`、`useCount-1`，实现**预载与释放自动配平**。等价于 FE 的 `pinGraphic` + 额外"预热绘制"。
- 帧缓存带**自校验**：`Paths.hx:260-264` 返回 `tempFramesCache[key]` 前检查 `frames.parent.bitmap != null`，
  失效即丢弃重载；且 `preStateSwitch` 时 `tempFramesCache.clear()`（`Paths.hx:24,30-36`）。
- 多图集：`loadFrames()` 自动探测 `images/<key>/1.png..N.png`（`Paths.hx:387-395`）并递归；
  `getMultiFrames()`（`:279-341`）把多张 PNG 合成**一个** `FlxFramesCollection`，每张图仍是独立 `FlxGraphic`。
  即「P4 拆图」在引擎侧**已经支持**，只差美术拆文件。
- 资产**直读磁盘**（`ModsFolderLibrary.getImage/getBytes/getAudioBuffer`，`:43-78`，同时记 `editedTimes[id]=mtime`），
  天然热重载；`getEditedTime()`（`:39`）是个预留钩子，**全仓无消费者**。代价：绕过 lime 缓存 → 每次请求都重新解码。
- `SystemInfo.hx:106-121` 读 `Context3D.__glMemoryTotalAvailable` 拿**显存总量**（仅用于系统信息面板显示，
  没有任何淘汰逻辑）；同文件 `:108-111` 拿 `FlxG.bitmap.maxTextureSize`。

### 2.2 NightmareVision (NMV)

**资源结构**：`FunkinAssets.cache = new FunkinCache()`（`FunkinAssets.hx:23`），
`currentTrackedGraphics/Sounds/Texts` 三个 `CacheMap<T>`（`FunkinCache.hx:96-102`），
key = 实际路径。与 Psych 的差别是 `CacheMap` 多了一个 `permanentKeys`（`:19,34-37`）——
**永久常驻名单**，与"本代碰过"的 `localTrackedAssets` 正交，目前只在 `Init.hx:78` 用来钉住菜单音乐。

**释放时机**：`PlayState.create()` 开头 `clearStoredMemory()`（`PlayState.hx:573`）、结尾 `clearUnusedMemory()`（`PlayState.hx:831`，紧跟 `super.create()`），
即**进门先标记、加载完立刻结算**，正好在角色/舞台全部接管贴图之后。Freeplay/Title/StoryMenu 同款（`FreeplayState.hx:74`、`TitleState.hx:41`、`StoryMenuState.hx:53`）。

**销毁实现**（`FunkinCache.hx:110-149`）：

```haxe
public function disposeGraphic(g:Null<FlxGraphic>) {
    if (g != null && g.bitmap != null && g.bitmap.__texture != null) g.bitmap.__texture.dispose();
    FlxG.bitmap.remove(g);
}
```
`removeFromCache(key, disposeToo=true)` → 按 key 找三张表，命中即 `disposeGraphic`/`Assets.cache.clear`。
与 FE 的 `destroyGraphic` 几乎同构（FE 多了 epoch 记账与 pendingReleases 排队），**说明 FE 的核心销毁策略已经是这一代引擎里最细的**。

**GC**：`clearUnusedMemory()` 末尾 `openfl.system.System.gc()` + `#if cpp cpp.vm.Gc.compact()`（`:88-92`）。

**统计**：`external/memory/Memory.hx:19` 走 C 头 `getCurrentRSS()` 拿**进程 RSS**（`Native.hx:34` 暴露），
`DebugDisplay.hx:108-111` 注释明说"gcMemory 只反映堆，taskMemory 才是全程序"。（FE 的 `MemoryStats.hx` 已做到同等甚至更细，无增量。）

**GPU 策略**：`cacheBitmap(key, bitmap, allowGPU)` 在 `ClientPrefs.gpuCaching` 时 `bitmap.disposeImage()`（`FunkinCache.hx:157-171`），
即"只丢 CPU 侧 Image"；`FlxAnimate` 图集另有一处 `atlas.parent.bitmap.disposeImage()`（`FunkinSprite.hx:93-94`）。
没有 `createRectangleTexture` 级别的 hardware-only。

**多图集**：`getMultiAtlas(keys,...)`（`Paths.hx:329-356`）把多张 atlas 合并进一个 `FlxAtlasFrames`；
`FunkinSprite.loadAtlas("a,b,c")` 逗号分隔（`FunkinSprite.hx:76-97`）。同样是"美术先拆"。

**对脚本精灵的清理**：**没有**。`PlayState.destroy()`（`PlayState.hx:2913-2932`）只销毁 scripts/input/modManager/noteskins，
不遍历脚本变量表。所以「HScript/Lua 建了但没 add 到 state 的精灵」在 NMV 里同样会卡住 `useCount`——
**它靠的是"下次 create 时按代际清掉整张图"，而不是"按精灵引用清"。**这一点是 FE 可以直接借鉴的思路转向。

### 2.3 FNF-FrozenEngine-Vulkan（实为 FE 0.4.10）

**结论先说**：`Project.xml:5` 是 `Friday Night Funkin': Frozen Engine` v0.2.8、`flixel 5.9.0`；
`git log` 最新提交 `ebd85e3 "vuvlkan test"` 的全部内容是 `Main.hx` + 图形设置里加了个**分辨率选项**
（`Main.hx:202-236` 的 `renderResolution` + `resetSpriteCache`），**没有任何 Vulkan / SDL_GPU / 渲染后端改动**。
所以"Vulkan 分支"= 名字误会，`D:` 盘上不存在 Vulkan 实现（Q3 的答案）。它作为 FE 的**祖先版本**仍有参考价值：

- `Paths.clearUnusedMemory()`（`:39-54`）：与本代 FE 同源，`destroyGraphic` + `System.gc()`。
- `Paths.clearStoredMemory()`（`:57-80`）：遍历 `FlxG.bitmap._cache`，**不在 `currentTrackedAssets` 里的一律销毁**——
  连"不是自己加载的图"一起清，比 Psych 更狠。
- `Paths.freeGraphicsFromMemory()`（`:83-131`）：**显示树 mark & sweep**。递归读 `members`（组）与 `graphic`（精灵），
  收集所有存活 `FlxGraphic` 作为保护区，其余 tracked 图全销毁。调用点：`FreeplayState.hx:1347`、`OldFreeplayState.hx:536`、`StoryMenuState.hx:537`。
  **FE 0.6 已经原样保留了它**（`FE source/backend/Paths.hx:239`），但注意它的盲区：没 `add()` 进 state 的
  Lua 精灵不在 `members` 里 → 会被误判死亡。这正是 FE 现在痛点的镜像。
- `SpritePool.hx:1-53`：FIFO 对象池，`put()` 时 `resetObject()`（alpha/scale/velocity/`FlxTween.cancelTweensOf`）并回收，
  超容量才 `destroy()`。用于 `NoteSplash.pool`（`NoteSplash.hx:39`）、`PlayState.ratingPool/comboNumPool`（`PlayState.hx:321-322`）。
  FE 0.6 已改为"容器自带 recycle()"（`FE PlayState.hx:371-378`），语义一致。
- `Cache.hx:35-69`：`currentTrackedFrames` + `checkFrame()` 会二次校验 `graphic.imageFrame.frames.length > 0` 才认命中，
  否则移除。FE 已继承（`FE source/backend/Cache.hx`），**这是应对"图被销毁但帧缓存还留着"的正确做法**。
- `FreeplayState.hx:614-665`：`menuBgGraphicCache` 按 folder 缓存 `menuDesat` 图，避免切歌重复解码。

### 2.4 Funkin-Psych-Online

- `Paths.clearUnusedMemory()`（`:58-79`）：`FlxG.bitmap._cache.remove(key)` + `Assets.cache.removeBitmapData(key)` +
  `persist=false; destroyOnNoUse=true; obj.destroy()`。**没有 `__texture.dispose()`**，靠 flixel 的 destroy。
- `clearStoredMemory()`（`:81-96`）：对 `FlxG.bitmap._cache` 里所有非 tracked 项 `obj.destroy()`。
- `bitmapToGraphic()`（`:343-355`）：`cacheOnGPU` 那一整段 `createRectangleTexture/uploadFromBitmapData/fromTexture` **被注释掉**，
  客户端的 GPU Caching 选项也被注释（`GraphicsSettingsSubState.hx:44`）。
- 结论：**网络层之外没有独门内存技术**，且是四家里最弱的一档（连纹理显式释放都没有）。唯一值得记的：
  它把"缓存里有、记账表里没有"的图也一并 destroy（与 FE-0.4 `clearStoredMemory` 同思路）。

## 3. 横向能力矩阵

| 能力 | Codename | NMV | FE-0.4("Vulkan") | Psych-Online |
|---|---|---|---|---|
| 释放判定 | **两层代际**（跨场景未复请求即死，`FunkinCache.hx:47-71`） | 代际标记 `localTrackedAssets` + 永久 key（`FunkinCache.hx:70-92`） | `useCount` + 显示树 mark&sweep（`Paths.hx:83-131`） | `useCount`（`Paths.hx:58-79`） |
| 显式 GL 纹理释放 | ✗ **真漏**（`dispose()` 不删纹理，见 §5-4） | ✓ `bitmap.__texture.dispose()`（`:147`） | ✓（`:136-140`） | ✗ **真漏** |
| 降采样 | ✗ | ✗ | ✗ | ✗ |
| 按显存预算淘汰 | ✗（只读 VRAM 总量做显示，`SystemInfo.hx:112-121`） | ✗ | ✗ | ✗ |
| 图集拆分 | **✓ 引擎侧支持** `1..N.png` 自动拼（`Paths.hx:387-395,279-341`） | ✓ 仅多 atlas 合并（`Paths.hx:329-356`） | ✗ | ✗ |
| 角色懒加载 | ✗ | ✗ | ✗ | ✗ |
| 显存/内存统计 | GPU 名 + VRAM 总量 + maxTextureSize（`SystemInfo.hx:106-121`） | 原生 RSS（`Memory.hx:19`）+ 面板 | 无 | 无 |
| 脚本精灵清理 | ✗ | ✗（靠代际连坐） | ✗（`freeGraphicsFromMemory` 扫不到未 add 的） | ✗ |
| 帧缓存失效校验 | ✓ `parent.bitmap != null`（`Paths.hx:260-264`） | ✗ | ✓ `checkFrame`（`Cache.hx:40-59`） | ✗ |
| 场景级全清 | ✓ `MainState.hx:41-45`（连 sound 一起） | 部分（songs only） | ✗ | ✗ |

## 4. 值得抄清单（按性价比排序）

**① 把"代际"从 FlxGraphic 层抬到 openfl `AssetCache` 层（Codename）**
来源：`FunkinCache.hx:12-128`、`Main.hx:126`。做法：`Assets.cache = new FunkinCache()`，
pre/postStateSwitch 双层降级，第二次没被请求就 `FlxG.bitmap.removeByKey + LimeAssets.cache.image.remove`。
收益：把"谁还记得这张图"从 `useCount` 这个不可靠信号，换成"新场景有没有再要一次"这个真实信号——
直接绕开 FE 当前"Lua 精灵不进 members → useCount 卡 1"的死结。成本：~200 行 + 需要 flixel 6（FE 已是 6.2.1）。
风险：**必须有排队机制**，否则就是 FE 0.4 那条"直接 destroy 抽掉别人还在用的图集"的老路；
FE 已有 `pendingReleases/flushReleasedGraphics`，可以套在 `clearSecondLayer` 前面做闸门。
**并且必须连 FE 现成的 `destroyGraphic` 一起用**——Codename 漏纹理正是因为少了那两行，
顺序还不能倒：只 `__texture.dispose()` 会因 `__textureContext` 未变而永久黑图，只 `bitmap.dispose()` 就是 Codename 的漏。

**② 帧缓存有效性校验 + 切场景清帧缓存（Codename）**
`Paths.hx:260-264` 返回前校验 `frames.parent.bitmap != null`，`Paths.hx:30-36` 在 `preStateSwitch` 清空。
对 FE 的意义：**这正是 P4 降采样最危险的地方**——改了 `FlxFrame.frame` 会撞 flixel 的 `cacheFrameMatrix`；
而 `Cache.currentTrackedFrames`（`FE source/backend/Cache.hx`）里存的是 `FlxFramesCollection`，
一旦底层 graphic 被 `destroyGraphic` 掉而帧缓存没校验，就是"角色全炸"。成本：10 行。风险：极低。

**③ 预加载"预热绘制 + 自动配平"（Codename）**
`GraphicCacheSprite.hx:28-62`。预载 = `incrementUseCount` + 首帧 `drawComplex()` 强制上传；销毁 = 还原引用。
FE 的 `pinGraphic` 只做前半段（撑过清理），没有"强制上传"，也没做"预载了但没人用 → 自动还回去"。
收益：预载不抖动 + 未使用的预载图不会永久钉死。成本：~30 行改造 `pinGraphic/unpinGraphics`。风险：低。

**④ 多图集自动探测 `1.png..N.png`（Codename）**——P4 拆图的现成引擎侧方案
`Paths.hx:387-395` 递归探测、`Paths.hx:279-341` 合并；`Paths.image()` 里 `images/<key>/1.png` 存在则优先（`:160-166`）。
收益：一次改 `Paths.image/getFrames`，所有角色/舞台自动支持"美术把一张 8K 图拆成 4 张 2K"，
每张独立 `FlxGraphic` → 单张不超 `maxTextureSize`，也能被单独淘汰。成本：中（30~60 行 + 加载器适配）。
风险：`FlxFrame` 的 sourceSize/offset 必须由 XML 决定（Codename 靠"每个分片自带 xml/txt"），
拆图后 XML 也得拆；对现有 mod 不兼容（只能新 mod 用）。

**⑤ 把声音纳入场景级回收（Codename `MainState.hx:41-45`）**
`FlxG.sound.destroy(true)` + `FlxG.sound.resetCache()` 与贴图同期执行。
FE 目前声音只清 `Assets.cache`（`Paths.hx:168`）与 `cache.clear("songs")`（`:180`），没做 `FlxG.sound.destroy`。
收益：长会话下 `Sound` 的 native buffer 是除贴图外最大一块。成本：3 行（放在切歌/回主菜单处）。风险：中——必须确认没有跨场景常驻的 Sound 实例。

**⑥ 显存总量读数（Codename）作为预算淘汰的**前置**（不是方案本身）**
`SystemInfo.hx:112-121`：`context3D.gl.getParameter(Context3D.__glMemoryTotalAvailable)` + `FlxG.bitmap.maxTextureSize`。
四家里**没有任何一家**据此淘汰（Q4=无）。若 FE 要做 P2/P4 的预算门控，只能自己写：
用 `MemoryStats` 已有的贴图解码字节统计 + 这两个 GL 查询做"软上限"。
成本：中；风险：`__glMemoryTotalAvailable` 在部分驱动返回 1000/1/-1（Codename 自己就做了这个防御，`:114-116`）。

**⑦（反向警示）`freeGraphicsFromMemory` 的显示树 mark&sweep 已经是 FE 的一部分，但它是双刃剑**
`FE source/backend/Paths.hx:239-296`。它能救"图集被别处误删"，但**保护不了没进 state 的 Lua 精灵**——
`makeLuaSprite` 建了却没 `addLuaSprite` 的对象，既不在 `members` 也不在 `pendingReleases` 的引用里。
若要继续用它，必须先把脚本变量表（`LuaScript` 的 globals / `modchartSprites`）也纳入 mark 根集合。

## 5. 疑点

1. **"Vulkan 分支"名不副实**：该仓库是 FE **0.4.10**（flixel 5.9.0，`gitVersion.txt`=`0.4.10`），最新提交 `ebd85e3` 只加了分辨率选项。
   要真正的 Vulkan 纹理池/staging/BC7 材料，**D 盘没有**，得另找或放弃 P3 这条路。
2. **Codename `removeLibrary()` 是死 API**（`AssetsLibraryList.hx:36` 定义，全仓无调用）。
   不要把"支持单 mod 卸载"写进它的能力表；它实际只有"重进 MainState 全部重建"。
3. **Codename `unload()` 不 dispose**：`lime/utils/AssetLibrary.hx:647-654` 只 `clear()` 内部 map。
   所以它的显存回收 100% 依赖 flixel `removeByKey → FlxGraphic.destroy()` 这条断链。另：NMV 的 `permanentKeys` 只用于 1 个 key（`Init.hx:78`），
   属设计留白而非成熟机制，FE 的 `pinGraphic` 语义更完整，不必回退。
4. **`BitmapData.dispose()` 不删 GL 纹理（openfl-probe 已核实，见 `01-openfl-gpu-caching.md` Q4/Q8）**：
   `openfl/display/BitmapData.hx:787` 只 `__texture = null`，`gl.deleteTexture` 整块在 `:790-808` 被注释（且顺序写反）；
   `disposeImage()`（`:823-826`）全文只有 `readable = false`。全仓唯一生效的 delete 在 `TextureBase.hx:96`，
   `Context3D` 无纹理登记表、`SamplerState` 不持有纹理、无池/WeakRef/finalizer，flixel 6.2.1 也没补丁
   （`FlxGraphic.hx:449` 一路到 `dispose()` 为止）→ `__texture = null` 之后只是孤立 GL name，活到 context 销毁。
   ⇒ Codename / Psych-Online **切场景真漏纹理**；FE 的"先 `__texture.dispose()` 再 `bitmap.dispose()`"是**必需**且**顺序不能倒**
   （只 dispose 纹理 → `__textureContext` 未变 → `getTexture()` 不重建 → 永久黑图；只 `bitmap.dispose()` → 漏）。
   `__vertexBuffer/__indexBuffer` 也一起漏（约 248 B/图，量级远小于 `w*h*4`）。
5. **NMV 的代际清理有前提**：`clearUnusedMemory()` 在 `PlayState.create()` 末尾执行，
   假设"新场景 create 期间会把所有还需要的图重新请求一遍"。任何"跨场景持有 + 不再请求"的图（脚本里囤的）
   都会被 `__texture.dispose()` 掉。FE 若照抄 ②，必须保留 `pendingReleases` 作为安全阀。
6. **四家全都没有降采样**：所以 P2（按显存预算淘汰）与 P4（拆图/降采样）**没有现成参考实现**，
   Codename 只能给出"多文件拆图 + VRAM 总量读数"两块零件，其余得 FE 自研。
