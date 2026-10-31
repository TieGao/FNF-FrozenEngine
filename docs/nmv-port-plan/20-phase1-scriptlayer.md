# NMV 脚本 API 移植计划 — 20 Phase 1：脚本层移植（已完成 2026-10-17）

## 落位文件（10 个，未提交）

| 文件 | 来源 | 处理 |
|---|---|---|
| `source/nmv/scripts/ParserEx.hx` | `extensions/hscript/ParserEx.hx` | 字节级拷贝，仅包名 `extensions.hscript` → `nmv.scripts` |
| `source/nmv/scripts/InterpEx.hx` | 同上 | 同上 |
| `source/nmv/scripts/IrisEx.hx` | 同上 | 同上 |
| `source/nmv/scripts/Sharables.hx` | 同上 | 同上 |
| `source/nmv/scripts/ScriptGroup.hx` | `funkin/scripts/ScriptGroup.hx` | 适配：补 `import nmv.scripting.ScriptConstants`（原来靠 NMV 全局 import.hx），`@:inheritDoc` 去掉参数 |
| `source/nmv/scripts/FunkinScript.hx` | `funkin/scripts/FunkinScript.hx` | 适配见下 |
| `source/nmv/scripting/ScriptConstants.hx` | `funkin/scripting/ScriptConstants.hx` | 适配：PlayState/GameOverSubstate 用 FE 路径（`states.` / `substates.`，两者 instance 静态字段 FE 都有） |
| `source/nmv/scripting/ScriptedState.hx` | `funkin/scripting/ScriptedState.hx` | 壳式改写见下 |
| `source/nmv/scripting/ScriptedSubstate.hx` | 同上 | 同上 |
| `source/nmv/states/FallbackState.hx` | `funkin/backend/FallbackState.hx` | 精简见下 |

## FunkinScript 的适配要点

- **preset 表整体收进 `#if NMV_PRESET`（默认关）**：原版 preset() 引用约 40 个 NMV 私有类（funkin.*），直接搬编译不过；`super.preset()` 留在宏外。Phase 2/3 按四档填表时再开。
- `init()`（Iris 调试后端）同样收进宏：依赖 NMV 的 DebugTextPlugin/Logger/Mods。
- FE 差异替换：`FunkinAssets.getContent` → `getContent()` 助手（磁盘优先 `FileSystem.exists` + `sys.io.File.getContent`，回退 `lime.utils.Assets.getText`——内容包是运行时磁盘资源，与项目约定一致）；`FunkinAssets.exists` → `FileSystem.exists`；`Logger.log(..., ERROR, ...)` → `FlxG.log.error(...)`；`Paths.getModFolder` FE 没有 → 去掉自动探测，modFolder 走显式传参（接线归 Phase 4）。
- `execute()` 的解析异常仍落 `parsingException`（NMV 语义保留）。

## ScriptedState / ScriptedSubstate 壳式改写

NMV 原版 extends 自带 scriptGroup 的 `funkin.backend.MusicBeatState`；FE 的 `backend.MusicBeatState` 没有脚本挂载。按方案 40 的壳式路线：**不改 FE 基类**，两个壳类各自持有 `scriptGroup/scripted/scriptName` + 本地实现 `initStateScript`（语义同 NMV：`scripts/states/<名>` 约定、失败走 FallbackState、onLoad/onCreate 广播）。引擎级全面挂载是 Phase 4。

## FallbackState 精简

- 去掉 `uhoh.png` 背景图：本仓库无此资源（FE 资源布局与原版不同），改纯文字版。
- 去掉 `@:nullSafety`：FE 侧同类用法（`setFormat(Paths.font("vcr.ttf"), ...)`）都不开空安全，开了反而编译不过（Paths.font 返回可空）。
- `controls.ACCEPT`、`Paths.font`、`MainMenuState` 均为 FE 既有物。

## 验证结果（全过）

| 项 | 命令 / 方式 | 结果 |
|---|---|---|
| 强制纳入编译 | `haxe export/release/windows/haxe/release.hxml --no-output --macro "include('nmv')"` | exit 0（修掉 3 个 import 缺失后） |
| 代码生成 | 同上不加 `--no-output` | exit 0，`obj/src/nmv/**` 产物生成 |
| 语法冒烟 | 隔离 harness 真跑脚本 | SMOKE OK，见下 |

**为什么必须 `--macro include('nmv')`**：没有任何模块引用 `nmv.*`，死代码消除会**整包跳过**——直接跑 release.hxml 显示 exit 0 是假象（一个 nmv 文件都没编）。此后凡涉及 nmv 包的验证都带这个宏。

**冒烟方式（隔离 harness）**：`--interp` 跑不了 lime 原生绑定（NativeCFFI 字段只在 cpp/hl/lime_cffi 下声明），且 `import.hx` 会把整个游戏拖进类型检查。做法：把 `source/nmv/scripts` 复制到临时目录（无 import.hx），加 `-cp <fork>`，宿主类直接 `ParserEx.parseString` + `InterpEx.execute`，脚本通过 `variables.set('report', fn)` 回调自报结果。命令：
`haxe -D hscriptPos -cp src -cp <hscript-iris-nmv> -cp . --interp -main SmokeMain`

冒烟验证通过的三件事：
1. **EFor**：`for (i => v in list)` 迭代数组，count=3；
2. **CString**：`msg = 'cstring: count=$count'` → `cstring: count=3`；
3. 宿主函数注入与调用（report 回调 4 次全达）。

## 踩坑记录（重要，后续写脚本/嵌脚本都会遇到）

1. **`-D hscriptPos` 是硬依赖**：fork 的 `Parser.parseStructure` 签名按它分叉，缺了 ParserEx override 类型不匹配报一片错。Project.xml:225 已挂在 HSCRIPT_ALLOWED 下，游戏构建自带；独立编译（冒烟/工具链）必须显式带。
2. **hscript 的插值只有单引号字符串生效**（`'...$x...'` / `${expr}`，双引号是字面量）——与宿主 Haxe 单引号串的插值行为一致，NMV 内容脚本同理。
3. **宿主 Haxe 单引号串会对 `$ident` 做编译期插值**：把带 `$` 的脚本文本嵌进宿主单引号字符串时，必须在 `$` 处拆串拼接（`'...$' + 'count'`），否则 Haxe 编译器报 "Unknown identifier"（报错位置在字符串内部，极具误导性；且 try/catch 拦不住，是编译期错误）。
4. hscript 顶层 `var` 进 locals 作用域、执行完即丢；跨调用保持的必须用 `public var`（ParserEx 把它转成 `:sharable` 元数据落 Iris variables）。冒烟因此用 report 回调而非读回变量。

## 完成判据

- [x] 10 个文件就位、强制纳入编译 + 代码生成通过
- [x] EFor / CString / 宿主函数注入的运行时冒烟通过
- [x] preset 表收进 NMV_PRESET 宏（默认关），Phase 2 再填
