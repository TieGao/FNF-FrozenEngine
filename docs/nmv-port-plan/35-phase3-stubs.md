# NMV 脚本 API 移植计划 — 35 Phase 3：三档补桩与四档处理

## 原则

所有补桩**主动抛异常**，形如 `throw 'NMV API <x> not implemented'`。原因：NMV 脚本是从 Impostor 1.0.3b 样本用 hscript 写的，打错函数名、调错库时静默 no-op 最难排查；主动 throw 能把"没效果"变成"崩溃+调用栈"，回归时一眼定位。

## 补桩清单（约 15 个）

| 函数 | NMV 行为 | 建议处理 |
|---|---|---|
| shader 族：`newShader(name)` 等 | `Paths.fragment(name)` + `FunkinAssets` 查表 | **第一优先**，接 FE 自家 shader 目录约定（见 50 小节） |
| `FunkinRuntimeShader` | 运行时 shader 持有者 | FE 用运行时 shader 方案；类名不同，映射时注意 uniform setter 方法名 |
| `FunkinSprite` | 封装 Sprite 带 shader | 小桩，内部委托 FE 的 sprite 类 |
| `BackgroundDancer` / `Girls` | 特定舞台装饰角色 | 若 FE 无对应类，先 throw；回归后再看命中率决定搬不搬 |
| `MacroUtil.buildAbstract` ×4 | 编译期抽象构造 | hscript 里多半是运行时等价物，逐个对照实现 |
| `FallbackState` | 资源缺失兜底 State | 小桩 |
| `newOption`/`getOption`/`getModSetting` | 模组设置读写 | 接 FE 的 mod 设置存储（有现成机制的话）|
| `initScript` | 从脚本内再起脚本 | 委托 ScriptGroup |
| `getInstance` | 取单例 | 映射 FE 的单例容器 |

## 四档（modchart）：默认不做

- FE 一个都没有；样本 127 个文件里只有 `CreditsRollSubState.hx` 用到 `SubModifier`（3 处，4 行）。
- 处理：全族先 throw；Phase 5 回归跑完后**单独确认这一个文件是否影响玩法**，不影响就永久 throw，影响再评估。
- 若将来真要做，最小增量顺序：`Modifier`（基类）→ `SubModifier` → `NoteModifier` → `ScriptedModifier` → `ModManager` 注册。

## 完成判据

- 15 个桩全部落位（实现或 throw），编译通过；
- 每类至少一个 throw 桩能被测试脚本触发（证明接线正确，不是死代码）。

## 实施结果（2026-10-17）

全部落在 `source/nmv/scripts/preset/PresetStubs.hx`（配合 30 小节新增）：

**接上 FE 的（2 个）**

- `newShader(name)` → 读 `Paths.shaderFragment(name)`，`new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(name, source)`；文件缺失显式 throw。样本 8 处调用（lights / outline2 等）有路径可走。
- `FunkinSprite` → `nmv.objects.FunkinSprite`（ PsychFlxAnimate 基座 + `loadNmvAtlas` spritemap 加载，详见 30 小节"偏离原计划"段），样本 14 处引用的可编译可用面最大。

**统一 throw 桩（21 个，`Reflect.makeVarArgs`，任意参数个数）**

- modchart 族 11 个：`ModManager`/`SubModifier`/`NoteModifier`/`ScriptedModifier`/`EventTimeline`/`Modifier`/`StepCallbackEvent`/`CallbackEvent`/`ModEvent`/`EaseEvent`/`SetEvent`
- 同名异义/无对应 6 个：`WeekData`/`StageData`（FE 同名不同义）、`FunkinCamera`、`FunkinSound`、`BackgroundDancer`、`BackgroundGirls`
- 机制型 6 个：`initScript`（Phase 4）、`getInstance`、`newOption`、`getOption`（各带原因文案）

**决策说明**

- modchart 族选择"注册 throw 函数"而非"不注册"：hscript 的 Unknown variable 报错不带原因文案，throw 桩能直接告诉移植者缺什么；回归跑完再决定是否永久 throw。
- `getModSetting` 未列入 throw——FE 有 `psychlua.LuaUtils.getModSetting(saveTag, modName)` 现成实现，已在 `PresetFnf` 注册真函数。
- throw 桩的运行时触发验证随 `NmvPresetSmoke` 一起推迟到 Phase 4（原因见 30 小节"未完成的 runtime 验证"）。
