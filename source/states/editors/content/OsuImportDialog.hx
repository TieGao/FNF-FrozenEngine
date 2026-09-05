package states.editors.content;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import backend.ui.PsychUIButton;
import backend.ui.PsychUICheckBox;
import backend.ui.PsychUIEventHandler;
import backend.Language;

/**
 * OSU 导入确认对话框，允许用户选择转换选项
 * 提供两种导入方式：加载到编辑器 或 保存为文件
 */
class OsuImportDialog extends MusicBeatSubstate implements PsychUIEventHandler.PsychUIEvent
{
    public static inline var ACTION_LOAD_TO_EDITOR:Int = 0;
    public static inline var ACTION_SAVE_TO_FILE:Int = 1;

    public var onConfirm:Null<Bool->Int->Void> = null; // 参数: 是否转换为4K, 操作类型 (0=加载到编辑器, 1=保存为文件)
    public var onCancel:Null<Void->Void> = null;

    private var bg:FlxSprite;
    private var titleText:FlxText;
    private var infoText:FlxText;
    private var convertTo4kCheck:PsychUICheckBox;
    private var loadToEditorBtn:PsychUIButton;
    private var saveToFileBtn:PsychUIButton;
    private var cancelBtn:PsychUIButton;

    private var detectedKeys:Int;
    
    // 对话框尺寸常量
    private static inline var DIALOG_WIDTH:Int = 520;
    private static inline var DIALOG_HEIGHT:Int = 340;
    private static inline var PADDING:Int = 24;
    private static inline var BUTTON_WIDTH:Int = 180;
    private static inline var BUTTON_HEIGHT:Int = 32;

    public function new(detectedKeys:Int)
    {
        super();
        this.detectedKeys = detectedKeys;
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

        // 对话框背景 - 更精致的颜色
        var boxBg:FlxSprite = new FlxSprite().makeGraphic(DIALOG_WIDTH, DIALOG_HEIGHT, FlxColor.fromString('0xFF2A2A2A'));
        boxBg.screenCenter();
        boxBg.scrollFactor.set();
        // 添加边框效果
        var border:FlxSprite = new FlxSprite(boxBg.x - 2, boxBg.y - 2).makeGraphic(DIALOG_WIDTH + 4, DIALOG_HEIGHT + 4, FlxColor.fromString('0xFF444444'));
        border.scrollFactor.set();
        add(border);
        add(boxBg);

        var centerX:Float = boxBg.x + DIALOG_WIDTH / 2;
        var currentY:Float = boxBg.y + PADDING;

        // 标题 - 居中，加粗
        titleText = new FlxText(0, currentY, DIALOG_WIDTH, 
            Language.getPhrase('osu_import_title', 'OSU Import Options'), 28);
        titleText.screenCenter(X);
        titleText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER);
        titleText.scrollFactor.set();
        add(titleText);
        currentY += 44;

        // 分隔线 - 标题下方
        var divider1:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF555555'));
        divider1.scrollFactor.set();
        add(divider1);
        currentY += 16;

        // 信息文本 - 居中对齐
        var infoMsg:String = '';
        if (detectedKeys >= 7) {
            infoMsg = Language.getPhrase('osu_import_convert_prompt', 
                'Detected: {1}K ({2} key mania)\nConvert to 4K (3 key mania)?',
                [Std.string(detectedKeys), Std.string(detectedKeys - 1)]);
        } else {
            infoMsg = Language.getPhrase('osu_import_keep_prompt',
                'Detected: {1}K ({2} key mania)\nKeeping original key count.',
                [Std.string(detectedKeys), Std.string(detectedKeys - 1)]);
        }

        infoText = new FlxText(0, currentY, DIALOG_WIDTH - PADDING * 2, infoMsg, 18);
        infoText.setFormat(null, 18, FlxColor.fromString('0xFFCCCCCC'), CENTER);
        infoText.scrollFactor.set();
        infoText.x = boxBg.x + PADDING;
        add(infoText);
        currentY += 68;

        // 转换复选框 (仅在键数 >= 7 时显示)
        if (detectedKeys >= 7) {
            convertTo4kCheck = new PsychUICheckBox(0, currentY, 
                Language.getPhrase('osu_import_convert_check', 'Convert to 4K (3 key mania)'), 240);
            convertTo4kCheck.checked = true;
            convertTo4kCheck.scrollFactor.set();
            convertTo4kCheck.x = centerX - convertTo4kCheck.width / 2;
            add(convertTo4kCheck);
            currentY += 42;
        } else {
            currentY += 12;
        }

        // 分隔线
        var divider2:FlxSprite = new FlxSprite(boxBg.x + 40, currentY).makeGraphic(DIALOG_WIDTH - 80, 1, FlxColor.fromString('0xFF444444'));
        divider2.scrollFactor.set();
        add(divider2);
        currentY += 18;

        // 操作提示 - 居中
        var actionLabel:FlxText = new FlxText(0, currentY, DIALOG_WIDTH, 
            Language.getPhrase('osu_import_action_label', '— Choose Action —'), 15);
        actionLabel.screenCenter(X);
        actionLabel.setFormat(null, 15, FlxColor.fromString('0xFF999999'), CENTER);
        actionLabel.scrollFactor.set();
        add(actionLabel);
        currentY += 28;

        // 按钮行 - 两个按钮对称居中
        var btnY:Float = currentY;
        var gap:Float = 20; // 两个按钮之间的间距

        // 加载到编辑器按钮 (左侧)
        var loadLabel:String = Language.getPhrase('osu_import_load_editor', 'Load to Editor');
        loadToEditorBtn = new PsychUIButton(0, btnY, loadLabel, function()
        {
            var convertTo4k:Bool = (convertTo4kCheck != null && convertTo4kCheck.checked);
            if (onConfirm != null) onConfirm(convertTo4k, ACTION_LOAD_TO_EDITOR);
            close();
        });
        loadToEditorBtn.normalStyle.bgColor = FlxColor.fromString('0xFF3B82F6'); // 蓝色
        loadToEditorBtn.normalStyle.textColor = FlxColor.WHITE;
        loadToEditorBtn.resize(BUTTON_WIDTH, BUTTON_HEIGHT);
        loadToEditorBtn.x = centerX - BUTTON_WIDTH - gap / 2;
        loadToEditorBtn.scrollFactor.set();
        add(loadToEditorBtn);

        // 保存到文件按钮 (右侧)
        var saveLabel:String = Language.getPhrase('osu_import_save_file', 'Save to File');
        saveToFileBtn = new PsychUIButton(0, btnY, saveLabel, function()
        {
            var convertTo4k:Bool = (convertTo4kCheck != null && convertTo4kCheck.checked);
            if (onConfirm != null) onConfirm(convertTo4k, ACTION_SAVE_TO_FILE);
            close();
        });
        saveToFileBtn.normalStyle.bgColor = FlxColor.fromString('0xFF22C55E'); // 绿色
        saveToFileBtn.normalStyle.textColor = FlxColor.WHITE;
        saveToFileBtn.resize(BUTTON_WIDTH, BUTTON_HEIGHT);
        saveToFileBtn.x = centerX + gap / 2;
        saveToFileBtn.scrollFactor.set();
        add(saveToFileBtn);
        currentY += BUTTON_HEIGHT + 16;

        // 取消按钮 - 居中，位于底部
        var cancelLabel:String = Language.getPhrase('osu_import_cancel', 'Cancel');
        cancelBtn = new PsychUIButton(0, boxBg.y + DIALOG_HEIGHT - PADDING - BUTTON_HEIGHT, cancelLabel, function()
        {
            if (onCancel != null) onCancel();
            close();
        });
        cancelBtn.normalStyle.bgColor = FlxColor.fromString('0xFFEF4444'); // 红色
        cancelBtn.normalStyle.textColor = FlxColor.WHITE;
        cancelBtn.resize(120, 28);
        cancelBtn.x = centerX - cancelBtn.width / 2;
        cancelBtn.scrollFactor.set();
        add(cancelBtn);

        super.create();
    }

    public function UIEvent(id:String, sender:Dynamic)
    {
        // 处理 UI 事件
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
    }
}