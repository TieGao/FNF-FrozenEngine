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
    
    // 存储所有文本对象以便统一管理
    private var allTexts:Array<FlxText> = [];
    private var visibleItems:Int = 0;

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
        var startY:Float = FlxG.height / 2;
        if(!state.isSplitCoopMode()) 
        {
            startX = 10;
            textAlign = LEFT;
            baseColor = FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]);       
        }
        
        // 先计算可见项的数量
        var tempIndex:Int = 0;
        if (ClientPrefs.data.showTNH) tempIndex++;
        if (ClientPrefs.data.showHC) tempIndex++;
        if (ClientPrefs.data.showCB) tempIndex++;
        tempIndex++; // Marvelous
        tempIndex++; // Sicks
        tempIndex++; // Goods
        tempIndex++; // Bads
        tempIndex++; // Shits
        if (ClientPrefs.data.showMiss) tempIndex++;
        visibleItems = tempIndex;
        
        // 计算总高度
        var totalHeight:Float = visibleItems * verticalSpacing;
        // 居中计算：从中心点减去总高度的一半，再加上单个项目高度的一半
        var centeredY:Float = startY - (totalHeight / 2) + (verticalSpacing / 2);
        
        // 重置索引用于实际创建
        var currentIndex:Int = 0;
        
        // 根据设置决定是否创建各个文本项
        if (ClientPrefs.data.showTNH) {
            tnhText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Total Notes Hit: 0", font, textSize, baseColor, textAlign);
            allTexts.push(tnhText);
            currentIndex++;
        }
        
        if (ClientPrefs.data.showHC) {
            highestcomboText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Highest Combo: 0", font, textSize, baseColor, textAlign);
            allTexts.push(highestcomboText);
            currentIndex++;
        }
        
        if (ClientPrefs.data.showCB) {
            comboText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Combo: 0", font, textSize, baseColor, textAlign);
            allTexts.push(comboText);
            currentIndex++;
        }
        
        // 评级统计（始终显示）
        marvelousText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Marvelous: 0", font, textSize, FlxColor.fromRGB(255,215,0), textAlign);
        allTexts.push(marvelousText);
        currentIndex++;
        sickText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Sicks: 0", font, textSize, FlxColor.fromRGB(0,191,255), textAlign);
        allTexts.push(sickText);
        currentIndex++;
        goodText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Goods: 0", font, textSize, FlxColor.fromRGB(0,205,0), textAlign);
        allTexts.push(goodText);
        currentIndex++;
        badText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Bads: 0", font, textSize, FlxColor.fromRGB(238,0,0), textAlign);
        allTexts.push(badText);
        currentIndex++;
        shitText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Shits: 0", font, textSize, FlxColor.fromRGB(205,0,0), textAlign);
        allTexts.push(shitText);
        currentIndex++;
        
        if (ClientPrefs.data.showMiss) {
            missText = createText(startX, centeredY + verticalSpacing * currentIndex, textWidth, "Misses: 0", font, textSize, FlxColor.fromRGB(139,0,0), textAlign);
            allTexts.push(missText);
            currentIndex++;
        }
    }

    private function createText(x:Float, y:Float, w:Float, txt:String, font:String, size:Int, ?color:FlxColor, ?align:Dynamic):FlxText {
        var t:FlxText = new FlxText(x, y, w, txt, size);
        var textAlign:Dynamic = if (align != null) align else LEFT;
        t.antialiasing = ClientPrefs.data.antialiasing;
        t.setFormat(font, size, (color != null ? color : FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2])), textAlign, OUTLINE, FlxColor.BLACK);
        t.scrollFactor.set(0, 0);
        t.borderSize = 2.00;
        t.visible = !ClientPrefs.data.hideHud;
        state.uiGroup.add(t);
        return t;
    }

    public function refresh():Void {
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
        
        // 更新文本 - 只有在对应的设置开启且文本对象存在时才更新
        if (tnhText != null && ClientPrefs.data.showTNH) {
            tnhText.text = "Total Notes Hit: " + hits;
        }
        if (highestcomboText != null && ClientPrefs.data.showHC) {
            highestcomboText.text = "Highest Combo: " + highestCombo;
        }
        if (comboText != null && ClientPrefs.data.showCB) {
            comboText.text = "Combo: " + comboValue;
        }
        
        // 评级统计始终更新（除非隐藏HUD）
        if (marvelousText != null) marvelousText.text = "Marvelous: " + ratings[0].hits;
        if (sickText != null) sickText.text = "Sicks: " + ratings[1].hits;
        if (goodText != null) goodText.text = "Goods: " + ratings[2].hits;
        if (badText != null) badText.text = "Bads: " + ratings[3].hits;
        if (shitText != null) shitText.text = "Shits: " + ratings[4].hits;
        
        if (missText != null && ClientPrefs.data.showMiss) {
            missText.text = "Misses: " + misses;
        }

        // 颜色更新
        if (ClientPrefs.data.customColor) {
            var color:FlxColor = if (side == "opponent") FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]) else FlxColor.fromRGB(state.boyfriend.healthColorArray[0], state.boyfriend.healthColorArray[1], state.boyfriend.healthColorArray[2]);
            if (tnhText != null) tnhText.color = color;
            if (highestcomboText != null) highestcomboText.color = color;
            if (comboText != null) comboText.color = color;
        }
    }
}