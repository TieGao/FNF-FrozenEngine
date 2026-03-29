package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.util.FlxStringUtil;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;

import states.StoryMenuState;
import states.OldFreeplayState;
import states.FreeplayState;
import options.OptionsState;
import options.KEOptionsMenu;

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
	
	// ========== Skip Time功能 ==========
	var skipTimeText:FlxText;
	var skipTimeBar:FlxSprite;
	var skipTimeBarFill:FlxSprite;
	var curTime:Float = 0;
	var skipTimeVisible:Bool = false;
	var skipDragging:Bool = false;
	var skipTimeTracker:FlxSprite; // 用于检测悬停的图标引用（Debug面板中的Skip Time选项背景）
	
	// ========== 难度选择 ==========
	var difficultyChoices:Array<String> = [];
	var difficultyTexts:Map<String, FlxText> = [];
	var difficultyBgs:Map<String, FlxSprite> = [];
	var inDifficultyMode:Bool = false;
	var difficultyBg:FlxSprite;
	
	// ========== Charting Mode调试面板 ==========
	var debugPanel:FlxSprite;
	var debugOptions:Array<String> = [];
	var debugTexts:Array<FlxText> = [];
	var debugBgs:Array<FlxSprite> = [];
	var curDebugOption:Int = 0;
	var debugPanelVisible:Bool = false;
	
	// ========== 鼠标控制变量（参考MainMenuState）==========
	var usingDebugPanel:Bool = false;
	var timeNotMoving:Float = 0;
	var mouseOverItem:Int = -1;
	var lastMousePos:FlxPoint;
	
	// 点击判定区域偏移量（与PauseSubState保持一致）
	// 正数向下/向右偏移，负数向上/向左偏移
	var clickHitboxOffsetX:Float = 0;
	var clickHitboxOffsetY:Float = 0;
	
	// ========== 动画常量 ==========
	static final SIDEBAR_ANIM_TIME:Float = 0.45;
	static final FADE_TIME:Float = 0.35;
	static final ICON_STAGGER:Float = 0.05;

	public static var songName:String = null;

	override function create()
	{
		super.create();
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		
		// 初始化鼠标
		FlxG.mouse.visible = true;
		lastMousePos = FlxPoint.get();
		
		initMenuItems();
		initDifficultyChoices();
		initPauseMusic();
		createCharmUI();
		createDebugPanel();
		
		// 初始化curTime
		curTime = Math.max(0, Conductor.songPosition);
		updateSkipTimeVisibility();
		
		usingDebugPanel = debugPanelVisible && debugOptions.length > 0;
	}
	
	function initMenuItems()
	{
		menuItems = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
		
		//if(Difficulty.list.length >= 2) menuItems.insert(menuItems.length - 2,'Change Difficulty');

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
				pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
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
		blueballedTxt = createText(panelX + 20, textY + 70, 310, "Blueballed: " + PlayState.deathCounter, 20, FlxColor.WHITE);
		
		practiceText = createText(panelX + 20, textY + 100, 310, "PRACTICE MODE", 18, FlxColor.YELLOW);
		practiceText.visible = PlayState.instance.practiceMode;
		
		chartingText = createText(panelX + 20, textY + 130, 310, "CHARTING MODE", 18, FlxColor.RED);
		chartingText.visible = PlayState.chartingMode;
	}
	
	function createDebugPanel()
	{
		initDebugOptions();
		
		if(debugOptions.length == 0)
		{
			debugPanelVisible = false;
			return;
		}
		
		var panelWidth:Int = 350;
		var panelHeight:Int = 220;
		var panelX:Float = 50;
		var panelY:Float = FlxG.height - 220 - panelHeight - 40;
		
		debugPanel = new FlxSprite(panelX, panelY).makeGraphic(panelWidth, panelHeight, FlxColor.BLACK);
		debugPanel.alpha = 0;
		debugPanel.scrollFactor.set();
		add(debugPanel);
		
		var optionY:Float = panelY + 20;
		var optionSpacing:Float = 35;
		
		var title = createText(panelX + 20, optionY, panelWidth - 40, "CHARTING PANEL", 22, FlxColor.YELLOW);
		debugTexts.push(title);
		
		for(i in 0...debugOptions.length)
		{
			var yPos = optionY + 40 + (i * optionSpacing);
			
			var optionBg = new FlxSprite(panelX + 15, yPos - 5);
			optionBg.makeGraphic(panelWidth - 30, 30, 0x00FFFFFF);
			optionBg.scrollFactor.set();
			optionBg.alpha = 0;
			add(optionBg);
			debugBgs.push(optionBg);
			
			var optionText = createText(panelX + 30, yPos, panelWidth - 60, debugOptions[i], 20, FlxColor.WHITE);
			optionText.alpha = 0;
			debugTexts.push(optionText);
			
			// 如果是Skip Time选项，保存其背景作为tracker，并创建时间文本
			if(debugOptions[i] == 'Skip Time')
			{
				skipTimeTracker = optionBg;
				createSkipTimeUI();
			}
		}
		
		debugPanelVisible = false;
		debugPanel.visible = false;
		for(text in debugTexts) if(text != null) text.visible = false;
		for(bg in debugBgs) if(bg != null) bg.visible = false;
	}
	
	function createSkipTimeUI()
	{
		skipTimeBar = new FlxSprite(0, 0);
		skipTimeBar.makeGraphic(300, 8, FlxColor.GRAY);
		skipTimeBar.scrollFactor.set();
		skipTimeBar.alpha = 0;
		skipTimeBar.visible = false;
		add(skipTimeBar);
		
		skipTimeBarFill = new FlxSprite(0, 0);
		skipTimeBarFill.makeGraphic(300, 8, FlxColor.CYAN);
		skipTimeBarFill.scrollFactor.set();
		skipTimeBarFill.alpha = 0;
		skipTimeBarFill.visible = false;
		add(skipTimeBarFill);
		
		skipTimeText = new FlxText(0, 0, 0, '', 24);
		skipTimeText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		skipTimeText.scrollFactor.set();
		skipTimeText.borderSize = 2;
		skipTimeText.alpha = 0;
		skipTimeText.visible = false;
		add(skipTimeText);
		
		updateSkipTimeText();
	}
	
	function initDebugOptions()
	{
		if(PlayState.chartingMode)
		{
			debugOptions = ['Skip Time', 'Toggle Practice', 'Toggle Botplay', 'Leave Charting Mode', 'End Song'];
		}
		else if(PlayState.instance.practiceMode || PlayState.instance.cpuControlled)
		{
			debugOptions = ['Skip Time'];
			
			if(PlayState.instance.practiceMode)
			{
				debugOptions = ['Toggle Practice', 'Skip Time'];
			}
			if(PlayState.instance.cpuControlled)
			{
				debugOptions = ['Toggle Botplay', 'Skip Time'];
			}
		}
		else
		{
			debugOptions = [];
		}
	}
	
	function createText(x:Float, y:Float, width:Float, text:String, size:Int, color:FlxColor):FlxText
	{
		var txt = new FlxText(x, y, width, text, size);
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
	
	// ========== 动画系统 ==========
	function startCharmAnimations()
	{
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
	
	// ========== 鼠标悬停检测（参考MainMenuState + PauseSubState）==========
	function updateMouseOver()
	{
		var newMouseOver:Int = -1;
		
		if (inDifficultyMode)
		{
			// 难度选择模式：检测难度选项
			for (i in 0...difficultyChoices.length)
			{
				var textBg = difficultyBgs.get(difficultyChoices[i]);
				if (textBg != null && FlxG.mouse.overlaps(textBg))
				{
					newMouseOver = i;
					break;
				}
			}
		}
		else if (usingDebugPanel && debugPanelVisible)
		{
			// 调试面板模式：检测调试选项（不对文本应用偏移）
			for (i in 0...debugBgs.length)
			{
				var bg = debugBgs[i];
				if (bg != null && FlxG.mouse.overlaps(bg))
				{
					newMouseOver = i;
					break;
				}
			}
		}
		else
		{
			// 正常模式：检测图标（应用偏移量，与PauseSubState一致）
			for (i in 0...menuItems.length)
			{
				var icon = menuIcons.get(menuItems[i]);
				if (icon != null && icon.visible)
				{
					// 应用偏移量检测悬停
					var originalX:Float = icon.x;
					var originalY:Float = icon.y;
					icon.x += clickHitboxOffsetX;
					icon.y += clickHitboxOffsetY;
					var overlaps:Bool = FlxG.mouse.overlaps(icon);
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
		
		// 悬停项改变时更新高亮
		if (newMouseOver != mouseOverItem)
		{
			mouseOverItem = newMouseOver;
			updateSelectionVisual();
		}
	}
	
	// ========== Skip Time拖拽处理 ==========
	function handleSkipTimeDrag(elapsed:Float)
	{
		if (!skipTimeVisible) return;
		
		// 检查是否悬停在Skip Time选项的背景上（Debug面板中）
		var isOverSkipTime:Bool = false;
		var skipTimeIndex:Int = debugOptions.indexOf('Skip Time');
		
		if (usingDebugPanel && debugPanelVisible && skipTimeIndex != -1 && skipTimeIndex < debugBgs.length)
		{
			var skipTimeBg = debugBgs[skipTimeIndex];
			if (skipTimeBg != null && FlxG.mouse.overlaps(skipTimeBg))
			{
				isOverSkipTime = true;
			}
		}
		
		// 检测是否悬停在时间文本或进度条上
		var isOverBar:Bool = skipTimeBar != null && skipTimeBar.visible && FlxG.mouse.overlaps(skipTimeBar);
		var isOverText:Bool = skipTimeText != null && skipTimeText.visible && FlxG.mouse.overlaps(skipTimeText);
		
		// 只有鼠标悬停在Skip Time选项或相关UI上时才处理拖拽
		var shouldHandle:Bool = isOverSkipTime || isOverBar || isOverText;
		
		if (shouldHandle)
		{
			// 鼠标拖动
			if (FlxG.mouse.pressed)
			{
				if (!skipDragging)
				{
					skipDragging = true;
					lastMousePos.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
				}
				
				var deltaX:Float = FlxG.mouse.screenX - lastMousePos.x;
				var deltaY:Float = FlxG.mouse.screenY - lastMousePos.y;
				var dragSpeed:Float = (deltaX + deltaY) * 10;
				
				if (Math.abs(dragSpeed) > 0.5)
				{
					curTime += dragSpeed;
					curTime = Math.max(0, Math.min(FlxG.sound.music.length, curTime));
					updateSkipTimeText();
					updateSkipTimeBarFill();
				}
				
				lastMousePos.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
			}
			else
			{
				skipDragging = false;
			}
			
			// 滚轮微调
			if (FlxG.mouse.wheel != 0)
			{
				curTime += FlxG.mouse.wheel * 1000;
				curTime = Math.max(0, Math.min(FlxG.sound.music.length, curTime));
				updateSkipTimeText();
				updateSkipTimeBarFill();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
		}
		else if (FlxG.mouse.justReleased)
		{
			skipDragging = false;
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
		else if (usingDebugPanel && debugPanelVisible)
		{
			if (mouseOverItem != curDebugOption)
			{
				changeDebugOption(mouseOverItem - curDebugOption);
			}
			else
			{
				executeDebugOption();
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
	
	// ========== 更新选择视觉（增强版，支持悬停高亮）==========
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
		else if (usingDebugPanel && debugPanelVisible)
		{
			for(i in 0...debugOptions.length)
			{
				var text = debugTexts[i + 1];
				if (text == null) continue;
				var bg = debugBgs[i];
				
				if(i == curDebugOption)
				{
					text.color = FlxColor.CYAN;
					text.size = 22;
					if(bg != null) { bg.color = 0x5500FFFF; bg.alpha = 1; }
				}
				else if ( i == mouseOverItem)
				{
					text.color = 0xFFFFFF00;
					text.size = 21;
					if(bg != null) { bg.color = 0x33FFFF00; bg.alpha = 0.8; }
				}
				else
				{
					text.color = FlxColor.WHITE;
					text.size = 20;
					if(bg != null) { bg.color = 0x00FFFFFF; bg.alpha = 0; }
				}
				text.updateHitbox();
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
	
	function changeDebugOption(change:Int)
	{
		curDebugOption = FlxMath.wrap(curDebugOption + change, 0, debugOptions.length - 1);
		mouseOverItem = curDebugOption;
		updateDebugSelection();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function updateDebugSelection()
	{
		updateSelectionVisual();
		// 更新Skip Time显示位置（当选择改变时）
		updateSkipTimePosition();
	}
	
	function changeSelection(change:Int)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		mouseOverItem = curSelected;
		updateSelectionVisual();
		
		if(change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	// ========== 主更新函数（整合鼠标控制）==========
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		cantUnpause -= elapsed;
		if(pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;
		
		updateSkipTimePosition();
		updateSkipTimeBarFill();
		
		if(isAnimating || cantUnpause > 0) return;
		
		// ===== 鼠标控制（参考MainMenuState + PauseSubState）=====
		if (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0)
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
		
		// 滚轮选择
		if (FlxG.mouse.wheel != 0)
		{
			if (inDifficultyMode)
			{
				changeDifficultySelection(-Std.int(FlxG.mouse.wheel));
			}
			else if (usingDebugPanel && debugPanelVisible)
			{
				changeDebugOption(-Std.int(FlxG.mouse.wheel));
			}
			else
			{
				changeSelection(-Std.int(FlxG.mouse.wheel));
			}
		}
		
		// 左键点击
		if (FlxG.mouse.justPressed)
		{
			handleMouseClick();
		}
		
		// Skip Time拖拽处理
		handleSkipTimeDrag(elapsed);
		
		// 键盘控制（按下任意键时禁用鼠标模式，与MainMenuState一致）
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
		else if (debugPanelVisible && usingDebugPanel)
		{
			updateDebugModeKeyboard();
		}
		else
		{
			updateNormalModeKeyboard();
		}
		
		// TAB切换调试面板
		if (debugPanelVisible && FlxG.keys.justPressed.TAB)
		{
			usingDebugPanel = !usingDebugPanel;

			mouseOverItem = -1;
			if (usingDebugPanel)
			{
				curDebugOption = 0;
				updateDebugSelection();
			}
			else
			{
				curSelected = 0;
				updateSelectionVisual();
			}
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
	}
	
	// ========== 键盘控制（分离出来保持清晰）==========
	function updateNormalModeKeyboard()
	{
		if(controls.UI_UP_P) changeSelection(-1);
		if(controls.UI_DOWN_P) changeSelection(1);
		if(controls.ACCEPT) executeMenuItem();
	}
	
	function updateDebugModeKeyboard()
	{
		if(controls.UI_UP_P) changeDebugOption(-1);
		if(controls.UI_DOWN_P) changeDebugOption(1);
		if(controls.ACCEPT) executeDebugOption();
		if(controls.BACK) 
		{
			usingDebugPanel = false;
			updateSelectionVisual();
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		}
	}
	
	function updateDifficultyModeKeyboard()
	{
		if(controls.UI_UP_P) changeDifficultySelection(-1);
		if(controls.UI_DOWN_P) changeDifficultySelection(1);
		if(controls.ACCEPT) executeDifficultyAction();
		if(controls.BACK) exitDifficultyMode();
	}
	
	// ========== Skip Time系统 ==========
	function updateSkipTimeVisibility()
	{
		skipTimeVisible = !PlayState.instance.startingSong && (PlayState.chartingMode || PlayState.instance.practiceMode || PlayState.instance.cpuControlled);
		
		if(skipTimeText != null)
		{
			skipTimeText.visible = skipTimeVisible;
			skipTimeBar.visible = skipTimeVisible;
			skipTimeBarFill.visible = skipTimeVisible;
		}
	}
	
	function showDebugPanel(visible:Bool)
	{
		debugPanelVisible = visible;
		if(debugPanel != null) 
		{
			debugPanel.visible = visible;
			debugPanel.alpha = visible ? 0.9 : 0;
		}
		for(text in debugTexts) 
		{
			text.visible = visible;
			text.alpha = visible ? 1 : 0;
		}
		for(bg in debugBgs)
		{
			bg.visible = visible;
			bg.alpha = visible ? 1 : 0;
		}
		
		updateSkipTimeDisplay();
	}
	
	function updateSkipTimeDisplay()
	{
		if(skipTimeText != null)
		{
			skipTimeText.visible = skipTimeVisible;
			skipTimeBar.visible = skipTimeVisible;
			skipTimeBarFill.visible = skipTimeVisible;
		}
		updateSkipTimePosition();
	}
	
	function updateSkipTimePosition()
	{
		if(skipTimeText == null) return;

		// 查找Skip Time选项在Debug面板中的位置
		var skipTimeIndex = debugOptions.indexOf('Skip Time');
		if (debugPanelVisible && skipTimeVisible && skipTimeIndex != -1 && skipTimeIndex < debugBgs.length)
		{
			var bg = debugBgs[skipTimeIndex];
			if (bg != null && bg.visible)
			{
				// 获取Skip Time选项文字的位置
				var skipTimeTextObj = debugTexts[skipTimeIndex + 1];
				if (skipTimeTextObj != null)
				{
					// 时间文本显示在选项文字右侧
					skipTimeText.x = skipTimeTextObj.x + skipTimeTextObj.width + 20;
					skipTimeText.y = skipTimeTextObj.y;
					
					// 进度条显示在时间文本下方
					skipTimeBar.x = skipTimeText.x;
					skipTimeBar.y = skipTimeText.y + skipTimeText.height + 5;
					skipTimeBarFill.x = skipTimeBar.x;
					skipTimeBarFill.y = skipTimeBar.y;
					
					// 调整进度条宽度与时间文本匹配
					skipTimeBar.width = Math.max(200, skipTimeText.width);
					skipTimeBarFill.width = skipTimeBar.width;
					skipTimeBar.makeGraphic(Std.int(skipTimeBar.width), 8, FlxColor.GRAY);
					skipTimeBarFill.makeGraphic(Std.int(skipTimeBarFill.width), 8, FlxColor.CYAN);
					return;
				}
			}
		}
		
		// 备用位置：屏幕底部中央
		skipTimeBar.x = (FlxG.width - skipTimeBar.width) / 2;
		skipTimeBar.y = FlxG.height - 100;
		skipTimeText.x = skipTimeBar.x;
		skipTimeText.y = skipTimeBar.y - 40;
		skipTimeBarFill.x = skipTimeBar.x;
		skipTimeBarFill.y = skipTimeBar.y;
	}
	
	function updateSkipTimeBarFill()
	{
		if(skipTimeBarFill == null || skipTimeBar == null) return;
		
		var percent = curTime / FlxG.sound.music.length;
		if(percent > 1) percent = 1;
		if(percent < 0) percent = 0;
		
		skipTimeBarFill.scale.x = percent;
		skipTimeBarFill.updateHitbox();
	}
	
	function updateSkipTimeText()
	{
		if(skipTimeText != null)
		{
			var current = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false);
			var total = FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
			skipTimeText.text = current + ' / ' + total;
			skipTimeText.updateHitbox();
		}
	}
	
	// ========== 难度选择系统 ==========
	function createDifficultySelection()
	{
		inDifficultyMode = true;
		mouseOverItem = -1;
		
		toggleSidebarElements(false);
		
		if(debugPanel != null && debugPanel.visible)
		{
			FlxTween.tween(debugPanel, {alpha: 0.3}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			for(text in debugTexts)
			{
				if(text != null)
					FlxTween.tween(text, {alpha: 0.3}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			}
			for(bg in debugBgs)
			{
				if(bg != null)
					FlxTween.tween(bg, {alpha: 0.3}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			}
		}
		
		if(skipTimeText != null)
		{
			skipTimeText.visible = false;
			skipTimeBar.visible = false;
			skipTimeBarFill.visible = false;
		}
		
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
		
		if(debugPanel != null && debugPanel.visible)
		{
			FlxTween.tween(debugPanel, {alpha: 0.9}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			for(text in debugTexts)
			{
				if(text != null)
					FlxTween.tween(text, {alpha: 1}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			}
			for(bg in debugBgs)
			{
				if(bg != null)
					FlxTween.tween(bg, {alpha: 1}, FADE_TIME * 0.5, {ease: FlxEase.quadOut});
			}
		}
		
		updateSkipTimeDisplay();
		
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
				debugPanelVisible = !debugPanelVisible;
				showDebugPanel(debugPanelVisible);
				usingDebugPanel = debugPanelVisible;
				mouseOverItem = -1;
				if(debugPanelVisible)
				{
					curDebugOption = 0;
					updateDebugSelection();
				}
				else
				{
					curSelected = 0;
					updateSelectionVisual();
				}
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				
			case "Exit to menu":
				exitToMenu();
		}
	}
	
	function executeDebugOption()
	{
		if(curDebugOption >= debugOptions.length) return;
		
		var option = debugOptions[curDebugOption];
		
		switch(option)
		{
			case 'Skip Time':
				handleSkipTimeAction();
				
			case 'Toggle Practice':
				togglePracticeMode();
				
			case 'Toggle Botplay':
				toggleBotplay();
				
			case 'Leave Charting Mode':
				leaveChartingMode();
				
			case 'End Song':
				endSong();
		}
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
	
	// ========== 具体功能实现 ==========
	function handleSkipTimeAction()
	{
		if(skipDragging) return;
		
		if(curTime < Conductor.songPosition)
		{
			PlayState.startOnTime = curTime;
			restartSong(true);
		}
		else
		{
			if(curTime != Conductor.songPosition)
			{
				PlayState.instance.clearNotesBefore(curTime);
				PlayState.instance.setSongTime(curTime);
			}
			closeMenu();
		}
	}
	
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
	
	function togglePracticeMode()
	{
		PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
		PlayState.changedDifficulty = true;
		practiceText.visible = PlayState.instance.practiceMode;
		
		initDebugOptions();
		updateSkipTimeVisibility();
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function toggleBotplay()
	{
		PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
		PlayState.changedDifficulty = true;
		PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
		PlayState.instance.botplayTxt.alpha = 1;
		PlayState.instance.botplaySine = 0;
		
		initDebugOptions();
		updateSkipTimeVisibility();
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function openOptions()
	{
		PlayState.instance.paused = true;
		PlayState.instance.vocals.volume = 0;
		PlayState.instance.canResync = false;
		
		if(ClientPrefs.data.keOptions)
			MusicBeatState.switchState(new KEOptionsMenu());
		else
			MusicBeatState.switchState(new OptionsState());
		
		if(ClientPrefs.data.pauseMusic != 'None')
		{
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
			FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
			FlxG.sound.music.time = pauseMusic.time;
		}
		
		OptionsState.onPlayState = KEOptionsMenu.onPlayState = true;
	}
	
	function restartSong(noTrans:Bool = false)
	{
		FlxG.sound.play(Paths.sound('confirmMenu'));
		
		PlayState.instance.paused = true;
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;
		
		if(noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		
		MusicBeatState.resetState();
	}
	
	function endSong()
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
	
	// ========== 关闭动画 ==========
	function closeMenu()
	{
		if(isAnimating) return;
		
		if(skipDragging && Math.abs(curTime - Conductor.songPosition) > 500)
		{
			handleSkipTimeAction();
		}
		
		isAnimating = true;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		
		fadeOutAll();
		slideOutIcons();
		
		safeTween(sidebar, {x: FlxG.width, alpha: 0}, SIDEBAR_ANIM_TIME, 
		{
			ease: FlxEase.quartIn,
			startDelay: menuItems.length * ICON_STAGGER,
			onComplete: function(twn:FlxTween)
			{
				FlxG.mouse.visible = false;
				close();
			}
		});
	}
	
	function fadeOutAll()
	{
		if(bg != null) FlxTween.tween(bg, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		if(backdrop != null) FlxTween.tween(backdrop, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		
		if(skipTimeText != null) FlxTween.tween(skipTimeText, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		if(skipTimeBar != null) FlxTween.tween(skipTimeBar, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		if(skipTimeBarFill != null) FlxTween.tween(skipTimeBarFill, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		
		var infoElements = [infoPanelBg, levelInfo, levelDifficulty, blueballedTxt, practiceText, chartingText];
		for(element in infoElements) if(element != null) fadeOutElement(element);
		
		if(debugPanel != null) fadeOutElement(debugPanel);
		for(text in debugTexts) fadeOutElement(text);
		for(bg in debugBgs) fadeOutElement(bg);
		
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
		FlxG.mouse.visible = false;
		
		super.destroy();
	}
}