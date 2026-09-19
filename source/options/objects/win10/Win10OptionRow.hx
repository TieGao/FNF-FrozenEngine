package options.objects.win10;

import options.Option;
import options.Option.OptionType;
import shapeEx.Rect;

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

    /** 主题切换后重新套用配色（行被重建时无需调用） */
    public function refreshTheme():Void
    {
        if (title != null) title.color = UITheme.textPrimary;
        if (subLabel != null) subLabel.color = UITheme.textSecondary;
        if (bg != null) bg.color = UITheme.control;
    }
}