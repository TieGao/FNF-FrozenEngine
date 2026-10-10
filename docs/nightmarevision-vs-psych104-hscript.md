# Nightmare Vision vs Psych Engine 1.0.4 — HScript 系统差异

对比对象：

| | 路径 | 依赖 |
|---|---|---|
| PE 1.0.4 | `H:\FNF-PsychEngine-1.0.4` | `hscript-iris` **1.1.3**（haxelib，crowplexus 官方） |
| Nightmare Vision | `E:\NightmareVision-dev` | `hscript-iris` **git fork `pisayesiwsi/hscript-iris@dev`** + `hscript` 2.6.0 |

两边都用 `crowplexus.iris.Iris` + `crowplexus.hscript`，都开 `hscriptPos`。**底层库不是同一份代码**，这决定了上层能写什么语法。

---

## 0. 一句话结论

- **PE 1.0.4 的 HScript 是 Lua 的附属品**。核心入口是 Lua 的 `runHaxeCode`（在 Lua 里执行一段 Haxe 代码当"逃逸舱口"），独立 `.hx` 文件只是附带能力，且只在 `PlayState` / `LoadingState` 生效。
- **Nightmare Vision 的 HScript 是一等公民**。没有任何 Lua，脚本系统是 FunkinCrew 官方那套 `FunkinScript`，按状态/对象自动挂载，多脚本组 + 显式共享作用域，连状态本身都能用脚本定义。

---

## 1. 底层库差异（fork 实际改了什么）

拿本地两份 `crowplexus/` 源码做 `diff -ru`，共 623 行差异、32 个 hunk。**功能性的**只有这几条：

| 改动 | 影响 |
|---|---|
| `EFor(i, v, it, e)` 由 3 字段扩到 4 字段 | 支持 `for (key => value in map)` 键值迭代；PE 版只能 `for (v in it)` |
| `CString(s, interp)` 加插值标记 + `Parser.interpolateString` | 支持单引号字符串插值 `'hp: ${hp}'`；PE 版单引号是纯字面量 |
| `ECall` 里特判 `f == "bind"` | 支持 `obj.bind(_, false)` 占位符绑定；PE 版不支持 |
| `Interp.increment` 去掉 `if (l == null)` 包裹 | **修 bug**：1.1.3 只在变量未声明时才走 `++/--` 逻辑，对已声明的局部变量 `x++` 静默失效 |
| `makeKVIterator` + `EInvalidKVIterator` | 配套键值迭代 |
| `Iris.execute` 的 catch 在 `#if IRIS_DEBUG` 下附 `CallStack.toString` | 报错堆栈更全 |
| `Printer` 补全返回类型标注、`EFor` 适配 | 无行为变化 |

> PE 的 `Project.xml` 定义了 `IRIS_DEBUG`，NV 没有。所以 NV 侧即使 fork 支持堆栈，也不会打出来（NV 走自己的 `DebugTextPlugin`）。

---

## 2. 类层次与解释器定制

### PE 1.0.4

```
crowplexus.iris.Iris
└── psychlua.HScript                (filePath / modFolder / returnValue / parentLua)
    └── interp = CustomInterp extends crowplexus.hscript.Interp
```

`CustomInterp` 只做三件事：

1. `parentInstance`（默认 `FlxG.state`），`resolve()` 里查它的实例字段 —— **只读**，没重写 `assign`，脚本写不回去。
2. `fcall` 里对 `setFilters` 做硬编码特判（`handleSetFilters` / `clearFiltersOnObject` / `setFiltersOnObject`，满屏 `trace('[DEBUG] ...')`）—— 这是给 shader filter 打的补丁。
3. 没重写 `increment` / `assign` / `evalAssignOp` / `whileLoop`。

构造时 `new IrisConfig(scriptName, false, false)`（3 参数旧签名），手动 new 一个 `CustomInterp` 塞进 `this.interp`。

### Nightmare Vision

```
crowplexus.iris.Iris
└── extensions.hscript.IrisEx        (绕过 super，自建 ParserEx + InterpEx)
    └── funkin.scripts.FunkinScript
        └── interp = InterpEx extends crowplexus.hscript.Interp
```

`IrisEx`：

- `if (false == true) super(scriptCode, config);` —— **故意用不可能条件绕过父类构造**，然后手动装配 `parser = new ParserEx()` / `interp = new InterpEx(null, sharables)`。
- `parser.allowTypes = allowMetadata = allowJSON = true`。
- 用 `IrisConfig.AutoIrisConfig`（新签名，带第 4 个参数）+ `Iris.fixScriptName`。

`InterpEx` 是主要工作量所在：

| 覆写 | 目的 |
|---|---|
| `parent` + `parentFields`（setter 缓存实例字段名） | 宿主对象注入，**可读可写** |
| `sharedFields:Sharables` | 组内共享作用域 |
| `increment` | `x++` / `++x` 能写回 parent / sharedFields |
| `assign` | `x = v` 同上 |
| `evalAssignOp` | `x += v` 同上 |
| `expr` 里处理 `EMeta(':sharable')` | `public var` 落地成共享字段 |
| `makeIterator` 加 try/catch | 修 debug build 上 for 循环崩溃 |
| `fcall` | `Unknown function` 报错后提前 return，避免双重报错 |
| `whileLoop` / `doWhileLoop` / `exprReturn` | hscript 的 `Stop` 是 private enum，必须整套重实现才能自定义（注释写着 `// overriden because Stop is private. DIE HSCRIPT DIE`） |

`ParserEx`：

- 新增 **`public` 关键字**：`parseStructure("public")` 把 `public var x` / `public function f` 编译成 `@:sharable` 元数据。
- 重写整个 `_token()` 词法，加 `readStringEx(until, interpolate)` 支持单引号 `'...${expr}...'`。

---

## 3. 加载与生命周期

### PE：扁平数组 + 手动调用

- 容器：`PlayState.hscriptArray:Array<HScript>` —— 一维数组，**没有分组**。
- 去重：`Iris.instances.exists(path)`。
- 入口：`PlayState.initHScript(file)` → `new HScript(null, file)` → 立刻 `call('onCreate')`。
- 加载目录（全部在 `PlayState.create()` 里，与 Lua 并排）：

| 目录 | 说明 |
|---|---|
| `mods/<mod>/scripts/*.hx` | 通用脚本（`Mods.directoriesWithFile`） |
| `mods/<mod>/data/<songName>/*.hx` | 歌曲专属 |
| `stages/<stage>.hx` | 舞台 |
| `characters/<char>.hx` | 角色 |
| `custom_notetypes/<nt>.hx` / `custom_events/<ev>.hx` | 自定义音符/事件 |
| `mods/<mod>/data/LoadingScreen.hx` | 唯一在 `LoadingState` 生效的脚本 |

- **其它状态（Freeplay / MainMenu / 设置菜单…）没有任何脚本支持**。
- 扩展名只认 `.hx`（`findScript(scriptFile, '.hx')`）。

### NV：ScriptGroup + 自动挂载

- 容器：`ScriptGroup`，`MusicBeatState` / `MusicBeatSubstate` 各自持有一个 `scriptGroup`。
- PlayState 有 **3 个组**：`scripts`（主体）/ `eventScripts` / `noteTypeScripts`。
- 入口：`initStateScript()` 自动找 `scripts/states/<类名>.hx`（子状态是 `scripts/<prefix>/<类名>.hx`）→ `onLoad`，`create()` 时再 `onCreate`。
- 解析失败不抛异常：`FunkinScript.__garbage = true`，调用方 `FlxDestroyUtil.destroy` 掉。
- 扩展名：`.hx` / `.hxs` / `.hscript`（`FunkinScript.H_EXTS`）。

| 目录 | 载体 |
|---|---|
| `scripts/*.hx`、`songs/<sanitized song>/scripts/` | PlayState 主体 |
| `scripts/states/<StateName>`、`scripts/substates/...` | 每个状态的 `scriptGroup` |
| `scripts/plugins/` | `PluginsManager.loadedScripts`（静态常驻，跨状态，带 `onStateSwitch` 信号） |
| `scripts/modifiers/` | `ScriptedModifier`（modchart） |
| `scripts/transitions/` | `ScriptedTransition` |
| `data/characters/<name>` 或 `characters/<name>` | `Character` / `Stage.runScript` |
| `notetypes/<type>` / `events/<name>` | `noteTypeScripts` / `eventScripts` |

另外 NV 还有 `ScriptedState` / `ScriptedSubstate`（兼容别名 `HScriptState` / `HScriptSubstate`）——**可以纯用脚本定义一个状态**，PE 没有对应物。

---

## 4. 回调分发与返回值协议

| | PE 1.0.4 | Nightmare Vision |
|---|---|---|
| 分发 | `PlayState.callOnHScript(func, args, ignoreStops, exclusions, excludeValues)` 遍历数组 | `ScriptGroup.call(event, args, ignoreStops, exclusions)` 遍历成员 |
| 返回值常量 | **字符串**：`LuaUtils.Function_Stop = "##PSYCHLUA_FUNCTIONSTOP"` 等 5 个 | **Int**：`ScriptConstants.CONTINUE_FUNC = 0` / `STOP_FUNC = 1` / `HALT_FUNC = 2` |
| 中断语义 | `Function_StopHScript` 停 HScript 链、`StopAll` 全停、`StopLua` 停 Lua | `STOP_FUNC` 停；`HALT_FUNC` **立即中断本组后续脚本** |
| 与 Lua 关系 | `callOnScripts` = 先 `callOnLuas` 再 `callOnHScript`；**Lua 优先** | 无 Lua |
| 单脚本直调 | 无（只能全量遍历） | `PlayState.callScript(script, event, args)` |
| 事件名 | `onCreate` / `onUpdate` / `onStepHit` / `goodNoteHit` / `onCountdownTick` / `onSpawnNote` …（Psych 风格） | `onLoad` / `onCreate` / `onUpdate` / `onStepHit` / `onAddSpriteGroups` / `onRecalculateRating` …（Funkin 风格） |

---

## 5. 变量作用域

### PE：一个静态全局 map

```haxe
set('setVar', (name, value) -> { MusicBeatState.getVariables().set(name, value); ... });
set('getVar', (name) -> MusicBeatState.getVariables().get(name));
set('removeVar', ...);
```

`MusicBeatState.getVariables()` 是**静态的**，跨状态、跨脚本共享。任何脚本 `setVar('x')`，别的脚本直接 `getVar('x')` 就能拿到 —— 无隔离，同名直接覆盖。

### NV：显式共享 + 宿主字段

```haxe
// 仅当 FlxG.state is PlayState 时才注册
set('global', PlayState.instance.variables);
set('setVar', (name, val) -> PlayState.instance.variables.set(name, val));
set('getVar', (name) -> PlayState.instance.variables.get(name));
```

三条差异：

1. **`setVar` / `getVar` 只在 PlayState 分支注册**。非 PlayState 状态（含 `ScriptedState`）的脚本**没有这两个函数**。
2. 跨脚本共享要走 `Sharables`：只有 `public var` / `public function`（→ `@:sharable`）才进共享池，同组脚本互访；没标 `public` 的变量是脚本私有的。
3. `interp.parent` 直接映射宿主状态/对象的实例字段，**可读可写** —— `curStep` 这种直接改宿主，不经过变量表。

`Sharables` 的定位（源码注释）：*Inspired by Rulescripts `Context`*。

---

## 6. 预设 API 对照

### 两边都有

`Type` / `StringTools` / `FlxG` / `FlxSprite` / `FlxText` / `FlxCamera` / `FlxTimer` / `FlxTween` / `FlxEase` / `FlxRuntimeShader` / `FlxColor`(包装类) / `PlayState` / `Paths` / `Conductor` / `ClientPrefs` / `Character` / `Alphabet` / `Note`

### PE 独有

- 文件系统：`File` / `FileSystem`（`#if sys`）
- `PsychCamera`、`backend.BaseStage.Countdown`、`Achievements`、`ShaderFilter`、`ErrorHandledRuntimeShader`
- `CustomSubstate` / `customSubstate` / `customSubstateName`
- **`getModSetting(saveTag, ?modName)`** —— NV 无对应
- **`debugPrint(text, ?color)`** —— NV 走 Logger
- `addHaxeLibrary(name, ?pkg)`（已标 deprecated，但仍在；NV 用原生 `import`）
- **Lua 桥**：`createCallback` / `createGlobalCallback` / `parentLua`
- 键鼠手柄全家桶：`keyboardJustPressed` / `keyboardPressed` / `keyboardReleased` / `keyJustPressed` / `keyPressed` / `keyReleased` / `anyGamepad*` / `gamepad*` / `gamepadAnalogX/Y` / `controls`
- `buildTarget`、`this`、`game`、`inPlaystate`
- 返回值常量：`Function_Stop` / `Function_Continue` / `Function_StopLua` / `Function_StopHScript` / `Function_StopAll`

### NV 独有

- **抽象转换**：`FlxTextAlign` / `FlxAxes` / `FlxKey` / `BlendMode`（`MacroUtil.buildAbstract` 现造）；`keyToString` / `keyFromString`
- **modchart 全套**：`ModManager` / `Modifier` / `SubModifier` / `NoteModifier` / `ScriptedModifier` / `EventTimeline` / `ModEvent` / `EaseEvent` / `SetEvent` / `CallbackEvent` / `StepCallbackEvent`
- 对象：`Bar` / `StrumNote` / `NoteSplash` / `HealthIcon` / `BGSprite` / `AttachedSprite` / `AttachedAlphabet` / `BackgroundDancer` / `BackgroundGirls` / `CutsceneHandler` / `DialogueBox` / `StageData` / `FunkinSound` / `FunkinVideoSprite`
- Flixel 补充：`FlxMath` / `FlxSpriteUtil` / `FlxBackdrop` / `FlxTiledSprite` / `FlxPoint`(= `FlxBasePoint`) / `FlxTypedGroup` / `FlxSpriteGroup` / `FlxEmitter` / `FlxFlicker` / `FlxSound` / `FlxAnimate` / `FlxAnimateFrames` / `FlxSpriteElement`
- 数据结构：`StringMap` / `IntMap` / `ObjectMap` / `Dynamic`
- 工具：`CoolUtil` / `WindowUtil` / `MusicBeatState` / `Main` / `Lib` / `Assets` / `OpenFlAssets` / `Defines`
- 自定义：`FlxColor`(ScriptedFlxColor，多了 `getHSBColorWheel` / `gradient` / `interpolate` / `toRGBA`) / `Random`(ScriptedFlxRandom)
- 脚本自身：`FunkinScript` / `ScriptConstants` / `ScriptedState` / `ScriptedSubstate` / `GameOverSubstate` / `initScript(path)`
- **节奏量**：`curBpm` / `crotchet` / `stepCrotchet` / `curBeat` / `curStep` / `curSection` / `curDecBeat` / `curDecStep`（PE 的 HScript **没有**这些，只在 Lua 侧有）
- **歌曲上下文**：`bpm` / `scrollSpeed` / `songName` / `isStoryMode` / `difficulty` / `difficultyName` / `week` / `weekRaw` / `songLength` / `seenCutscene` / `healthGainMult` / `healthLossMult` / `instakillOnMiss` / `botPlay` / `practice` / `startedCountdown` / `mustHitSection`
- `version`（`Main.NMV_VERSION`）、`newShader(frag, vert)`、`getInstance`
- 返回值常量：`Function_Halt` / `Function_Stop` / `Function_Continue`（**Int**）

---

## 7. 错误处理

| | PE 1.0.4 | NV |
|---|---|---|
| 覆盖点 | `Main.hx` 里 `Iris.warn` / `Iris.error` / `Iris.fatal` | `FunkinScript.init()` 里 `Iris.warn` / `Iris.error` / `Iris.print`（**没有 fatal**） |
| 输出格式 | `(funcName) - file:line: msg`，`showLine` / `isLua` 可控 | `[file:line] - msg`，路径含 `content/<当前mod>/` 会被裁掉 |
| 落地 | `PlayState.instance.addTextToDebug(...)`（YELLOW / RED / 0xFFBB0000） | `DebugTextPlugin.addText(...)` + `Logger.getHexColourFromSeverity(...)` |
| pos 类型 | `haxe.PosInfos` + `HScriptInfos` typedef（`funcName` / `showLine` / `isLua`） | 直接用 `Iris` 的 pos |
| 解析失败 | 抛 `IrisError`，外层 `catch` 后 `Iris.error(Printer.errorToString(e, false), pos)` | 内部 try/catch → `__garbage = true`，静默销毁 |
| `IRIS_DEBUG` | 定义（打完整堆栈） | 未定义 |

---

## 8. 从 PE 脚本迁到 NV 的注意事项

1. `Function_Stop`（字符串）→ `ScriptConstants.STOP_FUNC`（Int `1`）；`Function_Continue` → `CONTINUE_FUNC`（`0`）。字符串比较会**静默失效**。
2. `setVar` / `getVar` 语义变了：从"全局静态 map"变成"PlayState 局部"。跨脚本共享必须用 `public var` / `public function`。
3. 非 PlayState 状态里 `setVar` / `getVar` **不存在**，调用即报 unknown variable。
4. `addHaxeLibrary` 没有 → 改用 `import`。
5. `getModSetting` 没有 → 走 `ClientPrefs` 的 mod 设置接口。
6. `debugPrint` 没有 → `Logger.log`。
7. `CustomSubstate` 没有 → 用 `ScriptedSubstate`。
8. 脚本目录结构完全不同（`scripts/` vs `data/scripts` 那一套），`stages/` / `custom_notetypes/` / `custom_events/` 换成 `notetypes/` / `events/`。
9. PE 那套 `keyboardJustPressed` / `keyPressed` 系列在 NV 里换成 `Controls` 实例 + `keyToString` / `keyFromString`。
10. 反过来，NV 脚本能用的 PE 不一定有：`public` 关键字、`'${}'` 插值、`for (k => v in map)`、`obj.bind(_, x)`、`curStep` / `curBeat` 系列。

---

## 9. 一句话对照

| 维度 | PE 1.0.4 | Nightmare Vision |
|---|---|---|
| 定位 | Lua 的 Haxe 逃逸舱口 | 唯一的脚本语言 |
| 底层 | hscript-iris 1.1.3（官方） | hscript-iris fork@dev |
| 解释器 | `CustomInterp`（parentInstance 只读 + setFilters 特判） | `InterpEx`（parent 读写 + Sharables + 循环/赋值全重写） |
| 语法扩展 | 无 | `public`、`'${}'`、`for k=>v`、`bind(_, x)` |
| 容器 | `Array<HScript>` 扁平 | `ScriptGroup` 分组 × 多 |
| 挂载 | 仅 PlayState / LoadingState | 每个 State/Substate/对象自动 |
| 作用域 | 全局静态 map | Sharables（显式 public）+ 宿主字段 |
| 返回值 | 字符串常量 | Int 常量 |
| Lua | 有，且优先 | 无 |
