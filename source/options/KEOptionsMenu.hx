package options;

import flixel.math.FlxRect;
import flixel.input.gamepad.FlxGamepad;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import states.MainMenuState;
import backend.MusicBeatState;
import backend.StageData;

class KEOptionsMenu extends MusicBeatState
{
	public static var instance:KEOptionsMenu;

	public var background:FlxSprite;
	public var bg:FlxSprite;
	public var selectedCat:KEOptionCata;
	public var selectedOption:KEOption;
	public var selectedCatIndex:Int = 0;
	public var selectedOptionIndex:Int = 0;
	public var options:Array<KEOptionCata>;
	public static var isInPause:Bool = false;
	public var shownStuff:FlxTypedGroup<FlxText>;
	public static var visibleRange:Array<Int> = [164, 640];
	public static var onPlayState:Bool = false;
	public static var onMainMenuState:Bool = false;

	var notes:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
	var splashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
	var holdCovers:Array<String> = Mods.mergeAllTextsNamed('images/holdCover/list.txt');
	
	var changedOption:Bool = false;
	public var descText:FlxText;
	public var descBack:FlxSprite;

	var scrollOffset:Int = 0;
	var maxScrollOffset:Int = 0;
	
	var isClosing:Bool = false;
	var closeTimer:FlxTimer;
	
	// 长按滚动变量 - 只用于上下滚动
	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;
	var scrollHoldTime:Float = 0;
	
	// 防二次点击保护
	var optionClickCooldown:Float = 0;
	var optionClickProtected:Bool = false;
	
	// 可见选项数量
	static var VISIBLE_OPTIONS:Int = 10;

	public function new(pauseMenu:Bool = false)
	{
		super();

		isInPause = pauseMenu;
		notes.insert(0, ClientPrefs.defaultData.noteSkin);
		splashes.insert(0, ClientPrefs.defaultData.splashSkin);
		holdCovers.insert(0, ClientPrefs.defaultData.holdCoverSkin);
	}

	override function create()
	{
		super.create();

		// 创建完整的选项分类
		options = [
			new KEOptionCata(50, 40, "Gameplay", getGameplayOptions()),
			new KEOptionCata(345, 40, "Appearance", getAppearanceOptions()),
			new KEOptionCata(640, 40, "Visuals", getVisualsOptions()),
			new KEOptionCata(935, 40, "Controls", getControlsOptions()),
			new KEOptionCata(50, 104, "Advanced", getAdvancedOptions())
		];

		shownStuff = new FlxTypedGroup<FlxText>();

		// 创建彩色背景
		background = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		background.screenCenter();
		background.alpha = 0;
		background.scrollFactor.set();
		add(background);

		bg = new FlxSprite(50, 40).makeGraphic(1180, 640, FlxColor.BLACK);
		bg.alpha = 0.5;
		bg.scrollFactor.set();
		add(bg);

		descBack = new FlxSprite(50, 642).makeGraphic(1180, 38, FlxColor.BLACK);
		descBack.alpha = 0.5;
		descBack.scrollFactor.set();
		add(descBack);

		add(shownStuff);

		for (i in 0...options.length)
		{
			var cat = options[i];
			cat.alpha = 0.3;
			cat.titleObject.alpha = 0.7;
			add(cat);
			add(cat.titleObject);
		}

		descText = new FlxText(62, 648);
		descText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 2;
		descText.alpha = 1;
		add(descText);

		// 初始化第一个分类
		selectedCat = options[0];
		doSwitchToCat(selectedCat, false);

		// 开始渐入动画
		

		var colorArray:Array<FlxColor> = [
			FlxColor.fromRGB(148, 0, 211),
			FlxColor.fromRGB(75, 0, 130),
			FlxColor.fromRGB(0, 0, 255),
			FlxColor.fromRGB(0, 255, 0),
			FlxColor.fromRGB(255, 255, 0),
			FlxColor.fromRGB(255, 127, 0),
			FlxColor.fromRGB(255, 0, 0)
		];

		// 按顺序渐变而不是随机
		var currentColorIndex:Int = 0;
		var nextColorIndex:Int = 1;
		var colorTransitionTime:Float = 2.5;

		// 设置初始颜色
		background.color = colorArray[currentColorIndex];

		// 开始颜色渐变循环
		function startColorCycle():Void
		{
			FlxTween.color(background, colorTransitionTime, background.color, colorArray[nextColorIndex], {
				onComplete: function(twn:FlxTween)
				{
					// 更新颜色索引
					currentColorIndex = nextColorIndex;
					nextColorIndex = (nextColorIndex + 1) % colorArray.length;
					
					// 继续下一个渐变
					startColorCycle();
				}
			});
		}

		instance = this;
		// 开始循环
		startColorCycle();
	}
	

	override function destroy()
{
	super.destroy();
	instance = null;
}

	// Gameplay 选项
	function getGameplayOptions():Array<KEOption>
	{
		return [
			KEOption.create("Downscroll", "Notes scroll downwards instead of upwards", "downScroll", "bool"),
			KEOption.create("Middlescroll", "Put your lane in the center", "middleScroll", "bool"),
			KEOption.create("Opponent Notes", "Show opponent's strumline", "opponentStrums", "bool"),
			KEOption.create("Ghost Tapping", "Allow pressing keys without missing", "ghostTapping", "bool"),
			KEOption.create("Auto Pause", "Pause when window loses focus", "autoPause", "bool"),
			KEOption.create("Disable Reset", "Disable the reset button", "noReset", "bool"),
			KEOption.create("Guitar Hero Sustains", "Sustains count as one note", "guitarHeroSustains", "bool"),
			KEOption.create("Hitsound Volume", "Volume of hit sounds", "hitsoundVolume", "float", 0, 0, 1, 0.1),
			KEOption.create("Rating Offset", "Adjust note hit timing", "ratingOffset", "int", 0, -30, 30, 1),
			KEOption.create("Sick Window", "Timing window for SICK", "sickWindow", "float", 45, 15, 45, 0.1),
			KEOption.create("Good Window", "Timing window for GOOD", "goodWindow", "float", 90, 15, 90, 0.1),
			KEOption.create("Bad Window", "Timing window for BAD", "badWindow", "float", 135, 15, 135, 0.1),
			KEOption.create("Safe Frames", "Frames for early/late hits", "safeFrames", "float", 10, 2, 10, 0.1)
		];
	}

	// Appearance 选项
	function getAppearanceOptions():Array<KEOption>
	{
		return [
			KEOption.create("Low Quality", "Reduce graphics for performance", "lowQuality", "bool"),
			KEOption.create("Anti-Aliasing", "Smoother visuals", "antialiasing", "bool"),
			KEOption.create("Shaders", "Enable shader effects", "shaders", "bool"),
			KEOption.create("GPU Caching", "Use GPU for texture caching", "cacheOnGPU", "bool"),
			KEOption.create("FPS Counter", "Show FPS counter", "showFPS", "bool"),
			KEOption.create("Framerate", "Target framerate", "framerate", "int", 60, 60, 240, 1)
		];
	}

	// Visuals 选项
	function getVisualsOptions():Array<KEOption>
	{
		return [
			KEOption.create("Hide HUD", "Hide most HUD elements", "hideHud", "bool"),
			KEOption.create("Flashing Lights", "Enable screen flashes", "flashing", "bool"),
			KEOption.create("Camera Zooms", "Zoom camera on beat", "camZooms", "bool"),
			KEOption.create("Score Zoom", "Grow score text on hit", "scoreZoom", "bool"),
			KEOption.create('Time Bar:',"What should the Time Bar display?","timeBarType","string",['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']),
			KEOption.create("Health Bar Alpha", "Health bar transparency", "healthBarAlpha", "float", 1, 0, 1, 0.1),
			KEOption.create("Note Skins" , "Select your prefered Note skin", "noteSkin","string" , notes),
			KEOption.create("Note Splashes", "Select your prefered Note Splash variation","splashSkin","string", splashes),
			KEOption.create("Note HoldCover", "Select your prefered Note Hold Cover","holdCoverSkin","string", holdCovers),
			KEOption.create("Note Alpha", "Note transparency", "noteAlpha", "float", 0.6, 0, 1, 0.1),
			KEOption.create("Note Splash Alpha", "Note splash transparency", "splashAlpha", "float", 0.6, 0, 1, 0.1),
			KEOption.create("Combo Stacking", "Stack combo numbers", "comboStacking", "bool"),
			KEOption.create("Center Pause", "Center pause menu", "centerPause", "bool"),
			KEOption.create("Custom Color", "Color timebar by opponent", "customColor", "bool"),
			KEOption.create("Gradient TimeBar", "Gradient colored timebar", "gradientTimeBar", "bool"),
			KEOption.create("Health Text", "Show health as number", "healthText", "bool"),
			KEOption.create("Song Text", "Show song info watermark", "songText", "bool"),
			KEOption.create("Score Screen", "Show Kade-style results", "scoreScreen", "bool"),
			KEOption.create("NoteHits Counter", "Show note hits counter", "Counter", "bool"),
			KEOption.create("Discord RPC", "Enable Discord Rich Presence", "discordRPC", "bool")
		];
	}

	// Controls 选项
	function getControlsOptions():Array<KEOption>
	{
		return [
			KEOption.create("Open Note Colors", "Customize note colors", "", "action"),
			KEOption.create("Open Controls", "Customize key bindings", "", "action"),
			KEOption.create("Open KE Styled KeyBinds", "Customize key bindings in KE Styled Menu", "", "action"),
			KEOption.create("Adjust Delay and Combo", "Customize ingame experience", "", "action"),   
			KEOption.create("Reset KeyBinds", "Reset to default keys", "", "action"),
			KEOption.create("Reset Key", "Reset keybind", "reset", "keybind")
		];
	}

	// Advanced 选项
	function getAdvancedOptions():Array<KEOption>
	{
		return [
			KEOption.create("Enable Replay", "[Score Menu and Replay Required]", "saveReplays", "bool"),
			//KEOption.create("Replay Manager", "Manage and view ur Replays", "", "action"),
			KEOption.create("KE Styled Settings", "Use KE style options", "keOptions", "bool"),
			KEOption.create("Check Updates", "Check for game updates", "checkForUpdates", "bool"),
			KEOption.create("Loading Screen", "Show loading screen", "loadingScreen", "bool"),
			KEOption.create("Reset Settings", "Reset all settings to default [DO NOT APPLY IT UNLESS YOU KNOW WHAT YOU ARE DOING]", "", "action"),
			KEOption.create("Reset Scores", "Clear all high scores [DO NOT APPLY IT UNLESS YOU KNOW WHAT YOU ARE DOING]", "", "action")
		];
	}

	// 分类切换函数
	public function doSwitchToCat(cat:KEOptionCata, checkForOutOfBounds:Bool = true)
	{
		// 重置滚动
		scrollOffset = 0;
		
		// 清除前一个分类的高亮
		if (selectedCat != null && selectedCat.optionObjects != null)
		{
			for (i in 0...selectedCat.optionObjects.members.length)
			{
				var object = selectedCat.optionObjects.members[i];
				if(object != null && i < selectedCat.options.length) {
					object.text = selectedCat.options[i].getValue();
					object.color = FlxColor.WHITE; // 重置颜色
				}
			}
		}

		if (checkForOutOfBounds && selectedCatIndex > options.length - 1)
			selectedCatIndex = 0;

		if (selectedCat != null && selectedCat.middle)
			remove(selectedCat.titleObject);

		if (selectedCat != null) {
			selectedCat.changeColor(FlxColor.BLACK);
			selectedCat.alpha = 0.3;
			if (selectedCat.titleObject != null)
			{
				selectedCat.titleObject.color = FlxColor.WHITE;
				selectedCat.titleObject.alpha = 0.6;
			}
		}

		// 清空显示的内容
		shownStuff.clear();
		
		// 设置新分类
		selectedCat = cat;
		selectedCat.alpha = 0.2;
		selectedCat.changeColor(FlxColor.WHITE);

		if (selectedCat.middle)
			add(selectedCat.titleObject);

		// 添加选项对象到显示组
		for (i in selectedCat.optionObjects)
		{
			if(i != null) 
			{
				shownStuff.add(i);
				i.color = FlxColor.WHITE; // 确保初始颜色正确
			}
		}

		// 设置默认选项
		if(selectedCat.options.length > 0) {
			selectedOption = selectedCat.options[0];
			selectedOptionIndex = 0;
		}

		// 计算最大滚动偏移
		maxScrollOffset = Std.int(Math.max(0, selectedCat.options.length - VISIBLE_OPTIONS));
		
		// 更新可见性并选择当前选项
		updateOptionPositions();
		doSelectCurrentOption();
	}

	// 选项选择函数
	public function doSelectCurrentOption()
	{
		// 清除所有选项的 > 符号
		for (i in 0...selectedCat.optionObjects.members.length)
		{
			var object = selectedCat.optionObjects.members[i];
			if(object != null && i < selectedCat.options.length) {
				var currentValue = selectedCat.options[i].getValue();
				// 移除可能存在的 > 符号
				if (currentValue.startsWith("> ")) {
					object.text = currentValue.substring(2);
				} else {
					object.text = currentValue;
				}
			}
		}
		
		// 为当前选中的选项添加 > 符号
		var object = selectedCat.optionObjects.members[selectedOptionIndex];
		if(object != null) {
			var currentValue = selectedOption.getValue();
			// 检查是否已经包含 > 符号
			if (!currentValue.startsWith("> ")) {
				object.text = "> " + currentValue;
			} else {
				object.text = currentValue;
			}
			descText.text = selectedOption.getDescription();
			descText.color = FlxColor.WHITE;
		}
		
		// 确保选中项在可见区域内
		ensureOptionVisible();
	}

	// 更新选项位置
	function updateOptionPositions()
	{
		if (selectedCat == null || selectedCat.optionObjects == null) return;
		
		for (i in 0...selectedCat.optionObjects.members.length)
		{
			var optionText = selectedCat.optionObjects.members[i];
			if(optionText == null) continue;
			
			// 计算相对于滚动偏移的位置
			var displayIndex = i - scrollOffset;
			optionText.y = 120 + 54 + (46 * displayIndex);
			
			// 判断是否在可见区域内
			var isVisible = (displayIndex >= 0 && displayIndex < VISIBLE_OPTIONS);
			
			if (isVisible)
			{
				// 在可见区域内
				if (i == selectedOptionIndex)
				{
					optionText.alpha = 1.0;
				}
				else
				{
					optionText.alpha = 0.6;
				}
			}
			else
			{
				// 不在可见区域内，完全隐藏
				optionText.alpha = 0;
			}
		}
	}

	// 确保选中项可见
	private function ensureOptionVisible()
	{
		if (selectedOptionIndex < scrollOffset) {
			// 选中项在滚动区域上方，向上滚动
			scrollOffset = selectedOptionIndex;
			updateOptionPositions();
		} else if (selectedOptionIndex >= scrollOffset + VISIBLE_OPTIONS) {
			// 选中项在滚动区域下方，向下滚动
			scrollOffset = selectedOptionIndex - (VISIBLE_OPTIONS - 1);
			updateOptionPositions();
		}
	}

	// 滚动函数 - 支持长按
	function scrollOptions(change:Int, isLongPress:Bool = false)
	{
		if (selectedCat == null || selectedCat.options.length <= VISIBLE_OPTIONS) return;
		
		var newOffset = scrollOffset + change;
		
		// 限制滚动范围
		if (newOffset < 0) newOffset = 0;
		if (newOffset > maxScrollOffset) newOffset = maxScrollOffset;
		
		// 如果滚动位置没有变化，直接返回
		if (newOffset == scrollOffset) return;
		
		scrollOffset = newOffset;
		
		// 更新位置
		updateOptionPositions();
		
		// 如果选中项不再可见，调整选中项索引
		if (selectedOptionIndex < scrollOffset) {
			selectedOptionIndex = scrollOffset;
			selectedOption = selectedCat.options[selectedOptionIndex];
			doSelectCurrentOption();
		} else if (selectedOptionIndex >= scrollOffset + VISIBLE_OPTIONS) {
			selectedOptionIndex = scrollOffset + (VISIBLE_OPTIONS - 1);
			selectedOption = selectedCat.options[selectedOptionIndex];
			doSelectCurrentOption();
		}
		
		// 长按时降低音量和频率
		if (!isLongPress) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		} else if (scrollHoldTime % 2 == 0) { // 长按时每2帧播放一次音效
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
		}
	}

	// 更新函数
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// 更新点击保护计时器
		if (optionClickCooldown > 0) {
			optionClickCooldown -= elapsed;
			if (optionClickCooldown <= 0) {
				optionClickProtected = false;
			}
		}
		
		// 显示鼠标
		FlxG.mouse.visible = true;

		// 退出检测 - 添加鼠标右键支持
		if (!isClosing && (controls.BACK || FlxG.mouse.justPressedRight))
		{
			if(onMainMenuState && !onPlayState)
			{
				MusicBeatState.switchState(new MainMenuState());
				onMainMenuState = false;
			}
			else if(onPlayState)
			{
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else if(!ClientPrefs.data.keOptions && onMainMenuState)
			{
				MusicBeatState.switchState(new MainMenuState());
				onMainMenuState = false;
			}
		}

		// 如果正在关闭，不处理其他输入
		if (isClosing) return;

		#if !mobile
		var hoveredOptionIndex = -1;
		var hoveredCatIndex = -1;
		var hoveredOptionIsValue:Null<KEOption> = null;
		
		// 检查鼠标悬停在分类上
		for (i in 0...options.length)
		{
			var cat = options[i];
			if (cat != null && cat.titleObject != null && FlxG.mouse.overlaps(cat.titleObject))
			{
				hoveredCatIndex = i;
				break;
			}
		}
		
		// 检查鼠标悬停在选项上
		if (selectedCat != null && selectedCat.optionObjects != null)
		{
			for (i in 0...selectedCat.optionObjects.members.length)
			{
				var optionText = selectedCat.optionObjects.members[i];
				if (optionText == null || optionText.alpha == 0) continue;
				
				if (FlxG.mouse.overlaps(optionText))
				{
					hoveredOptionIndex = i;
					if (i < selectedCat.options.length) {
						hoveredOptionIsValue = selectedCat.options[i];
					}
					break;
				}
			}
		}
		
		// 更新分类悬停效果 - 修复透明度问题
		for (i in 0...options.length)
		{
			var cat = options[i];
			if (cat != null && cat.titleObject != null)
			{
				if (i == selectedCatIndex)
				{
					// 当前选中分类 - 保持原本效果
					cat.titleObject.color = FlxColor.WHITE;
					cat.titleObject.alpha = 1; // 选中分类完全不透明
				}
				else if (i == hoveredCatIndex)
				{
					// 鼠标悬停分类 - 黄色高亮，保持原本透明度
					cat.titleObject.color = FlxColor.YELLOW;
					cat.titleObject.alpha = 0.6; // 保持原本的透明度
				}
				else
				{
					// 其他分类 - 恢复原本效果
					cat.titleObject.color = FlxColor.WHITE;
					cat.titleObject.alpha = 0.6; // 原本的透明度
				}
			}
		}
		
		// 先调用 updateOptionPositions 设置基础透明度
		updateOptionPositions();
		
		// 然后应用悬停效果（只修改颜色，不修改透明度）
		if (selectedCat != null && selectedCat.optionObjects != null)
		{
			for (i in 0...selectedCat.optionObjects.members.length)
			{
				var optionText = selectedCat.optionObjects.members[i];
				if (optionText == null || optionText.alpha == 0) continue;
				
				if (i == selectedOptionIndex)
				{
					// 当前选中选项 - 保持高亮
					optionText.color = FlxColor.WHITE;
					// 透明度由 updateOptionPositions 控制
				}
				else if (i == hoveredOptionIndex)
				{
					// 鼠标悬停选项 - 只改变颜色，保持原本透明度
					optionText.color = FlxColor.YELLOW;
					// 透明度由 updateOptionPositions 控制
				}
				else
				{
					// 其他选项 - 恢复白色
					optionText.color = FlxColor.WHITE;
					// 透明度由 updateOptionPositions 控制
				}
			}
		}
		
		// 鼠标滚轮支持 - 只在悬停在数值选项上时调整数值
		if (FlxG.mouse.wheel != 0)
		{
			if (hoveredOptionIsValue != null && hoveredOptionIsValue.getAccept() && (hoveredOptionIsValue.type == "int" || hoveredOptionIsValue.type == "float" || hoveredOptionIsValue.type == "string"))
			{
				// 鼠标在数值选项上：滚轮调整数值
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				
				// 设置当前选中选项为悬停的选项
				selectedOptionIndex = hoveredOptionIndex;
				selectedOption = hoveredOptionIsValue;
				
				// 确保可见并更新显示
				ensureOptionVisible();
				updateOptionPositions();
				doSelectCurrentOption();
				
				// 根据滚轮方向调整数值
				if (FlxG.mouse.wheel < 0) {
					// 向下滚动：减小值
					selectedOption.left();
				} else {
					// 向上滚动：增加值
					selectedOption.right();
				}
				
				// 保存设置并更新显示
				ClientPrefs.saveSettings();
				doSelectCurrentOption();
			}
			else
			{
				// 鼠标不在数值选项上：滚轮滚动选项列表
				if (FlxG.mouse.wheel < 0) {
					// 向下滚动：向下移动选择
					handleDownKey(true); // 使用滚动触发
				} else if (FlxG.mouse.wheel > 0) {
					// 向上滚动：向上移动选择
					handleUpKey(true); // 使用滚动触发
				}
			}
		}
		#else
		// 移动端没有鼠标，直接调用 updateOptionPositions
		updateOptionPositions();
		#end

		
		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		var accept = false;
		var right = false;
		var left = false;
		var up = false;
		var down = false;
		var escape = false;
		var rightPressed = false;
		var leftPressed = false;
		var upPressed = false;
		var downPressed = false;

		changedOption = false;

		accept = FlxG.keys.justPressed.ENTER || (gamepad != null ? gamepad.justPressed.A : false);
		right = FlxG.keys.justPressed.RIGHT || (gamepad != null ? gamepad.justPressed.DPAD_RIGHT : false);
		left = FlxG.keys.justPressed.LEFT || (gamepad != null ? gamepad.justPressed.DPAD_LEFT : false);
		up = FlxG.keys.justPressed.UP || (gamepad != null ? gamepad.justPressed.DPAD_UP : false);
		down = FlxG.keys.justPressed.DOWN || (gamepad != null ? gamepad.justPressed.DPAD_DOWN : false);
		rightPressed = FlxG.keys.pressed.RIGHT || (gamepad != null ? gamepad.pressed.DPAD_RIGHT : false);
		leftPressed = FlxG.keys.pressed.LEFT || (gamepad != null ? gamepad.pressed.DPAD_LEFT : false);
		upPressed = FlxG.keys.pressed.UP || (gamepad != null ? gamepad.pressed.DPAD_UP : false);
		downPressed = FlxG.keys.pressed.DOWN || (gamepad != null ? gamepad.pressed.DPAD_DOWN : false);
		escape = FlxG.keys.justPressed.ESCAPE || (gamepad != null ? gamepad.justPressed.B : false);
		
		// 鼠标点击分类标签切换分类
		for (i in 0...options.length)
		{
			var cat = options[i];
			if (FlxG.mouse.overlaps(cat.titleObject) && FlxG.mouse.justPressed)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				selectedCatIndex = i;
				doSwitchToCat(options[selectedCatIndex]);
				break;
			}
		}

		// 鼠标点击选项 - 添加防二次点击保护
		if (selectedCat != null && selectedCat.optionObjects != null && FlxG.mouse.justPressed && !optionClickProtected)
		{
			var mousePos = FlxG.mouse.getScreenPosition(camera);
			
			for (i in 0...selectedCat.optionObjects.members.length)
			{
				var optionText = selectedCat.optionObjects.members[i];
				if (optionText == null || optionText.alpha == 0) continue;
				
				var option = selectedCat.options[i];
				if (option == null) continue;
				
				// 检测是否点击了选项文本
				if (FlxG.mouse.overlaps(optionText))
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					
					// 设置新选项并更新高亮
					selectedOptionIndex = i;
					selectedOption = option;
					
					// 确保可见并更新显示
					ensureOptionVisible();
					updateOptionPositions();
					doSelectCurrentOption();
					
					// 对于布尔选项，点击文本直接切换
					if (!option.getAccept()) {
						option.press();
						ClientPrefs.saveSettings();
						doSelectCurrentOption();
					}
					
					// 设置点击保护
					optionClickProtected = true;
					optionClickCooldown = 0.2; // 200毫秒保护时间
					break;
				}
				
				// 检测是否点击了左右调整区域
				if (option.getAccept()) {
					var leftArea = new FlxRect(optionText.x - 40, optionText.y, 40, optionText.height);
					var rightArea = new FlxRect(optionText.x + optionText.fieldWidth, optionText.y, 40, optionText.height);
					
					if (leftArea.containsPoint(mousePos)) {
						FlxG.sound.play(Paths.sound('scrollMenu'));
						selectedOptionIndex = i;
						selectedOption = option;
						
						// 确保可见并更新显示
						ensureOptionVisible();
						updateOptionPositions();
						doSelectCurrentOption();
						
						option.left();
						ClientPrefs.saveSettings();
						doSelectCurrentOption();
						
						// 设置点击保护
						optionClickProtected = true;
						optionClickCooldown = 0.2; // 200毫秒保护时间
						break;
					} else if (rightArea.containsPoint(mousePos)) {
						FlxG.sound.play(Paths.sound('scrollMenu'));
						selectedOptionIndex = i;
						selectedOption = option;
						
						// 确保可见并更新显示
						ensureOptionVisible();
						updateOptionPositions();
						doSelectCurrentOption();
						
						option.right();
						ClientPrefs.saveSettings();
						doSelectCurrentOption();
						
						// 设置点击保护
						optionClickProtected = true;
						optionClickCooldown = 0.2; // 200毫秒保护时间
						break;
					}
				}
			}
		}
		
		// 处理上下键 - 短按和长按分离
		if (up) {
			handleUpKey(false);
		}
		if (down) {
			handleDownKey(false);
		}
		
		// 处理长按上下滚动
		if (upPressed) {
			holdUpTime += elapsed;
			if (holdUpTime > 0.3) { // 0.3秒后开始连续滚动
				scrollHoldTime++;
				if (scrollHoldTime % 3 == 0) { // 控制滚动速度
					handleUpKey(true); // true表示是长按
				}
			}
		} else {
			holdUpTime = 0;
		}
		
		if (downPressed) {
			holdDownTime += elapsed;
			if (holdDownTime > 0.3) { // 0.3秒后开始连续滚动
				scrollHoldTime++;
				if (scrollHoldTime % 3 == 0) { // 控制滚动速度
					handleDownKey(true); // true表示是长按
				}
			}
		} else {
			holdDownTime = 0;
		}
		
		if (!upPressed && !downPressed) {
			scrollHoldTime = 0;
		}

		// 处理长按左右调整数值
		var optionChangedByHold = false;
		if (selectedOption != null && selectedOption.getAccept()) {
			// 只传递左右键状态，上下键由菜单处理
			optionChangedByHold = selectedOption.updateHold(elapsed, leftPressed, rightPressed);
			if (optionChangedByHold) {
				ClientPrefs.saveSettings();
				doSelectCurrentOption();
			}
		}

		// 左右键逻辑 - 短按（长按在上面处理）
		if (right && !optionChangedByHold)
		{
			handleRightKey();
		}
		else if (left && !optionChangedByHold)
		{
			handleLeftKey();
		}

		// 回车键
		if (accept)
		{
			var shouldKeepState = selectedOption.press();
			if (shouldKeepState)
			{
				ClientPrefs.saveSettings();
				doSelectCurrentOption();
			}
		}
	}
	
	// 处理上键
	private function handleUpKey(isLongPress:Bool = false)
	{
		if (selectedCat == null || selectedCat.options.length == 0) return;
		
		if (selectedOptionIndex > 0) {
			selectedOptionIndex--;
			selectedOption = selectedCat.options[selectedOptionIndex];
			
			// 确保选中项可见
			ensureOptionVisible();
			
			// 更新显示
			doSelectCurrentOption();
			
			if (!isLongPress) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			}
		} else if (isLongPress && scrollOffset > 0) {
			// 如果在顶部且长按，向上滚动
			scrollOptions(-1, isLongPress);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		}
	}
	
	// 处理下键
	private function handleDownKey(isLongPress:Bool = false)
	{
		if (selectedCat == null || selectedCat.options.length == 0) return;
		
		if (selectedOptionIndex < selectedCat.options.length - 1) {
			selectedOptionIndex++;
			selectedOption = selectedCat.options[selectedOptionIndex];
			
			// 确保选中项可见
			ensureOptionVisible();
			
			// 更新显示
			doSelectCurrentOption();
			
			if (!isLongPress) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			}
		} else if (isLongPress && scrollOffset < maxScrollOffset) {
			// 如果在底部且长按，向下滚动
			scrollOptions(1, isLongPress);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		}
	}
	
	// 处理右键
	private function handleRightKey()
	{
		if (selectedOption.getAccept())
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			selectedOption.right();
			ClientPrefs.saveSettings();
			doSelectCurrentOption();
		}
		else
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			selectedCatIndex++;
			if (selectedCatIndex >= options.length)
				selectedCatIndex = 0;
			doSwitchToCat(options[selectedCatIndex]);
		}
	}
	
	// 处理左键
	private function handleLeftKey()
	{
		if (selectedOption.getAccept())
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			selectedOption.left();
			ClientPrefs.saveSettings();
			doSelectCurrentOption();
		}
		else
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			selectedCatIndex--;
			if (selectedCatIndex < 0)
				selectedCatIndex = options.length - 1;
			doSwitchToCat(options[selectedCatIndex]);
		}
	}
}
