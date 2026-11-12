# flixel 6.2.1 贴图引用与缓存语义（FlxGraphic / FlxG.bitmap / FlxFrame）

源码根：`E:/HaxeToolkit/haxe/lib/flixel/6,2,1/flixel/`（下文行号均指此树）。只读调查，未改任何源码。

## 1. 一句话总览

flixel 的 `useCount` **只统计「有多少个 FlxSprite 正在引用这张图」**——既不是 GC 引用计数，也不是「还有没有人攥着 frames」：`FlxFrame.parent` / `FlxFramesCollection.parent` 都是**强引用但不计数**，而 `FlxGraphic.destroy()` 会销毁 frames 数组并 dispose bitmap。所以「useCount==0 就销毁」这条判据在 flixel 里本来就不安全，引擎必须自己兜住 frames 的存活。

## 2. 生命周期图

```
BitmapData            FlxGraphic                 FlxFramesCollection        FlxSprite
(openfl,无计数)  <--  bitmap:BitmapData      <--  parent:FlxGraphic     <--  graphic:FlxGraphic
                      useCount:Int (335)          无 useCount(*)              frames:FlxFramesCollection
                      ↑ 只有 5 处动它              (FlxAtlasFrames 例外:20)     ↑ set_graphic(1936) 唯一计数点
```
- `BitmapData` 层无引用计数；`BitmapData.dispose()` **不删 GL 纹理**（openfl `9,5,2/src/openfl/display/BitmapData.hx:773-788`，`gl.deleteTexture` 整段被注释），只把 `__texture = null`。
- `FlxGraphic` 层：`useCount`（`FlxGraphic.hx:335`），构造时 0（`404-414`），**不自动 +1**。
- `FlxFramesCollection` 层：**没有** useCount；`FlxAtlasFrames.addAtlas` 例外，用 `usedGraphics` 顶计数（`FlxAtlasFrames.hx:20, 469-473`）。
- 改 `useCount` 的全部位置：`FlxSprite.hx:1942/1946`、`FlxTilemap.hx:1247/1251`、`FlxBar.hx:1000/1003`、`FlxAtlasFrames.hx:472/30`、项目侧 `Paths.hx:118/134`（pin/unpin）。

## 3. 十个问题

### Q1 `useCount` 完整语义
```haxe
// FlxGraphic.hx:561-577
public function incrementUseCount() { useCount++; }
public function decrementUseCount() { useCount--; checkUseCount(); }
function checkUseCount()
{
    if (useCount <= 0 && destroyOnNoUse && !persist)
        FlxG.bitmap.remove(this);
}
```
`FlxSprite.destroy()` 对 graphic 只做一件事——置空引用触发递减：
```haxe
// FlxSprite.hx:443-446
frames = null;
graphic = null;      // → set_graphic(null) 1946: graphic.decrementUseCount()
_frame = FlxDestroyUtil.destroy(_frame);
_frameGraphic = FlxDestroyUtil.destroy(_frameGraphic);
```
**关键：sprite 没 `destroy()` 就被 GC，`useCount` 永远不归零**——hxcpp 没有 finalizer，计数只在 `set_graphic` 里变；这张图还被 `BitmapFrontEnd._cache`（`BitmapFrontEnd.hx:40`，强引用 Map）钉住，连同 `BitmapData` 永久驻留。这就是 2.61GB 的机制：**泄漏单位是「一次没 destroy 的 sprite 创建」**。补充：`destroy()` 不把 `useCount` 归零（可能留成负数），`FlxG.bitmap.remove()` 也不检查它。

### Q2 `persist` / `destroyOnNoUse` 判定链
唯一自动销毁路径是 `decrementUseCount → checkUseCount`，条件 `useCount<=0 && destroyOnNoUse && !persist`（`575`）→ `FlxG.bitmap.remove`。`destroyOnNoUse` 的 setter 也会判定（`579-586`），置 `true` 且 `useCount<=0` 时**立即销毁**；置 `false` 安全。`persist = true` 时**真的永不自动销毁**：三条自动回收路径都带 `!persist`（`575`、`clearCache:290`、`clearUnused:337`）。`FlxG.bitmap.remove()` **会顺手 destroy**：
```haxe
// BitmapFrontEnd.hx:242-251
removeKey(graphic.key);              // Assets.cache.removeBitmapData + _cache.remove
if (!graphic.isDestroyed)            // isDestroyed == shader == null (546-549)
    graphic.destroy();               // dispose bitmap + 销毁所有 frames
```

### Q3 `FlxG.bitmap` 缓存行为
| 操作 | 语义 | 证据 |
|---|---|---|
| `create(w,h,color,unique=false,?key)` | 转 `fromRectangle`；persist 取 `defaultPersist`（默认 false） | `84-87`；`FlxGraphic.hx:25, 404-407` |
| `add(asset,unique,key)` | 转 `fromAssetKey`/`fromBitmapData`/`fromGraphic` | `96-109` |
| `add(Graphic, unique=false)` | `if (!Unique) return Source;` 原样返回，不碰缓存 | `FlxGraphic.hx:189-190` |
| `add(BitmapData, true)` | `getBitmap` 会 `Bitmap.clone()`，多一份像素 | `FlxGraphic.hx:230-233` |
| `addGraphic` | `_cache.set(key, graphic)`，同 key **静默覆盖、不销毁旧对象** | `117-121` |
| `remove` / `removeByKey` | removeKey + `destroy()`（后者无 `isDestroyed` 保护） | `242-267` |
| `removeIfNoUse` / `clearCache` / `clearUnused` | 三者都是「`!persist` + `useCount<=0`」，`clearUnused` 另加 `destroyOnNoUse` | `269-342` |
| `reset` | 清空全部（含 persist），逐个 destroy | `310-326` |

`fromBitmapData` 的同 key 行为最易误用：
```haxe
// FlxGraphic.hx:121-129
key = FlxG.bitmap.generateKey(key, Key, Unique);
graphic = FlxG.bitmap.get(key);
if (graphic != null)
    return graphic;        // ← 直接返回缓存对象，你传入的 Source 被丢弃、无人释放
graphic = createGraphic(Source, key, Unique);
```
**`dump` 在 6.2.1 已不存在**：只剩 `refresh()`（`419-424`，从 assets 重新取图）与 `@:deprecated undump`（`427`）；`FlxG.bitmap` 无 `dump`。可视化是 `BitmapLogFrontEnd`（仅 `FLX_DEBUG`）。

### Q4 `FlxGraphic.bitmap` 的 setter
```haxe
// FlxGraphic.hx:601-620
function set_bitmap(value:BitmapData):BitmapData
{
    if (value != null)
    {
        bitmap = value;
        width = bitmap.width;
        height = bitmap.height;
        ... // 只有 maxTextureSize 警告
    }
    return value;
}
```
- 不碰 `useCount`、cache、frames——`FlxFrame.parent` 指向 `FlxGraphic` 本身，帧会「自动」看到新像素。
- **旧 BitmapData 不会被 dispose**：直接覆盖，谁换谁负责。
- **尺寸变化静默毁掉所有帧**：`uv` 是 `frame.x / parent.width` 预算好的（`FlxFrame.hx:809-818, 878-881`），setter 改了 `width/height` 却无任何 uv 失效逻辑。同尺寸替换安全，异尺寸 = 顶点（`frame` 矩形）与采样（`uv`）错位。
- `value == null` 时字段**不置空**（被 `if` 包住），而 `destroy()` 传的正是 `dispose(bitmap)` 返回的 null（`447-449`）→ **销毁后 `graphic.bitmap` 仍指向已 dispose 的对象，不是 null**。

### Q5 `FlxFrame` 的可变性
```haxe
// FlxFrame.hx:801-807 —— setter 只重算 uv
function set_frame(value:FlxRect):FlxRect { frame = value; updateUV(); return value; }
// FlxFrame.hx:166-174 —— 矩阵只在这里算
@:allow(flixel.graphics.frames.FlxFramesCollection)
@:allow(flixel.graphics.frames.FlxBitmapFont)
function cacheFrameMatrix():Void { blitMatrix.copyFrom(this, true); if (FlxG.renderTile) tileMatrix.copyFrom(this, false); }
```
`cacheFrameMatrix` 是 **private + 两个 `@:allow`，外部不可调用**；公开调用链只有 `pushFrame(373)`、`addAtlasFrame`（经 pushFrame）、`copyTo(780)`、`clip(744)`、`subFrameTo(600)`。
| 字段 | 可改？ | 说明 |
|---|---|---|
| `offset` / `duration` | 安全 | `offset` 是 `(default,null)`，只能就地 `.set()`；`duration` 有官方入口 `setFrameDuration:328` |
| `sourceSize` | 危险 | `(default,null)`，就地改影响**所有共享该帧的 sprite**；改后要 `resetFrameSize()` |
| `frame` | **危险** | setter 只更新 uv，矩阵仍旧，裸改后该帧无法独立渲染 |
改 frame 的正确姿势：① 走 `clip / subFrameTo / copyTo / pushFrame`（内部会 cacheFrameMatrix）；② 已挂到 sprite 上的，改完必须 `sprite.frame = sprite.frame`（或 `resetFrame()`，`FlxSprite.hx:712-715`），`set_frame`（`1834-1862`）会 `frame.copyTo(_frame)` 重算矩阵。**没有任何官方「运行期缩帧/降采样」API**（`FlxBitmapDataUtil` 只有 merge/compare/replaceColor/addSpacesAndBorders/copyBorderPixels/generateRotations）。

### Q6 `FlxImageFrame` / `FlxGraphic.imageFrame`
```haxe
// FlxGraphic.hx:340, 588-594
public var imageFrame(get, null):FlxImageFrame;    // set 为 null：对外只读（类内可写）
function get_imageFrame():FlxImageFrame
{
    if (imageFrame == null) imageFrame = FlxImageFrame.fromRectangle(this);  // 懒建一次
    return imageFrame;
}
```
懒建并缓存在 `frameCollections[IMAGE]`；`FlxImageFrame.new` 是 private（`FlxImageFrame.hx:25`），`fromGraphic` 遇 `graphic == null || isDestroyed` 返回 null（`92-96`）。
「逻辑尺寸不变、只换更小纹理」flixel **没有直接入口**，只有三种间接做法：① `loadGraphic(big)` + `setGraphicSize(w,h)` + `updateHitbox()`（靠 scale，纹理不变，`FlxSprite.hx:724-737`）；② `loadGraphic(small)` 后自己保持 `scale` / `resetFrameSize()`；③ `FlxGraphic.fromFrame(smallFrame)`（`143-159`，`Source.paint()` 出像素）建裁剪后的新图。另：`frameWidth/frameHeight` 是 `(default,null)`（`182-187`），只能经 `frame.sourceSize` + `resetFrameSize()` 间接改，且改的是共享帧。

### Q7 `FlxSprite.loadGraphic` 的分支
```haxe
// FlxSprite.hx:504-528
var graph:FlxGraphic = FlxG.bitmap.add(graphic, unique, key);
if (frameWidth == 0)
{
    frameWidth = animated ? graph.height : graph.width;       // animated: 按单行正方形帧
    frameWidth = (frameWidth > graph.width) ? graph.width : frameWidth;
}
if (frameHeight == 0) { frameHeight = animated ? frameWidth : graph.height; ... }
if (animated) frames = FlxTileFrames.fromGraphic(graph, frameWidth, frameHeight);
else          frames = graph.imageFrame;                      // 整图单帧，全局共享同一 FlxImageFrame

// FlxSprite.hx:1973-1998 —— set_frames 对旧 frames 不做计数，旧图递减靠 graphic setter
if (Frames != null)
{
    graphic = Frames.parent;    // ← 这里才 decrement 旧 graphic
    frames = Frames;
    frame = frames.getByIndex(0);
    ...
}
else { frames = null; frame = null; graphic = null; }
```
`unique` 透传到 `fromBitmapData/fromGraphic`，true 会 `clone()` 一份 `BitmapData`（独立缓存槽、可独立改像素）。frames 集合是 graphic 的附属物（`FlxGraphic.addFrameCollection:472-482`），**不能单独销毁**，多 sprite 共享同一份。

### Q8 `FlxText`
```haxe
// FlxText.hx:942-946 —— 只有尺寸变了才建新图
if (textField.textHeight != 0 && (oldWidth != newWidth || oldHeight != newHeight))
{
    final key:String = FlxG.bitmap.getUniqueKey("text");
    makeGraphic(newWidth, newHeight, FlxColor.TRANSPARENT, false, key);
}
else graphic.bitmap.fillRect(_flashRect, FlxColor.TRANSPARENT);   // 否则复用，只清空

// FlxText.hx:870-876 —— 旧图靠 override 的 setter 收
override function set_graphic(Value:FlxGraphic):FlxGraphic
{
    var oldGraphic:FlxGraphic = graphic;
    var graph:FlxGraphic = super.set_graphic(Value);   // 旧图 useCount -1
    FlxG.bitmap.removeIfNoUse(oldGraphic);             // ==0 && !persist → remove → destroy
    return graph;
}
```
清理链 `decrement → removeIfNoUse → remove → destroy → BitmapData.dispose()`，**漏 GL 纹理**（见 §2）。另：`_borderPixels = graphic.bitmap.clone()`（`955`）在 `destroy()`（`254-263`）里**从未释放**。

### Q9 `FlxGame.switchState` / `resetState`
```haxe
// FlxGame.hx:571-588
if (_state != null) _state.destroy();     // 1. 先销毁旧状态（add 过的对象在此减计数）
FlxG.bitmap.clearCache();                 // 2. 再清缓存（只清 !persist && useCount<=0）
_state = _nextState.createInstance();      // 3. 才 new 新状态
_state._constructor = _nextState.getConstructor();
FlxG.signals.preStateCreate.dispatch(_state);
_state.create();                          // 4. 最后 create
```
`_constructor` 是 `()->FlxState`（`FlxState.hx:53`），`FlxG.resetState()` 即 `switchState(state._constructor)`（`FlxG.hx:395-398`）；`FlxState.destroy()` 会把它换成抛异常函数（`170-175`）。
**二次 create 的坑**：`NextState.createInstance()` 若目标是**实例**（旧写法 `switchState(new PlayState())`）会直接 `return cast this`（`NextState.hx:50-58`）——同一个实例被 `create()` 两次而它已 destroy 过。必须传 `PlayState.new` / `()->new PlayState(...)`。

### Q10 正确卸载姿势
flixel 的语义假设是：① 每个 sprite 都会被 destroy；② 没人在 `graphic` 之外持有 `frames`；③ `BitmapData.dispose()` 能释放显存（在 openfl 上**不成立**）。自管生命周期的正确配法：
```haxe
var g = FlxGraphic.fromBitmapData(bd, false, key);  // 落进 FlxG.bitmap
g.persist = true;          // 挡 clearCache / clearUnused / removeIfNoUse
g.destroyOnNoUse = false;  // 挡 decrementUseCount（双保险，含义不同）
// 拆：1) 让所有 sprite 放手 → useCount 归 0，但不会销毁
// 2) 自己释放显存（openfl dispose 不删 GL 纹理）
if (g.bitmap != null && g.bitmap.__texture != null) g.bitmap.__texture.dispose();
// 3) 交给 flixel 摘缓存 + destroy（会再 dispose 一次 bitmap，幂等）
FlxG.bitmap.remove(g);     // removeKey → Assets.cache.removeBitmapData → g.destroy()
// 4) 不要再调 g.destroy()，remove 已做，且有 isDestroyed 保护
```
**铁律：先解除 sprite 引用，再销毁。** `FlxGraphic.destroy()` 会 `destroyArray` 掉所有 frames（`456-464` → `FlxFramesCollection.destroy:132-139` → `FlxFrame.destroy:784-794`，`parent = null`），此时任何还拿着 `frames`/`frame` 的对象立刻悬垂。

## 4. 引擎侧正确用法手册
1. **`useCount` 只等于「活着的 sprite 数」**，不能当「安全销毁」的判据（frames 的 parent 是强引用但不计数）。
2. **每个 sprite 必须 `destroy()`**，否则它引用的图永久钉在 `FlxG.bitmap._cache` 里——2.61GB 的成因。
3. **不要在 `useCount > 0` 时销毁图**；排队等引用也不可靠：引用永不降，队列永不收。
4. **`FlxG.bitmap.remove()` = 摘缓存 + dispose bitmap + 销毁所有 frames**；只想放显存就别走它，自己动 `__texture`。
5. **`graphic.bitmap` 只能在尺寸完全相同时替换**；尺寸变了所有 `uv` 失效且无 API 重算。
6. **不要裸改 `FlxFrame.frame`**；改帧走 `clip/subFrameTo/copyTo/pushFrame`，或改完 `sprite.resetFrame()`。
7. **`FlxFrame.offset/sourceSize` 是共享可变对象**，改它就是改所有共享该帧的 sprite。
8. **设了 persist 就必须自己兜底回收**：`clearCache()` 每次切状态都跑，但对 persist 图完全无效。
9. **`persist` 要在 useCount 归零前设**；注意 `destroyOnNoUse = true` 的赋值有立即销毁的副作用。
10. **`fromBitmapData(bd, false, key)` 会命中缓存并丢弃你刚解码的 `bd`**——先 `get(key)` 判重，或接受这份像素泄漏。
反例：同 key 二次解码不判重（第二份 `BitmapData` 无引用、永泄漏）；`persist = true` 之后以为 `clearCache` 会收（不会）；为省内存换降采样 bitmap（uv 全错，角色炸）。

## 5. 现有 `Paths` 实现与 flixel 语义冲突/危险点
1. **`persist=true` + `destroyOnNoUse=false` 让 flixel 全部自动回收失效**（`Paths.hx:1070-1071, 1126-1127, 1137-1138`）。意图正确，但 `switchState` 里的 `clearCache()` 从此空跑，**任何 Paths 记账漏掉的 key 再也回收不了**；`149-155` 那段对非记账 key 的兜底是这个设计的前提，不能删。
2. **拿 `useCount <= 0` 当「没人引用」是错的**（`Paths.hx:312, 338`）。反例：sprite 已 `graphic = null` 但还持有 `frames`，或外部缓存了 `FlxAtlasFrames`——计数为 0，`destroyGraphic` 一跑 frames 全废。这正是注释里「抽掉精灵池还攥着的图集」，只是被 `pendingReleases` 延后，不是解决。
3. **`destroyGraphic` 顺序反了**（`Paths.hx:384-398`）：先 `__texture.dispose()` 再 `FlxG.bitmap.remove` → 内部又 `graphic.destroy() → bitmap.dispose()`。现在不炸只是因为 openfl 的 `dispose()` 只置 null——靠实现细节活着。
4. **`graphic.bitmap = makeHardwareOnly(graphic.bitmap)`（`1029`）**：尺寸不变时安全（`990` 用 `bitmap.width/height` 建纹理），但一旦引入降采样走这条路径，`uv` 会静默失效。
5. **`fromBitmapData(bitmap, false, cacheKey)`（`1067`、`1125`）可能返回旧对象并丢弃新解码的 bitmap**；`1038-1044` 的预查缓解了大部分但非原子（不同文件解析到同 key 仍会命中）。
6. **直接读私有 `FlxG.bitmap._cache`**（`149` + `@:access(...BitmapFrontEnd._cache)`）：flixel 升级即断，且遍历中 `releaseGraphic` 会改 Map。
7. **`disposeGraphicData`（`365-372`）与 `destroyGraphic`（`378-399`）职责重叠**：前者跑完后 `isDestroyed` 仍 false、`bitmap` 仍非 null（只是 `__texture == null`），这个「半死」状态无标记，后续渲染会拿到空纹理。另外 `FlxText` 的旧图不在 Paths 记账里，只靠 `removeIfNoUse → BitmapData.dispose()`（漏纹理），`_borderPixels` 的 clone 更是无人释放。

## 6. 疑点
- `FlxGraphic.destroy()` 不重置 `useCount`、不自己摘 cache（依赖 `BitmapFrontEnd.remove`），`isDestroyed` 靠 `shader == null` 这个隐式标记；`removeByKey` 无保护，同一对象被 remove 两次会 destroy 两次（`FlxFrame.destroy` 勉强幂等）。
- `FlxAtlasFrames.addAtlas`（`464-476`）把**同一批 FlxFrame 对象**推进第二个集合（`pushFrame` 不复制），两边 `parent` 仍指第一个 graphic，两个集合各自 destroy 会二次 destroy 同一批 frame；`concat()`（`487-493`）还有明显 bug：`addAtlas(this)` 调两次、最后 `return this`。
- `FlxFrame.copyTo`（`759-782`）不复制 `uv`，靠 `clone.frame = ...` 的 setter 重算（赋相同 Rect 也会重算，目前安全）。
- `FlxSprite.updateFramePixels`（`1609-1615`）用 `fromBitmapData(framePixels, false, null, false)` 建**不入缓存**的 graphic（`Cache=false` → `new FlxGraphic(null, bitmap)`），`key == null`：`FlxG.bitmap.remove` 对它是「removeKey 空操作但照样 destroy」，语义别扭。
- `FlxGraphic` 构造的 `?persist` 参数（`404`）所有工厂方法都不传，实际永远取 `defaultPersist`；要改默认只能改静态变量，而 Paths 是逐张设。

## 7. 与 openfl 侧的接口（GL 纹理所有权，详见 `01-openfl-gpu-caching.md`）
flixel 侧确认：`FlxGraphic.destroy()` 唯一出口是 `bitmap = FlxDestroyUtil.dispose(bitmap)`（`FlxGraphic.hx:449`）→ `BitmapData.dispose()`；**flixel 全库没有一处 `TextureBase.dispose`**。所以只要走 flixel 原生销毁，GL 纹理必漏。
flixel 内部自建、且默认走原生销毁（= 漏纹理）的临时图清单：
- `FlxText` 的文本图：`FlxText.hx:945-946`（key `textN`）→ `FlxText.hx:874 removeIfNoUse` → `remove` → `destroy`。
- `FlxG.bitmap.create` / `makeGraphic` / `FlxGraphic.fromRectangle` 出来的图（`BitmapFrontEnd.hx:84-87`）。
- `FlxSprite._frameGraphic`：`FlxSprite.hx:1611-1614` 用 `Cache=false` 建的**未登记**图，`_frame` 的 parent 指向它，`destroy` 时照样只 `dispose`。
- `FlxGraphic.fromFrame` 的 `Source.paint()` 结果（`FlxGraphic.hx:154-155`）。
这些图 `useCount` 从 0 起（只有被 `sprite.graphic =` 接管才 +1），`Paths` 的记账也覆盖不到 —— 它们只能靠 `clearStoredMemory` 里 `149-155` 的非记账兜底扫到。
`bitmap.clone()` 在 flixel 里的全部调用点（若源是 GPU-only，openfl 侧会共享 `__texture`）：`FlxGraphic.hx:232`（`unique=true` 时）、`FlxText.hx:955`（`_borderPixels`，半透明描边 `_hasBorderAlpha` 才走）、`FlxBar.hx:648/690`、`FlxSpriteButton.hx:53`、`FlxSpriteUtil.hx:67/89`。其中 `FlxText` 的 `_borderPixels` 后续会 `fillRect / colorTransform / draw`，且**永远不被释放**（`destroy` 里没有它）。
最后一条给 Paths 的判活前提：`set_bitmap` 忽略 null，**destroy 后 `graphic.bitmap` 仍非 null**（只是 `__texture == null`），所以 `bitmap != null` 不能当「还活着」，必须再看 `isDestroyed` / `__texture`。

## 8. GPU-only（`readable=false`）下会被打破的 flixel 调用（给 openfl 侧对表）
`readable` 在 flixel 6.2.1 全库 **0 命中**（既无读也无写），所以「毒状态」不可能由 flixel 自己触发；只有 Paths 的 `makeHardwareOnly` 会造出 GPU-only 图。被它打破的 flixel 路径：
- **直接原地写 `graphic.bitmap`**（`fillRect`/`draw` 写穿，`colorTransform`/`copyPixels`/`setPixels` 静默丢）：`FlxSprite.stamp`（`FlxSprite.hx:1080/1095`）、`FlxSpriteUtil.updateSpriteGraphic`（`util/FlxSpriteUtil.hx:614`，`drawLine/drawRect/drawCircle/drawTriangles` 全走它）、`FlxSpriteUtil.fill`（`:670`）、`FlxSpriteUtil.alphaMaskFlxSprite`（`:89 clone → copyChannel → output.pixels =`，会把 GPU-only 克隆注册成新图）、`FlxText`（`:955 clone / :967 fillRect / :1230 draw`）、`FlxFilterFrames`（`graphics/frames/FlxFilterFrames.hx:179/196`，作用于它自建 bitmap）、`FlxBitmapText`（`:1184/1372/1378`）、`FlxBar`（`:752/814`）、`FlxTilemapBuffer`（`:166/199`）。
- **读取类**：`FlxFrame.paint` 的 ANGLE_0 分支走 `bmd.copyPixels(parent.bitmap, ...)`（`FlxFrame.hx:405`）——openfl 的 `copyPixels` 只校验**目标** readable，随后直接 `image.copyPixels(sourceBitmapData.image, ...)`（`BitmapData.hx:710-721`），GPU-only 源的 `image == null`；`FlxFrame.getPixelAt`（`:325` `parent.bitmap.getPixel32`）恒返回 0。
- 结论：GPU-only 只能给「纯显示、绝不二次加工」的图；`stamp / drawLine / fill / paint / getPixelAt` 全是雷。`unique=true` 的 `clone()` 契约在 GPU-only 下也失效（共享 `__texture`），见 §7。


