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
import states.FreeplayState;
import states.NewFreeplayState;
import options.OptionsState;
import options.KEOptionsMenu;

class NewPauseSubState extends MusicBeatSubstate
{
	// ========== Windows 8.1 Charm风格核心变量 ==========
	var sidebar:FlxSprite;                     // 右侧Charm侧边栏
	var infoPanelBg:FlxSprite;                 // 信息面板背景
	var menuIcons:Map<String, FlxSprite> = []; // 菜单图标
	var iconBgs:Map<String, FlxSprite> = [];   // 图标背景
	
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
	var skipTimeText:FlxText;                  // 时间显示文本 (00:00 / 歌曲时间)
	var skipTimeBar:FlxSprite;                  // 进度条背景
	var skipTimeBarFill:FlxSprite;              // 进度条填充
	var skipTimeTracker:FlxSprite;              // Skip Time位置跟踪器
	var skipTimeTextBg:FlxSprite;               // Skip Time文本背景，用于鼠标检测
	var curTime:Float = Math.max(0, Conductor.songPosition);
	var holdTime:Float = 0;
	var skipTimeMode:Bool = false;               // 是否在Skip Time调整模式
	var skipTimeVisible:Bool = false;             // Skip Time是否可见
	var skipDragging:Bool = false;                // 是否在拖拽进度条
	var lastMouseX:Float = 0;                      // 上次鼠标X位置，用于拖拽
	
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
	var usingDebugPanel:Bool = false; // true=使用调试面板, false=使用边栏
	var mouseOverSkipTime:Bool = false; // 鼠标是否悬浮在Skip Time上
	var mouseOverBar:Bool = false;      // 鼠标是否悬浮在进度条上
	var lastSkipClickTime:Float = 0;
	
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
		
		// 初始化菜单（不在边栏显示Skip Time）
		initMenuItems();
		
		// 初始化难度选项
		initDifficultyChoices();
		
		// 初始化暂停音乐
		initPauseMusic();
		
		// 创建Windows 8.1 Charm界面
		createCharmUI();
		
		// 创建调试面板（根据条件决定是否显示）
		createDebugPanel();
		
		// 默认输入控制：如果有调试面板则使用调试面板，否则使用边栏
		usingDebugPanel = debugPanelVisible && debugOptions.length > 0;
		
		// 启用鼠标
		FlxG.mouse.visible = true;
		FlxG.mouse.useSystemCursor = true;
		
		// 初始化Skip Time可见性
		updateSkipTimeVisibility();
	}
	
	function initMenuItems()
	{
		// 基础菜单项（不在边栏显示Skip Time）
		menuItems = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
		
		// 根据游戏状态调整
		if(Difficulty.list.length < 2) 
			menuItems.remove('Change Difficulty');

		// 在 Charting / Practice / Botplay 时显示 Tool 按钮（用于打开调试面板）
		if(PlayState.chartingMode || PlayState.instance.practiceMode || PlayState.instance.cpuControlled)
		{
			// 插入到倒数第二位（在 Exit to menu 之前）
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
		createSkipTimeUI(); // 创建Skip Time UI（包含进度条和时间显示）
		
		// 启动动画
		startCharmAnimations();
	}
	
	function createBackground()
	{
		// 网格背景
		if(ClientPrefs.data.coolBackdrop)
		{
			backdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
			backdrop.velocity.set(40, 40);
			backdrop.alpha = 0;
			backdrop.scrollFactor.set();
			add(backdrop);
		}
		
		// 半透明黑色背景
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
		
		// 歌曲信息
		levelInfo = createText(panelX + 20, textY, 310, PlayState.SONG.song, 28, FlxColor.WHITE);
		levelDifficulty = createText(panelX + 20, textY + 40, 310, Difficulty.getString().toUpperCase(), 22, FlxColor.CYAN);
		blueballedTxt = createText(panelX + 20, textY + 70, 310, "Blueballed: " + PlayState.deathCounter, 20, FlxColor.WHITE);
		
		// 模式标签
		practiceText = createText(panelX + 20, textY + 100, 310, "PRACTICE MODE", 18, FlxColor.YELLOW);
		practiceText.visible = PlayState.instance.practiceMode;
		
		chartingText = createText(panelX + 20, textY + 130, 310, "CHARTING MODE", 18, FlxColor.RED);
		chartingText.visible = PlayState.chartingMode;
	}
	
	// ========== 创建调试面板（向上移动并扩大） ==========
	function createDebugPanel()
	{
		// 根据条件决定调试选项（两种模式都包含Skip Time）
		initDebugOptions();
		
		// 如果没有调试选项，则不创建面板
		if(debugOptions.length == 0)
		{
			debugPanelVisible = false;
			return;
		}
		
		// 调试面板背景（向上移动并扩大）
		var panelWidth:Int = 350; // 与信息面板同宽
		var panelHeight:Int = 220; // 扩大高度为220
		var panelX:Float = 50; // 与信息面板同X
		var panelY:Float = FlxG.height - 220 - panelHeight - 40; // 在信息面板上方40像素（更向上）
		
		debugPanel = new FlxSprite(panelX, panelY).makeGraphic(panelWidth, panelHeight, FlxColor.BLACK);
		debugPanel.alpha = 0;
		debugPanel.scrollFactor.set();
		add(debugPanel);
		
		// 创建调试选项
		var optionY:Float = panelY + 20;
		var optionSpacing:Float = 35;
		
		// 调试面板标题
		var title = createText(panelX + 20, optionY, panelWidth - 40, "CHARTING PANEL", 22, FlxColor.YELLOW);
		debugTexts.push(title);
		
		// 调试选项
		for(i in 0...debugOptions.length)
		{
			var yPos = optionY + 40 + (i * optionSpacing);
			
			// 选项背景（用于鼠标检测）
			var optionBg = new FlxSprite(panelX + 15, yPos - 5);
			optionBg.makeGraphic(panelWidth - 30, 30, 0x00FFFFFF);
			optionBg.scrollFactor.set();
			optionBg.alpha = 0;
			add(optionBg);
			debugBgs.push(optionBg);
			
			// 选项文本
			var optionText = createText(panelX + 30, yPos, panelWidth - 60, debugOptions[i], 20, FlxColor.WHITE);
			optionText.alpha = 0;
			debugTexts.push(optionText);
		}
		
		// 默认不自动显示调试面板，由侧边栏 Tool 按钮切换显示（面板始终创建以保留完整功能）
		debugPanelVisible = false;
		// 隐藏全部元素，等待用户通过 Tool 打开
		debugPanel.visible = false;
		for(text in debugTexts) if(text != null) text.visible = false;
		for(bg in debugBgs) if(bg != null) bg.visible = false;
	}
	
	function initDebugOptions()
	{
		if(PlayState.chartingMode)
		{
			// Charting模式下显示完整调试选项
			debugOptions = ['Skip Time', 'Toggle Practice', 'Toggle Botplay', 'Leave Charting Mode', 'End Song'];
		}
		else if(PlayState.instance.practiceMode || PlayState.instance.cpuControlled)
		{
			// Practice或Botplay模式下显示Skip Time和对应的开关选项
			debugOptions = ['Skip Time'];
			
			// 如果是Practice模式，添加Toggle Practice
			if(PlayState.instance.practiceMode)
			{
				debugOptions = ['Toggle Practice', 'Skip Time'];
			}
			// 如果是Botplay模式，添加Toggle Botplay
			if(PlayState.instance.cpuControlled)
			{
				debugOptions = ['Toggle Botplay', 'Skip Time'];
			}
		}
		else
		{
			// 其他情况不显示调试面板
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
			
			// 图标背景
			var iconBg = createIconBg(yPos);
			iconBgs.set(itemName, iconBg);
			
			// 图标
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
	
	// ========== 创建Skip Time UI（进度条 + 时间显示） ==========
	function createSkipTimeUI()
	{
		// 进度条背景
		skipTimeBar = new FlxSprite(0, 0);
		skipTimeBar.makeGraphic(300, 8, FlxColor.GRAY);
		skipTimeBar.scrollFactor.set();
		skipTimeBar.alpha = 0;
		skipTimeBar.visible = false;
		add(skipTimeBar);
		
		// 进度条填充
		skipTimeBarFill = new FlxSprite(0, 0);
		skipTimeBarFill.makeGraphic(300, 8, FlxColor.CYAN);
		skipTimeBarFill.scrollFactor.set();
		skipTimeBarFill.alpha = 0;
		skipTimeBarFill.visible = false;
		add(skipTimeBarFill);
		
		// 时间显示文本
		skipTimeText = new FlxText(0, 0, 0, '', 32);
		skipTimeText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		skipTimeText.scrollFactor.set();
		skipTimeText.borderSize = 2;
		skipTimeText.alpha = 0;
		skipTimeText.visible = false;
		add(skipTimeText);
		
		// Skip Time位置跟踪器（用于在调试面板中定位）
		skipTimeTracker = new FlxSprite(0, 0);
		skipTimeTracker.makeGraphic(1, 1, 0x00FFFFFF);
		skipTimeTracker.visible = false;
		add(skipTimeTracker);
		
		// Skip Time文本背景（用于鼠标检测）
		skipTimeTextBg = new FlxSprite(0, 0);
		skipTimeTextBg.makeGraphic(1, 1, 0x00FFFFFF);
		skipTimeTextBg.scrollFactor.set();
		skipTimeTextBg.visible = false;
		add(skipTimeTextBg);
		
		updateSkipTimeText();
	}
	
	// ========== 动画系统 ==========
	function startCharmAnimations()
	{
		// 背景淡入
		FlxTween.tween(bg, {alpha: 0.6}, FADE_TIME, {ease: FlxEase.quadOut});
		if(backdrop != null) 
			FlxTween.tween(backdrop, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		
		// 侧边栏滑入
		// 使用 safeTween 防止目标值为 NaN 导致异常
		safeTween(sidebar, {x: FlxG.width - 75, alpha: 0.9}, SIDEBAR_ANIM_TIME,
		{
			ease: FlxEase.quartOut,
			onComplete: function(twn:FlxTween) {
				startInfoAnimations();
				
				// 如果调试面板存在，也淡入显示
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
				}
			}
		});
		
		// 图标滑入
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
				
				// 仅当 targetX 有效时执行移动动画
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
		
		// Skip Time UI淡入（如果需要）
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
			// 动画完成后更新选择状态
			if(usingDebugPanel && debugPanelVisible)
			{
				updateDebugSelection();
			}
			else
			{
				updateSelectionVisual();
			}
			
			// 更新Skip Time显示
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
		
		updateSkipTimePosition(); // 更新进度条和时间文本位置
		updateSkipTimeBarFill();   // 更新进度条填充
		
		if(isAnimating || cantUnpause > 0) return;
		
		// 更新鼠标交互（鼠标独立操作）
		updateMouseInteraction();
		
		// 处理进度条拖拽
		handleSkipTimeDragging(elapsed);
		
		// 键盘控制：Tab键切换键盘输入模式（只在有调试面板时）
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
		
		// 难度选择模式
		if(inDifficultyMode)
		{
			updateDifficultyMode(elapsed);
		}
		// 根据键盘输入模式分发更新逻辑
		else if(usingDebugPanel && debugPanelVisible)
		{
			updateDebugMode(elapsed);
		}
		else
		{
			updateNormalMode(elapsed);
		}
	}
	
	// ========== 处理进度条拖拽 ==========
	function handleSkipTimeDragging(elapsed:Float)
	{
		if(!skipTimeVisible) return;
		
		var mouseX = FlxG.mouse.screenX;
		var mouseY = FlxG.mouse.screenY;
		
		// 检查鼠标是否在进度条上
		if(skipTimeBar != null && skipTimeBar.visible)
		{
			mouseOverBar = mouseX >= skipTimeBar.x && mouseX <= skipTimeBar.x + skipTimeBar.width &&
						   mouseY >= skipTimeBar.y && mouseY <= skipTimeBar.y + skipTimeBar.height;
		}
		
		// 开始拖拽
		if(FlxG.mouse.justPressed && (mouseOverBar || mouseOverSkipTime))
		{
			skipDragging = true;
			lastMouseX = mouseX;
			FlxG.mouse.useSystemCursor = false; // 可以改成手型
		}
		
		// 拖拽中
		if(skipDragging && FlxG.mouse.pressed)
		{
			var deltaX = mouseX - lastMouseX;
			if(deltaX != 0)
			{
				// 根据鼠标移动计算时间变化
				var timePerPixel = FlxG.sound.music.length / skipTimeBar.width;
				var timeDelta = deltaX * timePerPixel;
				curTime += timeDelta;
				
				// 边界检查
				if(curTime >= FlxG.sound.music.length) 
					curTime = FlxG.sound.music.length;
				else if(curTime < 0) 
					curTime = 0;
				
				updateSkipTimeText();
				updateSkipTimeBarFill();
				
				lastMouseX = mouseX;
			}
		}
		
		// 结束拖拽
		if(skipDragging && FlxG.mouse.justReleased)
		{
			skipDragging = false;
			FlxG.mouse.useSystemCursor = true;
			
			// 如果拖拽幅度较大，自动执行跳转
			if(Math.abs(curTime - Conductor.songPosition) > 500)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				// 这里不立即执行，只是标记时间
			}
		}
		
		// 鼠标滚轮调整（当悬浮在进度条或文本上时）
		if((mouseOverBar || mouseOverSkipTime) && FlxG.mouse.wheel != 0)
		{
			var shiftMult = FlxG.keys.pressed.SHIFT ? 10 : 1;
			var wheelAmount = FlxG.mouse.wheel * 1000 * shiftMult; // 每次滚动1秒，Shift加速
			adjustSkipTime(wheelAmount);
		}
	}
	
	// ========== 鼠标交互系统（独立操作） ==========
	function updateMouseInteraction()
	{
		var mouseX = FlxG.mouse.screenX;
		var mouseY = FlxG.mouse.screenY;
		
		// 检查鼠标是否在Skip Time文本上
		mouseOverSkipTime = false;
		if(skipTimeText != null && skipTimeText.visible && skipTimeTextBg != null && skipTimeTextBg.visible && skipTimeText.alpha > 0.5)
		{
			if(mouseX >= skipTimeTextBg.x && mouseX <= skipTimeTextBg.x + skipTimeTextBg.width &&
			   mouseY >= skipTimeTextBg.y && mouseY <= skipTimeTextBg.y + skipTimeTextBg.height)
			{
				mouseOverSkipTime = true;
			}
		}
		
		// 如果不是难度选择模式，更新侧边栏和调试面板的鼠标交互
		if(!inDifficultyMode)
		{
			// 检查鼠标在侧边栏区域
			if(mouseX >= FlxG.width - 75 && mouseX <= FlxG.width)
			{
				updateSidebarMouseHover(mouseX, mouseY);
			}
			// 检查鼠标在调试面板区域
			else if(debugPanelVisible && debugPanel != null)
			{
				if(mouseX >= debugPanel.x && mouseX <= debugPanel.x + debugPanel.width &&
				   mouseY >= debugPanel.y && mouseY <= debugPanel.y + debugPanel.height)
				{
					updateDebugMouseHover(mouseX, mouseY);
				}
			}
		}
		else
		{
			// 难度选择模式下的鼠标交互
			updateDifficultyHover();
		}
	}
	
	function updateSidebarMouseHover(mouseX:Float, mouseY:Float)
	{
		var hoveredIndex = -1;
		
		// 检查悬停在侧边栏区域
		for(i in 0...menuItems.length)
		{
			var iconBg = iconBgs.get(menuItems[i]);
			if(iconBg != null && isPointInRect(mouseX, mouseY, iconBg))
			{
				hoveredIndex = i;
				break;
			}
		}
		
		// 鼠标移动到选项时立即切换选择
		if(hoveredIndex != -1 && hoveredIndex != curSelected)
		{
			// 鼠标操作不影响键盘输入模式，只是视觉反馈
			curSelected = hoveredIndex;
			updateSelectionVisual();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		
		// 鼠标点击直接执行
		if(FlxG.mouse.justPressed && hoveredIndex != -1)
		{
			executeMenuItem();
		}
	}
	
	function updateDebugMouseHover(mouseX:Float, mouseY:Float)
	{
		var hoveredIndex = -1;
		
		// 检查鼠标在哪个选项上
		for(i in 0...debugBgs.length)
		{
			var optionBg = debugBgs[i];
			if(optionBg != null && isPointInRect(mouseX, mouseY, optionBg))
			{
				hoveredIndex = i;
				break;
			}
		}
		
		// 鼠标移动到选项时立即切换选择
		if(hoveredIndex != -1 && hoveredIndex != curDebugOption)
		{
			// 鼠标操作不影响键盘输入模式，只是视觉反馈
			curDebugOption = hoveredIndex;
			updateDebugSelection();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		
		// 鼠标点击直接执行
		if(FlxG.mouse.justPressed && hoveredIndex != -1)
		{
			executeDebugOption();
		}
	}
	
	// ========== 普通模式更新（键盘） ==========
	function updateNormalMode(elapsed:Float)
	{
		// 键盘导航
		if(controls.UI_UP_P) changeSelection(-1);
		if(controls.UI_DOWN_P) changeSelection(1);
		
		// 确认/返回
		if(controls.ACCEPT) executeMenuItem();
		if(controls.BACK) closeMenu();
		
		// 鼠标滚轮（全局）
		if(FlxG.mouse.wheel != 0 && !mouseOverSkipTime && !mouseOverBar)
		{
			var shiftMult = FlxG.keys.pressed.SHIFT ? 3 : 1;
			changeSelection(-shiftMult * FlxG.mouse.wheel);
		}
		
		// 右键退出
		if(FlxG.mouse.justPressedRight)
		{
			closeMenu();
		}
	}
	
	// ========== 调试模式更新（键盘） ==========
	function updateDebugMode(elapsed:Float)
	{
		if(debugTexts.length == 0 || debugOptions.length == 0) return;
		
		// 检查当前是否选择了Skip Time（在调试面板中）
		var skipTimeInDebug = debugOptions.contains('Skip Time') && debugOptions[curDebugOption] == 'Skip Time';
		skipTimeMode = skipTimeInDebug;
		
		// 键盘导航（无论是否在Skip Time调整模式，上下键都应该可用）
		if(controls.UI_UP_P) changeDebugOption(-1);
		if(controls.UI_DOWN_P) changeDebugOption(1);
		
		// Skip Time控制（如果在Skip Time选项上）
		if(skipTimeMode)
		{
			// 左右键调整时间
			if(controls.UI_LEFT_P || controls.UI_RIGHT_P)
			{
				updateSkipTimeControls(elapsed);
			}
			
			// 同时支持持续按住调整
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
		
		// 确认/返回
		if(controls.ACCEPT) executeDebugOption();
		if(controls.BACK) closeMenu();
		
		// 鼠标滚轮（全局，除了Skip Time区域）
		if(FlxG.mouse.wheel != 0 && !mouseOverSkipTime && !mouseOverBar)
		{
			var shiftMult = FlxG.keys.pressed.SHIFT ? 3 : 1;
			changeDebugOption(-shiftMult * FlxG.mouse.wheel);
		}
		
		// 右键退出
		if(FlxG.mouse.justPressedRight)
		{
			closeMenu();
		}
	}
	
	// ========== 难度模式更新 ==========
	function updateDifficultyMode(elapsed:Float)
	{
		updateDifficultyHover();
		
		// 键盘导航
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
		
		// 确认/返回
		if(controls.ACCEPT) executeDifficultyAction();
		if(controls.BACK) exitDifficultyMode();
		
		// 右键退出
		if(FlxG.mouse.justPressedRight)
		{
			exitDifficultyMode();
		}
	}
	
	function updateDifficultyHover()
	{
		var mouseX = FlxG.mouse.screenX;
		var mouseY = FlxG.mouse.screenY;
		var hoveredIndex = -1;
		
		for(i in 0...difficultyChoices.length)
		{
			var textBg = difficultyBgs.get(difficultyChoices[i]);
			if(textBg != null && isPointInRect(mouseX, mouseY, textBg))
			{
				hoveredIndex = i;
				break;
			}
		}
		
		// 鼠标移动到选项时立即切换选择
		if(hoveredIndex != -1 && hoveredIndex != curSelected)
		{
			curSelected = hoveredIndex;
			updateDifficultySelection();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		
		// 鼠标点击直接执行
		if(FlxG.mouse.justPressed && hoveredIndex != -1)
		{
			executeDifficultyAction();
		}
	}
	
	// ========== 辅助函数 ==========
	function isPointInRect(x:Float, y:Float, sprite:FlxSprite):Bool
	{
		return x >= sprite.x && x <= sprite.x + sprite.width &&
			   y >= sprite.y && y <= sprite.y + sprite.height;
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
		// 注意：debugTexts[0]是标题，所以从1开始
		for(i in 1...debugTexts.length)
		{
			var text = debugTexts[i];
			var optionIndex = i - 1; // 转换为选项索引
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
	
	// ========== Skip Time控制系统（参考原PauseMenu逻辑） ==========
	function updateSkipTimeControls(elapsed:Float)
	{
		// 左右键调整时间
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
		
		// 边界检查
		if(curTime >= FlxG.sound.music.length) 
			curTime = FlxG.sound.music.length - 1000;
		else if(curTime < 0) 
			curTime = 0;
	}
	
	function adjustSkipTime(amount:Float)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curTime += amount;
		
		// 边界检查
		if(curTime >= FlxG.sound.music.length) 
			curTime = FlxG.sound.music.length - 1000;
		else if(curTime < 0) 
			curTime = 0;
		
		updateSkipTimeText();
		updateSkipTimeBarFill();
	}
	
	// ========== Skip Time可见性控制 ==========
	function updateSkipTimeVisibility()
	{
		// 歌曲开始时才显示Skip Time
		skipTimeVisible = !PlayState.instance.startingSong && (PlayState.chartingMode || PlayState.instance.practiceMode || PlayState.instance.cpuControlled);
		
		if(skipTimeText != null)
		{
			skipTimeText.visible = skipTimeVisible;
			skipTimeTextBg.visible = skipTimeVisible;
			skipTimeBar.visible = skipTimeVisible;
			skipTimeBarFill.visible = skipTimeVisible;
		}
	}
	
	// ========== 调试面板显示控制 ==========
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
		
		// 更新Skip Time显示
		updateSkipTimeDisplay();
	}
	
	function shouldShowSkipTime():Bool
	{
		// 只在调试面板显示Skip Time
		return debugPanelVisible && debugOptions.contains('Skip Time') && skipTimeVisible;
	}
	
	function updateSkipTimeDisplay()
	{
		// Skip Time 在满足基本可见性时总是可见（调试面板只决定位置），确保鼠标交互可用
		if(skipTimeText != null)
		{
			skipTimeText.visible = skipTimeVisible;
			skipTimeTextBg.visible = skipTimeVisible;
			skipTimeBar.visible = skipTimeVisible;
			skipTimeBarFill.visible = skipTimeVisible;
		}
		updateSkipTimePosition();
	}
	
	// ========== Skip Time UI位置更新 ==========
	function updateSkipTimePosition()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		// 如果调试面板中有Skip Time选项，将其定位到对应位置
		if(debugPanelVisible && debugOptions.contains('Skip Time') && skipTimeVisible)
		{
			var skipTimeIndex = debugOptions.indexOf('Skip Time');
			if(skipTimeIndex != -1 && skipTimeIndex < debugBgs.length)
			{
				var bg = debugBgs[skipTimeIndex];
				if(bg != null)
				{
					// 进度条位置
					skipTimeBar.x = bg.x + bg.width + 60;
					skipTimeBar.y = bg.y + bg.height / 2 - 4;
					
					// 时间文本位置（在进度条上方）
					skipTimeText.x = skipTimeBar.x;
					skipTimeText.y = skipTimeBar.y - 40;
					skipTimeText.visible = true;
					
					// 更新位置跟踪器
					skipTimeTracker.x = bg.x;
					skipTimeTracker.y = bg.y;
					
					// 更新文本背景
					skipTimeTextBg.x = skipTimeText.x - 10;
					skipTimeTextBg.y = skipTimeText.y - 5;
					skipTimeTextBg.makeGraphic(Std.int(skipTimeText.width + 20), Std.int(skipTimeText.height + 10), 0x00FFFFFF);
					
					// 更新进度条填充位置
					skipTimeBarFill.x = skipTimeBar.x;
					skipTimeBarFill.y = skipTimeBar.y;
				}
			}
		}
		else
		{
			// 如果不在调试面板中显示，将 Skip Time 放在屏幕底部中间
			if(skipTimeVisible)
			{
				skipTimeBar.x = (FlxG.width - skipTimeBar.width) / 2;
				skipTimeBar.y = FlxG.height - 100;
				
				skipTimeText.x = skipTimeBar.x;
				skipTimeText.y = skipTimeBar.y - 40;
				
				// 更新文本背景
				skipTimeTextBg.x = skipTimeText.x - 10;
				skipTimeTextBg.y = skipTimeText.y - 5;
				skipTimeTextBg.makeGraphic(Std.int(skipTimeText.width + 20), Std.int(skipTimeText.height + 10), 0x00FFFFFF);
				
				// 更新进度条填充位置
				skipTimeBarFill.x = skipTimeBar.x;
				skipTimeBarFill.y = skipTimeBar.y;
			}
		}
	}
	
	// 更新进度条填充
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
			// 使用"当前歌曲时间/总歌曲时间"格式
			var current = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false);
			var total = FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
			skipTimeText.text = '$current / $total';
			skipTimeText.updateHitbox();
			
			// 更新文本背景大小
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
		
		// 隐藏侧边栏元素
		toggleSidebarElements(false);
		
		// 不隐藏调试面板，只是降低透明度
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
		
		// 隐藏Skip Time文本
		if(skipTimeText != null)
		{
			skipTimeText.visible = false;
			skipTimeTextBg.visible = false;
			skipTimeBar.visible = false;
			skipTimeBarFill.visible = false;
		}
		
		// 创建难度选择界面
		var panelY:Float = FlxG.height - 220;
		difficultyBg = new FlxSprite(50, panelY).makeGraphic(350, 180, FlxColor.BLACK);
		difficultyBg.alpha = 0;
		difficultyBg.scrollFactor.set();
		add(difficultyBg);
		
		// 创建难度选项
		var startY:Float = panelY + 20;
		for(i in 0...difficultyChoices.length)
		{
			var diffName = difficultyChoices[i];
			var yPos = startY + (i * 35);
			
			// 文本背景
			var textBg = new FlxSprite(70, yPos - 5);
			textBg.makeGraphic(330, 30, 0x00FFFFFF);
			textBg.scrollFactor.set();
			textBg.alpha = 0;
			add(textBg);
			difficultyBgs.set(diffName, textBg);
			
			// 文本
			var diffText = createText(70, yPos, 330, diffName, 24, FlxColor.WHITE);
			diffText.alpha = 0;
			difficultyTexts.set(diffName, diffText);
		}
		
		// 淡入动画
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
		
		// 淡出难度界面
		fadeOutDifficultyUI();
		
		// 显示侧边栏元素
		toggleSidebarElements(true);
		
		// 恢复调试面板透明度
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
		
		// 更新Skip Time显示
		updateSkipTimeDisplay();
		
		// 重置选择
		curSelected = 0;
		updateSelectionVisual();
	}
	
	function toggleSidebarElements(visible:Bool)
	{
		// 图标和图标背景
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
		
		// 清理难度文本
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
				// 切换调试面板显示（Tool 按钮）
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
		if(skipDragging) return; // 拖拽时不执行
		
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
		
		// 重新初始化调试选项
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
		
		// 重新初始化调试选项
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
		else if(ClientPrefs.data.newFreeplay)
			MusicBeatState.switchState(new NewFreeplayState());
		else
			MusicBeatState.switchState(new FreeplayState());
		
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		PlayState.changedDifficulty = false;
		PlayState.chartingMode = false;
		FlxG.camera.followLerp = 0;
	}
	
	// ========== 关闭动画 ==========
	function closeMenu()
	{
		if(isAnimating) return;
		
		// 如果正在拖拽，先执行跳转
		if(skipDragging && Math.abs(curTime - Conductor.songPosition) > 500)
		{
			handleSkipTimeAction();
		}
		
		isAnimating = true;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		
		// 淡出所有元素
		fadeOutAll();
		
		// 图标滑出
		slideOutIcons();
		
		// 侧边栏滑出（使用 safeTween）
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
		// 背景
		if(bg != null) FlxTween.tween(bg, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		if(backdrop != null) FlxTween.tween(backdrop, {alpha: 0}, FADE_TIME, {ease: FlxEase.quadOut});
		
		// Skip Time UI
		if(skipTimeText != null) FlxTween.tween(skipTimeText, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		if(skipTimeTextBg != null) FlxTween.tween(skipTimeTextBg, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		if(skipTimeBar != null) FlxTween.tween(skipTimeBar, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		if(skipTimeBarFill != null) FlxTween.tween(skipTimeBarFill, {alpha: 0}, FADE_TIME * 0.8, {ease: FlxEase.quadOut});
		
		// 信息面板
		var infoElements = [infoPanelBg, levelInfo, levelDifficulty, blueballedTxt, practiceText, chartingText];
		for(element in infoElements) if(element != null) fadeOutElement(element);
		
		// 调试面板
		if(debugPanel != null) fadeOutElement(debugPanel);
		for(text in debugTexts) fadeOutElement(text);
		for(bg in debugBgs) fadeOutElement(bg);
		
		// 难度界面
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
			// 如果是坐标属性，确保目标值为数字；如果不是数字将根据对象当前值做修正
			if(key == 'x' || key == 'y')
			{
				// 如果传入目标值不是数字，则跳过该目标值
				if(!Math.isFinite(cast val)) continue;
				// 如果对象当前的起始值不是数字，则跳过该属性以避免 VarTween 异常
				if(Reflect.hasField(target, key))
				{
					var cur = Reflect.field(target, key);
					if(!Math.isFinite(cast cur)) continue;
				}
			}
			Reflect.setField(filtered, key, val);
		}
		// 如果没有可 tween 的字段则跳过
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
		if(pauseMusic != null)
		{
			pauseMusic.stop();
			pauseMusic.destroy();
		}
		
		super.destroy();
	}
}