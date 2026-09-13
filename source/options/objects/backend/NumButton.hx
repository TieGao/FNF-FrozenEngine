package options.objects.backend;

import options.psychoptions.PsychOption;
import openfl.display.Shape;
import openfl.display.BitmapData;

class NumButton extends FlxSpriteGroup {

    var follow:PsychOption;

    var innerX:Float;
    var innerY:Float;

    public var moveBG:Rect;
    public var moveDis:Rect;
    public var rod:Rect;
    var valueText:FlxText;
    var valueTextWidth:Float = 80;

    var max:Float;
    var min:Float;

    // ===== 新增：颜色常量 =====
    static inline var COLOR_NORMAL:Int = 0x0064fa;
    static inline var COLOR_HOVER:Int  = 0xFFFFFF;
    static inline var COLOR_PRESS:Int  = 0x808080;

    public function new(X:Float, Y:Float, width:Float, height:Float, follow:PsychOption) {
        super(X, Y);

        this.follow = follow;
        this.min = follow.minValue;
        this.max = follow.maxValue;
        innerX = X;
        innerY = Y;

        moveBG = new Rect(0,
                         0,
                         width,
                         height * 0.1,
                         0,
                         0,
                         0xFF363535,
                         0.4
                         );
        moveBG.y += (height - moveBG.height) / 2;
        add(moveBG);

        // 已填充部分：更圆的胶囊式
        moveDis = new Rect(0,
                         0,
                         width,
                         height * 0.1,
                         0,
                         0,
                         0x0064fa,
                         1.0
                         );
        moveDis.y += (height - moveDis.height) / 2;
        add(moveDis);

        // 滑块：更圆的胶囊（横窄高宽）
        var rodH:Float = height;
        var rodW:Float = width * 0.05;
        rod = new Rect(0,
                        0,
                        rodW,
                        rodH,
                        rodW,
                        rodW,
                        0x0064fa,
                        1.0
                        );
        rod.y += (height - rod.height) / 2;
        add(rod);

        valueText = new FlxText(0, 0, valueTextWidth, '', 12);
        valueText.setFormat(Paths.font('montserrat.ttf'), 12,
            0xD6E8FF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF000000);
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
        var percent = (curValue - min) / (max - min);
        var outputData = FlxMath.roundDecimal(curValue, follow.decimals);
        rectUpdate(percent, outputData);
    }

    public var onFocus:Bool = false;

    var savePending:Bool = false;

    override function update(elapsed:Float)
	{
		super.update(elapsed);

        if (!follow.allowUpdate) return;

        var page:OptionsPageState = OptionsPageState.instance;
        var currentState:OptionsState = OptionsState.instance;
        var mouseEvent = page != null ? page.mouseEvent : (currentState != null ? currentState.mouseEvent : null);
        var specBG = page != null ? page.specBG : (currentState != null ? currentState.specBG : null);
        var downBG = page != null ? page.downBG : (currentState != null ? currentState.downBG : null);

        if (mouseEvent == null || specBG == null || downBG == null) return;
        if (mouseEvent.overlaps(specBG) || mouseEvent.overlaps(downBG)) {
            // 鼠标在外部区域时，重置颜色
            setRodColor(COLOR_NORMAL);
            onFocus = false;
            return;
        }

        var mouse = FlxG.mouse;

        // ===== 悬浮 / 按下 颜色反馈 =====
        var hoverRod = mouse.overlaps(rod);
        var hoverBG  = mouse.overlaps(moveBG);

        if (mouse.pressed && (onFocus || hoverRod || hoverBG)) {
            setRodColor(COLOR_PRESS);
        } else if (hoverRod || hoverBG) {
            setRodColor(COLOR_HOVER);
        } else {
            setRodColor(COLOR_NORMAL);
        }

		if (mouse.justPressed && hoverRod)
        {
            onFocus = true;
            lastMouseX = mouse.x;
        }
        else if (mouse.justPressed && hoverBG && !hoverRod)
        {
            onFocus = true;
            jumpToPointer(mouse.x);
            lastMouseX = mouse.x;   // 防止下一帧 onHold 突跳
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

    var lastMouseX = 0;

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
        var page:OptionsPageState = OptionsPageState.instance;
        var cataMove = page != null ? page.cataMove : (OptionsState.instance != null ? OptionsState.instance.cataMove : null);
        if (cataMove != null) cataMove.inputAllow = false;
        var deltaX:Float = FlxG.mouse.x - lastMouseX;
        lastMouseX = FlxG.mouse.x;
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
		moveDis._frame.frame.width = moveDis.width * percent;
		if (moveDis._frame.frame.width < 1)
			moveDis._frame.frame.width = 1;
		rod.x = moveBG.x + (moveBG.width - rod.width) * percent;

        if (outputData == null) return;

        if (valueText != null)
        {
            valueText.text = formatValueText(outputData);
        }

        follow.setValue(outputData);
		follow.change();
        if (follow.updateDisText != null) follow.updateDisText();
        savePending = true;
	}

    function formatValueText(value:Dynamic):String
    {
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
}