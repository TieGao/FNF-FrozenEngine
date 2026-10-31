# 交接：角色零件错乱的真正根因（MC 元素 + 逐元素混合）— 2026-10-31 深夜 会话 g 二批

> 承接 60 号文档。上一轮把「零件错位」当成帧公式问题（错），这一轮从**参考引擎的元素类型**
> 找到真因，并用离线光栅化逐帧验证。

## 0. 一句话

参考引擎里 `SI.ST == "MC"` 的零件实例**恒显示自身第 0 帧**（`MovieClipInstance.getFrameIndex`
在 `swfMode=false` 时直接 `return 0`），移植端用的 Dot-Stuff flxanimate 没这个区分、
一律让零件跟着父时间线推进 —— 于是所有「手/刀/护目镜/光环」都在漂到别的姿势帧上。

## 1. 证据链（代码 + 数据 + 像素）

**代码**（`D:/NightmareVision/.haxelib/flixel-animate/git/src/animate/`）：

| 位置 | 内容 |
|---|---|
| `internal/Frame.hx:225` | `switch (si.ST) { case "B": ButtonInstance; case "MC": MovieClipInstance; default: SymbolInstance; }` |
| `internal/elements/MovieClipInstance.hx` | `override function getFrameIndex(index, frameIndex=0) return swfMode ? super.getFrameIndex(...) : 0;` |
| `internal/elements/ButtonInstance.hx` | `return FlxMath.minInt(curButtonState, timeline.frameCount-1)` |
| `Source 侧` | 全仓 grep `swfMode` **零命中**；`FunkinSprite.loadAtlas` 只传 `{cacheOnLoad:true}` → swfMode 恒 false |

**数据**（112 个 NMV Animation.json）：

- 元素类型分布 `G: 22388 / MC: 6504`（whitedk 70、maroon 102、chefogus 154、pink 63、grey 42
  —— 正好是用户点名的角色）。
- **MC 元素的 `FF`/`LP` 恒为空**，`G` 元素才带 `FF`/`LP`（grey: `mic hand`/`knife hand` 是 MC 无 FF，
  `impostorvisor` 是 G 且逐关键帧 FF=2/0/1）——**作者在 Animate 里根本没给 MC 设过帧**，
  因为 MC 在编辑器里就只显示第一帧。这条数据特征本身就是"该钉 0"的铁证。

**像素**（`docs/nmv-port-plan/scripts/anim-render-probe.py`）：

```
whitedk idle 14 帧
  旧行为（零件推进）：末 2 帧刀突然翻起、光环离开头顶、mic hand 回绕到 20 号 limb
  新规则（MC 钉 0）：光环稳稳在头上、刀不动、只有矩阵带来的轻微摇摆 —— 干净的 idle
```

## 2. 第二个根因：逐元素混合模式（颜色"红+黄"）

BTA 导出把混合写成整数 `SI.B`，语义见 `animate/internal/filters/Blend.hx:fromInt`：
`0=ADD 1=ALPHA 2=DARKEN 3=DIFFERENCE 4=ERASE 5=HARDLIGHT 6=INVERT 7=LAYER 8=LIGHTEN
9=MULTIPLY 10=NORMAL 11=OVERLAY 12=SCREEN 13=SHADER 14=SUBTRACT`。

Dot-Stuff 的 `FlxElement.fromJSONEx` 把它**原样赋给 `SymbolParameters.blendMode:BlendMode`**
（字符串抽象）→ 字段里躺着 `"8"`/`"12"` 这类非法值 → `blendMode != NORMAL` 成立 →
该元素被判成 `cacheAsBitmap` 走烘焙路径，真正画的时候又因为名字非法而**没应用混合**。

数据：全语料非 normal 混合 **1680 个**（ADD 1084 / LAYER 375 / SCREEN 129 / LIGHTEN 64 /
MULTIPLY 21 / NORMAL 7）。white 的 `halo` = `B=8`(LIGHTEN)、`mic hand`/`down mic`/`up mic`/
`right mic`/`mic hand copy` = `B=12`(SCREEN) —— 少了这层混合，红+黄的原始两层画直接露出来，
正是用户报的"光环有红有黄、手也有黄有红"。

## 3. 改动

`source/flxanimate/PsychFlxAnimate.hx` 新增 `applyNmvAtlasSemantics()`：

1. MC/Button 实例 → `loop = SingleFrame` + `firstFrame = 0`
   （必须 `@:bypassAccessor`：`set_loop` 对 `type==MovieClip` 强制改回 Loop，
   `set_firstFrame` 只对 `Graphic` 生效），让 `FlxElement.updateRender` 的
   `default: symbol.firstFrame` 分支接管 → 恒第 0 帧。
2. `SI.B` 数字 → 合法 `BlendMode` 名（LAYER/SHADER 归 NORMAL，openfl 里 LAYER 是容器语义）。

调用点：`loadAtlasEx` 末尾、`addExtraAtlas` 末尾（各一次，只扫符号表，开销一次性）。
作用域：**只对 NMV 内容**（`NMVContentData.currentMod != null` 或 `currentContentRoot`
含 `NMVMODS`），FE 自家 Animate 图集维持原行为。
面包屑：`nmv atlas semantics [<root符号>] mcPinned=N blend=M`。

## 4. 还没验证/待观察

1. **混合模式是否真的生效**：`parseElement` 只在 `cacheAsBitmap` 分支里
   `drawLimb(..., symbol.blendMode, ...)`。字段名合法之后这一支应该开始真正混合；
   若实测仍不对，下一步是把 `parseElement` 的普通分支也补 blend（需要
   `@:access` 复制该私有方法，成本高，先不动）。
2. **LAYER(7) 375 个**：NMV 会传给 draw，但 openfl 的 LAYER 不是逐元素混合，这里映射成
   NORMAL；若某些角色因此少一层效果，再单独看。
3. `B=0`(ADD) 1084 个元素：改动前它们已经因为非法值走了烘焙路径，改动只是把名字改对，
   路径不变，风险中性。

## 5. 工具

```bash
# 逐帧推演零件帧（已按 MC 规则）
python docs/nmv-port-plan/scripts/anim-frame-probe.py <图集目录> '!!!!' 0 13 'knife'

# 直接渲染成 PNG / 拼图看像素（--pin-bits 只钉 G，--no-nmv-mc 回到旧行为）
python docs/nmv-port-plan/scripts/anim-render-probe.py <图集目录> \
    --anim idle --char <角色json> --out /tmp/x --scale 0.35
```

两个脚本都不需要构建、不需要开游戏；**改动画语义前先跑它们**。
