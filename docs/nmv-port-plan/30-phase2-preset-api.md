# NMV 脚本 API 移植计划 — 30 Phase 2：preset API 四档映射（一、二档）

FunkinScript.hx 里注册了约 125 个 preset API。分四档处理，**这个编号是全流程的核心**：

| 档 | 数量 | 内容 | 处理 |
|---|---|---|---|
| ① | 约 70 | flixel 全套（`FlxG`/`FlxSprite`/`FlxTween`/`FlxTimer`/`FlxText`）、`Conductor`、`ClientPrefs`、`CoolUtil`、`Character`/`Note`/`StrumNote`/`Alphabet`/`HealthIcon`/`BGSprite`、歌内上下文变量（`boyfriend`/`dad`/`gf`/`game`） | 零改动，直接注册 |
| ② | 约 10 | `FunkinCamera` → FE 相机类、`FunkinSound` → `FlxSound`、`setVar`/`getVar` → FE 的 `MusicBeatState.getVariables()`、`FlxAnimate*` → FE 的 animate 类、`WeekData`/`StageData`（同名异义） | 写映射表 |
| ③ | 约 15 | shader 族、`FunkinSprite`、`BackgroundDancer`/`Girls`、`MacroUtil.buildAbstract` 等（见 35 小节） | 补小桩 |
| ④ | 约 15 | modchart 全家（`ModManager`/`Modifier`/`SubModifier`/`NoteModifier`/`ScriptedModifier`/`EventTimeline`/各类 Event/`ModOptions`） | **默认不补**，见 35 |

## 一档操作要点

- NMV 的 preset 注册是把类引用塞进 interp 的 variables；FE 里同名类直接塞即可（flixel 全库共用，Psych 系 API 名字一致）。
- **上下文变量 `game`**：NMV 里指向 `PlayState`，FE 里要指向移植目标的 PlayState 等价物，这一项在 Phase 4 定，先留 TODO。

## 二档操作要点（最容易出错的一段）

- **同名不同义的类**：`WeekData`、`StageData` 在 NMV 和 FE 里字段/方法都不同。映射错了**不报错**，只表现成"读出来是空/错的值"，是最难查的一类 bug。所以这两个类要么补转换函数，要么**先主动 throw**，别直接映射。
- 映射表落成代码放在 `source/nmv/scripts/preset/`（或 FunkinScript 里单独一个 mapping 段），每行注释写明 NMV 原类型 → FE 目标类型。
- `setVar`/`getVar`：FE 对应 `MusicBeatState` 的 variables 读写（项目已有 getVariables 约定），注意 null 语义一致。

## 完成判据

- 一二档全部注册，编译通过；
- 测试脚本访问每个一二档符号不抛异常（`interp.variables.get(name)` 非 null）。

## 备注

- 三、四档此时仍是 NMV 原样引用会编译失败——所以 Phase 2 要配合 35 的"先抛异常桩"一起推进，否则编不过。顺序建议：**先落 throw 桩（35）→ 再注册一二档（30）**。

## 实施结果（2026-10-17）

新增文件（`source/nmv/` 下，均未提交）：

- `objects/FunkinSprite.hx` — extends `flxanimate.PsychFlxAnimate`，构造 + `loadNmvAtlas` + `playAnim`
- `scripts/preset/PresetCore.hx` — std/集合/Assets/keyToString/version（`VersionInfo.lib('hscript-iris-nmv')`）
- `scripts/preset/PresetFlixel.hx` — flixel 全系
- `scripts/preset/PresetFnf.hx` — FNF 类 + setVar/getVar/removeVar + getModSetting + 歌内上下文
- `scripts/preset/PresetStubs.hx` — newShader + throw 桩
- `scripts/preset/ScriptFlxColor.hx` — Int 封装（抄 FE `psychlua.HScript` 的 CustomFlxColor 模式）
- `test/NmvPresetSmoke.hx` — `#if NMV_SMOKE` 守卫的符号清单（约 80 名）+ 6 个 throw 桩自检

关键决策（偏离原计划的以本段为准）：

- **`FunkinSprite` 不覆盖 `loadAtlas`**：flxanimate 库自带 `loadAtlas(atlasDirectory):Void`（Adobe Animate 布局），Haxe 不允许改返回类型收窄，链式 `new FunkinSprite().loadAtlas(...)` 会断。改为类内 `loadNmvAtlas(path)`，脚本里的 `loadAtlas` 调用由 `InterpEx.fcall` 对 `FunkinSprite` 类型特判转发（本仓库 `CustomInterp` 已有 setFilters/playMusic 同类先例）。
- **样本实测优先**：对 127 个样本文件做了 preset 符号频次统计，高频项（FlxSprite 700 / Paths 430 / FlxTween 301 / FlxG 249 / FlxEase 240 / ClientPrefs 221 / game 215 / FlxColor 119 / FlxTimer 88 / Conductor 76 / FlxMath 73 / Character 58 / FlxText 50…）全部可注册；`WeekData`/`StageData` 不进一二档。
- **`FlxPoint` 是 abstract**（flixel 6）不能直接注册，改注册实现类 `flixel.math.FlxBasePoint`。
- **`ScriptFlxColor`**：样本只用 `FlxColor.BLACK/WHITE/RED` 常量与 fromString/fromRGB/interpolate/getRed 等静态方法，Int 封装全覆盖；NMV 的 `ScriptedFlxColor`、FE 的 `CustomFlxColor` 同思路。
- **shader `newShader`** 落在 `PresetStubs`：读 `Paths.shaderFragment(name)`，用 `ErrorHandledRuntimeShader` 构造（编译失败有兜底弹窗，符合项目铁律）；找不到文件显式 throw。

验证（均通过）：

1. `haxe release.hxml --no-output --macro "include('nmv')"` 类型检查 exit 0；
2. `haxe release.hxml --macro "include('nmv')"` 代码生成 exit 0，`obj/src/nmv/scripts/preset/*.cpp` 产物确认；
3. 宏关方向（删 hscript-iris-nmv / hscriptPos / HSCRIPT_ALLOWED）类型检查 exit 0，nmv 不泄漏。

**未完成的 runtime 验证**：`NmvPresetSmoke` 需要真跑 `FunkinScript.fromString`，但 preset 引用游戏全类型图，interp/eval 目标编译不动（`sys.thread.Deque`、NativeCFFI 等 eval 限制，且 `--macro include('my.pack')` 全量纳入），**推迟到 Phase 4 挂载后游戏内验证 + Phase 5 回归**。文件本身留作符号清单与将来入口。
