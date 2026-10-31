# 62 · blend 改走实时混合（去烘焙）+ 锚点离线核对工具 — 2026-10-31 深夜 会话 h

> 承接 61 号。用户实测反馈：**white 普通版还是有烘焙问题**、**maroon 存在部分偏移**。
> 这一轮把 blend 从"烘焙后整块贴回"改成"沿绘制树实时传 blend"（对位参考引擎），
> 并补了一个锚点离线核对脚本，把 maroon 的锚点数值钉死在数据层面。

## 0. 一句话

带混合的符号此前被 Dot-Stuff 判成 `cacheAsBitmap` → 渲到离屏 camera 再整块贴回。
这条烘焙路径在 NMV 的 MC 零件上会错位/糊边（white 的 halo/mic hand、maroonParasite 的
器官都是 `B=12`），所以**光把 `SI.B` 数字改成合法名不够** —— 还得让它别烘焙。
现在 blend 由 `parseElement` 沿绘制树往下传，逐元素实时混合。

## 1. 根因链（补完 61 号第 2 条）

61 号只做了"数字 → 合法 BlendMode 名"。但 Dot-Stuff 的 `get_cacheAsBitmap()` 是：

```haxe
if (filters != null && filters.length > 0 || blendMode != NORMAL) return true;
```

名字一旦合法，`blendMode != NORMAL` 就成立 → **该符号一定走烘焙**：

1. `FlxAnimate.parseElement` 的 `cacheToBitmap` 分支把整个符号渲到自己的
   filterCamera（`new FlxCamera(0,0,0,0,1)`，尺寸 0×0）；
2. `renderFilter` 用 `canvas.getBounds` 取内容矩形 → 建 1.25× 边距的 bitmap → 抓像素；
3. 回贴时用 `_filterMatrix` 定位 + `drawLimb(..., symbol.blendMode, ...)`。

问题：
- 烘焙矩阵是按"内容矩形"重建的，MC 零件的锚点/缩放一偏就整体错位（maroon 的
  "部分偏移"）；
- 混叠边被 1.25× 拉伸后糊边（white 普通版"还是有烘焙问题"）；
- 混合只作用于整块矩形，父级 blend 无法继承（参考引擎是继承的）。

参考引擎（MaybeMaru）**根本不烘焙**：`Blend.resolve(this.blend, blend)` 把混合
当参数沿 `Timeline.draw → Frame.draw → element.draw` 一路传，最后落到
`camera.drawPixels(..., blend, ...)`。

## 2. 改动

### 2.1 库补丁（**改的是 haxelib 全局库**，务必看 §4）

`docs/nmv-port-plan/patches/flxanimate-blend-nobake.patch`（2 文件 +25/-6）：

| 文件 | 改动 |
|---|---|
| `flxanimate/animate/SymbolParameters.hx` | 新增 `public var blendNoBake:Bool = false`；`get_cacheAsBitmap()` 改成 `(blendMode != NORMAL && !blendNoBake)` |
| `flxanimate/FlxAnimate.hx` | `parseElement(..., ?blend)` 新增第 7 参；进函数先算 `elemBlend`（自身非 NORMAL 覆盖，否则继承父级；`filterin` 烘焙渲染时强制 null 防双重混合）；`renderLayer(..., ?blend)` 透传；位图分支改 `drawLimb(..., filterin, elemBlend, null, cameras)`（顺手修了原调用把 `cameras` 塞进 `blendMode` 位置的错位） |

默认 `blendNoBake = false` → **其他项目行为不变**，只有 NMV 内容打开。

### 2.2 `source/flxanimate/PsychFlxAnimate.hx`

`applyNmvAtlasSemantics()` 第 ② 步：数字 → 合法名之后，`name != 'normal'` 时置
`params.blendNoBake = true`。

### 2.3 语料事实（全 112 个 Animation.json）

| 项 | 数量 |
|---|---|
| 带非 normal blend 的元素 | **1790**，全部是 `ST=MC` |
| `B=0`(ADD) | 1159 |
| `B=7`(LAYER) | 375（映射成 normal） |
| `B=12`(SCREEN) | 135 |
| `B=8`(LIGHTEN) | 64 |
| `B=9`(MULTIPLY) | 33 |
| `B=14`(SUBTRACT) | 16 |
| `B=3`(DIFFERENCE) | 8 |
| **G 元素带 blend** | **0**（所以 `set_blendMode` 对 Graphic 强制 NORMAL 不影响语料） |

## 3. maroon 偏移：锚点算法已被证伪为"不是问题"

新增 `docs/nmv-port-plan/scripts/anchor-probe.py`：把 `NmvAtlasAnchor` 的包围盒算法
逐行复刻成 Python（Clipper/Clipped 求交、嵌套符号按 FF/LP 取帧、MC 钉 0），
可以直接拿图集目录算 anchor，不需要构建。

核对 `securitydlc/.../maroonthreat`（运行时 `nmv bounds` vs 离线）：

| 符号 | 运行时日志 | anchor-probe |
|---|---|---|
| idle | x=-75 y=-95 w=730 | x=-75.8 y=-95.1 w=730.1 |
| up | x=-1193 y=-262 w=943 h=519 | x=-1193.9 y=-262.3 w=943.1 h=519.6 |
| left | x=605 y=-47 w=654 h=592 | x=605.8 y=-47.1 w=654.5 h=592.3 |
| right | x=30 y=-147 w=735 h=539 | x=30.9 y=-147.6 w=735.0 h=539.8 |
| down | x=-71 y=-139 w=778 h=503 | x=-71.4 y=-139.9 w=778.7 h=503.9 |

**逐项吻合到整数**。说明：
- 运行时算的 anchor 与数据 100% 自洽，不是"算错"；
- maroon 各动画的 anchor 差异（-1193 ↔ 605）是**资源本身的摆放差异**（Animate 里
  每个姿势符号独立摆放），参考引擎同样按各自包围盒平移；
- 所以"部分偏移"要么是**渲染层**（MC 钉 0 后某个零件本身位置不对 / 烘焙错位），
  要么是 **offset 应用方式**（flipX、scale、origin 顺序），不是 anchor 数值。

**下一步定位需要一条信息**：maroon 偏的是"整个角色位置"还是"某个零件"（哪首歌、
哪个动画）。若整体偏，优先查 flipX 与 scale；若零件偏，优先查该零件的 `ST`/`FF`。

## 4. 库补丁的维护（重要）

补丁打在 `E:/HaxeToolkit/haxe/lib/flxanimate/git`（Dot-Stuff/flxanimate，master）。
**`haxelib update flxanimate` 会覆盖掉**。恢复方式：

```bash
cd E:/HaxeToolkit/haxe/lib/flxanimate/git
git apply --check ../../../../J:/FrozenEngine-NMV-ScriptAPI-Port/docs/nmv-port-plan/patches/flxanimate-blend-nobake.patch
git apply <上面的 patch>
```

（路径按实际调整；补丁只加可选参数 + 默认 false 的开关，不会影响其他项目。）

## 5. 验证

```bash
# 类型检查（项目根，15s 左右；注意 hxml 里 -cp 是相对路径，副本必须放项目根）
cp export/release/windows/haxe/release.hxml ./_nmvcheck.hxml && echo "--no-output" >> _nmvcheck.hxml
haxe _nmvcheck.hxml
```

本轮 `haxe _nmvcheck.hxml` 通过（exit=0）。**构建/实机仍由用户做。**

## 6. 待实测

1. white 普通版（Oversight，`char[white]`，符号前缀 `!!!`）的 halo / mic hand 是否恢复
   正常发光混合、不再有烘焙糊边。
2. maroonParasite 的 `B=12` 器官是否不再错位。
3. 若 white 正常、maroon 仍偏 → 按 §3 最后一段给一条现象描述，再定位。
