# 过时（Deprecation）警告全量报告 — 2026-11-10

## 背景

- `Project.xml:223-224` 的 `no-deprecation-warnings` 开关已**注释掉**（保留原行可随时勾回），过时警告重新放开。
- 收集方式：`haxelib run lime build windows`（debug），Haxe 编译阶段完整跑完，日志全量解析。
- **全量 72 条，全部为 WDeprecated，无其他类型警告。**
- 本次构建 C++ 阶段被无关问题打断（`MemoryStats.hx` 的 `@:cppFileCode` 元数据误挂方法级，见另案处理），不影响 Haxe 警告的完整性——Haxe 阶段在 C++ 之前已结束。

## 汇总

| 消息 | 条数 | 归属 |
|---|---:|---|
| `finishCallback is deprecated, use onFinish.add` | 28 | **FE 源码** |
| `FlxG.sound.load is deprecated, use create(...).setup(...).play()` | 7 | **FE 源码** |
| `Std.is is deprecated. Use Std.isOfType` | 12 | 第三方 tjson 1.4.0 |
| `Implicit cast from Int64 to Int is deprecated. Use .toInt()` | 8 | **FE 源码**（Discord.hx） |
| `callback is deprecated, use onFrameChange.add` | 7 | **FE 源码** |
| `use MyState.new or ()->new MyState() instead of new MyState()` | 3 | **FE 源码** |
| `haxe.Utf8 is deprecated. Use UnicodeString` | 3 | 第三方 tjson 1.4.0 |
| `subtractPoint / addPoint / copyFromFlash deprecated` | 3 | 第三方 flxanimate (git fork) |
| `FlxAssets.getSound is deprecated, use getSoundAddExtension` | 1 | **FE 源码** |
| **合计** | **72** | FE 54 / 第三方 18 |

## FE 源码 54 处明细

### 1. FlxAnimationController `finishCallback` → `onFinish.add`（28 处）

弃用于 flixel 5.9.0。旧写法是**属性赋值**（单回调、后设覆盖先设）；新 API 是 FlxSignal `add`（**累加**、不覆盖）。

| 文件:行 |
|---|
| source/objects/CheckboxThingie.hx:24 |
| source/objects/NoteHoldCover.hx:324 |
| source/objects/NoteSplash.hx:296 |
| source/options/psychoptions/GraphicsSettingsSubState.hx:52 |
| source/states/FreeplayState.hx:1713, 1728, 1831 |
| source/states/freeplay/FreeplayFlames.hx:45 |
| source/states/stages/PhillyStreets.hx:286, 296, 360, 368, 394, 395, 421, 960, 984 |
| source/states/stages/SchoolEvil.hx:74 |
| source/states/stages/SchoolEvilErect.hx:120 |
| source/states/stages/Tank.hx:168, 169, 183, 184, 278, 320, 386 |
| source/states/stages/objects/SpraycanAtlasSprite.hx:34 |
| source/substates/GameOverSubstate.hx:155 |

### 2. FlxAnimationController `callback` → `onFrameChange.add`（7 处）

弃用于 5.9.0，同样的赋值→信号语义陷阱。

| 文件:行 |
|---|
| source/states/stages/PhillyStreets.hx:209, 832, 839, 842 |
| source/substates/GameOverSubstate.hx:114, 123, 126 |

### 3. `FlxG.sound.load(...)` → `create(...).setup(...).play()`（7 处）

弃用于 6.2.0。替换链式 API 的参数落点：`load(asset, volume, loop, group, autoDestroy, autoPlay, onComplete, onLoad)` →
`create(asset, group).setup(volume, loop, autoDestroy, onComplete)` + 需要自动播时补 `.play()`。
`create` / `createFromURL` / `createStreamed` / `playStreamed` 全部 `@since 6.2.0`。

| 文件:行 |
|---|
| source/cutscenes/DialogueBox.hx:110 |
| source/cutscenes/PixelDialogueBox.hx:178 |
| source/states/stages/MallErect.hx:196 |
| source/substates/NewPauseSubState.hx:132 |
| source/substates/PauseSubState.hx:76, 79 |
| source/substates/ResultsScreen.hx:451 |

### 4. `FlxG.switchState(new X())` / 传 Class → NextState 写法（3 处）

flixel 6.0.0 起 `switchState` 参数改 `NextState`（Class 与 `()->FlxState` 的抽象），传 Class 字面量+实例化触发弃用警告。修法：`FlxG.switchState(MyState.new)` 或 `()->new MyState()`。`MusicBeatState.switchState` 包装器签名若从 `Class<FlxState>` 换成 NextState，调用点写法可整体不动。

| 文件:行 |
|---|
| source/backend/MusicBeatState.hx:142, 163 |
| source/backend/BlueScreenCrashHandler.hx:652 |

### 5. Int64 → Int 隐式转换加显式 `.toInt()`（8 处，全在 Discord.hx）

hxcpp 层警告，与 flixel 无关。`hxdiscord_rpc` 的 presence 时间戳是 Int64，赋给 Int 字段/传给 `LabelValuePair.weak` 触发。纯机械修，零兼容风险。

| 文件:行 |
|---|
| source/backend/Discord.hx:113, 114, 194, 195, 251, 256, 261, 266 |

### 6. `FlxAssets.getSound` → `getSoundAddExtension`（1 处）

替换 API 是老 API（早于 5.x），修了不影响旧版编译。LoadingState.hx:960。

## 第三方警告处置

- **tjson 1.4.0**（15 处）：**已解决（2026-11-11）**——vendor 进 `source/tjson/TJSON.hx`，见下节。
- **flxanimate git fork**（3 处：FlxAnimate.hx 710/725/791 用了 6.1.2 弃用的 `FlxPoint.addPoint/subtractPoint/copyFromFlash`）：要消就得在 flxanimate fork 仓库里改，走上游流程。这是目前仅剩的 3 条背景噪音。

## tjson 替换记录（2026-11-11）

**结论：无现成维护 fork（[martamius/TJSON](https://github.com/martamius/TJSON) 停更，JWambaugh 旧仓库同理），haxe.Json 缺注释容忍不能直接换 → vendor 修好的副本进源码树。**

- 依赖面：FE 全部 8 处调用只用 `TJSON.parse`（周目/舞台/成就/模组设置/标题/LuaUtils），encode 未用；谱面大文件本就走 haxe.Json。
- 键序实测（hxcpp）：**tjson 与 haxe.Json 一样都是哈希序**，"保序"仅 JS 目标成立 → 顺序不是迁移约束。
- 真实差异只有一项：**注释容忍**（模组手写 JSON 依赖），这是不换 haxe.Json 的原因。
- 实施：`source/tjson/TJSON.hx`（BSD，出处+改动写入文件头），`Project.xml` 去掉 `<haxelib name="tjson"/>`，`setup/windows.bat` 去掉安装行。改动：`Std.is→Std.isOfType`×12、`haxe.Utf8→String.fromCharCode`、**修复上游 bug：\u 小写十六进制位算错**（`10+nc-95`→`nc-87`，原版 `\u4e2d` 产出「倯」0x502F；大写不受影响故从未暴露）。
- 验证（J:\tjson-eval 对照测试，hxcpp 实跑）：注释/单引号/无引号键 ✓、`\u` BMP+代理对（中文/😀/é）与 haxe.Json 一致 ✓、重复键 ✓、真实 week1.json + 大谱面解析结果逐字段一致 ✓。
- FE 全量类型检查：**EXIT=0，仅剩 flxanimate 3 条**。

## 与旧版 flixel 的破坏性变更分析

FE 的 flixel 历史轨迹：5.6.2 → 5.8.0 → 5.9.0 → 6.1.0 → **5.8.0（曾降级）** → git → 6.2.0 → 现在 pin 的 TieGao fork（6.2.0 tag + 10 commits）。**这个仓库真降级过**，所以"修完就回不去旧版"不是杞人忧天。当前 Project.xml 对 flixel 不带版本号，吃 haxelib 当前指向（git 6.2.1）。

| 警告类 | 弃用于 | 替换 API 最早可用 | 修完后最低 flixel |
|---|---|---|---|
| callback / finishCallback → 信号 | 5.9.0 | 5.9.0 | 5.9.0 |
| switchState → NextState 写法 | 6.0.0 | 6.0.0 | 6.0.0 |
| FlxG.sound.load → create 链 | 6.2.0 | 6.2.0 | **6.2.0** |
| FlxAssets.getSound | 未标版本 | 很老（<5.x） | 无影响 |
| Int64 → .toInt() | hxcpp 层 | 永远可用 | 无关 |
| FlxPoint addPoint 等（flxanimate） | 6.1.2 | 6.1.2 | （第三方内部） |

结论：**这批修完，FE 事实上锁死 flixel ≥ 6.2.0**，与 addons 4.0.1 / openfl 9.6-dev / lime 8.4 搭配现状一致，但往回（哪怕 6.1.x）都编不过。若哪天需要回 5.8/5.9 编译验证，得临时回滚这批改动。

### 迁移陷阱（重点）

1. **`finishCallback = fn` ≠ `onFinish.add(fn)`**。赋值是替换语义，信号是累加语义。Tank.hx（168/169 成对）、PhillyStreets 大部分调用点都在**可能重复执行**的函数里——无脑换 `.add()` 会回调堆积：重复触发 + 内存泄漏。逐处核对，重复路径用 `onFinish.removeAll()` 先清再 add，或确认只在 create 里设一次。
2. `FlxG.sound.load` 有 `autoPlay/onComplete/onLoad` 参数的组合各调用点不同，`create` 链要逐点映射；注意 `create` 不会自动播，autoPlay=true 的点要补 `.play()`。
3. `MusicBeatState.switchState` 是全引擎入口包装，改签名一次到位（参数换 NextState），比逐调用点修便宜。

### 脚本 API 面（legacy 模组兼容）

- 本次 72 条里**没有任何一条来自 source/psychlua、source/nmv**——FE 的 Lua/HScript 包装层没有踩这些弃用 API。
- 但 hscript-iris 模组可以**直接摸** `sprite.animation.finishCallback`、`FlxG.sound.load` 这些 flixel API。flixel 6.2.x 里它们只是警告、功能完好，**legacy 模组不受影响**；真正的悬崖是将来升 flixel 7 移除弃用项时，老模组会连环炸。
- 建议：**源码侧**迁走（消除 FE 自己的警告），**不要**动脚本 API 面、不要做 shim 删除——那是 NMV 兼容层的领地，弃用≠移除。

### 不修的代价

当前零行为影响：弃用警告是纯编译期提示，flixel 6.2.x 全线可用。风险全在将来 flixel 大版本移除时一次性引爆（28+7 处动画回调 + 7 处 sound.load + 3 处 switchState）。

## 修复记录（2026-11-11，基线 flixel ≥ 6.2.0）

FE 源码侧 **57 处已全部修复**（原 54 处 + hxvlc 2.3.2 新增 3 处），共改 24 个文件：

- **finishCallback → `onFinish.add` / 置 null → `onFinish.removeAll()`**：CheckboxThingie、NoteHoldCover、NoteSplash（对象池：先 removeAll 再 add）、GraphicsSettingsSubState、FreeplayFlames、SpraycanAtlasSprite、SchoolEvil(+Erect)、GameOverSubstate、PhillyStreets、Tank、FreeplayState。
- **callback → `onFrameChange.add`（自毁式：handler 内 `removeAll()` 自清）**：GameOverSubstate、PhillyStreets（cock/shootMISS 两处一次性监听）。
- **FlxG.sound.load → `create(asset).setup(vol, loop)`**：DialogueBox、PixelDialogueBox、MallErect、PauseSubState（null 分支改 `= null`）、NewPauseSubState、ResultsScreen。
- **switchState → NextState 惰性包装**：MusicBeatState 两处 `FlxG.switchState(() -> nextState)`（不改包装器签名、不动调用点、保留急切构造语义）；BlueScreenCrashHandler 先急切构造再包装（TitleState 构造异常仍被 try 捕获）。
- **Discord.hx Int64**：4 个 inline 访问器改 `.toInt()` / 显式赋值（警告是内联展开到调用点的，修源头 8 处全消）。
- **FlxAssets.getSound → getSoundAddExtension**：LoadingState。
- **hxvlc onFormatSetup → onVideoFormatSetup**（审计时新发现，hxvlc git 已漂到 2.3.2，2.3.1 无此弃用）：CreditsVideoPanel、VideoSprite、CreditsVideoSubState。

**验证**：`haxe export/release/windows/haxe/debug.hxml --no-output` 类型检查 EXIT=0，剩余 WDeprecated 恰好 18 条（tjson 15 + flxanimate 3，全部第三方库内）。
**未完成**：exe 级验证构建被运行中的 FrozenEngine.exe 锁住 `lime.ndll`，关游戏后跑 `haxelib run lime build windows` 补上即可（改动全在 Haxe 层，C++ 为机械转译）。

迁移语义规则（务必遵守，否则引新 bug）：
1. 赋值=覆盖、`.add`=累加——可重复执行路径必须先 `removeAll()` 再 `add`。
2. 旧 handler 内 `= null` 自清 → handler 内 `removeAll()`（FlxSignal dispatch 期间 remove 走 pendingRemove 延迟，安全）。
3. flixel 动画结束时旧字段与新信号都触发（FlxAnimationController.hx 723/726），迁移后单一信号，行为等价。

## 后续

1. MemoryStats 修好后重编一遍，确认 C++ 全绿、警告仍为 72 条（应无新增）。
2. 修警告时按上面陷阱清单逐类来；修完重编确认归零。
3. 主版修完按 fe-sync 流程跟移动版——移动版是同一套 Psych 代码，GameOverSubstate/Tank/PhillyStreets/PauseSubState 那批基本同量存在。
4. tjson / flxanimate 的 18 条不在此列，除非换库/走 fork 上游。
