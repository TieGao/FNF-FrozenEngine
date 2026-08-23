package substates;

import backend.ui.PsychUIInputText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import objects.HealthIcon;
import states.FreeplayState;

class SearchSubState extends MusicBeatSubstate
{
    var allSongs:Array<NewSongMetaData>;
    var filteredSongs:Array<NewSongMetaData> = [];
    var onSelect:NewSongMetaData->Void;

    // ---- UI 元素（需添加 Fade 效果） ----
    var bg:FlxSprite;
    var title:FlxText;
    var searchIcon:FlxText;
    var inputText:PsychUIInputText;
    var searchLabel:FlxText;
    var inputLine:FlxSprite;
    var noResultText:FlxText;
    var hint:FlxText;

    // 卡片容器（不参与 Fade）
    var cardContainer:FlxTypedGroup<SearchCard>;

    // ---- Fade 控制 ----
    var fadeUI:Array<FlxSprite> = [];
    var fadeTargets:Map<FlxSprite, Float> = new Map();
    var isClosing:Bool = false;
    var fadeOutCount:Int = 0;

    // ---- 其他成员 ----
    var scrollOffset:Float = 0;
    var maxScroll:Float = 0;
    var cardHeight:Float = 75;
    var cardWidth:Float;
    var cardPool:Array<SearchCard> = [];
    var poolSize:Int = 15;
    var isDragging:Bool = false;
    var dragStartY:Float = 0;
    var dragStartScroll:Float = 0;
    var dragVelocity:Float = 0;
    var lastDragY:Float = 0;
    var lastDragTime:Float = 0;
    var isInertia:Bool = false;
    var inertiaVelocity:Float = 0;
    var scrollStartY:Float = 0;
    var scrollEndY:Float = 0;

    public function new(songs:Array<NewSongMetaData>, onSelectCallback:NewSongMetaData->Void)
    {
        super();
        this.allSongs = songs;
        this.onSelect = onSelectCallback;
        filteredSongs = [];
        cardWidth = FlxG.width * 0.4;
    }

    override function create()
    {
        super.create();

        // ---------- 创建所有 UI 元素 ----------
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.75;                   // 目标透明度
        bg.scrollFactor.set();
        add(bg);
        registerFadeElement(bg, 0.75);

        title = new FlxText(0, 20, FlxG.width, "Search Songs", 28);
        title.antialiasing = ClientPrefs.data.antialiasing;
        title.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
        title.scrollFactor.set();
        add(title);
        registerFadeElement(title, 1);

        var searchContainerX:Float = (FlxG.width - 400) / 2;
        var searchContainerY:Float = 70;

        searchIcon = new FlxText(searchContainerX, searchContainerY + 2, 30, "🔍", 22);
        searchIcon.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.GRAY, CENTER);
        searchIcon.scrollFactor.set();
        add(searchIcon);
        registerFadeElement(searchIcon, 1);

        inputText = new PsychUIInputText(Std.int(searchContainerX + 34), Std.int(searchContainerY), Std.int(360), "", 22);
        inputText.bg.visible = false;
        inputText.behindText.visible = false; 
        inputText.textObj.color = FlxColor.WHITE;
        inputText.textObj.alignment = LEFT;
        inputText.forceCase = backend.ui.CaseMode.LOWER_CASE;
        inputText.maxLength = 50;
        inputText.text = "";
        inputText.onChange = function(oldText:String, newText:String) {
            updateFilter(newText);
        };
        inputText.unfocus = function() { /* do nothing */ };
        inputText.scrollFactor.set();
        add(inputText);
        registerFadeElement(inputText, 1);

        searchLabel = new FlxText(searchContainerX + 34, searchContainerY + 4, 360, "Type to search songs...", 18);
        searchLabel.antialiasing = ClientPrefs.data.antialiasing;
        searchLabel.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.GRAY, LEFT);
        searchLabel.scrollFactor.set();
        add(searchLabel);
        registerFadeElement(searchLabel, 1);

        inputLine = new FlxSprite(searchContainerX + 30, searchContainerY + 38);
        inputLine.makeGraphic(370, 2, FlxColor.WHITE);
        inputLine.alpha = 0.4;               // 目标透明度
        inputLine.scrollFactor.set();
        add(inputLine);
        registerFadeElement(inputLine, 0.4);

        var originalOnChange = inputText.onChange;
        inputText.onChange = function(oldText:String, newText:String) {
            searchLabel.visible = (newText.length == 0);
            inputLine.alpha = (newText.length > 0) ? 0.8 : 0.4;
            // 如果尚未关闭，更新搜索
            if (!isClosing) updateFilter(newText);
            if (originalOnChange != null) originalOnChange(oldText, newText);
        };

        cardContainer = new FlxTypedGroup<SearchCard>();
        add(cardContainer);

        noResultText = new FlxText(0, FlxG.height / 2 - 20, FlxG.width, "No songs found", 28);
        noResultText.antialiasing = ClientPrefs.data.antialiasing;
        noResultText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
        noResultText.visible = false;
        noResultText.scrollFactor.set();
        add(noResultText);
        registerFadeElement(noResultText, 1);

        hint = new FlxText(0, FlxG.height - 35, FlxG.width, "Right click or ESC to close", 14);
        hint.antialiasing = ClientPrefs.data.antialiasing;
        hint.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.GRAY, CENTER);
        hint.scrollFactor.set();
        add(hint);
        registerFadeElement(hint, 1);

        // ---------- 初始化卡片（不参与 Fade） ----------
        initCardPool();

        scrollStartY = 130;
        scrollEndY = FlxG.height - 20;

        PsychUIInputText.focusOn = inputText;

        // ---------- 执行 FadeIn ----------
        for (obj in fadeUI) {
            var target = fadeTargets.get(obj);
            obj.alpha = 0;   // 初始透明
            FlxTween.tween(obj, {alpha: target}, 0.5, {ease: FlxEase.cubeOut});
        }
    }

    // 辅助：注册需要 Fade 的元素及其目标透明度
    function registerFadeElement(obj:FlxSprite, targetAlpha:Float) {
        fadeUI.push(obj);
        fadeTargets.set(obj, targetAlpha);
    }

    function initCardPool()
    {
        for (i in 0...poolSize)
        {
            var card = new SearchCard(allSongs[0], cardHeight, cardWidth);
            card.visible = false;
            cardContainer.add(card);
            cardPool.push(card);
        }
    }

    function getCard(index:Int):SearchCard
    {
        return cardPool[index % poolSize];
    }

    function updateFilter(text:String)
    {
        var lower = text.toLowerCase().trim();
        if (lower.length == 0)
        {
            filteredSongs = [];
            hideAllCards();
            noResultText.visible = false;
            scrollOffset = 0;
            return;
        }

        filteredSongs = allSongs.filter(function(s) {
            return s.songName.toLowerCase().indexOf(lower) != -1
                || s.folder.toLowerCase().indexOf(lower) != -1;
        });

        noResultText.visible = (filteredSongs.length == 0);
        scrollOffset = 0;
        maxScroll = 0;
        repositionCards();
    }

    function hideAllCards()
    {
        for (card in cardPool)
        {
            card.visible = false;
        }
    }

    function repositionCards()
    {
        var totalHeight = filteredSongs.length * (cardHeight + 10);
        var maxY = scrollEndY;
        maxScroll = Math.max(0, totalHeight - (maxY - scrollStartY));
        scrollOffset = FlxMath.bound(scrollOffset, 0, maxScroll);

        var visibleStart = Std.int(Math.floor(scrollOffset / (cardHeight + 10)));
        var visibleEnd = Std.int(Math.ceil((scrollOffset + (scrollEndY - scrollStartY)) / (cardHeight + 10)));
        visibleEnd = Std.int(Math.min(visibleEnd, filteredSongs.length));
        visibleStart = Std.int(Math.max(0, visibleStart - 1));

        for (card in cardPool) card.visible = false;

        var poolIndex = 0;
        for (i in visibleStart...visibleEnd)
        {
            if (i >= filteredSongs.length) break;
            var card = getCard(poolIndex);
            card.setSong(filteredSongs[i]);
            var posY = scrollStartY + i * (cardHeight + 10) - scrollOffset;
            card.updatePosition((FlxG.width - cardWidth) / 2, posY);
            card.visible = true;
            poolIndex++;
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (isClosing) return; // 关闭过程中不再响应交互

        // ---- 滚轮 ----
        if (FlxG.mouse.wheel != 0 && filteredSongs.length > 0)
        {
            var oldOffset = scrollOffset;
            scrollOffset = FlxMath.bound(scrollOffset - FlxG.mouse.wheel * 40, 0, maxScroll);
            if (scrollOffset != oldOffset)
            {
                repositionCards();
                inertiaVelocity = 0;
                isInertia = false;
            }
        }

        // ---- 拖拽 ----
        if (FlxG.mouse.justPressed)
        {
            var isOverInput = FlxG.mouse.overlaps(inputText) || FlxG.mouse.overlaps(searchLabel) || FlxG.mouse.overlaps(searchIcon);
            var isOverCard = false;
            for (card in cardPool)
            {
                if (card.visible && card.checkMouseOver())
                {
                    isOverCard = true;
                    break;
                }
            }
            
            if (!isOverInput && !isOverCard && filteredSongs.length > 0)
            {
                isDragging = true;
                isInertia = false;
                inertiaVelocity = 0;
                dragStartY = FlxG.mouse.screenY;
                dragStartScroll = scrollOffset;
                lastDragY = dragStartY;
                lastDragTime = Sys.time();
                dragVelocity = 0;
            }
        }

        if (isDragging)
        {
            if (FlxG.mouse.pressed)
            {
                var deltaY = FlxG.mouse.screenY - lastDragY;
                var currentTime = Sys.time();
                var dt = currentTime - lastDragTime;
                if (dt > 0.001)
                {
                    dragVelocity = -deltaY / dt;
                }
                else
                {
                    dragVelocity = 0;
                }
                
                var deltaScroll = (dragStartY - FlxG.mouse.screenY);
                var newOffset = FlxMath.bound(dragStartScroll + deltaScroll, 0, maxScroll);
                scrollOffset = newOffset;
                repositionCards();
                
                lastDragY = FlxG.mouse.screenY;
                lastDragTime = currentTime;
            }
            else
            {
                isDragging = false;
                if (Math.abs(dragVelocity) > 50 && filteredSongs.length > 0)
                {
                    isInertia = true;
                    inertiaVelocity = dragVelocity;
                }
            }
        }

        // ---- 惯性 ----
        if (isInertia && filteredSongs.length > 0)
        {
            var damping:Float = 0.96;
            var minVelocity:Float = 10;
            
            var deltaScroll = inertiaVelocity * elapsed * 60;
            var newOffset = scrollOffset + deltaScroll;
            scrollOffset = FlxMath.bound(newOffset, 0, maxScroll);
            repositionCards();
            
            inertiaVelocity *= damping;
            
            if (scrollOffset <= 0 || scrollOffset >= maxScroll)
            {
                inertiaVelocity = 0;
                isInertia = false;
            }
            else if (Math.abs(inertiaVelocity) < minVelocity)
            {
                inertiaVelocity = 0;
                isInertia = false;
            }
        }

        // ---- 键盘滚动 ----
        if (filteredSongs.length > 0)
        {
            if (FlxG.keys.justPressed.UP)
            {
                scrollOffset = FlxMath.bound(scrollOffset - 40, 0, maxScroll);
                repositionCards();
                inertiaVelocity = 0;
                isInertia = false;
            }
            if (FlxG.keys.justPressed.DOWN)
            {
                scrollOffset = FlxMath.bound(scrollOffset + 40, 0, maxScroll);
                repositionCards();
                inertiaVelocity = 0;
                isInertia = false;
            }
            if (FlxG.keys.justPressed.PAGEUP)
            {
                scrollOffset = FlxMath.bound(scrollOffset - 300, 0, maxScroll);
                repositionCards();
                inertiaVelocity = 0;
                isInertia = false;
            }
            if (FlxG.keys.justPressed.PAGEDOWN)
            {
                scrollOffset = FlxMath.bound(scrollOffset + 300, 0, maxScroll);
                repositionCards();
                inertiaVelocity = 0;
                isInertia = false;
            }
        }

        // ---- 点击卡片 ----
        if (FlxG.mouse.justPressed)
        {
            for (card in cardPool)
            {
                if (card.visible && card.checkMouseOver())
                {
                    if (card.songData != null)
                    {
                        onSelect(card.songData);
                        closeSubstate();
                        return;
                    }
                }
            }
        }

        // ---- 关闭 ----
        if (FlxG.mouse.justPressedRight)
        {
            closeSubstate();
        }

        if (controls.BACK)
        {
            if (PsychUIInputText.focusOn != null) return;
            closeSubstate();
        }
    }
    // -------- 关闭子状态（带 FadeOut） --------
    function closeSubstate()
    {
        if (isClosing) return;
        isClosing = true;

        // 清除输入焦点，防止后续输入干扰
        PsychUIInputText.focusOn = null;

        // 如果没有需要淡出的元素，直接关闭
        if (fadeUI.length == 0) {
            close();
            return;
        }

        fadeOutCount = fadeUI.length;

        for (obj in fadeUI) {
            FlxTween.tween(obj, {alpha: 0}, 0.4, {
                ease: FlxEase.cubeIn,
                onComplete: function(_) {
                    fadeOutCount--;
                    if (fadeOutCount <= 0) {
                        close();
                    }
                }
            });
        }
    }

    override function destroy()
    {
        // 清理卡片池
        for (card in cardPool) {
            card.destroy();
        }
        cardPool = [];
        // 清理映射表（可选）
        fadeTargets.clear();
        super.destroy();
    }
}

// ---------- SearchCard 保持不变（不参与 Fade） ----------
class SearchCard extends FlxTypedGroup<FlxSprite>
{
    public var songData:NewSongMetaData;
    public var bgSprite:FlxSprite;
    var icon:HealthIcon;
    var songNameText:FlxText;
    var modFolderText:FlxText;
    var colorRect:FlxSprite;
    var _isHovering:Bool = false;

    var _cardWidth:Float;
    var _cardHeight:Float;

    public function new(song:NewSongMetaData, cardHeight:Float, cardWidth:Float)
    {
        super();

        _cardWidth = cardWidth;
        _cardHeight = cardHeight;

        bgSprite = new FlxSprite(0, 0);
        bgSprite.makeGraphic(Math.round(_cardWidth), Math.round(_cardHeight), FlxColor.fromRGB(45, 45, 45));
        bgSprite.alpha = 0.85;
        add(bgSprite);

        icon = new HealthIcon(song.songCharacter, false, true, song.folder);
        icon.scale.set(0.65, 0.65);
        icon.updateHitbox();
        add(icon);

        songNameText = new FlxText(0, 0, 0, song.songName, 20);
        songNameText.antialiasing = ClientPrefs.data.antialiasing;
        songNameText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        add(songNameText);

        modFolderText = new FlxText(0, 0, 0, "Mod: " + song.folder, 13);
        modFolderText.antialiasing = ClientPrefs.data.antialiasing;
        modFolderText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.GRAY, LEFT);
        add(modFolderText);

        colorRect = new FlxSprite(0, 0);
        colorRect.makeGraphic(6, Math.round(_cardHeight), song.color);
        colorRect.alpha = 0.9;
        add(colorRect);

        setSong(song);
        updatePosition(0, 0);
    }

    public function updatePosition(x:Float, y:Float)
    {
        bgSprite.x = x;
        bgSprite.y = y;

        icon.x = x -50;
        icon.y = y -50 + (_cardHeight - icon.height) / 2;

        songNameText.x = x + icon.width + 24;
        songNameText.y = y + 14;

        modFolderText.x = songNameText.x;
        modFolderText.y = y + _cardHeight - 22;

        colorRect.x = x + _cardWidth - 6;
        colorRect.y = y;
    }

    public function setSong(song:NewSongMetaData)
    {
        this.songData = song;
        
        // 重置悬停状态
        _isHovering = false;
        bgSprite.color = FlxColor.fromRGB(45, 45, 45);
        bgSprite.alpha = 0.85;
        
        if (songNameText != null) {
            songNameText.text = song.songName;
            songNameText.color = FlxColor.WHITE;
        }
        if (modFolderText != null) modFolderText.text = "Mod: " + song.folder;
        
        // 确保色块颜色正确更新
        if (colorRect != null) {
            colorRect.color = song.color;
            // 重新绘制色块以确保颜色生效
            colorRect.makeGraphic(6, Math.round(_cardHeight), song.color);
            colorRect.alpha = 0.9;
        }

        if (icon != null)
        {
            icon.modFolder = song.folder;
            icon.changeIcon(song.songCharacter, true);
        }
    }

    public function checkMouseOver():Bool
    {
        if (!this.visible || songData == null) return false;
        var over = FlxG.mouse.overlaps(bgSprite);
        
        if (over != _isHovering)
        {
            _isHovering = over;
            if (over)
            {
                bgSprite.color = FlxColor.fromRGB(70, 70, 70);
                bgSprite.alpha = 1;
            }
            else
            {
                bgSprite.color = FlxColor.fromRGB(45, 45, 45);
                bgSprite.alpha = 0.85;
            }
        }
        
        return over;
    }
}