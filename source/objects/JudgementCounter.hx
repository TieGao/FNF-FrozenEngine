package objects;

import backend.Rating;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.PlayState;

/** 计数器一行的静态定义：标签、所属块、颜色。 */
typedef CounterRowSpec = {
	var key:String;
	var label:String;
	var block:String;
	var color:FlxColor;
}

/** 参与布局的最小单元：一块文本 + 它属于哪个块。 */
typedef CounterLayoutItem = {
	var text:FlxText;
	var block:String;
}

/**
 * 判定计数器。
 * 四种布局：Left（贴左）、Center（贴中，文字居中）、Right（贴右，数值在前）、
 * Split（顶部一行 Total Notes Hit + Combo，底部一行 5 个 rating，不显示 Highest Combo / Misses）。
 */
class JudgementCounter
{
	public static inline var POS_LEFT:String = 'left';
	public static inline var POS_CENTER:String = 'center';
	public static inline var POS_RIGHT:String = 'right';
	public static inline var POS_SPLIT:String = 'split';

	public static inline var BLOCK_STATS:String = 'stats';
	public static inline var BLOCK_RATINGS:String = 'ratings';

	public static inline var TEXT_WIDTH:Float = 280;
	public static inline var LINE_HEIGHT:Float = 24;
	public static inline var TEXT_SIZE:Int = 20;
	// 贴左 / 贴右模式与屏幕左右沿的留白
	public static inline var SIDE_MARGIN:Float = 10;
	// split 两块与屏幕上沿 / 下沿的留白
	public static inline var SPLIT_MARGIN:Float = 20;
	// split 横向一行里相邻两项的最小间距（窄屏兜底，避免文字贴到一起）
	public static inline var SPLIT_GAP_MIN:Float = 12;

	public var state:PlayState;
	public var side:String;

	public var tnhText:FlxText;
	public var highestcomboText:FlxText;
	public var comboText:FlxText;
	public var marvelousText:FlxText;
	public var sickText:FlxText;
	public var goodText:FlxText;
	public var badText:FlxText;
	public var shitText:FlxText;
	public var missText:FlxText;

	var rows:Array<{key:String, label:String, block:String, text:FlxText}> = [];
	var mode:String = '';
	var font:String;

	public function new(state:PlayState, ?side:String)
	{
		this.state = state;
		this.side = if (side == null) 'player' else side;
		if (!ClientPrefs.data.Counter) return;

		font = GameFont.resolve('vcr.ttf');
		build();
	}

	/** 当前实际生效的布局（coop_split 下两个计数器固定分居左右，位置设置不生效）。 */
	function resolveMode():String
	{
		if (state.isSplitCoopMode()) return side == 'opponent' ? POS_LEFT : POS_RIGHT;

		var m:String = ClientPrefs.data.counterPos;
		if (m == POS_CENTER || m == POS_RIGHT || m == POS_SPLIT) return m;
		return POS_LEFT;
	}

	inline function useOffset():Bool
	{
		return !state.isSplitCoopMode();
	}

	/** 行是否出现在给定布局里（split 不显示 Highest Combo / Misses）。 */
	public static function isRowVisible(key:String, mode:String):Bool
	{
		switch (key)
		{
			case 'tnh':
				return ClientPrefs.data.showTNH;
			case 'hc':
				return ClientPrefs.data.showHC && mode != POS_SPLIT;
			case 'cb':
				return ClientPrefs.data.showCB;
			case 'miss':
				return ClientPrefs.data.showMiss && mode != POS_SPLIT;
			case 'marv':
				return ClientPrefs.data.marvelousEnabled;
		}
		return true;
	}

	function baseColor():FlxColor
	{
		if (side == 'opponent')
			return FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]);
		return FlxColor.fromRGB(state.boyfriend.healthColorArray[0], state.boyfriend.healthColorArray[1], state.boyfriend.healthColorArray[2]);
	}

	function build():Void
	{
		mode = resolveMode();
		var color:FlxColor = baseColor();

		for (spec in specs())
		{
			if (!isRowVisible(spec.key, mode)) continue;

			var t:FlxText = new FlxText(0, 0, TEXT_WIDTH, format(mode, spec.label, 0), TEXT_SIZE);
			t.antialiasing = ClientPrefs.data.antialiasing;
			t.setFormat(font, TEXT_SIZE, isBaseColored(spec.key) ? color : spec.color, LEFT, OUTLINE, FlxColor.BLACK);
			t.scrollFactor.set(0, 0);
			t.borderSize = 2.00;
			t.visible = !ClientPrefs.data.hideHud;
			state.uiGroup.add(t);

			rows.push({key: spec.key, label: spec.label, block: spec.block, text: t});
			assignField(spec.key, t);
		}

		layout(mode, items(), useOffset());
	}

	function items():Array<CounterLayoutItem>
	{
		var list:Array<CounterLayoutItem> = [];
		for (row in rows) list.push({text: row.text, block: row.block});
		return list;
	}

	function assignField(key:String, t:FlxText):Void
	{
		switch (key)
		{
			case 'tnh': tnhText = t;
			case 'hc': highestcomboText = t;
			case 'cb': comboText = t;
			case 'marv': marvelousText = t;
			case 'sick': sickText = t;
			case 'good': goodText = t;
			case 'bad': badText = t;
			case 'shit': shitText = t;
			case 'miss': missText = t;
		}
	}

	function rebuild():Void
	{
		for (row in rows)
		{
			state.uiGroup.remove(row.text, true);
			row.text.destroy();
		}
		rows = [];
		tnhText = highestcomboText = comboText = null;
		marvelousText = sickText = goodText = badText = shitText = missText = null;
		build();
	}

	public function refresh():Void
	{
		if (!ClientPrefs.data.Counter) return;
		if (mode == '') return;
		// 位置设置在暂停菜单里随时可能被改，改了就当场换布局
		if (resolveMode() != mode) rebuild();
		if (rows.length < 1) return;

		var hits:Int = if (side == 'opponent') state.opponentSongHits else state.playerSongHits;
		var highestCombo:Int = if (side == 'opponent') state.opponentHighestCombo else state.playerHighestCombo;
		var comboValue:Int = if (side == 'opponent') state.opponentCombo else state.playerCombo;
		var ratings:Array<Rating> = if (side == 'opponent') state.opponentRatingsData else state.playerRatingsData;
		var misses:Int = if (side == 'opponent') state.opponentSongMisses else state.playerSongMisses;

		if (!state.isSplitCoopMode())
		{
			hits = state.songHits;
			highestCombo = state.highestCombo;
			comboValue = state.combo;
			ratings = state.ratingsData;
			misses = state.songMisses;
		}

		var color:FlxColor = baseColor();
		var recolor:Bool = ClientPrefs.data.customColor;
		var visible:Bool = !ClientPrefs.data.hideHud;

		var changed:Bool = false;
		for (row in rows)
		{
			var value:String = format(mode, row.label, valueOf(row.key, hits, highestCombo, comboValue, ratings, misses));
			if (row.text.text != value)
			{
				row.text.text = value;
				changed = true;
			}
			row.text.visible = visible;
			if (recolor && isBaseColored(row.key)) row.text.color = color;
		}

		// split 是横向拼接：数值位数一变整行宽度就变，要当场重新居中（直接改坐标，不做补间）
		if (changed && mode == POS_SPLIT) layout(mode, items(), useOffset());
	}

	static function valueOf(key:String, hits:Int, highestCombo:Int, comboValue:Int, ratings:Array<Rating>, misses:Int):Int
	{
		switch (key)
		{
			case 'tnh': return hits;
			case 'hc': return highestCombo;
			case 'cb': return comboValue;
			case 'marv': return ratings[0].hits;
			case 'sick': return ratings[1].hits;
			case 'good': return ratings[2].hits;
			case 'bad': return ratings[3].hits;
			case 'shit': return ratings[4].hits;
			case 'miss': return misses;
		}
		return 0;
	}

	/** Total Notes Hit / Highest Combo / Combo 三行跟随角色血条配色，其余行固定色。 */
	public static function isBaseColored(key:String):Bool
	{
		return key == 'tnh' || key == 'hc' || key == 'cb';
	}

	/** 全部行的定义，按显示顺序。 */
	public static function specs():Array<CounterRowSpec>
	{
		return [
			{key: 'tnh', label: 'Total Notes Hit', block: BLOCK_STATS, color: FlxColor.WHITE},
			{key: 'hc', label: 'Highest Combo', block: BLOCK_STATS, color: FlxColor.WHITE},
			{key: 'cb', label: 'Combo', block: BLOCK_STATS, color: FlxColor.WHITE},
			{key: 'marv', label: 'Marvelous', block: BLOCK_RATINGS, color: FlxColor.fromRGB(255, 215, 0)},
			{key: 'sick', label: 'Sicks', block: BLOCK_RATINGS, color: FlxColor.fromRGB(0, 191, 255)},
			{key: 'good', label: 'Goods', block: BLOCK_RATINGS, color: FlxColor.fromRGB(0, 205, 0)},
			{key: 'bad', label: 'Bads', block: BLOCK_RATINGS, color: FlxColor.fromRGB(238, 0, 0)},
			{key: 'shit', label: 'Shits', block: BLOCK_RATINGS, color: FlxColor.fromRGB(205, 0, 0)},
			{key: 'miss', label: 'Misses', block: BLOCK_RATINGS, color: FlxColor.fromRGB(139, 0, 0)},
		];
	}

	/** Right 模式数值在前（靠右对齐时数字才对得上），其余模式标签在前。 */
	public static function format(mode:String, label:String, value:Int):String
	{
		return mode == POS_RIGHT ? value + ' ' + label : label + ': ' + value;
	}

	/**
	 * 按布局摆放文本。useOffset=false 用于 coop_split（固定分居左右、不吃微调偏移）。
	 */
	public static function layout(mode:String, items:Array<CounterLayoutItem>, useOffset:Bool = true):Void
	{
		if (items.length < 1) return;

		if (mode == POS_SPLIT)
		{
			var top:Array<CounterLayoutItem> = [];
			var bottom:Array<CounterLayoutItem> = [];
			for (it in items)
			{
				if (it.block == BLOCK_RATINGS) bottom.push(it) else top.push(it);
			}

			var topX:Float = FlxG.width / 2 + (useOffset ? ClientPrefs.data.counterSplitTopX : 0);
			var topY:Float = SPLIT_MARGIN + (useOffset ? ClientPrefs.data.counterSplitTopY : 0);
			placeRow(top, topX, topY);

			var bottomX:Float = FlxG.width / 2 + (useOffset ? ClientPrefs.data.counterSplitBottomX : 0);
			var bottomY:Float = FlxG.height - SPLIT_MARGIN - LINE_HEIGHT + (useOffset ? ClientPrefs.data.counterSplitBottomY : 0);
			placeRow(bottom, bottomX, bottomY);
			return;
		}

		var align:FlxTextAlign = LEFT;
		var baseX:Float = SIDE_MARGIN;
		switch (mode)
		{
			case POS_CENTER:
				align = CENTER;
				baseX = (FlxG.width - TEXT_WIDTH) / 2;
			case POS_RIGHT:
				align = RIGHT;
				baseX = FlxG.width - TEXT_WIDTH - SIDE_MARGIN;
		}
		if (useOffset) baseX += ClientPrefs.data.counterOffsetX;

		var startY:Float = FlxG.height / 2 - items.length * LINE_HEIGHT / 2 + LINE_HEIGHT / 2;
		if (useOffset) startY += ClientPrefs.data.counterOffsetY;
		place(items, baseX, startY, align);
	}

	static function place(items:Array<CounterLayoutItem>, x:Float, y:Float, align:FlxTextAlign):Void
	{
		for (i in 0...items.length)
		{
			var t:FlxText = items[i].text;
			t.alignment = align;
			t.x = x;
			t.y = y + LINE_HEIGHT * i;
		}
	}

	/**
	 * split 的一块：各项横向排开，整块以 centerX 居中，宽度跟着文字内容实时变化（无动画）。
	 *
	 * 每次调用都重新量一遍文字宽度，所以数值从 9 变 10、从 99 变 100 时整行会当场放宽并重新居中。
	 * 项间距取"均分列宽方案下相邻间距"的一半（列宽 − 平均文字宽，再除以 2），比原来紧一倍。
	 */
	static function placeRow(items:Array<CounterLayoutItem>, centerX:Float, y:Float):Void
	{
		if (items.length < 1) return;

		var widths:Array<Float> = [];
		var total:Float = 0;
		for (it in items)
		{
			var t:FlxText = it.text;
			t.fieldWidth = 0;   // autoSize：框宽跟随文字
			t.updateHitbox();   // 立刻量出新宽度（否则要等下一帧才准）
			widths.push(t.width);
			total += t.width;
		}

		var colW:Float = Math.min(TEXT_WIDTH, (FlxG.width - SPLIT_MARGIN * 2) / items.length);
		var gap:Float = Math.max(SPLIT_GAP_MIN, (colW - total / items.length) * 0.5);

		var x:Float = centerX - (total + gap * (items.length - 1)) * 0.5;
		for (i in 0...items.length)
		{
			var t:FlxText = items[i].text;
			t.x = x;
			t.y = y;
			x += widths[i] + gap;
		}
	}
}
