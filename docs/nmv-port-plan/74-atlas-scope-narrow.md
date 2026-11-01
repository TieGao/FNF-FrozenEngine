# 74 · 收窄 NMV 图集兼容范围（2026-11-01 下午）

> 起因：NMV 的 Animate 图集兼容把原版 atlas 角色带坏了（用户点名 `content/VanillaSongs/Collab`
> 的 sserafim 角色）。目标是让"只该给 NMV 语料用的语义"不再落到原版/其他内容包头上。

## 判据

`Character.nmvContentChar` = 角色 json 的**解析路径含 `/NMVMODS/`**。
这是唯一的分派开关；`assets/`、`content/VanillaSongs/*`、`content/CustomCharts/*`、`mods/` 一律走 FE 原有语义。

## 收窄的三处（都挂到 `nmvContentChar`）

| 位置 | 收窄前 | 收窄后 |
|---|---|---|
| `Character.loadCharacterFile` 动画注册 | 所有 atlas 角色走 NMV 六步优先级（帧标签优先于符号） | NMV 语料走 `registerNmvAtlasAnim`；其余走 `registerFeAtlasAnim`（indices → 符号，即 FE 原逻辑） |
| `Character.playAnim` 翻转偏移修正 | 所有 atlas 角色按 `frameWidth - baseFrameWidth` 镜像 offset | 仅 NMV 语料；其余 `offset.set(daOffset)` |
| `Character.loadCharacterFile` dummy frame（1×1 白图） | 所有 atlas 角色 | 仅 NMV 语料 |

第 1 条是 sserafim 坏掉的主因：`kazuha` 的 `idle`、`sakura` 的 `joint pose *` 在 json 里
**既是符号名又是主符号的帧标签**，NMV 优先级会改走根时间线标签段 → 内容与锚点都换了一条时间线。

第 2 条配 dummy frame 更糟：1×1 frame 让 `baseFrameWidth = 1`，翻转态下 offset 直接取反。

## 附带修掉的一处误判

`PsychFlxAnimate.isNmvContent()` 原来取或 `NMVContentData.currentMod != null`。
`currentMod` 是 Freeplay 的选择态、回主菜单后仍保留 —— 从 story mode 进 `VanillaSongs/Collab`
时会把别的包的图集判成 NMV，套上 MC 钉第 0 帧 + 数字 blend 改名。
现在只看 `Paths.currentContentRoot`（进歌前由 WeekData / Freeplay 设成本歌的资源根）。

## 单角色逃生口

判据是**内容来源**，不是图集导出格式 —— 两者在 BTA 导出上无法区分（原版 FNF 0.8 与 NMV 都是 BTA 1.1/1.2）。
NMV 包里若混有原版格式的图集角色，给该角色 json 加 `"atlas_anchor": "fe"`（或 `"none"`）即可整体退出
NMV 语义：锚点补偿、NMV 动画注册优先级、dummy frame、翻转偏移修正四项一起关。

图集层的 `applyNmvAtlasSemantics`（MC 钉第 0 帧 + 数字 blend 改名）仍按内容根判定，不受这个字段影响。
