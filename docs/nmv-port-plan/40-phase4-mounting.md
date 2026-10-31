# NMV 脚本 API 移植计划 — 40 Phase 4：挂载机制与 Content 模式接线

> 状态：**已完成（编译期验证通过；运行时验证随 Phase 5 回归）**

## 问题

脚本要挂到某个 State 下才能随游戏循环 update / 事件广播 / pause / destroy。NMV 的做法是 `ScriptedState` + `ScriptedSubstate` 包装层 + `ModPlugin` 生命周期。

## 选定方案：壳式挂载，不动 FE 的 State 树

不引入 ScriptedState 基类（那要改 FE 全部 State 的继承，动静太大）。改为：

1. `source/nmv/scripts/NMVSciptHolder.hx`：持有一个 `ScriptGroup`，对外暴露 `load` / `loadDir` / `loadStateScript` / `call` / `set` / `destroy`，供 State 以**组合**方式持有。
2. 挂点只有两个 State：`PlayState`（歌内）与 `FreeplayState`（浏览态）。切换判据一律读 `Paths.currentChartCategory` / `Paths.currentContentRoot`，模式写入仍只走 `FreeplayState.enterContentMode/exitContentMode` 两个入口。
3. 脚本目录来源（两套布局都支持）：
   - 状态脚本：`<contentRoot>/shared/scripts/states/<StateName>.hx`（FE 布局，走 `Paths.getPath` 的 shared 回退）与 `<contentRoot>/scripts/states/<StateName>.hx`（NMV 样本布局）。
   - 歌内脚本：谱面目录下全部 `.hx`。目录优先取 `Paths.currentChartDirectory`（`setChartContext` 写入，CustomCharts 与内容包通吃），回退 `<contentRoot>/songs/<歌>`。

## 落地细节

### NMVSciptHolder

- 每个脚本加入组时注入宿主变量：`add` / `remove` / `insert`（包一层闭包，保证 `this` 绑到宿主 State）、`camGame` / `camHUD` / `camOther`（宿主有该字段才注入）。这是 NMV `Stage.startScript` 的同名约定，样本里 347 处 `add(...)` 靠它。
- 脚本加载完立即回调 `onLoad`（与 NMV `ScriptedState` / `Stage` 同时机）。
- `initScript(path)` 已接通：`FunkinScript.scriptGroup` → `ScriptGroup.holder` → `holder.load(...)`，宿主变量与事件广播沿用同一组；未挂到容器时显式 throw。

### PlayState

- 字段 `nmvScripts`（`#if HSCRIPT_ALLOWED`）。
- `create()` 里「SONG SPECIFIC SCRIPTS」之后建容器并加载：内容包模式下才扫歌内脚本 + `scripts/states/PlayState.hx`。位置在 `callOnScripts('onCreatePost')` 之前，所以 `onCreatePost` 一定能收到。
- **事件广播复用 `callOnScripts`**：lua / FE hscript 都没有返回值时再走 `nmvScripts.call`，事件名与参数保持一套（`onUpdate`/`onUpdatePost`/`onStepHit`/`onBeatHit`/`onSectionHit`/`onEvent`/`onSongStart`/`onEndSong`/`onPause`… 全在 `callOnScripts` 的既有调用点上）。
- `destroy()` 里 `onDestroy` → 销毁容器。

### FreeplayState

- 字段 `nmvScripts`；`reloadNmvScripts()` 负责「先销毁旧的、Content 模式再重建」，并回调 `onCreate`。
- 触发点：`create()` 末尾 + `onModFolderChanged()` 开头（`enterContentMode`/`exitContentMode`/`applySourceFilter` 都会经过这里）。
- `update()` 转发 `onUpdate` / `onUpdatePost`；`destroy()` 销毁容器。

## 完成判据

- [x] 编译期：正式 hxml（不带 include 宏）类型检查 + 代码生成 exit 0，`obj/src/nmv/scripts/NMVSciptHolder.cpp` 确认生成 —— 说明 PlayState/FreeplayState 的真实引用链已把 nmv 包纳入编译，不再依赖 `--macro include('nmv')`。
- [x] 宏关方向：删掉 `HSCRIPT_ALLOWED` / `hscript-iris-nmv` / `hscriptPos` 后类型检查 exit 0，无 nmv 残留。
- [ ] 运行时：`fixtures/nmv-smoke-test.hx` 放进内容包（`<包>/scripts/states/PlayState.hx` 或 `<包>/songs/<歌>/test.hx`），进歌应依次看到 5 条 `[nmv-smoke]` 输出；退出再进不重复、不泄漏。**随 Phase 5 回归一起做**。

## 已知边界

- 只挂了 `PlayState` 与 `FreeplayState`。`MainMenuState` / 其它 State 的脚本（样本里的 `scripts/states/MainMenuState.hx` 等）走的是 NMV「整 State 替换」路线，属四档外，不做。
- 舞台脚本（`<contentRoot>/stages/<舞台>.hx`）未挂：FE 舞台是编译期类 + `assets/shared/stages/*.hx`（hscript），两套体系不合并。
- `modFolder` 取 `Mods.currentModDirectory`（内容包模式下 = `ClientPrefs.data.customChartModFolder`），供 `getModSetting` 等使用。

## commit

挂载机制独立 commit（它是后面所有功能的地基）。
