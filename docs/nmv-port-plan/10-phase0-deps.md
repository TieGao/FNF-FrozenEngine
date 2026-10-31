# NMV 脚本 API 移植计划 — 10 Phase 0：依赖与分支（已完成 2026-10-17）

## 前置状态（执行前核对）

- 分支 `NMV-ScriptAPI-Port` 已创建并切换；工作区原有未提交改动（KeyboardViewer、ModsMenuState、NoteOffsetState、两个 .gitkeep、Necron 元数据）**原样保留、不动、不提交**。
- `Project.xml` 原状：`haxelib name="hscript-iris" if="HSCRIPT_ALLOWED" version="1.1.3"`（官方版）。
- **`HSCRIPT_ALLOWED` 无需改构建脚本**：`Project.xml:24` 有 `<define name="HSCRIPT_ALLOWED" if="desktop"/>`，Windows 构建自动开启；`hscriptPos` 宏挂在它下面（:225）。
- FE 源码无 `funkin/`、`nmv/` 目录；`psychlua/` 完整。

## 实际执行（结论）

**不采用仓库内 `.haxelib` dev link**：cwd 下的 `.haxelib/` 会被 haxelib 当作唯一仓库根，**整体遮蔽**全局库（实测 `haxelib path lime`、`haxelib run lime` 全部 "not installed"），此路不通。

**实际方案**：把 NMV fork 改名 `hscript-iris-nmv` 装进**全局库**，与原版 `hscript-iris` 并存：

1. fork 源码 = `D:/NightmareVision/.haxelib/hscript-iris/git`（HEAD `62d828b`，remote `pisayesiwsi/hscript-iris@dev`，626K）。
2. 拷到 `C:/HaxeToolkit/haxe/lib/hscript-iris-nmv/1,1,3/`，`.current` 写 `1.1.3`（与全局库 `hscript-iris` 的目录约定一致：current 用点分版本，目录名用逗号）。
3. 修改库内 `haxelib.json` 的 `name` 为 `hscript-iris-nmv`（不改的话 lime 注入的 define 仍是 `-D hscript-iris=1.1.3`，About 界面版本显示会错）。version 保持 1.1.3，与 Project.xml 约束匹配。
4. fork 与原版的包结构一致（`crowplexus.hscript` / `crowplexus.iris`），`HScript.hx` 的 import 零改动；fork 自带 `extraParams.hxml` 注入 `-D IRIS_DEBUG`，与上游行为一致。
5. 改动文件（未提交）：
   - `Project.xml`：`<haxelib name="hscript-iris-nmv" if="HSCRIPT_ALLOWED" version="1.1.3"/>`，注释写明"官方 1.1.3 解析不了脚本层 EFor/CString 自定义语法节点"。
   - `source/substates/AboutSubState.hx`：`VersionInfo.lib('hscript-iris-nmv')` + 显示文字改 `hscript-iris-nmv`（该宏读 `-D <库名>=<版本>`，库改名必须同步，否则显示 Unknown）。
6. 原版 `hscript-iris` 保留不动 → 主版 FE（J:/FNF-FrozenEngine）等其他项目继续用官方版，互不影响。

## 验证结果（全过）

| 项 | 命令 | 结果 |
|---|---|---|
| 解析 | `haxelib path hscript-iris-nmv` | fork 路径 + `-D hscript-iris-nmv=1.1.3` |
| hxml 注入 | `haxelib run lime display windows` | `-cp .../hscript-iris-nmv/1,1,3` + define 均在 |
| hxml 生成 | `haxelib run lime update windows` | `export/release/windows/haxe/release.hxml` 生成（本仓库首个） |
| 宏开-类型检查 | `haxe export/release/windows/haxe/release.hxml --no-output` | exit 0 |
| 宏开-代码生成 | `haxe export/release/windows/haxe/release.hxml` | exit 0，`obj/src/psychlua/` 产物正常 |
| 宏关-类型检查 | 删 `-D HSCRIPT_ALLOWED` / `-D hscriptPos` / fork 两行、`-cpp` 改临时目录后 `--no-output` | exit 0 |
| 宏关-代码生成 | 同上 | exit 0；产物无 crowplexus 引用（`CreditsState.cpp` 里的 "crowplexus" 是致谢名单字符串，非残留） |

宏关能干净编译的原因（既有结构）：`HScript.hx` 的 `class HScript extends Iris`、`CustomInterp extends crowplexus.hscript.Interp` 整体在 `#if HSCRIPT_ALLOWED` 内，宏关时走文件末尾的桩 `class HScript`（788 行）。

## 遗留

- 临时验证产物 `/tmp/no_hscript.hxml`、`%TEMP%/obj_no_hscript` 未删（删除操作被拦），需要时手动清。
- `haxelib run lime update windows` 有一条提示：Lime 9.0.0 与 OpenFL 9.5.2 版本提示（expected 7.7.0+），与本任务无关，未处理。

## 完成判据

- [x] `HSCRIPT_ALLOWED` 开启途径确认（desktop 自动开）
- [x] fork 以 `hscript-iris-nmv` 进入全局库并被本仓库引用，官方版不受影响
- [x] 宏开 / 宏关四个编译验证全部通过
