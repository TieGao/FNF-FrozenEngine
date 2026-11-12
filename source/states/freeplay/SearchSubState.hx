package states.freeplay;

import backend.ui.PsychUIInputText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import options.objects.win10.Win10SearchBar;
import states.FreeplayState;

class SearchSubState extends MusicBeatSubstate
{
    var allSongs:Array<NewSongMetaData>;
    var filteredSongs:Array<NewSongMetaData> = [];
    var onSelect:NewSongMetaData->Void;

    // ---- UI 元素（需添加 Fade 效果） ----
    var bg:FlxSprite;
    var title:FlxText;
    var searchBar:Win10SearchBar;
    var noResultText:FlxText;
    var hint:FlxText;

    /** ESC 退出输入框那一帧的 BACK 要吞掉，别当成"关闭搜索窗"（同 Freeplay 本体的守卫） */
    var backGuard:Float = 0;

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

    /** 卡片左侧健康图标外伸到卡片矩形之外的宽度（SearchCard 里 icon.x = -50），裁剪视口要让出来。 */
    static inline var ICON_OVERHANG:Int = 60;

    /** 按下时记录的卡片，松手时用来判定"是否同一张卡" */
    var pressedCard:SearchCard = null;

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

        var searchContainerY:Float = 66;
        var barW:Float = 420;
        var barH:Float = 36;

        // 跟 Freeplay 顶部同款 Win10 搜索框（放大镜 / 蓝色下划线 / × 清除 / 点击聚焦）
        searchBar = new Win10SearchBar((FlxG.width - barW) * 0.5, searchContainerY, barW, barH, 16, true, true, Paths.font('vcr.ttf'));
        searchBar.setPlaceholder(Language.getPhrase('freeplay_search_placeholder', 'Search songs...'));
        searchBar.onChange = function(_oldText:String, newText:String) {
            if (!isClosing) updateFilter(newText);
        };
        // ESC 退出输入框时 PsychUIInputText 会先自己清 focusOn，同一帧的 controls.BACK
        // 会顺手把它当「关闭搜索窗」—— 开个短窗口吞掉那一次。
        searchBar.onUnfocus = function() backGuard = 0.1;
        searchBar.onSubmit = function(_) backGuard = 0.1;
        searchBar.scrollFactor.set();
        add(searchBar);
        registerFadeElement(searchBar, 1);

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

        PsychUIInputText.focusOn = searchBar.input;

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
        clearPressedCard();
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
                || (s.displayName != null && s.displayName.toLowerCase().indexOf(lower) != -1)
                || s.folder.toLowerCase().indexOf(lower) != -1;
        });

        noResultText.visible = (filteredSongs.length == 0);
        scrollOffset = 0;
        maxScroll = 0;
        repositionCards();
    }

    function clearPressedCard():Void
    {
        var card = pressedCard;
        pressedCard = null;
        if (card != null) card.setPressed(false);
    }

    function hideAllCards()
    {
        clearPressedCard();
        for (card in cardPool)
        {
            card.visible = false;
            card.resetClip();
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

        // 卡片视口：只裁上下边界。左侧放宽出健康图标的外伸量（SearchCard 里 icon.x = -50），
        // 右侧留一点给背景的柔光。
        var cardX:Float = (FlxG.width - cardWidth) / 2;
        var viewLeft:Float = cardX - ICON_OVERHANG;
        var viewRight:Float = cardX + cardWidth + 8;

        for (card in cardPool) card.visible = false;

        var poolIndex = 0;
        var pressedCardAssigned:Bool = false;
        for (i in visibleStart...visibleEnd)
        {
            if (i >= filteredSongs.length) break;
            var card = getCard(poolIndex);
            var song = filteredSongs[i];
            if (card == pressedCard)
            {
                if (card.songData == song)
                    pressedCardAssigned = true;
                else
                    clearPressedCard();
            }
            if (card.songData != song)
                card.setSong(song);
            var posY = scrollStartY + i * (cardHeight + 10) - scrollOffset;
            card.updatePosition(cardX, posY);
            card.visible = true;
            card.clipToViewport(viewLeft, scrollStartY, viewRight, scrollEndY);
            poolIndex++;
        }
        if (pressedCard != null && !pressedCardAssigned)
            clearPressedCard();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (isClosing) return; // 关闭过程中不再响应交互
        if (backGuard > 0) backGuard -= elapsed;

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
            var isOverInput = searchBar.isHovered();
            var isOverCard = false;
            for (card in cardPool)
            {
                if (card.visible && card.overlapsMouse())
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
                dragStartY = FlxG.mouse.viewY;
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
                var deltaY = FlxG.mouse.viewY - lastDragY;
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

                var deltaScroll = (dragStartY - FlxG.mouse.viewY);
                var newOffset = FlxMath.bound(dragStartScroll + deltaScroll, 0, maxScroll);
                scrollOffset = newOffset;
                repositionCards();

                lastDragY = FlxG.mouse.viewY;
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

        // ---- 点击卡片（松手生效：按下与松开必须在同一张卡上） ----
        // 修复：pressedCard 提到成员变量，跨帧保持
        if (FlxG.mouse.justPressed)
        {
            clearPressedCard();
            for (card in cardPool)
            {
                if (card.visible && card.overlapsMouse())
                {
                    pressedCard = card;
                    break;
                }
            }
            if (pressedCard != null)
                pressedCard.setPressed(true);
        }

        if (FlxG.mouse.justReleased)
        {
            var releasedCard:SearchCard = null;
            for (card in cardPool)
            {
                if (card.visible && card.overlapsMouse())
                {
                    releasedCard = card;
                    break;
                }
            }

            // 按下与松开同一张卡才触发
            if (releasedCard != null && releasedCard == pressedCard && releasedCard.songData != null)
            {
                var selectedSong = releasedCard.songData;
                clearPressedCard();
                onSelect(selectedSong);
                closeSubstate();
                return;
            }

            clearPressedCard();
        }
        else if (pressedCard != null && !FlxG.mouse.pressed)
        {
            clearPressedCard();
        }

        // 悬停效果（每帧刷新）
        for (card in cardPool)
        {
            if (card.visible)
                card.setHovered(card.overlapsMouse());
        }

        // ---- 关闭 ----
        if (FlxG.mouse.justPressedRight)
        {
            closeSubstate();
        }

        if (controls.BACK)
        {
            // 输入框正在吃键盘 / 刚被 ESC 退出：这一下属于「退出输入」，不是「关窗口」
            if (PsychUIInputText.focusOn != null || backGuard > 0) return;
            closeSubstate();
        }
    }

    // -------- 关闭子状态（带 FadeOut） --------
    function closeSubstate()
    {
        if (isClosing) return;
        isClosing = true;
        clearPressedCard();

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
        clearPressedCard();
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

// ---------- SearchCard 使用共用的 FreeplayListItem 外壳 ----------
class SearchCard extends FreeplayListItem
{
    public var songData:NewSongMetaData;
    public var icon:HealthIcon;
    var songNameText:FlxText;
    var modFolderText:FlxText;
    var colorRect:FlxSprite;
    var _cardWidth:Float;
    var _cardHeight:Float;

    public function new(song:NewSongMetaData, cardHeight:Float, cardWidth:Float)
    {
        super(Math.round(cardWidth), Math.round(cardHeight));

        _cardWidth = cardWidth;
        _cardHeight = cardHeight;

        // 浅色卡片背景（这个列表原本就不靠 blur 面板，而是实色块 + 悬停变亮）
        setColors(FlxColor.fromRGB(45, 45, 45), FlxColor.fromRGB(70, 70, 70),
            FlxColor.fromRGB(90, 90, 90), FlxColor.fromRGB(70, 70, 70), 0.85);

        // 注意：所有子元素坐标一次性在构造里定好，之后只靠 setItemPosition 移动整行，
        // 不要再在 updatePosition 里写 icon.x 之类的绝对坐标 —— 那会触发
        // FlxSpriteGroup 的增量传播，把成员坐标反复叠加，最终内容漂到左上角外。
        colorRect = new FlxSprite(0, 0);
        colorRect.makeGraphic(6, Math.round(_cardHeight), song.color);
        colorRect.alpha = 0.9;
        colorRect.x = _cardWidth - 6;
        colorRect.y = 0;
        content.add(colorRect);

        icon = new HealthIcon(song.songCharacter, false, true, song.folder);
        icon.scale.set(0.65, 0.65);
        icon.updateHitbox();
        // 图标相对 content 的坐标（content 本身在行的左上角）
        icon.x = -50;
        icon.y = (_cardHeight - icon.height) / 2;
        content.add(icon);

        songNameText = new FlxText(0, 0, 0, song.displayName, 20);
        songNameText.antialiasing = ClientPrefs.data.antialiasing;
        songNameText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
        songNameText.x = 90;
        songNameText.y = 14;
        content.add(songNameText);

        modFolderText = new FlxText(0, 0, 0, "Mod: " + song.folder, 13);
        modFolderText.antialiasing = ClientPrefs.data.antialiasing;
        modFolderText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.GRAY, LEFT);
        modFolderText.x = 90;
        modFolderText.y = _cardHeight - 22;
        content.add(modFolderText);

        setSong(song);
    }

    public function updatePosition(x:Float, y:Float)
    {
        // 走 setItemPosition：只动 bg / content 这一层，
        // 内容（icon、文字、色条）的相对坐标保持不变，不会漂移。
        setItemPosition(x, y);
    }

    public function setSong(song:NewSongMetaData)
    {
        this.songData = song;

        setHovered(false);
        setSelected(false);
        setPressed(false);

        if (songNameText != null) {
            songNameText.text = song.displayName;
            songNameText.color = FlxColor.WHITE;
        }
        if (modFolderText != null) modFolderText.text = "Mod: " + song.folder;

        if (colorRect != null) {
            colorRect.color = song.color;
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
        var over = overlapsMouse();
        setHovered(over);
        return over;
    }
}