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
	
	private var allowMouse:Bool = true;
	private var isMouseControl:Bool = false;
	private var mouseOverItem:Int = -1;
	private var mouseHoldTime:Float = 0;
	
	private var mouseXOffset:Float = 0;
	private var mouseYOffset:Float = 30;
	private var optionHeight:Float = 100;

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
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 60);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
		
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

		if (allowMouse && (FlxG.mouse.justPressed || FlxG.mouse.justReleased || FlxG.mouse.wheel != 0 || FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
		{
			allowMouse = false;
			FlxG.mouse.visible = true;
			isMouseControl = true;

			var newMouseOverItem:Int = -1;
			var minDist:Float = 999999;
			
			for (i in 0...grpOptions.length)
			{
				var item:Alphabet = grpOptions.members[i];
				if (item == null) continue;
				
				var itemWidth:Float = item.width;
				var itemX:Float = item.x + mouseXOffset;
				var itemY:Float = item.y + mouseYOffset;
				
				var isOverItem:Bool = (FlxG.mouse.screenX >= itemX && 
									  FlxG.mouse.screenX <= itemX + itemWidth &&
									  FlxG.mouse.screenY >= itemY && 
									  FlxG.mouse.screenY <= itemY + optionHeight);
				
				if (!isOverItem)
				{
					for (checkbox in checkboxGroup)
					{
						if (checkbox.ID == i && checkbox.exists && FlxG.mouse.overlaps(checkbox))
						{
							isOverItem = true;
							break;
						}
					}
					if (!isOverItem && optionsArray[i].type != BOOL)
					{
						for (text in grpTexts)
						{
							if (text.ID == i && text.exists)
							{
								var textX:Float = text.x - 40;
								var textY:Float = text.y - 20;
								var textWidth:Float = text.width + 80;
								var textHeight:Float = text.height + 40;
								
								isOverItem = (FlxG.mouse.screenX >= textX && 
											 FlxG.mouse.screenX <= textX + textWidth &&
											 FlxG.mouse.screenY >= textY && 
											 FlxG.mouse.screenY <= textY + textHeight);
								if (isOverItem) break;
							}
						}
					}
				}
				
				if (isOverItem)
				{
					var centerX:Float = itemX + itemWidth / 2;
					var centerY:Float = itemY + optionHeight / 2;
					var distance:Float = Math.sqrt(Math.pow(centerX - FlxG.mouse.screenX, 2) + 
												   Math.pow(centerY - FlxG.mouse.screenY, 2));
					if (distance < minDist)
					{
						minDist = distance;
						newMouseOverItem = i;
					}
				}
			}

			if (newMouseOverItem != -1 && newMouseOverItem != mouseOverItem)
			{
				mouseOverItem = newMouseOverItem;
				updateMouseHover();
			}
			else if (newMouseOverItem == -1)
			{
				mouseOverItem = -1;
				updateMouseHover();
			}
			
			allowMouse = true;
		}
		
		if (FlxG.mouse.wheel != 0)
		{
			if (mouseOverItem != -1 && mouseOverItem == curSelected && !isBindingKey())
			{
				var wheelValue:Float = FlxG.mouse.wheel * (FlxG.keys.pressed.SHIFT ? 3 : 1);
				handleMouseWheel(wheelValue);
			}
			else
			{
				var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
				var selectionChange:Int = -shiftMult * FlxG.mouse.wheel;
				changeSelection(selectionChange);
			}
		}

		if (FlxG.mouse.justPressed && isMouseControl && !isBindingKey() && mouseOverItem != -1)
		{
			if (curSelected != mouseOverItem)
			{
				curSelected = mouseOverItem;
				changeSelection(0);
			}
			else
			{
				var usesCheckbox:Bool = (curOption.type == BOOL);
				if (usesCheckbox && nextAccept <= 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
				}
			}
		}
		
		if (FlxG.mouse.pressed && isMouseControl && mouseOverItem != -1 && mouseOverItem == curSelected && 
			!isBindingKey() && nextAccept <= 0 && curOption != null)
		{
			if (curOption.type != BOOL && curOption.type != KEYBIND && curOption.type != STRING)
			{
				mouseHoldTime += elapsed;
				if (mouseHoldTime > 0.1)
				{
					var mouseDelta:Float = FlxG.mouse.deltaScreenX;
					if (Math.abs(mouseDelta) > 0.1)
					{
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
						
						if (Math.abs(mouseDelta) > 2)
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
		
		if (FlxG.mouse.justPressedRight && isMouseControl && !isBindingKey())
		{
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.mouse.visible = true;
			return;
		}

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

		if(nextAccept <= 0)
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
										var num:Int = curOption.curOption;
										if(controls.UI_LEFT_P) --num;
										else num++;
			
										if(num < 0)
											num = curOption.options.length - 1;
										else if(num >= curOption.options.length)
											num = 0;
			
										curOption.curOption = num;
										curOption.setValue(curOption.options[num]);

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
						var add:Dynamic = wheelValue * curOption.changeValue;
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
						if(wheelValue > 0) num++;
						else if (wheelValue < 0) num--;

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
					keyPressed = LEFT_TRIGGER;
				else if(FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					keyPressed = RIGHT_TRIGGER;
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
				case '[', ']':
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

		curOption = optionsArray[curSelected];
		
		updateMouseHover();
		
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function reloadCheckboxes()
		for (checkbox in checkboxGroup)
			checkbox.daValue = Std.string(optionsArray[checkbox.ID].getValue()) == 'true';
	
	override function destroy()
	{
		super.destroy();
		FlxG.mouse.visible = true;
	}
}