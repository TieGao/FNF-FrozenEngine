# 03 · Psych 各版本 与 官方 Funkin 0.8.7 的资源/内存管理演变

> 调查对象：`D:/funkin-sources/` 下的 Psych 0.1.1 / 0.4.2 / 0.6.3 / 0.7.3 / 1.0 / 1.0.1 / 1.0.2h / 1.0.3 / 1.0.4 / 1.0.4-OG / EK-0.4.6 / Mobile-1.0.4、以及官方 `Funkin/`（0.8.7）。
> 全部只读，未修改任何文件。

## 1. 一句话总览

**Psych 全系（0.1.1 → 1.0.4 + EK + Mobile）从来没有引用计数、没有 LRU、没有显存预算、没有运行时降采样**；
它的内存模型始终是「一张全局 Map<路径, FlxGraphic> + 一个 `localTrackedAssets` 使用列表 + 三处手动调用点」，
版本演进只做了一件事——**把 `obj.destroy()` 逐步换成"先 dispose 掉 GL 纹理再 destroy"**。
真正的按需/代际缓存是官方 Funkin 0.8.7 的 `FunkinMemory` 做的，但它也**没有预算/LRU/降采样**，
唯一"控显存"手段是**离线 ASTC 压缩**（构建期，非运行时）。⇒ Fatal Finale 那个 8.88GB 预载问题，
在这两个谱系里都**没有现成答案**。

## 2. 版本演进表

| 版本 | 引用计数 | 销毁时动 GL 纹理 | 存活表结构 | 清理时机 | 预加载 pin | 降采样/压缩/预算 |
|---|---|---|---|---|---|---|
| 0.1.1 | 无 | 无（`image()` 只返回字符串路径，交给 `FlxSprite.loadGraphic` / OpenFL） | 无 | 无 | 无 | 无 |
| 0.4.2 | 无（`customImagesLoaded:Map<String,Bool>` 只是"载过没"） | 是，但**全量 flush**：`bitmap.dispose()`+`destroy()` | `Map<String,Bool>` + `FlxG.bitmap` 全局表 | 切状态时 `destroyLoadedImages()` | 无（`ClientPrefs.imagesPersist` 只决定**跳过**清理） | 无 |
| 0.6.3 | 无（`localTrackedAssets` 是"本代用过"的 Array，不是计数） | 否，只 `obj.destroy()` | `currentTrackedAssets:Map<String,FlxGraphic>`（key=实际路径）+ `localTrackedAssets:Array<String>` | 各 State 手动调 `clearUnusedMemory`/`clearStoredMemory` | 无 | 无 |
| 0.7.3 / EK-0.4.6 | 同上 | 否，但先 `persist=false` + `destroyOnNoUse=true` 再 `destroy()` | 同上 | 同上 | 无 | 无（但新增 `cacheOnGPU`：上传 `RectangleTexture` 后丢 CPU 拷贝） |
| 1.0 / 1.0.1 / 1.0.2h | 同上（1.0.1 与 1.0.2h 的 Paths.hx 逐字节相同） | **是**：`destroyGraphic()` 里 `bitmap.__texture.dispose()` + `FlxG.bitmap.remove()` | 同上（key 变为 `images/xxx.png` 逻辑 key） | 同上 | 无 | 同上 |
| 1.0.3（== 1.0.4-OG） | 无，但新增"遍历场景找活引用" | 同上 | 同上 + `freeGraphicsFromMemory()` 用 `FlxG.state.members` 反射出的 `graphic` 当白名单 | + `PlayState.create()` 预载后清一次 | 无 | 无 |
| 1.0.4（第三方中文 fork，NovaFlare 血统） | 同上，另有 `backend/Cache.hx` 记 frame/anim | 同上 | 同上 | 同上 | 无 | 无 |
| Mobile-1.0.4 | 同上 | 同上 | 同上 | 同上 + **`cpp.NativeGc.run(true)`** | 无 | 无 |

> 关键否定结论：在 Psych 全系源码里 `grep "useCount"` **零命中**（`Paths.hx` 从未读过 `FlxGraphic.useCount`）。
> `pinGraphic/pinSound/trackedEpochs/pendingReleases/downscale/maxTextureSize/LRU` 在所有 Psych 目录里也**零命中**。

## 3. 逐版本要点（只写有差异的）

### 3.1 Psych 0.4.2 —— "切状态全清"
- `source/Paths.hx:37` `destroyLoadedImages()`：遍历 `customImagesLoaded` 的 key，`graphic.bitmap.dispose(); graphic.destroy(); FlxG.bitmap.removeByKey(key)`，然后 `clear()`。
- `source/Paths.hx:307` `addCustomGraphic()`：mod 图 `persist=true` + `FlxG.bitmap.addGraphic()`，**按逻辑 key（不是路径）入表** ⇒ 不同 mod 同名图会互相覆盖。
- 调用点：`CustomFadeTransition.hx:87`、`ChartingState.hx:171`、`FreeplayState.hx:51`、`PlayState.hx:253`、`StoryMenuState.hx:55`
  ⇒ 每次切歌/切菜单**全部重载**。这是"能跑但极慢"的原始形态。

### 3.2 Psych 0.6.3 —— 引入 tracked 表（第一个真正的缓存层）
- `source/Paths.hx:67` `clearUnusedMemory()`：遍历 `currentTrackedAssets`，key 不在 `localTrackedAssets` 且不在 `dumpExclusions` 就
  `openfl.Assets.cache.removeBitmapData(key)` + `FlxG.bitmap._cache.remove(key)` + `obj.destroy()`，最后 `System.gc()`。
- `source/Paths.hx:90` `clearStoredMemory()`：反方向扫 `FlxG.bitmap._cache`，不在 `currentTrackedAssets` 的一律 destroy；**把 `localTrackedAssets = []` 清空**当作"代际翻页"。
- `source/Paths.hx:337` `currentTrackedAssets:Map<String,FlxGraphic>`，key 是**实际文件路径**（`mods/.../x.png` 或 `assets/.../x.png`）。
- `source/Paths.hx:369` `localTrackedAssets.push(key)` 无去重 ⇒ 一帧内重复请求会重复 push，`contains()` 是 O(n) 线性扫。
- 销毁**不碰 GL**：直接 `obj.destroy()`，而 `persist=true` 时 flixel 不会真销毁 ⇒ **这是 0.6.x 显存泄漏的根源**。

### 3.3 Psych 0.7.3 / EK-0.4.6 —— 两个小补丁（EK 的 Paths 与 0.7.3 **逐字节相同**）
- `source/backend/Paths.hx:51-53`：`obj.persist = false; obj.destroyOnNoUse = true; obj.destroy();`
  ⇒ 让 flixel 的 `destroyOnNoUse` 机制接管，但**仍然不 dispose `__texture`**。
- `source/backend/Paths.hx:273-282`：新增 `ClientPrefs.cacheOnGPU`，把 `BitmapData` 上传到 `openfl.display3D.textures.RectangleTexture`，
  然后 `bitmap.image.data = null; bitmap.dispose(); bitmap.disposeImage();` ⇒ **这是 Psych 唯一一次"主动管 GPU 侧"的尝试**，
  但它只是「把 CPU 拷贝扔掉」，纹理该多大还是多大，省的是 RAM 不是 VRAM。
- `:283-284` `persist=true` + `destroyOnNoUse=false` 写死 ⇒ 又回到"只能靠 destroyGraphic 显式销毁"。
- EK-0.4.6 的 `source-EK/backend/Paths.hx` 与 `FNF-PsychEngine-0.7.3/source/backend/Paths.hx` **完全一致**（`diff -q` 无输出），**没有任何独门技巧**。

### 3.4 Psych 1.0 / 1.0.1 / 1.0.2h —— 终于 dispose 纹理
- `1.0/source/backend/Paths.hx:83-89` `destroyGraphic()`：`if (bitmap.__texture != null) bitmap.__texture.dispose(); FlxG.bitmap.remove(graphic);`
  ⇒ **Psych 谱系里第一个真正释放 GL 纹理的版本**（靠 `@:access(openfl.display.BitmapData)` 才能读 `__texture`）。
- `1.0/source/backend/Paths.hx:204-213` GPU 路径改用 `bitmap.getTexture(FlxG.stage.context3D)` + `disposeImage()` + `image=null` + `readable=true`；
  失败时（`bitmap.image == null`）会静默跳过 GPU 缓存，**保留全量 CPU 位图**。
- 1.0.1 = 1.0.2h：只有翻译 key 与 `trace` 文案差异（`Paths.hx:196`）。**内存模型与 1.0 完全一致**。

### 3.5 Psych 1.0.3 / 1.0.4-OG —— `freeGraphicsFromMemory()`
- `1.0.3/source/backend/Paths.hx:83-136`（1.0.4-OG 同文件同位置）：
  反射遍历 `FlxG.state.members`（以及 `subState.members`），对每个成员取 `members`（组）或 `graphic`，
  收集成 `protectedGfx:Array<FlxGraphic>`，然后把 `currentTrackedAssets` 里**不在这份白名单里**的全部 destroy。
- 这是"不引用计数，改为扫场景找活引用"的近似方案。**已知漏洞**：
  - 只看 `FlxG.state` 一层 substate（`FlxG.state.subState.members`），**没有递归**，孙级 substate 的图会被误杀；
  - 只看 `graphic` 属性，HUD / `FlxCamera` / `FlxG.plugins` / 静态缓存里的图看不到；
  - `FlxSprite.frames` 指向的 `FlxAtlasFrames` 若由别的 sprite 共享，父 graphic 会随第一个 sprite 一起被算活，但**逐帧动画 atlas 里手写的 `graphic` 引用**看不到。
- 调用点只有两处：`FreeplayState.hx:443`（检测到 mod 目录变了）、`StoryMenuState.hx:355`。PlayState 里**没用**。
- `1.0.4-OG/source/backend/Paths.hx` 与 `1.0.3` 的 Paths.hx **逐字节相同**（`diff -q` 无输出）。

### 3.6 "1.0.4" 这个目录 ≠ 官方 1.0.4
- `diff -rq 1.0.4-OG/source 1.0.4/source`：`1.0.4` 多出 `backend/Cache.hx`、`HitGraph.hx`、`PsychText.hx`、`Replay.hx`、
  `OpponentModeSystem.hx`、`OFLSprite.hx` 等，是**挂了 NovaFlare 血统的第三方中文分支**（`Cache.hx:1` 自己写着"本文件所有代码归属 FNF NovaFlare Engine"）。
- 它在 Paths 上只多了一个**视频路径缓存**（`1.0.4/source/backend/Paths.hx:199-243` `cachedVideo` / `cacheVideoPath`，缓存的是**路径字符串不是资源**），
  **对图片/纹理内存零改动**。⇒ 参考价值：无。
- 它的 `Cache.hx` 额外记 `currentTrackedFrames` / `currentTrackedAnims`，但只做"frame 还活着吗"的查询，不做释放决策。

### 3.7 Psych 1.0 的激进预载（这才是 8.88GB 的直接来源）
- `1.0/source/states/LoadingState.hx:330` 起：为 note skin / splash / song `preload` JSON / stage `preload` 收集 `imagesToPrepare`，
  然后 `_threadFunc()`（同文件 1.0.4-OG 版 `:670`）**为每一张图 `initThread(→ preloadGraphic)`**。
- `1.0.4-OG/source/states/LoadingState.hx:798-828` `preloadGraphic()`：在工作线程里 `BitmapData.fromFile()` **整张解码**，
  塞进 `requestedBitmaps:Map<String,BitmapData>`；主线程 `:341-351` `checkLoaded()` 里再逐张 `Paths.cacheBitmap()` 上传。
- `:409-421` `_startPool()`：`FixedThreadPool(hardware_concurrency() - 1~2)`。
- ⇒ 峰值 = **全部 preload 图的 CPU 位图 + 全部 GPU 纹理同时存在**，且 `loadMax` 就是全部，**没有任何上限或分帧**。
  预载表完全由 mod 的 `preload` JSON 决定 ⇒ Fatal Finale 的 185 张 / 8.88GB 就是被这个机制原样灌进去的。
- 对比：**0.7.3 的 LoadingState 不预载图片**，只用 `Assets.loadLibrary()/loadSound()` 加载 songs 库（`0.7.3/source/states/LoadingState.hx:93,106`）
  ⇒ "一次预载全周素材"是 **1.0 引入的**，不是 Psych 一直如此。

### 3.8 Psych Mobile 1.0.4 —— 唯一一条真技巧
- `source/backend/Paths.hx:54-56`：`System.gc(); #if cpp cpp.NativeGc.run(true); #end`
  ⇒ hxcpp 的**大对象块要 major GC 才还给系统**，单 `System.gc()`（= minor）不够。这条 FE 可以直接抄（我们已有 `frequentGC` 开关）。
- 其余改动全是路径查找（Linux 大小写不敏感 `findFile`、Android 外部存储），与内存无关。

## 4. 官方 Funkin 0.8.7 拆解

### 4.1 架构图

```
 funkin.Paths       纯路径解析，无缓存（'songs:assets/songs/x/Inst.ogg'）   Paths.hx:44-73
        │ 返回 key
        ▼
 funkin.Assets      openfl.utils.Assets 的薄包装，自认 "Later we'll add caching"  Assets.hx:1-16
        │
        ▼
 Polymod 合并出的 AssetLibrary（每 mod 一个 library，key = "modid:assets/..."）  PolymodHandler.hx:152
        │
        ▼
 funkin.FunkinMemory  真正的缓存层（唯一有策略的地方）                      :20-26
        permanentCachedTextures  ← 永不释放（UI/字体/音符）
        currentCachedTextures    ← 本"代"
        previousCachedTextures   ← 上一"代"，purge 时整批销毁（声音同构）
        │ 落地到
        ▼
 FlxG.bitmap._cache ← FlxGraphic（persist=true, allowGPU=true）
        │
        ▼
 funkin.util.MemoryUtil  只**测量**：GC info / working set / VmRSS / collect / compact
```

### 4.2 关键机制与代码

**(a) 三代缓存 = 代际 + "重请求即续命"，不是引用计数**
- `FunkinMemory.hx:178-191` `preparePurgeTextureCache()`：`previous = current.copy()`，剔除 permanent，然后 `current = permanent.copy()`。
- `:118-142` `cacheTexture(key)`：先查 `current`，命中直接返回；否则去 `previous` **捞回来**（= 这一代又被请求了，续命）；都没有才新加载。
- `:196-248` `purgeTextureCache()`：遍历 `previous` 里剩下的 ⇒ 这一代**没被重新请求过**的一律 `FlxG.bitmap.remove` + `persist=false` + `destroy()` + `Assets.cache.clear(key)`。
- 结论：**和 FE 的 `trackedEpochs` + `assetEpoch` 是同一思路**（都是"代际翻页 + 重请求续命"），但 Funkin 多一层 `permanent` 白名单。

**(b) 一个明显的 bug/quirk**
- `:235` `if (obj.useCount > 0)` — 只有**正在被引用**的图才会走下面的 `purgeFilter` 路径被销毁；
  `useCount == 0` 的"僵尸图"反而 `continue` 跳过。语义应该是 `== 0`。⇒ 官方实现里 `purgeFilter`
  （`['/week','/characters','/charSelect','/results']`）这条分支基本是失效的，实际兜底完全靠 (a) 的代际对比。

**(c) `forceRender()` —— 预载后强制上传 GPU（值得抄）**
- `:254-267`：临时 `new FlxSprite(); sprite.loadGraphic(graphic); sprite.draw(); graphic.bitmap?.getTexture(FlxG.stage.context3D); sprite.destroy();`
  ⇒ 保证纹理**真正进了 VRAM**，而不是"缓存里有个 FlxGraphic、首帧才上传"（那会产生加载后第一次进游戏的卡顿峰值）。
  FE 的 `pinGraphic` 只解决"不被清理"，没解决"没上传"。

**(d) 声音：整库清**
- `:398-425` `purgeSoundCache()`：逐 key `Assets.cache.removeSound`，然后**无条件** `Assets.cache.clear('songs')` + `clear('music')`。
  粗暴但对谱面音频合理（一次只用一首歌的 inst/voices）。

**(e) 由谁触发清理**
- `LoadingState.hx:357-362`：`FlxG.signals.preStateSwitch.addOnce(() -> { clearFreeplay(); purgeCache(true); })`
- `MainMenuState.hx:153-154`、`TitleState.hx:330`、`ResultState.hx:1044-1048`、`StickerSubState.hx:218-222`、`CharacterUnlockState.hx:130-137`
- ⇒ 策略是：**"状态切换"这一个钩子统一翻代 + 顺手 GC**。没有任何"显存超阈值就清"的反馈环。

**(f) `MemoryUtil` 里有什么**
- `MemoryUtil.hx:24` `buildGCInfo()`：dump hxcpp Immix 的 usage/reserved/current/large pool 与一堆 GC 编译宏；崩溃报告用（`CrashHandler.hx:221`）。
- `:70` `getTaskMemory()`：**真实进程工作集**——Windows 走自写 C++ `WinAPI.getProcessMemoryWorkingSetSize()`（`external/windows/WinAPI.hx:25`），
  macOS/iOS 走 RSS，Linux/Android 读 `/proc/<pid>/status` 的 `VmRSS`。
- `:129` `getGCMemory()` = `openfl.system.System.totalMemoryNumber`。
- `:163` `collect(major)` = `cpp.vm.Gc.run(major)`；`:178` `compact()` = `cpp.vm.Gc.compact()`（注释明确说这**不是**真正的压缩，是反复 major GC 到每次释放 <16KB）。
- `:137/:149` `enable()/disable()` 可整体开关 GC。
- **没有**：预算、阈值告警、自动触发清理、显存统计。它纯粹是"仪表盘"。
- 仪表盘消费者：`ui/debug/FunkinDebugDisplay.hx:175-190` 把 `gcMem` / `taskMem` 画成两条曲线（含 peak 值）。

### 4.3 官方 Funkin 有没有做纹理降采样 / 合图限制？

**没有运行时降采样，但有离线 ASTC：**
- 全仓 `grep downscale|halfRes|lowRes|mipmap|maxTextureSize|4096` → **零命中**（`source/` 下）。
- ASTC 只在两处以"扩展名"出现：`FunkinMemory.hx:37`、`LoadingState.hx:328`（`#if FEATURE_COMPRESSED_TEXTURES`）。
- 真正的压缩在**构建期**：`astc-compression-data.json`（`input: ./assets`、`output: ./astc-textures/`、`quality: medium`、`blocksize: 10x10`，
  并对 `NOTE_assets.png`、`characters/darnell/spritemap1.png` 等关键资源单独指定 `4x4`）；
  `project.hxp:1850-1855` 在打包时把 `.png` 路径**改写**成 `astc-textures/*.astc`；`astcExcludes` 来自 `astc-compression-data.json` 的 `excludes`。
- ⇒ 结论：官方解决"图太大"的办法是**离线降质量/降分辨率**（10x10 block ≈ 1/12.5 的原始体积），
  运行时**完全不管**。这对 FE 的启示很大：Fatal Finale 那种体积，运行时降采样不如**离线重压/缩图**。

### 4.4 官方 Funkin 的预载现状（重要）

- `LoadingState.hx:380-431` `preloadLevelAssets()` **整个函数体是注释掉的**，注释原话：
  `// TODO: This section is a hack! Redo this later when we have a proper asset caching system.`
- 目前唯一"手工预载"是 `:296-355` 里给 `2hot`（Weekend 1）写死的一张图/一串音效列表。
- ⇒ **官方自己也承认没有成熟的预载系统**。它靠的是 `FunkinMemory.initialCache()`（`:31-93`）
  用 `Assets.list()` **自动把所有 `ui/*.png` 与 `countdown/*.ogg` 注册为 permanent**，其余全部按需加载 + 切状态翻代淘汰。

## 5. 「Psych / Funkin 从来没做过的事」清单

写在这里，避免我们在错误方向上找答案：

1. **引用计数**：Psych 全系零 `useCount` 读取；Funkin 只在 `FunkinMemory.hx:235` 读了一次（且写成 `> 0`，疑似笔误）。
2. **LRU / 淘汰优先级 / 显存预算 / 阈值触发**：全部为零。两边都是"代际 or 状态切换"驱动的批量清理，
   没有任何版本用 `getTaskMemory()` 的结果去驱动释放（Funkin 只拿它画曲线）。
3. **运行时纹理降采样 / mipmap / 合图尺寸上限**：零。Funkin 用构建期 ASTC 代替。
4. **预加载 pin（防止预载完立刻被清）**：零。Psych 靠"预载 → 统一上传 → 进 PlayState 刚好没人清"的时序巧合；
   Funkin 靠 `current` 代续命。**FE 的 `pinGraphic`/`pinSound` 是独创**。
5. **延迟释放（等 useCount 归零再 dispose）**：零。Psych 立刻 `__texture.dispose()`（可能在 sprite 还在 draw 时），
   Funkin 也是立刻 `destroy()`。**FE 的 `pendingReleases` 队列是独创**。
6. **按 key 记账代际 / CPU 位图与 GPU 纹理分开记账**：只有 FE 有。两边都只有 `FlxGraphic` 一个句柄。

## 6. 给 FE 的结论

1. **别回头抄 Psych 的 `freeGraphicsFromMemory()`**（`1.0.3/source/backend/Paths.hx:83`）。
   它是"反射扫一层 state 找 graphic"的近似，漏 substate 递归、漏非 `graphic` 字段的引用，误杀风险高。
   FE 的 `useCount + pendingReleases + trackedEpochs` 在**正确性上已经是这两个谱系里最强的**。

2. **可以抄 Funkin 的 `permanent` 白名单 + `Assets.list()` 自动注册**（`FunkinMemory.hx:31-93`）。
   我们现在常驻资源靠手写列表；改成"启动时枚举 `ui/**` + 关键音符/字体 → 一次 pin 到底"更不容易漏，
   且能用 `pinGraphic` 复用现有机制（把 permanent 实现为"永不 unpin 的 pin"即可，不必新增一套 Map）。

3. **值得抄的第二件：`forceRender()`**（`FunkinMemory.hx:254-267`）。
   预载完先 `getTexture(FlxG.stage.context3D)` 强制上传，能把"进 PlayState 首帧"的上传峰值挪到 Loading 屏，
   避免"加载条走完 → 黑屏卡 3 秒"。我们只需要在 `pinGraphic` 后补一次上传，成本极小。

4. **值得抄的第三件：Mobile 的 `cpp.NativeGc.run(true)`**（`Mobile/source/backend/Paths.hx:55`）。
   hxcpp 大对象要先 major GC 才会把页还给系统；只 `System.gc()` 时 RSS 只涨不跌的现象就是它造成的。
   建议在 `clearUnusedMemory()` / 切歌后**无条件**跑一次 `cpp.vm.Gc.run(true)`（比 `frequentGC` 每帧开关更划算）。

5. **值得抄的第四件：`MemoryUtil.getTaskMemory()`**（`util/MemoryUtil.hx:70` + `external/windows/WinAPI.hx:25`）。
   拿不到真实 VRAM，但 **Windows 工作集 / Linux `VmRSS`** 是最接近的近似值。
   Fatal Finale 场景下，"预载前记录基线 → 预载后比较增量"能让预算决策有数据依据，而不是拍脑袋。

6. **8.88GB 这件事，两个谱系都给不出答案——必须自己造预算层。**
   所有版本的预载都是"mod 说预载 185 张就解码 185 张"（`1.0.4-OG/source/states/LoadingState.hx:798` 无任何上限判断）。
   我们能站的位置比它们都好（有 epoch 记账 + useCount），缺的只是"**预载前按 `w*h*4` 估算 + 超阈值降级**"：
   - 超阈值时优先**跳过**非关键项（`preload` JSON 里加优先级/lazy 标记）；
   - 次选**降采样**：`BitmapData` 加载后 `new BitmapData(w*0.5, h*0.5)` blit 一次再上传（Psych/Funkin 都没做过，要自己写，注意 `FlxAtlasFrames` 的 frame 矩形要同步缩放）；
   - 最优仍是**离线**（Funkin 的 ASTC 思路）：给 mod 提供一个缩图工具，运行时只读已经小过的资源。

7. **善用 "Psych 1.0 的峰值 = CPU 位图 + GPU 纹理同时存在" 这条诊断**（`LoadingState.hx:798` + `:341`）。
   我们如果沿用"工作线程全解码 → 主线程统一上传"，峰值同样会翻倍。
   建议：**在 `cacheBitmap` 上传成功后立刻释放 CPU 拷贝**（Psych 的 `cacheBitmap` 在 `cacheOnGPU=true` 时会做，
   但 `bitmap.image == null` 或低配时**静默保留全量**，见 `1.0/source/backend/Paths.hx:204`），
   而不是等清理；这才是把 8.88GB 砍半最省事的一刀。

8. **声音的整库清空可以更狠**：Funkin `purgeSoundCache()` 直接 `Assets.cache.clear('songs')` + `clear('music')`（`FunkinMemory.hx:415-416`）。
   我们现在按 key 逐个比对，遇到 mod 用奇怪路径写入的音频会漏。切歌时直接整段清 `songs`/`music` 更稳。

## 7. 疑点

1. **`FlxG.bitmap.remove(graphic)` 在 flixel 6.2.1 的确切语义**未在本机验证（`~/.haxelib` 为空，FE 仓库也没有 vendored flixel）。
   按 flixel 6.x 源码记忆，`remove()` 会从 `_cache` 摘 key、`useCount` 归零，并在 `destroyOnNoUse` 时 destroy。
   Psych 1.0.4 在 `destroyGraphic` 里**没有**把 `persist` 改 false（`1.0.4-OG/source/backend/Paths.hx:138-144`），
   所以如果 `remove()` 内部尊重 `persist`，那 Psych 1.0.x 的"显式销毁"其实一直没生效——需要真机/单测确认。
2. **`RectangleTexture` + `BGRA` 在部分 GPU 上会失败**（`0.7.3/source/backend/Paths.hx:275` 未做 format 回退），
   Psych 0.7.3 分支上 `cacheOnGPU` 导致的"图片变黑/透明"issue 可能与此有关；1.0 换成 `getTexture()` 后规避了。
3. **`FunkinMemory.purgeTextureCache` 的 `useCount > 0` 是否是笔误**：如果是笔误，说明官方这条 `purgeFilter` 分支从未生效过；
   如果不是（比如作者想表达"只清正在用的"？），那逻辑本身说不通。倾向笔误，但没有 git history（源码包无 `.git`）无法确认。
4. **`1.0.4` 目录的真实出处**：`backend/Cache.hx:1` 自称归属 NovaFlare，`Paths.hx` 又有中文注释的 `cachedVideo`，
   应是"Frozen Engine 上游的那份 1.0.4 中文整合包"，而非 ShadowMario 官方 1.0.4。做版本对比时不要把它当官方基线。
5. **`astc-textures/` 实际是否随发布包分发**：`project.hxp:1850` 只有在 `FileSystem.exists(astcPath)` 时才改写路径，
   否则静默用原始 png ⇒ 移动端很可能一直在用未压过的图。这条需要看发布流水线才能定论。
