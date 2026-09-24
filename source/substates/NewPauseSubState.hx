package substates;

import backend.Highscore;
import backend.Song;

import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxPoint;

import states.StoryMenuState;
import states.OldFreeplayState;
import states.FreeplayState;
import options.psychoptions.PsychOptionsState;
import options.keoptions.KEOptionsMenu;

/**
 * Win8 Charm 风格的暂停菜单（右侧图标栏 + 左下角歌曲信息面板 + 难度子页）。
 *
 * 由 PlayState.pause() 在 `ClientPrefs.data.charmPause` 打开时使用，否则走原版
 * PauseSubState。
 *
 * 'Tool' 图标的调试面板是独立子状态 `substates.PauseDebugCharm`，本类只负责
 * openSubState() 和接收它的回传。
 *
 * 类名被 HScript 导出，不要重命名。
 */
class NewPauseSubState extends MusicBeatSubstate
{
	// ========== Windows 8.1 Charm风格核心变量 ==========
	var sidebar:FlxSprite;
	var infoPanelBg:FlxSprite;
	var menuIcons:Map<String, FlxSprite> = [];
	var iconBgs:Map<String, FlxSprite> = [];
	
	// ========== UI信息面板元素 ==========
	var levelInfo:FlxText;
	var levelDifficulty:FlxText;
	var blueballedTxt:FlxText;
	var practiceText:FlxText;
	var chartingText:FlxText;
	var bg:FlxSprite;
	var backdrop:FlxBackdrop;
	
	// ========== 菜单控制 ==========
	var menuItems:Array<String> = [];
	var curSelected:Int = 0;
	var pauseMusic:FlxSound;
	var isAnimating:Bool = true;
	var cantUnpause:Float = 0.1;
	var closing:Bool = false;        // 关闭动画进行中（isAnimating 分不清开场还是关闭）
	var doubleEnterTimer:Float = 0;  // > 0 表示已按过一次 accept 键、正在等第二次
	
	// ========== 难度选择 ==========
	var difficultyChoices:Array<String> = [];
	var difficultyTexts:Map<String, FlxText> = [];
	var difficultyBgs:Map<String, FlxSprite> = [];
	var inDifficultyMode:Bool = false;
	var difficultyBg:FlxSprite;
	
	var timeNotMoving:Float = 0;
	var mouseOverItem:Int = -1;
	var lastMousePos:FlxPoint;
	
	// 点击判定区域偏移量（与旧版一致）
	var clickHitboxOffsetX:Float = 0;
	var clickHitboxOffsetY:Float = 0;
	
	// ========== 动画常量 ==========
	static final SIDEBAR_ANIM_TIME:Float = 0.45;
	static final FADE_TIME:Float = 0.35;
	static final ICON_STAGGER:Float = 0.05;
	static final DOUBLE_ENTER_WINDOW:Float = 0.3;

	public static var songName:String = null;

	override function create()
	{
		super.create();
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		
		FlxG.mouse.visible = true;
		lastMousePos = FlxPoint.get();
		
		initMenuItems();
		initDifficultyChoices();
		initPauseMusic();
		createCharmUI();
	}
	
	function initMenuItems()
	{
		menuItems = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];

		if(PlayState.chartingMode || PlayState.instance.practiceMode || PlayState.instance.cpuControlled)
		{
			menuItems.insert(menuItems.length - 1, 'Tool');
		}
	}
	
	function initDifficultyChoices()
	{
		for (i in 0...Difficulty.list.length) {
			var diff:String = Difficulty.getString(i);
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');
	}
	
	function initPauseMusic()
	{
		pauseMusic = new FlxSound();
		try
		{
			var pauseSong:String = getPauseSong();
			if(pauseSong != null) 
				pauseMusic.load(Paths.music(pauseSong), true);
		}
		catch(e:Dynamic) {}
		
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);
	}
	
	function createCharmUI()
	{
		createBackground();
		createSidebar();
		createInfoPanel();
		createMenuIcons();
		startCharmAnimations();
	}
	
	function createBackground()
	{
		if(ClientPrefs.data.coolBackdrop)
		{
			backdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
			backdrop.velocity.set(40, 40);
			backdrop.alpha = 0;
			backdrop.scrollFactor.set();
			add(backdrop);
		}
		
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);
	}
	
	function createSidebar()
	{
		sidebar = new FlxSprite(FlxG.width).makeGraphic(75, FlxG.height, FlxColor.BLACK);
		sidebar.alpha = 0;
		sidebar.scrollFactor.set();
		add(sidebar);
	}
	
	function createInfoPanel()
	{
		var panelY:Float = FlxG.height - 220;
		infoPanelBg = new FlxSprite(50, panelY).makeGraphic(350, 180, FlxColor.BLACK);
		infoPanelBg.alpha = 0;
		infoPanelBg.scrollFactor.set();
		add(infoPanelBg);
		
		var panelX:Float = 50;
		var textY:Float = panelY + 20;
		
		levelInfo = createText(panelX + 20, textY, 310, PlayState.SONG.song, 28, FlxColor.WHITE);
		levelDifficulty = createText(panelX + 20, textY + 40, 310, Difficulty.getString().toUpperCase(), 22, FlxColor.CYAN);
		blueballedTxt = createText(panelX + 20, textY + 70, 310, Language.getPhrase("blueballed", "Blueballed: {1}", [PlayState.deathCounter]), 20, FlxColor.WHITE);
		
		practiceText = createText(panelX + 20, textY + 100, 310, Language.getPhrase("Practice Mode", "Practice Mode").toUpperCase(), 18, FlxColor.YELLOW);
		practiceText.visible = PlayState.instance.practiceMode;
		
		chartingText = createText(panelX + 20, textY + 130, 310, Language.getPhrase("Charting Mode", "Charting Mode").toUpperCase(), 18, FlxColor.RED);
		chartingText.visible = PlayState.chartingMode;
	}
	
	function createText(x:Float, y:Float, width:Float, text:String, size:Int, color:FlxColor):FlxText
	{
		var txt = new FlxText(x, y, width, text, size);
		txt.antialiasing = ClientPrefs.data.antialiasing;
		txt.setFormat(Paths.font("vcr.ttf"), size, color, LEFT);
		txt.scrollFactor.set();
		txt.alpha = 0;
		add(txt);
		return txt;
	}
	
	function createMenuIcons()
	{
		var iconSize:Int = 75;
		var startY:Float = (FlxG.height - (menuItems.length * iconSize)) / 2;
		
		for (i in 0...menuItems.length)
		{
			var itemName = menuItems[i];
			var yPos = startY + (i * iconSize);
			
			var iconBg = createIconBg(yPos);
			iconBgs.set(itemName, iconBg);
			
			var icon = createIcon(itemName, yPos, iconSize);
			menuIcons.set(itemName, icon);
		}
	}
	
	function createIconBg(yPos:Float):FlxSprite
	{
		var iconBg = new FlxSprite(FlxG.width + 75, yPos);
		iconBg.makeGraphic(75, 75, 0x00FFFFFF);
		iconBg.scrollFactor.set();
		add(iconBg);
		return iconBg;
	}
	
	function createIcon(itemName:String, yPos:Float, iconSize:Int):FlxSprite
	{
		var icon = new FlxSprite(FlxG.width + 75, yPos);
		
		try
		{
			icon.loadGraphic(Paths.image('pausemenu/' + getIconName(itemName)));
			var scale = iconSize / Math.max(icon.width, icon.height);
			icon.scale.set(scale, scale);
		}
		catch(e:Dynamic)
		{
			icon.makeGraphic(iconSize, iconSize, 0xFFCCCCCC);
		}
		
		icon.updateHitbox();
		icon.scrollFactor.set();
		icon.antialiasing = ClientPrefs.data.antialiasing;
		icon.x = FlxG.width + 75 + (iconSize - icon.width) / 2;
		icon.y = yPos + (iconSize - icon.height) / 2;
		add(icon);
		
		return icon;
	}
	
	function startCharmAnimations()
	{
		if(ClientPrefs.data.pauseSkipFadeIn)
		{
			finishIntroInstantly();
			return;
		}
		
		FlxTween.tween(bg, {alpha: 0.6}, FADE_TIME, {ease: FlxEase.quadOut});
		if(backdrop != null) 
			FlxTween.tween(backdrop, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		
		safeTween(sidebar, {x: FlxG.width - 75, alpha: 0.9}, SIDEBAR_ANIM_TIME,
		{
			ease: FlxEase.quartOut,
			onComplete: function(twn:FlxTween) {
				startInfoAnimations();
			}
		});
		
		startIconAnimations();
	}
	
	function startIconAnimations()
	{
		for (i in 0...menuItems.length)
		{
			var itemName = menuItems[i];
			var icon = menuIcons.get(itemName);
			var iconBg = iconBgs.get(itemName);
			var delay:Float = i * ICON_STAGGER;
			
			if(iconBg != null)
			{
				safeTween(iconBg, {x: FlxG.width - 75}, SIDEBAR_ANIM_TIME, 
				{
					ease: FlxEase.quartOut,
					startDelay: delay
				});
			}
			
			if(icon != null)
			{
				var targetX:Float = FlxG.width - 75 + (75 - icon.width) / 2;
				
				if(Math.isFinite(targetX))
				{
					safeTween(icon, {x: targetX}, SIDEBAR_ANIM_TIME, 
					{
						ease: FlxEase.quartOut,
						startDelay: delay,
						onComplete: function(twn:FlxTween) {
							checkAnimationComplete(i);
						}
					});
				}
			}
		}
	}
	
	function checkAnimationComplete(i:Int)
	{
		if(i == menuItems.length - 1)
		{
			isAnimating = false;
			updateSelectionVisual();
		}
	}

	/**
	 * 收掉暂停菜单所有元素的补间。
	 * 瞬时跳终值 / 直接 close() 之前必须先做 —— 否则补间会继续往已销毁的 sprite 上写属性。
	 */
	function cancelAllTweens():Void
	{
		var targets:Array<FlxSprite> = [bg, backdrop, sidebar, infoPanelBg, levelInfo,
			levelDifficulty, blueballedTxt, practiceText, chartingText, difficultyBg];
		for(t in targets) if(t != null) FlxTween.cancelTweensOf(t);
		
		for(itemName in menuItems)
		{
			var icon = menuIcons.get(itemName);
			var iconBg = iconBgs.get(itemName);
			if(icon != null) FlxTween.cancelTweensOf(icon);
			if(iconBg != null) FlxTween.cancelTweensOf(iconBg);
		}
		
		for(diffName in difficultyChoices)
		{
			var diffText = difficultyTexts.get(diffName);
			var textBg = difficultyBgs.get(diffName);
			if(diffText != null) FlxTween.cancelTweensOf(diffText);
			if(textBg != null) FlxTween.cancelTweensOf(textBg);
		}
	}

	/** 把开场动画直接跳到终值（跳过 fadein、以及动画期间要操作时用） */
	function finishIntroInstantly():Void
	{
		cancelAllTweens();
		
		bg.alpha = 0.6;
		if(backdrop != null) backdrop.alpha = 1;
		sidebar.x = FlxG.width - 75;
		sidebar.alpha = 0.9;
		
		for(itemName in menuItems)
		{
			var icon = menuIcons.get(itemName);
			var iconBg = iconBgs.get(itemName);
			if(iconBg != null)
			{
				iconBg.x = FlxG.width - 75;
				iconBg.alpha = 1;
			}
			if(icon != null)
			{
				var targetX:Float = FlxG.width - 75 + (75 - icon.width) / 2;
				if(Math.isFinite(targetX)) icon.x = targetX;
				icon.alpha = 1;
			}
		}
		
		// sidebar 的补间被收掉了，它的 onComplete 里那个 startInfoAnimations() 不会跑，
		// 所以信息面板这几个 alpha 必须在这里手动补上
		infoPanelBg.alpha = 0.9;
		levelInfo.alpha = 1;
		levelDifficulty.alpha = 1;
		blueballedTxt.alpha = 1;
		if(practiceText.visible) practiceText.alpha = 1;
		if(chartingText.visible) chartingText.alpha = 1;
		
		isAnimating = false;
		cantUnpause = 0;
		updateSelectionVisual();
	}

	/** 直接关掉菜单（跳过 fadeout、双击 Enter 用） */
	function finishCloseInstantly():Void
	{
		cancelAllTweens();
		FlxG.mouse.visible = true;
		close();
	}

	/** 开场动画期间是否有"用户主动输入"（只看按下，不看鼠标移动，避免误触发） */
	function hasAnyInput():Bool
	{
		return FlxG.keys.justPressed.ANY || FlxG.mouse.justPressed
			|| FlxG.mouse.justPressedRight || FlxG.mouse.wheel != 0;
	}
	
	function startInfoAnimations()
	{
		FlxTween.tween(infoPanelBg, {alpha: 0.9}, FADE_TIME, {ease: FlxEase.quadOut});
		
		var elements = [levelInfo, levelDifficulty, blueballedTxt];
		if(practiceText.visible) elements.push(practiceText);
		if(chartingText.visible) elements.push(chartingText);
		
		for (i in 0...elements.length)
		{
			FlxTween.tween(elements[i], {alpha: 1}, FADE_TIME,
			{
				ease: FlxEase.quadOut,
				startDelay: i * 0.05
			});
		}
	}
	
	// ========== 鼠标悬停检测 ==========
	function updateMouseOver()
	{
		var newMouseOver:Int = -1;
		
		if (inDifficultyMode)
		{
			for (i in 0...difficultyChoices.length)
			{
				var textBg = difficultyBgs.get(difficultyChoices[i]);
				if (textBg != null && FlxG.mouse.overlaps(textBg, cameras[0]))
				{
					newMouseOver = i;
					break;
				}
			}
		}
		else
		{
			for (i in 0...menuItems.length)
			{
				var icon = menuIcons.get(menuItems[i]);
				if (icon != null && icon.visible)
				{
					var originalX:Float = icon.x;
					var originalY:Float = icon.y;
					icon.x += clickHitboxOffsetX;
					icon.y += clickHitboxOffsetY;
					var overlaps:Bool = FlxG.mouse.overlaps(icon, cameras[0]);
					icon.x = originalX;
					icon.y = originalY;
					
					if (overlaps)
					{
						newMouseOver = i;
						break;
					}
				}
			}
		}
		
		if (newMouseOver != mouseOverItem)
		{
			mouseOverItem = newMouseOver;
			updateSelectionVisual();
		}
	}
	
	// ========== 鼠标点击处理 ==========
	function handleMouseClick()
	{
		if (mouseOverItem == -1) return;
		
		if (inDifficultyMode)
		{
			if (mouseOverItem != curSelected)
			{
				changeDifficultySelection(mouseOverItem - curSelected);
			}
			else
			{
				executeDifficultyAction();
			}
		}
		else
		{
			if (mouseOverItem != curSelected)
			{
				changeSelection(mouseOverItem - curSelected);
			}
			else
			{
				executeMenuItem();
			}
		}
	}
	
	// ========== 更新选择视觉 ==========
	function updateSelectionVisual()
	{
		if (inDifficultyMode)
		{
			for(i in 0...difficultyChoices.length)
			{
				var diffName = difficultyChoices[i];
				var textBg = difficultyBgs.get(diffName);
				var diffText = difficultyTexts.get(diffName);
				
				if(textBg == null || diffText == null) continue;
				
				if(i == curSelected)
				{
					textBg.color = 0x5500FFFF;
					textBg.alpha = 1;
					diffText.color = FlxColor.CYAN;
					diffText.size = 28;
				}
				else if ( i == mouseOverItem)
				{
					textBg.color = 0x33FFFF00;
					textBg.alpha = 0.8;
					diffText.color = 0xFFFFFF00;
					diffText.size = 26;
				}
				else
				{
					textBg.color = 0x00FFFFFF;
					textBg.alpha = 0;
					diffText.color = FlxColor.WHITE;
					diffText.size = 24;
				}
				diffText.updateHitbox();
			}
		}
		else
		{
			for(i in 0...menuItems.length)
			{
				var itemName = menuItems[i];
				var iconBg = iconBgs.get(itemName);
				var icon = menuIcons.get(itemName);
				
				if(iconBg == null || icon == null) continue;
				
				if(i == curSelected)
				{
					iconBg.color = 0x5500FFFF;
					iconBg.alpha = 1;
					icon.color = FlxColor.WHITE;
					icon.alpha = 1.0;
				}
				else if ( i == mouseOverItem)
				{
					iconBg.color = 0x33FFFF00;
					iconBg.alpha = 0.8;
					icon.color = 0xFFFFFF00;
					icon.alpha = 0.9;
				}
				else
				{
					iconBg.color = 0x00FFFFFF;
					iconBg.alpha = 0;
					icon.color = 0xFFAAAAAA;
					icon.alpha = 0.8;
				}
			}
		}
	}
	
	function changeDifficultySelection(change:Int)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, difficultyChoices.length - 1);
		mouseOverItem = curSelected;
		updateDifficultySelection();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function updateDifficultySelection()
	{
		updateSelectionVisual();
	}
	
	function changeSelection(change:Int)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		mouseOverItem = curSelected;
		updateSelectionVisual();
		
		if(change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	// ========== 主更新函数 ==========
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		cantUnpause -= elapsed;
		if(pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;
		
		// 关闭动画期间菜单正在离开，唯一出口是"双击 accept 键瞬时关闭"
		if(closing)
		{
			if(ClientPrefs.data.pauseDoubleEnterSkip && controls.ACCEPT)
			{
				if(doubleEnterTimer > 0)
				{
					finishCloseInstantly();
					return;
				}
				doubleEnterTimer = DOUBLE_ENTER_WINDOW;
			}
			if(doubleEnterTimer > 0) doubleEnterTimer -= elapsed;
			return;
		}
		
		// 开场动画期间：开了开关就先把动画瞬时跳完，再让这一帧的输入照常往下走
		if(isAnimating)
		{
			if(!ClientPrefs.data.pauseUnlockInputDuringAnim || !hasAnyInput()) return;
			finishIntroInstantly();
			updateMouseOver();   // 鼠标点进来的话，让这次点击落到正确的那一项上
		}
		
		if(cantUnpause > 0) return;
		
		// ===== 鼠标控制 ======
		if (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0)
		{
			timeNotMoving = 0;
			updateMouseOver();
		}
		else
		{
			timeNotMoving += elapsed;
			if (timeNotMoving > 3)
			{
				updateMouseOver();
			}
		}
		
		// 右键返回
		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			closeMenu();
			return;
		}
		
		// ===== 滚轮选择 =====
		if (FlxG.mouse.wheel != 0)
		{
			if (inDifficultyMode)
			{
				changeDifficultySelection(-Std.int(FlxG.mouse.wheel));
			}
			else
			{
				changeSelection(-Std.int(FlxG.mouse.wheel));
			}
		}
		
		// ===== 左键点击 =====
		if (FlxG.mouse.justPressed)
		{
			handleMouseClick();
		}
		
		// 键盘控制（按下任意键时禁用鼠标模式）
		if (FlxG.keys.justPressed.ANY && !FlxG.keys.pressed.LEFT && !FlxG.keys.pressed.RIGHT && 
			!FlxG.keys.pressed.UP && !FlxG.keys.pressed.DOWN)
		{
			mouseOverItem = -1;
			updateSelectionVisual();
		}
		
		// 根据模式处理键盘输入
		if (inDifficultyMode)
		{
			updateDifficultyModeKeyboard();
		}
		else
		{
			updateNormalModeKeyboard();
		}
		
		// TAB：打开 Tool 浮出层。
		// 旧行为是在主菜单和内联 debug 面板之间切换；面板现在是独立子状态，TAB 只负责打开它。
		if (FlxG.keys.justPressed.TAB && !inDifficultyMode && menuItems.contains('Tool'))
			openToolCharm();
	}
	
	// ========== 键盘控制（常规模式） ==========
	function updateNormalModeKeyboard()
	{
		if(controls.UI_UP_P) changeSelection(-1);
		if(controls.UI_DOWN_P) changeSelection(1);
		if(controls.ACCEPT) executeMenuItem();
	}
	
	function updateDifficultyModeKeyboard()
	{
		if(controls.UI_UP_P) changeDifficultySelection(-1);
		if(controls.UI_DOWN_P) changeDifficultySelection(1);
		if(controls.ACCEPT) executeDifficultyAction();
		if(controls.BACK) exitDifficultyMode();
	}
	
	// ========== 菜单执行系统 ==========
	function executeMenuItem()
	{
		var selected = menuItems[curSelected];
		
		switch(selected)
		{
			case "Resume":
				closeMenu();
				
			case 'Change Difficulty':
				createDifficultySelection();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				
			case "Restart Song":
				restartSong();
				
			case 'Options':
				openOptions();
				
			case 'Tool':
				openToolCharm();
				
			case "Exit to menu":
				exitToMenu();
		}
	}
	
	/** 打开 Tool 浮出层（点图标 / TAB 共用）。它是嵌套子状态，关掉后回到本菜单。 */
	function openToolCharm():Void
	{
		if(subState != null) return;
		
		mouseOverItem = -1;
		updateSelectionVisual();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		openSubState(new PauseDebugCharm(this));
	}

	function executeDifficultyAction()
	{
		var selected = difficultyChoices[curSelected];
		
		if(selected == 'BACK')
		{
			exitDifficultyMode();
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}
		
		changeDifficulty(selected);
	}
	
	// ========== 具体功能实现（保持不变） ==========
	function leaveChartingMode()
	{
		PlayState.chartingMode = false;
		restartSong();
	}
	
	function changeDifficulty(diffName:String)
	{
		var diffIndex = difficultyChoices.indexOf(diffName);
		if(diffIndex < 0 || diffIndex >= Difficulty.list.length) return;
		
		var songLowercase = Paths.formatToSongPath(PlayState.SONG.song);
		var poop = Highscore.formatSong(songLowercase, diffIndex);
		
		try
		{
			Song.loadFromJson(poop, songLowercase);
			PlayState.storyDifficulty = diffIndex;
			MusicBeatState.resetState();
			FlxG.sound.music.volume = 0;
			PlayState.changedDifficulty = true;
			PlayState.chartingMode = false;
		}
		catch(e:Dynamic)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		}
	}
	
	public function togglePracticeMode():Void
	{
		setPracticeMode(!PlayState.instance.practiceMode);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	public function toggleBotplay():Void
	{
		setBotplay(!PlayState.instance.cpuControlled);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	/**
	 * 供 substates.PauseDebugCharm 调用。
	 * 浮出层里的开关给出的是"目标值"，所以这里必须是 set 而不是 toggle
	 * （BoolButton 自己已经把当前值取反过了，见 BoolButton.hx:152-153）。
	 */
	public function setPracticeMode(v:Bool):Void
	{
		PlayState.instance.practiceMode = v;
		PlayState.changedDifficulty = true;
		refreshInfoPanel();
	}
	
	public function setBotplay(v:Bool):Void
	{
		PlayState.instance.cpuControlled = v;
		PlayState.changedDifficulty = true;
		if(PlayState.instance.botplayTxt != null)
		{
			PlayState.instance.botplayTxt.visible = v;
			PlayState.instance.botplayTxt.alpha = 1;
			PlayState.instance.botplaySine = 0;
		}
	}
	
	/** 同步左下角信息面板上跟游戏状态相关的那两行 */
	public function refreshInfoPanel():Void
	{
		if(practiceText != null) practiceText.visible = PlayState.instance.practiceMode;
		if(chartingText != null) chartingText.visible = PlayState.chartingMode;
	}
	
	function openOptions()
	{
		PlayState.instance.paused = true;
		PlayState.instance.vocals.volume = 0;
		PlayState.instance.canResync = false;
		
		var optionType:String = ClientPrefs.getOptionType();
		if (optionType == 'new')
		{ 
			MusicBeatState.switchState(new options.OptionsState());
			options.OptionsState.stateType = 2;
		}
		else if(optionType == 'ke')
			MusicBeatState.switchState(new KEOptionsMenu());
		else
			MusicBeatState.switchState(new PsychOptionsState());
		
		if(ClientPrefs.data.pauseMusic != 'None')
		{
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
			FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
			FlxG.sound.music.time = pauseMusic.time;
		}
		
		PsychOptionsState.onPlayState = KEOptionsMenu.onPlayState = true;
	}
	
	public function restartSong(noTrans:Bool = false):Void
	{
		FlxG.sound.play(Paths.sound('confirmMenu'));
		
		if (PlayState.debugRestartTiming) trace('[restart] restartSong enter (NewPauseSubState, noTrans=$noTrans)');
		PlayState.instance.paused = true;
		PlayState.instance.skipResumeOnClose = true;
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;
		
		if(noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		
		MusicBeatState.resetState();
	}
	
	public function endSong():Void
	{
		closeMenu();
		PlayState.instance.notes.clear();
		PlayState.instance.unspawnNotes = [];
		PlayState.instance.finishSong(true);
	}
	
	function exitToMenu()
	{
		FlxG.sound.play(Paths.sound('confirmMenu'));
		
		#if DISCORD_ALLOWED
		DiscordClient.resetClientID();
		#end
		
		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;
		PlayState.instance.canResync = false;
		
		PlayState.inReplay = false;
		PlayState.loadRep = false;
		
		Mods.loadTopMod();
		if(PlayState.isStoryMode)
			MusicBeatState.switchState(new StoryMenuState());
		else if(!ClientPrefs.data.oldFreeplay)
			MusicBeatState.switchState(new FreeplayState());
		else
			MusicBeatState.switchState(new OldFreeplayState());
		
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		PlayState.changedDifficulty = false;
		PlayState.chartingMode = false;
		FlxG.camera.followLerp = 0;
	}
	
	// ========== 难度UI ==========
	function createDifficultySelection()
	{
		inDifficultyMode = true;
		mouseOverItem = -1;
		
		toggleSidebarElements(false);
		
		var panelY:Float = FlxG.height - 220;
		difficultyBg = new FlxSprite(50, panelY).makeGraphic(350, 180, FlxColor.BLACK);
		difficultyBg.alpha = 0;
		difficultyBg.scrollFactor.set();
		add(difficultyBg);
		
		var startY:Float = panelY + 20;
		for(i in 0...difficultyChoices.length)
		{
			var diffName = difficultyChoices[i];
			var yPos = startY + (i * 35);
			
			var textBg = new FlxSprite(70, yPos - 5);
			textBg.makeGraphic(330, 30, 0x00FFFFFF);
			textBg.scrollFactor.set();
			textBg.alpha = 0;
			add(textBg);
			difficultyBgs.set(diffName, textBg);
			
			var diffText = createText(70, yPos, 330, diffName, 24, FlxColor.WHITE);
			diffText.alpha = 0;
			difficultyTexts.set(diffName, diffText);
		}
		
		FlxTween.tween(difficultyBg, {alpha: 0.9}, FADE_TIME, {ease: FlxEase.quadOut});
		for(i in 0...difficultyChoices.length)
		{
			var diffText = difficultyTexts.get(difficultyChoices[i]);
			var textBg = difficultyBgs.get(difficultyChoices[i]);
			if(diffText != null && textBg != null)
			{
				FlxTween.tween(diffText, {alpha: 1}, FADE_TIME,
				{
					ease: FlxEase.quadOut,
					startDelay: i * 0.05
				});
				FlxTween.tween(textBg, {alpha: 1}, FADE_TIME,
				{
					ease: FlxEase.quadOut,
					startDelay: i * 0.05
				});
			}
		}
		
		curSelected = 0;
		updateDifficultySelection();
	}
	
	function exitDifficultyMode()
	{
		inDifficultyMode = false;
		mouseOverItem = -1;
		
		fadeOutDifficultyUI();
		toggleSidebarElements(true);
		
		curSelected = 0;
		updateSelectionVisual();
	}
	
	function toggleSidebarElements(visible:Bool)
	{
		for(itemName in menuItems)
		{
			var icon = menuIcons.get(itemName);
			var iconBg = iconBgs.get(itemName);
			if(icon != null) 
			{
				icon.visible = visible;
				FlxTween.tween(icon, {alpha: visible ? 1 : 0}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			}
			if(iconBg != null) 
			{
				iconBg.visible = visible;
				FlxTween.tween(iconBg, {alpha: visible ? 1 : 0}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			}
		}
	}
	
	function fadeOutDifficultyUI()
	{
		if(difficultyBg != null)
		{
			FlxTween.tween(difficultyBg, {alpha: 0}, FADE_TIME * 0.8, 
			{
				ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween)
				{
					difficultyBg.destroy();
					difficultyBg = null;
				}
			});
		}
		
		for(diffName in difficultyChoices)
		{
			var diffText = difficultyTexts.get(diffName);
			var textBg = difficultyBgs.get(diffName);
			
			if(diffText != null) fadeOutAndDestroy(diffText);
			if(textBg != null) fadeOutAndDestroy(textBg);
		}
		
		difficultyTexts.clear();
		difficultyBgs.clear();
	}
	
	function fadeOutAndDestroy(obj:Dynamic)
	{
		if(obj != null)
		{
			FlxTween.tween(obj, {alpha: 0}, FADE_TIME * 0.8, 
			{
				ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween) {
					if(Std.isOfType(obj, FlxText)) cast(obj, FlxText).destroy();
					else if(Std.isOfType(obj, FlxSprite)) cast(obj, FlxSprite).destroy();
				}
			});
		}
	}
	
	// ========== 关闭动画 ==========
	public function closeMenu():Void
	{
		if(isAnimating) return;
		
		FlxG.sound.play(Paths.sound('cancelMenu'));
		
		if(ClientPrefs.data.pauseSkipFadeOut)
		{
			finishCloseInstantly();
			return;
		}
		
		isAnimating = true;
		closing = true;
		doubleEnterTimer = 0;
		
		fadeOutAll();
		slideOutIcons();
		
		safeTween(sidebar, {x: FlxG.width, alpha: 0}, SIDEBAR_ANIM_TIME, 
		{
			ease: FlxEase.quartIn,
			startDelay: menuItems.length * ICON_STAGGER,
			onComplete: function(twn:FlxTween)
			{
				FlxG.mouse.visible = true;
				close();
			}
		});
	}
	
	function fadeOutAll()
	{
		if(bg != null) FlxTween.tween(bg, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		if(backdrop != null) FlxTween.tween(backdrop, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		
		var infoElements = [infoPanelBg, levelInfo, levelDifficulty, blueballedTxt, practiceText, chartingText];
		for(element in infoElements) if(element != null) fadeOutElement(element);
		
		if(difficultyBg != null) fadeOutElement(difficultyBg);
	}
	
	function fadeOutElement(element:Dynamic)
	{
		FlxTween.tween(element, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
	}

	function safeTween(target:Dynamic, props:Dynamic, time:Float, ?options:Dynamic)
	{
		if(target == null) return;
		var filtered:Dynamic = {};
		for(key in Reflect.fields(props))
		{
			var val = Reflect.field(props, key);
			if(key == 'x' || key == 'y')
			{
				if(!Math.isFinite(cast val)) continue;
				if(Reflect.hasField(target, key))
				{
					var cur = Reflect.field(target, key);
					if(!Math.isFinite(cast cur)) continue;
				}
			}
			Reflect.setField(filtered, key, val);
		}
		if(Reflect.fields(filtered).length == 0) return;
		if(options != null)
			FlxTween.tween(target, filtered, time, options);
		else
			FlxTween.tween(target, filtered, time);
	}
	
	function slideOutIcons()
	{
		for(i in 0...menuItems.length)
		{
			var itemName = menuItems[i];
			var icon = menuIcons.get(itemName);
			var iconBg = iconBgs.get(itemName);
			var delay = (menuItems.length - 1 - i) * ICON_STAGGER;
			
			if(icon != null)
			{
				safeTween(icon, {x: FlxG.width + 75, alpha: 0}, SIDEBAR_ANIM_TIME, 
				{
					ease: FlxEase.quartIn,
					startDelay: delay
				});
			}
			
			if(iconBg != null)
			{
				safeTween(iconBg, {x: FlxG.width + 75, alpha: 0}, SIDEBAR_ANIM_TIME, 
				{
					ease: FlxEase.quartIn,
					startDelay: delay
				});
			}
		}
	}
	
	function getPauseSong()
	{
		var formattedSongName:String = (songName != null ? Paths.formatToSongPath(songName) : '');
		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
		
		if(formattedSongName == 'none' || (formattedSongName != 'none' && formattedPauseMusic == 'none')) 
			return null;
		
		return (formattedSongName != '') ? formattedSongName : formattedPauseMusic;
	}
	
	function getIconName(itemName:String):String
	{
		return switch(itemName)
		{
			case "Resume": "resume";
			case "Restart Song": "restart";
			case "Change Difficulty": "difficulty";
			case 'Tool': 'tool';
			case "Options": "options";
			case "Exit to menu": "exit";
			default: "resume";
		}
	}
	
	override function destroy()
	{
		if(pauseMusic != null)
		{
			pauseMusic.stop();
			pauseMusic.destroy();
		}
		
		if (lastMousePos != null) lastMousePos.put();
		FlxG.mouse.visible = true;
		
		super.destroy();
	}
}
