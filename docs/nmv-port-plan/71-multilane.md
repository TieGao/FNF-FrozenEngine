# 71 · 多人唱（NMV `SONG.lanes > 2`）落地 —— 2026-11-01 上午 多人唱线

> 接手点：本文件在 70 号之后。**这是"多人唱"那条线的第一份交接**，
> 与 NMV 移植 bug 线（68/69/70 号）并行，改动面互不重叠。
> 用户原始诉求（65 号 §1）："白 note 本应 2 人分着唱、结果全被 dad 唱"。

---

## 1. 结论表

| # | 现象 | 根因 | 修在哪 |
|---|---|---|---|
| 1 | lane 2/3 的 note 从 dad 轨落下 | `generateStaticArrows` 只建 2 组 strum，`getStrumGroup` 只按 `mustPress` 二分 | `PlayState.generateExtraLaneArrows` + `getStrumGroup` |
| 2 | lane 2/3 由 dad 唱 | `playFields[2]/[3]` 是空壳（`owner=null`） | `PlayState.bindPlayFieldStrums` + `getPlayFieldByLane` |
| 3 | 即使建了组也会全叠在屏幕正中 | NMV 的 lane>=2 基准 X **恒为屏幕中心**，靠脚本 `transformX` 推走；移植端 `setValue` 只存值不生效 | `PlayState.applyLaneStrumOffsets` + `ModManagerCompat.getLaneValue` |
| 4 | 中间组被推高后 note 仍半透明挂着 | NMV 的 `noteAlpha=1` 是"整条轨道 note 全透明"，此前只实现了 `alpha` | `ModManagerCompat.laneNoteAlphaMult` 补 `noteAlpha` 因子 |
| 5 | `refreshZ(playFields)` 后按 `members[lane]` 取 owner 会错位 | 排序原地重排 members | 全部改按 `shim.ID` 查（`getPlayFieldByLane`） |
| 6 | 跨歌修饰值残留 | `PresetFnf.sharedModManager` 是静态共享，`setValue` 永久赋值 | `ModManagerCompat.reset` + `NMVSciptHolder.new` 里调用 |
| 7 | lane 2/3 的长条在 dad 轨上凭空亮光圈 | hold cover 按 `mustPress` 选边，不知道 lane | 三处 `noteHoldCover` 触发点统一加 `note.nmvLane < 2`（`NoteHoldCover` 内部只用 player/opponentStrums 定位，挡住触发即可） |

---

## 2. 硬事实（别再重新推导）

### 2.1 NMV 的车道模型

- `funkin/data/Song.hx:25-26`：`keys`（每条 playfield 的列数）+ `lanes`（playfield 条数）。
- `funkin/data/Chart.hx:103-104`：`keys ??= 4; lanes ??= 2;` —— **普通两轨歌也是 lanes=2**。
- 谱面 `sectionNotes[1]` 是**绝对车道** `0 .. lanes*keys-1`。
- `Note.hx:409`：`mustPress = (player == 0)` —— **与 FE 现有的 `noteData < totalColumns` 等价**，
  所以 mustPress 语义本来就没错，不要再去改它。
- `generatePlayfields`：`character = (lane == 1 ? dad : boyfriend)`、`isPlayer = (lane != 1)`、
  `auto = (lane != 0 || cpuControlled)`、`noteSplashes = (lane == 0)`。

### 2.2 语料分布（决定改动面有多安全）

63 个谱面：57 个 `lanes=2/keys=4`，**2 个 `lanes=4`**（`monotone-attack`、`voting-time`），
4 个缺字段（按缺省 2/4 处理）。所以 `lanes>2` 的分支只影响两首歌。

### 2.3 隐藏依赖：lane>=2 的位置是"脚本推出来的"

`ModManager.getCenterX`（NMV `funkin/game/modchart/ModManager.hx:220-231`）：

```haxe
case 0: FlxG.width - swagWidth*(keys/2) - 100 - 3;   // ≈965（右）
case 1: swagWidth*(keys/2) + 100 - 3;                // ≈321（左）
default: FlxG.width * 0.5 - 3;                       // ≈637（正中，lane>=2 全一样）
```

**lane 2 和 lane 3 的基准 X 完全相同**，默认是叠在一起的。分开它们的是舞台脚本：

- `voting.hx:120` → `transformX = i.ID == 2 ? -865 : 865`（推到场外）
- `attack.hx:151` → 非 wrap 组 `±865`（场外）；wrap 组 `transformX = 315 * ±1`（推到左右半屏）
- `attack.hx:170` → lane 0/1 用 `opponentSwap = -0.85`（OpponentModifier：
  `pos.x += (对侧基准X - 本侧基准X) * value`，≈把两组各推 544px 出屏）

**所以多人唱不等于"4 条 strumline 同屏"**。NMV 里这两首的演出是：
note 被推出屏幕（`noteAlpha=1` 再补一刀全透明），角色照样按 owner 唱。

### 2.4 `refreshZ(playFields)` 会毁掉下标语义

`attack.hx:172` / `voting.hx:126` 都调 `refreshZ(playFields)`，而 FE 的 `refreshZ` 是
**按 zIndex 原地重排 members**（与 NMV 同款）。之后 `members[2]` 不再是 lane 2。
NMV 不受影响是因为它靠 `note.playField` 直接引用；移植端靠下标取 owner → 必须改成按
`PlayFieldShim.ID`（= 车道号）查。**这条适用于所有读 playFields 的地方。**

---

## 3. 改动清单

| 文件 | 改动 |
|---|---|
| `source/backend/Song.hx` | `SwagSong` 加 `@:optional lanes/keys`；`parseJSON` 末尾补缺省（`lanes ??= 2`、`keys ??= getKeyCount`）。**放在 parseJSON 而不是 convert**：convert 只对非 psych_v1 格式执行 |
| `source/objects/StrumNote.hx` | 新增 `baseX` / `baseY`（默认 NaN）。只有多轨分支会读它们 |
| `source/states/PlayState.hx` | 见下 |
| `source/nmv/objects/PlayFieldShim.hx` | `noteSplashes` 默认改 **false**（对齐 NMV：只有 lane 0 为 true） |
| `source/nmv/utils/ModManagerCompat.hx` | 新增 `getLaneValue(field, lane):Float`、`reset()`；`laneNoteAlphaMult` 补 `noteAlpha` 因子 |
| `source/nmv/scripts/preset/PresetFnf.hx` | 新增 `resetModManager()` |
| `source/nmv/scripts/NMVSciptHolder.hx` | `new()` 里调 `resetModManager()`（每首歌一份干净修饰值） |

`PlayState.hx` 的具体点：

- 字段：`songLanes`（默认 2）、`extraStrums:Array<FlxTypedGroup<StrumNote>>`、`laneOffsetLogged`
- `refreshSongLanes()` / `isMultiLaneSong()` / `getStrumGroupForLane()` / `getPlayFieldByLane()`
- `refreshColumnCount()` 里也调 `refreshSongLanes()`
- create 里 playFields 按 `max(4, songLanes)` 建（0/1 包真实组，>=2 后补 strums）
- `generateExtraLaneArrows()`：lane 2..n-1，位置 = `ModManagerCompat.getCenterX + getStrumX`，
  **不调 `playerPosition()`**（它会按 player 再加半屏基准）
- `applyLaneStrumOffsets()`：每帧叠加 `transformX` / `transformY`（全 lane）、
  `opponentSwap`（lane 0/1）、`visible`（lane>=2）
- `bindPlayFieldStrums()`：绑 `strums` 活引用 + `owner` 缺省（**不覆盖**脚本已设的
  isPlayer / playerControls / autoPlayed / visible / zIndex）
- `getStrumGroup(note)`：lane>=2 → 自己的组
- `strumPlayAnim(..., ?lane)`：lane>=2 点亮自己那条轨的 strum（两处调用点已传 `note.nmvLane`）
- `spawnNoteSplashOnNote`：lane>=2 按 `shim.noteSplashes` 判定
- `noteHoldCover` 三处触发点（opponentNoteHit / goodNoteHit / triggerOpponentEventsForHumanHit）：
  统一加 `note.nmvLane < 2`，中间组的长条不出光圈
- `opponentNoteHit` 的演唱 owner：改 `getPlayFieldByLane(lane)`
- `generateStaticArrows` 末尾记 `baseX/baseY`（无副作用，只有多轨才读）
- startCountdown：`generateExtraLaneArrows()` → `bindPlayFieldStrums()` → `applyLaneStrumOffsets()`
- update：每帧 `applyLaneStrumOffsets()`

---

## 4. 明确没做的（取舍记录）

| 项 | 为什么不做 |
|---|---|
| **输入路由按 `playerControls`** | **这是特化**。真实游玩时 `voting.hx:55` 写死 `ID != 0 → false`，`attack.hx` 默认 `attackCharacter=0`；唯一会用到的是 `attack.hx` 的 `ClientPrefs.inDevMode` 分支（按 1/2/4/5 切角色）。代价却是改 `keysCheck` / `keyPressed` / `keyReleased` / `getStrumForKey` / `noteIsHuman` / `strumsBlocked` 六处主干，还要和 `opponentMode`（opponent / coop / coop_split）矩阵相乘。**字段仍可写，按键仍固定走 lane 0。** |
| `transformZ` | NMV 的透视深度，FE 没有 z 轴。attack/voting 给 lane 2/3 设 -1，那两条轨本来就在场外 |
| `underlay` | FE 没有轨道底板，`PlayFieldShim.underlay` 保持可 kill 的空壳（脚本不炸即可） |
| `stealthPastReceptors` / `hidden` / `sudden` / `blink` | 位置型 stealth 分量，此前 `laneStealthGlow` 只取常值部分（64 号），本次未扩 |
| playFields 的 zIndex → 实际绘制序 | `refreshZ(playFields)` 只重排 shim；strum 都在 `strumLineNotes` 一个组里。中间组在场外，暂时无视觉影响 |

---

## 5. 实机验证清单

1. **Voting Time**：屏幕应只剩左右两条 strumline；`gf`（lane 2）和 `redmungus`（lane 3）
   会在自己的段落跟着唱，**不再有白 note 从 dad 轨落下**。
2. **Monotone Attack**（默认 `attackCharacter=0`）：同样只剩左右两轨；
   `gf`（lane 2）/ `biddle`（lane 3）会唱。
3. **回归**：任意一首 lanes=2 的老歌（如 `double-trouble`、`torture`）strum 位置、
   note 归属、splash 应与改动前完全一致。
4. **跨歌**：先玩 voting-time 再玩 monotone-attack，中间组的 transformX 不应串味。
5. 日志（`crash/bread.log`）应出现：
   - `nmv lanes: lanes=4 keys=4 extra=2 centerX=637`
   - `nmv lanes transform: lane=2 dx=-865 ... -> x=-228`（或 lane 3 的 +865 → 1502）
   - 不应再有 `nmv modchart no-op: setValue('transformX')` 之外的异常
     （no-op 面包屑本身还在，那是 `setValue` 的通用提示，**不代表没生效**——
     生效走的是 `getLaneValue` 直读 values，不经过 modifier 链）

## 6. 协作约定（本轮改过的文件，归属多人唱线）

`source/backend/Song.hx`、`source/objects/StrumNote.hx`、`source/states/PlayState.hx`、
`source/nmv/objects/PlayFieldShim.hx`、`source/nmv/utils/ModManagerCompat.hx`、
`source/nmv/scripts/preset/PresetFnf.hx`、`source/nmv/scripts/NMVSciptHolder.hx`。

工作区里另有对方线未提交的改动（`Conductor.hx` / `Character.hx` / `InterpEx.hx` /
`FunkinSprite.hx` / `GameOverSubstate.hx` / `NmvAtlasAnchor.hx` / `AmongWalker.hx` /
`PsychFlxAnimate.hx` / `Paths.hx`）—— **本轮一行都没碰**，类型检查若在那些文件上报错，
视为对方在改，不要顺手修。

类型检查：`haxe _nmvcheck.hxml` → exit 0，零输出。构建与实机验证由用户做。
