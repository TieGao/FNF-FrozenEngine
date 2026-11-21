package backend;

/**
 * 全局 UI 主题调色板（Win10 风格界面专用）
 *
 * 数据源就是已有的 ClientPrefs.data.colorMode 字段：
 *   'dark'  → 深色（原来的配色）
 *   'white' → 浅色（'light' 也当作浅色处理）
 *
 * 所有界面（OptionsState / OptionsPageState 及其子控件）都从这里取色，
 * 不要再写死颜色值。
 *
 * 切换流程：
 *   BasicsData 的 "Color Mode" 选项（或调用 UITheme.toggle()）
 *   → Option.saveCurrentValue() → Option.applyImmediateChanges()
 *   → UITheme.refresh() → 通知监听者 → 界面按新配色重建
 */
class UITheme
{
	// ---------------------------------------------------------
	// 模式常量
	// ---------------------------------------------------------
	public static inline var DARK:String = 'dark';
	public static inline var LIGHT:String = 'white';

	/** 当前是否浅色模式（由 colorMode 推导） */
	public static var isLight(default, null):Bool = false;

	/**
	 * 主题版本号：每次 refresh() 自增。
	 * 界面只要在 update 里比较自己记录的版本号，就能知道要不要重建，
	 * 比注册回调更省心（不用担心回调没被摘干净）。
	 */
	public static var version(default, null):Int = 0;

	// ---------------------------------------------------------
	// 窗口 / 遮罩
	// ---------------------------------------------------------
	public static var windowBG:FlxColor = 0xFF000000;
	public static var overlay:FlxColor = 0xFF000000;
	public static var overlayAlpha:Float = 0.5;
	public static var mask:FlxColor = 0xFF000000;

	// ---------------------------------------------------------
	// 面板
	// ---------------------------------------------------------
	public static var sidebar:FlxColor = 0xFF2B2B2B;   // 导航栏 / 头部左
	public static var divider:FlxColor = 0xFF3F3F3F;   // 分割线
	public static var base:FlxColor = 0xFF1F1F1F;      // 更深一层的底色

	// ---------------------------------------------------------
	// 大类卡片
	// ---------------------------------------------------------
	public static var card:FlxColor = 0xFF0A0A0A;
	public static var cardHover:FlxColor = 0xFF2E2E2E;
	public static var cardPress:FlxColor = 0xFF454545;

	// ---------------------------------------------------------
	// 左侧导航项
	// ---------------------------------------------------------
	public static var navItem:FlxColor = 0xFF2B2B2B;
	public static var navItemHover:FlxColor = 0xFF3A3A3A;
	public static var navItemActive:FlxColor = 0xFF3A3A3A;
	public static var navItemPress:FlxColor = 0xFF222222;

	// ---------------------------------------------------------
	// 通用控件（按钮 / 下拉条）
	// ---------------------------------------------------------
	public static var control:FlxColor = 0xFF3A3A3A;
	public static var controlHover:FlxColor = 0xFF4A4A4A;
	public static var controlPress:FlxColor = 0xFF2B2B2B;

	// ---------------------------------------------------------
	// 弹层（下拉 / 调色板）
	// ---------------------------------------------------------
	public static var popup:FlxColor = 0xFF2B2B2B;
	public static var popupItem:FlxColor = 0xFF3A3A3A;

	// ---------------------------------------------------------
	// 搜索框
	// ---------------------------------------------------------
	public static var searchBG:FlxColor = 0xFF1F1F1F;
	public static var searchBGFocus:FlxColor = 0xFF2B2B2B;
	public static var searchBorder:FlxColor = 0xFF5A5A5A;
	public static var searchBorderHover:FlxColor = 0xFF8A8A8A;
	public static var searchText:FlxColor = 0xFFFFFFFF;
	public static var searchHint:FlxColor = 0xFF9A9A9A;

	// ---------------------------------------------------------
	// 强调色 / 图标
	// ---------------------------------------------------------
	/**
	 * 强调色的三个档位全部由 ClientPrefs.data.uiAccent 派生（见 applyAccent）。
	 * 这里给的字面量只是"还没调用 ensure() 时"的占位值，applyAccent 会覆盖。
	 */
	public static var accent:FlxColor = 0xFF4CC2FF;
	/** 次要槽位：悬停与轻量反馈，来自 ClientPrefs.data.uiAccentHover */
	public static var accentHover:FlxColor = 0xFF67CBFF;
	/** 主色压暗一档，用于搜索框聚焦线这类"需要更沉"的位置 */
	public static var accentDeep:FlxColor = 0xFF0078D4;
	/** 主色压暗两档，按下态 */
	public static var accentPress:FlxColor = 0xFF2E9BD6;
	public static var icon:FlxColor = 0xFFCCCCCC;

	// ---------------------------------------------------------
	// 消息通知（toast）：Win8 通知条固定深蓝，不随明暗模式变
	// ---------------------------------------------------------
	public static var toast:FlxColor = 0xFF14406F;
	public static var toastBarTrack:FlxColor = 0xFF0A2A4C;

	// ---------------------------------------------------------
	// 文字
	// ---------------------------------------------------------
	public static var textPrimary:FlxColor = 0xFFFFFFFF;
	public static var textSecondary:FlxColor = 0xFFAAAAAA;
	public static var textMuted:FlxColor = 0xFFE0E0E0;
	public static var textOnAccent:FlxColor = 0xFFFFFFFF;

	// ---------------------------------------------------------
	// 危险操作（Reset 之类）
	// ---------------------------------------------------------
	public static var danger:FlxColor = 0xFFFF6363;
	public static var dangerBase:FlxColor = 0xFF5A2B2B;
	public static var dangerHover:FlxColor = 0xFF7A3A3A;
	public static var dangerPress:FlxColor = 0xFF3A1F1F;

	// ---------------------------------------------------------
	// 滑块 / 开关
	// ---------------------------------------------------------
	public static var sliderTrack:FlxColor = 0xFF363535;
	public static var sliderTrackAlpha:Float = 0.4;
	public static var sliderFill:FlxColor = 0xFF0064FA;
	public static var sliderKnob:FlxColor = 0xFF0064FA;
	public static var sliderKnobHover:FlxColor = 0xFFFFFFFF;
	public static var sliderKnobPress:FlxColor = 0xFF808080;
	public static var sliderValueText:FlxColor = 0xFFD6E8FF;
	public static var switchOff:FlxColor = 0xFF666666;
	public static var switchOn:FlxColor = 0xFF4CC2FF;
	public static var knob:FlxColor = 0xFFFFFFFF;

	/**
	 * 选项页预览层里"中性线条"的颜色。
	 * 判定条（HitErrorBar）的指针/中线/竖线原本是纯白，放在浅色页面上会看不见，
	 * 所以预览层会拿这个颜色给自己的实例重新着色（不影响游戏内那一个）。
	 */
	public static var previewLine:FlxColor = 0xFFFFFFFF;

	// ---------------------------------------------------------
	// 内部状态
	// ---------------------------------------------------------
	static var listeners:Array<Void->Void> = [];
	static var inited:Bool = false;

	/** 确保调色板已按当前 colorMode 初始化（幂等，可随意调用） */
	public static function ensure():Void
	{
		if (inited) return;
		inited = true;
		applyPalette();
	}

	/** 重新读取 ClientPrefs.data.colorMode，刷新调色板并通知所有监听者 */
	public static function refresh():Void
	{
		inited = true;
		applyPalette();
		version++;

		for (fn in listeners.copy())
			if (fn != null) fn();
	}

	public static function isLightMode():Bool
	{
		ensure();
		return isLight;
	}

	/** 设置模式（'dark' / 'white'，'light' 亦可），并立即刷新界面 */
	public static function setMode(mode:String, save:Bool = true):Void
	{
		ClientPrefs.data.colorMode = normalize(mode);
		if (save) ClientPrefs.saveSettings();
		refresh();
	}

	/** 深色 <-> 浅色 互换 */
	public static function toggle(save:Bool = true):Void
	{
		setMode(isLight ? DARK : LIGHT, save);
	}

	/** 注册主题变化回调（界面重建用） */
	public static function addListener(fn:Void->Void):Void
	{
		if (fn == null) return;
		if (listeners.indexOf(fn) < 0) listeners.push(fn);
	}

	public static function removeListener(fn:Void->Void):Void
	{
		if (fn == null) return;
		listeners.remove(fn);
	}

	// ---------------------------------------------------------
	// 悬停 / 按下的通用提亮压暗
	// 浅色模式下改成"压暗"，避免越点越白看不出反馈
	// ---------------------------------------------------------
	public static function hoverTint(c:FlxColor):FlxColor
	{
		return isLight
			? FlxColor.interpolate(c, 0xFF000000, 0.08)
			: FlxColor.interpolate(c, 0xFFFFFFFF, 0.15);
	}

	public static function pressTint(c:FlxColor):FlxColor
	{
		return FlxColor.interpolate(c, 0xFF000000, isLight ? 0.16 : 0.20);
	}

	// ---------------------------------------------------------
	// 内部
	// ---------------------------------------------------------
	/** 把 colorMode 归一到 'dark' / 'white' */
	public static function normalize(mode:String):String
	{
		if (mode == null) return DARK;
		var m = mode.trim().toLowerCase();
		return (m == LIGHT || m == 'light' || m == 'bright') ? LIGHT : DARK;
	}

	static function applyPalette():Void
	{
		var mode:String = (ClientPrefs.data != null) ? ClientPrefs.data.colorMode : DARK;
		isLight = (normalize(mode) == LIGHT);

		if (isLight) applyLight();
		else applyDark();

		// 强调色必须在明暗配色之后应用：applyDark/applyLight 不再写 accent 系列字段，
		// 否则切换深浅色会把用户自定义色冲回默认。
		applyAccent();
	}

	// ---------------------------------------------------------
	// 强调色派生
	// ---------------------------------------------------------
	static inline var DEFAULT_ACCENT:FlxColor = 0xFF4CC2FF;
	static inline var DEFAULT_ACCENT_HOVER:FlxColor = 0xFF67CBFF;

	/**
	 * 从一个主色派生出整套强调色。
	 * 明暗两套共用同一个用户色（不做暗色特判），只按 isLight 调整"混合到背景"的比例。
	 */
	static function applyAccent():Void
	{
		if (ClientPrefs.data == null) return;

		accent = sanitize(ClientPrefs.data.uiAccent, DEFAULT_ACCENT);
		accentHover = sanitize(ClientPrefs.data.uiAccentHover, DEFAULT_ACCENT_HOVER);

		accentPress = shade(accent, 0.22);
		accentDeep = shade(accent, 0.28);
		textOnAccent = contrastText(accent);

		sliderFill = accent;
		sliderKnob = accent;
		switchOn = accent;
		// 旋钮悬停：暗色提亮到白，浅色压暗一档
		sliderKnobHover = isLight ? shade(accent, 0.2) : 0xFFFFFFFF;
		// 滑块数值文字：浅色直接用正文色，暗色用主色混白，保持同一色相
		sliderValueText = isLight ? textPrimary : FlxColor.interpolate(accent, 0xFFFFFFFF, 0.72);

		// 选中行 / 下拉项底色：往当前面板底色里混一点主色，暗色也能看出色相
		var panelBase:FlxColor = isLight ? 0xFFFFFFFF : 0xFF2B2B2B;
		navItemActive = FlxColor.interpolate(isLight ? 0xFFF0F0F0 : 0xFF2B2B2B, accent, isLight ? 0.16 : 0.12);
		popupItem = FlxColor.interpolate(panelBase, accent, isLight ? 0.08 : 0.10);
	}

	/** 0 视为"没设置"，回落默认；顺手把 alpha 补成不透明 */
	static inline function sanitize(v:FlxColor, def:FlxColor):FlxColor
		return (v == 0) ? def : (v | 0xFF000000);

	/** 往黑色插值，amt 是压暗强度（0~1） */
	static inline function shade(c:FlxColor, amt:Float):FlxColor
		return FlxColor.interpolate(c, 0xFF000000, amt);

	/**
	 * 强调色底上的文字色：按感知亮度自动选黑/白。
	 * 默认阈值 186 是为了让默认色 #4CC2FF（亮度 165.7）仍取白字，保持现有观感。
	 * 色块预览这类"大面积纯色"传更低的阈值，更早转黑字。
	 */
	public static function contrastText(c:FlxColor, threshold:Float = 186):FlxColor
	{
		var r:Int = (c >> 16) & 0xFF;
		var g:Int = (c >> 8) & 0xFF;
		var b:Int = c & 0xFF;
		var lum:Float = 0.299 * r + 0.587 * g + 0.114 * b;
		return lum > threshold ? 0xFF000000 : 0xFFFFFFFF;
	}

	static function applyDark():Void
	{
		windowBG = 0xFF000000;
		overlay = 0xFF000000;
		overlayAlpha = 0.5;
		mask = 0xFF000000;

		sidebar = 0xFF2B2B2B;
		divider = 0xFF3F3F3F;
		base = 0xFF1F1F1F;

		card = 0xFF0A0A0A;
		cardHover = 0xFF2E2E2E;
		cardPress = 0xFF454545;

		navItem = 0xFF2B2B2B;
		navItemHover = 0xFF3A3A3A;
		navItemPress = 0xFF222222;

		control = 0xFF3A3A3A;
		controlHover = 0xFF4A4A4A;
		controlPress = 0xFF2B2B2B;

		popup = 0xFF2B2B2B;

		searchBG = 0xFF1F1F1F;
		searchBGFocus = 0xFF2B2B2B;
		searchBorder = 0xFF5A5A5A;
		searchBorderHover = 0xFF8A8A8A;
		searchText = 0xFFFFFFFF;
		searchHint = 0xFF9A9A9A;

		icon = 0xFFCCCCCC;

		toast = 0xFF14406F;
		toastBarTrack = 0xFF0A2A4C;

		textPrimary = 0xFFFFFFFF;
		textSecondary = 0xFFAAAAAA;
		textMuted = 0xFFE0E0E0;

		danger = 0xFFFF6363;
		dangerBase = 0xFF5A2B2B;
		dangerHover = 0xFF7A3A3A;
		dangerPress = 0xFF3A1F1F;

		sliderTrack = 0xFF363535;
		sliderTrackAlpha = 0.4;
		sliderKnobPress = 0xFF808080;
		switchOff = 0xFF666666;
		knob = 0xFFFFFFFF;
		previewLine = 0xFFFFFFFF;
	}

	static function applyLight():Void
	{
		windowBG = 0xFFFAFAFA;
		overlay = 0xFFFFFFFF;
		overlayAlpha = 0.35;
		mask = 0xFFFFFFFF;

		sidebar = 0xFFF0F0F0;
		divider = 0xFFDCDCDC;
		base = 0xFFE6E6E6;

		card = 0xFFFFFFFF;
		cardHover = 0xFFEDEDED;
		cardPress = 0xFFE0E0E0;

		navItem = 0xFFF0F0F0;
		navItemHover = 0xFFE4E4E4;
		navItemPress = 0xFFD6D6D6;

		// 浅色下按钮用浅灰而不是纯白：白底页面（0xFAFAFA）上纯白按钮完全看不出边界，
		// 只能靠描边撑，视觉上就是"没有按钮"。三档灰度保持 常态 > 悬停 > 按下。
		control = 0xFFF0F0F0;
		controlHover = 0xFFE6E6E6;
		controlPress = 0xFFDADADA;

		popup = 0xFFFFFFFF;

		searchBG = 0xFFFFFFFF;
		searchBGFocus = 0xFFFFFFFF;
		searchBorder = 0xFF8A8A8A;
		searchBorderHover = 0xFF5A5A5A;
		searchText = 0xFF1B1B1B;
		searchHint = 0xFF767676;

		icon = 0xFF5A5A5A;

		toast = 0xFF14406F;
		toastBarTrack = 0xFF0A2A4C;

		textPrimary = 0xFF1B1B1B;
		textSecondary = 0xFF5A5A5A;
		textMuted = 0xFF2B2B2B;

		danger = 0xFFC42B1C;
		dangerBase = 0xFFFDE7E9;
		dangerHover = 0xFFF5D3D6;
		dangerPress = 0xFFEDC0C4;

		sliderTrack = 0xFFBDBDBD;
		sliderTrackAlpha = 0.5;
		sliderKnobPress = 0xFF8A8A8A;
		switchOff = 0xFF9A9A9A;
		knob = 0xFFFFFFFF;
		previewLine = 0xFF3A3A3A;
	}
}
