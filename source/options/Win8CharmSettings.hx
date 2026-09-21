package options;

import backend.MouseMove;
import backend.UIControlTheme;
import options.Option.OptionType;
import options.objects.OptionWidgetFactory;
import options.objects.win8.Win8CharmIcon;
import options.objects.win8.Win8CharmRow;
import options.objects.win8.Win8CharmSection;
import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

/**
 * ==========================================================================
 * Win8 风格设置面板（基类）
 * ==========================================================================
 *
 * Windows 8 的"设置浮出层"（Settings flyout）：贴屏幕右侧 30% 的面板，从右边缘滑入，
 * 顶部标题栏 + 中间滚动区 + 底部说明栏。子类只重写 buildCharms() 声明分组与 Option
 * （可以是动态的，rebuildCharms() 换内容），排版 / 滚动 / 键鼠 / 深浅色 / 控件主题全由基类处理。
 *
 * 两种"隐藏"别搞混：showPanel() / hidePanel() 是纯滑动、不销毁自己；关闭整个界面走
 * animateOutAndClose() → closeCharmBar() → close()。返回按钮 / ESC / 右键共用
 * onBackAction()，子类可重写成"先收面板"。面板贴屏幕最右（panelX = FlxG.width - panelW）。
 *
 * 模态控件（目前只有等按键的 options.objects.backend.KeybindButton）把状态同步到
 * inputModal 上，面板自己的键盘 / 鼠标处理就会整段让路，不必 override 那串输入方法。
 */
class Win8CharmSettings extends backend.MusicBeatSubstate
{
	public static var instance:Win8CharmSettings = null;

	// =========================================================
	// 布局常量
	// =========================================================
	/** 顶部标题区高度 */
	public static inline var HEADER_H:Float = 96;
	/**
	 * 面板内一行的高度。
	 * 行的排版沿用 Win10 的 Win10OptionRow（标题在上、控件在下）。
	 */
	public static inline var ROW_H:Float = 88;
	public static inline var ROW_GAP:Float = 6;
	/** 动作按钮（ACTION）的高度；largeActionButtons 打开时用 */
	public static inline var ACTION_BTN_H:Float = 40;
	/** 面板内边距 */
	public static inline var PANEL_PAD:Float = 12;
	/** 面板底部"选项说明"栏的高度（对应 Win10 设置页底部那行说明） */
	public static inline var FOOTER_H:Float = 54;
	/**
	 * 面板最小宽度。
	 * 30% 面板下这个下限只有在窗口宽 < 1000px 时才会生效，
	 * 300 是"行标题还能单行放下"的下限（最长标题 Health Gain Multiplier ≈242px，
	 * 而 Win8CharmRow 的 title.fieldWidth = panelW - 52）。
	 */
	static inline var PANEL_W_MIN:Float = 300;
	/** 两组之间的额外间距 */
	static inline var SECTION_GAP:Float = 12;

	public static inline var ANIM_IN:Float = 0.34;
	public static inline var ANIM_OUT:Float = 0.24;

	// =========================================================
	// 数据
	// =========================================================
	/** 子类通过 buildCharms() 填充 */
	public var charms:Array<CharmEntry> = [];

	/**
	 * ACTION 按钮是否用"大按钮"渲染。
	 * false（默认）= 工厂默认的 100×35 小按钮；true = widgetW 宽 × ACTION_BTN_H 高。
	 * 目前只有 substates.PauseDebugCharm 打开。
	 */
	public var largeActionButtons:Bool = false;

	/** 分组小标题（每条有 options 的 CharmEntry 对应一个） */
	public var sections:Array<Win8CharmSection> = [];

	/** 面板内的行 */
	public var rows:Array<Win8CharmRow> = [];
	/** 键盘选中的行 */
	public var selectedRow:Int = 0;

	// =========================================================
	// UI
	// =========================================================
	/** 整屏暗色遮罩（面板不是整屏时左侧那一块） */
	var dim:Rect;

	var panelBG:Rect;
	var panelHeader:Rect;
	var panelTitle:FlxText;
	var panelDesc:FlxText;
	var backBtn:Win8CharmIcon;

	/** 底部"选项说明"栏（对应 Win10 设置页底部的说明文字） */
	var footerBG:Rect;
	var footerDivider:Rect;
	var footerText:FlxText;
	/** 鼠标当前悬停在哪一行，-1 = 没有 */
	var hoveredRow:Int = -1;

	var contentGroup:FlxSpriteGroup;
	/** 下拉/调色板弹层的挂载层（永远在最上面） */
	var overlayContainer:FlxSpriteGroup;

	// =========================================================
	// 滚动 / 动画状态
	// =========================================================
	var scroller:MouseMove;
	var scrollHolder:{value:Float} = {value: 0};
	public var scroll:Float = 0;
	public var maxScroll:Float = 0;

	var panelX:Float = 0;
	var panelW:Float = 0;

	/** 面板相对"最终位置"的偏移量（= panelW 表示完全在右边屏幕外） */
	var panelOffset:Float = 0;
	/** FlxTween 用的载体（FlxTween 只能 tween 对象字段） */
	var panelSlide:{value:Float} = {value: 0};
	/** 标题/描述/返回按钮的最终 x，滑动时在它基础上加 panelOffset */
	var titleBaseX:Float = 0;
	var backBaseX:Float = 0;
	var footerBaseX:Float = 0;

	public var isAnimating:Bool = true;
	public var closing:Bool = false;

	/**
	 * 面板占屏宽的比例。默认 0.3 —— 也就是真 Win8 那个贴屏幕右侧的设置浮出层。
	 * 面板贴屏幕最右（panelX = FlxG.width - panelW），所以它天然盖住右边的图标栏。
	 */
	public var panelWidthRatio:Float = 0.3;

	/**
	 * 面板当前是否处于"贴右展开"状态。
	 * 设置页在 startIntro() 里直接展开（恒为 true）；
	 * 暂停菜单初始为 false（只显示图标栏），点 Difficulty / Tool 才 showPanel()。
	 */
	public var panelVisible:Bool = false;

	/** 进入前 UITheme 的 surface 值，destroy 时还原 */
	var prevSurface:String = UIControlTheme.WIN10;

	/** 已套用的主题版本号（深浅色 / 控件主题变了就重建） */
	var themeVersion:Int = -1;

	/** 待重建标记：0 = 无，1 = 面板内容，2 = 整块重建 */
	var pendingRebuild:Int = 0;

	/** 点面板之外的地方是否收起整个面板 */
	public var dismissOnOutsideClick:Bool = true;

	/**
	 * 有模态交互在进行中（目前只有等按键的 KeybindButton）。
	 * 为 true 时面板自己的键盘 / 鼠标操作**全部挂起**（连"点空白处关闭"也不做），交给模态控件
	 * 消费这一轮输入 —— 否则等按键时按方向键会同时滚动列表、按回车会触发选中行上的别的选项、
	 * 按 ESC 会把整个界面关掉。子类每帧同步过来即可。
	 */
	public var inputModal:Bool = false;

	var langReloadCb:Void->Void = null;

	// =========================================================
	// 生命周期
	// =========================================================
	public function new()
	{
		super();
	}

	override function create()
	{
		super.create();

		instance = this;

		// 声明本界面画在哪台相机上（子类 PauseDebugCharm 会在 create() 里先设好 cameras）。
		// 面板的命中判定 —— 控件 / 行悬停 / 点空白 / 拖拽滚动 —— 全靠它统一到这台相机，
		// 否则控件会按 FlxG.camera（游戏相机）的 scroll / zoom 去算命中区，整体偏掉。
		OptionInput.bind(this, (cameras != null && cameras.length > 0) ? cameras[0] : null);

		FlxG.mouse.visible = true;

		// 声明"我现在是 Win8 界面"：控件主题设为 auto 时，这里的控件就用 Win8 风格
		prevSurface = UIControlTheme.setSurface(UIControlTheme.WIN8);

		UITheme.ensure();
		themeVersion = UITheme.version;

		computeLayout();

		// 1) 数据（子类的字段必须先初始化好，见类注释）
		charms = buildCharms();
		if (charms == null) charms = [];

		// 2) 背景层（子类可以在这里加自己的背景/信息面板，位于面板之下）
		createBackdrop();

		// 3) 面板本体
		createPanelUI();

		// 4) 面板内容（暂停菜单的 buildCharms() 是动态的，初始可能什么都没有）
		rebuildPanelRows();
		applyHeaderText();

		// 5) 语言热重载
		langReloadCb = refreshLanguage;
		Language.addReloadCallback(langReloadCb);

		// 6) 入场动画。onPanelOpened 由 startIntro/showPanel 负责触发，
		//    不在这里调 —— 暂停菜单初始面板是收起的，不该收到"面板已打开"。
		startIntro();
	}

	/** 计算面板的 x 与宽度 */
	function computeLayout():Void
	{
		var ratio:Float = FlxMath.bound(panelWidthRatio, 0.25, 1);
		panelW = FlxMath.bound(FlxG.width * ratio, PANEL_W_MIN, FlxG.width);
		panelX = FlxG.width - panelW;
	}

	// =========================================================
	// 子类接口
	// =========================================================
	/** 声明所有分组（子类必须重写） */
	public function buildCharms():Array<CharmEntry>
	{
		return [];
	}

	/**
	 * 背景层。默认什么都不加（透明）。
	 * 子类（比如暂停）可以在这里 add 自己的背景、遮罩、信息面板。
	 * 此时面板还没创建，所以这里的元素一定在面板下面。
	 */
	public function createBackdrop():Void
	{
	}

	/** 面板打开时调用 */
	public function onPanelOpened(entry:CharmEntry):Void {}

	/** 面板关闭时调用 */
	public function onPanelClosed(entry:CharmEntry):Void {}

	/**
	 * 返回：顶部返回按钮 / ESC / 右键都走这里。
	 * 默认 = 关闭整个界面。暂停菜单重写成"面板开着就先收面板"。
	 */
	public function onBackAction():Void
	{
		animateOutAndClose();
	}

	/**
	 * 点了面板外面的地方。
	 * 默认：dismissOnOutsideClick 为真时关闭整个界面。
	 * 注意触发条件里带了 !isAnyPopupOpen()，不会因为点自己的下拉而误关。
	 */
	public function handleOutsideClick():Void
	{
		if (dismissOnOutsideClick) animateOutAndClose();
	}

	/** 面板收起（用户按 ESC / 点空白处）后调用；默认直接关闭自己 */
	public function closeCharmBar():Void
	{
		close();
	}

	/** 当前面板里展示的条目（没有就是 null）。面板只放一组时就是那一组。 */
	public function currentEntry():CharmEntry
	{
		return (charms.length > 0) ? charms[0] : null;
	}

	/** 面板顶部的标题。默认取第一个分组的标题；子类想要个总标题就重写它。 */
	public function getPageTitle():String
	{
		if (charms.length == 0 || charms[0] == null) return '';
		return Language.getPhrase('charm_' + charms[0].id, charms[0].title);
	}

	/** 面板顶部的说明文字 */
	public function getPageDescription():String
	{
		if (charms.length == 0 || charms[0] == null) return '';
		return charms[0].description;
	}

	/** 把面板标题/说明写成某个分组的（entry 为 null 时用 getPageTitle/getPageDescription） */
	function applyHeaderText(?entry:CharmEntry):Void
	{
		if (panelTitle == null) return;

		var t:String = null;
		var d:String = null;

		if (entry != null)
		{
			t = Language.getPhrase('charm_' + entry.id, entry.title);
			d = entry.description;
		}
		else
		{
			t = getPageTitle();
			d = getPageDescription();
		}

		panelTitle.text = (t != null) ? t : '';
		panelDesc.text = (d != null) ? d : '';
	}

	// =========================================================
	// 构建
	// =========================================================
	function createPanelUI():Void
	{
		// ---------- 遮罩：面板不是整屏时挡在左边 ----------
		dim = new Rect(0, 0, FlxG.width, FlxG.height, 0, 0, UIControlTheme.overlay(), 0);
		dim.scrollFactor.set();
		add(dim);

		// ---------- 面板底 ----------
		// 全部按"最终位置"创建，滑动效果由 applyPanelOffset() 统一加 panelOffset 实现
		panelBG = new Rect(panelX, 0, panelW, FlxG.height, 0, 0, UIControlTheme.panelBG(), 0);
		panelBG.scrollFactor.set();
		add(panelBG);

		contentGroup = new FlxSpriteGroup();
		// 内容层用面板坐标（scrollFactor = 0）：命中区就是元素自身坐标，不受相机 scroll 影响。
		// 设一次就够 —— 之后 add() 进来的行由 preAdd 继承，行再经 scrollFactorCallback 传给
		// 自己的标题与控件，控件再传给自己的子元素。
		//（指针侧由 OptionInput 统一到"本界面绘制所在的相机"，见它的类注释。）
		contentGroup.scrollFactor.set();
		add(contentGroup);

		// 标题区画在内容之后 → 内容往上滚时会"钻"到标题下面（等于裁剪）
		panelHeader = new Rect(panelX, 0, panelW, HEADER_H, 0, 0, UIControlTheme.panelHeader(), 0);
		panelHeader.scrollFactor.set();
		add(panelHeader);

		// 返回按钮在左（12 + 40 + 8 = 60），标题从它右边开始，右侧只留一个内边距
		backBaseX = panelX + 12;
		titleBaseX = panelX + 60;

		var titleX:Float = titleBaseX;
		var titleW:Float = panelW - 60 - PANEL_PAD;

		panelTitle = new FlxText(titleX, 20, titleW, '', 20);
		panelTitle.setFormat(Paths.font('montserrat.ttf'), 20, UIControlTheme.text(), LEFT);
		panelTitle.borderStyle = NONE;
		panelTitle.antialiasing = ClientPrefs.data.antialiasing;
		panelTitle.scrollFactor.set();
		add(panelTitle);

		panelDesc = new FlxText(titleX, 48, titleW, '', 11);
		panelDesc.setFormat(Paths.font('montserrat.ttf'), 11, UIControlTheme.textSecondary(), LEFT);
		panelDesc.borderStyle = NONE;
		panelDesc.antialiasing = ClientPrefs.data.antialiasing;
		panelDesc.scrollFactor.set();
		add(panelDesc);

		backBtn = new Win8CharmIcon(backBaseX, 14, 40, 40, function() {
			onBackAction();
		});
		backBtn.scrollFactor.set();
		add(backBtn);

		// ---------- 底部说明栏（对应 Win10 设置页底部那行选项说明） ----------
		footerBG = new Rect(panelX, FlxG.height - FOOTER_H, panelW, FOOTER_H, 0, 0, UIControlTheme.panelHeader(), 0);
		footerBG.scrollFactor.set();
		add(footerBG);

		footerDivider = new Rect(panelX, FlxG.height - FOOTER_H, panelW, 1, 0, 0, UIControlTheme.divider(), 0);
		footerDivider.scrollFactor.set();
		add(footerDivider);

		footerBaseX = panelX + PANEL_PAD + 2;

		footerText = new FlxText(footerBaseX, 0, panelW - PANEL_PAD * 2 - 4, '', 12);
		footerText.setFormat(Paths.font('montserrat.ttf'), 12, UIControlTheme.accent(), LEFT);
		footerText.borderStyle = NONE;
		footerText.antialiasing = ClientPrefs.data.antialiasing;
		footerText.y = FlxG.height - FOOTER_H + 10;
		footerText.scrollFactor.set();
		add(footerText);

		// 下拉 / 调色板弹层挂在这里，同样要面板坐标（理由见上面 contentGroup 那段）
		overlayContainer = new FlxSpriteGroup();
		overlayContainer.scrollFactor.set();
		add(overlayContainer);

		buildScroller();

		// 初始状态：面板整体停在屏幕右边外面
		// （不需要淡入 —— 这个位置整个面板都在屏幕外，看不见，纯滑动就是真 Win8 的效果）
		panelSlide.value = panelW;
		applyPanelOffset();
	}

	/**
	 * 把 panelOffset 套用到面板的所有元素上。
	 * 注意 contentGroup 是 FlxSpriteGroup，给它的 x 赋值会以"增量"方式传播到所有行，
	 * 所以这里只要给绝对偏移即可，不用逐行处理。
	 */
	function applyPanelOffset():Void
	{
		panelOffset = panelSlide.value;

		if (panelBG != null) panelBG.x = panelX + panelOffset;
		if (panelHeader != null) panelHeader.x = panelX + panelOffset;
		if (panelTitle != null) panelTitle.x = titleBaseX + panelOffset;
		if (panelDesc != null) panelDesc.x = titleBaseX + panelOffset;
		if (backBtn != null) backBtn.x = backBaseX + panelOffset;
		if (footerBG != null) footerBG.x = panelX + panelOffset;
		if (footerDivider != null) footerDivider.x = panelX + panelOffset;
		if (footerText != null) footerText.x = footerBaseX + panelOffset;
		if (contentGroup != null) contentGroup.x = panelOffset;
	}

	/** 面板整体滑入/滑出（targetOffset = 0 是最终位置，panelW 是屏幕外） */
	function slidePanel(targetOffset:Float, time:Float, ease:flixel.tweens.EaseFunction, ?onDone:Void->Void):Void
	{
		FlxTween.cancelTweensOf(panelSlide);
		FlxTween.tween(panelSlide, {value: targetOffset}, time, {
			ease: ease,
			onUpdate: function(_) applyPanelOffset(),
			onComplete: function(_) {
				applyPanelOffset();
				if (onDone != null) onDone();
			}
		});
	}

	function buildScroller():Void
	{
		if (scroller != null)
		{
			remove(scroller, true);
			scroller = null;
		}

		scroller = new MouseMove(
			scrollHolder, 'value',
			[0, 0],
			[
				[panelX, FlxG.width],
				[HEADER_H, FlxG.height - FOOTER_H]
			],
			function()
			{
				scroll = scrollHolder.value;
				applyScroll();
			},
			true
		);
		scroller.infScroll = false;
		scroller.dragSensitivity = 1.0;
		scroller.deceleration = 0.92;
		scroller.mouseWheelSensitivity = -1000.0;
		scroller.dragStartDelayMs = 100;
		scroller.dragStartDistance = 10;
		// 面板的 mouseLimit / 拖拽基准都是面板坐标，而 MouseMove 默认读 FlxG.mouse.x/y
		// （相对 FlxG.camera 的世界坐标，被游戏相机的 scroll / zoom 推着走）
		// → 切到 OptionInput 的指针空间，否则"能拖动的区域"和面板对不上。
		scroller.useViewSpace = true;
		add(scroller);
	}

	// =========================================================
	// 重建
	// =========================================================
	/**
	 * 请求下一帧重建面板内容。
	 * 一定要在控件的回调里用它，而不是直接调 rebuildPanelRows() ——
	 * 直接调会在控件自己的 update 里把它销毁掉。
	 */
	public function requestPanelRebuild():Void
	{
		if (pendingRebuild < 1) pendingRebuild = 1;
	}

	/** 请求下一帧重建整块内容（选项条目本身变了） */
	public function requestCharmsRebuild():Void
	{
		pendingRebuild = 2;
	}

	public function charmById(id:String):CharmEntry
	{
		for (c in charms)
			if (c != null && c.id == id) return c;
		return null;
	}

	public function charmIndex(id:String):Int
	{
		for (i in 0...charms.length)
			if (charms[i] != null && charms[i].id == id) return i;
		return -1;
	}

	/** 重新声明内容（数量/条目变了）并重建 */
	public function rebuildCharms():Void
	{
		charms = buildCharms();
		if (charms == null) charms = [];

		clearPanelRows();
		rebuildPanelRows();
		applyHeaderText();
	}

	/** 面板内容变了（比如某个选项切换后选项列表变了）→ 就地重建 */
	public function rebuildPanelRows():Void
	{
		clearPanelRows();

		var rowW:Float = panelW - PANEL_PAD * 2;
		var widgetW:Float = Math.min(260, Math.max(160, rowW - 32));
		var curY:Float = HEADER_H + PANEL_PAD;

		var first:Bool = true;

		for (ci in 0...charms.length)
		{
			var c:CharmEntry = charms[ci];
			if (c == null) continue;

			var hasOptions:Bool = (c.options != null && c.options.length > 0);
			var hasAction:Bool = (c.action != null);
			if (!hasOptions && !hasAction) continue;

			// 有选项 → 先铺一条分组小标题，再逐条排控件行
			if (hasOptions)
			{
				if (!first) curY += SECTION_GAP;
				first = false;

				var section:Win8CharmSection = new Win8CharmSection(panelX + PANEL_PAD, curY, rowW, ci, c.id,
					Language.getPhrase('charm_' + c.id, c.title));
				section.setRowMeta(curY, Win8CharmSection.SECTION_H);
				sections.push(section);
				contentGroup.add(section);

				curY += Win8CharmSection.SECTION_H;

				for (opt in c.options)
				{
					if (opt == null) continue;
					var w:FlxSpriteGroup = makeWidget(opt, widgetW);
					if (w == null) continue;
					curY = pushRow(opt, w, rowW, curY);
				}
			}

			// 有动作（且没选项）→ 直接渲染成一行按钮
			if (hasAction)
			{
				if (!first) curY += SECTION_GAP;
				first = false;

				var actOpt:Option = makeActionOption(c);
				var actW:FlxSpriteGroup = makeWidget(actOpt, widgetW);
				if (actW != null) curY = pushRow(actOpt, actW, rowW, curY);
			}
		}

		var contentH:Float = (rows.length > 0 || sections.length > 0) ? (curY - HEADER_H - PANEL_PAD - ROW_GAP) : 0;
		// 可视高度要去掉底部的说明栏
		var viewH:Float = FlxG.height - HEADER_H - FOOTER_H - PANEL_PAD * 2;
		maxScroll = Math.max(0, contentH - viewH);

		scroll = FlxMath.bound(scroll, 0, maxScroll);
		scrollHolder.value = scroll;

		if (scroller != null)
		{
			scroller.moveLimit = [0, maxScroll];
			scroller.velocity = 0;
		}

		var lastRow:Int = rows.length - 1;
		if (lastRow < 0) lastRow = 0;
		if (selectedRow > lastRow) selectedRow = lastRow;
		if (selectedRow < 0) selectedRow = 0;

		applyScroll();
		updateSelectionVisual();
	}

	/**
	 * 造选项控件。
	 * 开了 largeActionButtons 时 ACTION 用更大的按钮 —— 宽度仍取 widgetW，
	 * 好跟同列其它控件的宽度对齐。
	 */
	function makeWidget(opt:Option, widgetW:Float):FlxSpriteGroup
	{
		if (largeActionButtons && opt.type == ACTION)
			return OptionWidgetFactory.createActionButton(opt, widgetW, ACTION_BTN_H);
		return OptionWidgetFactory.create(opt, overlayContainer, widgetW);
	}

	/** 造一行并挂进 contentGroup，返回下一行的 y */
	function pushRow(opt:Option, widget:FlxSpriteGroup, rowW:Float, curY:Float):Float
	{
		var row:Win8CharmRow = new Win8CharmRow(panelX + PANEL_PAD, curY, rowW, ROW_H, opt, widget);
		row.setRowMeta(curY, ROW_H);
		rows.push(row);
		contentGroup.add(row);
		return curY + ROW_H + ROW_GAP;
	}

	/**
	 * 给"只有动作、没有选项"的条目造一个能喂给 OptionButton 的 Option。
	 * 它不读也不写 ClientPrefs，值恒为 null。
	 */
	function makeActionOption(entry:CharmEntry):Option
	{
		var title:String = Language.getPhrase('charm_' + entry.id, entry.title);
		var label:String = (entry.actionLabel != null && entry.actionLabel != '')
			? entry.actionLabel
			: Language.getPhrase('options.action.open', 'Open');

		var opt:CharmActionOption = new CharmActionOption(title, entry.description, label);
		opt.action = entry.action;
		return opt;
	}

	function clearPanelRows():Void
	{
		for (r in rows)
		{
			FlxTween.cancelTweensOf(r);
			contentGroup.remove(r, true);
			r.destroy();
		}
		rows = [];

		for (s in sections)
		{
			FlxTween.cancelTweensOf(s);
			contentGroup.remove(s, true);
			s.destroy();
		}
		sections = [];

		scroll = 0;
		scrollHolder.value = 0;
		maxScroll = 0;
		hoveredRow = -1;
		updateFooterText();
	}

	// =========================================================
	// 滚动 / 选中
	// =========================================================
	function applyScroll():Void
	{
		scroll = FlxMath.bound(scrollHolder.value, 0, maxScroll);
		scrollHolder.value = scroll;

		var viewTop:Float = HEADER_H;
		var viewBottom:Float = FlxG.height - FOOTER_H;

		for (s in sections)
		{
			s.y = s.baseY - scroll;
			var vis:Bool = (s.y + s.rowH > viewTop) && (s.y < viewBottom);
			s.visible = vis;
			s.active = vis;
		}

		for (i in 0...rows.length)
		{
			var row:Win8CharmRow = rows[i];
			row.y = row.baseY - scroll;

			var visible:Bool = (row.y + row.rowH > viewTop) && (row.y < viewBottom);
			row.visible = visible;
			row.active = visible;
		}
	}

	function updateSelectionVisual():Void
	{
		for (i in 0...rows.length)
			rows[i].setSelected(i == selectedRow);

		updateFooterText();
	}

	/**
	 * 底部说明栏：优先显示鼠标悬停那一行，没有悬停就显示键盘选中那一行。
	 * 对应 Win10 设置页底部的说明文字（行本身不再放描述，保持 Win10 的干净排版）。
	 */
	function updateFooterText():Void
	{
		if (footerText == null) return;

		var opt:Option = null;
		if (hoveredRow >= 0 && hoveredRow < rows.length) opt = rows[hoveredRow].option;
		else if (selectedRow >= 0 && selectedRow < rows.length) opt = rows[selectedRow].option;

		footerText.text = (opt != null && opt.description != null) ? opt.description : '';
	}

	/** 找出鼠标当前悬停在哪一行（只更新说明栏，不抢键盘选中） */
	function updateHoveredRow():Void
	{
		var idx:Int = -1;

		if (!isAnyPopupOpen() && rows.length > 0)
		{
			// 面板自己的悬停判定必须和控件的命中判定用同一套坐标 —— 就是 OptionInput 那个空间
			//（= FlxObject.overlapsPoint 里的 xPos），否则两边会对不上。
			var mx:Float = OptionInput.mouseX();
			var my:Float = OptionInput.mouseY();

			if (mx >= panelX && mx <= panelX + panelW && my >= HEADER_H && my < FlxG.height - FOOTER_H)
			{
				for (i in 0...rows.length)
				{
					var r:Win8CharmRow = rows[i];
					if (!r.visible || !r.active) continue;
					if (my >= r.y && my <= r.y + r.rowH)
					{
						idx = i;
						break;
					}
				}
			}
		}

		if (idx != hoveredRow)
		{
			hoveredRow = idx;
			updateFooterText();
		}
	}

	/** 把某一行滚进可视区 */
	function scrollRowIntoView(index:Int):Void
	{
		if (index < 0 || index >= rows.length) return;

		var top:Float = rows[index].baseY - HEADER_H;
		var bottom:Float = top + ROW_H;
		var viewH:Float = FlxG.height - HEADER_H - FOOTER_H - PANEL_PAD;

		var target:Float = scroll;
		if (top < target) target = top;
		else if (bottom > target + viewH) target = bottom - viewH;

		target = FlxMath.bound(target, 0, maxScroll);

		if (scroller != null) scroller.tweenData = target;
		else
		{
			scrollHolder.value = target;
			applyScroll();
		}
	}

	/** 滚到某个分组（按 CharmEntry.id） */
	public function scrollToSection(id:String):Void
	{
		for (s in sections)
		{
			if (s.charmId != id) continue;

			var target:Float = FlxMath.bound(s.baseY - HEADER_H, 0, maxScroll);
			if (scroller != null) scroller.tweenData = target;
			else
			{
				scrollHolder.value = target;
				applyScroll();
			}
			return;
		}
	}

	public function changeRowSelection(delta:Int):Void
	{
		if (rows.length == 0) return;

		var old:Int = selectedRow;
		selectedRow = FlxMath.wrap(selectedRow + delta, 0, rows.length - 1);
		if (selectedRow == old) return;

		updateSelectionVisual();
		scrollRowIntoView(selectedRow);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	// =========================================================
	// 键盘操作（控件本身是鼠标驱动的，这里补上键盘支持）
	// =========================================================
	/** 当前选中的选项 */
	public function selectedOption():Option
	{
		if (selectedRow < 0 || selectedRow >= rows.length) return null;
		return rows[selectedRow].option;
	}

	/** 调整当前选中项的值；dir = -1 / +1 */
	public function adjustSelected(dir:Int):Void
	{
		var opt:Option = selectedOption();
		if (opt == null) return;

		switch (opt.type)
		{
			case BOOL:
				opt.setValue(!(opt.getValue() == true));
			case INT, FLOAT, PERCENT:
				var step:Float = Std.parseFloat(Std.string(opt.changeValue));
				if (Math.isNaN(step) || step == 0) step = 1;

				var v:Float = cast opt.getValue();
				v += dir * step;

				var lo:Dynamic = opt.minValue;
				var hi:Dynamic = opt.maxValue;
				if (lo != null && v < lo) v = lo;
				if (hi != null && v > hi) v = hi;

				opt.setValue(opt.type == INT ? Math.round(v) : FlxMath.roundDecimal(v, opt.decimals));
			case STRING:
				cycleString(opt, dir);
			case COLOR:
				cycleColor(opt, dir);
			case ACTION:
				return;
			case KEYBIND:
				return;
		}

		opt.change();
		opt.saveCurrentValue();
		refreshSelectedWidget();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	/** 回车：BOOL 切换、ACTION 执行、其它等同于往右调整一次 */
	public function activateSelected():Void
	{
		var opt:Option = selectedOption();
		if (opt == null) return;

		switch (opt.type)
		{
			case ACTION:
				if (opt.action != null) opt.action();
				return;
			case BOOL:
				opt.setValue(!(opt.getValue() == true));
			case INT, FLOAT, PERCENT, STRING, COLOR:
				adjustSelected(1);
				return;
			case KEYBIND:
				return;
		}

		opt.change();
		opt.saveCurrentValue();
		refreshSelectedWidget();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	/** 把当前选中项恢复默认值 */
	public function resetSelected():Void
	{
		var opt:Option = selectedOption();
		if (opt == null) return;

		opt.setValue(opt.defaultValue);
		if (opt.type == STRING && opt.options != null)
		{
			var idx:Int = opt.options.indexOf(Std.string(opt.getValue()));
			opt.curOption = idx < 0 ? 0 : idx;
		}
		opt.change();
		opt.saveCurrentValue();
		refreshSelectedWidget();
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
	}

	function refreshSelectedWidget():Void
	{
		if (selectedRow < 0 || selectedRow >= rows.length) return;
		OptionWidgetFactory.refreshValue(rows[selectedRow].widget);
	}

	function cycleString(opt:Option, dir:Int):Void
	{
		if (opt.options == null || opt.options.length == 0) return;

		var idx:Int = opt.options.indexOf(Std.string(opt.getValue()));
		if (idx < 0) idx = opt.curOption;
		idx = FlxMath.wrap(idx + dir, 0, opt.options.length - 1);

		opt.curOption = idx;
		opt.setValue(opt.options[idx]);
	}

	function cycleColor(opt:Option, dir:Int):Void
	{
		var pal:Array<Int> = Option.COLOR_PALETTE;
		var idx:Int = pal.indexOf(cast opt.getValue());
		if (idx < 0) idx = opt.curOption;
		idx = FlxMath.wrap(idx + dir, 0, pal.length - 1);

		opt.curOption = idx;
		opt.setValue(pal[idx]);
	}

	/** 有没有正在展开的下拉/调色板 */
	public function isAnyPopupOpen():Bool
	{
		for (r in rows)
		{
			var w:FlxSpriteGroup = r.widget;
			if (w == null) continue;

			if (Std.isOfType(w, options.objects.backend.StringSelect)
				&& cast(w, options.objects.backend.StringSelect).isOpen) return true;
			if (Std.isOfType(w, options.objects.backend.ColorSelect)
				&& cast(w, options.objects.backend.ColorSelect).isOpen) return true;
		}
		return false;
	}

	/** 统一开关面板里控件的鼠标响应（动画过程中关掉，避免误触） */
	function setWidgetsEnabled(v:Bool):Void
	{
		for (r in rows)
			if (r.option != null) r.option.allowUpdate = v;

		// 标题栏的返回按钮也要一起关，否则滑入滑出的过程中能被点到
		if (backBtn != null) backBtn.setInputEnabled(v);
	}

	// =========================================================
	// 动画
	// =========================================================
	public function startIntro():Void
	{
		isAnimating = true;
		setWidgetsEnabled(false);

		dim.alpha = 0;
		FlxTween.tween(dim, {alpha: UIControlTheme.overlayAlpha()}, ANIM_IN, {ease: FlxEase.quadOut});

		// 面板从屏幕右边外面滑到贴右位置。
		// 不需要淡入：offset = panelW 时整个面板（含所有行）都在屏幕外，看不见。
		panelVisible = true;
		panelSlide.value = panelW;
		applyPanelOffset();

		slidePanel(0, ANIM_IN, FlxEase.quartOut, function() {
			isAnimating = false;
			setWidgetsEnabled(true);
		});

		onPanelOpened(currentEntry());
	}

	/**
	 * 把面板从屏幕外滑到贴右位置（内容不重建）。
	 * 暂停菜单用它来"点图标 → 弹出对应面板"。
	 */
	public function showPanel():Void
	{
		if (closing || panelVisible) return;

		panelVisible = true;
		isAnimating = true;
		setWidgetsEnabled(false);

		applyPanelOffset(); // 归一到当前 panelSlide（调用前应该是 panelW）
		slidePanel(0, ANIM_IN, FlxEase.quartOut, function() {
			isAnimating = false;
			setWidgetsEnabled(true);
		});

		onPanelOpened(currentEntry());
	}

	/**
	 * 把面板滑回屏幕外，但**不关闭自己**。
	 * 暂停菜单用它来"返回图标栏"。
	 */
	public function hidePanel():Void
	{
		if (closing || !panelVisible) return;

		panelVisible = false;
		isAnimating = true;
		setWidgetsEnabled(false);

		onPanelClosed(currentEntry());

		slidePanel(panelW, ANIM_OUT, FlxEase.quartIn, function() {
			isAnimating = false;
		});
	}

	/** 面板滑出并结束 */
	public function animateOutAndClose():Void
	{
		if (closing) return;
		closing = true;
		setWidgetsEnabled(false);

		onPanelClosed(currentEntry());

		FlxTween.tween(dim, {alpha: 0}, ANIM_OUT, {ease: FlxEase.quadOut});
		slidePanel(panelW, ANIM_OUT, FlxEase.quartIn, function() {
			closeCharmBar();
		});
	}

	// =========================================================
	// 更新
	// =========================================================
	override function update(elapsed:Float)
	{
		// 深浅色 / 控件主题切换：先重建再更新，避免销毁正在 update 的控件
		if (themeVersion != UITheme.version)
		{
			themeVersion = UITheme.version;
			refreshTheme();
			rebuildPanelRows();
		}

		// 待重建（控件回调里请求的，延后到这里做）
		if (pendingRebuild > 0)
		{
			var mode:Int = pendingRebuild;
			pendingRebuild = 0;
			if (mode == 2) rebuildCharms();
			else rebuildPanelRows();
		}

		// 有下拉/调色板展开时，滚轮归它们用；面板收起时滚轮也不该驱动屏外的列表；
		// 模态交互（等按键）期间连滚动都要停 —— 行一旦滚出可视区就会被置 active = false，
		// 里面的控件跟着停更，模态状态就永远结束不了。
		if (scroller != null) scroller.inputAllow = !isAnyPopupOpen() && panelVisible && !inputModal;

		super.update(elapsed);

		if (scrollHolder.value != scroll)
			scrollHolder.value = scroll;

		// inputModal：模态控件（等按键）正在消费输入，面板这一轮什么都不做
		if (isAnimating || closing || inputModal) return;

		// ---------- 返回：ESC / 右键 / 顶部返回按钮走同一条路 ----------
		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			onBackAction();
			return;
		}

		// 面板收在屏幕外时，面板里的键盘/鼠标操作全部跳过
		if (!panelVisible) return;

		// ---------- 键盘 ----------
		if (controls.UI_DOWN_P) changeRowSelection(1);
		if (controls.UI_UP_P) changeRowSelection(-1);

		if (rows.length > 0)
		{
			if (controls.UI_LEFT_P) adjustSelected(-1);
			if (controls.UI_RIGHT_P) adjustSelected(1);
			if (controls.ACCEPT) activateSelected();
			if (controls.RESET) resetSelected();
		}

		// ---------- 鼠标：悬停更新底部说明 / 点击选中行 ----------
		updateHoveredRow();

		if (FlxG.mouse.justPressed && hoveredRow >= 0 && hoveredRow != selectedRow && !isAnyPopupOpen())
		{
			selectedRow = hoveredRow;
			updateSelectionVisual();
		}

		// ---------- 点空白处 ----------
		// !isAnyPopupOpen() 是必须的：下拉/调色板弹层挂在 overlayContainer 上，
		// 可能向左伸出 panelX，没有这个判断会"点自己的下拉却把整个界面关掉"。
		if (FlxG.mouse.justPressed && !isAnyPopupOpen() && isOutsideUI(OptionInput.mouseX(), OptionInput.mouseY()))
		{
			handleOutsideClick();
		}
	}

	/** 鼠标是否在面板之外（点这里 = 收起） */
	function isOutsideUI(mx:Float, my:Float):Bool
	{
		// 面板占满屏宽时根本没有"外面"
		if (panelW >= FlxG.width) return false;
		return (mx < panelX || mx >= panelX + panelW);
	}

	// =========================================================
	// 语言 / 主题
	// =========================================================
	public function refreshLanguage():Void
	{
		for (s in sections)
		{
			var c:CharmEntry = (s.charmIndex >= 0 && s.charmIndex < charms.length) ? charms[s.charmIndex] : null;
			if (c != null) s.setLabel(Language.getPhrase('charm_' + c.id, c.title));
		}

		applyHeaderText();

		// 这里**不能**直接 rebuildPanelRows()：语言热重载是从 Option 的回调里
		// 触发的（Language.reloadPhrases），也就是某个控件正在 update 的中途，
		// 直接重建会把正在跑 update 的控件当场销毁。延后一帧最稳。
		requestPanelRebuild();
	}

	/** 深浅色切换：整块面板重新套色 */
	public function refreshTheme():Void
	{
		if (dim != null)
		{
			dim.color = UIControlTheme.overlay();
			dim.alpha = UIControlTheme.overlayAlpha();
		}
		if (panelBG != null) panelBG.color = UIControlTheme.panelBG();
		if (panelHeader != null) panelHeader.color = UIControlTheme.panelHeader();
		if (panelTitle != null) panelTitle.color = UIControlTheme.text();
		if (panelDesc != null) panelDesc.color = UIControlTheme.textSecondary();
		if (footerBG != null) footerBG.color = UIControlTheme.panelHeader();
		if (footerDivider != null) footerDivider.color = UIControlTheme.divider();
		if (footerText != null) footerText.color = UIControlTheme.accent();

		if (backBtn != null) backBtn.refreshTheme();

		for (s in sections) s.refreshTheme();
		for (r in rows) r.refreshTheme();
	}

	override function destroy()
	{
		if (langReloadCb != null)
		{
			Language.removeReloadCallback(langReloadCb);
			langReloadCb = null;
		}

		UIControlTheme.restoreSurface(prevSurface);
		if (instance == this) instance = null;
		OptionInput.unbind(this);

		super.destroy();
	}
}

// =========================================================
// 面板条目
// =========================================================
typedef CharmEntry = {
	/** 唯一 id（也用作语言 key：charm_<id>） */
	var id:String;
	/** 标题 */
	var title:String;
	/** 说明文字（面板标题下面那行） */
	var description:String;
	/** 分组里的选项；为空时看 action */
	var options:Array<Option>;
	/** 有它且没有 options 时，这一条会渲染成一个动作按钮 */
	@:optional var action:Void->Void;
	/** 动作按钮上的文字（不填就用 "Open"） */
	@:optional var actionLabel:String;
	/** 打开前调用（刷新数据用） */
	@:optional var onOpen:Void->Void;
	/** 关闭后调用 */
	@:optional var onClose:Void->Void;
}

// =========================================================
// 不写进 ClientPrefs 的"临时选项"
// =========================================================
/**
 * 面板里经常需要一些并不保存到存档的选项（例如暂停里的 Skip Time），
 * 它们只要一个"值 + 回调"就够了，所以这里给 Option 做一个不碰 ClientPrefs 的实现。
 */
class CharmOption extends Option
{
	public var getter:Void->Dynamic = null;
	public var setter:Dynamic->Void = null;
	public var onSave:Void->Void = null;

	var localValue:Dynamic = null;

	public function new(name:String, description:String, type:OptionType, defaultValue:Dynamic, ?options:Array<String>)
	{
		super(name, description, 'charm_' + name, type, options);

		this.defaultValue = defaultValue;
		localValue = defaultValue;

		if (type == STRING && options != null && options.length > 0)
		{
			var idx:Int = options.indexOf(Std.string(defaultValue));
			curOption = idx < 0 ? 0 : idx;
		}
	}

	override public function getValue():Dynamic
		return getter != null ? getter() : localValue;

	override public function setValue(value:Dynamic):Void
	{
		if (setter != null) setter(value) else localValue = value;
	}

	/** 不落盘，只通知 */
	override public function saveCurrentValue():Void
	{
		if (onSave != null) onSave();
		if (Option.onValueSaved != null) Option.onValueSaved(this);
	}
}

/**
 * "动作型"条目用的 Option：只为把 entry.action 喂给 OptionButton，
 * 值恒为 null，读写都是空操作。
 */
class CharmActionOption extends Option
{
	public function new(name:String, description:String, actionLabel:String)
	{
		super(name, description, 'charm_action', ACTION);
		this.actionLabel = actionLabel;
	}

	override public function getValue():Dynamic
		return null;

	override public function setValue(value:Dynamic):Void {}

	override public function saveCurrentValue():Void {}
}
