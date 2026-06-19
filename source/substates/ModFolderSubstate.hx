package substates;

import backend.Mods;
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
 * 从右侧弹出，使用 FlxTween 和 FlxEase.circOut 进行动画
 */
class ModFolderSubstate extends MusicBeatSubstate
{
	var modsList:Array<ModFolderItem> = [];
	var curSelected:Int = 0;
	var parent:FreeplayState;

	var bgList:FlxSprite;
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
		var modsList:ModsList = Mods.parseList();
		totalItems = modsList.all.length + 1; // +1 为 "ALL" 选项

		// 计算可见项目数量
		var panelHeight:Int = FlxG.height;
		visibleItemCount = Math.floor((panelHeight - PADDING_TOP - PADDING_BOTTOM) / (itemHeight + ITEM_SPACING));
		if (visibleItemCount < 1) visibleItemCount = 1;
		
		// 最大滚动位置（像素）
		maxScrollPos = Math.max(0, (totalItems * (itemHeight + ITEM_SPACING)) - (panelHeight - PADDING_TOP - PADDING_BOTTOM));

		// 创建背景面板
		var panelWidth:Int = 500;
		bgList = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(FlxG.width, 40).makeGraphic(panelWidth, FlxG.height - 80, FlxColor.TRANSPARENT),
			0, 0, panelWidth, FlxG.height - 80, 15, 15, FlxColor.BLACK
		);
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
		var allSongsItem = new ModFolderItem("ALL", "Show all songs", 0xFFFFFFFF, null, 0);
		allSongsItem.setPosition(bgList.x + 10, startY);
		if (Mods.currentModDirectory == null)
			curSelected = 0;
		modsGroup.add(allSongsItem);

		// 添加每个模组
		var itemIndex:Int = 1;
		for (mod in modsList.all)
		{
			var modItem = new ModFolderItem(mod, mod, 0xFF888888, mod, itemIndex);
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

		// 模组信息显示区域
		selectedModIcon = new FlxSprite(FlxG.width *0.2, 80);
		selectedModIcon.antialiasing = ClientPrefs.data.antialiasing;
		selectedModIcon.scrollFactor.set();
		add(selectedModIcon);

		selectedModName = new FlxText(FlxG.width *0.2 + 100, 200, 300, "", 32);
		selectedModName.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		selectedModName.scrollFactor.set();
		selectedModName.borderSize = 2;
		add(selectedModName);

		selectedModDesc = new FlxText(FlxG.width *0.2 + 100, 250, 300, "", 16);
		selectedModDesc.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		selectedModDesc.scrollFactor.set();
		selectedModDesc.borderSize = 2;
		add(selectedModDesc);

		// 起始位置和目标位置
		startX = FlxG.width;
		targetX = FlxG.width - 420;

		// 弹出动画
		bgList.x = startX;
		scrollBarTrack.x = startX + panelWidth - 20;
		scrollBar.x = startX + panelWidth - 20;
		selectedModIcon.x = startX + 50;
		selectedModName.x = startX + 50;
		selectedModDesc.x = startX + 50;

		for (item in modsGroup)
		{
			item.x = startX + 10;
		}

		// 使用 FlxTween 和 FlxEase.circOut 从右侧弹出
		FlxTween.tween(bgList, {x: targetX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBarTrack, {x: targetX + panelWidth - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBar, {x: targetX + panelWidth - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModIcon, {x: targetX - 450}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModName, {x: targetX - 450}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModDesc, {x: targetX - 450}, 0.6, {ease: FlxEase.circOut});

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
			if (closingTimer >= 0.65) // 动画时间 + 小余量
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
		else if (controls.BACK)
			close();

		// 鼠标支持 - 点击项目
		for (i in 0...modsGroup.members.length)
		{
			var item = modsGroup.members[i];
			if (item.visible && FlxG.mouse.overlaps(item) && FlxG.mouse.justPressed)
			{
				curSelected = i;
				// 滚动到选中项
				scrollToItem(i);
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
	 * 滚动到指定项目
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

	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, modsGroup.members.length - 1);
		
		// 如果选中项不在可见区域，滚动到它
		var selectedItem = modsGroup.members[curSelected];
		if (selectedItem != null)
		{
			var itemTop = selectedItem.y;
			var itemBottom = selectedItem.y + itemHeight;
			
			if (itemTop < bgList.y + PADDING_TOP)
			{
				scrollToItem(curSelected);
			}
			else if (itemBottom > bgList.y + bgList.height - PADDING_BOTTOM)
			{
				scrollToItem(curSelected - visibleItemCount + 1);
			}
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
			// 如果是"ALL"或空字符串则设置为null
			if (selectedItem.folder == null || selectedItem.folder.length == 0)
				Mods.currentModDirectory = null;
			else
				Mods.currentModDirectory = selectedItem.folder;

			// 通知parent状态改变
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

		// 收回动画
		FlxTween.tween(bgList, {x: startX}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBarTrack, {x: startX + 400 - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(scrollBar, {x: startX + 400 - 20}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModIcon, {x: startX + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModName, {x: startX + 50}, 0.6, {ease: FlxEase.circOut});
		FlxTween.tween(selectedModDesc, {x: startX + 50}, 0.6, {ease: FlxEase.circOut});

		for (item in modsGroup)
		{
			FlxTween.tween(item, {x: startX + 10}, 0.6, {ease: FlxEase.circOut});
		}

		FlxTween.tween(bgDim, {alpha: 0}, 0.6, {ease: FlxEase.circOut});
		
		// 移除 scroller
		if (cardScroller != null)
		{
			remove(cardScroller);
			cardScroller.destroy();
			cardScroller = null;
		}

        if (parent != null)
        {
            parent.inModFolderSelector = false;
        }
    }
}

/**
 * 模组项目 - 用于显示单个模组
 */
class ModFolderItem extends FlxSpriteGroup
{
	public var selectBg:FlxSprite;
	public var icon:FlxSprite;
	public var text:FlxText;

	public var name:String = 'Unknown';
	public var desc:String = 'No description';
	public var folder:Null<String>;
	public var isSelected:Bool = false;
	public var isHovered:Bool = false;

	static inline var WIDTH:Int = 450;
	static inline var HEIGHT:Int = 80;

	public function new(id:String, name:String, color:Int, ?folder:String, index:Int)
	{
		super();

		this.name = name;
		this.folder = folder;

		// 背景选择框
		selectBg = new FlxSprite().makeGraphic(WIDTH, HEIGHT, FlxColor.WHITE);
		selectBg.color = color;
		selectBg.alpha = 0.3;
		add(selectBg);

		// 模组图标
		icon = new FlxSprite(5, 5);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		icon.scale.set(0.5, 0.5);
		add(icon);

		// 模组名称文本
		text = new FlxText(75, 32, 280, name, 20);
		text.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y -= Std.int(text.height / 2);
		add(text);

		// 加载模组图标
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