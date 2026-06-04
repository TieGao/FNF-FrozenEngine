package objects;

import backend.Rating;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.PlayState;

class JudgementCounter {
    public var state:PlayState;
    public var side:String;
    public var tnhText:FlxText;
    public var highestcomboText:FlxText;
    public var comboText:FlxText;
    public var marvelousText:FlxText;
    public var sickText:FlxText;
    public var goodText:FlxText;
    public var badText:FlxText;
    public var shitText:FlxText;
    public var missText:FlxText;

    public function new(state:PlayState, ?side:String) {
        this.state = state;
        this.side = if (side == null) "player" else side;
        if (!ClientPrefs.data.Counter) return;

        var font:String = Paths.font("vcr.ttf");
        var textSize:Int = 20;
        var textWidth:Float = 280;
        var verticalSpacing:Float = 24;
        var startX:Float = if (this.side == "player") FlxG.width - textWidth - 10 else 10;
        var textAlign = if (this.side == "player") RIGHT else LEFT;
        var baseColor:FlxColor = if (this.side == "opponent") FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]) else FlxColor.fromRGB(state.boyfriend.healthColorArray[0], state.boyfriend.healthColorArray[1], state.boyfriend.healthColorArray[2]);
        var startY:Float = 210;
        if(!state.isSplitCoopMode()) 
        {
            startX = 10;
            textAlign = LEFT;
            baseColor = FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]);       
        }
        tnhText = createText(startX, startY, textWidth, "Total Notes Hit: 0", font, textSize, baseColor, textAlign);
        highestcomboText = createText(startX, startY + verticalSpacing, textWidth, "Highest Combo: 0", font, textSize, baseColor, textAlign);
        comboText = createText(startX, startY + verticalSpacing * 2, textWidth, "Combo: 0", font, textSize, baseColor, textAlign);
        marvelousText = createText(startX, startY + verticalSpacing * 3, textWidth, "Marvelous: 0", font, textSize, FlxColor.fromRGB(255,215,0), textAlign);
        sickText = createText(startX, startY + verticalSpacing * 4, textWidth, "Sicks: 0", font, textSize, FlxColor.fromRGB(0,191,255), textAlign);
        goodText = createText(startX, startY + verticalSpacing * 5, textWidth, "Goods: 0", font, textSize, FlxColor.fromRGB(0,205,0), textAlign);
        badText = createText(startX, startY + verticalSpacing * 6, textWidth, "Bads: 0", font, textSize, FlxColor.fromRGB(238,0,0), textAlign);
        shitText = createText(startX, startY + verticalSpacing * 7, textWidth, "Shits: 0", font, textSize, FlxColor.fromRGB(205,0,0), textAlign);
        missText = createText(startX, startY + verticalSpacing * 8, textWidth, "Misses: 0", font, textSize, FlxColor.fromRGB(139,0,0), textAlign);
    }

    private function createText(x:Float, y:Float, w:Float, txt:String, font:String, size:Int, ?color:FlxColor, ?align:Dynamic):FlxText {
        var t:FlxText = new FlxText(x, y, w, txt, size);
        var textAlign:Dynamic = if (align != null) align else LEFT;
        t.setFormat(font, size, (color != null ? color : FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2])), textAlign, OUTLINE, FlxColor.BLACK);
        t.scrollFactor.set(0, 0);
        t.borderSize = 2.00;
        t.visible = !ClientPrefs.data.hideHud;
        state.uiGroup.add(t);
        return t;
    }

    public function update():Void {
        if (!ClientPrefs.data.Counter) return;

        var hits:Int = if (side == "opponent") state.opponentSongHits else state.playerSongHits;
        var highestCombo:Int = if (side == "opponent") state.opponentHighestCombo else state.playerHighestCombo;
        var comboValue:Int = if (side == "opponent") state.opponentCombo else state.playerCombo;
        var ratings:Array<Rating> = if (side == "opponent") state.opponentRatingsData else state.playerRatingsData;
        var misses:Int = if (side == "opponent") state.opponentSongMisses else state.playerSongMisses;

        if (!PlayState.instance.isSplitCoopMode()) {
            hits = state.songHits;
            highestCombo = state.highestCombo;
            comboValue = state.combo;
            ratings = state.ratingsData;
            misses = state.songMisses;
        }
        if (tnhText != null) tnhText.text = "Total Notes Hit: " + hits;
        if (highestcomboText != null) highestcomboText.text = "Highest Combo: " + highestCombo;
        if (comboText != null) comboText.text = "Combo: " + comboValue;
        if (marvelousText != null) marvelousText.text = "Marvelous: " + ratings[0].hits;
        if (sickText != null) sickText.text = "Sicks: " + ratings[1].hits;
        if (goodText != null) goodText.text = "Goods: " + ratings[2].hits;
        if (badText != null) badText.text = "Bads: " + ratings[3].hits;
        if (shitText != null) shitText.text = "Shits: " + ratings[4].hits;
        if (missText != null) missText.text = "Misses: " + misses;

        if (ClientPrefs.data.customColor) {
            var color:FlxColor = if (side == "opponent") FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]) else FlxColor.fromRGB(state.boyfriend.healthColorArray[0], state.boyfriend.healthColorArray[1], state.boyfriend.healthColorArray[2]);
            if (tnhText != null) tnhText.color = color;
            if (highestcomboText != null) highestcomboText.color = color;
            if (comboText != null) comboText.color = color;
        }
    }
}
