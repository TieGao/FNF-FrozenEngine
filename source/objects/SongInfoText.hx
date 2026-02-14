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
        this.borderSize = 1;
        this.visible = !ClientPrefs.data.hideHud && ClientPrefs.data.songText;
        state.uiGroup.add(this);
        refresh();
    }

    public function refresh():Void {
        var version:String = MainMenuState.frozenEngineVersion;
        this.text = PlayState.SONG.song + ' - ' + Difficulty.getString() + ' | FE - ' + version;
        this.y = FlxG.height - 18 ; // keep near bottom by default
        if (ClientPrefs.data.downScroll) this.y = - FlxG.height + 18;
        if (ClientPrefs.data.customColor) {
            this.color = FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]);
        }
    }
}
