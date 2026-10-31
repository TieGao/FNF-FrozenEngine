# Phase 6：NMVMODS 接线（界面用 FE 的）

## 前提结论（源码考察）

Impostor Legacy 是 NightmareVision 的 total-conversion mod，**界面全部是源码**：

| 位置 | 行数 | 内容 |
|---|---|---|
| `source/funkin/states/` | 8442（12 个） | PlayState 3517 / FNAFState 1516 / FreeplayState 918 / MainMenuState 496 / StoryMenuState 432 / MarathonMenuState 353 / TitleState 343 … |
| `source/funkin/states/substates/` | 4226（23 个） | Pause / GameOver / Cosmetics / Cosmicube / GameplayChangers … |
| `source/funkin/states/options/` | 2997（9 个） | BaseOptionsMenu 691 / ControlsSubState 663 / OptionsState 398 … |
| `source/funkin/objects/menu/` | 1818（10 个） | FreeplayCard 226 / CosmicubeNode 401 / AmongControls 165 … |

发布版里的 `content/legacy/scripts/states/MainMenuState.hx`（70 行）只是 `ClientPrefs.inDevMode` 下的调试按键钩子，不是菜单本体。

主菜单是「平板 + 5 按钮」（storymode / freeplay / cosmi + options / awards），没有 tab 结构。

**决定**：界面用 FE 的，NMV 只提供歌 + 脚本 + 数据。入口放在 Freeplay 的 ModFolder 子界面（一级来源加 `NMVMODS`），不占主菜单。

## 目录约定

```
content/NMVMODS/<mod>/
├─ meta.json                 { "name": "...", "description": "..." }
├─ data/weeks/*.json         NMV week 定义（回退 weeks/*.json）
├─ songs/<歌>/               Inst.ogg / Voices.ogg / data/normal.json / <歌>.hx
├─ scripts/                  全局脚本（PlayState 加载）+ scripts/states|substates/
├─ stages/  data/  images/  music/  sounds/  shaders/  fonts/
```

一个 mod 一个包，和 NMV 的 `content/<mod>/` 结构一致，拷进来只多一层。

## week 数据转换

NMV 的 week 是 JSON，schema 与 FE 相近但元组语义不同：

| 位置 | NMV | FE | 处理 |
|---|---|---|---|
| 0 | 歌名 | 歌名 | 保留 |
| 1 | 图标 | 角色 | 保留 |
| 2 | 颜色数组 | 颜色数组 | 保留 |
| 3 | **立绘名** | **音乐人** | 丢弃 |
| 4 | **曲师** | **各难度谱师数组** | 移到音乐人位 |
| 5+ | 解锁条件 / 豆子价 / 金锁 | — | 丢弃 |

不重排会静默错位：音乐人显示成立绘名，谱师显示成解锁条件里的歌名。

其余字段：`storyName` / `weekName` / `weekBefore` / `startUnlocked` / `hiddenUntilUnlocked` / `hideStoryMode` / `hideFreeplay` 直接映射；`section`（NMV 是字符串分区名）与 `node`（剧情地图节点）丢弃；`difficulties` 留空走默认。

**解锁**：NMV 靠 Cosmicube / 豆子购买，FE 的 `StoryMenuState.weekCompleted` 里没有 NMV 的周名，所以注册时强制 `startUnlocked = true` 且清空 `weekBefore`——否则除 week1 外全部被 `weekIsLocked` 锁死。

## 代码接线（4 处）

| 文件 | 改动 |
|---|---|
| `source/backend/NMVContentData.hx` | 新增。扫 `content/NMVMODS/*/`、读 `meta.json`、列 week 文件、`readWeek()` 做元组重排 |
| `source/backend/WeekData.hx` | `reloadWeekFiles()` 调 `addNmvModWeeks()`：只在 `NMVContentData.currentMod` 非空时注册，周 key 带包名前缀，`contentRoot = content/NMVMODS/<mod>` |
| `source/backend/Song.hx` | `getChart()` 加 NMV 谱面回退：`songs/<歌>/data/<难度>.json` → `<难度>.json` → `data/normal.json` → `song.json`。**必须在 `Assets.getText()` 之前判存在**——那条路找不到会抛异常，回退就再也走不到 |
| `source/states/FreeplayState.hx` | `applySourceFilter('nmv', <mod>)`；`matchesSourceFilter` 按 `contentRoot` 前缀匹配（vanilla 分支要排除 NMVMODS）；`create()` 里 `currentMod` 非空时自动切到 nmv 来源；抽出 `rebuildSongLists()`，切进/切出 NMV 时重扫周定义并重建列表 |
| `source/states/freeplay/ModFolderSubstate.hx` | 一级来源加 `NMVMODS`（没有包时整项不显示），二级列 `content/NMVMODS/<mod>`，包名取 `meta.json` 的 name；选中走 `applySourceFilter('nmv', <mod>)` |

## 已验证

- `release.hxml` 类型检查 + 代码生成 exit 0，`obj/src/backend/NMVContentData.cpp` 生成。
- 用真实样本 `D:/impostorLegacyPublic/assets/legacy/data/weeks/` 跑转换：18 个 week 全部可转，曲师正确落到 FE 音乐人位（例：`['Sussus Moogus', 'red', [255,0,0], 'EthanTheDoodler']`）。
- 歌目录名与 `Paths.formatToSongPath` 一致（`Sussus Moogus` → `sussus-moogus`，样本 56 个目录实测）。
- 人声：FE 的 `Paths.voices(song)` 无后缀候选正好是 `songs/<歌>/Voices.ogg`，与 NMV 同名。
- 音轨：`songs/<歌>/Inst.ogg`，走 `currentContentRoot` 加性回退。

## 2026-10-26 合并主分支后的运行时接线修正

与主分支（0.6.6/0.6.7 内容包体系）合并后发现三处运行时冲突，已修：

1. **psych 脚本扫描豁免 NMV 包**（PlayState create 的内容包脚本扫描）：主分支的扫描把
   `<contentRoot>/scripts/**` + `stages/` 全部用 psych HScript 运行时加载——NMV 脚本被
   错载后只调 onCreate 不调 onLoad，脚本变量全空（chef.hx 倒计时闭包裸抛崩游戏，
   20 个舞台脚本同时进 PlayState）。现按 `NMVContentData.currentMod == null` 整包豁免，
   NMV 包脚本归 NMV 层加载。
2. **NMV 层补舞台脚本**：NMV `Stage.runScript` 在角色创建前跑 `stages/<stage>.hx` 的
   onLoad（脚本 add 的背景才能垫在角色下面）。FE 侧把 NMV 容器创建挪到 create 早期
  （角色 new 出来之前），只对 NMV 包加载 `stages/<curStage>.hx`；歌内脚本与
   `scripts/states/PlayState.hx` 仍在原位（角色创建后）加载。
3. **pet 行为桩**（PresetFnf）：NMV `Pet` 继承 Bopper（未随路线 C 移植），但舞台/歌曲
   脚本普遍引用 `pet.curPet` / `pet.loadPet`，缺了会让脚本 onLoad 中断、后续定时器
   闭包裸抛崩游戏。桩为 `{curPet:'', loadPet:no-op}`，逻辑放行、宠物本体不显示。
4. **Freeplay 卡片小图标**：卡片 `HealthIcon` 建在 Freeplay 列表期，此时没有包根上下文
   （applyContentRoot 只在进歌前调），NMV 包的 `images/icons/` 命中不了。ensureCard
   建卡期间按 `song.contentRoot` 临时设置 `Paths.currentContentRoot` 并还原（与既有
   modDir 存取恢复同一模式）。
5. **getPath 补 NMV 布局候选**（2026-10-26 晚）：NMV 包是**包根相对**布局（`images/ data/
   stages/ songs/...`），没有 FE 内容包的 `<root>/shared/` 前缀层 —— getPath / fileExists
   / loadAnimateAtlas / Character(:116) / StageData(:84) 全走 getPath，此前一律 miss：
   角色 json 找不到回退 BF（`assets/shared/characters/...` 异常就是 getPath 兜底路径被
   裸 File.getContent 打出来的噪音）、舞台 json 落 dummy()、atlas 图集 / 图标全部空。
   现 `isNmvContentRoot()`（按根含 `/NMVMODS/` 判定）追加 `<root>/data/$file` 与
   `<root>/$file` 两条候选，FE 布局候选保持优先。NMV 的角色 json / 舞台 json schema
   本身与 FE 同构（角色图集是 FlxAnimate 格式，FE :154 原生检测），不需要转换层。

**引擎源码参照**：`D:\impostorLegacyPublic`（用户指定，NMV 引擎全源 +
Impostor Legacy 内容），补 NMV API 时以它的 `source/funkin/` 为准核对签名。

## 已知缺口

- **难度**：NMV 56 首歌全部只有 `normal.json`，FE 仍显示 easy/normal/hard 三档，选非 normal 会回退 normal 谱面。
- **谱面格式**：NMV 是 Psych 0.6 风格（`{"song": {...}}`、`sectionNotes`），走 FE 现成的 `psych_v1` 转换器；`lanes` / `keys` / `player3` / `player4`（多键位）不识别。
- **舞台 / 角色 / 图标**：NMV 的 `stages/*.json`、`data/characters/*.json` schema 与 FE 不同，需要逐个适配（Phase 5 回归时按失败清单处理）。
- **歌曲名带撇号**：`d'low` 经 `formatToSongPath` 变成 `dlow`，与目录名 `d'low` 不匹配。
- **NMV 专属系统**：Cosmicube、Awards、Marathon、剧情地图（`node`）、Freeplay 分区（`data/weeks/freeplay/*.json`）均未接入。
