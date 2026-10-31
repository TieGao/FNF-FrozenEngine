# Phase 5 回归进展与交接（2026-10-28 凌晨）

> 本文是 Phase 5 的**交接快照**，配合 `50-phase5-regression.md`（原计划）读。
> 本文档目录声明不提交；代码已 commit（见 §8）。
>
> **已于 2026-10-28 关账。** §5 的谜题已解（不是 hscript cast 问题）、§4 beach-old
> 的"补文件"修法已被推翻——两处的旧结论保留原文作过程记录，但**勿按旧结论行动**，
> 最终结论以 §8 为准。

## 一句话状态

批量回归 harness 已建成并跑了 6 轮，按数据补了 14 个移植类 + 5 处接线/路径修复，
**可加载率 114/126 = 90.5%**（≥80% 验收线达成）；真实 API 缺口只剩 2 个已判定
限制（见 §4），其余失败全部是 harness 上下文差异或包内容缺失。有一个未解之谜
（AmongWalker × hscript 构造参数）见 §5。**（后续更新：谜题已解、修复后
115/126 = 91.3%，见 §8。）**

## 1. 怎么构建与运行（新接手先读这段）

```bash
# 0) 铁律：haxelib 指向必须是 E:/HaxeToolkit/haxe/lib/（FE 仓库）。
#    本机用户并行开发 NF，指向会被切走（本次会话中被切到 F: 过一次）——
#    构建报 "Library lime is not installed" 就是这事，别去 install：
haxelib config          # 检查
echo "E:/HaxeToolkit/haxe/lib" | haxelib setup   # 切回（管道喂路径）

# 1) 构建（回归 harness 需要 NMV_BATCH 定义；正常构建不含它，零残留）
cd /j/FrozenEngine-NMV-ScriptAPI-Port
haxelib run lime build windows -DNMV_BATCH      # 增量约 2-4 分钟

# 2) 跑回归（exe 会自己扫 content/NMVMODS/ 下全部包，报告落在 exe 工作目录）
cd export/release/windows/bin
./FrozenEngine.exe -nmvbatch            # 报告 → nmv-batch-report.md
# 参数：-nmvbatch [root] [-o report.md]
```

- 样本 = 用户测试包 `export/release/windows/bin/content/NMVMODS/{legacy,securitydlc}`
  （即 VS IMPOSTOR LEGACY 1.0.3b 的 content，127 个 .hx；harness 排除空文件后 126）。
- 引擎源码参照（补 API 时查签名）：`D:\impostorLegacyPublic\source\funkin\`。

## 2. Harness（`source/nmv/test/NmvBatchState.hx`）

- 入口 `Main.hx`：`-D NMV_BATCH` 构建 + `-nmvbatch` 参数时把 initialState 换成
  NmvBatchState，跑完写报告自动退出（正常构建零残留）。
- 时序镜像 NMV PlayState：全部包的 `scripts/*.hx`（**扁平一层**，NMV 不递归）
  先载并共享一份 Sharables（NMV LOOSE 语义 = 启用包并集）→ 逐包 stages →
  data/characters → songs/<歌> → scripts/states|substates。
- 每脚本 parse + 顶层执行 → 注入上下文变量（songName/bpm/isStoryMode 等，
  按 NMV preset PlayState 段取值；角色脚本 parent = PetStub）→ **直接 Reflect
  调 onLoad 与常见回调**。
- 关键教训（首轮踩过）：**不能走 Iris.call** —— 它把函数体内异常 catch 成
  `[ERROR:file:line]` 日志不抛，统计全瞎。要 `script.get(fn)` 后 Reflect 直调。
- 报告含：汇总、load/onLoad/回调三级明细、Unknown variable 直方图。

## 3. 本轮按数据补掉的东西（全部已验证通过对应脚本）

### 3.1 接线（FE 源）
| 位置 | 内容 |
|---|---|
| `PlayState.hx` create 早期 | NMV 全局脚本并集加载：全部 NMVMODS 包的 `scripts/*.hx` 载入同一 holder（当前包优先）——NMV `addSongScripts('scripts')` 的对应物，此前完全没有 |
| `PlayState.hx` 角色创建后 | `nmvScripts.loadCharacterScript(名, 角色)`：NMV 角色脚本 `data/characters/<名>.hx`，先设 `parent` 再 onLoad（NMV `startCharacterScript` 对应物） |
| `NMVSciptHolder.hx` | 新增 `loadCharacterScript()`（不能走 load()，它载完立即 onLoad、parent 没来得及设） |

### 3.2 路径（`backend/Paths.hx`）
| 修复 | 原因 |
|---|---|
| NMV 候选追加**兄弟包探测**（`nmvSiblingRoots()`，按当前根缓存） | securitydlc 的歌用 legacy 的 `lights.frag`——NMV 的 LOOSE 资源语义是启用包并集 |
| `getSparrowAtlas`/`getPackerAtlas` 磁盘命中先读内容（`readDiskAsset()`） | **本轮最大单点**：fromSparrow 收到磁盘路径时内部只走 openfl Assets（只认嵌入资源），磁盘路径被当 XML 字符串解析 → 裸 NPE，16 个舞台脚本全栽在这 |

### 3.3 NMV 类移植（`source/nmv/`）
| 文件 | 说明 |
|---|---|
| `shaders/` 7 个：DropShadowShader、ColorMatrixShader、HeatwaveShader、ChromaticAbberation、OverlayShader、ColorSwap、RGBPalette | NMV 引擎自带 shader 原样移植（FE 同名类 API 不同形：属性式 vs 方法式）。RGBGraphics 没搬（依赖 flixel 批渲染内部字段，pin 的 6.2.0 没有）；RGBShaderReference 接 FE 同名类（NMV 本体也没有这个类） |
| `objects/AmongWalker.hx` | sussus-toogus 的路人（继承 FunkinSprite，补 Bopper 面：addAnimByPrefix 映射、animCurFrame、canDance；hibernating/idle/right 显式 public——hscript 会直接赋值） |
| `objects/SnowEmitter.hx` + `CustomEmitter.hx` | 雪粒子（polus/maroon）；heatwave 纹理缺时兜底生成中性灰图 |
| `data/Lang.hx` | NMV i18n；语言文件在 `content/NMVMODS/lang/`（用户已放），候选序 = 当前包 → 共享层 → 其余包 |
| `data/GameFlags.hx` / `ProgressionUtil.hx` | 最小移植：旗标会话内存；songIsClear 用 FE Highscore.songRatingFC 作"打过这首歌"判据 |
| `objects/PetStub.hx` | 宠物行为桩升级：FlxSprite 实例 + curPet/loadPet + zIndex/skew/useRenderTexture（脚本碰 pet.origin/pet.zIndex 不再断） |
| `objects/NmvSprite.hx` | 注册为脚本侧 `FlxSprite`：补 zIndex/skew（API 兼容、无渲染语义）+ `loadFromSheet()`（defeat/finalem 用） |
| `objects/PlayHUDShim.hx` | NMV playHUD（BaseHUD）→ FE PlayState 的 iconP1/iconP2/healthBar/scoreTxt，getter 逐次取（不能快照，建卡时字段未建） |
| `objects/AnimateElementShim.hx` | NMV flxanimate fork 内部元素类（charles.hx 置子件 active 用），注册点名声 `animate.internal.elements.FlxSpriteElement` |

### 3.4 preset 注册与 FE 侧小改
- PresetFlixel：BlendMode（Int enum abstract → 名字→值映射对象）、ShaderFilter、
  FlxShader、FlxParticle、FlxAxes、FlxTextAlign（同法）+ 上述 nmv/shaders 类。
- PresetFnf：Lang、GameFlags、ProgressionUtil、SnowEmitter、CustomEmitter、
  AmongWalker、playHUD、pet→PetStub、`stage`→宿主 state（语料只用 add/insert/members）。
- PresetStubs：新增 informative throw：AmongWalker→（注意：后来真移植了，此桩
  已被真类覆盖）、FinaleState、CameraUtil（storyNodes/剧情系统，未接）。
- `backend/ClientPrefs.hx`：加静态别名 `globalAntialiasing` → data.antialiasing
  （NMV 脚本到处用这个静态面）。
- `objects/Character.hx`：加 NMV 兼容面 `useRenderTexture`（Bool 字段，无渲染）
  + `onBeatHit(curBeat)`（空实现——FE 角色跳舞走自己的 beat 循环，不能再触发）。
- `FunkinSprite.hx`：loadNmvAtlas 支持 Animation.json 布局（语料实测 bfIntro/
  charlesClouds 是 Adobe Animate 多 spritemap，FE loadAnimateAtlas 原生支持）；
  缺图集改**告警不抛**（NMV 同语义，walkers 图集在发行版引擎 assets 里）；playAnim
  空控制器防护（flxanimate 对未加载控制器 play 会裸 NPE）。

## 4. 当前失败清单定性（最后一轮：114/126 load+onLoad，cb 失败 47）

**onLoad 失败 11 个：**
| 文件 | 定性 |
|---|---|
| warehouse.hx | harness 上下文（顶层读 `PlayState.SONG.notes`，真实流程 SONG 已设） |
| toogus.hx | **已判定限制**：`new flixel.system.FlxBGSprite()`（TieGao flixel fork 的类，全限定 new 绕不过 preset 注册）+ `.zIndex`。修复需给 fork 的 FlxBasic 加 zIndex/skew——用户已否决（不为 1 个文件动共享底层库） |
| who / lights-down / armed / greatest-plan / reinforcements | harness 上下文：`startCharacterPos`/`addCharacterToList` 是 FE PlayState 自带方法，真实游戏经 parentFields 命中 |
| charles.hx | **已判定限制**：脚本用 `parent.timeline.layers`——NMV Character 是 FlxAnimate 基座，FE Character 不是 |
| ashes → dialogue.hx:339、CreditsRollSubState:248 | harness 上下文：`FlxG.sound.music.volume`，harness 里没有音乐 |
| beach-old.hx | **【已推翻，见 §8】** 原定性"包内容缺失"是错的：实证后确认 beach-old 是 NMV 遗留死舞台——securitydlc 全部谱面的 stage 字段只有 beach/horse/medbay/security/security2，没有任何谱面引用 beach-old，引擎源仓（D:\impostorLegacyPublic）里也不存在 beach/sea.xml；该脚本在 NMV 原版同样不会被真实游玩加载。harness 伪影，无需修 |

**回调失败 ~47 个**：几乎全是 PlayState 字段的上下文差异（curBeat/curStep/isDead/gf/
playHUD 已修/health 已修/tasksong 要 onCreatePost 先跑/jads 的 modchart 跨脚本
时序）。doubletrouble 的 red/rainShader 失败在 onCreatePost 里，harness 不调它。

## 5. 未解之谜（→ 已解，2026-10-28；原怀疑被推翻）

**sussus-toogus.hx:12**：`var walker = new AmongWalker(...)` 后 `walker.xRange` 报
null。实证过程：
- 直接 `Type.createInstance(AmongWalker, [[-700.0,1700.0], 520.0, 0.72, []])`（Float 参数）→ **OK**；
- 但 hscript 路径（参数是 Int 字面量 → hscript 内部 Array<Dynamic>）→ 字段落 null；
- 尝试把构造器签名改成 `Dynamic` + 内部规整 → **反而所有直接调用也 NPE**（原因未定位，
  已回退）。回退后 = 原签名版本，直接调用 OK、hscript 仍 xRange null。
- 探针代码已从工作区清除；AmongWalker 构造器已回到已验证形态。

**真相（2026-10-28，已验证）**：与 hscript/hxcpp 的数组 cast **无关**（独立 hxcpp
探针证明 `Array<Dynamic>`→`Array<Float>` 形参的 `Type.createInstance`/`Reflect`
转换全部正常）。真正的根因有两层：

1. **`PresetStubs.missing('AmongWalker', ...)` 桩反覆盖真类**。`PresetFnf.register()`
   末尾才调 `PresetStubs.register()`，把 57 行刚注册的 `nmv.objects.AmongWalker`
   类覆盖成了"调用即抛"的 varargs **函数桩**。§3.4 里"此桩已被真类覆盖"的说法
   方向搞反了——是桩覆盖真类。
2. **hxcpp `Type.createInstance` 对非类对象静默返回 null**（生成代码：
   `if (IsNotNull(cl)) return cl->ConstructArgs(args); return null();`）。hscript
   `cnew` 拿函数桩当类传进去 → `new AmongWalker(...)` 不报错、返回 null → 脚本
   首次碰字段时才在别的行报错（"Invalid access to field xRange" 实为 hscript 的
   `get(null, 'xRange')`，**对象**为 null，不是 xRange 为 null）。

修复（已 commit）：① `PresetStubs.hx` 删除 AmongWalker 桩行（附防再犯注释）；
② `InterpEx.hx` 覆写 `cnew`——`new X(...)` 解析到函数（TFunction）时显式抛
"是补桩函数,不是可构造的类"，把这类静默 null 变成带原因的异常（兜住
FinaleState/CameraUtil 等仍在的桩）。修复后 sussus-toogus onLoad 通过，全量
91.3%。

教训：**"Invalid access to field X" 在 hscript-iris 里是 hscript 自己的
EInvalidAccess（`get/set` 判 `o == null` 即抛），语义是"X 前面的对象是 null"，
不是"X 字段是 null"**。定位脚本报错时先按这个读。

## 6. 交接后建议顺序（→ 2026-10-28 已执行）

1. ~~解决 §5~~ → 已解（§5 末尾），sussus-toogus 通过。
2. ~~commit~~ → 已 commit：`76e08444`（harness）、`cbca0813`（Phase 5 补桩）、
   `692a4092`（视频链路，见 §8）。
3. **游戏内实测（待用户）**：NMVMODS 进歌跑一首；重点 onEvent/onCreatePost 这些
   harness 没覆盖的回调。现在视频演出链路（videoCutscene/meltdown）也有了适配类
   和 songStart/EndCallback 钩子，值得直接测故事模式开场。
4. ~~内容侧补文件~~ → **已取消**：beach-old 是死舞台伪影（§4 修正），无需补文件。
5. ~~文档回填~~ → 已并进 `50-phase5-regression.md`，Phase 5 关账。

## 8. 收尾记录（2026-10-28）

- **最终数据**：126 脚本，可加载率 **115/126 = 91.3%**（首轮 90.5%）。
- **本轮修复**：§5 谜题（桩反覆盖 + hxcpp 静默 null，cnew 防护）。
- **本轮新增（原悬项）**：`FunkinVideoSprite` 薄适配（hxvlc 直包，50 号文档登记
  的首例发现就此关掉）+ PlayState 的 songStartCallback/songEndCallback 属性别名
  （挂到 FE 自带 startCallback/endCallback，语义与 NMV 同构）+ `Paths.sanitize`。
  这三个一起构成 legacy 包开场演出链路（videoCutscene / meltdown outro）。
- **剩余失败 11 个 onLoad + 48 个回调的定性（终版）**：
  - 已判定限制 2：toogus.hx（fork FlxBGSprite 无 zIndex，用户否决动 fork）、
    charles.hx（parent.timeline 需要 FlxAnimate 基座）。
  - harness 上下文 9+：warehouse/who/armed/greatest-plan/lights-down/reinforcements/
    ashes/CreditsRollSubState（无音乐、SONG、PlayState 方法等）、beach-old（死脚本）。
  - 回调 48：几乎全为 PlayState 上下文变量（curBeat/curStep/isDead/gf）、
    onCreatePost 未跑（saxguy/red shader）、jads modchart 跨脚本时序。
- **登记未做（后续工作，非缺陷）**：
  - NMV 剧情/演出系统：`funkin.data.FinaleState`、`funkin.states.substates.CreditsRollSubState`
    （NMV 是原生类绑定伴随脚本架构，`new funkin.states.substates.CreditsRollSubState(...)`
    需要该架构或壳类）、storyNodes/CameraUtil——finale 周故事模式结束路径会用到；
  - FunkinVideoSprite 的暂停联动（tiedToGame）与 NMV 字幕（FunkinCaption）；
  - `songEndCallback` 脚本函数是 hscript 闭包，FE 直调 Void->Void 已验证可走
    （iris 的 makeVarArgs 包装），但 onEndSong 返回 Function_Stop 的语义未核。
- **杂散文件**：工作区遗留未跟踪的 `assets/base_game/shared/data/blammed/Necron-Doom-metadata.json`
  （内容是 Blammed 的 metadata，文件名与内容不符，疑为转化器测试遗留）——不属于
  本移植，未提交，待用户处置。
- **harness 复跑命令**：见 §1；报告 `nmv-batch-report.md`（exe 目录）。

## 9. 首轮游戏内实测崩溃与修复（2026-10-28 上午）

用户实测 legacy 包 Sussus Moogus 进歌即崩（`crash/latest.log`：PlayState:1355 →
Main:182 → Iris:376 → NMVSciptHolder:73/104 → PlayState:798，Null Object Reference）。
三层问题，全部已修（`git log` 见当笔 commit）：

1. **报错打印自身崩溃**：脚本 onLoad 报错走 `Iris.error` 回调（Main.hx）→
   `PlayState.addTextToDebug`，但 `luaDebugGroup` 在 create 更晚处才建 → null 解引用。
   修：`addTextToDebug` 开头 `luaDebugGroup == null` 直接返回；顺带把 ERROR/WARNING/FATAL
   文本写进 `Bread.crumb`（脚本错误从此落 `crash/bread.log`，不再只进一闪而过的控制台）。
2. **全局脚本加载时机过早**：我们把 NMV `addSongScripts('scripts')` 的对应物放在了
   create 极早期（`StageData.newStage` 之前），而 NMV 原版（PlayState:706-723）是
   **舞台 + gf/dad/bf 组 add 完之后**才 onLoad。已挪到 "PS stage+chars added" 之后
   （角色脚本之前，与 NMV 先后一致），并加 `PS nmv global scripts done` 面包屑。
   舞台脚本 `stages/<stage>.hx` 仍留原处（NMV 舞台脚本本就在角色前跑，那段没错）。
3. **ClientPrefs 缺 NMV cosmetics 字段**：legacy `scripts/utils.hx` 的 onLoad 读
   `ClientPrefs.bfSkin/gfSkin/pet/colorText`——harness 里能过是因为注入上下文挡住了
   真实类解析，真实游戏里 hscript 解析到真类、缺字段直接抛。已在 FE ClientPrefs
   补 NMV 同构兼容面（`equipment` Map + bfSkin/gfSkin/pet getter/setter +
   colorText='Enabled'，会话内存版，不落盘）。

**存档隔离（用户要求）**：本工作区 `CoolUtil.getSavePath()` 追加 `-NMVPort` 后缀
→ 存档落 `ShadowMario/FrozenEngine-NMVPort/`，不再与主版共用
`ShadowMario/FrozenEngine/`（此前测试已覆盖用户主存档一次，funkin.sol 无备份可还原）。
已实测：新目录自建存档，主存档不再被写。注意：主版工作区（J:\FNF-FrozenEngine）
代码不含此后缀，属预期——隔离只针对移植工作区构建。

harness 复跑：**91.3% 保持**（115/126），本轮改动无回归。

## 10. 第二轮实测修复（2026-10-28 上午，commit `7ae0ab35`）

用户复测反馈：场景好了；**所有 note 归给玩家**（谱面转化 bug）；对手偏移到右下角；
"没过场动画"（Freeplay 测的，见下）；Ejected 开场视频正常播放（视频链路 ✓）。
bread.log 已能抓到脚本报错（§9.1 的修复生效），据此定位：

1. **nmv2 谱面 note 全归玩家（已修）**：nmv2 的 sectionNotes 车道是**绝对值**
   （0..keys-1 = 玩家侧、keys..2keys-1 = 对手侧，NMV Chart.correctFormat 只对
   非 nmv2/psych_v1 格式做 +keys 取模翻转；时间/延音本来就是毫秒，与 FE 运行时同构）。
   FE 的 convert() 把它当旧格式的"相对车道 + mustHitSection XOR"又翻了一次：
   mustHitSection:false 段的对手 note（4-7）被 (4%4)+0 翻成玩家侧。
   修：parseJSON 把原始 fmt 传入 convert()，nmv2 跳过车道翻转（保留 sectionBeats
   修正与事件提取）；getKeyCount/getColumnsPerPlayer 补 `keys` 回退（NMV 多键字段）。
2. **对手偏移（未定位到根因，已布诊断）**：静态比对全对齐——FE 已应用 stage json 的
   opponent/boyfriend/girlfriend 站位（PlayState:756-762）与 camera_boyfriend/opponent
   相机偏移（767-773）、Character 已读 json.camera_position、moveCamera 公式与 NMV
   getCharacterCameraPos 同构（150 vs 100 基数差 50px 可忽略）。camTweenEvent 只动
   相机、事件时基（ms）已核对一致。已在 startCountdown 加位置诊断面包屑
   （dad/bf/gf 坐标 + camFollow + DAD_X/BF_X + 首段 mustHitSection），
   等下一轮 bread.log 定位。
3. **"没过场动画"= NMV 原版行为**：dialogue.hx 的 videoCutscene 开头
   `if (!isStoryMode || PlayState.seenCutscene) return;`——开场视频只在**故事模式**放。
   用户两次都是 Freeplay 选歌。Ejected 有视频是因为走 stages/ejected.hx 那条不检查
   isStoryMode 的链路。非 bug，不需修。
4. **dialogue.hx:88 skipText.zIndex 报错（已修）**：pin 的 flixel fork 的 FlxSprite
   **没有 zIndex 字段**（grep 证实；与 toogus.hx 的 FlxBGSprite 同因），hxcpp
   Reflect.setProperty 对缺失字段抛 "Invalid field:zIndex" 并**中断脚本函数后续行**。
   修：InterpEx 覆写 set()，对 zIndex 写入定向 try/catch 吸收（有此字段的移植类
   照常写入，原生 flixel 对象 no-op——同 NmvSprite "zIndex 无渲染语义"先例）。
5. **utils.hx:157 playHUD.ratingPop 报错（已修）**：PlayHUDShim 补 NMV PsychHUD 的
   脚本可调字段 ratingPop/combosPop/ratingScale/combosScale/ratingSuffix（NMV 同款
   默认值的会话内存版）。
6. **"Tried to call a non-function, for onLoad" 噪音（已修）**：camTweenEvent/
   cheatMenu/dialogue/tasksong 等全局脚本没有 onLoad，holder.load() 无条件 call 报错。
   修：先 script.exists('onLoad') 再 call（与 loadCharacterScript 的 138 行同法）。

harness 复跑：**92.1%**（116/126，比上轮 91.3% 多过一个 onLoad——zIndex/PlayHUD
吸收生效）。

## 7. 用户的现场约束（务必遵守）

- **不要动共享的 haxelib git fork**（E:\HaxeToolkit\... 的 flixel/openfl/hxcpp）——
  三仓库共用，为单个脚本加字段已被用户否决；兼容壳一律放 `source/nmv/`。
- 补桩原则：宁可显式抛异常带原因，不要静默 no-op（静默失效定位成本极高）。
- hscript 的 `Iris.call` 吞异常；宿主测异常必须 Reflect 直调（见 §2）。
