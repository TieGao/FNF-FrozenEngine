package options.objects.backend;

import options.Option;
import backend.InputFormatter;
import backend.UIControlTheme;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

/**
 * 键位控件（KEYBIND 类型）
 *
 * 主条样式沿用 StringSelect，但不弹下拉，而是"就地捕获"：点一下 → 条上的文字变成
 * "Press a key..."，之后按下的那个键就是新键位。
 *
 * 交互与原版 Controls 菜单保持一致：
 *   - 长按 ESC（手柄 B）0.5s = 取消，保留原键位；长按退格（手柄 BACK）0.5s = 清空成 NONE
 *   - 点别处 / 右键 = 取消
 *
 * ⚠️ 捕获期间界面自己的键鼠操作必须让路，否则"按方向键选键位"会同时滚动列表、
 *   "按回车选键位"会顺手触发选中行上的别的选项。这里用静态 `capturing` 对外声明
 *   "我正在等按键"，宿主界面把它接到 Win8CharmSettings.inputModal 上。
 *
 * ⚠️ 捕获期间**不能**让所在的行滚出可视区：行不可见时 Win8CharmSettings 会把
 *   row.active 置 false，FlxSpriteGroup 的 active 会传播给子元素 → 本控件不再 update，
 *   捕获就永远结束不了。宿主界面靠 inputModal 冻结滚动来避免这种情况。
 */
class KeybindButton extends FlxSpriteGroup
{
	/** 当前正在等按键的按钮（全局唯一）。宿主界面用它判断要不要挂起自己的输入处理。 */
	public static var capturing:KeybindButton = null;

	/** 长按多久算"取消/清空"（秒） */
	static inline var HOLD_TIME:Float = 0.5;

	var follow:Option;

	var bg:Rect;
	var border:FlxSprite;   // 仅 Win8 风格
	var dis:FlxText;

	/** 本次构建时解析出的风格 */
	var win8:Bool = false;

	var hover:Bool = false;
	var pressing:Bool = false;

	/** 长按计时（ESC / 退格） */
	var holdTime:Float = 0;

	public function new(X:Float, Y:Float, width:Float, height:Float, follow:Option)
	{
		super(X, Y);
		UITheme.ensure();

		this.follow = follow;
		win8 = UIControlTheme.isWin8();

		bg = new Rect(0, 0, width, height, UIControlTheme.radius(4), UIControlTheme.radius(4),
			win8 ? UIControlTheme.face() : UITheme.control, 1);
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		if (win8)
		{
			border = UIControlTheme.makeFrameSprite(width, height);
			border.color = borderColor();
			add(border);
		}

		dis = new FlxText(10, 0, width - 20, '', 16);
		dis.setFormat(Paths.font('montserrat.ttf'), 16, textColor(), LEFT);
		dis.borderStyle = NONE;
		dis.antialiasing = ClientPrefs.data.antialiasing;
		dis.y = (height - dis.height) * 0.5;
		add(dis);

		refreshValue();
	}

	// =========================================================
	// 配色
	// =========================================================
	inline function accentColor():FlxColor
		return win8 ? UIControlTheme.accent() : UITheme.accent;

	inline function mainTextColor():FlxColor
		return win8 ? UIControlTheme.text() : UITheme.textPrimary;

	function textColor():FlxColor
		return (hover || isCapturing()) ? accentColor() : mainTextColor();

	function borderColor():FlxColor
		return (hover || isCapturing()) ? UIControlTheme.accent() : UIControlTheme.border();

	function computeMainColor():Int
	{
		if (win8)
			return pressing ? UIControlTheme.facePress() : (hover ? UIControlTheme.faceHover() : UIControlTheme.face());
		return pressing ? UITheme.controlPress : (hover ? UITheme.controlHover : UITheme.control);
	}

	// =========================================================
	// 值
	// =========================================================
	public function isCapturing():Bool
		return capturing == this;

	/** 当前键位的显示名（跟随键鼠模式） */
	function currentKeyLabel():String
	{
		var raw:Dynamic = follow.getValue();
		var v:String = (raw == null) ? 'NONE' : Std.string(raw);
		if (v.length == 0) v = 'NONE';

		if (Controls.instance.controllerMode)
			return InputFormatter.getGamepadName(FlxGamepadInputID.fromString(v));
		return InputFormatter.getKeyName(FlxKey.fromString(v));
	}

	public function refreshValue():Void
	{
		if (dis == null) return;

		dis.text = isCapturing()
			? Language.getPhrase('controls_rebinding_wait', 'Press a key...')
			: currentKeyLabel();

		dis.color = textColor();
		if (border != null) border.color = borderColor();
	}

	// =========================================================
	// 捕获
	// =========================================================
	/** 开始等按键（鼠标点它 / 界面按回车都会走这里） */
	public function startCapture():Void
	{
		if (capturing == this) return;
		if (capturing != null) capturing.cancelCapture();

		capturing = this;
		holdTime = 0;
		refreshValue();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	/** 取消捕获，保留原键位 */
	public function cancelCapture():Void
	{
		if (capturing != this) return;
		capturing = null;
		holdTime = 0;
		refreshValue();
	}

	/**
	 * 写入新键位并结束捕获。
	 * 值统一存成 FlxKey / FlxGamepadInputID 的**枚举名**（'A' / 'SPACE' / 'NONE'…），
	 * 这样 mod 侧 settings.json 里写的字符串能直接对上（不要存 InputFormatter 的显示名，
	 * 那是给玩家看的，fromString 认不出来）。
	 */
	function commitKey(value:String):Void
	{
		capturing = null;
		holdTime = 0;

		follow.setValue(value);
		follow.change();
		refreshValue();
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
	}

	// =========================================================
	// 更新
	// =========================================================
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!follow.allowUpdate) return;

		if (isCapturing())
		{
			captureUpdate(elapsed);
			return;
		}

		var mouse = FlxG.mouse;
		var wasHover = hover;
		hover = OptionInput.overlaps(bg);

		if (hover != wasHover)
		{
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 0.12, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
			refreshValue();
		}

		if (hover && mouse.justPressed)
		{
			pressing = true;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 0.05, bg.color, computeMainColor());
		}

		if (mouse.justReleased && pressing && hover)
		{
			pressing = false;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 0.1, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
			startCapture();
		}

		if (!hover && pressing)
		{
			pressing = false;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 0.1, bg.color, computeMainColor(), {ease: FlxEase.quadOut});
		}
	}

	function captureUpdate(elapsed:Float):Void
	{
		// ---------- 取消：右键 / 点别处 ----------
		if (FlxG.mouse.justPressedRight)
		{
			cancelCapture();
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			return;
		}

		if (FlxG.mouse.justPressed && !OptionInput.overlaps(bg))
		{
			cancelCapture();
			return;
		}

		// ---------- 长按 ESC / B = 取消 ----------
		if (FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
		{
			holdTime += elapsed;
			if (holdTime > HOLD_TIME)
			{
				cancelCapture();
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			}
			return;
		}

		// ---------- 长按退格 / BACK = 清空 ----------
		if (FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
		{
			holdTime += elapsed;
			if (holdTime > HOLD_TIME) commitKey('NONE');
			return;
		}

		holdTime = 0;

		if (Controls.instance.controllerMode) captureGamepad();
		else captureKeyboard();
	}

	function captureKeyboard():Void
	{
		if (!FlxG.keys.justPressed.ANY && !FlxG.keys.justReleased.ANY) return;

		var keyPressed:FlxKey = cast FlxG.keys.firstJustPressed();
		var keyReleased:FlxKey = cast FlxG.keys.firstJustReleased();

		// 刚按下的键直接绑；ESC / 退格走"长按"那条路，所以只在**松开**时才允许绑它们
		if (keyPressed != NONE && keyPressed != ESCAPE && keyPressed != BACKSPACE)
			commitKey(keyName(keyPressed));
		else if (keyReleased != NONE && (keyReleased == ESCAPE || keyReleased == BACKSPACE))
			commitKey(keyName(keyReleased));
	}

	function captureGamepad():Void
	{
		if (!FlxG.gamepads.anyJustPressed(ANY) && !FlxG.gamepads.anyJustPressed(LEFT_TRIGGER)
			&& !FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) && !FlxG.gamepads.anyJustReleased(ANY)) return;

		var keyPressed:FlxGamepadInputID = NONE;
		var keyReleased:FlxGamepadInputID = NONE;

		// 扳机在 anyJustPressed 里不生效，得单独判（和原版 Controls 菜单同一个坑）
		if (FlxG.gamepads.anyJustPressed(LEFT_TRIGGER))
			keyPressed = LEFT_TRIGGER;
		else if (FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
			keyPressed = RIGHT_TRIGGER;
		else
		{
			for (i in 0...FlxG.gamepads.numActiveGamepads)
			{
				var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
				if (gamepad == null) continue;

				keyPressed = gamepad.firstJustPressedID();
				keyReleased = gamepad.firstJustReleasedID();
				if (keyPressed != NONE || keyReleased != NONE) break;
			}
		}

		if (keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
			commitKey(padName(keyPressed));
		else if (keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
			commitKey(padName(keyReleased));
	}

	/** FlxKey --(@:to toString)--> 枚举名（'A' / 'SPACE'…） */
	function keyName(k:FlxKey):String
	{
		var s:String = k;
		return (s != null) ? s : 'NONE';
	}

	/** FlxGamepadInputID --(@:to toString)--> 枚举名（'A' / 'DPAD_UP'…） */
	function padName(id:FlxGamepadInputID):String
	{
		var s:String = id;
		return (s != null) ? s : 'NONE';
	}

	/** 主题/控件风格切换后重新套用配色（行被重建时无需调用） */
	public function refreshTheme():Void
	{
		if (bg != null) bg.color = computeMainColor();
		if (border != null) border.color = borderColor();
		refreshValue();
	}

	override function destroy():Void
	{
		// 静态指针必须清掉，否则面板关了以后它还指着一个已销毁的控件
		if (capturing == this) capturing = null;
		super.destroy();
	}
}
