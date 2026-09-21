package options.objects.backend;

import options.Option;
import backend.UIControlTheme;

/**
 * 数值控件（滑块）
 *
 * Win10 风格：粗轨道 + 胶囊滑块
 * Win8  风格：细轨道（2px）+ 方形滑块（Metro 滑块）
 *
 * ⚠️ 不强依赖 OptionsPageState / OptionsState：那两个 mouseEvent/specBG 只用于"鼠标在
 *   外部区域时取消焦点"，Win8 Charm 边栏里没有这些对象（见 livePage() / liveState()）。
 * 支持 Option.valueFormatter，可把数值显示成任意文本（如 mm:ss）。
 */
class NumButton extends FlxSpriteGroup {

    var follow:Option;

    var innerX:Float;
    var innerY:Float;

    public var moveBG:Rect;
    public var moveDis:Rect;
    public var rod:Rect;
    var valueText:FlxText;
    var valueTextWidth:Float = 80;

    var max:Float;
    var min:Float;

    /** 本次构建时解析出的风格 */
    var win8:Bool = false;

    // ===== 颜色全部来自主题（深浅色切换由 UITheme 提供） =====
    inline function colorNormal():Int return win8 ? UIControlTheme.knob() : UITheme.sliderKnob;
    inline function colorHover():Int return win8 ? UIControlTheme.knobHover() : UITheme.sliderKnobHover;
    inline function colorPress():Int return win8 ? UIControlTheme.knobPress() : UITheme.sliderKnobPress;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:Option) {
        super(X, Y);
        UITheme.ensure();

        this.follow = follow;
        // min/max 是 Dynamic（不同选项可能不设），这里兜个底，避免后面算比例除零
        this.min = (follow.minValue != null) ? cast follow.minValue : 0;
        this.max = (follow.maxValue != null) ? cast follow.maxValue : 1;
        innerX = X;
        innerY = Y;
        win8 = UIControlTheme.isWin8();

        var trackH:Float = win8 ? 3 : height * 0.1;
        var rodH:Float = win8 ? Math.min(height, 18) : height;
        var rodW:Float = win8 ? 8 : width * 0.05;

        moveBG = new Rect(0,
                         0,
                         width,
                         trackH,
                         0,
                         0,
                         win8 ? UIControlTheme.track() : UITheme.sliderTrack,
                         win8 ? 1.0 : UITheme.sliderTrackAlpha
                         );
        moveBG.y += (height - moveBG.height) / 2;
        add(moveBG);

        // 已填充部分
        moveDis = new Rect(0,
                         0,
                         width,
                         trackH,
                         0,
                         0,
                         win8 ? UIControlTheme.accent() : UITheme.sliderFill,
                         1.0
                         );
        moveDis.y += (height - moveDis.height) / 2;
        add(moveDis);

        // 滑块
        rod = new Rect(0,
                        0,
                        rodW,
                        rodH,
                        win8 ? 0 : rodW,
                        win8 ? 0 : rodW,
                        win8 ? UIControlTheme.knob() : UITheme.sliderFill,
                        1.0
                        );
        rod.y += (height - rod.height) / 2;
        add(rod);

        valueText = new FlxText(0, 0, valueTextWidth, '', 12);
        valueText.setFormat(Paths.font('montserrat.ttf'), 12,
            win8 ? UIControlTheme.text() : UITheme.sliderValueText, LEFT);
        valueText.borderStyle = NONE;
        valueText.antialiasing = ClientPrefs.data.antialiasing;
        valueText.y = (height - valueText.height) * 0.5;
        valueText.x = moveBG.width + 12;
        add(valueText);

        initData();
    }

    public function initData() {
        var curValue:Dynamic = follow.getValue();
        if (curValue == null) curValue = follow.defaultValue;
        var percent = (max - min) == 0 ? 0 : (curValue - min) / (max - min);
        // ★ 初始值也吸附一次
        var stepped:Float = snapToStep(cast curValue, min, getStep());
        var outputData = FlxMath.roundDecimal(stepped, follow.decimals);
        rectUpdate(percent, outputData);
    }

    public var onFocus:Bool = false;

    /**
     * 键盘选中宿主行时由 Win10OptionRow 置位：让滑块看起来和鼠标悬停一样。
     * ⚠️ 只参与**配色**计算，不能并进 `onFocus` —— 那个字段同时是"正在拖动"的状态。
     */
    public var keyboardHighlight:Bool = false;

    var savePending:Bool = false;

    override function update(elapsed:Float)
	{
		super.update(elapsed);

        if (!follow.allowUpdate) return;

        var page:OptionsPageState = livePage();
        var currentState:OptionsState = liveState();
        var mouseEvent = page != null ? page.mouseEvent : (currentState != null ? currentState.mouseEvent : null);
        var specBG = page != null ? page.specBG : (currentState != null ? currentState.specBG : null);
        var downBG = page != null ? page.downBG : (currentState != null ? currentState.downBG : null);

        // 只有真的取到了"外部区域"才做焦点复位；Win8 边栏里没有这些对象。
        if (mouseEvent != null && specBG != null && downBG != null)
        {
            if (mouseEvent.overlaps(specBG) || mouseEvent.overlaps(downBG)) {
                setRodColor(colorNormal());
                onFocus = false;
                return;
            }
        }

        var mouse = FlxG.mouse;

        // ===== 悬浮 / 按下 颜色反馈 =====
        var hoverRod = OptionInput.overlaps(rod);
        var hoverBG  = OptionInput.overlaps(moveBG);

        if (mouse.pressed && (onFocus || hoverRod || hoverBG)) {
            setRodColor(colorPress());
        } else if (hoverRod || hoverBG || keyboardHighlight) {
            setRodColor(colorHover());
        } else {
            setRodColor(colorNormal());
        }

        // 指针映射用的是"命中判定空间"的坐标（就是 FlxObject.overlapsPoint 里的 xPos，见 OptionInput）。
        // 不能拿 FlxG.mouse.x —— 那是相对 FlxG.camera 的世界坐标，会被游戏相机的 scroll 推着走，
        // 和 moveBG.x（屏幕坐标）不在一个空间，点数值条会跳到错误的位置。
		if (mouse.justPressed && hoverRod)
        {
            onFocus = true;
            lastMouseX = OptionInput.mouseX();
        }
        else if (mouse.justPressed && hoverBG && !hoverRod)
        {
            onFocus = true;
            jumpToPointer(OptionInput.mouseX());
            lastMouseX = OptionInput.mouseX();   // 防止下一帧 onHold 突跳
        }

        if (mouse.justReleased && savePending)
        {
            follow.saveCurrentValue();
            savePending = false;
        }

        var inputAllow:Bool = true;

        var cataMove = page != null ? page.cataMove : (currentState != null ? currentState.cataMove : null);
        if (cataMove != null && Math.abs(cataMove.velocity) > 2) inputAllow = false;

        if (inputAllow) {
            if (onFocus && mouse.pressed)
                onHold();

            if (mouse.justReleased)
            {
                onFocus = false;
            }
        }
	}

    // ===== 新增：设置 rod 颜色的辅助函数 =====
    inline function setRodColor(color:Int)
    {
        if (rod != null && rod.color != color)
            rod.color = color;
    }

    /**
     * 取"当前真的还活着"的设置页实例。
     *
     * instance 是 static，界面切走后可能还留着旧引用；旧 state 的 specBG / downBG 已销毁、
     * scrollFactor 被置成 null，再拿去做鼠标命中判定会在 FlxObject.getScreenPosition() 里炸
     * Null Object Reference。统一用 exists 过滤一遍，拿不到就当没有（滑块照样能拖）。
     */
    static inline function isAlive(s:Dynamic):Bool
        return s != null && s.exists;

    inline function livePage():OptionsPageState
    {
        var p:OptionsPageState = OptionsPageState.instance;
        return isAlive(p) ? p : null;
    }

    inline function liveState():OptionsState
    {
        var s:OptionsState = OptionsState.instance;
        return isAlive(s) ? s : null;
    }

    /** 拖拽基准（命中判定空间的指针 X，Float —— OptionInput.mouseX() 不是整数） */
    var lastMouseX:Float = 0;

    // ===== 跳转到指针位置（世界坐标转局部） =====
    function jumpToPointer(pointerX:Float)
    {
        // moveBG.x 在 FlxSpriteGroup 中已经是绝对世界坐标，无需再减 this.x
        var localX = pointerX - moveBG.x;
        var usable = moveBG.width - rod.width;
        if (usable <= 0) return;

        var percent = FlxMath.bound(localX / usable, 0, 1);

        var outputData = FlxMath.roundDecimal(min + (max - min) * percent, follow.decimals);
        rectUpdate(percent, outputData);
    }

    function onHold()
	{
        var page:OptionsPageState = livePage();
        var cataMove = page != null ? page.cataMove : (liveState() != null ? liveState().cataMove : null);
        if (cataMove != null) cataMove.inputAllow = false;
        var deltaX:Float = OptionInput.mouseX() - lastMouseX;
        lastMouseX = OptionInput.mouseX();
        if (deltaX == 0) return;

		rod.x += deltaX;

        var startX = moveBG.x;
        var endX = moveBG.x + moveBG.width - rod.width;
		if (rod.x < startX)
			rod.x = startX;
		if (rod.x > endX)
			rod.x = endX;

		var percent = (rod.x - moveBG.x) / (moveBG.width - rod.width);
        var outputData = FlxMath.roundDecimal(min + (max - min) * percent, follow.decimals);
        rectUpdate(percent, outputData);
	}

    function rectUpdate(percent:Float, ?outputData)
    {
        percent = FlxMath.bound(percent, 0, 1);

        moveDis._frame.frame.width = moveDis.width * percent;
        if (moveDis._frame.frame.width < 1)
            moveDis._frame.frame.width = 1;
        rod.x = moveBG.x + (moveBG.width - rod.width) * percent;

        if (outputData == null) return;

        // ★ 吸附到 changeValue 的倍数
        var stepped:Float = snapToStep(cast outputData, min, getStep());
        outputData = FlxMath.roundDecimal(stepped, follow.decimals);

        if (valueText != null)
        {
            valueText.text = formatValueText(outputData);
        }

        follow.setValue(outputData);
        follow.change();
        if (follow.updateDisText != null) follow.updateDisText();
        savePending = true;
    }

    /** 让控件按当前值重新摆一次（键盘操作改了值之后调用） */
    public function refreshValue():Void
    {
        var curValue:Dynamic = follow.getValue();
        if (curValue == null) curValue = follow.defaultValue;
        var denom:Float = (max - min);
        var percent:Float = denom == 0 ? 0 : (curValue - min) / denom;
        rectUpdate(percent, FlxMath.roundDecimal(cast curValue, follow.decimals));
    }

    /**
     * 键盘选中宿主行时由 Win10OptionRow 调用（见 OptionWidgetFactory.setKeyboardHighlight）。
     * rod 颜色每帧都在 update() 里按 hoverRod / hoverBG / keyboardHighlight 重算，这里不用额外重绘。
     */
    public function setKeyboardHighlight(v:Bool):Void
    {
        keyboardHighlight = v;
    }

    /** 主题/控件风格切换后重新套用配色 */
    public function refreshTheme():Void
    {
        if (moveBG != null) moveBG.color = win8 ? UIControlTheme.track() : UITheme.sliderTrack;
        if (moveDis != null) moveDis.color = win8 ? UIControlTheme.accent() : UITheme.sliderFill;
        if (rod != null) rod.color = colorNormal();
        if (valueText != null) valueText.color = win8 ? UIControlTheme.text() : UITheme.sliderValueText;
    }

    function formatValueText(value:Dynamic):String
    {
        // 自定义格式化（例如 Skip Time 的 mm:ss）
        if (follow.valueFormatter != null)
            return follow.valueFormatter(cast value);

        var decimals:Int = follow.decimals;
        if (decimals <= 0)
            return Std.string(Std.int(value));

        var roundedValue:Float = FlxMath.roundDecimal(value, decimals);
        var str:String = Std.string(roundedValue);

        if (str.indexOf('.') == -1)
            str += '.';

        var parts:Array<String> = str.split('.');
        while (parts[1].length < decimals)
            parts[1] += '0';

        return parts[0] + '.' + parts[1].substr(0, decimals);
    }

    inline function snapToStep(value:Float, base:Float, step:Float):Float
    {
        if (step <= 0) return value;
        return base + Math.round((value - base) / step) * step;
    }

    inline function getStep():Float
    {
        var s:Float = Std.parseFloat(Std.string(follow.changeValue));
        if (Math.isNaN(s) || s <= 0) return 0;
        return s;
    }
}
