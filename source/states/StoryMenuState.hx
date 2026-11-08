package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.MouseMove;

import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;

import objects.MenuItem;
import objects.MenuCharacter;
import objects.story.StoryActionButton;

import options.psychoptions.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import substates.WeekReplaySubState;

import backend.StageData;


class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	// ---------------------------------------------------------
	// 左上角战绩
	// ---------------------------------------------------------
	var statsBG:FlxSprite;
	var scoreText:FlxText;

	private static var lastDifficultyName:String = '';
	var curDifficulty:Int = 1;

	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;

	private static var curWeek:Int = 0;

	var space:FlxSprite;
	var starsBG:FlxBackdrop;
	var starsFG:FlxBackdrop;

	var txtTracklist:FlxText;

	var grpWeekText:FlxTypedGroup<MenuItem>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	var grpLocks:FlxTypedGroup<FlxSprite>;

	var difficultySelectors:FlxGroup;
	var sprDifficulty:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;

	/** 右下角斜切功能块：REPLAY / BACK / CHANGER（数组顺序 = 画序 = 叠放顺序） */
	var actionButtons:Array<StoryActionButton> = [];
	/** 周锁定时要单独置灰的那块 */
	var replayButton:StoryActionButton;

	var loadedWeeks:Array<WeekData> = [];

	// ---------------------------------------------------------
	// 鼠标 / 滚动
	// ---------------------------------------------------------
	var mouseOverWeek:Int = -1;
	var mouseOverLeftArrow:Bool = false;
	var mouseOverRightArrow:Bool = false;

	/** 连续滚动值（单位与 MenuItem.targetY 相同）。选中项落在 LIST_BASE_Y。
	    由 weekScroller（MouseMove）驱动：拖拽 / 惯性 / 吸附全走它。 */
	var scrollPos:Float = 0;

	/** 滚动器组件，拖拽手感对齐 Credits（1.6x 灵敏度 + 加权惯性 + 弹簧越界） */
	var weekScroller:MouseMove;

	/** 拖拽 / 惯性是否正在驱动列表（惯性耗尽后要吸附回最近的周） */
	var scrollDriven:Bool = false;

	/** 列表区按压中（从按下到松手，期间抑制悬停高亮变化） */
	var pressActive:Bool = false;
	var pressedWeek:Int = -1;
	var pressY:Float = 0;

	/** 操作后的输入锁（秒）——防"手一抖连点"与"拖完立刻选中" */
	var inputCooldown:Float = 0;
	var wheelCooldown:Float = 0;

	// hover 变化追踪，避免每帧重设 alpha / 重播箭头 idle
	var lastHoverWeek:Int = -1;
	var lastHoverLeft:Bool = false;
	var lastHoverRight:Bool = false;

	var holdTime:Float = 0; // 键盘长按连发计时
	var shiftMult:Int = 1;  // SHIFT 加速倍率

	// ---------------------------------------------------------
	// 常量
	// ---------------------------------------------------------
	static inline var LIST_BASE_Y:Float = 480;
	static inline var CLICK_SLOP:Float = 12;
	static inline var INPUT_COOLDOWN:Float = 0.15;

	// 右下角三块**同尺寸**平行四边形，边对边拼成缺左上角的 L：
	//                 ┌──────────┐
	//                 │  REPLAY  │   上
	//       ┌─────────┼──────────┤
	//       │ CHANGER │   BACK   │   左 / 中
	//       └─────────┴──────────┘
	// 接缝规则：右块的 x = 左块的 x + 一个 skew；上块的 y = 下块的 y - BTN_H。
	// 位置不写死：整组按"距屏幕右下角的留白"反推（FlxG.width / FlxG.height），
	// 改 BTN_W / BTN_H / 留白都不会再把接缝算歪。
	static inline var BTN_W:Float = 230;
	static inline var BTN_H:Float = 70;
	static inline var BTN_SKEW:Float = 28;
	static inline var BTN_BORDER:Float = 2;

	/** 整组右下角距屏幕边缘的留白 */
	static inline var BTN_MARGIN_RIGHT:Float = 0;
	static inline var BTN_MARGIN_BOTTOM:Float = 5;

	/** 难度行右端到屏幕边缘的留白：整行从右往左排（1280 下右箭头落在 1226，和原先调好的位置一致） */
	static inline var DIFF_ROW_RIGHT_MARGIN:Float = 7;
	/** 左箭头 → 右箭头的水平间距（难度图就塞在这段里），与屏幕宽度无关 */
	static inline var DIFF_ARROW_GAP:Float = 376;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		persistentUpdate = persistentDraw = true;
		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			showNoWeeksError();
			return;
		}

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

		if(curWeek >= WeekData.weeksList.length) curWeek = 0;

		scoreText = new FlxText(10, 24, 0, '', 18);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		scoreText.antialiasing = ClientPrefs.data.antialiasing;

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		var num:Int = 0;
		var itemTargetY:Float = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if(!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
				WeekData.setDirectoryFromWeek(weekFile);
				var weekThing:MenuItem = new MenuItem(0, bgSprite.y + 396, WeekData.weeksList[i]);
				weekThing.y += ((weekThing.height + 20) * num);
				weekThing.ID = num;
				weekThing.targetY = itemTargetY;
				// 间距与 targetY 用同一套公式，否则滚动位置会和初始堆叠错开
				itemTargetY += Math.max(weekThing.height, 110) + 10;
				grpWeekText.add(weekThing);

				weekThing.screenCenter(X);

				// Needs an offset thingie
				if (isLocked)
				{
					var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
					lock.antialiasing = ClientPrefs.data.antialiasing;
					lock.frames = ui_tex;
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					// ID 必须是 grpWeekText 的下标（num），不是 weeksList 的下标（i）：
					// hiddenUntilUnlocked 的周不会进 loadedWeeks，用 i 会错位。
					lock.ID = num;
					grpLocks.add(lock);
				}
				num++;
			}
		}

		if (loadedWeeks.length < 1)
		{
			showNoWeeksError();
			return;
		}

		WeekData.setDirectoryFromWeek(loadedWeeks[0]);
		var charArray:Array<String> = loadedWeeks[0].weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		// 箭头 y 用首项的初始堆叠位（与旧版一致：难度行在周标题上方一点）
		// x 先留空，等右箭头的贴图宽度出来后再从右边缘反推（见下面 rightArrow 那段）
		leftArrow = new FlxSprite(0, grpWeekText.members[0].y + 10);
		leftArrow.antialiasing = ClientPrefs.data.antialiasing;
		leftArrow.frames = ui_tex;
		leftArrow.animation.addByPrefix('idle', "arrow left");
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		difficultySelectors.add(leftArrow);

		Difficulty.resetList();
		if(lastDifficultyName == '')
		{
			lastDifficultyName = Difficulty.getDefault();
		}
		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		sprDifficulty = new FlxSprite(0, leftArrow.y);
		sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;
		difficultySelectors.add(sprDifficulty);

		rightArrow = new FlxSprite(0, leftArrow.y);
		rightArrow.antialiasing = ClientPrefs.data.antialiasing;
		rightArrow.frames = ui_tex;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrow.animation.play('idle');
		difficultySelectors.add(rightArrow);

		// 难度行贴着屏幕右边排：右箭头的右端固定距边 DIFF_ROW_RIGHT_MARGIN，
		// 左箭头再往左推一个 DIFF_ARROW_GAP。必须等贴图宽度出来才能算，所以放在这里。
		rightArrow.x = FlxG.width - DIFF_ROW_RIGHT_MARGIN - rightArrow.width;
		leftArrow.x = rightArrow.x - DIFF_ARROW_GAP;

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07 + 100, bgSprite.y + 425).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		tracksSprite.x -= tracksSprite.width/2;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);

		// 战绩背板：一行装下 Score / 准确率 / FC（vcr 是等宽字体，18 号最坏约 31 字符 ≈ 560px）
		// y=20 起是为了避开 Main 里那个 (10,3) 的 FPS 计数器
		statsBG = new FlxSprite(4, 20).makeGraphic(600, 34, 0xCC000000);
		statsBG.scrollFactor.set();
		add(statsBG);

		add(scoreText);
		add(txtWeekTitle);

		// 右下角功能块（必须在 txtWeekTitle 之后，否则会被 bgYellow / bgSprite 盖住）
		createActionButtons();

		changeWeek();

		scrollPos = grpWeekText.members[curWeek].targetY;
		applyScrollPositions();

		// 拖拽手感与 Credits 一致：交给 MouseMove 组件。必须在 scrollPos 初始化之后创建，
		// 构造函数会读一次初值。
		setupWeekScroller();

		// 显示鼠标
		FlxG.mouse.visible = true;

		super.create();
	}

	function showNoWeeksError():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		persistentUpdate = false;
		MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR STORY MODE\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
			function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
			function() MusicBeatState.switchState(new states.MainMenuState())));
	}

	// ---------------------------------------------------------
	// 右下角斜切按钮组
	// ---------------------------------------------------------
	function createActionButtons():Void
	{
		actionButtons = [];

		// ---- 坐标：从屏幕右下角反推，不写死 1280×720 的绝对像素 ----
		// 整组外框：宽 = 2*BTN_W（最左点是 CHANGER 的左下角，最右点是 REPLAY 的右上角），高 = 2*BTN_H。
		var groupW:Float = BTN_W * 2;
		var groupH:Float = BTN_H * 2;
		var left:Float = FlxG.width - BTN_MARGIN_RIGHT - groupW;
		var top:Float = FlxG.height - BTN_MARGIN_BOTTOM - groupH;

		// 由外框左上角推三块：REPLAY 的左边 = 外框左边 + 一个块宽，其余按接缝公式递推
		var replayX:Float = left + BTN_W;
		var replayY:Float = top;
		var backX:Float = replayX - BTN_SKEW;
		var backY:Float = replayY + BTN_H;
		var changerX:Float = backX - BTN_W + BTN_SKEW;   // 化简后就是 left
		var changerY:Float = backY;

		// 画序 = 数组顺序。三块互不重叠（只差 2px 接缝），命中裁决取"最后一个命中的"，
		// 也就是共用那条斜接缝归后画的那块。
		replayButton = new StoryActionButton(replayX, replayY, BTN_W, BTN_H, BTN_SKEW,
			Language.getPhrase('story_replay', 'REPLAY'), 21, onReplayPressed, BTN_BORDER);
		actionButtons.push(replayButton);
		add(replayButton);

		var backButton = new StoryActionButton(backX, backY, BTN_W, BTN_H, BTN_SKEW,
			Language.getPhrase('story_back', 'BACK'), 23, onBackPressed, BTN_BORDER);
		actionButtons.push(backButton);
		add(backButton);

		var changerButton = new StoryActionButton(changerX, changerY, BTN_W, BTN_H, BTN_SKEW,
			Language.getPhrase('story_changer', 'CHANGER'), 21, onChangersPressed, BTN_BORDER);
		actionButtons.push(changerButton);
		add(changerButton);
	}

	function lockActionButtons():Void
	{
		// 立刻清掉 hover / 按下态，避免开子状态后按钮还亮着黄
		for (b in actionButtons)
			b.updateButton(false, false);
	}

	function onBackPressed():Void
	{
		if (movedBack || selectedWeek) return;

		FlxG.sound.play(Paths.sound('cancelMenu'));
		movedBack = true;
		inputCooldown = INPUT_COOLDOWN;
		lockActionButtons();
		MusicBeatState.switchState(new MainMenuState());
	}

	function onReplayPressed():Void
	{
		if (!canOpenWeekReplay()) return;

		persistentUpdate = false;
		inputCooldown = INPUT_COOLDOWN;
		lockActionButtons();
		openSubState(new WeekReplaySubState(loadedWeeks[curWeek], PlayState.storyWeek, curDifficulty));
	}

	function canOpenWeekReplay():Bool
	{
		if (loadedWeeks.length == 0) return false;
		if (weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return false;
		}
		return true;
	}

	function onChangersPressed():Void
	{
		persistentUpdate = false;
		inputCooldown = INPUT_COOLDOWN;
		lockActionButtons();
		openSubState(new GameplayChangersSubstate());
	}

	override function closeSubState() {
		persistentUpdate = true;
		inputCooldown = INPUT_COOLDOWN;
		// 子状态期间父状态不 update，松手事件会丢；不清掉的话 MouseMove 的待拖拽状态
		// 会一直挂着，恢复后的第一帧就会误判成"开始拖拽"，把刚设置好的吸附 lerp 取消掉。
		pressActive = false;
		pressedWeek = -1;
		if (weekScroller != null) weekScroller.resetInputState();
		changeWeek();
		super.closeSubState();
	}

	// ---------------------------------------------------------
	// update
	// ---------------------------------------------------------
	override function update(elapsed:Float)
	{
		starsBG.x -= 0.05;
        starsFG.x -= 0.15;

        if (starsBG.x < -starsBG.width) starsBG.x = 0;
        if (starsFG.x < -starsFG.width) starsFG.x = 0;

		if(WeekData.weeksList.length < 1 || loadedWeeks.length < 1)
		{
			if ((controls.BACK || FlxG.mouse.justPressedRight) && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(new MainMenuState());
			}
			super.update(elapsed);
			return;
		}

		if (inputCooldown > 0) inputCooldown -= elapsed;
		if (wheelCooldown > 0) wheelCooldown -= elapsed;

		if(intendedScore != lerpScore)
		{
			lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 30)));
			if(Math.abs(intendedScore - lerpScore) < 10) lerpScore = intendedScore;

			scoreText.text = formatStatsLine();
		}

		updateScroll(elapsed);

		if (!movedBack && !selectedWeek)
		{
			updateHover();

			var canInput:Bool = inputCooldown <= 0;

			// 多个斜切块是叠着的：后画的在上层，命中裁决取"最后一个命中的"
			var hoverIdx:Int = -1;
			for (i in 0...actionButtons.length)
			{
				var b = actionButtons[i];
				if (b.enabled && b.containsPoint(FlxG.mouse.x, FlxG.mouse.y)) hoverIdx = i;
			}

			for (i in 0...actionButtons.length)
				actionButtons[i].updateButton(i == hoverIdx, canInput);

			var pointerOverButton:Bool = hoverIdx >= 0;

			handleWeekPointer(canInput, pointerOverButton);
			handleArrowClicks(canInput, pointerOverButton);
			handleWheel(canInput, pointerOverButton);
			handleKeyboard(elapsed);
			handleHotkeys();
		}
		else
		{
			lockActionButtons();
			// 切换 / 返回过程中不再接受新的拖拽；惯性让它自然滑完
			// （跟随逻辑已在 onWeekScrollChange 里短路，不会中途换选中周）
			if (weekScroller != null) weekScroller.inputAllow = false;
		}

		if ((controls.BACK || FlxG.mouse.justPressedRight) && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			lockActionButtons();
			MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);
	}

	// ---------------------------------------------------------
	// 滚动（手感对齐 Credits：MouseMove 组件 + 惯性滑行 + 弹簧越界）
	// ---------------------------------------------------------
	function applyScrollPositions():Void
	{
		for (i in 0...grpWeekText.length)
		{
			var item = grpWeekText.members[i];
			item.y = item.targetY - scrollPos + LIST_BASE_Y;
		}

		for (lock in grpLocks.members)
		{
			var idx:Int = lock.ID;
			if (idx < 0 || idx >= grpWeekText.length) continue;
			lock.y = grpWeekText.members[idx].y + grpWeekText.members[idx].height / 2 - lock.height / 2;
		}
	}

	function setupWeekScroller():Void
	{
		var minY:Float = grpWeekText.members[0].targetY;
		var maxY:Float = grpWeekText.members[grpWeekText.length - 1].targetY;
		weekScroller = new MouseMove(this, 'scrollPos', [minY, maxY], [[0, FlxG.width], [0, FlxG.height]], onWeekScrollChange);
		weekScroller.useLerp = true;
		weekScroller.lerpSmooth = 12;
		weekScroller.dragSensitivity = 1.6;
		weekScroller.deceleration = 0.94;

		// 滚轮只由 handleWheel 消费，否则一次滚轮会滚两格
		weekScroller.enableMouseWheel = false;
		// 只认"位移"起拖：按住不动不该变成拖拽，否则单击永远选不了周
		weekScroller.dragStartDelayMs = 1000000;
		weekScroller.dragStartDistance = 8;

		add(weekScroller);
	}

	function updateScroll(elapsed:Float):Void
	{
		if (grpWeekText.length == 0) return;

		// 位置应用挪进了 onWeekScrollChange（MouseMove 每帧在写入 scrollPos 之后回调，
		// 保证位置永远基于最新滚动值）。这里只兜底 scroller 缺位的情况。
		if (weekScroller == null) applyScrollPositions();
	}

	function nearestWeekTo(pos:Float):Int
	{
		var best:Int = curWeek;
		var bestDist:Float = 1e12;
		for (i in 0...grpWeekText.length)
		{
			var d:Float = Math.abs(grpWeekText.members[i].targetY - pos);
			if (d < bestDist)
			{
				bestDist = d;
				best = i;
			}
		}
		return best;
	}

	/** MouseMove 的每帧回调：调用时 scrollPos 已被写入最新滚动值。 */
	function onWeekScrollChange():Void
	{
		if (grpWeekText.length == 0) return;
		applyScrollPositions();

		if (weekScroller == null || movedBack || selectedWeek) return;

		// 只跟随"用户拖动 / 拖拽惯性"；程序化滚动（键盘、滚轮）不参与，否则会中途扫过一堆周
		var driven:Bool = weekScroller.isDragging || Math.abs(weekScroller.velocity) > 0.01;
		if (driven)
		{
			scrollDriven = true;
			var nearest:Int = nearestWeekTo(scrollPos);
			if (nearest != curWeek)
			{
				curWeek = nearest;
				changeWeek(0, false);
			}
		}
		else if (scrollDriven)
		{
			// 惯性耗尽 → 吸附到最近的周
			scrollDriven = false;
			var nearest:Int = nearestWeekTo(scrollPos);
			weekScroller.tweenData = grpWeekText.members[nearest].targetY;
			if (nearest != curWeek)
			{
				curWeek = nearest;
				changeWeek(0, false);
			}
		}
	}

	// ---------------------------------------------------------
	// 鼠标 / 键盘
	// ---------------------------------------------------------
	function updateHover():Void
	{
		// 按压期间冻结悬停：不能往下继续算，否则 newOver 会被算成 -1 并覆盖 mouseOverWeek，
		// 松手时 `mouseOverWeek == pressedWeek` 就永远不成立 → 单击选周 / 单击进周全部失效。
		if (pressActive) return;

		var mouse = FlxG.mouse;
		var newOver:Int = -1;

		{
			var minDist:Float = 1e12;
			for (i in 0...grpWeekText.length)
			{
				var weekItem:MenuItem = grpWeekText.members[i];
				if (mouse.overlaps(weekItem))
				{
					var mid = weekItem.getGraphicMidpoint();
					var distance:Float = Math.sqrt(Math.pow(mid.x - mouse.x, 2) + Math.pow(mid.y - mouse.y, 2));
					if (distance < minDist)
					{
						minDist = distance;
						newOver = i;
					}
				}
			}
		}

		var newLeft:Bool = mouse.overlaps(leftArrow);
		var newRight:Bool = mouse.overlaps(rightArrow);

		if (newOver != lastHoverWeek || newLeft != lastHoverLeft || newRight != lastHoverRight)
		{
			lastHoverWeek = newOver;
			lastHoverLeft = newLeft;
			lastHoverRight = newRight;
			mouseOverWeek = newOver;
			mouseOverLeftArrow = newLeft;
			mouseOverRightArrow = newRight;
			updateMouseHover();
		}
	}

	function handleWeekPointer(canInput:Bool, pointerOverButton:Bool):Void
	{
		var mouse = FlxG.mouse;

		// 兜底：按下后状态被冻结（开子状态 / 切状态），松手事件丢了 → 这里把残留的按压状态清掉
		if (pressActive && !mouse.pressed && !mouse.justReleased)
		{
			pressActive = false;
			pressedWeek = -1;
		}

		// 起拖裁决交给 MouseMove，这里只负责给它开门/关门：
		// 按在按钮 / 箭头上不许起拖；已经拖起来的就让它拖完，别半路掐断。
		if (weekScroller != null)
			weekScroller.inputAllow = weekScroller.isDragging
				|| (canInput && !pointerOverButton && !mouseOverLeftArrow && !mouseOverRightArrow);

		if (mouse.justPressed && canInput && !pointerOverButton && !mouseOverLeftArrow && !mouseOverRightArrow)
		{
			pressActive = true;
			pressY = mouse.y;
			pressedWeek = mouseOverWeek;
		}

		if (mouse.justReleased && pressActive)
		{
			// 是否算拖拽：MouseMove 已起拖，或按压期间纵向位移超出手势阈值
			var dragged:Bool = (weekScroller != null && weekScroller.isDragging)
				|| Math.abs(mouse.y - pressY) >= CLICK_SLOP;

			if (!dragged && canInput && pressedWeek != -1 && mouseOverWeek == pressedWeek)
			{
				if (curWeek != pressedWeek)
				{
					curWeek = pressedWeek;
					changeWeek();
					inputCooldown = Math.max(inputCooldown, INPUT_COOLDOWN);
				}
				else
				{
					selectWeek();
				}
			}
			else if (dragged)
			{
				// 拖完松手不要立刻被当成点击
				inputCooldown = Math.max(inputCooldown, INPUT_COOLDOWN * 0.6);
			}

			pressActive = false;
			pressedWeek = -1;
		}
	}

	function handleArrowClicks(canInput:Bool, pointerOverButton:Bool):Void
	{
		var mouse = FlxG.mouse;
		if (!canInput || pointerOverButton || !mouse.justPressed) return;

		// 现算命中：changeDifficulty 会把 hover 缓存清掉，不能依赖 mouseOverXxx
		if (mouse.overlaps(leftArrow))
		{
			leftArrow.animation.play('press');
			changeDifficulty(-1);
			inputCooldown = Math.max(inputCooldown, 0.08);
		}
		else if (mouse.overlaps(rightArrow))
		{
			rightArrow.animation.play('press');
			changeDifficulty(1);
			inputCooldown = Math.max(inputCooldown, 0.08);
		}
	}

	function handleWheel(canInput:Bool, pointerOverButton:Bool):Void
	{
		if (!canInput || pointerOverButton) return;
		if (FlxG.mouse.wheel == 0 || wheelCooldown > 0) return;

		wheelCooldown = 0.06;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		changeWeek(-FlxG.mouse.wheel);
	}

	function handleKeyboard(elapsed:Float):Void
	{
		if (FlxG.keys.pressed.SHIFT)
			shiftMult = 3;
		else
			shiftMult = 1;

		if (controls.UI_UP_P)
		{
			changeWeek(-1);
			FlxG.sound.play(Paths.sound('scrollMenu'));
			holdTime = 0;
		}

		if (controls.UI_DOWN_P)
		{
			changeWeek(1);
			FlxG.sound.play(Paths.sound('scrollMenu'));
			holdTime = 0;
		}

		if(controls.UI_DOWN || controls.UI_UP)
		{
			var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
			holdTime += elapsed;
			var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);
			if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
				changeWeek((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
		}

		if (controls.UI_RIGHT)
			rightArrow.animation.play('press')
		else if (!mouseOverRightArrow)
			rightArrow.animation.play('idle');

		if (controls.UI_LEFT)
			leftArrow.animation.play('press');
		else if (!mouseOverLeftArrow)
			leftArrow.animation.play('idle');

		if (controls.UI_RIGHT_P)
			changeDifficulty(1);
		else if (controls.UI_LEFT_P)
			changeDifficulty(-1);
	}

	function handleHotkeys():Void
	{
		if(FlxG.keys.justPressed.CONTROL)
		{
			onChangersPressed();
		}
		else if(controls.RESET)
		{
			persistentUpdate = false;
			inputCooldown = INPUT_COOLDOWN;
			lockActionButtons();
			// 第 4 参是 weeksList 下标（ResetScoreSubState 内部按 WeekData.weeksList[week] 取），
			// 不能传 curWeek（loadedWeeks 下标）；modFolder 也要带上，否则 mod 周分数清不掉。
			openSubState(new ResetScoreSubState('', curDifficulty, '', PlayState.storyWeek, loadedWeeks[curWeek].folder));
		}
		else if (FlxG.mouse.justPressedMiddle)
		{
			onChangersPressed();
		}
		else if (controls.ACCEPT)
			selectWeek();
	}

	function updateMouseHover()
	{
		var unlocked:Bool = !weekIsLocked(loadedWeeks[curWeek].fileName);

		for (num => item in grpWeekText.members)
		{
			if (num == curWeek && unlocked)
			{
				item.alpha = 1;
				item.isFlashing = false;
			}
			else if (mouseOverWeek == num)
			{
				item.alpha = 0.8;
				item.isFlashing = false;
			}
			else
			{
				item.alpha = 0.6;
				item.isFlashing = false;
			}
		}

		// 更新箭头动画
		if (!mouseOverLeftArrow && leftArrow.animation.name != 'press')
			leftArrow.animation.play('idle');
		if (!mouseOverRightArrow && rightArrow.animation.name != 'press')
			rightArrow.animation.play('idle');
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		if (loadedWeeks.length == 0) return;

		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			// Nevermind that's stupid lmao
			try
			{
				PlayState.storyPlaylist = songArray;
				PlayState.isStoryMode = true;
				selectedWeek = true;

				var diffic = Difficulty.getFilePath(curDifficulty);
				if(diffic == null) diffic = '';

				PlayState.storyDifficulty = curDifficulty;

				// 周目身份快照：结算时只认这里，不再靠 storyWeek / weeksList 下标反推
				PlayState.resetCampaignStats();
				PlayState.campaignWeekFile = loadedWeeks[curWeek].fileName;
				PlayState.campaignModFolder = loadedWeeks[curWeek].folder;
				PlayState.campaignVariant = loadedWeeks[curWeek].variant;
				PlayState.campaignSongCount = songArray.length;

				WeekData.applyContentRoot(loadedWeeks[curWeek]);
				Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
			}
			catch(e:Dynamic)
			{
				trace('ERROR! $e');
				return;
			}

			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				grpWeekText.members[curWeek].isFlashing = true;
				for (char in grpWeekCharacters.members)
				{
					if (char.character != '' && char.hasConfirmAnimation)
					{
						char.animation.play('confirm');
					}
				}
				stopspamming = true;
			}

			inputCooldown = INPUT_COOLDOWN;
			lockActionButtons();

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				FlxTransitionableState.skipNextTransOut = true; // 跳过退出渐变，直接进入LoadingState
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
				LoadingState.loadAndSwitchState(new PlayState(), true);
				OldFreeplayState.destroyFreeplayVocals();
			});

			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function changeDifficulty(change:Int = 0):Void
	{
		if (Difficulty.list.length == 0) return;

		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = Difficulty.list.length-1;
		if (curDifficulty >= Difficulty.list.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		var diff:String = Difficulty.getString(curDifficulty, false);
		var newImage:FlxGraphic = Paths.image('menudifficulties/' + Paths.formatToSongPath(diff));

		if(sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);
			sprDifficulty.x = leftArrow.x + 60;
			sprDifficulty.x += (308 - sprDifficulty.width) / 3;
			sprDifficulty.alpha = 0;
			sprDifficulty.y = leftArrow.y - sprDifficulty.height + 50;

			FlxTween.cancelTweensOf(sprDifficulty);
			FlxTween.tween(sprDifficulty, {y: sprDifficulty.y + 30, alpha: 1}, 0.07);
		}
		lastDifficultyName = diff;

		refreshWeekStats();

		// 重置鼠标悬停状态（连 lastHover 一起清，否则 updateHover 的变化检测会认为"没变"，
		// 箭头永远不再亮起来）
		mouseOverLeftArrow = false;
		mouseOverRightArrow = false;
		lastHoverLeft = false;
		lastHoverRight = false;
	}

	var lerpScore:Int = 49324858;
	var intendedScore:Int = 0;
	var intendedAcc:Float = 0;
	var intendedFC:String = '';

	/** 读当前周 + 当前难度的三条战绩。全部走只读 peek，不会往存档灌 0 键。 */
	function refreshWeekStats():Void
	{
		if (loadedWeeks.length == 0) return;

		var w:WeekData = loadedWeeks[curWeek];
		var diffName:String = (curDifficulty >= 0 && curDifficulty < Difficulty.list.length)
			? Difficulty.list[curDifficulty] : Difficulty.getDefault();

		intendedScore = Highscore.peekWeekScore(w.fileName, diffName, w.folder, w.variant);
		intendedAcc = Highscore.peekWeekRating(w.fileName, diffName, w.folder, w.variant) * 100;
		intendedFC = Highscore.peekWeekRatingFC(w.fileName, diffName, w.folder, w.variant);

		if (scoreText != null)
			scoreText.text = formatStatsLine();
	}

	/** 一行装下三项：`Score: 12345 98.72% [SFC]` */
	function formatStatsLine():String
	{
		var fc:String = (intendedFC.length > 0) ? intendedFC : '--';
		return 'Score: ' + lerpScore + ' ' + formatAccuracy(intendedAcc) + '% [' + fc + ']';
	}

	/** 固定两位小数（floorDecimal 会把 98.70 显示成 98.7）。 */
	static function formatAccuracy(v:Float):String
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

	function changeWeek(change:Int = 0, moveScroller:Bool = true):Void
	{
		if (loadedWeeks.length == 0) return;

		curWeek += change;

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);
		WeekData.applyContentRoot(leWeek);

		// weeksList 与 loadedWeeks 是两套下标（后者会跳过 hiddenUntilUnlocked 的周），
		// PlayState 那边要靠 weeksList 下标拿周名，这里必须换算。
		var weekIdx:Int = WeekData.weeksList.indexOf(leWeek.fileName);
		PlayState.storyWeek = (weekIdx >= 0) ? weekIdx : curWeek;

		var leName:String = Language.getPhrase('storyname_${leWeek.fileName}', leWeek.storyName);
		txtWeekTitle.text = leName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (num => item in grpWeekText.members)
		{
			item.alpha = 0.6;
			if (num - curWeek == 0 && unlocked)
				item.alpha = 1;
		}

		bgSprite.visible = true;
		var assetName:String = leWeek.weekBackground;
		if(assetName == null || assetName.length < 1) {
			bgSprite.visible = false;
		} else {
			bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
		}

		Difficulty.loadFromWeek();
		difficultySelectors.visible = unlocked;

		// 换周后沿用上次的难度名；这一周没有该难度就回默认
		if (Difficulty.list.contains(lastDifficultyName))
			curDifficulty = Difficulty.list.indexOf(lastDifficultyName);
		else if (Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Difficulty.list.indexOf(Difficulty.getDefault());
		else
			curDifficulty = 0;

		updateText();
		changeDifficulty(0);

		// 重置鼠标悬停状态
		mouseOverWeek = -1;
		lastHoverWeek = -1;
		updateMouseHover();

		// 周锁定状态影响 Replay 是否可点
		if (replayButton != null)
			replayButton.enabled = unlocked;

		// 程序化换周（键盘 / 滚轮 / 点击别的周）让滚动器平滑滚到新选中项；
		// 拖拽跟随路径传 false，避免和用户的手打架。
		if (moveScroller && weekScroller != null && grpWeekText.length > 0)
		{
			scrollDriven = false;
			weekScroller.tweenData = grpWeekText.members[curWeek].targetY;
			// 清掉残留惯性，别跟吸附 lerp 打架（键盘 / 滚轮换周要干脆）
			if (!weekScroller.isDragging && Math.abs(weekScroller.velocity) > 0)
				weekScroller.resetInputState();
		}
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		if (leWeek == null) return true;
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
	{
		var weekArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekArray[i]);
		}

		var leWeek:WeekData = loadedWeeks[curWeek];
		var stringThing:Array<String> = [];
		for (i in 0...leWeek.songs.length) {
			stringThing.push(leWeek.songs[i][0]);
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;
	}
}
