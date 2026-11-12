package options.objects.win10;

import backend.ui.PsychUIInputText;
import shapeEx.Rect;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

import openfl.display.BitmapData;

/**
 * Win10 风格搜索框
 * - 底部 1px 边框：悬停变灰白，聚焦变蓝 (#0078D4)
 * - 背景：#1F1F1F / 聚焦 #2B2B2B
 * - 支持 placeholder、清除按钮
 *
 * 可选参数（默认值与设置页原有行为一致，老调用点不用改）：
 * - `withIcon`：左侧画一个矢量放大镜，不依赖图片资源
 * - `forceDark`：固定用深色配色，给 Freeplay 这类背景恒为深色的界面
 */
class Win10SearchBar extends FlxSpriteGroup
{
    // forceDark 用的一套固定深色（取值与 UITheme 的 dark 档一致）
    static inline var DARK_ACCENT:Int = 0xFF0078D4;
    static inline var DARK_BG:Int = 0xFF1F1F1F;
    static inline var DARK_BG_FOCUS:Int = 0xFF2B2B2B;
    static inline var DARK_BORDER:Int = 0xFF5A5A5A;
    static inline var DARK_BORDER_HOVER:Int = 0xFF8A8A8A;
    static inline var DARK_TEXT:Int = 0xFFFFFFFF;
    static inline var DARK_HINT:Int = 0xFF9A9A9A;
    static inline var DARK_ICON:Int = 0xFF9A9A9A;

    public var input:PsychUIInputText;
    public var bg:Rect;
    public var border:Rect;          // 底部 1px 线
    public var hint:FlxText;
    public var clearBtn:FlxSprite;   // 可选清除按钮
    public var icon:FlxSprite;       // withIcon 时的放大镜（否则为 null）

    /**
     * 只读入口：不接收键盘输入，点击只触发 `onClick`。
     * 给「点开独立搜索窗」的老入口用 —— 搜索框只当按钮使。
     */
    public var readOnly:Bool = false;
    /** 点击回调（只读模式下点整条，可输入模式下点已聚焦的框） */
    public var onClick:Void->Void;
    /** 回车：先失焦，再回调 */
    public var onSubmit:String->Void;
    /** 失焦（ESC / 回车 / 点击别处 / 主动 unfocus 都会走） */
    public var onUnfocus:Void->Void;

    public var onChange:String->String->Void;

    var _hovered:Bool = false;
    var _focused:Bool = false;
    var _borderColor:Int = -1;
    var _bgColor:Int = -1;
    var _iconColor:Int = -1;

    var forceDark:Bool = false;

    public function new(x:Float, y:Float, w:Float, h:Float, fontSize:Int = 16, ?withIcon:Bool = false, ?forceDark:Bool = false,
        ?font:String = null)
    {
        super(x, y);
        UITheme.ensure();
        this.forceDark = (forceDark == true);
        var leFont:String = (font == null || font.length == 0) ? Paths.font('montserrat.ttf') : font;

        // 背景
        bg = new Rect(0, 0, w, h, 0, 0, bgIdle(), 1);
        bg.antialiasing = ClientPrefs.data.antialiasing;
        add(bg);

        // 底部边框（1px）
        border = new Rect(0, h - 1, w, 1, 0, 0, borderIdle(), 1);
        border.antialiasing = ClientPrefs.data.antialiasing;
        add(border);

        // 左侧放大镜：占位宽度同时推右输入区，避免文字压在图标上
        var padLeft:Int = Std.int(h * 0.3);
        // PsychUIInputText 的文字从自己的 y+1 起排，直接放在组 y=0 会贴着上边缘，
        // 和垂直居中的 placeholder 差好几像素（进输入态时文字会往上跳）。两边用同一个 padY。
        var padY:Int = Std.int((h - (fontSize + 4)) * 0.5);
        if (padY < 0) padY = 0;
        if (withIcon)
        {
            var iconSize:Int = 12;
            icon = new FlxSprite(Std.int(h * 0.3), Std.int((h - iconSize) * 0.5));
            // ⚠️ 第 4 参 unique 必须给 true：makeGraphic 默认 unique=false，key 是「宽x高:颜色」，
            // 同尺寸同底色的两次调用会**拿到同一张 BitmapData**。下面 clearBtn 也是 12×12 透明底，
            // 不隔离的话放大镜和清除按钮的 × 会画进同一张图 —— 表现出来就是「搜索图标上有个叉」。
            icon.makeGraphic(iconSize, iconSize, 0x00000000, true);
            drawMagnifier(icon.pixels, iconSize);
            icon.color = iconIdle();
            _iconColor = icon.color;
            add(icon);
            padLeft += 18;
        }

        // 真正的输入组件
        input = new PsychUIInputText(
            padLeft, padY, Std.int(w - padLeft - h * 0.6), '', fontSize
        );
        input.bg.visible = false;
        input.behindText.visible = false;
        input.textObj.font = leFont;
        input.textObj.color = textColor();
        input.textObj.alignment = LEFT;
        input.forceCase = backend.ui.CaseMode.LOWER_CASE;
        input.maxLength = 50;
        input.onChange = function(oldT, newT) {
            hint.visible = (newT.length == 0);
            if (onChange != null) onChange(oldT, newT);
        };
        input.unfocus = function() {
            _focused = false;
            if (onUnfocus != null) onUnfocus();
        };
        // 回车 = 交还键盘焦点。列表类宿主（Freeplay）靠这个把方向键还给列表。
        input.onPressEnter = function(_) {
            PsychUIInputText.focusOn = null;
            if (onSubmit != null) onSubmit(getText());
        };
        input.scrollFactor.set();
        add(input);

        // placeholder
        hint = new FlxText(padLeft, 0, w - padLeft - h * 0.6, '');
        hint.setFormat(leFont, fontSize, hintColor(), LEFT);
        hint.antialiasing = ClientPrefs.data.antialiasing;
        hint.y = padY;
        add(hint);

        // 清除按钮（×）—— Win10 搜索框右侧的 ×
        clearBtn = new FlxSprite(w - h * 0.7, (h - 12) * 0.5);
        // 同样要 unique，理由见上面放大镜那段的注释
        clearBtn.makeGraphic(12, 12, 0x00000000, true);
        var g = clearBtn.pixels;
        for (i in 0...12) {
            g.setPixel32(i, i, 0xFFFFFFFF);
            g.setPixel32(i, 11 - i, 0xFFFFFFFF);
        }
        clearBtn.color = secondaryText();
        clearBtn.visible = false;
        add(clearBtn);
    }

    inline function accentColor():Int return forceDark ? DARK_ACCENT : UITheme.accentDeep;          // 聚焦时的边框
    inline function borderIdle():Int return forceDark ? DARK_BORDER : UITheme.searchBorder;
    inline function borderHover():Int return forceDark ? DARK_BORDER_HOVER : UITheme.searchBorderHover;
    inline function bgIdle():Int return forceDark ? DARK_BG : UITheme.searchBG;
    inline function bgFocus():Int return forceDark ? DARK_BG_FOCUS : UITheme.searchBGFocus;
    inline function textColor():Int return forceDark ? DARK_TEXT : UITheme.searchText;
    inline function hintColor():Int return forceDark ? DARK_HINT : UITheme.searchHint;
    inline function iconIdle():Int return forceDark ? DARK_ICON : UITheme.searchHint;
    inline function secondaryText():Int return forceDark ? DARK_ICON : UITheme.textSecondary;

    /** 12×12 的 1px 细线放大镜：圆环 + 右下斜手柄（比例按 12px 调过，换尺寸跟着缩放）。 */
    static function drawMagnifier(pixels:BitmapData, size:Int):Void
    {
        if (pixels == null) return;
        var r:Float = size * 0.317;
        var cx:Float = size * 0.375;
        var cy:Float = size * 0.375;

        // 手柄：圆环右下 → 图标右下角
        var ax:Float = cx + r * 0.72;
        var ay:Float = cy + r * 0.72;
        var bx:Float = size - 1.1;
        var by:Float = size - 1.1;
        var vx:Float = bx - ax;
        var vy:Float = by - ay;
        var len2:Float = vx * vx + vy * vy;

        for (py in 0...size)
        {
            for (px in 0...size)
            {
                var sx:Float = px + 0.5;
                var sy:Float = py + 0.5;
                var dx:Float = sx - cx;
                var dy:Float = sy - cy;
                var d:Float = Math.sqrt(dx * dx + dy * dy);
                var ink:Bool = (d > r - 1.5 && d < r + 0.6);

                if (!ink && len2 > 0)
                {
                    var t:Float = ((sx - ax) * vx + (sy - ay) * vy) / len2;
                    if (t >= 0 && t <= 1)
                    {
                        var qx:Float = ax + vx * t;
                        var qy:Float = ay + vy * t;
                        var hd:Float = Math.sqrt((sx - qx) * (sx - qx) + (sy - qy) * (sy - qy));
                        ink = hd < 0.95;
                    }
                }

                if (ink) pixels.setPixel32(px, py, 0xFFFFFFFF);
            }
        }
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
        if (readOnly) return;
        PsychUIInputText.focusOn = input;
        _focused = true;
    }

    /** 主动收掉键盘焦点（不改变输入内容） */
    public function unfocus():Void
    {
        if (PsychUIInputText.focusOn == input)
            PsychUIInputText.focusOn = null;
        _focused = false;
    }

    public function isFocused():Bool
    {
        return PsychUIInputText.focusOn == input;
    }

    /** 指针是否压在本搜索框上（宿主用来做「点别处收焦点」判定） */
    public function isHovered():Bool
    {
        return _hovered;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var mx = FlxG.mouse.getViewPosition().x;
        var my = FlxG.mouse.getViewPosition().y;
        var sp = getViewPosition();
        _hovered = mx >= sp.x && mx <= sp.x + width
                && my >= sp.y && my <= sp.y + height;

        // 只读模式挡住 PsychUIInputText 自带的「点 behindText 即聚焦」
        input.behindText.exists = !readOnly;
        _focused = !readOnly && (PsychUIInputText.focusOn == input);

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
        // 放大镜跟边框同步提亮
        if (icon != null) {
            var targetIcon = (_focused || _hovered) ? borderHover() : iconIdle();
            if (targetIcon != _iconColor) {
                _iconColor = targetIcon;
                icon.color = targetIcon;
            }
        }

        // 清除按钮：有内容且悬停或聚焦时显示（只读入口不给 ×，免得点它反被当成打开）
        var hasText = input.text != null && input.text.length > 0;
        clearBtn.visible = !readOnly && hasText && (_hovered || _focused);
        if (clearBtn.visible && FlxG.mouse.justPressed) {
            var cs = clearBtn.getViewPosition();
            if (mx >= cs.x && mx <= cs.x + clearBtn.width
             && my >= cs.y && my <= cs.y + clearBtn.height) {
                input.text = '';
                if (onChange != null) onChange(input.text, '');
                hint.visible = true;
            }
        }

        if (FlxG.mouse.justPressed && _hovered) {
            if (readOnly) {
                if (onClick != null) onClick();
            } else if (!_focused) {
                PsychUIInputText.focusOn = input;
                _focused = true;
            }
        }
    }

    /** 主题切换后重新套用配色（下一帧 update 会自动刷新边框/背景） */
    public function refreshTheme():Void
    {
        _borderColor = -1;
        _bgColor = -1;
        _iconColor = -1;
        if (input != null && input.textObj != null) input.textObj.color = textColor();
        if (hint != null) hint.color = hintColor();
        if (clearBtn != null) clearBtn.color = secondaryText();
        if (icon != null) icon.color = iconIdle();
    }
}
