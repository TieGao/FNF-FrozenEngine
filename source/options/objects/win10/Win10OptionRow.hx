package options.objects.win10;

import options.psychoptions.PsychOption;
import options.psychoptions.PsychOption.OptionType;
import shapeEx.Rect;

class Win10OptionRow extends FlxSpriteGroup
{
    public var title:FlxText;
    public var desc:FlxText;
    public var widget:FlxSpriteGroup;
    public var option:PsychOption;
    public var bg:Rect;

    public var baseY:Float = 0;
    public var rowH:Float = 0;

    public function setRowMeta(baseY:Float, rowH:Float):Void
    {
        this.baseY = baseY;
        this.rowH = rowH;
    }

    public function new(x:Float, y:Float, w:Float, h:Float, opt:PsychOption, widget:FlxSpriteGroup)
    {
        super(x, y);
        this.option = opt;
        this.widget = widget;

        // 方角
        bg = new Rect(0, 0, w, h, 0, 0, 0x000000, 0.0);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        title = new FlxText(20, 10, w, opt.name, 18);
        title.setFormat(Paths.font('montserrat.ttf'), 18,
            0xFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
        title.borderStyle = NONE;
        title.antialiasing = ClientPrefs.data.antialiasing;
        add(title);

        if (widget != null)
        {
            widget.x = 20;
            widget.y = 56;
            add(widget);
        }
    }
}