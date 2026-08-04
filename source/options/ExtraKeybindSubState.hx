// ExtraKeybindSubState.hx
package options;

import backend.InputFormatter;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import objects.AttachedSprite;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;

class ExtraKeybindSubState extends MusicBeatSubstate
{
    var curSelected:Int = 0;
    var curAlt:Bool = false;

    // 当前选中的键数 (5-16)
    var selectedKeyCount:Int = 5;

    // 键数选择选项
    var keyCountOptions:Array<Dynamic> = [
        [true, 'SELECT KEY COUNT'],
        [true, '5K', 'note_5k', '5K'],
        [true, '6K', 'note_6k', '6K'],
        [true, '7K', 'note_7k', '7K'],
        [true, '8K', 'note_8k', '8K'],
        [true, '9K', 'note_9k', '9K'],
        [true, '10K', 'note_10k', '10K'],
        [true, '11K', 'note_11k', '11K'],
        [true, '12K', 'note_12k', '12K'],
        [true, '13K', 'note_13k', '13K'],
        [true, '14K', 'note_14k', '14K'],
        [true, '15K', 'note_15k', '15K'],
        [true, '16K', 'note_16k', '16K']
    ];

    // 绑定选项 - 动态生成
    var options:Array<Dynamic> = [];
    var curOptions:Array<Int>;
    var curOptionsValid:Array<Int>;
    static var defaultKey:String = 'Reset to Default Keys';

    var bg:FlxSprite;
    var grpDisplay:FlxTypedGroup<Alphabet>;
    var grpBlacks:FlxTypedGroup<AttachedSprite>;
    var grpOptions:FlxTypedGroup<Alphabet>;
    var grpBinds:FlxTypedGroup<Alphabet>;
    var selectSpr:AttachedSprite;

    var gamepadColor:FlxColor = 0xfffd7194;
    var keyboardColor:FlxColor = 0xff7192fd;
    var onKeyboardMode:Bool = true;

    var controllerSpr:FlxSprite;

    // 鼠标控制相关变量
    var allowMouse:Bool = true;
    var isMouseControl:Bool = false;
    var mouseOverOption:Int = -1;
    var mouseOverBind:Int = -1; // 0 = 主键, 1 = 副键
    var mouseOverController:Bool = false;

    // 模式：true = 选择键数, false = 绑定键位
    var selectMode:Bool = true;

    public function new()
    {
        super();

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("Extra Keybinds Menu", null);
        #end

        bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = keyboardColor;
        bg.antialiasing = ClientPrefs.data.antialiasing;
        bg.screenCenter();
        add(bg);

        var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
        grid.velocity.set(40, 40);
        grid.alpha = 0;
        FlxTween.tween(grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
        add(grid);

        grpDisplay = new FlxTypedGroup<Alphabet>();
        add(grpDisplay);
        grpOptions = new FlxTypedGroup<Alphabet>();
        add(grpOptions);
        grpBlacks = new FlxTypedGroup<AttachedSprite>();
        add(grpBlacks);
        selectSpr = new AttachedSprite();
        selectSpr.makeGraphic(250, 78, FlxColor.WHITE);
        selectSpr.copyAlpha = false;
        selectSpr.alpha = 0.75;
        add(selectSpr);
        grpBinds = new FlxTypedGroup<Alphabet>();
        add(grpBinds);

        controllerSpr = new FlxSprite(50, 40).loadGraphic(Paths.image('controllertype'), true, 82, 60);
        controllerSpr.antialiasing = ClientPrefs.data.antialiasing;
        controllerSpr.animation.add('keyboard', [0], 1, false);
        controllerSpr.animation.add('gamepad', [1], 1, false);
        add(controllerSpr);

        var text:Alphabet = new Alphabet(60, 90, 'CTRL', false);
        text.alignment = CENTERED;
        text.setScale(0.4);
        add(text);

        createTexts();

        // 显示鼠标
        FlxG.mouse.visible = true;
    }

    var lastID:Int = 0;

    function createTexts()
    {
        if (selectMode) {
            createKeyCountSelectUI();
        } else {
            createKeyBindingUI();
        }
    }

    function createKeyCountSelectUI()
    {
        curSelected = 0;
        curAlt = false;
        curOptions = [];
        curOptionsValid = [];
        clearGroups();

        var myID:Int = 0;
        for (i => option in keyCountOptions)
        {
            if (onKeyboardMode || option[0])
            {
                var isCentered:Bool = (option.length < 3);
                var isDisplayKey:Bool = (isCentered);

                var str:String = option[1];
                var keyStr:String = option[2];
                var text:Alphabet = new Alphabet(475, 300, !isDisplayKey ? Language.getPhrase('key_$keyStr', str) : Language.getPhrase('keygroup_$str', str), !isDisplayKey);
                text.isMenuItem = true;
                text.changeX = false;
                text.distancePerItem.y = 60;
                text.targetY = myID;
                text.ID = myID;
                lastID = myID;

                if (!isDisplayKey)
                {
                    text.alignment = RIGHT;
                    grpOptions.add(text);
                    curOptions.push(i);
                    curOptionsValid.push(myID);
                }
                else grpDisplay.add(text);

                if (isCentered) addCenteredText(text, option, myID);
                else addKeyTextForCountSelect(text, option, myID);

                text.snapToPosition();
                text.y += FlxG.height * 2;
                myID++;
            }
        }
        updateText();
    }

    function createKeyBindingUI()
    {
        curSelected = 0;
        curAlt = false;
        curOptions = [];
        curOptionsValid = [];
        clearGroups();

        // 生成当前键数的绑定选项
        options = [];
        options.push([true, '${selectedKeyCount}K KEYBINDS']); // 标题

        // 添加每个键的绑定选项
        for (i in 1...selectedKeyCount + 1)
        {
            options.push([true, 'Key $i', 'note_${selectedKeyCount}k_$i', 'Key $i']);
        }

        options.push([true]);
        options.push([true]);
        options.push([true, defaultKey]);

        var myID:Int = 0;
        for (i => option in options)
        {
            if (onKeyboardMode || option[0])
            {
                if (option.length > 1)
                {
                    var isCentered:Bool = (option.length < 3);
                    var isDefaultKey:Bool = (option[1] == defaultKey);
                    var isDisplayKey:Bool = (isCentered && !isDefaultKey);

                    var str:String = option[1];
                    var keyStr:String = option[2];
                    if (isDefaultKey) str = Language.getPhrase(str);
                    var text:Alphabet = new Alphabet(475, 300, !isDisplayKey ? Language.getPhrase('key_$keyStr', str) : Language.getPhrase('keygroup_$str', str), !isDisplayKey);
                    text.isMenuItem = true;
                    text.changeX = false;
                    text.distancePerItem.y = 60;
                    text.targetY = myID;
                    text.ID = myID;
                    lastID = myID;

                    if (!isDisplayKey)
                    {
                        text.alignment = RIGHT;
                        grpOptions.add(text);
                        curOptions.push(i);
                        curOptionsValid.push(myID);
                    }
                    else grpDisplay.add(text);

                    if (isCentered) addCenteredText(text, option, myID);
                    else addKeyText(text, option, myID);

                    text.snapToPosition();
                    text.y += FlxG.height * 2;
                }
                myID++;
            }
        }
        updateText();
    }

    function addCenteredText(text:Alphabet, option:Array<Dynamic>, id:Int)
    {
        text.alignment = LEFT;
        text.screenCenter(X);
        text.y -= 55;
        text.startPosition.y -= 55;
    }

    function addKeyText(text:Alphabet, option:Array<Dynamic>, id:Int)
    {
        var bindMap:Dynamic = onKeyboardMode ? ClientPrefs.keyBinds : ClientPrefs.gamepadBinds;
        var defaultMap:Dynamic = onKeyboardMode ? ClientPrefs.defaultKeys : ClientPrefs.defaultButtons;
        var keys:Array<Dynamic> = null;  // 改为 Array<Dynamic>

        if (onKeyboardMode)
        {
            keys = cast bindMap.get(option[2]);
            if (keys == null && defaultMap != null && defaultMap.exists(option[2]))
                keys = cast defaultMap.get(option[2]).copy();
            if (keys == null)
                keys = [NONE, NONE];
        }
        else
        {
            var gmpds:Array<Null<FlxGamepadInputID>> = cast bindMap.get(option[2]);
            if (gmpds == null && defaultMap != null && defaultMap.exists(option[2]))
                gmpds = cast defaultMap.get(option[2]).copy();
            if (gmpds == null)
                gmpds = [NONE, NONE];
            keys = gmpds;  // 保持为 Dynamic 数组
        }

        for (n in 0...2)
        {
            var key:String = null;
            if (onKeyboardMode)
                key = InputFormatter.getKeyName((keys[n] != null) ? keys[n] : FlxKey.NONE);
            else
                key = InputFormatter.getGamepadName((keys[n] != null) ? keys[n] : FlxGamepadInputID.NONE);

            var attach:Alphabet = new Alphabet(560 + n * 300, 248, key, false);
            attach.isMenuItem = true;
            attach.changeX = false;
            attach.distancePerItem.y = 60;
            attach.targetY = text.targetY;
            attach.ID = Math.floor(grpBinds.length / 2);
            attach.snapToPosition();
            attach.y += FlxG.height * 2;
            grpBinds.add(attach);

            playstationCheck(attach);
            attach.scaleX = Math.min(1, 230 / attach.width);

            // spawn black bars at the right of the key name
            var black:AttachedSprite = new AttachedSprite();
            black.makeGraphic(250, 78, FlxColor.BLACK);
            black.alphaMult = 0.4;
            black.sprTracker = text;
            black.yAdd = -6;
            black.xAdd = 75 + n * 300;
            grpBlacks.add(black);
        }
    }

    function addKeyTextForCountSelect(text:Alphabet, option:Array<Dynamic>, id:Int)
    {
        // 键数选择模式不需要显示绑定键位
        // 只是占位
    }

    function playstationCheck(alpha:Alphabet)
    {
        if (onKeyboardMode) return;

        var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
        var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;
        var letter = alpha.letters[0];
        if (model == PS4)
        {
            switch (alpha.text)
            {
                case '[', ']': //Square and Triangle respectively
                    letter.image = 'alphabet_playstation';
                    letter.updateHitbox();

                    letter.offset.x += 4;
                    letter.offset.y -= 5;
            }
        }
    }

    function updateBind(num:Int, text:String)
    {
        var bind:Alphabet = grpBinds.members[num];
        var attach:Alphabet = new Alphabet(350 + (num % 2) * 300, 248, text, false);
        attach.isMenuItem = true;
        attach.changeX = false;
        attach.distancePerItem.y = 60;
        attach.targetY = bind.targetY;
        attach.ID = bind.ID;
        attach.x = bind.x;
        attach.y = bind.y;

        playstationCheck(attach);
        attach.scaleX = Math.min(1, 230 / attach.width);

        bind.kill();
        grpBinds.remove(bind);
        grpBinds.insert(num, attach);
        bind.destroy();
    }

    function clearGroups()
    {
        grpDisplay.forEachAlive(function(text:Alphabet) text.destroy());
        grpBlacks.forEachAlive(function(black:AttachedSprite) black.destroy());
        grpOptions.forEachAlive(function(text:Alphabet) text.destroy());
        grpBinds.forEachAlive(function(text:Alphabet) text.destroy());
        grpDisplay.clear();
        grpBlacks.clear();
        grpOptions.clear();
        grpBinds.clear();
    }

    var binding:Bool = false;
    var holdingEsc:Float = 0;
    var bindingBlack:FlxSprite;
    var bindingText:Alphabet;
    var bindingText2:Alphabet;
    var hasPendingChanges:Bool = false;

    var timeForMoving:Float = 0.1;

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        // 右键返回支持
        #if !mobile
        if (FlxG.mouse.justPressedRight && !binding)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            close();
            return;
        }
        #end

        if (timeForMoving > 0) //Fix controller bug
        {
            timeForMoving = Math.max(0, timeForMoving - elapsed);
            return;
        }

        #if !mobile
        // 鼠标悬停检测
        if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
        {
            allowMouse = false;
            isMouseControl = true;

            var newMouseOverOption:Int = -1;
            var newMouseOverBind:Int = -1;

            // 检查鼠标悬停在控制器图标上
            mouseOverController = FlxG.mouse.overlaps(controllerSpr);

            // 检查鼠标悬停在选项上
            for (i in 0...grpOptions.length)
            {
                var option = grpOptions.members[i];
                if (option != null && FlxG.mouse.overlaps(option))
                {
                    newMouseOverOption = i;
                    break;
                }
            }

            // 检查鼠标悬停在键位绑定上
            for (i in 0...grpBinds.length)
            {
                var bind = grpBinds.members[i];
                if (bind != null && FlxG.mouse.overlaps(bind))
                {
                    newMouseOverOption = Math.floor(i / 2);
                    newMouseOverBind = i % 2;
                    break;
                }
            }

            // 检查鼠标悬停在黑色背景框上
            for (i in 0...grpBlacks.length)
            {
                var black = grpBlacks.members[i];
                if (black != null && FlxG.mouse.overlaps(black))
                {
                    newMouseOverOption = Math.floor(i / 2);
                    newMouseOverBind = i % 2;
                    break;
                }
            }

            // 更新鼠标悬停状态
            if (newMouseOverOption != -1 && newMouseOverOption != mouseOverOption)
            {
                mouseOverOption = newMouseOverOption;
                mouseOverBind = newMouseOverBind;
                updateMouseHover();
            }
            else if (newMouseOverOption == -1)
            {
                mouseOverOption = -1;
                mouseOverBind = -1;
                updateMouseHover();
            }

            allowMouse = true;
        }

        // 鼠标点击控制器图标切换模式
        if (FlxG.mouse.justPressed && mouseOverController)
        {
            swapMode();
        }

        // 鼠标点击选项或键位绑定
        if (FlxG.mouse.justPressed && mouseOverOption != -1)
        {
            if (mouseOverOption != curSelected)
            {
                // 点击未选中的选项：选择它
                curSelected = mouseOverOption;
                updateText();
            }
            else if (mouseOverBind != -1 && !selectMode)
            {
                // 点击已选中选项的键位绑定：切换到对应的alt键
                if ((mouseOverBind == 0 && curAlt) || (mouseOverBind == 1 && !curAlt))
                {
                    updateAlt(true);
                }
            }
        }

        // 鼠标双击开始绑定
        if (FlxG.mouse.justPressed && mouseOverOption != -1 && mouseOverOption == curSelected &&
            (mouseOverBind == -1 || mouseOverBind == (curAlt ? 1 : 0)))
        {
            if (!selectMode)
            {
                if (options[curOptions[curSelected]][1] != defaultKey)
                {
                    startBinding();
                }
                else
                {
                    // 重置为默认键位
                    ClientPrefs.resetKeys(!onKeyboardMode);
                    ClientPrefs.reloadVolumeKeys();
                    hasPendingChanges = true;
                    ClientPrefs.saveSettings();
                    var lastSel:Int = curSelected;
                    createTexts();
                    curSelected = lastSel;
                    updateText();
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                }
            }
            else
            {
                // 键数选择模式 - 点击选项
                var selectedValue:Int = curOptions[curSelected];
                if (selectedValue != -1)
                {
                    // 选择键数
                    var keyStr:String = keyCountOptions[selectedValue][2];
                    // 从 keyStr 中提取键数，例如 "note_5k" -> 5
                    var countStr:String = keyStr.split('_')[1];
                    selectedKeyCount = Std.parseInt(countStr.substring(0, countStr.length - 1));
                    selectMode = false;
                    createTexts();
                    FlxG.sound.play(Paths.sound('confirmMenu'));
                }
            }
        }

        // 鼠标滚轮滚动
        if (FlxG.mouse.wheel != 0 && !binding)
        {
            if (FlxG.mouse.wheel < 0) {
                updateText(1);
            } else {
                updateText(-1);
            }
        }
        #end

        if (!binding)
        {
            if (FlxG.keys.justPressed.ESCAPE || FlxG.gamepads.anyJustPressed(B))
            {
                if (selectMode)
                {
                    close();
                    return;
                }
                else
                {
                    selectMode = true;
                    createTexts();
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                    return;
                }
            }

            if (FlxG.keys.justPressed.CONTROL || FlxG.gamepads.anyJustPressed(LEFT_SHOULDER) || FlxG.gamepads.anyJustPressed(RIGHT_SHOULDER))
                swapMode();

            if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT || FlxG.gamepads.anyJustPressed(DPAD_LEFT) || FlxG.gamepads.anyJustPressed(DPAD_RIGHT) ||
                FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_LEFT) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_RIGHT))
            {
                if (!selectMode) updateAlt(true);
            }

            if (FlxG.keys.justPressed.UP || FlxG.gamepads.anyJustPressed(DPAD_UP) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_UP))
                updateText(-1);
            else if (FlxG.keys.justPressed.DOWN || FlxG.gamepads.anyJustPressed(DPAD_DOWN) || FlxG.gamepads.anyJustPressed(LEFT_STICK_DIGITAL_DOWN))
                updateText(1);

            if (FlxG.keys.justPressed.ENTER || FlxG.gamepads.anyJustPressed(START) || FlxG.gamepads.anyJustPressed(A))
            {
                if (!selectMode)
                {
                    if (options[curOptions[curSelected]][1] != defaultKey)
                    {
                        startBinding();
                    }
                    else
                    {
                        // Reset to Default
                        ClientPrefs.resetKeys(!onKeyboardMode);
                        ClientPrefs.reloadVolumeKeys();
                        hasPendingChanges = true;
                        ClientPrefs.saveSettings();
                        var lastSel:Int = curSelected;
                        createTexts();
                        curSelected = lastSel;
                        updateText();
                        FlxG.sound.play(Paths.sound('cancelMenu'));
                    }
                }
                else
                {
                    // 键数选择模式 - 按确认
                    var selectedValue:Int = curOptions[curSelected];
                    if (selectedValue != -1)
                    {
                        var keyStr:String = keyCountOptions[selectedValue][2];
                        var countStr:String = keyStr.split('_')[1];
                        selectedKeyCount = Std.parseInt(countStr.substring(0, countStr.length - 1));
                        selectMode = false;
                        createTexts();
                        FlxG.sound.play(Paths.sound('confirmMenu'));
                    }
                }
            }
        }
        else
        {
            var altNum:Int = curAlt ? 1 : 0;
            var curOption:Array<Dynamic> = options[curOptions[curSelected]];

            if (FlxG.mouse.justPressedRight)
            {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                closeBinding();
            }

            if (FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
            {
                holdingEsc += elapsed;
                if (holdingEsc > 0.5)
                {
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                    closeBinding();
                }
            }
            else if (FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
            {
                holdingEsc += elapsed;
                if (holdingEsc > 0.5)
                {
                    if (onKeyboardMode)
                        ClientPrefs.keyBinds.get(curOption[2])[altNum] = NONE;
                    else
                        ClientPrefs.gamepadBinds.get(curOption[2])[altNum] = NONE;
                    ClientPrefs.clearInvalidKeys(curOption[2]);
                    updateBind(Math.floor(curSelected * 2) + altNum, onKeyboardMode ? InputFormatter.getKeyName(NONE) : InputFormatter.getGamepadName(NONE));
                    hasPendingChanges = true;
                    ClientPrefs.saveSettings();
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                    closeBinding();
                }
            }
            else
            {
                holdingEsc = 0;
                var changed:Bool = false;
                var curKeys:Array<FlxKey> = ClientPrefs.keyBinds.get(curOption[2]);
                var curButtons:Array<FlxGamepadInputID> = ClientPrefs.gamepadBinds.get(curOption[2]);
                if (curKeys == null) curKeys = [NONE, NONE];
                if (curButtons == null) curButtons = [NONE, NONE];

                if (onKeyboardMode)
                {
                    if (FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
                    {
                        var keyPressed:Int = FlxG.keys.firstJustPressed();
                        var keyReleased:Int = FlxG.keys.firstJustReleased();
                        if (keyPressed > -1 && keyPressed != FlxKey.ESCAPE && keyPressed != FlxKey.BACKSPACE)
                        {
                            curKeys[altNum] = keyPressed;
                            changed = true;
                        }
                        else if (keyReleased > -1 && (keyReleased == FlxKey.ESCAPE || keyReleased == FlxKey.BACKSPACE))
                        {
                            curKeys[altNum] = keyReleased;
                            changed = true;
                        }
                    }
                }
                else if (FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
                {
                    var keyPressed:Null<FlxGamepadInputID> = NONE;
                    var keyReleased:Null<FlxGamepadInputID> = NONE;
                    if (FlxG.gamepads.anyJustPressed(LEFT_TRIGGER)) keyPressed = LEFT_TRIGGER; //it wasnt working for some reason
                    else if (FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)) keyPressed = RIGHT_TRIGGER; //it wasnt working for some reason
                    else
                    {
                        for (i in 0...FlxG.gamepads.numActiveGamepads)
                        {
                            var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
                            if (gamepad != null)
                            {
                                keyPressed = gamepad.firstJustPressedID();
                                keyReleased = gamepad.firstJustReleasedID();

                                if (keyPressed == null) keyPressed = NONE;
                                if (keyReleased == null) keyReleased = NONE;
                                if (keyPressed != NONE || keyReleased != NONE) break;
                            }
                        }
                    }

                    if (keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
                    {
                        curButtons[altNum] = keyPressed;
                        changed = true;
                    }
                    else if (keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
                    {
                        curButtons[altNum] = keyReleased;
                        changed = true;
                    }
                }

                if (changed)
                {
                    if (onKeyboardMode)
                    {
                        if (curKeys[altNum] == curKeys[1 - altNum])
                            curKeys[1 - altNum] = FlxKey.NONE;
                    }
                    else
                    {
                        if (curButtons[altNum] == curButtons[1 - altNum])
                            curButtons[1 - altNum] = FlxGamepadInputID.NONE;
                    }

                    var option:String = options[curOptions[curSelected]][2];
                    ClientPrefs.clearInvalidKeys(option);
                    for (n in 0...2)
                    {
                        var key:String = null;
                        if (onKeyboardMode)
                        {
                            var savKey:Array<Null<FlxKey>> = ClientPrefs.keyBinds.get(option);
                            key = InputFormatter.getKeyName(savKey[n] != null ? savKey[n] : NONE);
                        }
                        else
                        {
                            var savKey:Array<Null<FlxGamepadInputID>> = ClientPrefs.gamepadBinds.get(option);
                            key = InputFormatter.getGamepadName(savKey[n] != null ? savKey[n] : NONE);
                        }
                        updateBind(Math.floor(curSelected * 2) + n, key);
                    }
                    hasPendingChanges = true;
                    ClientPrefs.saveSettings();
                    FlxG.sound.play(Paths.sound('confirmMenu'));
                    closeBinding();
                }
            }
        }
    }

    function updateMouseHover()
    {
        // 更新控制器图标悬停效果
        if (mouseOverController) {
            controllerSpr.alpha = 1.0;
        } else {
            controllerSpr.alpha = 0.8;
        }

        // 更新选项悬停效果
        for (i in 0...grpOptions.length)
        {
            var option = grpOptions.members[i];
            if (option != null)
            {
                if (i == curSelected) {
                    option.alpha = 1.0;
                } else if (i == mouseOverOption) {
                    option.alpha = 0.8;
                } else {
                    option.alpha = 0.6;
                }
            }
        }
    }

    function closeBinding()
    {
        binding = false;
        bindingBlack.destroy();
        remove(bindingBlack);

        bindingText.destroy();
        remove(bindingText);

        bindingText2.destroy();
        remove(bindingText2);
        ClientPrefs.reloadVolumeKeys();
    }

    override function close()
    {
        if (hasPendingChanges)
        {
            ClientPrefs.saveSettings();
            hasPendingChanges = false;
        }
        super.close();
    }

    function updateText(?change:Int = 0)
    {
        curSelected = FlxMath.wrap(curSelected + change, 0, curOptions.length - 1);

        var num:Int = curOptionsValid[curSelected];
        var addNum:Int = 0;
        if (num < 3) addNum = 3 - num;
        else if (num > lastID - 4) addNum = (lastID - 4) - num;

        grpDisplay.forEachAlive(function(item:Alphabet) {
            item.targetY = item.ID - num - addNum;
        });

        grpOptions.forEachAlive(function(item:Alphabet)
        {
            item.targetY = item.ID - num - addNum;
            item.alpha = (item.ID - num == 0) ? 1 : 0.6;
        });
        grpBinds.forEachAlive(function(item:Alphabet)
        {
            var parent:Alphabet = grpOptions.members[item.ID];
            item.targetY = parent.targetY;
            item.alpha = parent.alpha;
        });

        updateAlt();
        FlxG.sound.play(Paths.sound('scrollMenu'));

        // 更新鼠标悬停状态
        updateMouseHover();
    }

    function swapMode()
    {
        FlxTween.cancelTweensOf(bg);
        FlxTween.color(bg, 0.5, bg.color, onKeyboardMode ? gamepadColor : keyboardColor, {ease: FlxEase.linear});
        onKeyboardMode = !onKeyboardMode;

        curSelected = 0;
        curAlt = false;
        controllerSpr.animation.play(onKeyboardMode ? 'keyboard' : 'gamepad');
        createTexts();

        // 重置鼠标悬停状态
        mouseOverOption = -1;
        mouseOverBind = -1;
        mouseOverController = false;
    }

    function updateAlt(?doSwap:Bool = false)
    {
        if (doSwap)
        {
            curAlt = !curAlt;
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }
        selectSpr.sprTracker = grpBlacks.members[Math.floor(curSelected * 2) + (curAlt ? 1 : 0)];
        selectSpr.visible = (selectSpr.sprTracker != null);
    }

    function startBinding()
    {
        bindingBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
        bindingBlack.scale.set(FlxG.width, FlxG.height);
        bindingBlack.updateHitbox();
        bindingBlack.alpha = 0;
        FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
        add(bindingBlack);

        bindingText = new Alphabet(FlxG.width / 2, 160, Language.getPhrase('controls_rebinding', 'Rebinding {1}', [options[curOptions[curSelected]][3]]), false);
        bindingText.alignment = CENTERED;
        add(bindingText);

        bindingText2 = new Alphabet(FlxG.width / 2, 340, Language.getPhrase('controls_rebinding2', 'Hold ESC to Cancel\nHold Backspace to Delete'), true);
        bindingText2.alignment = CENTERED;
        add(bindingText2);

        binding = true;
        holdingEsc = 0;
        ClientPrefs.toggleVolumeKeys(false);
        FlxG.sound.play(Paths.sound('scrollMenu'));
    }
}