package objects;

import backend.ui.PsychUIInputText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flash.events.KeyboardEvent;

class SearchBar extends PsychUIInputText
{
    public var isVisible(default, set):Bool = true;
    private var bottomLine:FlxSprite;

    public function new(x:Float = 0, y:Float = 0, width:Int = 100)
    {
        super(x, y, width, '', 16);

        maxLength = 50;

        remove(bg);
        bg.destroy();
        bg = null;

        behindText.visible = false;

        bottomLine = new FlxSprite(x, y + height -50).makeGraphic(width, 2, FlxColor.WHITE);
        add(bottomLine);

        textObj.y = y + 2;
        textObj.color = FlxColor.WHITE;
        textObj.alignment = "left";

        visible = true;
        active = true;
    }

    private function set_isVisible(value:Bool):Bool
    {
        visible = value;
        active = value;
        if (value)
        {
            PsychUIInputText.focusOn = this;
        }
        else
        {
            if (PsychUIInputText.focusOn == this)
                PsychUIInputText.focusOn = null;
        }
        return isVisible = value;
    }

    override function onKeyDown(e:KeyboardEvent)
    {
        if (!isVisible) return;

        // 阻止 ESC 键关闭输入框（让父状态处理）
        if (e.keyCode == 27) // ESC
        {
            e.stopPropagation();
            e.preventDefault();
            return;
        }

        // 阻止 BACKSPACE 与游戏返回冲突（仅在输入框有内容或焦点时）
        if (e.keyCode == 8) // Backspace
        {
            if (PsychUIInputText.focusOn == this)
            {
                super.onKeyDown(e);
            }
            e.stopPropagation();
            e.preventDefault();
            return;
        }

        super.onKeyDown(e);
    }

    override public function setGraphicSize(width:Float = 0, height:Float = 0)
    {
        super.setGraphicSize(width, height);
        if (bottomLine != null)
        {
            bottomLine.setGraphicSize(width, 2);
            bottomLine.y = y + height - 2;
        }
    }

    override public function destroy()
    {
        super.destroy();
    }
}