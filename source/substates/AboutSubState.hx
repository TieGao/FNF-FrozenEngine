package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import lime.app.Application;
import backend.MusicBeatSubstate;

class AboutSubState extends MusicBeatSubstate
{
    public static var instance:AboutSubState;
    var leftState:Bool = false;

    // 版本信息
    public static var engineVersion:String = '0.5.1'; // Frozen Engine
    public static var psychVersion:String = '1.0.4'; // Psych Engine
    public static var fnfVersion:String = '0.3.0'; // FNF

    var bg:FlxSprite;
    var panel:FlxFilteredSprite;
    var titleText:FlxText;
    var infoContainer:FlxTypedGroup<FlxText>;
    var closeButton:FlxSprite;
    var closeText:FlxText;
    var hintText:FlxText;

    override function create()
    {
        super.create();

        instance = this;
        persistentUpdate = true;
        persistentDraw = true;

        // 背景遮罩
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.scrollFactor.set();
        bg.alpha = 0.0;
        add(bg);

        // 主面板
        var panelWidth:Int = Std.int(FlxG.width * 0.65);
        var panelHeight:Int = Std.int(FlxG.height * 0.82);
        panel = new FlxFilteredSprite();
        panel.makeGraphic(panelWidth, panelHeight, FlxColor.fromHSL(0, 0, 0.1, 0.95));
        panel.filters = [new BlurFilter(50, 50, BitmapFilterQuality.HIGH)];
        panel.screenCenter();
        panel.scrollFactor.set();
        panel.color = FlxColor.fromHSL(0, 0, 0.15);
        panel.alpha = 0.0;
        add(panel);

        // 标题
        titleText = new FlxText(0, panel.y + 15, panelWidth, "=== About Frozen Engine ===", 40);
        titleText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 2;
        titleText.scrollFactor.set();
        titleText.alpha = 0.0;
        titleText.screenCenter(X);
        titleText.antialiasing = ClientPrefs.data.antialiasing;
        add(titleText);

        // 分割线
        var line:FlxSprite = new FlxSprite(panel.x + 20, titleText.y + titleText.height + 8);
        line.makeGraphic(Std.int(panelWidth - 40), 2, FlxColor.WHITE);
        line.scrollFactor.set();
        line.alpha = 0.3;
        add(line);

        // 信息容器
        infoContainer = new FlxTypedGroup<FlxText>();

        for (text in infoContainer.members)
            text.antialiasing = ClientPrefs.data.antialiasing;
        
        add(infoContainer);

        var startY:Float = line.y + 18;
        var textHeight:Float = 34;
        var leftX:Float = panel.x + 30;

        // ===== 引擎版本 =====
        var header1 = createText(0, startY, "Engine Versions:", 24, FlxColor.YELLOW, CENTER, panelWidth);
        header1.screenCenter(X);
        infoContainer.add(header1);
        startY += textHeight + 4;

        var frozenText = createText(leftX, startY, "Frozen Engine v" + engineVersion, 20, FlxColor.CYAN, LEFT);
        infoContainer.add(frozenText);
        startY += textHeight;

        var psychText = createText(leftX, startY, "Psych Engine v" + psychVersion, 20, FlxColor.CYAN, LEFT);
        infoContainer.add(psychText);
        startY += textHeight;

        var fnfText = createText(leftX, startY, "Friday Night Funkin' v" + fnfVersion, 20, FlxColor.CYAN, LEFT);
        infoContainer.add(fnfText);
        startY += textHeight + 10;

        // ===== Haxe库版本 - 两列 =====
        var header2 = createText(0, startY, "Haxe Libraries:", 24, FlxColor.YELLOW, CENTER, panelWidth);
        header2.screenCenter(X);
        infoContainer.add(header2);
        startY += textHeight + 4;

        var col1X:Float = panel.x + 30;
        var col2X:Float = panel.x + panelWidth / 2 + 10;

        var limeText = createText(col1X, startY, "Lime " + getLimeVersion(), 20, FlxColor.CYAN, LEFT);
        infoContainer.add(limeText);
        
        var openflText = createText(col2X, startY, "OpenFL " + getOpenFLVersion(), 20, FlxColor.CYAN, LEFT);
        infoContainer.add(openflText);
        startY += textHeight;

        var flixelText = createText(col1X, startY, "Flixel " + getFlixelVersion(), 20, FlxColor.CYAN, LEFT);
        infoContainer.add(flixelText);
        
        var flixelAddonsText = createText(col2X, startY, "Flixel-Addons " + getFlixelAddonsVersion(), 20, FlxColor.CYAN, LEFT);
        infoContainer.add(flixelAddonsText);
        startY += textHeight;

        var hxvlcText = createText(col1X, startY, "hxvlc " + getHxvlcVersion(), 20, FlxColor.CYAN, LEFT);
        infoContainer.add(hxvlcText);
        
        var hscriptText = createText(col2X, startY, "hscript-iris " + getHscriptIrisVersion(), 20, FlxColor.CYAN, LEFT);
        infoContainer.add(hscriptText);
        startY += textHeight + 10;

        // ===== 编译日期 =====
        var header3 = createText(0, startY, "Compiled:", 24, FlxColor.YELLOW, CENTER, panelWidth);
        header3.screenCenter(X);
        infoContainer.add(header3);
        startY += textHeight + 4;

        var buildDateText = createText(leftX, startY, "Build Date " + getBuildDate(), 20, FlxColor.CYAN, LEFT);
        infoContainer.add(buildDateText);
        startY += textHeight + 10;

        // ===== 功能状态 =====
        var header4 = createText(0, startY, "Features:", 24, FlxColor.YELLOW, CENTER, panelWidth);
        header4.screenCenter(X);
        infoContainer.add(header4);
        startY += textHeight + 4;

        var features:Array<String> = [
            #if LUA_ALLOWED "Lua Scripts: ✓" #else "Lua Scripts: ✗" #end,
            #if MODS_ALLOWED "Mod Support: ✓" #else "Mod Support: ✗" #end,
            #if DISCORD_ALLOWED "Discord RPC: ✓" #else "Discord RPC: ✗" #end,
            #if VIDEOS_ALLOWED "Video Support: ✓" #else "Video Support: ✗" #end,
            #if BASE_GAME_FILES "Base Game Assets: ✓" #else "Base Game Assets: ✗" #end,
            #if TITLE_SCREEN_EASTER_EGG "Psych Easter Egg: ✓" #else "Psych Easter Egg: ✗" #end
        ];

        var perRow:Int = 2;
        var featWidth:Float = (panelWidth - 60) / perRow;
        for (i in 0...features.length)
        {
            var row:Int = Math.floor(i / perRow);
            var col:Int = i % perRow;
            var color = features[i].indexOf("✓") != -1 ? FlxColor.LIME : FlxColor.RED;
            var featText = createText(panel.x + 30 + (col * featWidth), startY + (row * (textHeight + 2)), features[i], 18, color, LEFT);
            infoContainer.add(featText);
        }

        // 关闭按钮
        closeButton = new FlxSprite(panel.x + panelWidth - 45, panel.y + 10);
        closeButton.frames = Paths.getSparrowAtlas('mainmenu/menu_credits');
        closeButton.animation.addByPrefix('idle', 'credits idle', 24, true);
        closeButton.animation.addByPrefix('selected', 'credits selected', 24, true);
        closeButton.animation.play('idle');
        closeButton.scale.set(0.7, 0.7);
        closeButton.updateHitbox();
        closeButton.scrollFactor.set();
        closeButton.alpha = 0.0;
        add(closeButton);

        closeText = createText(closeButton.x - 10, closeButton.y + closeButton.height + 4, "CLOSE", 14, FlxColor.WHITE, CENTER, closeButton.width + 20);
        closeText.alpha = 0.0;
        add(closeText);

        hintText = createText(0, FlxG.height - 20, "ESC or Click Outside to Close", 18, FlxColor.GRAY, CENTER, FlxG.width);
        hintText.alpha = 0.0;
        add(hintText);

        // 动画进入
        FlxTween.tween(bg, { alpha: 0.6 }, 0.6, { ease: FlxEase.sineIn });
        FlxTween.tween(panel, { alpha: 0.6 }, 0.4, { ease: FlxEase.sineIn, startDelay: 0.1 });
        FlxTween.tween(titleText, { alpha: 1.0 }, 0.5, { ease: FlxEase.sineIn, startDelay: 0.15 });
        FlxTween.tween(closeButton, { alpha: 0.7 }, 0.4, { ease: FlxEase.sineIn, startDelay: 0.3 });
        FlxTween.tween(closeText, { alpha: 1.0 }, 0.4, { ease: FlxEase.sineIn, startDelay: 0.3 });
        FlxTween.tween(hintText, { alpha: 0.8 }, 0.5, { ease: FlxEase.sineIn, startDelay: 0.35 });

        // 所有文本渐入
        for (i in 0...infoContainer.members.length)
        {
            var text = infoContainer.members[i];
            FlxTween.tween(text, { alpha: 1.0 }, 0.4, { ease: FlxEase.sineIn, startDelay: 0.1 + (i * 0.012) });
        }

        // 面板滑入动画
        panel.y = FlxG.height;
        FlxTween.tween(panel, { y: (FlxG.height - panelHeight) / 2 }, 0.5, { ease: FlxEase.quadOut });

        FlxG.mouse.visible = true;
    }

    // 创建带边框的文本
    function createText(x:Float, y:Float, text:String, size:Int, color:FlxColor, align:FlxTextAlign = LEFT, ?width:Float):FlxText
    {
        if (width == null) width = 0;
        var txt = new FlxText(x, y, width, text, size);
        txt.setFormat(Paths.font("vcr.ttf"), size, color, align, OUTLINE, FlxColor.BLACK);
        txt.borderSize = 1.5;
        txt.scrollFactor.set();
        txt.alpha = 0.0;
        return txt;
    }

    function getLimeVersion():String
    {
        try
        {
            var version:String = Application.current.meta.get('lime');
            return version != null ? version : 'Unknown';
        }
        catch (e)
        {
            return 'Unknown';
        }
    }

    function getOpenFLVersion():String
    {
        try
        {
            var version:String = Application.current.meta.get('openfl');
            return version != null ? version : 'Unknown';
        }
        catch (e)
        {
            return 'Unknown';
        }
    }

    function getFlixelVersion():String
    {
        try
        {
            var version:String = Application.current.meta.get('flixel');
            if (version != null) return version;
            return Std.string(FlxG.VERSION);
        }
        catch (e)
        {
            return Std.string(FlxG.VERSION);
        }
    }

    function getFlixelAddonsVersion():String
    {
        try
        {
            var meta = Application.current.meta;
            var version:String = meta.get('flixel-addons');
            if (version == null)
            {
                version = meta.get('flixel_addons');
            }
            return version != null ? version : 'Unknown';
        }
        catch (e)
        {
            return 'Unknown';
        }
    }

    function getHxvlcVersion():String
    {
        try
        {
            #if VIDEOS_ALLOWED
            var meta = Application.current.meta;
            var version:String = meta.get('hxvlc');
            if (version == null) version = meta.get('hxvlc_linux');
            return version != null ? version : '2.2.5';
            #else
            return 'N/A';
            #end
        }
        catch (e)
        {
            #if VIDEOS_ALLOWED
            return '2.2.5';
            #else
            return 'N/A';
            #end
        }
    }

    function getHscriptIrisVersion():String
    {
        try
        {
            #if HSCRIPT_ALLOWED
            var meta = Application.current.meta;
            var version:String = meta.get('hscript-iris');
            if (version == null) version = meta.get('hscript_iris');
            return version != null ? version : '1.1.3';
            #else
            return 'N/A';
            #end
        }
        catch (e)
        {
            #if HSCRIPT_ALLOWED
            return '1.1.3';
            #else
            return 'N/A';
            #end
        }
    }

    function getBuildDate():String
    {
        try
        {
            var date:String = Application.current.meta.get('buildDate');
            if (date != null) return date;
        }
        catch (e) {}

        try
        {
            var date:String = Sys.getEnv('BUILD_DATE');
            if (date != null && date != "") return date;
        }
        catch (e) {}

        return Date.now().toString();
    }

    override function update(elapsed:Float)
    {
        if (!leftState)
        {
            if (FlxG.mouse.overlaps(closeButton))
            {
                closeButton.animation.play('selected');
                closeButton.alpha = 1;
                if (FlxG.mouse.justPressed)
                {
                    closeAbout();
                }
            }
            else
            {
                closeButton.animation.play('idle');
                closeButton.alpha = 0.7;
            }

            if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
            {
                closeAbout();
            }

            if (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(panel) && !FlxG.mouse.overlaps(closeButton))
            {
                closeAbout();
            }
        }

        super.update(elapsed);
    }

    function closeAbout():Void
    {
        if (leftState) return;
        leftState = true;

        FlxTween.tween(bg, { alpha: 0.0 }, 0.5, { ease: FlxEase.sineOut });
        FlxTween.tween(panel, { alpha: 0.0 }, 0.4, { ease: FlxEase.sineOut });
        FlxTween.tween(titleText, { alpha: 0.0 }, 0.4, { ease: FlxEase.sineOut });
        FlxTween.tween(closeButton, { alpha: 0.0 }, 0.3, { ease: FlxEase.sineOut });
        FlxTween.tween(closeText, { alpha: 0.0 }, 0.3, { ease: FlxEase.sineOut });
        FlxTween.tween(hintText, { alpha: 0.0 }, 0.3, { ease: FlxEase.sineOut });

        for (text in infoContainer.members)
        {
            FlxTween.tween(text, { alpha: 0.0 }, 0.3, { ease: FlxEase.sineOut });
        }

        new FlxTimer().start(0.5, function(tmr:FlxTimer)
        {
            FlxG.mouse.visible = false;
            instance = null;
            close();
        });
    }

    override function destroy():Void
    {
        FlxG.mouse.visible = false;
        instance = null;
        super.destroy();
    }

    public static function show():Void
    {
        if (instance != null) return;
        FlxG.state.openSubState(new AboutSubState());
    }
}