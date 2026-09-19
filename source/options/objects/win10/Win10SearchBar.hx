package options.objects.win10;

import backend.ui.PsychUIInputText;
import shapeEx.Rect;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

/**
 * Win10 风格搜索框
 * - 底部 1px 边框：悬停变灰白，聚焦变蓝 (#0078D4)
 * - 背景：#1F1F1F / 聚焦 #2B2B2B
 * - 支持 placeholder、清除按钮
 */
class Win10SearchBar extends FlxSpriteGroup
{
    // 配色统一走主题（深浅色切换由 UITheme 提供）
    inline function accentColor():Int return UITheme.accentDeep;          // 聚焦时的边框
    inline function borderIdle():Int return UITheme.searchBorder;
    inline function borderHover():Int return UITheme.searchBorderHover;
    inline function bgIdle():Int return UITheme.searchBG;
    inline function bgFocus():Int return UITheme.searchBGFocus;

    public var input:PsychUIInputText;
    public var bg:Rect;
    public var border:Rect;          // 底部 1px 线
    public var hint:FlxText;
    public var clearBtn:FlxSprite;   // 可选清除按钮

    var _hovered:Bool = false;
    var _focused:Bool = false;
    var _wasFocused:Bool = false;
    var _borderColor:Int = -1;
    var _bgColor:Int = -1;

    public var onChange:String->String->Void;

    public function new(x:Float, y:Float, w:Float, h:Float, fontSize:Int = 16)
    {
        super(x, y);
        UITheme.ensure();

        // 背景
        bg = new Rect(0, 0, w, h, 0, 0, bgIdle(), 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        // 底部边框（1px）
        border = new Rect(0, h - 1, w, 1, 0, 0, borderIdle(), 1);
        border.antialiasing = ClientPrefs.data.antialiasing;
        add(border);

        // 真正的输入组件
        input = new PsychUIInputText(
            Std.int(h * 0.3), 0, Std.int(w - h * 0.6), '', fontSize
        );
        input.bg.visible = false;
        input.behindText.visible = false;
        input.textObj.color = UITheme.searchText;
        input.textObj.alignment = LEFT;
        input.forceCase = backend.ui.CaseMode.LOWER_CASE;
        input.maxLength = 50;
        input.onChange = function(oldT, newT) {
            hint.visible = (newT.length == 0);
            if (onChange != null) onChange(oldT, newT);
        };
        input.unfocus = function() { _focused = false; };
        input.scrollFactor.set();
        add(input);

        // placeholder
        hint = new FlxText(h * 0.3, 0, w - h * 0.6, '');
        hint.setFormat(Paths.font('montserrat.ttf'), fontSize, UITheme.searchHint, LEFT);
        hint.antialiasing = ClientPrefs.data.antialiasing;
        hint.y = (h - hint.height) * 0.5;
        add(hint);

        // 清除按钮（×）—— Win10 搜索框右侧的 ×
        clearBtn = new FlxSprite(w - h * 0.7, (h - 12) * 0.5);
        clearBtn.makeGraphic(12, 12, 0x00000000);
        // 简单画一个 ×（你也可以换成图片）；像素画成白色，用 color 跟随主题
        var g = clearBtn.pixels;
        for (i in 0...12) {
            g.setPixel32(i, i, 0xFFFFFFFF);
            g.setPixel32(i, 11 - i, 0xFFFFFFFF);
        }
        clearBtn.color = UITheme.textSecondary;
        clearBtn.visible = false;
        add(clearBtn);

        var icon = new FlxSprite(h * 0.2, (h - 12) * 0.5).makeGraphic(12, 12, 0x00000000);
// 简单圆圈 + 斜线；也可以直接用图片
    }

    public function setPlaceholder(text:String)
    {
        hint.text = text;
    }

    /** 当前输入内容（不会为 null） */
    public function getText():String
    {
        return (input.text == null) ? '' : input.text;
    }

    /**
     * 直接写入输入内容（不会触发 onChange，调用方需要自己刷新依赖它的界面）。
     * 用于「从大类页带着搜索词进入分类页」这种预填场景。
     */
    public function setText(value:String):Void
    {
        var t = (value == null) ? '' : value;
        input.text = t;
        hint.visible = (t.length == 0);
    }

    /** 键盘 Tab 切到搜索框时调用 */
    public function focus()
    {
        PsychUIInputText.focusOn = input;
        _focused = true;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var mx = FlxG.mouse.getViewPosition().x;
        var my = FlxG.mouse.getViewPosition().y;
        var sp = getViewPosition();
        _hovered = mx >= sp.x && mx <= sp.x + width
                && my >= sp.y && my <= sp.y + height;

        _focused = (PsychUIInputText.focusOn == input);

        // 状态变化时重建 Rect 颜色
        var targetBorder = _focused ? accentColor() : (_hovered ? borderHover() : borderIdle());
        if (targetBorder != _borderColor) {
            _borderColor = targetBorder;
            border.color = targetBorder;
        }
        var targetBg = _focused ? bgFocus() : bgIdle();
        if (targetBg != _bgColor) {
            _bgColor = targetBg;
            bg.color = targetBg;
        }

        // 清除按钮：有内容且悬停或聚焦时显示
        var hasText = input.text != null && input.text.length > 0;
        clearBtn.visible = hasText && (_hovered || _focused);
        if (clearBtn.visible && FlxG.mouse.justPressed) {
            var cs = clearBtn.getViewPosition();
            if (mx >= cs.x && mx <= cs.x + clearBtn.width
             && my >= cs.y && my <= cs.y + clearBtn.height) {
                input.text = '';
                if (onChange != null) onChange(input.text, '');
                hint.visible = true;
            }
        }

        // 点击背景聚焦
        if (FlxG.mouse.justPressed && _hovered && !_focused) {
            PsychUIInputText.focusOn = input;
            _focused = true;
        }
    }

    /** 主题切换后重新套用配色（下一帧 update 会自动刷新边框/背景） */
    public function refreshTheme():Void
    {
        _borderColor = -1;
        _bgColor = -1;
        if (input != null && input.textObj != null) input.textObj.color = UITheme.searchText;
        if (hint != null) hint.color = UITheme.searchHint;
        if (clearBtn != null) clearBtn.color = UITheme.textSecondary;
    }
}