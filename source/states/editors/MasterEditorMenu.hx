package states.editors;

import backend.WeekData;

import objects.Character;

import states.MainMenuState;
import states.OldFreeplayState;

class MasterEditorMenu extends EditorMusicState
{
	var options:Array<String> = [
		'Chart Editor',
		'Character Editor',
		'Stage Editor',
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Note Splash Editor'
	];
	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var directories:Array<String> = [null];

	private var curSelected = 0;
	private var curDirectory = 0;
	private var directoryTxt:FlxText;
	
	// 鼠标控制变量
	private var mouseOverIndex:Int = -1;
	private var lastMousePos:FlxPoint;
	private var allowMouse:Bool = true;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		for (i in 0...options.length)
		{
			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.isMenuItem = true;
			leText.targetY = i;
			grpTexts.add(leText);
			leText.snapToPosition();
		}
		
		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Mods.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if(found > -1) curDirectory = found;
		changeDirectory();
		#end
		
		FlxG.mouse.visible = true; // 显示鼠标
		lastMousePos = FlxPoint.get();
		changeSelection();

		super.create();
	}

	override function update(elapsed:Float)
	{
		// 检测鼠标移动
		if (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0)
		{
			allowMouse = true;
			checkMouseOver(); // 更新悬停检测
		}
		
		// 鼠标控制优先
		if (allowMouse)
		{
			// 鼠标滚轮滚动
			if (FlxG.mouse.wheel != 0)
			{
				changeSelection(-Std.int(FlxG.mouse.wheel));
			}
			
			// 鼠标点击处理
			if (FlxG.mouse.justPressed)
			{
				handleMouseClick();
			}
			
			// 鼠标右键返回
			if (FlxG.mouse.justPressedRight)
			{
				FlxG.mouse.visible = false;
				lastMousePos.put();
				MusicBeatState.switchState(new MainMenuState());
			}
		}
		
		// 键盘控制（始终可用）
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
			allowMouse = false; // 键盘操作时禁用鼠标
			mouseOverIndex = -1; // 清除悬停效果
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
			allowMouse = false;
			mouseOverIndex = -1;
		}
		
		#if MODS_ALLOWED
		if(controls.UI_LEFT_P)
		{
			changeDirectory(-1);
			allowMouse = false;
			mouseOverIndex = -1;
		}
		if(controls.UI_RIGHT_P)
		{
			changeDirectory(1);
			allowMouse = false;
			mouseOverIndex = -1;
		}
		#end

		if (controls.ACCEPT)
		{
			executeSelectedOption();
		}

		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			FlxG.mouse.visible = false;
			lastMousePos.put();
			MusicBeatState.switchState(new MainMenuState());
		}
		
		// 更新所有文本的显示效果
		for (num => item in grpTexts.members)
		{
			item.targetY = num - curSelected;
			
			// 优先显示选中效果，其次是悬停效果
			if (item.targetY == 0)
			{
				item.alpha = 1; // 当前选中项
			}
			else if (allowMouse && num == mouseOverIndex)
			{
				item.alpha = 0.8; // 鼠标悬停项
			}
			else
			{
				item.alpha = 0.6; // 其他项
			}
		}
		
		// 目录文本悬停效果
		#if MODS_ALLOWED
		if (allowMouse && checkMouseOverDirectory())
		{
			directoryTxt.color = 0xFFFFFF00; // 黄色
		}
		else
		{
			directoryTxt.color = 0xFFFFFFFF; // 白色
		}
		#end
		
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory += change;

		if(curDirectory < 0)
			curDirectory = directories.length - 1;
		if(curDirectory >= directories.length)
			curDirectory = 0;
	
		WeekData.setDirectoryFromWeek();
		if(directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Mods.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ' + Mods.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end
	
	// 检查鼠标悬停
	private function checkMouseOver()
	{
		var mousePos = FlxG.mouse.getPosition();
		mouseOverIndex = -1;
		
		for (i in 0...grpTexts.members.length)
		{
			var item = grpTexts.members[i];
			if (item != null && item.visible)
			{
				// 简单的矩形碰撞检测
				if (mousePos.x >= item.x - 50 && mousePos.x <= item.x + item.width + 50 &&
					mousePos.y >= item.y - 30 && mousePos.y <= item.y + item.height + 30)
				{
					mouseOverIndex = i;
					break;
				}
			}
		}
	}
	
	// 检查是否悬停在目录文本上
	private function checkMouseOverDirectory():Bool
	{
		#if MODS_ALLOWED
		var mousePos = FlxG.mouse.getPosition();
		return (mousePos.x >= directoryTxt.x && mousePos.x <= directoryTxt.x + directoryTxt.width &&
				mousePos.y >= directoryTxt.y && mousePos.y <= directoryTxt.y + directoryTxt.height);
		#else
		return false;
		#end
	}
	
	// 处理鼠标点击
	private function handleMouseClick()
	{
		// 先更新悬停检测
		checkMouseOver();
		
		// 检查是否点击了目录文本
		#if MODS_ALLOWED
		if (checkMouseOverDirectory())
		{
			// 左键向右，右键向左
			changeDirectory(FlxG.mouse.justPressedRight ? -1 : 1);
			return;
		}
		#end
		
		// 检查是否点击了选项
		if (mouseOverIndex != -1)
		{
			if (mouseOverIndex != curSelected)
			{
				// 点击不同的选项 - 只选中不执行
				curSelected = mouseOverIndex;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
			else
			{
				// 点击当前选中的选项 - 执行
				executeSelectedOption();
			}
		}
	}
	
	// 执行选中的选项
	private function executeSelectedOption()
	{
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		
		switch(options[curSelected]) {
			case 'Chart Editor':
				LoadingState.loadAndSwitchState(new ChartingState(), false);
			case 'Character Editor':
				LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
			case 'Stage Editor':
				LoadingState.loadAndSwitchState(new StageEditorState());
			case 'Week Editor':
				MusicBeatState.switchState(new WeekEditorState());
			case 'Menu Character Editor':
				MusicBeatState.switchState(new MenuCharacterEditorState());
			case 'Dialogue Editor':
				LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
			case 'Dialogue Portrait Editor':
				LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
			case 'Note Splash Editor':
				MusicBeatState.switchState(new NoteSplashEditorState());
		}
		
		FlxG.mouse.visible = false;
		FlxG.sound.music.volume = 0;
		OldFreeplayState.destroyFreeplayVocals();
	}
	
	override function destroy()
	{
		super.destroy();
		if (lastMousePos != null)
			lastMousePos.put();
		FlxG.mouse.visible = false;
	}
}