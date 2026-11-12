# Fatal Finale — 单曲极限内存测试基线

> 对象：`export/release/windows/bin/mods/Fatal Finale`（只读分析，未改动任何文件）
> 日期：2026-11-10
> 配套：`docs/memory-texture-report-2026-11-09.md`

## 1. 这个 mod 为什么适合当极限用例

| 项 | 值 |
|---|---|
| 体量 | 1.1GB（images 634MB / videos 276MB / songs 169MB / music 3MB） |
| 全部 PNG | 302 张，磁盘 613.7MB → **解码后 10.4GB**（17.4x） |
| 歌曲 | `fatal-final-encore`（30:20，11,380 notes，591 events）、`-lite` 版 |
| 舞台 | `fatal-finale`，`fatal-finale.lua` 建 **73 个 luaSprite + 38 个 animated**，0 次 remove |
| 预热 | `data/fatal-final-encore/precache stuff.lua`：**99 次 `precacheImage` + 56 次 `addCharacterToList`** |
| 角色图集 | 51 张唯一 PNG，**5.98GB** 解码 |
| 预加载图 | 99 张，**2.95GB** 解码 |
| 脚本运行期再引用 | 额外 18 张 / 161MB |

### 关键：`addCharacterToList` 是"立刻 new 一个 Character"

`PlayState.addCharacterToList()`（`source/states/PlayState.hx:1382`）不是"登记待用"，
而是当场 `new Character(...)` 并 `add` 进 `boyfriendGroup/dadGroup/gfGroup`（`alpha = 0.00001`）。
所以 **56 个角色在 `onCreate` 阶段就全部加载完毕**，进歌前内存就已经到位。

## 2. 实测静态数字

### 2.1 加载集合（去重后）

| 集合 | 张数 | 解码 |
|---|---:|---:|
| A：`characters/*.json` 的 `image` 图集 | 51 | 5,980.6MB |
| B：`precacheImage` 列表 | 99 | 2,951.8MB |
| **A ∪ B（= `onCreate` 结束时的下限）** | — | **8,932.5MB** |
| R：舞台/歌曲/事件脚本里再引用的图 | 118 | 3,177.2MB |
| **A ∪ B ∪ R（整首歌可能触达的上限）** | 168 | **9,093.8MB** |

> `/lite` 版本并没有更轻：同样 99 次 `precacheImage`、52 次 `addCharacterToList`。

### 2.2 尺寸分布（并集 168 张）

| 尺寸档 | 张数 | 解码 |
|---|---:|---:|
| 任一维 ≥ 8192 | 34 | 6,366.6MB |
| 4096–8191 | 29 | 1,656.2MB |
| 2048–4095 | 52 | 884.7MB |
| < 2048 | 53 | 186.3MB |

单张最大：

| 解码 | 尺寸 | 文件 |
|---:|---|---|
| 391.7MB | 10545×9738 | `images/characters/Lord_x_EncoreFULLX.png` |
| 256.0MB | 8192×8192 | `fleetway-bf / fleetway1 / fleetway2 / Fleetway_Super_Sonic / gfgone / SUNKYOMG / Super_BoyFriend_Extra_Anims / Tails_Doll / Tails_Doll_Front / Exeternal_TT_xeno_encore` |
| 256.0MB | 8192×8192 | `chaos/Emerald Beam`、`chaos/FleetwayBGshit`、`chaos/Wall`、`dopple/lights` |
| 226.7MB | 8192×7255 | `characters/fe.png` |
| 138.3MB | 7408×4894 | `flare/band`、`flare/LightShade` |

15 张 8192×8192，单张 256MB —— 这类尺寸本身就该拆图。

## 3. 预期运行时表现

### 3.1 进歌前就会看到 ~9GB

`precache stuff.lua` 的 `onCreate` 在 `PlayState.create()` 里执行，早于 countdown。
默认 `cacheOnGPU = false`（桌面）时，这 8.9GB 全是 **CPU 侧 BGRA 像素**；
首次绘制后每张再上传一份到显存（再 8.9GB）。

- 8GB 显卡：显存直接不够，openfl 不会报错，只会**黑图/贴图错乱**（`createRectangleTexture` 失败后不抛异常）。
- 16GB 内存：CPU 8.9GB + 系统 + 视频解码，已经贴边；WDDM 会把显存溢出到共享内存，FPS 崩。
- 32GB：能跑，但 RSS 常态 10GB+。

### 3.2 30 分钟里只会涨不会降

`StepHit.lua` 有 199 次 `removeLuaSprite`，但：

- `removeLuaSprite(tag, true)` 只 `obj.destroy()`（`FunkinLua.hx:1110-1125`）；
- `FlxSprite.destroy()` 只是把 `graphic/frames` 置 null（`FlxSprite.hx:421-448`），**不 dispose 图集**；
- `Paths.image()` 又把每张图设成 `persist = true; destroyOnNoUse = false`。

→ 换景只销毁 sprite，像素缓冲永远留在 `Paths.currentTrackedAssets`。
所以内存曲线是**单调上升**，峰值在歌末 + `Final Credits.mp4`（229MB）解码时。

### 3.3 会踩到的两个已知坑

1. **10545×9738 超出部分 GPU 的 `GL_MAX_TEXTURE_SIZE`**（老 Intel/移动端 8192）→ 该角色会黑图。
2. **主角色被预加载两次**：`LoadingState.preloadCharacter()` 把 bf/tails/nogf 交给
   `cacheBitmap()`（键 `images/...`），`Character` 构造时 `Paths.image()` 用的是
   `Fatal Finale:images/...`（mod 前缀）→ miss → 再解码一份。
   这三个图集合计 321MB（bf 44 + tails 21 + nogf 256），会白多 321MB。
   （其余 53 个角色没有走 LoadingState 预加载，只解一次。）

## 4. 建议的测量协议（不改 mod）

1. `modsList.txt` 只留 `Fatal Finale`（避免别的 mod 干扰），`contentList.txt` 保持现状。
2. 设置：`GPU Caching` 先 **关**；FPS 计数器打开 **Show Memory Peak**（会显示 RSS）。
3. 进歌后用 F9 抓 4 个点（`logs/memory-*.txt` + `memory-session.txt` 时间线）：
   - A：进入歌曲、countdown 之前（应已 ~9GB）
   - B：第一个 section
   - C：中段（约 15 分钟）
   - D：歌末、`Final Credits` 视频之前
4. 关注三个数：
   - `RSS`：真实占用。A 点若 ≈ 9–10GB 属预期；若 ≈ 18GB 说明 CPU 副本翻倍（命中 P1/P3）。
   - `Paths 追踪 CPU`：应≈ 8.9GB；若明显小于 RSS，差值就是 native/显存/字体。
   - `重复浪费`：`duplicateKeys()` 按归一化路径统计，非 0 就是同一文件被缓存了多份（P1 直接指标）。
5. 想验证 GPU 侧：把 `GPU Caching` 打开再跑一次。预期**不会更好**（8.9GB 显存放不下），
   而且会触发 2.3 节说的 `__surface` 悬垂/`readable` 假象，崩的概率更高。

## 5. 和优化项的对应关系

| 优化项 | 对这个 mod 的效果 |
|---|---|
| **P1 统一缓存键** | 省掉主角色的 321MB 重复 + 跨歌复用；对这个 mod 只是小头 |
| **P3 丢 CPU 像素** | 省 8.9GB 的 CPU 副本（但显存仍放不下 → 必须配合降采样） |
| **P3 降采样（2048 上限）** | **最大杠杆**：8.9GB → 约 1.4GB（按像素面积），且能塞进 8GB 显存 |
| **P3 预算/LRU** | 这个 mod 一次性就要 8.9GB，预算机制会直接拒绝加载大部分角色 → 需要"按需加载"配合 |
| **P4 图集拆分** | 15 张 8192² 拆成 2048² 后，单张显存从 256MB → 16MB×16，可按 section 流式加载 |
| **引擎侧可选**：`addCharacterToList` 懒加载 | 56 个角色 → 实际用到 3 个，可省 ~5.5GB；但会改变脚本语义（`setProperty('xxx.alpha')` 会找不到对象），只能做成 opt-in |

## 6. 结论

这个 mod 的"极限"不在显存带宽，而在**一次性预热了 8.9GB 解码图**：
它把 Psych 资源模型的两个缺陷同时放大到了不可用级别 ——

1. `addCharacterToList` 立即实例化 + `Paths` 永不淘汰 → 预热即峰值；
2. 默认不丢 CPU 像素 → CPU/GPU 双份，任何单卡都放不下。

所以它是验证 **P3 降采样** 和 **P4 图集拆分** 的最佳用例；
只做 P1/P2 对它帮助有限。测试时请以 **RSS** 为准，不要看 FPS 里的 `Memory:`（那是 GC 堆口径）。

---

## 7. 实测结果（2026-11-11 00:06–00:24）

环境：RTX 2060（6GB VRAM）+ 32GB RAM；本轮 **GPU Caching = ON**（`CPU` 列全程为 0，说明 CPU 像素已被 dispose）。
数据来源：`export/release/windows/bin/logs/memory-session.txt`（13 次 F9 采样）。

| 时间 | GC usage | large | RSS | 贴图数 | GPU≈ | FlxG.bitmap |
|---|---:|---:|---:|---:|---:|---:|
| 00:06:09 | 2.92GB | 2.78GB | 10.41GB | 259 | 10.48GB | 340 |
| 00:06:16 | 2.94GB | 2.78GB | **10.74GB** | 260 | 10.50GB | — |
| 00:12:09 | 1.20GB | 934MB | 8.90GB | 274 | 10.52GB | 356 |
| 00:13:26 | 1.25GB | 943MB | 8.33GB | 276 | 10.52GB | — |
| 00:14:10 | 1.27GB | 943MB | 8.48GB | 278 | 10.52GB | — |
| 00:14:46 | 1.29GB | 945MB | 9.50GB | 280 | 10.52GB | — |
| 00:16:29 | 1.01GB | 845MB | 8.17GB | 280 | 10.52GB | 361 |
| 00:18:05 | 1.10GB | 859MB | 8.26GB | 280 | 10.52GB | — |
| 00:18:47 | 1.13GB | 846MB | 9.37GB | 281 | 10.52GB | — |
| 00:19:21 | 1.16GB | 848MB | 9.13GB | 283 | 10.52GB | — |
| 00:22:53 | 1.05GB | 845MB | 8.21GB | 283 | 10.52GB | — |
| 00:23:59 | 1.09GB | 862MB | 8.57GB | 283 | 10.52GB | — |
| 00:24:12 | 1.11GB | 855MB | 8.42GB | 283 | 10.52GB | 364 |

### 结论 1：GC 指示器只剩 1/7 的可信度

00:12 之后 `GC usage` 稳定在 **1.0–1.3GB**，而 `RSS` 是 **8.2–9.5GB** —— 差 **7.3GB**。
这正是报告 §3 的实证：GC 只统计 hxcpp 堆，10.5GB 纹理全在显存/驱动里，FPS 计数器一个字节都看不到。

### 结论 2：10.5GB 纹理 vs 6GB 显存 = 4.5GB 溢出

RTX 2060 只有 6GB VRAM，而 `Paths` 追踪的纹理估算 10.52GB → 约 **4.5GB 只能放在 WDDM 共享内存**（系统 RAM），
这就是 RSS 常年 8GB+ 且随镜头/换景在 8.17–9.50GB 之间摆动的原因（纹理换入换出）。

**开 GPU Caching 并没有救回来**：CPU 侧确实清零了（`CPU 0`），但总量本身超出显存一个量级。
按"最长边限 2048"重算同一批 168 张图：**8.88GB → 1.36GB（-85%）**，才可能完整进 6GB 显存。

### 结论 3：纹理只增不减

18 分钟里 `Paths` 贴图 259 → 283（+24），`FlxG.bitmap` 340 → 364，GPU 估算 10.48 → 10.52GB。
`StepHit.lua` 的 199 次 `removeLuaSprite` 只销毁 sprite，图集继续挂在 `Paths.currentTrackedAssets`（`persist=true`）。

### 结论 4：重复缓存被实测抓到（P1 实锤）

Top 40 里同一张图同时存在**带 mod 前缀**和**不带前缀**两份 key：

| 文件 | 两份 key | 浪费 |
|---|---|---:|
| `chaos/Wall.png` | `images/…` + `Fatal Finale:images/…` | 256MB |
| `chaos/FleetwayBGshit.png` | 同上 | 256MB |
| `characters/gfgone.png` | 同上 | 256MB |
| `flare/LightShade.png` | 同上 | 138MB |
| `image/end.png` | 同上 | 128MB |
| `chaos/Emerald Beam Charged.png` | 同上 | 128MB |

`noteSkins/NOTE_assets.png`、`final escape/*.png`、`BF MISS.png` 也都是成对的。
**仅 Top 40 内可数的浪费就 ≈1.2GB**，完整数字需要下一版快照（`duplicateKeys()` 会按归一化路径统计并给出总浪费）。

顺带：日志里还残留 `Sonic.exe 2.5:images/icons/icon-true-fatal.png` 这类**别的 mod 的 key**，
说明 `currentTrackedAssets` 跨 mod 会话也不清 —— 换 mod 不重启时同样会叠。

### 结论 5：加载期的 CPU 像素要等 GC 才回来

00:06 的 `GC usage` 是 2.92GB（large 2.78GB），到 00:12 掉到 1.20GB。
`Paths.image` 的 `image = null` 只是断引用，**字节要等下一次 GC 才真正释放**；
这也解释了为什么加载瞬间 RSS 会摸到 10.7GB。`Paths.clearUnusedMemory()` 里的 `System.gc()` 是唯一的强制回收点。

---

## 8. A/B 对比：GPU Caching 开 vs 关（2026-11-11 00:32 / 00:33）

同一首歌、同一台机器（RTX 2060 6GB / 32GB RAM），只切 `GPU Caching`：

| 指标 | GPU Caching **ON** (00:32:06) | GPU Caching **OFF** (00:33:57) | 差值 |
|---|---:|---:|---:|
| `GC usage` | 913MB | **12.19GB** | +11.3GB |
| `RSS` | **10.35GB** | **15.07GB** | **+4.72GB** |
| `CPU` 贴图 | 0 | **11.34GB** | +11.34GB |
| `GPU` 估算 | **10.69GB** | 5.80GB | −4.89GB |
| CPU+GPU 合计 | 10.69GB | **17.14GB** | +6.45GB |
| 纹理张数 | 289 | 295 | +6 |
| `FlxG.bitmap` | 369 | 375 | +6 |
| 重复浪费 | 1.91GB（94 组） | 2.55GB（97 组） | +0.64GB |

### 结论 1：关掉 GPU Caching = 多背一份 CPU 像素，RSS 直接 +4.7GB

OFF 时同一批图同时存在 CPU（11.34GB）和 GPU（5.80GB），合计 17.14GB；
ON 时每张图只留 GPU 一份（10.69GB）。**这就是"未开启 GPU Caching 时特别明显"的量化答案**：
不是引擎漏了什么，而是 openfl 的 `readable` 语义本来就会保留 CPU 缓冲，而 `Paths` 又从不主动丢。

顺带一个反直觉点：ON 模式的 GPU 估算反而**更高**（10.69 vs 5.80），因为 `Paths.cacheBitmap()` 在 GPU 分支里
会主动 `getTexture()`，连"从来没被绘制过"的预加载图也上传显存；OFF 模式只上传真正画过的。

### 结论 2：GC 指示器的读数随设置"变脸"，不能跨设置比较

- OFF：`GC usage` 12.19GB ≈ CPU 11.34GB —— 因为像素就在 hxcpp 堆里，读数看着很准；
- ON：`GC usage` 913MB，而真实占用 10.35GB —— 差 11 倍。

同一个"Memory:"数字，在两种设置下含义完全不同。**要么看 RSS，要么明确当前是哪种缓存模式**。

### 结论 3（新发现）：`LuaScriptPreload` 的预加载目前 100% 落空，白烧 ~2GB

重复组清一色是 `<图片路径>` 与 `Fatal Finale:<图片路径>` 成对，覆盖 `chaos/*`、`Cycles/*`、`flare/*`、
`dopple/*`、`eggman/*`、`final escape/*`、`image/end`、`BF MISS` —— 正好是 `fatal-finale.lua` 里
`makeLuaSprite` 用到的整套舞台图。

链路：

```
ClientPrefs.luaScriptParser = 'preload'
  → LuaScriptPreload 静态解析 data/<song>/*.lua、stages/<stage>.lua，抽出 makeLuaSprite/precacheImage 的图片
    → LoadingState.prepare(imgs) → preloadGraphic() → Paths.cacheBitmap('images/x.png', bmp)
      → currentTrackedAssets['images/x.png']        ← 没有 mod 前缀
运行期 Character / makeLuaSprite
  → Paths.image('x') → cacheKey = 'Fatal Finale:images/x.png'   ← 永远 miss → 再解码一份
```

`cacheBitmap()` 不补 mod 前缀 / contentRoot 后缀，`image()` 补 —— 两边永远对不上。
**结果：预加载既没省加载时间，还让内存多背一份。** OFF 快照里 `images/chaos/Wall.png`
是 `CPU 256MB / GPU 0`（从没被画过），就是这批"白存"的预加载副本。

> 立即可用的缓解：把 `LuaScriptParser` 调回 `native`（默认值），这两个快照里的 1.9–2.6GB 重复会立刻消失；
> 真正的修法是 P1（统一缓存键），修完预加载才会第一次真正生效。

### 结论 4：ON 也救不了，因为 10.69GB > 6GB 显存

即使把重复的 1.91GB 修掉，剩下 8.78GB 仍超过 6GB VRAM，还是要走 WDDM 共享内存。
按"最长边限 2048"重算：**≈1.4GB**，这才是能落地的目标。
所以优先级不变：**P1（省 1.9–2.6GB）→ P3 降采样（省到 1.4GB）→ P4 拆图**。
