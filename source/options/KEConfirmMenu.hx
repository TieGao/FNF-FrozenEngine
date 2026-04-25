package options;

import backend.Language;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;

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
	var headerBack:FlxSprite;
	var confirmBack:FlxSprite;
	var cancelBack:FlxSprite;
	var bodyBack:FlxSprite;
	var topEdge:FlxSprite;
	var bottomEdge:FlxSprite;
	var descBack:FlxSprite;

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

	public function new(parentOption:KEOption)
	{
		super();
		this.parentOption = parentOption;
		this.isColorMode = parentOption.type == "color";
		this.isConfirmMode = parentOption.type == "confirm";
		this.availableOptions = this.isConfirmMode ? [] : (this.isColorMode ? KEOption.COLOR_NAMES.copy() : parentOption.options.copy());
		this.selectedIndex = this.isConfirmMode ? 0 : Std.int(Math.max(0, parentOption.curOption));
		this.originalIndex = this.selectedIndex;
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
		add(bg);

		var bodyY = Std.int(screenHeight * 0.25);
		var bodyHeight = Std.int(screenHeight * 0.5);
		bodyBack = new FlxSprite(0, bodyY).makeGraphic(screenWidth, bodyHeight, FlxColor.BLACK);
		bodyBack.alpha = 0.8;
		bodyBack.scrollFactor.set();
		add(bodyBack);

		topEdge = new FlxSprite(0, bodyY - 20).makeGraphic(screenWidth, 20, FlxColor.BLACK);
		topEdge.scrollFactor.set();
		add(topEdge);

		bottomEdge = new FlxSprite(0, bodyY + bodyHeight).makeGraphic(screenWidth, 20, FlxColor.BLACK);
		bottomEdge.scrollFactor.set();
		add(bottomEdge);

		headerBack = new FlxSprite(0, marginTop - 10).makeGraphic(screenWidth, 140, FlxColor.BLACK);
		headerBack.alpha = 0.7;
		headerBack.scrollFactor.set();
		add(headerBack);

		var titles:String = isConfirmMode ? Language.getPhrase("Confirm action", "Confirm action") : Language.getPhrase("Select an option", "Select an option");
		titleText = new FlxText(0, marginTop, screenWidth, titles);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		var typeLabel = isConfirmMode ? Language.getPhrase("Confirm", "Confirm") : Language.getPhrase("Type", "Type");
		typeText = new FlxText(0, titleText.y + 44, screenWidth, typeLabel + ": " + (isConfirmMode ? parentOption.name : parentOption.type));
		typeText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
		typeText.borderSize = 2;
		add(typeText);

		valueText = new FlxText(0, typeText.y + 40, screenWidth, getSelectedName());
		valueText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		valueText.borderSize = 2;
		add(valueText);

		var buttonY = Std.int(bodyY + bodyHeight - 70);
		var buttonWidth = Std.int(screenWidth * 0.24);
		var buttonHeight = 44;

		descBack = new FlxSprite(0, buttonY - 60).makeGraphic(screenWidth, 50, FlxColor.BLACK);
		descBack.alpha = 0.8;
		descBack.scrollFactor.set();
		add(descBack);

		confirmBack = new FlxSprite(Std.int(screenWidth * 0.18), buttonY).makeGraphic(buttonWidth, buttonHeight, FlxColor.fromRGB(0, 120, 220));
		confirmBack.alpha = 0.9;
		confirmBack.scrollFactor.set();
		add(confirmBack);

		cancelBack = new FlxSprite(Std.int(screenWidth * 0.58), buttonY).makeGraphic(buttonWidth, buttonHeight, FlxColor.fromRGB(180, 40, 40));
		cancelBack.alpha = 0.9;
		cancelBack.scrollFactor.set();
		add(cancelBack);

		optionTexts = new FlxTypedGroup<FlxText>();
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
		confirmText.borderSize = 2;
		add(confirmText);

		cancelText = new FlxText(Std.int(screenWidth * 0.58), buttonY + 6, buttonWidth, Language.getPhrase("Cancel", "Cancel"));
		cancelText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		cancelText.borderSize = 2;
		add(cancelText);

		updateDisplay();
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

		if (FlxG.mouse.wheel != 0)
		{
			if (hoveredIndex >= 0) {
				moveSelection(FlxG.mouse.wheel < 0 ? 1 : -1);
			} else {
				moveSelection(FlxG.mouse.wheel < 0 ? 1 : -1);
			}
		}

		if (FlxG.mouse.justPressed && !optionClickProtected)
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

			if (hoveredIndex >= 0) {
				selectedIndex = hoveredIndex;
				updateDisplay();
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

		if (upPressed) {
			holdUpTime += elapsed;
			if (holdUpTime > 0.3) {
				scrollHoldTime++;
				if (scrollHoldTime % 3 == 0) moveSelection(-1);
			}
		} else {
			holdUpTime = 0;
		}

		if (downPressed) {
			holdDownTime += elapsed;
			if (holdDownTime > 0.3) {
				scrollHoldTime++;
				if (scrollHoldTime % 3 == 0) moveSelection(1);
			}
		} else {
			holdDownTime = 0;
		}

		if (!upPressed && !downPressed) scrollHoldTime = 0;

		if (up) moveSelection(-1);
		if (down) moveSelection(1);

		if (accept) confirmSelection();
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
			return Language.getPhrase("Selected: ", "Selected: ") + resolveTranslation(availableOptions[selectedIndex], availableOptions[selectedIndex]);
		}
		return "";
	}

	function resolveTranslation(key:String, defaultVal:String):String
	{
		return Language.getPhrase(key, defaultVal);
	}

	function moveSelection(change:Int):Void
	{
		selectedIndex += change;
		if (selectedIndex < 0) selectedIndex = availableOptions.length - 1;
		if (selectedIndex >= availableOptions.length) selectedIndex = 0;
		ensureOptionVisible();
		updateDisplay();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function ensureOptionVisible():Void
	{
		if (selectedIndex < scrollOffset) scrollOffset = selectedIndex;
		else if (selectedIndex >= scrollOffset + VISIBLE_OPTIONS) scrollOffset = selectedIndex - (VISIBLE_OPTIONS - 1);
		if (scrollOffset < 0) scrollOffset = 0;
		if (scrollOffset > maxScrollOffset) scrollOffset = maxScrollOffset;
	}

	function updateDisplay():Void
	{
		for (i in 0...optionTexts.length)
		{
			var optionText = optionTexts.members[i];
			if (optionText == null) continue;

			var displayIndex = i - scrollOffset;
			optionText.y = listStartY + (48 * displayIndex);
			optionText.text = resolveTranslation(availableOptions[i], availableOptions[i]);
			if (this.isColorMode) {
				optionText.color = KEOption.COLOR_PALETTE[i];
			}

			var visible = displayIndex >= 0 && displayIndex < VISIBLE_OPTIONS;
			optionText.alpha = visible ? 1 : 0;
		}

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
		FlxTween.tween(topEdge, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(bottomEdge, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(headerBack, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(titleText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(typeText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(valueText, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
		FlxTween.tween(descBack, {alpha: 0}, 0.2, {ease: FlxEase.sineIn});
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