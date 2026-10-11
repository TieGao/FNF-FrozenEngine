package states.freeplay;

import backend.Mods;
import backend.CustomChartData;
import backend.MusicBeatState;
import backend.MouseMove;

import flixel.util.FlxSpriteUtil;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxG;

import states.FreeplayState;

import openfl.display.BitmapData;

#if sys
import sys.FileSystem;
#end

/**
 * ModFolder 子界面 - 在 Freeplay 里选择内容来源，从左侧弹出（FlxTween + FlxEase.circOut）。
 *
 * 一级四类来源（NMVMODS 未实现，暂不列）：
 *   ALL           —— 原版 + 模组（不含 CustomCharts），点击即筛选
 *   Vanilla       —— 仅原版：assets 基础周 + content/VanillaSongs 各内容包（Erect / PicoMix …）
 *   Mods          —— 仅 mods/ 下的模组
 *   CustomCharts  —— content/CustomCharts 下的自定义谱面
 * 二级：Vanilla / Mods / CustomCharts 各自的具体项，每层首项都是一个「ALL」。
 *
 * 层级切换只发生在本界面内部。改变 Freeplay 状态的两个出口：
 *   - 原版 / 模组：FreeplayState.applySourceFilter(filter, sub)
 *   - 自定义谱面：FreeplayState.enterContentMode(category)
 */
class ModFolderSubstate extends MusicBeatSubstate
{
	// 层级：一级来源 → 二级（Vanilla / Mods / CustomCharts 各自的具体项）
	static inline var LEVEL_ROOT:Int = 0;
	static inline var LEVEL_VANILLA:Int = 1;
	static inline var LEVEL_MODS:Int = 2;
	static inline var LEVEL_CHARTS:Int = 3;

	// 列表项类型
	static inline var KIND_SOURCE:String = 'source';     // 一级：进入某个来源的二级层（chartCategory = vanilla/mods/charts）
	static inline var KIND_FILTER:String = 'filter';     // 叶子：按来源筛选（filter / filterSub 见 ModFolderItem）
	static inline var KIND_CATEGORY:String = 'category'; // 叶子：content 分类（chartCategory = 相对 content 根的路径）
	static inline var KIND_BACK:String = 'back';         // 返回上一级

	var curSelected:Int = 0;
	var pressedItem:Int = -1;
	var parent:FreeplayState;
	var level:Int = LEVEL_ROOT;

	var bgList:FlxFilteredSprite;
	var bgDim:FlxSprite;

	var selectedModName:FlxText;
	var selectedModDesc:FlxText;
	var selectedModInfo:FlxText;
	var selectedModIcon:FlxSprite;

	var openFolderButton:PsychUIButton;

	var modsGroup:FlxTypedGroup<ModFolderItem>;

	var startX:Float;
	var targetX:Float;

	// 滚动相关
	var scrollPos:Float = 0;
	var maxScrollPos:Float = 0;
	var itemHeight:Int = 100;
	var visibleItemCount:Int = 0;
	var totalItems:Int = 0;
	var scrollBar:FlxSprite;
	var scrollBarTrack:FlxSprite;
	var cardScroller:MouseMove;

	// 面板内部边距
	static inline var PADDING_TOP:Int = 20;
	static inline var PADDING_BOTTOM:Int = 20;
	static inline var ITEM_SPACING:Int = 10;
	static inline var PANEL_WIDTH:Int = 500;

	public function new(parent:FreeplayState)
	{
		super();
		this.parent = parent;
	}

	override function create()
	{
		// 昏暗背景
		bgDim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgDim.alpha = 0;
		bgDim.scrollFactor.set();
		add(bgDim);

		// 已经处在某个筛选里就直接进对应二级，否则从一级进。
		level = LEVEL_ROOT;
		if (parent != null)
		{
			if (parent.isContentMode())
				level = LEVEL_CHARTS;
			else if (FreeplayState.sourceFilter == 'vanilla')
				level = LEVEL_VANILLA;
			else if (FreeplayState.sourceFilter == 'mods')
				level = LEVEL_MODS;
		}

		// 计算可见项目数量
		var panelHeight:Int = FlxG.height;
		visibleItemCount = Math.floor((panelHeight - PADDING_TOP - PADDING_BOTTOM) / (itemHeight + ITEM_SPACING));
		if (visibleItemCount < 1) visibleItemCount = 1;

		// 创建背景面板
		bgList = new FlxFilteredSprite();
		bgList.makeGraphic(PANEL_WIDTH, panelHeight, FlxColor.BLACK,);
		bgList.filters = [new BlurFilter(30,30,BitmapFilterQuality.HIGH)];
		bgList.alpha = 0.8;
		bgList.scrollFactor.set();
		add(bgList);

		// 创建滚动条轨道
		scrollBarTrack = new FlxSprite();
		scrollBarTrack.makeGraphic(8, panelHeight - 40, FlxColor.GRAY);
		scrollBarTrack.alpha = 0.3;
		scrollBarTrack.x = bgList.x + PANEL_WIDTH - 20;
		scrollBarTrack.y = bgList.y + 20;
		scrollBarTrack.scrollFactor.set();

		// 创建滚动条
		scrollBar = new FlxSprite();
		scrollBar.makeGraphic(8, 30, FlxColor.WHITE);
		scrollBar.alpha = 0.6;
		scrollBar.x = scrollBarTrack.x;
		scrollBar.y = scrollBarTrack.y;
		scrollBar.scrollFactor.set();

		// 创建列表项组
		modsGroup = new FlxTypedGroup<ModFolderItem>();
		add(modsGroup);

		// 模组信息显示区域（右侧）
		selectedModIcon = new FlxSprite(FlxG.width * 0.2, 80);
		selectedModIcon.antialiasing = ClientPrefs.data.antialiasing;
		selectedModIcon.scrollFactor.set();
		add(selectedModIcon);

		selectedModName = new FlxText(FlxG.width * 0.2 + 100, 240, 300, "", 32);
		selectedModName.antialiasing = ClientPrefs.data.antialiasing;
		selectedModName.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		selectedModName.scrollFactor.set();
		selectedModName.borderSize = 2;
		add(selectedModName);

		selectedModDesc = new FlxText(FlxG.width * 0.2 + 100, 292, 300, "", 16);
		selectedModDesc.antialiasing = ClientPrefs.data.antialiasing;
		selectedModDesc.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		selectedModDesc.scrollFactor.set();
		selectedModDesc.borderSize = 2;
		add(selectedModDesc);

		selectedModInfo = new FlxText(FlxG.width * 0.2 + 100, 330, 300, "", 16);
		selectedModInfo.antialiasing = ClientPrefs.data.antialiasing;
		selectedModInfo.setFormat(Paths.font("vcr.ttf"), 16, 0xFFDDDDDD, CENTER, OUTLINE, FlxColor.BLACK);
		selectedModInfo.scrollFactor.set();
		selectedModInfo.borderSize = 2;
		add(selectedModInfo);

		// 打开当前项对应的目录（系统文件管理器）
		openFolderButton = new PsychUIButton(0, FlxG.height - 70,
			Language.getPhrase('mod_folder_open', 'OPEN FOLDER'), openSelectedFolder, 450, 44);
		openFolderButton.text.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
		openFolderButton.text.fieldWidth = 450;
		openFolderButton.normalStyle = {bgColor: 0xFF333333, textColor: FlxColor.WHITE, bgAlpha: 0.9};
		openFolderButton.hoverStyle = {bgColor: 0xFF555577, textColor: FlxColor.WHITE, bgAlpha: 1};
		openFolderButton.clickStyle = {bgColor: 0xFF8888AA, textColor: FlxColor.WHITE, bgAlpha: 1};
		openFolderButton.scrollFactor.set();
		add(openFolderButton);

		// 建列表（定位依赖 bgList，必须排在面板创建之后）
		buildList();

		// ===== 弹出动画：从屏幕左侧外滑入 =====
		startX = -PANEL_WIDTH - 250;
		targetX = 10;

		bgList.x = startX;
		scrollBarTrack.x = startX + PANEL_WIDTH - 20;
		scrollBar.x = startX + PANEL_WIDTH - 20;
		selectedModIcon.x = startX;
		selectedModName.x = startX;
		selectedModDesc.x = startX;
		selectedModInfo.x = startX;
		openFolderButton.x = startX + 10;

		for (item in modsGroup)
			item.x = startX + 10;

		FlxTween.tween(bgList, {x: targetX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBarTrack, {x: targetX + PANEL_WIDTH - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBar, {x: targetX + PANEL_WIDTH - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModIcon, {x: targetX + PANEL_WIDTH + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModName, {x: targetX + PANEL_WIDTH + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModDesc, {x: targetX + PANEL_WIDTH + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModInfo, {x: targetX + PANEL_WIDTH + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(openFolderButton, {x: targetX + 10}, 0.6, {ease: FlxEase.circOut});

		for (item in modsGroup)
			FlxTween.tween(item, {x: targetX + 10}, 0.6, {ease: FlxEase.circOut});

		FlxTween.tween(bgDim, {alpha: 0.5}, 0.6, {ease: FlxEase.circOut});

		// 鼠标滚动 / 拖拽控制器
		cardScroller = new MouseMove(this, 'scrollPos', [0, Math.max(0, maxScrollPos)],
			[[0, FlxG.width], [0, FlxG.height]],
			function() { updateItemsPosition(); updateScrollBar(); }
		);
		cardScroller.useLerp = true;
		cardScroller.lerpSmooth = 12;
		cardScroller.dragSensitivity = 1.6;
		cardScroller.deceleration = 0.94;
		cardScroller.mouseWheelSensitivity = -200.0;
		add(cardScroller);

		updateSelection();
		updateItemsPosition();
		updateScrollBar();

		super.create();
	}

	// =========================================================
	// 列表构建
	// =========================================================

	/**
	 * 按当前层级重建列表项。
	 * 列表项是 FlxSpriteGroup，remove / clear 都不会 destroy，必须自己收尾（否则只脱离绘制树、不释放）。
	 */
	function buildList():Void
	{
		var old:Array<ModFolderItem> = modsGroup.members.copy();
		for (item in old)
		{
			if (item == null) continue;
			modsGroup.remove(item, true);
			item.destroy();
		}
		modsGroup.clear();

		curSelected = 0;
		var startY:Float = bgList.y + PADDING_TOP;
		var itemIndex:Int = 0;

		switch (level)
		{
			case LEVEL_VANILLA:
				itemIndex = buildVanillaLevel(startY, itemIndex);
			case LEVEL_MODS:
				itemIndex = buildModsLevel(startY, itemIndex);
			case LEVEL_CHARTS:
				itemIndex = buildChartsLevel(startY, itemIndex);
			default:
				itemIndex = buildRootLevel(startY, itemIndex);
		}

		totalItems = itemIndex;
		maxScrollPos = Math.max(0, (totalItems * (itemHeight + ITEM_SPACING)) - (FlxG.height - PADDING_TOP - PADDING_BOTTOM));

		// 滚动条拇指高度跟着条目数走
		var trackHeight:Float = scrollBarTrack.height;
		var thumbHeight:Float = Math.max(30, trackHeight * (visibleItemCount / Math.max(1, totalItems)));
		scrollBar.makeGraphic(8, Std.int(thumbHeight), FlxColor.WHITE);
		scrollBar.alpha = 0.6;

		// 回到顶部。scrollPos 的实际写入方是滚动控制器，所以它的 target 也要一起复位。
		scrollPos = 0;
		if (cardScroller != null)
		{
			cardScroller.moveLimit = [0, maxScrollPos];
			cardScroller.target = 0;
			cardScroller.tweenData = 0;
		}

		updateItemsPosition();
		updateScrollBar();
		updateSelection();
	}

	/** 一级：ALL / Vanilla / Mods / CustomCharts 四类来源（NMVMODS 未实现，暂不列）。 */
	function buildRootLevel(startY:Float, itemIndex:Int):Int
	{
		var contentMode:Bool = parent != null && parent.isContentMode();
		var filter:String = FreeplayState.sourceFilter;

		addItem(Language.getPhrase('mod_folder_all', 'ALL'),
			Language.getPhrase('mod_folder_all_desc', 'Show all songs'),
			null, null, KIND_FILTER, itemIndex, startY, !contentMode && filter == 'all', 'all', null);
		itemIndex++;

		addItem(Language.getPhrase('mod_folder_vanilla', 'Vanilla'),
			Language.getPhrase('mod_folder_vanilla_desc', 'Official songs: base weeks + content packs'),
			null, 'vanilla', KIND_SOURCE, itemIndex, startY, !contentMode && filter == 'vanilla');
		itemIndex++;

		addItem(Language.getPhrase('mod_folder_mods', 'Mods'),
			Language.getPhrase('mod_folder_mods_desc', 'Songs from the mods/ folder'),
			null, 'mods', KIND_SOURCE, itemIndex, startY, !contentMode && filter == 'mods');
		itemIndex++;

		addItem(Language.getPhrase('mod_folder_charts', 'CustomCharts'),
			Language.getPhrase('mod_folder_charts_desc', 'Custom charts under content/CustomCharts'),
			null, 'charts', KIND_SOURCE, itemIndex, startY, contentMode);
		itemIndex++;

		return itemIndex;
	}

	/** 二级：原版 —— 全部 / 基础周 / 各 content/VanillaSongs 内容包。 */
	function buildVanillaLevel(startY:Float, itemIndex:Int):Int
	{
		itemIndex = addBackItem(startY, itemIndex);

		var filter:String = FreeplayState.sourceFilter;
		var sub:String = FreeplayState.sourceSubFilter;

		addItem(Language.getPhrase('mod_folder_all_vanilla', 'ALL VANILLA'),
			Language.getPhrase('mod_folder_all_vanilla_desc', 'Every official song'),
			null, null, KIND_FILTER, itemIndex, startY, filter == 'vanilla' && sub == null, 'vanilla', null);
		itemIndex++;

		addItem(Language.getPhrase('mod_folder_vanilla_base', 'Vanilla (Base)'),
			Language.getPhrase('mod_folder_vanilla_base_desc', 'Base-game weeks'),
			null, null, KIND_FILTER, itemIndex, startY,
			filter == 'vanilla' && sub == FreeplayState.SOURCE_VANILLA_BASE, 'vanilla', FreeplayState.SOURCE_VANILLA_BASE);
		itemIndex++;

		#if sys
		for (pack in CustomChartData.listSubCategories('VanillaSongs'))
		{
			var root:String = '${Paths.CONTENT_ROOT}/VanillaSongs/$pack';
			addItem(pack,
				Language.getPhrase('mod_folder_group_desc', 'Browse {1}', [root]),
				null, null, KIND_FILTER, itemIndex, startY, filter == 'vanilla' && sub == root, 'vanilla', root);
			itemIndex++;
		}
		#end

		return itemIndex;
	}

	/** 二级：模组 —— 全部模组 / 各 mods/ 下的模组。 */
	function buildModsLevel(startY:Float, itemIndex:Int):Int
	{
		itemIndex = addBackItem(startY, itemIndex);

		var filter:String = FreeplayState.sourceFilter;
		var sub:String = FreeplayState.sourceSubFilter;

		addItem(Language.getPhrase('mod_folder_all_mods', 'ALL MODS'),
			Language.getPhrase('mod_folder_all_mods_desc', 'Every song from mods/'),
			null, null, KIND_FILTER, itemIndex, startY, filter == 'mods' && sub == null, 'mods', null);
		itemIndex++;

		for (mod in Mods.parseList().all)
		{
			var pack = Mods.getPack(mod);
			var modName:String = mod;
			var modDesc:String = Language.getPhrase('mod_folder_no_desc', 'No description');
			if (pack != null)
			{
				if (pack.name != null) modName = pack.name;
				if (pack.description != null) modDesc = pack.description;
			}

			addItem(modName, modDesc, mod, null, KIND_FILTER, itemIndex, startY, filter == 'mods' && sub == mod, 'mods', mod);
			itemIndex++;
		}
		return itemIndex;
	}

	/** 二级：自定义谱面 —— 全部聚合 / content/CustomCharts 下各分类。 */
	function buildChartsLevel(startY:Float, itemIndex:Int):Int
	{
		itemIndex = addBackItem(startY, itemIndex);

		#if sys
		var current:String = Paths.currentChartCategory;
		var folders:Array<String> = CustomChartData.listSubCategories(Paths.CUSTOM_CHART_GROUP);

		if (folders.length > 0)
		{
			addItem('ALL CUSTOM CHARTS', Language.getPhrase('mod_folder_charts_desc', 'Show all custom charts'),
				null, 'custom', KIND_CATEGORY, itemIndex, startY, current == 'custom');
			itemIndex++;
		}

		for (folder in folders)
		{
			var path:String = Paths.CUSTOM_CHART_GROUP + '/' + folder;
			addItem(folder,
				Language.getPhrase('mod_folder_category_desc', 'Show charts from {1}', [Paths.CONTENT_ROOT + '/' + path]),
				null, path, KIND_CATEGORY, itemIndex, startY, current == path);
			itemIndex++;
		}
		#end

		return itemIndex;
	}

	/** 二级列表统一的返回项。 */
	function addBackItem(startY:Float, itemIndex:Int):Int
	{
		addItem(Language.getPhrase('mod_folder_back', '< BACK'),
			Language.getPhrase('mod_folder_back_desc', 'Return to the source list'),
			null, null, KIND_BACK, itemIndex, startY, false);
		return itemIndex + 1;
	}


	function addItem(name:String, desc:String, ?folder:String, ?chartCategory:String, kind:String, index:Int, startY:Float, selected:Bool, ?filter:String = null, ?filterSub:String = null):Void
	{
		var item = new ModFolderItem(name, desc, folder, chartCategory, kind, filter, filterSub);
		item.setPosition(bgList.x + 10, startY + (index * (itemHeight + ITEM_SPACING)));
		modsGroup.add(item);
		if (selected) curSelected = index;
	}

	/**
	 * 更新所有项目的位置（基于滚动偏移）
	 */
	function updateItemsPosition()
	{
		var panelY:Float = bgList.y + PADDING_TOP;

		for (i in 0...modsGroup.members.length)
		{
			var item = modsGroup.members[i];
			var baseY:Float = panelY + i * (itemHeight + ITEM_SPACING);
			var offsetY:Float = -scrollPos;

			item.y = baseY + offsetY;

			// 检查项目是否在可见区域内
			var isVisible = item.y + itemHeight > bgList.y && item.y < bgList.y + bgList.height;
			item.visible = isVisible;
			item.active = isVisible;
		}
	}

	/**
	 * 更新滚动条位置
	 */
	function updateScrollBar()
	{
		if (maxScrollPos <= 0)
		{
			scrollBar.alpha = 0;
			return;
		}

		scrollBar.alpha = 0.6;
		var trackHeight = scrollBarTrack.height;
		var thumbHeight = scrollBar.height;
		var scrollRatio = scrollPos / maxScrollPos;
		var availableSpace = trackHeight - thumbHeight;

		scrollBar.y = scrollBarTrack.y + scrollRatio * availableSpace;
	}

	function clearPressedItem():Void
	{
		pressedItem = -1;
		if (modsGroup == null || modsGroup.members == null) return;
		for (item in modsGroup.members)
		{
			if (item != null) item.setPressed(false);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (shouldClose)
		{
			clearPressedItem();
			closingTimer += elapsed;
			if (closingTimer >= 0.65)
			{
				_closeNow();
				return;
			}
			return;
		}

		// 鼠标滚轮滚动（当鼠标在列表区域时）
		if (FlxG.mouse.wheel != 0 && isMouseOverList())
		{
			var newScroll = scrollPos - FlxG.mouse.wheel * 40;
			scrollPos = Math.max(0, Math.min(newScroll, maxScrollPos));
			updateItemsPosition();
			updateScrollBar();
		}

		if (controls.UI_UP_P)
			changeSelection(-1);
		else if (controls.UI_DOWN_P)
			changeSelection(1);
		else if (controls.ACCEPT)
			selectItem();
		else if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			// 逐级返回：二级回一级，一级才真的关掉
			if (level != LEVEL_ROOT)
			{
				level = LEVEL_ROOT;
				buildList();
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			}
			else
				close();
		}

		if (shouldClose)
		{
			clearPressedItem();
			return;
		}

		// 点击面板外空白处退出
		if (FlxG.mouse.justPressed && !isMouseOverPanel())
		{
			close();
			return;
		}

		// 「打开文件夹」按钮盖在列表底部，指针在它上面时列表不吃点击 / 不响应悬停
		var overOpenFolder:Bool = (openFolderButton != null && FlxG.mouse.overlaps(openFolderButton));

		// 按下项保存在成员中，才能在后续松开帧与命中项比较。
		var releasedItem:Int = -1;
		if (overOpenFolder)
		{
			clearPressedItem();
		}
		else if (FlxG.mouse.justPressed)
		{
			clearPressedItem();
			for (i in 0...modsGroup.members.length)
			{
				var item = modsGroup.members[i];
				if (item.visible && item.overlapsMouse())
				{
					pressedItem = i;
					item.setPressed(true);
					break;
				}
			}
		}
		else if (pressedItem >= 0 && !FlxG.mouse.pressed && !FlxG.mouse.justReleased)
		{
			clearPressedItem();
		}

		if (FlxG.mouse.justReleased)
		{
			if (!overOpenFolder)
			{
				for (i in 0...modsGroup.members.length)
				{
					var item = modsGroup.members[i];
					if (item.visible && item.overlapsMouse())
					{
						releasedItem = i;
						break;
					}
				}
			}

			var clickedItem:Int = pressedItem;
			clearPressedItem();
			if (!overOpenFolder && releasedItem >= 0 && releasedItem == clickedItem)
			{
				curSelected = releasedItem;
				scrollToItemMiddle(releasedItem);
				updateSelection();
				selectItem();
			}
		}

		// 悬停效果
		for (i in 0...modsGroup.members.length)
		{
			var item = modsGroup.members[i];
			if (item.visible && !overOpenFolder && item.overlapsMouse())
			{
				item.updateHover(true);
			}
			else
			{
				item.updateHover(false);
			}
		}
	}

	/**
	 * 检查鼠标是否在列表区域内
	 */
	function isMouseOverList():Bool
	{
		var mouseX = FlxG.mouse.viewX;
		var mouseY = FlxG.mouse.viewY;
		return mouseX >= bgList.x && mouseX <= bgList.x + bgList.width &&
			   mouseY >= bgList.y && mouseY <= bgList.y + bgList.height;
	}

	/** 面板完整矩形——点它外面即退出。 */
	function isMouseOverPanel():Bool
	{
		if (bgList == null) return false;
		var mouseX = FlxG.mouse.viewX;
		var mouseY = FlxG.mouse.viewY;
		return mouseX >= bgList.x && mouseX <= bgList.x + bgList.width &&
			   mouseY >= bgList.y && mouseY <= bgList.y + bgList.height;
	}

	/**
	 * 滚动到指定项目，使其出现在列表可视区域的中间
	 */
	function scrollToItemMiddle(index:Int)
	{
		var targetScroll = index * (itemHeight + ITEM_SPACING) - (visibleItemCount * (itemHeight + ITEM_SPACING)) / 2 + (itemHeight / 2);
		targetScroll = Math.max(0, Math.min(targetScroll, maxScrollPos));

		if (cardScroller != null)
		{
			cardScroller.tweenData = targetScroll;
		}
		else
		{
			scrollPos = targetScroll;
			updateItemsPosition();
			updateScrollBar();
		}
	}

	/**
	 * 键盘选择逻辑 - 滚动到中间位置
	 */
	function changeSelection(change:Int = 0)
	{
		if (modsGroup.members.length == 0) return;

		curSelected = FlxMath.wrap(curSelected + change, 0, modsGroup.members.length - 1);

		var selectedItem = modsGroup.members[curSelected];
		if (selectedItem != null)
		{
			scrollToItemMiddle(curSelected);
		}

		updateSelection();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function updateSelection()
	{
		for (i in 0...modsGroup.members.length)
		{
			var item = modsGroup.members[i];
			item.updateSelection(i == curSelected);
		}

		// 更新右侧信息显示
		var selectedItem = modsGroup.members[curSelected];
		if (selectedItem != null)
		{
			selectedModName.text = selectedItem.name;
			selectedModDesc.text = selectedItem.desc;
			updateModInfoText(selectedItem);

			// 加载模组图标
			if (selectedItem.folder != null && selectedItem.folder.length > 0)
			{
				#if MODS_ALLOWED
				var oldModDir = Mods.currentModDirectory;
				Mods.currentModDirectory = selectedItem.folder;

				var file:String = Paths.mods('${selectedItem.folder}/pack.png');
				var isPixel = false;
				if (!FileSystem.exists(file))
				{
					file = Paths.mods('${selectedItem.folder}/pack-pixel.png');
					isPixel = true;
				}

				var bmp:BitmapData = null;
				if (FileSystem.exists(file))
					bmp = BitmapData.fromFile(file);
				else
					isPixel = false;

				if (FileSystem.exists(file))
				{
					selectedModIcon.loadGraphic(Paths.cacheBitmap(file, bmp), true, 150, 150);
					if (isPixel) selectedModIcon.antialiasing = false;
					selectedModIcon.scale.set(1.5, 1.5);
				}
				else
				{
					selectedModIcon.loadGraphic(Paths.image('unknownMod'));
					selectedModIcon.scale.set(1.5, 1.5);
				}

				selectedModIcon.updateHitbox();
				Mods.currentModDirectory = oldModDir;
				#end
			}
			else
			{
				selectedModIcon.loadGraphic(Paths.image('unknownMod'));
				selectedModIcon.scale.set(1.5, 1.5);
				selectedModIcon.updateHitbox();
			}
		}
	}

	/**
	 * 右侧补充信息：按条目类型给文件夹 / 歌曲数 / 启用状态或分类说明。
	 */
	function updateModInfoText(item:ModFolderItem)
	{
		if (selectedModInfo == null || item == null) return;

		var lines:Array<String> = [];

		switch (item.kind)
		{
			case KIND_FILTER:
				if (item.filter == 'mods' && item.filterSub != null && item.filterSub.length > 0)
				{
					lines.push(Language.getPhrase('mod_info_folder', 'Folder: {1}', ['mods/' + item.filterSub]));
					lines.push(Language.getPhrase('mod_info_songs', 'Songs: {1}', [parent != null ? parent.getSongCountForFolder(item.filterSub) : 0]));
					var isEnabled:Bool = Mods.parseList().enabled.contains(item.filterSub);
					lines.push(isEnabled
						? Language.getPhrase('mod_info_enabled', 'Status: Enabled')
						: Language.getPhrase('mod_info_disabled', 'Status: Disabled'));
				}
				else if (item.filter == 'vanilla' && item.filterSub != null && item.filterSub != FreeplayState.SOURCE_VANILLA_BASE)
				{
					lines.push(Language.getPhrase('mod_info_folder', 'Folder: {1}', [item.filterSub]));
					lines.push(Language.getPhrase('mod_info_songs', 'Songs: {1}', [parent != null ? parent.getSongCountForFolder() : 0]));
				}
				else
					lines.push(Language.getPhrase('mod_info_songs', 'Songs: {1}', [parent != null ? parent.getSongCountForFolder() : 0]));

			case KIND_CATEGORY:
				lines.push(Language.getPhrase('mod_info_category', 'Category: {1}', [item.chartCategory]));

			default:
				lines.push(Language.getPhrase('mod_info_songs', 'Songs: {1}', [parent != null ? parent.getSongCountForFolder() : 0]));
		}

		selectedModInfo.text = lines.join('\n');
	}

	/**
	 * 在系统文件管理器里打开选中项对应的目录。
	 * 模组项 → mods/<mod>；内容项 → content/<大类>/<分类>；其余 → mods/
	 */
	function openSelectedFolder()
	{
		if (shouldClose) return;

		#if (sys && MODS_ALLOWED)
		var selectedItem = modsGroup.members[curSelected];
		var target:String = Paths.mods();

		if (selectedItem != null)
		{
			if (selectedItem.kind == KIND_FILTER && selectedItem.filter == 'mods'
				&& selectedItem.filterSub != null && selectedItem.filterSub.length > 0)
				target = Paths.mods(selectedItem.filterSub + '/');
			else if (selectedItem.kind == KIND_FILTER && selectedItem.filter == 'vanilla'
				&& selectedItem.filterSub != null && selectedItem.filterSub != FreeplayState.SOURCE_VANILLA_BASE)
				target = selectedItem.filterSub + '/';
			else if (selectedItem.kind == KIND_CATEGORY && selectedItem.chartCategory != null
				&& selectedItem.chartCategory.length > 0 && selectedItem.chartCategory != 'custom')
				target = '${Paths.CONTENT_ROOT}/${selectedItem.chartCategory}/';
			else if (selectedItem.kind == KIND_SOURCE && selectedItem.chartCategory == 'charts')
				target = '${Paths.CONTENT_ROOT}/${Paths.CUSTOM_CHART_GROUP}/';
		}

		if (!FileSystem.exists(target))
			FileSystem.createDirectory(target);

		CoolUtil.openFolder(target);
		#end
	}

	/**
	 * 激活当前选中项。
	 * 一级的 CONTENT / 二级的 BACK 只切层级、不关面板；其余都是真正改变 Freeplay 模式后关闭。
	 */
	function selectItem()
	{
		var selectedItem = modsGroup.members[curSelected];
		if (selectedItem == null) return;

		switch (selectedItem.kind)
		{
			case KIND_SOURCE:
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				level = switch (selectedItem.chartCategory)
				{
					case 'vanilla': LEVEL_VANILLA;
					case 'mods':    LEVEL_MODS;
					default:        LEVEL_CHARTS;
				}
				buildList();
				return;

			case KIND_BACK:
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
				level = LEVEL_ROOT;
				buildList();
				return;

			case KIND_FILTER:
				if (parent != null) parent.applySourceFilter(selectedItem.filter, selectedItem.filterSub);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

			case KIND_CATEGORY:
				if (parent != null) parent.enterContentMode(selectedItem.chartCategory);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

			default:
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		}

		close();
	}

	private function _closeNow():Void
	{
        parent.inModFolderSelector = false;
		super.close();
	}

	var closingTimer:Float = 0;
	var shouldClose:Bool = false;

	override function close()
	{
		clearPressedItem();
		if (shouldClose)
		{
			#if !flash
			FlxTransitionableState.skipNextTransOut = false;
			#end
			_closeNow();
			return;
		}

		shouldClose = true;
		closingTimer = 0;

		// 收回动画 - 滑向左侧
		FlxTween.tween(bgList, {x: startX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBarTrack, {x: startX + PANEL_WIDTH - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBar, {x: startX + PANEL_WIDTH - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModIcon, {x: startX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModName, {x: startX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModDesc, {x: startX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModInfo, {x: startX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(openFolderButton, {x: startX + 10}, 0.6, {ease: FlxEase.circOut});

		for (item in modsGroup)
		{
			FlxTween.tween(item, {x: startX + 10}, 0.6, {ease: FlxEase.circOut});
		}

		FlxTween.tween(bgDim, {alpha: 0}, 0.6, {ease: FlxEase.circOut});

		if (cardScroller != null)
		{
			remove(cardScroller);
			cardScroller.destroy();
			cardScroller = null;
		}
    }
}

/**
 * 列表项 - 一级的 ALL / Vanilla / Mods / CustomCharts，二级的 BACK / 具体项共用。
 * kind 决定点击后做什么，见 ModFolderSubstate 里的 KIND_* 常量。
 */
class ModFolderItem extends FreeplayListItem
{
	public var icon:FlxSprite;
	public var text:FlxText;

	public var name:String = 'Unknown';
	public var desc:String = 'No description';
	public var folder:Null<String>;
	public var chartCategory:Null<String>;
	public var kind:String = '';
	/** KIND_FILTER 用：'all' | 'vanilla' | 'mods'。 */
	public var filter:String = null;
	/** KIND_FILTER 用：vanilla → 内容包资源根（SOURCE_VANILLA_BASE = 仅基础周）；mods → 模组目录名；null = 全部。 */
	public var filterSub:String = null;

	static inline var WIDTH:Int = FreeplayListItem.DEFAULT_WIDTH;
	static inline var HEIGHT:Int = FreeplayListItem.DEFAULT_HEIGHT;

	public function new(name:String, desc:String, ?folder:String, ?chartCategory:Null<String>, ?kind:String = '', ?filter:String = null, ?filterSub:String = null)
	{
		super(WIDTH, HEIGHT);

		this.name = name;
		this.desc = desc;
		this.folder = folder;
		this.chartCategory = chartCategory;
		this.kind = kind;
		this.filter = filter;
		this.filterSub = filterSub;

		// 配色沿用这个列表原来的绿/蓝三点式（选中绿是它的既有语义）
		setColors(0xFF888888, 0xFF4488FF, 0xFF66AAFF, 0xFF00FF00, 0.3);

		icon = new FlxSprite(5, 5);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		icon.scale.set(0.5, 0.5);
		content.add(icon);

		text = new FlxText(75, 32, 280, name, 20);
		text.antialiasing = ClientPrefs.data.antialiasing;
		text.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y -= Std.int(text.height / 2);
		content.add(text);

		if (folder != null && folder.length > 0)
		{
			#if MODS_ALLOWED
			var oldModDir = Mods.currentModDirectory;
			Mods.currentModDirectory = folder;

			var file:String = Paths.mods('$folder/pack.png');
			var isPixel = false;
			if (!FileSystem.exists(file))
			{
				file = Paths.mods('$folder/pack-pixel.png');
				isPixel = true;
			}

			var bmp:BitmapData = null;
			if (FileSystem.exists(file))
				bmp = BitmapData.fromFile(file);
			else
				isPixel = false;

			if (FileSystem.exists(file))
			{
				icon.loadGraphic(Paths.cacheBitmap(file, bmp), true, 150, 150);
				if (isPixel) icon.antialiasing = false;
			}
			else
				icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);

			Mods.currentModDirectory = oldModDir;
			#end
		}
		else
		{
			icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		}

		icon.updateHitbox();
	}

	public function updateSelection(isSelected:Bool)
	{
		setSelected(isSelected);
		text.color = isSelected ? FlxColor.WHITE : (isHovered ? 0xFFDDDDDD : 0xFFCCCCCC);
	}

	public function updateHover(isHovered:Bool)
	{
		setHovered(isHovered);
		if (!isSelected)
			text.color = isHovered ? 0xFFDDDDDD : 0xFFCCCCCC;
	}
}
