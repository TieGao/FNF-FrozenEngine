package options;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;
import flixel.util.FlxColor;

import objects.CheckboxThingie;
import objects.AttachedText;
import options.Option;
import backend.InputFormatter;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	public var bg:FlxSprite;
	
	// 鼠标控制相关变量
	private var allowMouse:Bool = true;
	private var isMouseControl:Bool = false;
	private var mouseOverItem:Int = -1;
	private var mouseHoldTime:Float = 0;
	
	// 鼠标区域偏移
	private var mouseXOffset:Float = -50; // X轴偏移
	private var mouseYOffset:Float = 30; // Y轴偏移，下移一些
	private var optionWidth:Float = 800; // 选项宽度
	private var optionHeight:Float = 60; // 选项高度

	public function new()
	{
		super();

		if(title == null) title = 'Options';
		if(rpcTitle == null) rpcTitle = 'Options Menu';
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end
		
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		var titleText:Alphabet = new Alphabet(75, 45, title, true);
		titleText.setScale(0.6);
		titleText.alpha = 0.4;
		add(titleText);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(220, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			/*optionText.forceX = 300;
			optionText.yMult = 90;*/
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(optionsArray[i].type == BOOL)
			{
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, Std.string(optionsArray[i].getValue()) == 'true');
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
			}
			else
			{
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				//optionText.xAdd -= 80;
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 60);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			//optionText.snapToPosition(); //Don't ignore me when i ask for not making a fucking pull request to uncomment this line ok
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
		
		// 初始隐藏鼠标
		FlxG.mouse.visible = false;
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
		return option;
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	var bindingKey:Bool = false;
	var holdingEsc:Float = 0;
	var bindingBlack:FlxSprite;
	var bindingText:Alphabet;
	var bindingText2:Alphabet;
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(bindingKey)
		{
			bindingKeyUpdate(elapsed);
			return;
		}

		// 鼠标控制逻辑 - 只在点击、滚轮或明显移动时检测
		if (allowMouse && (FlxG.mouse.justPressed || FlxG.mouse.justReleased || FlxG.mouse.wheel != 0))
		{
			allowMouse = false;
			FlxG.mouse.visible = true;
			isMouseControl = true;

			var newMouseOverItem:Int = -1;
			var minDist:Float = 999999;
			
			// 检查鼠标是否悬停在某个选项上
			for (i in 0...grpOptions.length)
			{
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
				
				// 检查复选框区域（如果选项是布尔类型）
				if (!isOverItem && optionsArray[i].type == BOOL)
				{
					for (checkbox in checkboxGroup)
					{
						if (checkbox.ID == i && checkbox.exists)
						{
							// 复选框区域判定（扩大区域）
							var checkboxX:Float = checkbox.x - 30; // 向左扩展
							var checkboxY:Float = checkbox.y - 20; // 向上扩展
							var checkboxWidth:Float = 60; // 宽度
							var checkboxHeight:Float = 60; // 高度
							
							isOverItem = (FlxG.mouse.screenX >= checkboxX && 
										 FlxG.mouse.screenX <= checkboxX + checkboxWidth &&
										 FlxG.mouse.screenY >= checkboxY && 
										 FlxG.mouse.screenY <= checkboxY + checkboxHeight);
							if (isOverItem) break;
						}
					}
				}
				
				// 检查值文本区域（如果选项不是布尔类型）
				if (!isOverItem && optionsArray[i].type != BOOL)
				{
					for (text in grpTexts)
					{
						if (text.ID == i && text.exists)
						{
							// 值文本区域判定（扩大区域）
							var textX:Float = text.x - 30;
							var textY:Float = text.y - 15;
							var textWidth:Float = text.width + 60;
							var textHeight:Float = text.height + 30;
							
							isOverItem = (FlxG.mouse.screenX >= textX && 
										 FlxG.mouse.screenX <= textX + textWidth &&
										 FlxG.mouse.screenY >= textY && 
										 FlxG.mouse.screenY <= textY + textHeight);
							if (isOverItem) break;
						}
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
		
		// 鼠标滚轮逻辑
		if (FlxG.mouse.wheel != 0)
		{
			if (mouseOverItem != -1 && mouseOverItem == curSelected && !isBindingKey())
			{
				// 鼠标悬停在当前选中的选项上：调整数值
				var wheelValue:Float = FlxG.mouse.wheel * (FlxG.keys.pressed.SHIFT ? 3 : 1);
				handleMouseWheel(wheelValue);
			}
			else
			{
				// 鼠标不在选项上或不在当前选中的选项上：上下滚动选择
				// 修改：滚轮向上为向上滑动（选择上面的选项），向下为向下滑动（选择下面的选项）
				// 注意：wheelValue向上滚动时为正值，向下滚动时为负值
				// 我们想要向上滚动选择上面的选项（索引变小），所以应该是 -1 * wheelValue
				// 但wheelValue已经是正值表示向上，负值表示向下，所以我们需要取反
				var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
				var selectionChange:Int = -shiftMult * FlxG.mouse.wheel;
				changeSelection(selectionChange);
			}
		}

		// 鼠标点击选择选项
		if (FlxG.mouse.justPressed && isMouseControl && !isBindingKey())
		{
			if (mouseOverItem != -1)
			{
				if (curSelected != mouseOverItem)
				{
					// 左键点击未选中的选项：选择它
					curSelected = mouseOverItem;
					changeSelection(0);
				}
				else
				{
					// 左键点击已选中的选项：执行选项操作
					handleMouseClick();
				}
			}
		}
		
		// 鼠标拖动调整数值（非布尔类型和非键位绑定类型）
		if (FlxG.mouse.pressed && isMouseControl && mouseOverItem != -1 && mouseOverItem == curSelected && 
			!isBindingKey() && nextAccept <= 0 && curOption != null)
		{
			if (curOption.type != BOOL && curOption.type != KEYBIND && curOption.type != STRING)
			{
				mouseHoldTime += elapsed;
				if (mouseHoldTime > 0.1) // 延迟一点防止过于敏感
				{
					var mouseDelta:Float = FlxG.mouse.deltaScreenX;
					if (Math.abs(mouseDelta) > 0.1)
					{
						// 鼠标向右拖动为增加数值，向左拖动为减少数值
						var add:Dynamic = mouseDelta * curOption.changeValue * 0.2;
						holdValue = curOption.getValue() + add;
						if(holdValue < curOption.minValue) holdValue = curOption.minValue;
						else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

						switch(curOption.type)
						{
							case INT:
								holdValue = Math.round(holdValue);
								curOption.setValue(holdValue);

							case FLOAT, PERCENT:
								holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
								curOption.setValue(holdValue);

							default:
						}
						
						if (Math.abs(mouseDelta) > 2) // 防止连续播放音效
						{
							FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
						}
						
						updateTextFrom(curOption);
						curOption.change();
					}
				}
			}
		}
		else if (FlxG.mouse.justReleased)
		{
			mouseHoldTime = 0;
		}
		
		// 鼠标右键返回
		if (FlxG.mouse.justPressedRight && isMouseControl && !isBindingKey())
		{
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.mouse.visible = true;
			return;
		}

		// 保留原来的键盘控制逻辑
		if (!isMouseControl || isBindingKey())
		{
			if (controls.UI_UP_P)
			{
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P)
			{
				changeSelection(1);
			}

			if (controls.BACK) {
				close();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		}

		if(nextAccept <= 0)
		{
			if (!isMouseControl || isBindingKey())
			{
				switch(curOption.type)
				{
					case BOOL:
						if(controls.ACCEPT)
						{
							FlxG.sound.play(Paths.sound('scrollMenu'));
							curOption.setValue((curOption.getValue() == true) ? false : true);
							curOption.change();
							reloadCheckboxes();
						}

					case KEYBIND:
						if(controls.ACCEPT)
						{
							bindingBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
							bindingBlack.scale.set(FlxG.width, FlxG.height);
							bindingBlack.updateHitbox();
							bindingBlack.alpha = 0;
							FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
							add(bindingBlack);
		
							bindingText = new Alphabet(FlxG.width / 2, 160, Language.getPhrase('controls_rebinding', 'Rebinding {1}', [curOption.name]), false);
							bindingText.alignment = CENTERED;
							add(bindingText);
							
							bindingText2 = new Alphabet(FlxG.width / 2, 340, Language.getPhrase('controls_rebinding2', 'Hold ESC to Cancel\nHold Backspace to Delete'), true);
							bindingText2.alignment = CENTERED;
							add(bindingText2);
		
							bindingKey = true;
							holdingEsc = 0;
							ClientPrefs.toggleVolumeKeys(false);
							FlxG.sound.play(Paths.sound('scrollMenu'));
						}

					default:
						if(controls.UI_LEFT || controls.UI_RIGHT)
						{
							var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
							if(holdTime > 0.5 || pressed)
							{
								if(pressed)
								{
									var add:Dynamic = null;
									if(curOption.type != STRING)
										add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
			
									switch(curOption.type)
									{
										case INT, FLOAT, PERCENT:
											holdValue = curOption.getValue() + add;
											if(holdValue < curOption.minValue) holdValue = curOption.minValue;
											else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;
			
											if(curOption.type == INT)
											{
												holdValue = Math.round(holdValue);
												curOption.setValue(holdValue);
											}
											else
											{
												holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
												curOption.setValue(holdValue);
											}
			
										case STRING:
											var num:Int = curOption.curOption; //lol
											if(controls.UI_LEFT_P) --num;
											else num++;
			
											if(num < 0)
												num = curOption.options.length - 1;
											else if(num >= curOption.options.length)
												num = 0;
			
											curOption.curOption = num;
											curOption.setValue(curOption.options[num]);
											//trace(curOption.options[num]);

										default:
									}
									updateTextFrom(curOption);
									curOption.change();
									FlxG.sound.play(Paths.sound('scrollMenu'));
								}
								else if(curOption.type != STRING)
								{
									holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
									if(holdValue < curOption.minValue) holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;
			
									switch(curOption.type)
									{
										case INT:
											curOption.setValue(Math.round(holdValue));
										
										case PERCENT:
											curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));

										default:
									}
									updateTextFrom(curOption);
									curOption.change();
								}
							}
			
							if(curOption.type != STRING)
								holdTime += elapsed;
						}
						else if(controls.UI_LEFT_R || controls.UI_RIGHT_R)
						{
							if(holdTime > 0.5) FlxG.sound.play(Paths.sound('scrollMenu'));
							holdTime = 0;
						}
				}

				if(controls.RESET)
				{
					resetCurrentOption();
				}
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
	}
	
		private function handleMouseWheel(wheelValue:Float)
	{
		if (nextAccept <= 0 && curOption != null)
		{
			var usesCheckbox:Bool = (curOption.type == BOOL);
			if (!usesCheckbox && curOption.type != KEYBIND)
			{
				switch(curOption.type)
				{
					case INT, FLOAT, PERCENT:
						// 修改：滚轮向上为增加数值，向下为减少数值
						// 注意：wheelValue向上滚动时为正值，向下滚动时为负值
						// 所以我们需要将wheelValue取反
						var add:Dynamic = wheelValue * curOption.changeValue; // 移除负号
						holdValue = curOption.getValue() + add;
						if(holdValue < curOption.minValue) holdValue = curOption.minValue;
						else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

						switch(curOption.type)
						{
							case INT:
								holdValue = Math.round(holdValue);
								curOption.setValue(holdValue);

							case FLOAT, PERCENT:
								holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
								curOption.setValue(holdValue);

							default:
						}
						FlxG.sound.play(Paths.sound('scrollMenu'));

					case STRING:
						var num:Int = curOption.curOption;
						// 修改：滚轮向上为向前选择，向下为向后选择
						// 注意：wheelValue向上滚动时为正值，向下滚动时为负值
						if(wheelValue > 0) num++; // 向上滚动：向前选择
						else if (wheelValue < 0) num--; // 向下滚动：向后选择

						if(num < 0)
							num = curOption.options.length - 1;
						else if(num >= curOption.options.length)
							num = 0;

						curOption.curOption = num;
						curOption.setValue(curOption.options[num]);
						FlxG.sound.play(Paths.sound('scrollMenu'));

					default:
				}
				updateTextFrom(curOption);
				curOption.change();
			}
		}
	}
	
	private function handleMouseClick()
	{
		if (nextAccept <= 0 && curOption != null)
		{
			switch(curOption.type)
			{
				case BOOL:
					FlxG.sound.play(Paths.sound('scrollMenu'));
					curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
					
				case KEYBIND:
					bindingBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
					bindingBlack.scale.set(FlxG.width, FlxG.height);
					bindingBlack.updateHitbox();
					bindingBlack.alpha = 0;
					FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
					add(bindingBlack);

					bindingText = new Alphabet(FlxG.width / 2, 160, Language.getPhrase('controls_rebinding', 'Rebinding {1}', [curOption.name]), false);
					bindingText.alignment = CENTERED;
					add(bindingText);
					
					bindingText2 = new Alphabet(FlxG.width / 2, 340, Language.getPhrase('controls_rebinding2', 'Hold ESC to Cancel\nHold Backspace to Delete'), true);
					bindingText2.alignment = CENTERED;
					add(bindingText2);

					bindingKey = true;
					holdingEsc = 0;
					ClientPrefs.toggleVolumeKeys(false);
					FlxG.sound.play(Paths.sound('scrollMenu'));
					
				default:
					// 对于其他类型，点击可以快速调整（可选）
			}
		}
	}
	
	private function resetCurrentOption()
	{
		var leOption:Option = optionsArray[curSelected];
		if(leOption.type != KEYBIND)
		{
			leOption.setValue(leOption.defaultValue);
			if(leOption.type != BOOL)
			{
				if(leOption.type == STRING) leOption.curOption = leOption.options.indexOf(leOption.getValue());
				updateTextFrom(leOption);
			}
		}
		else
		{
			leOption.setValue(!Controls.instance.controllerMode ? leOption.defaultKeys.keyboard : leOption.defaultKeys.gamepad);
			updateBind(leOption);
		}
		leOption.change();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		reloadCheckboxes();
	}

	private function isBindingKey():Bool
	{
		return bindingKey;
	}

	private function updateMouseHover()
	{
		for (num => item in grpOptions.members)
		{
			if (item == null) continue;
			item.alpha = 0.6;
			if (item.targetY == 0) 
				item.alpha = 1;
			else if (mouseOverItem == num)
				item.alpha = 0.8;
		}
		for (text in grpTexts)
		{
			text.alpha = 0.6;
			if(text.ID == curSelected)
				text.alpha = 1;
			else if(mouseOverItem == text.ID)
				text.alpha = 0.8;
		}
		for (checkbox in checkboxGroup)
		{
			checkbox.alpha = 0.6;
			if(checkbox.ID == curSelected)
				checkbox.alpha = 1;
			else if(mouseOverItem == checkbox.ID)
				checkbox.alpha = 0.8;
		}
	}

	function bindingKeyUpdate(elapsed:Float)
	{
		if(FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else if (FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				if (!controls.controllerMode) curOption.keys.keyboard = NONE;
				else curOption.keys.gamepad = NONE;
				updateBind(!controls.controllerMode ? InputFormatter.getKeyName(NONE) : InputFormatter.getGamepadName(NONE));
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else
		{
			holdingEsc = 0;
			var changed:Bool = false;
			if(!controls.controllerMode)
			{
				if(FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
				{
					var keyPressed:FlxKey = cast (FlxG.keys.firstJustPressed(), FlxKey);
					var keyReleased:FlxKey = cast (FlxG.keys.firstJustReleased(), FlxKey);

					if(keyPressed != NONE && keyPressed != ESCAPE && keyPressed != BACKSPACE)
					{
						changed = true;
						curOption.keys.keyboard = keyPressed;
					}
					else if(keyReleased != NONE && (keyReleased == ESCAPE || keyReleased == BACKSPACE))
					{
						changed = true;
						curOption.keys.keyboard = keyReleased;
					}
				}
			}
			else if(FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
			{
				var keyPressed:FlxGamepadInputID = NONE;
				var keyReleased:FlxGamepadInputID = NONE;
				if(FlxG.gamepads.anyJustPressed(LEFT_TRIGGER))
					keyPressed = LEFT_TRIGGER; //it wasnt working for some reason
				else if(FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					keyPressed = RIGHT_TRIGGER; //it wasnt working for some reason
				else
				{
					for (i in 0...FlxG.gamepads.numActiveGamepads)
					{
						var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
						if(gamepad != null)
						{
							keyPressed = gamepad.firstJustPressedID();
							keyReleased = gamepad.firstJustReleasedID();
							if(keyPressed != NONE || keyReleased != NONE) break;
						}
					}
				}

				if(keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
				{
					changed = true;
					curOption.keys.gamepad = keyPressed;
				}
				else if(keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
				{
					changed = true;
					curOption.keys.gamepad = keyReleased;
				}
			}

			if(changed)
			{
				var key:String = null;
				if(!controls.controllerMode)
				{
					if(curOption.keys.keyboard == null) curOption.keys.keyboard = 'NONE';
					curOption.setValue(curOption.keys.keyboard);
					key = InputFormatter.getKeyName(FlxKey.fromString(curOption.keys.keyboard));
				}
				else
				{
					if(curOption.keys.gamepad == null) curOption.keys.gamepad = 'NONE';
					curOption.setValue(curOption.keys.gamepad);
					key = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(curOption.keys.gamepad));
				}
				updateBind(key);
				FlxG.sound.play(Paths.sound('confirmMenu'));
				closeBinding();
			}
		}
	}

	final MAX_KEYBIND_WIDTH = 320;
	function updateBind(?text:String = null, ?option:Option = null)
	{
		if(option == null) option = curOption;
		if(text == null)
		{
			text = option.getValue();
			if(text == null) text = 'NONE';

			if(!controls.controllerMode)
				text = InputFormatter.getKeyName(FlxKey.fromString(text));
			else
				text = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(text));
		}

		var bind:AttachedText = cast option.child;
		var attach:AttachedText = new AttachedText(text, bind.offsetX);
		attach.sprTracker = bind.sprTracker;
		attach.copyAlpha = true;
		attach.ID = bind.ID;
		playstationCheck(attach);
		attach.scaleX = Math.min(1, MAX_KEYBIND_WIDTH / attach.width);
		attach.x = bind.x;
		attach.y = bind.y;

		option.child = attach;
		grpTexts.insert(grpTexts.members.indexOf(bind), attach);
		grpTexts.remove(bind);
		bind.destroy();
	}

	function playstationCheck(alpha:Alphabet)
	{
		if(!controls.controllerMode) return;

		var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
		var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;
		var letter = alpha.letters[0];
		if(model == PS4)
		{
			switch(alpha.text)
			{
				case '[', ']': //Square and Triangle respectively
					letter.image = 'alphabet_playstation';
					letter.updateHitbox();
					
					letter.offset.x += 4;
					letter.offset.y -= 5;
			}
		}
	}

	function closeBinding()
	{
		bindingKey = false;
		bindingBlack.destroy();
		remove(bindingBlack);

		bindingText.destroy();
		remove(bindingText);

		bindingText2.destroy();
		remove(bindingText2);
		ClientPrefs.toggleVolumeKeys(true);
	}

	function updateTextFrom(option:Option) {
		if(option.type == KEYBIND)
		{
			updateBind(option);
			return;
		}

		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == PERCENT) val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0) item.alpha = 1;
		}
		for (text in grpTexts)
		{
			text.alpha = 0.6;
			if(text.ID == curSelected) text.alpha = 1;
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		curOption = optionsArray[curSelected]; //shorter lol
		
		// 更新鼠标悬停状态
		updateMouseHover();
		
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function reloadCheckboxes()
		for (checkbox in checkboxGroup)
			checkbox.daValue = Std.string(optionsArray[checkbox.ID].getValue()) == 'true'; //Do not take off the Std.string() from this, it will break a thing in Mod Settings Menu
	
	override function destroy()
	{
		super.destroy();
		FlxG.mouse.visible = true;
	}
}