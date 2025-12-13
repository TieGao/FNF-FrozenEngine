package options;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;
import flixel.input.mouse.FlxMouse;

import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxStringUtil;
import backend.InputFormatter;

using StringTools;

class KEKeyBindMenu extends MusicBeatSubstate
{
    var keyTextDisplay:FlxText;
    var infoText:FlxText;
    var bindingText:FlxText;
    var bindingText2:FlxText;
    
    var keyText:Array<String> = [
        "NOTES",
        "Left", "Down", "Up", "Right",
        "",
        "UI",
        "Left", "Down", "Up", "Right",
        "",
        "Accept", "Back", "Pause", "Reset"
    ];
    
    var optionTypes:Array<String> = [
        "header", "note_left", "note_down", "note_up", "note_right",
        "spacer", "header", "ui_left", "ui_down", "ui_up", "ui_right",
        "spacer", "accept", "back", "pause", "reset"
    ];
    
    var curSelected:Int = 1;
    var curAlt:Bool = false;
    
    var onKeyboardMode:Bool = true;
    var binding:Bool = false;
    var holdingEsc:Float = 0;
    
    var grpOptions:FlxTypedGroup<FlxText>;
    var grpBinds:FlxTypedGroup<FlxText>;
    var grpHeaders:FlxTypedGroup<FlxText>;
    
    var selectSpr:FlxSprite;
    var bindingBlack:FlxSprite;
    var controllerSpr:FlxSprite;
    var bg:FlxSprite;
    var infoBg:FlxSprite; // 新增：信息文本背景框
    
    // 添加一个标志来防止重复关闭
    var closing:Bool = false;
    var justCreated:Bool = true; // 标记是否刚刚创建

    // 添加这个数组来跟踪我们在绑定界面中修改的键
    var modifiedKeys:Map<String, Bool> = new Map();
    var originalBackKey:FlxKey = FlxKey.ESCAPE;
    var originalBackButton:FlxGamepadInputID = FlxGamepadInputID.B;

    // 鼠标控制相关变量
    var allowMouse:Bool = true;
    var isMouseControl:Bool = false;
    var mouseOverOption:Int = -1;
    var mouseOverBind:Int = -1; // -1: 无悬停, 0: 主键位, 1: 副键位
    var mouseOptionStartY:Float = 100;
    var mouseOptionHeight:Float = 30;

    override function create()
    {
        super.create();
        
        // 保存原始的退出键
        saveOriginalBackKeys();
        
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0;
        add(bg);
        
        grpHeaders = new FlxTypedGroup<FlxText>();
        add(grpHeaders);
        
        grpOptions = new FlxTypedGroup<FlxText>();
        add(grpOptions);
        
        grpBinds = new FlxTypedGroup<FlxText>();
        add(grpBinds);
        
        selectSpr = new FlxSprite().makeGraphic(150, 40, FlxColor.WHITE);
        selectSpr.alpha = 0;
        selectSpr.visible = false; // 初始隐藏
        add(selectSpr);
        
        controllerSpr = new FlxSprite(20, 20).loadGraphic(Paths.image('controllertype'), true, 82, 60);
        controllerSpr.animation.add('keyboard', [0], 1, false);
        controllerSpr.animation.add('gamepad', [1], 1, false);
        controllerSpr.animation.play(onKeyboardMode ? 'keyboard' : 'gamepad');
        controllerSpr.alpha = 0;
        add(controllerSpr);
        
        // 创建更窄的信息文本背景框（高度40像素）
        infoBg = new FlxSprite(0, FlxG.height - 45).makeGraphic(FlxG.width, 40, FlxColor.BLACK);
        infoBg.alpha = 0;
        add(infoBg);
        
        infoText = new FlxText(0, FlxG.height - 40, FlxG.width, 
            'Press CTRL to switch mode • ENTER to rebind • ESC to save and exit',
            20);
        infoText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        infoText.borderSize = 2;
        infoText.screenCenter(X);
        infoText.alpha = 0;
        add(infoText);
        
        createTexts();
        updateText();
        
        // 开始进入动画
        startEnterAnimation();
        
        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
        
        // 初始化鼠标控制
        FlxG.mouse.visible = true;
    }
    
    function startEnterAnimation()
    {
        // 背景渐变显示
        FlxTween.tween(bg, {alpha: 0.6}, 0.7, {ease: FlxEase.expoInOut});
        
        // 控制器图标渐变显示
        FlxTween.tween(controllerSpr, {alpha: 1}, 0.7, {ease: FlxEase.expoInOut});
        
        // 信息背景框和文本渐变显示
        FlxTween.tween(infoBg, {alpha: 0.7}, 0.7, {ease: FlxEase.expoInOut});
        FlxTween.tween(infoText, {alpha: 1}, 0.7, {ease: FlxEase.expoInOut});
        
        // 延迟后显示文本内容
        haxe.Timer.delay(function() {
            // 显示所有文本内容
            for (header in grpHeaders) {
                header.alpha = 0;
                FlxTween.tween(header, {alpha: 1}, 0.5, {ease: FlxEase.expoInOut});
            }
            for (option in grpOptions) {
                option.alpha = 0;
                FlxTween.tween(option, {alpha: 1}, 0.5, {ease: FlxEase.expoInOut});
            }
            for (bind in grpBinds) {
                bind.alpha = 0;
                FlxTween.tween(bind, {alpha: 1}, 0.5, {ease: FlxEase.expoInOut});
            }
            
            // 动画完成后更新选择框
            haxe.Timer.delay(function() {
                justCreated = false;
                updateSelectSprPosition();
            }, 500);
        }, 200);
    }
    
    function saveOriginalBackKeys()
    {
        // 保存原始的退出键绑定
        var backKeyBinds = ClientPrefs.keyBinds.get("back");
        if (backKeyBinds != null && backKeyBinds[0] != FlxKey.NONE)
        {
            originalBackKey = backKeyBinds[0];
        }
        
        var backGamepadBinds = ClientPrefs.gamepadBinds.get("back");
        if (backGamepadBinds != null && backGamepadBinds[0] != FlxGamepadInputID.NONE)
        {
            originalBackButton = backGamepadBinds[0];
        }
    }
    
    function restoreOriginalBackKeys()
    {
        // 恢复原始的退出键绑定
        var backKeyBinds = ClientPrefs.keyBinds.get("back");
        if (backKeyBinds != null)
        {
            backKeyBinds[0] = originalBackKey;
            ClientPrefs.keyBinds.set("back", backKeyBinds);
        }
        
        var backGamepadBinds = ClientPrefs.gamepadBinds.get("back");
        if (backGamepadBinds != null)
        {
            backGamepadBinds[0] = originalBackButton;
            ClientPrefs.gamepadBinds.set("back", backGamepadBinds);
        }
    }
    
    function createTexts()
    {
        grpHeaders.forEachAlive(function(text:FlxText) text.destroy());
        grpOptions.forEachAlive(function(text:FlxText) text.destroy());
        grpBinds.forEachAlive(function(text:FlxText) text.destroy());
        
        grpHeaders.clear();
        grpOptions.clear();
        grpBinds.clear();
        
        mouseOptionStartY = 100;
        mouseOptionHeight = 30;
        var bindStartX:Float = 400;
        var headerStartX:Float = 200;
        
        for (i in 0...keyText.length)
        {
            var type:String = optionTypes[i];
            
            if (type == "header")
            {
                var header:FlxText = new FlxText(headerStartX, mouseOptionStartY + i * mouseOptionHeight, 0, keyText[i], 32);
                header.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
                header.borderSize = 2;
                header.alpha = 0; // 初始透明，动画中渐变显示
                grpHeaders.add(header);
            }
            else if (type == "spacer")
            {
                // Skip spacer
            }
            else
            {
                // Option name
                var option:FlxText = new FlxText(headerStartX, mouseOptionStartY + i * mouseOptionHeight, 0, keyText[i], 28);
                option.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
                option.borderSize = 2;
                option.ID = i;
                option.alpha = 0; // 初始透明，动画中渐变显示
                grpOptions.add(option);
                
                // Binds (main and alt)
                for (n in 0...2)
                {
                    var keyName:String = getBindDisplay(i, n);
                    var bind:FlxText = new FlxText(bindStartX + n * 150, mouseOptionStartY + i * mouseOptionHeight, 0, keyName, 28);
                    bind.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
                    bind.borderSize = 2;
                    bind.ID = i * 2 + n;
                    bind.alpha = 0; // 初始透明，动画中渐变显示
                    grpBinds.add(bind);
                }
            }
        }
    }
    
    function getBindDisplay(optionIndex:Int, bindIndex:Int):String
    {
        var type:String = optionTypes[optionIndex];
        if (type == "header" || type == "spacer") return "";
        
        if (onKeyboardMode)
        {
            var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(type);
            if (keys != null && bindIndex < keys.length && keys[bindIndex] != NONE)
                return InputFormatter.getKeyName(keys[bindIndex]);
        }
        else
        {
            var buttons:Array<FlxGamepadInputID> = ClientPrefs.gamepadBinds.get(type);
            if (buttons != null && bindIndex < buttons.length && buttons[bindIndex] != NONE)
                return InputFormatter.getGamepadName(buttons[bindIndex]);
        }
        
        return "---";
    }
    
    function updateBind(optionIndex:Int, bindIndex:Int)
    {
        var type:String = optionTypes[optionIndex];
        var keyName:String = getBindDisplay(optionIndex, bindIndex);
        
        for (bind in grpBinds)
        {
            if (bind.ID == optionIndex * 2 + bindIndex)
            {
                bind.text = keyName;
                break;
            }
        }
    }
    
    function updateSelectSprPosition()
    {
        var selectedOption:FlxText = null;
        for (option in grpOptions)
        {
            if (option.ID == curSelected)
            {
                selectedOption = option;
                break;
            }
        }
        
        if (selectedOption != null)
        {
            selectSpr.x = selectedOption.x + 200 + (curAlt ? 150 : 0);
            selectSpr.y = selectedOption.y - 5;
            selectSpr.visible = true;
            if (!justCreated) {
                FlxTween.tween(selectSpr, {alpha: 0.3}, 0.3, {ease: FlxEase.expoOut});
            }
        }
        else
        {
            selectSpr.visible = false;
            selectSpr.alpha = 0;
        }
    }
    
    function updateText(?change:Int = 0)
    {
        // Find next selectable option
        do {
            curSelected += change;
            curSelected = FlxMath.wrap(curSelected, 0, keyText.length - 1);
        } while (optionTypes[curSelected] == "header" || optionTypes[curSelected] == "spacer");
        
        // Update selection
        for (option in grpOptions)
        {
            option.color = (option.ID == curSelected) ? FlxColor.YELLOW : FlxColor.WHITE;
        }
        
        // 更新选择框位置
        updateSelectSprPosition();
        
        FlxG.sound.play(Paths.sound('scrollMenu'));
    }
    
    function startBinding()
    {
        binding = true;
        holdingEsc = 0;
        
        bindingBlack = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bindingBlack.alpha = 0;
        FlxTween.tween(bindingBlack, {alpha: 0.8}, 0.3);
        add(bindingBlack);
        
        var optionName = keyText[curSelected];
        bindingText = new FlxText(0, FlxG.height * 0.3, FlxG.width, 
            'Press any key for ${optionName} (${curAlt ? "Alt" : "Main"})',
            32);
        bindingText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        bindingText.borderSize = 2;
        add(bindingText);
        
        bindingText2 = new FlxText(0, FlxG.height * 0.5, FlxG.width, 
            'Hold ESC to Cancel • Hold BACKSPACE to Clear',
            24);
        bindingText2.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        bindingText2.borderSize = 2;
        add(bindingText2);
        
        ClientPrefs.toggleVolumeKeys(false);
    }
    
    function closeBinding()
    {
        binding = false;
        
        if (bindingBlack != null)
        {
            FlxTween.tween(bindingBlack, {alpha: 0}, 0.3, {
                onComplete: function(_) {
                    bindingBlack.destroy();
                    remove(bindingBlack);
                }
            });
        }
        
        if (bindingText != null)
        {
            bindingText.destroy();
            remove(bindingText);
        }
        
        if (bindingText2 != null)
        {
            bindingText2.destroy();
            remove(bindingText2);
        }
        
        ClientPrefs.reloadVolumeKeys();
    }
    
    function swapMode()
    {
        onKeyboardMode = !onKeyboardMode;
        controllerSpr.animation.play(onKeyboardMode ? 'keyboard' : 'gamepad');
        
        // Reset selection to first bindable option
        curSelected = 1;
        while (optionTypes[curSelected] == "header" || optionTypes[curSelected] == "spacer")
        {
            curSelected++;
            if (curSelected >= keyText.length) curSelected = 1;
        }
        
        createTexts();
        updateText();
        
        FlxG.sound.play(Paths.sound('scrollMenu'));
    }
    
    function updateAlt(?doSwap:Bool = false)
    {
        if (doSwap)
        {
            curAlt = !curAlt;
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }
        
        // 更新选择框位置
        updateSelectSprPosition();
    }
    
    // 鼠标悬停检测函数
    function checkMouseHover()
    {
        var newMouseOverOption = -1;
        var newMouseOverBind = -1;
        
        // 检查鼠标是否悬停在选项名称上
        for (option in grpOptions)
        {
            var optionType = optionTypes[option.ID];
            if (optionType != "header" && optionType != "spacer")
            {
                if (FlxG.mouse.overlaps(option))
                {
                    newMouseOverOption = option.ID;
                    break;
                }
            }
        }
        
        // 检查鼠标是否悬停在键位绑定文本上
        if (newMouseOverOption == -1)
        {
            for (bind in grpBinds)
            {
                var optionIndex = Math.floor(bind.ID / 2);
                var bindIndex = bind.ID % 2;
                var optionType = optionTypes[optionIndex];
                
                if (optionType != "header" && optionType != "spacer")
                {
                    if (FlxG.mouse.overlaps(bind))
                    {
                        newMouseOverOption = optionIndex;
                        newMouseOverBind = bindIndex;
                        break;
                    }
                }
            }
        }
        
        // 更新鼠标悬停状态
        if (newMouseOverOption != mouseOverOption || newMouseOverBind != mouseOverBind)
        {
            mouseOverOption = newMouseOverOption;
            mouseOverBind = newMouseOverBind;
            
            // 更新选项文本颜色
            for (option in grpOptions)
            {
                var optionType = optionTypes[option.ID];
                if (optionType != "header" && optionType != "spacer")
                {
                    if (option.ID == mouseOverOption)
                    {
                        option.color = FlxColor.LIME;
                    }
                    else if (option.ID == curSelected)
                    {
                        option.color = FlxColor.YELLOW;
                    }
                    else
                    {
                        option.color = FlxColor.WHITE;
                    }
                }
            }
            
            // 如果鼠标悬停在选项上，自动切换到该选项
            if (mouseOverOption != -1 && mouseOverOption != curSelected && !binding)
            {
                var oldSelected = curSelected;
                curSelected = mouseOverOption;
                curAlt = (mouseOverBind != -1) ? (mouseOverBind == 1) : false;
                
                // 更新选择框位置
                updateSelectSprPosition();
                
                // 如果切换了选项，播放音效
                if (oldSelected != curSelected)
                {
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
                }
            }
        }
    }
    
    override function update(elapsed:Float)
    {
        if (closing) return;
        
        // 鼠标控制逻辑
        if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed || FlxG.mouse.justMoved))
        {
            allowMouse = false;
            isMouseControl = true;
            checkMouseHover();
            allowMouse = true;
        }
        
        // 鼠标滚轮滚动
        if (FlxG.mouse.wheel != 0 && !binding)
        {
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
            changeSelection(-FlxG.mouse.wheel, false);
        }
        
        // 鼠标点击功能
        if (FlxG.mouse.justPressed && isMouseControl && !binding && mouseOverOption != -1)
        {
            if (mouseOverOption != curSelected)
            {
                // 左键点击未选中的选项：选择它
                curSelected = mouseOverOption;
                curAlt = (mouseOverBind != -1) ? (mouseOverBind == 1) : false;
                updateText();
            }
            else
            {
                // 左键点击已选中的选项：进入绑定模式
                startBinding();
            }
        }
        
        if (!binding)
        {
            // 关键修改：使用直接按键检测，不依赖controls系统
            var pressedEsc = FlxG.keys.justPressed.ESCAPE;
            var gamepad = FlxG.gamepads.lastActive;
            var pressedB = (gamepad != null && gamepad.justPressed.B);
            
            if (pressedEsc || pressedB  || FlxG.mouse.justPressedRight)
            {
                // 先恢复原始的退出键，确保其他界面正常工作
                restoreOriginalBackKeys();
                ClientPrefs.saveSettings();
                
                // 使用原始风格的退出动画
                closeWithOriginalAnimation();
                return;
            }
            
            if (FlxG.keys.justPressed.CONTROL || FlxG.gamepads.anyJustPressed(LEFT_SHOULDER))
            {
                swapMode();
            }
            
            if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT || 
                FlxG.gamepads.anyJustPressed(DPAD_LEFT) || FlxG.gamepads.anyJustPressed(DPAD_RIGHT))
            {
                updateAlt(true);
            }
            
            if (FlxG.keys.justPressed.UP || FlxG.gamepads.anyJustPressed(DPAD_UP))
            {
                updateText(-1);
            }
            else if (FlxG.keys.justPressed.DOWN || FlxG.gamepads.anyJustPressed(DPAD_DOWN))
            {
                updateText(1); 
            }
            
            if (FlxG.keys.justPressed.ENTER || FlxG.gamepads.anyJustPressed(A) || FlxG.gamepads.anyJustPressed(START))
            {
                startBinding();
            }
            
            // 防止R键重复触发
            if (FlxG.keys.justPressed.R)
            {
                // Reset all keys to default
                ClientPrefs.resetKeys(!onKeyboardMode);
                ClientPrefs.reloadVolumeKeys();
                createTexts();
                updateText();
                // 不播放音效，避免干扰
            }
        }
        else
        {
            var optionType:String = optionTypes[curSelected];
            var altNum:Int = curAlt ? 1 : 0;
            
            if (FlxG.mouse.justPressedRight)
            {
                closeBinding();
            }
            if (FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
            {
                holdingEsc += elapsed;
                if (holdingEsc > 0.5)
                {
                    closeBinding();
                }
            }
            else if (FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
            {
                holdingEsc += elapsed;
                if (holdingEsc > 0.5)
                {
                    if (onKeyboardMode)
                    {
                        ClientPrefs.keyBinds.get(optionType)[altNum] = NONE;
                    }
                    else
                    {
                        ClientPrefs.gamepadBinds.get(optionType)[altNum] = NONE;
                    }
                    ClientPrefs.clearInvalidKeys(optionType);
                    updateBind(curSelected, altNum);
                    closeBinding();
                }
            }
            else
            {
                holdingEsc = 0;
                var changed:Bool = false;
                
                if (onKeyboardMode)
                {
                    if (FlxG.keys.justPressed.ANY)
                    {
                        var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
                        if (keyPressed != FlxKey.ESCAPE && keyPressed != FlxKey.BACKSPACE)
                        {
                            // 记录修改的键
                            modifiedKeys.set(optionType, true);
                            
                            ClientPrefs.keyBinds.get(optionType)[altNum] = keyPressed;
                            
                            // Clear duplicate
                            var otherAlt = 1 - altNum;
                            if (ClientPrefs.keyBinds.get(optionType)[otherAlt] == keyPressed)
                            {
                                ClientPrefs.keyBinds.get(optionType)[otherAlt] = NONE;
                                updateBind(curSelected, otherAlt);
                            }
                            
                            changed = true;
                        }
                    }
                }
                else
                {
                    if (FlxG.gamepads.anyJustPressed(ANY))
                    {
                        var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
                        if (gamepad != null)
                        {
                            var buttonPressed:FlxGamepadInputID = gamepad.firstJustPressedID();
                            // 修复：直接检查是否为 NONE，不检查 null
                            if (buttonPressed != NONE && 
                                buttonPressed != BACK && buttonPressed != B)
                            {
                                // 记录修改的键
                                modifiedKeys.set(optionType, true);
                                
                                ClientPrefs.gamepadBinds.get(optionType)[altNum] = buttonPressed;
                                
                                // Clear duplicate
                                var otherAlt = 1 - altNum;
                                if (ClientPrefs.gamepadBinds.get(optionType)[otherAlt] == buttonPressed)
                                {
                                    ClientPrefs.gamepadBinds.get(optionType)[otherAlt] = NONE;
                                    updateBind(curSelected, otherAlt);
                                }
                                
                                changed = true;
                            }
                        }
                    }
                }
                
                if (changed)
                {
                    ClientPrefs.clearInvalidKeys(optionType);
                    updateBind(curSelected, altNum);
                    FlxG.sound.play(Paths.sound('confirmMenu'));
                    closeBinding();
                }
            }
        }
        
        super.update(elapsed);
    }
    
    function closeWithOriginalAnimation()
    {
        if (closing) return;
        closing = true;
        
        // 恢复原始风格的退出动画
        FlxTween.tween(bg, {alpha: 0}, 0.73, {
            ease: FlxEase.expoInOut,
            onComplete: function(flx:FlxTween)
            {
                ClientPrefs.saveSettings();
                close();
            }
        });
        
        // 同时渐出其他元素
        FlxTween.tween(controllerSpr, {alpha: 0}, 0.7, {ease: FlxEase.expoInOut});
        FlxTween.tween(infoBg, {alpha: 0}, 0.7, {ease: FlxEase.expoInOut});
        FlxTween.tween(infoText, {alpha: 0}, 0.7, {ease: FlxEase.expoInOut});
        FlxTween.tween(selectSpr, {alpha: 0}, 0.7, {ease: FlxEase.expoInOut});
        
        // 渐出所有文本
        for (header in grpHeaders) {
            FlxTween.tween(header, {alpha: 0}, 0.6, {ease: FlxEase.expoInOut});
        }
        for (option in grpOptions) {
            FlxTween.tween(option, {alpha: 0}, 0.6, {ease: FlxEase.expoInOut});
        }
        for (bind in grpBinds) {
            FlxTween.tween(bind, {alpha: 0}, 0.6, {ease: FlxEase.expoInOut});
        }
    }
    
    function changeSelection(change:Int = 0, playSound:Bool = true)
    {
        do {
            curSelected += change;
            curSelected = FlxMath.wrap(curSelected, 0, keyText.length - 1);
        } while (optionTypes[curSelected] == "header" || optionTypes[curSelected] == "spacer");
        
        // 更新选择状态
        for (option in grpOptions)
        {
            if (option.ID == curSelected)
            {
                option.color = FlxColor.YELLOW;
            }
            else if (option.ID == mouseOverOption)
            {
                option.color = FlxColor.LIME;
            }
            else
            {
                option.color = FlxColor.WHITE;
            }
        }
        
        // 更新选择框位置
        updateSelectSprPosition();
        
        if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'));
    }
    
    override function close()
    {
        // 确保退出键恢复到原始状态
        restoreOriginalBackKeys();
        ClientPrefs.saveSettings();
        super.close();
    }
}