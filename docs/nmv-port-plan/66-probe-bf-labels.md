# 66 · bf（identity-crisis）逐动作偏移：帧标签 / 符号 两条路径混用 — 2026-11-01 上午

> 用户："ejected 的 bf 在身份危机里对战 green 时，有的动作往左上偏有的不会，
> 绘制一下看是图集问题还是引擎问题。"（**不是** `greenEjected` / green 寄生虫）

## 1. 结论先行

**是"角色 json 配置"层面的问题，但可以在引擎侧安全修掉。**

`bf` → `characters/BOYFRIEND`（`flip_x=true`、`scale=1`、`position=[-12,342]`）。
它的动画注册在两条不同路径上混着走：

| 动画 | json `name` | 注册路径 | timeline | **锚点包围盒** |
|---|---|---|---|---|
| idle | `BF idle dance` | ③ 精确符号 | 子符号 | **x=288.2 y=-207.3** w=427.8 h=421.0 |
| singUP | `Up` | ② 帧标签 | 根符号 `BF ALL ANIMS` | x=0.0 y=-6.3 w=482.5 h=490.9 |
| singDOWN | `Down` | ② 帧标签 | 根符号 | x=-1.7 y=-1.9 w=391.7 h=377.9 |
| singLEFT | `Left` | ② 帧标签 | 根符号 | x=285.6 y=-208.9 w=402.0 h=423.1 |
| singRIGHT | `Right` | ② 帧标签 | 根符号 | **x=337.0 y=-214.9** w=424.6 h=429.1 |

根符号 `BF ALL ANIMS` 上的帧标签是 **`Idle / Left / Left Miss / Right / Right Miss / Up / Up Miss / Down / Down Miss / Hey / Scared`**。
`bf.json` 里四条 sing 写的 `Up/Down/Left/Right` 正好是标签名 → 走帧标签（timeline = 根符号）；
而 idle 写的是**姿势符号名** `BF idle dance`，不是标签（标签叫 `Idle`）→ 掉进符号分支（timeline = 子符号）。

**两条路径的 timeline 不是同一条，包围盒差 288 / 207 像素**，锚点补偿只在 idle 上生效
→ **只有 idle 被额外平移**，其余四个唱姿不动。这就是"有的动作往左上偏有的不会"。

## 2. 为什么修在引擎侧是安全的

根符号 `BF ALL ANIMS` 的 `Layer_1` 第 0 帧（标签 `Idle`，`DU=14`）里，元素就是
**符号实例 `BF idle dance`** —— 也就是"根符号的 Idle 帧段"和"子符号"画的是同一份内容。

| 检查点 | 结果 |
|---|---|
| 帧数 | 根符号 `Idle` 标签 `DU=14`；子符号 `BF idle dance` 各层 5/3/5 帧 |
| 内容 | 根符号该帧段 = 一个 `SI` 引用 `BF idle dance` → 完全等价 |
| 包围盒 | 根符号 = 所有姿势并集（统一）→ 所有动作补偿一致 |

所以把 idle 拉回根符号帧标签，**画面不变、只是包围盒统一**。

## 3. 改动（**已于 2026-11-01 09:33 回退 —— 见 §3.1**）

> 用户实测："回退一下 bf 的改动，bf 本来是正常的。"
> 也就是说 §1 里那个 288/207 的包围盒差 **在 NMV 里同样存在**，是作者的正常配置，
> 不是 bug。下面这段作为"走过的弯路"保留，不要再应用。

### 3.1 回退说明

已从 `source/objects/Character.hx` 移除 `label-fallback`（`labelName` 变量 + `cands`
循环 + 面包屑），`addFromFrameLabel` 恢复传 `animName`。

**为什么当初判错**：我把"两条时间线的包围盒不同"直接当成"必然错位"，但参考引擎在
同一条 json 上走的是**同一套**判定（`findFrameLabelIndices(name)` 命中才走标签），
bf 的 `BF idle dance` 不命中标签 → 两端都走子符号 → **一致**。
`NmvAtlasAnchor` 忠实地按"实际播放的符号"取包围盒，所以结果也对。

真正有问题的是 `bf-fall`（ejected）：那里是**移植端自己的注册顺序**（indices 优先）
与 NMV（标签优先）不同，才导致两端分叉 —— 见 §7。

### 3.2 原始方案（已回退，仅供追溯）

### 3.2.1 原改动（历史）

在 `hasFrameLabel` 判定失败后，补一次"**用动画名（`anim` 字段）再查一次帧标签**"的回退，
大小写不敏感（`Idle` vs `idle`）：

```haxe
if (!hasFrameLabel) {
    var cands = [animAnim, capitalize(animAnim)];   // 'idle' -> 'Idle'
    for (cand in cands) if (atlas.anim.getFrameLabel(cand) != null) {
        hasFrameLabel = true; labelName = cand; break;
    }
}
// 之后 addFromFrameLabel 用 labelName，不再用 animName
```

命中时打一条面包屑：`char[bf] anim idle label-fallback BF idle dance -> Idle`。
无命中的角色完全不受影响（`labelName` 仍等于 `animName`）。

**为什么不去改内容包 json**：`bf.json` 是 `legacy` 包里所有歌共用的角色，
改资源会牵连全部曲目；而"name 不等于标签"是这批 NMV 导出的普遍现象，
在注册器里统一兜一层更合算。

## 4. 顺带确认：这不解释 maroonthreat

`maroonthreat` 的根符号 `master` **一个帧标签都没有** → 它所有动画本来就都走子符号路径，
逐动画包围盒（-75/-95、-1193/-262、605/-47…）是**两端一致**的正常行为。
所以 maroon 的漂移另有原因，仍靠 `nmv off` 面包屑里的 `origin` / `fw,fh` 定位（见 65 号 §4.2）。

## 5. 探针产物

`docs/nmv-port-plan/probe/greenEjected/` 里那批图是**误查对象**（green 寄生虫）时画的，
留作"包围盒全为 (0,0)"的反例，不代表 bf。

## 6. 待实测（**§1-3 部分已作废**，bf 保持原样）

1. ~~identity-crisis 里 bf 的 idle 是否回到同一基线~~ —— **作废，bf 本来正常，改动已回退**。
2. `bf-fall`（ejected）见 §7.5。
3. 其他用 `bf` 的歌无需再验证（行为与改动前完全一致）。

---

## 7. 补充（同一根因的另一半）：`bf-fall`（ejected）的 `-loop` 变体

用户纠正：ejected 用的是它自己特化的 bf —— 查证为 **`bf-fall`**
（`songs/ejected/data/normal.json` → `player1=bf-fall`、`player2=greenEjected`）。

### 7.1 日志证据（`crash/bread.log`）

```
nmv bounds characters/bf/bfFly|__BTA_TEMP_SPRITEMAP_PACKED_SYMBOL via=idle frames=351 x=-683 y=-506 w=1322 h=1012
nmv bounds characters/bf/bfFly|animations/right via=singRIGHT-loop frames=18 x=-20 y=-5 w=466 h=494
nmv off bf-fall singRIGHT  … bw=1322 json=-63,-5 anchor=-683,-506 -> -746,-511
nmv off bf-fall singRIGHT-loop … bw=466  json=-64,-5 anchor=-20,-5   -> -84,-10
```

**同一角色的两套动画走了两条不同的时间线**：

| 动画 | 实际符号 | frames | bounds |
|---|---|---|---|
| singLEFT / UP / DOWN / RIGHT（无 indices） | **主符号** `__BTA_TEMP_SPRITEMAP_PACKED_SYMBOL` | 351 | (-683,-506,1322,1012) |
| `*-loop`（json 带 3 个 indices） | **子符号** `animations/right` 等 | 18 | (-20,-5,466,494) |

锚点差 **663 / 501 像素** → 普通唱姿与 `-loop` 唱姿之间整体错开。
`bf-fall.json` 的 16 条动画里正好一半带 indices（`hey-loop`/`idle-loop`/`sing*-loop`），
所以表现就是"有的动作偏、有的不偏"。

### 7.2 为什么 NMV 不偏

NMV 的 `addAnimByIndices` 是**先帧标签、再符号**：

```haxe
if (library != null && anim.findFrameLabelIndices(prefix).length > 0)
    anim.addByFrameLabelIndices(name, prefix, indices, ...);   // timeline = 主符号
else
    anim.addBySymbolIndices(name, prefix, indices, ...);       // timeline = 子符号
```

`animations/right` 同时是主符号上的帧标签 → NMV 走前者，timeline 仍是主符号
→ bounds 与普通唱姿一致。

移植端为了 gf 的 `danceLeft/danceRight` 分段，把 indices 排在帧标签**前面**
（`safeAddBySymbolIndices` 第一优先级），于是 `-loop` 掉进子符号 → bounds 变小。

### 7.3 改动

**A. `source/flxanimate/PsychFlxAnimate.hx`**：`loadAtlasEx` 里记下主符号名

```haxe
nmvMainSymbol = haxelib... AN.SN 的末段;   // BTA 常见 __BTA_TEMP_SPRITEMAP_PACKED_SYMBOL
```
（`addExtraAtlas` 不覆盖它。）

**B. `source/nmv/utils/NmvAtlasAnchor.hx` · `resolveSymbol`**：包装符号拆回 base 之后，
再加一道"**标签优先**"判定 —— 若 `base` 同时是主符号的帧标签，返回**主符号**：

```haxe
final main = mainSymbolOf(atlas);
if (main != null && main != base && dict.exists(main) && isFrameLabel(atlas, base)) return main;
```

于是 `singRIGHT-loop` 也用主符号的 (1322×1012) 包围盒，与普通唱姿统一。

### 7.4 影响面

| 角色 | 主符号有帧标签？ | 行为 |
|---|---|---|
| `bf-fall`（ejected） | 有（`animations/*`） | `-loop` 与普通唱姿统一 ✓ |
| `bf`（BOYFRIEND） | 有（`Idle/Left/…`） | 与 §3 的 label-fallback 叠加生效 ✓ |
| `maroonthreat` | **无**（`master` 零标签） | 仍走子符号，**不变** ✓ |
| `white`（`!!!`） | 无 | 不变 ✓ |

### 7.5 待实测

1. ejected 里 `bf-fall` 的 `-loop` 唱姿与普通唱姿是否回到同一基线。
2. `bread.log` 里 `sing*-loop` 的 `nmv bounds` 行应变成
   `__BTA_TEMP_SPRITEMAP_PACKED_SYMBOL … w=1322`。
3. maroonthreat / white 位置不应变化（它们的图集没有帧标签）。
