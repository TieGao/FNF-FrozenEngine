package states.editors.content;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import backend.ui.PsychUIButton;
import backend.ui.PsychUICheckBox;
import backend.ui.PsychUIEventHandler;
import backend.ui.Win8DropDown;
import backend.Language;

/**
 * 转换结果，由 onConfirm 回传。
 * 导入用 action/diff/convertKeys/targetKeys/extractAudio，导出只用 action/format/diff。
 */
typedef ChartConvertOptions =
{
	var action:Int;
	var format:Null<String>; // 导出目标格式；导入时为 null
	var diff:String;
	var convertKeys:Bool;
	var targetKeys:Int;
	var extractAudio:Bool;
}

/**
 * 通用谱面导入/导出对话框（双向共用一个界面）。
 * 导入：StepMania(.sm/.ssc)、osu!mania(.osu/.osz)、Quaver(.qua/.qp)、MIDI(.mid)、Malody(.mc)
 *   曲名/格式提示 + 难度选择（多难度时）+ 目标键数转换 + .osz 音频提取 + 载入编辑器/保存 JSON 两种去向
 * 导出：StepMania(.sm/.ssc)、osu!mania(.osu)、Quaver(.qua)
 *
 * 交互约定：
 *  - BACK / Esc：先收起展开的下拉；没有展开的下拉时才关窗（等同取消）
 *  - 任一下拉展开时，其余按钮/复选框/下拉全部挂起（防点击穿透），展开的那个保持可交互
 *  - 高度按真实文本高度算，不写死数字
 */
class ChartImportDialog extends MusicBeatSubstate implements PsychUIEventHandler.PsychUIEvent
{
	// 对话框模式
	public static inline var MODE_IMPORT:Int = 0;
	public static inline var MODE_EXPORT:Int = 1;

	// options.action 的取值
	public static inline var ACTION_LOAD:Int = 0;   // 导入：载入编辑器
	public static inline var ACTION_SAVE:Int = 1;   // 导入：保存为 Psych JSON
	public static inline var ACTION_EXPORT:Int = 2; // 导出模式固定回传

	public var onConfirm:Null<ChartConvertOptions->Void> = null;
	public var onCancel:Null<Void->Void> = null;

	// UI 元素
	private var bg:FlxSprite;
	private var titleText:FlxText;
	private var infoText:FlxText;
	private var mode:Int;

	// 导入相关
	private var convertKeysCheck:PsychUICheckBox;
	private var targetKeysLabel:FlxText;
	private var targetKeysDropDown:Win8DropDown;
	private var diffDropDown:Win8DropDown;
	private var extractAudioCheck:PsychUICheckBox;
	private var diffs:Array<String>;
	private var formatLabel:String;
	private var sourceFormat:String;
	private var songTitle:String;

	// 导出相关
	private var formatDropDown:Win8DropDown;
	private var difficultyDropDown:Win8DropDown;
	private var exportFormats:Array<String>;

	private var cancelBtn:PsychUIButton;

	// 下拉弹层的最高层容器（create 末尾 add，画在所有按钮之上）
	private var topLayer:FlxSpriteGroup;
	// 全部下拉：update 里查"有没有展开的"，展开时挂起其它交互组件
	private var dropdowns:Array<Win8DropDown> = [];
	// 下拉以外的交互组件（按钮 / 复选框），展开时统一挂起
	private var clickables:Array<FlxSpriteGroup> = [];

	// 检测到的键数（导入时）
	private var detectedKeys:Int;
	// 当前歌曲的键数（导出时）
	private var currentKeys:Int;

	// 版面量测结果（create 里算好，内容区构建函数直接用）
	private var infoMsg:String = '';
	private var infoH:Int = 0;
	private var hintMsg:String = '';
	private var hintH:Int = 0;

	// 关闭语义：确认按钮先把 confirmed 置 true，close() 据此决定要不要回调 onCancel
	private var confirmed:Bool = false;
	private var cancelFired:Bool = false;

	// 对话框尺寸
	private static inline var DIALOG_WIDTH:Int = 540;
	private static inline var PADDING:Int = 24;
	private static inline var BUTTON_WIDTH:Int = 170;
	private static inline var BUTTON_HEIGHT:Int = 32;
	private static inline var CANCEL_HEIGHT:Int = 28;
	private static inline var DROPDOWN_WIDTH:Int = 220;
	private static inline var INFO_SIZE:Int = 16;
	private static inline var HINT_SIZE:Int = 13;
	private static var EXPORT_DIFFS:Array<String> = ['Beginner', 'Easy', 'Medium', 'Hard', 'Challenge', 'Edit'];

	/**
	 * @param mode MODE_IMPORT 或 MODE_EXPORT
	 * @param detectedKeys 导入时检测到的源键数
	 * @param currentKeys 导出时当前歌曲的键数
	 * @param diffs 导入时源文件的难度列表
	 * @param formatLabel 导入时源格式显示名（如 'osu!mania (.osu)'）
	 * @param sourceFormat 导入时源格式 tag（如 'osz'），用于决定是否显示音频提取选项
	 * @param songTitle 导入时源曲名（可为空；'Unknown' 视为没有）
	 */
	public function new(mode:Int, ?detectedKeys:Int = 4, ?currentKeys:Int = 4, ?diffs:Array<String> = null, ?formatLabel:String = '',
			?sourceFormat:String = '', ?songTitle:String = '')
	{
		super();
		this.mode = mode;
		this.detectedKeys = detectedKeys;
		this.currentKeys = currentKeys;
		this.diffs = (diffs != null && diffs.length > 0) ? diffs : ['default'];
		this.formatLabel = formatLabel;
		this.sourceFormat = sourceFormat;
		this.songTitle = songTitle;
		this.exportFormats = ChartConvertCore.EXPORT_FORMATS;
	}

	override function create()
	{
		persistentUpdate = false;
		persistentDraw = true;

		// 编辑器的 camUI 是最后加入的那台相机（ChartMinimap、各面板都画在它上面）。
		// 弹窗不设相机会画默认相机（主相机），被 camUI 整层盖住 —— 谱面缩略图浮到
		// 弹窗上面就是这个原因。对齐到最后一台相机后 substate 后于父 state 绘制，
		// 弹窗必然盖过小地图（BasePrompt / ChartSourceSelectSubstate 同款做法）。
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		var showAudioOption:Bool = (mode == MODE_IMPORT && sourceFormat == 'osz');
		var showDiffOption:Bool = (mode == MODE_IMPORT) ? (diffs.length > 1) : true;

		// 先把文本内容与真实高度算出来，再决定对话框多高（曲名/格式/难度都可能多一行）
		infoMsg = buildInfoText(showDiffOption);
		hintMsg = buildHintText();
		infoH = measureTextHeight(infoMsg, INFO_SIZE);
		hintH = measureTextHeight(hintMsg, HINT_SIZE);
		var dialogHeight:Int = contentHeight(showDiffOption, showAudioOption);

		// 背景半透明遮罩：1×1 拉伸（整屏 makeGraphic 会真分配一张全屏位图）
		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0.6;
		add(cam(bg));

		// 对话框背景
		var boxBg:FlxSprite = new FlxSprite().makeGraphic(DIALOG_WIDTH, dialogHeight, FlxColor.fromString('0xFF2A2A2A'));
		boxBg.screenCenter();

		// 边框
		var border:FlxSprite = new FlxSprite(boxBg.x - 2, boxBg.y - 2).makeGraphic(DIALOG_WIDTH + 4, dialogHeight + 4, FlxColor.fromString('0xFF444444'));
		add(cam(border));
		add(cam(boxBg));

		var centerX:Float = boxBg.x + DIALOG_WIDTH / 2;
		var currentY:Float = boxBg.y + PADDING;

		// 标题
		var titleTextStr:String = (mode == MODE_IMPORT)
			? Language.getPhrase('chart_import_title', 'Import Chart')
			: Language.getPhrase('chart_export_title', 'Export Chart');

		titleText = makeText(0, currentY, DIALOG_WIDTH, titleTextStr, 28, FlxColor.WHITE, CENTER);
		titleText.screenCenter(X);
		currentY += 44;

		// 分隔线
		var divider1:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF555555'));
		add(cam(divider1));
		currentY += 16;

		if(mode == MODE_IMPORT)
			createImportUI(boxBg, centerX, currentY, showDiffOption, showAudioOption);
		else
			createExportUI(boxBg, centerX, currentY);

		// 取消按钮 - 底部居中（onCancel 由 close() 统一触发，这里只管关）
		var cancelLabel:String = Language.getPhrase('chart_convert_cancel', 'Cancel');
		cancelBtn = new PsychUIButton(0, boxBg.y + dialogHeight - PADDING - CANCEL_HEIGHT, cancelLabel, function()
		{
			close();
		});
		cancelBtn.normalStyle.bgColor = FlxColor.fromString('0xFFEF4444');
		cancelBtn.text.font = Paths.font('vcr.ttf');
		cancelBtn.normalStyle.textColor = FlxColor.WHITE;
		cancelBtn.resize(120, CANCEL_HEIGHT);
		cancelBtn.x = centerX - cancelBtn.width / 2;
		add(cam(cancelBtn));
		clickables.push(cancelBtn);

		// 最高层容器：下拉弹层挂这里，保证展开时画在对话框所有按钮之上
		// （旧 PsychUIDropDownMenu 的弹层是对话框普通成员，会被后加的按钮盖住）
		topLayer = new FlxSpriteGroup();
		topLayer.scrollFactor.set();
		topLayer.cameras = cameras;
		add(topLayer);
		for(dd in dropdowns)
			dd.attachPopup(topLayer, cameras[0]);

		// 两个导入下拉是并列的：目标键数只有在勾了"转换键数"时才有意义
		syncTargetKeysState();

		super.create();
	}

	// =========================================================
	// 文本 / 尺寸
	// =========================================================

	/**
	 * 成员统一设 UI 相机再挂进对话框：交互组件 update 期的默认相机解析不到 camUI，必须显式下发。
	 * 约束写 FlxSprite 而不是 FlxBasic —— 本工程 import.hx 没有 import flixel.FlxBasic，
	 * 写 FlxBasic 会直接 "Type not found"（按钮/复选框/下拉的基类也都是 FlxSpriteGroup）。
	 */
	private function cam<T:FlxSprite>(obj:T):T
	{
		obj.scrollFactor.set();
		obj.cameras = cameras;
		return obj;
	}

	/**
	 * 统一创建 vcr.ttf 文本：抗锯齿跟随 ClientPrefs.data.antialiasing。
	 * 不设的话走 flixel 默认的 ADVANCED + sharpness 400 锐利档，等宽字体小字号下边缘毛刺明显。
	 */
	private function makeText(x:Float, y:Float, width:Float, content:String, size:Int, color:FlxColor, align:FlxTextAlign):FlxText
	{
		var text:FlxText = new FlxText(x, y, width, content, size);
		text.setFormat(Paths.font('vcr.ttf'), size, color, align);
		text.antialiasing = ClientPrefs.data.antialiasing;
		add(cam(text));
		return text;
	}

	/**
	 * 用同字号的临时文本量出真实高度（含换行后的行数），末尾补 8px 与下一项隔开。
	 * 对话框高度全由它决定，别再写死 66 / 38 这种魔法数字。
	 */
	private function measureTextHeight(msg:String, size:Int):Int
	{
		var probe:FlxText = new FlxText(0, 0, DIALOG_WIDTH - PADDING * 2, msg, size);
		probe.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, CENTER);
		var h:Int = Std.int(probe.height) + 8;
		probe.destroy();
		return (h < size + 12) ? size + 12 : h; // 字体还没注册好时 height 可能为 0
	}

	/** 内容区高度，决定对话框整体高度（避免选项多时按钮和取消键重叠） */
	private function contentHeight(showDiffOption:Bool, showAudioOption:Bool):Int
	{
		var content:Int = infoH;
		if(mode == MODE_IMPORT)
		{
			if(showDiffOption) content += 44;
			content += 36 + 48; // 键数复选框 + 目标键数
			if(showAudioOption) content += 36;
			content += hintH;
		}
		else
		{
			content += 44 + 48; // 格式 + 难度名
			content += hintH;
		}
		content += 18; // 分隔线
		return PADDING + 44 + 16 + content + BUTTON_HEIGHT + 12 + CANCEL_HEIGHT + PADDING;
	}

	/** 信息区文本：导入显示曲名 / 源格式 / 源键数，导出显示当前键数 */
	private function buildInfoText(showDiffOption:Bool):String
	{
		if(mode == MODE_EXPORT)
			return Language.getPhrase('chart_export_info',
				'Export current chart to an external format.\nCurrent key count: {1}K ({2} key mania)',
				[Std.string(currentKeys), Std.string(currentKeys - 1)]);

		var head:String = '';
		if(songTitle != null && songTitle.length > 0 && songTitle != 'Unknown')
			head += songTitle + '\n';
		if(formatLabel != null && formatLabel.length > 0)
			head += formatLabel + '\n';

		return Language.getPhrase('chart_import_detected',
			'{1}Detected: {2}K ({3} key mania)\nChoose difficulty and target key count.',
			[head, Std.string(detectedKeys), Std.string(detectedKeys - 1)]);
	}

	private function buildHintText():String
	{
		if(mode == MODE_EXPORT)
			return Language.getPhrase('chart_export_hint',
				'Note: .sm is widely compatible, .ssc keeps labels and BPM changes.\n.osu and .qua export the player side only.');

		return Language.getPhrase('chart_import_hint',
			'Note: Converting key counts will remap notes to the nearest column.\nHold notes will be preserved when possible.');
	}

	// =========================================================
	// 导入 UI
	// =========================================================

	private function createImportUI(boxBg:FlxSprite, centerX:Float, startY:Float, showDiffOption:Bool, showAudioOption:Bool):Void
	{
		var currentY:Float = startY;

		// 曲名 / 格式 / 键数信息
		infoText = makeText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2, infoMsg, INFO_SIZE,
			FlxColor.fromString('0xFFCCCCCC'), CENTER);
		currentY += infoH;

		// 难度选择（单难度文件不显示）
		if(showDiffOption)
		{
			makeText(centerX - 160, currentY + 6, 120,
				Language.getPhrase('chart_difficulty', 'Difficulty:'), 16, FlxColor.WHITE, LEFT);

			diffDropDown = addDropDown(centerX - 20, currentY, diffs.copy());
			diffDropDown.selectedIndex = 0;
			currentY += 44;
		}

		// 转换键数复选框（勾选状态直接决定下面目标键数下拉是否可用）
		convertKeysCheck = new PsychUICheckBox(centerX - 140, currentY,
			Language.getPhrase('chart_convert_keys', 'Convert to different key count'), 220, syncTargetKeysState);
		convertKeysCheck.checked = (detectedKeys >= 7);
		convertKeysCheck.text.font = Paths.font('vcr.ttf');
		add(cam(convertKeysCheck));
		clickables.push(convertKeysCheck);
		currentY += 36;

		// 目标键数下拉菜单
		targetKeysLabel = makeText(centerX - 160, currentY + 6, 120,
			Language.getPhrase('chart_target_keys', 'Target Keys:'), 16, FlxColor.WHITE, LEFT);

		var keyOptions:Array<String> = [];
		for(i in 4...17) // 4-16K
		{
			var label:String = Std.string(i) + 'K (' + Std.string(i - 1) + ' key mania)';
			if(i == detectedKeys) label += ' (original)';
			keyOptions.push(label);
		}

		targetKeysDropDown = addDropDown(centerX - 20, currentY, keyOptions);
		var defaultIndex:Int = detectedKeys - 4;
		if(detectedKeys < 4) defaultIndex = 0;
		if(detectedKeys > 16) defaultIndex = 12;
		targetKeysDropDown.selectedIndex = defaultIndex;
		currentY += 48;

		// .osz 才有包内音频可提
		if(showAudioOption)
		{
			extractAudioCheck = new PsychUICheckBox(centerX - 170, currentY,
				Language.getPhrase('chart_import_extract_audio', 'Extract audio from pack (save mode)'), 300);
			extractAudioCheck.checked = true;
			extractAudioCheck.text.font = Paths.font('vcr.ttf');
			add(cam(extractAudioCheck));
			clickables.push(extractAudioCheck);
			currentY += 36;
		}

		// 转换提示
		makeText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2, hintMsg, HINT_SIZE,
			FlxColor.fromString('0xFF888888'), CENTER);
		currentY += hintH;

		// 分隔线
		var divider2:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF444444'));
		add(cam(divider2));
		currentY += 18;

		// 两个去向按钮：载入编辑器 / 保存 JSON
		var loadLabel:String = Language.getPhrase('chart_load_editor', 'Load to Editor');
		var loadBtn:PsychUIButton = new PsychUIButton(centerX - BUTTON_WIDTH - 10, currentY, loadLabel, function()
		{
			confirm(ACTION_LOAD);
		});
		loadBtn.normalStyle.bgColor = FlxColor.fromString('0xFF3B82F6');
		loadBtn.text.font = Paths.font('vcr.ttf');
		loadBtn.normalStyle.textColor = FlxColor.WHITE;
		loadBtn.resize(BUTTON_WIDTH, BUTTON_HEIGHT);
		add(cam(loadBtn));
		clickables.push(loadBtn);

		var saveLabel:String = Language.getPhrase('chart_save_json', 'Save JSON');
		var saveBtn:PsychUIButton = new PsychUIButton(centerX + 10, currentY, saveLabel, function()
		{
			confirm(ACTION_SAVE);
		});
		saveBtn.normalStyle.bgColor = FlxColor.fromString('0xFF22C55E');
		saveBtn.text.font = Paths.font('vcr.ttf');
		saveBtn.normalStyle.textColor = FlxColor.WHITE;
		saveBtn.resize(BUTTON_WIDTH, BUTTON_HEIGHT);
		add(cam(saveBtn));
		clickables.push(saveBtn);
	}

	/** 没勾"转换键数"时目标键数没有意义：灰掉并禁止展开 */
	private function syncTargetKeysState():Void
	{
		if(targetKeysDropDown == null) return;
		var on:Bool = (convertKeysCheck != null && convertKeysCheck.checked);
		targetKeysDropDown.enabled = on;
		if(targetKeysLabel != null)
			targetKeysLabel.color = on ? FlxColor.WHITE : FlxColor.fromString('0xFF666666');
	}

	// =========================================================
	// 导出 UI
	// =========================================================

	private function createExportUI(boxBg:FlxSprite, centerX:Float, startY:Float):Void
	{
		var currentY:Float = startY;

		// 信息文本
		infoText = makeText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2, infoMsg, INFO_SIZE,
			FlxColor.fromString('0xFFCCCCCC'), CENTER);
		currentY += infoH;

		// 格式选择
		makeText(centerX - 160, currentY + 6, 100,
			Language.getPhrase('chart_export_format', 'Format:'), 16, FlxColor.WHITE, LEFT);

		var formatOptions:Array<String> = [for(fmt in exportFormats) ChartConvertCore.FORMAT_LABELS.get(fmt) ?? fmt];
		formatDropDown = addDropDown(centerX - 20, currentY, formatOptions);
		formatDropDown.selectedIndex = 0;
		currentY += 44;

		// 难度选择
		makeText(centerX - 160, currentY + 6, 100,
			Language.getPhrase('chart_export_difficulty', 'Difficulty:'), 16, FlxColor.WHITE, LEFT);

		difficultyDropDown = addDropDown(centerX - 20, currentY, EXPORT_DIFFS.copy());
		difficultyDropDown.selectedIndex = 4; // 默认 Challenge
		currentY += 48;

		// 导出选项提示
		makeText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2, hintMsg, HINT_SIZE,
			FlxColor.fromString('0xFF888888'), CENTER);
		currentY += hintH;

		// 分隔线
		var divider2:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF444444'));
		add(cam(divider2));
		currentY += 18;

		// 导出按钮
		var exportLabel:String = Language.getPhrase('chart_export', 'Export');
		var exportBtn:PsychUIButton = new PsychUIButton(centerX - 90, currentY, exportLabel, function()
		{
			confirm(ACTION_EXPORT);
		});
		exportBtn.normalStyle.bgColor = FlxColor.fromString('0xFF22C55E');
		exportBtn.text.font = Paths.font('vcr.ttf');
		exportBtn.normalStyle.textColor = FlxColor.WHITE;
		exportBtn.resize(180, BUTTON_HEIGHT);
		add(cam(exportBtn));
		clickables.push(exportBtn);
	}

	// =========================================================
	// 下拉 / 选项
	// =========================================================

	/** 建 Win8 下拉：挂相机并登记（弹层延后由 create 末尾统一 attach 到 topLayer） */
	private function addDropDown(x:Float, y:Float, opts:Array<String>):Win8DropDown
	{
		var dd:Win8DropDown = new Win8DropDown(x, y, DROPDOWN_WIDTH, opts, function(id:Int, val:String) {});
		add(cam(dd));
		dropdowns.push(dd);
		return dd;
	}

	private function selectedDiff():String
	{
		if(diffDropDown != null)
			return diffs[diffDropDown.selectedIndex] ?? diffs[0];
		return diffs[0];
	}

	private function buildOptions(action:Int):ChartConvertOptions
	{
		var convertKeys:Bool = (convertKeysCheck != null && convertKeysCheck.checked);
		return {
			action: action,
			format: (mode == MODE_IMPORT || formatDropDown == null) ? null : exportFormats[formatDropDown.selectedIndex],
			diff: (mode == MODE_IMPORT) ? selectedDiff() : EXPORT_DIFFS[difficultyDropDown.selectedIndex],
			convertKeys: convertKeys,
			targetKeys: (targetKeysDropDown != null) ? targetKeysDropDown.selectedIndex + 4 : detectedKeys,
			extractAudio: (extractAudioCheck != null && extractAudioCheck.checked)
		};
	}

	/**
	 * 确认出口：先把 confirmed 置位（onConfirm 里可能开新弹窗/原生文件对话框，
	 * 期间本弹窗的 close() 不能再当成"取消"），再回调、再关。
	 */
	private function confirm(action:Int):Void
	{
		var opts:ChartConvertOptions = buildOptions(action);
		confirmed = true;
		if(onConfirm != null) onConfirm(opts);
		close();
	}

	/** 取消只回调一次：Esc / 取消按钮 / 任何 close() 路径都走这里 */
	override public function close():Void
	{
		if(!confirmed && !cancelFired)
		{
			cancelFired = true;
			if(onCancel != null) onCancel();
		}
		super.close();
	}

	// =========================================================
	// 交互
	// =========================================================

	override public function update(elapsed:Float):Void
	{
		// 任一下拉展开时挂起对话框里其它交互组件（按钮 / 复选框 / 兄弟下拉），
		// 防止点击穿透：弹层只是画在 topLayer 上，底下组件的命中判定照常触发。
		// ⚠️ 展开的那个下拉必须保持 active —— 否则它自己收不到"选项点击 / 点外面关闭"，
		//    弹层会永远挂在屏幕上（旧版 for 循环把包括自己在内的全部组件都设成 inactive）。
		var openDD:Win8DropDown = null;
		for(dd in dropdowns)
			if(dd.isOpen) { openDD = dd; break; }

		for(dd in dropdowns)
		{
			var shouldBeActive:Bool = (openDD == null) || (dd == openDD);
			if(dd.active != shouldBeActive)
			{
				dd.active = shouldBeActive;
				if(!shouldBeActive) dd.clearInputState();
			}
		}
		for(c in clickables)
			if(c != null) c.active = (openDD == null);

		if(controls.BACK)
		{
			// 有展开的下拉先收下拉，再按一次才关窗（与原生下拉行为一致）
			if(openDD != null) { openDD.closeList(); return; }
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			close();
			return;
		}

		super.update(elapsed);
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		// 处理 UI 事件
	}
}
