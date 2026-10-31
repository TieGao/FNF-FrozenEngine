# 交接：角色组（偏移 / 图集注册 / 零件）— 2026-10-31

> 新对话从这里接手。**只做通用修复，不对单**（不写 `if (curCharacter == 'xxx')`）。
> 只做类型检查，构建由 zcode 负责；别人文件的语法错误不修。

## 0. 一句话现状

角色偏移已从"运行时采样"改成"确定性包围盒"，并把注册优先级、遮罩语义对齐到 NMV。
`white` / `whitedk` 的"到处飘"已定位并修（注册优先级反了）；`whitedk` 末尾扭曲有机制解释但未动渲染。

## 1. 我改过的文件（这三个是我的地盘）

| 文件 | 内容 |
|---|---|
| `source/nmv/utils/NmvAtlasAnchor.hx` | **新增**。MaybeMaru `Timeline.getWholeBounds` 的逐行移植：按符号算整条时间线包围盒，带遮罩语义、跨实例缓存、`nmv bounds` 面包屑 |
| `source/objects/Character.hx` | `nmvApplyOffset`（offset 公式）、图集动画注册链、`healthColorArray` 回退、`nmv off` / `bind` / `FAILED` 面包屑 |
| `source/flxanimate/PsychFlxAnimate.hx` | `safeAddBySymbolIndices` 返回 `Bool`；包装符号字典键 `@<源符号>@<动画>` |

删掉的旧实现：`source/nmv/utils/NmvAtlasBounds.hx`（已删，git 里没有）。

**别碰**（zcode 的地盘）：`PlayHUDShim` / `Song` / `ClientPrefs` / `InterpEx` / `StageData` /
`CoolUtil` / `Note` / `PresetFnf` / `ModManagerCompat` / `AmongWalker` / `NmvBatchState`。

## 2. 已实现的规则（都对齐参考引擎代码，不是拟合）

1. **包围盒**：动画 → 实际播放符号 → 该符号**整条时间线**的包围盒（符号坐标系）。
   NMV 三条注册 API 都 `anim.timeline = symbol.timeline`（`FlxAnimateController:222/255`），
   indices / 帧标签只决定播哪几帧，**不影响 `_bounds`**。
2. **遮罩**：Clipper 层不进包围盒；Clipped 层与遮罩层求交（`Timeline.getBounds` + `Frame.getBounds`）。
3. **偏移**：`offset = json偏移 + (bx - 翻转?bw:0, by - flipY?bh:0)`，**不乘 scale**。
   依据：openfl `Matrix.translate` 是裸加（`tx += dx`）、`scale` 不动 tx → 锚在屏幕空间。
   翻转项来自 MaybeMaru `scale(-1,1); translate(bounds.width,0)`。
4. **注册优先级**：`indices → 帧标签 → 精确符号 → 标签兜底 → 前缀`，每级失败往下掉。
   NMV `addAnimByPrefix` 是**帧标签优先**；`indices` 排第一是因为 gf 的 danceLeft/danceRight
   靠 indices 切分同一符号。
5. **包装符号**：字典键 `@<源符号>@<动画>`。不能以源符号名开头 —— Dot-Stuff 的 `addBySymbol`
   是"遍历字典键做前缀匹配取第一个"，会被包装键污染（播放串台 + 零件混用）。
6. **血条颜色**：`healthbar_colors`（数组）只有 23/162 个角色有，其余只写单值
   `healthbar_colour`（ARGB int）→ 数组缺省时从单值拆 RGB。

## 3. 已知未解决（按优先级）

| # | 问题 | 现状 / 下一步 |
|---|---|---|
| 1 | `whitedk` idle 末几帧扭曲 | **机制已确认**：`idle_w` 末关键帧 `I=8 DU=6`，零件（knife/mic hand/idle bod）无 FF/LP → Loop，相对帧 0..5 推进到"别的姿势的帧"（knife 143×197→192×289、halo 302×185→373×344）。两库公式一致（`firstFrame + (帧号-关键帧起点)`），**Animate 本体是循环零件播放头连续走、不按关键帧重置**。要复现需接管渲染（把嵌套帧改成绝对帧），未动 |
| 2 | ejected 三者偏下 | 三者都是 `exact` 注册、锚点已是原值 → 不是偏移链路。`camFollow = dad.getMidpoint()+150,-100+camPos`，图集角色 `width/height` 两引擎都是 0（`updateHitbox` 只在加载时调）→ 疑舞台镜头/站位 |
| 3 | suspect 的 pico 整体偏左 | 锚点很小（`idle -12,-1`）；`positionArray` 只应用一次（`startCharacterPos`，同 NMV `CharacterGroup.startPos`）→ 舞台基准位置 |
| 4 | 翻转角色（`whitemad`/`noob49`/`detective`/`pip_evil`/bf 当对手） | `-bw` 项是推导值，**从未实测验证**。`nmv off ... bw=<宽>` 可直接对账：偏≈`bw` → 去掉该项；偏≈2×`bw` → 方向反了 |
| 5 | 血条/小图标色彩 | `healthColorArray` 已从单值 `healthbar_colour` 回退（168/192 个角色只写单值）；血条颜色改成 `update` 里**变更检测**（脚本直接换 dad/bf 时也刷新）。面包屑 `hud bar colors dad=..:r,g,b bf=..:r,g,b` 可核对。图标本身两引擎都**没有 tint 逻辑** |
| 6 | 194/1042 个动画从符号切到帧标签 | 这是 NMV 语义（charles / doubleTrouble / picoweird / maroonplayable* / pinkplayable 等）。若变差**按规则排查**（标签段是否覆盖整个姿势、标签是否在根时间线、符号与标签帧数是否一致），不开白名单 |

## 4. 工具与验证方法

- **离线复算**：`J:/tmp/nmv_bounds_probe.py`（可删可重建）。读 `Animation.json` + `spritemap*.json`
  复算包围盒，支持 `MX` 与 `M3D` 两种矩阵（`matof()`）。用法：
  `python /j/tmp/nmv_bounds_probe.py <图集目录> "符号名" ...`
  已用它验证：bf idle `288,-207` / gf danceRight `-149,-334` / red idle `101,431`
  —— 与 10-30 23:13 实测正确值吻合。
- **类型检查**：`haxe export/release/windows/haxe/release.hxml --no-output`（约 15s，无输出即过）。
  别人的文件坏了会挡住检查：把 `source` 复制到 `J:/tmp/tc/source`，hxml 副本里把 `-cp source`
  换成 `-cp J:/tmp/tc/source`，只改副本。
- **运行日志**：`export/release/windows/bin/crash/bread.log`。看这几类行：
  - `nmv bounds <图集>|<符号> via=<动画> frames=<n> x= y= w= h=`
  - `nmv off <角色> <动画> flip= bw= json= anchor= -> offset=`
  - `char[x] anim y -> ...`（分支）、`char[x] bind <动画> -> <符号>`、`char[x] anim y FAILED name=z`
- **内容包**：`export/release/windows/bin/content/NMVMODS/{legacy,securitydlc}`（106 个图集）。
- **参考源码**：NMV = `/d/NightmareVision/.haxelib/flixel-animate/git/src/animate/`；
  本端 = `E:/HaxeToolkit/haxe/lib/flxanimate/git/flxanimate/`。

## 5. 关键源码坐标（省得重新翻）

```
MaybeMaru:
  FlxAnimate.hx:205  drawAnimate → matrix.translate(-bounds.x,-bounds.y)
  FlxAnimate.hx:251  prepareAnimateMatrix → scale(-1,1); translate(bounds.width,0)
  FlxAnimateController.hx:285  _animate.timeline = curAnim.timeline（按动画切时间线）
  FlxAnimateController.hx:222/255  addBySymbol/Indices → anim.timeline = symbol.timeline
  internal/Timeline.hx:203  getWholeBounds / :244 getBounds / :367 _bounds = getWholeBounds()
  internal/Frame.hx:210  _loadJson（index = FR.I）
  internal/Layer.hx:51  getFrameAtIndex（frameIndices 是"位置重复 DU 次"）
  internal/elements/SymbolInstance.hx:100  getFrameIndex = firstFrame + (index - frameIndex)
Dot-Stuff:
  flxanimate/FlxAnimate.hx:213 draw / :633 drawLimb（offset 在屏幕空间减）
  flxanimate/animate/FlxAnim.hx:274 play / :462 addBySymbol（前缀匹配取第一个）/ :514 addBySymbolIndices
  flxanimate/animate/FlxLayer.hx:146 get（keyframe.index+duration > f）
  flxanimate/animate/FlxKeyFrame.hx:113 updateRender（curFrame - index）
  flxanimate/animate/FlxElement.hx:119 fromJSON / :188 fromJSONEx（MX / M3D → FlxMatrix）
  flxanimate/animate/FlxSymbolDictionary.hx:60 addSymbol（键 = 目录/名）
```

## 6. 排障套路（下次遇到"某个角色不对"）

1. 先看 `bread.log` 的 `nmv bounds` / `nmv off` / `bind` —— 判断是**位置**（锚点）还是**内容**（符号/帧）。
2. 位置：拿 `nmv bounds` 的 `x/y/w/h` 和离线复算对一遍，确认包围盒本身对不对。
3. 内容：看 `bind` 出来的符号是不是预期那个；再对照 json 的 `name` 在根时间线里有没有同名帧标签。
4. 零件级（手/护目镜/组件）：查该零件符号的 `FF/LF/LP` 与所属关键帧的 `I/DU`，算相对帧落在哪一帧。
5. 结论落到"规则"上：注册路径、时间线、遮罩、帧语义、锚点公式 —— 不要落到角色名。
