package states.editors.content;

import flixel.util.FlxSave;
import flixel.util.FlxStringUtil;

import options.Option;
import options.Option.OptionType;
import options.Win8CharmSettings;
import options.Win8CharmSettings.CharmEntry;
import options.Win8CharmSettings.CharmOption;
import options.Win8CharmSettings.CharmActionOption;
import options.objects.win8.CharmIcons;

/**
 * ChartMinimap —— 谱面缩略图 / 密度条（谱面编辑器用的通用组件）。
 *
 * 类似 osu! 的进度条：沿轴把整首歌按 section 摊开，每个 section 一个色块，
 * 颜色按 note 密度（NPS）分挡；点击 / 按住拖拽跳转对应时间点；
 * 悬浮显示该节的 BPM / note 数 / NPS / 时间点；条一端的齿轮打开 Win8 设置浮出层。
 *
 * 宿主只需提供数据与跳转的闭包：
 *   buildSections()  —— 返回每个 section 的 {time, endTime, bpm, noteCount}
 *   getPosition()    —— 当前播放位置（毫秒）
 *   onSeek(ms)       —— 跳转到指定毫秒
 *   openSettings()   —— 齿轮被点击时调用（一般 openSubState(new ChartMinimapPanel(this))）
 *
 * 数据每 0.4 秒自动轮询一次 buildSections()，谱面改动无需手动通知。
 * 组件自身画在屏幕坐标系（scrollFactor = 0），宿主把它挂到不滚动的相机上（编辑器用 camUI）。
 * mouseOver 标志每帧更新，宿主在网格鼠标逻辑里据此屏蔽点击穿透。
 */
typedef ChartMinimapSection =
{
	var time:Float;      // 节起点（毫秒）
	var endTime:Float;   // 节终点（毫秒）
	var bpm:Float;
	var noteCount:Int;
}

class ChartMinimap extends FlxSpriteGroup
{
	// =========================================================
	// 宿主接口
	// =========================================================
	/** 提供每个 section 的数据（每 0.4s 轮询一次） */
	public var buildSections:Void->Array<ChartMinimapSection>;
	/** 当前播放位置（毫秒）—— 名字避开 FlxObject.getPosition */
	public var getPlayheadPos:Void->Float;
	/** 跳转到指定毫秒 */
	public var onSeek:Float->Void;
	/** 齿轮被点击（宿主一般 openSubState(new ChartMinimapPanel(this))） */
	public var openSettings:Void->Void;
	/**
	 * 宿主的编辑器存档（编辑器的 chart_editor_data）。
	 * 缩略图的设置跟编辑器其它设置存一起，不另开一个 FlxSave；为 null 时退回 FlxG.save.data。
	 */
	public var chartSave:FlxSave;

	// =========================================================
	// 运行状态
	// =========================================================
	/** 最近一次轮询拿到的节数据 */
	public var sections:Array<ChartMinimapSection> = [];
	/** 鼠标当前是否悬停在本组件上（条 / 齿轮），宿主用来屏蔽网格点击 */
	public var mouseOver:Bool = false;
	/** 鼠标是否在条本体上（不含手柄抓取区）—— 宿主用它让滚轮给缩放让路 */
	public var barHovered:Bool = false;

	/** 轨道层：底板 / 密度色块（永远在最下面） */
	var trackLayer:FlxSpriteGroup;
	/** 分隔层：section 之间的 1px 分割线（压在色块上、播放头下） */
	var dividerLayer:FlxSpriteGroup;
	/** 前景层：手柄 / 播放头 / 齿轮 / 信息框（永远在上面，图层序不依赖增删顺序） */
	var frontLayer:FlxSpriteGroup;

	var bgSprite:FlxSprite;
	/** 白色拖拽手柄：贴在条朝屏幕中心一侧的边内侧，按住可整体挪位置 */
	var handle:FlxSprite;
	var cells:Array<FlxSprite> = [];
	/** section 边界的分割线池（数量 = section 数 - 1） */
	var dividers:Array<FlxSprite> = [];
	var playhead:FlxSprite;
	var gear:FlxSprite;
	var tooltip:FlxText;

	var refreshTimer:Float = 0;
	var scrubbing:Bool = false;
	var draggingPos:Bool = false;

	// 时间轴窗口（瞬态，不入存档）
	/** 窗口起点（绝对毫秒） */
	var viewStart:Float = 0;
	/** 窗口长度 = 全曲 / zoom */
	var viewSpan:Float = 0;
	/** 首次拿到数据时把窗口对准播放头 */
	var viewInitialized:Bool = false;
	/** 需要重画（窗口移动 / 缩放 / 数据变化） */
	var needRender:Bool = false;
	/** 滚轮缩放后的延迟落盘计时 */
	var zoomSaveTimer:Float = 0;
	/** 鼠标在"本组件相机视图空间"里的坐标缓存 */
	var mousePos:FlxPoint = FlxPoint.get();
	var lastMouse:FlxPoint = FlxPoint.get();
	/** 齿轮相对条左上角的偏移（拖拽时保持跟随） */
	var gearOffX:Float = 0;
	var gearOffY:Float = 0;

	// 布局缓存（applyLayout 时算好，update 里直接用）
	var barX:Float = 0;
	var barY:Float = 0;
	var barW:Float = 0;
	var barH:Float = 0;
	var gearX:Float = 0;
	var gearY:Float = 0;
	var gearSize:Int = 18;

	static inline var REFRESH_INTERVAL:Float = 0.4;
	static inline var GEAR_GAP:Float = 5;
	/** 拖拽手柄命中区：条外 / 条内各放宽多少像素（手柄本体只有几像素宽，纯靠视觉位置抓不住） */
	static inline var HANDLE_GRAB_OUT:Float = 10;
	static inline var HANDLE_GRAB_IN:Float = 16;
	/** 本节像素跨度不足这个值就不画分割线（节太密时画了反而糊成一片） */
	static inline var DIVIDER_MIN_SECTION_PX:Float = 3;
	/** 时间轴缩放：范围与每档倍率 */
	static inline var ZOOM_MIN:Float = 1;
	static inline var ZOOM_MAX:Float = 16;
	static inline var ZOOM_STEP:Float = 1.25;
	/** 滚轮缩放后多久落盘（避免每格滚轮都写文件） */
	static inline var ZOOM_SAVE_DELAY:Float = 0.8;
	/** 播放头跟随时窗口内保留的安全区比例 */
	static inline var FOLLOW_LO:Float = 0.15;
	static inline var FOLLOW_HI:Float = 0.85;

	// NPS 密度分挡配色：5 个阈值切 6 档（阈值在 ChartMinimapSettings 里可调）
	static inline var COLOR_EMPTY:FlxColor = 0xFF33363B;
	/** section 之间的 1px 分割线 */
	static inline var DIVIDER_COLOR:FlxColor = 0xCC0E1013;
	public static var TIER_COLORS:Array<FlxColor> = [
		0xFF3ADB5A, // < tier1：绿
		0xFF9BD83E, // tier1 ~ tier2：黄绿
		0xFFE8C63E, // tier2 ~ tier3：黄
		0xFFE8823E, // tier3 ~ tier4：橙
		0xFFE85A3E, // tier4 ~ tier5：橙红
		0xFFE83E4E  // > tier5：红
	];

	var settingsLoaded:Bool = false;

	public function new(?save:FlxSave)
	{
		super();
		chartSave = save;

		if (!settingsLoaded)
		{
			settingsLoaded = true;
			ChartMinimapSettings.load(chartSave);
		}

		bgSprite = new FlxSprite();
		bgSprite.makeGraphic(1, 1, FlxColor.BLACK);
		bgSprite.alpha = 0.45;

		handle = new FlxSprite();
		handle.makeGraphic(1, 1, FlxColor.WHITE);
		handle.alpha = 0.7;

		playhead = new FlxSprite();
		playhead.makeGraphic(1, 1, FlxColor.WHITE);
		playhead.color = 0xFF66D9FF;

		gear = new FlxSprite();
		gear.pixels = CharmIcons.draw('settings', gearSize, FlxColor.WHITE);
		gear.color = 0xFFCCCCCC;

		tooltip = new FlxText(0, 0, 240, '', 14);
		tooltip.setFormat(null, 14, FlxColor.WHITE, LEFT, FlxColor.BLACK);
		tooltip.borderSize = 1.5;
		tooltip.visible = false;

		// 三层结构：底板+色块 < 分割线 < 前景（手柄/播放头/齿轮/信息框）。
		// 播放头放前景层 —— 它是"现在播到哪"的唯一指示，任何情况下都不能被密度色块或拖拽手柄压住。
		trackLayer = new FlxSpriteGroup();
		dividerLayer = new FlxSpriteGroup();
		frontLayer = new FlxSpriteGroup();
		trackLayer.add(bgSprite);
		frontLayer.add(handle);
		frontLayer.add(playhead);
		frontLayer.add(gear);
		frontLayer.add(tooltip);
		add(trackLayer);
		add(dividerLayer);
		add(frontLayer);

		scrollFactor.set(0, 0);
		for (spr in members) if (spr != null) spr.scrollFactor.set(0, 0);

		applyLayout();
	}

	// =========================================================
	// 布局
	// =========================================================
	/** 按当前设置重摆整条（设置变化 / 初始化时调用） */
	public function applyLayout():Void
	{
		var s = ChartMinimapSettings;
		var margin:Float = Math.max(8, s.margin);

		if (s.vertical)
		{
			// 竖条：厚度沿 X，长度沿 Y
			barH = (s.length > 0) ? Math.min(s.length, FlxG.height - margin * 2) : FlxG.height - margin * 2;
			barW = Math.min(s.thickness, FlxG.width * 0.2);
		}
		else
		{
			// 横条：长度沿 X，厚度沿 Y
			barW = (s.length > 0) ? Math.min(s.length, FlxG.width - margin * 2) : FlxG.width - margin * 2;
			barH = Math.min(s.thickness, FlxG.height * 0.2);
		}

		// 拖拽手柄记录过的位置优先（拖拽时实时写回 posX/posY）；否则按方向贴边，两端各留 margin 安全区
		if (s.posX >= 0 && s.posY >= 0)
		{
			barX = FlxMath.bound(s.posX, 0, FlxG.width - barW);
			barY = FlxMath.bound(s.posY, 0, FlxG.height - barH);
		}
		else if (s.vertical)
		{
			barX = FlxG.width - margin - barW;
			barY = margin;
		}
		else
		{
			barX = margin;
			barY = FlxG.height - margin - barH;
		}
		s.posX = barX;
		s.posY = barY;

		// 齿轮挂在条的一端（竖条在上方、横条在左侧），偏移量记下来供拖拽时跟随
		gearOffX = s.vertical ? (barW - gearSize) / 2 : -gearSize - GEAR_GAP;
		gearOffY = s.vertical ? -gearSize - GEAR_GAP : (barH - gearSize) / 2;
		gearX = Math.max(2, barX + gearOffX);
		gearY = Math.max(2, barY + gearOffY);

		positionChrome();
		rebuildCells();
	}

	/** 摆放底板 / 手柄 / 齿轮（拖拽位置时每帧调用，色块由 rebuildCells 一起挪） */
	function positionChrome():Void
	{
		var s = ChartMinimapSettings;
		bgSprite.setPosition(barX, barY);
		bgSprite.scale.set(barW, barH);
		bgSprite.updateHitbox();

		// 白色手柄：竖条贴左缘内侧、横条贴上缘内侧，即朝屏幕中心那一边
		if (s.vertical)
		{
			handle.setPosition(barX, barY);
			handle.scale.set(4, barH);
		}
		else
		{
			handle.setPosition(barX, barY);
			handle.scale.set(barW, 4);
		}
		handle.updateHitbox();

		gear.setPosition(gearX, gearY);
	}

	// =========================================================
	// 数据刷新
	// =========================================================
	/** 立即重拉节数据并重画色块（宿主也可以主动调） */
	public function refreshData():Void
	{
		if (buildSections != null)
			sections = buildSections();
		else
			sections = [];
		if (sections == null) sections = [];
		rebuildCells();
	}

	function rebuildCells():Void
	{
		syncPools();

		if (getTotalLength() <= 0)
		{
			for (cell in cells) if (cell.visible) cell.visible = false;
			for (div in dividers) if (div.visible) div.visible = false;
			return;
		}

		clampViewStart();
		renderCells();
	}

	/** 色块 / 分割线池：够用就复用，不够补，多了删 */
	function syncPools():Void
	{
		while (cells.length < sections.length)
		{
			var cell:FlxSprite = new FlxSprite();
			cell.makeGraphic(1, 1, FlxColor.WHITE);
			cell.scrollFactor.set(0, 0);
			cells.push(cell);
			trackLayer.add(cell);
		}
		while (cells.length > sections.length)
		{
			var cell:FlxSprite = cells.pop();
			if (cell != null) { trackLayer.remove(cell); cell.destroy(); }
		}

		// 分割线：section 数 - 1 条（第一条前面就是条的起边，不用画）
		var dividerCount:Int = (sections.length > 1) ? sections.length - 1 : 0;
		while (dividers.length < dividerCount)
		{
			var div:FlxSprite = new FlxSprite();
			div.makeGraphic(1, 1, DIVIDER_COLOR);
			div.scrollFactor.set(0, 0);
			dividers.push(div);
			dividerLayer.add(div);
		}
		while (dividers.length > dividerCount)
		{
			var div:FlxSprite = dividers.pop();
			if (div != null) { dividerLayer.remove(div); div.destroy(); }
		}
	}

	/**
	 * 只重画、不动池。窗口外的节直接隐藏；可见节很少时这一步很便宜。
	 */
	function renderCells():Void
	{
		var vertical:Bool = ChartMinimapSettings.vertical;
		var len:Float = vertical ? barH : barW;

		if (len <= 2 || viewSpan <= 0)
		{
			for (cell in cells) if (cell.visible) cell.visible = false;
			for (div in dividers) if (div.visible) div.visible = false;
			return;
		}

		// 先全隐藏分割线：窗口滚动后旧线不会留在外面
		for (div in dividers) if (div.visible) div.visible = false;
		var lastDividerPx:Float = -1;

		for (i in 0...sections.length)
		{
			var sec = sections[i];
			var cell = cells[i];

			var rawStart:Float = (sec.time - viewStart) / viewSpan * len;
			var rawEnd:Float = (sec.endTime - viewStart) / viewSpan * len;
			if (rawEnd <= 0 || rawStart >= len)
			{
				if (cell.visible) cell.visible = false;
				continue;
			}

			var startT = Math.floor(FlxMath.bound(rawStart, 0, len));
			var endT = Math.ceil(FlxMath.bound(rawEnd, 0, len));
			// 钳在条内，否则最后几节会画到条外面
			var startPx = Math.min(startT, Math.max(0, len - 2));
			var span = Math.min(Math.max(2, endT - startT), len - startPx);

			cell.visible = true;
			if (vertical)
			{
				cell.setPosition(barX, barY + startPx);
				cell.scale.set(barW, span);
			}
			else
			{
				cell.setPosition(barX + startPx, barY);
				cell.scale.set(span, barH);
			}
			cell.updateHitbox();
			cell.color = tierColor(sec.noteCount, sec.endTime - sec.time);

			// 分割线压在本节起点上；节太密（不足 3px）就不画，否则整条糊成一片
			var px:Float = (sec.endTime - sec.time) / viewSpan * len;
			if (i > 0 && px >= DIVIDER_MIN_SECTION_PX && startPx >= 1 && startPx <= len - 1 && startPx != lastDividerPx)
			{
				var div = dividers[i - 1];
				if (div != null)
				{
					div.visible = true;
					if (vertical)
					{
						div.setPosition(barX, barY + startPx);
						div.scale.set(barW, 1);
					}
					else
					{
						div.setPosition(barX + startPx, barY);
						div.scale.set(1, barH);
					}
					div.updateHitbox();
					lastDividerPx = startPx;
				}
			}
		}
	}

	function getTotalLength():Float
	{
		if (sections.length == 0) return 0;
		return Math.max(0, sections[sections.length - 1].endTime - sections[0].time);
	}

	/** 把窗口起点钳进 [t0, t0 + total - viewSpan]，顺便刷新 viewSpan */
	function clampViewStart():Void
	{
		var total:Float = getTotalLength();
		var t0:Float = (sections.length > 0) ? sections[0].time : 0;
		viewSpan = total / FlxMath.bound(ChartMinimapSettings.zoom, ZOOM_MIN, ZOOM_MAX);
		if (total <= 0) { viewStart = t0; return; }
		viewStart = FlxMath.bound(viewStart, t0, t0 + total - viewSpan);
	}

	/** 播放头跟随：只把它往 15%~85% 的安全区里推，不居中（居中每次越界会跳掉三分之一窗口） */
	function updateViewFollow():Void
	{
		if (sections.length == 0 || getPlayheadPos == null) return;
		var total:Float = getTotalLength();
		if (total <= 0) return;

		var zoom:Float = FlxMath.bound(ChartMinimapSettings.zoom, ZOOM_MIN, ZOOM_MAX);
		var span:Float = total / zoom;
		viewSpan = span;

		// 首次拿到数据：窗口对准播放头，别让用户一进来就停在 0:00
		if (!viewInitialized)
		{
			viewInitialized = true;
			viewStart = getPlayheadPos() - span * 0.5;
			clampViewStart();
			needRender = true;
			return;
		}

		if (zoom <= 1.0001)
		{
			var t0:Float = sections[0].time;
			if (Math.abs(viewStart - t0) > 0.01) { viewStart = t0; needRender = true; }
			return;
		}
		// scrub / 拖位置 / 刚滚过滚轮时别抢用户的操作
		if (scrubbing || draggingPos || zoomSaveTimer > 0) return;
		if (!ChartMinimapSettings.followPlayhead) return;

		var pos:Float = getPlayheadPos();
		var old:Float = viewStart;
		if (pos < viewStart) viewStart = pos - FOLLOW_LO * span;
		else if (pos > viewStart + FOLLOW_HI * span) viewStart = pos - FOLLOW_HI * span;
		clampViewStart();
		if (Math.abs(viewStart - old) > 0.01) needRender = true;
	}

	/** 设置缩放；anchorRatio = 缩放锚点在条上的比例（0 = 起点，1 = 终点） */
	public function setZoom(z:Float, ?anchorRatio:Float = 0.5):Void
	{
		var total:Float = getTotalLength();
		var newZoom:Float = FlxMath.bound(z, ZOOM_MIN, ZOOM_MAX);
		if (total <= 0)
		{
			ChartMinimapSettings.zoom = newZoom;
			return;
		}

		// 锚点按"当前实际窗口"算 —— 面板刚改过 Settings.zoom 时它和 viewSpan 还不同步
		var oldSpan:Float = (viewSpan > 0) ? viewSpan : total / FlxMath.bound(ChartMinimapSettings.zoom, ZOOM_MIN, ZOOM_MAX);
		var r:Float = FlxMath.bound(anchorRatio, 0, 1);
		var anchorT:Float = viewStart + r * oldSpan;

		ChartMinimapSettings.zoom = newZoom;
		viewSpan = total / newZoom;
		viewStart = anchorT - r * viewSpan;

		clampViewStart();
		needRender = true;
		renderCells();
	}

	public function zoomBy(factor:Float, ?anchorRatio:Float):Void
		setZoom(ChartMinimapSettings.zoom * factor, anchorRatio);

	/** 面板改了 zoom 数值：以播放头当前在窗口里的位置为锚（不在窗口内就居中） */
	public function applyZoomFromSetting():Void
	{
		var r:Float = 0.5;
		if (getPlayheadPos != null && viewSpan > 0)
			r = FlxMath.bound((getPlayheadPos() - viewStart) / viewSpan, 0, 1);
		setZoom(ChartMinimapSettings.zoom, r);
	}

	/** 回到全曲视图（面板的 Reset View） */
	public function resetView():Void
	{
		ChartMinimapSettings.zoom = ZOOM_MIN;
		ChartMinimapSettings.followPlayhead = true;
		viewStart = (sections.length > 0) ? sections[0].time : 0;
		viewSpan = getTotalLength();
		viewInitialized = true;
		clampViewStart();
		needRender = true;
		ChartMinimapSettings.save(chartSave);
		renderCells();
	}

	/** NPS → 挡位颜色（5 个阈值切 6 档） */
	function tierColor(noteCount:Int, durationMs:Float):FlxColor
	{
		if (noteCount <= 0) return COLOR_EMPTY;
		if (!ChartMinimapSettings.densityColors) return TIER_COLORS[0];

		var nps:Float = noteCount / Math.max(0.001, durationMs / 1000);
		var s = ChartMinimapSettings;
		var idx:Int = 0;
		if (nps >= s.tier1) idx++;
		if (nps >= s.tier2) idx++;
		if (nps >= s.tier3) idx++;
		if (nps >= s.tier4) idx++;
		if (nps >= s.tier5) idx++;
		return TIER_COLORS[idx];
	}

	// =========================================================
	// 交互与每帧更新
	// =========================================================
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		refreshTimer += elapsed;
		if (refreshTimer >= REFRESH_INTERVAL)
		{
			refreshTimer = 0;
			refreshData();
		}

		// 滚轮缩放后延迟落盘，避免每格滚轮都写一次文件
		if (zoomSaveTimer > 0)
		{
			zoomSaveTimer -= elapsed;
			if (zoomSaveTimer <= 0) ChartMinimapSettings.save(chartSave);
		}

		// 窗口跟随播放头（可能改 viewStart）；变了只重画，不重建池
		updateViewFollow();
		if (needRender)
		{
			needRender = false;
			renderCells();
		}

		// 输入框打字时不响应（与两个编辑器的 blockInput 约定一致）
		if (PsychUIInputText.focusOn != null)
		{
			mouseOver = false;
			barHovered = false;
			tooltip.visible = false;
			return;
		}

		// 命中判定不能用 FlxG.mouse.screenX/Y —— 那是相对"主相机"scroll 的坐标（PE 编辑器主相机会
		// 随网格滚动，一滚就全偏）。必须换算到本组件实际绘制的那台相机的视图空间，条在这里才是
		// 纯屏幕坐标（scrollFactor = 0）。
		var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
		FlxG.mouse.getViewPosition(cam, mousePos);
		var mx:Float = mousePos.x;
		var my:Float = mousePos.y;

		var overGear:Bool = mx >= gearX && mx <= gearX + gearSize && my >= gearY && my <= gearY + gearSize;
		var overBar:Bool = mx >= barX && mx <= barX + barW && my >= barY && my <= barY + barH;
		// 手柄命中区：朝条内、朝条外都放宽，贴着屏幕边缘时从条外面也抓得住
		var overHandle:Bool = ChartMinimapSettings.vertical
			? (mx >= barX - HANDLE_GRAB_OUT && mx <= barX + HANDLE_GRAB_IN && my >= barY && my <= barY + barH)
			: (my >= barY - HANDLE_GRAB_OUT && my <= barY + HANDLE_GRAB_IN && mx >= barX && mx <= barX + barW);
		mouseOver = overGear || overBar || overHandle;
		barHovered = overBar;

		handle.alpha = (overHandle || draggingPos) ? 1 : 0.7;

		// 条上滚轮 = 时间轴缩放（宿主那边的滚轮分支靠 barHovered 让路）
		if (barHovered && !draggingPos && FlxG.mouse.wheel != 0)
		{
			var r:Float = ChartMinimapSettings.vertical ? (my - barY) / barH : (mx - barX) / barW;
			var dir:Int = FlxG.mouse.wheel > 0 ? 1 : -1;
			zoomBy(dir > 0 ? ZOOM_STEP : 1 / ZOOM_STEP, r);
			zoomSaveTimer = ZOOM_SAVE_DELAY;
		}

		// 白色手柄：按住拖动整条位置，松手落盘
		if (overHandle && FlxG.mouse.justPressed)
		{
			draggingPos = true;
			lastMouse.x = mx;
			lastMouse.y = my;
		}
		if (draggingPos)
		{
			if (FlxG.mouse.pressed)
			{
				// 每帧取鼠标增量位移条，才能 1:1 跟手（lastMouse 不更新的话，
				// 条会按"按下点→当前点"的固定差值一路滑到钳制边界）
				barX = FlxMath.bound(barX + (mx - lastMouse.x), 0, FlxG.width - barW);
				barY = FlxMath.bound(barY + (my - lastMouse.y), 0, FlxG.height - barH);
				lastMouse.x = mx;
				lastMouse.y = my;
				ChartMinimapSettings.posX = barX;
				ChartMinimapSettings.posY = barY;
				gearX = Math.max(2, barX + gearOffX);
				gearY = Math.max(2, barY + gearOffY);
				positionChrome();
				renderCells();
			}
			else
			{
				draggingPos = false;
				ChartMinimapSettings.save(chartSave);
			}
			// 拖位置期间不处理 seek / 信息框，但播放头要继续跟
			tooltip.visible = false;
			updatePlayhead();
			return;
		}

		// 齿轮：悬浮变色 + 点击开设置面板
		gear.color = overGear ? FlxColor.WHITE : 0xFFCCCCCC;
		if (overGear && FlxG.mouse.justPressed && openSettings != null)
			openSettings();

		// 条：点击跳转，按住拖拽 scrub（手柄区除外）
		if (overBar && !overHandle && FlxG.mouse.justPressed)
			scrubbing = true;
		if (scrubbing)
		{
			if (FlxG.mouse.pressed)
			{
				if (onSeek != null && sections.length > 0)
					onSeek(timeAtMouse(mx, my));
			}
			else
				scrubbing = false;
		}

		// 悬浮信息框
		if (overBar && !overHandle && sections.length > 0)
			updateTooltip(mx, my);
		else
			tooltip.visible = false;

		updatePlayhead();
	}

	/** 鼠标在条上的位置 → 歌曲时间（毫秒，按当前窗口换算） */
	function timeAtMouse(mx:Float, my:Float):Float
	{
		if (viewSpan <= 0) return 0;
		var r:Float = ChartMinimapSettings.vertical ? (my - barY) / barH : (mx - barX) / barW;
		return viewStart + FlxMath.bound(r, 0, 1) * viewSpan;
	}

	function updateTooltip(mx:Float, my:Float):Void
	{
		var t:Float = timeAtMouse(mx, my);
		var sec = null;
		for (s in sections)
		{
			if (t >= s.time && t < s.endTime) { sec = s; break; }
		}
		if (sec == null)
		{
			tooltip.visible = false;
			return;
		}

		var idx:Int = sections.indexOf(sec) + 1;
		var nps:Float = sec.noteCount / Math.max(0.001, (sec.endTime - sec.time) / 1000);
		tooltip.text = 'Section $idx  |  ' + FlxStringUtil.formatTime(sec.time / 1000, false)
			+ '\nBPM ' + Math.round(sec.bpm * 10) / 10
			+ '  |  ' + sec.noteCount + ' notes  |  ' + Math.round(nps * 10) / 10 + ' nps';
		tooltip.visible = true;

		// 定位三步走：先朝屏幕内侧弹出 → 钳回屏幕（4px 边距）→ 若仍压住条本体，翻到条另一侧再钳一次
		var tw:Float = tooltip.width;
		var th:Float = tooltip.height;
		var tx:Float;
		var ty:Float;
		if (ChartMinimapSettings.vertical)
		{
			tx = mx - tw - 14;
			ty = my + 14;
		}
		else
		{
			tx = mx + 14;
			ty = my - th - 14;
		}
		tx = FlxMath.bound(tx, 4, FlxG.width - tw - 4);
		ty = FlxMath.bound(ty, 4, FlxG.height - th - 4);

		if (tx < barX + barW && tx + tw > barX && ty < barY + barH && ty + th > barY)
		{
			if (ChartMinimapSettings.vertical)
				tx = (mx > FlxG.width / 2) ? barX - tw - 4 : barX + barW + 4;
			else
				ty = (my > FlxG.height / 2) ? barY - th - 4 : barY + barH + 4;
			tx = FlxMath.bound(tx, 4, FlxG.width - tw - 4);
			ty = FlxMath.bound(ty, 4, FlxG.height - th - 4);
		}
		tooltip.setPosition(tx, ty);
	}

	function updatePlayhead():Void
	{
		var total:Float = getTotalLength();
		if (getPlayheadPos == null || total <= 0 || sections.length == 0 || viewSpan <= 0)
		{
			playhead.visible = false;
			return;
		}

		var pos:Float = Math.max(0, getPlayheadPos());
		var r:Float = (pos - viewStart) / viewSpan;
		var inWindow:Bool = r >= 0 && r <= 1;
		r = FlxMath.bound(r, 0, 1);

		playhead.visible = true;
		// 窗口外的播放头贴边显示并压暗，别直接藏掉（否则会以为播放头没了）
		playhead.alpha = inWindow ? 1 : 0.35;
		if (ChartMinimapSettings.vertical)
		{
			playhead.setPosition(barX, barY + r * barH - 1);
			playhead.scale.set(barW + 4, 2);
		}
		else
		{
			playhead.setPosition(barX + r * barW - 1, barY);
			playhead.scale.set(2, barH + 4);
		}
		playhead.updateHitbox();
	}
}

/**
 * ChartMinimap 的设置（持久化到宿主的编辑器存档；没传 save 时退回 FlxG.save.data）。
 */
class ChartMinimapSettings
{
	public static var vertical:Bool = true;        // true = 竖条贴右缘，false = 横条贴底缘
	public static var length:Float = 0;            // 条长（px），0 = 自动铺满可用区
	public static var thickness:Float = 40;        // 条厚（px）
	public static var margin:Float = 50;           // 两端安全区（px）
	public static var densityColors:Bool = true;   // 密度分挡配色开关
	public static var zoom:Float = 1;              // 时间轴缩放：1 = 全曲，16 = 1/16
	public static var followPlayhead:Bool = true;  // 缩放后窗口是否跟随播放头
	public static var tier1:Float = 2;             // NPS 挡位：低于此值 = 绿
	public static var tier2:Float = 4;             // tier1 ~ 此值 = 黄绿
	public static var tier3:Float = 6;             // tier2 ~ 此值 = 黄
	public static var tier4:Float = 8;             // tier3 ~ 此值 = 橙
	public static var tier5:Float = 10;            // tier4 ~ 此值 = 橙红，以上 = 红
	public static var posX:Float = -1;             // 条左上角位置（<0 = 未拖拽过，按方向贴边）
	public static var posY:Float = -1;

	/** 从宿主的编辑器存档读；save 为 null 时退回 FlxG.save.data */
	public static function load(?save:FlxSave):Void
	{
		var d:Dynamic = (save != null) ? save.data : FlxG.save.data;

		if (d.chart_minimap_vertical != null) vertical = d.chart_minimap_vertical == true;
		if (d.chart_minimap_length != null) length = d.chart_minimap_length;
		if (d.chart_minimap_thickness != null) thickness = d.chart_minimap_thickness;
		if (d.chart_minimap_margin != null) margin = d.chart_minimap_margin;
		if (d.chart_minimap_density != null) densityColors = d.chart_minimap_density == true;
		if (d.chart_minimap_zoom != null) zoom = FlxMath.bound(d.chart_minimap_zoom, 1, 16);
		if (d.chart_minimap_follow != null) followPlayhead = d.chart_minimap_follow == true;
		if (d.chart_minimap_t1 != null) tier1 = d.chart_minimap_t1;
		if (d.chart_minimap_t2 != null) tier2 = d.chart_minimap_t2;
		if (d.chart_minimap_t3 != null) tier3 = d.chart_minimap_t3;
		if (d.chart_minimap_t4 != null) tier4 = d.chart_minimap_t4;
		if (d.chart_minimap_t5 != null) tier5 = d.chart_minimap_t5;
		if (d.chart_minimap_posx != null) posX = d.chart_minimap_posx;
		if (d.chart_minimap_posy != null) posY = d.chart_minimap_posy;
	}

	/** 写回宿主的编辑器存档并落盘；save 为 null 时退回 FlxG.save.data */
	public static function save(?save:FlxSave):Void
	{
		var d:Dynamic = (save != null) ? save.data : FlxG.save.data;

		d.chart_minimap_vertical = vertical;
		d.chart_minimap_length = length;
		d.chart_minimap_thickness = thickness;
		d.chart_minimap_margin = margin;
		d.chart_minimap_density = densityColors;
		d.chart_minimap_zoom = zoom;
		d.chart_minimap_follow = followPlayhead;
		d.chart_minimap_t1 = tier1;
		d.chart_minimap_t2 = tier2;
		d.chart_minimap_t3 = tier3;
		d.chart_minimap_t4 = tier4;
		d.chart_minimap_t5 = tier5;
		d.chart_minimap_posx = posX;
		d.chart_minimap_posy = posY;

		if (save != null) save.flush();
		else FlxG.save.flush();
	}

	public static function reset():Void
	{
		vertical = true;
		length = 0;
		thickness = 40;
		margin = 50;
		densityColors = true;
		zoom = 1;
		followPlayhead = true;
		tier1 = 2;
		tier2 = 4;
		tier3 = 6;
		tier4 = 8;
		tier5 = 10;
		posX = -1;
		posY = -1;
	}
}

/**
 * ChartMinimap 的设置浮出层（Win8CharmSettings 子类，和暂停菜单的 Tool 面板同一套）。
 * 值直接落在 ChartMinimapSettings 静态字段上：改值立刻重摆条，松手（saveCurrentValue）写回编辑器存档。
 */
class ChartMinimapPanel extends Win8CharmSettings
{
	var bar:ChartMinimap;
	var cam:FlxCamera;

	public function new(bar:ChartMinimap, ?cam:FlxCamera)
	{
		super();

		this.bar = bar;
		this.cam = cam;
		panelWidthRatio = 0.3;
		dismissOnOutsideClick = true;
	}

	override function create()
	{
		// 编辑器有两台相机：主相机跟着谱面滚，面板必须画在不动的那台（camUI）上
		if (cam != null) cameras = [cam];
		super.create();
	}

	override public function getPageTitle():String
		return Language.getPhrase('chart_minimap_title', 'Chart Minimap');

	override public function getPageDescription():String
		return Language.getPhrase('chart_minimap_desc', 'Density bar position, size and colors');

	override public function buildCharms():Array<CharmEntry>
	{
		return [{
			id: 'minimap',
			title: Language.getPhrase('charm_minimap', 'Layout'),
			description: Language.getPhrase('description_charm_minimap', 'Bar position, size and safe margins'),
			options: buildOptions()
		}, {
			id: 'minimap_view',
			title: Language.getPhrase('charm_minimap_view', 'View'),
			description: Language.getPhrase('description_charm_minimap_view', 'Timeline zoom and playhead follow'),
			options: buildViewOptions()
		}];
	}

	function buildOptions():Array<Option>
	{
		var out:Array<Option> = [];

		var orient:CharmOption = new CharmOption(Language.getPhrase('chart_minimap_orientation', 'Orientation'),
			Language.getPhrase('chart_minimap_orientation_desc', 'Vertical bar sits on the right edge, horizontal along the bottom'),
			STRING, ChartMinimapSettings.vertical ? 'Vertical' : 'Horizontal', ['Vertical', 'Horizontal']);
		orient.getter = function() return ChartMinimapSettings.vertical ? 'Vertical' : 'Horizontal';
		orient.setter = function(v) ChartMinimapSettings.vertical = (v == 'Vertical');
		orient.onChange = applyToBar;
		orient.onSave = persistSettings;
		out.push(orient);

		out.push(makeNum(Language.getPhrase('chart_minimap_length', 'Length (px, 0 = auto)'),
			Language.getPhrase('chart_minimap_length_desc', 'Bar length along its axis; Auto fills the screen minus both safe margins'),
			'length', 0, 4000, 20, 0, function(v) ChartMinimapSettings.length = v,
			function(v:Float) return v <= 0 ? Language.getPhrase('chart_minimap_auto', 'Auto') : Std.int(v) + 'px'));

		out.push(makeNum(Language.getPhrase('chart_minimap_thickness', 'Thickness (px)'),
			Language.getPhrase('chart_minimap_thickness_desc', 'How wide the bar is across its axis'),
			'thickness', 40, 150, 5, 0, function(v) ChartMinimapSettings.thickness = v));

		out.push(makeNum(Language.getPhrase('chart_minimap_margin', 'Safe margin (px)'),
			Language.getPhrase('chart_minimap_margin_desc', 'Empty space kept at both ends of the bar'),
			'margin', 8, 300, 2, 0, function(v) ChartMinimapSettings.margin = v));

		var density:CharmOption = new CharmOption(Language.getPhrase('chart_minimap_density', 'Density colors'),
			Language.getPhrase('chart_minimap_density_desc', 'Color each section by note density instead of a flat color'),
			BOOL, ChartMinimapSettings.densityColors);
		density.getter = function() return ChartMinimapSettings.densityColors;
		density.setter = function(v) ChartMinimapSettings.densityColors = (v == true);
		density.onChange = applyToBar;
		density.onSave = persistSettings;
		out.push(density);

		out.push(makeNum(Language.getPhrase('chart_minimap_tier1', 'Low / medium (nps)'),
			Language.getPhrase('chart_minimap_tier1_desc', 'Notes per second where green turns yellow-green'),
			'tier1', 0.5, 30, 0.5, 1, function(v) ChartMinimapSettings.tier1 = v));
		out.push(makeNum(Language.getPhrase('chart_minimap_tier2', 'Medium / high (nps)'),
			Language.getPhrase('chart_minimap_tier2_desc', 'Notes per second where yellow-green turns yellow'),
			'tier2', 1, 40, 0.5, 1, function(v) ChartMinimapSettings.tier2 = v));
		out.push(makeNum(Language.getPhrase('chart_minimap_tier3', 'High / very high (nps)'),
			Language.getPhrase('chart_minimap_tier3_desc', 'Notes per second where yellow turns orange'),
			'tier3', 2, 60, 0.5, 1, function(v) ChartMinimapSettings.tier3 = v));
		out.push(makeNum(Language.getPhrase('chart_minimap_tier4', 'Very high / extreme (nps)'),
			Language.getPhrase('chart_minimap_tier4_desc', 'Notes per second where orange turns orange-red'),
			'tier4', 3, 80, 0.5, 1, function(v) ChartMinimapSettings.tier4 = v));
		out.push(makeNum(Language.getPhrase('chart_minimap_tier5', 'Extreme+ (nps)'),
			Language.getPhrase('chart_minimap_tier5_desc', 'Notes per second where orange-red turns red'),
			'tier5', 4, 100, 0.5, 1, function(v) ChartMinimapSettings.tier5 = v));

		var reset:Option = new CharmActionOption(Language.getPhrase('chart_minimap_reset', 'Reset Defaults'),
			Language.getPhrase('chart_minimap_reset_desc', 'Restore every setting and snap the bar back to the screen edge'),
			Language.getPhrase('options.action.reset', 'Reset'));
		reset.action = function()
		{
			ChartMinimapSettings.reset();
			persistSettings();
			applyToBar();
		};
		out.push(reset);

		return out;
	}

	function buildViewOptions():Array<Option>
	{
		var out:Array<Option> = [];

		out.push(makeZoomNum());

		var follow:CharmOption = new CharmOption(Language.getPhrase('chart_minimap_follow', 'Follow playhead'),
			Language.getPhrase('chart_minimap_follow_desc', 'Scroll the zoomed window with the playhead'),
			BOOL, ChartMinimapSettings.followPlayhead);
		follow.getter = function() return ChartMinimapSettings.followPlayhead;
		follow.setter = function(v) ChartMinimapSettings.followPlayhead = (v == true);
		follow.onSave = persistSettings;
		out.push(follow);

		out.push(makeAction(Language.getPhrase('chart_minimap_zoom_in', 'Zoom In'),
			Language.getPhrase('chart_minimap_zoom_in_desc', 'Double the timeline zoom around the playhead'),
			'+', function()
			{
				if (bar != null) bar.zoomBy(2);
				persistSettings();
			}));

		out.push(makeAction(Language.getPhrase('chart_minimap_zoom_out', 'Zoom Out'),
			Language.getPhrase('chart_minimap_zoom_out_desc', 'Halve the timeline zoom around the playhead'),
			'-', function()
			{
				if (bar != null) bar.zoomBy(0.5);
				persistSettings();
			}));

		out.push(makeAction(Language.getPhrase('chart_minimap_reset_view', 'Reset View'),
			Language.getPhrase('chart_minimap_reset_view_desc', 'Back to the whole song at 1x'),
			Language.getPhrase('options.action.reset', 'Reset'), function()
			{
				if (bar != null) bar.resetView();
			}));

		return out;
	}

	/** Zoom 项：改值要以播放头为锚重算窗口，不能走默认的 applyToBar */
	function makeZoomNum():Option
	{
		var opt:CharmOption = new CharmOption(Language.getPhrase('chart_minimap_zoom', 'Zoom (1 = full song)'),
			Language.getPhrase('chart_minimap_zoom_desc', '1 shows the whole song, 16 shows one sixteenth'),
			FLOAT, ChartMinimapSettings.zoom);
		opt.getter = function() return ChartMinimapSettings.zoom;
		opt.setter = function(v) ChartMinimapSettings.zoom = v;
		opt.minValue = 1;
		opt.maxValue = 16;
		opt.changeValue = 0.25;
		opt.decimals = 2;
		opt.valueFormatter = function(v:Float) return (Math.round(v * 100) / 100) + 'x';
		opt.onChange = function() { if (bar != null) bar.applyZoomFromSetting(); };
		opt.onSave = persistSettings;
		return opt;
	}

	/** 动作项：点一下执行（动作自己负责落盘 / 重画） */
	function makeAction(name:String, desc:String, label:String, act:Void->Void):Option
	{
		var opt:Option = new CharmActionOption(name, desc, label);
		opt.action = act;
		return opt;
	}

	/** 数值项：getter 按字段名现读，拖动期间不写文件 */
	function makeNum(name:String, desc:String, variable:String, min:Float, max:Float, step:Float, dec:Int,
		setter:Float->Void, ?formatter:Float->String):Option
	{
		var opt:CharmOption = new CharmOption(name, desc, FLOAT, Reflect.field(ChartMinimapSettings, variable));
		opt.getter = function() return Reflect.field(ChartMinimapSettings, variable);
		opt.setter = function(v) setter(v);
		opt.minValue = min;
		opt.maxValue = max;
		opt.changeValue = step;
		opt.decimals = dec;
		if (formatter != null) opt.valueFormatter = formatter;
		opt.onChange = applyToBar;
		opt.onSave = persistSettings;
		return opt;
	}

	function applyToBar():Void
	{
		if (bar != null) bar.applyLayout();
	}

	/** 设置写回宿主编辑器的存档（ChartMinimap 持有 save 引用） */
	function persistSettings():Void
	{
		ChartMinimapSettings.save(bar != null ? bar.chartSave : null);
	}
}
