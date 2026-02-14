package objects;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.PlayState;

class JudgementCounter {
    public var state:PlayState;
    public var tnhText:FlxText;
    public var highestcomboText:FlxText;
    public var comboText:FlxText;
    public var marvelousText:FlxText;
    public var sickText:FlxText;
    public var goodText:FlxText;
    public var badText:FlxText;
    public var shitText:FlxText;
    public var missText:FlxText;

    public function new(state:PlayState) {
        this.state = state;
        if (!ClientPrefs.data.Counter) return;

        var font:String = Paths.font("vcr.ttf");
        var textSize:Int = 20;
        var textWidth:Float = 280;
        var verticalSpacing:Float = 24;
        var startX:Float = 10;
        var startY:Float = 250;

        tnhText = createText(startX, startY, textWidth, "Total Notes Hit: 0", font, textSize, FlxColor.WHITE);
        highestcomboText = createText(startX, startY + verticalSpacing, textWidth, "Highest Combo: 0", font, textSize, FlxColor.WHITE);
        comboText = createText(startX, startY + verticalSpacing * 2, textWidth, "Combo: 0", font, textSize, FlxColor.WHITE);
        marvelousText = createText(startX, startY + verticalSpacing * 3, textWidth, "Marvelous: 0", font, textSize, FlxColor.fromRGB(255,215,0));
        sickText = createText(startX, startY + verticalSpacing * 4, textWidth, "Sicks: 0", font, textSize, FlxColor.fromRGB(0,191,255) );
        goodText = createText(startX, startY + verticalSpacing * 5, textWidth, "Goods: 0", font, textSize, FlxColor.fromRGB(0,205,0) );
        badText = createText(startX, startY + verticalSpacing * 6, textWidth, "Bads: 0", font, textSize, FlxColor.fromRGB(238,0,0) );
        shitText = createText(startX, startY + verticalSpacing * 7, textWidth, "Shits: 0", font, textSize, FlxColor.fromRGB(205,0,0) );
        missText = createText(startX, startY + verticalSpacing * 8, textWidth, "Misses: 0", font, textSize, FlxColor.fromRGB(139,0,0) );
    }

    private function createText(x:Float, y:Float, w:Float, txt:String, font:String, size:Int, ?color:FlxColor):FlxText {
        var t:FlxText = new FlxText(x, y, w, txt, size);
        t.setFormat(font, size, (color != null ? color : FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2])), LEFT, OUTLINE, FlxColor.BLACK);
        t.scrollFactor.set(0, 0);
        t.borderSize = 2.00;
        t.visible = !ClientPrefs.data.hideHud;
        state.uiGroup.add(t);
        return t;
    }

    public function update():Void {
        if (!ClientPrefs.data.Counter) return;
        if (tnhText != null) tnhText.text = "Total Notes Hit: " + state.songHits;
        if (highestcomboText != null) highestcomboText.text = "Highest Combo: " + state.highestCombo;
        if (comboText != null) comboText.text = "Combo: " + state.combo;
        if (marvelousText != null) marvelousText.text = "Marvelous: " + state.ratingsData[0].hits;
        if (sickText != null) sickText.text = "Sicks: " + state.ratingsData[1].hits;
        if (goodText != null) goodText.text = "Goods: " + state.ratingsData[2].hits;
        if (badText != null) badText.text = "Bads: " + state.ratingsData[3].hits;
        if (shitText != null) shitText.text = "Shits: " + state.ratingsData[4].hits;
        if (missText != null) missText.text = "Misses: " + state.songMisses;

        // 颜色刷新
        if (ClientPrefs.data.customColor) {
            var opponentColor:FlxColor = FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]);
            if (tnhText != null) tnhText.color = opponentColor;
            if (highestcomboText != null) highestcomboText.color = opponentColor;
            if (comboText != null) comboText.color = opponentColor;
        }
    }
}
