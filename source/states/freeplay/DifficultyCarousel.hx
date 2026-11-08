package states.freeplay;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.Difficulty;
import backend.Paths;
import shapeEx.SlantQuad;

/**
 * Freeplay 的难度条：**最多 3 块斜切平行四边形，边对边拼成一条**（和 StoryMode 右下角同一套做法）。
 *
 * - 每块里面上面是难度名、下面是评级数字；选中的那块染成该难度的颜色，其余是深灰。
 * - 只要超过 3 个难度就开滑动窗口：左右方向键 / 点击右侧方块都会让窗口整体挪一格，
 *   窗口里的三块始终紧贴，不会因为切换被拉开缝。
 * - 只负责画和"点到第几块"。切换本身由宿主驱动（宿主自己管 changeDiff 和音效）。
 *
 * ⚠ 这里**不能**像旧版那样给每块单独缩放/插值 x：三块是共边的，任一块的 scale 或
 * x 只要和邻居不同步，接缝立刻就散了。所以"选中"只靠颜色区分，滑动也只整体位移。
 */
class DifficultyCarousel extends FlxTypedGroup<FlxSprite>
{
	// 3 块：3*96 - 2*18 = 252，和专辑封面宽度（262）基本对齐
	public static inline var BLOCK_W:Float = 96;
	public static inline var BLOCK_H:Float = 66;
	public static inline var BLOCK_SKEW:Float = 18;
	public static inline var BLOCK_BORDER:Float = 2;

	/** 每块往四周各胀 1px，两块拼起来就是 2px 重叠（同 StoryActionButton.SEAM_OVERLAP） */
	private static inline var SEAM_OVERLAP:Float = 1;

	private static inline var MAX_VISIBLE:Int = 3;
	private static inline var UNSELECTED_COLOR:Int = 0xFF1A1A1A;
	private static inline var LERP_SPEED:Float = 15;

	private var centerX:Float;
	private var centerY:Float;

	private var outlines:Array<SlantQuad> = [];
	private var blocks:Array<SlantQuad> = [];
	private var labels:Array<FlxText> = [];
	private var ratings:Array<FlxText> = [];

	/** 每块在条带里的基准左边缘（不含 slideX） */
	private var baseX:Array<Float> = [];
	private var shown:Array<Bool> = [];

	private var diffCount:Int = 0;
	private var selected:Int = 0;
	private var startIndex:Int = -1;
	/** 整条一起滑动的偏移：窗口换格时给它一个 ±步长，再 lerp 回 0，这样三块永远同步 */
	private var slideX:Float = 0;

	public function new(centerX:Float, centerY:Float)
	{
		super();
		this.centerX = centerX;
		this.centerY = centerY;
	}

	/** 难度列表变化时重建。curIndex 是当前选中下标。 */
	public function rebuild(list:Array<String>, curIndex:Int):Void
	{
		// FlxSpriteGroup.clear() 不 destroy 成员，而边遍历 members 边 remove 会隔一个漏一个
		// （splice 就地删）—— 所以先拷一份再逐个摘掉 + 销毁。
		var old = members.copy();
		for (m in old)
		{
			if (m != null)
			{
				remove(m, true);
				m.destroy();
			}
		}
		outlines = [];
		blocks = [];
		labels = [];
		ratings = [];
		baseX = [];
		shown = [];

		diffCount = (list == null) ? 0 : list.length;
		selected = (curIndex < 0 || curIndex >= diffCount) ? 0 : curIndex;

		var grow:Float = SEAM_OVERLAP;
		var top:Float = centerY - BLOCK_H * 0.5;
		var ox:Float = outlineX();

		// 先铺所有形状，再铺所有文字：否则后一块的白色描边会盖住前一块的标签
		for (i in 0...diffCount)
		{
			var outline:SlantQuad = new SlantQuad(0, top - grow - BLOCK_BORDER, BLOCK_W + ox * 2,
				BLOCK_H + (grow + BLOCK_BORDER) * 2, BLOCK_SKEW, FlxColor.WHITE, 1);
			outline.antialiasing = ClientPrefs.data.antialiasing;
			outline.scrollFactor.set();
			outline.visible = false;
			add(outline);
			outlines.push(outline);

			var block:SlantQuad = new SlantQuad(0, top - grow, BLOCK_W + grow * 2, BLOCK_H + grow * 2,
				BLOCK_SKEW, UNSELECTED_COLOR, 1);
			block.antialiasing = ClientPrefs.data.antialiasing;
			block.scrollFactor.set();
			block.visible = false;
			add(block);
			blocks.push(block);

			baseX.push(0);
			shown.push(false);
		}

		for (i in 0...diffCount)
		{
			var label:FlxText = new FlxText(0, top + 8, BLOCK_W, Difficulty.getString(i), 11);
			label.antialiasing = ClientPrefs.data.antialiasing;
			label.setFormat(Paths.font('vcr.ttf'), 11, FlxColor.WHITE, CENTER);
			label.scrollFactor.set();
			label.visible = false;
			add(label);
			labels.push(label);

			var rating:FlxText = new FlxText(0, top + 30, BLOCK_W, '--', 20);
			rating.antialiasing = ClientPrefs.data.antialiasing;
			rating.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER);
			rating.scrollFactor.set();
			rating.visible = false;
			add(rating);
			ratings.push(rating);
		}

		startIndex = -1;
		slideX = 0;
		applyLayout(true);
	}

	/** 换选中项。playTick 只在用户主动切换时传 true，重建/刷新时不要传。 */
	public function setSelected(index:Int, playTick:Bool = false):Void
	{
		if (diffCount < 1)
			return;

		var newIndex:Int = FlxMath.wrap(index, 0, diffCount - 1);
		var changed:Bool = (newIndex != selected);
		selected = newIndex;

		applyLayout(false);

		if (playTick && changed)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	/** 评级数字是异步算出来的，数据到了调一次刷新。provider 返回负数表示"还没有"。 */
	public function refreshRatings(provider:Int->Float):Void
	{
		for (i in 0...diffCount)
		{
			var rating = ratings[i];
			if (rating == null)
				continue;

			var v:Float = (provider == null) ? -1 : provider(i);
			rating.text = (v < 0) ? '--' : Std.string(v);
		}
	}

	/** 返回被点中的难度下标；没点中返回 -1。调用方负责判 FlxG.mouse.justPressed。 */
	public function tryClick():Int
	{
		if (diffCount < 1)
			return -1;

		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;

		// 从右往左判，最后一个命中的胜出：接缝那 2px 归画在上层的右块，和 StoryMode 一致
		var hit:Int = -1;
		for (i in 0...diffCount)
		{
			var block = blocks[i];
			if (block == null || !block.exists || !shown[i])
				continue;
			if (block.containsScreen(mx, my))
				hit = i;
		}
		return hit;
	}

	/** 斜边按"垂直方向 2px"折算成水平外扩；直接按 x 外扩会让斜边比上下边粗 */
	private function outlineX():Float
	{
		var slant:Float = Math.sqrt(BLOCK_SKEW * BLOCK_SKEW + BLOCK_H * BLOCK_H);
		return SEAM_OVERLAP + BLOCK_BORDER * (slant / BLOCK_H);
	}

	private function applyLayout(instant:Bool):Void
	{
		if (diffCount < 1)
		{
			startIndex = 0;
			return;
		}

		var visibleCount:Int = (diffCount < MAX_VISIBLE) ? diffCount : MAX_VISIBLE;

		// 选中项尽量落在中间那格；贴边时窗口整体退让
		var newStart:Int = selected - 1;
		if (newStart < 0) newStart = 0;
		if (newStart > diffCount - visibleCount) newStart = diffCount - visibleCount;

		if (instant || startIndex < 0)
		{
			startIndex = newStart;
			slideX = 0;
		}
		else if (newStart != startIndex)
		{
			// 窗口前进一格 → 整条先往右错一格再滑回来，读起来就是"内容从右边推进来"
			slideX += (newStart - startIndex) * step();
			startIndex = newStart;
		}

		var stripW:Float = visibleCount * BLOCK_W - (visibleCount - 1) * BLOCK_SKEW;
		var left:Float = centerX - stripW * 0.5;

		for (i in 0...diffCount)
		{
			var inRange:Bool = (i >= startIndex && i < startIndex + visibleCount);
			shown[i] = inRange;

			var outline = outlines[i];
			var block = blocks[i];
			if (outline != null) outline.visible = inRange;
			if (block != null) block.visible = inRange;
			if (labels[i] != null) labels[i].visible = inRange;
			if (ratings[i] != null) ratings[i].visible = inRange;

			if (!inRange)
				continue;

			baseX[i] = left + (i - startIndex) * step();
			if (block != null)
				block.color = (i == selected) ? Difficulty.getColor(i) : UNSELECTED_COLOR;
		}

		applyPositions();
	}

	/** 相邻两块的水平间距：正好等于一块的宽度减一个 skew，两条斜边才能完全重合 */
	private inline function step():Float
	{
		return BLOCK_W - BLOCK_SKEW;
	}

	private function applyPositions():Void
	{
		var grow:Float = SEAM_OVERLAP;
		var top:Float = centerY - BLOCK_H * 0.5;
		var ox:Float = outlineX();

		for (i in 0...diffCount)
		{
			if (!shown[i])
				continue;

			var bx:Float = baseX[i] + slideX;

			if (outlines[i] != null)
			{
				outlines[i].x = bx - ox;
				outlines[i].y = top - grow - BLOCK_BORDER;
			}
			if (blocks[i] != null)
			{
				blocks[i].x = bx - grow;
				blocks[i].y = top - grow;
			}
			if (labels[i] != null)
			{
				labels[i].x = bx;
				labels[i].y = top + 8;
			}
			if (ratings[i] != null)
			{
				ratings[i].x = bx;
				ratings[i].y = top + 30;
			}
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (slideX != 0)
		{
			slideX = FlxMath.lerp(slideX, 0, Math.min(1, elapsed * LERP_SPEED));
			if (Math.abs(slideX) < 0.5)
				slideX = 0;
			applyPositions();
		}
	}

	override function destroy():Void
	{
		// ⚠️ 成员其实由 super.destroy() 负责 —— FlxGroup.destroy() 会逐个 destroy 成员
		// 并把 members 置 null。这里自己再来一遍只是多余的一层保险；
		// 没有 members != null 守卫的话，二次调用会撞上 members == null（本组件就这么崩过）。
		// （容易搞混：clear() 确实不销毁成员，但 destroy() 会。）
		if (members != null)
		{
			var old = members.copy();
			for (m in old)
				if (m != null)
					m.destroy();
		}

		outlines = [];
		blocks = [];
		labels = [];
		ratings = [];
		baseX = [];
		shown = [];
		diffCount = 0;
		startIndex = -1;

		super.destroy();
	}
}
