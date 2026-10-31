# NMV 脚本 API 移植计划 — 50 Phase 5：回归集与收尾

## 回归集

唯一现成的真实语料：`D:/VS IMPOSTOR LEGACY 1.0.3b/content`（127 个 `.hx`、11817 行；`legacy` 与 `securitydlc` 两个内容包）。不要另找样例，真实内容的 API 组合最能暴露缺口。

## 流程（数据驱动，不靠估）

1. 把样本脚本批量过一遍 loader（可加一个临时 debug 开关，只 parse + 加载不执行），**统计**因缺 API 抛异常的脚本清单 → 得到真实命中率。
2. 按异常清单补三档桩（遵守"先崩后补"：每补一个，回归确认触发它的脚本跑过）。
3. 单确认 `CreditsRollSubState.hx` 的 3 个 `SubModifier` 用法是否影响玩法；不影响则 ④ 永久 throw。
4. shader 族单独专项：29 个文件依赖。重点核对两件事——
   - `newShader(name)` 的路径查找：NMV 走 `Paths.fragment(name)` + FunkinAssets；FE 要接 `Paths`（FE 的 shader 目录约定）与自己的图集/缓存机制；
   - 类名：NMV 的 `FunkinRuntimeShader` 等对应 FE 的运行时 shader 方案，uniform setter 方法名要对齐。
5. 收尾：清 debug 开关、临时测试脚本；文档更新（本目录）。

## 实测发现（回归前首例，2026-10-26）

- `content/legacy/songs/meltdown/meltdown.hx:11` → `Unknown variable: FunkinVideoSprite`（preset 层完全没注册视频类）。
  - NMV 用法：`new FunkinVideoSprite(0, 0, false)` 裸播放器，脚本自己 `insert`/`screenCenter`，靠 `video.onFormat(cb)` 在格式就绪时绑相机（`camOther`）和缩放；视频源 `videos/week1/meltdown.mp4`。
  - FE 的 `objects/VideoSprite` 形状不同：`new VideoSprite(videoName, isWaiting, canSkip, shouldLoop)` 自带加载 + skip UI，回调是 `finishCallback`/`onSkip`，格式就绪钩子是内部 `videoSprite.bitmap.onFormatSetup`。**不能直接映射**。
  - 候选方案（补桩时二选一）：① 在 `source/nmv/` 写薄适配类 `FunkinVideoSprite(x, y, pauseMusic)` 包 hxvlc `FlxVideoSprite`，`onFormat` 接 `bitmap.onFormatSetup`，视频名走 `Paths.video` 多格式回退；② 注册为显式 throw 桩，等真要跑视频 cutscene 再做 ①。
  - 关联：Impostor `songs/*/` 视频事件 `Meltdown Video` 走脚本内部状态机，`songEndCallback` 也是 NMV API，注意一并核对。

## 验收口径

- 一二档 + 已补三档下，样本**可加载率**（parse + 执行 onCreate 不崩）达到双方认可的一个数字（建议首轮目标 ≥ 80%，不进 playlist 的边缘样本单独记录）；
- 崩溃全部带 `NMV API <x> not implemented` 明确信息，没有静默 no-op；
- 双向编译各一次；关闭时零残留。

## Phase 5 关账（2026-10-28）

**结果：126 脚本（127 减 1 空文件）可加载率 115/126 = 91.3%，验收线（≥80%）达成。**
- 首轮 90.5%（114/126）；harness 建成后按数据补 14 个移植类 + 5 处接线/路径修复；
- 收尾修掉 AmongWalker 谜题（PresetStubs 桩反覆盖真类 + hxcpp `Type.createInstance`
  对非类对象静默返回 null → 脚本 `new` 得 null；修复 = 删桩 + InterpEx.cnew 防护）；
- 过程与失败清单终版定性见 `51-phase5-handoff.md` §5/§8（含"Invalid access to field X"
  = 对象为 null 的读法）。

**本流程条的收口情况：**
- 第 3 条 SubModifier 判定：随补桩进程解决，ModManager/modchart 族按"显式抛"档注册
  （PresetStubs），语料仅 CreditsRollSubState 触及，不影响玩法路径；
- 第 4 条 shader 族专项：`newShader(name)` 接 FE 的 `Paths.shaderFragment` +
  ErrorHandledRuntimeShader（PresetStubs），`shaders/` 7 个 NMV shader 类已移植；
- 第 5 条收尾：harness 走 `-D NMV_BATCH` + `-nmvbatch` 参数（正常构建零残留），
  代码已 commit（76e08444 / cbca0813 / 692a4092）。

**实测发现节（FunkinVideoSprite）已关**：采用候选①——`source/nmv/objects/FunkinVideoSprite.hx`
薄适配（hxvlc FlxVideoSprite 直包），配套 PlayState 的 songStartCallback/songEndCallback
属性别名（= FE startCallback/endCallback，NMV 同构语义）与 `Paths.sanitize`，
legacy 开场演出链路（videoCutscene / meltdown outro）具备；字幕与暂停联动未搬
（见 51 §8 登记未做）。

**遗留（非缺陷，登记）**：NMV 剧情系统（FinaleState/CreditsRollSubState/storyNodes）；
游戏内故事模式实测待用户执行（harness 不调 onCreatePost/onEvent，视频播放需实机）。

## 后续（超出本计划，仅登记）

- Impostor `PluginsManager` 与 NMV `ModPlugin` 的生命周期差异（若将来接 mod 插件体系再说）；
- CNE / NovaFlare 方言的接入点（脚本层目录隔离就是为了这个）。
