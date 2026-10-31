# 63 · modchart 移植筹划 — 2026-10-31 深夜 会话 h

> 结论先行：**当前语料里没有任何内容真正用到 modchart**（218 个谱面零 `mods` 数据，
> 4 首脚本里的 `modchart(step)` 只是镜头缩放且源码里根本没有调用点）。
> 所以移植的价值不在"让现有歌能跑"，而在"让引擎具备这个能力"。
> 建议按 §4 的 P0→P1 先落"零视觉变化"的骨架，modifier 全家等有实际内容再补。

## 1. 现状盘点（FE 侧）

| 件 | 位置 | 状态 |
|---|---|---|
| `ModManagerCompat` | `source/nmv/utils/ModManagerCompat.hx`（139 行） | **兼容面**：`setValue/getValue` 真存值（per 车道）；`registerMod` 记录名字；`queueEase/queueFuncOnce/updateObject/getPos/updateTimeline/update` 全是记录式 no-op + 每个名字一条面包屑 |
| 脚本注入 | `nmv/scripts/preset/PresetFnf.hx:114/160/223` | 脚本变量 `modManager` 指向共享 compat 实例；`funkin.game.modchart.ModManager` 这个 FQ 类名也指向 compat |
| 局部真实现 | `ModManagerCompat.laneNoteAlphaMult / laneStealthGlow` | 把 `alpha`/`stealth` 两个 mod 值翻译成 note 的透明度/白闪（attack、voting-time、Finale 用） |
| note 侧接缝 | `source/objects/Note.hx:865-905` | 已经在这里读上面两个值（NMV 内容才生效） |
| 52 号文档 | `docs/nmv-port-plan/52-missing-api-112.md` | 明确记着"完整 modchart 引擎 defer" |

## 2. 参考引擎的 modchart 是什么（NMV 侧）

`D:/NightmareVision/source/funkin/game/modchart/`，共 **1965 行**：

```
ModManager.hx 363   ← 注册表 + activeMods[player] + getPos/updateObject + 事件排队
Modifier.hx 111     ← 基类：getPos / updateNote / updateReceptor / updateNoteSplash / updateSustainSplash
NoteModifier.hx 17  ← NOTE_MOD 标记（会被 note/receptor 调用）
SubModifier.hx 19   ← 同名子模（如 xmod0..xmod3）
ScriptedModifier.hx 94 ← 脚本自定义 modifier
EventTimeline.hx 77 ← 按 step 推进的事件队列
SpeedEvent.hx 10
events/  BaseEvent, CallbackEvent, EaseEvent, ModEvent, SetEvent, StepCallbackEvent
modifiers/ Accel, Alpha, Beat, Confusion, Drunk, Flip, InfinitePath, Invert,
           LocalRotate, Opponent, Path, Perspective, ReceptorScroll, Reverse,
           Rotate, Scale, Transform, X
```

核心数据流（`PlayState.modchart()`，NMV `PlayState.hx:1701`）：

```haxe
pos = modManager.getPos(strumTime, visPos, diff, curDecBeat, noteData, lane, obj);
modManager.updateObject(curDecBeat, obj, pos, lane);   // 写回 x/y + 逐 mod 的 updateNote/updateReceptor
```

`getPos` 先给基准 `pos.setTo(getBaseX(data,player), getBaseY()+diff, 0)`，然后按
`activeMods[player]` 的顺序过每个 modifier 的 `getPos`（可改 x/y/z、可再次调用
`getPos(..., exclusions)` 取"未加某 mod 的路径"）。

`updateObject` 再按 activeMods 顺序跑 `updateNote/updateReceptor`，最后
`obj.centerOrigin(); obj.centerOffsets();`。

## 3. 接入 FE 的关键差异（这是移植的真正难点）

| 维度 | NMV | FE（Psych 系） |
|---|---|---|
| Note 基类 | `Note extends ModchartNote extends FunkinSprite` | `Note extends FlxSprite` |
| note 位置 | 由 `ModManager.getPos` 全权给（绝对屏幕坐标） | `Note.update` 里 `y = strumY + offsetY + correctionOffset + sin(angle)*distance` 自己算（滚动速度/section BPM/像素舞台都在里面） |
| strum 布局 | `PlayField` 用 `ModManager.getStrumX(data, keys)` | PlayState 里逐轨摆 `StrumNote`，`Note.swagWidth` 定距 |
| splash | `NoteSplash`/`SustainSplash` 都 extend `ModchartNote` | 只有 `NoteSplash`（sustain 用 hold cover） |
| 多玩家 | `lanes`（0=bf,1=dad） | `mustPress` + 可能 2v2 多 field |

**直接照搬 `getPos` 绝对定位会炸**：Psych 的滚动公式跟 section BPM、`downScroll`、
像素舞台、`StrumNote` 的实际 x 全都绑在一起，换掉等于重写 note 渲染。

## 4. 推荐路线（delta 叠加，不接管坐标）

### P0 · 骨架（无内容依赖，可先做）

1. 把 NMV 的 `Modifier` / `NoteModifier` / `SubModifier` / `EventTimeline` /
   `ModManager` 原样搬进 `source/nmv/modchart/`，只改 import 路径：
   - `funkin.game.modchart.*` → `nmv.modchart.*`
   - `funkin.backend.math.Vector3` → `nmv.backend.math.Vector3`（已存在）
   - `funkin.objects.*` → FE 的 `objects.Note` / `objects.StrumNote` / `objects.NoteSplash`
2. `Modifier` 里的 `updateSustainSplash` 留空实现（FE 没这个类）。
3. `ModManager.registerDefaultModifiers()` 里 `PlayState.SONG.keys` 改成 FE 的列数来源。

**验收**：类型检查过；`registerDefaultModifiers()` 能跑；不改变任何现有画面。

### P1 · 位置管线（delta 模式，关键设计）

在 `ModManager` 上加一个只算**变换量**的入口：

```haxe
// 返回 modifier 链对基准位置的偏移（不含基准本身）
public function getPosDelta(time, diff, tDiff, beat, data, player, obj):Vector3
{
    final base = Vector3.get(getBaseX(data, player), getBaseY() + diff, 0);
    final out  = getPos(time, diff, tDiff, beat, data, player, obj);   // 过 mod 链
    return out.subtract(base);   // 只留 delta
}
```

然后：
- **Note**：在 `copyX/copyY` 算完之后叠 `delta.x/delta.y`（`copyX/copyY` 为 true 时才叠）。
- **StrumNote**：同理，叠到自己的 x/y。
- **PlayState.update**：`modManager.updateTimeline(curDecStep)` + `modManager.update(elapsed)`。

这样默认（`xmod=1`、所有 mod 值 0）delta 恒 0 → **零视觉变化**，可以安全合入。

**验收**：无 modchart 的歌画面完全不变（截图比对）；手动 `queueSetP(0,'drunk',100)`
能看到 note 抖动。

### P2 · 内置 modifier（按需）

先上最常用的 6 个：`XModifier`（xmod）、`DrunkModifier`、`BeatModifier`、
`ScaleModifier`、`AlphaModifier`、`ReverseModifier`。剩下的（Path/InfinitePath/
Perspective/Transform/LocalRotate/ReceptorScroll/Confusion/Flip/Invert/Accel/Opponent）
可以一次性搬完但**不注册**，等有内容再挂。

**验收**：每个 mod 单独 `setValue` 有效，`updateObject` 里的 `centerOrigin/centerOffsets`
不会把 Psych 的 sustain 裁剪搞坏（这是最容易出问题的地方，sustain 的 origin/offset 有特判）。

### P3 · 脚本 API

把 `FunkinScript.hx` 里那批 `set("ModManager", ...)`、`set("ModEvent", ...)` 等
从 compat 换成真类；`ModManagerCompat` 保留为"脚本调用了未移植 API"的兜底（现在它会
打面包屑，方便发现漏网）。

**验收**：舞台脚本里 `modManager.setValue('alpha', 0.7)` 仍然表现一致；
`queueEase` 真的产生动画而不是 no-op。

### P4 · `modchart(step)` 钩子（低成本，可选）

调研发现 4 首歌（chlorophyll / inflorescence / lemon-lime / stargazer）的
`songs/<歌>/<歌>.hx` 里定义了 `public function modchart(step:Int)`，内容只是
`camGame.zoom += 0.03` 这类镜头缩放。**NMV 源码里没有任何地方调用它**
（全仓 grep `modchart(` 只命中 PlayState 的 `inline function modchart(obj, id, offsets)`，
那是 note 定位函数，同名不同物）。

两种可能：被更外层的 mod 加载器调用，或者已经是死代码。移植成本极低（PlayState.stepHit
里 `scripts.call('modchart', [curStep])` 即可），但**先确认它真的有用再挂**。

## 5. 风险清单

1. **sustain 的 origin/offset**：`updateObject` 末尾对 `isSustainNote` 有
   `note.origin.y = note.offset.y = 0` 的硬特判，Psych 的 sustain 还依赖
   `clipRect`/`frameHeight`，直接套会撕裂长条。
2. **坐标基准不同**：`getBaseX` 用的是 `FlxG.width` + 固定 100px 边距，FE 的 strum
   位置受 `PlayState.SONG.keys`、中间轨道、2v2 多 field 影响 → 必须走 delta，不能接管。
3. **`centerOrigin/centerOffsets`**：FE 的 `Note` 在 `updateHitbox` 后手动改过
   origin，每次 mod 更新都 `centerOrigin` 会把某些皮肤的锚点冲掉。
4. **脚本期望的类名**：脚本里 `new ModManager(...)` 走的是 FQ proxy import，
   换成真类前要确认构造函数签名一致（NMV 是 `new(state:PlayState)`）。
5. **性能**：`getPos` 每个 note 每帧过一次 modifier 链；NMV 的 `activeMods` 为空时
   直接跳过，FE 也要保证"没有 mod 时不进链"。

## 6. 建议的下一步（需要用户拍板）

- **A（推荐）**：先做 P0 + P1，约等于"把地基埋好但不装修"，风险最低、可随时停。
- **B**：P0 + P1 + P2 全上，一次性具备完整能力，但要连带处理 sustain 裁剪与锚点。
- **C**：只做 P4（`modchart(step)` 钩子），几十行，让那 4 首歌的镜头缩放生效。

现阶段语料零使用，**A** 的性价比最高；C 可以顺手做（但先确认那 4 个函数不是死代码）。
