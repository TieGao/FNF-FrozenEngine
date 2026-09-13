package options.objects.win10;

import options.objects.OptionCategory;
import options.psychoptions.PsychOption;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.KeyboardViewer;
import objects.HitErrorBar;

import backend.Paths;
import backend.animation.PsychAnimationController;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;

/**
 * 选项预览层
 *
 * - 构造时把 note / splash / holdcover / kbviewer / hiterrorbar 全部建好。
 * - showForCategory(cat) 按分类直接显示对应预览，不再依赖鼠标悬停。
 * - 总开关：ClientPrefs.data.optionPreview
 */
class OptionPreviewLayer extends FlxGroup
{
    // ---------- 锚点 ----------
    public var anchorX:Float = 0;
    public var anchorY:Float = 0;

    // ---------- Note / Splash ----------
    var notes:FlxTypedGroup<StrumNote>;
    var splashes:FlxTypedGroup<NoteSplash>;

    // ---------- HoldCover ----------
    var holdCoverSprites:Array<FlxSprite> = [];
    var holdCoverCfg:{
        imagePath:String,
        holdAnim:String,
        holdOffset:FlxPoint,
        scale:FlxPoint,
        fps:Int,
        alphaVal:Float
    } = null;

    // ---------- KeyboardViewer ----------
    var kbViewer:KeyboardViewer = null;

    // ---------- HitErrorBar ----------
    var hitBar:HitErrorBar = null;

    // ---------- 状态 ----------
    var currentKind:String = '';
    var currentOpt:PsychOption = null;

    static inline var NOTE_SPACING:Float = 56.0;

    public function new(x:Float = 0, y:Float = 0)
    {
        super();

        anchorX = x;
        anchorY = y;

        notes = new FlxTypedGroup<StrumNote>();
        splashes = new FlxTypedGroup<NoteSplash>();
        add(notes);
        add(splashes);

        // 全部提前建好
        buildNotePreview();
        rebuildHoldCover();
        ensureKeyboardViewer();
        ensureHitErrorBar();

        hideAll();
    }

    // =====================================================
    // Note / Splash
    // =====================================================
    function buildNotePreview():Void
    {
        var count = Note.colArray.length;
        var startX = anchorX - NOTE_SPACING * (count - 1) / 2;

        for (i in 0...count)
        {
            var nx = startX + NOTE_SPACING * i;

            var note = new StrumNote(nx, anchorY, i, 0);
            note.playAnim('static');
            notes.add(note);

            var splash = new NoteSplash(0, 0, NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix());
            splash.inEditor = true;
            splash.babyArrow = note;
            splash.ID = i;
            splash.kill();
            splashes.add(splash);
        }
    }

    function refreshNoteSkin():Void
    {
        for (note in notes)
        {
            var skin:String = Note.defaultNoteSkin;
            var customSkin:String = skin + Note.getNoteSkinPostfix();
            if (Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

            note.texture = skin;
            note.reloadNote();
            note.playAnim('static');
        }
    }

    function playSplashes():Void
    {
        var skin:String = NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix();
        for (splash in splashes)
        {
            splash.loadSplash(skin);
            splash.revive();
            splash.spawnSplashNote(0, 0, splash.ID, null, false);
            if (splash.animation.curAnim != null)
                splash.animation.curAnim.frameRate = 24;
        }
    }

    // =====================================================
    // HoldCover
    // =====================================================
    function loadHoldCoverConfig():Void
    {
        if (holdCoverCfg != null) return;

        var imagePath = "holdCover/holdCover";
        var holdAnim = "holdCoverLoop";
        var holdOffset = new FlxPoint(-3, 7);
        var scale = new FlxPoint(0.9, 0.9);
        var fps = 24;
        var alphaVal = 1.0;

        var skinName:String = ClientPrefs.data.holdCoverSkin;
        var possiblePaths:Array<String> = [];

        if (skinName != null && skinName.trim() != "" && skinName != "default")
        {
            var clean = skinName.trim();
            var formatted = clean.charAt(0).toUpperCase() + clean.substr(1).toLowerCase();
            possiblePaths.push('images/holdCover/holdCover-${formatted}.json');
        }
        possiblePaths.push('images/holdCover/holdCover.json');
        if (skinName != null && skinName.trim() != "" && skinName != "default")
        {
            var clean = skinName.trim();
            var formatted = clean.charAt(0).toUpperCase() + clean.substr(1).toLowerCase();
            possiblePaths.push('mods/holdcovers/holdCover-${formatted}.json');
        }
        possiblePaths.push('mods/holdcovers/holdCover.json');

        for (jsonPath in possiblePaths)
        {
            if (Paths.fileExists(jsonPath, TEXT))
            {
                try
                {
                    var data:Dynamic = haxe.Json.parse(Paths.getTextFromFile(jsonPath));
                    if (data != null)
                    {
                        imagePath = data.imagePath;
                        holdAnim = data.holdAnim;
                        if (data.holdOffset != null && data.holdOffset.length >= 2)
                            holdOffset.set(data.holdOffset[0], data.holdOffset[1]);
                        if (data.scale != null && data.scale.length >= 2)
                            scale.set(data.scale[0], data.scale[1]);
                        if (data.fps != null) fps = data.fps;
                        if (data.alphaVal != null) alphaVal = data.alphaVal;
                        break;
                    }
                }
                catch (e:Dynamic) {}
            }
        }

        holdCoverCfg = {
            imagePath: imagePath,
            holdAnim: holdAnim,
            holdOffset: holdOffset,
            scale: scale,
            fps: fps,
            alphaVal: alphaVal
        };
    }

    function rebuildHoldCover():Void
    {
        for (spr in holdCoverSprites)
        {
            remove(spr, true);
            spr.destroy();
        }
        holdCoverSprites = [];

        loadHoldCoverConfig();

        var frames = Paths.getSparrowAtlas(holdCoverCfg.imagePath);
        if (frames == null) return;

        var count = Note.colArray.length;
        var startX = anchorX - NOTE_SPACING * (count - 1) / 2;

        for (i in 0...count)
        {
            var spr = new FlxSprite(startX + NOTE_SPACING * i, anchorY);
            spr.animation = new PsychAnimationController(spr);
            spr.frames = frames;

            spr.animation.addByPrefix('Loop', holdCoverCfg.holdAnim, holdCoverCfg.fps, true);
            spr.animation.play('Loop', true);

            spr.scale.set(holdCoverCfg.scale.x, holdCoverCfg.scale.y);
            spr.updateHitbox();
            spr.offset.set(holdCoverCfg.holdOffset.x, holdCoverCfg.holdOffset.y);
            spr.alpha = holdCoverCfg.alphaVal * ClientPrefs.data.holdcoverAlpha;
            spr.antialiasing = ClientPrefs.data.antialiasing;

            spr.visible = false;
            add(spr);
            holdCoverSprites.push(spr);
        }
    }

    // =====================================================
    // KeyboardViewer
    // =====================================================
    function ensureKeyboardViewer():Void
    {
        if (kbViewer != null) return;

        kbViewer = new KeyboardViewer(0, 0, 4);
        kbViewer.x = anchorX;
        kbViewer.y = anchorY;
        kbViewer.visible = false;
        add(kbViewer);
    }

    function rebuildKeyboardViewer():Void
    {
        if (kbViewer != null)
        {
            remove(kbViewer, true);
            kbViewer.destroy();
            kbViewer = null;
        }
        ensureKeyboardViewer();
    }

    // =====================================================
    // HitErrorBar
    // =====================================================
    function ensureHitErrorBar():Void
    {
        if (hitBar != null) return;

        hitBar = new HitErrorBar();
        hitBar.x = anchorX - hitBar.width / 2;
        hitBar.y = anchorY - hitBar.height / 2;
        hitBar.visible = false;
        add(hitBar);
    }

    function rebuildHitErrorBar():Void
    {
        if (hitBar != null)
        {
            remove(hitBar, true);
            hitBar.destroy();
            hitBar = null;
        }
        ensureHitErrorBar();
    }

    // =====================================================
    // 对外接口
    // =====================================================

    /**
     * 按分类直接显示对应预览。
     * catId 为空 / 不匹配任何已知分类时，全部隐藏。
     */
    public function showForCategory(catId:String):Void
    {
        if (!ClientPrefs.data.optionPreview) { hideAll(); return; }
        if (catId == null) { hideAll(); return; }

        var kind = kindOfCategory(catId);
        if (kind == '') { hideAll(); return; }

        if (kind != currentKind)
        {
            currentKind = kind;
            ensureForKind(kind);
            refreshForKind(kind);
        }
        setKindVisible(kind);
    }

    /** 兼容旧调用：如果传 option，则按其 variable 决定 kind */
    public function showFor(opt:PsychOption):Void
    {
        if (opt == null) { hideAll(); return; }
        var v = opt.variable != null ? opt.variable.toLowerCase() : '';
        var kind = kindOfVariable(v);
        if (kind == '') { hideAll(); return; }

        currentOpt = opt;
        if (kind != currentKind)
        {
            currentKind = kind;
            ensureForKind(kind);
        }
        setKindVisible(kind);
    }

    function ensureForKind(kind:String):Void
    {
        switch (kind)
        {
            case 'kb':
                if (kbViewer == null) ensureKeyboardViewer();
            case 'hiterrorbar':
                if (hitBar == null) ensureHitErrorBar();
        }
    }

    /** 值保存时调用：真正重建 / 刷新 */
    public function notifyValueSaved(opt:PsychOption):Void
    {
        if (!ClientPrefs.data.optionPreview) return;
        if (opt == null) return;

        var v = opt.variable != null ? opt.variable.toLowerCase() : '';
        var kind = kindOfVariable(v);
        if (kind == '') return;

        if (kind == currentKind)
            refreshForKind(kind);
    }

    function refreshForKind(kind:String):Void
    {
        switch (kind)
        {
            case 'note':
                refreshNoteSkin();
                playSplashes();
                setKindVisible('note');
            case 'holdcover':
                rebuildHoldCover();
                setKindVisible('holdcover');
            case 'kb':
                rebuildKeyboardViewer();
                setKindVisible('kb');
            case 'hiterrorbar':
                rebuildHitErrorBar();
                setKindVisible('hiterrorbar');
        }
    }

    // ---------- 分类 → kind ----------
    // 按你 ComponentsData.hx 里 section id 来匹配（大小写不敏感）
    function kindOfCategory(catId:String):String
    {
        var id = catId.toLowerCase();

        // Hit Error Bar
        if (id == 'hiterrorbar') return 'hiterrorbar';

        // Keyboard Display
        if (id == 'keyboarddisplay') return 'kb';

        // Skin（note / splash / holdcover）
        if (id == 'skinsettings' || id == 'skin') return 'note';

        // JudgementsCounter / SongInfoText / ChartHelper 等无预览
        return '';
    }

    // ---------- variable → kind（notifyValueSaved / showFor 用）----------
    function kindOfVariable(v:String):String
    {
        if (v == 'noteskin' || v == 'splashskin' || v == 'splashalpha') return 'note';
        if (v == 'holdcoverskin' || v == 'holdcoveralpha') return 'holdcover';
        if (v == 'kb' || v == 'keyboardalpha'
            || v == 'kboffsetx' || v == 'kboffsety'
            || v == 'keyboardtimedisplay' || v == 'keyboardtime') return 'kb';
        if (v == 'hiterrorbarvisible' || v == 'pointertype'
            || v == 'hitbarlines' || v == 'hitbarlinetime'
            || v == 'hiterrorbaroffsetx' || v == 'hiterrorbaroffsety'
            || v == 'msinerrorbar') return 'hiterrorbar';
        return '';
    }

    // =====================================================
    // 显示 / 隐藏
    // =====================================================
    function setKindVisible(kind:String):Void
    {
        visible = true;

        var showNote      = (kind == 'note');
        var showHoldCover = (kind == 'holdcover');
        var showKb        = (kind == 'kb');
        var showHitBar    = (kind == 'hiterrorbar');

        if (notes != null)    notes.visible    = showNote;
        if (splashes != null) splashes.visible = showNote;

        for (spr in holdCoverSprites) spr.visible = showHoldCover;

        if (kbViewer != null) kbViewer.visible = showKb;
        if (hitBar != null)   hitBar.visible   = showHitBar;
    }

    function hideAll():Void
    {
        visible = false;

        if (notes != null)    notes.visible    = false;
        if (splashes != null) splashes.visible = false;

        for (spr in holdCoverSprites) spr.visible = false;

        if (kbViewer != null) kbViewer.visible = false;
        if (hitBar != null)   hitBar.visible   = false;

        currentKind = '';
        currentOpt = null;
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (!ClientPrefs.data.optionPreview && visible)
        {
            hideAll();
            return;
        }

        if (currentKind == 'holdcover' && holdCoverCfg != null)
        {
            for (spr in holdCoverSprites)
                spr.alpha = holdCoverCfg.alphaVal * ClientPrefs.data.holdcoverAlpha;
        }
    }

    override public function destroy():Void
    {
        for (spr in holdCoverSprites)
        {
            remove(spr, true);
            spr.destroy();
        }
        holdCoverSprites = [];

        if (kbViewer != null) { remove(kbViewer, true); kbViewer.destroy(); kbViewer = null; }
        if (hitBar != null)   { remove(hitBar, true);   hitBar.destroy();   hitBar = null; }

        super.destroy();
    }
}