package options.objects.win10;

import flixel.addons.display.shapes.FlxShapeCircle;
import flixel.util.FlxGradient;
import openfl.display.BitmapData;
import options.objects.OptionInput;
import objects.KeyboardViewer;

/**
 * KeyboardViewer 专用调色盘。
 *
 * 从 `options.psychoptions.NotesColorSubState` **原地复制**而来：只保留色相环、
 * 亮度条、预设色板和颜色代码，砍掉轨道选择 / 音符预览 / 复制粘贴 / 手柄指针。
 * 刻意不做成通用组件 —— 那套界面和设置页的 UI 框架完全是两回事。
 *
 * 四项颜色目标共用同一套控件，靠顶部切换行切：
 *   0 键盘主体 → keyboardBGColor
 *   1 键盘边缘 → keyboardEdgeColor
 *   2 键盘键雨 → keyboardRainColor
 *   3 字体颜色 → keyboardTextColor
 *
 * 交互全部走 update 轮询（和原版一致），不使用事件监听。
 */
class KeyboardColorPanel extends FlxSpriteGroup
{
	// ---------- 四个颜色目标 ----------
	public static inline var T_BODY:Int = 0;
	public static inline var T_EDGE:Int = 1;
	public static inline var T_RAIN:Int = 2;
	public static inline var T_FONT:Int = 3;

	static var TARGET_KEYS:Array<String> = ['kb_color_body', 'kb_color_edge', 'kb_color_rain', 'kb_color_font'];
	static var TARGET_EN:Array<String> = ['Body', 'Edge', 'Rain', 'Font'];

	// ---------- 版式常量（其余坐标全部由 W/H 推导） ----------
	static inline var PAD:Float = 14;
	static inline var SWITCH_H:Float = 30;
	static inline var ARROW_W:Float = 30;
	static inline var CHIP_W:Float = 34;
	static inline var CHIP_H:Float = 18;
	static inline var CHIP_GAP:Float = 8;
	static inline var HEX_H:Float = 26;
	static inline var RGB_H:Float = 16;
	static inline var BAR_W:Float = 24;
	static inline var BAR_GAP:Float = 10;
	static inline var BAR_SEL_H:Float = 8;
	static inline var WHEEL_MIN:Float = 120;
	static inline var WHEEL_MAX:Float = 260;
	static inline var PALETTE_COLS:Int = 16;
	static inline var PALETTE_ROWS:Int = 4;

	// ---------- 拖拽状态 ----------
	static inline var DRAG_NONE:Int = 0;
	static inline var DRAG_WHEEL:Int = 1;
	static inline var DRAG_BAR:Int = 2;

	public var target:Int = T_BODY;

	// 面板原点是世界坐标；FlxSpriteGroup.add() 会把 group 的 x/y 烘进子对象，
	// 所以命中判定统一按 px/py 算，不读子对象的坐标换算。
	var px:Float = 0;
	var py:Float = 0;
	var panelW:Float = 0;
	var panelH:Float = 0;
	var wheelSize:Float = 0;
	var paletteScale:Int = 16;

	var bg:Rect;
	var label:FlxText;
	var arrowL:FlxText;
	var arrowR:FlxText;
	var chips:Array<Rect> = [];
	var chipBacks:Array<Rect> = [];
	var chipFrames:Array<Rect> = [];
	var hexText:FlxText;
	var rgbText:FlxText;
	var wheel:FlxSprite;
	var wheelSel:FlxShapeCircle;
	var bar:FlxSprite;
	var barSel:FlxSprite;
	var palette:FlxSprite;
	/** 预设色板 16×4 = 64 个颜色，构建时读一次存下来（点击时不再碰 BitmapData） */
	var paletteColors:Array<Int> = [];

	var dragMode:Int = DRAG_NONE;
	var storedHue:Float = 0;
	var storedSat:Float = 0;
	var storedVal:Float = 0;

	public function new(X:Float, Y:Float, W:Float, H:Float)
	{
		super(X, Y);
		UITheme.ensure();

		px = X;
		py = Y;
		panelW = W;
		panelH = H;

		build();

		refreshLabels();
		refreshValueUI();
	}

	// =========================================================
	// 构建
	// =========================================================
	function build():Void
	{
		var innerW:Float = panelW - PAD * 2;

		bg = new Rect(0, 0, panelW, panelH, 6, 6, UITheme.popup, 1);
		add(bg);
		bg.setPosition(px, py);

		// ---------- 顶部切换行： <  键盘主体  > ----------
		label = new FlxText(0, 0, panelW, '', 18);
		label.setFormat(Paths.font('vcr.ttf'), 18, UITheme.textPrimary, CENTER);
		label.borderStyle = NONE;
		label.antialiasing = ClientPrefs.data.antialiasing;
		add(label);
		label.setPosition(px, py + PAD + (SWITCH_H - label.height) / 2);

		arrowL = makeArrow('<');
		arrowR = makeArrow('>');
		add(arrowL);
		add(arrowR);
		arrowL.setPosition(px + PAD, py + PAD + (SWITCH_H - arrowL.height) / 2);
		arrowR.setPosition(px + panelW - PAD - ARROW_W, py + PAD + (SWITCH_H - arrowR.height) / 2);

		// ---------- 四色块：既是预览也是快捷切换 ----------
		var chipsW:Float = 4 * CHIP_W + 3 * CHIP_GAP;
		var chipsX:Float = px + (panelW - chipsW) / 2;
		var chipsY:Float = py + PAD + SWITCH_H + 4;

		for (i in 0...4)
		{
			var cx:Float = chipsX + i * (CHIP_W + CHIP_GAP);

			var frame:Rect = new Rect(0, 0, CHIP_W + 4, CHIP_H + 4, 3, 3, UITheme.accent, 0);
			add(frame);
			frame.setPosition(cx - 2, chipsY - 2);
			chipFrames.push(frame);

			// 底色垫一圈边框：浅色主题下白色色块（字体色默认白）不然会整个消失
			var backing:Rect = new Rect(0, 0, CHIP_W + 2, CHIP_H + 2, 2, 2, UITheme.divider, 1);
			add(backing);
			backing.setPosition(cx - 1, chipsY - 1);
			chipBacks.push(backing);

			var swatch:Rect = new Rect(0, 0, CHIP_W, CHIP_H, 2, 2, FlxColor.WHITE, 1);
			add(swatch);
			swatch.setPosition(cx, chipsY);
			chips.push(swatch);
		}

		// ---------- 颜色代码 + RGB ----------
		var hexY:Float = chipsY + CHIP_H + 12;
		hexText = new FlxText(0, 0, panelW, '', 22);
		hexText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		hexText.borderSize = 2;
		hexText.antialiasing = ClientPrefs.data.antialiasing;
		add(hexText);
		hexText.setPosition(px, hexY);

		var rgbY:Float = hexY + HEX_H;
		rgbText = new FlxText(0, 0, panelW, '', 12);
		rgbText.setFormat(Paths.font('vcr.ttf'), 12, UITheme.textSecondary, CENTER);
		rgbText.borderStyle = NONE;
		rgbText.antialiasing = ClientPrefs.data.antialiasing;
		add(rgbText);
		rgbText.setPosition(px, rgbY);

		// ---------- 预设色板（贴底） ----------
		// 原图 16×4，放大整数倍显示；取色时再除回去
		paletteScale = Std.int(FlxMath.bound(Math.floor(innerW / PALETTE_COLS), 10, 18));
		var palW:Float = PALETTE_COLS * paletteScale;
		var palH:Float = PALETTE_ROWS * paletteScale;
		var palY:Float = py + panelH - PAD - palH;

		palette = new FlxSprite(0, 0);
		// allowGPU = false：开着「GPU Caching」时 Paths 会把 CPU 像素 dispose 掉
		// （image = null 却仍标记 readable），后面 getPixel32 就会空引用崩溃
		palette.loadGraphic(Paths.image('noteColorMenu/palette', null, false));
		palette.scale.set(paletteScale, paletteScale);
		palette.updateHitbox();
		palette.antialiasing = false;
		add(palette);
		palette.setPosition(px + (panelW - palW) / 2, palY);

		collectPaletteColors();

		// ---------- 亮度条 + 色相环：吃掉色板上方的剩余空间 ----------
		var areaTop:Float = rgbY + RGB_H + 8;
		var areaH:Float = palY - 12 - areaTop;
		wheelSize = FlxMath.bound(Math.min(areaH, innerW - BAR_W - BAR_GAP), WHEEL_MIN, WHEEL_MAX);

		var blockW:Float = wheelSize + BAR_W + BAR_GAP;
		var blockX:Float = px + PAD + (innerW - blockW) / 2;
		var blockY:Float = areaTop + (areaH - wheelSize) / 2;

		bar = FlxGradient.createGradientFlxSprite(Std.int(BAR_W), Std.int(wheelSize), [FlxColor.WHITE, FlxColor.BLACK]);
		add(bar);
		bar.setPosition(blockX, blockY);

		barSel = new FlxSprite(0, 0).makeGraphic(Std.int(BAR_W) + 10, Std.int(BAR_SEL_H), FlxColor.WHITE);
		barSel.offset.y = BAR_SEL_H / 2;    // 让 y 表示"选中那条线的中心"
		add(barSel);
		barSel.setPosition(blockX - 5, blockY);

		wheel = new FlxSprite(0, 0);
		wheel.loadGraphic(Paths.image('noteColorMenu/colorWheel'));
		wheel.setGraphicSize(Std.int(wheelSize));
		wheel.updateHitbox();
		add(wheel);
		wheel.setPosition(blockX + BAR_W + BAR_GAP, blockY);

		wheelSel = new FlxShapeCircle(0, 0, 7, {thickness: 0}, FlxColor.WHITE);
		wheelSel.offset.set(7, 7);
		wheelSel.alpha = 0.85;
		add(wheelSel);
	}

	/**
	 * 把预设色板的 64 个颜色读进数组，点击时只查表。
	 *
	 * 不能每次点击现读：`BitmapData.getPixel32` 只判 `readable`，而 `Paths.image` 在
	 * 「GPU Caching」开着时会 `disposeImage()` + `image = null`，却仍把 readable 标回 true，
	 * 于是解引用空的 image 直接崩。这里读不到就自己从文件再读一份兜底。
	 */
	function collectPaletteColors():Void
	{
		paletteColors = [];

		var bmp:BitmapData = (palette != null) ? palette.pixels : null;
		var owned:Bool = false;

		if (bmp == null || bmp.image == null)
		{
			#if sys
			var path:String = null;
			try path = Paths.getPath('images/noteColorMenu/palette.png', openfl.utils.AssetType.IMAGE)
			catch (e:Dynamic) {}

			if (path != null)
			{
				try bmp = BitmapData.fromFile(path)
				catch (e:Dynamic) {}

				owned = (bmp != null);
			}
			#end
		}

		if (bmp == null || bmp.image == null) return;

		for (y in 0...PALETTE_ROWS)
			for (x in 0...PALETTE_COLS)
				paletteColors.push(bmp.getPixel32(x, y));

		// 自己读的那份用完就释放；共享 graphic 的那份绝不能动
		if (owned) bmp.dispose();
	}

	function makeArrow(s:String):FlxText
	{
		var t:FlxText = new FlxText(0, 0, ARROW_W, s, 20);
		t.setFormat(Paths.font('vcr.ttf'), 20, UITheme.textSecondary, CENTER);
		t.borderStyle = NONE;
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.alpha = 0.55;
		return t;
	}

	// =========================================================
	// 交互
	// =========================================================
	override function update(elapsed:Float):Void
	{
		// 隐藏时别吃输入，正在拖的话顺手收尾（不落盘）
		if (!visible || !active)
		{
			if (dragMode != DRAG_NONE) endDrag(false);
			return;
		}

		super.update(elapsed);

		var mx:Float = OptionInput.mouseX();
		var my:Float = OptionInput.mouseY();
		var inside:Bool = inPanel(mx, my);

		var hovL:Bool = inside && hitRect(arrowL.x, arrowL.y, ARROW_W, arrowL.height, mx, my);
		var hovR:Bool = inside && hitRect(arrowR.x, arrowR.y, ARROW_W, arrowR.height, mx, my);
		arrowL.alpha = hovL ? 1 : 0.55;
		arrowR.alpha = hovR ? 1 : 0.55;

		if (inside && dragMode == DRAG_NONE && FlxG.mouse.justPressed)
		{
			var chipHit:Int = -1;
			for (i in 0...chips.length)
			{
				if (hitRect(chips[i].x, chips[i].y, CHIP_W, CHIP_H, mx, my))
				{
					chipHit = i;
					break;
				}
			}

			if (hovL)
				changeTarget(-1);
			else if (hovR)
				changeTarget(1);
			else if (hitRect(px + PAD + ARROW_W, py + PAD, panelW - (PAD + ARROW_W) * 2, SWITCH_H, mx, my))
				changeTarget(1);          // 点中间文字 = 切下一个
			else if (chipHit >= 0)
				setTarget(chipHit);
			else if (hitRect(wheel.x, wheel.y, wheelSize, wheelSize, mx, my))
				startDrag(DRAG_WHEEL, mx, my);
			else if (hitRect(bar.x, bar.y, BAR_W, wheelSize, mx, my))
				startDrag(DRAG_BAR, mx, my);
			else if (hitRect(palette.x, palette.y, PALETTE_COLS * paletteScale, PALETTE_ROWS * paletteScale, mx, my))
				pickPalette(mx, my);
		}

		if (dragMode != DRAG_NONE)
		{
			if (FlxG.mouse.pressed) updateDrag(mx, my);
			if (FlxG.mouse.justReleased) endDrag(true);
		}
	}

	inline function inPanel(mx:Float, my:Float):Bool
		return mx >= px && mx <= px + panelW && my >= py && my <= py + panelH;

	inline function hitRect(rx:Float, ry:Float, rw:Float, rh:Float, mx:Float, my:Float):Bool
		return mx >= rx && mx <= rx + rw && my >= ry && my <= ry + rh;

	function startDrag(mode:Int, mx:Float, my:Float):Void
	{
		var c:FlxColor = getTargetColor(target);
		storedHue = c.hue;
		storedSat = c.saturation;
		storedVal = c.brightness;

		// 纯黑（亮度 0）时拖色环永远是黑的，用户会以为色环坏了 —— 按满亮度起算。
		// 只兜色环这一路：亮度条本来就是按指针位置取值，不受影响。
		if (mode == DRAG_WHEEL && storedVal <= 0.02) storedVal = 1.0;

		dragMode = mode;
		OptionInput.capturePointer(this);   // 独占指针，别让列表跟着一起滚
		updateDrag(mx, my);                 // 点哪跳哪
	}

	function updateDrag(mx:Float, my:Float):Void
	{
		var c:FlxColor;

		if (dragMode == DRAG_WHEEL)
		{
			var cx:Float = wheel.x + wheelSize / 2;
			var cy:Float = wheel.y + wheelSize / 2;
			var dx:Float = mx - cx;
			var dy:Float = my - cy;

			// 角度 0 在正上方、顺时针增长。
			// ⚠️ 方向：原版用的是 mouse.degreesTo(center)，即"从鼠标指向圆心"；
			// 写成 atan2(my-cy, mx-cx)（圆心指向鼠标）会整体反 180°，点正上方会选到青色。
			var deg:Float = Math.atan2(cy - my, cx - mx) * 180 / Math.PI;
			var hue:Float = FlxMath.wrap(FlxMath.wrap(Std.int(deg), 0, 360) - 90, 0, 360);
			var sat:Float = FlxMath.bound(Math.sqrt(dx * dx + dy * dy) / (wheelSize / 2), 0, 1);

			if (sat > 0.001)
				c = FlxColor.fromHSB(hue, sat, storedVal);
			else
				c = FlxColor.fromRGBFloat(storedVal, storedVal, storedVal);

			storedHue = hue;
			storedSat = sat;
		}
		else
		{
			// 亮度条上白下黑，所以取反
			var v:Float = 1 - FlxMath.bound((my - bar.y) / wheelSize, 0, 1);
			c = FlxColor.fromHSB(storedHue, storedSat, v);
			storedVal = v;
		}

		applyColor(c, false);
	}

	function endDrag(commit:Bool):Void
	{
		dragMode = DRAG_NONE;
		OptionInput.releasePointer(this);

		if (commit)
		{
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		}
	}

	function pickPalette(mx:Float, my:Float):Void
	{
		if (paletteColors.length == 0) return;   // 像素读不到就静默跳过，绝不崩

		// 色板是 16×4 原图放大来的，采样要除 scale；贴边点会越界，必须夹紧
		var col:Int = Std.int(FlxMath.bound((mx - palette.x) / paletteScale, 0, PALETTE_COLS - 1));
		var row:Int = Std.int(FlxMath.bound((my - palette.y) / paletteScale, 0, PALETTE_ROWS - 1));
		var idx:Int = row * PALETTE_COLS + col;
		if (idx < 0 || idx >= paletteColors.length) return;

		var raw:FlxColor = FlxColor.fromInt(paletteColors[idx]);
		applyColor(FlxColor.fromRGB(raw.red, raw.green, raw.blue), true);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	// =========================================================
	// 取值 / 写值
	// =========================================================
	function getTargetColor(i:Int):FlxColor
	{
		return switch (i)
		{
			case T_EDGE: ClientPrefs.data.keyboardEdgeColor;
			case T_RAIN: ClientPrefs.data.keyboardRainColor;
			case T_FONT: ClientPrefs.data.keyboardTextColor;
			default: ClientPrefs.data.keyboardBGColor;
		}
	}

	function setTargetColor(i:Int, c:FlxColor):Void
	{
		switch (i)
		{
			case T_EDGE: ClientPrefs.data.keyboardEdgeColor = c;
			case T_RAIN: ClientPrefs.data.keyboardRainColor = c;
			case T_FONT: ClientPrefs.data.keyboardTextColor = c;
			default: ClientPrefs.data.keyboardBGColor = c;
		}
	}

	function applyColor(c:FlxColor, commit:Bool):Void
	{
		setTargetColor(target, c);
		refreshValueUI();
		KeyboardViewer.refreshAll();        // 游戏内键盘 + 设置页预览一起刷
		if (commit) ClientPrefs.saveSettings();
	}

	// =========================================================
	// 刷新显示
	// =========================================================
	public function refreshValueUI():Void
	{
		var c:FlxColor = getTargetColor(target);

		hexText.text = c.toHexString(false, false);   // 6 位、无 #，与原版一致
		hexText.color = c;
		// 选到纯黑时黑字看不见，按亮度切描边色
		hexText.borderColor = (c.luminance > 0.5) ? FlxColor.BLACK : FlxColor.WHITE;
		rgbText.text = 'R ${c.red}   G ${c.green}   B ${c.blue}';

		// 色相环整体按亮度压暗，暗色时看起来也是暗的（原版做法）
		wheel.color = FlxColor.fromHSB(0, 0, c.brightness);

		var cx:Float = wheel.x + wheelSize / 2;
		var cy:Float = wheel.y + wheelSize / 2;
		wheelSel.setPosition(cx, cy);
		if (c.brightness > 0)
		{
			var rad:Float = c.hue * Math.PI / 180;
			wheelSel.x += Math.sin(rad) * (wheelSize / 2) * c.saturation;
			wheelSel.y -= Math.cos(rad) * (wheelSize / 2) * c.saturation;
		}

		barSel.y = bar.y + wheelSize * (1 - c.brightness);

		for (i in 0...chips.length)
		{
			chips[i].color = getTargetColor(i);
			chipFrames[i].alpha = (i == target) ? 1 : 0;
		}
	}

	public function refreshLabels():Void
	{
		label.text = Language.getPhrase(TARGET_KEYS[target], TARGET_EN[target]);
		// 文字高度随语言/字号变，重新垂直居中（否则中文会偏上）
		label.y = py + PAD + (SWITCH_H - label.height) / 2;
	}

	/** 外部改动（切子页 / 语言热重载 / 主题切换）后回读 */
	public function syncFromPrefs():Void
	{
		refreshLabels();
		refreshValueUI();
	}

	public function setTarget(i:Int):Void
	{
		target = FlxMath.wrap(i, 0, TARGET_KEYS.length - 1);
		refreshLabels();
		refreshValueUI();
	}

	function changeTarget(delta:Int):Void
	{
		setTarget(target + delta);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
	}

	public function refreshTheme():Void
	{
		if (bg != null) bg.color = UITheme.popup;
		if (label != null) label.color = UITheme.textPrimary;
		if (arrowL != null) arrowL.color = UITheme.textSecondary;
		if (arrowR != null) arrowR.color = UITheme.textSecondary;
		if (rgbText != null) rgbText.color = UITheme.textSecondary;

		for (f in chipFrames)
			if (f != null) f.color = UITheme.accent;
		for (b in chipBacks)
			if (b != null) b.color = UITheme.divider;

		refreshValueUI();
	}

	/** 指针是否压在面板上 —— 宿主用它拦列表滚动 / 行悬停 / 右键返回 */
	public function blocksPointer(mx:Float, my:Float):Bool
		return visible && inPanel(mx, my);

	override public function draw():Void
	{
		if (!visible) return;
		super.draw();
	}

	override public function destroy():Void
	{
		OptionInput.releasePointer(this);
		super.destroy();
	}
}
