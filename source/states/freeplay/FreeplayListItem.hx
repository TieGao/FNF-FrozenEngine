package states.freeplay;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

import backend.UIControlTheme;
import backend.UITheme;
import backend.FlxFilteredSprite;

import openfl.filters.BlurFilter;
import openfl.filters.BitmapFilterQuality;

/**
 * Freeplay 三个列表子界面（搜索 / 模组选择 / 回放选择）共用的列表项外壳。
 *
 * 只管"行为"和"背景材质"，不管内容：整行背景、悬停 / 按下 / 选中三态、
 * 松手生效的点按判定都收在这里；进度条、图标、标题这些由宿主自己 add 进来。
 *
 * 三种背景风格由设置项 freeplayListStyle 决定（ClientPrefs）：
 * - `blur`（默认）：FlxFilteredSprite + BlurFilter 的柔光面板，原三个界面的观感。
 * - `win8`：直角 + 描边的扁平色块。
 * - `win10`：圆角 + 高光的色块。
 *
 * 三种风格都按 80px 行高设计 —— blur 风格需要足够的面积才看得出光晕，
 * Win8 / Win10 保持同高，只把材质换成紧凑风格，避免各列表行高不一致。
 */
class FreeplayListItem extends FlxSpriteGroup
{
	/** 背景风格（`blur` / `win8` / `win10`），默认取设置项 */
	public static inline var STYLE_BLUR:String = 'blur';
	public static inline var STYLE_WIN8:String = 'win8';
	public static inline var STYLE_WIN10:String = 'win10';

	public static inline var DEFAULT_WIDTH:Int = 450;
	public static inline var DEFAULT_HEIGHT:Int = 80;

	/** 整行背景。子类 / 宿主可改它的颜色来贴合自身配色。 */
	public var bg:FlxSprite;

	/** 当前背景风格 */
	public var style(default, null):String = STYLE_BLUR;

	public var isHovered:Bool = false;
	public var isPressed:Bool = false;
	public var isSelected:Bool = false;

	/** 当前行宽 / 行高（内容排版要用） */
	public var itemWidth(default, null):Int;
	public var itemHeight(default, null):Int;

	/**
	 * 本行"内容"的容器。宿主往里 add 自己的东西（图标 / 文字 / 进度条），
	 * 这样按下缩放时只缩内容层，不会动宿主的坐标假设。
	 *
	 * 注意：本类继承 FlxSpriteGroup，而 FlxSpriteGroup 的 x/y 是"增量传播"语义
	 * （见 set_x → transformChildren(xTransform, Value - x)，只推差值），
	 * preAdd 又会在 add() 时把当时的 x/y 烘进成员坐标。两套语义叠加很容易算错，
	 * 所以这里固定一条约定：**本类自身的 x/y 永远是 0**，
	 * 所有定位都通过 bg / content 的子层坐标表达（见 setItemPosition）。
	 */
	public var content:FlxSpriteGroup;

	// 三态配色：宿主可以在构造后用 setColors 覆盖
	var colorNormal:FlxColor = 0xFF888888;
	var colorHover:FlxColor = 0xFF445370;
	var colorPress:FlxColor = 0xFF5A6E96;
	var colorSelected:FlxColor = 0xFF32466E;

	// 按下时的缩放（只缩内容，不缩背景；背景缩了反而会露出面板底色）
	static inline var PRESS_SCALE:Float = 0.97;

	var baseAlpha:Float = 0.3;
	var pressTransforms:Array<{sprite:FlxSprite, scaleX:Float, scaleY:Float, originX:Float, originY:Float, offsetX:Float, offsetY:Float}> = [];

	public function new(w:Int = DEFAULT_WIDTH, h:Int = DEFAULT_HEIGHT)
	{
		super();
		itemWidth = w;
		itemHeight = h;
		style = readStyle();

		bg = buildBackground(w, h);
		add(bg);

		content = new FlxSpriteGroup();
		add(content);

		applyState();
	}

	/** 读设置项，非法值回退到 blur */
	public static function readStyle():String
	{
		var v:String = ClientPrefs.data.freeplayListStyle;
		if (v == STYLE_WIN8 || v == STYLE_WIN10) return v;
		return STYLE_BLUR;
	}

	/** 改本行的三态配色（不传的保持原值） */
	public function setColors(?normal:FlxColor, ?hover:FlxColor, ?press:FlxColor, ?selected:FlxColor, ?alpha:Float):Void
	{
		if (normal != null) colorNormal = normal;
		if (hover != null) colorHover = hover;
		if (press != null) colorPress = press;
		if (selected != null) colorSelected = selected;
		if (alpha != null) baseAlpha = alpha;
		applyState();
	}

	/** 宿主改行高（布局用）。三风格都按传入值重建背景。 */
	public function resize(w:Int, h:Int):Void
	{
		if (w == itemWidth && h == itemHeight) return;
		itemWidth = w;
		itemHeight = h;

		var oldX:Float = x;
		var oldY:Float = y;

		var idx:Int = members.indexOf(bg);
		remove(bg, true);
		bg.destroy();

		bg = buildBackground(w, h);
		// add()/insert() 的 preAdd 会把当前 group 坐标烘进新 bg，先归零再对齐，
		// 否则新背景会比 content 多偏移一个 group.x/y（两者对不上）。
		bg.setPosition(0, 0);
		if (idx >= 0) insert(idx, bg) else add(bg);
		bg.setPosition(oldX, oldY);

		applyState();
	}

	/**
	 * 定位这一行（唯一入口）。写父类的 x/y 字段（走下面的 set_x/set_y），
	 * 由它们同步到 bg / content 两个子层。
	 */
	public function setItemPosition(x:Float, y:Float):Void
	{
		this.x = x;
		this.y = y;
	}

	// ===== 坐标同步 =====
	// 父类 FlxSpriteGroup 的 set_x 会把差值推给**所有成员**（transformChildren(xTransform, Value - x)），
	// 而 preAdd 在 add() 时又把当时的 group 坐标烘进了成员坐标 —— 两套叠加必然算错：
	// bg 和 content 各被推一次，偏移翻倍（Search 卡片内容就是这么跑到左上角外的）。
	//
	// 这里覆写 set_x/set_y：绕开父类的传播，只把新值**直接指派**给 bg / content 两个子层，
	// 让"这一行的位置"始终只由这一处决定。**不调用 super.set_x** —— 那正是要避开的传播逻辑。
	// 父类的 x/y 字段照常更新，宿主读 `item.y` 依然正确。
	// 成员自己的坐标（bg/content 内部的图标 / 文字）保持相对行左上角，不受影响。

	override function set_x(value:Float):Float
	{
		if (bg != null) bg.x = value;
		if (content != null) content.x = value;
		// 直接写字段，不走父类（父类是增量传播）。x 是父类 (default, set) 字段，可直接赋值。
		return x = value;
	}

	override function set_y(value:Float):Float
	{
		if (bg != null) bg.y = value;
		if (content != null) content.y = value;
		return y = value;
	}

	/**
	 * 命中判定。不要用 FlxG.mouse.overlaps(this)：FlxSpriteGroup 的 get_width()/get_height()
	 * 返回的是**成员包围盒的尺寸**（findMaxX - findMinX），而 overlapsPoint 按 (x, x + width) 判 ——
	 * 成员坐标里已经烘进了偏移，再加一次 group.x 就会整体偏移，永远点不中。
	 * 用 bg 判断即可：它就是这一行的整行背景，位置和尺寸都准确。
	 */
	public function overlapsMouse(?camera:FlxCamera):Bool
	{
		return bg != null && FlxG.mouse.overlaps(bg, camera);
	}

	function buildBackground(w:Int, h:Int):FlxSprite
	{
		switch (style)
		{
			case STYLE_WIN8:
				return buildWin8(w, h);
			case STYLE_WIN10:
				return buildWin10(w, h);
			default:
				return buildBlur(w, h);
		}
	}

	/** blur 风格：柔光面板（原三个界面的观感）。需要 80px 左右的高度才有明显光晕。 */
	function buildBlur(w:Int, h:Int):FlxSprite
	{
		var spr:FlxFilteredSprite = new FlxFilteredSprite();
		spr.makeGraphic(w, h, FlxColor.WHITE);
		spr.filters = [new BlurFilter(30, 30, BitmapFilterQuality.HIGH)];
		return spr;
	}

	/** win8 风格：直角实色块，靠一层描边撑出"扁平"的观感。 */
	function buildWin8(w:Int, h:Int):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite();
		spr.makeGraphic(w, h, FlxColor.WHITE);
		return spr;
	}

	/** win10 风格：实色块 + 顶部一条高光（模拟亚克力面板的顶边）。 */
	function buildWin10(w:Int, h:Int):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite();
		spr.makeGraphic(w, h, FlxColor.WHITE);
		return spr;
	}

	// ===== 状态 =====

	public function setHovered(v:Bool):Void
	{
		if (isHovered == v) return;
		isHovered = v;
		applyState();
	}

	public function setSelected(v:Bool):Void
	{
		if (isSelected == v) return;
		isSelected = v;
		applyState();
	}

	/** 按动反馈：不缩背景（缩了会露出面板底色），只缩内容层 + 微调亮度。 */
	public function setPressed(v:Bool):Void
	{
		if (isPressed == v) return;
		isPressed = v;

		if (content != null && content.members != null)
		{
			if (v)
			{
				// 图标等子元素有自己的缩放；updateHitbox 还会改 offset，因此保存完整变换。
				pressTransforms = [];
				for (member in content.members)
				{
					if (member == null || !Std.isOfType(member, FlxSprite)) continue;
					var spr:FlxSprite = cast member;
					var state = {
						sprite: spr,
						scaleX: spr.scale.x,
						scaleY: spr.scale.y,
						originX: spr.origin.x,
						originY: spr.origin.y,
						offsetX: spr.offset.x,
						offsetY: spr.offset.y
					};
					pressTransforms.push(state);

					spr.origin.set(spr.frameWidth * 0.5, spr.frameHeight * 0.5);
					spr.scale.set(state.scaleX * PRESS_SCALE, state.scaleY * PRESS_SCALE);
					spr.updateHitbox();
					spr.offset.set(-(spr.width - spr.frameWidth) * 0.5, -(spr.height - spr.frameHeight) * 0.5);
				}
			}
			else
			{
				for (state in pressTransforms)
				{
					var spr = state.sprite;
					if (spr == null) continue;
					spr.scale.set(state.scaleX, state.scaleY);
					spr.updateHitbox();
					spr.origin.set(state.originX, state.originY);
					spr.offset.set(state.offsetX, state.offsetY);
				}
				pressTransforms = [];
			}
		}

		applyState();
	}

	function applyState():Void
	{
		if (bg == null) return;

		var col:FlxColor;
		var a:Float;

		if (isPressed)
		{
			col = colorPress;
			a = 1.0;
		}
		else if (isSelected)
		{
			col = colorSelected;
			a = (style == STYLE_BLUR) ? 0.9 : 1.0;
		}
		else if (isHovered)
		{
			col = colorHover;
			a = (style == STYLE_BLUR) ? 0.6 : 0.95;
		}
		else
		{
			col = colorNormal;
			a = baseAlpha;
		}

		bg.color = col;
		bg.alpha = a;
	}

	override function destroy():Void
	{
		// 成员由 super.destroy() 负责，这里只断引用（见 FlxGroup.destroy 会把 members 置 null）
		bg = null;
		content = null;

		super.destroy();
	}
}
