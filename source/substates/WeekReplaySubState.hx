package substates;

import backend.WeekData;
import backend.WeekReplay;
import backend.ReplayLibrary;
import backend.MetroEase;
import objects.story.StoryActionButton;
import shapeEx.SlantQuad;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;

/**
 * 周回放选择面板：一张卡片代表"本周回放"，点卡片展开本周每首歌的最佳回放（按准确率取最高），
 * 卡片右侧的播放键整周连播。全部歌曲都有回放才允许开始 —— 缺一首就没法"整周连播"，
 * 这里不做跳歌，避免播出来少一段还以为是 bug。
 *
 * 动效统一走 Win8（Metro）曲线：入场 ENTRANCE（先快后慢）、退场 EXIT（先停顿后离场）。
 * 点击卡片外的空白处直接退出。
 */
class WeekReplaySubState extends MusicBeatSubstate
{
	var week:WeekData;
	var weekIndex:Int;
	var difficulty:Int;

	var bgDim:FlxSprite;

	var cardOutline:SlantQuad;
	var cardBg:SlantQuad;
	var titleText:FlxText;     // WEEK REPLAY
	var weekText:FlxText;      // 周名
	var statusText:FlxText;    // 曲数 / 均准 / 缺失提示
	var expandIcon:FlxSprite;  // 展开指示三角（vcr 无箭头字形，画三角）

	var playBg:SlantQuad;      // 右侧播放键
	var playIcon:FlxSprite;

	var rows:Array<FlxText> = [];       // 歌名
	var accRows:Array<FlxText> = [];    // 右侧 ACC 信息

	var hintText:FlxText;

	var songNames:Array<String> = [];
	var entries:Array<ReplayFileInfo> = [];

	var expanded:Bool = false;
	var animating:Bool = false;
	var closing:Bool = false;
	var entranceDone:Bool = false;
	var scrollOffset:Int = 0;
	var playHovered:Bool = false;
	var playPressed:Bool = false;

	var canStart:Bool = false;
	var missing:Int = 0;

	static inline var CARD_W:Int = 640;
	static inline var CARD_H:Int = 96;
	static inline var ROW_H:Int = 44;
	static inline var MAX_VISIBLE:Int = 8;

	public function new(week:WeekData, weekIndex:Int, difficulty:Int)
	{
		super();
		this.week = week;
		this.weekIndex = weekIndex;
		this.difficulty = difficulty;
	}

	override function create()
	{
		super.create();

		loadEntries();

		bgDim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgDim.alpha = 0;
		bgDim.scrollFactor.set();
		add(bgDim);
		FlxTween.tween(bgDim, {alpha: 0.65}, 0.2);

		var cardX:Float = (FlxG.width - CARD_W) * 0.5;
		var cardY:Float = FlxG.height * 0.5 - 150;

		// 卡片 = 白描边 + 深底（skew=0 即矩形），配色与故事菜单右下角按钮同一套
		cardOutline = new SlantQuad(cardX - 2, cardY - 2, CARD_W + 4, CARD_H + 4, 0, FlxColor.WHITE, 1);
		add(cardOutline);
		cardBg = new SlantQuad(cardX, cardY, CARD_W, CARD_H, 0, StoryActionButton.COLOR_NORMAL, 1);
		add(cardBg);

		titleText = new FlxText(cardX + 20, cardY + 8, 300, 'WEEK REPLAY', 16);
		titleText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFF9CF51, LEFT);
		titleText.antialiasing = ClientPrefs.data.antialiasing;
		add(titleText);

		var weekLabel:String = (week != null && week.storyName != null) ? week.storyName : '';
		weekText = new FlxText(cardX + 20, cardY + 28, CARD_W - 140, weekLabel.toUpperCase(), 24);
		weekText.setFormat(Paths.font('vcr.ttf'), 24, 0xFFF2F2F2, LEFT);
		weekText.antialiasing = ClientPrefs.data.antialiasing;
		add(weekText);

		statusText = new FlxText(cardX + 20, cardY + 62, CARD_W - 140, '', 14);
		statusText.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.GRAY, LEFT);
		statusText.antialiasing = ClientPrefs.data.antialiasing;
		add(statusText);

		// 展开指示三角：收起朝下（可展开），展开朝上
		expandIcon = new FlxSprite(cardX + CARD_W - 128, cardY + CARD_H * 0.5 - 6).makeGraphic(12, 12, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawTriangle(expandIcon, 0, 0, 12, FlxColor.WHITE);
		expandIcon.angle = 180;
		expandIcon.scrollFactor.set();
		expandIcon.alpha = 0.7;
		add(expandIcon);

		// 右侧播放键（整周连播）
		playBg = new SlantQuad(cardX + CARD_W - 96, cardY + 12, 82, CARD_H - 24, 0, StoryActionButton.COLOR_NORMAL, 1);
		add(playBg);
		playIcon = new FlxSprite(0, 0).makeGraphic(20, 20, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawTriangle(playIcon, 0, 0, 20, FlxColor.WHITE);
		playIcon.angle = 90; // 朝右
		playIcon.scrollFactor.set();
		playIcon.setPosition(playBg.x + 34, playBg.y + (playBg.quadHeight - 20) * 0.5);
		add(playIcon);

		buildRows(cardX, cardY);

		hintText = new FlxText(0, FlxG.height - 36, FlxG.width, 'CLICK CARD: TRACKS    ENTER: PLAY    ESC: CLOSE', 14);
		hintText.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.GRAY, CENTER);
		hintText.antialiasing = ClientPrefs.data.antialiasing;
		add(hintText);

		refreshStatus();
		animateCardIn(cardY);
		new FlxTimer().start(0.27, function(_) entranceDone = true);
	}

	function loadEntries():Void
	{
		songNames = [];
		entries = [];
		missing = 0;

		if (week == null || week.songs == null)
		{
			canStart = false;
			return;
		}

		for (s in week.songs)
			songNames.push(Std.string(s[0]));

		var found:Map<String, Array<ReplayFileInfo>> = ReplayLibrary.findForSongs(songNames, difficulty);

		for (name in songNames)
		{
			var list:Array<ReplayFileInfo> = found.get(ReplayLibrary.normalizeSongName(name));
			var best:ReplayFileInfo = ReplayLibrary.bestByAccuracy(list);
			if (best == null) missing++;
			entries.push(best);
		}

		canStart = (missing == 0 && entries.length > 0);
	}

	// ---------------------------------------------------------
	// 布局 / 动效
	// ---------------------------------------------------------

	function listTop(cardY:Float):Float
	{
		return cardY + CARD_H + 10;
	}

	function rowY(cardY:Float, i:Int):Float
	{
		return listTop(cardY) + (i - scrollOffset) * ROW_H;
	}

	function buildRows(cardX:Float, cardY:Float):Void
	{
		for (i in 0...songNames.length)
		{
			var nameText:FlxText = new FlxText(cardX + 24, rowY(cardY, i) + 10, 300, songNames[i], 20);
			nameText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT);
			nameText.antialiasing = ClientPrefs.data.antialiasing;
			nameText.visible = false;
			nameText.alpha = 0;
			add(nameText);
			rows.push(nameText);

			var entry:ReplayFileInfo = entries[i];
			var info:String;
			var color:FlxColor;

			if (entry == null)
			{
				info = 'MISSING';
				color = 0xFFFF5555;
			}
			else
			{
				var fc:String = (entry.finalRatingFC != null && entry.finalRatingFC.length > 0) ? ' ' + entry.finalRatingFC : '';
				info = 'ACC ' + formatAcc(entry.finalAccuracy) + '%' + fc + '  ' + formatDate(entry.timestampMs);
				color = (entry.finalAccuracy >= 95) ? 0xFF7BE07B : 0xFFFFD54A;
			}

			var infoText:FlxText = new FlxText(cardX + 24, rowY(cardY, i) + 12, CARD_W - 48, info, 16);
			infoText.setFormat(Paths.font('vcr.ttf'), 16, color, RIGHT);
			infoText.antialiasing = ClientPrefs.data.antialiasing;
			infoText.visible = false;
			infoText.alpha = 0;
			add(infoText);
			accRows.push(infoText);
		}
	}

	function animateCardIn(cardY:Float):Void
	{
		// 卡片整体从上方 24px 滑入落定（win8 entrance：先快后慢）
		var members:Array<Dynamic> = [cardOutline, cardBg, titleText, weekText, statusText, expandIcon, playBg, playIcon];
		for (m in members)
		{
			m.y -= 24;
			m.alpha = 0;
			FlxTween.tween(m, {y: m.y + 24, alpha: m.alpha + 1}, 0.25, {ease: MetroEase.ENTRANCE});
		}
		hintText.alpha = 0;
		FlxTween.tween(hintText, {alpha: 1}, 0.25, {ease: MetroEase.ENTRANCE, startDelay: 0.1});
	}

	function toggleExpand(cardY:Float):Void
	{
		if (animating || songNames.length == 0) return;
		animating = true;
		expanded = !expanded;
		scrollOffset = 0;

		FlxTween.tween(expandIcon, {angle: expanded ? 0 : 180}, 0.2, {ease: MetroEase.ENTRANCE});

		var n:Int = Std.int(Math.min(songNames.length, MAX_VISIBLE));
		if (expanded)
		{
			for (i in 0...n)
			{
				var row:FlxText = rows[i + scrollOffset];
				var acc:FlxText = accRows[i + scrollOffset];
				// 逐行错峰滑入
				for (t in [row, acc])
				{
					t.visible = true;
					t.y = rowY(cardY, i) + 12;
					FlxTween.tween(t, {y: rowY(cardY, i), alpha: 1}, 0.22, {ease: MetroEase.ENTRANCE, startDelay: i * 0.03});
				}
			}
			new FlxTimer().start(0.22 + (n - 1) * 0.03, function(_) animating = false);
		}
		else
		{
			for (row in rows)
			{
				FlxTween.tween(row, {alpha: 0, y: row.y + 10}, 0.15, {ease: MetroEase.EXIT});
			}
			for (acc in accRows)
			{
				FlxTween.tween(acc, {alpha: 0, y: acc.y + 10}, 0.15, {ease: MetroEase.EXIT});
			}
			new FlxTimer().start(0.16, function(_) {
				for (t in rows) t.visible = false;
				for (t in accRows) t.visible = false;
				animating = false;
			});
		}
	}

	function requestClose():Void
	{
		if (closing) return;
		closing = true;

		FlxTween.tween(bgDim, {alpha: 0}, 0.18, {ease: MetroEase.EXIT});
		for (t in rows) FlxTween.tween(t, {alpha: 0}, 0.18);
		for (t in accRows) FlxTween.tween(t, {alpha: 0}, 0.18);
		var members:Array<Dynamic> = [cardOutline, cardBg, titleText, weekText, statusText, expandIcon, playBg, playIcon, hintText];
		for (m in members)
			FlxTween.tween(m, {alpha: 0, y: m.y - 16}, 0.18, {ease: MetroEase.EXIT});

		new FlxTimer().start(0.19, function(_) close());
	}

	// ---------------------------------------------------------
	// 状态 / 交互
	// ---------------------------------------------------------

	function refreshStatus():Void
	{
		if (canStart)
		{
			var total:Float = 0;
			var cnt:Int = 0;
			for (e in entries)
			{
				if (e == null) continue;
				total += e.finalAccuracy;
				cnt++;
			}
			var avg:Float = (cnt > 0) ? total / cnt : 0;
			statusText.text = songNames.length + ' TRACKS  ·  ' + Difficulty.getString(difficulty) + '  ·  AVG ACC ' + formatAcc(avg) + '%';
			statusText.color = 0xFF7BE07B;
		}
		else
		{
			statusText.text = 'MISSING ' + missing + ' TRACK(S) - NO COMPLETE REPLAY FOR THIS DIFFICULTY';
			statusText.color = 0xFFFF5555;
		}
		playBg.alpha = canStart ? 1 : 0.4;
		playIcon.alpha = canStart ? 1 : 0.4;
	}

	function cardRect():{x:Float, y:Float, w:Float, h:Float}
	{
		return {x: cardBg.x, y: cardBg.y, w: cardBg.quadWidth, h: cardBg.quadHeight};
	}

	function inRect(rx:Float, ry:Float, rw:Float, rh:Float):Bool
	{
		return FlxG.mouse.x >= rx && FlxG.mouse.x <= rx + rw && FlxG.mouse.y >= ry && FlxG.mouse.y <= ry + rh;
	}

	function overCard():Bool
	{
		var r = cardRect();
		return inRect(r.x, r.y, r.w, r.h);
	}

	function overPlay():Bool
	{
		return inRect(playBg.x, playBg.y, playBg.quadWidth, playBg.quadHeight);
	}

	function overList():Bool
	{
		var r = cardRect();
		var n:Int = Std.int(Math.min(songNames.length, MAX_VISIBLE));
		return inRect(r.x, listTop(r.y), r.w, n * ROW_H);
	}

	function setPlayVisual(hover:Bool, press:Bool):Void
	{
		FlxTween.cancelTweensOf(playBg);
		if (press)
		{
			playBg.color = StoryActionButton.COLOR_PRESS;
			playIcon.color = StoryActionButton.COLOR_LABEL_PRESS;
		}
		else
		{
			FlxTween.color(playBg, 0.1, playBg.color, hover ? StoryActionButton.COLOR_HOVER : StoryActionButton.COLOR_NORMAL, {ease: FlxEase.quadOut});
			playIcon.color = StoryActionButton.COLOR_LABEL;
		}
	}

	function startWeekReplay():Void
	{
		if (!canStart)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		var paths:Array<String> = [];
		for (entry in entries)
		{
			if (entry == null) return;
			paths.push(entry.fullPath);
		}

		WeekReplay.start(paths, songNames, week.fileName, weekIndex, difficulty, week.contentRoot, week.variant);

		FlxG.sound.play(Paths.sound('confirmMenu'));
		closing = true;
		new FlxTimer().start(0.1, function(_) {
			close();
			WeekReplay.startFromMenu();
		});
	}

	function refreshVisibleRows(cardY:Float):Void
	{
		var n:Int = Std.int(Math.min(songNames.length, MAX_VISIBLE));
		for (i in 0...songNames.length)
		{
			var show:Bool = expanded && !animating && i >= scrollOffset && i < scrollOffset + n;
			rows[i].visible = show;
			accRows[i].visible = show;
			if (show)
			{
				rows[i].y = rowY(cardY, i) + 10;
				accRows[i].y = rowY(cardY, i) + 12;
			}
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (closing) return;

		var cardY:Float = cardBg.y;

		// ---- 键盘 ----
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			requestClose();
			return;
		}

		if (controls.ACCEPT)
		{
			startWeekReplay();
			return;
		}

		// 入场动画没落定前先不接鼠标，避免和入场 tween 打架（位置会被抓到半路上）
		if (!entranceDone) return;

		// ---- 播放键（松手才触发，与故事菜单按钮同约定）----
		var canInput:Bool = canStart && !animating;
		var hover:Bool = canInput && overPlay();

		if (hover != playHovered)
		{
			playHovered = hover;
			if (!playPressed) setPlayVisual(hover, false);
		}

		if (hover && FlxG.mouse.justPressed)
		{
			playPressed = true;
			setPlayVisual(true, true);
		}

		if (playPressed)
		{
			if (FlxG.mouse.justReleased)
			{
				var fire:Bool = overPlay();
				playPressed = false;
				setPlayVisual(overPlay(), false);
				if (fire)
				{
					startWeekReplay();
					return;
				}
			}
			else if (!FlxG.mouse.pressed)
			{
				playPressed = false;
				setPlayVisual(overPlay(), false);
			}
		}

		// ---- 卡片展开/收起 ----
		if (FlxG.mouse.justPressed && overCard() && !overPlay())
			toggleExpand(cardY);

		// ---- 列表滚动（超出可视行数时滚轮）----
		if (expanded && !animating && songNames.length > MAX_VISIBLE && overList())
		{
			var maxOffset:Int = songNames.length - MAX_VISIBLE;
			var newOffset:Int = scrollOffset;
			if (FlxG.mouse.wheel > 0) newOffset--;
			else if (FlxG.mouse.wheel < 0) newOffset++;
			if (newOffset != scrollOffset)
			{
				scrollOffset = (newOffset < 0) ? 0 : (newOffset > maxOffset ? maxOffset : newOffset);
				refreshVisibleRows(cardY);
			}
		}

		// ---- 点击空白退出 ----
		if (FlxG.mouse.justPressed && !overCard() && !overPlay() && !(expanded && overList()))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			requestClose();
			return;
		}
	}

	// ---------------------------------------------------------
	// 格式化
	// ---------------------------------------------------------

	static function formatAcc(v:Float):String
	{
		if (Math.isNaN(v) || v <= 0) return '0.00';
		var rounded:Float = Math.round(v * 100) / 100;
		var s:String = Std.string(rounded);
		var dot:Int = s.indexOf('.');
		if (dot < 0) return s + '.00';
		var decimals:Int = s.length - dot - 1;
		if (decimals == 0) return s + '00';
		if (decimals == 1) return s + '0';
		return s.substr(0, dot + 3);
	}

	static function formatDate(ms:Float):String
	{
		if (ms <= 0) return '';
		var d:Date = Date.fromTime(ms);
		var mm:String = Std.string(d.getMonth() + 1);
		var dd:String = Std.string(d.getDate());
		if (mm.length < 2) mm = '0' + mm;
		if (dd.length < 2) dd = '0' + dd;
		return d.getFullYear() + '-' + mm + '-' + dd;
	}
}
