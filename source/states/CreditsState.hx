package states;

import objects.AttachedSprite;

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

	var offsetThing:Float = -75;
	
	// 鼠标控制相关变量
	var allowMouse:Bool = true;
	var isMouseControl:Bool = false;
	var mouseOverItem:Int = -1;
	
	// 鼠标区域偏移
	private var mouseXOffset:Float = -200; // X轴偏移
	private var mouseYOffset:Float = 30; // Y轴偏移，下移一些
	private var optionWidth:Float = 1000; // 选项宽度
	private var optionHeight:Float = 60; // 选项高度

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
		
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled) pushModCreditsToList(mod);
		#end

		var defaultList:Array<Array<String>> = [ //Name - Icon name - Description - Link - BG Color
			["Psych Engine Team"],
			["Shadow Mario",		"shadowmario",		"Main Programmer and Head of Psych Engine",					"https://ko-fi.com/shadowmario",	"444444"],
			["Riveren",				"riveren",			"Main Artist/Animator of Psych Engine",						"https://x.com/riverennn",			"14967B"],
			[""],
			["Former Engine Members"],
			["bb-panzu",			"bb",				"Ex-Programmer of Psych Engine",							"https://x.com/bbsub3",				"3E813A"],
			[""],
			["Engine Contributors"],
			["crowplexus",			"crowplexus",	"Linux Support, HScript Iris, Input System v3, and Other PRs",	"https://twitter.com/IamMorwen",	"CFCFCF"],
			["Kamizeta",			"kamizeta",			"Creator of Pessy, Psych Engine's mascot.",				"https://www.instagram.com/cewweey/",	"D21C11"],
			["MaxNeton",			"maxneton",			"Loading Screen Easter Egg Artist/Animator.",	"https://bsky.app/profile/maxneton.bsky.social","3C2E4E"],
			["Keoiki",				"keoiki",			"Note Splash Animations and Latin Alphabet",				"https://x.com/Keoiki_",			"D2D2D2"],
			["SqirraRNG",			"sqirra",			"Crash Handler and Base code for\nChart Editor's Waveform",	"https://x.com/gedehari",			"E1843A"],
			["EliteMasterEric",		"mastereric",		"Runtime Shaders support and Other PRs",					"https://x.com/EliteMasterEric",	"FFBD40"],
			["MAJigsaw77",			"majigsaw",			".MP4 Video Loader Library (hxvlc)",						"https://x.com/MAJigsaw77",			"5F5F5F"],
			["iFlicky",				"flicky",			"Composer of Psync and Tea Time\nAnd some sound effects",	"https://x.com/flicky_i",			"9E29CF"],
			["KadeDev",				"kade",				"Fixed some issues on Chart Editor and Other PRs",			"https://x.com/kade0912",			"64A250"],
			["superpowers04",		"superpowers04",	"LUA JIT Fork",												"https://x.com/superpowers04",		"B957ED"],
			["CheemsAndFriends",	"cheems",			"Creator of FlxAnimate",									"https://x.com/CheemsnFriendos",	"E1E1E1"],
			[""],
			["Funkin' Crew"],
			["ninjamuffin99",		"ninjamuffin99",	"Programmer of Friday Night Funkin'",						"https://x.com/ninja_muffin99",		"CF2D2D"],
			["PhantomArcade",		"phantomarcade",	"Animator of Friday Night Funkin'",							"https://x.com/PhantomArcade3K",	"FADC45"],
			["evilsk8r",			"evilsk8r",			"Artist of Friday Night Funkin'",							"https://x.com/evilsk8r",			"5ABD4B"],
			["kawaisprite",			"kawaisprite",		"Composer of Friday Night Funkin'",							"https://x.com/kawaisprite",		"378FC7"],
			[""],
			["Psych Engine Discord"],
			["Join the Psych Ward!", "discord", "", "https://discord.gg/2ka77eMXDv", "5165F6"]
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
		super.create();
		
		// 初始隐藏鼠标
		FlxG.mouse.visible = true;
	}

	var quitting:Bool = false;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
		}

		if(!quitting)
		{
			// 鼠标控制逻辑 - 只在点击、滚轮或明显移动时检测
			if (allowMouse && (FlxG.mouse.justPressed || FlxG.mouse.justReleased || FlxG.mouse.wheel != 0))
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				isMouseControl = true;

				var newMouseOverItem:Int = -1;
				var minDist:Float = 999999;
				
				// 检查鼠标是否悬停在某个可选项上
				for (i in 0...grpOptions.length)
				{
					if (unselectableCheck(i)) continue;
					
					var item:Alphabet = grpOptions.members[i];
					if (item == null) continue;
					
					// 计算选项的实际位置（考虑偏移）
					var itemX:Float = item.x + mouseXOffset;
					var itemY:Float = item.y + mouseYOffset;
					
					// 检查鼠标是否在选项文本区域内
					var isOverItem:Bool = (FlxG.mouse.screenX >= itemX && 
										  FlxG.mouse.screenX <= itemX + optionWidth &&
										  FlxG.mouse.screenY >= itemY && 
										  FlxG.mouse.screenY <= itemY + optionHeight);
					
					// 检查图标区域
					if (!isOverItem && iconArray[i] != null)
					{
						var icon:AttachedSprite = iconArray[i];
						if (icon.exists)
						{
							// 图标区域判定（扩大区域）
							var iconX:Float = icon.x - 20;
							var iconY:Float = icon.y - 20;
							var iconWidth:Float = icon.width + 40;
							var iconHeight:Float = icon.height + 40;
							
							isOverItem = (FlxG.mouse.screenX >= iconX && 
										 FlxG.mouse.screenX <= iconX + iconWidth &&
										 FlxG.mouse.screenY >= iconY && 
										 FlxG.mouse.screenY <= iconY + iconHeight);
						}
					}
					
					if (isOverItem)
					{
						// 计算距离
						var distance:Float = Math.sqrt(Math.pow(item.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + 
													   Math.pow(item.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
						if (distance < minDist)
						{
							minDist = distance;
							newMouseOverItem = i;
						}
					}
				}

				if (newMouseOverItem != mouseOverItem)
				{
					mouseOverItem = newMouseOverItem;
					// 鼠标悬停时高亮显示
					updateMouseHover();
				}
				
				allowMouse = true;
			}
			
			// 鼠标滚轮滚动
			if (FlxG.mouse.wheel != 0 && creditsStuff.length > 1)
			{
				// 滚轮向上为向上滑动（选择上面的选项），向下为向下滑动（选择下面的选项）
				var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
				var selectionChange:Int = -shiftMult * FlxG.mouse.wheel;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				changeSelection(selectionChange);
			}

			// 鼠标点击选择
			if (FlxG.mouse.justPressed && isMouseControl)
			{
				if (mouseOverItem != -1)
				{
					if (curSelected != mouseOverItem)
					{
						curSelected = mouseOverItem;
						changeSelection(0);
					}
					else if (creditsStuff[curSelected][3] != null && creditsStuff[curSelected][3].length > 4)
					{
						// 左键点击已选中的项目时打开链接
						CoolUtil.browserLoad(creditsStuff[curSelected][3]);
					}
				}
			}
			
			// 鼠标右键返回
			if (FlxG.mouse.justPressedRight && isMouseControl)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				quitting = true;
				FlxG.mouse.visible = false;
				return;
			}

			if(creditsStuff.length > 1 && !isMouseControl)
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

			if(controls.ACCEPT && (creditsStuff[curSelected][3] == null || creditsStuff[curSelected][3].length > 4)) {
				CoolUtil.browserLoad(creditsStuff[curSelected][3]);
			}
			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				quitting = true;
				FlxG.mouse.visible = false;
			}
		}
		
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
		super.update(elapsed);
	}
	
	function updateMouseHover()
	{
		for (num => item in grpOptions.members)
		{
			if(!unselectableCheck(num))
			{
				if (mouseOverItem == num)
				{
					// 鼠标悬停时高亮显示
					item.alpha = 0.8;
					
					// 图标也高亮
					if (iconArray[num] != null)
						iconArray[num].alpha = 0.8;
				}
				else
				{
					// 恢复原始透明度
					item.alpha = (num == curSelected) ? 1 : 0.6;
					
					// 图标也恢复
					if (iconArray[num] != null)
						iconArray[num].alpha = (num == curSelected) ? 1 : 0.6;
				}
			}
		}
	}

	var moveTween:FlxTween = null;
	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		
		if (change != 0)
		{
			do
			{
				curSelected = FlxMath.wrap(curSelected + change, 0, creditsStuff.length - 1);
			}
			while(unselectableCheck(curSelected));
		}
		
		// 更新鼠标悬停状态
		mouseOverItem = curSelected;
		updateMouseHover();

		var newColor:FlxColor = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			if(!unselectableCheck(num)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
				}
			}
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
	}

	#if MODS_ALLOWED
	function pushModCreditsToList(folder:String)
	{
		var creditsFile:String = Paths.mods(folder + '/data/credits.txt');
		
		#if TRANSLATIONS_ALLOWED
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
		super.destroy();
		FlxG.mouse.visible = true;
	}
}