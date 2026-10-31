# 交接：角色动画冻结事故的回退与修复 — 2026-10-31 夜（会话 g）

> 用户实测反馈："改坏了很多东西……**所有角色动画现在都只剩 1 帧了**（不是全部，但大部分）。
> 仔细看上一轮改了啥。" 本文档记录定位过程、回退了什么、保留了什么、还欠什么。

## 0. 一句话结论

上一轮（22:13）在 `PsychFlxAnimate.updateAnimation` 里加的 **`freezePartFrames` 把每个
嵌套零件（手/刀/护目镜…）的帧钉死在 firstFrame**，于是角色只剩一个姿势、动画看着像 1 帧。
**该逻辑已整段删除**，"零件帧语义与参考引擎不同"这个前提本身是错的（见 §2 证据）。

## 1. 事故现场与证据链

- 用户测试的构建：`export/release/windows/bin/FrozenEngine.exe` 22:51（含 22:13 的改动），
  运行日志 `crash/bread.log` 22:52–22:53（reactor / sussus-toogus 两首）。
- 症状：动画"只剩 1 帧"，但角色位置/朝向正常、脚本无新报错 → 不是播放头没走，是**每帧算出来
  的帧都一样**。
- 机制：`freezePartFrames` 每帧把整棵符号树的 `element.symbol._curFrame` 重设成
  `firstFrame`。角色的实际动作全在嵌套符号里（根时间线的关键帧只是"姿势切换"），
  钉死后整条动画变成一个静止姿势。
- 离线复现（新增工具，见 §5）：
  ```
  python docs/nmv-port-plan/scripts/anim-frame-probe.py <whitedk 图集> '!!!!' 0 13 'knife' 'mic hand'
  #   frame 0..13: knife@0,1,0,1,… 2,3,4,5   ← 正常：零件帧在变
  #   加 --freeze: knife@0 0 0 0 …           ← 事故版：恒定
  ```

## 2. 根因：交接文档 59 号的立论是错的（代码级反证）

59 号文档认为"参考引擎缺 `LF` 时 `lastFrame` 吃 null = 0，区间塌成一帧，所以零件恒显示
firstFrame"。实际读 NMV 依赖的 flixel-animate 源码：

```haxe
// D:/NightmareVision/.haxelib/flixel-animate/git/src/animate/FlxAnimateJson.hx:190
public var LF(get, never):Int;
extern inline function get_LF()
    return this.LF ?? this.lastFrame ?? -1;      // ← 缺省 -1，不是 0

// .../animate/internal/elements/SymbolInstance.hx:105
final hasLastFrame:Bool = (lastFrame > -1);     // ← 缺省 false
```

`hasLastFrame == false` 时走 `FlxMath.wrap(firstFrame + 相对帧, 0, 符号总帧-1)`；
移植端 Dot-Stuff 是 `(相对帧 + firstFrame) % symbol.length`，而
`FlxSymbol.length == timeline.totalFrames`（`FlxSymbol.hx:404`）—— **两边数学等价**。
语料里"0 个元素带 LF"恰好说明零件就该跟着父时间线走。

另外核对了关键帧分发（`FlxKeyFrame.updateRender` 传 `curFrame - index`、
`FlxLayer._get` 取第一个 `index+duration > frame` 的关键帧）与 NMV
（`Frame.draw → element.draw(camera, currentFrame, this.index)`）也一致。

## 3. 本轮改了什么（3 处，全部过类型检查）

### 3.1 删除 freezePartFrames（回退，核心）

`source/flxanimate/PsychFlxAnimate.hx`

- 删掉 `freezePartFrames(...)` 函数与 `updateAnimation` 里的调用。
- `updateAnimation` 保留"两条播放头各推各的"，并把事故原因写进注释（避免下一轮再"修"一次）：
  ```haxe
  override function updateAnimation(elapsed:Float):Void
  {
      if (anim != null && anim.curInstance != null && anim.curSymbol != null) { anim.update(elapsed); return; }
      if (allowPlainDraw && animation != null) animation.update(elapsed);   // sparrow 路径
  }
  ```

### 3.2 修 sparrow 播放头（上一轮没修对的地方）

上一轮的 `if (allowPlainDraw) super.updateAnimation(elapsed);` **不推进标准控制器**——
`super` 是 `FlxAnimate.updateAnimation`，实现是 `anim.update(elapsed)`，标准
`animation` 控制器照样不动。改为直接 `animation.update(elapsed)`。
（这就是"reactor 大球已显示但动画不推进"的另一半原因。）

### 3.3 修 reactor:50 的空指针（长期未解，本轮找到）

`source/nmv/objects/FunkinSprite.hx` `addSparrowAnim`：
纯 Sparrow 图集没有 Animation.json → `anim.symbolDictionary` 仍是 **null**
（`FlxAnim` 只在 `_loadAtlas` 里初始化它），而 `addSparrowAnim` 直接
`anim.symbolDictionary.set(...)` → 裸 NPE。

```haxe
if (anim.symbolDictionary == null) anim.symbolDictionary = [];
```

后果链：`reactor.hx:50 coreGlow.addAnimByPrefix('bop','reactor core',…)` 每次进歌必炸 →
`onLoad` 后半段（coreRing / coreClaw / overlay）全不建 → 大球"显示但不动"、
运镜相关对象缺失。同一处也补了 `PsychFlxAnimate.addExtraAtlas` 的 sparrow 分支。

> 备注：`crash/bread.log` 显示 `reactor:50 Null Object Reference` 从 10-30 22:34 就在，
> 与上一轮改动无关；本轮顺手修掉。

### 3.4 `Note.player` 语义只对 NMV 内容生效

`source/states/PlayState.hx`：上一轮把 `note.player` 全局改成 NMV 绝对车道（0=玩家侧），
FE 自家谱面/老模组读它一直是 `mustPress?1:0`，会被反。改为
`backend.NMVContentData.currentMod != null` 时才用 NMV 语义。

## 4. 明确**保留**的上一轮改动（没有回退，理由）

| 改动 | 保留理由 |
|---|---|
| `safeAddBySymbolIndices` 字典键 `@源符号@动画` | Dot-Stuff `addBySymbol` 是**前缀匹配**（`FlxAnim.hx:471 startsWith`），旧键 `<源符号>#<动画>` 会被当成源符号候选，Map 顺序一变就串台。真 bug，修得对 |
| 角色动画注册优先级改为 帧标签→符号→前缀 | 与 NMV `FunkinSprite.addAnimByPrefix:223` 一致；`addFromFrameLabel` 的 `getFrameIndices()`（`FlxKeyFrame.hx`）与 NMV `Timeline.findFrameLabelIndices` 同义 |
| 逐动画包围盒锚点（`nmv.utils.NmvAtlasAnchor`） | NMV `FlxAnimate.draw` 确实 `matrix.translate(-timeline._bounds.x, -bounds.y)`，而 timeline 随动画切换 → 逐符号锚点是对的；`bread.log` 的 `nmv bounds …` 可核 |
| reactor/redmungus/walkers/finale 血条/PetStub 单例/GameOver 音效 等会话 f 修复 | 都是上一轮**修 bug** 的改动，与动画冻结无关 |
| `RGBPalette` attribute→uniform | 只影响 NMV 脚本自建 shader（`nmv.shaders`），FE 的 Note 用的是 `shaders.RGBPalette`，互不影响 |

## 5. 新增工具：`docs/nmv-port-plan/scripts/anim-frame-probe.py`

离线推演任意 NMV 图集"每帧每个零件显示第几帧"，不需要构建/开游戏。
改动画帧语义、怀疑零件错位时**先跑它**，别靠肉眼比对或猜参考引擎行为。

```bash
python docs/nmv-port-plan/scripts/anim-frame-probe.py \
    export/release/windows/bin/content/NMVMODS/legacy/images/characters/story/white/whitedk \
    '!!!!' 0 13 'knife' 'mic hand'
# 末尾加 --freeze 可复现事故版本
```

## 6. 用户原报的"零件错位"仍未定论（重要）

用上面的工具核对 whitedk idle：`knife` 在最后一段关键帧（I=8 DU=6）走 0→5 帧、
`mic hand`（5 帧）走 0→4 后**在最后一帧回绕到 0**（limb 22 → 20）。这在 NMV 里
也是同一结果（两边取模等价），说明"最后一帧错位"要么是**数据本身的回绕**，
要么来自整体锚点而不是零件帧。下一轮排查建议：

1. 先在 NMV 本体（`D:/NightmareVision`）跑同一首歌同一角色，确认是否也有该回绕；
2. 用 `nmv off <角色> <动画>` 面包屑核对整体偏移是否与 NMV 实际位置差一个 bbox；
3. **不要再动 `FlxElement`/`updateRender` 的帧公式**——两边已证明等价。

## 7. 验证清单

1. `haxe <release.hxml 副本> --no-output` —— 已过（本次）。
2. 关游戏 → `haxelib run lime build windows -release`。
3. 重点看：
   - whitedk / maroon / pink / grey / chefogus 的 idle 与 sing 是否**重新动起来**（本轮主症）；
   - reactor：大球 coreGlow 是否转、coreRing/coreClaw/overlay 是否出现（3.3）；
   - sussus toogus 的 walkers 走路动画（上一轮修的重叠改动，未被本轮回退）。
4. 若仍有脚本报错，看 `crash/bread.log` 的 `HS ERROR 脚本:行号`。
