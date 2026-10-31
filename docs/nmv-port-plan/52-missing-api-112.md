# 1.1.2 内容下的 API 缺口清单

扫描口径：`D:/VS IMPOSTOR LEGACY 1.1.2/assets` 下 106 个 `.hx` 的 `import` 行频次，
叠加 2026-10-28 12:31 运行的 `bread.log`。补的顺序按"改动量 / 影响面"排。

## 一档：只加别名（`Iris.addProxyImport`，零逻辑）

脚本按 NMV 自己的包名 import，类其实已经有了，只是名字不同。已全部接上
（`PresetFnf.registerImportAliases()`，共 21 条）：

| NMV import | 目标类 |
|---|---|
| `funkin.utils.CoolUtil` | `backend.CoolUtil` |
| `funkin.data.ClientPrefs` | `backend.ClientPrefs` |
| `funkin.data.GameFlags` | `nmv.data.GameFlags` |
| `funkin.utils.ProgressionUtil` | `nmv.data.ProgressionUtil` |
| `funkin.states.substates.PauseSubState` | `substates.PauseSubState` |
| `funkin.states.substates.GameOverSubstate` | `substates.GameOverSubstate` |
| `funkin.states.TitleState` | `states.TitleState` |
| `funkin.data.WeekData` | `backend.WeekData` |
| `funkin.Mods` | `backend.Mods` |
| `funkin.objects.SnowEmitter` | `nmv.objects.SnowEmitter` |
| `funkin.objects.FunkinCaption` / `FunkinCaptionGroup` | `nmv.objects.*` |
| `funkin.objects.stageobjects.AmongWalker` | `nmv.objects.AmongWalker` |
| `funkin.game.huds.PsychHUD` | `nmv.objects.PlayHUDShim` |
| `funkin.game.shaders.*`（5 个） | `nmv.shaders.*` |
| `funkin.FunkinAssets` | `nmv.FunkinAssets` |
| `funkin.backend.DebugDisplay` | `nmv.backend.DebugDisplay` |
| `funkin.backend.math.Vector3` | `nmv.backend.math.Vector3` |
| `funkin.data.CosmicubeData` | `nmv.data.CosmicubeData` |

## 二档：小移植（工具类，几十行）

已补：`FunkinAssets`（`parseJson5` 走"标准 JSON → 去注释/尾逗号重试"）。

已补（2026-10-29，commit 见 git log）：
- `funkin.utils.MathUtil` → `nmv/utils/MathUtil.hx`（原样移植，语料主要用 fpsLerp）。
- `funkin.utils.SortUtil` → `nmv/utils/SortUtil.hx`（laserSort + sortByZ；svSort 未搬——
  参数是 modchart.SpeedEvent；sortByZ 用 Reflect 容错读 zIndex，因为 pin 的 flixel fork
  连 FlxBasic 都没这字段，缺失按 0 = 稳定不重排，与 zIndex 写入本就被吸收的现状一致）。
- `funkin.game.shaders.ExtraDropShadowShader` → `nmv/shaders/ExtraDropShadowShader.hx`
  （6 层 rimlight 全量 GLSL + ExtraDropShadowLayer + LayerOperation/ThreshMode；
  setAdjustColor 依赖的 animate fork 内部 AdjustColorFilter.getColorMatrix 落成本文件
  私有实现，矩阵数学照搬）。继承 `nmv/shaders/ShaderCompat.hx`——medbay/beach/
  doubletrouble 直接对 shader 调 setFloat/setFloatArray/setBool，标准 flixel 的
  FlxShader 没有这些运行时方法（NMV 的 flixel 栈才有），ShaderCompat 按
  FlxRuntimeShader 的同名实现补。
- `funkin.backend.FunkinShader.FunkinRuntimeShader` → `nmv/shaders/FunkinRuntimeShader.hx`
  （防崩壳：GLSL 编译失败退回纯色采样模板；NMV 落 Logger/dump，这里落 bread.log。
  flixel-addons 4.0.1 自带 FlxRuntimeShader，setFloat/setBool/setSampler2D 原生可用）。
- `funkin.game.shaders.HSLColorSwap` → `nmv/shaders/HSLColorSwap.hx`（原样移植）。
- `funkin.utils.CameraUtil` → `nmv/utils/CameraUtil.hx`（lastCamera/quickCreateCam/
  addShader/findShader；`ClientPrefs.shaders` 依赖 → backend/ClientPrefs.hx 加了静态
  别名，语料 34 处同款用法）。

## 三档：中等

| 类 | 状态 |
|---|---|
| `FunkinCaption` / `FunkinCaptionGroup` | 已补（`nmv/objects/`，只搬 set/text/visible/defaultY） |
| `funkin.backend.DebugDisplay` | 已补桩：只收集 `addPlugin` 的文本，FE 的 `debug.FPSCounter` 不消费 |
| `funkin.utils.CameraUtil` | 已补（见二档；storyNodes/week4.hx 的 addShader 在用） |
| `flixel.addons.ui.FlxUIButton` / `FlxSlider` | 不做：本机 flixel-addons 4.0.1 无 ui 模块，只有 cheatMenu 用，且 `ClientPrefs.inDevMode` 为假时整段跳过 |

## 四档：大件（剧情 / 进度系统）

| 类 | 状态 |
|---|---|
| `funkin.data.CosmicubeData` | 已补桩：只有 `currentMoney` 读写，解锁/商店不移植 |
| `funkin.data.FinaleState` / `CreditsRollSubState` / `HenryState` / `MissCounterSubstate` / `funkin.objects.RGBSprite` / `funkin.game.modchart.ModManager` | 未移植；FQ 名已挂"调用即抛"proxy 桩（`PresetFnf.missingProxyImport`），撞上会带原因报错而不是 Unknown variable |
| storyNodes / 剧情地图 | 未做 |

## 脚本面缺口（按实测日志）

| 报错 | 状态 |
|---|---|
| `Unknown function: addAnimByPrefix`（skeldpixel 等） | 已补 `FunkinSprite.addAnimByPrefix/ByIndices`，Sparrow 图集也支持 |
| `Unknown function: getFlag`（多个舞台） | 已补 `Character.getFlag/hasFlag` + `flags`（读角色 json 的 `flags`） |
| `Invalid field: scalableOffsets` | 已补 `Character.scalableOffsets`（FE 的 offset 不随缩放，仅脚本读写） |
| `legacyOffset` | 已补字段；FE 的动画偏移就在 offset 上，故不实现"updateHitbox 清零" |
| `Unknown function: getAnimName` / `hasAnim` / `renameAnim` | 已补 `Character` 别名 |
| `healthColour` / `canDance` / `ghostsEnabled` / `gameoverCharacter` | 已补字段（canDance 生效；残影与死亡角色选择未移植） |
| `Null Object Reference`（退歌时 `PsychFlxAnimate.destroy`） | 已修：旧库 `anim.destroy()` 会把 metadata 置空，catch 里再解引用会二次抛 |
| `videoCutscene` 的 Null Function Pointer | 已修（`NmvSprite.makeScaledGraphic`） |
| `Unknown function: contains` | 已修（`InterpEx.fcall`） |
| `Invalid access to field contains`（`getAnimName().contains(...)` 等"调用结果上取字段"） | 已修：这类走 `get()` 不走 fcall，hxcpp 的 Reflect.field 对 String/Array 缺失字段原生抛错——新增 hxcpp 分支的 `InterpEx.get()` 覆写（hl 分支原有另一份），contains 截下返回可调用包装 |
| `Unknown variable: PathsTestMode` | 已修（值对象 + `getPath` 参数重排） |
| **FQ 全限定名**（`new funkin.game.shaders.ExtraDropShadowShader()` 等，语料 38 种） | 已修：代理 import 只管 import 语句；`new` 表达式里的 FQ 名走 `resolve`（整条路径当一个标识符）→ `InterpEx.resolve` 末尾加了 proxyImports 兜底 + `cnew`/`getOrImportClass` 覆写。**教训：同一次调用里 probe 显示 `Iris.proxyImports.exists(key)==true` 而基类 `getOrImportClass(key)` 返回 null，根因未明（hxcpp 目标），用 InterpEx 自己直查绕开** |
| `Unknown variable: snapCamToPos` | 已补 `PlayState.snapCamToPos(x, y, lockPosition)`（NMV 同签名，语料 30 个舞台脚本在用） |
| `Invalid field: animCurFrame`（bf-running 写 `legs.animCurFrame`） | 已补 `Character.animCurFrame`（get/set，NMV FunkinSprite 同语义：无动画读 0 写丢弃）+ `PetStub.animCurFrame`（harness 里 parent 是它） |
| `canTaunt`（d'low.hx 关嘲讽） | 已补 `Character.canTaunt` 字段（NMV 的嘲讽按键玩法未移植） |
| `Unknown variable: ClientPrefs.shaders`（34 处） | 已补 `backend/ClientPrefs.hx` 静态别名（同 globalAntialiasing 先例）。**注意：接通前脚本全走"shader 禁用"分支所以假通过，接通后才暴露 FQ shader 缺口** |
| `Unknown variable: modchart` | 未做（modchart 系统整体未移植） |
| `boyfriend.animateAtlas`（turbulence） | 未做：NMV 的 flxanimate fork 特有对象（`.timeline` / `.getWholeBounds`），只该舞台用 |
| `funkin.objects.Pet`（monotone 真实构造） | 已映射到 `PetStub`；`loadPet` 改为返回 `this`，`new Pet().loadPet(x).destroy()` 链式刷新走通 |


## 1.1.2 新增的脚本 API（CHANGELOG 提到，需核对）

- `curDecSection`（1.1.2 新增）——语料 0 处使用，未做
- `canTaunt`（角色变量，1.1.1）——已补字段
- `modFolder`（脚本变量，1.1.1）——已接（`PresetFnf` 注册）
- state / substate 脚本的 `parent` 变量——已有（FunkinScript 对所有脚本设 parent = FlxG.state）
- 插件脚本可共享 public 变量（`NMVSciptHolder.sharePublicVars`）——已补
- `Defines` 支持——未核对（语料未见使用）
- 宠物与角色组的变更 / 预加载信号（`PetStub.onChange` 已补）

## harness 数据（2026-10-30，语料 = legacy 1.1.2 + securitydlc，90 脚本）

**93.3%（84/90），load 90/90 = 100%。** 剩余失败全部定性：
- onLoad 6 = harness 上下文 4（`startCharacterPos`/`boyfriend`——真机经 parent=PlayState
  解析命中）+ CreditsRollSubState:268（harness 无音乐，`FlxG.sound.music` null）+
  beach-old（死舞台伪影）。
- 回调 26 = PlayState 上下文变量（curBeat/curStep/curDecBeat/dad/gf/isDead、跨脚本
  saxguy、onCreatePost 产出的对象 x/alpha/barCenter/intro）+ top-10/sigh.hx 的
  `playFields`（modchart PlayField，归 modchart 桶）。
- bf-running:26 的 "Invalid access to field contains" 已定性为伪影链：harness 里
  parent=PetStub 缺 getAnimName → fcall 的 `Iris.error` **只记日志不抛**、返回 null →
  对 null 取 `.contains`。教训再次应验："Invalid access to field X" = **X 前面的对象
  是 null**。PetStub 已补 getAnimName，脚本推进到 :28（curDecBeat，上下文伪影）。

## 2026-10-30 游戏内实测四连修（bread.log 驱动）

| 现象 | 根因 | 修法 |
|---|---|---|
| ejected 背景大楼整个不建 | `ejected.hx:22 grayShader.setAdjustColor` → 移植的 ColorMatrixShader 缺该方法 → 舞台脚本 onLoad 中断，其后的 sky/buildings/clouds/speedlines 全没创建 | `nmv/shaders/AdjustColorMatrix.hx` 共享助手（NMV flxanimate fork 内部 AdjustColorFilter.getColorMatrix 照搬），ColorMatrixShader/ExtraDropShadowShader 都接 setAdjustColor |
| ejected 运镜每拍中断 | `ejected.hx:197 camHUD.scrollAngle` —— NMV 的 FlxCamera 有相机旋转字段，FE 没有 → Reflect 抛 Invalid field，onUpdate 后续行全断 | InterpEx get/set 把 `FlxCamera.scrollAngle` 映射到 FE fork 自带的 `angle`（真实旋转生效，danger/turbulence 同款用法一并救活） |
| 所有 gf 只向一个方向摆头 | d097ee11 的 animate 注册顺序把"精确符号"排在 indices 前：gf 的 danceLeft/danceRight 是同一符号 `GF Dancing Beat` 靠 indices 分段，结果两个动画都整段注册了 150 帧符号 | 注册优先级改为 **indices → 帧标签 → 精确符号 → 前缀**（indices 必须最先；帧标签仍先于符号以保住 'black left' 串台修复） |
| red 系角色（玩家侧）漂移 | NMV `setAnimOffset` 有翻转修正：`flipX != baseFlipX` 时 X 偏移按 `frameWidth - baseFrameWidth - x` 镜像。FE 裸用 json 偏移，red 被换成玩家侧（翻转）后每个唱击动作横向甩 500px+；周 1 的 red 是对手侧不翻转所以没事 | FE Character 加 `baseFlipX/baseFlipY`（= 出生时 flipX，与 NMV 同公式）+ `baseFrameWidth/Height` 采样，playAnim 施加偏移时对 animate 角色做同款修正；顺带补 bf-running 要写的 `parent.baseFlipX` 字段 |

## 2026-10-30 实测第二轮四修（red 乱飞 / bf+gf 上天 / white 闪退 / yellow 动画错）

用户反馈：red 仍到处乱飞、默认 bf 和 gf 都上天、yellow 待机播未知动作、white 曲目直接闪退、
green 寄生虫形态整体偏下；并明确 **red/yellow/white/green 全是对手站位角色，只考虑对手侧**。
结合 10-30 01:00 实测 bread.log（本轮无任何 `nmv anchor` 采样行）定位出四个独立根因：

| 现象 | 根因 | 修法 |
|---|---|---|
| red 乱飞 / bf+gf 上天 / green 偏下 | d097ee11 把锚点补偿改成"json 显式开启（atlas_anchor）"，而语料所有角色 json 都不带这个键 → 10-30 构建里补偿**全关**（bread.log 无 anchor 行可证）。10-28 的构建是无条件开、位置正确——等于把验证过的行为自己关掉了 | `changeCharacter` 按角色 json 解析路径判 NMV 语料（`/NMVMODS/`），语料角色默认开；json `atlas_anchor:'fe'/'none'` 可显式关，`'nmv'` 强制开；FE 原生角色不受影响 |
| white 曲目必闪退（栈溢出硬崩，bread.log 停在 `char[white] atlas ok` 后） | white 的姿势符号与根 timeline 帧标签**同名**（'idle'/'down'…），而 73709ce6 的注册优先级是"帧标签先于精确符号" → `addByFrameLabel→addBySymbolIndices` 建同名包装符号**覆盖字典里的真符号**，根 timeline Layer_1 又引用 'idle' → `updateRender` 无限递归 → 栈溢出。教训与 kazuha 防环注释同款 | 注册优先级改为 **indices → 精确符号 → 帧标签 → 前缀**：精确命中走 fork `addBySymbol`（只写 animsMap、不写字典）；帧标签路径改用 `safeAddBySymbolIndices`（混乱键 `<符号>#<动画名>`，永不覆盖）；精确名有前缀歧义（'black left' vs 'black left alt'）时用显式全帧 indices 的 safe 包装。每个动画注册路径落面包屑（indices/exact/exact-ambiguous/label/prefix + 帧数） |
| yellow 待机播"不知道啥动作"（= 根主 timeline 原样循环，含 death 段） | yellow 的 Animation.json 是**新版 MX 矩阵格式但 MD.V 缺失**（别的导出器 V='BTA 1.2.0'）。旧库按 `MD.V != null` 判 BTA，yellow 被错走 fromJSON——它只认 M3D、**完全忽略 MX** → 全部元素矩阵变单位阵，所有零件堆在原点；json 里 'yellow idle' 等动画名在图集里带 `animations/` 前缀不存在，帧标签又在根 timeline 上（fromJSON 不解析？实际 fromJSON/fromJSONEx 都解析标签）——总之注册与渲染双双报废 | `Paths.patchBtaVersion()`：缺 MD.V 但树里有 MX 的 Animation.json 补上 `V='BTA 1.2.0'` 再喂给 loadAtlasEx（fromJSONEx 对 MX/M3D 都认）；`addExtraAtlas` 的子图集解析同样接上。fromJSONEx 不加 POS，与新版格式语义一致 |

锚点语义备查（本轮核实）：NMV 的 flixel-animate `drawAnimate` 每帧 `matrix.translate(-timeline._bounds.x, -bounds.y)`——**当前动画符号整条 timeline 并集包围盒的左上角钉在绘制原点**（`applyStageMatrix` 默认 false 且 NMV 未开）。旧 fork 的 `_flashRect` 是未缩放世界坐标（getScreenPosition 不含 zoom），故 `captureNmvAnchor` 的重构式 `relativeX + scroll*sf + offset = 符号坐标 bbox` 数学上精确。已知近似：补偿按首帧采样一次全局固定，若某角色各动画的并集包围盒不一致（分析工具显示 red 的各动画 bbox 差异大：idle(101,432)/left(180,-11)/down(-91,-116)），切动画时会有残余跳位——真要逐动画补需要把 union 计算移植进 Haxe，本轮先不动（10-28 行为已够用户验收）。green 寄生虫分析 bbox=(0,0)，NMV 理论上不需要补偿，10-28 采样值 (-32,-56) 疑似被 ejected 掉落场景的相机污染，复测后若仍偏下再单独处理。

## 下一步优先级

1. ~~snapCamToPos~~ / ~~MathUtil / SortUtil / ExtraDropShadowShader~~ / ~~CameraUtil~~ —— 本轮全清。
2. 用户复测（NMVMODS 进歌，重点：shader 演出链路——rimlight/灰度/黑边、
  snapCamToPos 演出、bf-running 双腿动画、`ClientPrefs.shaders` 接通后的舞台）。
3. modchart 体系（playFields/modManager/PlayField/note.rgbGraphics/onSpawnNote——
  top-10/sigh.hx 整条依赖链）。
4. 剧情大件（FinaleState/CreditsRollSubState/storyNodes——FQ 桩已挂，等真要做故事模式再动）。
