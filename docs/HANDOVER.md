# 交接 · 贴图内存优化（2026-11-12 现状）

> 这份是「换新对话」用的单文件交接。看完这一页就能接手，细节再按最后一节的索引去翻。
> 旧文档 `memory-optimization-handover.md` 是过程记录，按时间堆了很多，别从头读。

---

## 0. 一句话现状

引擎（Psych 1.0.x 衍生的 HaxeFlixel 项目）的贴图生命周期已经重写完毕：
**缓存键统一、按代际 + 引用计数延迟释放、预加载有 pin 保护、GPU 上传走 openfl 自己的路径、并按显存自动决定是否预载上传**。
类型检查 + Windows 构建通过（最新产物 `bin/FrozenEngine.exe` **18:58:28**，43.3MB）；
**实机只验证过前半部分**，最近三轮改动（GPU 上传路径重写、预载不上传、显存分档）**尚未实机验证**。

---

## 1. 环境与命令

```bash
# 类型检查（零输出 = 通过，约 90s）
cd J:/FNF-FrozenEngine
haxe export/release/windows/haxe/release.hxml --no-output

# 构建（必须手动注入 MSVC/SDK，沙箱拦 reg.exe 让 lime 探不到工具链）
export MSVC="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207"
export SDKINC="C:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0"
export SDKLIB="C:\Program Files (x86)\Windows Kits\10\Lib\10.0.19041.0"
export INCLUDE="$MSVC\include;$SDKINC\ucrt;$SDKINC\um;$SDKINC\shared;$SDKINC\winrt;"
export LIB="$SDKLIB\ucrt\x64;$SDKLIB\um\x64;$MSVC\lib\x64;"
export PATH="$PATH:/c/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64:$MSVC/bin/HostX64/x64"
haxelib run lime build windows
```

- 构建日志末尾的 `reg.exe BLOCKED BY SECURITY POLICY` 是**正常现象**，只要前面出现 `Link: ApplicationMain.exe` 就是成功。
- **不要 taskkill 游戏进程**；游戏在跑时构建会报 `Cannot copy to lime.ndll, is the file in use`，等用户关。
- 产物：`export/release/windows/bin/FrozenEngine.exe`；运行时读 `export/release/windows/bin/content/`，
  改 `content/` 或 `assets/` 后要 cp 到 `bin/` 下（本轮只改源码，没动资源）。
- Haxe/haxelib 在 `E:/HaxeToolkit`，**别设 `HAXELIB_PATH` 指向 C 盘**。

---

## 2. 已实现（按时间顺序）

| # | 改动 | 位置 | 状态 |
|---|---|---|---|
| P1 | 贴图缓存键 = **实际文件路径**（`Paths.resolveImage`），预载与运行期同键；修掉「同一文件被缓存成多份」 | `Paths.hx` | 实机验证过（重复浪费 0） |
| P1.5 | 修 GPU caching 分支：`disposeImage()` 只标 `readable=false` | `Paths.hx` | 同上 |
| P2 | 释放语义重写：`trackedEpochs` + `assetEpoch` 代际、`releaseGraphic` 按 `useCount` 延迟、`pendingReleases` + `flushReleasedGraphics`、`pinGraphic`/`pinSound` 保护预载 | `Paths.hx`、`LoadingState.hx`、`MemoryStats.hx` | 实机连打 10 首，RSS 成锯齿 |
| — | `PlayState.destroy()` 清理 `variables` 里没 add 的 Lua 精灵（修 `useCount` 卡 1 / 2.61GB 收不走） | `PlayState.hx` | 已构建，未单独验证 |
| — | GPU Caching 三态 `disabled/auto/full`（老 Bool 字段 `cacheOnGPU` 自动迁移） | `ClientPrefs.hx`、`Paths.hx`、三套菜单 | 已构建 |
| — | Frequent GC（Advanced，默认关）：`clearStoredMemory` 真销毁过就 `System.gc()`；`clearUnusedMemory` 用 `cpp.vm.Gc.compact()` | `Paths.hx` | 已构建 |
| — | **GPU 上传路径重写**：`makeHardwareOnly` 改成 `disposeImage()` + `getTexture()`，删掉 `createRectangleTexture`/`fromTexture` | `Paths.hx` | **未实机** |
| — | 预载 `cacheBitmap(..., false)`；`image()` 命中时按模式补 full/auto | `LoadingState.hx`、`Paths.hx` | **未实机** |
| — | **按显存分档**：`MemoryStats.dedicatedVRAM()` 走 DXGI；新设置 `preloadTextureToVRAM`（auto/on/off，auto = 独占显存 ≥10GB） | `MemoryStats.hx`、`ClientPrefs.hx`、三套菜单 | **未实机** |
| — | `MemoryStats.hasGpuTexture()`：判活用 `__texture.__textureID != null` | `MemoryStats.hx` | 已构建 |

**回退掉的**：P3 纹理降采样（v1 改 `FlxFrame.frame`，实机角色全炸）。原因见 §4。
源码备份在 `.workbuddy-ai/backup/2026-11-12-p3-downscale/`。

---

## 3. 关键设置项（都在 Graphics 页，三套菜单都有）

| 字段 | 值 | 说明 |
|---|---|---|
| `gpuCaching` | `disabled` / `auto` / `full` | disabled = 纯内存；auto = 首次绘制上传后丢 CPU；full = 加载即上传并丢 CPU |
| `preloadTextureToVRAM` | `auto` / `on` / `off` | 预载阶段是否上传显存。auto = 独占显存 ≥10GB 才开（6GB 卡 off，12GB 卡 on） |
| `frequentGC` | bool，默认 false | 每次切场景做 full GC + compact |

F9 报告（`PauseSubState` 导出到 `bin/logs/memory-*.txt`）现在包含：
GC 四口径 / RSS / **独占显存 + 预载判定** / 贴图张数与 CPU·GPU 估算 / 重复浪费 / 待释放明细。

---

## 4. 必须记住的坑（都付过代价）

**flixel**
- `FlxFrame` 的 `blitMatrix`/`tileMatrix` 只在 `cacheFrameMatrix()`（`addAtlasFrame` 时）算一次；
  之后改 `FlxFrame.frame` 只刷新 `uv`。而 `uv` 是按 `frame.x / parent.width` 算的，
  **换了尺寸不同的 bitmap 就等于所有 uv 基准全错，且没有重算 API**。→ 任何"运行期缩帧"都不可行。
- `useCount` 只统计活着的 `FlxSprite`（唯一计数点是 `set_graphic`）。sprite 不 destroy 被 GC → 计数永不归零。
- `FlxFrame.parent` / `FlxFramesCollection.parent` 是强引用但**不计数**，`useCount==0` 不等于没人引用。
- `FlxG.bitmap.remove()` 会连带 `graphic.destroy()`（`BitmapData.dispose()` + 销毁所有 frameCollections）。
  所以销毁顺序必须是：先 `__texture.dispose()`，再 `FlxG.bitmap.remove()`。
- `FlxGraphic.fromBitmapData(bd, false, key)` 同 key 命中会**直接返回旧对象、丢掉刚解码的 bd（不 dispose）**。
  解码前必须先查 `FlxG.bitmap`。
- `set_bitmap(null)` 不清空字段，`graphic.bitmap == null` 不能当销毁判据，用 `isDestroyed`。
- 绝不把状态实例包成 `() -> inst` 传给 `switchState`（会存进 `_constructor`，`resetState` 二次 create）。
  用 `MusicBeatState.wrapNextState(inst)`。

**openfl**
- `BitmapData.dispose()` 里 `gl.deleteTexture` **整块被注释**（`BitmapData.hx:801`），且 `TextureBase` 没有 finalizer。
  → `bmp.__texture.dispose()` 是**唯一**能真正释放显存的调用。
- `disposeImage()` 全文只有一行 `readable = false`，零字节释放。真正丢 CPU 副本在 `getTexture()` 末尾的
  `if (!readable && image != null) { __surface=null; image=null; }` —— **只在上传成功的同一帧发生**。
- `readable=false` 后 `getPixel32` 返回 **0**、`getPixels` 返回 **null**（不崩，是静默失效）。
- `__texture.dispose()` 之后**不会重建**（`__texture`/`__textureContext` 都还在）→ 后续渲染拿已删句柄、
  **永久黑图且不报错**。
- `createRectangleTexture` 第 4 参 `optimizeForRenderToTexture` 传 true 会额外建 FBO + `DEPTH24_STENCIL8`
  renderbuffer（≈ +100% 显存）。openfl 自己传 false。
- GPU-only 的图没有 CPU 像素：`copyPixels`/`FlxFrame.paint` 静默空白，`draw`/`fillRect` 会写穿共享纹理。
  → `full` 只适合「纯显示、不二次加工」的图。
- `Context3D.totalGPUMemory` 只查 NVIDIA 专有的 `NVX_gpu_memory_info`，**AMD 上恒 0**。读显存要用 DXGI。

**工具链**
- 跨平台验证方法：把 `release.hxml` 的 `-D windows` 换成 `-D linux`、`-cpp` 指向临时目录，
  跑 `haxe <hxml> --no-output`。DXGI 那套已验证在「cpp 但非 Windows」下零错误。

---

## 5. 待办（按性价比）

1. **实机验证最近三轮**（GPU 上传重写 + 预载不上传 + 显存分档）：
   - 6GB 卡：F9 里「显卡 / 独占显存」应显示约 6.0GB、「预载上传 关」；Fatal Finale 的 GPU 峰值应低于 8.76GB。
   - 12GB 卡（6750 GRE）：自动变「开」，进歌不应再有一次大上传卡顿。
   - 画质：角色边缘、半透明舞台件、图标描边。
2. **结算点从 `PlayState.create()` 开头挪到末尾**（NMV / Impostor 的做法）：
   那样可以整块删掉 `pinGraphic`/`pinSound`，并解决「create 末尾不敢清理」的历史包袱。中风险，要回归 note 池 / 角色重载。
3. **P3 降采样重做**（唯一真正减小纹理的手段）：
   正解是「解码后缩图 **+ 同步重写图集描述坐标**」（sparrow / packer / texturepacker 三种）。
   不要再改 `FlxFrame.frame`（已证明必炸）。外部没有先例，需自研。
4. **角色懒加载**：Fatal Finale 的 `characterList` 有 56 个角色只用到 3 个，预载就占 ~5.5GB。
   做成开关 + 在 chart events 前预取。脚本访问未加载角色会拿不到对象，需要兜底。
5. **显存仪表**：DXGI 已能拿总量；如果要「当前可用」，得用 `IDXGIAdapter3::QueryVideoMemoryInfo`（再加几十行 C++）。

---

## 6. 文档索引

```
docs/HANDOVER.md                        ← 本文件（先读这个）
docs/memory-research/
├── 00-总览.md                          ← 五路外部调查的结论 + 三个已修 bug + 跨平台矩阵
├── 01-openfl-gpu-caching.md            ← BitmapData 五态状态机、唯一释放路径、10 条硬规则
├── 02-novaflare-impostor.md            ← NovaFlare / Impostor 实现拆解 + 移植清单
├── 03-psych-vanilla.md                 ← 12 个 Psych 版本演进 + 官方 Funkin 0.8.7 拆解
├── 04-other-engines.md                 ← Codename 代际 GC / 图集拆分 / "Vulkan 分支"真相
├── 05-flixel-graphics.md               ← useCount / cacheFrameMatrix / GPU-only 风险清单
└── 06-novaflare-lime-fork.md           ← lime fork 的解码期降采样（setMaxTextureSize + graphicScale）
docs/memory-optimization-handover.md    ← 过程记录（按时间堆的，查细节用）
```

参考源都在 `D:/funkin-sources/`（Psych 各版本、官方 Funkin、Codename、NMV、Impostor 等）。
注意：`D:/funkin-sources/FNF-PsychEngine-1.0.4/` **不是官方 1.0.4**，是挂 NovaFlare 血统的第三方 fork；
逐字节对标 1.0.3 的是 `1.0.4-OG/`。

---

## 7. 备份

| 目录 | 内容 |
|---|---|
| `.workbuddy-ai/backup/2026-11-11-p2-release/` | P2 之前的原始文件 |
| `.workbuddy-ai/backup/2026-11-12-p3-downscale/` | P3 降采样完整源码（已回退，要重做可取） |
| `.workbuddy-ai/backup/2026-11-12-gpu-fix/` | GPU 上传路径重写前的文件 |
| `.workbuddy-ai/backup/2026-11-12-vram-tier/` | 显存分档前的文件 |
