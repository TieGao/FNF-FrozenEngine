package options;

import options.KEOption;
import backend.Language;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import backend.MouseMove;

class KEConfirmMenu extends MusicBeatSubstate
{
	var parentOption:KEOption;
	var availableOptions:Array<String>;
	var selectedIndex:Int;
	var originalIndex:Int;
	var isColorMode:Bool;
	var isConfirmMode:Bool;

	var screenWidth:Int;
	var screenHeight:Int;
	var marginTop:Int;
	var marginBottom:Int;
	var listStartY:Int;

	var bg:FlxSprite;
	var confirmBack:FlxSprite;
	var cancelBack:FlxSprite;
	var bodyBack:FlxFilteredSprite;

	var titleText:FlxText;
	var typeText:FlxText;
	var valueText:FlxText;
	var optionTexts:FlxTypedGroup<FlxText>;
	var confirmText:FlxText;
	var cancelText:FlxText;

	static var VISIBLE_OPTIONS:Int = 5;
	var scrollOffset:Int = 0;
	var maxScrollOffset:Int = 0;

	var optionClickCooldown:Float = 0;
	var optionClickProtected:Bool = false;
	var isClosing:Bool = false;
	public var closeParentSubMenu:Bool = false;

	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;
	var scrollHoldTime:Float = 0;
	
	// 鼠标拖拽滚动
	var optionScroller:MouseMove;
	public static var optionScrollPos:Float = 0;

	public function new(parentOption:KEOption)
	{
		super();
		this.parentOption = parentOption;
		this.isColorMode = parentOption.type == "color";
		this.isConfirmMode = parentOption.type == "confirm";
		this.availableOptions = this.isConfirmMode ? [] : (this.isColorMode ? KEOption.COLOR_NAMES.copy() : parentOption.options.copy());
		this.selectedIndex = this.isConfirmMode ? 0 : Std.int(Math.max(0, parentOption.curOption));
		this.originalIndex = this.selectedIndex;
		
		optionScrollPos = 0;
	}

	override function create()
	{
		super.create();

		screenWidth = Std.int(FlxG.width);
		screenHeight = Std.int(FlxG.height);
		marginTop = Std.int(screenHeight * 0.09);
		marginBottom = Std.int(screenHeight * 0.12);
		listStartY = marginTop + 140;
		maxScrollOffset = Std.int(Math.max(0, availableOptions.length - VISIBLE_OPTIONS));

		bg = new FlxSprite(0, 0).makeGraphic(screenWidth, screenHeight, FlxColor.BLACK);
		bg.alpha = 0.75;
		bg.scrollFactor.set();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		var bodyY = Std.int(screenHeight * 0.25);
		var bodyHeight = Std.int(screenHeight * 0.5);
		bodyBack = new FlxFilteredSprite(0, bodyY);
		bodyBack.makeGraphic(screenWidth, bodyHeight, FlxColor.BLACK);
		if (ClientPrefs.data.blurEffects)bodyBack.filters = [new BlurFilter(50, 50, BitmapFilterQuality.HIGH)];
		bodyBack.alpha = 0.7;
		bodyBack.scrollFactor.set();
		add(bodyBack);

		var titles:String = isConfirmMode ? Language.getPhrase("Confirm action", "Confirm action") : Language.getPhrase("Select an option", "SelectOption");
		titleText = new FlxText(0, marginTop, screenWidth, titles);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.antialiasing = ClientPrefs.data.antialiasing;
		titleText.borderSize = 2;
		add(titleText);

		var typeLabel = isConfirmMode ? Language.getPhrase("Confirm", "Confirm") : Language.getPhrase("Type", "Type");
		typeText = new FlxText(0, titleText.y + 44, screenWidth, typeLabel + ": " + (isConfirmMode ? parentOption.name : parentOption.type));
		typeText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
		typeText.antialiasing = ClientPrefs.data.antialiasing;
		typeText.borderSize = 2;
		add(typeText);

		valueText = new FlxText(0, typeText.y + 40, screenWidth, getSelectedName());
		valueText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		valueText.antialiasing = ClientPrefs.data.antialiasing;
		valueText.borderSize = 2;
		add(valueText);

		var buttonY = Std.int(bodyY + bodyHeight - 70);
		var buttonWidth = Std.int(screenWidth * 0.24);
		var buttonHeight = 44;

		confirmBack = new FlxSprite(Std.int(screenWidth * 0.18), buttonY).makeGraphic(buttonWidth, buttonHeight, FlxColor.fromRGB(0, 120, 220));
		confirmBack.alpha = 0.9;
		confirmBack.scrollFactor.set();
		add(confirmBack);

		cancelBack = new FlxSprite(Std.int(screenWidth * 0.58), buttonY).makeGraphic(buttonWidth, buttonHeight, FlxColor.fromRGB(180, 40, 40));
		cancelBack.alpha = 0.9;
		cancelBack.scrollFactor.set();
		add(cancelBack);

		optionTexts = new FlxTypedGroup<FlxText>();

		for (text in optionTexts.members)
			text.antialiasing = ClientPrefs.data.antialiasing;
		add(optionTexts);

		if (!isConfirmMode) {
			for (i in 0...availableOptions.length)
			{
				var optionText = new FlxText(0, listStartY + (48 * i), screenWidth, availableOptions[i]);
				optionText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				optionText.borderSize = 2;
				optionText.alpha = 0;
				optionText.ID = i;
				optionTexts.add(optionText);
			}
		}

		confirmText = new FlxText(Std.int(screenWidth * 0.18), buttonY + 6, buttonWidth, Language.getPhrase("Confirm", "Confirm"));
		confirmText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		confirmText.antialiasing = ClientPrefs.data.antialiasing;
		confirmText.borderSize = 2;
		add(confirmText);

		cancelText = new FlxText(Std.int(screenWidth * 0.58), buttonY + 6, buttonWidth, Language.getPhrase("Cancel", "Cancel"));
		cancelText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		cancelText.antialiasing = ClientPrefs.data.antialiasing;
		cancelText.borderSize = 2;
		add(cancelText);

		if (!isConfirmMode) {
			setupMouseScroller();
		}

		updateDisplay();
	}
	
	function setupMouseScroller():Void
	{
		var totalOptionsHeight:Float = availableOptions.length * 48;
		var visibleHeight:Float = screenHeight - marginTop - marginBottom - 400;
		var minScroll:Float = 0;
		var maxScroll:Float = Math.max(0, totalOptionsHeight - visibleHeight);
		
		var contentStartY:Float = listStartY;
		var contentHeight:Float = visibleHeight;
		
		optionScroller = new MouseMove(
			KEConfirmMenu,
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
		var newScrollOffset = Math.round(optionScrollPos / 48);
		if (newScrollOffset != scrollOffset)
		{
			scrollOffset = newScrollOffset;
			if (scrollOffset < 0) scrollOffset = 0;
			if (scrollOffset > maxScrollOffset) scrollOffset = maxScrollOffset;
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
			optionText.y = listStartY + (48 * displayIndex);
			
			var isVisible = (displayIndex >= 0 && displayIndex < VISIBLE_OPTIONS);
			optionText.alpha = isVisible ? 1 : 0;
			if (isVisible && this.isColorMode) {
				optionText.color = KEOption.COLOR_PALETTE[i];
			}
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (optionClickCooldown > 0) {
			optionClickCooldown -= elapsed;
			if (optionClickCooldown <= 0) optionClickProtected = false;
		}

		if (isClosing) return;

		FlxG.mouse.visible = true;
		FlxG.mouse.useSystemCursor = ClientPrefs.data.useSystemCursor;

		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			cancelSelection();
			return;
		}

		var hoveredIndex = -1;
		var hoveredButton:String = "";

		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText == null || optionText.alpha <= 0) continue;
			if (FlxG.mouse.overlaps(optionText))
			{
				hoveredIndex = i;
				break;
			}
		}

		if (FlxG.mouse.overlaps(confirmBack)) hoveredButton = "confirm";
		else if (FlxG.mouse.overlaps(cancelBack)) hoveredButton = "cancel";

		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText == null || optionText.alpha <= 0) continue;
			var baseColor = this.isColorMode ? KEOption.COLOR_PALETTE[i] : FlxColor.WHITE;
			if (i == selectedIndex) {
				optionText.color = FlxColor.YELLOW;
				optionText.alpha = 1;
			} else if (i == hoveredIndex) {
				optionText.color = FlxColor.fromRGB(255, 215, 0);
				optionText.alpha = 1;
			} else {
				optionText.color = baseColor;
				optionText.alpha = 0.85;
			}
		}

		if (hoveredButton == "confirm")
		{
			confirmBack.color = FlxColor.fromRGB(0, 150, 255);
		}
		else
		{
			confirmBack.color = FlxColor.fromRGB(0, 120, 220);
		}

		if (hoveredButton == "cancel")
		{
			cancelBack.color = FlxColor.fromRGB(220, 70, 70);
		}
		else
		{
			cancelBack.color = FlxColor.fromRGB(180, 40, 40);
		}

		// 鼠标滚轮：只滚动列表，不改变选中项
		if (FlxG.mouse.wheel != 0 && !isConfirmMode)
		{
             var wheelDelta = -FlxG.mouse.wheel;  // 反转方向
        	scrollOptions(wheelDelta, false);
		}
		// 鼠标点击
		if (FlxG.mouse.justPressed && !optionClickProtected && (optionScroller == null || !optionScroller.isDragging))
		{
			var mousePos = FlxG.mouse.getScreenPosition(camera);

			if (confirmBack.overlapsPoint(mousePos)) {
				confirmSelection();
				optionClickProtected = true;
				optionClickCooldown = 0.2;
				return;
			}
			else if (cancelBack.overlapsPoint(mousePos)) {
				cancelSelection();
				optionClickProtected = true;
				optionClickCooldown = 0.2;
				return;
			}

			if (hoveredIndex >= 0 && !isConfirmMode) {
				selectedIndex = hoveredIndex;
				updateDisplay();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
				optionClickProtected = true;
				optionClickCooldown = 0.2;
				return;
			}
		}

		var accept = controls.ACCEPT;
		var up = controls.UI_UP_P;
		var down = controls.UI_DOWN_P;
		var upPressed = controls.UI_UP;
		var downPressed = controls.UI_DOWN;

		if (upPressed && !isConfirmMode) {
			holdUpTime += elapsed;
			if (holdUpTime > 0.3) {
				scrollHoldTime += elapsed;
				if (scrollHoldTime >= 0.05) {
					scrollHoldTime = 0;
					moveSelection(-1);
				}
			}
		} else {
			holdUpTime = 0;
		}

		if (downPressed && !isConfirmMode) {
			holdDownTime += elapsed;
			if (holdDownTime > 0.3) {
				scrollHoldTime += elapsed;
				if (scrollHoldTime >= 0.05) {
					scrollHoldTime = 0;
					moveSelection(1);
				}
			}
		} else {
			holdDownTime = 0;
		}

		if (!upPressed && !downPressed) scrollHoldTime = 0;

		if (up && !isConfirmMode) moveSelection(-1);
		if (down && !isConfirmMode) moveSelection(1);

		if (accept) confirmSelection();
	}
	
	function scrollOptions(change:Int, isLongPress:Bool = false):Void
	{
		var newOffset = scrollOffset - change; // 注意方向
		if (newOffset < 0) newOffset = 0;
		if (newOffset > maxScrollOffset) newOffset = maxScrollOffset;
		
		if (newOffset == scrollOffset) return;
		
		scrollOffset = newOffset;
		optionScrollPos = scrollOffset * 48;
		if (optionScroller != null) {
			optionScroller.target = optionScrollPos;
		}
		updateOptionPositions();
		
		if (!isLongPress) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		}
	}

	function getSelectedName():String
	{
		if (isConfirmMode) {
			if (parentOption.warningMessage != "") {
				return resolveTranslation(parentOption.warningMessage, parentOption.warningMessage);
			}
			return parentOption.getDescription();
		}

		if (selectedIndex >= 0 && selectedIndex < availableOptions.length) {
			var selectedName = getOptionDisplayName(availableOptions[selectedIndex]);
			return Language.getPhrase("Selected: ", "Selected: ") + resolveTranslation(selectedName, selectedName);
		}
		return "";
	}

	function getOptionDisplayName(optionName:String):String
	{
		if (parentOption.variable == "hitsound" && optionName.startsWith("hitsounds/"))
			return optionName.substring("hitsounds/".length);
		return optionName;
	}

	function resolveTranslation(key:String, defaultVal:String):String
	{
		return Language.getPhrase(key, defaultVal);
	}

	function moveSelection(change:Int):Void
	{
		if (isConfirmMode) return;
		
		selectedIndex += change;
		if (selectedIndex < 0) selectedIndex = availableOptions.length - 1;
		if (selectedIndex >= availableOptions.length) selectedIndex = 0;
		ensureOptionVisible();
		updateDisplay();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
	}

	function ensureOptionVisible():Void
	{
		if (isConfirmMode) return;
		
		var oldOffset = scrollOffset;
		
		if (selectedIndex < scrollOffset) {
			scrollOffset = selectedIndex;
		} else if (selectedIndex >= scrollOffset + VISIBLE_OPTIONS) {
			scrollOffset = selectedIndex - (VISIBLE_OPTIONS - 1);
		}
		
		if (scrollOffset < 0) scrollOffset = 0;
		if (scrollOffset > maxScrollOffset) scrollOffset = maxScrollOffset;
		
		if (oldOffset != scrollOffset) {
			optionScrollPos = scrollOffset * 48;
			if (optionScroller != null) {
				optionScroller.target = optionScrollPos;
			}
			updateOptionPositions();
		}
	}

	function updateDisplay():Void
	{
		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText == null) continue;
			var optionName = getOptionDisplayName(availableOptions[i]);
			optionText.text = resolveTranslation(optionName, optionName);
		}
		updateOptionPositions();
		valueText.text = getSelectedName();
	}

	function confirmSelection():Void
	{
		if (isClosing) return;
		if (isConfirmMode) {
			parentOption.executeWarningAction();
			closeMenu();
			return;
		}

		if (selectedIndex < 0 || selectedIndex >= availableOptions.length) return;

		parentOption.curOption = selectedIndex;
		if (this.isColorMode) {
			parentOption.value = KEOption.COLOR_PALETTE[selectedIndex];
		} else {
			parentOption.value = availableOptions[selectedIndex];
		}
		if (KEOptionsMenu.instance != null)
			KEOptionsMenu.instance.doSelectCurrentOption();

		if (KEOptionsMenu.instance != null && KEOptionsMenu.instance.subState != null && Std.is(KEOptionsMenu.instance.subState, KESubMenu))
		{
			var subMenu:KESubMenu = cast(KEOptionsMenu.instance.subState, KESubMenu);
			subMenu.updateDisplay();
		}

		parentOption.saveCurrentValue();
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		closeMenu();
	}

	function cancelSelection():Void
	{
		if (isClosing) return;
		if (!isConfirmMode) {
			parentOption.curOption = originalIndex;
			parentOption.value = availableOptions[originalIndex];
		}
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
		closeMenu();
	}

	function closeMenu(closeParent:Bool = false):Void
	{
		if (isClosing) return;
		isClosing = true;
		FlxTween.tween(bg, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(bodyBack, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(titleText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(typeText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(valueText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(confirmBack, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(cancelBack, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(confirmText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(cancelText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		for (text in optionTexts) FlxTween.tween(text, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		new FlxTimer().start(0.25, function(tmr:FlxTimer) {
			close();
			if (closeParent) {
				KEOptionsMenu.instance.closeSubState();
			}
		});
	}
}