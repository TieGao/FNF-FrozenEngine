package options.objects;

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
    static inline var ACCENT:Int   = 0xFF0078D4; // Win10 主题蓝
    static inline var BORDER_IDLE:Int   = 0xFF5A5A5A;
    static inline var BORDER_HOVER:Int  = 0xFF8A8A8A;
    static inline var BG_IDLE:Int  = 0xFF1F1F1F;
    static inline var BG_FOCUS:Int = 0xFF2B2B2B;
    static inline var TEXT_COLOR:Int = 0xFFFFFFFF;
    static inline var HINT_COLOR:Int = 0xFF9A9A9A;

    public var input:PsychUIInputText;
    public var bg:Rect;
    public var border:Rect;          // 底部 1px 线
    public var hint:FlxText;
    public var clearBtn:FlxSprite;   // 可选清除按钮

    var _hovered:Bool = false;
    var _focused:Bool = false;
    var _wasFocused:Bool = false;
    var _borderColor:Int = BORDER_IDLE;
    var _bgColor:Int = BG_IDLE;

    public var onChange:String->String->Void;

    public function new(x:Float, y:Float, w:Float, h:Float, fontSize:Int = 16)
    {
        super(x, y);

        // 背景
        bg = new Rect(0, 0, w, h, 0, 0, BG_IDLE, 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        // 底部边框（1px）
        border = new Rect(0, h - 1, w, 1, 0, 0, BORDER_IDLE, 1);
        border.antialiasing = ClientPrefs.data.antialiasing;
        add(border);

        // 真正的输入组件
        input = new PsychUIInputText(
            Std.int(h * 0.3), 0, Std.int(w - h * 0.6), '', fontSize
        );
        input.bg.visible = false;
        input.behindText.visible = false;
        input.textObj.color = TEXT_COLOR;
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
        hint.setFormat(Paths.font('montserrat.ttf'), fontSize, HINT_COLOR, LEFT);
        hint.antialiasing = ClientPrefs.data.antialiasing;
        hint.y = (h - hint.height) * 0.5;
        add(hint);

        // 清除按钮（×）—— Win10 搜索框右侧的 ×
        clearBtn = new FlxSprite(w - h * 0.7, (h - 12) * 0.5);
        clearBtn.makeGraphic(12, 12, 0x00000000);
        // 简单画一个 ×（你也可以换成图片）
        var g = clearBtn.pixels;
        for (i in 0...12) {
            g.setPixel32(i, i, 0xFFAAAAAA);
            g.setPixel32(i, 11 - i, 0xFFAAAAAA);
        }
        clearBtn.visible = false;
        add(clearBtn);

        var icon = new FlxSprite(h * 0.2, (h - 12) * 0.5).makeGraphic(12, 12, 0x00000000);
// 简单圆圈 + 斜线；也可以直接用图片
    }

    public function setPlaceholder(text:String)
    {
        hint.text = text;
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

        var mx = FlxG.mouse.getScreenPosition().x;
        var my = FlxG.mouse.getScreenPosition().y;
        var sp = getScreenPosition();
        _hovered = mx >= sp.x && mx <= sp.x + width
                && my >= sp.y && my <= sp.y + height;

        _focused = (PsychUIInputText.focusOn == input);

        // 状态变化时重建 Rect 颜色
        var targetBorder = _focused ? ACCENT : (_hovered ? BORDER_HOVER : BORDER_IDLE);
        if (targetBorder != _borderColor) {
            _borderColor = targetBorder;
            border.color = targetBorder;
        }
        var targetBg = _focused ? BG_FOCUS : BG_IDLE;
        if (targetBg != _bgColor) {
            _bgColor = targetBg;
            bg.color = targetBg;
        }

        // 清除按钮：有内容且悬停或聚焦时显示
        var hasText = input.text != null && input.text.length > 0;
        clearBtn.visible = hasText && (_hovered || _focused);
        if (clearBtn.visible && FlxG.mouse.justPressed) {
            var cs = clearBtn.getScreenPosition();
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
}