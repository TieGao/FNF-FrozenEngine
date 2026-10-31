# 交接：动画零件（子符号实例）帧语义 — 2026-10-31 夜

> ## ⚠️ 本文档第 2、3 节的结论是**错的，实现已回退**（2026-10-31 22:5x 事故）
>
> `freezePartFrames` 上线后**所有角色动画塌成 1 帧**（实机：whitedk/maroon/pink/grey/chef
> 全身静止），已整段删除。错在：
>
> - 文中"`this.lastFrame = data.LF;` —— JSON 没写 `LF` 时吃 null = 0" **不成立**。
>   NMV 的 `FlxAnimateJson.hx:190` 是 `public var LF(get,never):Int;`，getter 实现为
>   `return this.LF ?? this.lastFrame ?? -1;` —— **缺省是 -1**。
> - 于是 `SymbolInstance.hx:105 hasLastFrame = (lastFrame > -1)` 为 **false**，走的是
>   `FlxMath.wrap(firstFrame + 相对帧, 0, 符号总帧-1)`，与 Dot-Stuff 的
>   `(相对帧 + firstFrame) % symbol.length`（`FlxSymbol.length == timeline.totalFrames`）
>   **完全等价**。零件本来就该跟着父时间线走，"钉死"是凭空造出来的差异。
> - 见 `60-handoff-20261031-night-anim-fix.md` 与 `scripts/anim-frame-probe.py`
>   （可离线推演任意图集的零件帧，改这块之前先跑）。
>
> 保留的部分：`safeAddBySymbolIndices` 的字典键改成 `@源符号@动画`（避开 Dot-Stuff
> `addBySymbol` 的前缀匹配串台）—— 这条是对的，与帧语义无关。

> 针对用户反馈的 5 条零件错位 + alt 缺失。**已落第一处修复**（零件帧钉回 firstFrame），
> 过类型检查，待构建实测。

## 1. 症状（用户实测）

| 角色 / 动画 | 现象 |
|---|---|
| whitedk `idle` | 最后一帧仍然错位 |
| maroon `singDOWN` | 手和剑来回交替 |
| grey `idle` | 手一直错乱 |
| pink `idle` | 手、护目镜、爱心全乱；`singLEFT` 身体有问题；`singRIGHT` 手炸 |
| chefogus | 护目镜有问题；`singLEFT` / 待机 |
| alt 动画 | 观察到的 alt 角色只有 `singUP-alt` / `singDOWN-alt` |

## 2. 根因（代码级，两库对同一份数据算出不同帧）

参考引擎（MaybeMaru / NMV）与移植端（Dot-Stuff flxanimate）在**嵌套符号实例的帧**上
语义不同：

**参考引擎** `internal/elements/SymbolInstance.hx:100 getFrameIndex`：
```haxe
frameIndex = firstFrame + (index - frameIndex);   // index=父时间线当前帧, frameIndex=关键帧起点
final lastIndex = libraryItem.timeline.frameCount - 1;
final hasLastFrame = (lastFrame > -1);            // ← lastFrame 来自 JSON 的 LF
final doWrap = hasLastFrame && (lastFrame < firstFrame);
final length = (doWrap ? lastIndex : (hasLastFrame ? min(lastFrame,lastIndex) : lastIndex)) - firstFrame + 1;
switch (loopType) {
    case LOOP:      ... wrap(frameIndex, 0, lastIndex) / doWrap 分支
    case PLAY_ONCE: frameIndex = min(frameIndex - firstFrame, totalLength - 1);
    case SINGLE_FRAME: return firstFrame;
}
```
`this.lastFrame = data.LF;` —— `lastFrame` 是 `Int` 字段，**JSON 没写 `LF` 时吃 null = 0**，
于是 `hasLastFrame` 成立、可用区间塌成 `[firstFrame, 0]` → **三种 loop 类型全部收敛到
firstFrame，零件恒显示它自己的第一帧**。零件的"动作"来自父时间线换关键帧 / 换 FF，
不是零件自己在播。

**移植端** `flxanimate/animate/FlxElement.hx:84 updateRender`：
```haxe
var curFF = curFrame + symbol.firstFrame;
curFF = switch (symbol.loop) {
    case Loop: curFF % length;                 // ← 按整符号长度取模
    case PlayOnce: bound(curFF, 0, length-1);
    default: symbol.firstFrame;
};
```
不解析 `LF`（`fromJSONEx` 只读 `FF`），于是无 `LF` 的零件被当成"整符号循环"：
父帧每走一步，零件就漂到下一帧 —— 漂到**别的姿势的帧**上，就是手/剑/护目镜/爱心错乱；
末关键帧 `DU` 大（whitedk `idle_w` 末帧 I=8 DU=6）时零件相对帧走 0..5，表现为"最后一帧错位"。

### 数据证据

- 全量扫 `content/NMVMODS/{legacy,securitydlc}/images` 下 **112 个 `Animation.json`**：
  **带 `LF` 的元素 = 0**。
- whitedk 实例：符号 `idle_w` 5 个关键帧（I=0/2/4/6/8，DU=2/2/2/2/6），
  零件 `knife`(7 帧) / `mic hand`(5 帧) 均无 `FF`/`LP` → 参考引擎恒显示第 0 帧；
  移植端在末关键帧播 0..5，正是用户看到的错位。
- 根符号 `!!!!` 的层 1：`('idle_w', FF=0, LP=LP)`，即姿势切换由父时间线驱动，
  与"零件自身不动"一致。

## 3. 已落修复

`source/flxanimate/PsychFlxAnimate.hx`：

- `updateAnimation`：`anim.update(elapsed)` 之后调用 `freezePartFrames(...)`。
- `freezePartFrames(params, frame, depth)`：从当前动画的实例出发递归整棵符号树，
  对每个嵌套元素把 `SymbolParameters._curFrame` 钉回它的 `firstFrame`
  （越界夹到 `symbol.length-1`，深度上限 16 防环）。
  因为语料 0 个 `LF`，这与参考引擎"区间塌成一帧"的结果完全等价；
  同时覆盖 `Loop` / `PlayOnce` / `SingleFrame` / 缺省四种情况（都收敛到 firstFrame）。

风险面：只影响**嵌套元素**的帧，动画本身（wrapper 播放头）仍由 `anim.update` 推进；
`addBySymbolIndices` 包装符号每关键帧只有一个元素且 `firstFrame` = 源帧号，钉住即正确。

## 4. alt 动画缺失 — 排查结论（不是引擎丢的）

- 原版内容包 `D:/VS IMPOSTOR LEGACY 1.1.2/assets/data/characters` 对照：
  `white` / `chefogus` / `bfsauce` / `chefplayable` **本来就只有 `singUP-alt` + `singDOWN-alt`**；
  `black` / `blue-ow` / `charles` / `detective` / `horsemate` / `powers` / `ziffytorture`
  是 4 个；`maroonplayable` / `pinkplayable` / `minigrey` **一个 alt 都没有**。
  → 用户看到"只有 Up/Down"的角色属于**内容事实**，移植端没有丢。
- 引擎侧只有一处语义差异（不是缺失）：FE 的 `isAlt = section.altAnim && !gottaHitNote`
  只给**对手侧**加 `-alt`；NMV 是 note 级（`PlayState:1617` 给整段 note 设
  `noteType='Alt Animation'` → 两侧都带 `-alt`）。要不要对齐待定：改成两侧会让
  没有 alt 的角色（BF 侧）在该段唱不出动画。

## 5. 下一批候选（按优先级）

1. **共享符号的多实例**：`SymbolParameters._curFrame` 是**每个元素实例**自己的字段，
   本端不存在共享播放头问题；但如果实测仍有"同一零件在不同位置显示不同帧"的需求，
   就得把帧计算搬到 draw（每个实例各自算），即真正接管渲染。
2. **`reverse`（`LP` 带 `R`）**：Dot-Stuff 解析了 `reverse` 但 `updateRender` 没用；
   NMV 也没有反向播放路径 —— 语料若确有 `LPR` 需要单独核。
3. **`LF` 真要支持**：只能在 `PsychFlxAnimate` 里按 JSON 建旁表（`FlxElement → lastFrame`），
   再在 `freezePartFrames` 里按 `firstFrame..lastFrame` 收敛。当前语料用不上。

## 6. 验证方法

1. `haxe export/release/windows/haxe/release.hxml --no-output`（已过）。
2. 关游戏 → `haxelib run lime build windows -release`。
3. 重点看：whitedk idle 末帧、maroon singDOWN、grey idle、pink 全套、chefogus 护目镜。
4. 若某个角色反而变"僵"（零件该动却不动），说明该图集有 `LF` 或依赖零件自播，
   去 `Animation.json` 查该元素的 `LF`/`LP`，再决定是否放宽冻结条件。
