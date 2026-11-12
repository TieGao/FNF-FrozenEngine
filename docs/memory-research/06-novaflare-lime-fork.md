# NovaFlare 的 lime fork（补充探查，2026-11-12）

> 前五份调查只看了 `F:/FNF-NovaFlare-Engine/.haxelib/openfl/git/`（fork 的 openfl）和 NF 的 `source/`，
> **没有进 `D:/HaxeToolkit/haxe/lib/lime/`**。这份补上。仅探查，未改任何代码。

## 身份

`D:/HaxeToolkit/haxe/lib/lime/git/` 是 fork 的 lime，remote：

```
https://github.com/NovaFlare-Engine-haxelib/lime-8.3.0
```

`haxelib.json` 声明 8.3.0，但**带 .git 历史**（可以直接 `git log` / `git show`）。D 盘另有一个纯版本的
`8,3,2/`（无 git）。项目实际用哪个由 `.haxelib` 决定。

## 相对上游 lime 8.4.0 的全部实质改动

只看 `src/`，Haxe 层一共 **两处**：

### 1. `Image.setMaxTextureSize(size:Int)`（`src/lime/graphics/Image.hx:1393-1402`）

```haxe
/**
    Sets the maximum supported texture size for automatic downscaling when loading images.
    This should be called when the OpenGL context is initialized.
    @param	size	The maximum texture size (e.g. 16384). Pass 0 to disable downscaling.
**/
public static function setMaxTextureSize(size:Int):Void
{
    #if (lime_cffi && !macro)
    NativeCFFI.lime_image_set_max_texture_size(size);
    #end
}
```

引入提交是 **`521ff704 加入图像大小兼容，解决黑块问题`**（2025-12-17，作者 beihu235）——
不是 NovaFlare 自己加的，是 fork 的上游作者为了「超尺寸贴图被驱动拒绝导致黑块」做的兜底。

### 2. `ImageBuffer.graphicScale:Float = 1.0`（`src/lime/graphics/ImageBuffer.hx:82`）

C++ 侧在 `ExternalInterface.cpp:2112` 把缩放比写进返回对象：

```cpp
alloc_field (ret, val_id ("graphicScale"), alloc_float (scale));
```

## C++ 侧机制（`project/src/ExternalInterface.cpp:2018-2113`）

```cpp
static int gMaxTextureSize = 0;                       // set_max_texture_size 写入

// lime_image_load_file() 里，解码成功之后：
int maxTextureSize = gMaxTextureSize;
if (maxTextureSize > 0 && (imageBuffer.width > maxTextureSize || imageBuffer.height > maxTextureSize)) {
    float scaleW = (imageBuffer.width  > maxTextureSize) ? (float)maxTextureSize / imageBuffer.width  : 1.0;
    float scaleH = (imageBuffer.height > maxTextureSize) ? (float)maxTextureSize / imageBuffer.height : 1.0;
    scale = min(scaleW, scaleH);
    ImageDataUtil::Resize (srcImage, destBuffer, newWidth, newHeight);
    imageBuffer.width  = newWidth;
    imageBuffer.height = newHeight;
}
```

要点：**缩放发生在解码那一刻**，用的是 lime 自己的 `ImageDataUtil::Resize`（直接操作像素缓冲），
不是在 openfl/flixel 层用 `BitmapData.draw` 缩。缩完 `imageBuffer.width/height` 就是新尺寸。

## NovaFlare 侧怎么用（`source/states/backend/initState/InitState.hx:130-132`）

```haxe
var maxTextureSize:Int = GL.getParameter(GL.MAX_TEXTURE_SIZE);
trace('maxTextureSize: ' + maxTextureSize);
Image.setMaxTextureSize(maxTextureSize);
```

即：**拿 GL 的上限当阈值**（桌面一般 16384），只是个防崩溃兜底。NF 没有把它调小当降采样开关用。

## 关键结论：它不是「CPU 侧缓存卸载」，也不能直接解决我们的 P3

1. **不是"卸载"**：没有新增任何 `dispose` / `data = null` / 释放 CPU 副本的代码。
   lime 层实际做的是**解码期缩图**（减少解码后的像素量），名字上更接近"降采样"。
   朋友说的"CPU 侧缓存卸载"如果指「上传后释放 CPU 侧数据」，那是 **openfl fork 的 `disposeOnUpload`**
   （见 `01-openfl-gpu-caching.md` 第 6 节），不在 lime。

2. **`graphicScale` 没人消费**：整个 openfl fork 里它只有两处 —— 定义（`BitmapData.hx:204`）和赋值
   （`:3385-3388`），**没有任何读取方**。`BitmapData.width/height` 用的是缩小后的 `image.width/height`。
   所以真把 max 调小，所有超尺寸图会**变小、构图错位**，和我们 P3 回退前的症状同源（只是发生在更底层）。

3. **但它证明了一件事**：把缩放点放在「解码完成、FlxGraphic 创建之前」是可行的，而且比我们在
   `Paths.image()` 里 `BitmapData.draw` 更高效（C++ 直接改缓冲，无额外临时 BitmapData）。
   如果要做，仍然必须解决**帧坐标**问题 —— 图集描述文件（xml/json/txt）里的坐标得按同一比例缩，
   否则 uv 基准变了照样错位（`FlxFrame.uv` 是按 `frame.x / parent.width` 算的）。

## 移植到 FE 的成本

| 方案 | 改动 | 成本 | 风险 |
|---|---|---|---|
| fork lime（照抄这套） | 改 `ExternalInterface.cpp` + 重编 Windows/Android/mac 三套 ndll | **高**（要为每个平台维护 ndll） | 重编后与上游 lime 脱节 |
| Haxe 层模拟（在 `Paths.image()` 解码后 `draw` 缩放） | 只改 FE | 低 | 就是 P3 的老问题：帧坐标 |
| **正解：解码后缩图 + 同步缩图集描述坐标** | 改 FE，写 sparrow/packer/texturepacker 三种格式的坐标重写 | 中 | 无（uv 基准一致） |

所以这个 fork 的价值是**佐证"解码期缩"这条路可行**，而不是提供一个能直接抄的完整方案。
