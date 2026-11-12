# 贴图内存优化 · 交接文档

> 生成时间：2026-11-11 00:45
> 适用仓库：`J:/FNF-FrozenEngine`（Psych 衍生 / openfl 9.6.0-dev fork / lime 8.4.0 / flixel 6.2.1 / hxcpp 4.3.184）
> 本文是给「下一个对话」的自包含交接：现状、已改、未改、怎么验、坑在哪。

---

## 0. 一句话现状

P1（统一贴图缓存键）+ P1.5（修 GPU caching 分支）已实机验证通过；**P2（释放语义）已落地，类型检查 + codegen +
release 构建全过（2026-11-11 01:03），实机未验**。

- P1 实测（00:47）：`重复浪费 0`（改前 328MB/7 组）、CPU 8.78GB（改前 9.10GB）、RSS 14.63GB（改前 15.72GB）。
- P2 实测（18:25–18:26，连打 10 首）：RSS 539MB→1.82GB，每一步都等于「当前这首自己的贴图」，不累积；
  贴图 37–55 张、`重复浪费` 全 0。**唯一异常：`待释放` 8→20 单调增、从不回落**（每首 1–2 张图被谁攥着），
  已给报告加「待释放明细」（key/尺寸/useCount），待下一轮 F9 定位。
- P2：`Paths` 的销毁改成「代际 + useCount」延迟释放，预加载的图/声音有 pin 保护；`PlayState` 那条禁用注释
  已换成新语义说明（仍然不补 `clearUnusedMemory()`，原因见 §2.4）。
- **P3 v1 纹理降采样做过一版，已完整回退**（2026-11-12 12:25 构建）：缩图本身没问题，但帧矩形回缩
  改不动绘制的顶点矩阵（`FlxFrame.cacheFrameMatrix()` 在构建时定死、外部调不到），实机「角色全炸」。
  复盘见 §2.4.1。P3 余项（LRU 预算、预加载窗口）与 P4（拆图/压缩纹理）未做。
- 回退前的完整 P3 源码存在 `.workbuddy-ai/backup/2026-11-12-p3-downscale/`（9 个文件的 `.bak`），要重做可直接取。
- **五路外部调查已完成（2026-11-12）**：结论汇总在 `docs/memory-research/00-总览.md`，
  明细 `01` openfl 机制 / `02` NovaFlare+Impostor / `03` Psych+官方 Funkin / `04` 其他引擎 / `05` flixel 语义。
  三个最重要的产出：① `createRectangleTexture` 第 4 参传 `true` 导致每张图多一套 FBO+depth（≈+100% 显存）；
  ② `LoadingState` 预载默认 `allowGPU=true`，`full` 模式预载即上传；③ 降采样/显存预算/角色懒加载在
  Psych + 官方 Funkin 两条谱系里**都没有先例**，Funkin 走的是构建期 ASTC。

---

## 1. 先读这三份

| 文档 | 内容 |
|---|---|
| `docs/memory-texture-report-2026-11-09.md` | 完整调查报告：根因、量级、openfl/lime/hxcpp 源码证据、其他引擎对比、P0–P4 方案 |
| `docs/fatal-finale-memory-baseline.md` | 极限用例 Fatal Finale 的静态基线 + 13 次实测 + A/B（GPU caching 开/关） |
| 本文 | 交接：改了哪些代码、怎么验、下一步从哪下手 |

工具：`tools/atlas_memory_audit.py`（PNG 解码体积静态审计）、`source/backend/MemoryStats.hx`（运行期快照，F9 导出）。

---

## 2. 已落地的代码（本轮）

### 2.1 P1：贴图缓存键 = 实际文件路径

**问题**：旧键是"查找上下文" `"<mod>:<key>|<contentRoot>/<level>|<依赖根>"`。
`Paths.image()` 会拼这些后缀，`Paths.cacheBitmap()`（预加载走它）不拼 →
同一个文件被解码两份。Fatal Finale 实测 **94–97 组重复、浪费 1.9–2.6GB**。

**改法**（`source/backend/Paths.hx`）：

```haxe
public static function resolveImage(fullKey:String, ?parentFolder:String):ImageResolve
{
    var file = getPath(fullKey, IMAGE, parentFolder, true);
    if (file != null && FileSystem.exists(file)) return {key: file, file: file};
    return {key: contextCacheKey(fullKey), file: file};   // 找不到文件才用旧键兜底
}
```

- `contextCacheKey()` = 原来的 mod 前缀 / contentRoot / level / 依赖根拼接，只在文件不存在时兜底
  （此路径不会写缓存，所以不会造成重复）；
- `image()` 改成先 `resolveImage()`，再用 `resolved.key` 查缓存、`resolved.file` 读盘；
- `cacheBitmap()` 同样解析；但**先判 `FileSystem.exists(key)`**——编辑器/ModsMenu 会直接把文件路径当 key 传进来；
- `LoadingState.preloadGraphic()` 改用 `Paths.resolveImage(requestKey)`，并把解析后的键存进 `originalBitmapKeys`。

**效果**：同一文件只有一个键（路径里已含 mod 目录 / 内容包 / 层级），预加载与运行期第一次对上；
LuaScriptPreload 抽出来的舞台图也一起生效（不需要改 LuaScriptPreload 本身）。

### 2.2 P1.5：GPU caching 分支只保留 `disposeImage()`

旧的 `getSurface() → disposeImage() → image.data=null → image=null → readable=true` 已删（`Paths.disposeCPUImage()`）。
理由：openfl 9.6.0-dev 的 `disposeImage()` 只置 `readable=false`，真正释放发生在首次 `getTexture()`
（`if (!readable && image != null) { __surface = null; image = null; }`）。
旧写法留下悬垂 cairo surface（`getSurface()` 只拿裸指针）和 `readable=true` 的谎。

### 2.3 MemoryStats 的两处修正

- `trackedTextures()` 的 `hasCPU` 改成 `image != null`（不再看 `readable`）：
  P1.5 之后未上传的图是 `readable=false + image 还在`，按旧判据会漏记；
- 新增 `normalizeKey()` / `duplicateKeys()` / `duplicateWaste()`：按归一化路径统计"同一文件多份缓存"。
  （旧的 `duplicateSuspects()` 同尺寸检测已删，图标噪音太大。）

### 2.4 P2：释放语义从「硬销毁」改成「代际 + 引用计数」

**问题**（报告 §2.5）：`destroyGraphic()` 不看 `useCount` 直接 destroy，而存活表 `localTrackedAssets` 是
只增不减的数组（只在 `clearStoredMemory()` 末尾清空）→ 判定永远为真。结果 `PlayState` 干脆不调
`clearUnusedMemory()`，内存只涨不降。

**改法**（主改动都在 `source/backend/Paths.hx`）：

| 概念 | 实现 |
|---|---|
| 记账 | `trackedEpochs: Map<String, Int>`（key → 最后一次请求的代际）取代 `localTrackedAssets`；`markAssetUsed(key)` 是唯一写入口（贴图命中/新载/声音共用） |
| 代际 | `assetEpoch`，每次 `clearStoredMemory()` 开头 +1 |
| 释放 | `releaseGraphic()`：`useCount <= 0` 立刻销毁；否则进 `pendingReleases` 队列 |
| 攒批 | `flushReleasedGraphics()`：把队列里引用已归零的销毁。**必须先 `copy()` 再遍历** —— `destroyGraphic` 会顺手从队列里删元素，边遍历边改会漏掉后面几张 |
| 销毁 | `destroyGraphic()` 是唯一出口：先 `__texture.dispose()` 删 GL 纹理，再 `FlxG.bitmap.remove()`，并清掉记账 |
| 接管 | `adoptGraphic()`：被释放过、但还活在 `FlxG.bitmap` 里的同 key 图，`image()` / `cacheBitmap()` 直接接管，不重复解码 |
| 预加载保护 | `pinGraphic()` / `pinSound()`：`LoadingState` 预载完 +1，`clearStoredMemory()` 跳过它们、末尾统一 unpin。**unpin 之后不能再 flush**（否则刚预载的图当场被收） |

三条硬约束：

1. **`persist` 永远保持 true，销毁只走 `destroyGraphic()`。** 交给 flixel 的 `destroyOnNoUse` /
   `FlxG.bitmap.clearCache()` 销毁会走 `BitmapData.dispose()` —— 那里 `gl.deleteTexture` 是注释掉的
   （openfl 9.6），显存不释放。
2. **`clearStoredMemory()` 对「不在 Paths 记账里的图」（`makeGraphic` / `FlxG.bitmap.create` 现画的）也走
   `releaseGraphic()`**：有 sprite 引用就留到下一次，不再抽掉别人正在用的图。
3. **声音同样按代际清 + pin 保护**：不然预加载的音乐一进 `PlayState` 就被清掉、白解一遍。

附带：`Paths.disposeGraphicData(graphic)`（先删纹理再 `bitmap.dispose()`），已替换 `AchievementPopup` /
`MessageBox` 里三处裸 `bitmap.dispose()` —— 那三处每建一次文本就漏一张 GL 纹理。

**2026-11-12 补的三条（学 NovaFlare / VS Impostor）**：

1. `Paths.makeHardwareOnly()` + **GPU Caching 三态**（`ClientPrefs.data.gpuCaching`，老字段 `cacheOnGPU:Bool` 已迁移）：
   - `disabled`：只用内存，CPU 像素常驻（老默认）；
   - `auto`：加载时 `disposeImage()`，靠 openfl 在首次绘制上传后丢 CPU（P1.5 的行为）；
   - `full`：加载时立刻 `createRectangleTexture` + `uploadFromBitmapData` + `BitmapData.fromTexture`
     （NovaFlare 式），**预加载落地和运行期命中都转**，CPU 副本当场没了。
     ⚠️ `full` 在预载重的歌上会把显存顶穿：Fatal Finale 实测 5.76GB→8.76GB、RSS 13.4→15.3GB
     （超 6GB 后驱动要在系统内存里再留一份），这是用户显式选的取舍。

3. **`PlayState.destroy()` 清理脚本精灵**（本轮新发现的老 bug）：`makeLuaSprite` 建的精灵只登记在
   `MusicBeatState.getVariables()`（当前 state 的 `variables` map），没 `addLuaSprite` 的既不在 members、
   也不会被 `destroy()` —— GC 掉时 `FlxSprite` 的引用计数不减，图集永远挂在 `useCount=1`。
   Fatal Finale 舞台脚本建 112 个只 add 几个 → 退出后 104 张 / 2.61GB 卡在待释放、RSS 停在 6.3GB。
   现在 destroy 里把不在 members 的 `FlxSprite` 显式销毁再清表（表里还有 tween/timer/sound，别碰）。
2. **`frequentGC`（Advanced 里的「Frequent GC」，默认关）**：打开后 `clearStoredMemory()` 在真销毁过图时
   补一次 `System.gc()`，`clearUnusedMemory()` 用 `cpp.vm.Gc.compact()`（Impostor 同款）；关着就走原来的
   单次 `System.gc()`。hxcpp 的大对象块只有 full GC 才还给系统，之前「释放了但 RSS 不动」正是缺这一步
   （18:26:51→18:28:00：CPU 少 830MB，RSS 反 +30MB）。

**为什么 `PlayState.create()` 末尾还是不补 `clearUnusedMemory()`**：那时 `cacheCountdown()` /
`cachePopUpScore()` 还没跑，note 图全靠预加载活着；真正的释放已经在同一函数开头的 `clearStoredMemory()`
做完了（上一局的图此时 `useCount` 已归零）。

### 2.4.1a GPU 上传路径重写（2026-11-12 15:12 构建）

五路外部调查（`docs/memory-research/`）之后的三个修复，全部已验证类型检查 + 构建：

| 文件 | 改动 |
|---|---|
| `Paths.makeHardwareOnly` | 改成 `bitmap.disposeImage(); bitmap.getTexture(context);` —— 走 openfl 自己的上传路径，删掉 `createRectangleTexture` / `uploadFromBitmapData` / `BitmapData.fromTexture` |
| `Paths.image()` 命中分支 | 补齐 `full`（就地转显存）与 `auto`（补 `disposeImage()`）两种模式 |
| `LoadingState.checkLoaded` | 预载改 `cacheBitmap(key, null, bitmap, false)` —— 预载阶段不上传显存 |
| `MemoryStats` | 新增 `hasGpuTexture()`：判活从 `__texture != null` 改成 `__texture.__textureID != null` |

**为什么这么改（三条，都有源码证据，详见 `docs/memory-research/01`）：**

1. `createRectangleTexture` 第 4 参 `optimizeForRenderToTexture` 传 `true` 会触发
   `RectangleTexture.hx:39` 的 `__getGLFramebuffer(true, 0, 0)` → 每张图额外一套 FBO +
   `DEPTH24_STENCIL8` renderbuffer（4 B/px，叠在纹理之上 ≈ +100% 显存）。
   现在不自己建纹理，参数由 openfl 内部传 `false`，问题自动消失。
2. `BitmapData.fromTexture()` 内部先 `new BitmapData(w, h, true, 0)` 再 `image = null`
   （`BitmapData.hx:1397`），每张图多一份 `w·h·4` 临时分配；新写法没有。
3. `fromTexture` 产出的 BitmapData 与任何 `clone()` 共享同一 `__texture`（`FlxGraphic.getBitmap`
   在 `unique=true` 时就是 clone），改副本会写穿原图。新写法让原 BitmapData 自己持有纹理，语义干净。

**为什么 `image()` 命中要补 `auto`**：预载改成 `allowGPU=false` 后，`auto` 模式在预载阶段连
`disposeImage()` 都不做了；不补的话这些图永远 `readable=true`，首次绘制上传后也不丢 CPU 副本
—— 从「双份」退化成「永久双份」。补上之后：预载只解码（CPU 常驻、可被 pin 保护），
运行时第一次索取时按模式处理（full 立刻转显存 / auto 标不可读等首次绘制）。

**按显存分档（17:05 补）**：`MemoryStats.dedicatedVRAM()` 走 DXGI（`IDXGIAdapter1::GetDesc1`），
因为 openfl 的 `totalGPUMemory` 只查 NVIDIA 专有的 `NVX_gpu_memory_info`，AMD 上恒 0。
新设置项 `preloadTextureToVRAM`：`auto`（默认，独占显存 >= 10GB 才在预载时上传）/ `on` / `off`。
F9 报告的「显卡」段会显示独占显存和当前判定。探测失败返回 0 → auto 退化为 off。

⚠️ 已知边界（`docs/memory-research/00` §一）：GPU-only 的图没有 CPU 像素，
`getPixel32` 返 0、`copyPixels`（`FlxFrame.paint`）静默空白、`draw`/`fillRect` 会写穿共享纹理。
所以 `full` 只适用于「纯显示、绝不二次加工」的图；像素判定 / 抠帧 / `stamp` / `drawLine` 需要 CPU 像素。

### 2.4.1 P3 纹理降采样（已尝试，已完整回退）

做过的一版：`textureDownscale` 开关（三套菜单 + 三语），只压**图集**（`isAtlasFile` 判同目录有无同名
`.xml/.json/.txt`），最长边 > 2048 缩到 2048；在预加载 worker 里缩（比例经 `workerDownscaleRatios` 传回
`cacheBitmap`），图集建好后 `applyDownscaleToFrames()` 把每个 `FlxFrame.frame`（纹理区域）乘比例，
`sourceSize` / `offset` 保持原值。

**实机结果：角色全炸（尺寸/采样全错），已回退。**

根因：flixel 6 的 `FlxFrame` 有两套渲染数据 —— `uv`（由 `set_frame` 触发 `updateUV()` 重算）和
`blitMatrix` / `tileMatrix`（顶点缩放与偏移，**只在 `cacheFrameMatrix()` 里算一次**，由
`FlxFramesCollection.addAtlasFrame` 在构建图集时调用）。我在构建后改 `frame`，只刷新了 uv，
矩阵还是按原始尺寸缓存的 → 四边形顶点和纹理采样区对不上，整个图集的所有帧一起错。

`cacheFrameMatrix()` 是 `@:allow(flixel.graphics.frames.FlxFramesCollection / FlxBitmapFont)` 的 internal，
引擎侧调不到。**要重做只有两条路**：
1. 反射调用 `cacheFrameMatrix()`（每帧一次，成本可接受，但依赖 flixel 内部字段名，升级会崩）；
2. **在解析图集前把描述文件里的坐标一起缩**（xml/json/txt 里的 x/y/width/height/frameX/frameY），
   等于内存里生成一份「缩过的图集描述」——最干净、不碰 flixel 内部，但要为 sparrow / packer /
   texturepacker 三种格式各写一遍解析与重写。

**结论**：这条方案本身可行，但改动面比预想大一个量级（不是「在 image() 里缩一下」那么小）。
再启动前先评估第 2 条路的工作量，别再走改 `FlxFrame.frame` 的捷径。

### 2.5 改动文件清单

| 文件 | 状态 |
|---|---|
| `source/backend/Paths.hx` | 改：`resolveImage` / `disposeCPUImage` / `image()` / `cacheBitmap()` / `ImageResolve` |
| `source/states/LoadingState.hx` | 改：`preloadGraphic()` 用 `resolveImage` |
| `source/backend/MemoryStats.hx` | 新增（P1 轮）+ 重复统计；P2 轮加 `isDestroyed` 过滤与「待释放」计数 |
| `source/states/LoadingState.hx` | 改（P1：`preloadGraphic` 用 `resolveImage`；P2：预载完 `pinGraphic` / `pinSound`） |
| `source/states/PlayState.hx` | 改：`create()` 末尾那条禁用注释换成 P2 语义说明 |
| `source/objects/BreathGlow.hx` / `source/states/editors/ChartingState.hx` | 改：跟 `localTrackedAssets` 的两处调用换 API |
| `source/objects/AchievementPopup.hx` / `source/objects/MessageBox.hx` | 改：临时文本图改走 `Paths.disposeGraphicData()` |
| `source/debug/FPSCounter.hx` | 改（上一轮）：`showMEMPeak` 时追加 `RSS:` |
| `source/substates/PauseSubState.hx` | 改（上一轮）：F9 导出快照 |
| `tools/atlas_memory_audit.py` | 新增（上一轮） |

> ⚠️ 工作区还有**用户自己**的并行改动（`Paths.getResourceRoots/getRootOf`、`Character`、
> `LoadingState` 的图集判定等）。这些不是本次改动，不要回滚。

---

## 3. 怎么验（下一步第一件事）

1. 类型检查：
   ```bash
   cp export/debug/windows/haxe/debug.hxml /tmp/t.hxml && echo --no-output >> /tmp/t.hxml && haxe /tmp/t.hxml
   ```
   零输出 = 过（约 17–30s）。
2. 构建（见 §5）。**必须关掉游戏**，否则 `lime.ndll` / `FrozenEngine.exe` 被占用会报 `Cannot copy`。
   本轮已构建成功（`Link: ApplicationMain.exe` + `EXIT=0`），所以直接实机即可；改代码后再构建。
3. 进 Fatal Finale（`mods/Fatal Finale`），暂停按 F9：
   - `重复浪费` 应该从 1.91GB / 94 组降到 **≈0**（只剩跨 mod 的 freeplay 图标之类）；
   - `LuaScriptParser = preload` 时，预加载的舞台图不再出现"两份 key"；
   - 加载时间应该比之前短一点（预加载第一次真正命中）。
4. 观察 `RSS`：预期**不会**大幅下降（总纹理 ~15GB vs 6GB 显存，见基线 §8），
   下降的是 `Paths 追踪 CPU` 里的重复副本。
5. P2 的看点（本轮新增）：
   - 报告里多一行 `待释放 N 张`：这是「已经没人要、但还有对象引用」的图，正常情况下应该是个位数；
   - **切歌锯齿**：连续进/退 5 首歌，每次回到 Freeplay（或下一首的 Loading）时 RSS 应往下掉一截，
     而不是只涨不跌；`Paths 追踪贴图` 的张数也应随之回落；
   - 预加载不能退化：进歌时不应该出现「角色图集重新解码」（表现为进歌变慢），
     说明 `pinGraphic` 生效、预载的图没被 `clearStoredMemory` 收掉；
   - 回归重点：角色重载（`changeCharacter`）、note 池（连打两首）、编辑器预览（ChartingState / CharacterEditor）。

**已完成的实测（2026-11-11 00:47，native + 无 GPU caching）**：

| 指标 | P1 前 (00:39) | P1 后 (00:47) |
|---|---:|---:|
| 贴图张数 | 202 | **195**（-7，正好是 7 组重复键） |
| CPU 贴图 | 9.10GB | **8.78GB**（-0.32GB ≈ 328MB 重复） |
| RSS | 15.72GB | **14.63GB**（-1.09GB） |
| 重复浪费 | 328MB / 7 组 | **0** |

如果 F9 里 `重复浪费` 还在，先查：`normalizeKey()` 是否漏了某种前缀格式；`getPath()` 是否返回了带盘符/反斜杠的路径。

---

## 4. 未完成清单（按优先级）

### P2 释放语义（✅ 已完成，待实机验证）

做法见 §2.4。验收标准：连续切 5 首歌 RSS 呈锯齿而非阶梯；无 `frames` 空引用崩。
**遗留**：flixel 自己创建并销毁的图（`FlxG.bitmap.create` 的临时图，`persist=false`）在
`destroyOnNoUse` 触发时仍然只 `BitmapData.dispose()`、不删纹理 —— 要彻底修得动 openfl 或给
`FlxGraphic` 打补丁，成本高于收益，暂不处理。

### P3 纹理策略（降采样试过一版，已回退）

1. **降采样**：~~`lowQuality` 或新开关，把最长边压到 2048~~ —— **实测 8.88GB → 1.36GB 的估算成立，但实现
   不能靠改 `FlxFrame.frame`**（会撞 `cacheFrameMatrix` 缓存，角色全炸，见 §2.4.1）。重做要走
   「解析前改描述文件坐标」那条路。
2. **按需丢 CPU 像素**：非 GPU-caching 模式下，对"只渲染不读像素"的大图上传后 `disposeImage()`。
3. **预算 + LRU**：需要 P2 的引用计数做前提。
4. **预加载窗口**：`LoadingState.prepareToSong` 目前是 `concat` 累加，要加"清空上一批"。

### P4 长期

图集拆分（15 张 8192² → 2048² × N）、压缩纹理（BC7/ASTC）、大背景按镜头分块。

### 可选

`addCharacterToList` 懒加载（Fatal Finale 56 个角色只用到 3 个，可省 ~5.5GB），
但会改变脚本语义（`setProperty('xxx.alpha')` 找不到对象），只能 opt-in。

---

## 5. 构建（本机实测可用）

沙箱拦 `reg.exe`，lime 探不到 MSVC/SDK，必须手动注入环境变量（**Community 版**，不是 BuildTools）：

```bash
export MSVC="C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Tools\\MSVC\\14.44.35207"
export SDKINC="C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.19041.0"
export SDKLIB="C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.19041.0"
export INCLUDE="$MSVC\\include;$SDKINC\\ucrt;$SDKINC\\um;$SDKINC\\shared;$SDKINC\\winrt;"
export LIB="$SDKLIB\\ucrt\\x64;$SDKLIB\\um\\x64;$MSVC\\lib\\x64;"
export PATH="$PATH:/c/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64:$MSVC/bin/HostX64/x64"
haxelib run lime build windows
```

- 会打印一次 `reg.exe blocked` 的安全提示，**不影响**构建；末尾 `Link: ApplicationMain.exe` + `EXIT=0` 即成功；
- 产物 `export/release/windows/bin/FrozenEngine.exe`；失败在 `Cannot copy ... in use` = 游戏没关；
- 判别 Haxe 阶段已过：日志里出现 `Creating ... __pch/haxe/hxcpp.pch`。

---

## 6. 已知坑（别重复踩）

**工程约定**
- 运行时读 `export/release/windows/bin/content/...`，与仓库 `content/` 是两份，改完要 cp。
- 不要 `taskkill` 游戏进程；编译前让用户自己关。
- `export/` 体积巨大（含打包进构建的 mods），不要清。

**openfl / lime**
- `BitmapData.disposeImage()` 只置 `readable=false`；真正的 `image = null` 在 `getTexture()` 里。
- `BitmapData.dispose()` **不删 GL 纹理**（代码被注释），只有 `TextureBase.dispose()` 会 `gl.deleteTexture`。
- `getSurface()` 返回的 cairo surface 直接引用像素内存（裸指针、不拷贝），`image=null` 后会悬垂。
- `BitmapData.disposeImage()` 之后 `readable=false`，但 `image` 可能还在——判"有没有 CPU 副本"要认 `image != null`。

**hxcpp GC**
- `Gc.memInfo64(MEM_INFO_USAGE)` = `mLargeAllocated + mRowsInUse<<7`；large 池（≥4000B，贴图全在此列）**分配即时计入、释放要等 GC**；
  小对象只在 GC 时结算。**不含 native 与显存**。
- 同一首歌：GPU caching 开 → GC 913MB / RSS 10.35GB；关 → GC 12.19GB / RSS 15.07GB。读数不能跨设置比。

**测出来但没修的行为**
- `Paths.clearStoredMemory()` 会 hard destroy 图集（不看 useCount），note 池/编辑器持有 frames 时会空引用；
- `currentTrackedAssets` 跨 mod 会话不清（日志里残留 `Sonic.exe 2.5:` 的 key）。

---

## 7. 关键数据速查（Fatal Finale，RTX 2060 6GB / 32GB RAM）

| 场景 | GC usage | RSS | CPU 贴图 | GPU 估算 |
|---|---:|---:|---:|---:|
| GPU caching ON | 913MB | 10.35GB | 0 | 10.69GB |
| GPU caching OFF | 12.19GB | 15.07GB | 11.34GB | 5.80GB |
| native + OFF（关预加载后） | 9.94GB | 15.72GB | 9.10GB | 5.78GB |

- 重复浪费：ON 1.91GB/94 组 → OFF 2.55GB/97 组 → 关预加载后 328MB/7 组；
- 关预加载剩下的 7 组正是 `LoadingState` 预加载的主角（bf 44MB / tails 21MB / gfgone 256MB）+ note skin/splash → **P1 修的就是这 328MB**；
- 静态：全 mod 302 张 PNG / 613.7MB → 解码 10.4GB；单曲触达 168 张 = 8.88GB；限 2048 后 1.36GB。

---

## 8. 文件/行号索引

| 位置 | 内容 |
|---|---|
| `source/backend/Paths.hx` `resolveImage()` | P1 核心：解析键 = 文件路径 |
| `source/backend/Paths.hx` `disposeCPUImage()` | P1.5 |
| `source/backend/Paths.hx` `image()` / `cacheBitmap()` | 两个入口 |
| `source/states/LoadingState.hx` `preloadGraphic()` | 预加载入口（线程池） |
| `source/backend/LuaScriptPreload.hx` | 静态抽 `makeLuaSprite`/`precacheImage`（无需改，P1 后生效） |
| `source/backend/MemoryStats.hx` | GC 四口径 + RSS + 贴图记账 + 快照 |
| `source/debug/FPSCounter.hx` `updateText()` | 内存行 + RSS |
| `source/substates/PauseSubState.hx` | F9 快照 |
| `source/states/PlayState.hx:1246` | 为什么禁用 `clearUnusedMemory()`（P2 要删的注释） |
| `source/objects/Note.hx:412-430` | note 池与 frames 悬垂引用 |

---

## 9. 下一个对话的开场建议

> 「继续 J:/FNF-FrozenEngine 的贴图内存优化。先读 docs/memory-optimization-handover.md。
> P1/P1.5 已实机验证，P2 已构建待验 —— 我要先看连续切歌时 RSS 有没有锯齿；然后开始 P3（降采样）。」

如果 P1 实机出问题，回滚点：`Paths.image()`/`cacheBitmap()` 回到上下文键 + `LoadingState.preloadGraphic` 用 `requestKey`，
其余（P1.5、MemoryStats）可独立保留。
