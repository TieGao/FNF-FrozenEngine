# FrozenEngine 引擎新增 API 速查手册

> 收录 2026-10 中旬为移植 V-Slice 内容包（Erect / PicoMix / BFMix / Collab）往 Psych 1.0.4 基底上加的引擎能力。
> 所有签名均已对照 `source/` 核实。示例取自 `content/VanillaSongs/` 现役内容包，可照抄改参数。
>
> **万金油提醒：改完 `content/` 里的任何文件，必须 cp 到 `export/release/windows/bin/content/`，运行时读的是 bin 那份。**

## 目录

1. [角色图集 API](#1-角色图集-api) —— 多图拼装 / 逐动画翻转 / 动画名契约
2. [内容包设施](#2-内容包设施) —— 目录布局 / 脚本加载 / 视频 / 谱面上下文
3. [脚本钩子体系](#3-脚本钩子体系hscript) —— 签名总表 / 返回值 / 事件换算 / note 钩子
4. [着色器](#4-着色器) —— FlxRuntimeShader / DropShadowShader 蒙版
5. [高频坑速查](#5-高频坑速查)

---

## 1. 角色图集 API

### 1.1 addExtraAtlas —— 多图拼装（"拼拼乐"）

**用途**：一个角色挂多张 animate atlas。死亡动画、变体动画、分尸图追加件（如 tankman 的 extra-animations、sakura 的 bf-death）不用塞进主图集。

**用法**：不用改引擎。角色 JSON 的**动画条目**上加可选字段 `assetPath`，引擎在 `Character.hx` 加载时自动收集、去重、逐份并进 atlas：

```json
{
  "image": "characters/tankman-bloody",
  "animations": [
    { "anim": "idle", "name": "tankman all_basic", "indices": [0,1,2] },
    {
      "anim": "stressPicoEnding",
      "name": "tankman stress ending",
      "assetPath": "characters/tankman-bloody_tankmanEnding",
      "indices": [0, 1, 2]
    }
  ]
}
```

规则（踩过的坑）：

- `assetPath` 是 `images/` 下的相对路径，指向**另一张分尸图的目录**（含 Animation.json 那层）。
- **动画条目在各自包内查符号，不存在跨包撞名**——这是最稳的拼法，放心用。
- 但 `addExtraAtlas` 的子图集 **sprite 帧名若与主图集撞**（如子图集帧叫 `0/1/2`）是恶性的：flixel `pushFrame` 会丢帧。判定与修法：`tools/atlas_prefix_rewrite.py` 给子图集帧名加前缀。仅 SD 符号名撞 = 良性，复查即可。
- 写 indices 时**避免"合并根符号 + 绝对 indices"**（FlxLayer 跨段跳帧 bug），用逐子符号。

### 1.2 逐动画 flip_x（2026-10-19 加，需重编译）

**用途**：同一图集里美术朝向不一致（如 tankman basic 包的 idle+sing 全画反了，bloody 包却是对的）。整体 `flip_x` 会把对的也翻错，所以翻了引擎。

**用法**：角色 JSON 动画条目加可选 `flip_x`：

```json
{ "anim": "idle", "name": "tankman all_basic", "flip_x": true, "indices": [0,1,2] }
```

- 实现：`Character.hx` `AnimArray` typedef `@:optional var flip_x` → `animFlipXMap` 记录 → `playAnim` 时 `animFlipX = map[AnimName]` → `copyAtlasValues` 里 `atlas.flipX = flipX != animFlipX`。只走 atlas 分支，sparrow 不受影响。
- **注意**：翻面是绘制矩阵镜像（绕原点不重对位），翻转后视觉位置会动，靠 offsets 校；offsets.x 不随翻转。

### 1.3 动画名契约与引擎硬编码名

animate-atlas 角色的动画名不是随便起的：

| 后缀/名字 | 引擎行为 |
|---|---|
| `-hold` | sustain 尾音拼接 |
| `-loop` | `Character.update` 自动循环接播（**别改成 hold**） |
| `-alt` | Alt Animation note 驱动 |
| `-censor` | Censor noteType（引擎 `Note.hx` 已加 case → animSuffix '-censor'） |

**引擎硬编码动画名**（脚本/谱面可能直接调，角色 JSON 必须有，缺了冻结）：`combo50` / `combo100`、`drop70`、`sad`、`hairBlow` / `hairFall`（PhillyTrain.hx 硬调，nene 缺了会卡死）、`scared`、`cheer`、`hey`。

**铁律**：`Character.hx` 对 atlas 角色播放不存在的动画**无 fallback，直接定住**。上谱面前用 `tools/check_anim_coverage.py` 扫一遍（按歌曲 player1/player2/gfVersion 映射槽位，别把 dad 当角色 id）。

脚本侧查动画只能用 `getAnimationName()` / `hasAnimation()`——atlas 角色 `animation` 控制器恒空，`animation.curAnim` 那套不可靠。

---

## 2. 内容包设施

### 2.1 目录布局

```
content/VanillaSongs/<包名>/
├── week.json                  # variants 接线见 2.4
├── dependencies.json          # 依赖其他包（如 BFMix 依赖 Erect 的舞台图）
├── shared/
│   ├── characters/            # 角色 JSON + 分尸图目录
│   ├── data/<歌>/             # 谱面 + events + per-song 脚本(.hx/.lua) + metadata
│   └── images/ sound/ music/
├── songs/<歌>-<变体>/         # 音轨（Inst/Voices ogg）
├── videos/<key>.<ext>         # 过场视频（见 2.3）
├── scripts/                   # 包级脚本（含一级子目录都会被扫）
└── stages/                    # 包级舞台脚本
```

### 2.2 脚本加载规则（PlayState）

| 层级 | 位置 | 扫描时机 |
|---|---|---|
| 全局 | `mods/*/scripts/` | PlayState.create 开头 |
| 包级 | `content/<包>/scripts/**`（根 + 一级子目录） | 同上，内容包补扫 |
| 包级舞台 | `content/<包>/stages/*.hx` | 同上（补齐 startHScriptsNamed 只查 mods/assets 的缺口） |
| **per-song** | `content/<包>/shared/data/<歌>/*.hx|.lua`（含依赖包回退） | create 靠后，加载谱面时 |

per-song 是给"只影响一首歌"的演出的（如 PicoMix 的 ugh/guns/stress 各一份）；全包共用逻辑放 `scripts/`。**脚本无参钩子必须写成 `function onCreatePost(?e)` 或 `function onCreatePost()`，带必选形参 Iris 直接报错**。

### 2.3 Paths.video —— 内容包 + 多格式

```haxe
Paths.video('stressPicoCutscene')  // 返回磁盘绝对路径
```

查找顺序：`mods/<当前mod>/videos/` → `content/<包>/videos/<key>.<ext>` → 依赖包 `videos/` → `assets/videos/<key>.<mp4>`。

- `VIDEO_EXTS = ['mp4','mkv','webm','ogv']`，hxvlc 按内容探测格式——**官方 mkv 可直接拷进内容包，不必转码**。
- 脚本里拿到的可能是"不存在"的兜底路径 `assets/videos/<key>.mp4`，判断文件存在请用 `FileSystem.exists(返回值)`（参照 `PicoMix/shared/data/stress/stress.hx` 的 `onStartCountdown`）。
- `Paths.cachedVideo(key)` 带缓存登记，反复播的用这个。

### 2.4 setChartContext —— 谱面上下文一次写全

```haxe
Paths.setChartContext(category, directory, hasVSlice, audioSuffix,
                      contentRoot, metaArtist, metaCharter, variant)
```

**8 个参数必须一次写全**：这些字段分散赋值很容易把上一首的残留（尤其 `hasVSlice`/`audioSuffix`）带进下一首。只拿到 `contentRoot` 时 `variant` 可传空——`setContentRoot` 会按资源根反查周定义自动推出变体（同一包内变体唯一）。

**包变体接线**（week.json，PicoMix/BFMix 模式）：

```json
{ "difficulties": "Easy,Normal,Hard", "variant": "Pico", "variantLabel": "Pico Mix" }
```

文件名全带变体：谱面 `<歌>-<变体>-<档位>.json`、音轨目录 `songs/<歌>-<变体>/`。同名歌跨包靠 variant 隔离，**不加就会互相覆盖**。`NewSongMetaData.songName` 是路径键永远原始歌名，展示名走 `displayName`。

---

## 3. 脚本钩子体系（HScript）

### 3.1 钩子签名总表（Iris，照抄即可）

| 钩子 | 签名 |
|---|---|
| `onCreatePost` / `onDestroy` / `onStartCountdown` / `onEndSong` / `onPause` / `onSongStart` / `onResume` / `onGameOver` | 无参（写 `?e` 可选形参最保险） |
| `onUpdate` / `onUpdatePost` / `onStepHit` / `onBeatHit` / `onCountdownTick` | `(elapsed)` / `(curStep)` / `(curBeat)` / `(tick)` |
| `onEvent` | `(name, value1, value2, strumTime)` |
| `goodNoteHitPre` / `goodNoteHit` / `opponentNoteHitPre` / `opponentNoteHit` / `noteMiss` / `onSpawnNote` | `(note)` 对象，字段随便读写 |
| `onKeyPress(Pre)` / `onKeyRelease(Pre)` / `onGhostTap` | `(key)` |

要点：

- 拿 PlayState 一律 `var p = PlayState.instance`，判空再干活。
- **要截断引擎原逻辑，钩子返回 `Function_Stop` 常量的字符串值 `'##PSYCHLUA_FUNCTIONSTOP'`**（`LuaUtils.Function_Stop`）。Pre 系钩子返回它可整段跳过引擎实现（sserafim/stress 的"防 sing 打断"就是这么做的：Pre 里给 `note.noAnimation = true`，比返回值更轻）。
- `onEndSong` 想拦截结尾播过场：返回 `Function_Stop`，自己排定时器后手动 `p.endSong()`（参照 stress.hx）。

### 3.2 onEvent 事件换算对照表

内容包 events JSON **保留 V-Slice 原事件名**，`value1` 放参数（JSON 串或逗号串），脚本在 `onEvent` 里换算：

| V-Slice 事件 | FE 换算 |
|---|---|
| `ZoomCamera` | stage 模式 `zoom × defaultCamZoom`；direct 模式 ÷ V-Slice 舞台 cameraZoom 再拼 `',stage'` |
| `ScrollSpeed` | VS 的 duration 是**步**，PE 要**秒** |
| `SetHealthIcon` | value1 = `{"char":1,"id":"tankman-bloody"}`，`iconP2.changeIcon(id)` |
| `EnableMask` | 见 4.2 |
| `Play Animation` | 引擎原生支持（PlayState `case 'Play Animation'`，value2 = dad/bf/gf）；脚本通常只借它登记"保护窗"防 sing 打断 |

### 3.3 note 钩子实战：后缀改写（stress tankman bloody 案例范文）

引擎播 note 动画用的是 `singAnimations[方向] + note.animSuffix`（`PlayState.opponentNoteHit` / `goodNoteHit`），而 `animSuffix` 是 public——**Pre 钩子里改后缀 = 改演出的瞄准镜**：

```haxe
function opponentNoteHitPre(note) {
    guardNote(note, 'dad');                       // 保护窗内 noAnimation = true
    rewriteSingSuffix(note, singTargetIsDad(note, false));
}

function rewriteSingSuffix(note, isDadSide) {
    if (note == null || note.animSuffix != '-alt') return;
    if (isDadSide && isBloody) note.animSuffix = '-bloody';  // 引擎自动播 singX-bloody
    else note.animSuffix = '';                               // 无 -alt 动画的角色剥空，防冻结
}
```

注意目标角色判定：`opponentNoteHit` 反打模式落到 boyfriend、`goodNoteHit` 里 `!note.mustPress` 落到 dad，`gfNote` 永远是 gf。

### 3.4 相机 helper（防 bop 打架）

脚本里动相机不要直接拽 `camGame.zoom`（会被 bop 回弹覆盖），用 stress.hx/sserafim.hx 里的 `camZoomTo` / `camPosTo` 模式：tween 的是 `p.defaultCamZoom` / `p.camFollow`，onUpdate 里同步 `camGame.zoom`；强制定位配 `isCameraOnForcedPos = true`。

---

## 4. 着色器

### 4.1 FlxRuntimeShader + 外挂 frag（sserafim 模式）

`flixel.addons.display.FlxRuntimeShader`（flixel-addons，无需 import 自己加）：

```haxe
var src = Paths.getTextFromFile('shaders/xxx.frag');   // 内容包先试包内路径
if (src == null) src = File.getContent(Paths.currentContentRoot + '/sserafim/shaders/xxx.frag');
var sh = new FlxRuntimeShader(src);
sh.setBool('isChar', true);
sh.setFloat('darkAmt', 0);
sh.setFloatArray('lightColor', [1, 1, 1]);
sprite.shader = sh;
```

- frag 放 `content/<包>/sserafim/shaders/*.frag` 这类包内路径；`Paths.getTextFromFile` 查不到就按 `currentContentRoot` 直读磁盘兜底（frag 不会被打进资源清单）。
- uniform 更新走 `sh.data.<名>.value = [...]` 或包装好的 `setFloat/setBool/setFloatArray`。
- **性能两条**：frag 里 `rgb2hsl/hsl2rgb` 这类重活必须按 `combinedAlpha` 短路，否则透明像素也在跑；给角色挂 shader 时记得舞台脚本要每帧 `rim.updateFrameInfo(char.frame)` 同步帧信息（参照官方 stage 脚本）。

### 4.2 DropShadowShader 蒙版（EnableMask / rim 光）

`source/shaders/DropShadowShader.hx`，边缘高光 + AdjustColor + **蒙版**三合一。TankErect.hx 的 `DropShadowShader.attach(char, {hue, saturation, brightness, contrast, color, angle, strength, distance, threshold})` 是标准入口。

蒙版开关（tankman bloody / gf-tankmen 用）：

```haxe
var sh:DropShadowShader = cast char.shader;
sh.setAltMask(Paths.image('erect/masks/tankmanCaptainBloody_mask').bitmap, 1.0);  // 预载
// 事件来时：
sh.data.useMask.value = [1.0];   // 关掉写 [0.0]
```

三个坑（都写在 shader 头注释里了）：

- **`useMask` 是 float 不是 bool**——OpenFL 的 bool uniform 赋值路径不稳，脚本里赋值写 `[1.0]`。
- **`altMask` 必须在构造期就绑一张纹理**：它被动态分支引用，驱动不会优化掉，留空 sampler 悬空。这就是 stress.hx `enableMask()` 里"先 `altMask.input = 图` + `thr2=1` 预载、事件时只翻 `useMask`"的原因。
- 失败要兜底（`maskFailed` 标志），蒙版挂不了只影响光效，不能挡通关。

---

## 5. 高频坑速查

| 坑 | 正解 |
|---|---|
| 改了 content/ 没生效 | 运行时读 `export/release/windows/bin/content/`，**双同步** |
| 全屏黑幕显存爆炸 | 1×1 `makeGraphic` + `setGraphicSize()`，禁 `makeGraphic(10000,10000)`（≈400MB 显存） |
| 去评级弹窗 | 舞台脚本只写一次 `comboGroup.visible = false`；别改 PlayState、别每帧轮询 |
| HScript 钩子报形参错 | 无参钩子就是无参，`?e` 可选形参可以 |
| atlas 角色冻住 | 缺动画（见 1.3 铁律）；脚本里别摸 `animation.curAnim`，用 `getAnimationName()` |
| 类型检查 | `HAXELIB_PATH="C:/HaxeToolkit/haxe/lib" haxe export/release/windows/haxe/release.hxml --no-output`（零输出=过） |
| lime build windows | 本机跑不通（沙箱黑名单 reg.exe → 探不到 SDK）；能用脚本/资源解决的别动 `source/` |
| haxelib API 不匹配 | 优先升 `setup/*` 里的钉子，别在 source/ 写兼容 shim；CI 重装需 `dependencies_to_update: all` |
| 转换器产物 | 转换器产的 events-\<变体\>.json 是空转垃圾，**整体重生成别叠加**；外部 events 齐全时谱面内嵌 events 清空 |
| offsets | 别公式推算，以实机/编辑器调值为准；等价折算 `position -= base; off_i -= base`（offset.x 是**减**） |
| 舞台图层全黑 | filters 用 FE 语义：**常显=3**；带 STORY_MODE 位的层在 Freeplay 会被整批跳过 |
| 分发 | funkin.assets 是 All Rights Reserved，移植资产**勿随引擎外发** |
