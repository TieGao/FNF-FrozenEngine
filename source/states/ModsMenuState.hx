package states;

import backend.WeekData;
import backend.Mods;
import backend.ContentPacks;
import backend.MouseMove;

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import haxe.Json;

import flixel.util.FlxSpriteUtil;
import objects.AttachedSprite;
import options.ModSettingsSubState;

import openfl.display.BitmapData;
import openfl.display.Shape;
import lime.utils.Assets;

import openfl.filters.BlurFilter;
import backend.FlxFilteredSprite;
import openfl.filters.BitmapFilterQuality;

private typedef ModItemChildTransform = {
	var sprite:FlxSprite;
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
	var originX:Float;
	var originY:Float;
	var offsetX:Float;
	var offsetY:Float;
}

class ModsMenuState extends MusicBeatState
{
	/** Reload 时用来在 startMod 里标记"当前在 Content 页"的前缀 */
	static inline var CONTENT_PREFIX:String = 'content:';

	var bg:FlxFilteredSprite;
	var icon:FlxSprite;
	var modName:Alphabet;
	var modDesc:FlxText;
	var modRestartText:FlxText;
	var modsList:ModsList = null;
	/** Content 体系（content/<大类>/<包>）的启用表，结构与 modsList 完全一致，切换页签只是换个指针。 */
	var contentList:ModsList = null;
	var usingContent:Bool = false;

	var bgList:FlxSprite;
	var buttonReload:MenuButton;
	//var buttonModFolder:MenuButton;
	var buttonEnableAll:MenuButton;
	var buttonDisableAll:MenuButton;
	/** MODS ⇄ CONTENT 页签切换（放在按钮栏第二行最左边） */
	var buttonSwitchList:MenuButton;
	var buttons:Array<MenuButton> = [];
	/** 置顶 / 置底 / 上移 / 下移 四个按钮，Content 页里它们没有意义，需要单独禁用 */
	var moveButtons:Array<MenuButton> = [];
	var settingsButton:MenuButton;

	// 功能栏新增的两个"上/下选择"按钮（模拟键盘上/下键）。**故意不放进 buttons 数组**，见 create() 里的注释
	var buttonSelectPrev:MenuButton;
	var buttonSelectNext:MenuButton;

	var bgTitle:FlxSprite;
	var bgDescription:FlxSprite;
	var bgButtons:FlxSprite;

	var modsGroup:FlxTypedGroup<ModItem>;
	/** mods/ 与 content/ 各自一组卡片，页签切换只换 modsGroup 指针（两组都在，未激活的整组隐藏） */
	var groupMods:FlxTypedGroup<ModItem>;
	var groupContent:FlxTypedGroup<ModItem>;
	var curSelectedMod:Int = 0;
	
	var hoveringOnMods:Bool = true;
	var curSelectedButton:Int = 0; ///-1 = Enable/Disable All, -2 = Reload
	var modNameInitialY:Float = 0;

	var noModsSine:Float = 0;
	var noModsTxt:FlxText;

	var _lastControllerMode:Bool = false;
	var startMod:String = null;
	public function new(startMod:String = null)
	{
		this.startMod = startMod;
		super();
	}
	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		persistentUpdate = false;

		modsList = Mods.parseList();
		contentList = ContentPacks.parseList();
		Mods.loadTopMod();

		// Reload 时把"当前在 Content 页的哪一项"带过来（键加前缀，免得和 mods 目录名撞）
		var contentStart:String = null;
		if(startMod != null && startMod.startsWith(CONTENT_PREFIX))
		{
			contentStart = startMod.substr(CONTENT_PREFIX.length);
			startMod = null;
		}

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		bg = new FlxFilteredSprite();
		bg.loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF665AFF;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		if(ClientPrefs.data.blurEffects)bg.filters = [new BlurFilter(4, 4, BitmapFilterQuality.HIGH)];
		add(bg);
		bg.screenCenter();

		bgList = FlxSpriteUtil.drawRoundRect(new FlxSprite(40, 40).makeGraphic(340, 650, FlxColor.TRANSPARENT), 0, 0, 340, 650, 15, 15, FlxColor.BLACK);
		bgList.alpha = 0.6;

		// 两组卡片一次建好：页签切换只换指针，避免重建时丢掉滚动位置 / 拖拽状态
		groupMods = new FlxTypedGroup<ModItem>();
		for (i => mod in modsList.all)
		{
			if(startMod == mod) curSelectedMod = i;

			var modItem:ModItem = new ModItem(mod);
			if(modsList.disabled.contains(mod))
				modItem.setDisabled(true);
			groupMods.add(modItem);
		}

		groupContent = new FlxTypedGroup<ModItem>();
		var contentIndex:Int = 0;
		for (path in contentList.all)
		{
			var item:ModItem = new ModItem(path, '${Paths.CONTENT_ROOT}/$path', contentDescription(path));
			if(contentList.disabled.contains(path)) item.setDisabled(true);
			if(contentStart == path) curSelectedMod = contentIndex;
			groupContent.add(item);
			contentIndex++;
		}

		// mods 一个都没有、但 content 有东西时，直接开在 Content 页（否则玩家会以为整个菜单是空的）
		usingContent = (contentStart != null) || (modsList.all.length < 1 && contentList.all.length > 0);
		modsGroup = usingContent ? groupContent : groupMods;
		if(usingContent && contentStart == null) curSelectedMod = 0;
		groupMods.active = groupMods.visible = !usingContent;
		groupContent.active = groupContent.visible = usingContent;
		hideGroupMembers(usingContent ? groupMods : groupContent);

		var mod:ModItem = modsGroup.members[curSelectedMod];
		if(mod != null) bg.color = mod.bgColor;
		//

		bgTitle = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgList.x + bgList.width + 20, 40).makeGraphic(840, 180, FlxColor.TRANSPARENT), 0, 0, 840, 180, 15, 15, 0, 0, FlxColor.BLACK);
		bgTitle.alpha = 0.6;
		add(bgTitle);

		icon = new FlxSprite(bgTitle.x + 15, bgTitle.y + 15);
		add(icon);

		modNameInitialY = icon.y + 80;
		modName = new Alphabet(icon.x + 165, modNameInitialY, "", true);
		modName.scaleY = 0.8;
		add(modName);

		bgDescription = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgTitle.x, bgTitle.y + 200).makeGraphic(840, 450, FlxColor.TRANSPARENT), 0, 0, 840, 450, 0, 0, 15, 15, FlxColor.BLACK);
		bgDescription.alpha = 0.6;
		add(bgDescription);
		
		modDesc = new FlxText(bgDescription.x + 15, bgDescription.y + 15, bgDescription.width - 30, "", 24);
		modDesc.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
		add(modDesc);

		var myHeight = 200;
		modRestartText = new FlxText(bgDescription.x + 15, bgDescription.y + bgDescription.height - myHeight - 25, bgDescription.width - 30, Language.getPhrase('mod_restart', '* Moving or Toggling On/Off this Mod will restart the game.'), 16);
		modRestartText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT);
		add(modRestartText);

		bgButtons = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgDescription.x, bgDescription.y + bgDescription.height - myHeight).makeGraphic(840, myHeight, FlxColor.TRANSPARENT), 0, 0, 840, myHeight, 0, 0, 15, 15, FlxColor.WHITE);
		bgButtons.color = FlxColor.BLACK;
		bgButtons.alpha = 0.2;
		add(bgButtons);

		var buttonsX = bgButtons.x + 230;
		var buttonsY = bgButtons.y + 10;

		// ---- 置顶 / 置底 放一起（画风统一：置底 = 置顶图标垂直翻转） ----

		// Move to the top
		var button = new MenuButton(buttonsX, buttonsY, 80, 80, null, makeModTopIcon(), function() moveModToPosition(0));
		add(button);
		buttons.push(button);
		moveButtons.push(button);

		// Move to the bottom
		var button = new MenuButton(buttonsX + 100, buttonsY, 80, 80, null, makeModBottomIcon(), function() moveModToPosition(curList().all.length - 1));
		add(button);
		buttons.push(button);
		moveButtons.push(button);

		// Move up
		var button = new MenuButton(buttonsX + 200, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod - 1), 54, 54);
		button.icon.animation.add('icon', [1]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		moveButtons.push(button);

		// Move down
		var button = new MenuButton(buttonsX + 300, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod + 1), 54, 54);
		button.icon.animation.add('icon', [2]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		moveButtons.push(button);

		// 第二行：页签切换 / Reload / Enable-Disable All。
		// 都用大号 VCR 文字（原来是 Alphabet —— 字形推进量太大，长标签会顶到隔壁按钮上），
		// 三个按钮等距摆开，标签按按钮内宽自动缩放，任何语言都不会互相顶撞。
		buttonSwitchList = new MenuButton(440, 590, 240, 80, listSwitchLabel(), null, function() switchList(!usingContent), 0, 0, 28);
		add(buttonSwitchList);

		buttonReload = new MenuButton(700, 590, 260, 80, Language.getPhrase('reload_button', 'RELOAD'), null, reload, 0, 0, 32);
		add(buttonReload);

		buttonEnableAll = new MenuButton(980, 590, 240, 80, Language.getPhrase('enable_all_button', 'ENABLE ALL'), null, function() setAllDisabled(false), 0, 0, 30);
		buttonEnableAll.bg.color = FlxColor.GREEN;
		buttonEnableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonEnableAll.bg.color = FlxColor.GREEN;
		add(buttonEnableAll);

		buttonDisableAll = new MenuButton(980, 590, 240, 80, Language.getPhrase('disable_all_button', 'DISABLE ALL'), null, function() setAllDisabled(true), 0, 0, 30);
		buttonDisableAll.bg.color = 0xFFFF6666;
		buttonDisableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonDisableAll.bg.color = 0xFFFF6666;
		add(buttonDisableAll);
		checkToggleButtons();

		// 两个"上/下选择"按钮，等价于焦点在卡片列表上时按一次键盘上/下键。
		// 摆在整排最左边（buttonsX 左侧那 200px 空档里）。
		//
		// ⚠️ 这两个**故意不 push 进 buttons 数组**：
		//   buttons 的下标就是 changeSelectedButton() 的左右切换顺序；不进数组 = 现有键盘
		//   导航路径一个字都不用动（键盘用户本来就有上下键，没必要再绕一圈）。
		buttonSelectPrev = new MenuButton(buttonsX - 200, buttonsY, 80, 80, null, makeModNavIcon(true), function() selectModByArrow(-1));
		add(buttonSelectPrev);

		buttonSelectNext = new MenuButton(buttonsX - 100, buttonsY, 80, 80, null, makeModNavIcon(false), function() selectModByArrow(1));
		add(buttonSelectNext);

		updateMoveButtonsEnabled();

		settingsButton = new MenuButton(buttonsX + 400, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() //Settings
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null && curMod.settings != null && curMod.settings.length > 0)
			{
				openSubState(new ModSettingsSubState(curMod.settings, curMod.folder, curMod.name));
			}
		}, 54, 54);

		settingsButton.icon.animation.add('icon', [3]);
		settingsButton.icon.animation.play('icon', true);
		add(settingsButton);
		buttons.push(settingsButton);

		var curItem:ModItem = modsGroup.members[curSelectedMod];
		if(curItem == null || curItem.settings == null || curItem.settings.length < 1)
			settingsButton.enabled = false;

		var button = new MenuButton(buttonsX + 500, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() //On/Off
		{
			toggleSelected();
		}, 54, 54);
		button.icon.animation.add('icon', [4]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		// 页签按钮也进 buttons：键盘 / 手柄左右切换才够得到它（放在队尾，不影响原导航顺序）
		buttons.push(buttonSwitchList);
		button.focusChangeCallback = function(focus:Bool) {
			if(!focus)
				button.bg.color = curList().enabled.contains(curSelectedItemKey()) ? FlxColor.GREEN : 0xFFFF6666;
		};

		maxScrollPos = Math.max(0, curList().all.length * ROW_H - (bgList.height - 10));
		cardScroller = new MouseMove(this, 'scrollPos', [0, maxScrollPos],
			[[bgList.x, bgList.x + bgList.width], [bgList.y, bgList.y + bgList.height]],
			function() { updateItemPositions(); updateScrollBar(); });
		cardScroller.useLerp = true;
		cardScroller.lerpSmooth = 12;
		cardScroller.dragSensitivity = 1.6;
		cardScroller.deceleration = 0.94;
		cardScroller.mouseWheelSensitivity = -200.0;
		cardScroller.enableMouseWheel = true;
		add(cardScroller);

		add(bgList);
		add(groupMods);
		add(groupContent);
		_lastControllerMode = controls.controllerMode;

		scrollBarTrack = new FlxSprite(bgList.x + bgList.width - 20, bgList.y + 20).makeGraphic(8, Std.int(bgList.height - 40), FlxColor.WHITE);
		scrollBarTrack.alpha = 0.3;
		add(scrollBarTrack);
		var scrollBarThumb:Float = Math.max(30, (bgList.height - 40) * ((bgList.height - 10) / Math.max(1, curList().all.length * ROW_H)));
		scrollBar = new FlxSprite(scrollBarTrack.x, scrollBarTrack.y).makeGraphic(8, Std.int(scrollBarThumb), FlxColor.WHITE);
		scrollBar.alpha = 0.6;
		add(scrollBar);


		changeSelectedMod();
		if(curList().all.length < 1) updateModDisplayData(); // 空列表也要把"没有内容"的提示画出来
		super.create();
	}
	
	var nextAttempt:Float = 1;
	var holdingMod:Bool = false;
	var mouseOffsets:FlxPoint = new FlxPoint();
	var holdingElapsed:Float = 0;

	var pressIndex:Int = -1;
	var pressedMod:ModItem = null;
	var pressStartX:Float = 0;
	var pressStartY:Float = 0;
	var pressHoldElapsed:Float = 0;
	var pressHoldCancelled:Bool = false;

	var scrollPos:Float = 0;
	var maxScrollPos:Float = 0;
	var cardScroller:MouseMove = null;
	var scrollBar:FlxSprite = null;
	var scrollBarTrack:FlxSprite = null;

	static inline var ROW_H:Int = 86;

	var holdTime:Float = 0;

	override function update(elapsed:Float)
	{
		if(controls.BACK && hoveringOnMods)
		{
			saveTxt();

			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(waitingToRestart)
			{
				//MusicBeatState.switchState(new TitleState());
				TitleState.initialized = false;
				TitleState.closedState = false;
				FlxG.sound.music.fadeOut(0.3);
				if(FreeplayState.vocals != null)
				{
					FreeplayState.vocals.fadeOut(0.3);
					FreeplayState.vocals = null;
				}
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			}
			else MusicBeatState.switchState(new MainMenuState());

			persistentUpdate = false;
			FlxG.autoPause = ClientPrefs.data.autoPause;
			FlxG.mouse.visible = false;
			return;
		}

		if(Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10)
		{
			controls.controllerMode = false;
			if(!FlxG.mouse.visible) FlxG.mouse.visible = true;
		}
		
		if(controls.controllerMode != _lastControllerMode)
		{
			if(controls.controllerMode) FlxG.mouse.visible = false;
			_lastControllerMode = controls.controllerMode;
		}

		if(controls.UI_DOWN_R || controls.UI_UP_R) holdTime = 0;

		if(curList().all.length > 0)
		{
			if(controls.controllerMode && holdingMod)
			{
				holdingMod = false;
				holdingElapsed = 0;
				pressIndex = -1;
				if(pressedMod != null) pressedMod.resetScale();
				pressedMod = null;
				pressHoldElapsed = 0;
				pressHoldCancelled = false;
				if(cardScroller != null)
				{
					cardScroller.resetInputState();
					cardScroller.inputAllow = true;
				}
				updateItemPositions();
			}

			var lastMode = hoveringOnMods;
			if(curList().all.length > 1)
			{
				if(FlxG.mouse.justPressed)
				{
					var pressedOnMod:Bool = false;
					for (i in 0...modsGroup.members.length)
					{
						var mod = modsGroup.members[i];
						if(mod != null && mod.visible && FlxG.mouse.overlaps(mod))
						{
							hoveringOnMods = true;
							var button = getButton();
							if(!FlxG.mouse.overlaps(button)) button.ignoreCheck = button.onFocus = false;
							mouseOffsets.x = FlxG.mouse.x - mod.x;
							mouseOffsets.y = FlxG.mouse.y - mod.y;
							pressIndex = i;
							pressedMod = mod;
							pressStartX = FlxG.mouse.x;
							pressStartY = FlxG.mouse.y;
							pressHoldElapsed = 0;
							pressHoldCancelled = false;
							if(cardScroller != null)
							{
								cardScroller.resetInputState();
								cardScroller.inputAllow = true;
							}
							pressedOnMod = true;
							break;
						}
					}
					if(!pressedOnMod)
					{
						// 按在列表空白处：交给 MouseMove 拖拽滚视口
						if(FlxG.mouse.x > bgList.x && FlxG.mouse.x < bgList.x + bgList.width
							&& FlxG.mouse.y > bgList.y && FlxG.mouse.y < bgList.y + bgList.height)
						{
							hoveringOnMods = true;
						}
						var button = getButton();
						if(!FlxG.mouse.overlaps(button)) button.ignoreCheck = button.onFocus = false;
					}
				}

				if(hoveringOnMods)
				{
					var shiftMult:Int = (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) || FlxG.gamepads.anyPressed(RIGHT_SHOULDER)) ? 4 : 1;
					if(controls.UI_DOWN_P)
						changeSelectedMod(shiftMult);
					else if(controls.UI_UP_P)
						changeSelectedMod(-shiftMult);
					else if(FlxG.keys.justPressed.HOME || FlxG.keys.justPressed.END ||
						FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					{
						if(FlxG.keys.justPressed.END || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)) curSelectedMod = curList().all.length-1;
						else curSelectedMod = 0;
						changeSelectedMod();
					}
					else if(controls.UI_UP || controls.UI_DOWN)
					{
						var lastHoldTime:Float = holdTime;
						holdTime += elapsed;
						if(holdTime > 0.5 && Math.floor(lastHoldTime * 8) != Math.floor(holdTime * 8)) changeSelectedMod(shiftMult * (controls.UI_UP ? -1 : 1));
					}
					else if(FlxG.mouse.pressed && pressIndex >= 0)
					{
						var curMod:ModItem = (holdingMod && pressedMod != null) ? pressedMod : modsGroup.members[pressIndex];
						if(curMod != null)
						{
							if(!holdingMod)
							{
								// Y 位移超出阈值就交给列表滚动；Y 稳定按住满 0.25 秒才锁定卡片拖拽。
								if(Math.abs(FlxG.mouse.y - pressStartY) > 10) pressHoldCancelled = true;
								if(!pressHoldCancelled)
								{
									pressHoldElapsed += elapsed;
									if(pressHoldElapsed >= 0.25)
									{
										curSelectedMod = pressIndex;
										changeSelectedMod();
										holdingMod = !usingContent; //Content 页不支持拖拽排序；changeSelectedMod 会复位 holdingMod，必须放在它之后
										if(holdingMod && cardScroller != null)
										{
											cardScroller.resetInputState();
											cardScroller.inputAllow = false;
										}
									}
								}
							}

							if(holdingMod)
							{
								var moved:Bool = false;
								for (i in 0...modsGroup.members.length)
								{
									var mod = modsGroup.members[i];
									if(mod != null && mod.visible && FlxG.mouse.overlaps(mod) && curSelectedMod != i)
									{
										moveModToPosition(i);
										moved = true;
										break;
									}
								}
								
								if(!moved)
								{
									var factor:Float = -1;
									if(FlxG.mouse.y < bgList.y)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (bgList.y - FlxG.mouse.y) / 100)));
									else if(FlxG.mouse.y > bgList.y + bgList.height)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (FlxG.mouse.y - bgList.y - bgList.height) / 100)));
		
									if(factor >= 0)
									{
										holdingElapsed += elapsed;
										if(holdingElapsed >= factor)
										{
											holdingElapsed = 0;
											var newPos = curSelectedMod;
											if(FlxG.mouse.y < bgList.y) newPos--;
											else newPos++;
											moveModToPosition(Std.int(Math.max(0, Math.min(modsGroup.length - 1, newPos))));
										}
									}
								}
								curMod.x = FlxG.mouse.x - mouseOffsets.x;
								curMod.y = FlxG.mouse.y - mouseOffsets.y;
							}
						}
					}
				}
			}

			// 短按卡片在松手时选中；长按触发排序拖拽
			if(FlxG.mouse.justReleased && pressIndex >= 0)
			{
				var wasHoldingMod:Bool = holdingMod;
				if(pressedMod != null) pressedMod.resetScale(); // 无论拖拽还是短按，松手都要复位缩放
				if(wasHoldingMod)
				{
					holdingMod = false;
					holdingElapsed = 0;
					updateItemPositions();
				}
				else if(!pressHoldCancelled && Math.max(Math.abs(FlxG.mouse.x - pressStartX), Math.abs(FlxG.mouse.y - pressStartY)) <= 10)
				{
					curSelectedMod = pressIndex;
					changeSelectedMod();
				}
				pressIndex = -1;
				pressedMod = null;
				pressHoldElapsed = 0;
				pressHoldCancelled = false;
				if(cardScroller != null)
				{
					if(wasHoldingMod) cardScroller.resetInputState();
					cardScroller.inputAllow = true;
				}
			}

			if(lastMode == hoveringOnMods)
			{
				if(hoveringOnMods)
				{
					if(controls.UI_RIGHT_P)
					{
						hoveringOnMods = false;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						curSelectedButton = 0;
						changeSelectedButton();
					}
				}
				else 
				{
					if(controls.BACK)
					{
						hoveringOnMods = true;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						changeSelectedMod();
					}
					else if(controls.ACCEPT)
					{
						var button = getButton();
						if(button.onClick != null) button.onClick();
					}
					else if(curSelectedButton < 0)
					{
						if(controls.UI_UP_P)
						{
							switch(curSelectedButton)
							{
								case -2:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
								case -1:
									changeSelectedButton(-1);
							}
						}
						else if(controls.UI_DOWN_P)
						{
							switch(curSelectedButton)
							{
								case -2:
									changeSelectedButton(1);
								case -1:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
							}
						}
						else if(controls.UI_RIGHT_P)
						{
							var button = getButton();
							button.ignoreCheck = button.onFocus = false;
							curSelectedButton = 0;
							changeSelectedButton();
						}
					}
					else if(controls.UI_LEFT_P)
						changeSelectedButton(-1);
					else if(controls.UI_RIGHT_P)
						changeSelectedButton(1);
				}
			}
		}
		else
		{
			// 当前列表（mods 或 content）是空的：闪烁提示文字，并定时重新扫盘
			noModsSine += 180 * elapsed;
			if(noModsTxt != null) noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);

			nextAttempt -= elapsed;
			if(nextAttempt < 0)
			{
				nextAttempt = 1;
				if(usingContent)
				{
					ContentPacks.invalidate();
					contentList = ContentPacks.parseList();
					if(contentList.all.length > 0)
					{
						trace('content pack(s) found! reloading');
						reload();
					}
				}
				else
				{
					@:privateAccess
					Mods.updateModList();
					modsList = Mods.parseList();
					if(modsList.all.length > 0)
					{
						trace('mod(s) found! reloading');
						reload();
					}
				}
			}
		}
		super.update(elapsed);
	}

	function changeSelectedButton(add:Int = 0)
	{
		var max = buttons.length - 1;
		
		var button = getButton();
		button.ignoreCheck = button.onFocus = false;

		curSelectedButton += add;
		if(curSelectedButton < -2)
			curSelectedButton = -2;
		else if(curSelectedButton > max)
			curSelectedButton = max;

		// 跳过被禁用的按钮（Content 页整排排序按钮、只有 1 个 mod 时的排序按钮），
		// 否则焦点会停在按不动的按钮上，看起来像"卡住了"
		var dir:Int = (add >= 0) ? 1 : -1;
		var guard:Int = 0;
		while(guard < buttons.length + 2 && curSelectedButton >= 0 && !getButton().enabled)
		{
			var next:Int = curSelectedButton + dir;
			if(next < 0 || next > max) break;
			curSelectedButton = next;
			guard++;
		}

		var button = getButton();
		button.ignoreCheck = button.onFocus = true;

		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod != null) curMod.selectBg.visible = false;
		if(curSelectedButton < 0)
		{
			bgButtons.color = FlxColor.BLACK;
			bgButtons.alpha = 0.2;
		}
		else
		{
			bgButtons.color = FlxColor.WHITE;
			bgButtons.alpha = 0.8;
		}

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function getButton()
	{
		switch(curSelectedButton)
		{
			case -2: return buttonReload;
			case -1: return buttonEnableAll.enabled ? buttonEnableAll : buttonDisableAll;
		}

		if(curList().all.length < 1) return buttonReload; //prevent possible crash from my irresponsibility
		return buttons[Std.int(Math.max(0, Math.min(buttons.length-1, curSelectedButton)))];
	}

	function changeSelectedMod(add:Int = 0, isMouseWheel:Bool = false)
	{
		var max = curList().all.length - 1;
		if(max < 0) return;

		if(hoveringOnMods)
		{
			var button = getButton();
			button.ignoreCheck = button.onFocus = false;
		}

		var lastSelected = curSelectedMod;
		curSelectedMod += add;

		var limited:Bool = false;
		if(curSelectedMod < 0)
		{
			curSelectedMod = 0;
			limited = true;
		}
		else if(curSelectedMod > max)
		{
			curSelectedMod = max;
			limited = true;
		}
		
		if(!isMouseWheel && limited && Math.abs(add) == 1)
		{
			if(add < 0) // pressed up on first mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -1;
				changeSelectedButton();
				return;
			}
			else // pressed down on last mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -2;
				changeSelectedButton();
				return;
			}
		}
		
		holdingMod = false;
		holdingElapsed = 0;
		updateModDisplayData();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		
		if(hoveringOnMods)
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null) curMod.selectBg.visible = true;
			bgButtons.color = FlxColor.BLACK;
			bgButtons.alpha = 0.2;
		}
	}

	/**
	 * 功能栏"上/下选择"按钮的点击处理 —— 等价于"焦点在卡片列表上时按一次键盘上/下键"。
	 *
	 * 不直接改 curSelectedMod，而是走 changeSelectedMod，是为了把**边界行为**也对齐键盘：
	 * 第一张再往上会跳到 Enable/Disable All 按钮，最后一张再往下会跳到 Reload 按钮。
	 *
	 * 先 `hoveringOnMods = true` 再调：changeSelectedMod 只负责改数据，选中框是
	 * updateItemPositions 里按 `i == curSelectedMod && hoveringOnMods` 画的，焦点还留在
	 * 按钮栏的话点了看不出反应（列表上不显示选中项，只有右侧信息面板在变）。
	 */
	function selectModByArrow(add:Int)
	{
		hoveringOnMods = true;
		changeSelectedMod(add);
	}

	/**
	 * 上/下选择按钮的图标（54×54），矢量现画，跟 options.objects.win8.CharmIcons 一个路子：
	 * 零资源、不用重导图集、要换尺寸 / 颜色随时改（所以没去动 assets/shared/images/
	 * modsMenuButtons.png 那个 5 帧 54×54 的图集）。
	 *
	 * 形状上刻意区分语义：**实心三角 = 把卡片挪到别的位置**，
	 * **折角箭头(chevron) = 把选中光标挪一格**。
	 *
	 * ⚠️ MenuButton 会把 icon.color 在黑(选中)/白(未选中)之间切，所以这里只能画纯白 + alpha。
	 * ⚠️ 走的是 MenuButton 的 img 分支且不传 animWidth/animHeight → 单帧，别再调
	 *    `icon.animation.add(...)`（非动画图集没有 animation controller，会空指针）。
	 */
	static function makeModNavIcon(up:Bool):FlxGraphic
	{
		var size:Int = 54;
		var shape:Shape = new Shape();
		var g = shape.graphics;
		g.lineStyle(size * 0.15, FlxColor.WHITE, 1);

		var tipY:Float = up ? size * 0.26 : size * 0.74;
		var tailY:Float = up ? size * 0.74 : size * 0.26;
		g.moveTo(size * 0.18, tailY);
		g.lineTo(size * 0.50, tipY);
		g.lineTo(size * 0.82, tailY);

		var bmd:BitmapData = new BitmapData(size, size, true, 0x00000000);
		bmd.draw(shape);
		return FlxGraphic.fromBitmapData(bmd, false, up ? 'modsMenuNavUp' : 'modsMenuNavDown');
	}

	/**
	 * 置顶图标：上方一条横线（表示"顶"）+ 下方一个向上实心三角。
	 * 置底图标 = 同一个图垂直翻转，画风 100% 一致（见 makeModBottomIcon）。
	 */
	static function makeModTopIcon():FlxGraphic
	{
		var size:Int = 54;
		var shape:Shape = new Shape();
		var g = shape.graphics;

		// 顶部横线
		g.lineStyle(size * 0.15, FlxColor.WHITE, 1);
		g.moveTo(size * 0.16, size * 0.16);
		g.lineTo(size * 0.84, size * 0.16);

		// 向上实心三角
		g.beginFill(FlxColor.WHITE, 1);
		g.moveTo(size * 0.20, size * 0.72);
		g.lineTo(size * 0.80, size * 0.72);
		g.lineTo(size * 0.50, size * 0.36);
		g.endFill();

		var bmd:BitmapData = new BitmapData(size, size, true, 0x00000000);
		bmd.draw(shape);
		return FlxGraphic.fromBitmapData(bmd, false, 'modsMenuNavTop');
	}

	/**
	 * 置底图标：直接拿置顶图标做垂直翻转，保证两者画风完全一致。
	 * 用 BitmapData 手动翻转（FlxGraphic 不直接支持 flip），复刻一圈像素即可。
	 */
	static function makeModBottomIcon():FlxGraphic
	{
		var size:Int = 54;
		var top:BitmapData = new BitmapData(size, size, true, 0x00000000);

		// 重新画一遍置顶形状（避免依赖 makeModTopIcon 的缓存实例被别处改色）
		var shape:Shape = new Shape();
		var g = shape.graphics;
		g.lineStyle(size * 0.15, FlxColor.WHITE, 1);
		g.moveTo(size * 0.16, size * 0.16);
		g.lineTo(size * 0.84, size * 0.16);
		g.beginFill(FlxColor.WHITE, 1);
		g.moveTo(size * 0.20, size * 0.72);
		g.lineTo(size * 0.80, size * 0.72);
		g.lineTo(size * 0.50, size * 0.36);
		g.endFill();
		top.draw(shape);

		// 垂直翻转
		var flipped:BitmapData = new BitmapData(size, size, true, 0x00000000);
		var m = new openfl.geom.Matrix();
		m.scale(1, -1);
		m.translate(0, size);
		flipped.draw(top, m);

		return FlxGraphic.fromBitmapData(flipped, false, 'modsMenuNavBottom');
	}

	function updateModDisplayData()
	{
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod == null)
		{
			showEmptyDetail();
			return;
		}
		hideEmptyDetail();

		FlxTween.cancelTweensOf(bg);
		FlxTween.color(bg, 1, bg.color, curMod.bgColor);

		scrollSelectedIntoView();
		updateItemPositions();

		icon.loadGraphic(curMod.icon.graphic, true, 150, 150);
		icon.antialiasing = curMod.icon.antialiasing;

		if(curMod.totalFrames > 0)
		{
			icon.animation.add("icon", [for (i in 0...curMod.totalFrames) i], curMod.iconFps);
			icon.animation.play("icon");
			icon.animation.curAnim.curFrame = curMod.icon.animation.curAnim.curFrame;
		}

		if(modName.scaleX != 0.8) modName.setScale(0.8);
		modName.text = curMod.name;
		var newScale = Math.min(620 / (modName.width / 0.8), 0.8);
		modName.setScale(newScale, Math.min(newScale * 1.35, 0.8));
		modName.y = modNameInitialY - (modName.height / 2);

		// 内容包的开关不需要重启（Freeplay / Story 每次进都会重扫），换一句提示
		if(curMod.mustRestart)
		{
			modRestartText.text = Language.getPhrase('mod_restart', '* Moving or Toggling On/Off this Mod will restart the game.');
			modRestartText.visible = true;
		}
		else if(curMod.contentRoot != null)
		{
			modRestartText.text = Language.getPhrase('content_restart_note', '* On/Off takes effect the next time the song lists are loaded (no restart needed).');
			modRestartText.visible = true;
		}
		else modRestartText.visible = false;

		modDesc.text = curMod.desc;

		for (button in buttons) if(button.focusChangeCallback != null) button.focusChangeCallback(button.onFocus);
		settingsButton.enabled = (curMod.settings != null && curMod.settings.length > 0);
	}

	/**
	 * 把选中项滚进视口（仅在越界时动；tweenData 同值会被 MouseMove 跳过）。
	 */
	function scrollSelectedIntoView()
	{
		if(cardScroller == null) return;
		var viewTop:Float = bgList.y + 5;
		var viewBottom:Float = bgList.y + bgList.height - 5;
		var itemTop:Float = viewTop + curSelectedMod * ROW_H;
		var visibleTop:Float = itemTop - scrollPos;
		var visibleBottom:Float = visibleTop + ROW_H;
		var target:Float = scrollPos;
		if(visibleTop < viewTop) target = itemTop - viewTop;
		else if(visibleBottom > viewBottom) target = itemTop + ROW_H - viewBottom;
		target = Math.max(0, Math.min(maxScrollPos, target));
		if(target != scrollPos) cardScroller.tweenData = target;
	}

	function updateScrollBar()
	{
		if(scrollBar == null || scrollBarTrack == null) return;
		if(maxScrollPos <= 0)
		{
			scrollBar.alpha = 0;
			return;
		}
		scrollBar.alpha = 0.6;
		scrollBar.y = scrollBarTrack.y + (scrollPos / maxScrollPos) * (scrollBarTrack.height - scrollBar.height);
	}

	function updateItemPositions()
	{
		for (i => mod in modsGroup.members)
		{
			if(mod == null)
			{
				trace('Mod #$i is null, maybe it was ' + curList().all[i]);
				continue;
			}

			mod.x = bgList.x + 5;
			mod.y = bgList.y + 5 + ROW_H * i - scrollPos;

			mod.updateClip(bgList.x, bgList.y + 5, bgList.width, bgList.height - 10, ROW_H);

			mod.alpha = 0.6;
			if(i == curSelectedMod) mod.alpha = 1;
			mod.selectBg.visible = (i == curSelectedMod && hoveringOnMods);
		}
	}

	var waitingToRestart:Bool = false;
	function moveModToPosition(?mod:String = null, position:Int = 0)
	{
		// Content 页没有"加载顺序"这回事，排序/拖拽一律忽略
		if(usingContent) return;

		if(mod == null) mod = curList().all[curSelectedMod];
		if(position >= curList().all.length) position = 0;
		else if(position < 0) position = curList().all.length-1;

		trace('Moved mod $mod to position $position');
		var id:Int = curList().all.indexOf(mod);
		if(position == id) return;

		var curMod:ModItem = modsGroup.members[id];
		if(curMod == null) return;

		if(curMod.mustRestart || modsGroup.members[position].mustRestart) waitingToRestart = true;

		modsGroup.remove(curMod, true);
		curList().all.remove(mod);
		//if(position > id) position--;
		modsGroup.insert(position, curMod);
		curList().all.insert(position, mod);

		curSelectedMod = position;
		if(curMod != null) curMod.resetScale(); // 拖拽排序会改 group 结构，强制复位缩放
		updateModDisplayData();
		updateItemPositions();
		
		if(!hoveringOnMods)
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null) curMod.selectBg.visible = false;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function checkToggleButtons()
	{
		buttonEnableAll.visible = buttonEnableAll.enabled = curList().disabled.length > 0;
		buttonDisableAll.visible = buttonDisableAll.enabled = !buttonEnableAll.visible;
	}

	// ============================================================
	//  MODS / CONTENT 双列表
	// ============================================================

	/** 当前页签对应的列表 —— 两者结构完全一致（ModsList），下面所有逻辑都能共用。 */
	inline function curList():ModsList
		return usingContent ? contentList : modsList;

	/** 当前选中项的键：mods 是 mods/ 下的目录名，content 是相对 content/ 的路径。 */
	function curSelectedItemKey():String
	{
		var item:ModItem = (modsGroup != null) ? modsGroup.members[curSelectedMod] : null;
		return (item != null) ? item.folder : '';
	}

	function listSwitchLabel():String
	{
		return usingContent
			? Language.getPhrase('mods_menu_show_mods', 'SHOW MODS')
			: Language.getPhrase('mods_menu_show_content', 'SHOW CONTENT');
	}

	/** 内容包在详情面板里的描述（没有 pack.json 时的兜底文案）。 */
	function contentDescription(path:String):String
	{
		var info:ContentPackInfo = ContentPacks.getInfo(path);
		var desc:String = Language.getPhrase('content_pack_desc', 'Content: {1}', ['${Paths.CONTENT_ROOT}/$path']);
		if(info != null && info.songs > 0)
			desc += '\n' + Language.getPhrase('content_pack_songs', 'Songs: {1}', [Std.string(info.songs)]);
		desc += '\n\n' + Language.getPhrase('content_pack_hint', 'Disabling hides it from the Freeplay / Story song lists. No restart needed.');
		return desc;
	}

	function hideGroupMembers(group:FlxTypedGroup<ModItem>)
	{
		if(group == null) return;
		for (item in group.members)
			if(item != null) item.visible = false;
	}

	/** Content 页没有"加载顺序"可言 —— 排序类按钮整页禁用。 */
	function updateMoveButtonsEnabled()
	{
		var locked:Bool = usingContent || curList().all.length < 2;
		for (button in moveButtons) button.enabled = !locked;
		if(buttonSelectPrev != null) buttonSelectPrev.enabled = !locked;
		if(buttonSelectNext != null) buttonSelectNext.enabled = !locked;
	}

	/** 切页签：只换 group 指针 + 复位滚动/选中，不重建卡片。 */
	function switchList(toContent:Bool)
	{
		if(toContent == usingContent) return;

		var oldGroup:FlxTypedGroup<ModItem> = modsGroup;
		oldGroup.active = oldGroup.visible = false;
		hideGroupMembers(oldGroup);

		usingContent = toContent;
		modsGroup = usingContent ? groupContent : groupMods;
		modsGroup.active = modsGroup.visible = true;

		curSelectedMod = 0;
		scrollPos = 0;
		holdingMod = false;
		holdingElapsed = 0;
		pressIndex = -1;
		pressedMod = null;
		pressHoldCancelled = false;

		maxScrollPos = Math.max(0, curList().all.length * ROW_H - (bgList.height - 10));
		if(cardScroller != null)
		{
			cardScroller.resetInputState();
			cardScroller.inputAllow = true;
			cardScroller.moveLimit = [0, maxScrollPos];
			cardScroller.target = 0;
			cardScroller.tweenData = 0;
		}
		refreshScrollBarThumb();
		if(buttonSwitchList != null) buttonSwitchList.setText(listSwitchLabel());

		// 从按钮栏点过来的话，把按钮焦点还回去，否则高亮会留在原按钮上
		if(!hoveringOnMods)
		{
			var focused:MenuButton = getButton();
			focused.ignoreCheck = focused.onFocus = false;
			bgButtons.color = FlxColor.BLACK;
			bgButtons.alpha = 0.2;
		}

		hoveringOnMods = true;
		updateMoveButtonsEnabled();
		updateModDisplayData();
		updateItemPositions();
		updateScrollBar();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function refreshScrollBarThumb()
	{
		if(scrollBar == null || scrollBarTrack == null) return;
		var thumb:Int = Std.int(Math.max(30, (bgList.height - 40) * ((bgList.height - 10) / Math.max(1, curList().all.length * ROW_H))));
		scrollBar.makeGraphic(8, thumb, FlxColor.WHITE);
		scrollBar.alpha = 0.6;
	}

	/** 单个开关（On/Off 按钮）。 */
	function toggleSelected()
	{
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod == null) return;

		var list:ModsList = curList();
		var key:String = curMod.folder;
		var disable:Bool = !list.disabled.contains(key);
		if(disable)
		{
			list.enabled.remove(key);
			list.disabled.push(key);
		}
		else
		{
			list.disabled.remove(key);
			list.enabled.push(key);
		}
		curMod.setDisabled(disable);

		if(usingContent)
		{
			// 内容包立刻落盘：Freeplay / Story 每次进入都会重新扫盘，不用重启
			ContentPacks.setDisabled(key, disable);
		}
		else if(curMod.mustRestart) waitingToRestart = true;

		updateModDisplayData();
		checkToggleButtons();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	/** 全开 / 全关（第二行那个绿 / 红按钮，按当前页签生效）。 */
	function setAllDisabled(disable:Bool)
	{
		var list:ModsList = curList();
		var restart:Bool = false;
		for (mod in modsGroup.members)
		{
			if(mod == null) continue;
			if(list.disabled.contains(mod.folder) == disable) continue;

			if(disable)
			{
				list.enabled.remove(mod.folder);
				list.disabled.push(mod.folder);
			}
			else
			{
				list.disabled.remove(mod.folder);
				list.enabled.push(mod.folder);
			}
			mod.setDisabled(disable);
			if(mod.mustRestart) restart = true;
		}

		if(usingContent)
		{
			ContentPacks.save(list);
			ContentPacks.invalidate();
		}
		else if(restart) waitingToRestart = true;

		updateModDisplayData();
		checkToggleButtons();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	var noModsHint:FlxText;

	function showEmptyDetail()
	{
		// 空列表时游戏会持续重扫目录，失焦也别暂停
		FlxG.autoPause = false;

		if(noModsTxt == null)
		{
			var myX:Float = bgList.x + bgList.width + 20;
			noModsTxt = new FlxText(myX, 0, FlxG.width - myX - 20, '', 48);
			noModsTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			noModsTxt.borderSize = 2;
			add(noModsTxt);
			noModsTxt.screenCenter(Y);
		}
		if(noModsHint == null)
		{
			noModsHint = new FlxText(bgList.x + 15, bgList.y + 15, bgList.width - 30, '', 16);
			noModsHint.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE);
			add(noModsHint);
		}

		noModsTxt.text = usingContent
			? Language.getPhrase('no_content_packs', 'NO CONTENT PACKS FOUND\nPRESS BACK TO EXIT OR PUT ONE IN content/')
			: Language.getPhrase('no_mods_installed', 'NO MODS INSTALLED\nPRESS BACK TO EXIT OR INSTALL A MOD');
		noModsHint.text = usingContent
			? Language.getPhrase('no_content_found', 'No content packs found.')
			: Language.getPhrase('no_mods_found', 'No Mods found.');
		noModsTxt.visible = noModsHint.visible = true;
		noModsSine = 0;

		icon.visible = false;
		modName.visible = false;
		modDesc.visible = false;
		modRestartText.visible = false;
		settingsButton.enabled = false;
	}

	function hideEmptyDetail()
	{
		if(noModsTxt != null) noModsTxt.visible = false;
		if(noModsHint != null) noModsHint.visible = false;

		icon.visible = true;
		modName.visible = true;
		modDesc.visible = true;
	}

	override function closeSubState()
	{
		pressIndex = -1;
		if(pressedMod != null) pressedMod.resetScale();
		pressedMod = null;
		pressHoldElapsed = 0;
		pressHoldCancelled = false;
		holdingMod = false;
		holdingElapsed = 0;
		if(cardScroller != null)
		{
			cardScroller.resetInputState();
			cardScroller.inputAllow = true;
		}
		super.closeSubState();
	}

	override function destroy()
	{
		if(cardScroller != null)
		{
			remove(cardScroller);
			cardScroller.destroy();
			cardScroller = null;
		}
		super.destroy();
	}


	function reload()
	{
		saveTxt();
		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		var startKey:String = (curMod != null) ? curMod.folder : null;
		// 带着"页签 + 选中项"回来，别一 Reload 就掉回 MODS 页第一项
		if(startKey != null && usingContent) startKey = CONTENT_PREFIX + startKey;
		MusicBeatState.switchState(new ModsMenuState(startKey));
	}
	
	function saveTxt()
	{
		var fileStr:String = '';
		for (mod in modsList.all)
		{
			if(mod.trim().length < 1) continue;

			if(fileStr.length > 0) fileStr += '\n';

			var on = '1';
			if(modsList.disabled.contains(mod)) on = '0';
			fileStr += '$mod|$on';
		}

		var path:String = 'modsList.txt';
		File.saveContent(path, fileStr);
		Mods.parseList();
		Mods.loadTopMod();
	}
}

class ModItem extends FlxSpriteGroup
{
	public var selectBg:FlxSprite;
	public var icon:FlxSprite;
	public var text:FlxText;
	public var totalFrames:Int = 0;

	// options
	public var name:String = 'Unknown Mod';
	public var desc:String = 'No description provided.';
	public var iconFps:Int = 10;
	public var bgColor:FlxColor = 0xFF665AFF;
	public var pack:Dynamic = null;
	public var folder:String = 'unknownMod';
	/** 非 null = Content 体系里的包（相对仓库根的路径，如 content/VanillaSongs/Erect）；普通 mod 为 null。 */
	public var contentRoot:String = null;
	public var mustRestart:Bool = false;
	public var settings:Array<Dynamic> = null;

	public var disabled:Bool = false;
	public var hovered:Bool = false;
	private var pressing:Bool = false;
	private var _pressScale:Float = 1;
	private var _pressScaleTween:FlxTween = null;
	private var _childTransforms:Array<ModItemChildTransform> = [];
	private var _pressCenterX:Float = 0;
	private var _pressCenterY:Float = 0;
	private var _cardWidth:Float = 0;
	private var _cardHeight:Float = 0;
	private var _clipLeft:Float = 0;
	private var _clipTop:Float = 0;
	private var _clipRight:Float = 0;
	private var _clipBottom:Float = 0;
	private var _clipRowHeight:Float = 0;

	/**
	 * @param folder     mods/ 下的目录名；Content 页里是相对 content/ 的路径（VanillaSongs/Erect）
	 * @param contentRoot 非 null 时表示这是 content/ 里的包（相对仓库根，如 content/VanillaSongs/Erect）
	 * @param fallbackDesc 没有 pack.json 时用的描述（内容包用扫描信息拼出来）
	 */
	public function new(folder:String, ?contentRoot:String = null, ?fallbackDesc:String = null)
	{
		super();

		this.folder = folder;
		this.contentRoot = contentRoot;

		var base:String = (contentRoot != null) ? contentRoot : Paths.mods(folder);
		pack = (contentRoot != null) ? readPackJson(base) : Mods.getPack(folder);

		var path:String = '$base/data/settings.json';
		if(FileSystem.exists(path))
		{
			try
			{
				//trace('trying to load settings: $folder');
				settings = tjson.TJSON.parse(File.getContent(path));
			}
			catch(e:Dynamic)
			{
				var errorTitle = 'Mod name: ' + folder;
				var errorMsg = 'An error occurred: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				trace('$errorTitle - $errorMsg');
			}
		}

		selectBg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		selectBg.alpha = 0.8;
		selectBg.visible = false;
		add(selectBg);

		// 图标左移 30px（原来是 5）
		icon = new FlxSprite(15, 5);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		add(icon);

		// 文字跟着左移 30px，保持与图标的相对间距
		text = new FlxText(95 - 30, 38, 230, "", 16);
		text.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y -= Std.int(text.height / 2);
		add(text);

		var isPixel = false;
		var file:String = '$base/pack.png';
		if (!FileSystem.exists(file))
		{
			file = '$base/pack-pixel.png';
			isPixel = true;
		}
		if (!FileSystem.exists(file) && contentRoot != null)
		{
			// 内容包一般不带 pack.png，退一步找包根下的 icon.png
			file = '$base/icon.png';
			isPixel = false;
		}
		
		var bmp:BitmapData = null;
		if (FileSystem.exists(file)) bmp = BitmapData.fromFile(file);
		else isPixel = false;

		if(FileSystem.exists(file))
		{
			icon.loadGraphic(Paths.cacheBitmap(file, bmp), true, 150, 150);
			if(isPixel) icon.antialiasing = false;
		}
		else icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		icon.scale.set(0.5, 0.5);
		icon.updateHitbox();
		
		this.name = folder;
		// Content 条目的键是 VanillaSongs/Erect，卡片上只留最后一段（Erect）
		var displayName:String = (contentRoot != null) ? folder.substr(folder.lastIndexOf('/') + 1) : folder;
		if(pack != null)
		{
			if(pack.name != null) this.name = pack.name;
			if(pack.description != null) this.desc = pack.description;
			if(pack.iconFramerate != null) this.iconFps = pack.iconFramerate;
			if(pack.color != null)
			{
				this.bgColor = FlxColor.fromRGB(pack.color[0] != null ? pack.color[0] : 170,
											  pack.color[1] != null ? pack.color[1] : 0,
											  pack.color[2] != null ? pack.color[2] : 255);
			}
			this.mustRestart = (pack.restart == true);
		}
		else
		{
			this.name = displayName;
			if(fallbackDesc != null) this.desc = fallbackDesc;
			if(contentRoot != null) this.bgColor = contentColor(displayName);
			this.mustRestart = false; // 内容包开关不需要重启
		}
		text.text = this.name;

		if(bmp != null)
		{
			totalFrames = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
			icon.animation.add("icon", [for (i in 0...totalFrames) i], iconFps);
			icon.animation.play("icon");
		}
		selectBg.scale.set(width + 5, height + 5);
		selectBg.updateHitbox();

		_cardWidth = width;
		_cardHeight = height;
		_pressCenterX = _cardWidth * 0.5;
		_pressCenterY = _cardHeight * 0.5;
		for (child in members)
		{
			if (child == null) continue;
			_childTransforms.push({
				sprite: child,
				x: child.x - x,
				y: child.y - y,
				scaleX: child.scale.x,
				scaleY: child.scale.y,
				originX: child.origin.x,
				originY: child.origin.y,
				offsetX: child.offset.x,
				offsetY: child.offset.y
			});
		}
	}

	/** 读某个目录下的 pack.json（内容包一旦自带 pack.json 也能享受 name/desc/color/restart）。 */
	static function readPackJson(base:String):Dynamic
	{
		var path:String = '$base/pack.json';
		if(!FileSystem.exists(path)) return null;
		try
		{
			var raw:String = File.getContent(path);
			if(raw != null && raw.length > 0) return tjson.TJSON.parse(raw);
		}
		catch(e:Dynamic) trace(e);
		return null;
	}

	/** 内容包没有 pack.json 时，按名字散列挑一个详情面板底色。 */
	static function contentColor(name:String):FlxColor
	{
		var palette:Array<Int> = [0xFF665AFF, 0xFF24AD65, 0xFFFF9E24, 0xFF24A7FF, 0xFFE05AFF, 0xFF5AE0C8];
		var hash:Int = 0;
		for (i in 0...name.length) hash = (hash * 31 + name.charCodeAt(i)) % 1000003;
		return palette[hash % palette.length];
	}

	public function setDisabled(on:Bool)
	{
		disabled = on;
		if(icon != null) icon.color = on ? 0xFFFF6666 : FlxColor.WHITE;
		updateTextColor();
	}

	function updateTextColor()
	{
		if(text == null) return;
		text.color = disabled ? FlxColor.GRAY : (hovered ? FlxColor.WHITE : 0xFFCCCCCC);
	}

	public function resetScale()
	{
		pressing = false;
		if (_pressScaleTween != null)
		{
			_pressScaleTween.cancel();
			_pressScaleTween = null;
		}
		_pressScale = 1;
		applyPressScale();
	}

	public function updateClip(listX:Float, listY:Float, listW:Float, listH:Float, rowHeight:Float)
	{
		_clipLeft = listX - 30; // 卡片图标向左超出卡片锚点 25px，裁剪边界需保留这段空间。
		_clipTop = listY;
		_clipRight = listX + listW;
		_clipBottom = listY + listH;
		_clipRowHeight = rowHeight;
		applyClipToChildren();
	}

	function applyPressScale():Void
	{
		// 组级 scale 会覆盖成员原缩放，因此按各成员保存的基础变换应用按压因子。
		for (state in _childTransforms)
		{
			var child = state.sprite;
			var baseX:Float = x + state.x;
			var baseY:Float = y + state.y;
			child.x = x + _pressCenterX + (baseX - state.offsetX + state.originX - x - _pressCenterX) * _pressScale + state.offsetX - state.originX;
			child.y = y + _pressCenterY + (baseY - state.offsetY + state.originY - y - _pressCenterY) * _pressScale + state.offsetY - state.originY;
			child.scale.set(state.scaleX * _pressScale, state.scaleY * _pressScale);
		}
		applyClipToChildren();
	}

	function applyClipToChildren():Void
	{
		var isInView:Bool = x + _cardWidth > _clipLeft && x < _clipRight
			&& y + _clipRowHeight > _clipTop && y < _clipBottom;
		visible = isInView;
		for (state in _childTransforms)
		{
			if (isInView) state.sprite.clipToWorldBounds(_clipLeft, _clipTop, _clipRight, _clipBottom);
			else state.sprite.clipRect = null;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		applyPressScale();

		if(!visible)
		{
			if(pressing) cancelPress();
			return;
		}

		hovered = FlxG.mouse.visible && !Controls.instance.controllerMode && FlxG.mouse.overlaps(this);
		updateTextColor();

		if(hovered && FlxG.mouse.justPressed)
		{
			pressing = true;
			pressScale();
		}
		else if(pressing && (!hovered || FlxG.mouse.justReleased))
		{
			pressing = false;
			releaseScale();
		}
	}

	function pressScale()
	{
		if (_pressScaleTween != null) _pressScaleTween.cancel();
		_pressScaleTween = FlxTween.tween(this, {_pressScale: 0.97}, 0.06, {ease: FlxEase.quadOut});
	}

	function releaseScale()
	{
		if (_pressScaleTween != null) _pressScaleTween.cancel();
		_pressScaleTween = FlxTween.tween(this, {_pressScale: 1}, 0.12, {ease: FlxEase.backOut});
	}

	function cancelPress()
	{
		if(!pressing) return;
		pressing = false;
		releaseScale();
	}
}

class MenuButton extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var textOn:FlxText;
	public var textOff:FlxText;
	public var icon:FlxSprite;
	public var onClick:Void->Void = null;
	public var enabled(default, set):Bool = true;
	public function new(x:Float, y:Float, width:Int, height:Int, ?text:String = null, ?img:FlxGraphic = null, onClick:Void->Void = null, animWidth:Int = 0, animHeight:Int = 0, ?textSize:Int = 32)
	{
		super(x, y);
		
		bg = FlxSpriteUtil.drawRoundRect(new FlxSprite().makeGraphic(width, height, FlxColor.TRANSPARENT), 0, 0, width, height, 15, 15, FlxColor.WHITE);
		bg.color = FlxColor.BLACK;
		add(bg);

		if(text != null)
		{
			// 文字用大号 VCR 而不是 Alphabet：Alphabet 的字形推进量是未缩放的定值，
			// 长标签（ENABLE ALL / DISABLE ALL）会溢出按钮、和隔壁按钮的标签撞在一起。
			// FlxText 走真实字宽，配合 fitTextSprite() 按按钮内宽自动缩，怎么翻译都不会出界。
			textOn = makeTextSprite(text, textSize + 2, FlxColor.BLACK, FlxTextBorderStyle.NONE);
			textOff = makeTextSprite(text, textSize, FlxColor.WHITE, FlxTextBorderStyle.OUTLINE);
			textOn.visible = false;
			add(textOn);
			add(textOff);
		}
		else if(img != null)
		{
			icon = new FlxSprite();
			if(animWidth > 0 || animHeight > 0) icon.loadGraphic(img, true, animWidth, animHeight);
			else icon.loadGraphic(img);
			centerOnBg(icon);
			add(icon);
		}

		this.onClick = onClick;
		setButtonVisibility(false);

		origin.set(Std.int(bg.width / 2), Std.int(bg.height / 2));
	}

	function makeTextSprite(str:String, size:Int, color:FlxColor, border:FlxTextBorderStyle):FlxText
	{
		var t:FlxText = new FlxText(0, 0, 0, str, size);
		t.setFormat(Paths.font('vcr.ttf'), size, color, CENTER, border, FlxColor.BLACK);
		t.borderSize = 2;
		t.antialiasing = ClientPrefs.data.antialiasing;
		fitTextSprite(t);
		return t;
	}

	/**
	 * 让文字塞进按钮：超宽就**降字号**（而不是缩放），居中摆放。
	 * 用缩放的话 FlxText 的 offset 会跟着缩放走，居中算式会偏，字号方案干净得多。
	 *
	 * `withOffset`：坐标要不要加组偏移。
	 * 本类是 FlxSpriteGroup，`add()` 时 `preAdd` 会把组的 x/y 加进子对象 —— 所以
	 * **构造期（add 之前）写局部坐标**、**事后重排（add 之后）必须写绝对坐标**，
	 * 否则等于把已经加上的偏移抹掉，文字会飞回屏幕左上角。
	 */
	function fitTextSprite(t:FlxText, withOffset:Bool = false):Void
	{
		if(t == null) return;

		var maxW:Float = bg.width - 20;
		var guard:Int = 0;
		t.updateHitbox();
		while(t.width > maxW && t.size > 9 && guard < 30)
		{
			t.setFormat(Paths.font('vcr.ttf'), t.size - 2, t.color, CENTER, t.borderStyle, FlxColor.BLACK);
			t.updateHitbox();
			guard++;
		}

		t.x = bg.width / 2 - t.width / 2 + (withOffset ? x : 0);
		t.y = bg.height / 2 - t.height / 2 + (withOffset ? y : 0);
	}

	/** 换文字（MODS / CONTENT 页签按钮用）。 */
	public function setText(str:String):Void
	{
		if(textOn == null || textOff == null) return;
		textOn.text = str;
		textOff.text = str;
		fitTextSprite(textOn, true);
		fitTextSprite(textOff, true);
	}

	public var focusChangeCallback:Bool->Void = null;
	public var onFocus(default, set):Bool = false;
	public var ignoreCheck:Bool = false;
	private var _needACheck:Bool = false;
	private var _hovering:Bool = false;
	private var pressing:Bool = false;
	private var _pendingClick:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!enabled)
		{
			onFocus = false;
			if(pressing) cancelPress();
			return;
		}

		if(!ignoreCheck && !Controls.instance.controllerMode && FlxG.mouse.justMoved && FlxG.mouse.visible)
			onFocus = FlxG.mouse.overlaps(this);

		var hovering:Bool = FlxG.mouse.visible && !Controls.instance.controllerMode && FlxG.mouse.overlaps(this);
		if(hovering != _hovering)
		{
			_hovering = hovering;
			setButtonVisibility(onFocus || hovering);
		}

		if(hovering && onClick != null && FlxG.mouse.justPressed)
		{
			pressing = true;
			pressScale();
		}
		else if(pressing && (!hovering || FlxG.mouse.justReleased))
		{
			pressing = false;
			releaseScale();
			if(hovering && onClick != null) _pendingClick = true; //仅内部松开触发
		}

		if(_needACheck)
		{
			_needACheck = false;
			if(!Controls.instance.controllerMode)
				setButtonVisibility(FlxG.mouse.overlaps(this));
		}

		//onClick 延到本帧末尾再执行：reload 等回调会切 state，回调后不许再碰控件成员
		if(_pendingClick)
		{
			_pendingClick = false;
			if(enabled && onClick != null) onClick();
		}
	}

	function set_onFocus(newValue:Bool)
	{
		var lastFocus:Bool = onFocus;
		onFocus = newValue;
		if(onFocus != lastFocus && enabled) setButtonVisibility(onFocus || _hovering);
		return newValue;
	}

	function set_enabled(newValue:Bool)
	{
		enabled = newValue;
		setButtonVisibility(false);
		alpha = enabled ? 1 : 0.4;

		_needACheck = enabled;
		return newValue;
	}

	public function setButtonVisibility(focusVal:Bool)
	{
		alpha = 1;
		bg.color = focusVal ? FlxColor.WHITE : FlxColor.BLACK;
		bg.alpha = focusVal ? 0.8 : 0.6;

		var focusAlpha = focusVal ? 1 : 0.6;
		if(textOn != null && textOff != null)
		{
			textOn.alpha = textOff.alpha = focusAlpha;
			textOn.visible = focusVal;
			textOff.visible = !focusVal;
		}
		else if(icon != null)
		{
			icon.alpha = focusAlpha;
			icon.color = focusVal ? FlxColor.BLACK : FlxColor.WHITE;
		}

		if(!enabled) alpha = 0.4;
		if(focusChangeCallback != null) focusChangeCallback(focusVal);
	}

	function pressScale()
	{
		FlxTween.cancelTweensOf(scale);
		FlxTween.tween(scale, {x: 0.97, y: 0.97}, 0.06, {ease: FlxEase.quadOut});
	}

	function releaseScale()
	{
		FlxTween.cancelTweensOf(scale);
		FlxTween.tween(scale, {x: 1, y: 1}, 0.12, {ease: FlxEase.backOut});
	}

	function cancelPress()
	{
		if(!pressing) return;
		pressing = false;
		releaseScale();
	}


	public function centerOnBg(spr:FlxSprite)
	{
		spr.x = bg.width/2 - spr.width/2;
		spr.y = bg.height/2 - spr.height/2;
	}
}