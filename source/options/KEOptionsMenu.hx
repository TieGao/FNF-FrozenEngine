package options;

import flixel.math.FlxRect;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import states.MainMenuState;
import backend.MusicBeatState;
import backend.StageData;

import objects.BiosDateDisplay;

import shaders.ParticleBeamShader;
#if !flash
#end

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

	var space:FlxSprite;
    var starsBG:FlxBackdrop;
    var starsFG:FlxBackdrop;

	public var dateDisplay:BiosDateDisplay;

	var notes:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
	var splashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
	var holdCovers:Array<String> = Mods.mergeAllTextsNamed('images/holdCover/list.txt');
	var ratings:Array<String> = Mods.mergeAllTextsNamed('images/ratings/list.txt');
	var pauseMusicList:Array<String> = Mods.mergeAllTextsNamed('music/list.txt');
	
	var changedOption:Bool = false;
	public var descText:FlxText;
	public var descBack:FlxSprite;

	var scrollOffset:Int = 0;
	var maxScrollOffset:Int = 0;
	
	var isClosing:Bool = false;
	var closeTimer:FlxTimer;

	// language reload callback holder
	var langReloadCb:Void->Void;
	
	// 长按滚动变量 - 只用于上下滚动
	var holdUpTime:Float = 0;
	var holdDownTime:Float = 0;
	var scrollHoldTime:Float = 0;
	
	// 防二次点击保护
	var optionClickCooldown:Float = 0;
	var optionClickProtected:Bool = false;
	
	// 可见选项数量
	static var VISIBLE_OPTIONS:Int = 11;

	// 新增：布局变量
	public static var SCREEN_WIDTH:Int = 1280;
	public static var SCREEN_HEIGHT:Int = 720;
	public static var MARGIN_TOP:Int = 60; // 上边距
	public static var MARGIN_BOTTOM:Int = 100; // 下边距
	public static var CATEGORY_COUNT:Int = 5;
	public static var CATEGORY_WIDTH:Int = Std.int(SCREEN_WIDTH / CATEGORY_COUNT); // 256像素每个
	public static var CATEGORY_HEIGHT:Int = 50;
	public static var OPTION_LEFT_MARGIN:Int = 20; // 选项左侧距离
	public static var OPTION_WIDTH:Int = 550; // 选项区域宽度
	public static var TAB_ALPHA:Float = 0.8; // 选项卡透明度
	public static var OPTION_ALPHA:Float = 0.6; // 选项透明度
	public static var DESC_ALPHA:Float = 0.8; // 描述文本透明度

	var beamShader:ParticleBeamShader = new ParticleBeamShader();


	public function new(pauseMenu:Bool = false)
	{
		super();

		isInPause = pauseMenu;
		notes.insert(0, ClientPrefs.defaultData.noteSkin);
		splashes.insert(0, ClientPrefs.defaultData.splashSkin);
		holdCovers.insert(0, ClientPrefs.defaultData.holdCoverSkin);
		ratings.insert(0, ClientPrefs.defaultData.customUI);
		pauseMusicList = ['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)'];
	}

	override function create()
	{
		super.create();
		// 创建横向铺满的选项卡
		options = [
			new KEOptionCata(0, MARGIN_TOP, "Basics", getControlsOptions()),
			new KEOptionCata(CATEGORY_WIDTH, MARGIN_TOP, "Gameplay", getGameplayOptions()),
			new KEOptionCata(CATEGORY_WIDTH * 2, MARGIN_TOP, "Visuals", getVisualsOptions()),
			new KEOptionCata(CATEGORY_WIDTH * 3, MARGIN_TOP, "Graphics", getAppearanceOptions()),
			new KEOptionCata(CATEGORY_WIDTH * 4, MARGIN_TOP, "Advanced", getAdvancedOptions())
		];

		shownStuff = new FlxTypedGroup<FlxText>();

		
		background = new FlxSprite(0, 0).makeGraphic(SCREEN_WIDTH, SCREEN_HEIGHT, FlxColor.BLACK);
		background.alpha = 0; // 半透明背景
		background.scrollFactor.set();
		add(background);

		// 创建选项区域的彩色循环底图
		var optionBg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		optionBg.alpha = 1; // 选项区域背景透明度
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

		// 主内容区域背景 - 从选项卡下方开始，覆盖整个内容区域
		var contentStartY:Int = MARGIN_TOP + CATEGORY_HEIGHT;
		var contentHeight:Int = SCREEN_HEIGHT - MARGIN_TOP - MARGIN_BOTTOM - CATEGORY_HEIGHT;
		
		bg = new FlxSprite(0, contentStartY).makeGraphic(SCREEN_WIDTH, contentHeight, FlxColor.BLACK);
		bg.alpha = 0.6; // 选项卡主体透明度
		bg.scrollFactor.set();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		// 描述区域背景 - 在屏幕底部
		descBack = new FlxSprite(0, SCREEN_HEIGHT - MARGIN_BOTTOM).makeGraphic(SCREEN_WIDTH, 32, FlxColor.BLACK);
		descBack.alpha = DESC_ALPHA; // 描述文本区域透明度
		descBack.scrollFactor.set();
		descBack.antialiasing = ClientPrefs.data.antialiasing;
		add(descBack);

		add(shownStuff);

		// 设置选项卡
		for (i in 0...options.length)
		{
			var cat = options[i];
			
			// 设置选项卡背景
			cat.makeGraphic(CATEGORY_WIDTH, CATEGORY_HEIGHT, FlxColor.BLACK);
			cat.x = i * CATEGORY_WIDTH;
			cat.y = MARGIN_TOP;
			cat.alpha = TAB_ALPHA; // 选项卡透明度
			
			// 调整标题位置
			cat.titleObject.x = cat.x + (CATEGORY_WIDTH / 2) - (cat.titleObject.fieldWidth / 2);
			cat.titleObject.y = cat.y + (CATEGORY_HEIGHT / 2) - (cat.titleObject.height / 2);
			cat.titleObject.alpha = 1.0; // 标题文字完全不透明
			
			add(cat);
			add(cat.titleObject);
		}

		// 描述文本
		descText = new FlxText(10, SCREEN_HEIGHT - MARGIN_BOTTOM + 5, SCREEN_WIDTH - 20);
		descText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 2;
		descText.alpha = 1.0; // 描述文字完全不透明
		descText.antialiasing = ClientPrefs.data.antialiasing;
		add(descText);

		dateDisplay = new BiosDateDisplay(10, 30, 20, FlxColor.WHITE, true); // 时间在前
		dateDisplay.setShowSeconds(true); // 显示秒数
		dateDisplay.setMilitaryTime(false); // 12小时制带AM/PM
		dateDisplay.scrollFactor.set();
		dateDisplay.antialiasing = ClientPrefs.data.antialiasing;
		add(dateDisplay);

		// 初始化第一个分类
		selectedCat = options[0];
		doSwitchToCat(selectedCat, false);

		// 颜色渐变效果 - 在选项区域背景上
		var colorArray:Array<FlxColor> = [
			FlxColor.fromRGB(148, 0, 211), // 紫色
			FlxColor.fromRGB(75, 0, 130),  // 靛蓝色
			FlxColor.fromRGB(0, 0, 255),   // 蓝色
			FlxColor.fromRGB(0, 255, 0),   // 绿色
			FlxColor.fromRGB(255, 255, 0), // 黄色
			FlxColor.fromRGB(255, 127, 0), // 橙色
			FlxColor.fromRGB(255, 0, 0)    // 红色
		];

		var currentColorIndex:Int = 0;
		var nextColorIndex:Int = 1;
		var colorTransitionTime:Float = 2.5;

		// 开始颜色渐变循环
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

		// 同时为主背景也添加渐变效果（可选）
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
		
		// 开始两个颜色循环
		startColorCycle();      // 选项区域彩色循环
		startBgColorCycle();    // 主背景颜色循环
		if (ClientPrefs.data.shaders && ClientPrefs.data.beamparticle) {
			optionBg.shader = beamShader;
		}

		// 注册语言重载回调
		var self = this;
		langReloadCb = function() {
			self.onLanguageReload();
		};
		backend.Language.addReloadCallback(langReloadCb);
	}
	
	// 语言重载回调函数
	function onLanguageReload():Void
	{
		// 刷新分类标题
		for (i in 0...options.length) {
			var cat = options[i];
			if (cat.titleObject != null) cat.titleObject.text = backend.Language.getPhrase(cat.title, cat.title);
			// 刷新选项文本
			for (j in 0...cat.optionObjects.members.length) {
				var txt = cat.optionObjects.members[j];
				if (txt != null && j < cat.options.length) txt.text = cat.options[j].getValue();
			}
		}

		// 重新应用字体格式
		for (i in 0...options.length) {
			var cat = options[i];
			if (cat.titleObject != null) cat.titleObject.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			for (j in 0...cat.optionObjects.members.length) {
				var txt = cat.optionObjects.members[j];
				if (txt != null) txt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK); // 改为左对齐
			}
		}

		// 刷新当前显示
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
		// 注销语言回调
		try {
			if (langReloadCb != null) backend.Language.removeReloadCallback(langReloadCb);
		} catch(e:Dynamic) {}
		instance = null;
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
					object.color = FlxColor.WHITE;
				}
			}
		}

		if (checkForOutOfBounds && selectedCatIndex > options.length - 1)
			selectedCatIndex = 0;

		if (selectedCat != null && selectedCat.middle)
			remove(selectedCat.titleObject);

		// 重置前一个选项卡
		if (selectedCat != null) {
			selectedCat.changeColor(FlxColor.BLACK);
			selectedCat.alpha = TAB_ALPHA; // 恢复默认透明度
			if (selectedCat.titleObject != null)
			{
				selectedCat.titleObject.color = FlxColor.WHITE;
				selectedCat.titleObject.alpha = 1.0;
			}
		}

		// 清空显示的内容
		shownStuff.clear();
		
		// 设置新分类
		selectedCat = cat;
		selectedCat.alpha = OPTION_ALPHA; // 选中状态稍亮
		selectedCat.changeColor(FlxColor.BLACK);

		if (selectedCat.middle)
			add(selectedCat.titleObject);

		// 添加选项对象
		for (i in selectedCat.optionObjects)
		{
			if(i != null) 
			{
				shownStuff.add(i);
				i.color = FlxColor.WHITE;
			}
		}

		// 设置默认选项
		if(selectedCat.options.length > 0) {
			selectedOption = selectedCat.options[0];
			selectedOptionIndex = 0;
		}

		// 计算最大滚动偏移
		maxScrollOffset = Std.int(Math.max(0, selectedCat.options.length - VISIBLE_OPTIONS));
		
		// 更新可见性
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
			if (!currentValue.startsWith("> ")) {
				object.text = "> " + currentValue;
			} else {
				object.text = currentValue;
			}
			descText.text = selectedOption.getDescription();
			descText.color = FlxColor.WHITE;
		}
		
		// 确保选中项可见
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
			
			// 计算Y坐标：选项卡下方开始
			var contentStartY = MARGIN_TOP + CATEGORY_HEIGHT;
			optionText.y = contentStartY + 10 +(46 * displayIndex);
			
			// X坐标：左侧100像素处
			optionText.x = OPTION_LEFT_MARGIN;
			
			// 判断是否在可见区域内
			var isVisible = (displayIndex >= 0 && displayIndex < VISIBLE_OPTIONS);
			
			if (isVisible)
			{
				// 在可见区域内
				if (i == selectedOptionIndex)
				{
					optionText.alpha = 1.0; // 选中项完全不透明
				}
				else
				{
					optionText.alpha = OPTION_ALPHA; // 选项默认透明度
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
			scrollOffset = selectedOptionIndex;
			updateOptionPositions();
		} else if (selectedOptionIndex >= scrollOffset + VISIBLE_OPTIONS) {
			scrollOffset = selectedOptionIndex - (VISIBLE_OPTIONS - 1);
			updateOptionPositions();
		}
	}

	// 滚动函数
	function scrollOptions(change:Int, isLongPress:Bool = false)
	{
		if (selectedCat == null || selectedCat.options.length <= VISIBLE_OPTIONS) return;
		
		var newOffset = scrollOffset + change;
		
		if (newOffset < 0) newOffset = 0;
		if (newOffset > maxScrollOffset) newOffset = maxScrollOffset;
		
		if (newOffset == scrollOffset) return;
		
		scrollOffset = newOffset;
		
		updateOptionPositions();
		
		if (selectedOptionIndex < scrollOffset) {
			selectedOptionIndex = scrollOffset;
			selectedOption = selectedCat.options[selectedOptionIndex];
			doSelectCurrentOption();
		} else if (selectedOptionIndex >= scrollOffset + VISIBLE_OPTIONS) {
			selectedOptionIndex = scrollOffset + (VISIBLE_OPTIONS - 1);
			selectedOption = selectedCat.options[selectedOptionIndex];
			doSelectCurrentOption();
		}
		
		if (!isLongPress) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		} else if (scrollHoldTime % 2 == 0) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
		}
	}

	// 更新函数
	override function update(elapsed:Float)
	{
		starsBG.x -= 0.05;
        starsFG.x -= 0.15;
        
        if (starsBG.x < -starsBG.width) starsBG.x = 0;
        if (starsFG.x < -starsFG.width) starsFG.x = 0;

		super.update(elapsed);
		
		if (beamShader != null) 
		{
			beamShader.update(elapsed * ClientPrefs.data.particleSpeed);
			beamShader.setParams(
			ClientPrefs.data.particleSpeed, // speed
			ClientPrefs.data.particleTrail, // trail
			0.004, // size
			1.0, // intensity
			ClientPrefs.data.particleAmount // particleCount
		);
		}
	
		// 更新点击保护计时器
		if (optionClickCooldown > 0) {
			optionClickCooldown -= elapsed;
			if (optionClickCooldown <= 0) {
				optionClickProtected = false;
			}
		}
		
		// 显示鼠标
		FlxG.mouse.visible = true;
		FlxG.mouse.useSystemCursor = ClientPrefs.data.useSystemCursor;

		// 使用 Controls 的 BACK 退出检测 - 添加鼠标右键支持
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
					cat.alpha = 0.6; // 选项卡背景也高亮
				}
				else if (i == hoveredCatIndex)
				{
					// 鼠标悬停分类 - 黄色高亮，保持原本透明度
					cat.titleObject.color = FlxColor.YELLOW;
					cat.titleObject.alpha = 0.8; // 悬停时稍亮
					cat.alpha = 0.5; // 选项卡背景也稍亮
				}
				else
				{
					// 其他分类 - 恢复原本效果
					cat.titleObject.color = FlxColor.WHITE;
					cat.titleObject.alpha = 0.6; // 原本的透明度
					cat.alpha = 0.8; // 选项卡背景恢复
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

		// 使用 Controls 获取输入状态
		var accept = controls.ACCEPT;
		var right = controls.UI_RIGHT_P;
		var left = controls.UI_LEFT_P;
		var up = controls.UI_UP_P;
		var down = controls.UI_DOWN_P;
		var rightPressed = controls.UI_RIGHT;
		var leftPressed = controls.UI_LEFT;
		var upPressed = controls.UI_UP;
		var downPressed = controls.UI_DOWN;

		changedOption = false;

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

	// 在 KEOptionsMenu 类的 getGameplayOptions 函数中，添加二级菜单示例：
	function getGameplayOptions():Array<KEOption>
	{
		// 创建一个窗口设置二级菜单
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
			KEOption.create("Rating Offset", "Adjust note hit timing", "ratingOffset", "int", 0, -30, 30, 1),
			windowSettings, // 使用二级菜单
			KEOption.create("Note Sustains Offset", "Adjust the timing offset for note sustains", "noteSustainsOffset", "float", 0, 0, 1, 0.05)
		];
	}

	// 在 getVisualsOptions 函数中，添加皮肤设置二级菜单：
	function getVisualsOptions():Array<KEOption>
	{
		// 创建皮肤设置二级菜单
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
		
		// 创建命中误差条设置二级菜单
		var hitErrorSettings = KEOption.createSubMenu(
			"Hit Error Bar",
			"Configure hit error bar display",
			[
				KEOption.create("Hit Error Bar", "Show hit error bar", "hitErrorBarVisible", "bool"),
				KEOption.create("Hit Bar Lines", "Number of lines on hit error bar", "hitBarLines", "int", 5, 0, 200, 1),
				KEOption.create("Hit Bar Line Time", "Time (in seconds) each line represents", "hitBarLineTime", "float", 2.0, 0.1, 5.0, 0.1),
				KEOption.create("Hit Error Bar Offset X", "Horizontal position of hit error bar", "hitErrorBarOffsetX", "int", 0, -500, 500, 10),
				KEOption.create("Hit Error Bar Offset Y", "Vertical position of hit error bar", "hitErrorBarOffsetY", "int", 0, -300, 300, 10)
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
				KEOption.create("Keyboard Offset X", "Horizontal position of the keyboard display", "kbOffsetX", "int", 0, -750, 750, 10),
				KEOption.create("Keyboard Offset Y", "Vertical position of the keyboard display", "kbOffsetY", "int", 0, -450, 750, 10),
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
		
		return [
			skinSettings,  // 皮肤设置二级菜单
			KEOption.create("Hide HUD", "Hide most HUD elements", "hideHud", "bool"),
			KEOption.create("Flashing Lights", "Enable screen flashes", "flashing", "bool"),
			KEOption.create("Camera Zooms", "Zoom camera on beat", "camZooms", "bool"),
			KEOption.create("Center Pause", "Center pause menu", "centerPause", "bool"),
			KEOption.create("Custom Color", "Color most things by opponent", "customColor", "bool"),
			KEOption.create("Gradient TimeBar", "Gradient colored timebar", "gradientTimeBar", "bool"),
			KEOption.create("Score Zoom", "Grow score text on hit", "scoreZoom", "bool"),
			KEOption.create('Time Bar:',"What should the Time Bar display?","timeBarType","string",['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']),
			KEOption.create("Pause Music", "Choose pause screen music", "pauseMusic", "string", pauseMusicList),
			KEOption.create("Health Bar Alpha", "Health bar transparency", "healthBarAlpha", "float", 1, 0, 1, 0.1),
			KEOption.create("Combo Stacking", "Stack combo numbers", "comboStacking", "bool"),
			KEOption.create("MS Number", "Make you know how late/early ur when hit notes", "showMS", "bool"),
			KEOption.create("Health Text", "Show health as number", "healthText", "bool"),
			KEOption.create("Song Text", "Show song info watermark", "songText", "bool"),
			KEOption.create("Score Screen", "Show Kade-style results", "scoreScreen", "bool"),
			KEOption.create("Judgements Counter", "Show judgments counter", "Counter", "bool"),
			KEOption.create("Charm Bar Pause", "Modern Pause Sub State", "charmPause", "bool"),
			hitErrorSettings, // 命中误差条二级菜单
			keyboardDisplayOptions,
			charthelperOptions,
			KEOption.create("New Freeplay Space BackGround", "Just a cool background lol", "globalspace", "bool"),
			KEOption.create("Space Back Ground EveryWhere", "Show space background everywhere", "globalspace", "bool"),
			KEOption.create("Impostor V3 Story Mode BG", "Use Impostor V3 Story Mode Background", "ImpStory", "bool")
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
			KEOption.create("Framerate", "Target framerate", "framerate", "int", 60, 60, 480, 1),
			KEOption.create("Show OS", "Show operating system in FPS Counter", "showOS", "bool"),
			KEOption.create("FPS Rework", "Make ur game more smooth", "fpsRework", "bool")
			//KEOption.create("New Freeplay", "Enable New Freeplay", "newFreeplay", "bool"),
		];
	}

	// Controls 选项
	function getControlsOptions():Array<KEOption>
	{
		return [
			KEOption.create("Open Note Colors", "Customize note colors", "", "action"),
			KEOption.create("Open Controls", "Customize key bindings", "", "action"),
			KEOption.create("Open EZ KeyBinds", "Customize key bindings in KE Styled Menu", "", "action"),
			KEOption.create("Adjust Delay and Combo", "Customize ingame experience", "", "action"),   
			KEOption.create("Reset KeyBinds", "Reset to default keys", "", "action"),
		];
	}

	// Advanced 选项
	function getAdvancedOptions():Array<KEOption>
	{
		var optionsparticle = KEOption.createSubMenu(
			"Options Particle",
			"Edit Particle Effects in Menu",
			[
				KEOption.create("Show Particle In Option", "Show particle effect in options menu", "particle", "bool"),
				KEOption.create("Particle Amount", "Amount of particles", "particleAmount", "float", 50, 0, 200, 0.1),
				KEOption.create("Particle Speed", "Speed of particles", "particleSpeed", "float", 1.0, 0.1, 5.0, 0.1),
				KEOption.create("Particle Trail Length", "Length of particle trails", "particleTrail", "int", 2, 0, 50, 1)
			],
			"",
			"Particle"
		);

		return [
			KEOption.create("Check Updates", "Check for game updates", "checkForUpdates", "bool"),
			KEOption.create("Loading Screen", "Show loading screen", "loadingScreen", "bool"),
			KEOption.create("Enable LUA Debug Printer", "Uncheck it if u dont want to see them ", "luadebugPrint", "bool"),
			KEOption.create("Discord RPC", "Enable Discord Rich Presence", "discordRPC", "bool"),
			KEOption.create("Language", "Change the game's language", "language", "string", ['en-US', 'pt-BR', 'zh-CN', 'zh-TW']),
			KEOption.create("Replay", "[Score Menu and Replay Required]", "saveReplays", "bool"),
			KEOption.create("Replay Manager", "Manage and view ur Replays", "", "action"),
			KEOption.create("NewOptions", "Disable it if u dont like current options menu", "keOptions", "bool"),
			KEOption.create("Old Freeplay Menu", "Use Psych Engine Default Freeplay Menu", "oldFreeplay", "bool"),
			KEOption.create("Legacy Music Player", "Use Psych Engine Default Music Player", "legacymp", "bool"),
			KEOption.create("Reset Settings", "Reset all settings to default [DO NOT APPLY IT UNLESS YOU KNOW WHAT YOU ARE DOING]", "", "action"),
			KEOption.create("Reset Scores", "Clear all high scores [DO NOT APPLY IT UNLESS YOU KNOW WHAT YOU ARE DOING]", "", "action"),
			//KEOption.create("Mirror Notes", "Mirror all notes in current chart", "mirrorNotes", "action"),
			optionsparticle,
			KEOption.create("Use Default Mouse Cursor", "Use ur system's default mouse cursor in game", "useSystemCursor", "bool")
		];
	}
}