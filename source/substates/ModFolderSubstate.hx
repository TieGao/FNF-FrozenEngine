package substates;

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
 * ModFolder 子界面 - 用于在 Freeplay 中选择模组
 * 从左侧弹出，使用 FlxTween 和 FlxEase.circOut 进行动画
 */
class ModFolderSubstate extends MusicBeatSubstate
{
	var modsList:Array<ModFolderItem> = [];
	var curSelected:Int = 0;
	var parent:FreeplayState;

	var bgList:FlxFilteredSprite;
	var bgDim:FlxSprite;

	var selectedModName:FlxText;
	var selectedModDesc:FlxText;
	var selectedModIcon:FlxSprite;
	
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
	var scrollBarDragging:Bool = false;
	var dragStartY:Float = 0;
	var dragStartScroll:Float = 0;
	var cardScroller:MouseMove;
	static final customChartCategories:Array<{name:String, category:Null<String>, desc:String}> = [
		{name: 'CUSTOM CHARTS', category: 'custom', desc: 'Show all custom charts'}
	];

	// 面板内部边距
	static inline var PADDING_TOP:Int = 20;
	static inline var PADDING_BOTTOM:Int = 20;
	static inline var ITEM_SPACING:Int = 10;

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

		// 加载模组列表
		var modsListData:ModsList = Mods.parseList();
		var chartFolders:Array<String> = [];
		#if sys
		chartFolders = CustomChartData.listChartCategories();
		#end
		var customChartItemCount:Int = chartFolders.length > 0 ? customChartCategories.length : 0;
		totalItems = modsListData.all.length + 1 + customChartItemCount + chartFolders.length;

		// 计算可见项目数量
		var panelHeight:Int = FlxG.height;
		visibleItemCount = Math.floor((panelHeight - PADDING_TOP - PADDING_BOTTOM) / (itemHeight + ITEM_SPACING));
		if (visibleItemCount < 1) visibleItemCount = 1;
		
		// 最大滚动位置（像素）
		maxScrollPos = Math.max(0, (totalItems * (itemHeight + ITEM_SPACING)) - (panelHeight - PADDING_TOP - PADDING_BOTTOM));

		// 创建背景面板
		var panelWidth:Int = 500;
		bgList = new FlxFilteredSprite();
		bgList.makeGraphic(panelWidth, panelHeight, FlxColor.BLACK,);
		bgList.filters = [new BlurFilter(30,30,BitmapFilterQuality.HIGH)];
		bgList.alpha = 0.8;
		bgList.scrollFactor.set();
		add(bgList);

		// 创建滚动条轨道
		scrollBarTrack = new FlxSprite();
		scrollBarTrack.makeGraphic(8, panelHeight - 40, FlxColor.GRAY);
		scrollBarTrack.alpha = 0.3;
		scrollBarTrack.x = bgList.x + panelWidth - 20;
		scrollBarTrack.y = bgList.y + 20;
		scrollBarTrack.scrollFactor.set();
		//add(scrollBarTrack);

		// 创建滚动条
		scrollBar = new FlxSprite();
		var trackHeight = scrollBarTrack.height;
		var thumbHeight = Math.max(30, trackHeight * (visibleItemCount / totalItems));
		scrollBar.makeGraphic(8, Std.int(thumbHeight), FlxColor.WHITE);
		scrollBar.alpha = 0.6;
		scrollBar.x = scrollBarTrack.x;
		scrollBar.y = scrollBarTrack.y;
		scrollBar.scrollFactor.set();
		//add(scrollBar);

		// 创建模组项目组
		modsGroup = new FlxTypedGroup<ModFolderItem>();
		add(modsGroup);

		var startY:Float = bgList.y + PADDING_TOP;

		// 添加"所有歌曲"选项
		var allSongsItem = new ModFolderItem("ALL", "Show all songs", 0xFFFFFFFF, null, 0, null);
		allSongsItem.setPosition(bgList.x + 10, startY);
		if (Mods.currentModDirectory == null && Paths.currentChartCategory == null)
			curSelected = 0;
		modsGroup.add(allSongsItem);

		// 添加自定义谱面分类。该页面状态决定 Freeplay 显示全部模组歌曲还是谱面分类。
		var itemIndex:Int = 1;
		if (chartFolders.length > 0)
		{
			for (chartCategory in customChartCategories)
			{
				var chartItem = new ModFolderItem(chartCategory.name, chartCategory.desc, 0xFF4488FF, null, itemIndex, chartCategory.category);
				chartItem.setPosition(bgList.x + 10, startY + (itemIndex * (itemHeight + ITEM_SPACING)));
				modsGroup.add(chartItem);
				if (Paths.currentChartCategory == chartCategory.category && Mods.currentModDirectory == null)
					curSelected = itemIndex;
				itemIndex++;
			}
		}

		#if sys
		// charts 下的一级目录就是自定义谱面的分类/来源。
		for (folder in chartFolders)
		{
			var chartItem = new ModFolderItem(folder, 'Show charts from mods/charts/$folder', 0xFF4488FF, null, itemIndex, folder);
			chartItem.setPosition(bgList.x + 10, startY + (itemIndex * (itemHeight + ITEM_SPACING)));
			modsGroup.add(chartItem);
			if (Paths.currentChartCategory == folder && Mods.currentModDirectory == null) curSelected = itemIndex;
			itemIndex++;
		}
		#end

		// 添加每个模组
		for (mod in modsListData.all)
		{
			// 获取模组描述
			var pack = Mods.getPack(mod);
			var modName:String = mod;
			var modDesc:String = 'No description';
			if (pack != null)
			{
				if (pack.name != null) modName = pack.name;
				if (pack.description != null) modDesc = pack.description;
			}
			
			var modItem = new ModFolderItem(modName, modDesc, 0xFF888888, mod, itemIndex, null);
			modItem.setPosition(bgList.x + 10, startY + (itemIndex * (itemHeight + ITEM_SPACING)));
			modsGroup.add(modItem);
			
			if (Mods.currentModDirectory == mod)
				curSelected = itemIndex;

			itemIndex++;
		}

		// 初始化滚动位置，使选中项可见
		var selectedIndex = curSelected;
		var targetScroll = selectedIndex * (itemHeight + ITEM_SPACING) - (visibleItemCount * (itemHeight + ITEM_SPACING)) / 2 + (itemHeight / 2);
		scrollPos = Math.max(0, Math.min(targetScroll, maxScrollPos));

		// 模组信息显示区域 - 调整位置（右侧显示）
		selectedModIcon = new FlxSprite(FlxG.width * 0.2, 80);
		selectedModIcon.antialiasing = ClientPrefs.data.antialiasing;
		selectedModIcon.scrollFactor.set();
		add(selectedModIcon);

		// mod名字下移40像素
		selectedModName = new FlxText(FlxG.width * 0.2 + 100, 240, 300, "", 32);
		selectedModName.antialiasing = ClientPrefs.data.antialiasing;
		selectedModName.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		selectedModName.scrollFactor.set();
		selectedModName.borderSize = 2;
		add(selectedModName);

		// 描述在mod名字下20像素
		selectedModDesc = new FlxText(FlxG.width * 0.2 + 100, 292, 300, "", 16);
		selectedModDesc.antialiasing = ClientPrefs.data.antialiasing;
		selectedModDesc.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		selectedModDesc.scrollFactor.set();
		selectedModDesc.borderSize = 2;
		add(selectedModDesc);

		// ===== 关键修改：从左侧弹出 =====
		// 起始位置：屏幕左侧之外（负的宽度）
		startX = -panelWidth - 250;
		// 目标位置：屏幕左侧，留一点边距
		targetX = 10;

		// 弹出动画 - 从左侧滑入
		bgList.x = startX;
		scrollBarTrack.x = startX + panelWidth - 20;
		scrollBar.x = startX + panelWidth - 20;
		selectedModIcon.x = startX ; // 图标在面板右侧
		selectedModName.x = startX ;
		selectedModDesc.x = startX ;

		for (item in modsGroup)
		{
			item.x = startX + 10;
		}

		// 使用 FlxTween 和 FlxEase.circOut 从左侧弹出
		FlxTween.tween(bgList, {x: targetX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBarTrack, {x: targetX + panelWidth - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBar, {x: targetX + panelWidth - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModIcon, {x: targetX + panelWidth + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModName, {x: targetX + panelWidth + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModDesc, {x: targetX + panelWidth + 50}, 0.6, {ease: FlxEase.circOut});

		for (item in modsGroup)
		{
			FlxTween.tween(item, {x: targetX + 10}, 0.6, {ease: FlxEase.circOut});
		}

		FlxTween.tween(bgDim, {alpha: 0.5}, 0.6, {ease: FlxEase.circOut});

		// 创建鼠标滚动控制器
		cardScroller = new MouseMove(this, 'scrollPos', [0, maxScrollPos], 
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

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (shouldClose)
		{
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
			selectMod();
		else if (controls.BACK || FlxG.mouse.justPressedRight)
			close();

		// 鼠标支持 - 点击项目
		for (i in 0...modsGroup.members.length)
		{
			var item = modsGroup.members[i];
			if (item.visible && FlxG.mouse.overlaps(item) && FlxG.mouse.justPressed)
			{
				curSelected = i;
				scrollToItemMiddle(i);
				updateSelection();
				selectMod();
				break;
			}
		}

		// 悬停效果
		for (i in 0...modsGroup.members.length)
		{
			var item = modsGroup.members[i];
			if (item.visible && FlxG.mouse.overlaps(item))
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
		var mouseX = FlxG.mouse.screenX;
		var mouseY = FlxG.mouse.screenY;
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
	 * 滚动到指定项目 (保留原有功能，用于鼠标点击等)
	 */
	function scrollToItem(index:Int)
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

			// 加载模组图标
			if (selectedItem.folder != null)
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

	function selectMod()
	{
		var selectedItem = modsGroup.members[curSelected];
		if (selectedItem != null)
		{
			Paths.currentChartCategory = selectedItem.chartCategory;
			if (selectedItem.chartCategory != null)
				Mods.currentModDirectory = null;
			else if (selectedItem.folder == null || selectedItem.folder.length == 0)
				Mods.currentModDirectory = null;
			else
				Mods.currentModDirectory = selectedItem.folder;

			if (parent != null)
			{
				parent.onModFolderChanged();
			}

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

		// ===== 关键修改：收回动画从左侧出去 =====
		// 收回动画 - 滑向左侧
		FlxTween.tween(bgList, {x: startX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBarTrack, {x: startX + 400 - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBar, {x: startX + 400 - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModIcon, {x: startX }, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModName, {x: startX }, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModDesc, {x: startX }, 0.6, {ease: FlxEase.circOut});

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
 * 模组项目 - 用于显示单个模组
 */
class ModFolderItem extends FlxSpriteGroup
{
	public var selectBg:FlxFilteredSprite;
	public var icon:FlxSprite;
	public var text:FlxText;

	public var name:String = 'Unknown';
	public var desc:String = 'No description';
	public var folder:Null<String>;
	public var chartCategory:Null<String>;
	public var isSelected:Bool = false;
	public var isHovered:Bool = false;

	static inline var WIDTH:Int = 450;
	static inline var HEIGHT:Int = 80;

	public function new(name:String, desc:String, color:Int, ?folder:String, index:Int, ?chartCategory:Null<String>)
	{
		super();

		this.name = name;
		this.desc = desc;
		this.folder = folder;
		this.chartCategory = chartCategory;

		selectBg = new FlxFilteredSprite();
		selectBg.makeGraphic(WIDTH, HEIGHT, FlxColor.WHITE);
		selectBg.filters = [new BlurFilter(30,30,BitmapFilterQuality.HIGH)];
		selectBg.color = color;
		selectBg.alpha = 0.3;
		add(selectBg);

		icon = new FlxSprite(5, 5);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		icon.scale.set(0.5, 0.5);
		add(icon);

		text = new FlxText(75, 32, 280, name, 20);
		text.antialiasing = ClientPrefs.data.antialiasing;
		text.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y -= Std.int(text.height / 2);
		add(text);

		if (folder != null)
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
		this.isSelected = isSelected;
		if (isSelected)
		{
			selectBg.alpha = 0.8;
			selectBg.color = 0xFF00FF00;
			text.color = FlxColor.WHITE;
		}
		else if (isHovered)
		{
			selectBg.alpha = 0.5;
			selectBg.color = 0xFF4488FF;
			text.color = 0xFFDDDDDD;
		}
		else
		{
			selectBg.alpha = 0.3;
			selectBg.color = 0xFF888888;
			text.color = 0xFFCCCCCC;
		}
	}

	public function updateHover(isHovered:Bool)
	{
		this.isHovered = isHovered;
		if (!isSelected)
		{
			if (isHovered)
			{
				selectBg.alpha = 0.5;
				selectBg.color = 0xFF4488FF;
				text.color = 0xFFDDDDDD;
			}
			else
			{
				selectBg.alpha = 0.3;
				selectBg.color = 0xFF888888;
				text.color = 0xFFCCCCCC;
			}
		}
	}
}