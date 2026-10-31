# NMV 脚本 API 移植计划 — 00 总览

分支：`NMV-ScriptAPI-Port`（基于 main 创建，用于本计划的分步开发，每阶段一个 commit）。
本目录为方案正文，按小节拆分为多份文档，**不提交**。

## 背景

把 Nightmare Vision（NMV）的 HScript 体系搬进 FNF-FrozenEngine，让无法编译 Haxe 的内容能跑起来：谱面事件里内联函数、角色脚本、舞台脚本调用引擎 API。此前四引擎 HScript 比对手册（`../hscript-engines-comparison.md`）和 skill `nmv-hscript-into-frozen` 已完成评估，本文档系列是**可执行的落盘计划**。

## 结论先行（已定，不再重开）

1. **路线选 C：只搬脚本层**，约 1200 行，90% 可原样复制；不搬 funkin 本体，不写 NMVPlayState。
   - 依据：对 `D:/VS IMPOSTOR LEGACY 1.0.3b` 全量扫描（127 个 .hx、11817 行），真正用 modchart 的只有 1 个文件 4 行，为它搬 5 万行引擎性价比极低。
   - 脚本层移植后，内容侧改用 FE 已有的舞台/角色机制。
2. **挡路的不是 modchart 而是 shader 族**：样本 29 个文件用 shader，`newShader(name)` 的查找路径与 FE 的 shader 目录约定不同。这是第一优先补的桩。
3. **补桩一律主动抛异常**：把"静默失效"（补错了不报错、只表现成没用）转成显式崩溃，崩一个补一个。
4. **挂载点接 FE 既有 Content 模式**：切换只走 `FreeplayState.enterContentMode()` / `exitContentMode()` 两处入口，判据是 `Paths.currentChartCategory` 非空（项目既有约定，勿零散改）。
5. FE 源码里没有 `funkin/` 命名空间，脚本层放 `source/nmv/`，不撞名，`Main.hx` / `import.hx` 需复核无冲突。
6. **界面用 FE 的**（2026-10-18 定）：NMV 的界面全是源码（states 8442 + substates 4226 + options 2997 + objects/menu 1818 行，强依赖 CosmicubeData / ProgressionUtil / AmongControls 等私有体系），不搬。NMV 内容放 `content/NMVMODS/<mod>/`，只提供歌 + 脚本 + week 数据；入口在 Freeplay 的 ModFolder 子界面加一级来源 `NMVMODS`。详见 `45-nmvmods-wiring.md`。

## 三条路线备选（备查，不重议）

| | A. 整树共存 | B. NMVPlayState + 补桩 | C. 只搬脚本层（选用） |
|---|---|---|---|
| 工作量 | 最重，5 万行级 | 中 | 最轻，约 1200 行 |
| 风险 | Main.hx 命名空间冲突、两套 PlayState 维护 | 语义风险最高：映射错不报错只表现成没用 | 低；未覆盖 API 显式报错 |
| 适用 | 100% 复刻 NMV 玩法 | 让 NMV 谱面能跑起来 | 默认推荐 |

## 分节索引

| 小节 | 内容 | 状态 |
|---|---|---|
| 10-phase0-deps | Phase 0：分支、hscript-iris fork 替换、双向编译 | ✅ 完成（2026-10-17） |
| 20-phase1-scriptlayer | Phase 1：脚本层 7 文件移植、包结构 | ✅ 完成（2026-10-17） |
| 30-phase2-preset-api | Phase 2：preset API 四档映射（一/二档） | ✅ 完成（2026-10-17，runtime 推迟 Phase 4） |
| 35-phase3-stubs | Phase 3：三档补桩（shader 族优先）、四档处理 | ✅ 完成（2026-10-17，runtime 推迟 Phase 4） |
| 40-phase4-mounting | Phase 4：挂载机制与 Content 模式接线 | ✅ 完成（2026-10-17，编译期验证；运行时随 Phase 5） |
| 45-nmvmods-wiring | Phase 6：NMVMODS 接线（界面用 FE 的，主菜单 tab） | ✅ 完成（2026-10-18，编译期 + 数据转换验证） |
| 50-phase5-regression | Phase 5：回归集跑命中率、迭代收尾 | ⬜ 下一步 |
| 60-pitfalls | 常见坑速查 | 持续补充 |

## 实施进度备注

- 每阶段完成后把执行结果、偏离计划的决策、验证情况回填到对应小节，**以小节"实施结果"段为准**（可能早于原计划描述）。
- Phase 1/2/3 的编译期验证（类型检查 + 代码生成 + 宏关方向）全部通过；运行时验证因 interp/eval 跑不动游戏全类型图，统一推迟到 Phase 4 游戏内冒烟与 Phase 5 回归。
- Phase 4 起正式 hxml（不带 `--macro include('nmv')`）就能把 nmv 包编进产物 —— 因为 `PlayState` / `FreeplayState` 已真实引用 `NMVSciptHolder`，不再依赖强制纳入。
- 运行时冒烟脚本见 `fixtures/nmv-smoke-test.hx`（复制进内容包即用），验证随 Phase 5 一起跑。
