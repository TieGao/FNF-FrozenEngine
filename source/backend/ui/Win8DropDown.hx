package backend.ui;

import backend.UIControlTheme;

/**
 * Win8（Metro）风格下拉选择框 —— 编辑器弹窗这类纯 UI 场景用（不绑 Option）。
 *
 * 视觉与 options 侧 StringSelect 的 Win8 分支同一套语言：方角、2px 描边、
 * 悬停/展开转强调色，弹层是 Metro 菜单（panelBG 底 + railHover 悬停行）。
 * 区别：不绑 Option（纯 onSelect 回调）、固定 Win8 形制不随 UIControlTheme.pref
 * 切换、字体用 vcr.ttf 与弹窗内其它文本统一（含 CJK 重映射，选项文本非 ASCII 也稳）。
 *
 * 层级：弹层 popup 由宿主 attachPopup() 挪到"最后 add 的 topLayer"上，保证展开时
 * 画在对话框所有按钮之上（旧 PsychUIDropDownMenu 的弹层是对话框普通成员，
 * 会被后加的按钮盖住 —— "下拉图层比按钮低"的根因）。
 *
 * 命中：一律 FlxG.mouse.overlaps(sprite, cam) 显式传相机 —— update 期的默认相机
 * 解析到 defaults[0]（主相机），编辑器主相机带 scroll 必偏（flixel-clip 三节）。
 *
 * 穿透屏蔽：本组件只管自己（弹层悬停时不抢主条 hover、点外面关闭、打开那一帧
 * 不处理项点击防误选）；宿主负责在下拉展开时把其它交互组件 active 关掉
 * （见 ChartImportDialog.update）。
 */
class Win8DropDown extends FlxSpriteGroup
{
	/** 选中某项时回调（下标、文本） */
	public var onSelect:Int->String->Void;
	public var options:Array<String> = [];
	public var selectedIndex(default, set):Int = 0;
	/** 弹层是否展开（宿主据此挂起其它组件的点击） */
	public var isOpen(default, null):Bool = false;

	var mainW:Float;
	var mainH:Float;
	var uiCam:FlxCamera;
	var topLayer:FlxSpriteGroup;
	var popupAttached:Bool = false;

	var face:Rect;         // 主条底
	// ⚠️ 不能叫 frame：FlxSprite 已有 frame 字段，子类重定义直接编译报错
	var outline:FlxSprite; // 主条 2px 描边
	var label:FlxText;     // 当前值
	var arrow:FlxSprite;   // 手绘箭头（vcr 没有箭头字形，画三角形）

	var popup:FlxSpriteGroup;
	var popupBg:Rect;
	var popupFrame:FlxSprite;
	var popupItems:Array<Rect> = [];
	var popupTexts:Array<FlxText> = [];
	/** 长列表右侧滑块；放得下时为 null */
	var popupThumb:Rect;

	var hover:Bool = false;
	var pressing:Bool = false;
	var scrollIndex:Int = 0;

	static inline var ITEM_H:Float = 28;
	static inline var MAX_VISIBLE_ROWS:Int = 8;
	static inline var THUMB_W:Float = 3;
	static inline var EDGE_MARGIN:Float = 4;

	public function new(x:Float, y:Float, width:Float, options:Array<String>, ?onSelect:Int->String->Void, ?height:Float = 28)
	{
		super(x, y);
		this.options = (options != null) ? options.copy() : [];
		this.onSelect = onSelect;
		mainW = width;
		mainH = height;

		face = new Rect(0, 0, width, height, 0, 0, UIControlTheme.face(), 1);
		face.antialiasing = ClientPrefs.data.antialiasing;
		add(face);

		outline = UIControlTheme.makeFrameSprite(width, height);
		outline.color = UIControlTheme.border();
		add(outline);

		label = new FlxText(10, 0, width - 28, '', 15);
		label.setFormat(Paths.font('vcr.ttf'), 15, UIControlTheme.text(), LEFT);
		label.borderStyle = NONE;
		label.antialiasing = ClientPrefs.data.antialiasing;
		label.y = (height - label.height) * 0.5;
		add(label);

		arrow = new FlxSprite();
		arrow.antialiasing = ClientPrefs.data.antialiasing;
		add(arrow);
		redrawArrow();

		popup = new FlxSpriteGroup();
		popup.visible = false;
		add(popup); // attachPopup 之前先挂自己，保证没 attach 也能独立用

		refreshLabel();
	}

	/**
	 * 把弹层挪到宿主的最高层容器并绑定命中相机。
	 * 弹层成员坐标是绝对的（FlxSpriteGroup 特性），topLayer 在 (0,0) 时即屏幕坐标。
	 */
	public function attachPopup(newTopLayer:FlxSpriteGroup, newCam:FlxCamera):Void
	{
		topLayer = newTopLayer;
		uiCam = newCam;
		remove(popup, true);
		topLayer.add(popup);
		popupAttached = true;
		if (uiCam != null) popup.cameras = [uiCam];
	}

	function set_selectedIndex(v:Int):Int
	{
		if (v < 0 || options == null || v >= options.length) v = 0;
		selectedIndex = v;
		refreshLabel();
		return v;
	}

	function refreshLabel():Void
	{
		if (label == null) return;
		label.text = (selectedIndex >= 0 && selectedIndex < options.length) ? options[selectedIndex] : '';
		refreshColors();
	}

	function refreshColors():Void
	{
		if (face == null) return;
		var active:Bool = !enabled ? false : (hover || isOpen);
		face.color = active ? UIControlTheme.faceHover() : UIControlTheme.face();
		outline.color = active ? UIControlTheme.accent() : UIControlTheme.border();
		label.color = !enabled ? UIControlTheme.textSecondary() : (active ? UIControlTheme.accent() : UIControlTheme.text());
	}

	/**
	 * 禁用（灰掉且不响应鼠标）。宿主用它表达"当前选项无效"，
	 * 例如导入对话框里没勾选"转换键数"时目标键数下拉就是无意义的。
	 */
	public var enabled(default, set):Bool = true;

	function set_enabled(v:Bool):Bool
	{
		if (v == enabled) return v;
		enabled = v;
		if (!v)
		{
			closeList();
			clearInputState();
		}
		redrawArrow();
		refreshColors();
		return v;
	}

	/**
	 * 清掉按下/悬停状态。宿主把本组件 active 挂起（另一个下拉展开）时调用：
	 * 否则恢复后残留的 pressing 会被下一次 justReleased 误判成一次点击。
	 */
	public function clearInputState():Void
	{
		hover = false;
		pressing = false;
		redrawArrow();
		refreshColors();
	}

	// =========================================================
	// 弹层
	// =========================================================

	function visibleRows():Int
	{
		if (options.length == 0) return 0;
		return options.length > MAX_VISIBLE_ROWS ? MAX_VISIBLE_ROWS : options.length;
	}

	function maxScrollIndex():Int
	{
		var m:Int = options.length - visibleRows();
		return m > 0 ? m : 0;
	}

	function getPopupHeight():Float
	{
		var n:Int = visibleRows();
		return n <= 0 ? 0 : n * ITEM_H + 8;
	}

	/** 把下标 idx 滚进可视窗口 */
	function scrollToShow(idx:Int):Void
	{
		var rows:Int = visibleRows();
		if (rows <= 0) return;
		if (scrollIndex > idx) scrollIndex = idx;
		else if (idx >= scrollIndex + rows) scrollIndex = idx - rows + 1;
		scrollIndex = Std.int(FlxMath.bound(scrollIndex, 0, maxScrollIndex()));
	}

	function buildPopup():Void
	{
		clearPopup();
		if (options.length == 0) return;

		var w:Float = mainW;
		var h:Float = getPopupHeight();

		popupBg = new Rect(0, 0, w, h, 0, 0, UIControlTheme.panelBG(), 1);
		popupBg.antialiasing = ClientPrefs.data.antialiasing;
		popup.add(popupBg);

		popupFrame = UIControlTheme.makeFrameSprite(w, h);
		popupFrame.color = UIControlTheme.border();
		popup.add(popupFrame);

		for (i in 0...options.length)
		{
			var item:Rect = new Rect(4, 4 + i * ITEM_H, w - 8, ITEM_H, 0, 0, UIControlTheme.railHover(), 0);
			item.antialiasing = ClientPrefs.data.antialiasing;
			popup.add(item);
			popupItems.push(item);

			var t:FlxText = new FlxText(12, 4 + i * ITEM_H, w - 24, options[i], 15);
			t.setFormat(Paths.font('vcr.ttf'), 15, UIControlTheme.text(), LEFT);
			t.borderStyle = NONE;
			t.antialiasing = ClientPrefs.data.antialiasing;
			popup.add(t);
			popupTexts.push(t);
		}

		// 滑块最后加，画在列表项上面
		popupThumb = null;
		if (maxScrollIndex() > 0)
		{
			popupThumb = new Rect(0, 0, THUMB_W, ITEM_H, 0, 0, UIControlTheme.textSecondary(), 1);
			popupThumb.antialiasing = false;
			popup.add(popupThumb);
		}

		applyPopupScroll();
	}

	/**
	 * 清掉弹层旧成员。不能边遍历 popup.members 边 remove（splice 就地删元素会
	 * 隔一个漏一个），先拷一份再删；popupBg / popupFrame / popupThumb 必须置空，
	 * 留着已 destroy 的引用会被 update 的 overlaps 判定拿去用而空引用。
	 */
	function clearPopup():Void
	{
		var old:Array<FlxSprite> = popup.members.copy();
		for (m in old)
		{
			if (m == null) continue;
			popup.remove(m, true);
			m.destroy();
		}
		popupItems = [];
		popupTexts = [];
		popupBg = null;
		popupFrame = null;
		popupThumb = null;
	}

	/**
	 * 按 scrollIndex 重排可见项（滚出窗口的隐藏）。
	 * ⚠️ FlxSpriteGroup 成员坐标是绝对的：add 时已把 popup 的 x/y 烘进成员，
	 * 绘制不再叠加父级偏移 —— y 必须写 popup.y + 局部Y，否则整列飞到屏幕顶部。
	 */
	function applyPopupScroll():Void
	{
		var oy:Float = popup.y;
		var rows:Int = visibleRows();
		for (i in 0...popupItems.length)
		{
			var slot:Int = i - scrollIndex;
			var inView:Bool = slot >= 0 && slot < rows;
			var y:Float = oy + 4 + slot * ITEM_H;

			popupItems[i].y = y;
			if (i < popupTexts.length)
				popupTexts[i].y = y + (ITEM_H - popupTexts[i].height) * 0.5;

			popupItems[i].visible = inView;
			if (i < popupTexts.length) popupTexts[i].visible = inView;
		}
		updateThumb();
	}

	/** 长列表右侧滑块标出当前滚到哪一段 */
	function updateThumb():Void
	{
		if (popupThumb == null) return;

		var total:Int = popupItems.length;
		var rows:Int = visibleRows();
		if (rows <= 0 || total <= rows)
		{
			popupThumb.visible = false;
			return;
		}

		var trackH:Float = rows * ITEM_H;
		var h:Float = Math.max(18, trackH * rows / total);
		var maxIdx:Int = maxScrollIndex();

		popupThumb.visible = true;
		popupThumb.setGraphicSize(Std.int(THUMB_W), Std.int(h));
		popupThumb.updateHitbox();
		popupThumb.x = popup.x + mainW - THUMB_W - 3;
		popupThumb.y = popup.y + 4 + (trackH - h) * (maxIdx > 0 ? scrollIndex / maxIdx : 0);
	}

	/** 弹层位置：优先主条下方，放不下翻上方，都放不下居中夹取到屏幕内 */
	function syncPopupPosition():Void
	{
		if (popup == null || !isOpen) return;
		var popupH:Float = getPopupHeight();
		if (popupH <= 0) return;

		// face 是本组件成员，坐标已含组偏移（scrollFactor=0 + camUI 不滚 → 即屏幕坐标）
		var viewX:Float = face.x;
		var belowY:Float = face.y + mainH + 4;
		var aboveY:Float = face.y - popupH - 4;
		var maxBottom:Float = FlxG.height - EDGE_MARGIN;
		var viewY:Float;

		if (belowY + popupH <= maxBottom)
			viewY = belowY;
		else if (aboveY >= EDGE_MARGIN)
			viewY = aboveY;
		else
		{
			viewY = face.y + mainH * 0.5 - popupH * 0.5;
			if (viewY + popupH > maxBottom) viewY = maxBottom - popupH;
			if (viewY < EDGE_MARGIN) viewY = EDGE_MARGIN;
		}

		if (viewX + mainW > FlxG.width - EDGE_MARGIN)
			viewX = FlxG.width - mainW - EDGE_MARGIN;
		if (viewX < EDGE_MARGIN) viewX = EDGE_MARGIN;

		popup.x = viewX;
		popup.y = viewY;
		// 组的 set_x/y 只传播增量，弹层一挪就得重排成员，否则内容与背景错位
		applyPopupScroll();
	}

	public function openList():Void
	{
		if (!enabled || isOpen || options.length == 0) return;
		scrollIndex = 0;
		scrollToShow(selectedIndex);
		buildPopup();
		syncPopupPosition();
		popup.visible = true;
		isOpen = true;
		redrawArrow();
		refreshColors();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	public function closeList():Void
	{
		if (!isOpen) return;
		isOpen = false;
		popup.visible = false;
		pressing = false;
		redrawArrow();
		refreshColors();
	}

	// =========================================================
	// 交互
	// =========================================================

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!enabled || options.length == 0) return;
		syncPopupPosition();

		var mouse = FlxG.mouse;
		var cam:FlxCamera = (uiCam != null) ? uiCam : camera;
		var overPopup:Bool = isOpen && popup.visible && popupBg != null && mouse.overlaps(popupBg, cam);

		// 弹层上滚轮翻页（宿主弹窗没有滚轮逻辑，不用让路）
		if (isOpen && overPopup && mouse.wheel != 0 && maxScrollIndex() > 0)
		{
			scrollIndex = Std.int(FlxMath.bound(scrollIndex - mouse.wheel, 0, maxScrollIndex()));
			applyPopupScroll();
		}

		// 鼠标在弹层上时主条不抢悬停（弹层翻上来盖住主条时不误判）
		var wasHover:Bool = hover;
		hover = mouse.overlaps(face, cam) && !overPopup;
		if (hover != wasHover)
		{
			redrawArrow();
			refreshColors();
		}

		// 按下只记状态，松开仍在主条上才开/关 —— 打开瞬间的这次松开
		// 不能又被首项吃掉（否则刚展开就误选）
		if (hover && mouse.justPressed)
			pressing = true;
		if (!hover && pressing && !overPopup)
			pressing = false;

		var openedThisFrame:Bool = false;
		if (mouse.justReleased && pressing && hover)
		{
			pressing = false;
			if (isOpen) closeList();
			else { openList(); openedThisFrame = true; }
		}

		if (!isOpen || openedThisFrame) return;

		// 项悬停 + 点击选中（滚出窗口的项不参与）
		for (i in 0...popupItems.length)
		{
			var it:Rect = popupItems[i];
			if (!it.visible) continue;

			var itHover:Bool = mouse.overlaps(it, cam);
			it.alpha = itHover ? 1 : 0;

			if (itHover && mouse.justReleased)
			{
				selectedIndex = i;
				if (onSelect != null) onSelect(i, options[i]);
				closeList();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
				return;
			}
		}

		// 点外面关闭（主条和弹层都不算外面）；右键也算
		if ((mouse.justPressed || mouse.justPressedRight) && !mouse.overlaps(face, cam) && !overPopup)
			closeList();
	}

	// =========================================================
	// 箭头（手绘：vcr 没有箭头字形）
	// =========================================================

	function redrawArrow():Void
	{
		var size:Float = mainH * 0.16;
		var thickness:Float = Math.max(1.5, mainH * 0.05);
		var w:Int = Std.int(size * 2 + thickness + 2);
		var h:Int = Std.int(size + thickness + 2);

		var bmd = new openfl.display.BitmapData(w, h, true, 0x00000000);
		var cx:Float = w * 0.5;
		var cy:Float = h * 0.5;
		var dir:Float = isOpen ? -1 : 1;
		var col:FlxColor = !enabled ? UIControlTheme.textSecondary()
			: ((hover || isOpen) ? UIControlTheme.accent() : UIControlTheme.textSecondary());

		drawThickLine(bmd, cx - size, cy - size * 0.4 * dir, cx, cy + size * 0.4 * dir, thickness, col);
		drawThickLine(bmd, cx, cy + size * 0.4 * dir, cx + size, cy - size * 0.4 * dir, thickness, col);

		arrow.pixels = bmd;
		arrow.offset.set(0, 0);
		arrow.origin.set(0, 0);
		arrow.scale.set(1, 1);
		arrow.updateHitbox();
		// 成员坐标是绝对的，重设要带组偏移
		arrow.setPosition(this.x + mainW - w - 8, this.y + (mainH - h) * 0.5);
	}

	static function drawThickLine(bmd:openfl.display.BitmapData, x1:Float, y1:Float, x2:Float, y2:Float,
			thickness:Float, color:FlxColor):Void
	{
		var dx:Float = x2 - x1;
		var dy:Float = y2 - y1;
		var len:Float = Math.sqrt(dx * dx + dy * dy);
		if (len == 0) return;
		var nx:Float = dx / len;
		var ny:Float = dy / len;
		var half:Float = thickness * 0.5;

		var steps:Int = Std.int(len);
		if (steps < 1) steps = 1;
		for (i in 0...steps + 1)
		{
			var t:Float = i / steps;
			var px:Float = x1 + dx * t;
			var py:Float = y1 + dy * t;
			var perpX:Float = -ny;
			var perpY:Float = nx;
			for (j in 0...Std.int(thickness) + 1)
			{
				var off:Float = -half + j;
				var fx:Int = Std.int(px + perpX * off);
				var fy:Int = Std.int(py + perpY * off);
				if (fx >= 0 && fy >= 0 && fx < bmd.width && fy < bmd.height)
					bmd.setPixel32(fx, fy, color);
			}
		}
	}

	/**
	 * attachPopup 之后弹层挂在宿主的 topLayer 里，不在本组件销毁树内，
	 * 必须手动摘掉销毁（StringSelect.destroy 同款）。
	 */
	override function destroy():Void
	{
		if (popupAttached && topLayer != null && popup != null)
		{
			topLayer.remove(popup, true);
			popup.destroy();
		}
		popup = null;
		super.destroy();
	}
}
