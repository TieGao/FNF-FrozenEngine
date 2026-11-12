# openfl(native) BitmapData ↔ GL 纹理生命周期

调查对象：`E:/HaxeToolkit/haxe/lib/openfl/git/src/`（`haxelib path openfl` 实际解析到这里；声明 9.5.2，
git HEAD `fedf3d79` = 9.6.0-dev 合并版，项目用 `-D openfl=9.5.2`）。对照 `openfl/9,5,2/`。
**两版本在所有内存/纹理路径上完全一致**：`diff --strip-trailing-cr` 只剩 `BitmapData.hitTest` 的 `>`→`>=`（3 处）、
`TextureBase.__initFormats` 从构造函数内联抽成静态函数、`Context3D` 的 `__backBufferPixelRatio` 字段。
**无一处涉及 dispose / getTexture / 上传**。下文行号一律指 git 版。

构建宏（`export/release/windows/haxe/release.hxml`）：有 `-D tools=8.4.0`、**无 `-D display`**、有 `-D HXCPP_CHECK_POINTER` + `-D HXCPP_STACK_TRACE` —— 所以空引用是**抛异常**而非静默段错误。

---

## 1. 一句话总览

`BitmapData` 有三份可独立存在的东西：`image`（lime CPU 像素）、`__surface`（cairo 视图）、`__texture`（GL 纹理）。
**`readable` 是唯一决定「CPU 像素准不准留」的开关**：`readable=false` 的图**只有被 `getTexture()` 上传过一次之后**
openfl 才把 `image` 置 null；而 `dispose()` 把 `__texture` 直接置 null 且**从不调 `gl.deleteTexture`**（源码那行被注释），
所以「CPU 释放了 / 对象没了但 GL 纹理泄漏」是**默认行为**，唯一可靠释显存的手段是手动 `__texture.dispose()`。

---

## 2. 状态机

| # | `image` | `readable` | `__texture` | `__isValid` | 到达方式 | 渲染 | 像素 API | 备注 |
|---|---|---|---|---|---|---|---|---|
| A | 有 | true | null | true | `new` / `fromFile` / `fromImage` | ✅ 首次绘制建纹理，**保留 image** | 全正常 | 常态，CPU 副本永久常驻 |
| B | 有 | false | null | true | **`disposeImage()`** | ✅ 首次绘制时才上传 | 全静默 no-op | **「已标记未上传」，CPU 还占着** |
| C | null | false | 有 | true | B + 任一次 `getTexture()`/`draw()`，或 `fromTexture()` | ✅ | 全静默 no-op | 真 hardware-only |
| D | null | false | null | false | `dispose()` | ❌（`__isValid=false` 跳过） | no-op | 死对象，`getTexture()` 返回 null |
| E | null | **true** | 有 | true | 只有 `@:access` 手改 `readable=true` | ✅ | **空引用异常** | 毒状态，见 Q2 |

`__isValid` 与 `readable` **互不相关**：前者只在构造函数 `BitmapData.hx:320`、`__fromImage:3322`、`clone` 硬件分支 `:432` 置 true，只在 `dispose():779` 置 false。
**`getTexture()` 把 `image` 置 null 时不动 `__isValid`** —— 这正是 C 态还能正常渲染的原因（`_internal/Context3DBitmap.hx:29` 只查 `__isValid`）。

---

## 3. 逐条回答

### Q1 · `image` / `__texture` 的创建与置空

`image` 创建：`new BitmapData()` → `:289-293`（sys 分支 `new ImageBuffer(new UInt8Array(w*h*4))`、
`format=BGRA32`、`premultiplied=true`）；`fromFile/fromImage/fromBase64` → 统一 `__fromImage:3302-3325`，
并强制 `image.format=BGRA32; image.premultiplied=true`（`:3317-3318`，`#if sys`）。

`__texture` 创建只有两处：`getTexture():2261` 的 `context.createRectangleTexture(width, height, BGRA, **false**)`
（注意末参 false），以及用户自建（本项目 `Paths.hx:990` 传的是 `true`）。

置空 `image` 只有两处：`dispose():773`，以及 **`getTexture():2314-2318`**
`if (!readable && image != null) { __surface = null; image = null; }`。
置空 `__texture` 只有 `dispose():787`；**`TextureBase.dispose()` 不回写 `bitmap.__texture`**
（只把自己 `__textureID` 置 null，`TextureBase.hx:97`）。

置空后果：`image=null` 后所有像素 API 因 `readable=false` 提前 return，**不崩**；`__texture=null` 后
`getTexture()` 返回 null（`:2256`），`draw()` 会走到 `context.setRenderToTexture(null, true)`（`:3189`）——
而 `setRenderToTexture` 只存字段、**不校验 null**（`Context3D.hx:1760-1766`）→ 后续绘制**画到后台缓冲**（花屏），不报错。这是 D 态最阴的坑。

### Q2 · `readable` 的语义

`@:beta public var readable(default, null):Bool;`（`:173`）——外部只读，写入需 `@:access`。
**本项目 `Paths.hx:31` 带了 `@:access(openfl.display.BitmapData)`，所以能写**，这是唯一危险入口。

`!readable` 守卫点（均在 `BitmapData.hx`，全是提前 `return`）：`applyFilter:359` `colorTransform:457` `compare:486`
`copyChannel:641` `copyPixels:710` `encode:1186` `fillRect:1248` `getColorBoundsRect:2114` `getPixel:2156`
`getPixel32:2190` `getPixels:2210`(**null**) `getSurface:2233`(**null**) `hitTest:2403`(false) `merge:2654`
`noise:2692` `perlinNoise:2889` `scroll:2907` `setPixel:2932` `setPixel32:2973` `setPixels:3000`。

→ **`readable=false` 时全是静默 no-op**：`getPixel32` 返回 **0**、`getPixels` 返回 **null**、`getSurface` 返回 **null**。
**「readable=false 后 getPixel32 崩」在纯 openfl 语义下不成立。**
注意 `copyPixels` 只校验**目标**的 `readable`（`:710`），源图若 GPU-only 则 `:719` 把 `null` 传给 lime，
而 `lime/graphics/Image.hx:415` `if (buffer == null || sourceImage == null) return;` → **静默不拷贝、不崩，结果是空白**（比崩更难查）。

真正崩的是 **E 态**（`readable=true` + `image=null`）：`getPixel32:2192` 的 `image.getPixel32(...)` 直接打在 null 上，
`-D HXCPP_CHECK_POINTER` 抛 `Null Object Reference`——这就是「崩」的真身。
同理 `getPixel:2158`、`__applyAlpha:3129`（无守卫）、`__fillRect:3267` 的可读分支。
**只要不写 `readable=true`，E 态不可达。**

`draw()` 特殊（文档 `:167-168`）：`readable=false` 走硬件路径（`:952` `if (!readable && Lib.current.stage.context3D != null)`）可用；`readable=true` 走 cairo 软件路径（`:1025` `new Cairo(getSurface())`）。

### Q3 · `disposeImage()` 在 native 上做了什么

`BitmapData.hx:823-826`，**全文两行**：`@:beta public function disposeImage():Void { readable = false; }`
无 `#if` 分支、不碰 `image`、不碰 `__texture`、不碰 `gl`。**一个字节都不释放**，只立「下次上传完就丢 CPU 副本」的旗子。
若这张图这一局再没被画过，CPU 像素永远留着（本项目 `auto` 模式的已知缺陷，`Paths.hx:1024-1026` 注释已写明）。

### Q4 · `dispose()` 逐行 / `gl.deleteTexture` 在哪

`BitmapData.hx:745-809`：
```haxe
747  #if (js && html5) ... 只销毁 canvas/context，且 !__asset ... #end   // native 全跳过
773  image = null;
775-777 width = 0; height = 0; rect = null;
779  __isValid = false;   780  readable = false;   782  __surface = null;
784  __vertexBuffer = null;   // 只置 null，没调 VertexBuffer3D.dispose()
785  __framebuffer = null;    // 只置 null，没调 gl.deleteFramebuffer()
787  __texture = null;        // 只置 null，没调 TextureBase.dispose()
790-808 // if (__texture != null) { ... gl.deleteTexture (__texture); __texture = null; }  ← 整块被注释
```
**`gl.deleteTexture` 全仓库只出现 2 次**：`BitmapData.hx:801`（**注释里**）与 `TextureBase.hx:96`（**唯一生效**）。
`TextureBase.dispose()`（`:84-117`）是唯一释放出口：`gl.deleteTexture(__textureID)`(96) →
`gl.deleteFramebuffer`(102) → `gl.deleteRenderbuffer`×2(108/114)，并递归 dispose `__alphaTexture`(90)。

native 与 html5 差异：html5 额外销毁 `canvas.width/height` 与 2D context（`:753-770`，且 `!__asset` 才做，
因为 html5 的 `Assets.getImage` 复用同一 Image 实例）；`__asset` 在 native 上**完全无用**（只在 `:753` 这个 html5 分支读）。

### Q5 · `getTexture(context)` 逐行 —— GPU caching 的真相

`BitmapData.hx:2254-2322`：
```haxe
2256  if (!__isValid) return null;                                     // D 态直接 null
2258  if (__texture == null || __textureContext != context.__context) {
2261      __texture = context.createRectangleTexture(width, height, BGRA, false);  // 立即分配显存
2268      __textureVersion = -1;                                       // 强制首帧上传
2269  }
2276  if (image != null && image.version > __textureVersion) {          // image==null 就永远跳过 → 稳态 0 开销
2278      if (__surface != null) __surface.flush();
2296      if (!textureImage.premultiplied && textureImage.transparent)  // native：必要时克隆去预乘
2298          textureImage = textureImage.clone();
2306      __texture.__uploadFromImage(textureImage);                    // ← 真正的 gl.texImage2D
2308      __textureVersion = image.version;
2310-2311 __textureWidth/Height = textureImage.buffer.w/h;
2312  }
2314  if (!readable && image != null) { __surface = null; image = null; }   // ★ 丢 CPU 副本的唯一位置
2321  return __texture;
```
1. **每帧每图都会调用**：`ShaderInput.hx:172` `context.setTextureAt(id, bitmapData.getTexture(context))`
   在 `__updateGL` 里，由 `Context3DBitmap.render:39 applyBitmapData` 触发。稳态开销 = 一次判空 + 一次 version 比较。
2. **丢 CPU 副本严格发生在「上传成功的同一帧」**，条件 `!readable && image != null`。`readable` 默认 true（`:321`），
   所以**正常 `Paths.image(key)` 的图永远不丢 CPU 副本**。
3. **`Paths.image(key, null, false)`（allowGPU=false）能保住像素的原因：它压根不调 `disposeImage()`**
   （`Paths.hx:1061` `if (allowGPU)`），`readable` 恒为 true，`:2314` 不成立。
4. **不存在 `__useDirectPath` 之类标志**，判据只有 `readable`。
5. `__textureVersion` 是脏标记：`image.version++` 后下次自动重传。

### Q6 · `fromTexture(texture)`

`BitmapData.hx:1393-1403`：
```haxe
var bitmapData = new BitmapData(texture.__width, texture.__height, true, 0);  // ← 分配 w*h*4 CPU buffer！
bitmapData.readable = false;
bitmapData.__texture = texture;  bitmapData.__textureContext = texture.__textureContext;
bitmapData.image = null;         // ← 刚分配的 buffer 立刻丢弃
```
结果 = **C 态**：`readable=false`、`image=null`、`__texture`=你的纹理、`__isValid=true`、
`width/height/rect/__textureWidth/Height` 由构造函数 `:264-269` 正确赋成 `texture.__width/__height`。
对它：`getTexture()` 已有纹理且 context 相同 → 直接返回；`draw()` → `__drawGL` 正常；`dispose()` → 只置 null，**纹理泄漏**。
代价：`new BitmapData(w,h,...)` 会 `new UInt8Array(w*h*4)`，随即 `image=null` 变垃圾——
**这张临时 CPU buffer 就是「hardware-only 路线峰值暴涨」的一半原因**（另一半见 Q7）。
**`clone()` 会共享纹理**：`:418-433` 的 `!readable && image == null` 分支里 `bitmapData.__texture = __texture;`
→ **任一方 dispose 另一方立刻变黑**。克隆体 `readable` 仍是 false（`new BitmapData(0,0,...)` 走不到 `:271` 的 `readable=true`），
所以对克隆体改像素会**写穿**或**静默丢**：`colorTransform:457`/`setPixels:3000`/`copyPixels:710` 全 no-op；
`fillRect`（`:1231` → `__fillRect:3213`，GPU 分支条件是 `__texture.__glFramebuffer != null`）会 `setRenderToTexture(__texture)`+`__clear()`
**整块清掉共享纹理**；`draw()`（`:3189`）直接写进共享纹理，且采样源也是它 → feedback loop。
注：`BitmapData.__framebuffer` 是死字段（`:428` 只传播、`:785` 置 null、创建代码 `:3335-3361` 已注释），真正的 framebuffer 在 `__texture.__glFramebuffer`
（由 `Context3D.hx:2261` 在首次渲染到该纹理时创建，或 `optimizeForRenderToTexture=true` 时在 `RectangleTexture.hx:39` 立即创建）。

### Q7 · `TextureBase.dispose()` / `uploadFromBitmapData()`

`RectangleTexture.uploadFromBitmapData`（`RectangleTexture.hx:52-74`）：`source == null` → return；
`var image = __getImage(source); if (image == null) return;`（**静默返回**）→ `uploadFromTypedArray(image.data)`
→ `gl.texImage2D(target,0,__internalFormat,__width,__height,0,__format,UNSIGNED_BYTE,data)`（`:119`）。

`__getImage`（`TextureBase.hx:185-235`）：`if (!bitmapData.__isValid || image == null) return null;`（`:189`）；
native 分支 `:224-231` **只在 `!image.premultiplied && image.transparent` 时**克隆并置 `premultiplied=true`。
而 `__fromImage` 在 sys 上已强制 `premultiplied=true`、`new BitmapData` 的 buffer 也是 true，
**所以正常路径不克隆、不预乘，上传不修改原 BitmapData**（唯一副作用是 GL 侧占用）。

尺寸：`__width/__height` 构造时固定（`RectangleTexture.hx:31-32`），`uploadFromTypedArray` 每次都用
`__width/__height` 而**不看传入数据长度** → **必须与源尺寸严格相等**，否则截断/越界。

`TextureBase.dispose()`（`:84-117`）：见 Q4。**不置 `__width/__height/__format`**，dispose 后对象仍在、
`__textureID=null`；`bitmap.__texture` 引用仍非 null，所以本项目 `MemoryStats` 那种 `__texture != null` 判据会高估。

### Q8 · 唯一可靠释放路径 + 泄漏黑名单

**唯一可靠路径（两条都要，顺序不能倒）**：
```haxe
if (bmp.__texture != null) bmp.__texture.dispose();  // 真的 gl.deleteTexture
bmp.dispose();                                       // 清引用 + __isValid=false
```
（`Paths.destroyGraphic:384-385`、`disposeGraphicData:369-371` 已是这个写法，**正确**。）

| 黑名单组合 | 结果 |
|---|---|
| `bmp.dispose()`（`__texture != null` 时） | 纹理 + framebuffer + 2 renderbuffer 全泄漏（`:787` 只置 null） |
| `FlxGraphic.destroy()` / `FlxDestroyUtil.dispose(bmp)`（flixel 默认，`FlxGraphic.hx:449`） | 同上；**flixel 全库没有 `TextureBase.dispose`** |
| 只 `Assets.cache.clear()` / `FlxG.bitmap.clear()` | 只清 Map 引用，无 dispose → 纹理泄漏 |
| 只 `disposeImage()` 后对象被 GC | 若中途被画过 → 泄漏且 CPU 已被丢；没画过则不泄漏但 CPU 白占 |
| `__texture.dispose()` 后仍被某个 `Bitmap` 用 | 永久黑图（`__textureContext` 未变，`getTexture` **不会重建**） |
| `clone()` 一个 C 态图后 dispose 其中一个的纹理 | 另一个永久黑（共享 `__texture`） |
| 反复 `new BitmapData` + `draw()` 不释放 | 每张漏 vertex buffer(224B) + index buffer(24B) + texture + framebuffer + depth/stencil |

**次要泄漏**：`dispose()` 同时漏掉 `__vertexBuffer`（`VertexBuffer3D.dispose()` 才有 `gl.deleteBuffer`，
`VertexBuffer3D.hx:80-84`）与 `__indexBuffer`（每张图独立，`BitmapData.hx:1453` `// TODO: Use shared buffer on context`）。

### Q9 · 官方显存/纹理计数查询

- `Context3D.totalGPUMemory`（`Context3D.hx:2804-2818`）：**只有 NVIDIA `NVX_gpu_memory_info` 存在时非 0**（`:380-388`），且返回 `(total - current) * 1024` = **「当前可用空闲显存」而非本进程已用**（源码 `// TODO: Return amount used by this application only`）；非 N 卡一律 `0`，**不可用于统计自己**。
- `TextureBase` 的 `__memoryUsage` / `__compressedMemoryUsage` / `__outputTextureMemoryUsage` **全部被注释**（`TextureBase.hx:42,50,52`）→ 单张纹理不记账。
- `-D gl_stats` 的 `Context3DStats` **只统计 draw call 数**（`stats/Context3DStats.hx:12-44`），无纹理数；`__textureID` 是 `GLTexture` 句柄（`:56`）**不是序号**，无法计数。
- **结论：无官方手段**。现实做法 = 本项目 `MemoryStats` 那样遍历自己的图按 `w*h*4` 累加，**但应改成 `__texture != null && __texture.__textureID != null`**（否则 dispose 后仍计入）；
  `__textureID` 是 `@:noCompletion private`，同样要 `@:access(openfl.display3D.textures.TextureBase)`。

### Q10 · `Assets.cache` 与 `BitmapData`

- `Assets.getBitmapData`（`Assets.hx:121-155`）**整段包在 `#if (lime && tools && !display)` 内**，否则 `return null`。
  本项目 **有 `-D tools=8.4.0`、无 `-D display`** → 这段**生效**。
- **不 clone**：`BitmapData.fromImage(image)`（`:141`）→ `__asset = true`（`:142`）→ `cache.setBitmapData(id, ...)`（`:147`），
  **同一实例**下次直接返回（`:126-131`）。
- **有效性判据就是 `image != null`**：`isValidBitmapData` → `return (bitmapData != null && bitmapData.image != null)`（`:494`）。
  **一旦 GPU-only 化（`image=null`），Assets 缓存判定失效，下次 `getBitmapData` 会重新解码一份新的**，
  旧的纹理挂在旧 BitmapData 上没人释放 → **同一 key 两份纹理 + 泄漏**。本项目主路径走 `BitmapData.fromFile`
  （`Paths.hx:1051`）绕开，但 `OpenFlAssets.getBitmapData` 那条 fallback（`:1053`）会中招。
- `Assets.cache.clear()`（`AssetCache.hx:80-87`）**只把三个 Map 换成新的**，不 dispose、
  不删 lime 的 `LimeAssets.cache.image`（只有 `removeBitmapData:194-200` 才删）。

---

## 4. 安全用法清单（硬规则）

1. **释放显存只有一条路**：`bmp.__texture.dispose(); bmp.dispose();`。只做前者 → 引用还在（永久黑，`getTexture` 不重建）；只做后者 → 纹理泄漏。**禁止**单独调 `BitmapData.dispose()` / `FlxGraphic.destroy()` / `FlxDestroyUtil.dispose()`。
2. **绝不写 `bitmap.readable = true`**（本项目因 `@:access` 才编得过）。E 态下 `getPixel32`/`getPixel`/`__applyAlpha` 在 null 上取方法 → `Null Object Reference`。要恢复可读只能重新解码。
3. **不要手动 `bitmap.image = null`**。`getSurface()` 只拿 `CairoImageSurface.fromImage(image)` 的裸指针（`:2237`），手置 null 留悬垂 surface；且 `image.version` 比较失效会让纹理永不更新。丢 CPU 副本只允许由 `getTexture()` 自己做。
4. **`auto` 档（只 `disposeImage()`）必须保证图这一局真会被画到**，否则 CPU 副本永远留着。要「预载即转显存」只能走 `createRectangleTexture + uploadFromBitmapData + fromTexture` 手动路线。
5. **自建纹理时 `optimizeForRenderToTexture` 传 `false`**。当前 `Paths.hx:990` 传 `true`，而 `RectangleTexture.hx:39` 在 `true` 时 `__getGLFramebuffer(true, 0, 0)` → **每张图**额外分配 framebuffer + depth + stencil（每像素约 +3 字节 ≈ 纹理本身的 **+75%**）。除非要 `draw()` 进这张纹理，一律 false。
6. **`fromTexture()` 有一次性 `w*h*4` 临时分配**（`new BitmapData` 建完即丢）。批量转换必须分批 + 批间触发 GC，否则 RSS 峰值 = 全量 CPU 图 + 全量纹理。
7. **`clone()` GPU-only 图会共享 `__texture`**（`:430`）。必须保证「1 纹理 : 1 所有者」；重复 dispose 因 `__textureID != null` 守卫是安全的，但「一个已 dispose、另一个还在画」= 永久黑图。
8. **不要依赖 `Assets.cache` 记住 GPU-only 图**：`isValidBitmapData` 只看 `image != null`，`image=null` 会被判失效并重解码（同 key 两份纹理）。`Assets.cache.clear()` **不释放任何显存**。
9. **不要用 `Context3D.totalGPUMemory` 统计**：只有 N 卡 `NVX_gpu_memory_info` 才有值，且返回的是*剩余*显存。自己记账（`w*h*4`，并查 `__textureID != null`）。
10. **`dispose()` 之后不要再 `draw()` 到它**：`getTexture()` 返回 null，`setRenderToTexture(null)` 不报错，后续绘制直接落到后台缓冲 → 花屏，极难定位。

---

## 5. 仍未确认的疑点

1. **`optimizeForRenderToTexture=true` 实际多分配多少**：取决于 `Context3D.__glDepthStencil != 0`（`TextureBase.hx:145`）走「单 `DEPTH_STENCIL`」还是「`DEPTH_COMPONENT16`+`STENCIL_INDEX8`」，未实测本机；两种都是 +2~3 B/px。
2. **BGRA 回落的实际影响**：`__initFormats` 找不到 `EXT_bgra/EXT_texture_format_BGRA8888/APPLE_...` 时 `__format=gl.RGBA` 但送的仍是 BGRA 数据（`__uploadFromImage:452` 不转通道）→ 红蓝互换。自建路径同样如此（native 分支不转 RGBA32），所以**不比 openfl 更危险**，但未实测本机扩展支持。
3. **`fromTexture` 里的 `new BitmapData(w,h,true,0)`** 因 `transparent && fillColor==0` 被压成 0（`:275-278`）→ 不执行 `fillRect`，buffer 是零初始化内存。hxcpp 是否 lazy 成 zero-page 从而不真占 RSS 未验证（影响峰值结论严重度）。
4. **context 丢失/重建**：`getTexture` 用 `__textureContext != context.__context` 判断，变了会新建纹理、**旧的不 dispose**。理论上整个 GL context 一起没了不算漏，但「同进程换 window」场景未验证。
5. **`TextureBase.dispose()` 之后再 `setTextureAt`**：`__textureID=null` 时 `__bindGLTexture2D(null)` 依赖 lime 的 `GL` 包装，未逐行确认是否只是 bind 0。

---

## 6. 附注：NovaFlare fork 的 openfl 差异

fork 在 `F:/FNF-NovaFlare-Engine/.haxelib/openfl/git/`（声明 9.5.0，对应 `-D openfl=9.5.0`）。**`dispose()` / `disposeImage()` / `RectangleTexture` 与本文所述逐字节一致**
（`gl.deleteTexture` 同样在注释里，fork 行 `:799-817`；fork 全库 `__texture.dispose()` 零命中）→ **不存在「fork 补回了纹理释放」**，
NovaFlare 那条 `destroyOnNoUse = true` → `FlxGraphic.destroy()` → `BitmapData.dispose()` 的软释放路线，与上游一样漏纹理。
fork 真正新增两样（**上游没有**，FE 若要照搬得自建）：`disposeOnUpload`（`getTexture()` 上传成功后自动 `readable = false`，fork `:2317`，
由 openfl 自己丢 CPU 副本 —— **hardware-only 的正确解法**，没有 `fromTexture` 的 `w*h*4` 临时 buffer），
以及 `getTextureAsync` + `_internal/AsyncTextureUploader.hx`（`texImage2D(...,null)` 预分配后**每帧只 `texSubImage2D` 一个瓦片**，把单帧尖峰摊到 N 帧）。
