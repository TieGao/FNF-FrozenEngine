package options.keoptions;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import states.MainMenuState;
import backend.MusicBeatState;
import backend.StageData;

import objects.BiosDateDisplay;
import objects.DraggableBar;
import objects.MessageBox;

import backend.MouseMove;
import options.objects.OptionInput;
import options.groupData.GraphicsData;
import shapeEx.Rect;

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
	public static var onPlayState:Bool = false;
	public static var onMainMenuState:Bool = false;
	public static var isFreeplay:Bool = false;

	/** 行高：行 y 网格与滚动/裁剪都基于它 */
	public static inline var ROW_H:Float = 46;

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

	var descText:FlxText;
	var valueBar:DraggableBar;
	var valueBarText:FlxText;

	// ---- 行系统（根列表 / 子视图共用） ----
	/** 当前行列表：根视图 = 分类选项；子视图 = [BACK 行] + 分组选项 */
	var selectedList:Array<KEOption> = [];
	var rows:Array<KEOptionRow> = [];
	var rowGroup:FlxTypedGroup<FlxBasic>;
	/** 下拉弹层挂这层，永远画在内容与描述框之上、不参与列表裁剪 */
	var overlay:FlxSpriteGroup;

	// ---- 主界面内子视图（原 KESubMenu 的替代） ----
	var inSubView:Bool = false;
	var subReturnIndex:Int = 0;
	var backOption:KEOption;
	/** 子视图首行：不可选中的标题（type="title"） */
	var titleOption:KEOption;

	var optionScroller:MouseMove;

	var langReloadCb:Void->Void;

	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;
	var scrollHoldTime:Float = 0;

	var optionClickCooldown:Float = 0;
	var optionClickProtected:Bool = false;

	// ---- 按压候选（拖拽防误触 + 点击先选择）----
	var pressRow:Int = -1;
	var pressWasSelected:Bool = false;
	var pressY:Float = 0;
	var pressTarget:Float = 0;

	// ---- 数值直接输入 ----
	var numericInput:Bool = false;
	var numericBuf:String = "";

	// ---- 选项卡下划线动效状态：0 隐藏 / 1 悬停半展 / 2 选中全展 ----
	var catUnderlines:Array<Rect> = [];
	var underlineStates:Array<Int> = [];

	var isClosing:Bool = false;

	var hoveredCatIndex:Int = -1;

	public static var SCREEN_WIDTH:Int = FlxG.width;
	public static var SCREEN_HEIGHT:Int = FlxG.height;
	public static var MARGIN_TOP:Int = 60;
	public static var MARGIN_BOTTOM:Int = 100;
	public static var CATEGORY_COUNT:Int = 5;
	public static var CATEGORY_WIDTH:Int = Std.int(SCREEN_WIDTH / CATEGORY_COUNT);
	public static var CATEGORY_HEIGHT:Int = 50;
	public static var OPTION_LEFT_MARGIN:Int = 20;
	public static var TAB_ALPHA:Float = 0.8;
	public static var OPTION_ALPHA:Float = 0.6;

	public static var optionScrollPos:Float = 0;

	public static function updateLayout():Void
	{
		SCREEN_WIDTH = Std.int(FlxG.width);
		SCREEN_HEIGHT = Std.int(FlxG.height);
		MARGIN_TOP = Std.int(SCREEN_HEIGHT * 0.083);
		MARGIN_BOTTOM = Std.int(SCREEN_HEIGHT * 0.14);
		CATEGORY_WIDTH = Std.int(SCREEN_WIDTH / CATEGORY_COUNT);
		CATEGORY_HEIGHT = Std.int(Math.max(40, Std.int(SCREEN_HEIGHT * 0.07)));
		OPTION_LEFT_MARGIN = Std.int(Math.max(16, Std.int(SCREEN_WIDTH * 0.015)));
	}

	// ---- 布局辅助 ----
	function contentStartY():Float
	{
		return MARGIN_TOP + CATEGORY_HEIGHT + 10;
	}

	function visibleHeight():Float
	{
		return SCREEN_HEIGHT - MARGIN_BOTTOM - contentStartY();
	}

	function maxScrollPixels():Float
	{
		return Math.max(0, selectedList.length * ROW_H - visibleHeight());
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

		var contentHeight:Int = SCREEN_HEIGHT - MARGIN_TOP - MARGIN_BOTTOM - CATEGORY_HEIGHT;

		bg = new FlxFilteredSprite(0, MARGIN_TOP + CATEGORY_HEIGHT);
		bg.makeGraphic(SCREEN_WIDTH, contentHeight, FlxColor.GRAY);
		bg.alpha = 0.8;
		bg.scrollFactor.set();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		// 选项卡 + 选中下划线
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

			// 下划线：默认收起（scaleX=0），选中时从中心展开
			var underlineW:Float = Math.min(cat.titleObject.width + 24, CATEGORY_WIDTH - 20);
			var underline = new Rect(cat.x + (CATEGORY_WIDTH - underlineW) / 2, MARGIN_TOP + CATEGORY_HEIGHT - 4,
				Std.int(underlineW), 3, 2, 2, FlxColor.WHITE, 0);
			underline.scrollFactor.set();
			underline.origin.set(underlineW / 2, 1.5);
			underline.scale.x = 0;
			catUnderlines.push(underline);
			underlineStates.push(0);
			add(underline);
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
			commitNumericPending();
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

		// 行画在描述框之后（被裁剪不会越过描述框区域），弹层最后、永远在最上
		rowGroup = new FlxTypedGroup<FlxBasic>();
		add(rowGroup);
		overlay = new FlxSpriteGroup();
		add(overlay);

		// 主界面内子视图的固定行
		titleOption = new KEOption();
		titleOption.name = "";
		titleOption.type = "title";
		backOption = new KEOption();
		backOption.name = "Back";
		backOption.type = "back";

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

		var contentHeightScroller:Float = SCREEN_HEIGHT - MARGIN_TOP - CATEGORY_HEIGHT - MARGIN_BOTTOM - 20;

		optionScroller = new MouseMove(
			KEOptionsMenu,
			'optionScrollPos',
			[0, maxScrollPixels()],
			[
				[0, SCREEN_WIDTH],
				[contentStartY(), contentStartY() + contentHeightScroller]
			],
			null
		);
		optionScroller.useLerp = true;
		optionScroller.lerpSmooth = 5; // 滑动动画放慢（10 → 5）
		optionScroller.dragSensitivity = 1.5;
		optionScroller.deceleration = 0.96;
		// 滚轮统一交给 MouseMove（velocity 惯性滚动，与模组界面同参），不再自配音效
		optionScroller.enableMouseWheel = true;
		optionScroller.mouseWheelSensitivity = -200.0;
		add(optionScroller);
	}

	function onLanguageReload():Void
	{
		// 选项卡标题 + 重新居中
		for (i in 0...options.length)
		{
			var cat = options[i];
			if (cat.titleObject != null)
			{
				cat.titleObject.text = backend.Language.getPhrase(cat.title, cat.title);
				cat.titleObject.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				cat.titleObject.x = cat.x + (CATEGORY_WIDTH / 2) - (cat.titleObject.fieldWidth / 2);
			}
		}

		// 行全部重建（名字/值重新走翻译链）
		rebuildRows();
		doSelectCurrentOption();
	}

	override function destroy()
	{
		super.destroy();
		try {
			if (langReloadCb != null) backend.Language.removeReloadCallback(langReloadCb);
		} catch(e:Dynamic) {}
		instance = null;
	}

	// ==================== 行构建与视图切换 ====================

	/** 按 selectedList 重建全部行（视图切换/语言重载时） */
	function rebuildRows():Void
	{
		for (row in rows)
			row.destroyAll();
		rows = [];
		rowGroup.clear();

		// BIOS 式统一列：下拉/输入框宽 0.2×宽、右缘固定 0.85×宽（右侧留白 0.15×宽）
		var widgetW:Float = SCREEN_WIDTH * 0.20;

		for (i in 0...selectedList.length)
		{
			var opt = selectedList[i];
			if (opt == null) continue;
			var row = new KEOptionRow(opt, i, widgetW, FlxColor.WHITE, overlay);
			row.attachTo(rowGroup);
			row.refreshTexts(valueTextFor);
			rows.push(row);
		}

		pressRow = -1; // 行已重建，进行中的按压候选作废

		if (optionScroller != null)
			optionScroller.moveLimit = [0, maxScrollPixels()];
	}

	public function doSwitchToCat(cat:KEOptionCata, checkForOutOfBounds:Bool = true)
	{
		closeWidgetPopups();
		commitNumericPending();
		inSubView = false;

		if (checkForOutOfBounds && selectedCatIndex > options.length - 1)
			selectedCatIndex = 0;

		if (selectedCat != null) {
			selectedCat.changeColor(FlxColor.BLACK);
			selectedCat.alpha = TAB_ALPHA;
			if (selectedCat.titleObject != null)
			{
				selectedCat.titleObject.color = FlxColor.WHITE;
				selectedCat.titleObject.alpha = 1.0;
			}
		}

		selectedCat = cat;
		selectedCat.alpha = OPTION_ALPHA;
		selectedCat.changeColor(FlxColor.BLACK);

		selectedList = selectedCat.options;
		selectedOptionIndex = 0;

		optionScrollPos = 0;
		if (optionScroller != null)
		{
			optionScroller.target = 0;
			optionScroller.velocity = 0;
		}

		rebuildRows();
		updateUnderlines(false); // 点击切换也走 tween，展开条有过渡而不是直接变长
		doSelectCurrentOption();
	}

	/** 进入分组子视图：首行 = 不可选中标题，次行 = BACK，其后是组内选项 */
	function enterSubView(group:KEOption):Void
	{
		closeWidgetPopups();
		commitNumericPending();

		subReturnIndex = selectedOptionIndex;
		titleOption.name = backend.Language.getPhrase(group.subMenuTitle, group.subMenuTitle);
		backOption.name = backend.Language.getPhrase('back', 'BACK');

		selectedList = [titleOption, backOption].concat(group.subMenuOptions);
		inSubView = true;
		selectedOptionIndex = 1; // 光标落在 BACK 上

		resetScroll();
		rebuildRows();
		doSelectCurrentOption();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function exitSubView():Void
	{
		closeWidgetPopups();
		commitNumericPending();

		inSubView = false;
		selectedList = selectedCat.options;
		selectedOptionIndex = Std.int(FlxMath.bound(subReturnIndex, 0, selectedList.length - 1));

		resetScroll();
		rebuildRows();
		doSelectCurrentOption();
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.5);
	}

	function resetScroll():Void
	{
		optionScrollPos = 0;
		if (optionScroller != null)
		{
			optionScroller.target = 0;
			optionScroller.velocity = 0;
		}
	}

	function closeWidgetPopups():Void
	{
		for (row in rows)
		{
			if (row.widget != null && row.widget.isOpen)
				row.widget.closePopup();
		}
	}

	function findOpenWidget():StringSelect
	{
		for (row in rows)
		{
			if (row.widget != null && row.widget.isOpen)
				return row.widget;
		}
		return null;
	}

	// ==================== 选中 / 描述 / 值条 ====================

	function getSelectedRow():KEOptionRow
	{
		if (selectedOptionIndex < 0 || selectedOptionIndex >= rows.length) return null;
		return rows[selectedOptionIndex];
	}

	public function doSelectCurrentOption()
	{
		if (selectedOptionIndex >= selectedList.length) selectedOptionIndex = selectedList.length - 1;
		if (selectedOptionIndex < 0) selectedOptionIndex = 0;
		selectedOption = (selectedList.length > 0) ? selectedList[selectedOptionIndex] : null;

		for (i in 0...rows.length)
		{
			var row = rows[i];
			row.setSelected(i == selectedOptionIndex);
			row.nameText.color = FlxColor.WHITE;
			if (row.valueText != null) row.valueText.color = FlxColor.WHITE;
			if (row.widget != null) row.widget.setKeyboardHighlight(i == selectedOptionIndex);
			row.refreshTexts(valueTextFor);
		}

		if (selectedOption != null)
		{
			descText.text = (selectedOption.type == "back") ? "" : selectedOption.getDescription();
		}
		else
		{
			descText.text = "";
		}
		descText.color = FlxColor.WHITE;
		updateValueBar();
		ensureOptionVisible();
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
			valueBarText.text = valueTextFor(selectedOption);
		}
		else
		{
			valueBar.visible = false;
			valueBarText.visible = false;
		}
	}

	/** 行右侧值文本（数值 / 分组 ">" 标记；string/color/bool 走 widget 下拉框） */
	function valueTextFor(opt:KEOption):String
	{
		if (opt.hasSubMenu) return ">";
		switch(opt.type)
		{
			case "bool":
				return backend.Language.getPhrase(opt.value ? "on" : "off", opt.value ? "on" : "off");
			case "int", "float":
				return Std.string(opt.value);
			default:
				return "";
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
		if (optionScroller == null || rows.length == 0) return;

		var visH:Float = visibleHeight();
		var top:Float = selectedOptionIndex * ROW_H;
		var bottom:Float = top + ROW_H;

		// 目标：整行落进可视区（贴边即可，不强制居中）
		var minTarget:Float = Math.max(0, bottom - visH);
		var maxTarget:Float = Math.min(maxScrollPixels(), top);

		if (optionScroller.target < minTarget)
			optionScroller.target = minTarget;
		else if (optionScroller.target > maxTarget)
			optionScroller.target = maxTarget;
	}

	// ==================== 下划线动效 ====================

	function updateUnderlines(immediate:Bool):Void
	{
		for (i in 0...options.length)
		{
			var st:Int = (i == selectedCatIndex) ? 2 : (i == hoveredCatIndex ? 1 : 0);
			if (st == underlineStates[i]) continue;
			underlineStates[i] = st;

			var underline = catUnderlines[i];
			if (underline == null) continue;

			var targetScale:Float = (st == 2) ? 1.0 : ((st == 1) ? 0.5 : 0.0);
			var targetAlpha:Float = (st == 2) ? 1.0 : ((st == 1) ? 0.4 : 0.0);

			FlxTween.cancelTweensOf(underline.scale);
			FlxTween.cancelTweensOf(underline);
			if (immediate)
			{
				underline.scale.x = targetScale;
				underline.alpha = targetAlpha;
			}
			else
			{
				FlxTween.tween(underline.scale, {x: targetScale}, 0.22, {ease: FlxEase.quadOut});
				FlxTween.tween(underline, {alpha: targetAlpha}, 0.22, {ease: FlxEase.quadOut});
			}
		}
	}

	// ==================== 数值直接输入 ====================

	function startNumericInput():Void
	{
		numericInput = true;
		numericBuf = "";
		descText.text = backend.Language.getPhrase("type_number_hint", "Type a number, Enter to apply, Esc to cancel");
	}

	function handleNumericInput():Void
	{
		var opt = selectedOption;
		if (opt == null || !isNumericOption(opt))
		{
			cancelNumericInput(true);
			return;
		}

		var d:Int = digitJustPressed();
		if (d >= 0 && numericBuf.length < 9)
			numericBuf += Std.string(d);

		var j = FlxG.keys.justPressed;
		if ((j.MINUS || j.NUMPADMINUS) && numericBuf.length == 0 && opt.minValue < 0)
			numericBuf = "-";
		if ((j.PERIOD || j.NUMPADPERIOD) && opt.type == "float" && numericBuf.length > 0 && numericBuf.indexOf(".") < 0)
			numericBuf += ".";
		if (j.BACKSPACE)
		{
			numericBuf = numericBuf.substring(0, numericBuf.length - 1);
			if (numericBuf.length == 0)
			{
				cancelNumericInput(true);
				return;
			}
		}

		// 预览：值文本实时显示缓冲
		var row = getSelectedRow();
		if (row != null && row.valueText != null)
			row.setPreviewValue(numericBuf + "_");
	}

	/** 0-9 / 小键盘 0-9 → 数字，否则 -1 */
	function digitJustPressed():Int
	{
		var j = FlxG.keys.justPressed;
		if (j.ZERO || j.NUMPADZERO) return 0;
		if (j.ONE || j.NUMPADONE) return 1;
		if (j.TWO || j.NUMPADTWO) return 2;
		if (j.THREE || j.NUMPADTHREE) return 3;
		if (j.FOUR || j.NUMPADFOUR) return 4;
		if (j.FIVE || j.NUMPADFIVE) return 5;
		if (j.SIX || j.NUMPADSIX) return 6;
		if (j.SEVEN || j.NUMPADSEVEN) return 7;
		if (j.EIGHT || j.NUMPADEIGHT) return 8;
		if (j.NINE || j.NUMPADNINE) return 9;
		return -1;
	}

	function commitNumericInput():Void
	{
		var opt = selectedOption;
		var buf:String = numericBuf;
		cancelNumericInput(true);

		if (opt == null || buf.length == 0) return;

		var f:Float = Std.parseFloat(buf);
		if (Math.isNaN(f))
		{
			MessageBox.show(
				backend.Language.getPhrase("invalid_number", "Invalid number"),
				backend.Language.getPhrase("value_not_parsed", "Could not parse the value you typed"),
				MessageBoxType.MESSAGE, null, 2.5);
			return;
		}

		var warned:Bool = false;
		if (f < opt.minValue) { f = opt.minValue; warned = true; }
		if (f > opt.maxValue) { f = opt.maxValue; warned = true; }
		f = snapOptionValue(f, opt);

		opt.value = (opt.type == "int") ? Math.round(f) : f;
		opt.saveCurrentValue();
		ClientPrefs.saveSettings();

		if (warned)
		{
			MessageBox.show(
				backend.Language.getPhrase("value_out_of_range", "Value out of range"),
				backend.Language.getPhrase("clamped_to_bounds", "Clamped to allowed range") + ": " + opt.minValue + " ~ " + opt.maxValue,
				MessageBoxType.MESSAGE, null, 2.5);
		}
		doSelectCurrentOption();
	}

	function cancelNumericInput(restoreDesc:Bool):Void
	{
		if (!numericInput) return;
		numericInput = false;
		numericBuf = "";
		if (restoreDesc) doSelectCurrentOption();
	}

	/** 有未提交缓冲就提交（离开该行/切分类/进子视图/拖值条时走这里） */
	inline function commitNumericPending():Void
	{
		if (numericInput) commitNumericInput();
	}

	/** PC F9：恢复全部设置到默认值（等同 BIOS load defaults） */
	function resetAllSettings():Void
	{
		closeWidgetPopups();
		cancelNumericInput(false);

		ClientPrefs.data = ClientPrefs.defaultData;
		ClientPrefs.saveSettings();
		ClientPrefs.loadPrefs();

		// 分辨率随默认值重新应用（string 标签走 Main 的 Dynamic 入口）
		Main.applyRenderResolution(ClientPrefs.data.renderResolution, ClientPrefs.data.wideScreen, !ClientPrefs.data.useDpiSettings);

		// 重建行 + 复位滚动 + 选中刷新（值全变默认了）
		doSwitchToCat(options[selectedCatIndex], false);

		MessageBox.show(
			backend.Language.getPhrase("settings_restored", "Settings restored"),
			backend.Language.getPhrase("all_settings_reset_hint", "All settings have been reset to defaults (F9)"),
			MessageBoxType.MESSAGE, null, 2.5);
	}

	// ==================== 行激活 ====================

	/** Enter / 点击共用的「确认这一行」 */
	function activateRow(idx:Int):Void
	{
		if (idx < 0 || idx >= selectedList.length) return;
		var opt = selectedList[idx];
		if (opt == null) return;

		if (opt.type == "title") return; // 标题行不可交互

		if (opt.type == "back")
		{
			exitSubView();
			return;
		}
		if (opt.hasSubMenu)
		{
			enterSubView(opt);
			return;
		}
		if (opt.type == "confirm")
		{
			// 阻塞式确认对话框：菜单输入被 subState 门禁挡住，Yes 才执行
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			openSubState(new KEConfirmDialog(opt.getDisplayName(), opt.getWarning(), function() {
				opt.executeWarningAction();
			}));
			return;
		}
		if ((opt.type == "string" || opt.type == "color" || opt.type == "bool") && rows[idx] != null && rows[idx].widget != null)
		{
			rows[idx].widget.openPopup(true);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			return;
		}

		var shouldKeepState = opt.press();
		if (shouldKeepState)
		{
			ClientPrefs.saveSettings();
			doSelectCurrentOption();
		}
	}

	function selectRow(idx:Int, silent:Bool = false):Void
	{
		if (idx < 0 || idx >= selectedList.length) return;
		var target:KEOption = selectedList[idx];
		if (target != null && target.type == "title") return; // 标题行不可选中
		// 输入中离开本行 → 先提交缓冲再走（"离开即保存"）
		if (numericInput && idx != selectedOptionIndex)
			commitNumericInput();
		selectedOptionIndex = idx;
		ensureOptionVisible();
		doSelectCurrentOption();
		if (!silent)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		else if (scrollHoldTime == 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
	}

	/** 鼠标点是否落在 widget 主条上（用矩形探针，别用组包围盒） */
	function mouseInWidget(widget:StringSelect, widgetW:Float):Bool
	{
		var probe = new FlxObject(widget.x, widget.y, widgetW, 32);
		probe.scrollFactor.set();
		return OptionInput.overlaps(probe);
	}

	// ==================== 主循环 ====================

	override function update(elapsed:Float)
	{
		starsBG.x -= 0.05;
		starsFG.x -= 0.15;

		if (starsBG.x < -starsBG.width) starsBG.x = 0;
		if (starsFG.x < -starsFG.width) starsFG.x = 0;

		super.update(elapsed);

		if (optionClickCooldown > 0) {
			optionClickCooldown -= elapsed;
			if (optionClickCooldown <= 0) {
				optionClickProtected = false;
			}
		}

		FlxG.mouse.visible = true;
		FlxG.mouse.useSystemCursor = ClientPrefs.data.useSystemCursor;

		// ---- 有 substate 挡在前（确认对话框 / 键位编辑器等）：主菜单不再吃任何输入 ----
		if (this.subState != null)
		{
			optionScroller.inputAllow = false;
			positionRows();
			return;
		}

		// ---- PC：F9 恢复全部设置（BIOS load defaults 便捷键） ----
		#if desktop
		if (FlxG.keys.justPressed.F9)
		{
			resetAllSettings();
		}
		#end

		// ---- 弹层展开时先让下拉接管键盘（上下选/回车/ESC/R） ----
		var openWidget = findOpenWidget();

		// ---- BACK：输入中仅 ESC/右键取消（BACKSPACE 绑在 BACK 上，归删字符管） > 子视图返回 > 关闭菜单 ----
		if (!isClosing && (controls.BACK || FlxG.mouse.justPressedRight))
		{
			if (numericInput)
			{
				if (FlxG.keys.justPressed.ESCAPE || FlxG.mouse.justPressedRight)
					cancelNumericInput(true);
			}
			else if (openWidget != null)
			{
				// 键盘 BACK 由弹层 handleKeyNav 收起；鼠标右键这里就地收起
				if (FlxG.mouse.justPressedRight) openWidget.closePopup();
			}
			else if (inSubView)
			{
				exitSubView();
			}
			else if(onMainMenuState && !onPlayState)
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
			else if (isFreeplay)
				MusicBeatState.switchState(new states.FreeplayState());
			else
				MusicBeatState.switchState(new MainMenuState());
		}

		if (isClosing) return;

		var popupConsumesKeys:Bool = openWidget != null;
		if (popupConsumesKeys)
			openWidget.handleKeyNav();

		// 弹层展开时让出列表拖动与滚轮（wheel 由 MouseMove 在 inputAllow 门内处理）；数值输入不屏蔽
		optionScroller.inputAllow = (openWidget == null);

		// ---- 选项卡悬停/点击 + 下划线动效 ----
		var tabHoverIndex = -1;
		for (i in 0...options.length)
		{
			var cat = options[i];
			if (cat != null && cat.titleObject != null && FlxG.mouse.overlaps(cat.titleObject))
			{
				tabHoverIndex = i;
				break;
			}
		}
		hoveredCatIndex = tabHoverIndex;
		updateUnderlines(false);

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
				else if (i == tabHoverIndex)
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

		if (FlxG.mouse.justPressed && openWidget == null && !numericInput)
		{
			for (i in 0...options.length)
			{
				var cat = options[i];
				if (FlxG.mouse.overlaps(cat.titleObject))
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					selectedCatIndex = i;
					doSwitchToCat(options[selectedCatIndex]);
					break;
				}
			}
		}

		// ---- 行悬停 / 点击 ----
		var hoveredOptionIndex = -1;
		for (i in 0...rows.length)
		{
			var row = rows[i];
			if (row == null || !row.rowVisible) continue;
			if (OptionInput.overlaps(row.hitbox))
			{
				hoveredOptionIndex = i;
				break;
			}
		}

		for (i in 0...rows.length)
		{
			var row = rows[i];
			if (row == null) continue;
			if (i == selectedOptionIndex)
			{
				row.nameText.color = FlxColor.WHITE;
			}
			else if (i == hoveredOptionIndex && row.option.type != "title") // 标题行不响应悬停高亮
			{
				row.nameText.color = FlxColor.YELLOW;
			}
			else
			{
				row.nameText.color = FlxColor.WHITE;
			}
		}

		// ---- 行点击：按下记候选，松开时先做拖拽防误触判定，再"先选择、再执行" ----
		if (FlxG.mouse.justPressed && openWidget == null && !optionClickProtected)
		{
			pressRow = -1;
			if (hoveredOptionIndex >= 0)
			{
				var row = rows[hoveredOptionIndex];
				var widgetW:Float = SCREEN_WIDTH * 0.20;

				if (row.widget != null && mouseInWidget(row.widget, widgetW))
				{
					// 点在下拉条上：只移动选中，打开/关闭由控件自己的 update 处理
					if (selectedOptionIndex != hoveredOptionIndex)
						selectRow(hoveredOptionIndex);
				}
				else if (row.option.type != "title")
				{
					// 记录按压候选（不立即执行）：松开时未拖拽才结算
					pressRow = hoveredOptionIndex;
					pressWasSelected = (pressRow == selectedOptionIndex);
					pressY = FlxG.mouse.y;
					pressTarget = optionScroller.target;
				}
			}
		}

		if (FlxG.mouse.justReleased && pressRow >= 0)
		{
			// 拖拽防误触：指针位移 >8px 或按压期间滚动位移 >2 → 这次是拖拽，全部作废
			var dragged:Bool = Math.abs(FlxG.mouse.y - pressY) > 8
				|| Math.abs(optionScroller.target - pressTarget) > 2;

			if (!dragged)
			{
				if (!pressWasSelected)
				{
					selectRow(pressRow); // 首点：只选中
				}
				else
				{
					activateRow(pressRow); // 已选中的行再点：才执行
					optionClickProtected = true;
					optionClickCooldown = 0.2;
				}
			}
			pressRow = -1;
		}

		// ---- 数值直接输入：选中数值项时敲数字即开始（不屏蔽导航，离开该行自动保存） ----
		var numericJustStarted:Bool = false;
		if (!numericInput && openWidget == null && isNumericOption(selectedOption))
		{
			var d:Int = digitJustPressed();
			if (d >= 0)
			{
				startNumericInput();
				numericBuf = Std.string(d);
				numericJustStarted = true; // 起手帧不再进 handleNumericInput，修掉首输必双写
			}
		}

		// 缓冲编辑（数字/负号/小数点/退格）每帧跑；导航不受影响
		if (numericInput && !numericJustStarted)
		{
			handleNumericInput();
		}

		// ---- 键盘导航（弹层展开时让位；数值输入期间照常导航，离开该行自动提交） ----
		if (!popupConsumesKeys)
		{
			var accept = controls.ACCEPT;
			var right = controls.UI_RIGHT_P;
			var left = controls.UI_LEFT_P;
			var up = controls.UI_UP_P;
			var down = controls.UI_DOWN_P;
			var upPressed = controls.UI_UP;
			var downPressed = controls.UI_DOWN;

			// 左右键始终切换选项卡（不再被 String/数值项拦截）
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

			if (up)
			{
				selectRow(selectedOptionIndex - 1);
			}
			else if (down)
			{
				selectRow(selectedOptionIndex + 1);
			}

			if (upPressed) {
				holdUpTime += elapsed;
				if (holdUpTime > 0.3) {
					scrollHoldTime += elapsed;
					if (scrollHoldTime >= 0.05) {
						scrollHoldTime = 0;
						selectRow(selectedOptionIndex - 1, true);
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
						selectRow(selectedOptionIndex + 1, true);
					}
				}
			} else {
				holdDownTime = 0;
			}

			if (!upPressed && !downPressed) {
				scrollHoldTime = 0;
			}

			// 数值输入中：Esc 取消；Enter 提交。其余导航照常（离开该行时 selectRow/doSwitchToCat 自动提交）
			if (numericInput && FlxG.keys.justPressed.ESCAPE)
			{
				cancelNumericInput(true);
			}
			else if (accept)
			{
				if (numericInput)
					commitNumericInput();
				else
					activateRow(selectedOptionIndex);
			}
		}

		// ---- 行定位 + 边缘三态裁剪（每帧，跟随 lerp 后的滚动位） ----
		positionRows();
	}

	/** 每帧按 optionScrollPos 摆行：滚出视口隐藏、完全可见清裁剪、露半截逐叶子裁 */
	function positionRows():Void
	{
		var csY:Float = contentStartY();
		var cbY:Float = SCREEN_HEIGHT - MARGIN_BOTTOM;
		var cam = FlxG.camera;

		for (i in 0...rows.length)
		{
			var row = rows[i];
			if (row == null) continue;

			var rowY:Float = csY + i * ROW_H - optionScrollPos;
			row.setY(rowY);

			if (rowY + ROW_H <= csY || rowY >= cbY)
			{
				row.setVisible(false);
				row.clearClip();
			}
			else if (rowY >= csY && rowY + ROW_H <= cbY)
			{
				row.setVisible(true);
				row.clearClip();
			}
			else
			{
				row.setVisible(true);
				row.applyClip(-1000, csY, SCREEN_WIDTH + 1000, cbY, cam);
			}
		}
	}

	// ==================== 选项定义 ====================

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
			"FPS Counter Settings"
		);

		return [
			fpsOptions,
			KEOption.create("Low Quality", "Reduce graphics for performance", "lowQuality", "bool"),
			KEOption.create("Anti-Aliasing", "Smoother visuals", "antialiasing", "bool"),
			// Resolution：string 选择（与 Win10 页同一套标签），旧 Int 存档由 Main.getRenderResolutionIndex 兼容
			KEOption.create("Resolution", "Change the game's render resolution.", "renderResolution", "string", GraphicsData.getResolutionLabels()),
			KEOption.create("DPI Scale", "Scale the game based on your screen's DPI", "useDpiSettings", "bool"),
			KEOption.create("Shaders", "Enable shader effects", "shaders", "bool"),
			KEOption.create("Wide Screen", "Enable 21:9 widescreen mode", "wideScreen", "bool"),
			KEOption.createStringOption("GPU Caching", "Texture caching mode: disabled = RAM only; auto = drop the CPU copy after the first draw; full = upload and drop the CPU copy at load (least RAM, risky on low VRAM)", "gpuCaching", ["disabled", "auto", "full"], "disabled"),
			// TPS/FPS 拆分已废弃：flixel 的 updateFramerate 依赖 fixedTimestep，本引擎关掉了（见 ClientPrefs.applyFrameTiming）。
			// KEOption.create("Divide Draw And Update", "Draw and Update in separate threads", "devideDrawAndUpdate", "bool"),
			KEOption.create("Framerate", "Target framerate", "framerate", "int", 60, 60, 480, 1),
			// KEOption.create("Update Rate", "Target update rate", "updaterate", "int", 60, 60, 480, 1),
			KEOption.create("Unlimited FPS", "Remove framerate cap (lime UNCAPPED, takes priority over FPS Rework)", "unlimitedFPS", "bool"),
			KEOption.create("FPS Rework", "Make ur game more smooth", "fpsRework", "bool"),
			KEOption.create("Idle FPS Saver", "Enter power-saving mode after no input, lowering the framerate to save energy", "idleFPSReducer", "bool"),
			KEOption.create("Idle Delay", "Seconds of inactivity before entering power-saving mode", "idleFPSTime", "int", 60, 10, 600, 5),
			KEOption.create("Idle FPS", "Framerate cap used in power-saving mode", "idleFPSValue", "int", 15, 5, 60, 1)
		];
	}

	function getGameplayOptions():Array<KEOption>
	{
		var windowSettings = KEOption.createSubMenu(
			"Window Settings",
			"Configure window and timing settings",
			[
				KEOption.create("Enable Marvelous", "Toggle the Marvelous judgement; when off those hits count as Sick", "marvelousEnabled", "bool"),
				KEOption.create("Marvelous Window", "Timing window for SICK", "marvelousWindow", "float", 22.5, 0, 22.5, 0.5),
				KEOption.create("Sick Window", "Timing window for SICK", "sickWindow", "float", 45, 10, 45, 0.5),
				KEOption.create("Good Window", "Timing window for GOOD", "goodWindow", "float", 90, 10, 90, 0.5),
				KEOption.create("Bad Window", "Timing window for BAD", "badWindow", "float", 135, 10, 135, 0.5),
				KEOption.create("Safe Frames", "Frames for early/late hits", "safeFrames", "float", 10, 2, 10, 1)
			],
			"Window Settings"
		);

		return [
			KEOption.create("Downscroll", "Notes scroll downwards instead of upwards", "downScroll", "bool"),
			KEOption.create("Middlescroll", "Put your lane in the center", "middleScroll", "bool"),
			KEOption.create("Centered Multi-Key Scaling", "When centered, multi-key notes shrink by key count; turn off to keep the 4K note size", "centerMultiKeyScale", "bool"),
			KEOption.create("Opponent Notes", "Show opponent's strumline", "opponentStrums", "bool"),
			KEOption.create("Swap Hit Callbacks", "Opponent mode only: dispatch opponentNoteHit for the notes you play (dad side) and goodNoteHit for the CPU side, instead of by who hit it", "swapNoteHitCallbacks", "bool"),
			KEOption.create("Ghost Tapping", "Allow pressing keys without missing", "ghostTapping", "bool"),
			KEOption.create("Auto Pause", "Pause when window loses focus", "autoPause", "bool"),
			KEOption.create("Disable Reset", "Disable the reset button", "noReset", "bool"),
			KEOption.create("Guitar Hero Sustains", "Sustains count as one note", "guitarHeroSustains", "bool"),
			KEOption.create("Fast Restart", "Fast Restart When Dead or Press 'R' ", "skipDeath", "bool"),
			KEOption.create("Hitsound Volume", "Volume of hit sounds", "hitsoundVolume", "float", 0, 0, 1, 0.1),
			KEOption.create("Hitsound", "Choose the note hit sound", "hitsound", "string", hitsoundList),
			KEOption.create("Pause Music", "Choose pause screen music", "pauseMusic", "string", pauseMusicList),
			KEOption.create("Rating Offset", "Adjust note hit timing", "ratingOffset", "int", 0, -100, 100, 1),
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
				KEOption.create("Note System", "auto: detect | legacy: force HSV | new: force RGB + custom skin", "noteSystem", "string", ['auto', 'legacy', 'new']),
				KEOption.create("Splash System", "auto: detect | legacy: force HSV | new: force RGB + custom skin", "splashSystem", "string", ['auto', 'legacy', 'new'])
			],
			"Skin Settings"
		);

		var hitErrorSettings = KEOption.createSubMenu(
			"Hit Error Bar",
			"Configure hit error bar display",
			[
				KEOption.create("Hit Error Bar", "Show hit error bar", "hitErrorBarVisible", "bool"),
				KEOption.create("Hit Error Bar Pointer Style", "Style of the hit error bar pointer", "pointerType", "string", ["triangle", "inverted", "thick_line"]),
				KEOption.create("Hit Bar Lines", "Number of lines on hit error bar", "hitBarLines", "int", 5, 0, 200, 1),
				KEOption.create("Hit Bar Line Time", "Time (in seconds) each line represents", "hitBarLineTime", "float", 2.0, 0.1, 5.0, 0.1),
				KEOption.create("Hit Error Bar Offset X", "Horizontal position of hit error bar", "hitErrorBarOffsetX", "int", 0, -500, 500, 1),
				KEOption.create("Hit Error Bar Offset Y", "Vertical position of hit error bar", "hitErrorBarOffsetY", "int", 0, -300, 300, 1),
				KEOption.create("Hit Error Bar MS", "Show MS on hit error bar rather than on ratings", "msInErrorBar", "bool"),
				KEOption.create("Hit Error Bar Block Counter", "Show hit counts under each hit error bar zone", "hitBarBlockCounter", "bool")
			],
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
			"Keyboard Display Settings"
		);
		var charthelperOptions = KEOption.createSubMenu(
			"Chart Helper",
			"Configure Chart Helper settings",
			[
				KEOption.create("Note Guide Line Opacity", "Transparency of the chart helper display", "guideLineAlpha", "float", 1.0, 0.0, 1.0, 0.1),
			],
			"Chart Helper Settings"
		);

		var freeplayOptions = KEOption.createSubMenu(
			"Freeplay",
			"Configure Freeplay settings",
			[
				KEOption.create("Old Freeplay Menu", "Use Psych Engine Default Freeplay Menu", "oldFreeplay", "bool"),
				KEOption.create("Card Glow", "Enable breathing glow under selected card", "cardGlow", "bool"),
				KEOption.create("Difficulty Stars", "Show the official star rating above the album cover", "freeplayStars", "bool"),
				KEOption.create("Album Cover", "Show the album cover on the right side of Freeplay", "freeplayAlbumArt", "bool"),
				KEOption.create("Difficulty Blocks", "Show the clickable difficulty blocks in Freeplay", "freeplayDiffCarousel", "bool"),
				KEOption.create("Freeplay ToolBar", "Show tool bar in freeplay", "toolBar", "bool"),
				KEOption.create("New Freeplay Space BackGround", "Just a cool background lol", "freeplayspace", "bool"),
				KEOption.create("Save Freeplay Cache", "Save freeplay song metadata cache to disk", "saveFreeplayCache", "bool"),
				KEOption.create("Threaded Song Conversion", "Parse chart info on a background thread (turn off if Freeplay stutters)", "freeplayThreadedParse", "bool"),
				KEOption.create("Space Back Ground EveryWhere", "Show space background everywhere", "globalspace", "bool"),
				KEOption.create("Mod Folder Manager", "Organize mods in Freeplay using folder selector", "freeplayModFolder", "bool"),
				KEOption.create("Inline Search Filter", "Type into the Freeplay search bar to filter the song list in place instead of opening the search popup", "freeplaySearchInline", "bool"),
				KEOption.createStringOption("Freeplay List Style", "Background style of the Freeplay list items (search / mod folder / replay)",
					"freeplayListStyle", ["blur", "win8", "win10"], "blur"),
				KEOption.create("Audio Display Number", "Change the relax audio number", "relaxAudioNumber", "int", 16, 1, 64, 1),
				KEOption.create("Audio Display Quality", "Change the relax audio display quality", "relaxAudioDisplayQuality", "int", 4, 1, 8, 1),
				KEOption.create("Audio Display Update Speed", "Change the relax audio display update speed", "audioDisplayUpdate", "int", 33, 33, 100, 1),
				KEOption.create("Audio Gain", "Change the relax audio range", "audioGain", "float", 1.0, 0.1, 10.0, 0.5),
			],
			"Freeplay Settings"
		);

		var judgementsCounterOptions = KEOption.createSubMenu(
			"Judgements Counter",
			"Configure Judgements Counter settings",
			[
				KEOption.create("Judgements Counter", "Show judgements counter", "Counter", "bool"),
				KEOption.createStringOption("Counter Position", "Layout of the judgements counter: left, centered, right, or split across the top and bottom",
					"counterPos", ["left", "center", "right", "split"], "left"),
				KEOption.create("Show Highest Combo", "Show highest combo in judgements counter", "showHC", "bool"),
				KEOption.create("Show Current Combo", "Show current combo in judgements counter", "showCB", "bool"),
				KEOption.create("Show Total Notes Hit", "Show total notes in judgements counter", "showTNH", "bool"),
				KEOption.create("Show Misses", "Show misses in judgements counter", "showMiss", "bool"),
			],
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
			"Song Info Text Settings"
		);

		// 暂停菜单的动画/输入开关。显式翻译键与 Win10 设置界面（GameUIData）保持一致，
		// 这样三个菜单共用同一批 setting_pause_* 键。
		var pauseSkipFadeInOpt = KEOption.create("Skip Pause Fade In", "Skip the pause menu intro animation", "pauseSkipFadeIn", "bool");
		pauseSkipFadeInOpt.translationKey = "pause_skip_fade_in";
		var pauseSkipFadeOutOpt = KEOption.create("Skip Pause Fade Out", "Skip the pause menu closing animation", "pauseSkipFadeOut", "bool");
		pauseSkipFadeOutOpt.translationKey = "pause_skip_fade_out";
		var pauseDoubleEnterOpt = KEOption.create("Double Enter to Skip", "Press Enter twice while the pause menu is closing to skip the animation", "pauseDoubleEnterSkip", "bool");
		pauseDoubleEnterOpt.translationKey = "pause_double_enter_skip";
		var pauseUnlockInputOpt = KEOption.create("Control During Animation", "Allow using the pause menu while the intro animation is still playing", "pauseUnlockInputDuringAnim", "bool");
		pauseUnlockInputOpt.translationKey = "pause_unlock_input";

		return [
			skinSettings,
			hitErrorSettings,
			keyboardDisplayOptions,
			charthelperOptions,
			freeplayOptions,
			judgementsCounterOptions,
			songInfoTextOptions,
			KEOption.create("Hide HUD", "Hide most HUD elements", "hideHud", "bool"),
			KEOption.create("In-Game Font Follows Language", "HUD and Lua/HScript text use the language font",
				"gameFontFollowLanguage", "bool", null, 0, 100, 1, 50, false, "", "game_font_follow_language"),
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
			pauseSkipFadeInOpt,
			pauseSkipFadeOutOpt,
			pauseDoubleEnterOpt,
			pauseUnlockInputOpt,
			KEOption.create("Control Theme", "Button style: auto / win10 / win8", "controlTheme", "string", ['auto', 'win10', 'win8']),
		];
	}

	function getControlsOptions():Array<KEOption>
	{
		return [
			KEOption.create("Open Note Colors", "Customize note colors", "", "action"),
			KEOption.create("Open Note HSV Colors", "Customize legacy note HSV colors", "", "action"),
			KEOption.create("Open Controls", "Customize key bindings", "", "action"),
			KEOption.create("Open EK Controls", "Customize key bindings for EK mode", "", "action"),
			KEOption.create("Adjust Delay and Combo", "Customize ingame experience", "", "action"),
			KEOption.create("Language", "Change the game's language", "language", "string", ['en-US', 'pt-BR', 'zh-CN', 'zh-TW']),
			KEOption.create("Color Mode", "Switch between dark and white mode", "colorMode", "string", ['dark', 'white']),
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
			KEOption.create("Frequent GC", "Full GC + heap compact on every state transition: returns freed textures to the OS, may cause short hitches", "frequentGC", "bool"),
			KEOption.create("Enable LUA Debug Printer", "Uncheck it if u dont want to see them ", "luadebugPrint", "bool"),
			KEOption.create("Console Log On Screen", "Show trace (console) output on screen, applies to every screen", "screenLog", "bool"),
			KEOption.create("Console Log Lifetime", "Seconds a trace line stays on screen before fading out", "screenLogLifetime", "int", 2, 1, 30, 1),
			KEOption.create("Save Session Log", "Write trace output to crash/latest.log; past sessions are kept as timestamped files in crash/", "sessionLog", "bool"),
			KEOption.create("Session Log Files", "How many past session logs to keep in crash/ (0 = none, 50 = unlimited)", "sessionLogMax", "int", 30, 0, 50, 1),
			KEOption.create("Blue Screen Crash Handler", "Show a Windows-style blue screen when the game hits an uncaught error; off = native popup", "blueScreen", "bool"),
			KEOption.create("Blue Screen Duration", "Seconds before the blue screen returns to the title screen (0 = wait for a key)", "blueScreenTime", "int", 15, 0, 60, 1),
			KEOption.create("Crash Test", "Triggers a null object crash on purpose. Do not click it for no reason!", "", "action"),
			KEOption.create("Discord RPC", "Enable Discord Rich Presence", "discordRPC", "bool"),
			KEOption.create("Replay", "[Score Menu and Replay Required]", "saveReplays", "bool"),
			KEOption.create("High Quality Replays", "Enable high-quality replays", "replayQuality", "bool"),
			//KEOption.create("Replay Manager", "Manage and view ur Replays", "", "action"),
			KEOption.create("Options Style", "Choose which options menu style to use", "optionstype", "string", ["new", "psych", "ke"]),
			KEOption.create("Lua Script Parser", "Parse lua scripts before a song loads: native (off), check syntax only, or preload their assets", "luaScriptParser", "string", ["native", "check", "preload"]),
			KEOption.createResetOption("Reset Settings", "settings"),
			KEOption.createResetOption("Reset Scores", "scores"),
			KEOption.create("About", "View information about the game", "", "action"),
			KEOption.create("Use Default Mouse Cursor", "Use ur system's default mouse cursor in game", "useSystemCursor", "bool")
		];
	}
}
