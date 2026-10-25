package objects;

import backend.RollLine;
import flixel.group.FlxGroup;

/**
 * 通用「制作人员名单向上滚动」组件（对齐官方 FNF 的做法：边滚边建 + 出屏回收）。
 *
 * 刻意 `extends FlxGroup` 而**不是** `FlxSpriteGroup`：后者 `preAdd` 会把 `group.y` 烘进子对象、
 * `recycle` 又绕过 `preAdd`，两套坐标体系混用必算错。这里每帧显式摆位 `spr.y = scrollY + localY`，
 * 可见行只有 20 来个，成本可以忽略，而复用/重排全是纯算术。
 *
 * 不依赖 CreditsData：调用方自己把数据摊成 `Array<RollLine>`。
 */
class CreditsRoll extends FlxGroup
{
	/** 默认字体。含非 ASCII 的行由 RollLine.font 指定 CJK 字体。 */
	public static var FONT:String = 'vcr.ttf';

	static inline var SZ_HEADER:Int = 40;
	static inline var SZ_SUB:Int = 26;
	static inline var SZ_BODY:Int = 26;

	static inline var H_HEADER:Float = 56;
	static inline var H_SUB:Float = 40;
	static inline var H_BODY:Float = 34;

	/** 距离视口下沿多少像素内就该建行了 */
	static inline var BUILD_MARGIN:Float = 200;
	/** 每帧最多建几行，防止一次性 600 行卡帧 */
	static inline var MAX_BUILD_PER_FRAME:Int = 6;

	public var scrollY:Float = 0;
	public var speed:Float = 140;
	public var fastSpeed:Float = 560;
	public var paused:Bool = false;
	public var finished(default, null):Bool = false;

	public var viewTop:Float = 0;
	public var viewBottom:Float = 0;

	var lines:Array<RollLine> = [];
	var nextIdx:Int = 0;
	var cursorY:Float = 0;
	var activeItems:Array<RollItem> = [];
	var pool:Array<RollItem> = [];

	public function new(lines:Array<RollLine>)
	{
		super();
		this.lines = (lines == null) ? [] : lines;
		viewTop = 0;
		viewBottom = FlxG.height;
		restart();
	}

	/** 设定可视区（上下黑条之间的区域）。改完记得再调 restart() 让起点跟着走。 */
	public function setViewport(top:Float, bottom:Float):Void
	{
		viewTop = top;
		viewBottom = bottom;
	}

	/** 从头开始（默认从视口下沿升起，第一行立刻可见，不用空等一屏）。 */
	public function restart(?startY:Float):Void
	{
		for (it in activeItems) release(it);
		activeItems = [];
		nextIdx = 0;
		cursorY = 0;
		finished = false;
		scrollY = (startY == null) ? viewBottom : startY;
	}

	override function update(elapsed:Float):Void
	{
		if (!paused && !finished)
		{
			var sp:Float = speed;
			if (FlxG.keys.pressed.ENTER || FlxG.keys.pressed.SPACE || Controls.instance.pressed('accept'))
				sp = fastSpeed;
			else if (FlxG.keys.pressed.P || FlxG.keys.pressed.SHIFT)
				sp = 0;

			scrollY -= sp * elapsed;
		}

		buildWhileNeeded();
		layoutItems();
		cullItems();
		checkFinished();

		super.update(elapsed);
	}

	// ================================================================
	// 构建 / 摆位 / 回收
	// ================================================================

	function buildWhileNeeded():Void
	{
		var guard:Int = 0;
		while (nextIdx < lines.length && guard < MAX_BUILD_PER_FRAME)
		{
			var line:RollLine = lines[nextIdx];

			// style 3 = 纯间隔：不建对象，只推进游标
			if (line.style == 3)
			{
				cursorY += line.gapAfter;
				nextIdx++;
				guard++;
				continue;
			}

			// 还在屏幕下方很远，先不建
			if (scrollY + cursorY > viewBottom + BUILD_MARGIN) break;

			var it:RollItem = obtain();
			fill(it, line);
			it.localY = cursorY;
			// 用真实字高兜底（CJK 字体 / +2 字号会让常量偏低）
			it.height = Math.max(styleHeight(line.style), it.left.height);
			activeItems.push(it);

			cursorY += it.height + line.gapAfter;
			nextIdx++;
			guard++;
		}
	}

	function layoutItems():Void
	{
		for (it in activeItems)
		{
			it.left.y = scrollY + it.localY;
			if (it.right != null && it.right.exists) it.right.y = it.left.y;
		}
	}

	function cullItems():Void
	{
		var i:Int = activeItems.length - 1;
		while (i >= 0)
		{
			var it:RollItem = activeItems[i];
			if (scrollY + it.localY + it.height < viewTop - 40)
			{
				release(it);
				activeItems.splice(i, 1);
			}
			i--;
		}
	}

	function checkFinished():Void
	{
		if (finished) return;
		if (nextIdx < lines.length) return;
		if (activeItems.length > 0) return;
		finished = true;
	}

	function obtain():RollItem
	{
		if (pool.length > 0) return pool.pop();
		var it:RollItem = new RollItem();
		add(it.left);
		return it;
	}

	function release(it:RollItem):Void
	{
		it.left.exists = false;
		if (it.right != null) it.right.exists = false;
		pool.push(it);
	}

	// ================================================================
	// 填一行
	// ================================================================

	function fill(it:RollItem, line:RollLine):Void
	{
		var cjk:Bool = (line.font != null && line.font.length > 0);
		var font:String = cjk ? line.font : FONT;

		var size:Int = styleSize(line.style);
		if (cjk) size += 2; // 比例字体同字号看起来偏小

		it.left.exists = true;
		it.left.visible = true;
		it.left.alpha = (line.style == 1) ? 0.72 : 1.0;
		it.left.setFormat(Paths.font(font), size, lineColor(line), CENTER);
		it.left.borderStyle = OUTLINE;
		it.left.borderColor = FlxColor.BLACK;
		it.left.borderSize = (line.style == 0) ? 3 : 2;

		var hasSecond:Bool = (line.style == 2 && line.second != null && line.second.length > 0);

		if (hasSecond)
		{
			// 两栏：姓名右对齐到中线，职责左对齐从中线起
			it.left.alignment = RIGHT;
			it.left.fieldWidth = FlxG.width * 0.42;
			it.left.wordWrap = false;
			it.left.text = line.text;
			it.left.x = FlxG.width * 0.08;
		}
		else
		{
			it.left.alignment = CENTER;
			it.left.fieldWidth = FlxG.width;
			it.left.wordWrap = false;
			it.left.text = line.text;
			it.left.x = 0;
		}

		if (hasSecond)
		{
			if (it.right == null)
			{
				it.right = RollItem.makeText();
				add(it.right);
			}

			it.right.exists = true;
			it.right.visible = true;
			it.right.alpha = 0.72;
			it.right.setFormat(Paths.font(cjk ? font : FONT), size, FlxColor.WHITE, LEFT);
			it.right.borderStyle = OUTLINE;
			it.right.borderColor = FlxColor.BLACK;
			it.right.borderSize = 2;
			it.right.fieldWidth = FlxG.width * 0.40;
			it.right.wordWrap = false;
			it.right.text = line.second;
			it.right.x = FlxG.width * 0.52;
		}
		else if (it.right != null)
		{
			it.right.exists = false;
		}
	}

	inline function styleSize(s:Int):Int
	{
		return switch (s)
		{
			case 0: SZ_HEADER;
			case 1: SZ_SUB;
			default: SZ_BODY;
		}
	}

	inline function styleHeight(s:Int):Float
	{
		return switch (s)
		{
			case 0: H_HEADER;
			case 1: H_SUB;
			default: H_BODY;
		}
	}

	/** 组标题用 section 色，但太暗的颜色（如 Psych 的 444444）在黑底上不可读 → 退回白色。 */
	function lineColor(line:RollLine):FlxColor
	{
		if (line.style == 0 && line.color != null && line.color.length > 0)
		{
			var c:FlxColor = CoolUtil.colorFromString(line.color);
			var luma:Float = (0.299 * c.red + 0.587 * c.green + 0.114 * c.blue) / 255;
			if (luma >= 0.45) return c;
		}
		return FlxColor.WHITE;
	}
}

/** 一行 = 最多 2 个 FlxText。池对象常驻 group，靠 exists 开关，不做 add/remove。 */
private class RollItem
{
	public var left:FlxText;
	public var right:FlxText = null;
	public var localY:Float = 0;
	public var height:Float = 0;

	public function new()
	{
		left = makeText();
	}

	public static function makeText():FlxText
	{
		var t:FlxText = new FlxText(0, 0, 0, '', 26);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.scrollFactor.set();
		return t;
	}
}
