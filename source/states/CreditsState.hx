package states;

import backend.CreditsData;
import backend.CreditsData.CreditRow;
import backend.CreditsData.CreditSection;
import backend.CreditsData.CreditsBundle;
import backend.MouseMove;
import backend.RollLine;
import objects.AttachedSprite;
import objects.CreditsVideoPanel;
import openfl.utils.AssetType;
import substates.CreditsRollSubState;
import substates.CreditsVideoSubState;

/**
 * Credits 界面。
 *
 * 布局：顶部两层标题（大标题 = 分组，副标题 = 选中人物职责，0.25s 交叉淡化）、
 *      左侧纯人物列表（靠组间大留白做分隔）、右侧视频面板、底部描述栏 + 当前 mod 页脚。
 * 数据：backend.CreditsData（JSON + 旧 credits.txt 兼容）。
 */
class CreditsState extends MusicBeatState
{
	// ---- Alphabet 的固定几何（1 行 = 1.3 * 120 = 156px，基准 y = 300） ----
	static inline var ROW_BASE_Y:Float = 300;
	static inline var ROW_SPACING:Float = 156;

	// ---- 列表 ----
	static inline var LIST_SIDE_MARGIN:Float = 20;
	static inline var ICON_GAP:Float = 10;
	static inline var ICON_HEIGHT:Float = 110;
	static inline var HOVER_NUDGE:Float = 8;
	static var ALPHA_BY_DIST:Array<Float> = [1.0, 0.55, 0.0];
	static inline var LABEL_ALPHA:Float = 0.45;

	// ---- 视频框 ----
	static inline var VIDEO_H_RATIO:Float = 0.75;
	static inline var VIDEO_RIGHT_MARGIN:Float = 40;
	static inline var VIDEO_GAP:Float = 20;
	static inline var VIDEO_V_OFFSET:Float = -10;

	// ---- 顶部标题 ----
	/** 大标题视觉上沿（不是 Alphabet 的 y，y 由这个值和缩放反推）。留够高度避开左上角 FPS 文字。 */
	static inline var HEADER_TOP:Float = 44;
	/** 副标题与大标题的下沿间距。 */
	static inline var HEADER_GAP:Float = 10;
	static inline var HEADER_BIG_SCALE:Float = 1.0;
	/** 副标题上限缩放，同时按大标题缩放等比收缩，避免长短标题时字号倒挂。 */
	static inline var HEADER_SUB_SCALE:Float = 0.8;
	static inline var HEADER_SUB_RATIO:Float = 0.75;
	static inline var HEADER_MIN_SCALE:Float = 0.34;
	static inline var HEADER_FADE:Float = 0.25;
	/** true = 标题居中于整块屏幕；false = 居中于列表列（与列表、描述栏同轴）。 */
	static inline var HEADER_CENTER_ON_SCREEN:Bool = false;

	// Alphabet 内部几何（来自 alphabet.xml 实测）：粗体字高 68、非粗体最高 60，
	// 视觉下沿分别恒为 y + 70*s 与 y + 110*s —— 锚下沿排版，各字形上沿高低不齐也不影响。
	static inline var BOLD_FRAME_H:Float = 68;
	static inline var BOLD_BASELINE:Float = 70;
	static inline var NORMAL_GLYPH_H:Float = 60;
	static inline var NORMAL_BASELINE:Float = 110;

	// ---- 鼠标 ----
	static inline var HIT_TOP:Float = 40;
	static inline var HIT_BOTTOM:Float = 160;
	static inline var HIT_PAD_X:Float = 12;
	static inline var CLICK_MAX_MOVE:Float = 8;
	/** true = 回到旧手感（第一次点击只选中，第二次才开链接）。 */
	static inline var CLICK_SELECT_ONLY:Bool = false;

	var bundle:CreditsBundle;
	var rows:Array<CreditRow> = [];
	var sections:Array<CreditSection> = [];

	var grpOptions:FlxTypedGroup<Alphabet>;
	var iconArray:Array<AttachedSprite> = [];
	var iconWidth:Array<Float> = [];
	var itemWidth:Array<Float> = [];

	var bg:FlxFilteredSprite;
	var descText:FlxText;
	var descBox:AttachedSprite;
	var modLabel:FlxText;
	var listLabel:FlxText; // VIEW THE FULL LIST >
	var videoLabel:FlxText; // VIEW VIDEO >
	var intendedColor:FlxColor = FlxColor.WHITE;

	/** 当前组解析出的视频路径，'' = 该组没有视频 */
	var curSectionVideoPath:String = '';
	/** 子状态打开期间屏蔽父状态输入（persistentUpdate=true 时父状态照常 update） */
	var inputLocked:Bool = false;
	var hoverUi:Int = -1;
	var pressUi:Int = -1;

	var space:FlxSprite;
	var starsBG:FlxBackdrop;
	var starsFG:FlxBackdrop;

	var videoPanel:CreditsVideoPanel;

	var bigLayers:Array<Alphabet> = [];
	var subLayers:Array<Alphabet> = [];
	var bigFront:Int = 0;
	var subFront:Int = 0;
	var bigScaleNow:Float = 1;
	var headerFadeTimer:Float = 0;
	var lastHeaderCenterX:Float = -99999;

	var listColumnW:Float = 0;
	var listCenterX:Float = 0;
	var layoutTargetX:Float = 0;
	var wideCenterX:Float = 0;
	var narrowCenterX:Float = 0;
	var narrowColumnW:Float = 0;
	var videoCenterX:Float = 0;
	var videoCenterY:Float = 0;
	var videoMaxW:Float = 0;
	var videoMaxH:Float = 0;

	var selCursor:Int = 0; // 在 bundle.selectableRows 里的序号
	var curSelected:Int = 0; // rows 下标

	var hoverRow:Int = -1;
	var pressRow:Int = -1;
	var pressX:Float = 0;
	var pressY:Float = 0;
	var pressDragged:Bool = false;

	var creditScrollPos:Float = 0;
	var creditsScroller:MouseMove;
	static inline var CREDIT_SCROLL_SPACING:Float = 156;

	var quitting:Bool = false;
	var holdTime:Float = 0;
	var moveTween:FlxTween = null;

	// ================================================================
	// 创建
	// ================================================================

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;
		FlxG.mouse.visible = true;

		bundle = CreditsData.load();
		rows = bundle.rows;
		sections = bundle.sections;

		selCursor = 0;
		curSelected = (bundle.selectableRows.length > 0) ? bundle.selectableRows[0] : 0;

		computeLayout();
		createBackground();
		createVideoPanel();
		createList();
		createDescription();
		createModLabel();
		createActionRow();
		createHeader();
		setupCreditsScroller();

		bg.color = rowColor(curSelected);
		intendedColor = bg.color;

		// 首次进入：标题从空淡入，描述/视频/页脚一次补齐
		changeSelection(0);

		super.create();
	}

	function computeLayout():Void
	{
		videoMaxH = FlxG.height * VIDEO_H_RATIO;
		videoMaxW = videoMaxH;
		videoCenterY = FlxG.height * 0.5 + VIDEO_V_OFFSET;
		videoCenterX = FlxG.width - VIDEO_RIGHT_MARGIN - videoMaxW * 0.5;

		// 窄列 = 让开右侧视频面板后的可用宽度（长名缩放、标题最大宽度都按它算，保证不会因栏宽变化而跳字）
		narrowColumnW = Math.max(260, FlxG.width - videoMaxW - VIDEO_RIGHT_MARGIN - VIDEO_GAP);
		listColumnW = narrowColumnW;

		// 没有视频时整块内容铺满全屏居中；出现视频时压缩到左列。两者之间平滑过渡。
		wideCenterX = FlxG.width * 0.5;
		narrowCenterX = narrowColumnW * 0.5;
		listCenterX = wideCenterX;
		layoutTargetX = wideCenterX;
	}

	function createBackground():Void
	{
		bg = new FlxFilteredSprite();
		bg.loadGraphic(Paths.image('menuDesat'));
		if (ClientPrefs.data.blurEffects) bg.filters = [new BlurFilter(5, 5, BitmapFilterQuality.HIGH)];
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		space = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		space.antialiasing = ClientPrefs.data.antialiasing;
		space.updateHitbox();
		space.scrollFactor.set();
		space.alpha = 0;
		add(space);

		starsBG = new FlxBackdrop(Paths.image('starBG'));
		starsBG.setPosition(111.3, 67.95);
		starsBG.antialiasing = true;
		starsBG.updateHitbox();
		starsBG.scrollFactor.set();
		starsBG.alpha = 0;
		add(starsBG);

		starsFG = new FlxBackdrop(Paths.image('starFG'));
		starsFG.setPosition(54.3, 59.45);
		starsFG.updateHitbox();
		starsFG.antialiasing = true;
		starsFG.scrollFactor.set();
		starsFG.alpha = 0;
		add(starsFG);

		if (ClientPrefs.data.globalspace)
		{
			space.alpha = 1;
			starsBG.alpha = 1;
			starsFG.alpha = 1;
		}
	}

	function createVideoPanel():Void
	{
		videoPanel = new CreditsVideoPanel();
		videoPanel.setBox(videoCenterX, videoCenterY, videoMaxW, videoMaxH);
		add(videoPanel);
	}

	function createList():Void
	{
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...rows.length)
		{
			iconWidth.push(0);
			itemWidth.push(0);
		}

		var baseSlot:Int = (rows.length > 0) ? rows[curSelected].slot : 0;

		for (i in 0...rows.length)
		{
			var row:CreditRow = rows[i];
			var optionText:Alphabet = new Alphabet(LIST_SIDE_MARGIN, ROW_BASE_Y, row.name, row.isLabel);
			optionText.isMenuItem = true;
			optionText.changeX = false;
			optionText.targetY = row.slot - baseSlot;
			optionText.antialiasing = ClientPrefs.data.antialiasing;
			optionText.ID = i;

			if (row.isLabel)
			{
				optionText.alignment = CENTERED;
				optionText.alpha = LABEL_ALPHA;
				itemWidth[i] = optionText.getTextWidth();
				iconWidth[i] = 0;
				grpOptions.add(optionText);
				optionText.snapToPosition();
				continue;
			}

			var icon:AttachedSprite = buildIcon(row);
			itemWidth[i] = optionText.getTextWidth();

			// 长名保护：超出列宽就等比缩小
			var avail:Float = listColumnW - LIST_SIDE_MARGIN * 2 - ICON_GAP - icon.width;
			var rawW:Float = itemWidth[i];
			if (rawW > avail && rawW > 0 && avail > 0)
			{
				optionText.setScale(avail / rawW);
				itemWidth[i] = rawW * optionText.scale.x;
			}

			icon.xAdd = itemWidth[i] + ICON_GAP;
			icon.yAdd = 25; // 图标与文字视觉带（y+50..y+110）居中
			icon.sprTracker = optionText;
			iconWidth[i] = icon.width;
			iconArray.push(icon);

			grpOptions.add(optionText);
			add(icon);
			optionText.snapToPosition();
		}
	}

	function buildIcon(row:CreditRow):AttachedSprite
	{
		return CreditsData.withMod(row.mod, function()
		{
			var str:String = 'credits/missing_icon';
			if (row.icon != null && row.icon.length > 0)
			{
				var fileName:String = 'credits/' + row.icon;
				if (Paths.fileExists('images/$fileName.png', IMAGE)) str = fileName;
				else if (Paths.fileExists('images/$fileName-pixel.png', IMAGE)) str = fileName + '-pixel';
			}

			var icon:AttachedSprite = new AttachedSprite(str);
			if (str.endsWith('-pixel')) icon.antialiasing = false;
			icon.setGraphicSize(0, Std.int(ICON_HEIGHT));
			icon.updateHitbox();
			return icon;
		});
	}

	function createDescription():Void
	{
		descBox = new AttachedSprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.xAdd = -10;
		descBox.yAdd = -10;
		descBox.alphaMult = 0.6;
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, FlxG.height - 100, 1180, "", 32);
		descText.antialiasing = ClientPrefs.data.antialiasing;
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		descText.scrollFactor.set();
		descBox.sprTracker = descText;
		add(descText);
	}

	function createModLabel():Void
	{
		modLabel = new FlxText(FlxG.width - 444, FlxG.height - 34, 420, '', 20);
		modLabel.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, RIGHT);
		modLabel.antialiasing = ClientPrefs.data.antialiasing;
		modLabel.scrollFactor.set();
		modLabel.alpha = 0.6;
		modLabel.visible = false;
		add(modLabel);
	}

	/**
	 * 底部动作条：`[当前 mod] ... [V] VIEW VIDEO   VIEW THE FULL LIST >`
	 * 放在 y = H-34 —— descBox 底边恒为 H-45，这一行在任何情况下都空着。
	 */
	function createActionRow():Void
	{
		listLabel = makeActionLabel('VIEW THE FULL LIST  >');
		videoLabel = makeActionLabel('VIEW VIDEO  >');
		videoLabel.visible = false;
		add(listLabel);
		add(videoLabel);
		layoutActionRow();
	}

	function makeActionLabel(text:String):FlxText
	{
		var t:FlxText = new FlxText(0, FlxG.height - 34, 0, text, 20);
		t.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, RIGHT);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.scrollFactor.set();
		t.alpha = 0.65;
		return t;
	}

	/** 动作条右对齐排布：动作标签位置固定（只随内容和视频标签显隐变化），mod 名排到它们左边。 */
	function layoutActionRow():Void
	{
		var rowY:Float = FlxG.height - 34;
		var right:Float = FlxG.width - 24;

		listLabel.y = rowY;
		listLabel.x = right - listLabel.width;
		right = listLabel.x - 28;

		videoLabel.y = rowY;
		if (videoLabel.visible)
		{
			videoLabel.x = right - videoLabel.width;
			if (videoLabel.x < 40) videoLabel.x = 40;
			right = videoLabel.x - 28;
		}

		modLabel.y = rowY;
		modLabel.x = right - 420;
		if (modLabel.x < 40) modLabel.x = 40;
	}

	function createHeader():Void
	{
		bigLayers = [makeHeaderLayer(true), makeHeaderLayer(true)];
		subLayers = [makeHeaderLayer(false), makeHeaderLayer(false)];
		bigFront = 0;
		subFront = 0;
		bigScaleNow = HEADER_BIG_SCALE;
	}

	function makeHeaderLayer(bold:Bool):Alphabet
	{
		var a:Alphabet = new Alphabet(headerCenterX(), HEADER_TOP, '', bold);
		a.isMenuItem = false;
		a.changeX = false;
		a.changeY = false;
		a.alignment = LEFT; // 居中交给 centerOnX 按真实绘制宽度做，不依赖对齐偏移
		a.antialiasing = ClientPrefs.data.antialiasing;
		a.alpha = 0;
		add(a);
		return a;
	}

	function setupCreditsScroller():Void
	{
		if (bundle.selectableRows.length <= 1) return;

		var maxScroll:Float = Math.max(0, (bundle.selectableRows.length - 1) * CREDIT_SCROLL_SPACING);
		creditsScroller = new MouseMove(this, 'creditScrollPos', [0, maxScroll], [[0, FlxG.width], [0, FlxG.height]], onCreditScrollChange);
		creditsScroller.useLerp = true;
		creditsScroller.lerpSmooth = 12;
		creditsScroller.dragSensitivity = 1.6;
		creditsScroller.deceleration = 0.94;

		// 滚轮只由 handleMouseInput 消费，否则一次滚轮会滚两格
		creditsScroller.enableMouseWheel = false;
		// 只认"位移"起拖：按住不动不该变成拖拽，否则单击永远开不了链接
		creditsScroller.dragStartDelayMs = 1000000;
		creditsScroller.dragStartDistance = 8;

		add(creditsScroller);
	}

	// ================================================================
	// 每帧
	// ================================================================

	override function update(elapsed:Float)
	{
		starsBG.x -= 0.05;
		starsFG.x -= 0.15;
		if (starsBG.x < -starsBG.width) starsBG.x = 0;
		if (starsFG.x < -starsFG.width) starsFG.x = 0;

		if (!inputLocked && FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if (headerFadeTimer > 0) headerFadeTimer -= elapsed;

		// 列表列中心在「全屏居中」与「让开视频的左列」之间平滑过渡
		listCenterX = FlxMath.lerp(layoutTargetX, listCenterX, Math.exp(-elapsed * 8));
		if (Math.abs(listCenterX - layoutTargetX) < 0.3) listCenterX = layoutTargetX;
		if (listCenterX != lastHeaderCenterX)
		{
			lastHeaderCenterX = listCenterX;
			if (bigLayers.length > 0) bigLayers[bigFront].centerOnX(listCenterX);
			if (subLayers.length > 0) subLayers[subFront].centerOnX(listCenterX);
		}

		if (!quitting && !inputLocked)
		{
			handleMouseInput(elapsed);

			if (bundle.selectableRows.length > 1)
			{
				var shiftMult:Int = 1;
				if (FlxG.keys.pressed.SHIFT) shiftMult = 3;

				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);
					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}
			}

			if (controls.ACCEPT && canOpen(curSelected))
			{
				CoolUtil.browserLoad(rows[curSelected].link);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.4);
			}

			if (FlxG.keys.justPressed.TAB) openRoll();
			else if (FlxG.keys.justPressed.V) openSectionVideo();

			if (controls.BACK || FlxG.mouse.justPressedRight)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				quitting = true;
			}
		}

		updateItemPositions(elapsed);
		updateItemAlpha(elapsed);
		updateActionAlpha(elapsed);

		super.update(elapsed);
	}

	function updateActionAlpha(elapsed:Float):Void
	{
		if (listLabel == null || videoLabel == null) return;
		var lerpVal:Float = Math.exp(-elapsed * 14);
		listLabel.alpha = FlxMath.lerp((hoverUi == 0) ? 1.0 : 0.65, listLabel.alpha, lerpVal);
		videoLabel.alpha = FlxMath.lerp((hoverUi == 1) ? 1.0 : 0.65, videoLabel.alpha, lerpVal);
	}

	function handleMouseInput(elapsed:Float):Void
	{
		if (creditsScroller != null && FlxG.mouse.wheel != 0)
		{
			changeSelection(-Std.int(FlxG.mouse.wheel), true, false);
		}

		var ui:Int = uiAt(FlxG.mouse.x, FlxG.mouse.y);
		var row:Int = (ui >= 0) ? -1 : hitTest(); // 命中动作条时绝不同时命中人物行

		if (ui != hoverUi || row != hoverRow)
		{
			hoverUi = ui;
			hoverRow = row;
			updateCursor();
		}

		if (FlxG.mouse.justPressed)
		{
			pressUi = ui;
			pressRow = row;
			pressX = FlxG.mouse.x;
			pressY = FlxG.mouse.y;
			pressDragged = false;
		}

		if (pressRow >= 0 || pressUi >= 0)
		{
			if (FlxG.mouse.pressed)
			{
				var moved:Float = Math.abs(FlxG.mouse.x - pressX) + Math.abs(FlxG.mouse.y - pressY);
				if (moved > CLICK_MAX_MOVE) pressDragged = true;
			}
			else if (FlxG.mouse.justReleased)
			{
				var dragged:Bool = pressDragged || (creditsScroller != null && creditsScroller.isDragging);
				if (!dragged)
				{
					if (pressUi == 0) openRoll();
					else if (pressUi == 1) openSectionVideo();
					else if (pressRow >= 0) onRowClick(pressRow);
				}
				pressRow = -1;
				pressUi = -1;
			}
		}
	}

	/** 底部动作条命中：0 = 完整名单，1 = 组视频。 */
	function uiAt(mx:Float, my:Float):Int
	{
		if (listLabel != null && listLabel.visible && rectHit(listLabel, mx, my)) return 0;
		if (videoLabel != null && videoLabel.visible && rectHit(videoLabel, mx, my)) return 1;
		return -1;
	}

	inline function rectHit(t:FlxText, mx:Float, my:Float):Bool
	{
		return mx >= t.x - 8 && mx <= t.x + t.width + 8 && my >= t.y - 6 && my <= t.y + t.height + 6;
	}

	/** 自算命中矩形：FlxG.mouse.overlaps 会忽略字形 offset，判定区整块偏上 ~70px。 */
	function hitTest():Int
	{
		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;

		for (i in 0...grpOptions.members.length)
		{
			var item:Alphabet = grpOptions.members[i];
			if (item == null || rows[i].isLabel) continue;
			if (Math.abs(item.targetY) > 1) continue; // 只允许点可见行（|Δ|>=2 已淡到全透明）

			var left:Float = item.x - HIT_PAD_X;
			var right:Float = item.x + itemWidth[i] + ICON_GAP + iconWidth[i] + HIT_PAD_X;
			if (mx < left || mx > right) continue;

			var top:Float = item.y + HIT_TOP;
			var bottom:Float = item.y + HIT_BOTTOM;
			if (my < top || my > bottom) continue;

			return i;
		}
		return -1;
	}

	function onRowClick(rowIndex:Int):Void
	{
		if (rowIndex < 0 || rowIndex >= rows.length) return;

		var wasSelected:Bool = (rowIndex == curSelected);

		var ord:Int = bundle.selectableRows.indexOf(rowIndex);
		if (ord >= 0)
		{
			selCursor = ord;
			curSelected = rowIndex;
			changeSelection(0, false);
		}

		if (!canOpen(rowIndex)) return;
		if (CLICK_SELECT_ONLY && !wasSelected) return;

		CoolUtil.browserLoad(rows[rowIndex].link);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.4);
	}

	inline function canOpen(rowIndex:Int):Bool
	{
		if (rowIndex < 0 || rowIndex >= rows.length) return false;
		var link:String = rows[rowIndex].link;
		return link != null && link.length > 4;
	}

	function updateCursor():Void
	{
		#if desktop
		openfl.ui.Mouse.cursor = (hoverUi >= 0 || (hoverRow >= 0 && canOpen(hoverRow)))
			? openfl.ui.MouseCursor.BUTTON
			: openfl.ui.MouseCursor.ARROW;
		#end
	}

	function updateItemPositions(elapsed:Float):Void
	{
		var lerpVal:Float = Math.exp(-elapsed * 12);

		// 选中块「文字 + 图标」整体居中于列表列；其余行以它的左沿为基准往左退，
		// 这样列表列的横向位置（全屏居中 / 压缩到左列）变化时，整摞人名的相对关系不会散开。
		var selBlockW:Float = 0;
		if (curSelected >= 0 && curSelected < itemWidth.length)
			selBlockW = itemWidth[curSelected] + ICON_GAP + iconWidth[curSelected];
		var selLeft:Float = listCenterX - selBlockW * 0.5;

		for (i in 0...grpOptions.members.length)
		{
			var item:Alphabet = grpOptions.members[i];
			if (item == null) continue;

			var targetX:Float;
			if (rows[i].isLabel)
			{
				// 小标签是 CENTERED 对齐，组坐标 x 即视觉中心
				targetX = listCenterX;
			}
			else if (item.targetY == 0)
			{
				var blockW:Float = itemWidth[i] + ICON_GAP + iconWidth[i];
				targetX = listCenterX - blockW * 0.5;
			}
			else
			{
				targetX = selLeft - 40 * Math.abs(item.targetY);
			}

			if (i == hoverRow) targetX += HOVER_NUDGE;
			if (targetX < LIST_SIDE_MARGIN) targetX = LIST_SIDE_MARGIN;

			item.x = FlxMath.lerp(targetX, item.x, lerpVal);
		}
	}

	function updateItemAlpha(elapsed:Float):Void
	{
		var lerpVal:Float = Math.exp(-elapsed * 14);

		for (i in 0...grpOptions.members.length)
		{
			var item:Alphabet = grpOptions.members[i];
			if (item == null) continue;

			var target:Float;
			if (rows[i].isLabel)
			{
				target = LABEL_ALPHA;
			}
			else
			{
				var dist:Int = Std.int(Math.abs(item.targetY));
				target = (dist < ALPHA_BY_DIST.length) ? ALPHA_BY_DIST[dist] : 0.0;
				if (i == hoverRow) target = Math.min(1.0, target + 0.25);
			}

			item.alpha = FlxMath.lerp(target, item.alpha, lerpVal);
		}
	}

	// ================================================================
	// 选中变化
	// ================================================================

	function changeSelection(change:Int = 0, playSound:Bool = true, moveScroller:Bool = true):Void
	{
		if (bundle.selectableRows.length == 0) return;

		if (change != 0 && playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		selCursor = Std.int(FlxMath.bound(selCursor + change, 0, bundle.selectableRows.length - 1));
		curSelected = bundle.selectableRows[selCursor];

		if (moveScroller && creditsScroller != null)
		{
			creditScrollPos = selCursor * CREDIT_SCROLL_SPACING;
			creditsScroller.tweenData = creditScrollPos;
		}

		var row:CreditRow = rows[curSelected];
		var baseSlot:Int = row.slot;

		for (i in 0...grpOptions.members.length)
		{
			var item:Alphabet = grpOptions.members[i];
			if (item == null) continue;
			item.targetY = rows[i].slot - baseSlot;
		}

		// 背景色（1s 渐变）
		var newColor:FlxColor = rowColor(curSelected);
		if (newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		refreshHeader(row);
		refreshDescription(row);
		refreshModLabel(row);
		refreshVideo(row);
		refreshSectionVideo();
	}

	function rowColor(index:Int):FlxColor
	{
		if (index < 0 || index >= rows.length) return CoolUtil.colorFromString(CreditsData.DEFAULT_COLOR);
		return CoolUtil.colorFromString(rows[index].color);
	}

	function refreshHeader(row:CreditRow):Void
	{
		var wantBig:String = sections[row.section].name;
		var wantSub:String = CreditsData.subtitleOf(row);

		if (bigLayers[bigFront].text == wantBig && subLayers[subFront].text == wantSub) return;

		var busy:Bool = headerFadeTimer > 0;
		var maxW:Float = headerMaxWidth();

		// 大标题先做，副标题的缩放/位置依赖它的最终缩放
		bigFront = crossfadeLayer(bigLayers, bigFront, wantBig, HEADER_BIG_SCALE, maxW, busy, true);
		subFront = crossfadeLayer(subLayers, subFront, wantSub, HEADER_SUB_SCALE, maxW, busy, false);
		if (!busy) headerFadeTimer = HEADER_FADE;
	}

	function crossfadeLayer(layers:Array<Alphabet>, front:Int, newText:String, baseScale:Float, maxW:Float, hardSwap:Bool, isBig:Bool):Int
	{
		newText = (newText == null) ? '' : newText;

		var old:Alphabet = layers[front];
		var nxt:Alphabet = layers[1 - front];
		if (old.text == newText) return front;

		FlxTween.cancelTweensOf(old);
		FlxTween.cancelTweensOf(nxt);

		// createLetters 会按当前 scale 累积字距，所以必须先回到 1 倍再排字，量出来的宽度才是"自然宽度"
		nxt.setScale(1);
		nxt.text = newText;

		var target:Float = isBig ? baseScale : Math.min(baseScale, bigScaleNow * HEADER_SUB_RATIO);
		var natural:Float = nxt.getVisualWidth();
		if (natural > 0)
		{
			if (natural * target > maxW) target = maxW / natural;
			if (target < HEADER_MIN_SCALE) target = HEADER_MIN_SCALE;
		}
		nxt.setScale(target);

		// 锚视觉下沿排版：粗体下沿 = y + 70s，非粗体下沿 = y + 110s
		if (isBig)
		{
			bigScaleNow = target;
			nxt.y = HEADER_TOP - (BOLD_BASELINE - BOLD_FRAME_H) * target;
		}
		else
		{
			var bigBottom:Float = HEADER_TOP + BOLD_FRAME_H * bigScaleNow;
			nxt.y = bigBottom + HEADER_GAP - (NORMAL_BASELINE - NORMAL_GLYPH_H) * target;
		}

		nxt.centerOnX(headerCenterX());

		// set_text 重建字形后新字形 alpha=1，而组的 alpha 字段还是旧值 → 先归一化再给目标值
		nxt.alpha = 1;
		nxt.alpha = 0;

		if (hardSwap)
		{
			old.alpha = 0;
			nxt.alpha = 1;
			return 1 - front;
		}

		FlxTween.tween(old, {alpha: 0}, HEADER_FADE, {ease: FlxEase.quadOut});
		FlxTween.tween(nxt, {alpha: 1}, HEADER_FADE, {ease: FlxEase.quadOut});
		return 1 - front;
	}

	inline function headerCenterX():Float
	{
		return HEADER_CENTER_ON_SCREEN ? FlxG.width * 0.5 : listCenterX;
	}

	inline function headerMaxWidth():Float
	{
		// 始终按"让开视频"的窄列算：这样有无视频时标题字号不会跳
		return HEADER_CENTER_ON_SCREEN ? (FlxG.width - 80) : (narrowColumnW - LIST_SIDE_MARGIN * 2);
	}

	function refreshDescription(row:CreditRow):Void
	{
		descText.text = (row.desc == null) ? '' : row.desc;

		if (descText.text.trim().length > 0)
		{
			descText.visible = descBox.visible = true;
			descText.y = FlxG.height - descText.height - 135;

			if (moveTween != null) moveTween.cancel();
			moveTween = FlxTween.tween(descText, {y: descText.y + 75}, 0.25, {ease: FlxEase.sineOut});

			descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
			descBox.updateHitbox();
		}
		else
		{
			descText.visible = descBox.visible = false;
		}
	}

	function refreshModLabel(row:CreditRow):Void
	{
		var sec:CreditSection = sections[row.section];
		var isMod:Bool = (sec.kind == 'mod' && sec.mod != null && sec.mod.length > 0);
		modLabel.visible = isMod;
		modLabel.text = isMod ? sec.name : '';
	}

	function refreshVideo(row:CreditRow):Void
	{
		var path:String = resolveVideoPath(row);
		videoPanel.showVideo(path);
		layoutTargetX = (path.length > 0) ? narrowCenterX : wideCenterX;
	}

	function resolveVideoPath(row:CreditRow):String
	{
		#if VIDEOS_ALLOWED
		if (row == null || row.video == null || row.video.length == 0) return '';

		var key:String = 'credits/' + row.video;
		var path:String = CreditsData.withMod(row.mod, function() return Paths.video(key));

		#if sys
		if (!FileSystem.exists(path))
		{
			trace('[CreditsState] video not found: $path');
			return '';
		}
		#end
		return path;
		#else
		return '';
		#end
	}

	// ================================================================
	// 组级视频 / 完整名单入口
	// ================================================================

	function refreshSectionVideo():Void
	{
		curSectionVideoPath = resolveSectionVideo();
		videoLabel.visible = (curSectionVideoPath.length > 0);
		layoutActionRow();
	}

	function resolveSectionVideo():String
	{
		#if VIDEOS_ALLOWED
		if (rows.length == 0) return '';
		var row:CreditRow = rows[curSelected];
		if (row == null) return '';

		var sec:CreditSection = sections[row.section];
		if (sec == null || sec.video == null || sec.video.length == 0) return '';

		// 允许写 `Beihu` 也允许写 `credits/Beihu`，不要拼成 credits/credits/...
		var key:String = (sec.video.indexOf('/') >= 0) ? sec.video : 'credits/' + sec.video;
		var path:String = CreditsData.withMod(sec.mod, function() return Paths.video(key));

		#if sys
		if (!FileSystem.exists(path))
		{
			trace('[CreditsState] section video not found: $path');
			return '';
		}
		#end
		return path;
		#else
		return '';
		#end
	}

	function openRoll():Void
	{
		if (inputLocked || subState != null) return;

		var lines:Array<RollLine> = CreditsData.collectRollLines(bundle);
		if (lines.length == 0) return;

		inputLocked = true;
		persistentDraw = false; // 父界面整帧不绘制
		videoPanel.hideVideo(); // 别和全屏内容抢解码

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var sub:CreditsRollSubState = new CreditsRollSubState(lines);
		sub.closeCallback = onSubClosed;
		openSubState(sub);
	}

	function openSectionVideo():Void
	{
		if (inputLocked || subState != null) return;
		if (curSectionVideoPath.length == 0) return;

		inputLocked = true;
		persistentDraw = false;
		videoPanel.hideVideo();

		FlxG.sound.play(Paths.sound('confirmMenu'), 0.4);

		var sub:CreditsVideoSubState = new CreditsVideoSubState(curSectionVideoPath);
		sub.closeCallback = onSubClosed;
		openSubState(sub);
	}

	function onSubClosed():Void
	{
		inputLocked = false;
		persistentDraw = true;
		if (videoPanel != null) videoPanel.visible = true;
		if (rows.length > 0) refreshVideo(rows[curSelected]);
		updateCursor();
	}

	// ================================================================
	// 滚动器回调
	// ================================================================

	function onCreditScrollChange():Void
	{
		if (creditsScroller == null || bundle.selectableRows.length == 0) return;

		// 只跟随"用户拖动 / 拖拽惯性"；程序化 scroll（键盘、滚轮）不参与，否则会中途扫过一堆条目
		var drivenByUser:Bool = creditsScroller.isDragging || Math.abs(creditsScroller.velocity) > 0.01;
		if (!drivenByUser) return;

		var ord:Int = Std.int(Math.round(creditScrollPos / CREDIT_SCROLL_SPACING));
		ord = Std.int(FlxMath.bound(ord, 0, bundle.selectableRows.length - 1));
		if (ord == selCursor) return;

		selCursor = ord;
		changeSelection(0, false, false);
	}

	// ================================================================
	// 清理
	// ================================================================

	override function destroy()
	{
		#if desktop
		openfl.ui.Mouse.cursor = openfl.ui.MouseCursor.ARROW;
		#end

		if (videoPanel != null)
		{
			videoPanel.dispose();
			videoPanel = null;
		}

		super.destroy();
	}
}
