package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxRect;
import flixel.math.FlxMath;
import objects.DraggableBar;
import backend.MouseMove;

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
	
	// 点击保护
	var optionClickCooldown:Float = 0;
	var optionClickProtected:Bool = false;
	
	// 鼠标拖拽滚动
	var optionScroller:MouseMove;
	public static var optionScrollPos:Float = 0;
	var valueBar:DraggableBar;
	var valueBarText:FlxText;
	
	// 布局参数
	var screenWidth:Int;
	var screenHeight:Int;
	var marginTop:Int;
	var marginBottom:Int;
	var bgAlpha:Float;
	var optionAlpha:Float;
	var descAlpha:Float;
	
	public function new(parentOption:KEOption)
	{
		super();
		this.parentOption = parentOption;
		this.options = parentOption.subMenuOptions.copy();
		
		// 重置滚动位置
		optionScrollPos = 0;
		
		// 从主菜单继承布局参数
		inheritLayoutFromMainMenu();
		
		// 添加返回按钮到选项列表的开头
		backButton = KEOption.create("Back", "Return to previous menu", "", "action");
		this.options.unshift(backButton);
	}
	
	function inheritLayoutFromMainMenu():Void
	{
		if (KEOptionsMenu.instance != null) {
			screenWidth = KEOptionsMenu.SCREEN_WIDTH;
			screenHeight = KEOptionsMenu.SCREEN_HEIGHT;
			marginTop = KEOptionsMenu.MARGIN_TOP;
			marginBottom = KEOptionsMenu.MARGIN_BOTTOM;
			bgAlpha = KEOptionsMenu.TAB_ALPHA;
			optionAlpha = KEOptionsMenu.OPTION_ALPHA;
			descAlpha = KEOptionsMenu.DESC_ALPHA;
		} else {
			screenWidth = 1280;
			screenHeight = 720;
			marginTop = 80;
			marginBottom = 80;
			bgAlpha = 0.7;
			optionAlpha = 0.6;
			descAlpha = 0.8;
		}
	}
	
	override function create()
	{
		super.create();
		
		// 计算内容区域
		var contentStartY:Int = marginTop;
		
		// 创建半透明背景 - 全屏
		bg = new FlxSprite(0, 0).makeGraphic(screenWidth, screenHeight, FlxColor.BLACK);
		bg.alpha = bgAlpha;
		bg.scrollFactor.set();
		add(bg);
		
		// 标题 - 居中显示
		titleText = new FlxText(0, marginTop + 20, screenWidth, parentOption.subMenuTitle);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);
		
		// 描述区域背景 - 在屏幕底部
		descBack = new FlxSprite(0, screenHeight - marginBottom).makeGraphic(screenWidth, 40, FlxColor.BLACK);
		descBack.alpha = descAlpha;
		descBack.scrollFactor.set();
		add(descBack);
		
		// 选项文本
		optionTexts = new FlxTypedGroup<FlxText>();
		add(optionTexts);
		
		// 创建选项文本 - 居中显示
		var optionStartY:Int = marginTop + 80;
		for (i in 0...options.length)
		{
			var optionText = new FlxText(0, optionStartY + (46 * i), screenWidth, options[i].getValue());
			optionText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			optionText.borderSize = 2;
			optionText.ID = i;
			optionTexts.add(optionText);
		}
		
		// 描述文本
		descText = new FlxText(10, screenHeight - marginBottom + 5, screenWidth - 20);
		descText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 2;
		descText.alpha = 1.0;
		add(descText);

	valueBar = new DraggableBar(0, screenHeight - marginBottom, 'healthBar', function() return getSelectedOptionValue(), 0, 1);
	valueBar.scrollFactor.set();
	valueBar.visible = false;
	valueBar.cameras = [FlxG.camera];
	valueBar.screenCenter(X);
	valueBar.onValueChanged = function(percentValue:Float) {
		if (selectedOption == null || !isNumericOption(selectedOption)) return;
		var rawValue:Float = FlxMath.lerp(selectedOption.minValue, selectedOption.maxValue, percentValue / 100);
		var newValue:Float = snapOptionValue(rawValue, selectedOption);
		var currentValue:Float = Std.parseFloat(Std.string(selectedOption.value));
		if (newValue != currentValue) {
			selectedOption.value = newValue;
			selectedOption.saveCurrentValue();
			ClientPrefs.saveSettings();
			updateDisplay();
		}
		valueBarText.text = selectedOption.getValue();
	};
	valueBarText = new FlxText(0, valueBar.y - 32, screenWidth, "");
	valueBarText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
	valueBarText.borderSize = 2;
	valueBarText.visible = false;
	valueBarText.cameras = [FlxG.camera];
	add(valueBar);
	add(valueBarText);
		
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
		FlxTween.tween(bg, {alpha: bgAlpha}, tweenDuration, {ease: FlxEase.sineOut});
		FlxTween.tween(titleText, {alpha: 1}, tweenDuration, {ease: FlxEase.sineOut});
		FlxTween.tween(descBack, {alpha: descAlpha}, tweenDuration, {ease: FlxEase.sineOut});
		FlxTween.tween(descText, {alpha: 1}, tweenDuration, {ease: FlxEase.sineOut});
		
		for (i in 0...optionTexts.length) {
			FlxTween.tween(optionTexts.members[i], {alpha: optionAlpha}, tweenDuration, {ease: FlxEase.sineOut});
		}
		
		// 创建鼠标拖拽滚动器
		setupMouseScroller();
		
		// 播放音效
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		
		// 更新显示
		updateDisplay();
	}
	
	function setupMouseScroller():Void
	{
		var totalOptionsHeight:Float = options.length * 46;
		var visibleHeight:Float = screenHeight - marginTop - marginBottom - 120;
		var minScroll:Float = 0;
		var maxScroll:Float = Math.max(0, totalOptionsHeight - visibleHeight);
		
		// 选项区域范围
		var contentStartY:Float = marginTop + 80;
		var contentHeight:Float = visibleHeight;
		
		optionScroller = new MouseMove(
			KESubMenu,
			'optionScrollPos',
			[minScroll, maxScroll],
			[
				[0, screenWidth],
				[contentStartY, contentStartY + contentHeight]
			],
			onScrollChange
		);
		optionScroller.useLerp = true;
		optionScroller.lerpSmooth = 12;
		optionScroller.dragSensitivity = 1.2;
		optionScroller.deceleration = 0.94;
		add(optionScroller);
	}
	
	function onScrollChange():Void
	{
		// 根据滚动位置计算新的 scrollOffset
		var newScrollOffset = Math.round(optionScrollPos / 46);
		if (newScrollOffset != scrollOffset)
		{
			scrollOffset = newScrollOffset;
			if (scrollOffset < 0) scrollOffset = 0;
			if (scrollOffset > maxScrollOffset) scrollOffset = maxScrollOffset;
			// 直接更新选项位置，不改变选中项
			updateOptionPositions();
		}
	}
	
	function updateOptionPositions():Void
	{
		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText == null) continue;
			
			var displayIndex = i - scrollOffset;
			optionText.y = marginTop + 80 + (46 * displayIndex);
			
			// 判断是否在可见区域内
			var isVisible = (displayIndex >= 0 && displayIndex < VISIBLE_OPTIONS);
			optionText.alpha = isVisible ? (i == selectedOptionIndex ? 1.0 : optionAlpha) : 0;
		}
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
		
		// 使用 Controls 的 BACK 退出检测
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
		
		// 更新悬停效果
		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText != null && optionText.alpha > 0)
			{
				if (i == selectedOptionIndex)
				{
					optionText.alpha = 1.0;
					optionText.color = FlxColor.WHITE;
				}
				else if (i == hoveredIndex)
				{
					optionText.color = FlxColor.YELLOW;
					optionText.alpha = optionAlpha;
				}
				else
				{
					optionText.color = FlxColor.WHITE;
					optionText.alpha = optionAlpha;
				}
			}
		}
		
		// 鼠标滚轮：只滚动列表，不改变选中项
		if (FlxG.mouse.wheel != 0)
		{
            var wheelDelta = - FlxG.mouse.wheel;  // 反转方向
        	scrollOptions(wheelDelta, false);
		}
		// 鼠标点击
		if (FlxG.mouse.justPressed && !optionClickProtected && (optionScroller == null || !optionScroller.isDragging))
		{
			for (i in 0...optionTexts.length)
			{
				var optionText = optionTexts.members[i];
				if (optionText == null || optionText.alpha == 0) continue;
				
				if (FlxG.mouse.overlaps(optionText))
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
					selectedOptionIndex = i;
					selectedOption = options[i];
					ensureOptionVisible();
					updateDisplay();
					
					if (i == 0) {
						closeMenu();
						return;
					}
					
					var shouldKeepState = selectedOption.press();
					if (shouldKeepState) {
						ClientPrefs.saveSettings();
						updateDisplay();
					}
					
					optionClickProtected = true;
					optionClickCooldown = 0.2;
					break;
				}
			}
		}
		#end
		
		// 键盘控制
		var accept = controls.ACCEPT;
		var up = controls.UI_UP_P;
		var down = controls.UI_DOWN_P;
		var left = controls.UI_LEFT_P;
		var right = controls.UI_RIGHT_P;
		var upPressed = controls.UI_UP;
		var downPressed = controls.UI_DOWN;
		var leftPressed = controls.UI_LEFT;
		var rightPressed = controls.UI_RIGHT;
		
		// 长按上下滚动
		if (upPressed) {
			holdUpTime += elapsed;
			if (holdUpTime > 0.3) {
				scrollHoldTime += elapsed;
				if (scrollHoldTime >= 0.05) {
					scrollHoldTime = 0;
					handleUpKey();
				}
			}
		} else {
			holdUpTime = 0;
		}
		
		if (downPressed) {
			holdDownTime += elapsed;
			if (holdDownTime > 0.3) {
				scrollHoldTime += elapsed;
				if (scrollHoldTime >= 0.05) {
					scrollHoldTime = 0;
					handleDownKey();
				}
			}
		} else {
			holdDownTime = 0;
		}
		
		if (!upPressed && !downPressed) {
			scrollHoldTime = 0;
		}
		
		// 短按上下键
		if (up) handleUpKey();
		if (down) handleDownKey();
		
		// 长按左右调整数值
		var optionChangedByHold = false;
		if (selectedOption != null && selectedOption != backButton && selectedOption.getAccept()) {
			optionChangedByHold = selectedOption.updateHold(elapsed, leftPressed, rightPressed);
			if (optionChangedByHold) {
				ClientPrefs.saveSettings();
				updateDisplay();
			}
		}
		
		// 短按左右键
		if (right && !optionChangedByHold) handleRightKey();
		else if (left && !optionChangedByHold) handleLeftKey();
		
		// 回车键
		if (accept) {
			if (selectedOptionIndex == 0) {
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
	
	function scrollOptions(change:Int, isLongPress:Bool = false):Void
	{
		var newOffset = scrollOffset - change; // 注意方向：正滚轮向下滚动
		if (newOffset < 0) newOffset = 0;
		if (newOffset > maxScrollOffset) newOffset = maxScrollOffset;
		
		if (newOffset == scrollOffset) return;
		
		scrollOffset = newOffset;
		optionScrollPos = scrollOffset * 46;
		if (optionScroller != null) {
			optionScroller.target = optionScrollPos;
		}
		updateOptionPositions();
		
		if (!isLongPress) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		}
	}
	
	public function updateDisplay():Void
	{
		// 更新所有选项文本
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
			}
		}
		
		// 为当前选中的选项添加 > 符号
		var selectedText = optionTexts.members[selectedOptionIndex];
		if (selectedText != null)
		{
			var currentValue = selectedOption.getValue();
			if (!currentValue.startsWith("> ")) {
				selectedText.text = "> " + currentValue;
			}
			descText.text = selectedOption.getDescription();
			selectedText.alpha = 1.0;
		}

		updateValueBar();
		// 更新位置和可见性
		updateOptionPositions();
	}
	
	function isNumericOption(option:KEOption):Bool
	{
		return option != null && (option.type == "int" || option.type == "float");
	}
	
	function getSelectedOptionValue():Float
	{
		if (!isNumericOption(selectedOption)) return 0;
	return snapOptionValue(Std.parseFloat(Std.string(selectedOption.value)), selectedOption);
}

function updateValueBar():Void
{
	if (selectedOption != null && isNumericOption(selectedOption))
	{
		valueBar.visible = true;
		valueBarText.visible = true;
		valueBar.setBounds(selectedOption.minValue, selectedOption.maxValue);
		var currentValue:Float = snapOptionValue(Std.parseFloat(Std.string(selectedOption.value)), selectedOption);
		valueBar.setPercent(FlxMath.remapToRange(currentValue, selectedOption.minValue, selectedOption.maxValue, 0, 100), false);
		valueBarText.text = selectedOption.getValue();
	}
	else
	{
		valueBar.visible = false;
		valueBarText.visible = false;
	}
}

function getStepDecimals(step:Float):Int
{
	var s:String = Std.string(step);
	var index:Int = s.indexOf('.');
	if (index == -1) return 0;
	return s.length - index - 1;
}

function roundToDecimals(value:Float, decimals:Int):Float
{
	var factor:Float = Math.pow(10, decimals);
	return Math.round(value * factor) / factor;
}

function snapOptionValue(value:Float, option:KEOption):Float
{
	if (option == null) return value;
	var step:Float = option.changeValue;
	if (step <= 0) return value;
	var relative:Float = (value - option.minValue) / step;
	var snapped:Float = option.minValue + Math.round(relative) * step;
	if (option.type == "int") snapped = Math.round(snapped);
	else snapped = roundToDecimals(snapped, getStepDecimals(step));
	if (snapped < option.minValue) snapped = option.minValue;
	if (snapped > option.maxValue) snapped = option.maxValue;
	return snapped;
	}

function ensureOptionVisible():Void
{
	var oldOffset = scrollOffset;
	
	if (selectedOptionIndex < scrollOffset) {
		scrollOffset = selectedOptionIndex;
	} else if (selectedOptionIndex >= scrollOffset + VISIBLE_OPTIONS) {
		scrollOffset = selectedOptionIndex - (VISIBLE_OPTIONS - 1);
	}
	
	if (scrollOffset < 0) scrollOffset = 0;
	if (scrollOffset > maxScrollOffset) scrollOffset = maxScrollOffset;
	
	if (oldOffset != scrollOffset) {
		optionScrollPos = scrollOffset * 46;
		if (optionScroller != null) {
			optionScroller.target = optionScrollPos;
		}
		updateOptionPositions();
	}
}

	
	function handleUpKey():Void
	{
		if (selectedOptionIndex > 0) {
			selectedOptionIndex--;
			selectedOption = options[selectedOptionIndex];
			ensureOptionVisible();
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		} else if (scrollOffset > 0) {
			scrollOptions(1, true);
		}
	}
	
	function handleDownKey():Void
	{
		if (selectedOptionIndex < options.length - 1) {
			selectedOptionIndex++;
			selectedOption = options[selectedOptionIndex];
			ensureOptionVisible();
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		} else if (scrollOffset < maxScrollOffset) {
			scrollOptions(-1, true);
		}
	}
	
	function handleRightKey():Void
	{
		if (selectedOptionIndex > 0 && selectedOption.getAccept())
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			selectedOption.right();
			ClientPrefs.saveSettings();
			updateDisplay();
		}
	}
	
	function handleLeftKey():Void
	{
		if (selectedOptionIndex > 0 && selectedOption.getAccept())
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
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
		
		FlxTween.tween(bg, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		FlxTween.tween(titleText, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		FlxTween.tween(descBack, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		FlxTween.tween(descText, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
		
		for (text in optionTexts) {
			if (text != null) {
				FlxTween.tween(text, {alpha: 0}, tweenDuration, {ease: FlxEase.sineIn});
			}
		}
		
		new flixel.util.FlxTimer().start(tweenDuration + 0.1, function(tmr:flixel.util.FlxTimer) {
			close();
		});
	}
}