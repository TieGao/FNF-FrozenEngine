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
	public static var accent:FlxColor = 0xFF4CC2FF;
	public static var accentDeep:FlxColor = 0xFF0078D4;
	public static var icon:FlxColor = 0xFFCCCCCC;

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
		navItemActive = 0xFF3A3A3A;
		navItemPress = 0xFF222222;

		control = 0xFF3A3A3A;
		controlHover = 0xFF4A4A4A;
		controlPress = 0xFF2B2B2B;

		popup = 0xFF2B2B2B;
		popupItem = 0xFF3A3A3A;

		searchBG = 0xFF1F1F1F;
		searchBGFocus = 0xFF2B2B2B;
		searchBorder = 0xFF5A5A5A;
		searchBorderHover = 0xFF8A8A8A;
		searchText = 0xFFFFFFFF;
		searchHint = 0xFF9A9A9A;

		accent = 0xFF4CC2FF;
		accentDeep = 0xFF0078D4;
		icon = 0xFFCCCCCC;

		textPrimary = 0xFFFFFFFF;
		textSecondary = 0xFFAAAAAA;
		textMuted = 0xFFE0E0E0;
		textOnAccent = 0xFFFFFFFF;

		danger = 0xFFFF6363;
		dangerBase = 0xFF5A2B2B;
		dangerHover = 0xFF7A3A3A;
		dangerPress = 0xFF3A1F1F;

		sliderTrack = 0xFF363535;
		sliderTrackAlpha = 0.4;
		sliderFill = 0xFF0064FA;
		sliderKnob = 0xFF0064FA;
		sliderKnobHover = 0xFFFFFFFF;
		sliderKnobPress = 0xFF808080;
		sliderValueText = 0xFFD6E8FF;
		switchOff = 0xFF666666;
		switchOn = 0xFF4CC2FF;
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
		navItemActive = 0xFFDCE9F5;
		navItemPress = 0xFFD6D6D6;

		control = 0xFFFFFFFF;
		controlHover = 0xFFEDEDED;
		controlPress = 0xFFE0E0E0;

		popup = 0xFFFFFFFF;
		popupItem = 0xFFEAF2FB;

		searchBG = 0xFFFFFFFF;
		searchBGFocus = 0xFFFFFFFF;
		searchBorder = 0xFF8A8A8A;
		searchBorderHover = 0xFF5A5A5A;
		searchText = 0xFF1B1B1B;
		searchHint = 0xFF767676;

		accent = 0xFF0078D4;
		accentDeep = 0xFF0078D4;
		icon = 0xFF5A5A5A;

		textPrimary = 0xFF1B1B1B;
		textSecondary = 0xFF5A5A5A;
		textMuted = 0xFF2B2B2B;
		textOnAccent = 0xFFFFFFFF;

		danger = 0xFFC42B1C;
		dangerBase = 0xFFFDE7E9;
		dangerHover = 0xFFF5D3D6;
		dangerPress = 0xFFEDC0C4;

		sliderTrack = 0xFFBDBDBD;
		sliderTrackAlpha = 0.5;
		sliderFill = 0xFF0078D4;
		sliderKnob = 0xFF0078D4;
		sliderKnobHover = 0xFF005A9E;
		sliderKnobPress = 0xFF8A8A8A;
		sliderValueText = 0xFF1B1B1B;
		switchOff = 0xFF9A9A9A;
		switchOn = 0xFF0078D4;
		knob = 0xFFFFFFFF;
		previewLine = 0xFF3A3A3A;
	}
}
