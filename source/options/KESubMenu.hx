package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxRect;

class KESubMenu extends MusicBeatSubstate
{
	var parentOption:KEOption;
	var options:Array<KEOption>;
	var selectedOptionIndex:Int = 0;
	var selectedOption:KEOption;
	
	var titleText:FlxText;
	var backButton:KEOption;
	var optionTexts:FlxTypedGroup<FlxText>;
	var descText:FlxText;
	
	var bg:FlxSprite;
	var descBack:FlxSprite;
	
	var scrollOffset:Int = 0;
	static var VISIBLE_OPTIONS:Int = 10;
	var maxScrollOffset:Int = 0;
	
	// 动画相关
	var isClosing:Bool = false;
	var tweenDuration:Float = 0.2;
	
	// 长按相关变量
	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;
	var scrollHoldTime:Float = 0;
	
	// 游戏手柄支持
	var gamepad:flixel.input.gamepad.FlxGamepad;
	
	// 点击保护
	var optionClickCooldown:Float = 0;
	var optionClickProtected:Bool = false;
	
	public function new(parentOption:KEOption)
	{
		super();
		this.parentOption = parentOption;
		this.options = parentOption.subMenuOptions.copy();
		
		// 添加返回按钮到选项列表的开头
		backButton = KEOption.create("Back", "Return to previous menu", "", "action");
		this.options.unshift(backButton);
	}
	
	override function create()
	{
		super.create();
		
		// 创建半透明背景
		bg = new FlxSprite(50, 40).makeGraphic(1180, 640, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scrollFactor.set();
		add(bg);
		
		// 标题
		titleText = new FlxText(60, 50, 1160, parentOption.subMenuTitle);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);
		
		// 描述区域背景
		descBack = new FlxSprite(50, 642).makeGraphic(1180, 38, FlxColor.BLACK);
		descBack.alpha = 0.7;
		descBack.scrollFactor.set();
		add(descBack);
		
		// 选项文本
		optionTexts = new FlxTypedGroup<FlxText>();
		add(optionTexts);
		
		// 创建选项文本
		for (i in 0...options.length)
		{
			var optionText = new FlxText(60, 120 + (46 * i), 1160, options[i].getValue());
			optionText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			optionText.borderSize = 2;
			optionText.ID = i;
			optionTexts.add(optionText);
		}
		
		// 描述文本
		descText = new FlxText(62, 648);
		descText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 2;
		add(descText);
		
		// 初始化选择
		selectedOptionIndex = 0;
		selectedOption = options[0];
		maxScrollOffset = Std.int(Math.max(0, options.length - VISIBLE_OPTIONS));
		
		// 设置初始透明度为0，然后渐变显示
		bg.alpha = 0;
		titleText.alpha = 0;
		descBack.alpha = 0;
		descText.alpha = 0;
		
		for (text in optionTexts) {
			text.alpha = 0;
		}
		
		// 简单渐变动画
		FlxTween.tween(bg, {alpha: 0.7}, tweenDuration, {ease: FlxEase.sineOut});
		FlxTween.tween(titleText, {alpha: 1}, tweenDuration, {ease: FlxEase.sineOut});
		FlxTween.tween(descBack, {alpha: 0.7}, tweenDuration, {ease: FlxEase.sineOut});
		FlxTween.tween(descText, {alpha: 1}, tweenDuration, {ease: FlxEase.sineOut});
		
		// 所有选项同时渐变显示
		for (i in 0...optionTexts.length) {
			FlxTween.tween(optionTexts.members[i], {alpha: 0.6}, tweenDuration, {ease: FlxEase.sineOut});
		}
		
		// 播放音效
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		
		// 更新显示
		updateDisplay();
	}
	
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
		
		if (isClosing) return;
		
		// 显示鼠标
		FlxG.mouse.visible = true;
		
		// 退出检测
		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			closeMenu();
			return;
		}
		
		// 鼠标悬停检测
		#if !mobile
		var hoveredIndex = -1;
		
		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText != null && optionText.alpha > 0 && FlxG.mouse.overlaps(optionText))
			{
				hoveredIndex = i;
				break;
			}
		}
		
		// 更新悬停效果 - 参考 KEOptionsMenu 的逻辑
		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText != null && optionText.alpha > 0)
			{
				if (i == selectedOptionIndex)
				{
					// 当前选中项 - 完全不透明
					optionText.alpha = 1.0;
					optionText.color = FlxColor.WHITE;
				}
				else if (i == hoveredIndex)
				{
					// 鼠标悬停项 - 保持透明度，只改变颜色
					optionText.color = FlxColor.YELLOW;
					optionText.alpha = 0.6;
				}
				else
				{
					// 其他项
					optionText.color = FlxColor.WHITE;
					optionText.alpha = 0.6;
				}
			}
		}
		
		// 鼠标滚轮支持
		if (FlxG.mouse.wheel != 0)
		{
			if (hoveredIndex >= 0 && hoveredIndex < options.length) {
				var hoveredOption = options[hoveredIndex];
				if (hoveredOption != backButton && hoveredOption.getAccept() && 
					(hoveredOption.type == "int" || hoveredOption.type == "float" || hoveredOption.type == "string"))
				{
					// 鼠标在数值选项上：滚轮调整数值
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					
					// 设置当前选中选项为悬停的选项
					selectedOptionIndex = hoveredIndex;
					selectedOption = hoveredOption;
					
					// 确保可见并更新显示
					ensureOptionVisible();
					updateDisplay();
					
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
					updateDisplay();
				}
				else
				{
					// 鼠标不在数值选项上：滚轮滚动选项列表
					if (FlxG.mouse.wheel < 0) {
						// 向下滚动：向下移动选择
						handleDownKey();
					} else if (FlxG.mouse.wheel > 0) {
						// 向上滚动：向上移动选择
						handleUpKey();
					}
				}
			}
			else
			{
				// 鼠标不在任何选项上：滚轮滚动选项列表
				if (FlxG.mouse.wheel < 0) {
					// 向下滚动：向下移动选择
					handleDownKey();
				} else if (FlxG.mouse.wheel > 0) {
					// 向上滚动：向上移动选择
					handleUpKey();
				}
			}
		}
		
		// 鼠标点击 - 添加防二次点击保护
		if (FlxG.mouse.justPressed && !optionClickProtected)
		{
			var mousePos = FlxG.mouse.getScreenPosition(camera);
			
			for (i in 0...optionTexts.length)
			{
				var optionText = optionTexts.members[i];
				if (optionText == null || optionText.alpha == 0) continue;
				
				if (FlxG.mouse.overlaps(optionText))
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
					
					// 设置新选项
					selectedOptionIndex = i;
					selectedOption = options[i];
					
					// 确保可见并更新显示
					ensureOptionVisible();
					updateDisplay();
					
					// 对于返回按钮，直接关闭
					if (i == 0) {
						closeMenu();
						return;
					}
					
					// 检测是否点击了左右调整区域
					if (selectedOption.getAccept()) {
						var leftArea = new FlxRect(optionText.x - 40, optionText.y, 40, optionText.height);
						var rightArea = new FlxRect(optionText.x + optionText.fieldWidth, optionText.y, 40, optionText.height);
						
						if (leftArea.containsPoint(mousePos)) {
							selectedOption.left();
							ClientPrefs.saveSettings();
							updateDisplay();
							
							// 设置点击保护
							optionClickProtected = true;
							optionClickCooldown = 0.2;
							break;
						} else if (rightArea.containsPoint(mousePos)) {
							selectedOption.right();
							ClientPrefs.saveSettings();
							updateDisplay();
							
							// 设置点击保护
							optionClickProtected = true;
							optionClickCooldown = 0.2;
							break;
						}
					}
					
					// 点击文本中间
					var shouldKeepState = selectedOption.press();
					if (shouldKeepState) {
						ClientPrefs.saveSettings();
						updateDisplay();
					}
					
					// 设置点击保护
					optionClickProtected = true;
					optionClickCooldown = 0.2;
					break;
				}
			}
		}
		#end
		
		// 键盘和手柄控制
		gamepad = FlxG.gamepads.lastActive;
		
		var accept = FlxG.keys.justPressed.ENTER || (gamepad != null ? gamepad.justPressed.A : false);
		var up = FlxG.keys.justPressed.UP || (gamepad != null ? gamepad.justPressed.DPAD_UP : false);
		var down = FlxG.keys.justPressed.DOWN || (gamepad != null ? gamepad.justPressed.DPAD_DOWN : false);
		var left = FlxG.keys.justPressed.LEFT || (gamepad != null ? gamepad.justPressed.DPAD_LEFT : false);
		var right = FlxG.keys.justPressed.RIGHT || (gamepad != null ? gamepad.justPressed.DPAD_RIGHT : false);
		var upPressed = FlxG.keys.pressed.UP || (gamepad != null ? gamepad.pressed.DPAD_UP : false);
		var downPressed = FlxG.keys.pressed.DOWN || (gamepad != null ? gamepad.pressed.DPAD_DOWN : false);
		var leftPressed = FlxG.keys.pressed.LEFT || (gamepad != null ? gamepad.pressed.DPAD_LEFT : false);
		var rightPressed = FlxG.keys.pressed.RIGHT || (gamepad != null ? gamepad.pressed.DPAD_RIGHT : false);
		
		// 处理长按上下滚动
		if (upPressed) {
			holdUpTime += elapsed;
			if (holdUpTime > 0.3) { // 0.3秒后开始连续滚动
				scrollHoldTime++;
				if (scrollHoldTime % 3 == 0) { // 控制滚动速度
					handleUpKey();
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
					handleDownKey();
				}
			}
		} else {
			holdDownTime = 0;
		}
		
		if (!upPressed && !downPressed) {
			scrollHoldTime = 0;
		}
		
		// 处理上下键 - 短按
		if (up) {
			handleUpKey();
		}
		if (down) {
			handleDownKey();
		}
		
		// 处理长按左右调整数值
		var optionChangedByHold = false;
		if (selectedOption != null && selectedOption != backButton && selectedOption.getAccept()) {
			optionChangedByHold = selectedOption.updateHold(elapsed, leftPressed, rightPressed);
			if (optionChangedByHold) {
				ClientPrefs.saveSettings();
				updateDisplay();
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
			if (selectedOptionIndex == 0) {
				// 返回按钮
				closeMenu();
			} else {
				var shouldKeepState = selectedOption.press();
				if (shouldKeepState) {
					ClientPrefs.saveSettings();
					updateDisplay();
				}
			}
		}
	}
	
	function updateDisplay():Void
	{
		// 清除所有选项的 > 符号
		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText != null && i < options.length)
			{
				var currentValue = options[i].getValue();
				// 移除可能存在的 > 符号
				if (currentValue.startsWith("> ")) {
					optionText.text = currentValue.substring(2);
				} else {
					optionText.text = currentValue;
				}
				
				// 设置位置
				var displayIndex = i - scrollOffset;
				optionText.y = 120 + (46 * displayIndex);
				
				// 判断是否在可见区域内
				var isVisible = (displayIndex >= 0 && displayIndex < VISIBLE_OPTIONS);
				
				// 透明度由 update() 中的悬停逻辑控制，这里只处理位置
				if (!isVisible) {
					optionText.alpha = 0;
				}
			}
		}
		
		// 为当前选中的选项添加 > 符号
		var selectedText = optionTexts.members[selectedOptionIndex];
		if (selectedText != null)
		{
			var currentValue = selectedOption.getValue();
			// 检查是否已经包含 > 符号
			if (!currentValue.startsWith("> ")) {
				selectedText.text = "> " + currentValue;
			} else {
				selectedText.text = currentValue;
			}
			
			// 更新描述
			descText.text = selectedOption.getDescription();
			selectedText.alpha = 1.0; // 确保选中项完全不透明
		}
		
		// 确保选中项可见
		ensureOptionVisible();
	}
	
	function ensureOptionVisible():Void
	{
		if (selectedOptionIndex < scrollOffset) {
			// 选中项在滚动区域上方，向上滚动
			scrollOffset = selectedOptionIndex;
		} else if (selectedOptionIndex >= scrollOffset + VISIBLE_OPTIONS) {
			// 选中项在滚动区域下方，向下滚动
			scrollOffset = selectedOptionIndex - (VISIBLE_OPTIONS - 1);
		}
		
		if (scrollOffset < 0) scrollOffset = 0;
		if (scrollOffset > maxScrollOffset) scrollOffset = maxScrollOffset;
	}
	
	function scrollOptions(change:Int):Void
	{
		if (options.length <= VISIBLE_OPTIONS) return;
		
		var newOffset = scrollOffset + change;
		if (newOffset < 0) newOffset = 0;
		if (newOffset > maxScrollOffset) newOffset = maxScrollOffset;
		
		if (newOffset == scrollOffset) return;
		
		scrollOffset = newOffset;
		
		// 如果选中项不再可见，调整选中项索引
		if (selectedOptionIndex < scrollOffset) {
			selectedOptionIndex = scrollOffset;
			selectedOption = options[selectedOptionIndex];
		} else if (selectedOptionIndex >= scrollOffset + VISIBLE_OPTIONS) {
			selectedOptionIndex = scrollOffset + (VISIBLE_OPTIONS - 1);
			selectedOption = options[selectedOptionIndex];
		}
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		updateDisplay();
	}
	
	function handleUpKey():Void
	{
		if (selectedOptionIndex > 0) {
			selectedOptionIndex--;
			selectedOption = options[selectedOptionIndex];
			
			// 确保选中项可见
			ensureOptionVisible();
			
			// 更新显示
			updateDisplay();
			
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		} else if (scrollOffset > 0) {
			// 如果在顶部且需要滚动，向上滚动
			scrollOptions(-1);
		}
	}
	
	function handleDownKey():Void
	{
		if (selectedOptionIndex < options.length - 1) {
			selectedOptionIndex++;
			selectedOption = options[selectedOptionIndex];
			
			// 确保选中项可见
			ensureOptionVisible();
			
			// 更新显示
			updateDisplay();
			
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		} else if (scrollOffset < maxScrollOffset) {
			// 如果在底部且需要滚动，向下滚动
			scrollOptions(1);
		}
	}
	
	function handleRightKey():Void
	{
		if (selectedOptionIndex > 0 && selectedOption.getAccept()) // 不是返回按钮
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			selectedOption.right();
			ClientPrefs.saveSettings();
			updateDisplay();
		}
	}
	
	function handleLeftKey():Void
	{
		if (selectedOptionIndex > 0 && selectedOption.getAccept()) // 不是返回按钮
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			selectedOption.left();
			ClientPrefs.saveSettings();
			updateDisplay();
		}
	}
	
	function closeMenu():Void
	{
		if (isClosing) return;
		
		isClosing = true;
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
		
		// 简单渐变消失动画
		FlxTween.tween(bg, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		FlxTween.tween(titleText, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		FlxTween.tween(descBack, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		FlxTween.tween(descText, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		
		for (text in optionTexts) {
			if (text != null) {
				FlxTween.tween(text, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
			}
		}
		
		// 延迟关闭
		new flixel.util.FlxTimer().start(tweenDuration + 0.1, function(tmr:flixel.util.FlxTimer) {
			close();
		});
	}
}