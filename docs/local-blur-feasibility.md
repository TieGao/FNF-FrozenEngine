# Flixel（FE）局部模糊 UI / 组件可行性报告

> 结论先说：**能做，而且 FE 已经拥有这条路上大约 80% 的基础设施。**
> 已被实践验证的部分是"GPU 上跑 openfl 滤镜"（`FlxFilteredSprite` + Freeplay 柔光面板，15+ 个界面在用）；
> 缺的不是能力，而是"把背景变成一张可采样的纹理"这一步——这正是 backdrop blur（毛玻璃）与
> "模糊 sprite 自己"的唯一区别。下文给出三条落地路径、每条的真实代价、以及为什么其它路走不通。

---

## 1. 需求界定

"局部模糊 UI/组件" = **backdrop blur（毛玻璃）**：面板区域显示的是**它背后游戏画面的模糊版**，
面板外的画面保持清晰。它不等于：

- **模糊组件自身纹理**（发光/柔化面板自己的贴图）——FE 已实现（`FreeplayListItem` 的 blur 风格）；
- **全屏暗化遮罩**——FE 暂停菜单现状（`PauseSubState.hx:90`，1×1 黑块拉伸）。

用户实验确认过根因：把 `openfl.filters.BlurFilter` 套在 `FlxFilteredSprite` 上，
只能模糊 sprite 自己的像素，模糊不了背后的背景。**这不是用法错误，是架构使然**（见 §3）。

## 2. 技术栈现状（本次实测）

| 库 | 实际选中版本（haxelib list） | 说明 |
|---|---|---|
| flixel | **git**：TieGao/Flixel `dev`（= 6.2.0+10 commits） | 2026-10-26 从安装版 6.2.0 切换 |
| flixel-addons | **git**：TieGao/Flixel-Addons `dev`（= 4.0.1+8） | 同上 |
| openfl | **git**：TieGao/openfl（= 9.5.2+56） | 关键：原生 GL 滤镜链路完整 |
| lime | **8.4.0 安装版** | `lime/git` 目录 HEAD 损坏、未生效（见 §8 坑清单） |
| hxcpp | git（TieGao fork） | |

游戏窗口 1280×720@60，`allow-high-dpi="true"`（Project.xml:52）。
渲染模式：`FlxG.initRenderMethod()` 在 OPENGL/OPENGLES/WEBGL 下走 **DRAW_TILES**（FlxG.hx:594-608），
即 FE 的 Windows 与 Android 都是 **tile 模式**：每个 `FlxCamera` 把绘制指令画进
`canvas:Sprite`（FlxCamera.hx:505-508，openfl 显示对象子树），再由 openfl GL 后端上屏。

## 3. 为什么"套滤镜模糊不了背景"——根因

openfl 的 `DisplayObject.filters` 是**对象纹理空间**操作。设了 filters 后 openfl 做的事
（DisplayObjectRenderer.hx:214 `__updateCacheBitmap`）：

1. 给对象建一张 GPU 纹理 `__cacheBitmapData`，把**对象自身子树**渲染（RTT）进去（:594-599）；
2. 对这张纹理逐个跑滤镜 shader pass（:601 起，`__renderFilterPass`）；
3. 把结果贴回显示列表。

采样源永远是**对象自己的像素**，openfl 的 Shader 模型里**不存在"当前 framebuffer / 背景"这个输入**。
所以滤镜套在面板 sprite 上 = 模糊面板自己的图；背景像素根本不在采样范围内。
CSS `backdrop-filter` 那种"任意组件免费拿到背后画面"的模型，在 openfl/flash 显示列表架构里
**没有对应物，也无法通过改用法获得**——必须显式制造"背景 → 纹理"这一步。这就是全部额外代价的来源，
也是本报告所有方案的分水岭。

## 4. 三条可行路径

### 路径 C：一次性快照模糊（暂停/对话框，最便宜）

**思路**：打开面板瞬间把当前画面抓成 BitmapData，模糊一次，当作面板底图显示；关闭即弃。
背景冻结（暂停菜单本来就暂停），"实时性"需求不存在。

- 抓屏：`FlxG.stage.window.readPixels()`（lime API）或 `BitmapData.draw()`；
- 模糊：两种都已现成——
  - CPU：`BitmapData.applyFilter()` 在原生可用，`BlurFilter.__applyFilter` 底层就是
    lime 的 `ImageDataUtil.gaussianBlur`（BlurFilter.hx:182-193）；
  - GPU：上传回纹理后复用 FE 的 `FlxAnimateFilterRenderer.applyFilter`（见路径 B）。
- **代价**：一次性 hitch。720p 读屏 + CPU 高斯（quality 1）在 hxcpp 上估 15~50ms，
  约掉 1~2 帧，出现在"按暂停"瞬间，无感；走 GPU 路径 hitch 几乎为零。
- **开发量**：0.5~1 天。**质量**：真高斯模糊，观感上限高。
- **局限**：背景必须静止（或接受模糊层不更新）。暂停菜单、模态确认框完美适配；
  "游戏继续跑的浮动面板"不适用。

### 路径 A：相机分层 + `FlxCamera.filters`（推荐主线）

**思路**：背景内容与 UI 分属不同 FlxCamera（Psych 系 PlayState 本来就是 camGame / camHUD / camOther
多相机结构，菜单态按需补一个），给**背景相机**挂滤镜：

```haxe
camGame.filters = [new BlurFilter(12, 12)];   // flixel dev 自带
// camGame.filtersEnabled 默认 true
```

**为什么可行（证据链）**：flixel dev 的 `FlxCamera` 原生支持
`filters`（FlxCamera.hx:471）、`filtersEnabled`（:360），并在**每帧** `render()` 里应用：
`flashSprite.filters = filtersEnabled ? filters : null;`（:733）。
openfl 侧对设了 filters 的 Sprite 自动走 GPU 硬件缓存路径
（`__shouldCacheHardware_DisplayObject`：`displayObject.__filters != null → return true`，
DisplayObjectRenderer.hx:204，**不会**退化到 Cairo 软渲染），即每帧：
背景相机子树 RTT 到纹理 → 滤镜 pass → 贴回。安装版 flixel 6.2.0 里这段代码同样存在。

**"局部"怎么来**：模糊的是整个背景相机；面板区域 = UI 相机上的一块"洞"，
洞里露出底下被模糊的背景，洞外加面板边框/半透明着色。**背景整体被模糊、UI 清晰**——
这正是绝大多数游戏暂停/设置界面的毛玻璃形态，通常就是设计目标本身。
若要求"面板外背景清晰、只有面板后模糊"，用路径 B。

**代价（每帧，720p，工程估算）**：
- 背景相机 RTT 重渲一次：与正常渲染同量级（几百个批量四边形，~0.5-2ms；菜单态更低）；
- 模糊 pass 数 = `round(radius×quality/4)+1` 水平 + 同数垂直
  （BlurFilter.hx:271-278）：半径 12、quality 1 → 4+4=**8 pass**；半径 20 → 12 pass。
  每 pass 一个 7-tap 高斯（BlurFilter.hx:292-345）全屏四边形；
- 合计：桌面独显约 **1~2ms/帧**，核显与中端安卓约 **3~8ms/帧**；
  半分辨率缓存（`cacheAsBitmapMatrix` 缩 0.5，DisplayObjectRenderer.hx:329 支持）降到 1/4。
- 内存：相机尺寸 ×3 张 RGBA 纹理（cache + 两张 ping-pong）≈ 8MB@720p，
  注意 `allow-high-dpi` 下按 pixelRatio² 放大（150% 缩放 = 2.25×）。

**开发量**：1~3 天（各 state 检查相机分层；PlayState 结构现成，菜单态多数是单相机要补分层的）。
**质量**：GPU 高斯，逐帧更新，背景可继续动（演出不暂停的设置面板也成立）。
**移动版**：同一代码路径（GLES），建议默认半分辨率、低端机降级为暗化遮罩。

### 路径 B：真·局部毛玻璃（面板级，观感上限最高）

**思路**：背景照常清晰渲染；每帧（或需求驱动）把背景相机内容 RTT 成一张纹理，
只对面板尺寸跑模糊 pass，再以 FlxSprite + `clipRect` 贴回面板区域。面板外画面完全不受影响。

**为什么机械已存在 90%**：
- RTT 任意显示对象进 GPU 纹理：`BitmapData.__drawGL(source, renderer)`（BitmapData.hx:3180）——
  openfl 自己的滤镜链路内部就调它（DisplayObjectRenderer.hx:599）；
- 模糊 pass 循环 + 目标切换 + 裁剪：FE 的 `FlxAnimateFilterRenderer.applyFilter`
  （source/backend/FlxFilteredSprite.hx:316-387）已经封装完，且实测在跑（Freeplay 柔光面板）；
- 时序钩子：`FlxG.signals.postDraw`（SignalFrontEnd.hx:48）在相机绘制完成后触发，
  在此快照 → 结果下一帧显示（1 帧延迟，对模糊层无感）。

**拼装草图**：
```haxe
// postDraw 里：把 camGame 快照进纹理（纯 GPU，无 CPU 回读）
blurTex.__drawGL(camGame.flashSprite, glRenderer);
// 现成的 pass 循环，半径/quality 自定，可配合 __scissorRect 只处理面板子矩形
result = filterRenderer.applyFilter(blurTex, ping1, ping2, blurTex, [blur], rect, rect);
// 面板 sprite 换帧 + clipRect 限制到面板
panelSprite.frames = FlxGraphic.fromBitmapData(result); ...
```

**代价**：RTT 一次 + 模糊 pass；pass 成本与 A 相同、但目标纹理可只做面板尺寸（总像素更少），
等效成本 ≤ A。桌面 ~1-2ms、安卓 ~2-6ms/帧（同样可半分辨率）。
**开发量**：3~7 天（含面板组件封装、多面板/嵌套处理、移动端调参与验证）。
**风险**：大量 `@:privateAccess`（项目风格已如此）；`flashSprite` 含 scrollRect 子结构，
快照矩阵要对齐（FlxAnimateFilterRenderer.setRenderer 里已有同类矩阵处理可抄）。

## 5. 成本汇总

| 方案 | 每帧 GPU 成本 | 每帧 CPU 成本 | 内存 | 首次 hitch | 背景可动 | 开发量 | 移动端 |
|---|---|---|---|---|---|---|---|
| C 快照模糊 | ≈0（显示一张图） | 打开瞬间 15-50ms | ~3MB | 1-2 帧 | ✗ | 0.5-1 天 | ✓ |
| A 相机滤镜 | ~1-2ms（桌面）| ≈0 | ~8MB | 无 | ✓ | 1-3 天 | ✓ 半分辨率 |
| B 局部毛玻璃 | ≤A | ≈0 | ~4MB | 无 | ✓（滞后 1 帧） | 3-7 天 | ✓ 半分辨率 |
| 假模糊（现状） | 0 | 0 | ≈0 | 无 | — | 0 | ✓ |

（GPU 数字为量级估算，需在目标机型实测；pass 公式与纹理结构来自源码，见附录。）

## 6. 不推荐 / 走不通的路

- **实时 CPU 全屏模糊 / 切 blit 模式**：blit 模式整个场景改 CPU 合成，FNF 场景数百精灵 60fps 不现实；
  CPU 高斯 720p 每帧 10ms+ 起步，安卓直接出局。为了一个 UI 效果重写渲染路径，负收益。
- **shader 直采 backbuffer**：openfl Shader 没有 framebuffer 绑定；绕过它用
  `lime.graphics.opengl.GL` 做 glReadPixels/copyTexSubImage 黑科技"能做"，但要自己管理
  GL 状态与 openfl 管线打架、区分 GL/GLES、处理 dpi/多相机/视频，1-3 周起步且每次升库都可能碎。
  在 A/B 已把同效果做便宜的前提下，没有理由选它。
- **升级到"原生支持 backdrop 的框架"**：不存在。flash 血统的显示列表模型里就没有这个概念，
  换引擎不属于本命题的解。

## 7. 坑清单（落地时逐条核对）

1. **`lime/git` 损坏**：HEAD 无法解析、haxelib 实际用的是 8.4.0 安装版。若后续想生效 git 版需重装；
   本报告 openfl 结论基于 9.5.2+56，与 lime 版本无耦合。
2. **`allow-high-dpi`**：openfl cacheBitmap 按 pixelRatio 放大（DisplayObjectRenderer.hx:387），
   Windows 150% 缩放下纹理与成本 ×2.25；A/B 都建议显式半分辨率。
3. **滤镜相机每帧全价**：相机每帧重画 draw stack → cacheBitmap 每帧重渲。静态面板用
   `FlxFilteredSprite`（filterDirty 才重跑）与模糊相机是两种成本模型，别混用。
4. **半径↑ = pass 数线性↑**（BlurFilter.hx:275-278），大半径用"小半径多次/半分辨率"凑，
   不要直接 blurX=60。
5. **视频**：FE 走 `hxvlc.flixel.FlxVideoSprite extends FlxSprite`，视频帧进 flixel 相机管线，
   相机滤镜能盖住；但别用 `hxvlc.openfl.Video/FlxVideo` 直接挂 stage 的用法（会游离在所有相机滤镜外）。
6. **`FlxFilteredSprite` 与 clipRect 的既有冲突**已有 `setFiltersEnabled` 开关兜底
   （FlxFilteredSprite.hx:158-179，FreeplayListItem.hx:202 在用），B 路径面板复用同一模式。
7. **移动版同步**：功能要按 fe-sync 流程落到 D:\FNF-FrozenEngine-Moblie，安卓端务必真机测半分辨率档。

## 8. 推荐路线

1. **先 C 后 A**：暂停菜单/对话框先上 C（1 天内见效）；需要"背景继续动"的界面（设置页、
   Freeplay 详情面板）上 A。两者共享同一个"Blur 面板"组件抽象，随时互换实现。
2. **B 作为精品化第二步**：等 A 的相机分层改造铺完，挑一个高曝光面板（如 Freeplay 选中项详情）
   做真局部毛玻璃试点，再决定是否推广。
3. **降级链**：桌面全效 → 移动半分辨率 → 低端机/省电模式暗化遮罩（现状）。

---

## 附录：证据索引（均为本次实测路径）

- FE `source/backend/FlxFilteredSprite.hx`：自研滤镜 sprite；`FlxAnimateFilterRenderer.applyFilter` :316-387（GPU RTT + 滤镜 pass + scissor）；`setFiltersEnabled` :164
- FE `source/states/freeplay/FreeplayListItem.hx`：STYLE_BLUR 柔光面板（自模糊，非 backdrop）
- FE `source/substates/PauseSubState.hx:90` / `NewPauseSubState.hx:160`：现行黑遮罩基线
- flixel git `flixel/FlxCamera.hx`：`filters` :471、`filtersEnabled` :360、每帧应用 :733（`render()` 内）、`canvas:Sprite` :505
- flixel git `flixel/FlxG.hx:594-608`：GL → DRAW_TILES；`flixel/FlxSprite.hx:295`：`shader:FlxShader`
- flixel git `flixel/system/frontEnds/SignalFrontEnd.hx:47-48`：preDraw/postDraw
- openfl git `src/openfl/display/DisplayObject.hx`：`set_filters` :2138
- openfl git `src/openfl/display/DisplayObjectRenderer.hx`：`__updateCacheBitmap` :214、hasFilters :294、RTT :594-599、滤镜 pass :601+、强制硬件路径 :204、cacheAsBitmapMatrix :329、pixelRatio :387
- openfl git `src/openfl/filters/BlurFilter.hx`：构造 :164、CPU 实现 :182（ImageDataUtil.gaussianBlur）、pass 配置 :271-278、7-tap GLSL :292-345
- openfl git `src/openfl/display/OpenGLRenderer.hx`：`__renderFilterPass` :923、`__scissorRect` :1003、`__setRenderTarget` :1072
- openfl git `src/openfl/display/BitmapData.hx`：`applyFilter` :357、`__drawGL` :3180
- lime 8.4.0 `src/lime/graphics/opengl/GL.hx`：裸 GL 直通存在（黑科技方案的物质基础，未推荐）
- hxvlc git `source/hxvlc/flixel/FlxVideoSprite.hx:35`（extends FlxSprite → 相机管线内）
