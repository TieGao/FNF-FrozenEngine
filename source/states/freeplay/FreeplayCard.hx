package states.freeplay;

class FreeplayCard extends FlxTypedGroup<FlxSprite>
{
    public var targetY:Float = 0;
    public var songName:String;
    public var songCharacter:String;
    public var coloring:Int;
    public var week:Int;
    public var folder:String;
    
    public var bgSprite:FlxSprite;
    public var textSprite:FlxText;
    public var icon:HealthIcon;
    
    public var rhombusBg:FlxSprite;
    public var ratingSprite:FlxSprite;
    
    public var bpmText:FlxText;
    public var lengthText:FlxText;
    public var keysText:FlxText;
    private var ratingText:FlxText;

    public var isCardSelected:Bool = false;

    public function new(x:Float, y:Float, songName:String, songCharacter:String, coloring:Int, week:Int)
    {
        super();
        
        this.songName = songName;
        this.songCharacter = songCharacter;
        this.coloring = coloring;
        this.week = week;
        this.folder = Mods.currentModDirectory;
        if(this.folder == null) this.folder = '';
        
        bgSprite = new FlxSprite(x, y);
        bgSprite.makeGraphic(450, 75, 0xFF4A4A4A);
        bgSprite.alpha = 0.67;
        bgSprite.scrollFactor.set();
        
        add(bgSprite);
        
        textSprite = new FlxText(x + 60, y + 10, 380, songName, 20);
        textSprite.antialiasing = ClientPrefs.data.antialiasing;
        textSprite.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        textSprite.borderSize = 2;
        textSprite.borderColor = FlxColor.BLACK;
        textSprite.scrollFactor.set();
        add(textSprite);

        bpmText = new FlxText(x + 60, y + 35, 110, 'BPM: --', 14);
        bpmText.antialiasing = ClientPrefs.data.antialiasing;
        bpmText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        bpmText.borderSize = 1;
        bpmText.borderColor = FlxColor.BLACK;
        bpmText.scrollFactor.set();
        add(bpmText);
        
        lengthText = new FlxText(x + 180, y + 35, 130, 'LENGTH: 0:00', 14);
        lengthText.antialiasing = ClientPrefs.data.antialiasing;
        lengthText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        lengthText.borderSize = 1;
        lengthText.borderColor = FlxColor.BLACK;
        lengthText.scrollFactor.set();
        add(lengthText);

        keysText = new FlxText(x + 320, y + 35, 80, 'KEYS: --', 14);
        keysText.antialiasing = ClientPrefs.data.antialiasing;
        keysText.setFormat(Paths.font("vcr.ttf"), 14, 0xFFAAAAAA, LEFT);
        keysText.borderSize = 1;
        keysText.borderColor = FlxColor.BLACK;
        keysText.scrollFactor.set();
        add(keysText);
        
        var oldModDir = Mods.currentModDirectory;
        Mods.currentModDirectory = this.folder;
        
        icon = new HealthIcon(songCharacter, false, true, this.folder);
        icon.setPosition(x + 30, y + 5);
        icon.scale.set(0.6, 0.6);
        icon.updateHitbox();
        icon.scrollFactor.set();
        add(icon);
        
        rhombusBg = new FlxSprite(x + 400, y);

        try {
            rhombusBg.loadGraphic(Paths.image('freeplay/rhombus'));
        } catch (e:Dynamic) {
            rhombusBg.makeGraphic(60, 75, 0xFF333333);
        }
        
        rhombusBg.color = coloring;
        rhombusBg.alpha = 0.6;
        rhombusBg.scrollFactor.set();
        add(rhombusBg);
        
        ratingSprite = new FlxSprite(x + 490, y + 20);
        ratingSprite.antialiasing = true;
        ratingSprite.scrollFactor.set();
        add(ratingSprite);
        updateRatingSprite();
    }
    
    public function updateSelection(isSelected:Bool):Void
    {
        isCardSelected = isSelected;
        // 发光已移除，这里只保留状态，不执行额外操作
    }
    
    public function updateDifficultyInfo(bpm:Float, formattedLength:String, ?noteCount:Int = 0, ?difficultyRating:Float = 0.0, ?keyCount:Int = 0)
    {
        if (bpm > 0)
        {
            var bpmValue:String = Math.round(bpm) == bpm ? Std.string(Math.round(bpm)) : Std.string(FlxMath.roundDecimal(bpm, 1));
            bpmText.text = 'BPM: $bpmValue';
        }
        else
            bpmText.text = 'BPM: --';
            
        lengthText.text = 'LENGTH: $formattedLength';

        if (keysText != null)
            keysText.text = (keyCount > 0) ? 'KEYS: $keyCount' : 'KEYS: --';
    }
    
    public function updateRatingSprite(?mode:String = null)
    {
        if (mode == null) mode = ClientPrefs.getGameplaySetting('opponentplay');
        var songLowercase:String = songName.toLowerCase();
        songLowercase = songLowercase.replace(" ", "-");
        
        var bestRating:Float = 0;
        for (diff in 0...Difficulty.list.length)
        {
            var rating:Float = Highscore.getRating(songLowercase, diff, folder, mode);
            if (rating > bestRating)
            {
                bestRating = rating;
            }
        }
        
        var percent:Float = bestRating * 100;
        
        var ratingImage:String = "air";
        
        if (percent >= 99) {
            ratingImage = "P";
        } else if (percent >= 97.5) {
            ratingImage = "GP";
        } else if (percent >= 95) {
            ratingImage = "EP";
        } else if (percent >= 92.5) {
            ratingImage = "E";
        } else if (percent >= 90) {
            ratingImage = "SG";
        } else if (percent >= 80) {
            ratingImage = "G";
        } else if (percent >= 70) {
            ratingImage = "L";
        }
        
        try
        {
            ratingSprite.loadGraphic(Paths.image('freeplay/ratings/$ratingImage'));
            if (ratingText != null) ratingText.visible = false;
            ratingSprite.scale.set(0.7, 0.7);
            ratingSprite.updateHitbox();
            
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 205;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }
        catch (e:Dynamic)
        {
            trace('Failed to load rating image: $ratingImage');
            ratingSprite.makeGraphic(40, 40, FlxColor.TRANSPARENT);
            
            if (ratingText == null)
            {
                ratingText = new FlxText(ratingSprite.x, ratingSprite.y, 40, ratingImage, 20);
                ratingText.antialiasing = ClientPrefs.data.antialiasing;
                ratingText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
                ratingText.borderSize = 2;
                ratingText.borderColor = FlxColor.BLACK;
                add(ratingText);
            }
            else
            {
                ratingText.text = ratingImage;
                ratingText.x = ratingSprite.x;
                ratingText.y = ratingSprite.y;
            }
            ratingText.visible = true;
        }
    }
    
    public function updatePosition(curSelected:Float, selectedIndex:Int, isVisible:Bool = true)
    {
        var distance = targetY - curSelected;
        
        if (Math.abs(distance) > 5) 
        {
            bgSprite.visible = bgSprite.active = false;
            textSprite.visible = textSprite.active = false;
            icon.visible = icon.active = false;
            rhombusBg.visible = rhombusBg.active = false;
            ratingSprite.visible = ratingSprite.active = false;
            bpmText.visible = bpmText.active = false;
            lengthText.visible = lengthText.active = false;
            keysText.visible = keysText.active = false;
            return;
        }
        
        bgSprite.visible = bgSprite.active = true;
        textSprite.visible = textSprite.active = true;
        icon.visible = icon.active = true;
        rhombusBg.visible = rhombusBg.active = true;
        ratingSprite.visible = ratingSprite.active = true;
        bpmText.visible = bpmText.active = true;
        lengthText.visible = lengthText.active = true;
        keysText.visible = keysText.active = true;
        
        var middleY = FlxG.height * 0.5;
        var spacing = 80;
        
        var offsetY = distance * spacing;
        var offsetX = Math.abs(distance) * -60;
        
        var targetX = FlxG.width * 0.175 + offsetX;
        var targetYPos = middleY + offsetY - 30;
        
        bgSprite.x = targetX - 50;
        bgSprite.y = targetYPos;
        
        textSprite.x = targetX + 60;
        textSprite.y = targetYPos + 10;

        bpmText.x = targetX + 60;
        bpmText.y = targetYPos + 35;
        
        lengthText.x = targetX + 180;
        lengthText.y = targetYPos + 35;

        keysText.x = targetX + 320;
        keysText.y = targetYPos + 35;
        
        icon.x = targetX - 80;
        icon.y = targetYPos - 45;
        
        rhombusBg.x = targetX + 400;
        rhombusBg.y = targetYPos;
        
        if (ratingSprite.graphic != null)
        {
            ratingSprite.x = rhombusBg.x + rhombusBg.width - 100;
            ratingSprite.y = rhombusBg.y + (rhombusBg.height - ratingSprite.height) / 2;
        }

        var isSelected:Bool = (targetY == selectedIndex);
        updateSelection(isSelected);
        
        var alpha = if (isSelected) 1.0 else 0.6;
        if (isSelected) {
            bgSprite.color = 0xFF5A5A5A;
            alpha = 0.8;
        } else {
            bgSprite.color = 0xFF4A4A4A;
        }
        
        rhombusBg.color = coloring;
        
        bgSprite.alpha = alpha;
        textSprite.alpha = alpha;
        icon.alpha = alpha;
        rhombusBg.alpha = alpha;
        ratingSprite.alpha = alpha;
        bpmText.alpha = alpha;
        lengthText.alpha = alpha;
        keysText.alpha = alpha;
    }
    
    public function checkMouseOver():Bool
    {
        return FlxG.mouse.overlaps(bgSprite) || FlxG.mouse.overlaps(rhombusBg) || FlxG.mouse.overlaps(ratingSprite);
    }

    public function setAlpha(alphat:Float)
    {
        bgSprite.alpha = alphat;
        textSprite.alpha = alphat;
        icon.alpha = alphat;
        rhombusBg.alpha = alphat;
        ratingSprite.alpha = alphat;
        bpmText.alpha = alphat;
        lengthText.alpha = alphat;
        keysText.alpha = alphat;
    }
}