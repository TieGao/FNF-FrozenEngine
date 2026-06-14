package states;

import objects.AttachedSprite;
import backend.MouseMove;
import flixel.ui.FlxButton;
import flixel.math.FlxPoint;

class CreditsState extends MusicBeatState
{
	var curSelected:Int = -1;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<AttachedSprite> = [];
	private var creditsStuff:Array<Array<String>> = [];

	var bg:FlxSprite;
	var descText:FlxText;
	var intendedColor:FlxColor;
	var descBox:AttachedSprite;

	var space:FlxSprite;
    var starsBG:FlxBackdrop;
    var starsFG:FlxBackdrop;

	var offsetThing:Float = -75;
	
	// 鼠标控制相关变量
	var mouseOverItem:Alphabet = null;
	var lastMousePosition:FlxPoint = FlxPoint.get(0, 0);
	var mouseScrollTimer:Float = 0;
	var mouseWheelDelay:Float = 0; // 鼠标滚轮延迟
	var creditScrollPos:Float = 0;
	var creditsScroller:MouseMove;
	var creditScrollSpacing:Float = 156;
	var creditSelectableIndices:Array<Int> = [];
	var selectedItemLastFrame:Alphabet = null; // 记录上一帧选中的项目，用于滚轮动画

	override function create()
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		        space = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        space.antialiasing = ClientPrefs.data.antialiasing;
        space.updateHitbox();
        space.scrollFactor.set();
        space.alpha = 0;
        add(space);

        starsBG = new FlxBackdrop(Paths.image('starBG'));
        starsBG.setPosition(111.3, 67.95);
        starsBG.antialiasing = true;
        starsBG.updateHitbox();
        starsBG.scrollFactor.set();
        starsBG.alpha = 0;
        add(starsBG);

        starsFG = new FlxBackdrop(Paths.image('starFG'));
        starsFG.setPosition(54.3, 59.45);
        starsFG.updateHitbox();
        starsFG.antialiasing = true;
        starsFG.scrollFactor.set();
        starsFG.alpha = 0;
        add(starsFG);

		if (ClientPrefs.data.globalspace)
        {
            space.alpha = 1;
            starsBG.alpha = 1;
            starsFG.alpha = 1;
        }
		
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled) pushModCreditsToList(mod);
		#end

		var defaultList:Array<Array<String>> = [ //Name - Icon name - Description - Link - BG Color
            ["Psych Engine Team"],
            ["Shadow Mario",        "shadowmario",      "Main Programmer and Head of Psych Engine",                 "https://ko-fi.com/shadowmario",    "444444"],
            ["Riveren",             "riveren",          "Main Artist/Animator of Psych Engine",                     "https://x.com/riverennn",          "14967B"],
            [""],
            ["Former Engine Members"],
            ["bb-panzu",            "bb",               "Ex-Programmer of Psych Engine",                            "https://x.com/bbsub3",             "3E813A"],
            [""],
            ["Engine Contributors"],
            ["crowplexus",          "crowplexus",   "Linux Support, HScript Iris, Input System v3, and Other PRs",  "https://twitter.com/IamMorwen",    "CFCFCF"],
            ["Kamizeta",            "kamizeta",         "Creator of Pessy, Psych Engine's mascot.",             "https://www.instagram.com/cewweey/",   "D21C11"],
            ["MaxNeton",            "maxneton",         "Loading Screen Easter Egg Artist/Animator.",   "https://bsky.app/profile/maxneton.bsky.social","3C2E4E"],
            ["Keoiki",              "keoiki",           "Note Splash Animations and Latin Alphabet",                "https://x.com/Keoiki_",            "D2D2D2"],
            ["SqirraRNG",           "sqirra",           "Crash Handler and Base code for\nChart Editor's Waveform", "https://x.com/gedehari",           "E1843A"],
            ["EliteMasterEric",     "mastereric",       "Runtime Shaders support and Other PRs",                    "https://x.com/EliteMasterEric",    "FFBD40"],
            ["MAJigsaw77",          "majigsaw",         ".MP4 Video Loader Library (hxvlc)",                        "https://x.com/MAJigsaw77",         "5F5F5F"],
            ["iFlicky",             "flicky",           "Composer of Psync and Tea Time\nAnd some sound effects",   "https://x.com/flicky_i",           "9E29CF"],
            ["KadeDev",             "kade",             "Fixed some issues on Chart Editor and Other PRs",          "https://x.com/kade0912",           "64A250"],
            ["superpowers04",       "superpowers04",    "LUA JIT Fork",                                             "https://x.com/superpowers04",      "B957ED"],
            ["CheemsAndFriends",    "cheems",           "Creator of FlxAnimate",                                    "https://x.com/CheemsnFriendos",    "E1E1E1"],
            [""],
            ["Funkin' Crew"],
            ["ninjamuffin99",       "ninjamuffin99",    "Programmer of Friday Night Funkin'",                       "https://x.com/ninja_muffin99",     "CF2D2D"],
            ["PhantomArcade",       "phantomarcade",    "Animator of Friday Night Funkin'",                         "https://x.com/PhantomArcade3K",    "FADC45"],
            ["evilsk8r",            "evilsk8r",         "Artist of Friday Night Funkin'",                           "https://x.com/evilsk8r",           "5ABD4B"],
            ["kawaisprite",         "kawaisprite",      "Composer of Friday Night Funkin'",                         "https://x.com/kawaisprite",        "378FC7"],
            [""],
            ["Psych Engine Discord"],
            ["Join the Psych Ward!", "discord", "", "https://discord.gg/2ka77eMXDv", "5165F6"],
            [""],
            ["Frozen Engine Creator"],
            ["Ice_Axe",         "iceaxe",       "Creator of Frozen Engine","https://github.com/TieGao",     "87CEEB"],
			["Special Thanks"],
			["beihu", "novaflare", "Original of KeyboardViewer", "https://space.bilibili.com/511083372", "FF69B4"],
			["MaybeMaru","","Chart Converter Lib","https://lib.haxe.org/p/moonchart/", "FF69B4"]
        ];
		
		for(i in defaultList)
			creditsStuff.push(i);
	
		for (i => credit in creditsStuff)
		{
			var isSelectable:Bool = !unselectableCheck(i);
			var optionText:Alphabet = new Alphabet(FlxG.width / 2, 300, credit[0], !isSelectable);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			optionText.changeX = false;
			optionText.snapToPosition();
			
			// 为可选项目添加鼠标交互
			if(isSelectable)
			{
				creditSelectableIndices.push(i);
				optionText.antialiasing = ClientPrefs.data.antialiasing;
				optionText.ID = i; // 使用ID存储索引
			}
			
			grpOptions.add(optionText);

			if(isSelectable)
			{
				if(credit[5] != null)
					Mods.currentModDirectory = credit[5];

				var str:String = 'credits/missing_icon';
				if(credit[1] != null && credit[1].length > 0)
				{
					var fileName = 'credits/' + credit[1];
					if (Paths.fileExists('images/$fileName.png', IMAGE)) str = fileName;
					else if (Paths.fileExists('images/$fileName-pixel.png', IMAGE)) str = fileName + '-pixel';
				}

				var icon:AttachedSprite = new AttachedSprite(str);
				if(str.endsWith('-pixel')) icon.antialiasing = false;
				icon.xAdd = optionText.width + 10;
				icon.sprTracker = optionText;
	
				// using a FlxGroup is too much fuss!
				iconArray.push(icon);
				add(icon);
				Mods.currentModDirectory = '';

				if(curSelected == -1) curSelected = i;
			}
			else optionText.alignment = CENTERED;
		}
		
		descBox = new AttachedSprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.xAdd = -10;
		descBox.yAdd = -10;
		descBox.alphaMult = 0.6;
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, FlxG.height + offsetThing - 25, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER/*, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK*/);
		descText.scrollFactor.set();
		//descText.borderSize = 2.4;
		descBox.sprTracker = descText;
		add(descText);

		bg.color = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
		intendedColor = bg.color;
		changeSelection();
		setupCreditsScroller();
		
		// 初始化鼠标位置
		lastMousePosition.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
		
		super.create();
	}

	var quitting:Bool = false;
	var holdTime:Float = 0;
	var lastCurSelected:Int = -1; // 记录上一帧选中的索引，用于滚轮动画
	
	override function update(elapsed:Float)
	{
		starsBG.x -= 0.05;
        starsFG.x -= 0.15;
        
        if (starsBG.x < -starsBG.width) starsBG.x = 0;
        if (starsFG.x < -starsFG.width) starsFG.x = 0;

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
		}

		if(!quitting)
		{
			// 鼠标控制
			handleMouseInput(elapsed);
			
			if(creditsStuff.length > 1)
			{
				var shiftMult:Int = 1;
				if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

				var upP = controls.UI_UP_P;
				var downP = controls.UI_DOWN_P;

				if (upP)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (downP)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);
					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}
			}

			// 鼠标点击处理 - 左键点击选中，再次点击打开链接
			if(FlxG.mouse.justPressed && mouseOverItem != null && !unselectableCheck(mouseOverItem.ID))
			{
				var newIndex:Int = mouseOverItem.ID;
				
				// 如果点击的是当前选中的项目，且该项目有链接，则打开链接
				if(newIndex == curSelected)
				{
					if(creditsStuff[curSelected][3] != null && creditsStuff[curSelected][3].length > 4)
					{
						CoolUtil.browserLoad(creditsStuff[curSelected][3]);
					}
				}
				else // 否则选中该项目
				{
					curSelected = newIndex - 1; // 临时减1，让changeSelection的+1生效
					changeSelection(1);
				}
			}
			
			// 键盘确认打开链接
			if(controls.ACCEPT && (creditsStuff[curSelected][3] == null || creditsStuff[curSelected][3].length > 4)) {
				CoolUtil.browserLoad(creditsStuff[curSelected][3]);
			}
			
			// 返回
			if (controls.BACK || FlxG.mouse.justPressedRight)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				quitting = true;
			}
		}
		
		// 更新鼠标悬停效果（透明度）
		updateMouseHover();
		
		// 更新项目位置动画（原来的逻辑）
		for (item in grpOptions.members)
		{
			if(!item.bold)
			{
				var lerpVal:Float = Math.exp(-elapsed * 12);
				if(item.targetY == 0)
				{
					var lastX:Float = item.x;
					item.screenCenter(X);
					item.x = FlxMath.lerp(item.x - 70, lastX, lerpVal);
				}
				else
				{
					item.x = FlxMath.lerp(200 + -40 * Math.abs(item.targetY), item.x, lerpVal);
				}
			}
		}
		
		// 更新鼠标位置记录
		lastMousePosition.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
		
		super.update(elapsed);
	}
	
	function handleMouseInput(elapsed:Float)
	{
		// 鼠标滚轮控制 - 直接调用changeSelection，和键盘共用逻辑
		if (FlxG.mouse.wheel != 0)
		{
			mouseScrollTimer += elapsed;
			if (mouseScrollTimer >= mouseWheelDelay)
		{
			var scrollAmount:Int = -Std.int(FlxG.mouse.wheel); // 反转方向使其更自然
			changeSelection(scrollAmount);
				mouseScrollTimer = 0;
			}
		}
		else
		{
			mouseScrollTimer = mouseWheelDelay; // 重置计时器
		}
		
		// 如果鼠标移动了，检查鼠标下的项目
		if (FlxG.mouse.justMoved)
		{
			checkMouseOverItem();
		}
	}
	
	function checkMouseOverItem()
	{
		var foundItem:Alphabet = null;
		
		// 从后往前遍历，确保最上面的项目被检测到
		for (i in (grpOptions.members.length - 1)...0)
		{
			var item = grpOptions.members[i];
			if (item != null && !unselectableCheck(i) && item.visible)
			{
				// 简单的矩形碰撞检测
				if (FlxG.mouse.overlaps(item))
				{
					foundItem = item;
					break;
				}
			}
		}
		
		// 如果鼠标下的项目改变了
		if (foundItem != mouseOverItem)
		{
			mouseOverItem = foundItem;
		}
	}
	
	function updateMouseHover()
	{
		// 更新所有项目的鼠标悬停效果（透明度）
		for (i => item in grpOptions.members)
		{
			if (!unselectableCheck(i) && item.visible)
			{
				// 基础透明度由选中状态决定
				var targetAlpha:Float = (item.targetY == 0) ? 1.0 : 0.6;
				
				// 鼠标悬停时额外增加透明度（变得更亮）
				if (item == mouseOverItem)
				{
					targetAlpha = Math.min(targetAlpha + 0.2, 1.0);
				}
				
				// 平滑过渡透明度
				item.alpha = FlxMath.lerp(targetAlpha, item.alpha, 0.8);
			}
		}
	}

	var moveTween:FlxTween = null;
	function changeSelection(change:Int = 0)
	{
		// 如果change为0，不播放声音
		if(change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			
		do
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, creditsStuff.length - 1);
		}
		while(unselectableCheck(curSelected));

		if (creditsScroller != null && creditSelectableIndices.indexOf(curSelected) >= 0)
		{
			creditScrollPos = creditSelectableIndices.indexOf(curSelected) * creditScrollSpacing;
			creditsScroller.tweenData = creditScrollPos;
		}

		var newColor:FlxColor = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
		//trace('The BG color is: $newColor');
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			// 透明度现在在updateMouseHover中统一处理
		}

		descText.text = creditsStuff[curSelected][2];
		if(descText.text.trim().length > 0)
		{
			descText.visible = descBox.visible = true;
			descText.y = FlxG.height - descText.height + offsetThing - 60;
	
			if(moveTween != null) moveTween.cancel();
			moveTween = FlxTween.tween(descText, {y : descText.y + 75}, 0.25, {ease: FlxEase.sineOut});
	
			descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
			descBox.updateHitbox();
		}
		else descText.visible = descBox.visible = false;
		
		// 重置鼠标悬停项目（避免悬停状态残留）
		mouseOverItem = null;
	}

	function setupCreditsScroller():Void
	{
		if (creditSelectableIndices.length <= 1) return;

		var maxScroll:Float = Math.max(0, (creditSelectableIndices.length - 1) * creditScrollSpacing);
		// Use full-screen pointer bounds so drag continues while the cursor moves outside the visible credit text area.
		creditsScroller = new MouseMove(this, 'creditScrollPos', [0, maxScroll], [[0, FlxG.width], [0, FlxG.height]], onCreditScrollChange);
		creditsScroller.useLerp = true;
		creditsScroller.lerpSmooth = 12;
		creditsScroller.dragSensitivity = 1.6;
		creditsScroller.deceleration = 0.94;
		//creditsScroller.mouseWheelSensitivity = -200.0;
		add(creditsScroller);
	}

	function onCreditScrollChange():Void
	{
		 if (creditsScroller == null || !creditsScroller.isDragging) return;
		var newIndex:Int = Std.int(Math.round(creditScrollPos / creditScrollSpacing));
		if (newIndex < 0) newIndex = 0;
		if (newIndex >= creditSelectableIndices.length) newIndex = creditSelectableIndices.length - 1;
		var newSelected:Int = creditSelectableIndices[newIndex];
		if (newSelected != curSelected)
		{
			curSelected = newSelected;
			changeSelection(0);
		}
	}

	#if MODS_ALLOWED
	function pushModCreditsToList(folder:String)
	{
		var creditsFile:String = Paths.mods(folder + '/data/credits.txt');
		
		#if TRANSLATIONS_ALLOWED
		//trace('/data/credits-${ClientPrefs.data.language}.txt');
		var translatedCredits:String = Paths.mods(folder + '/data/credits-${ClientPrefs.data.language}.txt');
		#end

		if (#if TRANSLATIONS_ALLOWED (FileSystem.exists(translatedCredits) && (creditsFile = translatedCredits) == translatedCredits) || #end FileSystem.exists(creditsFile))
		{
			var firstarray:Array<String> = File.getContent(creditsFile).split('\n');
			for(i in firstarray)
			{
				var arr:Array<String> = i.replace('\\n', '\n').split("::");
				if(arr.length >= 5) arr.push(folder);
				creditsStuff.push(arr);
			}
			creditsStuff.push(['']);
		}
	}
	#end

	private function unselectableCheck(num:Int):Bool {
		return creditsStuff[num].length <= 1;
	}
	
	override function destroy()
	{
		// 清理资源
		lastMousePosition.put();
		super.destroy();
	}
}