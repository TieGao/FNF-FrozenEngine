package options.objects;

import flixel.FlxBasic;
import flixel.FlxCamera;

/**
 * 界面控件的鼠标命中判定入口。
 *
 * `FlxG.mouse.overlaps(obj)` 不传相机时，两边的坐标空间是分开取的：
 * "指针点"按 `FlxG.camera` 换算，"对象的屏幕位置"按 `obj.getDefaultCamera()` 换算。
 * 控件画在"不滚动、不缩放"的相机上（例如暂停菜单的 `camOther`）而自己解析不到那台相机时，
 * 命中区就会整体偏掉 —— 光靠 `scrollFactor.set()` 只治得了 scroll，`zoom != 1` 时还差一个缩放。
 * 界面在这里声明"我画在哪台相机上"，指针侧与对象侧就统一到同一台相机了。
 *
 * 没有声明时（栈为空）行为与直接调 `FlxG.mouse.*` 完全一致，
 * Win10 设置页这类不声明相机的界面不受影响。
 */
class OptionInput
{
	/**
	 * 声明栈，后声明的优先。
	 * 用栈而不是单个字段，是因为界面可以嵌套（暂停菜单浮出层里再开一个子浮出层）：
	 * 内层解绑不该把外层仍然有效的声明一起抹掉。
	 */
	static var stack:Array<{owner:FlxBasic, cam:FlxCamera}> = [];

	/** 栈顶相机的缓存 —— 命中判定一帧要读很多次，别每次都去翻数组。 */
	static var camera:FlxCamera = null;

	/**
	 * 声明 owner 这个界面画在 cam 上。
	 * 在界面 create() 里调（子类此时已经设好 cameras），destroy() 里对应 unbind()。
	 * cam 传 null 等价于"明确声明用 flixel 默认相机"。
	 */
	public static function bind(own:FlxBasic, cam:FlxCamera):Void
	{
		unbind(own);
		stack.push({owner: own, cam: cam});
		sync();
	}

	/** 撤销 own 的声明（只在它确实声明过时动手，不会误伤别的界面）。 */
	public static function unbind(own:FlxBasic):Void
	{
		for (i in 0...stack.length)
		{
			if (stack[i].owner != own) continue;
			stack.splice(i, 1);
			sync();
			return;
		}
	}

	static function sync():Void
	{
		camera = (stack.length > 0) ? stack[stack.length - 1].cam : null;
	}

	/**
	 * 鼠标是否落在 obj 上。
	 * 指针侧与对象侧都显式传同一台相机，不再各取各的默认值。
	 * 顺手挡掉已销毁的对象：`FlxBasic.destroy()` 会把 scrollFactor 这类内部点置成 null，
	 * 之后再做命中判定会在 `FlxObject.getScreenPosition()` 里对 null 取字段而崩。
	 *
	 * @param insidePopup 我自己就是弹层里的元素 —— 绕开遮挡判定（见 beginBlock）
	 */
	public static function overlaps(obj:FlxBasic, ?insidePopup:Bool = false):Bool
	{
		if (obj == null || !obj.exists) return false;
		if (!insidePopup && isBlocked()) return false;
		return FlxG.mouse.overlaps(obj, camera);
	}

	// =========================================================
	// 弹层遮挡（防穿透误触）
	// =========================================================

	/** 当前展开的弹层（下拉列表 / 调色板）的背景块 */
	static var blockArea:FlxBasic = null;

	/**
	 * 登记"我展开了一个弹层，它盖住了别的东西"。
	 *
	 * 弹层是挂在 overlayContainer 上的浮层：**画**在选项行之上，但行里的控件并不知道自己被盖住了
	 * —— 每个控件各自拿自己的 bg 做 `mouse.overlaps`，于是弹层上的点击会原样穿透到下面的按钮。
	 * Debug 页就是活例子：「Lua Script Parser」展开的三行列表正压在「Crash Test」上，
	 * 点列表任意一项都会顺手触发崩溃自测，游戏当场炸掉。
	 *
	 * 登记之后，`overlaps()` 会替**所有**控件挡掉压在弹层上的指针；
	 * 弹层自己（列表项）用 `overlaps(obj, true)` 取原始判定。
	 *
	 * @param area 弹层背景块（负责"指针是否压在弹层上"的几何判定）
	 */
	public static function beginBlock(area:FlxBasic):Void
	{
		blockArea = area;
	}

	/** 撤销 own 的登记（只在它确实登记过时动手，不会误伤后来者）。 */
	public static function endBlock(area:FlxBasic):Void
	{
		if (blockArea == area) blockArea = null;
	}

	/** 指针是否正压在展开的弹层上 */
	public static function isBlocked():Bool
	{
		if (blockArea == null || !blockArea.exists) return false;
		return FlxG.mouse.overlaps(blockArea, camera);
	}

	/**
	 * 指针在"命中判定空间"里的 X —— 就是 `FlxObject.overlapsPoint()` 内部算出来的那个 `xPos`。
	 * 拿指针坐标做数值映射（拖数值条、判行悬停）时必须用它，不能用 `FlxG.mouse.x/y`：
	 * 那是相对 `FlxG.camera` 的世界坐标，会被游戏相机的 scroll / zoom 推着走。
	 */
	public static function mouseX():Float
	{
		final cam = (camera != null) ? camera : FlxG.camera;
		return (FlxG.mouse.gameX - cam.x) / cam.zoom + cam.viewMarginX;
	}

	/** 见 mouseX()。 */
	public static function mouseY():Float
	{
		final cam = (camera != null) ? camera : FlxG.camera;
		return (FlxG.mouse.gameY - cam.y) / cam.zoom + cam.viewMarginY;
	}

	// =========================================================
	// 指针独占
	// =========================================================

	/** 当前独占指针的控件 */
	static var pointerOwner:FlxBasic = null;

	/**
	 * 声明"这次按住鼠标归我"（拖数值条这类）。
	 * 滚动容器（`backend.MouseMove`）据此让位 —— 否则按住滑块上下拖时，
	 * 列表会同时被当成"正在拖拽"而跟着滚，画面就是控件带着整页背景一起动。
	 */
	public static function capturePointer(own:FlxBasic):Void
	{
		pointerOwner = own;
	}

	/** 撤销 own 的独占（只在它确实持有时动手）。 */
	public static function releasePointer(own:FlxBasic):Void
	{
		if (pointerOwner == own) pointerOwner = null;
	}

	/**
	 * 指针是否被控件独占。
	 * 松开鼠标即失效：控件不一定收得到 `justReleased`（切界面那一帧的输入会被吞掉），
	 * 不自动清就会让列表永久拖不动。
	 */
	public static function isPointerCaptured():Bool
	{
		if (pointerOwner == null) return false;

		if (!FlxG.mouse.pressed || !pointerOwner.exists)
		{
			pointerOwner = null;
			return false;
		}
		return true;
	}
}
