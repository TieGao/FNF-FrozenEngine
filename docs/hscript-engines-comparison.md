# FNF 引擎 HScript 系统比对手册

**四引擎**：Psych Engine 1.0.4（PE） / Nightmare Vision（NV，含下游 Impostor Legacy 分支） / Codename Engine（CNE） / NovaFlare Engine（NF）。

这份文档的用途：把"一个 `.hx` 脚本在四个引擎里分别能干什么、靠什么机制实现、能不能挂到任意 State 上"讲清楚，作为移植 / 迁移时的通用对照。**不是只比 NV ↔ PE 两条血统**。

|                  | 路径                                                           | 依赖                                                                                                                                                                                               |
| ---------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| PE 1.0.4         | `D:\FNF-PsychEngine-1.0.4`（`Project.xml` 里 `if="HSCRIPT_ALLOWED"`） | `hscript-iris` **1.1.3**（haxelib，crowplexus 官方）；`<define name="IRIS_DEBUG"/>`                                                                                                                    |
| Nightmare Vision | `D:\NightmareVision`                                         | `hscript-iris` **git fork `pisayesiwsi/hscript-iris@dev`**（`hmm.json` 里锁 `ref: dev`，仓库自带 `.haxelib/hscript-iris/git`，HEAD = `62d828b` "small error check for .bind"，2024-12-28）+ `hscript` 2.6.0 |
| Codename Engine  | `D:\CodenameEngine`                                          | 自带 `hscript/Config.hx` 扩展 + `hscript-improved`（`Project.xml` `haxelib name="hscript-improved"`）；`funkin/backend/scripting/*` |
| NovaFlare        | `F:\FNF-NovaFlare-Engine`（`gitVersion.txt` = `1.2.1-Coldfix-Extra-2`；`D:\FNF-NovaFlare-Engine` 是早期同源代码副本） | `hscript-iris-improved`（`Project.xml` `haxelib name="hscript-iris-improved" if="HSCRIPT_ALLOWED"`，库在 `.haxelib/hscript-iris-improved/git`）+ **CNE 那份** `hscript-improved`（`if="CODENAME_ENGINE_COMPAT"`）+ `luahscript`（`use hscript to make lua script`）；`#if CODENAME_ENGINE_COMPAT` 时启用 CNE 兼容层 |

四家都用 `crowplexus` 系的 `Interp`（CNE 走 `hscript-improved` 分叉；NV/NF 走 `hscript-iris` 分叉），都开 `hscriptPos`（NF 只在 `CODENAME_ENGINE_COMPAT` / `HSCRIPT_ALLOWED` 下开）。**底层库不是同一份代码**，这决定了上层能写什么语法。

> 校验用的本地副本：PE 侧 `C:\HaxeToolkit\haxe\lib\hscript-iris\1,1,3`；NV 侧用仓库里 vendored 的 `D:\NightmareVision\.haxelib\hscript-iris\git`；NF 侧用 `D:\FNF-NovaFlare-Engine\.haxelib\hscript-iris-improved\git`；CNE 的 `hscript-improved` 未装在本机 haxelib，CNE 侧结论以仓库内源码 + `hscript/Config.hx` 为准。

---

## 0. 一句话结论

- **PE 1.0.4 的 HScript 是 Lua 的附属品**。核心入口是 Lua 的 `runHaxeCode`（在 Lua 里执行一段 Haxe 代码当"逃逸舱口"），独立 `.hx` 文件只是附带能力，**且只在 `PlayState` / `LoadingState` 生效，挂不到别的 State 上**（`hscriptArray` 是 `PlayState` 的字段，Freeplay / MainMenu / 设置菜单完全没有脚本入口）。
- **Nightmare Vision 的 HScript 是一等公民**。没有 Lua，脚本系统是 FunkinCrew 官方那套 `FunkinScript`，`MusicBeatState.initStateScript()` 按类名自动挂 `scripts/states/<类名>.hx`，**每个 State/Substate/对象都能挂**，多脚本组 + 显式共享作用域，连状态本身都能用脚本定义（`ScriptedState`）。
- **Codename Engine 的 HScript 同样是一等公民**，但定位更接近"CNE 的 Lua 替代品"（CNE 明说 `Lua is not supported in this engine. Use HScript instead.`）。挂载走 `MusicBeatState.stateScripts:ScriptPack`，脚本路径 `data/states/<类名>`，另外有 `ModState`/`ModSubState` 用"状态名 + scriptName"机制定义脚本化状态。
- **NovaFlare 的 HScript 是 PE 血统的增强版**：容器仍是 `HScriptPack` + `PlayState.hscriptGrp`（PE 那套），但**额外补了 `HScriptState` / `HScriptSubstate`**（`new HScriptState("脚本名")`，扫 `stageScripts/states/*.hx`）和 `HScriptGroup`（给 options 菜单用），所以它比 PE 多了"把脚本挂到独立 State 下"的能力 —— 但注意这**不是**自动按类名挂载，而是显式 `new HScriptState(...)`。

---

## 1. 底层库差异（fork 实际改了什么）

> 本节只比 **PE ↔ NV** 两家 `hscript-iris`（因为 NV 是 vendored fork，能逐文件 diff）。CNE / NF 用的是另外两个分叉（`hscript-improved` / `hscript-iris-improved`），不在这 7 文件 diff 里。

拿本地两份 `crowplexus/` 源码做逐文件 `diff`，**只有 7 个文件不同**：`hscript/{Bytes,Expr,Interp,Parser,Printer,Tools}.hx` + `iris/Iris.hx`。没有新增/删除文件。**功能性的**只有这几条：

| 改动                                                                                      | 文件                                                  | 影响                                                         |
| --------------------------------------------------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------- |
| `EFor(v, it, e)` 由 3 字段扩到 `EFor(i, v, it, e)`                                           | `Expr.hx`（+ `Parser`/`Tools`/`Bytes`/`Printer` 跟着改） | 支持 `for (key => value in map)` 键值迭代；PE 版只能 `for (v in it)` |
| `CString(s)` 加 `?interp:Bool` + `Parser.interpolateString`                              | `Expr.hx` / `Parser.hx`                             | 支持单引号字符串插值 `'hp: ${hp}'`；PE 版单引号是纯字面量                      |
| `ECall` 里特判 `f == "bind"`                                                               | `Interp.hx`                                         | 支持 `obj.bind(_, false)` 占位符绑定；PE 版不支持                      |
| 新增 `EInvalidKVIterator` / `EEmptyExpression`                                            | `Expr.hx`                                           | 配套键值迭代 + 空表达式                                              |
| `Interp.increment` 去掉 `if (l == null)` 包裹                                               | `Interp.hx`                                         | **修 bug**：1.1.3 只在变量未声明时才走 `++/--` 逻辑，对已声明的局部变量 `x++` 静默失效 |
| `Iris.execute` 的 catch 在 `#if IRIS_DEBUG` 下附 `CallStack.toString(exceptionStack(true))` | `iris/Iris.hx`                                      | 报错堆栈更全                                                     |
| `Printer` 补齐返回类型标注、`Tools.iter/map/mk` 补 `:Void`/`:Expr` 标注                             | `Printer.hx` / `Tools.hx`                           | 无行为变化，纯类型标注                                                |
| `ECall` 的 `EField` 分支重构成先取 `obj` 再判空（`s == true` 时直接 `return null`）                     | `Interp.hx`                                         | 配合 `?.` 安全访问，避免空对象报 `EInvalidAccess`                       |

> **注意**：上面这些就是 fork 的**全部**改动。NV 侧另有几个"看着像 fork 带来的能力"（`whileLoop`/`doWhileLoop` 的自定义、`EIdent` 的 `resolve` 重写、`forLoop` 的 keyvalue 分支）——**这些不在 fork 里**，全在 NV 自己的 `extensions.hscript.InterpEx` 里重写，见第 2 节。不要把它们记到"fork 差异"账上。

> PE 的 `Project.xml` 定义了 `IRIS_DEBUG`，NV 没有。所以 NV 侧即使 fork 支持堆栈，也不会打出来（NV 走自己的 `DebugTextPlugin`）；反过来 PE 的 `CustomInterp` 也不用堆栈。

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

`InterpEx` 是主要工作量所在（`extensions/hscript/InterpEx.hx`，374 行）：

| 覆写                                                                                  | 目的                                                                                                                 |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `parent` + `parentFields`（setter 用静态 `cachedFields` 缓存 `Type.getInstanceFields` 结果） | 宿主对象注入，**可读可写**；resolve/setTo 里同时认 `id` 和 `set_id`/`get_id`                                                        |
| `sharedFields:Sharables`                                                            | 组内共享作用域                                                                                                            |
| `setTo(id, v, canDefine)`（私有辅助，非覆写）                                                 | 赋值总入口：先 locals → variables → parentFields → sharedFields，都没有且 `canDefine` 才 `setVar`                               |
| `increment`                                                                         | `x++` / `++x` 能写回 parent / sharedFields                                                                            |
| `assign`                                                                            | `x = v`（`= EIdent` 时 `canDefine = true`，允许首次定义）                                                                    |
| `evalAssignOp`                                                                      | `x += v` / `x -= v` …                                                                                              |
| `resolve`                                                                           | 查找顺序 locals → variables → imports → parentFields → sharedFields，全没有才 `EUnknownVariable`                            |
| `expr` 里处理 `EMeta(':sharable')`                                                     | `public var` / `public function` 落地成共享字段（只在 `depth == 0`，即顶层）                                                      |
| `expr` 里额外拦 `EFor`                                                                  | 转调自己的 `forLoop`（因为 fork 的 `EFor` 是 4 字段）                                                                           |
| `forLoop` / `makeIterator` / `makeKeyValueIterator`                                 | 完整重实现，`loopRun` 用 **try/catch + `Type.enumConstructor` 字符串比对** 捕获 `SBreak`/`SContinue`（`Stop` enum 是 private，只能反射） |
| `fcall`                                                                             | 先走 `usings`，再 `get(o,f)`；`null` 时 `Iris.error('Unknown function: $f')` 后提前 return，避免双重报错                           |
| `#if hl get` 特判 `Enum`                                                              | HL 目标上把枚举值当可访问字段                                                                                                   |
| `destroy`                                                                           | 只把 `parent = null`（配合 `IrisEx.destroy` 走 `FlxDestroyUtil`）                                                         |

`ParserEx`：

- 新增 **`public` 关键字**：`parseStructure("public")` 把 `public var x` / `public function f` 编译成 `@:sharable` 元数据（`mk(EMeta(':sharable', [], e))`）。
- 重写整个 `_token()` 词法（注释 `oou gh.gh,gg,`），加 `readStringEx(until, interpolate)` 支持单引号 `'...${expr}...'`，并覆写 `interpolateString`。

`Sharables`：`Map<String, Dynamic>` 的薄包装（`exists`/`get`/`set`/`remove`/`clear`，`fields` 公开），源码注释 *Inspired by Rulescripts `Context`*。`ScriptGroup` 持有一个 `scriptShareables` 并强制派发给所有成员，所以**同组脚本的 `public` 变量天然互通**。

---

## 3. 加载与生命周期

### PE：扁平数组 + 手动调用

- 容器：`PlayState.hscriptArray:Array<HScript>` —— 一维数组，**没有分组**。
- 去重：`Iris.instances.exists(path)`。
- 入口：`PlayState.initHScript(file)` → `new HScript(null, file)` → 立刻 `call('onCreate')`。
- 加载目录（全部在 `PlayState.create()` 里，与 Lua 并排）：

| 目录                                                   | 说明                               |
| ---------------------------------------------------- | -------------------------------- |
| `mods/<mod>/scripts/*.hx`                            | 通用脚本（`Mods.directoriesWithFile`） |
| `mods/<mod>/data/<songName>/*.hx`                    | 歌曲专属                             |
| `stages/<stage>.hx`                                  | 舞台                               |
| `characters/<char>.hx`                               | 角色                               |
| `custom_notetypes/<nt>.hx` / `custom_events/<ev>.hx` | 自定义音符/事件                         |
| `mods/<mod>/data/LoadingScreen.hx`                   | 唯一在 `LoadingState` 生效的脚本         |

- **其它状态（Freeplay / MainMenu / 设置菜单…）没有任何脚本支持**。
- 扩展名只认 `.hx`（`findScript(scriptFile, '.hx')`）。

### NV：ScriptGroup + 自动挂载

- 容器：`ScriptGroup`（`funkin/scripts/ScriptGroup.hx`）：`members:Array<FunkinScript>` + `scriptShareables:Sharables` + `parent`。`set_parent` 会 `copyGroup()` 把 `parent` 与 `shareables` 刷给所有成员。
- `MusicBeatState` / `MusicBeatSubstate` 各自持有一个 `scriptGroup = new ScriptGroup()`；PlayState 另外有 **3 个组**：`scripts`（主体，注意它**不是**父类的 `scriptGroup`）/ `eventScripts` / `noteTypeScripts`。
- 入口：`MusicBeatState.initStateScript(?scriptName, callOnLoad = true)` 自动找 `scripts/states/<类名>.hx`（子状态是 `scripts/<scriptPrefix>/<类名>.hx`，`scriptPrefix` 默认 `'substates'`，`ScriptedTransition` 改成 `'transitions'`）→ 建脚本 → `scriptGroup.parent = this` → `onLoad`。`ScriptedState` / `ScriptedSubstate` 用 `initStateScript(scriptName, false)` + 自己补 `onLoad` / `onCreate`。
- PlayState 的载入入口是 `initFunkinScript(filePath, ?name)`（public）：`FunkinScript.fromFile` → `addScript` → `execute()` → 检查 `parsingFailed()` → 有 `onLoad` 就调。
- 解析失败不抛异常：`FunkinScript.parsingException` 非 null（`parsingFailed()` 为 true），调用方 `FlxDestroyUtil.destroy` 掉并按需 `removeScript`。
- 扩展名：`.hx` / `.hxs` / `.hscript`（`FunkinScript.H_EXTS`，靠 `getPath` 逐个试后缀）。

| 目录                                                                                          | 载体                                                                                                                                      |
| ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/*.hx`、`songs/<sanitized song>/scripts/`                                            | PlayState 主体（`initAllScriptsInDirectory('scripts')`）                                                                                    |
| `scripts/states/<StateName>`、`scripts/substates/<SubstateName>`、`scripts/transitions/<key>` | 每个状态的 `scriptGroup`                                                                                                                     |
| `scripts/plugins/`                                                                          | `ModPlugin.instance.scripts`（**静态常驻、跨状态**，靠 `FlxG.signals.preStateSwitch` / `postStateSwitch` 转发 `onStateSwitch` / `onStateSwitchPost`） |
| `scripts/modifiers/`                                                                        | `ScriptedModifier`（`ModManager.registerScriptedModifiers()`）                                                                            |
| `data/stages/<stage>/script`（或 `stages/<stage>`）                                            | `Stage.runScript(group)`，脚本拿到 `add` / `stage` / 各 stage object                                                                          |
| `data/characters/<name>` 或 `characters/<name>`                                              | `PlayState.startCharacterScript()`，会 `script.set('parent', char)`                                                                       |
| `data/notetypes/<type>` 或 `notetypes/<type>`                                                | `noteTypeScripts`                                                                                                                       |
| `data/events/<name>` 或 `events/<name>`                                                      | `eventScripts`                                                                                                                          |

另外 NV 还有 `ScriptedState` / `ScriptedSubstate`（兼容别名 `HScriptState` / `HScriptSubstate`）——**可以纯用脚本定义一个状态**，PE 没有对应物。`ScriptedTransition` 同理可脚本定义一个转场。

启动顺序（`Init.hx`）：`FunkinScript.init()` → `HotReloadPlugin.init()` → `ModPlugin.init()` → `DebugTextPlugin.init()` → `FullScreenPlugin.init()` → `ModPlugin.instance.populate()`（扫 `scripts/plugins/`）。

---

## 3.5 CNE 与 NF 的加载与生命周期

### Codename Engine

- **类层次**：`funkin.backend.scripting.Script`（抽象基类，`FlxBasic`）→ `HScript`（`interp = new Interp()`）/ `DummyScript`（语言不支持时的空壳）/ `ScriptPack`（`scripts:Array<Script>` 组）。
- **容器**：`ScriptPack`（不是 Array）。`MusicBeatState.stateScripts:ScriptPack`；`GlobalScript`（`#if GLOBAL_SCRIPT`）持有一个常驻 `ScriptPack`，挂在 `Conductor.onBeatHit` / `FlxG.signals.*` 上跨状态。
- **入口**：`Script.create(path)`（按扩展名分派：`.hx`/`.hscript`/`.hsc`/`.hxs` → `HScript`；`.pack` → 拆包；`.lua` → `Logs.error("Lua is not supported in this engine. Use HScript instead.")` + `DummyScript`）。
- **State 挂载**：`MusicBeatState.loadScript()` 在 `create()` 里跑，找 `data/states/<scriptName>/LIB_<mod名>`（`<scriptName>` 默认类名）。这就是"每个 State 自动挂脚本"的实现。
- **脚本化状态**：`ModState` / `ModSubState` 继承 `MusicBeatState`/`MusicBeatSubstate`，构造参数 `_stateName` 经 static `lastName` 传给 `super(true, lastName)`，从而按名字加载 `data/states/<名字>`。
- **`setParent`**：`HScript.setParent` → `interp.scriptObject = parent`（`hscript-improved` 字段）；`ScriptPack.setParent` 会把 parent 转发给所有成员。**注意：CNE 的 parent 不是"裸标识符回退"，真正的宿主暴露靠 `getDefaultVariables()` 里的 `"state" => FlxG.state`。**
- **扩展名**：`.hx` / `.hscript` / `.hsc` / `.hxs` / `.pack`。
- **预设**：`Script.buildDefaultVariables()`（一次构建、每脚本浅拷贝，含 `state` / `window` 两个动态项），`getDefaultPreprocessors()` 把编译期 define 灌进 `parser.preprocessorValues`。

### NovaFlare

> 校验基准：**`F:\FNF-NovaFlare-Engine`**，`gitVersion.txt` = **`1.2.1-Coldfix-Extra-2`**（`D:\FNF-NovaFlare-Engine` 是同一份代码的早期副本；两盘的 `hscript-iris-improved` 库**逐字节相同**，机制结论一致。下文以 F 盘为准）。

- **类层次**：`scripts.hscript.HScript`（独立 `.hx` 文件用，612 行）+ `HScriptPack`（组）+ `HScriptBase`（**Lua 逃逸舱口**，`runHaxeCode` 用；`#else` 分支在无 HSCRIPT_ALLOWED 时退化为空壳）+ `GlobalHandler`（常驻全局脚本，见下）。
- **容器**：`PlayState.hscriptGrp:HScriptPack`（PE 那套 `hscriptArray` 的升级版）。
- **State 挂载**：**没有 NV/CNE 式"按类名自动挂"**，而是显式 `new HScriptState("名字")` / `new HScriptSubstate("名字")`（各 110 / 110 行左右）：
  ```haxe
  class HScriptState extends MusicBeatState {
      public static final sign:String = "states";
      public function new(name:String, ?data:Null<Dynamic>) {
          stateScripts = new HScriptPack();
          for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), "stageScripts/states/"))
              for (fn in FileSystem.readDirectory(folder))
                  if (Path.extension(fn) == "hx") {
                      var sc:HScript = new HScript(folder + fn, this);   // parent = this
                      sc.set("MusicBeatState", MusicBeatState);
                      sc.set("MusicBeatSubstate", MusicBeatSubstate);
                      stateScripts.add(sc);
                  }
          stateScripts.execute();
          super();
      }
      // onCreate / onUpdate / onDraw / onStepHit / onBeatHit / onSectionHit … 转发给 stateScripts
  }
  ```
- **常驻全局脚本 `GlobalHandler`**（F 盘 1.2.1 新增，D 盘早期副本没有）：`InitState` 启动时 `GlobalHandler.init()`，扫 `stageScripts/globals/*.hx` 建成常驻 `HScriptPack`（`new HScript(path + fn)`，**注意不传 parent**），然后注册 14 个 `FlxG.signals` 回调转发给它（`onStateSwitch` / `onStateSwitchPost` / `onStateCreate` / `onGameResized` / `onGameReset(Post)` / `onGameStart(Post)` / `onUpdate(Post)` / `onDraw(Post)` / `onFocusGained` / `onFocusLost`）。**这是 NF 对标 CNE `GlobalScript` 的机制**（CNE 那份挂在 `Conductor.onBeatHit` + `FlxG.signals` 上）。
- **`MusicBeatState` 侧**：NF 的 `MusicBeatState`（`general/backend/MusicBeatState.hx`，继承 `FlxUIState`）**不持有 scriptGroup**（不像 NV/CNE）；脚本挂载完全靠 `HScriptState` 这个壳，或 `PlayState.initHScript`。有 `public var variables:Map<String,Dynamic>` + static `MusicBeatState.getVariables()` 给 `setVar`/`getVar` 用（PE 同款，取当前 state 的 map）。
- **options 菜单脚本**：`options.objects.HScriptGroup`（`OptionCata` 子类）专门给 mod 加设置页用，`new HScript(path + file + ".hx", this)` → `sc.set("Option", ...)` + 枚举 `OptionType` 各构造。
- **扩展名**：`.hx`（`FileSystem.readDirectory` + `Path.extension(fn) == "hx"`）。
- **预设**：`HScript.preset(parent)`（312 行起）——`interp.parentInstance = parent`；注册 `FlxG` / `FlxSprite` / `FlxText` / `PlayState` / `Paths` / `Conductor` / `ClientPrefs` / `Character` / `Alphabet` / `Note` / `CustomSubstate` / `ErrorHandledRuntimeShader` / `ScriptedState` / `ScriptedSubstate` / `HScriptState` / `HScriptSubstate` / `ScriptedSprite` / `ScriptedGroup` / `ScriptedSpriteGroup` / `ScriptedBaseStage` 等。`if (parent is MusicBeatState)` 分支才注册 `setVar`/`getVar`/`removeVar`；`if (parent is PlayState)` 才注册 `debugPrint` / `keyboardJustPressed` / `keyboardPressed` / `keyboardReleased` / Lua 桥 `createCallback` / `createGlobalCallback`（**和 PE 的条件注册思路一致**）。
- **依赖（`Project.xml`）**：`hscript-iris-improved`（`if="HSCRIPT_ALLOWED"`，NF 主体用）+ `hscript-improved`（`if="CODENAME_ENGINE_COMPAT"`，**就是 CNE 那份库**，v2.4.0，`hscript/Interp.hx` 带 `scriptObject` / `publicVariables` / `staticVariables`）+ `luahscript`（`if="LUA_ALLOWED"`，`use hscript to make lua script`，让 `.lua` 表达式能用 HScript 解析）。**`CODENAME_ENGINE_COMPAT`（非 mobile 默认开）打开时，NF 同时挂两套 `Interp`** —— 主体 `HScript` 走 `hscript-iris-improved`，CNE 兼容路径走 `hscript-improved`，脚本行为会向 CNE 靠。
- **崩溃诊断（F 盘 1.2.1 新增）**：`HScriptBase` 在 `#if (LUA_ALLOWED && cpp && (windows || android))` 下有一套 **native execution snapshot** 机制 —— 把动态 `runHaxeCode` 的源码按 `(code, where, context, func)` 去重后注册进 `NativeCrashHandler.registerHaxeRuntimeSnapshot(snapshot)`，缓存上限 32 条，崩溃时能还原是哪段脚本、在哪个 Lua 函数里跑崩的（不注册就只剩 RVA / minidump）。**与挂载机制无关，但排查脚本崩溃时有用。**

---

## 4. 回调分发与返回值协议

|          | PE 1.0.4                                                                                              | Nightmare Vision                                                                                                                                                                          |
| -------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 分发       | `PlayState.callOnHScript(func, args, ignoreStops, exclusions, excludeValues)` 遍历数组                    | `ScriptGroup.call(event, args, ignoreStops = false, ?exclusions)` 遍历成员                                                                                                                    |
| 返回值常量    | **字符串**：`LuaUtils.Function_Stop = "##PSYCHLUA_FUNCTIONSTOP"` 等 5 个                                    | **Int**：`ScriptConstants.CONTINUE_FUNC = 0` / `STOP_FUNC = 1` / `HALT_FUNC = 2`                                                                                                           |
| 中断语义     | `Function_StopHScript` 停 HScript 链、`StopAll` 全停、`StopLua` 停 Lua                                       | `STOP_FUNC` **只把返回值透传给调用方**（由调用方决定是否 return，如 `if (scripts.call('onPause') != STOP_FUNC) openPauseMenu()`）；`HALT_FUNC` 在 `ScriptGroup.call` 里**立即中断本组后续脚本**（`ignoreStops` 时改成只污染返回值、不真中断） |
| 与 Lua 关系 | `callOnScripts` = 先 `callOnLuas` 再 `callOnHScript`；**Lua 优先**                                         | 无 Lua                                                                                                                                                                                     |
| 单脚本直调    | 无（只能全量遍历）                                                                                             | `PlayState.callScript(script, event, args)` / `callEventScript(name, ...)` / `callNoteTypeScript(noteType, ...)`                                                                          |
| 事件名      | `onCreate` / `onUpdate` / `onStepHit` / `goodNoteHit` / `onCountdownTick` / `onSpawnNote` …（Psych 风格） | `onLoad` / `onCreate` / `onUpdate` / `onStepHit` / `onAddSpriteGroups` / `onRecalculateRating` …（Funkin 风格）                                                                               |

`ScriptGroup.call` 语义细节：默认返回 `CONTINUE_FUNC`；成员返回 `HALT_FUNC` 时若 `!ignoreStops` 直接 `return returnVal`（提前结束遍历），否则吞掉不污染；非 `CONTINUE_FUNC` 的返回值会留到最后的 `returnVal` 里带出去。

脚本回调全集（从 NV 源码 grep 出来的，共 60+ 个）：

- 通用状态：`onLoad` / `onCreate` / `onCreatePost` / `onUpdate` / `onUpdatePost` / `onStepHit` / `onBeatHit` / `onSectionHit` / `onDestroy` / `onCloseSubState` / `onStateSwitch` / `onStateSwitchPost`
- PlayState 开局：`onAddSpriteGroups` / `preNoteGeneration` / `preReceptorGeneration` / `postReceptorGeneration` / `postModifierRegister` / `onStartIntro` / `onStartCountdown` / `onCountdownStarted` / `onCountdownTick` / `onSkipIntro` / `onSongStart`
- PlayState 谱面：`onSpawnNote` / `onSpawnNotePost` / `onSpawnNoteSplash` / `onSpawnSustainSplash` / `onEventPush` / `onEvent` / `eventEarlyTrigger` / `onMoveCamera` / `onUpdateScore` / `onRecalculateRating` / `onPopUpScore` / `onPopUpScorePost`
- 手感 / 失误：`noteMiss` / `noteMissPress` / `onKeyPress` / `onKeyRelease` / `onInputPress` / `onInputRelease` / `onGhostTap` / `onGhostAnim`
- GameOver：`onGameOverStart` / `onGameOver` / `onGameOverCancel` / `onGameOverConfirm` / `onGameOverPost` / `deathAnimStart`
- 暂停 / 结束：`onPause` / `onResume` / `onSubstateOpen` / `onSubstateClose` / `onEndSong` / `onRestart`
- 菜单：`onSelect` / `onChangeSelection` / `onChangeDifficulty` / `onChangeWeek` / `onSelectWeek` / `onRegenMenu` / `onOptions` / `onEnter` / `onExit`


对比 PE 的关键差异：**NV 没有 `onDestroy` 之外的"链式 post"分区逻辑**（PE 的 `early` / `post` HScript 分工），但 NV 把 `Post` 后缀回调显式拆开（`onUpdatePost` / `onSpawnNotePost` / `onPopUpScorePost` / `onGameOverPost`）。

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

## 5.5 把脚本"挂到 State 下"——四引擎机制对照

这是最常见的一个问题：**"为什么 NV / CNE 能让脚本裸写 `boyfriend`、`curBeat`，而 PE 不行？"** 答案分两层：① 宿主对象怎么暴露给脚本；② 脚本怎么被挂到具体 State 上。

### 5.5.1 宿主作用域：三种暴露方式

所有"裸写宿主成员"能力，物理上都是 `Interp.resolve(id)` 里多了一条**回退分支**（`variables` 表查不到时，去宿主对象上按名取）。三家做法不同：

| 引擎     | 机制                                                                | 脚本写法                    | 可写回 | 优先级                                          |
| -------- | ----------------------------------------------------------------- | ------------------------- | --- | -------------------------------------------- |
| **CNE**  | 宿主当**普通变量**：`getDefaultVariables()` 里 `"state" => FlxG.state` | `state.boyfriend.x += 1`（要前缀） | 可   | 变量表即宿主，无回退层                                |
| **NV**   | `InterpEx.parent` + `parentFields`（`set_parent` 缓存 `Type.getInstanceFields`） | `boyfriend.x += 1`（裸写）      | 可   | `variables` > `imports` > **`parentFields`** > `sharedFields` |
| **NF**   | `Interp.parentInstance` + `_parentFields`（`set_parentInstance` 缓存 `Reflect.fields`/`Type.getInstanceFields`） | `boyfriend.x += 1`（裸写）      | 可   | `directorFields` > `staticVariables` > `variables` > **`parentInstance`** |
| **PE**   | `CustomInterp.parentInstance = FlxG.state`，**只重写 `resolve`、没重写 `assign`** | 裸读可以，**裸写不生效**          | **不可** | `variables` > `parentInstance`（只读）             |

关键细节：

- **CNE 的 `state` 是变量名，不是作用域**。脚本要写 `state.xxx`。CNE 还有个 `setParent(this)` 把宿主塞进 `interp.scriptObject`（`hscript-improved` 的字段），但那是脚本内部 `__script__` 相关，不是让裸标识符解析到宿主。真正让 CNE 脚本"贴近"宿主的是它在 `getDefaultVariables()` 里注册的一大批类（`ModState` / `ModSubState` / `PlayState` / `FunkinSprite` …），属于**全局注入**，不是"挂到当前 State"。
- **NV / NF 的 `parent` / `parentInstance` 才是"挂到宿主"**。NF 的 `set_parentInstance` 比 NV 多判了 `Type.ValueType.TObject`（普通匿名结构走 `Reflect.fields`）和 `Class` 分支（走 `Type.getClassFields`），比 NV 的 `Type.getInstanceFields(Type.getClass(v))` 更稳 —— NV 对"传进来的是类而非实例"会拿到实例字段而不是类静态字段。**NF 的 `resolve` 里还特判了 `id == "this"` 直接返回宿主**，NV 没有这一条（NV 靠显式 `scriptGroup.set('this', this)`）。
- **NF 的赋值优先级里 `parentInstance` 排在 `variables` 之后**（`else if (parentInstance != null)`），所以显式 `set()` 进去的变量会遮住宿主同名字段；NV 的 `setTo` 同理（locals → variables → parentFields）。**两家都是"变量表赢过宿主"**。
- **PE 只读**：`CustomInterp` 没重写 `assign` / `setTo` / `increment`，所以脚本里 `bf.x = 0` 会**静默写进 interp 自己的 `variables` 表**，碰不到真正的 `bf`。这是 PE 脚本最常见的"改了没反应"根因。

### 5.5.2 State 挂载：四种入口

| 引擎   | 容器                                        | 入口                                                                     | 自动按类名挂？          | 能挂到任意 State？                    |
| ---- | ----------------------------------------- | ---------------------------------------------------------------------- | ---------------- | ------------------------------ |
| **PE** | `PlayState.hscriptArray:Array<HScript>`    | `PlayState.initHScript(file)`（`PlayState.create()` 内手动枚举目录）           | 否                | **否**，只有 PlayState / LoadingState |
| **NV** | `ScriptGroup`（`scriptGroup` + PlayState 的 3 个组） | `MusicBeatState.initStateScript(?scriptName, callOnLoad)`              | **是**（`scripts/states/<类名>.hx`） | **是**（每个 State/Substate）        |
| **CNE**| `MusicBeatState.stateScripts:ScriptPack`   | `MusicBeatState.loadScript()`（在 `create()` 里自动调）                       | **是**（`data/states/<类名>/LIB_<mod>`） | **是**，另有 `ModState(name)` 显式定义状态 |
| **NF** | `HScriptPack`（`PlayState.hscriptGrp`；另有 `GlobalHandler` 常驻全局组） | PlayState 内 `initHScript(file)`；额外 `new HScriptState(name)` 走 `stageScripts/states/`；`GlobalHandler` 走 `stageScripts/globals/` | 否（PlayState 手工枚举） | **部分**：靠 `HScriptState`/`HScriptSubstate` 显式创建 |

### 5.5.3 NV 的 `initStateScript` 全链路（最典型）

`D:\NightmareVision\source\funkin\backend\MusicBeatState.hx`：

```haxe
public var scriptGroup:ScriptGroup = new ScriptGroup();

public function initStateScript(?scriptName:String, callOnLoad:Bool = true):Bool {
    if (scriptName == null)
        scriptName = Type.getClassName(Type.getClass(this)).split('.').pop(); // 类名兜底
    final scriptFile = FunkinScript.getPath('scripts/states/$scriptName');
    if (scriptGroup.exists(scriptFile)) return true;
    this.scriptName = scriptName;
    if (FunkinAssets.exists(scriptFile)) {
        var newScript = FunkinScript.fromFile(scriptFile, scriptName);
        if (newScript.parsingFailed()) { ... return false; }
        scriptGroup.parent = this;                 // ★ 关键：把宿主刷给全组
        scriptGroup.addScript(newScript);
        scripted = true;
    }
    if (callOnLoad) scriptGroup.call('onLoad', []);
    return scripted;
}
```

`scriptGroup.parent = this` 触发 `set_parent` → 对组内每个脚本 `copyGroup()` → `interp.parent = parent`（即 `InterpEx.set_parent` 缓存 `parentFields`）。**所以"挂载"= 建组、塞脚本、把宿主写进 `interp.parent`。** 之后 State 的 `update` / `stepHit` / `beatHit` 里 `scriptGroup.call('onUpdate'/'onStepHit'/...)` 分发（见第 3 节）。

CNE 的对应物是 `MusicBeatState.loadScript()`（不是 NV 的 `initStateScript` 名字，但结构一样）：建 `ScriptPack` → `setParent(this)` → 从 `data/states/<scriptName>/LIB_<mod>` 逐个 `Script.create` 加载 → `script.load()`；`create()` 里自动调，然后 `call('create')`。CNE 还额外支持 `ModState` / `ModSubState`：构造时传 `_stateName`，内部 `super(true, lastName)` 把脚本名传进 `MusicBeatState`，从而让**同一个 State 类**能跑不同脚本（用于纯脚本定义的状态）。

### 5.5.4 迁移含义

- **给 NV 写的裸写脚本（`bf.x`、`curBeat`）搬去 PE 会"能读不能写"**，而且不报错。搬去 CNE 则裸写直接 `EUnknownVariable`（CNE 没 `parent` 回退），必须先加 `state.` 前缀。
- **PE 想"把脚本挂到任意 State"没有现成开关**：要么照 NF 加个 `HScriptState` 壳，要么照 NV/CNE 给 `MusicBeatState` 注入 `scriptGroup` + `initStateScript`。**这是引擎级改造，不是脚本级能绕过的。**
- NF 的 `HScriptState` 是最省事的参考实现（一个类约 110 行，见第 3.5 节）。想要"跨状态常驻脚本"，NF 另有 `GlobalHandler`（`stageScripts/globals/*.hx` + `FlxG.signals`），对标 CNE 的 `GlobalScript`。

---

## 6. 预设 API 对照（PE ↔ NV）

> CNE / NF 的预设见 3.5 节（CNE 走 `Script.buildDefaultVariables()`，NF 走 `HScript.preset()`）。这一节只列 PE / NV 两条基础血统。

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
- 对象：`Bar` / `StrumNote` / `NoteSplash` / `HealthIcon` / `BGSprite` / `BackgroundDancer` / `BackgroundGirls` / `CutsceneHandler` / `DialogueBox` / `StageData` / `FunkinSound` / `FunkinVideoSprite`
- Flixel 补充：`FlxMath` / `FlxSpriteUtil` / `FlxBackdrop` / `FlxTiledSprite` / `FlxPoint`(= `FlxBasePoint`) / `FlxTypedGroup` / `FlxSpriteGroup` / `FlxEmitter` / `FlxFlicker` / `FlxSound` / `FlxAnimate` / `FlxAnimateFrames` / `FlxSpriteElement`
- 数据结构：`StringMap` / `IntMap` / `ObjectMap` / `Dynamic`
- 工具：`CoolUtil` / `WindowUtil` / `MusicBeatState` / `Main` / `Assets` / `OpenFlAssets` / `Defines`
- 自定义：`FlxColor`(ScriptedFlxColor，多了 `getHSBColorWheel` / `gradient` / `interpolate` / `toRGBA`) / `Random`(ScriptedFlxRandom)
- 脚本自身：`FunkinScript` / `ScriptConstants` / `ScriptedState` / `ScriptedSubstate` / `GameOverSubstate` / `initScript(path)` / `newShader` / `newOption` / `getOption`
- **节奏量**：`curBpm` / `crotchet` / `stepCrotchet`（PE 的 HScript **没有**这些，只在 Lua 侧有）；注意 `curBeat` / `curStep` / `curSection` 在 NV 里**不是 preset 变量**，而是靠 `interp.parent = FlxG.state` 从宿主状态实例字段直接读出来的
- **歌曲上下文**：`bpm` / `scrollSpeed` / `songName` / `isStoryMode` / `difficulty` / `difficultyName` / `week` / `weekRaw` / `songLength` / `seenCutscene` / `healthGainMult` / `healthLossMult` / `instakillOnMiss` / `botPlay` / `practice` / `startedCountdown` / `mustHitSection`
- `version`（`Main.NMV_VERSION`）、`asset_redirect`、`getInstance`
- 返回值常量：`Function_Halt` / `Function_Stop` / `Function_Continue`（**Int**）

> 上面这份是**按 `D:\NightmareVision` 源码（`funkin/scripts/FunkinScript.hx` 的 `preset()`）逐条核对过的**。注意 NV 的 preset 里**没有** `Lib` / `AttachedSprite` / `AttachedAlphabet` —— 那几个是 Impostor Legacy 分支的（见第二部分），别混。

### PE 独有里值得标注的两条

- **`curStep` / `curBeat` 系列**：PE 的 HScript 有 `curBeat` 等（从 Lua 变量表里带过来的），NV 靠宿主实例字段，语义更直接。
- **`getModSetting`**：NV 完全没有对应；NV 的 mod 设置走 `newOption` / `getOption`（`ModOptions`），是另一个体系。

---

## 7. 错误处理

|              | PE 1.0.4                                                                      | NV                                                                                                   |
| ------------ | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| 覆盖点          | `Main.hx` 里 `Iris.warn` / `Iris.error` / `Iris.fatal`                         | `FunkinScript.init()` 里 `Iris.warn` / `Iris.error` / `Iris.print`（**没有 fatal**）                      |
| 输出格式         | `(funcName) - file:line: msg`，`showLine` / `isLua` 可控                         | `[file:line] - msg`（`formatFileLoc` 裁掉 `Paths.mods(...)` / `Paths.trail` 前缀）                         |
| 落地           | `PlayState.instance.addTextToDebug(...)`（YELLOW / RED / 0xFFBB0000）           | `DebugTextPlugin.instance.addText(...)` + `Logger.getHexColourFromSeverity(...)`，再统一 `Iris.logLevel` |
| pos 类型       | `haxe.PosInfos` + `HScriptInfos` typedef（`funcName` / `showLine` / `isLua`）   | 直接用 `Iris` 的 pos                                                                                     |
| 解析失败         | 抛 `IrisError`，外层 `catch` 后 `Iris.error(Printer.errorToString(e, false), pos)` | `FunkinScript.execute()` 内部 try/catch → 存进 `parsingException`，`parsingFailed()` 供调用方判断后静默销毁          |
| 运行期 `trace`  | 走 Iris 默认                                                                     | `Iris.print`（`#if hl` 时还额外 set 了 HL 版 `trace`，`#if hscriptPos` 时用 Iris 默认的带 pos 版本）                  |
| `IRIS_DEBUG` | 定义（打完整堆栈）                                                                     | 未定义                                                                                                  |

> PE 那边 `hs` 脚本的错误直接进 `PlayState.addTextToDebug`；NV 统一进 `DebugTextPlugin`（屏幕角落文本 + Logger），且**只有调用方主动检查 `parsingFailed()`** 才知道脚本废了，不检查就是静默无脚本。`initFunkinScript` / `initStateScript` / `ModPlugin.populate` 都做了检查并 `destroy`，所以正常路径不会漏。

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

### 8.5 跨到 CNE / NF 的额外注意

- **CNE**：宿主是 `state` 变量（要写 `state.xxx`），裸写宿主成员会 `EUnknownVariable`；脚本放 `data/states/<类名>/`；Lua 完全不可用（`.lua` 被 `Script.create` 拒收）；`ScriptPack` 内变量用 `set()` 共享、没有 `public` 语义（那是 `hscript-improved` 的）。
- **NF**：宿主走 `parentInstance`（裸写可用、可读可写，和 NV 一样）；但**没有自动按类名挂载**，要用 `new HScriptState("名字")`，脚本放 `stageScripts/states/`；`setVar`/`getVar` 只在 `parent is MusicBeatState` 时注册，`debugPrint`/`keyboard*` 只在 `parent is PlayState` 时注册（**条件注册和 PE 同款**）；`CODENAME_ENGINE_COMPAT` 打开时行为向 CNE 靠。
- **共同陷阱**：四家的 `resolve` 优先级都是"变量表 > 宿主字段"，所以显式 `set()` 进去的同名变量会**遮住**宿主成员 —— 改了脚本行为异常时先查有没有同名 `set()`。PE 的宿主**只读**，脚本里 `bf.x = 0` 不报错但无效，是跨引擎移植时最阴的坑。

---

## 9. 一句话对照

| 维度   | PE 1.0.4                                          | Nightmare Vision                             | Codename Engine                                       | NovaFlare                                            |
| ---- | ------------------------------------------------- | -------------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------- |
| 定位   | Lua 的 Haxe 逃逸舱口                                   | 唯一的脚本语言                                      | Lua 的替代品（无 Lua）                                       | PE 血统 + CNE 部分特性                                     |
| 底层   | hscript-iris 1.1.3（官方）                            | hscript-iris fork@dev                        | `hscript-improved`                                    | `hscript-iris-improved`（`CODENAME_ENGINE_COMPAT` 时叠 `hscript-improved`） |
| 解释器  | `CustomInterp`（parentInstance **只读** + setFilters 特判） | `InterpEx`（parent 读写 + Sharables + 循环/赋值全重写） | `Interp`（`hscript-improved`，宿主作 `state` 变量）            | `Interp`（`parentInstance` 读写 + `directorFields`）       |
| 宿主暴露 | `parentInstance`（只读）                              | `interp.parent`（读写，裸标识符）                     | `variables["state"]`（要写 `state.` 前缀）                    | `interp.parentInstance`（读写，裸标识符）                        |
| 语法扩展 | 无                                                 | `public`、`'${}'`、`for k=>v`、`bind(_, x)`     | （`hscript-improved` 的 public/插值等）                       | 同 NV（`hscript-iris-improved`）+ `fixSyntax` 正则补 `new`   |
| 容器   | `Array<HScript>` 扁平                               | `ScriptGroup` 分组 × 多                          | `ScriptPack` 组 / `GlobalScript` 常驻                     | `HScriptPack` 组                                        |
| 挂载   | 仅 PlayState / LoadingState                        | 每个 State/Substate/对象自动（`initStateScript`）     | 每个 State 自动（`loadScript`，`data/states/`）               | **显式** `new HScriptState(...)`（无自动按类名）                |
| 作用域  | 全局静态 map                                          | Sharables（显式 public）+ 宿主字段                    | `ScriptPack` 内共享 + `state` 变量                          | `MusicBeatState.getVariables()` 静态 map + 宿主字段          |
| 返回值  | 字符串常量                                             | Int 常量                                       | 无显式协议                                                 | 无显式协议（同 PE 字符串系）                                       |
| Lua  | 有，且优先                                             | 无                                            | **无**（`Script.create` 对 `.lua` 直接报错）                    | 有（`luahscript`）                                        |

---

# 第二部分：NightmareVision 系的"下游分叉" —— Impostor Legacy

第一部分比的是 PE ↔ NV ↔ CNE ↔ NF 四条独立血统（另加 5.5 节的挂载机制横向对照）。但 NV 的脚本系统本身还派生出了**下游 mod 分支**：VS Impostor LEGACY（`D:\impostorLegacyPublic`，`Project.xml` 里 `version="0.2.7"`，`company="MotorFrog"`）整套照搬了 NV 的 `extensions.hscript.*` + `funkin.scripts.*`，又按自己的需要改了。考察 NV 系时不能只看 NV 本体，得知道 mod 分支长什么样。

## 10. Impostor Legacy 的依赖与"代际"关系

|                  | Nightmare Vision                                              | Impostor Legacy                                                                                              |
| ---------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `Project.xml`    | `<haxelib name="hscript-iris" version="git"/>`                | `<haxelib name="hscript-iris"/>`（**不带 version**，交给安装脚本）                                                      |
| 安装脚本             | `hmm.json` 锁 `pisayesiwsi/hscript-iris@dev` + `hscript` 2.6.0 | `projFiles/setup/setup-Windows.bat` 里 `haxelib install hscript-iris 1.1.3` + `haxelib install hscript 2.6.0` |
| 底层实际拿到的库         | fork@dev（vendored，HEAD `62d828b`）                             | **官方 1.1.3**（如果按脚本装；`Project.xml` 没锁 git，谁用过谁的 haxelib 就会拿到谁那份）                                              |
| `hscriptPos`     | 有                                                             | 有                                                                                                            |
| `IRIS_DEBUG`     | 无                                                             | 无                                                                                                            |
| `MODS_ALLOWED`   | `if="desktop"`                                                | `if="desktop"`                                                                                               |
| `VIDEOS_ALLOWED` | `if="cpp"`                                                    | `if="cpp"`                                                                                                   |

> **关键陷阱**：Impostor Legacy 的 `Project.xml` 写的是**不带版本**的 `<haxelib name="hscript-iris"/>`。这意味着它最终编到哪份 `hscript-iris`，**取决于本机 haxelib 里装的是哪份** —— 装了官方 1.1.3 就是 1.1.3，装了 NV 的 fork（`haxelib dev hscript-iris ...`）就会编成 fork。而 fork 改了 `EFor`/`CString` 的枚举字段数，**一旦底层库和源码假设对不上就是编译期硬错**（枚举模式匹配不穷尽）。所以 Impostor Legacy 的源码是**按 1.1.3 写的**，它的 setup 脚本也明确装 1.1.3。

代际关系（从注释能直接看出来）：**Impostor Legacy 的 `FunkinScript` 是更早的一版，NV 是从它演化/回流的**。证据：NV 的 `FunkinScript.init()` 里留着 `// took this from imposter legacy thanks ashley`，import 了 Impostor 的 `formatPosInfos` 思路。

## 11. 逐文件对账：哪些是共享、哪些是各自演进

拿 `D:\NightmareVision\source` 和 `D:\impostorLegacyPublic\source` 的同名文件 diff：

| 文件                                     | 差异量          | 结论                                     |
| -------------------------------------- | ------------ | -------------------------------------- |
| `extensions/hscript/ParserEx.hx`       | **0 行**      | 逐字节相同                                  |
| `extensions/hscript/Sharables.hx`      | **0 行**      | 逐字节相同                                  |
| `funkin/scripting/ScriptedState.hx`    | **0 行**      | 逐字节相同                                  |
| `funkin/scripting/ScriptedSubstate.hx` | **0 行**      | 逐字节相同                                  |
| `extensions/hscript/IrisEx.hx`         | 21 行         | 小改（见下）                                 |
| `funkin/scripts/ScriptGroup.hx`        | 57 行         | 中断协议不同（见下）                             |
| `extensions/hscript/InterpEx.hx`       | 308 行        | **两边反向演化**（见下）                         |
| `funkin/scripts/FunkinScript.hx`       | 214 行        | 预设 API 差别最大                            |
| `funkin/scripting/ScriptConstants.hx`  | 34 行         | Int 常量 ↔ 私有 enum                       |
| `funkin/scripting/PluginsManager.hx`   | 仅 Impostor 有 | NV 换成了 `ModPlugin`（`FlxTypedGroup` 插件） |

**`ParserEx` / `Sharables` / `ScriptedState` / `ScriptedSubstate` 完全一致** —— 也就是说 `public` 关键字、`'${}'` 插值、`Sharables` 共享作用域、纯脚本定义状态这几项**是 NV 系共享能力，Impostor Legacy 全都有**，写 NV 系脚本的人迁到 Impostor 不用改这部分。

## 12. 解释器分叉：`InterpEx` 的两条路线

这是本次考察最反直觉的发现 —— **NV 的 `InterpEx` 反而比 Impostor Legacy 的更"现代"**，两者是反向演化的。

| 能力                    | Impostor Legacy                                                                                   | Nightmare Vision                                                                                                                                                           |
| --------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Stop` 枚举             | 自己在 `InterpEx` 顶部 `private enum Stop { SBreak; SContinue; SReturn; }`，然后靠 `catch (err:Stop)` 精确捕获 | **不自己定义**，改用 `Type.typeof(err) == TEnum` + `Type.enumConstructor(err)` **按字符串名**比对 `'SContinue'` / `'SBreak'`（注释：`// just cuase someone wouldnt make the enum PUBLIC DIE`） |
| 循环重写                  | `exprReturn` / `doWhileLoop` / `whileLoop` 三个都重写（因为 `Stop` 是自己的 private enum，必须整套接）               | **一个都不重写**；只重写 `forLoop` + `makeIterator` + `makeKeyValueIterator`（fork 的 `EFor` 是 4 字段，必须自己处理 keyvalue 分支）                                                                |
| `makeIterator`        | 覆写，`if (v.iterator != null) try v = v.iterator() catch (e:Dynamic) {}`（修 debug 崩溃）                | 覆写，改成先判 `v is Array` 再取值，逻辑更仔细                                                                                                                                             |
| 赋值逻辑                  | `increment` / `assign` / `evalAssignOp` 各自**内联**一份 `setTo` 逻辑                                     | 抽出**独立 `setTo(id, v, canDefine)` 方法**，三个覆写都走它                                                                                                                              |
| `parentFields` 缓存     | 每次 `set_parent` 都重新 `Type.getInstanceFields`                                                      | 加静态 `cachedFields:Map<String, Array<String>>` 按类缓存                                                                                                                         |
| `#if hl` 的 `get` 枚举特判 | 无                                                                                                 | 有                                                                                                                                                                          |
| `destroy()`           | 无（只靠 `IrisEx.destroy`）                                                                            | 有独立 `destroy()`（`parent = null`）                                                                                                                                           |


> 结论：**Impostor Legacy 的 `InterpEx` 更接近"原始 NV 系"写法**（照 hscript 源码抄一套 `Stop`），**NV 本体后来把这套改成了反射式**，顺手加了字段缓存、抽了 `setTo`、补了 `hl` 分支。所以"NV 系 = 一批引擎共享同一套 InterpEx"不成立 —— 至少这两个快照的 `InterpEx` 已经分叉 308 行。

**两边都一致的**（属 NV 系共同特征，不是分支差异）：`parent` + `parentFields` 可读可写、`sharedFields:Sharables`、`EMeta(':sharable')` 处理、`fcall` 的 `Unknown function` 提前 return、`resolve` 的查找顺序（locals → variables → imports → parentFields → sharedFields）。

## 13. 返回值协议分叉：Int 常量 ↔ 私有 enum

这是**运行期真正会咬人**的差异。同样是"脚本返回值控制链"，两边类型完全不同：

### Nightmare Vision（`ScriptConstants.hx`）

```haxe
public static final STOP_FUNC:Int = 1;
public static final CONTINUE_FUNC:Int = 0;   // ScriptGroup 默认返回
public static final HALT_FUNC:Int = 2;       // 立即中断本组后续脚本
```

`ScriptGroup.call` 靠 `ret is Int` + `ret == HALT_FUNC` 判断。

### Impostor Legacy（`ScriptConstants.hx`）

```haxe
private enum ScriptDispatch { Cancel; Halt; Stop; Continue; }   // 私有！外部不能 match

public static final STOP_FUNC:ScriptDispatch = Stop;
public static final CONTINUE_FUNC:ScriptDispatch = Continue;
public static final HALT_FUNC:ScriptDispatch = Halt;
public static final CANCEL_FUNC:ScriptDispatch = Cancel;        // NV 没有的第 4 个

public static inline function stopping(v:Dynamic):Bool return (v == Stop || v == Cancel);
public static inline function halting(v:Dynamic):Bool  return (v == Halt || v == Cancel);
```

**四条差异**：

1. **类型**：NV 是 `Int`，Impostor 是私有枚举 `ScriptDispatch`。枚举是 private，脚本层拿到的就是一个不透明值，只能原样 `return ScriptConstants.STOP_FUNC`，不能 `return 1`。
2. **第 4 个常量**：Impostor 多了 `CANCEL_FUNC` = "既停正常行为、又停传播"（`cancel > halt + stop` 的合成）。NV 只有 3 个。
3. **判断方式**：NV 是 `ret == ScriptConstants.HALT_FUNC`（整数比较）；Impostor 提供 `stopping(v)` / `halting(v)` 两个 helper —— 注释 `// this is annoying .` 说明它自己也知道这套枚举比 Int 麻烦。
4. **脚本里读到的名字**：NV `preset()` 注册 `Function_Halt` / `Function_Stop` / `Function_Continue`；Impostor 注册 `Function_Cancel` / `Function_Halt` / `Function_Stop` / `Function_Continue`（**多了 Cancel**）。

> 迁移影响：给 NV 写的脚本里 `if (result == 1)` 这种**数字比较在 Impostor 上永远 false**（拿到的不是 Int）；反之 `result == Function_Stop` 这种常量比较两边都能用（因为常量名一致），这是唯一安全写法。反过来 Impostor 脚本里的 `Function_Cancel` 拿到 NV 上是 **unknown variable**。

## 14. 脚本 API 预设的分叉（`FunkinScript.preset()`）

预设 API 是两边差别最大的一块。Impostor Legacy 的 `preset()` 里有、而 NV **没有**的：

| 类别   | Impostor 独有                                                                       | 说明                                                                                                                 |
| ---- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 基础库  | **`Sys`** / **`Date`** / **`Lib`**（`openfl.Lib`）                                  | NV 全没有；NV 刻意不开放文件系统                                                                                                |
| 预处理  | `for (k => v in funkin.data.Defines.defines) parser.preprocesorValues.set(k, v);` | 让脚本能用 `#if` 读引擎 define                                                                                             |
| 路径   | `PathsTestMode`                                                                   | 配合 `getPath(path, mode)`                                                                                           |
| 数据   | `Lang` / `GameFlags`                                                              | 本地化 / 存档标记                                                                                                         |
| 对象   | `AttachedSprite` / `AttachedAlphabet` / `FlxParticle`                             | NV 里 `AttachedSprite` / `AttachedAlphabet` **不存在**，`FlxTypedGroup` 是精简版 `flixel.group.FlxGroup` 而非 `FlxTypedGroup` |
| 相机   | `FlxCamera` = **`flixel.FlxCamera`**（原版）                                          | NV 是 `funkin.backend.FunkinCamera` 子类                                                                              |
| 状态   | `state`（= `FlxG.state`，与 `game` 并存）                                               | NV 只有 `game`                                                                                                       |
| 节奏量  | 只有 `curBpm`                                                                       | NV 有 `curBpm` / `crotchet` / `stepCrotchet`                                                                        |
| 构造签名 | `newShader(?frag, ?vert)` **返回 `new FunkinRuntimeShader(...)`**                   | NV 是 `FunkinRuntimeShader.fromPath` 静态引用                                                                           |
| 选项   | ——                                                                                | NV 有 `newOption` / `getOption`（`ModOptions`）；Impostor **没有 mod 选项体系**                                              |

而 NV 有、Impostor **没有**的：`crotchet` / `stepCrotchet` / `asset_redirect` / `songLength` / `instakillOnMiss` / `startedCountdown` / `BackgroundDancer` / `BackgroundGirls` / `DialogueBox` / `FunkinSprite`（在 flixel 区）/ **`newOption` / `getOption`** / 整个 modchart 块（`ModManager` / `Modifier` / `SubModifier` / `NoteModifier` / `ScriptedModifier` / `EventTimeline` / `ModEvent` / `EaseEvent` / `SetEvent` / `CallbackEvent` / `StepCallbackEvent`）。

> **modchart 是 NV 独有的整块**：Impostor Legacy 的 `preset()` 里**完全没有** `ModManager` 那一坨 —— 它不用 NV 的 modchart 系统。给 NV 写的用 `ModManager` 的脚本搬去 Impostor 会直接 unknown variable。

两边都有的（NV 系共享 API）：`StringTools` / `Type` / `script` / `Dynamic` / `modFolder` / `StringMap` / `IntMap` / `ObjectMap` / `Main` / `Assets` / `OpenFlAssets` / `FlxG` / `FlxSprite` / `FlxMath` / `FlxTimer` / `FlxTween` / `FlxEase` / `FlxSound` / `FlxText` / `FlxRuntimeShader` / `FlxFlicker` / `FlxSpriteUtil` / `FlxBackdrop` / `FlxTiledSprite` / `FlxPoint` / `FlxEmitter` / `FlxCameraFollowStyle` / `FlxTextBorderStyle` / `FlxBarFillDirection` / `FlxAnimate*` / `Controls` / 四个 `MacroUtil.buildAbstract`（`FlxTextAlign` / `FlxAxes` / `FlxKey` / `BlendMode`）/ `keyToString` / `keyFromString` / `Paths` / `MusicBeatState` / `Conductor` / `ClientPrefs` / `CoolUtil` / `WindowUtil` / `StageData` / `PlayState` / `FunkinSound` / `FlxColor`(脚本化) / `Random`(脚本化) / `FunkinScript` / `ScriptConstants` / `ScriptedState` / `ScriptedSubstate` / `GameOverSubstate` / `Note` / `Bar` / `HealthIcon` / `Character` / `NoteSplash` / `BGSprite` / `StrumNote` / `Alphabet` / `CutsceneHandler` / 歌曲上下文那一坨（`bpm` / `scrollSpeed` / `songName` / `isStoryMode` / `difficulty` / `difficultyName` / `week` / `weekRaw` / `seenCutscene` / `healthGainMult` / `healthLossMult` / `botPlay` / `practice` / `mustHitSection`）/ `global` / `getInstance` / `setVar` / `getVar` / `initScript` / `inGameOver` / `game` / `inPlaystate`。

## 15. 加载路径与生命周期分叉

|                               | Nightmare Vision                                                                      | Impostor Legacy                                                                                  |
| ----------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 状态脚本                          | `scripts/states/<类名>.hx`、`scripts/substates/...`                                      | 同（`MusicBeatState.initStateScript` 逐字节近似）                                                        |
| 插件脚本                          | `ModPlugin`（`FlxTypedGroup<FlxBasic>` 插件，`instance.scripts`），`Init.hx` 里 `populate()` | `PluginsManager`（纯静态 `loadedScripts`），`populate()` 扫 `scripts/plugins/`（用 `PathsTestMode.LOOSE`） |
| 插件跨状态                         | `FlxG.signals` 在 `ModPlugin` 构造里挂                                                     | `PluginsManager.prepareSignals()` 显式调用挂                                                          |
| 插件销毁                          | 随插件组 `destroy`                                                                        | `clear()` 手动清 `loadedScripts` + `scriptShareables`                                               |
| PlayState 组名                  | `scripts` / `eventScripts` / `noteTypeScripts`                                        | `scripts` / `eventScripts` / `noteTypeScripts`（同结构，`initFunkinScript` 同签名）                       |
| **解析失败标记**                    | `parsingException` + `parsingFailed()`                                                | **`__garbage:Bool`**（`@:noCompletion`），调用方判 `script.__garbage`                                   |
| 失败后生命周期                       | `execute()` 覆写里 try/catch 存异常                                                         | `tryExecute()` 私有 + `__garbage = true`                                                           |
| `fromString`/`fromFile` 第 3 参 | `autoExecute:Bool = true`                                                             | **`?additionalVars:Map<String, Any>`** —— 不是 bool，而是一批要预设进脚本的额外变量                                |

> **`fromFile` 签名不同的坑**：NV 是 `fromFile(file, name, autoExecute=true, ?shareables, ?modFolder)`；Impostor 是 `fromFile(file, name, ?additionalVars, ?shareables, ?modFolder)`。**第 3 位从 Bool 变成了 Map**。把 NV 的 `fromFile(path, name, false)` 直接搬去 Impostor，会把 `false` 当 `additionalVars` 传进去 —— 虽然 `false != null` 会走 `for (key => obj in false)` 直接崩，但至少是编译期/早期运行期就能发现的问题，不像返回值常量那么阴。

Impostor 额外注册的 `Lib` / `Sys` / `Date` 意味着**它的脚本能做文件 IO**（`sys` 目标下），NV 脚本刻意做不到。这是安全边界差异，不是笔误。

## 16. 四个引擎 + Impostor 分支的定位总结

|                 | Psych 1.0.4                      | Nightmare Vision                              | Impostor Legacy                                 | Codename Engine                          | NovaFlare                                  |
| --------------- | -------------------------------- | --------------------------------------------- | ----------------------------------------------- | ---------------------------------------- | ------------------------------------------ |
| 脚本定位            | Lua 的逃逸舱口                        | 唯一脚本语言                                        | 唯一脚本语言                                          | Lua 替代品（无 Lua）                            | PE 血统 + CNE 部分特性                            |
| 底层库             | hscript-iris 1.1.3               | fork@dev（vendored）                            | `Project.xml` 不锁版本，setup 装 1.1.3                | `hscript-improved`                       | `hscript-iris-improved`                    |
| `InterpEx` 循环方案 | 无（`CustomInterp` 不重写）            | 反射式捕获 `Stop`（`Type.enumConstructor`）          | 自带 `private enum Stop` 精确捕获                     | 无（`hscript-improved` 自带）                  | 无（`directorFields` 机制）                      |
| `InterpEx` 覆写规模 | 极小                               | 大（含 `forLoop` / `setTo` / 字段缓存 / `hl` 分支）     | 中（含 `whileLoop` / `doWhileLoop` / `exprReturn`） | ——                                       | ——                                         |
| 宿主读写            | 只读                               | 可读可写                                          | 可读可写                                            | 通过 `state` 变量（读写）                         | 可读可写                                       |
| 返回值协议           | 字符串 `"##PSYCHLUA_FUNCTIONSTOP"`  | **Int**（0/1/2）                                | **私有 enum**（+ `CANCEL_FUNC` 共 4 个）              | 无                                        | 无（沿用 PE 字符串系）                              |
| 语法扩展            | 无                                | `public` / `'${}'` / `for k=>v` / `bind(_,x)` | 同 NV（`ParserEx` 逐字节相同）                          | `hscript-improved` 的能力                  | 同 NV + `fixSyntax`                          |
| 容器              | `Array<HScript>`                 | `ScriptGroup` × 多                             | `ScriptGroup` × 多                               | `ScriptPack`                             | `HScriptPack`                              |
| 插件机制            | `HScriptList`（无插件概念）             | `ModPlugin`（Flx 插件）                           | `PluginsManager`（静态类）                           | `GlobalScript`（`FlxG.signals` + Conductor） | `GlobalHandler`（`FlxG.signals`，`stageScripts/globals/`） |
| 失败标记            | 抛异常 + `.error`                   | `parsingException`                            | `__garbage`                                     | `DummyScript`（静默空壳）                       | `Iris.error` + `active = false`              |
| modchart        | Lua modchart                     | 内置整套 + 脚本化 modifier                           | **无**                                           | 无（靠 stageScripts）                        | 无                                          |
| 文件 IO 脚本 API    | `File` / `FileSystem`（`#if sys`） | 无                                             | `Sys` / `Lib` / `Date`                          | `Sys`（`#if sys`）                         | `File` / `FileSystem`（`#if sys`）            |
| 挂载范围            | 仅 PlayState / LoadingState       | 每个 State/Substate/对象                          | 每个 State/Substate/对象                            | 每个 State（自动）+ `ModState` 显式定义            | 仅显式 `new HScriptState(...)`                 |

**给引擎开发者的一句话**：想要"脚本挂到任意 State 下"，**NV / CNE 是现成的参考**（`ScriptGroup`/`ScriptPack` + `initStateScript`/`loadScript` + `interp.parent`），**NF 提供了最省事的"显式壳"实现**（`HScriptState`，一个类约 110 行，不用改 `MusicBeatState`），**PE 完全没有这条路**（`hscriptArray` 绑死 PlayState）。跨状态常驻脚本：CNE `GlobalScript` / NF `GlobalHandler` 是同一种"挂 `FlxG.signals`"的思路。

NV 系内部（NV 本体 ↔ Impostor Legacy）另有一层分叉：**只有 `ParserEx` 那层语法是稳的**（`public` / 插值 / keyvalue for），`InterpEx` 的解释器细节、`ScriptConstants` 的返回协议、`FunkinScript.preset()` 的 API 面一律以目标引擎源码为准，别看"都是 NV 系"就照抄。跨到 CNE / NF 时同理 —— 四家的宿主暴露方式（`parent` / `state` 变量 / `parentInstance`）和挂载入口各不相同，**移植脚本第一件事是确认目标引擎的 `resolve` 回退分支长什么样**。
