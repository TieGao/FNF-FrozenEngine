package objects;

import flixel.text.FlxText;
import flixel.FlxG;
import flixel.util.FlxColor;
import states.PlayState;
import states.MainMenuState;

class SongInfoText extends FlxText {
    public var state:PlayState;

    public function new(state:PlayState) {
        super(2, FlxG.height, 0, "", 15);
        this.state = state;
        this.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        this.scrollFactor.set();
        this.borderSize = 0.32;
        this.visible = !ClientPrefs.data.hideHud && ClientPrefs.data.songText;
        state.uiGroup.add(this);
        refresh();
    }

        public function refresh():Void {
        var version:String = MainMenuState.frozenEngineVersion;
        var playtime:Float = ClientPrefs.data.totalPlaytime;
        
        // 构建显示文本
        var textParts:Array<String> = [];
        var songPart:String = PlayState.SONG.song;
        
        // 根据设置决定是否添加难度（使用 " - " 连接）
        if (ClientPrefs.data.showDifficulty) {
            songPart += ' - ' + Difficulty.getString();
        }
        textParts.push(songPart);
        
        // 根据设置决定是否显示引擎版本（使用 "FE - " 前缀）
        if (ClientPrefs.data.showEngineVer) {
            textParts.push('FE $version');
        }
        
        // 用 ' | ' 连接所有部分
        this.text = textParts.join(' | ');
        
        this.y = FlxG.height - 18; // keep near bottom by default
        this.borderSize = 0.32;
        if (ClientPrefs.data.downScroll) this.y = - FlxG.height + 18;
        if (ClientPrefs.data.customColor) {
            this.color = FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]);
        }
    }
}