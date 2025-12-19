package options;

import flixel.FlxG;
import flixel.math.FlxMath;

class KEOption
{
	public function new()
	{
		display = updateDisplay();
	}

	private var description:String = "";
	private var display:String;
	private var acceptValues:Bool = false;

	public static var valuechanged:Bool = false;
	public var acceptType:Bool = false;
	public var waitingType:Bool = false;

	// 改进的长按支持
	public var holdTime:Float = 0;
	public var holdValue:Float = 0;
	public var isHolding:Bool = false;

	// Psych Engine选项引用
	public var psychOption:Option = null;
	
	// 直接KEOption属性
	public var name:String = "";
	public var variable:String = "";
	public var type:String = "bool";
	public var value:Dynamic = null;
	public var defaultValue:Dynamic = null;
	public var minValue:Float = 0;
	public var maxValue:Float = 100;
	public var changeValue:Float = 1;
	public var scrollSpeed:Float = 50; // 长按滚动速度
	
	// 新增：字符串选项支持
	public var options:Array<String> = []; // 字符串选项列表
	public var curOption:Int = 0; // 当前选择的选项索引

	// 警告功能相关
	public var hasWarning:Bool = false;
	public var warningMessage:String = "";
	public var warningCallback:Void->Void = null;

	// 长按保护相关变量
	public var lastPressTime:Float = 0; // 上次按下时间
	public var pressCooldown:Float = 0.3; // 按键冷却时间（秒）
	
	// 长按相关变量 - 改进版
	private var initialDelay:Float = 0.5; // 初始延迟时间（秒）
	private var repeatDelay:Float = 0.05;  // 重复间隔时间（秒） - 更快的响应
	private var lastActionTime:Float = 0; // 上次执行操作的时间
	private var wasLeftPressed:Bool = false;
	private var wasRightPressed:Bool = false;
	
	// 防二次点击保护
	public var clickProtected:Bool = false;
	public var clickProtectionTime:Float = 0.2; // 点击保护时间

	public final function getDisplay():String
	{
		return display;
	}

	public final function getAccept():Bool
	{
		return acceptValues;
	}

	public final function getDescription():String
	{
		if(description != "") return description;
		if(psychOption != null) return psychOption.description;
		return "No description available.";
	}

	public function getValue():String
	{
		return updateDisplay();
	}

	public function onType(text:String)
	{
		// 用于键位绑定输入
	}

	// 检查是否可以执行操作（防二次点击）
	private function canPress():Bool
	{
		var currentTime = Date.now().getTime();
		var timeSinceLastPress = (currentTime - lastPressTime) / 1000;
		
		if (timeSinceLastPress < pressCooldown && clickProtected) {
			return false;
		}
		
		lastPressTime = currentTime;
		return true;
	}

	public function press():Bool
	{
		if (!canPress()) return false;
		
		if(type == "bool") {
			value = !value;
			saveValue();
			return true;
		}
		else if(type == "action") {
			// 处理特殊动作 - 现在包含警告检查
			switch(name) {
				case "Open Note Colors":
					KEOptionsMenu.instance.openSubState(new options.NotesColorSubState());
					return false;
				case "Open Controls":
					KEOptionsMenu.instance.openSubState(new options.ControlsSubState());
					return false;
				case "Open KE Styled KeyBinds":
					KEOptionsMenu.instance.openSubState(new options.KEKeyBindMenu());
					return false;   
				case "Reset KeyBinds":
					ClientPrefs.resetKeys();
					ClientPrefs.saveSettings();
					return true;
				case "Reset Settings":
					ClientPrefs.data = ClientPrefs.defaultData;
					ClientPrefs.saveSettings();
					ClientPrefs.loadPrefs();
					return true;
				case "Reset Scores":
					#if desktop
					
					#end
					return true;
				case "Adjust Delay and Combo":
					MusicBeatState.switchState(new options.NoteOffsetState());
					return false;

			}
			return true;
		}
		else if(type == "keybind") {
			waitingType = true;
			return true;
		}
		return false;
	}

	// 执行警告确认后的操作
	public function executeWarningAction():Void
	{
		if (!hasWarning || !canPress()) return;

		switch(name) {
			case "Reset KeyBinds":
				ClientPrefs.resetKeys();
				ClientPrefs.saveSettings();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				
			case "Reset Settings":
				ClientPrefs.data = ClientPrefs.defaultData;
				ClientPrefs.saveSettings();
				ClientPrefs.loadPrefs();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				
			case "Reset Scores":
				#if desktop
				
				#end
		}
	}

	// 设置警告
	public function setWarning(message:String, ?callback:Void->Void):KEOption
	{
		this.hasWarning = true;
		this.warningMessage = message;
		if (callback != null) {
			this.warningCallback = callback;
		}
		return this;
	}

	// 获取警告信息
	public function getWarning():String
	{
		return warningMessage;
	}

	// 检查是否有警告
	public function hasWarningCheck():Bool
	{
		return hasWarning;
	}

	// 长按更新逻辑 - 只处理左右键
	public function updateHold(elapsed:Float, leftPressed:Bool, rightPressed:Bool):Bool
	{
		var currentTime = Date.now().getTime();
		
		// 检查是否是新的按键按下
		var leftJustPressed = leftPressed && !wasLeftPressed;
		var rightJustPressed = rightPressed && !wasRightPressed;
		
		// 如果刚刚按下按键，重置计时器并立即执行一次操作
		if ((leftJustPressed || rightJustPressed) && (type == "int" || type == "float" || type == "string")) 
		{
			holdTime = 0;
			lastActionTime = currentTime;
			
			// 立即执行一次操作
			if (leftJustPressed) {
				left();
			} else if (rightJustPressed) {
				right();
			}
			
			// 播放音效（音量较低）
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			
			wasLeftPressed = leftPressed;
			wasRightPressed = rightPressed;
			return true;
		}
		
		// 持续按住时的处理
		if ((leftPressed || rightPressed) && (type == "int" || type == "float" || type == "string")) 
		{
			holdTime += elapsed;
			
			// 检查是否应该执行操作
			var shouldAct = false;
			var delay = (holdTime > initialDelay) ? repeatDelay : initialDelay;
			
			if (holdTime > initialDelay && (currentTime - lastActionTime) > (delay * 1000)) 
			{
				shouldAct = true;
				lastActionTime = currentTime;
			}
			
			if (shouldAct && canPress()) 
			{
				if (leftPressed) {
					left();
				} else if (rightPressed) {
					right();
				}
				// 连续滚动时使用更低的音量
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
				
				wasLeftPressed = leftPressed;
				wasRightPressed = rightPressed;
				return true;
			}
		}
		else 
		{
			// 释放按键时重置状态
			if (holdTime > 0) {
				holdTime = 0;
				lastActionTime = 0;
			}
		}
		
		wasLeftPressed = leftPressed;
		wasRightPressed = rightPressed;
		return false;
	}

	public function startHold()
	{
		if (type == "int" || type == "float") {
			holdValue = Std.parseFloat(Std.string(value));
			isHolding = true;
			holdTime = 0;
			lastActionTime = Date.now().getTime();
		}
	}

	public function stopHold()
	{
		holdTime = 0;
		isHolding = false;
		lastActionTime = 0;
		clickProtected = true;
		
		// 设置短暂的点击保护时间
		new flixel.util.FlxTimer().start(clickProtectionTime, function(tmr:flixel.util.FlxTimer) {
			clickProtected = false;
		});
	}

	private function updateDisplay():String
	{
		switch(type) {
			case "bool":
				return name + ": < " + (value ? "on" : "off") + " >";
			case "int", "float":
				return name + ": < " + value + " >";
			case "string":
				// 如果有选项列表，显示当前选项
				if (options.length > 0) {
					return name + ": < " + options[curOption] + " >";
				}
				return name + ": < " + value + " >";
			case "action":
				// 对于有警告的操作，添加警告标识
				if (hasWarning) {
					return "> " + name + " [!] <";
				}
				return "> " + name + " <";
			case "keybind":
				return name + ": < Set Key >";
			default:
				return name + ": < " + value + " >";
		}
	}

	public function left():Bool
	{
		if (!canPress()) return false;
		
		switch(type) {
			case "bool":
				value = !value;
				saveValue();
				return true;
			case "int", "float":
				var newValue:Float = Std.parseFloat(Std.string(value)) - changeValue;
				if(newValue < minValue) newValue = minValue;
				value = (type == "int") ? Math.round(newValue) : newValue;
				saveValue();
				return true;
			case "string":
				// 参考Psych Engine的逻辑：左右键切换字符串选项
				if (options.length > 0) {
					curOption--;
					if (curOption < 0) curOption = options.length - 1;
					value = options[curOption];
					saveValue();
					return true;
				}
				return false;
		}
		return false;
	}

	public function right():Bool
	{
		if (!canPress()) return false;
		
		switch(type) {
			case "bool":
				value = !value;
				saveValue();
				return true;
			case "int", "float":
				var newValue:Float = Std.parseFloat(Std.string(value)) + changeValue;
				if(newValue > maxValue) newValue = maxValue;
				value = (type == "int") ? Math.round(newValue) : newValue;
				saveValue();
				return true;
			case "string":
				// 参考Psych Engine的逻辑：左右键切换字符串选项
				if (options.length > 0) {
					curOption++;
					if (curOption >= options.length) curOption = 0;
					value = options[curOption];
					saveValue();
					return true;
				}
				return false;
		}
		return false;
	}

	private function saveValue()
	{
		if(variable != "") {
			Reflect.setProperty(ClientPrefs.data, variable, value);
			
			// 只在值实际改变时保存
			static var lastSaveTime:Float = 0;
			var currentTime = Date.now().getTime();
			if (currentTime - lastSaveTime > 200) { // 每200ms最多保存一次
				ClientPrefs.saveSettings();
				lastSaveTime = currentTime;
			}
			
			applyImmediateChanges();
		}
	}

	private function applyImmediateChanges()
	{
		switch(variable) {
			case "framerate":
				if(ClientPrefs.data.framerate > FlxG.drawFramerate) {
					FlxG.updateFramerate = ClientPrefs.data.framerate;
					FlxG.drawFramerate = ClientPrefs.data.framerate;
				} else {
					FlxG.drawFramerate = ClientPrefs.data.framerate;
					FlxG.updateFramerate = ClientPrefs.data.framerate;
				}
			case "showFPS":
				if(Main.fpsVar != null)
					Main.fpsVar.visible = ClientPrefs.data.showFPS;
			case "autoPause":
				FlxG.autoPause = ClientPrefs.data.autoPause;
			// 移除了对noteSkin和splashSkin的即时预览代码
		}
	}

	// 静态构造函数 - 支持警告参数
	public static function create(name:String, description:String, variable:String, type:String = "bool", defaultValue:Dynamic = null, minValue:Float = 0, maxValue:Float = 100, changeValue:Float = 1, scrollSpeed:Float = 50, hasWarning:Bool = false, warningMessage:String = ""):KEOption
	{
		var option = new KEOption();
		option.name = name;
		option.description = description;
		option.variable = variable;
		option.type = type;
		option.minValue = minValue;
		option.maxValue = maxValue;
		option.changeValue = changeValue;
		option.scrollSpeed = scrollSpeed;
		option.hasWarning = hasWarning;
		option.warningMessage = warningMessage;
		
		// 从ClientPrefs获取当前值
		if(variable != "") {
			option.value = Reflect.getProperty(ClientPrefs.data, variable);
			#if debug
			if (type == "string") trace('[$name] ClientPrefs value: "${option.value}"');
			#end
			
			// 如果值为空，使用默认值
			if (option.value == null || option.value == "") {
				#if debug
				trace('[$name] Value is empty, using default');
				#end
				if (defaultValue != null && !Std.isOfType(defaultValue, Array)) {
					// 对于非数组的默认值
					option.value = defaultValue;
				}
			}
		}
		
		// 设置字符串选项的当前索引
		if (type == "string" && Std.isOfType(defaultValue, Array)) {
			option.options = cast defaultValue;
			
			#if debug
			trace('[$name] String array option with ${option.options.length} items');
			for (i in 0...option.options.length) {
				trace('  [$i] ${option.options[i]}');
			}
			#end
			
			// 确保选项列表不为空
			if (option.options.length == 0) {
				#if debug
				trace('[$name] WARNING: Options array is empty!');
				#end
				option.value = "";
				option.curOption = -1;
			} else {
				// 查找当前值在选项列表中的位置
				var found = false;
				if (option.value != null && option.value != "") {
					for (i in 0...option.options.length) {
						if (option.options[i] == option.value) {
							option.curOption = i;
							found = true;
							#if debug
							trace('[$name] Found value "${option.value}" at index $i');
							#end
							break;
						}
					}
				}
				
				// 如果没找到，使用第一个选项
				if (!found) {
					option.curOption = 0;
					option.value = option.options[0];
					#if debug
					trace('[$name] Value not found, using first option: "${option.value}"');
					#end
					
					// 保存到ClientPrefs（如果是新选项）
					if (variable != "" && (option.value != null && option.value != "")) {
						var currentValue = Reflect.getProperty(ClientPrefs.data, variable);
						if (currentValue != option.value) {
							Reflect.setProperty(ClientPrefs.data, variable, option.value);
							#if debug
							trace('[$name] Saving new value to ClientPrefs: "${option.value}"');
							#end
						}
					}
				}
			}
		} else if (type == "string") {
			// 对于没有选项列表的字符串类型（简单字符串）
			#if debug
			trace('[$name] Simple string option (no options array)');
			#end
			option.acceptValues = false; // 简单字符串不能左右切换
		}
		
		// 对于非字符串的数值类型
		if (type == "int" || type == "float") {
			// 确保值在范围内
			if (option.value == null) {
				option.value = defaultValue != null ? defaultValue : minValue;
			}
			var val:Float = Std.parseFloat(Std.string(option.value));
			if (val < minValue) val = minValue;
			if (val > maxValue) val = maxValue;
			option.value = (type == "int") ? Math.round(val) : val;
		}
		
		option.acceptValues = (type == "int" || type == "float" || type == "string" && option.options.length > 0);
		return option;

	}

	// 创建带选项列表的字符串选项的便捷方法
	public static function createStringOption(name:String, description:String, variable:String, options:Array<String>, defaultValue:String = ""):KEOption
	{
		var option = new KEOption();
		option.name = name;
		option.description = description;
		option.variable = variable;
		option.type = "string";
		option.options = options;
		
		// 从ClientPrefs获取当前值
		if(variable != "") {
			option.value = Reflect.getProperty(ClientPrefs.data, variable);
		}
		
		// 设置当前选项索引
		var found = false;
		for (i in 0...options.length) {
			if (options[i] == option.value) {
				option.curOption = i;
				found = true;
				break;
			}
		}
		
		// 如果没找到，使用默认值或第一个选项
		if (!found) {
			if (defaultValue != "" && options.contains(defaultValue)) {
				option.value = defaultValue;
				for (i in 0...options.length) {
					if (options[i] == defaultValue) {
						option.curOption = i;
						break;
					}
				}
			} else if (options.length > 0) {
				option.value = options[0];
				option.curOption = 0;
			}
		}
		
		option.acceptValues = true;
		return option;
	}

	// 创建带警告的重置选项的便捷方法
	public static function createResetOption(name:String, resetType:String):KEOption
	{
		var option:KEOption = null;
		
		switch(resetType) {
			case "keybinds":
				option = create("Reset KeyBinds", "Reset all key bindings to default", "", "action");
				option.setWarning("Are you sure you want to reset ALL key bindings to default?\nThis action cannot be undone!");
				
			case "settings":
				option = create("Reset Settings", "Reset all settings to default", "", "action");
				option.setWarning("Are you sure you want to reset ALL settings to default?\nThis will reset graphics, gameplay, and other preferences!\nThis action cannot be undone!");
				
			case "scores":
				option = create("Reset Scores", "Clear all high scores and ratings", "", "action");
				option.setWarning("Are you sure you want to reset ALL high scores?\nThis will delete all your progress and ratings!\nThis action cannot be undone!");
				
			default:
				option = create(name, "Reset option", "", "action");
		}
		
		return option;
	}
}