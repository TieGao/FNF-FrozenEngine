package options.objects.win10;

import options.Option;
import options.Option.OptionType;
import options.objects.OptionWidgetFactory;
import shapeEx.Rect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class Win10OptionRow extends FlxSpriteGroup
{
    public var title:FlxText;
    public var desc:FlxText;
    /** 搜索结果显示时，行右侧标注该选项属于哪个子分类 */
    public var subLabel:FlxText;
    public var widget:FlxSpriteGroup;
    public var option:Option;
    public var bg:Rect;

    public var baseY:Float = 0;
    public var rowH:Float = 0;

    /**
     * 键盘选中态。整行铺一层 `UITheme.navItemActive` 底色 + 标题转强调色。
     *
     * 这里原本是 Win8CharmRow 私有的东西（Win8 面板要支持键盘，Win10 页只靠鼠标悬停），
     * 现在 Win10 的设置页也要键盘导航，就上提到基类共用 —— 免得两份实现漂移。
     * `bg` 默认 alpha = 0，不选中时整行是"隐形"的。
     */
    var selected:Bool = false;

    public function setRowMeta(baseY:Float, rowH:Float):Void
    {
        this.baseY = baseY;
        this.rowH = rowH;
    }

    public function new(x:Float, y:Float, w:Float, h:Float, opt:Option, widget:FlxSpriteGroup)
    {
        super(x, y);
        UITheme.ensure();

        this.option = opt;
        this.widget = widget;

        // 方角（默认全透明，配色跟随主题，方便以后开启行底色）
        bg = new Rect(0, 0, w, h, 0, 0, UITheme.control, 0.0);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        title = new FlxText(20, 10, w, opt.name, 18);
        title.setFormat(Paths.font('montserrat.ttf'), 18,
            UITheme.textPrimary, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        title.borderStyle = NONE;
        title.antialiasing = ClientPrefs.data.antialiasing;
        add(title);

        if (widget != null)
        {
            widget.x = 20;
            widget.y = 56;
            add(widget);
        }

        // 搜索时在行右侧标注子分类，方便判断这条结果来自哪里
        subLabel = new FlxText(0, 0, w - 40, '', 13);
        subLabel.setFormat(Paths.font('montserrat.ttf'), 13,
            UITheme.textSecondary, RIGHT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        subLabel.borderStyle = NONE;
        subLabel.antialiasing = ClientPrefs.data.antialiasing;
        subLabel.y = (h - subLabel.height) * 0.5;
        subLabel.visible = false;
        add(subLabel);
    }

    /** 设置右侧的子分类标注；传空串则隐藏 */
    public function setSubLabel(text:String):Void
    {
        if (subLabel == null) return;
        subLabel.text = (text == null) ? '' : text;
        subLabel.visible = subLabel.text.length > 0;
    }

    /**
     * 选中时是否给整行铺底色。
     *
     * - true（默认）：整行铺 UITheme.navItemActive + 标题转强调色。Win8 Charm 面板
     *   （Win8CharmRow）用这个 —— 面板窄，铺底色是主要的强调手段。
     * - false：不铺行底色，只把标题转强调色 + 让控件自身进入悬停态。Win10 设置页
     *   （OptionsPageState）用这个 —— 整行铺色太重，只亮文字和按钮更清爽。
     *
     * ⚠️ 调用方必须在**第一次 setSelected() 之前**设好（OptionsPageState 是建完行立刻设）。
     */
    public var highlightWholeRow:Bool = true;

    /**
     * 键盘选中该行：按 highlightWholeRow 走两套视觉之一。
     * - true：整行铺 UITheme.navItemActive 底色
     * - false：不铺底色，标题转强调色 + 控件进入悬停态
     */
    public function setSelected(v:Bool):Void
    {
        if (selected == v) return;
        selected = v;

        if (bg != null)
        {
            FlxTween.cancelTweensOf(bg);
            if (highlightWholeRow)
                FlxTween.tween(bg, {alpha: v ? 1 : 0}, 0.1, {ease: FlxEase.quadOut});
            else
                bg.alpha = 0;   // 不铺行底色：这一行的选中感全靠标题 + 控件表达
        }

        applySelectedColors();

        if (!highlightWholeRow)
            OptionWidgetFactory.setKeyboardHighlight(widget, v);
    }

    public function isSelected():Bool
        return selected;

    function applySelectedColors():Void
    {
        if (title != null)
            title.color = selected ? UITheme.accent : UITheme.textPrimary;
    }

    /** 主题切换后重新套用配色（行被重建时无需调用） */
    public function refreshTheme():Void
    {
        if (title != null) title.color = UITheme.textPrimary;
        if (subLabel != null) subLabel.color = UITheme.textSecondary;
        // 选中底色用 Win10 导航项的激活色：深色下是浅灰、浅色下是淡蓝，
        // 两种模式下都能看出"这一行被选中了"。alpha 默认 0，不影响普通行。
        if (bg != null) bg.color = UITheme.navItemActive;
        applySelectedColors();

        if (!highlightWholeRow)
            OptionWidgetFactory.setKeyboardHighlight(widget, selected);
    }
}