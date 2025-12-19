package options;

import objects.AttachedText;
import objects.CheckboxThingie;

import options.Option.OptionType;

class GameplayChangersSubstate extends MusicBeatSubstate
{
	private var curSelected:Int = 0;
	private var optionsArray:Array<Dynamic> = [];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;
	
	// 鼠标控制相关变量
	var allowMouse:Bool = true;
	var timeNotMoving:Float = 0;
	var isMouseControl:Bool = false;
	var mouseOverItem:Int = -1;

	private var curOption(get, never):GameplayOption;
	function get_curOption() return optionsArray[curSelected]; //shorter lol

	function getOptions()
	{
		var goption:GameplayOption = new GameplayOption('Scroll Type', 'scrolltype', STRING, 'multiplicative', ["multiplicative", "constant"]);
		optionsArray.push(goption);

		var option:GameplayOption = new GameplayOption('Scroll Speed', 'scrollspeed', FLOAT, 1);
		option.scrollSpeed = 2.0;
		option.minValue = 0.35;
		option.changeValue = 0.05;
		option.decimals = 2;
		if (goption.getValue() != "constant")
		{
			option.displayFormat = '%vX';
			option.maxValue = 3;
		}
		else
		{
			option.displayFormat = "%v";
			option.maxValue = 6;
		}
		optionsArray.push(option);

		#if FLX_PITCH
		var option:GameplayOption = new GameplayOption('Playback Rate', 'songspeed', FLOAT, 1);
		option.scrollSpeed = 1;
		option.minValue = 0.5;
		option.maxValue = 3.0;
		option.changeValue = 0.05;
		option.displayFormat = '%vX';
		option.decimals = 2;
		optionsArray.push(option);
		#end

		var option:GameplayOption = new GameplayOption('Health Gain Multiplier', 'healthgain', FLOAT, 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Health Loss Multiplier', 'healthloss', FLOAT, 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		optionsArray.push(new GameplayOption('Instakill on Miss', 'instakill', BOOL, false));
		optionsArray.push(new GameplayOption('Practice Mode', 'practice', BOOL, false));
		optionsArray.push(new GameplayOption('Botplay', 'botplay', BOOL, false));
		optionsArray.push(new GameplayOption('Opponent Mode', 'opponentplay', BOOL, false));
	}

	public function getOptionByName(name:String)
	{
		for(i in optionsArray)
		{
			var opt:GameplayOption = i;
			if (opt.name == name)
				return opt;
		}
		return null;
	}

	public function new()
	{
		super();
		
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);
		
		getOptions();

		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(150, 360, optionsArray[i].name, true);
			optionText.isMenuItem = true;
			optionText.setScale(0.8);
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(optionsArray[i].type == BOOL)
			{
				optionText.x += 60;
				optionText.startPosition.x += 60;
				optionText.snapToPosition();
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.offsetX -= 20;
				checkbox.offsetY = -52;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
			}
			else
			{
				optionText.snapToPosition();
				var valueText:AttachedText = new AttachedText(Std.string(optionsArray[i].getValue()), optionText.width + 40, 0, true, 0.8);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
		
		// 初始隐藏鼠标
		FlxG.mouse.visible = false;
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	override function update(elapsed:Float)
	{
		// 鼠标控制逻辑
		if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
		{
			allowMouse = false;
			FlxG.mouse.visible = true;
			timeNotMoving = 0;
			isMouseControl = true;

			var newMouseOverItem:Int = -1;
			var minDist:Float = 999999;
			
			// 检查鼠标是否悬停在某个选项上
			for (i in 0...grpOptions.length)
			{
				var item:Alphabet = grpOptions.members[i];
				var checkbox:CheckboxThingie = null;
				var valueText:AttachedText = null;
				
				// 检查复选框
				for (cb in checkboxGroup)
				{
					if (cb.ID == i)
					{
						checkbox = cb;
						break;
					}
				}
				
				// 检查值文本
				for (vt in grpTexts)
				{
					if (vt.ID == i)
					{
						valueText = vt;
						break;
					}
				}
				
				var isOverItem:Bool = false;
				
				// 检查鼠标是否在选项文本、复选框或值文本上
				if (FlxG.mouse.overlaps(item))
					isOverItem = true;
				else if (checkbox != null && FlxG.mouse.overlaps(checkbox))
					isOverItem = true;
				else if (valueText != null && FlxG.mouse.overlaps(valueText))
					isOverItem = true;
				
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

			if (newMouseOverItem != -1 && newMouseOverItem != mouseOverItem)
			{
				mouseOverItem = newMouseOverItem;
				// 鼠标悬停时高亮显示
				updateMouseHover();
			}
			else if (newMouseOverItem == -1)
			{
				mouseOverItem = -1;
				updateMouseHover();
			}
			
			allowMouse = true;
		}
		else if (isMouseControl)
		{
			
		}
		
		// 鼠标滚轮逻辑
		if (FlxG.mouse.wheel != 0)
		{
			if (mouseOverItem != -1 && mouseOverItem == curSelected)
			{
				// 鼠标悬停在当前选中的选项上：调整数值
				var usesCheckbox:Bool = (curOption.type == BOOL);
				if (!usesCheckbox && nextAccept <= 0)
				{
					var wheelValue:Float = FlxG.mouse.wheel * (FlxG.keys.pressed.SHIFT ? 3 : 1);
					
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
							if(wheelValue < 0) --num;
							else num++;

							if(num < 0)
								num = curOption.options.length - 1;
							else if(num >= curOption.options.length)
								num = 0;

							curOption.curOption = num;
							curOption.setValue(curOption.options[num]);
							
							if (curOption.name == "Scroll Type")
							{
								var oOption:GameplayOption = getOptionByName("Scroll Speed");
								if (oOption != null)
								{
									if (curOption.getValue() == "constant")
									{
										oOption.displayFormat = "%v";
										oOption.maxValue = 6;
									}
									else
									{
										oOption.displayFormat = "%vX";
										oOption.maxValue = 3;
										if(oOption.getValue() > 3) oOption.setValue(3);
									}
									updateTextFrom(oOption);
								}
							}
							FlxG.sound.play(Paths.sound('scrollMenu'));

						default:
					}
					updateTextFrom(curOption);
					curOption.change();
				}
			}
			else
			{
				// 鼠标不在选项上或不在当前选中的选项上：上下滚动选择
				var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
				changeSelection(-shiftMult * FlxG.mouse.wheel);
			}
		}

		// 保留原来的键盘控制逻辑
		if(optionsArray.length > 1)
		{
			var shiftMult:Int = 1;
			if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

			var upP = controls.UI_UP_P;
			var downP = controls.UI_DOWN_P;

			if (upP && !isMouseControl)
			{
				changeSelection(-shiftMult);
				holdTime = 0;
			}
			if (downP && !isMouseControl)
			{
				changeSelection(shiftMult);
				holdTime = 0;
			}

			if(!isMouseControl && (controls.UI_DOWN || controls.UI_UP))
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
		
		// 鼠标点击选择选项
		if (FlxG.mouse.justPressed && isMouseControl && mouseOverItem != -1)
		{
			if (curSelected != mouseOverItem)
			{
				// 左键点击未选中的选项：选择它
				curSelected = mouseOverItem;
				changeSelection();
			}
			else
			{
				// 左键点击已选中的选项：如果是复选框则切换
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

		if (controls.BACK || FlxG.mouse.justPressedRight)
		{
			close();
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.mouse.visible = true;
		}
		
		// 鼠标拖动调整数值（非布尔类型）
		if (FlxG.mouse.pressed && isMouseControl && mouseOverItem != -1 && mouseOverItem == curSelected && !(curOption.type == BOOL) && curOption.type != STRING && nextAccept <= 0)
		{
			var mouseDelta:Float = FlxG.mouse.deltaScreenX;
			if (Math.abs(mouseDelta) > 0.1)
			{
				var add:Dynamic = mouseDelta * curOption.changeValue * 0.5;
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
				timeNotMoving = 0; // 重置不活动时间
			}
		}

		if(nextAccept <= 0)
		{
			var usesCheckbox:Bool = (curOption.type == BOOL);
			
			if(usesCheckbox)
			{
				if(controls.ACCEPT && !isMouseControl)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
				}
			}
			else
			{
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

								case STRING:
									var num:Int = curOption.curOption; //lol
									if(controls.UI_LEFT_P) --num;
									else num++;

									if(num < 0)
										num = curOption.options.length - 1;
									else if(num >= curOption.options.length)
										num = 0;

									curOption.curOption = num;
									curOption.setValue(curOption.options[num]); //lol
									
									if (curOption.name == "Scroll Type")
									{
										var oOption:GameplayOption = getOptionByName("Scroll Speed");
										if (oOption != null)
										{
											if (curOption.getValue() == "constant")
											{
												oOption.displayFormat = "%v";
												oOption.maxValue = 6;
											}
											else
											{
												oOption.displayFormat = "%vX";
												oOption.maxValue = 3;
												if(oOption.getValue() > 3) oOption.setValue(3);
											}
											updateTextFrom(oOption);
										}
									}
									//trace(curOption.options[num]);

								default:
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound('scrollMenu'));
						}
						else if(curOption.type != STRING)
						{
							holdValue = Math.max(curOption.minValue, Math.min(curOption.maxValue, holdValue + curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1)));

							switch(curOption.type)
							{
								case INT:
									curOption.setValue(Math.round(holdValue));
								
								case FLOAT, PERCENT:
									var blah:Float = Math.max(curOption.minValue, Math.min(curOption.maxValue, holdValue + curOption.changeValue - (holdValue % curOption.changeValue)));
									curOption.setValue(FlxMath.roundDecimal(blah, curOption.decimals));

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
					clearHold();
			}

			if(controls.RESET && !isMouseControl)
			{
				for (i in 0...optionsArray.length)
				{
					var leOption:GameplayOption = optionsArray[i];
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != BOOL)
					{
						if(leOption.type == STRING)
							leOption.curOption = leOption.options.indexOf(leOption.getValue());

						updateTextFrom(leOption);
					}

					if(leOption.name == 'Scroll Speed')
					{
						leOption.displayFormat = "%vX";
						leOption.maxValue = 3;
						if(leOption.getValue() > 3)
							leOption.setValue(3);

						updateTextFrom(leOption);
					}
					leOption.change();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}
	
	function updateMouseHover()
	{
		for (num => item in grpOptions.members)
		{
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
	}

	function updateTextFrom(option:GameplayOption) {
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == PERCENT) val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}

	function clearHold()
	{
		if(holdTime > 0.5)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		holdTime = 0;
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);
		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
				item.alpha = 1;
		}
		for (text in grpTexts)
		{
			text.alpha = 0.6;
			if(text.ID == curSelected)
				text.alpha = 1;
		}
		
		// 重置鼠标悬停状态
		mouseOverItem = -1;
		updateMouseHover();
		
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function reloadCheckboxes() {
		for (checkbox in checkboxGroup) {
			checkbox.daValue = (optionsArray[checkbox.ID].getValue() == true);
		}
	}
}

class GameplayOption
{
	private var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Void->Void = null; //Pressed enter (on Bool type options) or pressed/held left/right (on other types)
	public var type:OptionType = BOOL;

	public var showBoyfriend:Bool = false;
	public var scrollSpeed:Float = 50; //Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String = null; //Variable from ClientPrefs.hx's gameplaySettings
	public var defaultValue:Dynamic = null;

	public var curOption:Int = 0; //Don't change this
	public var options:Array<String> = null; //Only used in string type
	public var changeValue:Dynamic = 1; //Only used in int/float/percent type, how much is changed when you PRESS
	public var minValue:Dynamic = null; //Only used in int/float/percent type
	public var maxValue:Dynamic = null; //Only used in int/float/percent type
	public var decimals:Int = 1; //Only used in float/percent type

	public var displayFormat:String = '%v'; //How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var name:String = 'Unknown';

	public function new(name:String, variable:String, type:OptionType, defaultValue:Dynamic = 'null variable value', ?options:Array<String> = null)
	{
		_name = name;
		this.name = Language.getPhrase('setting_$name', name);
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		if(defaultValue == 'null variable value')
		{
			switch(type)
			{
				case BOOL:
					defaultValue = false;
				case INT, FLOAT:
					defaultValue = 0;
				case PERCENT:
					defaultValue = 1;
				case STRING:
					defaultValue = '';
					if(options.length > 0)
						defaultValue = options[0];

				default:
			}
		}

		if(getValue() == null)
			setValue(defaultValue);

		switch(type)
		{
			case STRING:
				var num:Int = options.indexOf(getValue());
				if(num > -1)
					curOption = num;

			case PERCENT:
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;

			default:
		}
	}

	public function change()
	{
		//nothing lol
		if(onChange != null)
			onChange();
	}

	public function getValue():Dynamic
		return ClientPrefs.data.gameplaySettings.get(variable);

	public function setValue(value:Dynamic)
		ClientPrefs.data.gameplaySettings.set(variable, value);

	public function setChild(child:Alphabet)
		this.child = child;

	var _name:String = null;
	var _text:String = null;
	private function get_text()
		return _text;

	private function set_text(newValue:String = '')
	{
		if(child != null)
		{
			_text = newValue;
			child.text = Language.getPhrase('setting_$_name-$_text', _text);
			return _text;
		}
		return null;
	}
}