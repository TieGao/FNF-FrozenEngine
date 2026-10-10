package states.freeplay;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.Difficulty;
import backend.Paths;

/**
 * Freeplay 的难度方块 carousel。
 *
 * 横向一排方块，每块里上面是难度名、下面是评级数字；选中的那块放大并染成该难度的颜色，
 * 离选中太远的块直接隐藏（滑动窗口），所以 1 个到十几个难度都能容纳。
 *
 * 只负责画和"点到第几块"。切换本身由宿主驱动（宿主自己管 changeDiff 和音效）。
 */
class DifficultyCarousel extends FlxTypedGroup<FlxSprite>
{
	// 4 块 × 75px = 300px，正好等于专辑封面的宽度（262×262 缩到高 300）
	public static inline var BLOCK_SIZE:Int = 75;
	public static inline var BLOCK_SPACING:Int = 75;

	private static inline var MAX_VISIBLE:Int = 4; // 一次最多显示几块（整行与专辑封面同宽）
	private static inline var UNSELECTED_COLOR:Int = 0xFF1A1A1A;
	private static inline var LERP_SPEED:Float = 15;

	private var centerX:Float;
	private var centerY:Float;

	private var blocks:Array<FlxSprite> = [];
	private var labels:Array<FlxText> = [];
	private var ratings:Array<FlxText> = [];

	private var diffCount:Int = 0;
	private var selected:Int = 0;
	private var targetXs:Array<Float> = [];

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
		blocks = [];
		labels = [];
		ratings = [];
		targetXs = [];

		diffCount = (list == null) ? 0 : list.length;
		selected = (curIndex < 0 || curIndex >= diffCount) ? 0 : curIndex;

		for (i in 0...diffCount)
		{
			var block:FlxSprite = new FlxSprite();
			block.makeGraphic(BLOCK_SIZE, BLOCK_SIZE, FlxColor.WHITE);
			// origin 放中心：缩放绕中心做，视觉中心恒为 x + BLOCK_SIZE/2。
			// 不能用 updateHitbox 那套补偿 —— 它会把 offset 挪走，命中区反而和画面对不上。
			block.antialiasing = ClientPrefs.data.antialiasing;
			block.origin.set(BLOCK_SIZE * 0.5, BLOCK_SIZE * 0.5);
			block.scrollFactor.set();
			block.y = centerY - BLOCK_SIZE * 0.5;
			block.visible = false;
			add(block);
			blocks.push(block);

			var label:FlxText = new FlxText(0, 0, BLOCK_SIZE, Difficulty.getString(i), 11);
			label.antialiasing = ClientPrefs.data.antialiasing;
			label.setFormat(Paths.font('vcr.ttf'), 11, FlxColor.WHITE, CENTER);
			label.scrollFactor.set();
			label.visible = false;
			add(label);
			labels.push(label);

			var rating:FlxText = new FlxText(0, 0, BLOCK_SIZE, '--', 18);
			rating.antialiasing = ClientPrefs.data.antialiasing;
			rating.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER);
			rating.scrollFactor.set();
			rating.visible = false;
			add(rating);
			ratings.push(rating);

			targetXs.push(centerX);
		}

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

		for (i in 0...diffCount)
		{
			var block = blocks[i];
			// 判 exists：销毁过的 sprite 上取字段会空指针，而且它还留在数组里。
			if (block == null || !block.exists || !block.visible)
				continue;

			// 自己算命中区。方块是 origin=中心 缩放的，视觉中心 = x + BLOCK_SIZE/2，
			// 半宽随 scale 变 —— 用 FlxG.mouse.overlaps 反而会因为 offset 语义对不上。
			var cx:Float = block.x + BLOCK_SIZE * 0.5;
			var half:Float = BLOCK_SIZE * 0.5 * block.scale.x;

			if (mx >= cx - half && mx <= cx + half && my >= centerY - half && my <= centerY + half)
				return i;
		}
		return -1;
	}

	private function applyLayout(instant:Bool):Void
	{
		// 可见窗口整体以 centerX 居中，而不是「选中块居中」—— 窗口是偶数格（4），
		// 选中块本来就不可能正好落在中心。整行宽度恒为 MAX_VISIBLE * BLOCK_SPACING，
		// 和专辑封面同宽同轴，选中块在窗口内滑动。
		var visibleCount:Int = (diffCount < MAX_VISIBLE) ? diffCount : MAX_VISIBLE;
		var startIndex:Int = selected - 1;
		if (startIndex < 0) startIndex = 0;
		if (startIndex > diffCount - visibleCount) startIndex = diffCount - visibleCount;

		for (i in 0...diffCount)
		{
			var block = blocks[i];
			if (block == null)
				continue;

			var inRange:Bool = (i >= startIndex && i < startIndex + visibleCount);

			block.visible = inRange;
			labels[i].visible = inRange;
			ratings[i].visible = inRange;

			if (!inRange)
			{
				targetXs[i] = centerX;
				continue;
			}

			var slot:Float = (i - startIndex) - (visibleCount - 1) * 0.5;
			var isSel:Bool = (i == selected);
			var s:Float = isSel ? 1.0 : 0.85;

			targetXs[i] = centerX + slot * BLOCK_SPACING - BLOCK_SIZE * 0.5;
			block.scale.set(s, s);
			block.color = isSel ? Difficulty.getColor(i) : UNSELECTED_COLOR;

			if (instant)
				block.x = targetXs[i];
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var k:Float = Math.min(1, elapsed * LERP_SPEED);

		for (i in 0...diffCount)
		{
			var block = blocks[i];
			if (block == null)
				continue;

			if (Math.abs(block.x - targetXs[i]) > 0.05)
				block.x = FlxMath.lerp(block.x, targetXs[i], k);
			else
				block.x = targetXs[i];

			if (!block.visible)
				continue;

			// 文字跟着方块的当前 x 走（方块在滑动，不能只按目标位置摆一次）
			var cx:Float = block.x + BLOCK_SIZE * 0.5;
			var label = labels[i];
			var rating = ratings[i];

			if (label != null)
			{
				label.x = cx - BLOCK_SIZE * 0.5;
				label.y = centerY - BLOCK_SIZE * 0.5 + 4;
			}
			if (rating != null)
			{
				rating.x = cx - BLOCK_SIZE * 0.5;
				rating.y = centerY - 2;
			}
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

		blocks = [];
		labels = [];
		ratings = [];
		targetXs = [];
		diffCount = 0;

		super.destroy();
	}
}
