package states.editors.content;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import backend.ui.PsychUIButton;
import backend.ui.PsychUICheckBox;
import backend.ui.PsychUIDropDownMenu;
import backend.ui.PsychUIEventHandler;
import backend.Language;

/**
 * 通用谱面导入/导出对话框
 * 导入：StepMania(.sm/.ssc)、osu!mania(.osu/.osz)、Quaver(.qua/.qp)、MIDI(.mid)、Malody(.mc)
 *   —— 难度选择（多难度时）+ 目标键数转换 + 载入编辑器/保存 JSON 两种去向
 * 导出：StepMania(.sm/.ssc)
 */
class ChartImportDialog extends MusicBeatSubstate implements PsychUIEventHandler.PsychUIEvent
{
	// 对话框模式
	public static inline var MODE_IMPORT:Int = 0;
	public static inline var MODE_EXPORT:Int = 1;

	// onConfirm 回传的动作类型
	public static inline var ACTION_LOAD:Int = 0;   // 导入：载入编辑器
	public static inline var ACTION_SAVE:Int = 1;   // 导入：保存为 Psych JSON
	public static inline var ACTION_EXPORT:Int = 2; // 导出模式固定回传

	// 导出目标格式
	public static inline var FORMAT_SM:String = "sm";
	public static inline var FORMAT_SSC:String = "ssc";

	// 回调函数: (动作类型, 格式, 是否转换键数, 目标键数, 源难度/导出难度名)
	public var onConfirm:Null<Int->String->Bool->Int->String->Void> = null;
	public var onCancel:Null<Void->Void> = null;

	// UI 元素
	private var bg:FlxSprite;
	private var titleText:FlxText;
	private var infoText:FlxText;
	private var mode:Int;

	// 导入相关
	private var convertKeysCheck:PsychUICheckBox;
	private var targetKeysDropDown:PsychUIDropDownMenu;
	private var diffDropDown:PsychUIDropDownMenu;
	private var diffs:Array<String>;
	private var formatLabel:String;

	// 导出相关
	private var formatDropDown:PsychUIDropDownMenu;
	private var difficultyDropDown:PsychUIDropDownMenu;

	private var cancelBtn:PsychUIButton;

	// 检测到的键数（导入时）
	private var detectedKeys:Int;
	// 当前歌曲的键数（导出时）
	private var currentKeys:Int;

	// 对话框尺寸
	private static inline var DIALOG_WIDTH:Int = 540;
	private static inline var DIALOG_HEIGHT:Int = 420;
	private static inline var PADDING:Int = 24;
	private static inline var BUTTON_WIDTH:Int = 170;
	private static inline var BUTTON_HEIGHT:Int = 32;

	/**
	 * 创建对话框
	 * @param mode MODE_IMPORT 或 MODE_EXPORT
	 * @param detectedKeys 导入时检测到的源键数
	 * @param currentKeys 导出时当前歌曲的键数
	 * @param diffs 导入时源文件的难度列表
	 * @param formatLabel 导入时源格式显示名（如 'osu!mania (.osu)'）
	 */
	public function new(mode:Int, ?detectedKeys:Int = 4, ?currentKeys:Int = 4, ?diffs:Array<String> = null, ?formatLabel:String = '')
	{
		super();
		this.mode = mode;
		this.detectedKeys = detectedKeys;
		this.currentKeys = currentKeys;
		this.diffs = (diffs != null && diffs.length > 0) ? diffs : ['default'];
		this.formatLabel = formatLabel;
	}

	override function create()
	{
		persistentUpdate = false;
		persistentDraw = true;

		// 背景半透明遮罩
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.scrollFactor.set();
		add(bg);

		// 对话框背景
		var boxBg:FlxSprite = new FlxSprite().makeGraphic(DIALOG_WIDTH, DIALOG_HEIGHT, FlxColor.fromString('0xFF2A2A2A'));
		boxBg.screenCenter();
		boxBg.scrollFactor.set();

		// 边框
		var border:FlxSprite = new FlxSprite(boxBg.x - 2, boxBg.y - 2).makeGraphic(DIALOG_WIDTH + 4, DIALOG_HEIGHT + 4, FlxColor.fromString('0xFF444444'));
		border.scrollFactor.set();
		add(border);
		add(boxBg);

		var centerX:Float = boxBg.x + DIALOG_WIDTH / 2;
		var currentY:Float = boxBg.y + PADDING;

		// 标题
		var titleTextStr:String = (mode == MODE_IMPORT)
			? Language.getPhrase('chart_import_title', 'Import Chart')
			: Language.getPhrase('stepmania_export_title', 'Export to StepMania');

		titleText = new FlxText(0, currentY, DIALOG_WIDTH, titleTextStr, 28);
		titleText.screenCenter(X);
		titleText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER);
		titleText.scrollFactor.set();
		add(titleText);
		currentY += 44;

		// 分隔线
		var divider1:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF555555'));
		divider1.scrollFactor.set();
		add(divider1);
		currentY += 16;

		if(mode == MODE_IMPORT)
			createImportUI(boxBg, centerX, currentY);
		else
			createExportUI(boxBg, centerX, currentY);

		// 取消按钮 - 底部居中
		var cancelLabel:String = Language.getPhrase('stepmania_cancel', 'Cancel');
		cancelBtn = new PsychUIButton(0, boxBg.y + DIALOG_HEIGHT - PADDING - 28, cancelLabel, function()
		{
			if(onCancel != null) onCancel();
			close();
		});
		cancelBtn.normalStyle.bgColor = FlxColor.fromString('0xFFEF4444');
		cancelBtn.text.font = Paths.font('vcr.ttf');
		cancelBtn.normalStyle.textColor = FlxColor.WHITE;
		cancelBtn.resize(120, 28);
		cancelBtn.x = centerX - cancelBtn.width / 2;
		cancelBtn.scrollFactor.set();
		add(cancelBtn);

		super.create();
	}

	/**
	 * 创建导入 UI
	 */
	private function createImportUI(boxBg:FlxSprite, centerX:Float, startY:Float):Void
	{
		var currentY:Float = startY;

		// 格式与键数信息
		var formatLine:String = (formatLabel != null && formatLabel.length > 0) ? formatLabel + '\n' : '';
		var infoMsg:String = Language.getPhrase('chart_import_detected',
			'{1}Detected: {2}K ({3} key mania)\nChoose difficulty and target key count.',
			[formatLine, Std.string(detectedKeys), Std.string(detectedKeys - 1)]);

		infoText = new FlxText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2, infoMsg, 16);
		infoText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.fromString('0xFFCCCCCC'), CENTER);
		infoText.scrollFactor.set();
		add(infoText);
		currentY += 66;

		// 难度选择（单难度文件不显示）
		if(diffs.length > 1)
		{
			var diffLabel:FlxText = new FlxText(0, currentY + 4, 120,
				Language.getPhrase('chart_difficulty', 'Difficulty:'), 16);
			diffLabel.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE);
			diffLabel.x = centerX - 160;
			diffLabel.scrollFactor.set();
			add(diffLabel);

			diffDropDown = new PsychUIDropDownMenu(centerX - 20, currentY, diffs.copy(), function(id:Int, val:String) {});
			diffDropDown.selectedIndex = 0;
			diffDropDown.textObj.font = Paths.font('vcr.ttf');
			diffDropDown.scrollFactor.set();
			add(diffDropDown);
			currentY += 44;
		}

		// 转换键数复选框
		convertKeysCheck = new PsychUICheckBox(centerX - 140, currentY,
			Language.getPhrase('stepmania_convert_keys', 'Convert to different key count'), 220);
		convertKeysCheck.checked = (detectedKeys >= 7);
		convertKeysCheck.text.font = Paths.font('vcr.ttf');
		convertKeysCheck.scrollFactor.set();
		add(convertKeysCheck);
		currentY += 36;

		// 目标键数下拉菜单
		var targetLabel:FlxText = new FlxText(0, currentY + 4, 120,
			Language.getPhrase('stepmania_target_keys', 'Target Keys:'), 16);
		targetLabel.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE);
		targetLabel.x = centerX - 160;
		targetLabel.scrollFactor.set();
		add(targetLabel);

		var keyOptions:Array<String> = [];
		for(i in 4...17) // 4-16K
		{
			var label:String = Std.string(i) + 'K (' + Std.string(i - 1) + ' key mania)';
			if(i == detectedKeys) label += ' (original)';
			keyOptions.push(label);
		}

		targetKeysDropDown = new PsychUIDropDownMenu(centerX - 20, currentY, keyOptions, function(id:Int, val:String) {});
		var defaultIndex:Int = detectedKeys - 4;
		if(detectedKeys < 4) defaultIndex = 0;
		if(detectedKeys > 16) defaultIndex = 12;
		targetKeysDropDown.selectedIndex = defaultIndex;
		targetKeysDropDown.textObj.font = Paths.font('vcr.ttf');
		targetKeysDropDown.scrollFactor.set();
		add(targetKeysDropDown);
		currentY += 48;

		// 转换提示
		var hintText:FlxText = new FlxText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2,
			Language.getPhrase('stepmania_import_hint',
				'Note: Converting key counts will remap notes to the nearest column.\nHold notes will be preserved when possible.'),
			13);
		hintText.setFormat(Paths.font('vcr.ttf'), 13, FlxColor.fromString('0xFF888888'), CENTER);
		hintText.scrollFactor.set();
		add(hintText);
		currentY += 38;

		// 分隔线
		var divider2:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF444444'));
		divider2.scrollFactor.set();
		add(divider2);
		currentY += 18;

		// 两个去向按钮：载入编辑器 / 保存 JSON
		var loadLabel:String = Language.getPhrase('stepmania_load_editor', 'Load to Editor');
		var loadBtn:PsychUIButton = new PsychUIButton(centerX - BUTTON_WIDTH - 10, currentY + 8, loadLabel, function()
		{
			if(onConfirm != null)
			{
				onConfirm(ACTION_LOAD, FORMAT_SM, convertKeysCheck.checked, targetKeysDropDown.selectedIndex + 4, selectedDiff());
			}
			close();
		});
		loadBtn.normalStyle.bgColor = FlxColor.fromString('0xFF3B82F6');
		loadBtn.text.font = Paths.font('vcr.ttf');
		loadBtn.normalStyle.textColor = FlxColor.WHITE;
		loadBtn.resize(BUTTON_WIDTH, BUTTON_HEIGHT);
		loadBtn.scrollFactor.set();
		add(loadBtn);

		var saveLabel:String = Language.getPhrase('chart_save_json', 'Save JSON');
		var saveBtn:PsychUIButton = new PsychUIButton(centerX + 10, currentY + 8, saveLabel, function()
		{
			if(onConfirm != null)
			{
				onConfirm(ACTION_SAVE, FORMAT_SM, convertKeysCheck.checked, targetKeysDropDown.selectedIndex + 4, selectedDiff());
			}
			close();
		});
		saveBtn.normalStyle.bgColor = FlxColor.fromString('0xFF22C55E');
		saveBtn.text.font = Paths.font('vcr.ttf');
		saveBtn.normalStyle.textColor = FlxColor.WHITE;
		saveBtn.resize(BUTTON_WIDTH, BUTTON_HEIGHT);
		saveBtn.scrollFactor.set();
		add(saveBtn);
	}

	private function selectedDiff():String
	{
		if(diffDropDown != null)
			return diffs[diffDropDown.selectedIndex] ?? diffs[0];
		return diffs[0];
	}

	/**
	 * 创建导出 UI
	 */
	private function createExportUI(boxBg:FlxSprite, centerX:Float, startY:Float):Void
	{
		var currentY:Float = startY;

		// 信息文本
		var infoMsg:String = Language.getPhrase('stepmania_export_info',
			'Export current chart to StepMania format.\nCurrent key count: {1}K ({2} key mania)',
			[Std.string(currentKeys), Std.string(currentKeys - 1)]);

		infoText = new FlxText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2, infoMsg, 16);
		infoText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.fromString('0xFFCCCCCC'), CENTER);
		infoText.scrollFactor.set();
		add(infoText);
		currentY += 62;

		// 格式选择
		var formatLabel:FlxText = new FlxText(0, currentY + 4, 100,
			Language.getPhrase('stepmania_format', 'Format:'), 16);
		formatLabel.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE);
		formatLabel.x = centerX - 160;
		formatLabel.scrollFactor.set();
		add(formatLabel);

		formatDropDown = new PsychUIDropDownMenu(centerX - 20, currentY,
			['.sm (StepMania 4/5)', '.ssc (StepMania 5+)'],
			function(id:Int, val:String) {});
		formatDropDown.selectedIndex = 0;
		formatDropDown.textObj.font = Paths.font('vcr.ttf');
		formatDropDown.scrollFactor.set();
		add(formatDropDown);
		currentY += 44;

		// 难度选择
		var diffLabel:FlxText = new FlxText(0, currentY + 4, 100,
			Language.getPhrase('stepmania_difficulty', 'Difficulty:'), 16);
		diffLabel.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE);
		diffLabel.x = centerX - 160;
		diffLabel.scrollFactor.set();
		add(diffLabel);

		var diffOptions:Array<String> = ['Beginner', 'Easy', 'Medium', 'Hard', 'Challenge', 'Edit'];
		difficultyDropDown = new PsychUIDropDownMenu(centerX - 20, currentY, diffOptions,
			function(id:Int, val:String) {});
		difficultyDropDown.selectedIndex = 4; // 默认 Challenge
		difficultyDropDown.textObj.font = Paths.font('vcr.ttf');
		difficultyDropDown.scrollFactor.set();
		add(difficultyDropDown);
		currentY += 48;

		// 导出选项提示
		var hintText:FlxText = new FlxText(boxBg.x + PADDING, currentY, DIALOG_WIDTH - PADDING * 2,
			Language.getPhrase('stepmania_export_hint',
				'Note: .sm is widely compatible.\n.ssc supports more features like labels and multiple BPM changes.'),
			13);
		hintText.setFormat(Paths.font('vcr.ttf'), 13, FlxColor.fromString('0xFF888888'), CENTER);
		hintText.scrollFactor.set();
		add(hintText);
		currentY += 38;

		// 分隔线
		var divider2:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF444444'));
		divider2.scrollFactor.set();
		add(divider2);
		currentY += 18;

		// 导出按钮
		var exportLabel:String = Language.getPhrase('stepmania_export', 'Export');
		var exportBtn:PsychUIButton = new PsychUIButton(centerX - 90, currentY + 8, exportLabel, function()
		{
			if(onConfirm != null)
			{
				var format:String = (formatDropDown.selectedIndex == 0) ? FORMAT_SM : FORMAT_SSC;
				var diffOptions:Array<String> = ['Beginner', 'Easy', 'Medium', 'Hard', 'Challenge', 'Edit'];
				onConfirm(ACTION_EXPORT, format, false, currentKeys, diffOptions[difficultyDropDown.selectedIndex]);
			}
			close();
		});
		exportBtn.normalStyle.bgColor = FlxColor.fromString('0xFF22C55E');
		exportBtn.text.font = Paths.font('vcr.ttf');
		exportBtn.normalStyle.textColor = FlxColor.WHITE;
		exportBtn.resize(180, BUTTON_HEIGHT);
		exportBtn.scrollFactor.set();
		add(exportBtn);
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		// 处理 UI 事件
	}
}
