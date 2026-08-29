package options;

import flixel.math.FlxRect;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import states.MainMenuState;
import backend.MusicBeatState;
import backend.StageData;

import objects.BiosDateDisplay;
import objects.DraggableBar;

import backend.MouseMove;
import backend.MouseEvent;

#if !flash
#end

class KEOptionsMenu extends MusicBeatState
{
	public static var instance:KEOptionsMenu;

	public var background:FlxSprite;
	public var bg:FlxFilteredSprite;
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
	public static var isFreeplay:Bool = false;

	var space:FlxSprite;
    var starsBG:FlxBackdrop;
    var starsFG:FlxBackdrop;

	public var dateDisplay:BiosDateDisplay;

	var notes:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
	var splashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
	var holdCovers:Array<String> = Mods.mergeAllTextsNamed('images/holdCover/list.txt');
	var ratings:Array<String> = Mods.mergeAllTextsNamed('images/ratings/list.txt');
	var pauseMusicList:Array<String> = Mods.mergeAllTextsNamed('music/list.txt');
	var hitsoundList:Array<String> = Mods.mergeAllTextsNamed('sounds/hitsounds/HitSound.txt');
	
	var changedOption:Bool = false;
	public var descText:FlxText;
	public var descBack:FlxFilteredSprite;
	var valueBar:DraggableBar;
	var valueBarText:FlxText;

	var scrollOffset:Int = 0;
	var maxScrollOffset:Int = 0;
	
	var isClosing:Bool = false;
	var closeTimer:FlxTimer;

	var langReloadCb:Void->Void;
	
	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;
	var scrollHoldTime:Float = 0;
	
	var optionClickCooldown:Float = 0;
	var optionClickProtected:Bool = false;
	
	static var VISIBLE_OPTIONS:Int = 11;

	public static var SCREEN_WIDTH:Int = FlxG.width;
	public static var SCREEN_HEIGHT:Int = FlxG.height;
	public static var MARGIN_TOP:Int = 60;
	public static var MARGIN_BOTTOM:Int = 100;
	public static var CATEGORY_COUNT:Int = 5;
	public static var CATEGORY_WIDTH:Int = Std.int(SCREEN_WIDTH / CATEGORY_COUNT);
	public static var CATEGORY_HEIGHT:Int = 50;
	public static var OPTION_LEFT_MARGIN:Int = 20;
	public static var OPTION_WIDTH:Int = 550;
	public static var TAB_ALPHA:Float = 0.8;
	public static var OPTION_ALPHA:Float = 0.6;
	public static var DESC_ALPHA:Float = 0.8;

	public static var optionScrollPos:Float = 0;
    
    var optionScroller:MouseMove;

    var _lastResolution:Int = -1;
    
    // 普通分辨率名称
    var _resolutionNames:Array<String> = [
        "1280x720 (720p)",
        "1920x1080 (1080p)",
        "2560x1440 (1440p)",
        "3840x2160 (2160p)"
    ];
    
    // 普通分辨率
    var _normalResolutions:Array<Array<Int>> = [
        [1280, 720],
        [1920, 1080],
        [2560, 1440],
        [3840, 2160]
    ];

	public static function updateLayout():Void
	{
		SCREEN_WIDTH = Std.int(FlxG.width);
		SCREEN_HEIGHT = Std.int(FlxG.height);
		MARGIN_TOP = Std.int(SCREEN_HEIGHT * 0.083);
		MARGIN_BOTTOM = Std.int(SCREEN_HEIGHT * 0.14);
		CATEGORY_WIDTH = Std.int(SCREEN_WIDTH / CATEGORY_COUNT);
		CATEGORY_HEIGHT = Std.int(Math.max(40, Std.int(SCREEN_HEIGHT * 0.07)));
		OPTION_LEFT_MARGIN = Std.int(Math.max(16, Std.int(SCREEN_WIDTH * 0.015)));
		OPTION_WIDTH = Std.int(SCREEN_WIDTH * 0.43);
	}
    
    // 21:9 宽屏分辨率
    var _wideResolutions:Array<Array<Int>> = [
        [Math.round(720 * 21.0 / 9.0), 720],   // 1680x720
        [Math.round(1080 * 21.0 / 9.0), 1080], // 2520x1080
        [Math.round(1440 * 21.0 / 9.0), 1440], // 3360x1440
        [Math.round(2160 * 21.0 / 9.0), 2160]  // 5040x2160
    ];
    
    // 宽屏分辨率名称
    var _wideResolutionNames:Array<String> = [
        "1680x720 (21:9)",
        "2520x1080 (21:9)",
        "3360x1440 (21:9)",
        "5040x2160 (21:9)"
    ];
    
    // 获取当前分辨率列表
    function getCurrentResolutions():Array<Array<Int>>
    {
        var wideScreen:Bool = ClientPrefs.data != null && ClientPrefs.data.wideScreen;
        return wideScreen ? _wideResolutions : _normalResolutions;
    }
    
    // 获取当前分辨率名称列表
    function getCurrentResolutionNames():Array<String>
    {
        var wideScreen:Bool = ClientPrefs.data != null && ClientPrefs.data.wideScreen;
        return wideScreen ? _wideResolutionNames : _resolutionNames;
    }

	function getResolutionName(index:Int):String
	{
		var names = getCurrentResolutionNames();
		if (index >= 0 && index < names.length) return names[index];
		return "Unknown";
	}

	function refreshResolutionText():Void
	{
		if (selectedCat == null || selectedCat.optionObjects == null) return;
		for (i in 0...selectedCat.options.length)
		{
			var opt = selectedCat.options[i];
			if (opt != null && opt.variable == "renderResolution" && opt.type == "int")
			{
				var idx = Std.int(opt.value);
				var text = "Resolution: < " + getResolutionName(idx) + " >";
				var optionText = selectedCat.optionObjects.members[i];
				if (optionText != null) optionText.text = text;
			}
		}
	}

	function applyRenderResolution(index:Int):Void
	{
		var resolutions = getCurrentResolutions();
		if (index < 0 || index >= resolutions.length) return;
		if (index == _lastResolution) return;
		if (ClientPrefs.data.useDpiSettings) return;
		
		var res = resolutions[index];
		var w = res[0];
		var h = res[1];
		
		#if (cpp || hl)
		try {
			var window = openfl.Lib.current.stage.window;
			window.resize(w, h);
			var displayBounds = window.display.bounds;
			window.x = Std.int(displayBounds.x + (displayBounds.width - w) / 2);
			window.y = Std.int(displayBounds.y + (displayBounds.height - h) / 2);
		} catch(e:Dynamic) {}
		#end
		flixel.FlxG.resizeGame(w, h);
		flixel.FlxG.scaleMode = new flixel.system.scaleModes.RatioScaleMode(false);
		_lastResolution = index;
	}

	public function new(pauseMenu:Bool = false)
	{
		super();

		isInPause = pauseMenu;
		notes.insert(0, ClientPrefs.defaultData.noteSkin);
		splashes.insert(0, ClientPrefs.defaultData.splashSkin);
		holdCovers.insert(0, ClientPrefs.defaultData.holdCoverSkin);
		ratings.insert(0, ClientPrefs.defaultData.customUI);
		pauseMusicList = ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)'];
		if (hitsoundList.length == 0) hitsoundList = ['hitsound'];
		for (i in 0...hitsoundList.length)
		{
			if (!hitsoundList[i].contains('/')) hitsoundList[i] = 'hitsounds/' + hitsoundList[i];
		}
		//if (!hitsoundList.contains('hitsound')) hitsoundList.insert(0, 'hitsound');
	}

	override function create()
	{
		super.create();
		updateLayout();

		options = [
			new KEOptionCata(0, MARGIN_TOP, "Basics", getControlsOptions()),
			new KEOptionCata(CATEGORY_WIDTH, MARGIN_TOP, "Gameplay", getGameplayOptions()),
			new KEOptionCata(CATEGORY_WIDTH * 2, MARGIN_TOP, "Visuals", getVisualsOptions()),
			new KEOptionCata(CATEGORY_WIDTH * 3, MARGIN_TOP, "Graphics", getAppearanceOptions()),
			new KEOptionCata(CATEGORY_WIDTH * 4, MARGIN_TOP, "Advanced", getAdvancedOptions())
		];

		shownStuff = new FlxTypedGroup<FlxText>();
		/*for(text in shownStuff.members)
			text.antialiasing = ClientPrefs.data.antialiasing;*/

		
		background = new FlxSprite(0, 0).makeGraphic(SCREEN_WIDTH, SCREEN_HEIGHT, FlxColor.BLACK);
		background.alpha = 0;
		background.scrollFactor.set();
		add(background);

		var optionBg = new FlxFilteredSprite();
		optionBg.loadGraphic(Paths.image('menuDesat'));
		if(ClientPrefs.data.blurEffects)optionBg.filters = [new BlurFilter(4, 4, BitmapFilterQuality.HIGH)];
		optionBg.alpha = 1;
		optionBg.scrollFactor.set();
		optionBg.antialiasing = ClientPrefs.data.antialiasing;
		optionBg.screenCenter();
		add(optionBg);

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

		var contentStartY:Int = MARGIN_TOP + CATEGORY_HEIGHT;
		var contentHeight:Int = SCREEN_HEIGHT - MARGIN_TOP - MARGIN_BOTTOM - CATEGORY_HEIGHT;
		
		bg = new FlxFilteredSprite(0, contentStartY);
		bg.makeGraphic(SCREEN_WIDTH, contentHeight, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.scrollFactor.set();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		descBack = new FlxFilteredSprite(0, SCREEN_HEIGHT - MARGIN_BOTTOM);
		descBack.makeGraphic(SCREEN_WIDTH, 32, FlxColor.BLACK);
		descBack.alpha = DESC_ALPHA;
		descBack.scrollFactor.set();
		descBack.antialiasing = ClientPrefs.data.antialiasing;
		//descBack.filters = [blurFilter];
		add(descBack);

		add(shownStuff);

		for (i in 0...options.length)
		{
			var cat = options[i];
			
			cat.makeGraphic(CATEGORY_WIDTH, CATEGORY_HEIGHT, FlxColor.BLACK);
			cat.x = i * CATEGORY_WIDTH;
			cat.y = MARGIN_TOP;
			cat.alpha = TAB_ALPHA;
			
			cat.titleObject.x = cat.x + (CATEGORY_WIDTH / 2) - (cat.titleObject.fieldWidth / 2);
			cat.titleObject.y = cat.y + (CATEGORY_HEIGHT / 2) - (cat.titleObject.height / 2);
			cat.titleObject.alpha = 1.0;
			
			add(cat);
			add(cat.titleObject);
		}

		descText = new FlxText(10, SCREEN_HEIGHT - MARGIN_BOTTOM + 5, SCREEN_WIDTH - 20);
		descText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 2;
		descText.alpha = 1.0;
		descText.antialiasing = ClientPrefs.data.antialiasing;
		add(descText);

	valueBar = new DraggableBar(0, SCREEN_HEIGHT - MARGIN_BOTTOM + 20, 'healthBar', function() return getSelectedOptionValue(), 0, 1);
	valueBar.scrollFactor.set();
	valueBar.visible = false;
	valueBar.cameras = [FlxG.camera];
	valueBar.screenCenter(X);
	valueBar.onValueChanged = function(percentValue:Float) {
		if (selectedOption == null || !isNumericOption(selectedOption)) return;
		var rawValue:Float = FlxMath.lerp(selectedOption.minValue, selectedOption.maxValue, percentValue / 100);
		var newValue:Float = snapOptionValue(rawValue, selectedOption);
		selectedOption.value = newValue;
		selectedOption.saveCurrentValue();
		ClientPrefs.saveSettings();
		doSelectCurrentOption();
	};
	valueBarText = new FlxText(0, valueBar.y - 32, SCREEN_WIDTH, "");
	valueBarText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
	valueBarText.borderSize = 2;
	valueBarText.visible = false;
	valueBarText.cameras = [FlxG.camera];
	valueBarText.antialiasing = ClientPrefs.data.antialiasing;
	add(valueBar);
	add(valueBarText);

		dateDisplay = new BiosDateDisplay(FlxG.width/2 , 30, 20, FlxColor.WHITE, true);
		dateDisplay.setShowSeconds(true);
		dateDisplay.setMilitaryTime(false);
		dateDisplay.scrollFactor.set();
		dateDisplay.antialiasing = ClientPrefs.data.antialiasing;
		add(dateDisplay);

		selectedCat = options[0];
		doSwitchToCat(selectedCat, false);

		var colorArray:Array<FlxColor> = [
			FlxColor.fromRGB(148, 0, 211),
			FlxColor.fromRGB(75, 0, 130),
			FlxColor.fromRGB(0, 0, 255),
			FlxColor.fromRGB(0, 255, 0),
			FlxColor.fromRGB(255, 255, 0),
			FlxColor.fromRGB(255, 127, 0),
			FlxColor.fromRGB(255, 0, 0)
		];

		var currentColorIndex:Int = 0;
		var nextColorIndex:Int = 1;
		var colorTransitionTime:Float = 2.5;

		function startColorCycle():Void
		{
			FlxTween.color(optionBg, colorTransitionTime, optionBg.color, colorArray[nextColorIndex], {
				onComplete: function(twn:FlxTween)
				{
					currentColorIndex = nextColorIndex;
					nextColorIndex = (nextColorIndex + 1) % colorArray.length;
					startColorCycle();
				}
			});
		}

		var bgColorArray:Array<FlxColor> = [
			FlxColor.fromRGB(30, 30, 46),
			FlxColor.fromRGB(46, 30, 46),
			FlxColor.fromRGB(30, 46, 46),
			FlxColor.fromRGB(46, 46, 30)
		];

		var bgCurrentColorIndex:Int = 0;
		var bgNextColorIndex:Int = 1;
		var bgColorTransitionTime:Float = 3.0;

		background.color = bgColorArray[bgCurrentColorIndex];

		function startBgColorCycle():Void
		{
			FlxTween.color(background, bgColorTransitionTime, background.color, bgColorArray[bgNextColorIndex], {
				onComplete: function(twn:FlxTween)
				{
					bgCurrentColorIndex = bgNextColorIndex;
					bgNextColorIndex = (bgNextColorIndex + 1) % bgColorArray.length;
					startBgColorCycle();
				}
			});
		}

		instance = this;
		
		startColorCycle();
		startBgColorCycle();

		var self = this;
		langReloadCb = function() {
			self.onLanguageReload();
		};
		backend.Language.addReloadCallback(langReloadCb);

		var totalOptionsHeight:Float = selectedCat.options.length * 46;
        var visibleHeight:Float = SCREEN_HEIGHT - MARGIN_TOP - CATEGORY_HEIGHT - MARGIN_BOTTOM - 20;
        var minScroll:Float = 0;
        var maxScroll:Float = Math.max(0, totalOptionsHeight - visibleHeight);
        
        var contentStartY:Float = MARGIN_TOP + CATEGORY_HEIGHT + 10;
        var contentHeight:Float = SCREEN_HEIGHT - MARGIN_TOP - CATEGORY_HEIGHT - MARGIN_BOTTOM - 20;
        
        optionScroller = new MouseMove(
            KEOptionsMenu,
            'optionScrollPos',
            [minScroll, maxScroll],
            [
                [0, SCREEN_WIDTH],
                [contentStartY, contentStartY + contentHeight]
            ],
            onScrollChange
        );
        optionScroller.useLerp = true;
        optionScroller.lerpSmooth = 10;
        optionScroller.dragSensitivity = 1.5;
        optionScroller.deceleration = 0.96;
        optionScroller.enableMouseWheel = false;
        add(optionScroller);
	}
	
	
	function onLanguageReload():Void
	{
		for (i in 0...options.length) {
			var cat = options[i];
			if (cat.titleObject != null) cat.titleObject.text = backend.Language.getPhrase(cat.title, cat.title);
			for (j in 0...cat.optionObjects.members.length) {
				var txt = cat.optionObjects.members[j];
				if (txt != null && j < cat.options.length) txt.text = cat.options[j].getValue();
			}
		}

		for (i in 0...options.length) {
			var cat = options[i];
			if (cat.titleObject != null) cat.titleObject.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			for (j in 0...cat.optionObjects.members.length) {
				var txt = cat.optionObjects.members[j];
				if (txt != null) txt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			}
		}

		if (selectedCat != null && selectedCat.optionObjects != null) {
			for (i in selectedCat.optionObjects) {
				if (i != null) i.text = selectedCat.options[selectedCat.optionObjects.members.indexOf(i)].getValue();
			}
		}
		if (selectedOption != null) {
			descText.text = selectedOption.getDescription();
			descText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		}
	}
	
	
	override function destroy()
	{
		super.destroy();
		try {
			if (langReloadCb != null) backend.Language.removeReloadCallback(langReloadCb);
		} catch(e:Dynamic) {}
		instance = null;
	}

	public function doSwitchToCat(cat:KEOptionCata, checkForOutOfBounds:Bool = true)
	{
    scrollOffset = 0;
    optionScrollPos = 0;
    
    if (selectedCat != null && selectedCat.optionObjects != null)
    {
        for (i in 0...selectedCat.optionObjects.members.length)
        {
            var object = selectedCat.optionObjects.members[i];
            if(object != null && i < selectedCat.options.length) {
                object.text = selectedCat.options[i].getValue();
                object.color = FlxColor.WHITE;
            }
        }
    }

    if (checkForOutOfBounds && selectedCatIndex > options.length - 1)
        selectedCatIndex = 0;

    if (selectedCat != null && selectedCat.middle)
        remove(selectedCat.titleObject);

    if (selectedCat != null) {
        selectedCat.changeColor(FlxColor.BLACK);
        selectedCat.alpha = TAB_ALPHA;
        if (selectedCat.titleObject != null)
        {
            selectedCat.titleObject.color = FlxColor.WHITE;
            selectedCat.titleObject.alpha = 1.0;
        }
    }

    shownStuff.clear();
    
    selectedCat = cat;
    selectedCat.alpha = OPTION_ALPHA;
    selectedCat.changeColor(FlxColor.BLACK);

    if (selectedCat.middle)
        add(selectedCat.titleObject);

    for (i in selectedCat.optionObjects)
    {
        if(i != null) 
        {
            shownStuff.add(i);
            i.color = FlxColor.WHITE;
        }
    }

    if(selectedCat.options.length > 0) {
        selectedOption = selectedCat.options[0];
        selectedOptionIndex = 0;
    }

    var totalOptionsHeight = selectedCat.options.length * 46;
    var visibleHeight = SCREEN_HEIGHT - MARGIN_TOP - CATEGORY_HEIGHT - MARGIN_BOTTOM - 20;
    maxScrollOffset = Std.int(Math.max(0, (totalOptionsHeight - visibleHeight) / 46));
    
    if (optionScroller != null) {
        optionScroller.moveLimit = [0, maxScrollOffset * 46];
    }
    
    updateOptionPositions();
    refreshResolutionText();
    doSelectCurrentOption();
}

	public function doSelectCurrentOption()
	{
		for (i in 0...selectedCat.optionObjects.members.length)
		{
			var object = selectedCat.optionObjects.members[i];
			if(object != null && i < selectedCat.options.length) {
				var currentValue = selectedCat.options[i].getValue();
				if (currentValue.startsWith("> ")) {
					object.text = currentValue.substring(2);
				} else {
					object.text = currentValue;
				}
			}
		}
		
		var object = selectedCat.optionObjects.members[selectedOptionIndex];
		if(object != null) {
			var currentValue = selectedOption.getValue();
			if (!currentValue.startsWith("> ")) {
				object.text = "> " + currentValue;
			} else {
				object.text = currentValue;
			}
			descText.text = selectedOption.getDescription();
			descText.color = FlxColor.WHITE;
		}
		refreshResolutionText();
		updateValueBar();
		
		ensureOptionVisible();
	}

function updateOptionPositions()
{
    if (selectedCat == null || selectedCat.optionObjects == null) return;
    
    var contentStartY = MARGIN_TOP + CATEGORY_HEIGHT + 10;
    
    for (i in 0...selectedCat.optionObjects.members.length)
    {
        var optionText = selectedCat.optionObjects.members[i];
        if(optionText == null) continue;
        
        var displayIndex = i - scrollOffset;
        
        optionText.y = contentStartY + (46 * displayIndex);
        
        optionText.x = OPTION_LEFT_MARGIN;
        
        var isVisible = (displayIndex >= 0 && displayIndex < VISIBLE_OPTIONS);
        
        if (isVisible)
        {
            optionText.alpha = (i == selectedOptionIndex) ? 1.0 : OPTION_ALPHA;
        }
        else
        {
            optionText.alpha = 0;
        }
    }
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
	else if (option.type == "float") snapped = roundToDecimals(snapped, getStepDecimals(step));
	if (snapped < option.minValue) snapped = option.minValue;
	if (snapped > option.maxValue) snapped = option.maxValue;
	return snapped;
}

private function ensureOptionVisible()
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

function scrollOptions(change:Int, isLongPress:Bool = false)
{
    if (selectedCat == null) return;
    
    var newOffset = scrollOffset + change;
    
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
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
    } else if (scrollHoldTime % 2 == 0) {
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
    }
}

	override function update(elapsed:Float)
{
    starsBG.x -= 0.05;
    starsFG.x -= 0.15;
    
    if (starsBG.x < -starsBG.width) starsBG.x = 0;
    if (starsFG.x < -starsFG.width) starsFG.x = 0;

    super.update(elapsed);
    
    // 检查分辨率是否需要更新 - 使用当前分辨率列表
    var curRes = ClientPrefs.data.renderResolution;
    var resolutions = getCurrentResolutions();
    if (curRes >= 0 && curRes < resolutions.length && curRes != _lastResolution && !FlxG.save.data.fullscreen) {
        applyRenderResolution(curRes);
    }
    
    if (optionClickCooldown > 0) {
        optionClickCooldown -= elapsed;
        if (optionClickCooldown <= 0) {
            optionClickProtected = false;
        }
    }
    
    FlxG.mouse.visible = true;
    FlxG.mouse.useSystemCursor = ClientPrefs.data.useSystemCursor;

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
		else if (isFreeplay)
			MusicBeatState.switchState(new states.FreeplayState());
		else
			MusicBeatState.switchState(new MainMenuState());
    }

    if (isClosing) return;

    var hoveredOptionIndex = -1;
    var hoveredCatIndex = -1;
    
    for (i in 0...options.length)
    {
        var cat = options[i];
        if (cat != null && cat.titleObject != null && FlxG.mouse.overlaps(cat.titleObject))
        {
            hoveredCatIndex = i;
            break;
        }
    }
    
    if (selectedCat != null && selectedCat.optionObjects != null)
    {
        for (i in 0...selectedCat.optionObjects.members.length)
        {
            var optionText = selectedCat.optionObjects.members[i];
            if (optionText == null || optionText.alpha == 0) continue;
            
            if (FlxG.mouse.overlaps(optionText))
            {
                hoveredOptionIndex = i;
                break;
            }
        }
    }
    
    for (i in 0...options.length)
    {
        var cat = options[i];
        if (cat != null && cat.titleObject != null)
        {
            if (i == selectedCatIndex)
            {
                cat.titleObject.color = FlxColor.WHITE;
                cat.titleObject.alpha = 1;
                cat.alpha = 0.6;
            }
            else if (i == hoveredCatIndex)
            {
                cat.titleObject.color = FlxColor.YELLOW;
                cat.titleObject.alpha = 0.8;
                cat.alpha = 0.5;
            }
            else
            {
                cat.titleObject.color = FlxColor.WHITE;
                cat.titleObject.alpha = 0.6;
                cat.alpha = 0.8;
            }
        }
    }
    
    updateOptionPositions();
    
    if (selectedCat != null && selectedCat.optionObjects != null)
    {
        for (i in 0...selectedCat.optionObjects.members.length)
        {
            var optionText = selectedCat.optionObjects.members[i];
            if (optionText == null || optionText.alpha == 0) continue;
            
            if (i == selectedOptionIndex)
            {
                optionText.color = FlxColor.WHITE;
            }
            else if (i == hoveredOptionIndex)
            {
                optionText.color = FlxColor.YELLOW;
            }
            else
            {
                optionText.color = FlxColor.WHITE;
            }
        }
    }
    
    if (FlxG.mouse.wheel != 0)
    {
        var wheelDelta = - FlxG.mouse.wheel;
        scrollOptions(wheelDelta, false);
    }

    var accept = controls.ACCEPT;
    var right = controls.UI_RIGHT_P;
    var left = controls.UI_LEFT_P;
    var up = controls.UI_UP_P;
    var down = controls.UI_DOWN_P;
    var rightPressed = controls.UI_RIGHT;
    var leftPressed = controls.UI_LEFT;
    var upPressed = controls.UI_UP;
    var downPressed = controls.UI_DOWN;

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

    if (selectedCat != null && selectedCat.optionObjects != null && FlxG.mouse.justPressed && !optionClickProtected)
    {
        for (i in 0...selectedCat.optionObjects.members.length)
        {
            var optionText = selectedCat.optionObjects.members[i];
            if (optionText == null || optionText.alpha == 0) continue;
            
            var option = selectedCat.options[i];
            if (option == null) continue;
            
            if (FlxG.mouse.overlaps(optionText))
            {
                selectedOptionIndex = i;
                selectedOption = option;
                
                ensureOptionVisible();
                updateOptionPositions();
                doSelectCurrentOption();
                
                option.press();
                ClientPrefs.saveSettings();
                doSelectCurrentOption();
                
                optionClickProtected = true;
                optionClickCooldown = 0.2;
                break;
            }
        }
    }
    
    if (up)
    {
        if (selectedOptionIndex > 0) {
            selectedOptionIndex--;
            selectedOption = selectedCat.options[selectedOptionIndex];
            ensureOptionVisible();
            updateOptionPositions();
            doSelectCurrentOption();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        } else if (scrollOffset > 0) {
            scrollOptions(-1, false);
        }
    }
    
    if (down)
    {
        if (selectedOptionIndex < selectedCat.options.length - 1) {
            selectedOptionIndex++;
            selectedOption = selectedCat.options[selectedOptionIndex];
            ensureOptionVisible();
            updateOptionPositions();
            doSelectCurrentOption();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        } else if (scrollOffset < maxScrollOffset) {
            scrollOptions(1, false);
        }
    }
    
    if (upPressed) {
        holdUpTime += elapsed;
        if (holdUpTime > 0.3) {
            scrollHoldTime += elapsed;
            if (scrollHoldTime >= 0.05) {
                scrollHoldTime = 0;
                if (selectedOptionIndex > 0) {
                    selectedOptionIndex--;
                    selectedOption = selectedCat.options[selectedOptionIndex];
                    ensureOptionVisible();
                    updateOptionPositions();
                    doSelectCurrentOption();
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
                } else if (scrollOffset > 0) {
                    scrollOptions(-1, true);
                }
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
                if (selectedOptionIndex < selectedCat.options.length - 1) {
                    selectedOptionIndex++;
                    selectedOption = selectedCat.options[selectedOptionIndex];
                    ensureOptionVisible();
                    updateOptionPositions();
                    doSelectCurrentOption();
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
                } else if (scrollOffset < maxScrollOffset) {
                    scrollOptions(1, true);
                }
            }
        }
    } else {
        holdDownTime = 0;
    }
    
    if (!upPressed && !downPressed) {
        scrollHoldTime = 0;
    }

    if (selectedOption != null && selectedOption.getAccept())
    {
        var optionChangedByHold = selectedOption.updateHold(elapsed, leftPressed, rightPressed);
        if (optionChangedByHold)
        {
            ClientPrefs.saveSettings();
            doSelectCurrentOption();
        }
        
        if (right && !optionChangedByHold)
        {
            selectedOption.right();
            ClientPrefs.saveSettings();
            doSelectCurrentOption();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        }
        else if (left && !optionChangedByHold)
        {
            selectedOption.left();
            ClientPrefs.saveSettings();
            doSelectCurrentOption();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        }
    }
    else
    {
        if (right)
        {
            selectedCatIndex++;
            if (selectedCatIndex >= options.length) selectedCatIndex = 0;
            doSwitchToCat(options[selectedCatIndex]);
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        }
        else if (left)
        {
            selectedCatIndex--;
            if (selectedCatIndex < 0) selectedCatIndex = options.length - 1;
            doSwitchToCat(options[selectedCatIndex]);
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
        }
    }

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
	
	private function handleUpKey(isLongPress:Bool = false)
	{
		if (selectedCat == null || selectedCat.options.length == 0) return;
		
		if (selectedOptionIndex > 0) {
			selectedOptionIndex--;
			selectedOption = selectedCat.options[selectedOptionIndex];
			
			ensureOptionVisible();
			
			doSelectCurrentOption();
			
			if (!isLongPress) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			}
		} else if (isLongPress && scrollOffset > 0) {
			scrollOptions(-1, isLongPress);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		}
	}
	
	private function handleDownKey(isLongPress:Bool = false)
	{
		if (selectedCat == null || selectedCat.options.length == 0) return;
		
		if (selectedOptionIndex < selectedCat.options.length - 1) {
			selectedOptionIndex++;
			selectedOption = selectedCat.options[selectedOptionIndex];
			
			ensureOptionVisible();
			
			doSelectCurrentOption();
			
			if (!isLongPress) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			}
		} else if (isLongPress && scrollOffset < maxScrollOffset) {
			scrollOptions(1, isLongPress);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		}
	}
	
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

function onScrollChange()
{
    if (selectedCat == null || selectedCat.options.length == 0) return;
    
    var newScrollOffset = Math.round(optionScrollPos / 46);
    
    if (newScrollOffset != scrollOffset)
    {
        scrollOffset = newScrollOffset;
        if (scrollOffset < 0) scrollOffset = 0;
        if (scrollOffset > maxScrollOffset) scrollOffset = maxScrollOffset;
        updateOptionPositions();
    }
}

	// 修改 getAppearanceOptions 中的 Resolution 选项
	function getAppearanceOptions():Array<KEOption>
	{
		var fpsOptions = KEOption.createSubMenu(
			"FPS Counter",
			"Configure FPS counter settings",
			[
				KEOption.create("FPS Counter", "Show FPS counter", "showFPS", "bool"),
				KEOption.create("Show OS", "Show operating system in FPS Counter", "showOS", "bool"),
				KEOption.create("Show API", "Show graphics API in FPS Counter", "showApi", "bool"),
				KEOption.create("Show TPS", "Show ticks per second in FPS Counter", "showTPS", "bool"),
				KEOption.create("Show Memory Peak", "Show peak memory usage in FPS Counter", "showMEMPeak", "bool"),
			],
			"",
			"FPS Counter Settings"
		);
		
		// 获取当前分辨率名称列表的最大索引
		var maxResIdx = getCurrentResolutionNames().length - 1;
		
		return [
			fpsOptions,
			KEOption.create("Low Quality", "Reduce graphics for performance", "lowQuality", "bool"),
			KEOption.create("Anti-Aliasing", "Smoother visuals", "antialiasing", "bool"),
			// 修改 Resolution 选项 - 动态获取最大索引
			KEOption.create("Resolution", "Change the game's render resolution.", "renderResolution", "int", 0, 0, maxResIdx, 1),
			KEOption.create("dpiScale", "Scale the game based on your screen's DPI", "useDpiSettings", "bool"),
			KEOption.create("Shaders", "Enable shader effects", "shaders", "bool"),
			KEOption.create("Wide Screen", "Enable 21:9 widescreen mode", "wideScreen", "bool"),
			KEOption.create("GPU Caching", "Use GPU for texture caching", "cacheOnGPU", "bool"),
			KEOption.create("Devide Draw And Update", "Draw and Update in separate threads", "devideDrawAndUpdate", "bool"),
			KEOption.create("Framerate", "Target framerate", "framerate", "int", 60, 60, 480, 1),
			KEOption.create("Update Rate", "Target update rate", "updaterate", "int", 60, 60, 480, 1),
			KEOption.create("Unlimited FPS", "Remove framerate cap (also for update rate)", "unlimitedFPS", "bool"),
			KEOption.create("FPS Rework", "Make ur game more smooth", "fpsRework", "bool")
		];
	}

	// 其他函数保持不变...
	function getGameplayOptions():Array<KEOption>
	{
		var windowSettings = KEOption.createSubMenu(
			"Window Settings",
			"Configure window and timing settings",
			[
				KEOption.create("Marvelous Window", "Timing window for SICK", "marvelousWindow", "float", 22.5, 10, 22.5, 0.5),
				KEOption.create("Sick Window", "Timing window for SICK", "sickWindow", "float", 45, 10, 45, 0.5),
				KEOption.create("Good Window", "Timing window for GOOD", "goodWindow", "float", 90, 10, 90, 0.5),
				KEOption.create("Bad Window", "Timing window for BAD", "badWindow", "float", 135, 10, 135, 0.5),
				KEOption.create("Safe Frames", "Frames for early/late hits", "safeFrames", "float", 10, 2, 10, 1)
			],
			"",
			"Window Settings"
		);

		return [
			KEOption.create("Downscroll", "Notes scroll downwards instead of upwards", "downScroll", "bool"),
			KEOption.create("Middlescroll", "Put your lane in the center", "middleScroll", "bool"),
			KEOption.create("Opponent Notes", "Show opponent's strumline", "opponentStrums", "bool"),
			KEOption.create("Ghost Tapping", "Allow pressing keys without missing", "ghostTapping", "bool"),
			KEOption.create("Auto Pause", "Pause when window loses focus", "autoPause", "bool"),
			KEOption.create("Disable Reset", "Disable the reset button", "noReset", "bool"),
			KEOption.create("Guitar Hero Sustains", "Sustains count as one note", "guitarHeroSustains", "bool"),
			KEOption.create("Fast Restart", "Fast Restart When Dead or Press 'R' ", "skipDeath", "bool"),
			KEOption.create("Hitsound Volume", "Volume of hit sounds", "hitsoundVolume", "float", 0, 0, 1, 0.1),
			KEOption.create("Hitsound", "Choose the note hit sound", "hitsound", "string", hitsoundList),
			KEOption.create("Pause Music", "Choose pause screen music", "pauseMusic", "string", pauseMusicList),
			KEOption.create("Rating Offset", "Adjust note hit timing", "ratingOffset", "int", 0, -30, 30, 1),
			windowSettings,
			KEOption.create("Show Stage", "Show the stage", "showStage", "bool"),
			KEOption.create("Note Sustains Offset", "Adjust the timing offset for note sustains", "noteSustainsOffset", "float", 0, 0, 1, 0.05),
			KEOption.create("KE Style Sustains", "Enable KE style note sustains", "keLike", "bool")
		];
	}

	function getVisualsOptions():Array<KEOption>
	{
		var skinSettings = KEOption.createSubMenu(
			"Skin Settings",
			"Configure note skins, splashes and ratings",
			[
				KEOption.create("Note Skins" , "Select your preferred Note skin", "noteSkin","string" , notes),
				KEOption.create("Note Splashes", "Select your preferred Note Splash variation","splashSkin","string", splashes),
				KEOption.create("Note HoldCover", "Select your preferred Note Hold Cover","holdCoverSkin","string", holdCovers),
				KEOption.create("Judgements Style", "Select your preferred judgements Image","customUI","string", ratings),
				KEOption.create("Note Opacity", "Note transparency", "noteAlpha", "float", 0.9, 0, 1, 0.1),
				KEOption.create("Note Splash Opacity", "Note splash transparency", "splashAlpha", "float", 0.8, 0, 1, 0.1),
				KEOption.create("Note HoldCover Opacity", "Note splash transparency", "holdcoverAlpha", "float", 0.8, 0, 1, 0.1),
				KEOption.create("Force Number Color", "Force numbers to a specific color", "forceNumberColor", "bool"),
				KEOption.create("showEarlyLate", "Show early/late text on hit", "showEarlyLate", "bool"),
				KEOption.create("showCombo", "Show combo text when combo > 10", "showCombo", "bool"),
				KEOption.create("Force Note Skin", "Force using the custom note skin", "forceNoteSkin", "bool"),
				KEOption.create("Force Splash Skin", "Force using the custom splash skin", "forceSplashSkin", "bool"),
				KEOption.create("Force RGB Shader", "Force using the RGB shader for notes and splashes", "forceRGBShader", "bool")

			],
			"",
			"Skin Settings"
		);
		
		var hitErrorSettings = KEOption.createSubMenu(
			"Hit Error Bar",
			"Configure hit error bar display",
			[
				KEOption.create("Hit Error Bar", "Show hit error bar", "hitErrorBarVisible", "bool"),
				KEOption.create("Hit Bar Lines", "Number of lines on hit error bar", "hitBarLines", "int", 5, 0, 200, 1),
				KEOption.create("Hit Bar Line Time", "Time (in seconds) each line represents", "hitBarLineTime", "float", 2.0, 0.1, 5.0, 0.1),
				KEOption.create("Hit Error Bar Offset X", "Horizontal position of hit error bar", "hitErrorBarOffsetX", "int", 0, -500, 500, 1),
				KEOption.create("Hit Error Bar Offset Y", "Vertical position of hit error bar", "hitErrorBarOffsetY", "int", 0, -300, 300, 1),
				KEOption.create("Hit Error Bar MS", "Show MS on hit error bar rather than on ratings", "msInErrorBar", "bool")
			],
			"",
			"Hit Error Bar Settings"
		);

		var keyboardDisplayOptions = KEOption.createSubMenu(
			"Keyboard Display",
			"Configure keyboard display settings",
			[
				KEOption.create("Show Keyboard", "Display keyboard on screen", "kb", "bool"),
				KEOption.create("Keyboard Opacity", "Transparency of the keyboard display", "keyboardAlpha", "float", 1.0, 0.0, 1.0, 0.1),
				KEOption.create("Keyboard BG Color", "Background color of the keyboard display", "keyboardBGColor", "color", FlxColor.BLACK),
				KEOption.create("Keyboard Text Color", "Text color of the keyboard display", "keyboardTextColor", "color", FlxColor.WHITE),
				KEOption.create("Keyboard Offset X", "Horizontal position of the keyboard display", "kbOffsetX", "int", 0, -750, 750, 1),
				KEOption.create("Keyboard Offset Y", "Vertical position of the keyboard display", "kbOffsetY", "int", 0, -450, 750, 1),
				KEOption.create("Keyboard Time Display", "Change the keyboard time should display or not", "keyboardTimeDisplay", "bool"),
				KEOption.create("Keyboard Time Length", "Change the how long the keyboard is displayed", "keyboardTime", "float", 300, 0 , 2000, 20)
			],
			"",
			"Keyboard Display Settings"
		);
		var charthelperOptions = KEOption.createSubMenu(
			"Chart Helper",
			"Configure Chart Helper settings",
			[
				KEOption.create("Note Guide Line Opacity", "Transparency of the chart helper display", "guideLineAlpha", "float", 1.0, 0.0, 1.0, 0.1),
			],
			"",
			"Chart Helper Settings"
		);

		var freeplayOptions = KEOption.createSubMenu(
			"Freeplay",
			"Configure Freeplay settings",
			[
				KEOption.create("Old Freeplay Menu", "Use Psych Engine Default Freeplay Menu", "oldFreeplay", "bool"),
				KEOption.create("Card Glow", "Enable breathing glow under selected card", "cardGlow", "bool"),
				KEOption.create("Freeplay ToolBar", "Show tool bar in freeplay", "toolBar", "bool"),
				KEOption.create("New Freeplay Space BackGround", "Just a cool background lol", "freeplayspace", "bool"),
				KEOption.create("Save Freeplay Cache", "Save freeplay song metadata cache to disk", "saveFreeplayCache", "bool"),
				KEOption.create("Space Back Ground EveryWhere", "Show space background everywhere", "globalspace", "bool"),
				KEOption.create("Mod Folder Manager", "Organize mods in Freeplay using folder selector", "freeplayModFolder", "bool"),
				KEOption.create("Audio Display Number", "Change the relax audio number", "relaxAudioNumber", "int", 16, 1, 64, 1),
				KEOption.create("Audio Display Quality", "Change the relax audio display quality", "relaxAudioDisplayQuality", "int", 4, 1, 8, 1),
				KEOption.create("Audio Display Update Speed", "Change the relax audio display update speed", "audioDisplayUpdate", "int", 33, 33, 100, 1),
				KEOption.create("Audio Gain", "Change the relax audio range", "audioGain", "float", 1.0, 0.1, 10.0, 0.5),

			],
			"",
			"Freeplay Settings"
		);

		var judgementsCounterOptions = KEOption.createSubMenu(
			"Judgements Counter",
			"Configure Judgements Counter settings",
			[
				KEOption.create("Judgements Counter", "Show judgements counter", "Counter", "bool"),
				KEOption.create("Show Highest Combo", "Show highest combo in judgements counter", "showHC", "bool"),
				KEOption.create("Show Current Combo", "Show current combo in judgements counter", "showCB", "bool"),
				KEOption.create("Show Total Notes Hit", "Show total notes in judgements counter", "showTNH", "bool"),
				KEOption.create("Show Misses", "Show misses in judgements counter", "showMiss", "bool"),
			],
			"",
			"Judgements Counter Settings"
		);

		var songInfoTextOptions = KEOption.createSubMenu(
			"Song Info Text",
			"Configure Song Info Text settings",
			[
				KEOption.create("Song Info Text", "Show Song Info Text", "songText", "bool"),
				KEOption.create("Song Info Text Size", "Change the size of song info text", "songInfoTextSize", "float", 1.0, 0.5, 3.0, 0.1),
				KEOption.create("Show Difficulty", "Show difficulty in song info text", "showDifficulty", "bool"),
				KEOption.create("Song Engine Version", "Show engine version in song info text", "showEngineVer", "bool"),
			],
			"",
			"Song Info Text Settings"
		);
		
		return [
			skinSettings, 
			hitErrorSettings,
			keyboardDisplayOptions,
			charthelperOptions,
			freeplayOptions,
			judgementsCounterOptions,
			songInfoTextOptions,
			KEOption.create("Hide HUD", "Hide most HUD elements", "hideHud", "bool"),
			KEOption.create("Flashing Lights", "Enable screen flashes", "flashing", "bool"),
			KEOption.create("Camera Zooms", "Zoom camera on beat", "camZooms", "bool"),
			KEOption.create("Center Pause", "Center pause menu", "centerPause", "bool"),
			KEOption.create("Custom Color", "Color most things by opponent", "customColor", "bool"),
			KEOption.create("Gradient TimeBar", "Gradient colored timebar", "gradientTimeBar", "bool"),
			KEOption.create("Score Zoom", "Grow score text on hit", "scoreZoom", "bool"),
			KEOption.create('Time Bar',"What should the Time Bar display?","timeBarType","string",['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']),
			KEOption.create("Health Bar Alpha", "Health bar transparency", "healthBarAlpha", "float", 1, 0, 1, 0.1),
			KEOption.create("Combo Stacking", "Stack combo numbers", "comboStacking", "bool"),
			KEOption.create("MS Number", "Make you know how late/early ur when hit notes", "showMS", "bool"),
			KEOption.create("Health Text", "Show health as number", "healthText", "bool"),
			KEOption.create("Score Screen", "Show Kade-style results", "scoreScreen", "bool"),
			KEOption.create("Transition Type", "Choose the transition animation style when switching scenes", "transitionType", "string", ['fade', 'pixel', 'loading']),
			KEOption.create("Blur Effect", "Enable blur effect on background elements", "blurEffects", "bool"),
			KEOption.create("Skip Results Screen Fade Out", "Skip the exit results screen animation", "skipResultExitAnim", "bool"),
			KEOption.create("Charm Bar Pause", "Modern Pause Sub State", "charmPause", "bool"),
		];
	}

	function getControlsOptions():Array<KEOption>
	{
		return [
			KEOption.create("Open Note Colors", "Customize note colors", "", "action"),
			KEOption.create("Open Controls", "Customize key bindings", "", "action"),
			KEOption.create("Open EK Controls", "Customize key bindings for EK mode", "", "action"),
			KEOption.create("Adjust Delay and Combo", "Customize ingame experience", "", "action"),
			KEOption.create("Language", "Change the game's language", "language", "string", ['en-US', 'pt-BR', 'zh-CN', 'zh-TW']),
			KEOption.createResetOption("Reset KeyBinds", "keybinds"),
		];
	}

	function getAdvancedOptions():Array<KEOption>
	{
	return [
			KEOption.create("Check Updates", "Check for game updates", "checkForUpdates", "bool"),
			KEOption.create("Beta Updates", "Change the channel to beta", "betaUpdates", "bool"),
			KEOption.create("Loading Screen", "Show loading screen", "loadingScreen", "bool"),
			KEOption.create('Lua Text Antialiasing', "Enable antialiasing on lua texts", "luatextantialiasing", "bool"),
			KEOption.create("Enable LUA Debug Printer", "Uncheck it if u dont want to see them ", "luadebugPrint", "bool"),
			KEOption.create("Discord RPC", "Enable Discord Rich Presence", "discordRPC", "bool"),
			KEOption.create("Replay", "[Score Menu and Replay Required]", "saveReplays", "bool"),
			//KEOption.create("Replay Manager", "Manage and view ur Replays", "", "action"),
			KEOption.create("NewOptions", "Disable it if u dont like current options menu", "keOptions", "bool"),
			KEOption.createResetOption("Reset Settings", "settings"),
			KEOption.createResetOption("Reset Scores", "scores"),
			KEOption.create("About", "View information about the game", "", "action"),
			KEOption.create("Use Default Mouse Cursor", "Use ur system's default mouse cursor in game", "useSystemCursor", "bool")
		];
	}
}