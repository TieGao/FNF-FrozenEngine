package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.util.FlxStringUtil;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.ui.FlxButton;
import flixel.input.mouse.FlxMouseEventManager;

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
	
	// ========== Skip Time功能增强 ==========
	var skipTimeText:FlxText;
	var skipTimeBar:FlxSprite;
	var skipTimeBarFill:FlxSprite;
	var skipTimeTracker:FlxSprite;
	var skipTimeTextBg:FlxSprite;
	var curTime:Float = Math.max(0, Conductor.songPosition);
	var holdTime:Float = 0;
	var skipTimeMode:Bool = false;
	var skipTimeVisible:Bool = false;
	var skipDragging:Bool = false;
	var lastMouseX:Float = 0;
	
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
	
	// ========== 输入控制 ==========
	var usingDebugPanel:Bool = false;
	var mouseOverSkipTime:Bool = false;
	var mouseOverBar:Bool = false;
	var lastSkipClickTime:Float = 0;
	
	// ========== 鼠标事件管理 ==========
	var mouseEventManager:FlxMouseEventManager;
	var hoveredIconIndex:Int = -1;
	var hoveredDebugIndex:Int = -1;
	var hoveredDifficultyIndex:Int = -1;
	
	// ========== 动画常量 ==========
	static final SIDEBAR_ANIM_TIME:Float = 0.45;
	static final FADE_TIME:Float = 0.35;
	static final ICON_STAGGER:Float = 0.05;

	public static var songName:String = null;

	// ========== 主创建函数 ==========
	override function create()
	{
		super.create();
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		
		// 初始化鼠标事件管理器（Flixel 6.1.0+方式）
		mouseEventManager = new FlxMouseEventManager();
		add(mouseEventManager);
		
		initMenuItems();
		initDifficultyChoices();
		initPauseMusic();
		createCharmUI();
		createDebugPanel();
		
		usingDebugPanel = debugPanelVisible && debugOptions.length > 0;
		
		// 启用鼠标（Flixel 6.1.0+）
		FlxG.mouse.enabled = true;
		FlxG.mouse.visible = true;
		FlxG.mouse.useSystemCursor = true;
		
		updateSkipTimeVisibility();
	}
	
	function initMenuItems()
	{
		menuItems = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
		
		if(Difficulty.list.length < 2) 
			menuItems.remove('Change Difficulty');

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
	
	// ========== 创建Charm界面 ==========
	function createCharmUI()
	{
		createBackground();
		createSidebar();
		createInfoPanel();
		createMenuIcons();
		createSkipTimeUI();
		
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
		}
		
		debugPanelVisible = false;
		debugPanel.visible = false;
		for(text in debugTexts) if(text != null) text.visible = false;
		for(bg in debugBgs) if(bg != null) bg.visible = false;
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
			
			// 添加鼠标事件（Flixel 6.1.0+方式）
			setupIconMouseEvents(iconBg, icon, i, itemName);
		}
	}
	
	function setupIconMouseEvents(iconBg:FlxSprite, icon:FlxSprite, index:Int, itemName:String)
	{
		// 鼠标进入
		mouseEventManager.add(iconBg, 
			null, // 点击
			function(sprite:FlxSprite)
			{
				// 鼠标进入
				if(!isAnimating && !inDifficultyMode)
				{
					curSelected = index;
					updateSelectionVisual();
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				}
			},
			function(sprite:FlxSprite)
			{
				// 鼠标离开
				if(!isAnimating && !inDifficultyMode)
				{
					// 不改变选择，只是视觉反馈
					if(curSelected == index)
					{
						// 保持选中状态
					}
				}
			}
		);
		
		// 鼠标点击
		mouseEventManager.add(iconBg, function(sprite:FlxSprite)
		{
			if(!isAnimating && !inDifficultyMode)
			{
				executeMenuItem();
			}
		});
		
		// 同样设置图标的鼠标事件（为了扩大点击区域）
		mouseEventManager.add(icon, 
			null, 
			function(sprite:FlxSprite)
			{
				if(!isAnimating && !inDifficultyMode)
				{
					curSelected = index;
					updateSelectionVisual();
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				}
			},
			null,
			function(sprite:FlxSprite)
			{
				if(!isAnimating && !inDifficultyMode)
				{
					executeMenuItem();
				}
			}
		);
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
		
		skipTimeText = new FlxText(0, 0, 0, '', 32);
		skipTimeText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		skipTimeText.scrollFactor.set();
		skipTimeText.borderSize = 2;
		skipTimeText.alpha = 0;
		skipTimeText.visible = false;
		add(skipTimeText);
		
		skipTimeTracker = new FlxSprite(0, 0);
		skipTimeTracker.makeGraphic(1, 1, 0x00FFFFFF);
		skipTimeTracker.visible = false;
		add(skipTimeTracker);
		
		skipTimeTextBg = new FlxSprite(0, 0);
		skipTimeTextBg.makeGraphic(1, 1, 0x00FFFFFF);
		skipTimeTextBg.scrollFactor.set();
		skipTimeTextBg.visible = false;
		add(skipTimeTextBg);
		
		// 为Skip Time添加鼠标事件
		setupSkipTimeMouseEvents();
		
		updateSkipTimeText();
	}
	
	function setupSkipTimeMouseEvents()
	{
		// 进度条鼠标事件
		mouseEventManager.add(skipTimeBar, 
			null, 
			function(sprite:FlxSprite)
			{
				mouseOverBar = true;
			},
			function(sprite:FlxSprite)
			{
				mouseOverBar = false;
			},
			function(sprite:FlxSprite)
			{
				if(skipTimeVisible)
				{
					startSkipTimeDrag();
				}
			}
		);
		
		// 文本背景鼠标事件
		mouseEventManager.add(skipTimeTextBg, 
			null,
			function(sprite:FlxSprite)
			{
				mouseOverSkipTime = true;
			},
			function(sprite:FlxSprite)
			{
				mouseOverSkipTime = false;
			},
			function(sprite:FlxSprite)
			{
				if(skipTimeVisible)
				{
					startSkipTimeDrag();
				}
			}
		);
	}
	
	function startSkipTimeDrag()
	{
		if(!skipTimeVisible || isAnimating) return;
		skipDragging = true;
		lastMouseX = FlxG.mouse.screenX;
		FlxG.mouse.useSystemCursor = false;
	}
	
	function setupDebugPanelMouseEvents()
	{
		if(debugBgs.length == 0) return;
		
		for(i in 0...debugBgs.length)
		{
			var bg = debugBgs[i];
			var optionIndex = i;
			
			mouseEventManager.add(bg,
				null,
				function(sprite:FlxSprite)
				{
					if(!isAnimating && debugPanelVisible && !inDifficultyMode)
					{
						curDebugOption = optionIndex;
						updateDebugSelection();
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					}
				},
				null,
				function(sprite:FlxSprite)
				{
					if(!isAnimating && debugPanelVisible && !inDifficultyMode)
					{
						executeDebugOption();
					}
				}
			);
		}
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
				
				if(debugPanel != null && debugPanelVisible)
				{
					FlxTween.tween(debugPanel, {alpha: 0.9}, FADE_TIME, {ease: FlxEase.quadOut});
					for(text in debugTexts)
					{
						if(text != null)
							FlxTween.tween(text, {alpha: 1}, FADE_TIME, {ease: FlxEase.quadOut});
					}
					for(bg in debugBgs)
					{
						if(bg != null)
							FlxTween.tween(bg, {alpha: 1}, FADE_TIME, {ease: FlxEase.quadOut});
					}
					setupDebugPanelMouseEvents();
				}
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
		
		if(skipTimeVisible && skipTimeText != null)
		{
			FlxTween.tween(skipTimeText, {alpha: 1}, FADE_TIME, 
			{
				ease: FlxEase.quadOut,
				startDelay: menuItems.length * ICON_STAGGER
			});
			FlxTween.tween(skipTimeTextBg, {alpha: 1}, FADE_TIME, 
			{
				ease: FlxEase.quadOut,
				startDelay: menuItems.length * ICON_STAGGER
			});
			FlxTween.tween(skipTimeBar, {alpha: 0.5}, FADE_TIME, 
			{
				ease: FlxEase.quadOut,
				startDelay: menuItems.length * ICON_STAGGER
			});
			FlxTween.tween(skipTimeBarFill, {alpha: 1}, FADE_TIME, 
			{
				ease: FlxEase.quadOut,
				startDelay: menuItems.length * ICON_STAGGER
			});
		}
	}
	
	function checkAnimationComplete(i:Int)
	{
		if(i == menuItems.length - 1)
		{
			isAnimating = false;
			if(usingDebugPanel && debugPanelVisible)
			{
				updateDebugSelection();
			}
			else
			{
				updateSelectionVisual();
			}
			
			updateSkipTimeDisplay();
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
	
	// ========== 主更新函数 ==========
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		cantUnpause -= elapsed;
		if(pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;
		
		updateSkipTimePosition();
		updateSkipTimeBarFill();
		
		if(isAnimating || cantUnpause > 0) return;
		
		// 处理进度条拖拽
		handleSkipTimeDragging(elapsed);
		
		// 键盘控制
		if(debugPanelVisible && debugOptions.length > 0)
		{
			if(FlxG.keys.justPressed.TAB)
			{
				usingDebugPanel = !usingDebugPanel;
				if(usingDebugPanel)
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
		
		// 模式更新
		if(inDifficultyMode)
		{
			updateDifficultyMode(elapsed);
		}
		else if(usingDebugPanel && debugPanelVisible)
		{
			updateDebugMode(elapsed);
		}
		else
		{
			updateNormalMode(elapsed);
		}
		
		// 鼠标滚轮（独立处理）
		handleMouseWheel();
	}
	
	function handleSkipTimeDragging(elapsed:Float)
	{
		if(!skipTimeVisible || !skipDragging) return;
		
		var mouseX = FlxG.mouse.screenX;
		
		if(FlxG.mouse.pressed)
		{
			var deltaX = mouseX - lastMouseX;
			if(deltaX != 0)
			{
				var timePerPixel = FlxG.sound.music.length / skipTimeBar.width;
				var timeDelta = deltaX * timePerPixel;
				curTime += timeDelta;
				
				if(curTime >= FlxG.sound.music.length) 
					curTime = FlxG.sound.music.length;
				else if(curTime < 0) 
					curTime = 0;
				
				updateSkipTimeText();
				updateSkipTimeBarFill();
				
				lastMouseX = mouseX;
			}
		}
		
		if(FlxG.mouse.justReleased)
		{
			skipDragging = false;
			FlxG.mouse.useSystemCursor = true;
			
			if(Math.abs(curTime - Conductor.songPosition) > 500)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
		}
	}
	
	function handleMouseWheel()
	{
		if(!skipTimeVisible || isAnimating) return;
		
		var wheel = FlxG.mouse.wheel;
		if(wheel != 0 && (mouseOverBar || mouseOverSkipTime))
		{
			var shiftMult = FlxG.keys.pressed.SHIFT ? 10 : 1;
			var wheelAmount = wheel * 1000 * shiftMult;
			adjustSkipTime(wheelAmount);
		}
	}
	
	// ========== 普通模式更新 ==========
	function updateNormalMode(elapsed:Float)
	{
		if(controls.UI_UP_P) changeSelection(-1);
		if(controls.UI_DOWN_P) changeSelection(1);
		
		if(controls.ACCEPT) executeMenuItem();
		if(controls.BACK) closeMenu();
		
		// 右键退出（Flixel 6.1.0+）
		if(FlxG.mouse.justPressedRight)
		{
			closeMenu();
		}
	}
	
	function updateDebugMode(elapsed:Float)
	{
		if(debugTexts.length == 0 || debugOptions.length == 0) return;
		
		var skipTimeInDebug = debugOptions.contains('Skip Time') && debugOptions[curDebugOption] == 'Skip Time';
		skipTimeMode = skipTimeInDebug;
		
		if(controls.UI_UP_P) changeDebugOption(-1);
		if(controls.UI_DOWN_P) changeDebugOption(1);
		
		if(skipTimeMode)
		{
			if(controls.UI_LEFT_P || controls.UI_RIGHT_P)
			{
				updateSkipTimeControls(elapsed);
			}
			
			if(controls.UI_LEFT || controls.UI_RIGHT)
			{
				holdTime += elapsed;
				if(holdTime > 0.5)
				{
					var amount = 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
					adjustSkipTime(amount);
				}
			}
			else
			{
				holdTime = 0;
			}
		}
		
		if(controls.ACCEPT) executeDebugOption();
		if(controls.BACK) closeMenu();
		
		if(FlxG.mouse.justPressedRight)
		{
			closeMenu();
		}
	}
	
	function updateDifficultyMode(elapsed:Float)
	{
		if(controls.UI_UP_P)
		{
			curSelected = FlxMath.wrap(curSelected - 1, 0, difficultyChoices.length - 1);
			updateDifficultySelection();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		if(controls.UI_DOWN_P)
		{
			curSelected = FlxMath.wrap(curSelected + 1, 0, difficultyChoices.length - 1);
			updateDifficultySelection();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		
		if(controls.ACCEPT) executeDifficultyAction();
		if(controls.BACK) exitDifficultyMode();
		
		if(FlxG.mouse.justPressedRight)
		{
			exitDifficultyMode();
		}
	}
	
	// ========== 选择系统 ==========
	function changeSelection(change:Int)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		updateSelectionVisual();
		
		if(change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function changeDebugOption(change:Int)
	{
		curDebugOption = FlxMath.wrap(curDebugOption + change, 0, debugOptions.length - 1);
		updateDebugSelection();
		
		if(change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function updateSelectionVisual()
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
			else
			{
				iconBg.color = 0x00FFFFFF;
				iconBg.alpha = 0;
				icon.color = 0xFFAAAAAA;
				icon.alpha = 0.8;
			}
		}
	}
	
	function updateDebugSelection()
	{
		for(i in 1...debugTexts.length)
		{
			var text = debugTexts[i];
			var optionIndex = i - 1;
			if(optionIndex >= debugBgs.length) continue;
			
			var bg = debugBgs[optionIndex];
			
			if(optionIndex == curDebugOption)
			{
				text.color = FlxColor.CYAN;
				text.size = 22;
				if(bg != null)
				{
					bg.color = 0x5500FFFF;
					bg.alpha = 1;
				}
			}
			else
			{
				text.color = FlxColor.WHITE;
				text.size = 20;
				if(bg != null)
				{
					bg.color = 0x00FFFFFF;
					bg.alpha = 0;
				}
			}
			text.updateHitbox();
		}
	}
	
	function updateDifficultySelection()
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
	
	// ========== Skip Time系统 ==========
	function updateSkipTimeControls(elapsed:Float)
	{
		if(controls.UI_LEFT_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			curTime -= 1000;
			holdTime = 0;
		}
		if(controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			curTime += 1000;
			holdTime = 0;
		}

		updateSkipTimeText();
		updateSkipTimeBarFill();
		
		if(curTime >= FlxG.sound.music.length) 
			curTime = FlxG.sound.music.length - 1000;
		else if(curTime < 0) 
			curTime = 0;
	}
	
	function adjustSkipTime(amount:Float)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curTime += amount;
		
		if(curTime >= FlxG.sound.music.length) 
			curTime = FlxG.sound.music.length - 1000;
		else if(curTime < 0) 
			curTime = 0;
		
		updateSkipTimeText();
		updateSkipTimeBarFill();
	}
	
	function updateSkipTimeVisibility()
	{
		skipTimeVisible = !PlayState.instance.startingSong && (PlayState.chartingMode || PlayState.instance.practiceMode || PlayState.instance.cpuControlled);
		
		if(skipTimeText != null)
		{
			skipTimeText.visible = skipTimeVisible;
			skipTimeTextBg.visible = skipTimeVisible;
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
		
		if(visible)
		{
			setupDebugPanelMouseEvents();
		}
		
		updateSkipTimeDisplay();
	}
	
	function updateSkipTimeDisplay()
	{
		if(skipTimeText != null)
		{
			skipTimeText.visible = skipTimeVisible;
			skipTimeTextBg.visible = skipTimeVisible;
			skipTimeBar.visible = skipTimeVisible;
			skipTimeBarFill.visible = skipTimeVisible;
		}
		updateSkipTimePosition();
	}
	
	function updateSkipTimePosition()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		if(debugPanelVisible && debugOptions.contains('Skip Time') && skipTimeVisible)
		{
			var skipTimeIndex = debugOptions.indexOf('Skip Time');
			if(skipTimeIndex != -1 && skipTimeIndex < debugBgs.length)
			{
				var bg = debugBgs[skipTimeIndex];
				if(bg != null)
				{
					skipTimeBar.x = bg.x + bg.width + 60;
					skipTimeBar.y = bg.y + bg.height / 2 - 4;
					
					skipTimeText.x = skipTimeBar.x;
					skipTimeText.y = skipTimeBar.y - 40;
					skipTimeText.visible = true;
					
					skipTimeTracker.x = bg.x;
					skipTimeTracker.y = bg.y;
					
					skipTimeTextBg.x = skipTimeText.x - 10;
					skipTimeTextBg.y = skipTimeText.y - 5;
					skipTimeTextBg.makeGraphic(Std.int(skipTimeText.width + 20), Std.int(skipTimeText.height + 10), 0x00FFFFFF);
					
					skipTimeBarFill.x = skipTimeBar.x;
					skipTimeBarFill.y = skipTimeBar.y;
				}
			}
		}
		else if(skipTimeVisible)
		{
			skipTimeBar.x = (FlxG.width - skipTimeBar.width) / 2;
			skipTimeBar.y = FlxG.height - 100;
			
			skipTimeText.x = skipTimeBar.x;
			skipTimeText.y = skipTimeBar.y - 40;
			
			skipTimeTextBg.x = skipTimeText.x - 10;
			skipTimeTextBg.y = skipTimeText.y - 5;
			skipTimeTextBg.makeGraphic(Std.int(skipTimeText.width + 20), Std.int(skipTimeText.height + 10), 0x00FFFFFF);
			
			skipTimeBarFill.x = skipTimeBar.x;
			skipTimeBarFill.y = skipTimeBar.y;
		}
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
			skipTimeText.text = '$current / $total';
			skipTimeText.updateHitbox();
			
			if(skipTimeTextBg != null)
			{
				skipTimeTextBg.makeGraphic(Std.int(skipTimeText.width + 20), Std.int(skipTimeText.height + 10), 0x00FFFFFF);
			}
		}
	}
	
	// ========== 难度选择系统 ==========
	function createDifficultySelection()
	{
		inDifficultyMode = true;
		
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
			skipTimeTextBg.visible = false;
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
			
			// 添加鼠标事件
			setupDifficultyMouseEvents(textBg, diffText, i, diffName);
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
	
	function setupDifficultyMouseEvents(textBg:FlxSprite, diffText:FlxText, index:Int, diffName:String)
	{
		mouseEventManager.add(textBg,
			null,
			function(sprite:FlxSprite)
			{
				if(inDifficultyMode && !isAnimating)
				{
					curSelected = index;
					updateDifficultySelection();
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				}
			},
			null,
			function(sprite:FlxSprite)
			{
				if(inDifficultyMode && !isAnimating)
				{
					executeDifficultyAction();
				}
			}
		);
		
		mouseEventManager.add(diffText,
			null,
			function(sprite:FlxSprite)
			{
				if(inDifficultyMode && !isAnimating)
				{
					curSelected = index;
					updateDifficultySelection();
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				}
			},
			null,
			function(sprite:FlxSprite)
			{
				if(inDifficultyMode && !isAnimating)
				{
					executeDifficultyAction();
				}
			}
		);
	}
	
	function exitDifficultyMode()
	{
		inDifficultyMode = false;
		
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
		var songLowercase = Paths.formatToSongPath(PlayState.SONG.song);
		var poop = Highscore.formatSong(songLowercase, curSelected);
		
		try
		{
			Song.loadFromJson(poop, songLowercase);
			PlayState.storyDifficulty = curSelected;
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
		updateSkipTimeDisplay();
		
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
		updateSkipTimeDisplay();
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
	
	function openOptions()
	{
		PlayState.instance.paused = true;
		PlayState.instance.vocals.volume = 0;
		PlayState.instance.canResync = false;
		
		if(ClientPrefs.data.keOptions)
			MusicBeatState.switchState(new options.KEOptionsMenu());
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
				FlxG.mouse.enabled = false;
				close();
			}
		});
	}
	
	function fadeOutAll()
	{
		if(bg != null) FlxTween.tween(bg, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		if(backdrop != null) FlxTween.tween(backdrop, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		
		if(skipTimeText != null) FlxTween.tween(skipTimeText, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		if(skipTimeTextBg != null) FlxTween.tween(skipTimeTextBg, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
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

	// ========== 安全 tween 辅助 ==========
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
	
	// ========== 辅助函数 ==========
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
		if(mouseEventManager != null)
		{
			mouseEventManager.destroy();
			mouseEventManager = null;
		}
		
		if(pauseMusic != null)
		{
			pauseMusic.stop();
			pauseMusic.destroy();
		}
		
		super.destroy();
	}
}