# 72 · 多人唱（多 playfield）按参考引擎重审 —— 2026-11-01 上午

> 接手点：71 号之后。用户实测反馈：**白 note 落在 dad/bf 的轨上，那条轨的判定线不亮**，
> 要求"重新审计多轨道处理，做成最接近参考引擎（NMV / Impostor Legacy）的实现"。
> 参考源：`D:/NightmareVision/source`、`D:/impostorLegacyPublic/source`、
> 语料脚本 `content/NMVMODS/legacy/data/stages/{attack,voting}.hx`。

---

## 1. 参考引擎到底怎么处理 lane>=2（源码事实）

| 事实 | 位置 |
|---|---|
| `PlayField` 是**容器**，strum 在 `generateReceptors()` 里建，位置 = `getBaseX(col, lane)`；**每帧**再由 modchart 重算绝对坐标（`getPos` → `updateObject`：`obj.x = pos.x - width*.5`） | `PlayField.hx:188-199`、`ModManager.hx:243-282` |
| note 和 receptor **同源**：note 的坐标也来自 `getPos(...)`，不读 receptor 的 x | `PlayState.hx:1838-1840` |
| `getCenterX`：lane 0 贴右、1 贴左、**>=2 一律屏幕正中**（lane 2/3 默认重叠） | `ModManager.hx:220-231` |
| lane 2/3 的分离完全靠舞台脚本 `transformX = ±865` 推出屏幕 | `attack.hx:151-166`、`voting.hx:120` |
| 外侧轨同时设 `noteAlpha=1`（note 全透明）、`alpha=0.7`（受体 30%）、`stealth=0.5`、`transformY=-90` | `attack.hx:155-168`、`voting.hx:109-122` |
| `stealth` 不是"染白"：`getVisibility = 1-stealth` → `getAlpha = clamp(v*2,0,1)`、`getGlow = clamp((1-v)*2.6,0,1)`；**白闪只在部分淡出时出现**，`stealth=0.5` 时 `alpha=1`、`glow=1`（白但可见） | `AlphaModifier.hx:42-119` |
| `alpha` 子模同时作用在**受体**上：`receptor.rgbGraphics.alpha = (1-alpha)*(1-alpha{col})` | `AlphaModifier.hx:121-130` |
| 输入只走 lane 0（`playerControls` 字段存在，但 `attack/voting` 实际只让 lane 0 可玩） | `attack.hx:136-137`、`voting.hx:55` |

**结论：参考引擎里 lane 2/3 的 note 是"被推出屏幕 + 全透明"的，玩家看不到任何额外轨道。**
所以"白 note 挂在 dad/bf 轨上"是移植端漏了透明/定位，不是参考行为。

---

## 2. 移植端的三处偏差（本次修掉）

| # | 偏差 | 后果 | 修在哪 |
|---|---|---|---|
| 1 | note 侧 alpha/glow 管线挂在 `copyAlpha` 上 | FE 的倒计时对存活 note 关掉 `copyAlpha`（`PlayState` countdownTick）→ 那批 note 永远拿不到 `noteAlpha`，外侧轨本该全透明却一直挂在屏幕上（用户看到的"白 note"） | `Note.followStrumNote` 去掉 `copyAlpha` 条件 |
| 2 | 倒计时把 `note.alpha` 刷成 `ClientPrefs.noteAlpha` | 同上，逐 tick 把外侧轨刷回可见 | 多轨歌跳过这段 |
| 3 | note 坐标只从 `strum.x` 派生 | 那条车道的 strum 组一旦缺失/回退，note 就落到 dad/bf 的轨上（并且亮的是另一条轨的 strum → "轨道不会亮起"） | 新增 `PlayState.getLaneNoteBaseX(col, lane)`（`getCenterX + getStrumX + transformX`），lane>=2 的 note 直接按公式定位 |

另外补齐参考引擎有、移植端缺的一项：

- **受体透明度**（`AlphaModifier.updateReceptor`）：`applyLaneStrumOffsets` 里按
  `laneReceptorAlpha(lane, col) = (1-alpha)*(1-alpha{col})` 设 strum alpha。

---

## 3. `ModManagerCompat` 的函数口径

| 函数 | 口径 |
|---|---|
| `laneVisibility(lane)` | `clamp(1 - stealth, 0, 1)`（位置项 hidden/sudden/blink 未移植，要逐帧算 NMV 的 y，滚动公式不同源） |
| `laneStealthAlpha(lane)` | `clamp(v*2, 0, 1)` = NMV `getAlpha` |
| `laneStealthGlow(lane)` | `v >= 1 → 0`，否则 `clamp((1-v)*2.6, 0, 1)` = NMV `getGlow` |
| `laneNoteAlphaMult(lane)` | `(1-alpha)*(1-noteAlpha)` = NMV `updateNote` 的常值项 |
| `laneReceptorAlpha(lane, col)` | `(1-alpha)*(1-alpha{col})` = NMV `updateReceptor` |

---

## 4. 诊断面包屑（下次实机只认这几行）

- `nmv note lane=<n> nmvLane=<n> col=<c> strumX=<x> -> noteX=<x> alpha=<a> glow=<g> laneAlpha=<a> extra=<n>`
  —— 每车道第一条 note 打一次：确认 note 跟的是哪条 strum、最终 x、透明度和白闪。
- `nmv lanes transform: lane=<n> dx=<..> dy=<..> baseX=<..> -> x=<..> visible=<..> alpha=<..>`
  —— **dx 变化时**打（首帧必打）：确认 transformX 没被中途清掉。
- `nmv lanes: note lane=<n> 没有对应 strum 组（extra=<n>），回退到 <player|opponent> 轨`
  —— 只在 strum 组缺失时出现，出现即说明 note 会"长到别人轨上"。

判定：
- lane 2/3 的 `strumX` 应约为 `-396`（lane 2）/ `1334`（lane 3），`alpha=0`、`laneAlpha=0`。
- lane 0/1 的 `glow` 必须是 `0`。若 lane 0/1 出现 `glow>0`，说明 `stealth` 被写到了 0/1 号位
  （脚本侧或 `setValue` 的 playFieldIndex 传错），那是另一条 bug。

---

## 5. 合轨模式（`legacyCompactLanes`，默认开）

**模型：外侧轨被脚本移到与 dad/bf 轨道重叠的位置，不是归给它们，也不是留在屏幕正中。**
`attack.hx:149` 的 wrap 分支就是干这个的：

```haxe
if (i.ID >= 2 && !ClientPrefs.middleScroll)
    modManager.setValue("transformX", 315 * (i.ID == 2 ? -1 : 1), i.ID);
```

NMV 的坐标里 ±315 正好把 lane 2 压到 dad 轨、lane 3 压到 bf 轨（dad 列基准 153，正中列基准 469，
469-315 = 154）。非 wrap 分支才是 `±865` 推到场外 —— 移植端只实现了后者，所以轨道飞到左上角。

| 项 | 内容 |
|---|---|
| 设置项 | `ClientPrefs.data.legacyCompactLanes`（Bool，默认 true） |
| 位置 | 设置 → Engine(Advanced) → **NMV / Impostor Legacy** 页 → `Legacy Compact Lanes` |
| 开 | lane>=2 的 strum **逐列取目标轨道的基准 X/Y**（偶 → 对手轨、奇 → 玩家轨），不抄 315 这个数（FE 的轨道基准与 NMV 不同源，抄数字会偏几十像素）；note 呈半透明白（白闪 mult=1，alpha 取脚本 `alpha` 子模 → 0.3，未设 0.35）、自动演唱、**不亮判定线**（`strumPlayAnim` 对 compact 外侧轨直接返回）；演唱归属不变（`playFields[lane].owner`） |
| 关 | 参考引擎的非 wrap 分支：`transformX ±865` 推到场外，note `noteAlpha=1` 全透明 |

实现点：`PlayState.useCompactLanes()`、`applyLaneStrumOffsets` 的 compact 分支（取目标轨基准）、
`Note.followStrumNote` 的 `compactLane` 分支（白 + 半透明）、`strumPlayAnim` 的"不亮"短路。

**注意**：`Note.alpha` 一律写成 `nmvAlphaBase * 乘数`，不能写 `alpha *= 乘数` ——
FE 倒计时会关掉 `copyAlpha`（不再每帧重置 alpha），连乘会指数衰减到 0。

## 6. 验证

```bash
haxe _nmvcheck.hxml   # exit 0，零输出
```

实机（用户做）：
1. **合轨开（默认）**：Monotone Attack / Voting Time 里，lane 2 的轨道压在 dad 轨上、
   lane 3 压在 bf 轨上（受体半透明），note 半透明白、玩家不用打、打了判定线也不亮；
   演唱仍归 gf / biddle / redmungus。
2. **合轨关**：外侧轨被推到场外、note 全透明。
3. `bread.log` 新增 `nmv lanes owner: lane=<n> -> <角色名>`，可直接核对 2/3 号位的归属有没有绑反。

## 7. 附带修：monotone attack 锁镜到 gf / biddle 时相机飘出场景

`attack.hx` 的 `Attack Events / force camera` 只是把 `camCurTarget` 设成 gf 或 biddle
（`attack.hx:290-299`），真正的坐标由引擎的 `moveCamera` 算。NMV 走
`getCharacterCameraPos(char)`：

```haxe
desiredPos = char.getMidpoint();
offsets = char.isPlayer ? boyfriendCameraOffset : opponentCameraOffset;
desiredPos.y += -100 + char.cameraPosition[1] + offsets[1];
desiredPos.x += char.isPlayer ? -(100 + char.cameraPosition[0]) : (100 + char.cameraPosition[0]);
desiredPos.x += offsets[0];
```

移植端此前只写了 `midpoint + cameraPosition`，少了 `±100`、y 的 `-100` 和舞台
`camera_boyfriend/opponent` 偏移。按本包数据算：biddle（isPlayer=true，
cameraPosition=[225,384]，舞台 opponent 偏移 [125,-125]）偏差 **625px 横向 / 225px 纵向**，
正好把镜头送到舞台画面之外。现补 `PlayState.getCharacterCameraPos()`，`moveCamera` 的
`camCurTarget` 分支改用它。
3. 回归：lanes=2 的老歌位置/颜色/判定完全不变。
4. `bread.log`：`nmv lanes: compact mode（lanes=4，不生成外侧 strum 组）` 一行；
   关掉后应恢复 `nmv lanes: lanes=4 …` + `nmv lanes transform: … dx=±865`。
